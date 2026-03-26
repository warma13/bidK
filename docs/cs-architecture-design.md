# 拍卖之王 — C/S 架构重写设计文档

> 本文档描述新的 C/S 架构应该长什么样，而非在旧代码上打补丁。
>
> 保留的部分：`Shared.lua`（事件常量）、`ClientGameState.lua`（只读镜像）、所有 UI 的 `SetNetworkMode` 机制、`Standalone.lua`
>
> 重写的部分：`Client.lua`、`Server.lua`、`RoomManager.lua`、`RoomInstance.lua`
>
> 需配合修改的部分：`AI/Strategies.lua`、`EstimateValue.lua`、`AIPlayer.lua`、`MoneyManager.lua`、`SaveSystem.lua`、若干 UI 模块

---

## 目录

1. [总体架构](#1-总体架构)
2. [事件协议设计](#2-事件协议设计)
3. [Client.lua 设计](#3-clientlua-设计)
4. [Server.lua 设计](#4-serverlua-设计)
5. [RoomManager.lua 设计](#5-roommanagerlua-设计)
6. [RoomInstance.lua 设计](#6-roominstancelua-设计)
7. [模块隔离策略](#7-模块隔离策略)
8. [数据持久化策略](#8-数据持久化策略)
9. [现有模块改动](#9-现有模块改动)
10. [断线重连设计](#10-断线重连设计)
11. [实施顺序](#11-实施顺序)
12. [仓库类型选择机制](#12-仓库类型选择机制)
13. [结算回收流程（详细）](#13-结算回收流程详细)
14. [AI 补位生命周期](#14-ai-补位生命周期)
15. [在线人数与自定义房间（扩展预留）](#15-在线人数与自定义房间扩展预留)
16. [局外系统 C/S 处理方案](#16-局外系统-cs-处理方案)
17. [数据持久化策略（补充）](#17-数据持久化策略补充)

---

## 1. 总体架构

### 1.1 角色划分

```
┌─────────────────────────────────────────────────────┐
│                     服务端                            │
│                                                       │
│  Server.lua          连接管理 + 事件路由               │
│       │                                               │
│  RoomManager.lua     房间生命周期管理 + 匹配           │
│       │                                               │
│  RoomInstance.lua     单局游戏驱动（一个房间一个实例）   │
│       │                                               │
│  ┌────┴────────────────────────────┐                  │
│  │ 隔离模块（每房间独立副本）        │                  │
│  │ GameState · AuctionEngine       │                  │
│  │ AIPlayer · SkillSystem          │                  │
│  │ MoneyManager · InfoSystem       │                  │
│  │ WarehouseGenerator · RevealPlanner │                │
│  │ EstimateValue · RecycleManager  │                  │
│  │ AntiCheat · Strategies · InfoEstimation │           │
│  └─────────────────────────────────┘                  │
└─────────────────────────────────────────────────────┘
          ↕  Remote Events (JSON over VariantMap)
┌─────────────────────────────────────────────────────┐
│                     客户端                            │
│                                                       │
│  Client.lua          连接管理 + 事件收发 + 加载闸门    │
│       │                                               │
│  ClientGameState.lua 只读状态镜像（setter 仅 Client 调用）│
│       │                                               │
│  GameController.lua  UI 流程编排                       │
│       │                                               │
│  各 UI Panel         SetNetworkMode(clientGameState)  │
└─────────────────────────────────────────────────────┘
```

### 1.2 核心原则

| 原则 | 说明 |
|------|------|
| **服务端权威** | 所有游戏逻辑（出价、判定、技能、结算）由服务端执行，客户端只提交操作 + 展示结果 |
| **客户端无写** | 对局内的金币/物品/统计变动，客户端不写 `clientCloud`，由服务端通过 `serverCloud` 写入 |
| **事件驱动** | 客户端通过事件接收状态变更，不轮询 |
| **房间隔离** | 每个房间拥有独立的模块副本，多房间并行互不干扰 |
| **闸门加载** | 客户端在 `lobby` + `clientCloud` 就绪后才进入菜单，确保数据正确 |

### 1.3 三路分发（不变）

```lua
-- main.lua（不变）
if IsServerMode() then
    require("network.Server").Start()
elseif IsNetworkMode() then
    require("network.Client").Start()
else
    require("network.Standalone").Start()
end
```

---

## 2. 事件协议设计

### 2.1 客户端 → 服务端

| 事件 | 数据 | 触发时机 |
|------|------|---------|
| `C_JOIN_ROOM` | `{ regionId, diffIdx, charIdx }` | 玩家点击开始游戏 |
| `C_LEAVE_ROOM` | `{}` | 玩家主动离开房间 |
| `C_SEALED_BID` | `{ amount, useSkill }` | 暗标阶段出价 |
| `C_TIEBREAK_BID` | `{ amount }` | 实时竞拍阶段出价 |
| `C_USE_SKILL` | `{}` | 使用主动技能 |
| `C_SKIP_WAREHOUSE` | `{}` | 跳过开箱动画 |
| `C_REQUEST_STATE` | `{}` | 断线重连后请求完整状态 |
| `C_REDEEM_CODE` | `{ code }` | 请求兑换码验证（见 16.6 节） |

注意：与旧版相比，`C_JOIN_ROOM` 新增了 `charIdx`（不含 `warehouseTypeId`，仓库类型由服务端根据区域配置决定，见第 12 章）；新增了 `C_REQUEST_STATE`。

### 2.2 服务端 → 客户端

#### 匹配/房间阶段

| 事件 | 数据 | 说明 |
|------|------|------|
| `S_JOIN_RESULT` | `{ ok, roomId, error? }` | 加入房间结果（替代旧 `S_ASSIGN_SLOT`） |
| `S_ROOM_STATUS` | `{ roomId, players[], countdown }` | 房间等待状态更新（新玩家加入/倒计时） |
| `S_GAME_INIT` | 见下方详细结构 | 游戏初始化（每人收到不同的 `mySlot`） |
| `S_JOIN_FAILED` | `{ reason }` | 加入失败（金币不足 / 房间满 / 匹配超时） |

#### 竞拍阶段

| 事件 | 数据 | 说明 |
|------|------|------|
| `S_PHASE_CHANGE` | `{ phase, round, timer }` | 阶段变更通知 |
| `S_INFO_REVEALED` | `{ round, items[] }` | 信息揭示（每个 item 含 idx/level/已揭示字段） |
| `S_PRIVATE_INFO` | `{ skillItems[] }` | 技能揭示的私密信息（仅发给使用者） |
| `S_BID_START` | `{ timer }` | 暗标阶段开始 |
| `S_AI_BID_CONFIRMED` | `{ playerIdx }` | AI 已出价（UI 显示"已锁定"） |
| `S_PLAYER_BID_CONFIRMED` | `{ playerIdx }` | 真人玩家已出价 |
| `S_BID_FINALIZED` | `{ revealOrder[] }` | 所有出价锁定，准备揭示 |
| `S_BID_REVEALED` | `{ revealIndex, playerIdx, amount }` | 逐个揭示出价 |
| `S_JUDGE_RESULT` | `{ result }` | 判定结果（赢家/平局/未决） |
| `S_TIEBREAK_START` | `{ players[], startBid, timer }` | 实时竞拍开始 |
| `S_BID_PLACED` | `{ playerIdx, amount }` | 实时竞拍中有人出价 |
| `S_WAREHOUSE_OPEN` | `{ winner, winnerPaid }` | 开箱开始 |
| `S_ITEM_REVEALED` | `{ itemIndex, item }` | 逐个揭示物品 |
| `S_TIMER_SYNC` | `{ timer }` | 倒计时周期同步 |
| `S_MONEY_UPDATE` | `{ playerIdx, money }` | 资金变动 |
| `S_SKILL_USED` | `{ playerIdx, skillInfo, resultData }` | 技能使用结果 |

#### 结算阶段

| 事件 | 数据 | 说明 |
|------|------|------|
| `S_GAME_OVER` | 见下方详细结构 | 游戏结束（含每轮赢家获得的物品列表，非直接加钱） |
| `C_RECYCLE_ITEMS` | `{ rarities[] }` | 客户端请求按品质回收物品（见第 13 章） |
| `S_RECYCLE_RESULT` | `{ recycledItems[], totalValue, remainingItems[] }` | 回收结果 |
| `C_LEAVE_SETTLE` | `{}` | 客户端结算完成，请求离开（未回收的物品自动入库） |
| `S_SETTLE_COMPLETE` | `{ storedItems[], autoRecycledItems[], autoRecycledValue }` | 入库 + 自动回收结果 |
| `S_RETURN_LOBBY` | `{}` | 通知客户端可以返回大厅 |

#### 局外系统

| 事件 | 数据 | 说明 |
|------|------|------|
| `S_REDEEM_RESULT` | `{ ok, reward?, error? }` | 兑换码验证结果（见 16.6 节） |

> **入场费校验与扣除**：服务端在 `StartGame()` 时通过 `serverCloud` 查询玩家金币余额。校验条件：`余额 >= entryFee`（若该难度配置了 `minMoney` 门槛，则 `余额 >= entryFee + minMoney`）。校验通过后**立即扣除入场费**（`serverCloud:Set(userId, "player_money", 余额 - entryFee)`），然后才开始第一轮竞拍。这样玩家对局内的可用金币已经是扣费后的金额，出价不会超出可用范围。若余额不足，返回 `S_JOIN_FAILED { reason = "insufficient_funds" }`。详见第 6.4 节 StartGame 步骤 2-3。

#### 断线重连

| 事件 | 数据 | 说明 |
|------|------|------|
| `S_FULL_STATE` | 完整游戏快照 | 断线重连后的状态恢复 |

### 2.3 关键事件数据结构

#### S_GAME_INIT

```lua
{
    mySlot = 2,                -- 当前客户端的玩家槽位（每人不同）
    players = {
        [1] = { idx=1, name="玩家A", isHuman=true, money=49500000,
                characterId="gu_qianhe", characterName="顾千鹤" },
                -- ↑ money 是扣除入场费后的可用金币（50000000 - 500000）
        [2] = { idx=2, name="沈惊鸿", isHuman=false, money=50000000,
                characterId="shen_jinghong", characterName="沈惊鸿" },
                -- ↑ AI 不扣入场费，使用 startingMoney 或同等金额
        -- ...4 个玩家
    },
    warehouse = {
        warehouseTypeId = "grocery",   -- 仓库类型 ID（服务端选择，见第 12 章）
        warehouseName = "杂货仓库",     -- 仓库类型显示名称
        regionId = "region_1",         -- 所属区域
        diffLabel = "困难",             -- 难度显示名称
        entryFee = 500000,             -- 本局入场费（已在开局时扣除，此处仅供 UI 显示）
        expectedValue = 3000000,       -- 仓库期望总价值（供 UI 显示参考）
        itemCount = 22,                -- 仓库内物品总数（由生成算法决定，见第 16.6 章）
                                       -- 客户端不知道具体物品内容，仅知道数量
        grid = { cols=10, rows=12 },   -- 仓库网格尺寸（10列 × N行）
                                       -- 这是被竞拍的仓库的网格布局，不是玩家个人仓库
                                       -- 物品按不同尺寸（1×1 到 5×5）摆放在这个网格中
                                       -- 赢家开箱时按此网格展示物品位置
    },
    config = {
        maxRounds = 5,                 -- 最大竞拍轮数
        sealedBidTimer = 45,           -- 暗标阶段倒计时（秒）
        tiebreakTimer = 30,            -- 实时竞拍倒计时（秒）
    },
}
```

> **关于 `itemCount` 和 `grid`**：这里描述的是**被竞拍的仓库**的属性，不是玩家个人仓库。被竞拍的仓库由服务端 `WarehouseGenerator` 程序化生成（见第 16.6 章），包含若干物品摆放在 10 列 × N 行的网格中。`itemCount` 是生成的物品数量（通常 15-30 个），`grid.rows` 是实际使用的行数（由物品填充算法决定）。客户端在竞拍阶段不知道具体物品内容，仅知道数量和网格尺寸；赢家开箱时物品逐个揭示。

#### S_GAME_OVER

> **核心变更**：赢家不直接获得钱，而是获得物品。玩家可在结算阶段选择回收物品换钱，也可直接离开（未回收物品自动入库，溢出部分自动回收）。详见第 13 章。

```lua
{
    winner = 2,                    -- 总冠军 playerIdx（赢得仓库的玩家）
    players = {
        [1] = {
            moneyBeforeGame = 50000000, -- 入场前原始金币（扣费前）
            entryFee = 500000,          -- 入场费（开局时已扣除，此处仅供展示）
            moneyInGame = 49500000,     -- 对局开始时的可用金币（= moneyBeforeGame - entryFee）
            moneyAfterGame = 49700000,  -- 对局结束时的最终金币
                                        -- 输家: = moneyInGame + bonus
                                        -- 赢家: = moneyInGame - winningBid（物品需回收才变钱）
            roundsWon = { 3 },          -- 赢得的回合号列表
            itemsWon = {                -- 赢得的物品列表（非直接加钱！需回收才变钱）
                -- 物品结构与 Config.lua 中一致，使用 baseValue 作为物品固定价值
                { name = "古董花瓶", rarity = 4, baseValue = 500000, w = 2, h = 2, category = "antique" },
                -- ...
            },
            winningBid = 0,             -- 赢家在胜出轮的出价金额（输家为 0）
            bonus = 200000,             -- 安慰奖（仅输家，赢家 overpay 时输家获得 abs(profit)/10）
        },
        [2] = { ... },
        -- ...
    },
    warehouseTotalValue = 5800000,  -- 仓库实际总价值
    gameDuration = 180,             -- 对局时长（秒）
    settleTimeout = 60,             -- 结算阶段超时（秒），超时后服务端自动入库
}
```

> 收到 `S_GAME_OVER` 后客户端进入**结算阶段**（SETTLING），可发送 `C_RECYCLE_ITEMS` 和 `C_LEAVE_SETTLE`。

---

## 3. Client.lua 设计

### 3.1 职责

- 连接管理（监听 `ServerReady` 事件）
- **加载闸门**：等待 `lobby` + `clientCloud` 就绪后再初始化数据和 UI
- 订阅所有 `S_*` 远程事件，解包数据后更新 `ClientGameState`
- 提供 `Send*` 系列方法供 UI 调用
- 管理匹配等待 UI

### 3.2 生命周期

```
Client.Start()
  │
  ├─ CreateMinimalScene()           创建网络必需的空场景
  ├─ SubscribeToEvent("ServerReady", HandleServerReady)
  ├─ SubscribeToEvent("Update", HandleUpdate)
  ├─ 注册所有 S_* 远程事件处理函数
  │
  ▼
加载闸门（HandleUpdate 每帧检查）
  │
  ├─ 检查 lobby ~= nil AND clientCloud ~= nil
  │   ├─ 未就绪 → 显示/更新 "连接服务器..." 等待画面
  │   └─ 超时 30 秒 → 显示错误 + 重试按钮
  │
  ├─ 就绪后执行一次性初始化：
  │   ├─ SaveSystem.Init()              读取云存档（clientCloud 读取，键名不变）
  │   ├─ MoneyHUD.LoadFromCloud()       读取金币（serverCloud 写入后 clientCloud 自动可见）
  │   ├─ userId = GetMyUserId()         获取用户信息
  │   ├─ nickname = GetUserNickname(userId)
  │   ├─ ClientGameState.SetMyUserId(userId)
  │   └─ GameController.ShowMenu()      进入主菜单
  │
  ▼
主菜单阶段（用户操作）
  │
  ├─ 用户选择区域/角色/难度 → 点击开始
  │   └─ Client.SendJoinRoom(regionId, diffIdx, charIdx)
  │       └─ 发送 C_JOIN_ROOM → 显示匹配等待 UI
  │       注：仓库类型不由客户端选择，服务端根据区域配置决定（见第 12 章）
  │
  ▼
匹配等待阶段
  │
  ├─ 收到 S_JOIN_RESULT
  │   ├─ ok=true  → 进入房间等待
  │   └─ ok=false → 显示错误信息（S_JOIN_FAILED）
  │
  ├─ 收到 S_ROOM_STATUS → 更新等待 UI（当前人数/倒计时）
  │
  ├─ 收到 S_GAME_INIT → 初始化游戏
  │   ├─ ClientGameState.HandleGameInit(data)
  │   └─ GameController.StartGameNetwork(ClientGameState)
  │
  ▼
对局阶段
  │
  ├─ 收到各 S_* 事件 → 更新 ClientGameState → UI 自动响应
  ├─ 用户操作 → Client.SendSealedBid() / SendTiebreakBid() / SendUseSkill()
  │
  ├─ 收到 S_GAME_OVER
  │   ├─ ClientGameState.HandleGameOver(data)
  │   ├─ GameController 显示结算 UI（物品列表 + 回收面板）
  │   └─ 不执行任何 clientCloud 写入（服务端已处理）
  │
  ▼
结算阶段（SETTLING）
  │
  ├─ 赢家可操作：选择品质 → 发送 C_RECYCLE_ITEMS { rarities }
  │   └─ 收到 S_RECYCLE_RESULT → 更新回收结果 UI
  │
  ├─ 点击"回家" → 发送 C_LEAVE_SETTLE
  │   └─ 收到 S_SETTLE_COMPLETE → 显示入库结果（放入仓库 + 溢出自动回收）
  │
  ├─ 超时（60秒）→ 服务端自动执行入库 + 全部物品存储
  │
  ▼
返回大厅
  │
  ├─ MoneyHUD.LoadFromCloud()    重新读取最新金币（serverCloud 写入后 clientCloud 自动可见）
  ├─ SaveSystem.Reload()         重新加载物品数据（新物品已入库）
  └─ GameController.ShowMenu()
```

### 3.3 事件处理函数映射

```lua
-- 匹配
HandleJoinResult(data)          → 处理加入结果
HandleRoomStatus(data)          → 更新匹配等待 UI
HandleJoinFailed(data)          → 显示失败原因

-- 游戏初始化
HandleGameInit(data)            → ClientGameState.HandleGameInit(data)
                                → GameController.StartGameNetwork(cgs)

-- 竞拍循环
HandlePhaseChange(data)         → ClientGameState.SetPhase(data.phase) 等
HandleInfoRevealed(data)        → ClientGameState 更新 + CenterPanel 播放动画
HandleBidStart(data)            → ClientGameState.SetPhase(SEALED_BID) + BidControlPanel
HandleAIBidConfirmed(data)      → ClientGameState.SetBidLocked(idx, true)
HandlePlayerBidConfirmed(data)  → 同上
HandleBidFinalized(data)        → ClientGameState.SetRevealInfo(order, 0)
HandleBidRevealed(data)         → ClientGameState 更新 + PlayerListPanel 动画
HandleJudgeResult(data)         → ClientGameState.SetJudgeResult(result)
HandleTiebreakStart(data)       → ClientGameState.SetTiebreakInfo(...)
HandleBidPlaced(data)           → ClientGameState.SetCurrentBid/Bidder(...)
HandleWarehouseOpen(data)       → ClientGameState 更新 + LootPanel 开始
HandleItemRevealed(data)        → ClientGameState 更新 + LootPanel 显示物品
HandleTimerSync(data)           → ClientGameState.SetTimer(data.timer)
HandleMoneyUpdate(data)         → ClientGameState.SetPlayerMoney(idx, money)
HandleSkillUsed(data)           → ClientGameState 更新 + InfoFeed 显示

-- 结算
HandleGameOver(data)            → ClientGameState.HandleGameOver(data)
                                → GameOverDialog.Show(data)  -- 显示物品 + 回收面板
HandleRecycleResult(data)       → 更新回收结果 UI（回收的物品 + 获得金额）
HandleSettleComplete(data)      → 显示入库结果（存入仓库 + 自动回收溢出部分）

-- 断线重连
HandleFullState(data)           → ClientGameState.RestoreFromSnapshot(data)
```

### 3.4 发送方法

```lua
Client.SendJoinRoom(regionId, diffIdx, charIdx)   -- 不含 warehouseTypeId
Client.SendLeaveRoom()
Client.SendSealedBid(amount, useSkill)
Client.SendTiebreakBid(amount)
Client.SendUseSkill()
Client.SendSkipWarehouse()
Client.SendRecycleItems(rarities)                  -- 结算阶段：请求按品质回收
Client.SendLeaveSettle()                           -- 结算阶段：完成回收，请求离开
Client.SendRequestState()
```

### 3.5 存档系统说明

> **无需迁移**：`serverCloud` 和 `clientCloud` 共享同一个 userId 的数据空间，键名完全相同。

| 写入方 | 读取方 | 键名 | 说明 |
|--------|--------|------|------|
| 服务端（`serverCloud`） | 客户端（`clientCloud`） | `player_money` | 金币余额 |
| 服务端（`serverCloud`） | 客户端（`clientCloud`） | `money_rank` | 排行榜分数（iscores） |
| 服务端（`serverCloud`） | 客户端（`clientCloud`） | `save_head`, `save_core`, `save_items`, `save_stats` | 物品/统计存档 |
| 客户端（`clientCloud`） | 客户端（`clientCloud`） | 设置/兑换码等 | 非竞争性数据，客户端直接读写 |

- `SaveSystem.lua` 的键名（`save_head`、`save_core`、`save_items`、`save_stats`）和压缩格式（短键：`n`=name、`r`=rarity、`v`=baseValue 等）保持不变
- 服务端写入时使用相同格式，客户端 `SaveSystem.Init()` 直接读取即可
- 分块机制（`CHUNK_SIZE = 8000`）也保持一致：`items_head` + `items_1` ~ `items_N`

---

## 4. Server.lua 设计

### 4.1 职责

- 连接/断线事件管理
- userId ↔ connection 映射维护
- 将所有 `C_*` 事件路由到对应的 `RoomManager` / `RoomInstance`
- 不包含任何游戏逻辑

### 4.2 生命周期

```
Server.Start()
  │
  ├─ CreateMinimalScene()
  ├─ Shared.RegisterEvents()
  ├─ SubscribeToEvent("ClientConnected", HandleConnect)
  ├─ SubscribeToEvent("ClientDisconnected", HandleDisconnect)
  ├─ 注册所有 C_* 事件路由
  ├─ RoomManager.Init()
  └─ SubscribeToEvent("Update", HandleUpdate)

HandleConnect(conn)
  ├─ 获取 userId（GetUserIdByConnection）
  ├─ 异步获取 nickname
  └─ 存入 connections[userId] = { conn, userId, nickname, roomId }

HandleDisconnect(conn)
  ├─ 查找 userId
  ├─ 通知 RoomManager.HandleDisconnect(userId)
  └─ 清除 connections[userId]

HandleUpdate(dt)
  └─ RoomManager.Update(dt)

-- 事件路由（所有 C_* 事件统一模式）
HandleJoinRoom(conn, eventData)
  ├─ data = Shared.UnpackEvent(eventData)
  ├─ userId = GetUserIdByConnection(conn)
  └─ RoomManager.JoinRoom(userId, conn, data)

HandleSealedBid(conn, eventData)
  ├─ data = Shared.UnpackEvent(eventData)
  ├─ userId = GetUserIdByConnection(conn)
  ├─ room = RoomManager.GetRoomByPlayer(userId)
  └─ room:HandleSealedBid(userId, data)

-- 其他 C_* 事件同理...
```

### 4.3 连接数据结构

```lua
connections = {
    [userId] = {
        conn = <Connection>,
        userId = 123456,
        nickname = "玩家A",
        roomId = nil,        -- 当前所在房间 ID（nil = 未在房间）
    }
}
```

---

## 5. RoomManager.lua 设计

### 5.1 职责

- 房间创建、查找、分配、回收
- 匹配逻辑（基于 matchKey 查找或创建房间）
- 玩家 ↔ 房间映射
- 对外暴露操作路由接口

### 5.2 匹配策略

```lua
matchKey = regionId .. "_" .. diffIdx
```

> **为什么不含 warehouseTypeId**：仓库类型由服务端在 `StartGame()` 时根据区域配置决定（有的区域固定、有的随机），不参与匹配分组。同一区域 + 同一难度的玩家匹配到同一房间。

匹配流程：
```
JoinRoom(userId, conn, data)
  │
  ├─ 校验: 该玩家是否已在某个房间 → 是则拒绝
  │
  ├─ 生成 matchKey = data.regionId .. "_" .. data.diffIdx
  │
  ├─ 查找状态为 WAITING 的房间（matchKey 匹配 + 未满）
  │   ├─ 找到 → room:AddPlayer(userId, conn, data.charIdx)
  │   └─ 未找到 → 创建新房间
  │       └─ room = RoomInstance.New(matchKey, data.regionId, data.diffIdx)
  │       └─ room:AddPlayer(userId, conn, data.charIdx)
  │
  ├─ 发送 S_JOIN_RESULT { ok=true, roomId }
  ├─ 广播 S_ROOM_STATUS 给房间内所有人
  │
  └─ 检查是否满员 → 是则 room:StartGame()
```

### 5.3 数据结构

```lua
rooms = {
    [roomId] = <RoomInstance>,
}

playerToRoom = {
    [userId] = roomId,
}

-- 匹配索引：快速查找同 matchKey 的等待中房间
matchIndex = {
    [matchKey] = { roomId1, roomId2, ... },
}
```

### 5.4 房间回收

```lua
RoomManager.Update(dt)
  ├─ 遍历所有房间
  │   ├─ room.state == PLAYING → room:Update(dt)
  │   ├─ room.state == WAITING → 检查等待超时
  │   │   └─ 超时（首人加入后 15 秒）且人数 > 0 → room:StartGame()（AI 补位）
  │   └─ room.state == FINISHED → 检查是否所有人已离开
  │       └─ 是 → 销毁房间，清理映射
```

### 5.5 公开接口

```lua
RoomManager.Init()
RoomManager.Update(dt)
RoomManager.JoinRoom(userId, conn, data)     -- data = { regionId, diffIdx, charIdx }
RoomManager.LeaveRoom(userId)
RoomManager.HandleDisconnect(userId)
RoomManager.GetRoomByPlayer(userId) → RoomInstance|nil
RoomManager.RouteAction(userId, action, data) -- 通用路由
```

---

## 6. RoomInstance.lua 设计

这是最核心的重写模块，负责一局游戏的完整生命周期。

### 6.1 职责

- 玩家管理（加入/离开/断线/角色分配）
- 模块隔离（创建独立的 GameState / AuctionEngine / AIPlayer 等副本）
- 游戏驱动（每帧调用隔离的 AuctionEngine.Update）
- 事件广播（将游戏状态变更发送给所有真人玩家）
- 结算持久化（通过 serverCloud 写入金币/物品/排行榜）
- 状态快照（断线重连）

### 6.2 房间状态

```
WAITING → PLAYING → SETTLING → FINISHED
```

- `WAITING`：等待玩家加入（最多 15 秒或满员）
- `PLAYING`：游戏进行中
- `SETTLING`：游戏结束，正在写入 serverCloud（异步）
- `FINISHED`：结算完成，等待所有人离开后回收

### 6.3 玩家数据结构

```lua
self.players = {
    [slot] = {                  -- slot = 1~4
        userId = 123456,        -- nil = AI
        conn = <Connection>,    -- nil = AI 或已断线
        nickname = "玩家A",
        charIdx = 3,            -- 玩家选择的角色索引
        isHuman = true,
        connected = true,       -- false = 断线但保留槽位
    }
}
```

### 6.4 生命周期

```
RoomInstance.New(matchKey, regionId, diffIdx)
  │
  ├─ 存储匹配参数（仓库类型在 StartGame 时由服务端根据区域配置决定）
  ├─ self.state = WAITING
  ├─ self.players = {}
  └─ self.waitTimer = 15.0

AddPlayer(userId, conn, charIdx)
  │
  ├─ 分配槽位（1~4，优先使用玩家选择的角色，冲突先到先得）
  ├─ 存入 self.players[slot]
  ├─ 发送 S_JOIN_RESULT 给该玩家
  └─ 广播 S_ROOM_STATUS 给所有人

StartGame()
  │
  ├─ 1. 仓库类型决定（见第 12 章）
  │   ├─ 读取 Config.REGIONS[regionId].warehouseTypes
  │   ├─ 单个类型 → 直接使用
  │   └─ 多个类型 → math.random 选一个
  │
  ├─ 2. 角色分配
  │   ├─ 真人玩家直接使用他们选择的 charIdx（**允许重复**，多个玩家可选同一角色）
  │   └─ AI 玩家：从所有角色中随机分配（也允许与真人重复）
  │
  ├─ 3. 入场费校验与扣除（serverCloud 查询每个真人玩家的金币）
  │   ├─ 校验条件：余额 >= entryFee（若有 minMoney 门槛则 余额 >= entryFee + minMoney）
  │   ├─ 不足者：发送 S_JOIN_FAILED → 移出房间 → AI 补位
  │   └─ 通过者：立即扣除入场费（serverCloud 写入 余额 - entryFee）
  │       此后对局内 money = 扣费后的金额，玩家只能用此金额出价
  │
  ├─ 4. 模块隔离（见第 7 章）
  │
  ├─ 5. 构建 playersConfig
  │   └─ 4 个玩家位置：真人使用选择的角色，空位由 AI 填充
  │
  ├─ 6. 初始化隔离模块
  │   ├─ self.gs.Init(playersConfig)           -- 服务端模式
  │   ├─ self.warehouseGen.Generate(warehouseTypeId, ...)
  │   ├─ self.revealPlanner.Build(...)
  │   ├─ self.auctionEngine.Init(...)
  │   ├─ self.auctionEngine.SetHeadless(true)
  │   └─ 注册 AuctionEngine 回调 → 广播对应事件
  │
  ├─ 7. 向每个真人玩家发送 S_GAME_INIT（各自的 mySlot 不同）
  │     players[].money = 扣费后的可用金币
  │
  └─ 8. self.state = PLAYING

Update(dt)        -- 仅在 PLAYING 状态下调用
  │
  ├─ self.auctionEngine.Update(dt)     -- 驱动竞拍状态机
  └─ 周期性 S_TIMER_SYNC 广播（每 2 秒）

HandleSealedBid(userId, data)
  │
  ├─ 查找 userId → slot
  ├─ self.gs.PlaceSealedBid(slot, data.amount)
  ├─ 处理技能使用（data.useSkill）
  ├─ 广播 S_PLAYER_BID_CONFIRMED { playerIdx = slot }
  └─ 压缩 AI 思考时间（AIPlayer.OnPlayerBidConfirmed）

HandleTiebreakBid(userId, data)
  │
  ├─ 查找 userId → slot
  ├─ self.gs.PlaceTiebreakBid(slot, data.amount)
  └─ 广播 S_BID_PLACED { playerIdx = slot, amount = data.amount }

HandleUseSkill(userId)
  │
  ├─ 查找 userId → slot
  ├─ self.gs.UseActiveSkill(slot)
  ├─ 执行技能效果（如 reveal_top3）
  └─ 广播 S_SKILL_USED / 私发 S_PRIVATE_INFO

HandleGameOver()        -- AuctionEngine 回调触发
  │
  ├─ self.state = SETTLING
  ├─ self.settleTimer = 60.0      -- 结算超时倒计时
  │
  ├─ 计算每人结算数据（金币变动、物品列表、安慰奖等）
  │   └─ 安慰奖 = CalcBonus(entryFee, round)
  │
  ├─ serverCloud 写入金币（不含物品，物品等结算完成后写入）
  │   ├─ 遍历每个真人玩家
  │   └─ serverCloud:Set(userId, "player_money", moneyAfterGame)
  │
  ├─ 广播 S_GAME_OVER（包含 itemsWon 列表，见 2.3 节）
  │
  ├─ 等待客户端回收操作（C_RECYCLE_ITEMS / C_LEAVE_SETTLE）
  └─ 超时后自动执行 AutoSettleForPlayer()（见第 13 章）

HandleRecycleItems(userId, data)    -- 客户端请求回收
  │
  ├─ 查找 userId → slot → pendingItems[slot]
  ├─ recycleManager.FilterByRarity(pendingItems, data.rarities)
  ├─ 计算回收金额 → 更新 moneyAfterGame
  ├─ 更新 pendingItems（移除已回收的）
  └─ 发送 S_RECYCLE_RESULT 给该玩家

HandleLeaveSettle(userId)           -- 客户端完成回收，请求离开
  │
  ├─ 对 pendingItems 执行 AutoRecycleForFit（入库 + 溢出自动回收）
  ├─ serverCloud 写入最终金币 + 物品存档
  ├─ 发送 S_SETTLE_COMPLETE 给该玩家
  └─ 标记该玩家结算完成 → 全部完成后 self.state = FINISHED

AutoSettleForPlayer(slot)           -- 超时/断线时自动结算
  │
  ├─ 对所有 pendingItems 直接执行 AutoRecycleForFit
  ├─ serverCloud 写入最终金币 + 物品存档
  └─ 标记该玩家结算完成

RemovePlayer(userId)
  │
  ├─ 清除 self.players[slot]
  └─ 如果 FINISHED 且所有人已离开 → 标记可回收

MarkDisconnected(userId)
  │
  ├─ self.players[slot].connected = false
  ├─ self.players[slot].conn = nil
  └─ 如果 WAITING → 移除玩家；如果 PLAYING → 保留槽位等重连
```

### 6.5 AuctionEngine 回调注册

```lua
-- RoomInstance:StartGame() 中注册隔离 AuctionEngine 的回调

self.auctionEngine.SetOnInfoRevealed(function(round, publicInfos, skillInfos)
    self:BroadcastAll("S_INFO_REVEALED", { round = round, items = publicInfos })
    -- 私发技能信息给对应玩家
    for playerIdx, info in pairs(skillInfos or {}) do
        self:SendToSlot(playerIdx, "S_PRIVATE_INFO", { skillInfo = info })
    end
end)

self.auctionEngine.SetOnAISealedBidConfirmed(function(playerIdx)
    self:BroadcastAll("S_AI_BID_CONFIRMED", { playerIdx = playerIdx })
end)

self.auctionEngine.SetOnBidRevealed(function(revealIndex, playerIdx, amount)
    self:BroadcastAll("S_BID_REVEALED", { revealIndex = revealIndex, playerIdx = playerIdx, amount = amount })
end)

self.auctionEngine.SetOnJudgeResult(function(result)
    self:BroadcastAll("S_JUDGE_RESULT", { result = result })
    -- 金额变动同步
    for idx, player in ipairs(self.gs.GetPlayers()) do
        self:BroadcastAll("S_MONEY_UPDATE", { playerIdx = idx, money = player.money })
    end
end)

self.auctionEngine.SetOnTiebreakStart(function(tiebreakPlayers)
    self:BroadcastAll("S_TIEBREAK_START", {
        players = tiebreakPlayers,
        startBid = self.gs.GetCurrentBid(),
        timer = Config.GAME.TiebreakTimer,
    })
end)

self.auctionEngine.SetOnBidPlaced(function(playerIdx, amount)
    self:BroadcastAll("S_BID_PLACED", { playerIdx = playerIdx, amount = amount })
end)

self.auctionEngine.SetOnWarehouseOpen(function()
    self:BroadcastAll("S_WAREHOUSE_OPEN", {
        winner = self.gs.GetWinner(),
        winnerPaid = self.gs.GetWinnerPaid(),
    })
end)

self.auctionEngine.SetOnItemRevealed(function(itemIndex, item)
    self:BroadcastAll("S_ITEM_REVEALED", {
        itemIndex = itemIndex,
        item = SerializeItem(item),   -- 序列化物品（含名称/品质/估值）
    })
end)

self.auctionEngine.SetOnGameOver(function()
    self:HandleGameOver()
end)
```

### 6.6 广播工具方法

```lua
function RoomInstance:BroadcastAll(eventName, data)
    local vm = Shared.PackEvent(data)
    for _, p in pairs(self.players) do
        if p.isHuman and p.connected and p.conn then
            p.conn:SendRemoteEvent(eventName, true, vm)
        end
    end
end

function RoomInstance:SendToSlot(slot, eventName, data)
    local p = self.players[slot]
    if p and p.isHuman and p.connected and p.conn then
        local vm = Shared.PackEvent(data)
        p.conn:SendRemoteEvent(eventName, true, vm)
    end
end

function RoomInstance:SendToUserId(userId, eventName, data)
    for _, p in pairs(self.players) do
        if p.userId == userId and p.connected and p.conn then
            local vm = Shared.PackEvent(data)
            p.conn:SendRemoteEvent(eventName, true, vm)
            return
        end
    end
end
```

---

## 7. 模块隔离策略

### 7.1 问题回顾

多房间并行时，如果所有房间共享同一个 `GameState` 模块实例，状态会互相覆盖。

### 7.2 隔离列表

需要隔离的模块（每房间一个独立副本）：

```lua
ISOLATED_MODULES = {
    -- 核心状态
    "GameState",
    "AuctionEngine",
    "AIPlayer",

    -- 游戏系统
    "SkillSystem",
    "MoneyManager",
    "InfoSystem",
    "WarehouseGenerator",
    "RevealPlanner",
    "EstimateValue",
    "RecycleManager",
    "AntiCheat",

    -- AI 子模块（新增！旧版遗漏）
    "AI.Strategies",
    "AI.InfoEstimation",
}
```

### 7.3 隔离方式：依赖注入（推荐）

旧版通过 `package.loaded` 操作实现隔离，但 `AI.Strategies` 等模块在文件顶部 `require("GameState")` 缓存了原始引用，导致隔离失效。

**新方案：依赖注入**

核心思路：不再依赖 `package.loaded` 操作来"欺骗" require，而是在模块初始化时显式注入依赖。

**需要改造的模块**（删除顶部 require，改为注入）：

#### AI/Strategies.lua

```lua
-- 旧版（问题）：
local GameState = require("GameState")
local InfoSystem = require("InfoSystem")
local EstimateValue = require("EstimateValue")

-- 新版（注入）：
local gs       -- 由 Init 注入
local infoSys  -- 由 Init 注入
local estValue -- 由 Init 注入

function Strategies.Init(gameState, infoSystem, estimateValue)
    gs = gameState
    infoSys = infoSystem
    estValue = estimateValue
end

-- 所有原来调用 GameState.XXX() 的地方改为 gs.XXX()
-- 所有原来调用 InfoSystem.XXX() 的地方改为 infoSys.XXX()
-- 所有原来调用 EstimateValue.XXX() 的地方改为 estValue.XXX()
```

#### EstimateValue.lua

```lua
-- 旧版：
local GameState = require("GameState")

-- 新版：
local gs

function EstimateValue.Init(gameState)
    gs = gameState
end

-- 所有 GameState.GetWarehouseItems() 改为 gs.GetWarehouseItems()
```

#### AI/InfoEstimation.lua

```lua
-- 新版：
local estValue

function InfoEstimation.Init(estimateValue)
    estValue = estimateValue
end

-- 所有 EstimateValue.XXX() 改为 estValue.XXX()
```

#### AIPlayer.lua

```lua
-- 旧版：
local GameState = require("GameState")
local Strategies = require("AI.Strategies")
local InfoEstimation = require("AI.InfoEstimation")

-- 新版：
local gs
local strategies
local infoEstimation

function AIPlayer.Init(gameState, strategiesMod, infoEstMod)
    gs = gameState
    strategies = strategiesMod
    infoEstimation = infoEstMod
    -- 初始化内部状态...
end

-- DecideSealedBid 中原来调用 GameState.XXX() 改为 gs.XXX()
-- 原来调用 Strategies.XXX() 改为 strategies.XXX()
```

### 7.4 RoomInstance 中的初始化链

```lua
function RoomInstance:IsolateAndInit(playersConfig)
    -- 1. 通过 package.loaded 操作创建模块副本
    local mods = self:CreateIsolatedModules(ISOLATED_MODULES)

    -- 2. 保存引用
    self.gs = mods["GameState"]
    self.auctionEngine = mods["AuctionEngine"]
    self.aiPlayer = mods["AIPlayer"]
    self.moneyManager = mods["MoneyManager"]
    self.infoSystem = mods["InfoSystem"]
    self.warehouseGen = mods["WarehouseGenerator"]
    self.revealPlanner = mods["RevealPlanner"]
    self.estimateValue = mods["EstimateValue"]
    self.skillSystem = mods["SkillSystem"]
    self.recycleManager = mods["RecycleManager"]
    self.antiCheat = mods["AntiCheat"]
    self.strategies = mods["AI.Strategies"]
    self.infoEstimation = mods["AI.InfoEstimation"]

    -- 3. 依赖注入（关键！）
    self.estimateValue.Init(self.gs)
    self.infoEstimation.Init(self.estimateValue)
    self.strategies.Init(self.gs, self.infoSystem, self.estimateValue)
    self.aiPlayer.Init(self.gs, self.strategies, self.infoEstimation)

    -- 4. 初始化游戏状态
    self.gs.Init(playersConfig)
    self.warehouseGen.Generate(...)
    self.revealPlanner.Build(...)
    self.moneyManager.SetServerMode(true)  -- 使用 serverCloud
    self.auctionEngine.Init(...)
    self.auctionEngine.SetHeadless(true)
end
```

### 7.5 保留 package.loaded 隔离作为底层机制

`package.loaded` 操作仍然用于创建模块副本（让每个房间的 `require("GameState")` 返回不同的表）。依赖注入是在此基础上**额外确保**跨模块引用的正确性。

```lua
function RoomInstance:CreateIsolatedModules(moduleNames)
    local saved = {}
    local mods = {}

    -- 清除缓存
    for _, name in ipairs(moduleNames) do
        saved[name] = package.loaded[name]
        package.loaded[name] = nil
    end

    -- 重新 require（每个模块得到全新副本）
    for _, name in ipairs(moduleNames) do
        mods[name] = require(name)
    end

    -- 恢复原始缓存（不影响其他房间）
    for _, name in ipairs(moduleNames) do
        package.loaded[name] = saved[name]
    end

    return mods
end
```

---

## 8. 数据持久化策略

### 8.1 读写分工

```
┌──────────────────────┬─────────────────┬─────────────────┐
│       数据类型        │    单机模式      │    多人模式      │
├──────────────────────┼─────────────────┼─────────────────┤
│ 金币余额              │ clientCloud Set │ serverCloud Set │
│ 排行榜分数            │ clientCloud Set │ serverCloud Set │
│ 物品存档              │ clientCloud Set │ serverCloud Set │
│ 统计数据              │ clientCloud Set │ serverCloud Set │
│ 入场费扣除            │ 本地（GameState）│ serverCloud Set │
├──────────────────────┼─────────────────┼─────────────────┤
│ 用户设置（音量等）     │ clientCloud Set │ clientCloud Set │
│ 存钱罐领取时间戳       │ clientCloud Set │ clientCloud Set │
│ 存钱罐容量等级         │ clientCloud Set │ clientCloud Set │
│ 版本奖励领取状态       │ clientCloud Set │ clientCloud Set │
│ 兑换码验证与发放       │ clientCloud Set │ serverCloud Set │
│                      │ （旧：用户专属码）│ （新：通用码，服务端验证）│
└──────────────────────┴─────────────────┴─────────────────┘
```

### 8.2 serverCloud 键设计

复用 clientCloud 的键名（两者共享同一数据空间）：

| 键名 | 类型 | 说明 |
|------|------|------|
| `player_money` | values | 金币余额（精确值） |
| `money_rank` | iscores | 排行榜分数（万为单位） |
| `items_head` | values | 物品索引头（版本/chunk数/校验） |
| `items_1` ~ `items_N` | values | 物品数据分块 |
| `items_core` | values | 仓库等级/设置 |
| `stats` | values | 胜负/利润统计 |

### 8.3 服务端结算写入流程

> **结算分两步**：① 游戏结束时写金币（不含物品）；② 玩家结算完成后写物品存档。详见第 13 章。

```lua
-- 步骤 1：游戏结束时立即写入金币（HandleGameOver 中调用）
function RoomInstance:PersistMoney(slot)
    local p = self.players[slot]
    if not p or not p.isHuman or not p.userId then return end
    local r = self.settleData[slot]

    serverCloud:Set(p.userId, "player_money", r.moneyAfterGame)
    serverCloud:Set(p.userId, "stats", cjson.encode(r.stats))

    local rankValue = math.floor(r.moneyAfterGame / 10000)
    serverCloud:SetScore(p.userId, "money_rank", rankValue)
end

-- 步骤 2：结算完成时写入物品存档（HandleLeaveSettle / AutoSettleForPlayer 中调用）
function RoomInstance:PersistItems(slot)
    local p = self.players[slot]
    if not p or not p.isHuman or not p.userId then return end
    local r = self.settleData[slot]

    -- 更新最终金币（可能经过回收增加了）
    serverCloud:Set(p.userId, "player_money", r.finalMoney)
    local rankValue = math.floor(r.finalMoney / 10000)
    serverCloud:SetScore(p.userId, "money_rank", rankValue)

    -- 写入物品存档（包含新入库的物品）
    if r.finalItems and #r.finalItems > 0 then
        local chunks = ChunkItems(r.finalItems)
        serverCloud:Set(p.userId, "items_head", chunks.head)
        for i, chunk in ipairs(chunks.data) do
            serverCloud:Set(p.userId, "items_" .. i, chunk)
        end
    end

    -- 标记该玩家结算完成
    self.settledCount = self.settledCount + 1
    if self.settledCount >= self.humanCount then
        self.state = "FINISHED"
    end
end
```

### 8.4 客户端行为变更

**对局中**：客户端不写任何 `clientCloud` 数据。

**结算阶段**：
- `GameOverDialog` 在网络模式下显示物品列表 + 回收面板
- 玩家选择品质后发送 `C_RECYCLE_ITEMS`，服务端计算后返回 `S_RECYCLE_RESULT`
- 玩家点击"回家"发送 `C_LEAVE_SETTLE`，服务端执行入库 + 溢出回收后返回 `S_SETTLE_COMPLETE`
- 客户端不调用 `SaveSystem` / `MoneyManager` 的写入方法

**返回大厅后**：
- `MoneyHUD.LoadFromCloud()` 重新读取 `clientCloud`（服务端已通过 `serverCloud` 写入，共享数据空间）
- `SaveSystem.Reload()` 重新加载物品存档（新物品已入库）

---

## 9. 现有模块改动

### 9.1 需要改动的模块总表

| 模块 | 改动类型 | 改动内容 |
|------|---------|---------|
| `AI/Strategies.lua` | 依赖注入 | 删除顶部 3 个 require，新增 `Init(gs, infoSys, estValue)`，全部 `GameState.XXX()` → `gs.XXX()` |
| `EstimateValue.lua` | 依赖注入 | 删除顶部 require，新增 `Init(gs)`，`GameState.GetWarehouseItems()` → `gs.GetWarehouseItems()` |
| `AI/InfoEstimation.lua` | 依赖注入 | 新增 `Init(estValue)`，间接调用改为注入引用 |
| `AIPlayer.lua` | 依赖注入 | 改 `Init()` 签名接收 `gs, strategies, infoEstimation`，删除顶部对 GameState/Strategies 的 require |
| `MoneyManager.lua` | 服务端模式 | `SetServerMode(true)` 改为使用 serverCloud 写入（而非跳过） |
| `UI/GameOverDialog.lua` | 网络模式 | `GoHome()` 网络模式下不写 clientCloud，从事件数据显示结算 |
| `UI/InfoFeed.lua` | 硬编码修复 | `CreateInfoCard()` 中 `players[1]` → `players[mySlot]` |
| `UI/LootPanel.lua` | 网络模式 | 网络模式下物品估值从事件数据获取，不调用 EstimateValue |
| `UI/PlayerListPanel.lua` | 动态化 | 根据实际玩家数创建卡片，而非固定 4 个 |
| `UI/DebugPanel.lua` | 限制 | 网络模式下禁用 "+1亿" 等调试功能 |
| `AuctionEngine.lua` | 可选清理 | `PlayerSealedBid`/`PlayerTiebreakBid`/`CanTiebreakBid` 中硬编码的 `1` 改为参数（非必须，网络模式不调用） |

### 9.2 不需要改动的模块

| 模块 | 原因 |
|------|------|
| `GameState.lua` | 双初始化路径已存在，服务端模式可用 |
| `SkillSystem.lua` | 通过参数接收 gs，无硬编码 |
| `InfoSystem.lua` | 无直接 require GameState |
| `WarehouseGenerator.lua` | 纯生成逻辑，无依赖问题 |
| `RevealPlanner.lua` | 同上 |
| `Config.lua` | 静态配置 |
| `Standalone.lua` | 多人模式不加载 |
| `ClientGameState.lua` | 设计正确，可能只需新增 `HandleGameOver` 和 `RestoreFromSnapshot` |
| 所有 UI 的 `SetNetworkMode` | 已实现，保留 |
| `MenuScreen` / `MapScreen` | 纯导航 |
| `MyWarehousePanel` / `LeaderboardPanel` 等 | 局外功能，客户端直接操作 |

---

## 10. 断线重连设计

### 10.1 重连流程

```
客户端断线
  │
  ├─ 服务端: HandleDisconnect(userId)
  │   └─ room 状态为 PLAYING → MarkDisconnected(userId)（保留槽位，AI 不补位）
  │   └─ room 状态为 WAITING → RemovePlayer(userId)（直接移除）
  │
  ▼
客户端重连（新连接建立）
  │
  ├─ ServerReady 事件触发
  │
  ├─ Client.Start() → 加载闸门 → 数据初始化
  │
  ├─ 检查是否有未完成的游戏：
  │   └─ Client.SendRequestState()
  │
  ├─ 服务端收到 C_REQUEST_STATE
  │   ├─ RoomManager.GetRoomByPlayer(userId)
  │   ├─ 有房间 → room:GetSnapshot(userId) → 发送 S_FULL_STATE
  │   └─ 无房间 → 不响应（客户端超时后显示菜单）
  │
  ├─ 客户端收到 S_FULL_STATE
  │   ├─ ClientGameState.RestoreFromSnapshot(data)
  │   └─ GameController.StartGameNetwork(cgs)  // 直接进入游戏
  │
  └─ 客户端超时（3秒）未收到 → 显示主菜单
```

### 10.2 快照数据结构

```lua
{
    mySlot = 2,
    phase = "sealed_bid",
    currentRound = 3,
    timer = 25.5,
    players = { ... },           -- 完整玩家列表（含金额）
    warehouse = { ... },         -- 仓库信息
    sealedBids = { ... },        -- 已提交的出价（已锁定的）
    bidLocked = { ... },         -- 锁定状态
    roundBids = { ... },         -- 历史出价
    judgeResult = nil,           -- 当前判定结果
    tiebreakPlayers = {},        -- 平局参与者
    currentBid = 0,              -- 当前实时竞拍最高出价
    currentBidder = 0,
    revealedItemIndex = 0,       -- 已揭示物品数
    winner = 0,
    activeSkillUses = { ... },
    -- ...其他 ClientGameState 需要的所有字段
}
```

### 10.3 优先级

断线重连是最后实施的功能。先确保基本流程跑通。

---

## 11. 实施顺序

### 阶段一：能进游戏

```
步骤 1  重写 Server.lua         简单的连接管理 + 事件路由
步骤 2  重写 RoomManager.lua    匹配逻辑 + 房间生命周期
步骤 3  重写 RoomInstance.lua   模块隔离 + 游戏驱动（不含结算持久化）
步骤 4  重写 Client.lua         加载闸门 + 事件收发 + 匹配等待
步骤 5  更新 Shared.lua         新增/修改事件常量
```

**验证点**：客户端能成功匹配、进入游戏、看到正确的角色和仓库信息

### 阶段二：能玩完一局

```
步骤 6  改造 AI 依赖注入        Strategies / EstimateValue / InfoEstimation / AIPlayer
步骤 7  注册 AuctionEngine 回调  RoomInstance 中注册所有回调并广播事件
步骤 8  修复 UI 硬编码          InfoFeed / LootPanel / PlayerListPanel / DebugPanel
```

**验证点**：能完成 5 轮竞拍、AI 正常出价、客户端 UI 正确显示

### 阶段三：数据不丢

```
步骤 9  实现服务端结算           RoomInstance.HandleGameOver → serverCloud 写入
步骤 10 改造 MoneyManager       服务端模式使用 serverCloud
步骤 11 改造 GameOverDialog     网络模式不写 clientCloud
步骤 12 客户端返回后刷新数据    MoneyHUD.LoadFromCloud()
```

**验证点**：打完一局后金币、物品、排行榜正确持久化

### 阶段四：断线重连

```
步骤 13 RoomInstance.GetSnapshot()
步骤 14 ClientGameState.RestoreFromSnapshot()
步骤 15 Client 重连流程
```

**验证点**：断线后重连能恢复游戏状态

---

## 12. 仓库类型选择机制

### 12.1 问题背景

不同区域的仓库类型配置不同：
- 有的区域只有一种仓库类型（如 `oldtown` → `grocery`）
- 有的区域有多种仓库类型，需要随机选择（如 `techpark` → `techpark` 或 `datacenter`）

因此仓库类型**不应由客户端选择**，而是由服务端在 `StartGame()` 时根据区域配置决定。

### 12.2 区域配置（来自 Config.lua）

```lua
Config.REGIONS = {
    {
        id = "oldtown",
        warehouseTypes = { "grocery" },       -- 单一类型，固定
        difficulties = {
            { level = "easy",   entryFee = 0,     startingMoney = 800000 },
            { level = "normal", entryFee = 5000,  startingMoney = 800000 },
        },
    },
    {
        id = "techpark",
        warehouseTypes = { "techpark", "datacenter" },  -- 多类型，随机
        difficulties = {
            { level = "hard",      label = "50万场",  entryFee = 25000,  startingMoney = 3000000 },
            { level = "nightmare", label = "200万场", entryFee = 40000,  startingMoney = 10000000 },
        },
    },
    {
        id = "bondedport",
        warehouseTypes = { "bondedport" },    -- 单一类型，固定
        difficulties = {
            { level = "expert",  label = "1000万场", entryFee = 80000,  startingMoney = nil },
            { level = "legend",  label = "5000万场", entryFee = 200000, startingMoney = 50000000 },
        },
    },
}
```

### 12.3 服务端选择逻辑

```lua
-- RoomInstance:StartGame() 步骤 1
function RoomInstance:DecideWarehouseType()
    local region = Config.GetRegionById(self.regionId)
    local types = region.warehouseTypes

    if #types == 1 then
        self.warehouseTypeId = types[1]
    else
        -- 多类型：服务端随机
        self.warehouseTypeId = types[math.random(1, #types)]
    end
end
```

### 12.4 客户端表现

- 客户端 `C_JOIN_ROOM` **不包含** `warehouseTypeId`（见 2.1 节）
- 客户端在收到 `S_GAME_INIT` 后从 `warehouse.warehouseTypeId` 获取服务端选择结果
- 对于多类型区域，客户端可播放"老虎机/转盘"动画展示随机选择过程（纯表现，结果由服务端决定）
- 单一类型区域无需展示随机动画

### 12.5 matchKey 不含仓库类型

```lua
matchKey = regionId .. "_" .. diffIdx
```

同一区域 + 同一难度的玩家匹配到同一房间，仓库类型在开局时统一决定，所有玩家共享同一仓库。

---

## 13. 结算回收流程（详细）

### 13.1 概述

游戏结束后，赢家获得的是**物品**而非直接加钱。玩家需要在结算阶段决定如何处理物品：
1. **回收物品**：按品质筛选，选中的物品变成钱（`realValue` 或 `baseValue`）
2. **回家（入库）**：剩余物品尝试放入仓库网格，放不下的自动回收（从最低品质开始）
3. **超时/断线**：服务端自动执行全部物品入库（AutoRecycleForFit）

### 13.2 房间状态扩展

```
WAITING → PLAYING → SETTLING → FINISHED
                      │
                      ├─ 每个真人玩家有独立的结算状态
                      ├─ settleTimer = 60 秒倒计时
                      └─ 所有真人结算完成 → FINISHED
```

每个玩家的结算状态：

```lua
self.settleData[slot] = {
    moneyAfterGame = 49500000,    -- 对局结束时的金币
    itemsWon = { ... },           -- 赢得的物品（原始列表）
    pendingItems = { ... },       -- 待处理物品（回收后更新）
    recycledMoney = 0,            -- 已回收获得的总金额
    settled = false,              -- 是否已完成结算
}
```

### 13.3 时序图

```
服务端                              客户端（赢家）
  │                                     │
  │──── S_GAME_OVER ────────────────────→│  显示物品列表 + 回收面板
  │     (itemsWon=[...])                 │
  │                                     │
  │                                     │  用户选择品质（如 1星2星）
  │←──── C_RECYCLE_ITEMS ───────────────│  { rarities: [1, 2] }
  │                                     │
  │  RecycleManager.FilterByRarity()     │
  │  计算回收金额                        │
  │  更新 pendingItems                   │
  │                                     │
  │──── S_RECYCLE_RESULT ───────────────→│  显示回收结果
  │     (recycledItems, totalValue,      │  更新剩余物品列表
  │      remainingItems)                 │
  │                                     │
  │                                     │  （可重复回收不同品质）
  │                                     │
  │                                     │  用户点击"回家"
  │←──── C_LEAVE_SETTLE ────────────────│
  │                                     │
  │  AutoRecycleForFit(pendingItems,     │
  │    warehouseGrid)                    │
  │  写入 serverCloud（金币 + 物品）      │
  │                                     │
  │──── S_SETTLE_COMPLETE ──────────────→│  显示入库结果
  │     (storedItems, autoRecycledItems, │  → 返回大厅
  │      autoRecycledValue)              │
  │                                     │

------- 超时/断线场景 -------

服务端                              客户端（断线）
  │                                     ✕
  │  settleTimer 到 0                    │
  │  AutoSettleForPlayer(slot):          │
  │    AutoRecycleForFit(all items)      │
  │    serverCloud 写入金币 + 物品        │
  │    标记 settled = true               │
  │                                     │
  │  （物品不丢失，全部入库/回收）         │
```

### 13.4 关键函数映射（复用现有模块）

| 服务端操作 | 调用的模块 | 说明 |
|-----------|-----------|------|
| 按品质回收 | `RecycleManager.FilterByRarity(items, rarities)` | 返回 `toRecycle, toKeep` |
| 计算回收价值 | `RecycleManager.GetRecycleValue(item)` | 返回 `item.realValue or item.baseValue` |
| 自动入库 | `RecycleManager.AutoRecycleForFit(items, grid, gridInst)` | 返回 `placed, recycled, recycledValue` |
| 品质排序 | `RecycleManager.SortByRarityAsc(items)` | 低品质排前（优先回收） |

> `RecycleManager.lua` 是纯逻辑模块，不依赖 UI，可直接在服务端使用。

### 13.5 输家的结算

输家没有 `itemsWon`，只有安慰奖（`bonus`）。输家的结算流程简化为：
1. 收到 `S_GAME_OVER` → 显示安慰奖面板
2. 点击"回家" → 发送 `C_LEAVE_SETTLE`
3. 服务端直接标记 `settled = true`（无物品需要处理）

### 13.6 断线保护

**核心保证：断线玩家的物品不会丢失。**

| 断线时机 | 服务端处理 |
|---------|-----------|
| PLAYING 阶段断线 | 保留槽位等重连；游戏结束后进入 SETTLING |
| SETTLING 阶段断线 | `AutoSettleForPlayer(slot)`：全部物品执行 AutoRecycleForFit → 入库 + 溢出回收 → serverCloud 写入 |
| 从不在线（匹配后掉线，整局未参与） | 同上，结算时自动处理 |

---

## 14. AI 补位生命周期

### 14.1 概述

AI 玩家完全由服务端管理，客户端不参与 AI 的决策过程。客户端只接收 AI 的行为结果事件。

### 14.2 AI 创建时机

| 场景 | 触发 | AI 数量 |
|------|------|---------|
| 等待超时 | `waitTimer` 到 0 且房间人数 < 4 | 4 - 真人数 |
| 入场费校验失败 | 真人被踢出 | 替补 1 个 |

```lua
-- RoomInstance:StartGame() 中
function RoomInstance:FillAIPlayers()
    local aiCount = 4 - self:GetHumanCount()
    for i = 1, aiCount do
        local slot = self:GetNextEmptySlot()
        local charIdx = self:RandomCharForAI()  -- 随机角色（允许与真人重复）
        local character = Config.CHARACTERS[charIdx]

        self.players[slot] = {
            userId = nil,           -- AI 无 userId
            conn = nil,             -- AI 无连接
            nickname = character.name,
            charIdx = charIdx,
            isHuman = false,
            connected = false,      -- AI 不需要连接
        }
    end
end
```

### 14.3 AI 决策驱动

```
RoomInstance:Update(dt)
  │
  ├─ self.auctionEngine.Update(dt)      -- 驱动竞拍状态机
  │   │
  │   ├─ 进入 SEALED_BID 阶段
  │   │   └─ 启动 AI 思考定时器（随机 2~8 秒）
  │   │
  │   ├─ AI 思考定时器到期
  │   │   └─ AIPlayer.UpdateSealedBid(playerIdx)
  │   │       │
  │   │       ├─ 1. InfoEstimation.EstimateValue()      评估当前物品价值
  │   │       ├─ 2. Strategies.DecideBid(playerIdx)     三层决策
  │   │       │   ├─ Intent 层：基于资金/胜场/性格决定意图
  │   │       │   ├─ Strategy 层：选择出价策略
  │   │       │   └─ Style 层：应用角色风格微调
  │   │       ├─ 3. GameState.PlaceSealedBid(idx, amount)
  │   │       └─ 4. 触发回调 → 广播 S_AI_BID_CONFIRMED
  │   │
  │   ├─ 进入 TIEBREAK 阶段（AI 参与平局竞拍）
  │   │   └─ AIPlayer.UpdateTiebreakBid(playerIdx)
  │   │       ├─ Strategies.DecideTiebreakBid(...)
  │   │       └─ 触发回调 → 广播 S_BID_PLACED
  │   │
  │   └─ 其他阶段（INFO_REVEAL / WAREHOUSE_OPEN 等）
  │       └─ AI 无需操作，AuctionEngine 自动推进
```

### 14.4 依赖注入关系

```
RoomInstance (房间实例)
  │
  ├─ auctionEngine (隔离副本)
  │   └─ 内部调用 aiPlayer
  │
  ├─ aiPlayer (隔离副本)
  │   ├─ gs (注入) ← 隔离的 GameState
  │   ├─ strategies (注入) ← 隔离的 AI/Strategies
  │   └─ infoEstimation (注入) ← 隔离的 AI/InfoEstimation
  │
  ├─ strategies (隔离副本)
  │   ├─ gs (注入) ← 同一份隔离 GameState
  │   ├─ infoSys (注入) ← 隔离的 InfoSystem
  │   └─ estValue (注入) ← 隔离的 EstimateValue
  │
  └─ estimateValue (隔离副本)
      └─ gs (注入) ← 同一份隔离 GameState
```

所有模块引用同一房间的 GameState 副本，确保数据一致性。

### 14.5 AI 结算

AI 不需要持久化数据，结算时直接跳过：
- 不写 serverCloud
- 不执行物品入库
- 结算完成判断只统计真人玩家数

### 14.6 Headless 模式差异

| 特性 | 单机模式（headless=false） | 服务端模式（headless=true） |
|------|--------------------------|---------------------------|
| AI 思考延迟 | 随机 2~8 秒（配合 UI 动画） | 随机 1~3 秒（加快节奏） |
| 信息揭示延迟 | 每条信息 1.5 秒动画 | 固定 0.5 秒 |
| 出价揭示延迟 | 每人 2 秒动画 | 固定 0.5 秒 |
| 开箱延迟 | 每物品 1.5 秒动画 | 固定 0.3 秒 |
| 回调触发 | 仅在动画完成后 | 延迟到期后立即触发 |

---

## 15. 在线人数与自定义房间（扩展预留）

### 15.1 max_players 设置

常驻服模式（persistent world）应支持较多玩家同时在线：

```json
{
    "@runtime": {
        "multiplayer": {
            "enabled": true,
            "max_players": 100,
            "persistent_world": { "enabled": true },
            "background_match": true
        }
    }
}
```

> 注意：`max_players = 100` 是服务器同时在线人数上限，不是一局游戏的人数。每局游戏固定 4 人（含 AI）。

### 15.2 在线人数显示

服务端维护当前在线玩家计数，周期性广播：

```lua
-- 新增事件
S_ONLINE_COUNT = "S_OnlineCount"
```

| 事件 | 数据 | 说明 |
|------|------|------|
| `S_ONLINE_COUNT` | `{ count, inGame }` | `count`=总在线人数，`inGame`=正在对局的人数 |

**服务端逻辑**：
```lua
-- Server.lua 中每 10 秒广播一次
function Server.BroadcastOnlineCount()
    local count = TableLen(connections)
    local inGame = RoomManager.GetPlayingPlayerCount()
    local vm = Shared.PackEvent({ count = count, inGame = inGame })

    for _, c in pairs(connections) do
        c.conn:SendRemoteEvent(S_ONLINE_COUNT, true, vm)
    end
end
```

**客户端显示**：在主菜单 UI 角落显示"在线: 56 | 对局中: 32"。

### 15.3 自定义房间（未来扩展）

当前版本使用自动匹配（`matchKey` 匹配），未来可扩展支持自定义房间：

#### 新增事件

| 事件 | 数据 | 说明 |
|------|------|------|
| `C_CREATE_ROOM` | `{ regionId, diffIdx, password?, maxWait? }` | 创建自定义房间 |
| `S_ROOM_CREATED` | `{ roomId, roomCode }` | 返回房间码（6位数字） |
| `C_JOIN_ROOM_BY_CODE` | `{ roomCode, charIdx }` | 通过房间码加入 |

#### 实现要点

1. **房间码生成**：6位随机数字，存入 `codeToRoom[code] = roomId` 映射
2. **密码保护**：可选，创建时设置密码，加入时校验
3. **等待时间**：房主可设置最长等待时间（默认 60 秒），超时自动开始
4. **兼容现有匹配**：自定义房间不参与自动匹配（不加入 `matchIndex`）

#### 与当前架构的关系

自定义房间的核心变更在 `RoomManager.lua`，其他模块（`RoomInstance`、`AuctionEngine` 等）无需改动：

```lua
-- RoomManager.lua 新增
function RoomManager.CreateRoom(userId, conn, data)
    local roomCode = GenerateRoomCode()
    local room = RoomInstance.New(nil, data.regionId, data.diffIdx)  -- matchKey=nil，不参与自动匹配
    room.roomCode = roomCode
    room.isCustom = true
    codeToRoom[roomCode] = room.roomId
    room:AddPlayer(userId, conn, data.charIdx)
    return roomCode
end

function RoomManager.JoinByCode(userId, conn, data)
    local roomId = codeToRoom[data.roomCode]
    if not roomId then return false, "房间不存在" end
    local room = rooms[roomId]
    if room.state ~= "WAITING" then return false, "游戏已开始" end
    room:AddPlayer(userId, conn, data.charIdx)
    return true
end
```

> **优先级**：自定义房间是后续扩展功能，当前版本先实现自动匹配。

---

## 16. 局外系统 C/S 处理方案

### 16.1 概述

以下系统是**局外系统**，不在对局竞拍过程中运行，而是在大厅/菜单阶段操作。它们的共同特点是：**不涉及竞争性对抗**，因此安全要求与对局内不同。

| 系统 | 涉及金币变动 | 涉及物品变动 | 防作弊等级 | 处理端 |
|------|-------------|-------------|-----------|--------|
| 仓库管理（查看/整理/出售/升级） | 出售→加钱；升级→扣钱 | 删除/移动物品 | 中 | 客户端 |
| 存钱罐 | 领取→加钱 | 无 | 低（幂等） | 客户端 |
| 版本更新奖励 | 领取→加钱 | 无 | 低（幂等） | 客户端 |
| 兑换码 | 兑换→加钱/加物品 | 可能加物品 | **高（必须服务端）** | **服务端** |

### 16.2 处理端选择原则

```
┌──────────────────────────────────────────────────────────────┐
│                     局外系统处理策略                           │
│                                                              │
│  判断标准：该操作是否能被客户端伪造来获得不正当利益？             │
│                                                              │
│  ┌───────────────────┬────────────┬────────────────────────┐ │
│  │   系统             │ 处理端     │ 原因                    │ │
│  ├───────────────────┼────────────┼────────────────────────┤ │
│  │ 仓库/存钱罐/版本奖励│ 客户端     │ 不涉及对抗，幂等，       │ │
│  │                   │ clientCloud│ 篡改不影响公平性          │ │
│  ├───────────────────┼────────────┼────────────────────────┤ │
│  │ 兑换码             │ 服务端     │ 需要全局验证码的有效性    │ │
│  │                   │ serverCloud│ 客户端无法防伪造/防重放   │ │
│  └───────────────────┴────────────┴────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
```

**客户端处理的系统（仓库/存钱罐/版本奖励）为什么安全？**

1. **不涉及竞争对抗**：仓库整理、出售物品、领取奖励都是单人操作，不影响其他玩家
2. **serverCloud 与 clientCloud 共享数据空间**：服务端写入的金币/物品，客户端可以直接读取和修改
3. **减少服务端负载**：局外操作频繁（玩家反复整理仓库），没必要每次都走服务端
4. **对局内的安全由服务端保证**：入场费扣除、竞拍结算等竞争性操作已经由 serverCloud 处理

**兑换码为什么必须服务端处理？**

1. **防伪造**：客户端无法验证码的真伪，用户可以构造任意码
2. **防重放**：通用码需要全局追踪"谁已经用过"，而非单用户本地追踪
3. **限量控制**：如"前 1000 名兑换"需要全局计数器，客户端无法实现
4. **无需更新发码**：码的定义存储在服务端，可随时新增，不依赖客户端版本

**关键保障**：
- 对局开始时，服务端从 serverCloud 读取金币余额做入场费校验（此时读到的是最新值，无论客户端改过什么）
- 对局结算时，服务端覆盖写入最终金币和物品（客户端的局外修改不影响结算结果）

### 16.3 仓库管理系统

#### 16.3.1 功能列表

| 操作 | 说明 | 数据变动 |
|------|------|---------|
| **查看仓库** | 展示网格中的所有物品 | 只读 |
| **移动物品** | 在网格中拖拽物品到新位置 | 修改 `gridX`, `gridY` |
| **出售物品** | 按品质批量出售，或单个出售 | 删除物品 + 加钱 |
| **升级仓库** | 扩展网格行数（3级） | 扣钱 + 修改 `warehouseLevel` |

#### 16.3.2 数据存储

仓库数据通过 `SaveSystem.lua` 存储到 cloud，键名：

| 键名 | 内容 | 说明 |
|------|------|------|
| `items_head` | `{ version, chunkCount, checksum }` | 物品索引头 |
| `items_1` ~ `items_N` | 物品数据分块（每块 ≤ 8KB） | 压缩格式存储 |
| `items_core` | `{ warehouseLevel, gridCols, gridRows }` | 仓库配置 |

每个物品的存储格式（压缩短键）：

```lua
{
    n = "古董花瓶",       -- name
    r = 4,              -- rarity
    w = 2, h = 2,       -- 占用网格尺寸
    v = 500000,          -- baseValue
    c = "antique",       -- category
    t = 1711234567,      -- wonAt（获得时间戳）
    gx = 3, gy = 1,     -- gridX, gridY（网格位置）
}
```

#### 16.3.3 C/S 处理流程

```
┌─────────────────────────────────────────────────────────┐
│  仓库管理（客户端处理，单机/多人模式相同）                   │
│                                                          │
│  查看仓库:                                                │
│    SaveSystem.GetItems() → WarehouseGrid.Load() → 显示 UI │
│                                                          │
│  移动物品:                                                │
│    UI 拖拽 → WarehouseGrid.PlaceAt(item, newX, newY)      │
│    → SaveSystem.Save() → clientCloud 写入                  │
│                                                          │
│  出售物品:                                                │
│    选择物品/按品质批量 → RecycleManager.GetRecycleValue()   │
│    → 确认出售 → WarehouseGrid.Remove(item)                 │
│    → MoneyManager.SecureAddMoney(totalValue)               │
│    → SaveSystem.Save() → clientCloud 写入                  │
│                                                          │
│  升级仓库:                                                │
│    检查升级条件（金币 + 材料）                               │
│    → MoneyManager.SecureAddMoney(-upgradeCost)             │
│    → SaveSystem.SetWarehouseLevel(newLevel)                │
│    → WarehouseGrid.Resize(newRows)                        │
│    → SaveSystem.Save() → clientCloud 写入                  │
└─────────────────────────────────────────────────────────┘
```

#### 16.3.4 对局结算与仓库的交互

对局结束后，赢家获得物品需要入库。这部分在**服务端**处理（见第 13 章），流程：

```
服务端 RoomInstance:HandleLeaveSettle()
  │
  ├─ 读取玩家当前仓库数据（serverCloud 读取 items_head + items_*）
  ├─ 反序列化为物品列表
  ├─ AutoRecycleForFit(newItems, existingItems, gridCapacity)
  │   ├─ 尝试放入新物品
  │   ├─ 放不下的 → 从最低品质开始自动回收
  │   └─ 返回 { placed, recycled, recycledValue }
  ├─ 合并物品列表（existing + placed）
  ├─ 序列化 → serverCloud 写入 items_head + items_*
  └─ 更新金币（加上自动回收所得）→ serverCloud 写入 player_money
```

### 16.4 存钱罐系统

#### 16.4.1 机制说明

存钱罐是一个**随时间累积**的奖励系统：

| 参数 | 值 |
|------|-----|
| 累积速率 | 每小时 10 万金币 |
| 最大累积时长 | 6 小时 |
| 单次最大领取 | 60 万金币（10万 × 6小时） |

玩家离线或在线时，存钱罐按时间自动累积金币。玩家可以随时领取已累积的金币，领取后重新开始计时。

#### 16.4.2 C/S 处理方案

**客户端处理**（单机/多人模式相同）：

```lua
-- 云存储键
"piggy_bank_last_collect"  -- 上次领取的时间戳
"piggy_bank_capacity"      -- 存钱罐容量等级（决定最大累积时长上限）
```

```
存钱罐操作流程（客户端）:

累积计算（打开存钱罐 UI 时）:
  读取 piggy_bank_last_collect → 计算距今经过的秒数
  → elapsedHours = math.min(elapsed / 3600, maxHours)   -- 上限 6 小时
  → accumulated = math.floor(elapsedHours) × 100000     -- 每小时 10 万
  → 显示当前可领取金额

领取存钱罐:
  UI 点击 → 计算 accumulated（同上）
  → MoneyManager.SecureAddMoney(accumulated)
  → clientCloud 设置 piggy_bank_last_collect = os.time()  -- 重置计时
```

**为什么不走服务端**：
- 存钱罐是基于时间的个人奖励，不涉及对局竞争性数据
- 不影响排行榜（排行榜由服务端写入 money_rank）
- 即使玩家篡改存钱罐金额，也不影响对局公平性
- 时间累积上限（6小时 × 10万 = 60万）金额可控，篡改收益极低

### 16.5 版本更新奖励系统

#### 16.5.1 机制说明

每次游戏版本更新后，玩家可以领取一次性奖励（通常是金币）。每个版本的奖励只能领取一次。

#### 16.5.2 C/S 处理方案

**客户端处理**（单机/多人模式相同）：

```lua
-- 云存储键（每个版本独立键）
"ver_reward_1_0_8"     -- v1.0.8 奖励领取状态（true = 已领取）
"ver_reward_1_1_0"     -- v1.1.0 奖励领取状态
-- ...
```

```
版本奖励领取流程（客户端）:

检查未领取奖励:
  游戏启动 → 遍历 Config.VERSION_REWARDS
  → 逐个检查 clientCloud:Get("ver_reward_" .. version)
  → 未领取的显示红点提醒

领取奖励:
  UI 点击领取 → 检查 clientCloud:Get("ver_reward_X") == nil
  → MoneyManager.SecureAddMoney(rewardAmount)
  → clientCloud:Set("ver_reward_X", true)
```

**幂等性保证**：
- 领取前先检查云端标记，已领取则忽略
- `clientCloud:Set("ver_reward_X", true)` 是幂等操作，重复调用无副作用
- 即使网络闪断导致重复请求，也不会重复发放

#### 16.5.3 与现有代码的关系

当前 `VersionRewardPanel.lua` 已实现了完整的版本奖励逻辑，使用 clientCloud 存储领取状态。**多人模式下无需改动**，保持客户端处理即可。

### 16.6 兑换码系统（服务端处理）

#### 16.6.1 现有系统的局限

当前 `RedeemCode.lua` 采用**用户专属码**方案：码中编码了 userId，只能由对应用户使用。

| 问题 | 说明 |
|------|------|
| 无法发通用码 | 码绑定 userId，无法在社交媒体发"所有人可用"的码 |
| 无法限量 | 客户端无全局计数器，无法实现"前 1000 名" |
| 无法不更新发码 | 码的验证逻辑和奖励配置写死在客户端代码中 |
| 客户端可伪造 | 算法在本地，理论上可以逆向生成任意码 |

#### 16.6.2 新方案：服务端验证 + 服务端配置

**核心思路**：码的定义和验证全部放在服务端，客户端只负责输入和展示结果。

```
┌─────────────────────────────────────────────────────────────┐
│                    兑换码处理流程                              │
│                                                              │
│  客户端                          服务端                       │
│  ┌──────┐    C_REDEEM_CODE      ┌──────────────────────┐    │
│  │ 输入码 │ ──────────────────→ │ 1. 查 codeRegistry    │    │
│  │      │    { code }          │    码是否存在？        │    │
│  │      │                      │ 2. 查 serverCloud     │    │
│  │      │                      │    该用户是否已用过？   │    │
│  │      │                      │ 3. 检查使用次数上限     │    │
│  │      │    S_REDEEM_RESULT   │ 4. 发放奖励            │    │
│  │ 显示  │ ←────────────────── │    serverCloud 写入     │    │
│  │ 结果  │    { ok, reward }   │ 5. 标记已使用           │    │
│  └──────┘                      └──────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

#### 16.6.3 事件协议

| 事件 | 方向 | 数据 | 说明 |
|------|------|------|------|
| `C_REDEEM_CODE` | 客户端→服务端 | `{ code }` | 请求兑换 |
| `S_REDEEM_RESULT` | 服务端→客户端 | `{ ok, reward?, error? }` | 兑换结果 |

`S_REDEEM_RESULT` 数据结构：

```lua
-- 成功
{ ok = true, reward = { type = "money", amount = 5000000, desc = "500万金币" } }
{ ok = true, reward = { type = "items", items = { ... }, desc = "稀有物品礼包" } }

-- 失败
{ ok = false, error = "invalid_code" }      -- 码不存在
{ ok = false, error = "already_redeemed" }   -- 已经用过
{ ok = false, error = "code_expired" }       -- 码已过期
{ ok = false, error = "code_depleted" }      -- 码已达使用次数上限
```

#### 16.6.4 码定义存储（如何不更新版本就能发码）

码的定义存储在 **Server.lua 的运行时配置**中。有两种更新方式：

**方式 A：服务端脚本内置（需重新构建部署服务端）**

```lua
-- Server.lua 或 CodeConfig.lua 中
local CODE_REGISTRY = {
    ["SPRING2026"] = {
        reward = { type = "money", amount = 5000000 },
        desc = "春节活动 500万金币",
        maxUses = 10000,        -- 全局最多使用 10000 次（nil = 无限）
        expiresAt = 1743465600, -- 过期时间戳（nil = 永不过期）
    },
    ["VIP888"] = {
        reward = { type = "money", amount = 8880000 },
        desc = "VIP专属 888万金币",
        maxUses = 100,
        expiresAt = nil,
    },
}
```

> 服务端脚本更新**不需要客户端版本更新**。只需重新部署服务端代码，客户端无感知。

**方式 B：serverCloud 动态存储（完全不需要任何部署）**

```lua
-- 使用一个"管理员用户"的 serverCloud 存储码定义
-- 管理员通过特殊客户端命令或工具写入
local ADMIN_USER_ID = "system_code_admin"
local codeJson = serverCloud:Get(ADMIN_USER_ID, "code_registry")
local CODE_REGISTRY = cjson.decode(codeJson or "{}")
```

> 方式 B 更灵活，但需要额外的管理工具来写入码定义。方式 A 足以满足大多数场景。

**推荐**：先用方式 A，需要高频发码时再扩展为方式 B。

#### 16.6.5 服务端验证逻辑

```lua
-- Server.lua 中注册事件
SubscribeRemoteEvent("C_REDEEM_CODE", HandleRedeemCode)

function HandleRedeemCode(conn, eventData)
    local data = Shared.UnpackEvent(eventData)
    local userId = GetUserIdByConnection(conn)
    local code = string.upper(data.code or "")  -- 统一大写

    -- 1. 查码表
    local codeDef = CODE_REGISTRY[code]
    if not codeDef then
        SendToConn(conn, "S_REDEEM_RESULT", { ok = false, error = "invalid_code" })
        return
    end

    -- 2. 检查过期
    if codeDef.expiresAt and os.time() > codeDef.expiresAt then
        SendToConn(conn, "S_REDEEM_RESULT", { ok = false, error = "code_expired" })
        return
    end

    -- 3. 检查该用户是否已用过（per-user key）
    local redeemKey = "redeemed_" .. code
    local alreadyUsed = serverCloud:Get(userId, redeemKey)
    if alreadyUsed then
        SendToConn(conn, "S_REDEEM_RESULT", { ok = false, error = "already_redeemed" })
        return
    end

    -- 4. 检查全局使用次数（用一个系统 key 追踪）
    if codeDef.maxUses then
        local countKey = "code_count_" .. code
        local SYSTEM_ID = "system_code_counter"
        local currentCount = tonumber(serverCloud:Get(SYSTEM_ID, countKey)) or 0
        if currentCount >= codeDef.maxUses then
            SendToConn(conn, "S_REDEEM_RESULT", { ok = false, error = "code_depleted" })
            return
        end
        -- 递增计数（注意：非原子操作，高并发下可能略微超额，可接受）
        serverCloud:Set(SYSTEM_ID, countKey, tostring(currentCount + 1))
    end

    -- 5. 发放奖励
    if codeDef.reward.type == "money" then
        local currentMoney = tonumber(serverCloud:Get(userId, "player_money")) or 0
        serverCloud:Set(userId, "player_money", currentMoney + codeDef.reward.amount)
        -- 同步排行榜
        local rankValue = math.floor((currentMoney + codeDef.reward.amount) / 10000)
        serverCloud:SetScore(userId, "money_rank", rankValue)
    end
    -- 扩展：type == "items" 时写入物品存档...

    -- 6. 标记已使用
    serverCloud:Set(userId, redeemKey, tostring(os.time()))

    -- 7. 返回结果
    SendToConn(conn, "S_REDEEM_RESULT", {
        ok = true,
        reward = { type = codeDef.reward.type, amount = codeDef.reward.amount, desc = codeDef.desc },
    })
end
```

#### 16.6.6 客户端处理

```lua
-- Client.lua 中
function Client.SendRedeemCode(code)
    local vm = Shared.PackEvent({ code = code })
    connection:SendRemoteEvent("C_REDEEM_CODE", true, vm)
end

-- 收到结果
function HandleRedeemResult(eventData)
    local data = Shared.UnpackEvent(eventData)
    if data.ok then
        -- 刷新金币显示（serverCloud 已写入，clientCloud 自动可见）
        MoneyHUD.LoadFromCloud()
        -- 显示成功提示
        UI.Toast("兑换成功: " .. data.reward.desc)
    else
        local errorMsgs = {
            invalid_code = "兑换码无效",
            already_redeemed = "该兑换码已使用过",
            code_expired = "兑换码已过期",
            code_depleted = "兑换码已被领完",
        }
        UI.Toast(errorMsgs[data.error] or "兑换失败")
    end
end
```

#### 16.6.7 单机模式兼容

单机模式下没有服务端，保留旧的用户专属码机制：

```lua
-- RedeemCode.lua 中根据模式分发
function RedeemCode.Redeem(code)
    if IsNetworkMode() then
        -- 多人模式：发给服务端验证
        Client.SendRedeemCode(code)
    else
        -- 单机模式：本地验证（旧逻辑，用户专属码）
        RedeemCode.RedeemLocal(code)
    end
end
```

#### 16.6.8 码的类型总结

| 码类型 | 适用模式 | 生成方式 | 验证方 | 使用限制 |
|--------|---------|---------|--------|---------|
| 用户专属码 | 单机 | 客户端算法（编码 userId） | 客户端 | 每用户 64 个序列号 |
| 通用码 | 多人 | 运营手动配置在服务端 | 服务端 | 每用户一次 + 全局上限 |
| 限时码 | 多人 | 同上 + 设置 expiresAt | 服务端 | 同上 + 过期时间 |

### 16.7 仓库生成（服务端调用）

服务端在 `StartGame()` 时直接调用现有的 `WarehouseGenerator.Generate(warehouseTypeId, diffIdx, regionId)`，算法实现已完成，此处只记录 C/S 信息分发规则。

**调用与返回**：

```lua
-- 服务端调用（已有代码，无需修改）
local result = WarehouseGenerator.Generate(warehouseTypeId, diffIdx, regionId)
-- 返回: { items[], itemCount, grid = { cols, rows }, totalValue }
```

**信息分发（服务端 → 客户端）**：

| 信息 | 服务端持有 | 客户端何时可知 |
|------|-----------|---------------|
| 物品完整列表及位置 | 始终知道 | 不知道（直到开箱） |
| 物品总数 | 始终知道 | `S_GAME_INIT.warehouse.itemCount` |
| 网格尺寸 | 始终知道 | `S_GAME_INIT.warehouse.grid` |
| 单个物品部分属性 | 始终知道 | 竞拍中通过 `S_INFO_REVEALED` 逐步揭示 |
| 物品实际内容 | 始终知道 | 开箱时通过 `S_ITEM_REVEALED` 逐个揭示 |

这种信息差是游戏的核心——竞拍阶段玩家只能通过有限的线索来估算仓库价值并决定出价。

---

## 17. 数据持久化策略（补充）

### 17.1 完整键设计（更新 8.2 节）

| 键名 | 类型 | 写入方 | 说明 |
|------|------|--------|------|
| `player_money` | values | 对局内: serverCloud / 局外: clientCloud | 金币余额 |
| `money_rank` | iscores | serverCloud | 排行榜分数（万为单位） |
| `items_head` | values | 对局内: serverCloud / 局外: clientCloud | 物品索引头 |
| `items_1` ~ `items_N` | values | 对局内: serverCloud / 局外: clientCloud | 物品数据分块 |
| `items_core` | values | 对局内: serverCloud / 局外: clientCloud | 仓库等级/配置 |
| `stats` | values | serverCloud | 胜负/利润统计 |
| `piggy_bank_last_collect` | values | clientCloud | 存钱罐上次领取时间戳 |
| `piggy_bank_capacity` | values | clientCloud | 存钱罐容量等级（决定最大累积时长上限） |
| `ver_reward_*` | values | clientCloud | 版本奖励领取状态 |
| 用户设置 | values | clientCloud | 音量/其他偏好 |
| `redeemed_<CODE>` | values | serverCloud | 用户是否已使用某兑换码（值为使用时间戳） |
| `code_count_<CODE>` | values | serverCloud（系统账号） | 兑换码全局使用次数计数器 |

### 17.2 读写冲突处理

由于仓库物品数据可能被客户端（局外出售/整理）和服务端（对局结算入库）同时操作，需要处理冲突：

**冲突场景**：玩家在大厅整理仓库时，上一局的结算尚未完成。

**解决方案**：时序隔离

```
对局中:
  客户端不操作仓库（仓库 UI 在对局中不可用）

对局结算中（SETTLING）:
  服务端写入新物品 → S_SETTLE_COMPLETE → 客户端收到后刷新数据

返回大厅后:
  SaveSystem.Reload() → 读取最新数据（serverCloud 写入的结果）
  此后客户端可自由操作仓库 → clientCloud 写入
```

**关键约束**：
- 对局中和结算中，客户端**禁止操作仓库**（UI 层面禁用）
- 返回大厅后，客户端先 `Reload()` 获取最新数据，再允许操作
- 这确保了不会出现客户端和服务端同时写入同一个键的情况

### 17.3 数据一致性保证

```
┌────────────────────────────────────────────────────────┐
│                   数据写入时序                           │
│                                                         │
│  大厅阶段:                                               │
│    客户端自由读写 clientCloud（仓库/存钱罐/版本奖励）       │
│          ↓                                              │
│  匹配成功 → 进入对局:                                     │
│    客户端停止写入（仓库 UI 禁用）                           │
│    服务端读取 serverCloud 校验入场费                        │
│          ↓                                              │
│  对局进行中:                                              │
│    服务端独占所有竞争性数据的写入                            │
│          ↓                                              │
│  结算阶段:                                               │
│    服务端写入金币 + 物品 → serverCloud                     │
│    客户端等待 S_SETTLE_COMPLETE                           │
│          ↓                                              │
│  返回大厅:                                               │
│    客户端 Reload() 读取最新数据                            │
│    恢复客户端自由读写                                      │
└────────────────────────────────────────────────────────┘
```

---

*文档版本: v1.4*
*最后更新: 2026-03-25*
*v1.1 变更：补充仓库选择机制、结算回收流程、AI 生命周期、在线人数与自定义房间*
*v1.2 变更：修正 S_GAME_OVER 数据结构（移除 totalSpent/realValue，修正 moneyAfterGame 公式）；补充局外系统（仓库管理/存钱罐/版本奖励）C/S 处理方案；补充数据持久化键设计和冲突处理*
*v1.3 变更：修正入场费扣除时机（开局时立即扣除，而非结算时计算）；修正 S_GAME_INIT 中 money 为扣费后金额；合并 StartGame 步骤 3 和 7 为统一的入场费校验与扣除；补充仓库生成机制（16.7 章）详细说明 itemCount、grid 含义和两阶段生成算法*
*v1.4 变更：兑换码系统改为服务端处理（16.6 章），支持通用码/限时码/限量码，无需客户端版本更新即可发码；更新 8.1 读写分工表；补充兑换码事件协议（C_REDEEM_CODE/S_REDEEM_RESULT）到 2.1/2.2 节；更新 17.1 键设计表补充兑换码相关键；修正 16.7 节子章节编号*
