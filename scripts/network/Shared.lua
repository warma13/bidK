-- ============================================================================
-- network/Shared.lua - 多人游戏共享常量和工具函数
-- ============================================================================

-- cjson 是引擎内置全局变量，无需 require

local Shared = {}

-- ============================================================================
-- Remote Event 名称常量
-- ============================================================================

Shared.EVENTS = {
    -- === Client → Server ===
    C_READY            = "C_Ready",           -- 客户端场景就绪
    C_SELECT_CHAR      = "C_SelectChar",      -- 选择角色 { charIdx }
    C_SEALED_BID       = "C_SealedBid",       -- 暗标出价 { amount }
    C_TIEBREAK_BID     = "C_TiebreakBid",     -- 实时竞拍出价 { amount }
    C_USE_SKILL        = "C_UseSkill",        -- 使用主动技能
    C_SKIP_WAREHOUSE   = "C_SkipWarehouse",   -- 跳过开箱动画
    C_JOIN_ROOM        = "C_JoinRoom",        -- 加入房间 { regionId, diffIdx, charIdx }
    C_LEAVE_ROOM       = "C_LeaveRoom",       -- 离开房间
    C_RECYCLE_ITEMS    = "C_RecycleItems",    -- 请求按品质回收物品 { rarities[] }
    C_LEAVE_SETTLE     = "C_LeaveSettle",     -- 结算完成请求离开（未回收物品自动入库）
    C_REQUEST_STATE    = "C_RequestState",    -- 断线重连后请求完整状态
    C_REDEEM_CODE      = "C_RedeemCode",      -- 请求兑换码验证 { code }

    -- === Server → Client (broadcast / targeted) ===
    S_JOIN_RESULT      = "S_JoinResult",      -- 加入房间结果 { ok, roomId, error? }
    S_JOIN_FAILED      = "S_JoinFailed",      -- 加入失败 { reason }
    S_ASSIGN_SLOT      = "S_AssignSlot",      -- 分配玩家槽位 { slot, players }
    S_GAME_INIT        = "S_GameInit",        -- 游戏初始化 { players, warehouse, config }
    S_PHASE_CHANGE     = "S_PhaseChange",     -- 阶段变更 { phase, round, timer }
    S_INFO_REVEALED    = "S_InfoRevealed",    -- 信息揭露 { round, publicInfos }
    S_PRIVATE_INFO     = "S_PrivateInfo",     -- 私密线索（仅发给目标玩家） { skillInfo }
    S_BID_START        = "S_BidStart",        -- 暗标阶段开始 { timer }
    S_AI_BID_CONFIRMED = "S_AIBidConfirmed",  -- AI确认出价 { playerIdx }
    S_PLAYER_BID_CONFIRMED = "S_PlayerBidConfirmed", -- 真人玩家已出价 { playerIdx }
    S_BID_FINALIZED    = "S_BidFinalized",    -- 所有出价锁定 { revealOrder }
    S_BID_REVEALED     = "S_BidRevealed",     -- 揭示某玩家出价 { revealIndex, playerIdx, amount }
    S_JUDGE_RESULT     = "S_JudgeResult",     -- 判定结果 { result }
    S_TIEBREAK_START   = "S_TiebreakStart",   -- 实时竞拍开始 { players, startBid, timer }
    S_BID_PLACED       = "S_BidPlaced",       -- 实时竞拍出价 { playerIdx, amount }
    S_WAREHOUSE_OPEN   = "S_WarehouseOpen",   -- 开箱开始 { winner, winnerPaid }
    S_ITEM_REVEALED    = "S_ItemRevealed",    -- 物品揭示 { itemIndex, item }
    S_GAME_OVER        = "S_GameOver",        -- 游戏结束 { finalState, roundResults[] }
    S_TIMER_SYNC       = "S_TimerSync",       -- 倒计时同步 { timer }
    S_MONEY_UPDATE     = "S_MoneyUpdate",     -- 资金变动 { playerIdx, money }
    S_PLAYER_LIST      = "S_PlayerList",      -- 玩家列表更新 { players }
    S_SKILL_USED       = "S_SkillUsed",       -- 技能使用 { playerIdx, skillInfo, resultData }
    S_ROOM_STATUS      = "S_RoomStatus",      -- 房间状态更新 { roomId, players, maxPlayers }
    S_RECYCLE_RESULT   = "S_RecycleResult",   -- 回收结果 { recycledItems[], totalValue, remainingItems[] }
    S_SETTLE_COMPLETE  = "S_SettleComplete",  -- 入库+自动回收结果 { storedItems[], autoRecycledItems[], autoRecycledValue }
    S_RETURN_LOBBY     = "S_ReturnLobby",     -- 游戏结束返回大厅
    S_FULL_STATE       = "S_FullState",       -- 断线重连完整状态恢复
    S_REDEEM_RESULT    = "S_RedeemResult",    -- 兑换码验证结果 { ok, reward?, error? }
}

-- ============================================================================
-- 注册所有远程事件
-- ============================================================================

function Shared.RegisterEvents()
    for _, name in pairs(Shared.EVENTS) do
        network:RegisterRemoteEvent(name)
    end
    print("[Shared] Registered " .. Shared.CountEvents() .. " remote events")
end

function Shared.CountEvents()
    local n = 0
    for _ in pairs(Shared.EVENTS) do n = n + 1 end
    return n
end

-- ============================================================================
-- JSON 序列化工具
-- ============================================================================

--- 安全 JSON 编码
function Shared.JsonEncode(t)
    local ok, result = pcall(cjson.encode, t) ---@diagnostic disable-line: undefined-global
    if ok then return result end
    print("[Shared] JSON encode error: " .. tostring(result))
    return "{}"
end

--- 安全 JSON 解码
function Shared.JsonDecode(s)
    if not s or s == "" then return {} end
    local ok, result = pcall(cjson.decode, s) ---@diagnostic disable-line: undefined-global
    if ok then return result end
    print("[Shared] JSON decode error: " .. tostring(result))
    return {}
end

-- ============================================================================
-- VariantMap 打包/解包（用 JSON 字符串传输复杂数据）
-- ============================================================================

--- 将 Lua table 打包为 VariantMap（通过 JSON 字符串）
---@param data table 要发送的数据
---@return VariantMap
function Shared.PackEvent(data)
    local vm = VariantMap()
    vm["Data"] = Variant(Shared.JsonEncode(data))
    return vm
end

--- 从 VariantMap 解包出 Lua table
---@param eventData VariantMap
---@return table
function Shared.UnpackEvent(eventData)
    local json = eventData["Data"]:GetString()
    return Shared.JsonDecode(json)
end

-- ============================================================================
-- 玩家序列化（用于网络传输，去除不可序列化的字段）
-- ============================================================================

--- 将玩家数据序列化为可传输的 table
function Shared.SerializePlayer(player, playerIdx)
    return {
        idx = playerIdx,
        name = player.name,
        isHuman = player.isHuman,
        money = player.money,
        characterId = player.character and player.character.id or nil,
        characterName = player.character and player.character.name or nil,
    }
end

--- 序列化所有玩家
function Shared.SerializePlayers(players)
    local result = {}
    for idx, p in ipairs(players) do
        result[idx] = Shared.SerializePlayer(p, idx)
    end
    return result
end

return Shared
