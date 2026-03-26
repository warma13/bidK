-- ============================================================================
-- network/Client.lua - 客户端网络逻辑
-- 接收服务端事件 → 填充 ClientGameState → 驱动 UI
-- ============================================================================

---@diagnostic disable: undefined-global

local UI = require("urhox-libs/UI")
local Shared = require("network.Shared")
local Config = require("Config")
local ClientGameState = require("network.ClientGameState")
local UIState = require("UI.UIState")
local Utils = require("UI.Utils")
local GameController = require("UI.GameController")
local MoneyHUD = require("UI.MoneyHUD")
local RewardPanel = require("UI.RewardPanel")
local SettingsPanel = require("UI.SettingsPanel")
local VersionRewardPanel = require("UI.VersionRewardPanel")
local DebugPanel = require("UI.DebugPanel")
local SaveSystem = require("SaveSystem")

local Client = {}

-- 内部状态
local scene_ = nil
local serverConnection_ = nil
local serverReady_ = false       -- 服务器连接是否已就绪
local gameInitialized_ = false
local mySlot_ = 1
local pendingGameConfig_ = nil   -- 等待服务器连接时暂存的游戏配置
local matchOverlay_ = nil        -- 匹配等待浮层
local matchTimerLabel_ = nil     -- 匹配计时标签
local matchElapsed_ = 0          -- 匹配已用时间（秒）
local cloudReady_ = false        -- clientCloud 是否已就绪
local cloudRetryTimer_ = 0       -- clientCloud 轮询重试计时器
local cloudRetryCount_ = 0       -- clientCloud 重试次数
local CLOUD_RETRY_INTERVAL = 1.0 -- 每 1 秒检查一次
local CLOUD_MAX_RETRIES = 30     -- 最多重试 30 次（30 秒）

-- ============================================================================
-- 发送事件到服务端
-- ============================================================================

local function SendToServer(eventName, data)
    if not serverConnection_ then
        print("[Client] No server connection!")
        return
    end
    local vm = Shared.PackEvent(data or {})
    serverConnection_:SendRemoteEvent(eventName, true, vm)
end

-- 暴露给 UI 模块调用
function Client.SendSealedBid(amount)
    SendToServer(Shared.EVENTS.C_SEALED_BID, { amount = amount })
end

function Client.SendTiebreakBid(amount)
    SendToServer(Shared.EVENTS.C_TIEBREAK_BID, { amount = amount })
end

function Client.SendUseSkill()
    SendToServer(Shared.EVENTS.C_USE_SKILL, {})
end

function Client.SendSkipWarehouse()
    SendToServer(Shared.EVENTS.C_SKIP_WAREHOUSE, {})
end

--- 发送 C_RECYCLE_ITEMS 请求按品质回收物品
function Client.SendRecycleItems(rarities)
    SendToServer(Shared.EVENTS.C_RECYCLE_ITEMS, { rarities = rarities })
end

--- 发送 C_LEAVE_SETTLE 请求离开结算（未回收物品自动入库）
function Client.SendLeaveSettle()
    SendToServer(Shared.EVENTS.C_LEAVE_SETTLE, {})
end

--- 发送 C_REQUEST_STATE 请求断线重连后完整状态
function Client.SendRequestState()
    SendToServer(Shared.EVENTS.C_REQUEST_STATE, {})
end

--- 发送 C_JOIN_ROOM 请求加入房间
function Client.SendJoinRoom(config)
    SendToServer(Shared.EVENTS.C_JOIN_ROOM, {
        regionId = config.regionId,
        diffIdx = config.diffIdx,
        charIdx = config.charIdx,
    })
end

--- 多人模式开始游戏（由 GameController.StartGame 在网络模式下调用）
--- 显示匹配浮层，等待服务器连接就绪后发送 C_JOIN_ROOM
function Client.StartMultiplayerGame(regionId, charIdx, diffIdx, warehouseTypeId)
    local config = {
        regionId = regionId,
        charIdx = charIdx,
        diffIdx = diffIdx,
        warehouseTypeId = warehouseTypeId,
    }

    if serverConnection_ and serverReady_ then
        -- 已连接，直接发送
        print("[Client] Server already connected, sending C_JOIN_ROOM")
        Client.SendJoinRoom(config)
    else
        -- 尚未连接，暂存配置等待连接
        print("[Client] Server not yet connected, queuing game config...")
        pendingGameConfig_ = config
    end

    -- 显示匹配等待浮层（覆盖在当前菜单之上）
    Client.ShowMatchOverlay()
end

--- 离开当前房间，返回地图
function Client.LeaveRoom()
    SendToServer(Shared.EVENTS.C_LEAVE_ROOM, {})
    Client.HideMatchOverlay()
    gameInitialized_ = false
    GameController.ShowMenu()
end

--- 显示匹配等待浮层
function Client.ShowMatchOverlay()
    if matchOverlay_ then return end

    ---@type table
    local overlay = nil
    overlay = UI.Panel {
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        backgroundColor = { 0, 0, 0, 180 },
        justifyContent = "center", alignItems = "center",
        children = {
            UI.Panel {
                width = 300, minHeight = 140,
                backgroundColor = { 25, 30, 45, 255 },
                flexDirection = "column",
                justifyContent = "center", alignItems = "center",
                paddingVertical = 24, paddingHorizontal = 32,
                gap = 16,
                children = {
                    UI.Label {
                        text = "正在加入房间...",
                        fontSize = 18,
                        fontColor = { 255, 200, 80, 255 },
                        fontWeight = "bold",
                    },
                    UI.ProgressBar {
                        width = 200, height = 4,
                        value = 100, indeterminate = true,
                    },
                    UI.Label {
                        id = "matchTimerLabel",
                        text = "等待其他玩家加入...",
                        fontSize = 14,
                        fontColor = { 200, 205, 220, 255 },
                    },
                    UI.Button {
                        text = "取消",
                        width = 100, height = 34,
                        fontSize = 13,
                        variant = "outline",
                        onClick = function()
                            -- 如果已经加入了房间，通知服务器离开
                            if serverConnection_ and serverReady_ and not pendingGameConfig_ then
                                SendToServer(Shared.EVENTS.C_LEAVE_ROOM, {})
                            end
                            Client.HideMatchOverlay()
                            pendingGameConfig_ = nil
                            GameController.ShowMenu()
                        end,
                    },
                },
            },
        },
    }
    matchOverlay_ = overlay
    matchElapsed_ = 0
    matchTimerLabel_ = overlay:FindById("matchTimerLabel")
    local root = UI.GetRoot()
    if root then
        root:AddChild(overlay)
    else
        UI.SetRoot(overlay)
    end
end

--- 隐藏匹配等待浮层
function Client.HideMatchOverlay()
    if matchOverlay_ then
        matchOverlay_:Remove()
        matchOverlay_ = nil
        matchTimerLabel_ = nil
        matchElapsed_ = 0
    end
end

-- 客户端是否已初始化游戏
function Client.IsGameInitialized()
    return gameInitialized_
end

-- 获取自己的槽位
function Client.GetMySlot()
    return mySlot_
end

-- ============================================================================
-- 重建角色数据（从 characterId 还原完整 character 对象）
-- ============================================================================

local function RebuildCharacterFromId(charId)
    if not charId then return nil end
    for _, ch in ipairs(Config.CHARACTERS) do
        if ch.id == charId then return ch end
    end
    return nil
end

local function RebuildPlayers(serializedPlayers)
    local players = {}
    for idx, sp in ipairs(serializedPlayers) do
        local char = RebuildCharacterFromId(sp.characterId)
        players[idx] = {
            name = sp.name or ("Player" .. idx),
            isHuman = sp.isHuman,
            character = char,
            money = sp.money or 0,
            personality = char and char.personality or nil,
            userId = sp.userId,
        }
    end
    return players
end

-- ============================================================================
-- 服务端事件处理（全局函数供 SubscribeToEvent 使用）
-- ============================================================================

--- 收到槽位分配
function HandleAssignSlot(eventType, eventData)
    local data = Shared.UnpackEvent(eventData)
    mySlot_ = data.slot or 1
    ClientGameState.SetMySlot(mySlot_)
    print("[Client] Assigned slot: " .. mySlot_)
end

--- 收到游戏初始化数据
function HandleGameInit(eventType, eventData)
    local data = Shared.UnpackEvent(eventData)

    -- 重建玩家列表
    local players = RebuildPlayers(data.players or {})
    ClientGameState.SetPlayers(players)
    ClientGameState.SetMySlot(data.mySlot or mySlot_)
    mySlot_ = data.mySlot or mySlot_

    -- 重建仓库物品
    local items = data.warehouseItems or {}
    for i, item in ipairs(items) do
        item.idx = item.idx or i
    end

    ClientGameState.SetWarehouseInfo({
        warehouseName = data.warehouseName or "",
        warehouseItems = items,
        warehouseTotalValue = 0,  -- 客户端不知道总价值直到开箱
        warehouseTypeId = data.warehouseTypeId or "grocery",
        regionId = data.regionId or "",
        diffLabel = data.diffLabel or "",
        entryFee = data.entryFee or 0,
        expectedValue = data.expectedValue or 100000,
    })

    -- 初始化技能状态
    for idx, p in ipairs(players) do
        if p.character and p.character.activeSkill then
            ClientGameState.SetActiveSkillUses(idx, p.character.activeSkill.maxUses or 1)
        else
            ClientGameState.SetActiveSkillUses(idx, 0)
        end
        ClientGameState.SetActiveSkillActivated(idx, false)
        ClientGameState.SetBidBoostStacks(idx, 0)
    end

    -- 设置金币显示（自己的资金）
    local myPlayer = players[mySlot_]
    if myPlayer then
        MoneyHUD.SetMoney(myPlayer.money)
    end

    -- 隐藏匹配等待浮层
    Client.HideMatchOverlay()

    -- 启动游戏 UI
    gameInitialized_ = true
    GameController.StartGameNetwork(ClientGameState, data)

    print("[Client] Game initialized. My slot: " .. mySlot_ .. ", players: " .. #players)
end

--- 收到阶段变更
function HandlePhaseChange(eventType, eventData)
    if not gameInitialized_ then return end
    local data = Shared.UnpackEvent(eventData)
    local phase = data.phase

    ClientGameState.SetCurrentRound(data.round or ClientGameState.GetCurrentRound())
    ClientGameState.SetTimer(data.timer or 0)

    if phase == ClientGameState.PHASE.INFO_REVEAL then
        ClientGameState.ResetBidState()
    elseif phase == ClientGameState.PHASE.SEALED_BID then
        UIState.playerBidConfirmed = false
        UIState.aiBidConfirmed = {}
        UIState.bidInputStr = ""
        UIState.playerBidAmount = 0
        UIState.lastTickSecond = -1
        UIState.bidPanelVisible = true
        if UIState.refs.bidPanel then UIState.refs.bidPanel:SetVisible(true) end
    elseif phase == ClientGameState.PHASE.TIEBREAK_BID then
        UIState.lastTickSecond = -1
        UIState.bidPanelVisible = false
        if UIState.refs.bidPanel then UIState.refs.bidPanel:SetVisible(false) end
    end

    ClientGameState.SetPhase(phase)
end

--- 收到公开信息揭露
function HandleInfoRevealed(eventType, eventData)
    if not gameInitialized_ then return end
    local data = Shared.UnpackEvent(eventData)

    -- 通知 GameController 的信息揭露回调
    if Client._onInfoRevealed then
        Client._onInfoRevealed(data.round, data.publicInfos, nil)
    end
end

--- 收到私密线索（仅自己）
function HandlePrivateInfo(eventType, eventData)
    if not gameInitialized_ then return end
    local data = Shared.UnpackEvent(eventData)

    -- 合成为 skillInfos 格式传给回调
    if Client._onInfoRevealed and data.skillInfo then
        local skillInfos = {}
        skillInfos[mySlot_] = data.skillInfo
        Client._onInfoRevealed(data.round, nil, skillInfos)
    end
end

--- AI 出价确认
function HandleAIBidConfirmed(eventType, eventData)
    if not gameInitialized_ then return end
    local data = Shared.UnpackEvent(eventData)
    local playerIdx = data.playerIdx
    if playerIdx then
        ClientGameState.SetBidLocked(playerIdx, true)
        UIState.aiBidConfirmed[playerIdx] = true
        -- 触发 UI 刷新
        ClientGameState.NotifyChange()
    end
end

--- 出价锁定完成（进入 BID_REVEAL）
function HandleBidFinalized(eventType, eventData)
    if not gameInitialized_ then return end
    local data = Shared.UnpackEvent(eventData)
    if data.revealOrder then
        ClientGameState.SetRevealInfo(data.revealOrder, 0)
    end
end

--- 揭示某玩家出价
function HandleBidRevealed(eventType, eventData)
    if not gameInitialized_ then return end
    local data = Shared.UnpackEvent(eventData)

    local revealIndex = data.revealIndex
    local playerIdx = data.playerIdx
    local amount = data.amount

    ClientGameState.SetRevealIndex(revealIndex)

    -- 更新出价数据
    local bids = ClientGameState.GetSealedBids()
    bids[playerIdx] = amount
    ClientGameState.SetSealedBids(bids)

    -- 记录本轮出价
    local round = ClientGameState.GetCurrentRound()
    ClientGameState.SetRoundBid(round, playerIdx, amount)

    if Client._onBidRevealed then
        Client._onBidRevealed(revealIndex, playerIdx, amount)
    end

    ClientGameState.NotifyChange()
end

--- 判定结果
function HandleJudgeResult(eventType, eventData)
    if not gameInitialized_ then return end
    local data = Shared.UnpackEvent(eventData)
    ClientGameState.SetJudgeResult(data.result)

    if data.result and data.result.passed then
        ClientGameState.SetWinner(data.result.winner, 0)
    end

    if Client._onJudgeResult then
        Client._onJudgeResult(data.result)
    end

    ClientGameState.NotifyChange()
end

--- 竞拍开始
function HandleTiebreakStart(eventType, eventData)
    if not gameInitialized_ then return end
    local data = Shared.UnpackEvent(eventData)
    ClientGameState.SetTiebreakInfo(data.tiebreakPlayers, data.startBid)
    ClientGameState.SetTimer(data.timer or Config.GAME.TiebreakSeconds)

    if Client._onTiebreakStart then
        Client._onTiebreakStart(data.tiebreakPlayers)
    end
end

--- 竞拍出价
function HandleBidPlaced(eventType, eventData)
    if not gameInitialized_ then return end
    local data = Shared.UnpackEvent(eventData)
    ClientGameState.SetCurrentBid(data.amount)
    ClientGameState.SetCurrentBidder(data.playerIdx)
    ClientGameState.AddBidHistory({
        playerIdx = data.playerIdx,
        amount = data.amount,
        time = ClientGameState.GetTimer(),
    })

    -- 重置倒计时（与服务端逻辑一致）
    if ClientGameState.GetTimer() < Config.GAME.TiebreakExtend then
        ClientGameState.SetTimer(Config.GAME.TiebreakExtend)
    end

    if Client._onBidPlaced then
        Client._onBidPlaced(data.playerIdx, data.amount)
    end

    ClientGameState.NotifyChange()
end

--- 开箱开始
function HandleWarehouseOpen(eventType, eventData)
    if not gameInitialized_ then return end
    local data = Shared.UnpackEvent(eventData)
    ClientGameState.SetWinner(data.winner, data.winnerPaid)
    ClientGameState.SetRevealedItemIndex(0)

    if Client._onWarehouseOpen then
        Client._onWarehouseOpen()
    end
end

--- 物品揭示
function HandleItemRevealed(eventType, eventData)
    if not gameInitialized_ then return end
    local data = Shared.UnpackEvent(eventData)
    local itemIndex = data.itemIndex
    local item = data.item

    ClientGameState.SetRevealedItemIndex(itemIndex)

    -- 更新仓库物品数据（可能包含之前未知的 value）
    local items = ClientGameState.GetWarehouseItems()
    if item and item.idx then
        for i, it in ipairs(items) do
            if it.idx == item.idx then
                items[i].value = item.value
                items[i].name = item.name or items[i].name
                break
            end
        end
    end

    if Client._onItemRevealed then
        Client._onItemRevealed(itemIndex, item)
    end
end

--- 游戏结束（含丰富结算数据）
function HandleGameOver(eventType, eventData)
    if not gameInitialized_ then return end
    local data = Shared.UnpackEvent(eventData)

    ClientGameState.SetWinner(data.winner, data.winnerPaid or 0)

    -- 存储完整的 finalPlayers 数据
    if data.players then
        ClientGameState.SetFinalPlayers(data.players)

        -- 更新玩家列表金额
        local players = ClientGameState.GetPlayers()
        for _, fp in ipairs(data.players) do
            if players[fp.idx] then
                players[fp.idx].money = fp.moneyAfterGame or fp.money or players[fp.idx].money
            end
        end

        -- 如果自己是赢家，设置赢得的物品
        local winner = data.winner or 0
        if winner == mySlot_ then
            local myData = data.players[mySlot_]
            if myData and myData.itemsWon then
                ClientGameState.SetMyItemsWon(myData.itemsWon)
            end
        end
    end

    -- 存储每轮结果
    if data.roundResults then
        ClientGameState.SetRoundResults(data.roundResults)
    end

    -- 设置仓库总价值
    if data.warehouseTotalValue then
        local info = {
            warehouseName = ClientGameState.GetWarehouseName(),
            warehouseItems = ClientGameState.GetWarehouseItems(),
            warehouseTotalValue = data.warehouseTotalValue,
            warehouseTypeId = ClientGameState.GetWarehouseTypeId(),
            regionId = "",
            diffLabel = ClientGameState.GetDiffLabel(),
            entryFee = ClientGameState.GetEntryFee(),
            expectedValue = ClientGameState.GetExpectedValue(),
        }
        ClientGameState.SetWarehouseInfo(info)
    end

    -- 进入结算阶段
    ClientGameState.SetSettleTimeout(data.settleTimeout or 60)
    ClientGameState.SetSettling(true)

    print("[Client] Game over. Winner: " .. tostring(data.winner)
        .. ", settleTimeout: " .. tostring(data.settleTimeout))

    if Client._onGameOver then
        Client._onGameOver()
    end

    ClientGameState.NotifyChange()
end

--- 加入房间结果
function HandleJoinResult(eventType, eventData)
    local data = Shared.UnpackEvent(eventData)
    if data.ok then
        print("[Client] Joined room: " .. tostring(data.roomId))
    else
        print("[Client] Join room failed: " .. tostring(data.error))
        Client.HideMatchOverlay()
        if Client._onJoinFailed then
            Client._onJoinFailed(data.error or "未知错误")
        end
    end
end

--- 加入失败（余额不足等）
function HandleJoinFailed(eventType, eventData)
    local data = Shared.UnpackEvent(eventData)
    local reason = data.reason or "加入失败"
    print("[Client] Join failed: " .. reason)
    Client.HideMatchOverlay()
    gameInitialized_ = false

    ---@type table
    local failRoot = nil
    failRoot = UI.Panel {
        width = "100%", height = "100%",
        backgroundColor = { 0, 0, 0, 200 },
        justifyContent = "center", alignItems = "center",
        children = {
            UI.Panel {
                width = 320, minHeight = 140,
                backgroundColor = { 30, 35, 50, 255 },
                flexDirection = "column",
                justifyContent = "center", alignItems = "center",
                paddingVertical = 24, paddingHorizontal = 32,
                gap = 16,
                children = {
                    UI.Label {
                        text = "加入失败",
                        fontSize = 20,
                        fontColor = { 255, 100, 100, 255 },
                        fontWeight = "bold",
                    },
                    UI.Label {
                        text = reason,
                        fontSize = 14,
                        fontColor = { 180, 185, 200, 255 },
                        textAlign = "center",
                    },
                    UI.Button {
                        text = "返回",
                        width = 120, height = 38,
                        fontSize = 14,
                        variant = "primary",
                        onClick = function()
                            failRoot:Remove()
                            GameController.ShowMenu()
                        end,
                    },
                },
            },
        },
    }
    UI.SetRoot(failRoot)
end

--- 真人玩家出价确认（区别于 AI）
function HandlePlayerBidConfirmed(eventType, eventData)
    if not gameInitialized_ then return end
    local data = Shared.UnpackEvent(eventData)
    local playerIdx = data.playerIdx
    if playerIdx then
        ClientGameState.SetBidLocked(playerIdx, true)
        UIState.aiBidConfirmed[playerIdx] = true  -- 复用同一 UI 标记
        ClientGameState.NotifyChange()
    end
end

--- 回收结果
function HandleRecycleResult(eventType, eventData)
    if not gameInitialized_ then return end
    local data = Shared.UnpackEvent(eventData)

    -- 更新 ClientGameState 的待处理物品
    if data.remainingItems then
        ClientGameState.SetMyPendingItems(data.remainingItems)
    end
    if data.totalValue then
        ClientGameState.AddMyRecycledMoney(data.totalValue)
        -- 更新玩家金币显示
        local players = ClientGameState.GetPlayers()
        local myPlayer = players[mySlot_]
        if myPlayer then
            myPlayer.money = (myPlayer.money or 0) + data.totalValue
            MoneyHUD.SetMoney(myPlayer.money)
        end
    end

    print("[Client] Recycle result: " .. tostring(data.totalValue)
        .. " from " .. #(data.recycledItems or {}) .. " items")

    if Client._onRecycleResult then
        Client._onRecycleResult(data)
    end

    ClientGameState.NotifyChange()
end

--- 结算完成（入库结果）
function HandleSettleComplete(eventType, eventData)
    if not gameInitialized_ then return end
    local data = Shared.UnpackEvent(eventData)

    ClientGameState.SetMySettled(true)
    ClientGameState.SetSettling(false)

    -- 更新最终金额
    if data.finalMoney then
        local players = ClientGameState.GetPlayers()
        local myPlayer = players[mySlot_]
        if myPlayer then
            myPlayer.money = data.finalMoney
            MoneyHUD.SetMoney(data.finalMoney)
        end
    end

    print("[Client] Settle complete. Stored: " .. #(data.storedItems or {})
        .. ", auto-recycled: " .. #(data.autoRecycledItems or {})
        .. " for " .. tostring(data.autoRecycledValue))

    if Client._onSettleComplete then
        Client._onSettleComplete(data)
    end

    ClientGameState.NotifyChange()
end

--- 倒计时同步
function HandleTimerSync(eventType, eventData)
    if not gameInitialized_ then return end
    local data = Shared.UnpackEvent(eventData)
    -- 用服务端时间修正本地计时（防漂移）
    ClientGameState.SetTimer(data.timer or 0)
end

--- 资金变动
function HandleMoneyUpdate(eventType, eventData)
    if not gameInitialized_ then return end
    local data = Shared.UnpackEvent(eventData)
    ClientGameState.SetPlayerMoney(data.playerIdx, data.money)

    -- 更新金币 HUD
    if data.playerIdx == mySlot_ then
        MoneyHUD.SetMoney(data.money)
    end
end

--- 技能使用
function HandleSkillUsed(eventType, eventData)
    if not gameInitialized_ then return end
    local data = Shared.UnpackEvent(eventData)
    local playerIdx = data.playerIdx

    -- 更新技能状态
    if data.skillInfo and data.skillInfo.remaining ~= nil then
        ClientGameState.SetActiveSkillUses(playerIdx, data.skillInfo.remaining)
    end
    ClientGameState.SetActiveSkillActivated(playerIdx, true)

    if Client._onActiveSkillUsed then
        Client._onActiveSkillUsed(playerIdx, data.skillInfo, data.resultData)
    end

    ClientGameState.NotifyChange()
end

--- 玩家列表更新
function HandlePlayerList(eventType, eventData)
    if not gameInitialized_ then return end
    local data = Shared.UnpackEvent(eventData)
    if data.players then
        local players = RebuildPlayers(data.players)
        ClientGameState.SetPlayers(players)
        ClientGameState.NotifyChange()
    end
end

--- 房间状态更新（等待中的玩家数量变化）
function HandleRoomStatus(eventType, eventData)
    local data = Shared.UnpackEvent(eventData)
    local playerCount = data.playerCount or 0
    local maxPlayers = data.maxPlayers or 4
    local playerNames = data.players or {}

    print("[Client] Room status: " .. playerCount .. "/" .. maxPlayers .. " players")

    -- 更新匹配浮层显示
    if matchOverlay_ and matchTimerLabel_ then
        local namesStr = table.concat(playerNames, ", ")
        matchTimerLabel_:SetText(playerCount .. "/" .. maxPlayers .. " 名玩家  " .. namesStr)
    end
end

--- 服务器通知返回大厅（游戏结束后）
function HandleReturnLobby(eventType, eventData)
    print("[Client] Server requests return to lobby")
    -- 重置结算状态
    ClientGameState.ResetSettleState()
    -- 游戏结束后的返回由 GameOver UI 中的按钮触发，
    -- 这里只做状态重置标记，实际 UI 切换在 GameController.GoBackToLobby 中进行
end

-- ============================================================================
-- 连接事件处理
-- ============================================================================

function HandleServerConnected(eventType, eventData)
    print("[Client] ServerConnected event received")

    -- 连接建立后立即赋值 scene，避免引擎内部处理 LoadScene 消息时
    -- 因 scene 未赋值而报错 "Can not handle LoadScene message without an assigned scene"
    local conn = network:GetServerConnection()
    if conn and scene_ then
        conn.scene = scene_
        print("[Client] Scene assigned to connection in ServerConnected")
    end
end

--- 常驻服模式：服务器就绪事件（连接建立 + 服务器脚本加载完毕）
function HandleServerReady(eventType, eventData)
    print("[Client] ServerReady event received - server is ready!")

    -- 通过 network API 获取连接
    serverConnection_ = network:GetServerConnection()
    serverReady_ = true

    if not serverConnection_ then
        print("[Client] WARNING: ServerReady but GetServerConnection() returned nil!")
        return
    end

    -- 设置场景给连接（启用远程事件传输）
    serverConnection_.scene = scene_

    print("[Client] Server connection established")

    -- 如果有等待中的游戏配置（用户先点了开始），立即发送 C_JOIN_ROOM
    if pendingGameConfig_ then
        print("[Client] Server ready, sending pending C_JOIN_ROOM...")
        Client.SendJoinRoom(pendingGameConfig_)
        pendingGameConfig_ = nil
    end
end

function HandleServerDisconnected(eventType, eventData)
    print("[Client] Disconnected from server")
    serverConnection_ = nil

    -- 游戏进行中断线 → 弹窗提示并返回等待界面
    if gameInitialized_ then
        gameInitialized_ = false
        -- 使用 UI 弹窗通知玩家
        ---@type table
        local disconnectRoot = nil
        disconnectRoot = UI.Panel {
            width = "100%", height = "100%",
            backgroundColor = { 0, 0, 0, 200 },
            justifyContent = "center", alignItems = "center",
            children = {
                UI.Panel {
                    width = 320, minHeight = 160,
                    backgroundColor = { 30, 35, 50, 255 },
                    flexDirection = "column",
                    justifyContent = "center", alignItems = "center",
                    paddingVertical = 24, paddingHorizontal = 32,
                    gap = 16,
                    children = {
                        UI.Label {
                            text = "连接已断开",
                            fontSize = 20,
                            fontColor = { 255, 100, 100, 255 },
                            fontWeight = "bold",
                        },
                        UI.Label {
                            text = "与服务器的连接已丢失，请重新加入游戏。",
                            fontSize = 14,
                            fontColor = { 180, 185, 200, 255 },
                            textAlign = "center",
                        },
                        UI.Button {
                            text = "返回",
                            width = 120, height = 38,
                            fontSize = 14,
                            variant = "primary",
                            onClick = function()
                                disconnectRoot:Remove()
                                GameController.ShowMenu()
                            end,
                        },
                    },
                },
            },
        }
        UI.SetRoot(disconnectRoot)
    end
end

-- ============================================================================
-- 回调注册（供 GameController 设置）
-- ============================================================================

Client._onInfoRevealed = nil
Client._onBidRevealed = nil
Client._onJudgeResult = nil
Client._onItemRevealed = nil
Client._onBidPlaced = nil
Client._onWarehouseOpen = nil
Client._onGameOver = nil
Client._onTiebreakStart = nil
Client._onActiveSkillUsed = nil
Client._onRecycleResult = nil
Client._onSettleComplete = nil
Client._onJoinFailed = nil

function Client.SetOnInfoRevealed(fn)     Client._onInfoRevealed = fn end
function Client.SetOnBidRevealed(fn)      Client._onBidRevealed = fn end
function Client.SetOnJudgeResult(fn)      Client._onJudgeResult = fn end
function Client.SetOnItemRevealed(fn)     Client._onItemRevealed = fn end
function Client.SetOnBidPlaced(fn)        Client._onBidPlaced = fn end
function Client.SetOnWarehouseOpen(fn)    Client._onWarehouseOpen = fn end
function Client.SetOnGameOver(fn)         Client._onGameOver = fn end
function Client.SetOnTiebreakStart(fn)    Client._onTiebreakStart = fn end
function Client.SetOnActiveSkillUsed(fn)  Client._onActiveSkillUsed = fn end
function Client.SetOnRecycleResult(fn)    Client._onRecycleResult = fn end
function Client.SetOnSettleComplete(fn)   Client._onSettleComplete = fn end
function Client.SetOnJoinFailed(fn)       Client._onJoinFailed = fn end

-- ============================================================================
-- 入口
-- ============================================================================

function Client.Start()
    graphics.windowTitle = Config.GAME.Title

    -- 初始化 UI 系统
    UI.Init({
        fonts = {
            { family = "sans", weights = {
                normal = "Fonts/MiSans-Regular.ttf",
            } }
        },
        scale = UI.Scale.DEFAULT,
    })

    -- 全局去掉圆角
    local Theme = UI.Theme
    local curTheme = Theme.GetTheme()
    local noRadius = Theme.ExtendTheme(curTheme, {
        components = {
            Button = { borderRadius = 0 },
            Panel = { borderRadius = 0 },
            TextField = { borderRadius = 0 },
            Checkbox = { borderRadius = 0 },
            ProgressBar = { borderRadius = 0 },
        },
    })
    Theme.SetTheme(noRadius)

    -- 加载音效
    Utils.LoadSounds()

    -- 注册远程事件
    Shared.RegisterEvents()

    -- 创建最小场景
    scene_ = Scene()
    scene_:CreateComponent("Octree")

    -- 订阅连接事件（常驻服模式）
    SubscribeToEvent("ServerConnected", "HandleServerConnected")
    SubscribeToEvent("ServerDisconnected", "HandleServerDisconnected")
    SubscribeToEvent("ServerReady", "HandleServerReady")

    -- 防御性检查：如果连接在脚本加载前已建立，直接使用
    local existingConn = network:GetServerConnection()
    if existingConn then
        print("[Client] Connection already exists at Start(), using it directly")
        serverConnection_ = existingConn
        serverReady_ = true
        serverConnection_.scene = scene_
    end

    -- 订阅服务端远程事件
    local E = Shared.EVENTS
    SubscribeToEvent(E.S_ASSIGN_SLOT,      "HandleAssignSlot")
    SubscribeToEvent(E.S_GAME_INIT,        "HandleGameInit")
    SubscribeToEvent(E.S_PHASE_CHANGE,     "HandlePhaseChange")
    SubscribeToEvent(E.S_INFO_REVEALED,    "HandleInfoRevealed")
    SubscribeToEvent(E.S_PRIVATE_INFO,     "HandlePrivateInfo")
    SubscribeToEvent(E.S_AI_BID_CONFIRMED, "HandleAIBidConfirmed")
    SubscribeToEvent(E.S_BID_FINALIZED,    "HandleBidFinalized")
    SubscribeToEvent(E.S_BID_REVEALED,     "HandleBidRevealed")
    SubscribeToEvent(E.S_JUDGE_RESULT,     "HandleJudgeResult")
    SubscribeToEvent(E.S_TIEBREAK_START,   "HandleTiebreakStart")
    SubscribeToEvent(E.S_BID_PLACED,       "HandleBidPlaced")
    SubscribeToEvent(E.S_WAREHOUSE_OPEN,   "HandleWarehouseOpen")
    SubscribeToEvent(E.S_ITEM_REVEALED,    "HandleItemRevealed")
    SubscribeToEvent(E.S_GAME_OVER,        "HandleGameOver")
    SubscribeToEvent(E.S_TIMER_SYNC,       "HandleTimerSync")
    SubscribeToEvent(E.S_MONEY_UPDATE,     "HandleMoneyUpdate")
    SubscribeToEvent(E.S_SKILL_USED,       "HandleSkillUsed")
    SubscribeToEvent(E.S_PLAYER_LIST,      "HandlePlayerList")
    SubscribeToEvent(E.S_ROOM_STATUS,      "HandleRoomStatus")
    SubscribeToEvent(E.S_RETURN_LOBBY,     "HandleReturnLobby")
    SubscribeToEvent(E.S_JOIN_RESULT,      "HandleJoinResult")
    SubscribeToEvent(E.S_JOIN_FAILED,      "HandleJoinFailed")
    SubscribeToEvent(E.S_PLAYER_BID_CONFIRMED, "HandlePlayerBidConfirmed")
    SubscribeToEvent(E.S_RECYCLE_RESULT,   "HandleRecycleResult")
    SubscribeToEvent(E.S_SETTLE_COMPLETE,  "HandleSettleComplete")

    -- 通知 GameController 当前为网络模式（StartGame 会路由到 Client.StartMultiplayerGame）
    GameController.SetClientMode(true)

    -- 常驻服模式：直接显示完整菜单（与 Standalone 相同流程）
    -- 注意：常驻服模式下 clientCloud 可能在脚本加载时还未就绪
    -- 如果 clientCloud 为 nil，先用默认值显示菜单，后台轮询等待 clientCloud 就绪

    -- 详细环境诊断（帮助判断浏览器预览 vs TapTap App）
    print("[Client] === Environment Diagnostics ===")
    print("[Client] lobby: " .. tostring(lobby))
    print("[Client] clientCloud: " .. tostring(clientCloud))
    print("[Client] network: " .. tostring(network))
    if lobby then
        local uid = lobby:GetMyUserId()
        print("[Client] lobby:GetMyUserId() = " .. tostring(uid))
    end
    print("[Client] ================================")

    if clientCloud then
        cloudReady_ = true
        print("[Client] clientCloud available at startup")
    else
        cloudReady_ = false
        cloudRetryTimer_ = 0
        cloudRetryCount_ = 0
        print("[Client] clientCloud NOT available, will poll every " .. CLOUD_RETRY_INTERVAL .. "s (max " .. CLOUD_MAX_RETRIES .. " retries = " .. (CLOUD_RETRY_INTERVAL * CLOUD_MAX_RETRIES) .. "s)")
    end

    MoneyHUD.LoadFromCloud(function()
        SaveSystem.Init(function(success, isNewPlayer)
            print("[Client] SaveSystem ready. New player: " .. tostring(isNewPlayer))
            SettingsPanel.Init()
            RewardPanel.Init()
            VersionRewardPanel.Init()
            GameController.ShowMenu()
        end)
    end)

    print("=== " .. Config.GAME.Title .. " [Client] Started ===")
end

--- 刷新用户显示（当 clientCloud/lobby 延迟就绪时调用）
function Client.RefreshUserDisplay()
    DebugPanel.RefreshUserId()
end

function Client.Stop()
    UI.Shutdown()
end

---@param eventType string
---@param eventData UpdateEventData
function Client.HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()

    -- clientCloud 延迟就绪：轮询检查（常驻服模式下可能延迟可用）
    if not cloudReady_ and cloudRetryCount_ < CLOUD_MAX_RETRIES then
        cloudRetryTimer_ = cloudRetryTimer_ + dt
        if cloudRetryTimer_ >= CLOUD_RETRY_INTERVAL then
            cloudRetryTimer_ = cloudRetryTimer_ - CLOUD_RETRY_INTERVAL
            cloudRetryCount_ = cloudRetryCount_ + 1

            -- 检查 lobby 和 clientCloud
            local hasLobby = lobby ~= nil
            local hasCloud = clientCloud ~= nil
            local lobbyUid = hasLobby and lobby:GetMyUserId() or 0

            if hasCloud then
                cloudReady_ = true
                print("[Client] clientCloud became available! (retry #" .. cloudRetryCount_ .. ", lobby=" .. tostring(hasLobby) .. ", uid=" .. lobbyUid .. ")")
                -- 重新加载所有云端数据
                MoneyHUD.LoadFromCloud(function()
                    print("[Client] MoneyHUD cloud data reloaded")
                end)
                SaveSystem.Init(function(success, isNewPlayer)
                    print("[Client] SaveSystem ready (retry path). New player: " .. tostring(isNewPlayer))
                    SettingsPanel.Init()
                    RewardPanel.Init()
                    VersionRewardPanel.Init()
                end)
                -- 刷新 DebugPanel 用户名
                Client.RefreshUserDisplay()
            elseif cloudRetryCount_ % 5 == 0 then
                -- 每 5 次输出一次状态，避免日志刷屏
                print("[Client] Retry #" .. cloudRetryCount_ .. ": lobby=" .. tostring(hasLobby) .. " uid=" .. lobbyUid .. " clientCloud=" .. tostring(hasCloud))
            end

            if not hasCloud and cloudRetryCount_ >= CLOUD_MAX_RETRIES then
                print("[Client] clientCloud still nil after " .. CLOUD_MAX_RETRIES .. " retries (" .. (CLOUD_MAX_RETRIES * CLOUD_RETRY_INTERVAL) .. "s). Environment: lobby=" .. tostring(hasLobby) .. " uid=" .. lobbyUid)
                if not hasLobby then
                    print("[Client] lobby is also nil — likely running in browser preview (no TapTap login available)")
                else
                    print("[Client] lobby exists but clientCloud is nil — possible platform issue")
                end
            end
        end
    end

    -- SaveSystem 延迟保存计时
    SaveSystem.Update(dt)

    -- 奖励面板动画（菜单/游戏通用）
    RewardPanel.Update(dt)

    -- 匹配计时器更新（文案由 S_ROOM_STATUS 事件驱动）
    if matchOverlay_ then
        matchElapsed_ = matchElapsed_ + dt
    end

    if not gameInitialized_ then
        -- 菜单阶段也需要驱动 GameController（菜单动画等）
        GameController.HandleUpdate(dt)
        return
    end

    -- 本地倒计时递减（服务端每秒同步修正）
    ClientGameState.UpdateTimer(dt)

    -- 结算阶段倒计时递减
    ClientGameState.UpdateSettleTimer(dt)

    -- 驱动 GameController UI 更新
    GameController.HandleUpdate(dt)
end

return Client
