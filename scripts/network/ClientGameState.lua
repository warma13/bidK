-- ============================================================================
-- network/ClientGameState.lua - 客户端只读状态镜像
-- 提供与 GameState 相同的 getter API，但数据来自服务端网络事件
-- ============================================================================

local Config = require("Config")

local ClientGameState = {}

-- 阶段枚举（与 GameState.PHASE 完全一致）
ClientGameState.PHASE = {
    CHAR_SELECT     = "char_select",
    WAREHOUSE_INTRO = "warehouse_intro",
    INFO_REVEAL     = "info_reveal",
    SEALED_BID      = "sealed_bid",
    BID_REVEAL      = "bid_reveal",
    ROUND_JUDGE     = "round_judge",
    TIEBREAK_BID    = "tiebreak_bid",
    WAREHOUSE_OPEN  = "warehouse_open",
    GAME_OVER       = "game_over",
}

-- 内部状态（由 Client.lua 通过 setter 方法填充）
local state = {
    phase = ClientGameState.PHASE.CHAR_SELECT,
    players = {},
    warehouseName = "",
    warehouseItems = {},
    warehouseTotalValue = 0,
    warehouseTypeId = "grocery",
    regionId = "",
    diffLabel = "",
    entryFee = 0,
    expectedValue = 100000,
    currentRound = 0,
    sealedBids = {},
    bidLocked = {},
    revealOrder = { 1, 2, 3, 4 },
    revealIndex = 0,
    judgeResult = nil,
    tiebreakPlayers = {},
    currentBid = 0,
    currentBidder = 0,
    bidHistory = {},
    roundBids = {},
    timer = 0,
    revealedItemIndex = 0,
    winner = 0,
    winnerPaid = 0,
    activeSkillUses = {},
    activeSkillActivated = {},
    bidBoostStacks = {},
    mySlot = 1,
    myUserId = 0,
    grid = nil,   -- 仓库网格布局（LootPanel 使用）

    -- 结算阶段
    settleTimeout = 60,         -- 结算超时（秒）
    settleTimer = 60,           -- 结算剩余时间
    isSettling = false,         -- 是否处于结算阶段
    roundResults = {},          -- 每轮赢家结果
    myItemsWon = {},            -- 自己赢得的物品列表（赢家才有）
    myPendingItems = {},        -- 待处理物品（回收后更新）
    myRecycledMoney = 0,        -- 已回收金额
    mySettled = false,          -- 自己是否已完成结算
    finalPlayers = {},          -- 完整的结算玩家数据（S_GAME_OVER.players）

    -- UI 回调
    onStateChange = nil,
    onMoneyChanged = nil,
}

-- ============================================================================
-- Getters（与 GameState 完全相同的 API）
-- ============================================================================

function ClientGameState.GetPhase()           return state.phase end
function ClientGameState.GetPlayers()         return state.players end
function ClientGameState.GetCurrentRound()    return state.currentRound end
function ClientGameState.GetTimer()           return state.timer end
function ClientGameState.GetWarehouseName()   return state.warehouseName end
function ClientGameState.GetWarehouseItems()  return state.warehouseItems end
function ClientGameState.GetWarehouseTotalValue() return state.warehouseTotalValue end
function ClientGameState.GetExpectedValue()   return state.expectedValue end
function ClientGameState.GetSealedBids()      return state.sealedBids end
function ClientGameState.GetBidLocked()       return state.bidLocked end
function ClientGameState.GetRevealIndex()     return state.revealIndex end
function ClientGameState.GetRevealOrder()     return state.revealOrder end
function ClientGameState.GetJudgeResult()     return state.judgeResult end
function ClientGameState.GetTiebreakPlayers() return state.tiebreakPlayers end
function ClientGameState.GetCurrentBid()      return state.currentBid end
function ClientGameState.GetCurrentBidder()   return state.currentBidder end
function ClientGameState.GetBidHistory()      return state.bidHistory end
function ClientGameState.GetRoundBids()       return state.roundBids end
function ClientGameState.GetRevealedItemIndex() return state.revealedItemIndex end
function ClientGameState.GetWinner()          return state.winner end
function ClientGameState.GetWinnerPaid()      return state.winnerPaid end
function ClientGameState.GetActiveSkillUses() return state.activeSkillUses end
function ClientGameState.GetActiveSkillActivated() return state.activeSkillActivated end
function ClientGameState.GetBidBoostStacks()  return state.bidBoostStacks end
function ClientGameState.GetMyUserId()        return state.myUserId end
function ClientGameState.GetWarehouseTypeId() return state.warehouseTypeId end
function ClientGameState.GetEntryFee()        return state.entryFee end
function ClientGameState.GetDiffLabel()       return state.diffLabel end
function ClientGameState.GetRegionId()        return state.regionId or "" end
function ClientGameState.GetMySlot()          return state.mySlot end
function ClientGameState.GetSettleTimeout()   return state.settleTimeout end
function ClientGameState.GetSettleTimer()     return state.settleTimer end
function ClientGameState.IsSettling()         return state.isSettling end
function ClientGameState.GetRoundResults()    return state.roundResults end
function ClientGameState.GetMyItemsWon()      return state.myItemsWon end
function ClientGameState.GetMyPendingItems()  return state.myPendingItems end
function ClientGameState.GetMyRecycledMoney() return state.myRecycledMoney end
function ClientGameState.IsMySettled()        return state.mySettled end
function ClientGameState.GetFinalPlayers()    return state.finalPlayers end

-- 合成 warehouseData 供 UI 使用（LootPanel 需要 grid/warehouseTypeId 等字段）
function ClientGameState.GetWarehouseData()
    return {
        warehouseTypeId = state.warehouseTypeId,
        warehouseName = state.warehouseName,
        items = state.warehouseItems,
        totalValue = state.warehouseTotalValue,
        grid = state.grid,
        regionId = state.regionId,
    }
end

-- 竞拍辅助
function ClientGameState.GetNextTiebreakBidAmount()
    if state.currentBid == 0 then return Config.GAME.MinBidIncrement end
    local increment = Config.CalcBidIncrement(state.currentBid, 0.05)
    return state.currentBid + increment
end

function ClientGameState.IsTiebreakParticipant(playerIdx)
    for _, idx in ipairs(state.tiebreakPlayers) do
        if idx == playerIdx then return true end
    end
    return false
end

-- ============================================================================
-- 技能相关 getter（客户端展示用）
-- ============================================================================

function ClientGameState.GetActiveSkillInfo(playerIdx)
    local player = state.players[playerIdx]
    if not player or not player.character then return nil end
    local ch = player.character
    if not ch.activeSkill then return nil end
    return {
        name = ch.activeSkill.name,
        desc = ch.activeSkill.desc,
        effect = ch.activeSkill.effect,
        remaining = state.activeSkillUses[playerIdx] or 0,
        activatedThisRound = state.activeSkillActivated[playerIdx] or false,
    }
end

function ClientGameState.GetBidBoostMultiplier(playerIdx)
    local stacks = state.bidBoostStacks[playerIdx] or 0
    if stacks <= 0 then return 1.0 end
    local player = state.players[playerIdx]
    if not player or not player.character then return 1.0 end
    local ch = player.character
    -- 查找 bid_boost 被动
    if ch.passiveSkill and ch.passiveSkill.effect == "bid_boost" then
        local boostPerStack = ch.passiveSkill.boostPerStack or 0.05
        return 1.0 + stacks * boostPerStack
    end
    return 1.0
end

function ClientGameState.GetDiscountRate(playerIdx)
    local player = state.players[playerIdx]
    if not player or not player.character then return 0 end
    local ch = player.character
    if ch.passiveSkill and ch.passiveSkill.effect == "discount" then
        return ch.passiveSkill.discountRate or 0
    end
    return 0
end

function ClientGameState.GetValueBonus(playerIdx)
    local player = state.players[playerIdx]
    if not player or not player.character then return 0 end
    local ch = player.character
    if ch.passiveSkill and ch.passiveSkill.effect == "value_bonus" then
        local bonus = ch.passiveSkill.bonusRate or 0
        -- 铁柱专精加成
        if ch.passiveSkill.specialization then
            if state.warehouseTypeId == ch.passiveSkill.specialization then
                bonus = bonus + (ch.passiveSkill.specializationBonus or 0)
            end
        end
        return bonus
    end
    return 0
end

-- ============================================================================
-- Setters（仅供 Client.lua 调用，非公开 API）
-- ============================================================================

function ClientGameState.SetPhase(phase)
    local old = state.phase
    state.phase = phase
    print("[ClientGS] Phase: " .. old .. " -> " .. phase)
    ClientGameState.NotifyChange()
end

function ClientGameState.SetPlayers(players)
    state.players = players
end

function ClientGameState.SetMySlot(slot)
    state.mySlot = slot
end

function ClientGameState.SetMyUserId(userId)
    state.myUserId = userId
end

function ClientGameState.SetTimer(timer)
    state.timer = timer
end

function ClientGameState.SetCurrentRound(round)
    state.currentRound = round
end

function ClientGameState.SetWarehouseInfo(data)
    state.warehouseName = data.warehouseName or ""
    state.warehouseItems = data.warehouseItems or {}
    state.warehouseTotalValue = data.warehouseTotalValue or 0
    state.warehouseTypeId = data.warehouseTypeId or "grocery"
    state.regionId = data.regionId or ""
    state.diffLabel = data.diffLabel or ""
    state.entryFee = data.entryFee or 0
    state.expectedValue = data.expectedValue or 100000
    state.grid = data.grid  -- 仓库网格布局（LootPanel 需要）
end

function ClientGameState.SetSealedBids(bids)
    state.sealedBids = bids or {}
end

function ClientGameState.SetBidLocked(playerIdx, locked)
    state.bidLocked[playerIdx] = locked
end

function ClientGameState.SetRevealInfo(revealOrder, revealIndex)
    state.revealOrder = revealOrder or { 1, 2, 3, 4 }
    state.revealIndex = revealIndex or 0
end

function ClientGameState.SetRevealIndex(idx)
    state.revealIndex = idx
end

function ClientGameState.SetJudgeResult(result)
    state.judgeResult = result
end

function ClientGameState.SetTiebreakInfo(players, startBid)
    state.tiebreakPlayers = players or {}
    state.currentBid = startBid or 0
    state.currentBidder = 0
    state.bidHistory = {}
end

function ClientGameState.SetCurrentBid(bid)
    state.currentBid = bid
end

function ClientGameState.SetCurrentBidder(bidder)
    state.currentBidder = bidder
end

function ClientGameState.AddBidHistory(entry)
    state.bidHistory[#state.bidHistory + 1] = entry
end

function ClientGameState.SetRoundBid(round, playerIdx, amount)
    if not state.roundBids[round] then
        state.roundBids[round] = {}
    end
    state.roundBids[round][playerIdx] = amount
end

function ClientGameState.SetRevealedItemIndex(idx)
    state.revealedItemIndex = idx
end

function ClientGameState.SetWinner(winner, paid)
    state.winner = winner or 0
    state.winnerPaid = paid or 0
end

function ClientGameState.SetPlayerMoney(playerIdx, money)
    local player = state.players[playerIdx]
    if player then
        player.money = money
        if state.onMoneyChanged then
            state.onMoneyChanged(playerIdx, money)
        end
    end
end

function ClientGameState.SetActiveSkillUses(playerIdx, uses)
    state.activeSkillUses[playerIdx] = uses
end

function ClientGameState.SetActiveSkillActivated(playerIdx, activated)
    state.activeSkillActivated[playerIdx] = activated
end

function ClientGameState.SetBidBoostStacks(playerIdx, stacks)
    state.bidBoostStacks[playerIdx] = stacks
end

-- ============================================================================
-- 结算阶段 Setters
-- ============================================================================

function ClientGameState.SetSettleTimeout(timeout)
    state.settleTimeout = timeout or 60
    state.settleTimer = state.settleTimeout
end

function ClientGameState.SetSettling(settling)
    state.isSettling = settling
end

function ClientGameState.SetRoundResults(results)
    state.roundResults = results or {}
end

function ClientGameState.SetFinalPlayers(players)
    state.finalPlayers = players or {}
end

function ClientGameState.SetMyItemsWon(items)
    state.myItemsWon = items or {}
    -- 初始化 pendingItems 为 itemsWon 的副本
    state.myPendingItems = {}
    for _, item in ipairs(state.myItemsWon) do
        state.myPendingItems[#state.myPendingItems + 1] = item
    end
    state.myRecycledMoney = 0
    state.mySettled = false
end

function ClientGameState.SetMyPendingItems(items)
    state.myPendingItems = items or {}
end

function ClientGameState.AddMyRecycledMoney(amount)
    state.myRecycledMoney = state.myRecycledMoney + (amount or 0)
end

function ClientGameState.SetMySettled(settled)
    state.mySettled = settled
end

function ClientGameState.UpdateSettleTimer(dt)
    if not state.isSettling then return end
    state.settleTimer = state.settleTimer - dt
    if state.settleTimer < 0 then state.settleTimer = 0 end
end

function ClientGameState.ResetSettleState()
    state.isSettling = false
    state.settleTimer = 60
    state.roundResults = {}
    state.myItemsWon = {}
    state.myPendingItems = {}
    state.myRecycledMoney = 0
    state.mySettled = false
    state.finalPlayers = {}
end

-- 重置出价阶段状态
function ClientGameState.ResetBidState()
    state.sealedBids = {}
    state.bidLocked = {}
    state.revealIndex = 0
    state.judgeResult = nil
end

-- ============================================================================
-- 倒计时更新（客户端本地平滑递减，服务端周期同步修正）
-- ============================================================================

function ClientGameState.UpdateTimer(dt)
    if state.phase ~= ClientGameState.PHASE.SEALED_BID
       and state.phase ~= ClientGameState.PHASE.TIEBREAK_BID then
        return
    end
    state.timer = state.timer - dt
    if state.timer < 0 then state.timer = 0 end
end

-- ============================================================================
-- 回调
-- ============================================================================

function ClientGameState.SetOnStateChange(fn)
    state.onStateChange = fn
end

function ClientGameState.SetOnMoneyChanged(fn)
    state.onMoneyChanged = fn
end

function ClientGameState.NotifyChange()
    if state.onStateChange then
        state.onStateChange(ClientGameState)
    end
end

-- ============================================================================
-- 空操作（保持与 GameState 的 API 兼容，客户端不需要这些）
-- ============================================================================

function ClientGameState.ValidateMoney(_) end
function ClientGameState.ValidateBids() end
function ClientGameState.SecureAddMoney(_, _) end
function ClientGameState.SecureSetMoney(_, _) end
function ClientGameState.SaveCloudMoney() end
function ClientGameState.SetTimer(val) state.timer = val end
function ClientGameState.AddMoney(_, _) end

-- Debug helpers（客户端不允许）
function ClientGameState.UseActiveSkill(_) return false end
function ClientGameState.ResetRoundSkills() end
function ClientGameState.ApplyRoundPassives() end
function ClientGameState.LoadCloudMoney(cb) if cb then cb() end end

return ClientGameState
