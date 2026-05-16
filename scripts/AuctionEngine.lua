-- ============================================================================
-- AuctionEngine.lua - 竞拍引擎（暗标仓库竞拍版）
-- ============================================================================

local Config = require("Config")
local SaveSystem = require("SaveSystem")
local PropSystem = require("PropSystem")

local AuctionEngine = {}

-- ============================================================================
-- 依赖注入（多房间隔离时由 RoomInstance 注入正确的实例）
-- ============================================================================

local _GameState = nil
local _AIPlayer = nil
local _InfoSystem = nil

--- 注入依赖（必须在使用前调用）
---@param gameState table GameState 模块
---@param aiPlayer table AIPlayer 模块
---@param infoSystem table InfoSystem 模块
function AuctionEngine.InjectDeps(gameState, aiPlayer, infoSystem)
    _GameState = gameState
    _AIPlayer = aiPlayer
    _InfoSystem = infoSystem
end

-- 世代计数器（防止异步回调操作过期状态）
local engineGeneration = 0

-- 惰性加载 CenterPanel（避免在 INFO_REVEAL 热路径中每帧调用 require）
local _CenterPanel = nil
local function GetCenterPanel()
    if not _CenterPanel then
        _CenterPanel = require("UI.CenterPanel")
    end
    return _CenterPanel
end

-- 引擎状态
local engine = {
    initialized = false,

    -- 阶段延迟控制
    phaseDelay = 0,
    WAREHOUSE_INTRO_DURATION = 3.0,
    INFO_REVEAL_DURATION = 4.0,
    BID_REVEAL_INTERVAL = 1.0,
    JUDGE_DISPLAY_DURATION = 0,
    ITEM_REVEAL_INTERVAL = 0.8,  -- 默认值（白/绿）
    ITEM_REVEAL_BY_RARITY = {
        common    = 0.8,
        uncommon  = 0.8,
        rare      = 1.0,
        epic      = 1.2,
        legendary = 2.0,
        mythic    = 2.0,
    },
    GAME_OVER_DELAY = 2.0,

    -- 实时竞拍
    bidCooldown = 0,
    BID_COOLDOWN_TIME = 0.5,

    -- UI 驱动的出价揭示
    bidRevealDone = false,

    -- onGameOver 已触发守卫（防止 SkipWarehouseOpen 与 Update 双重触发）
    gameOverFired = false,

    -- 无头模式（服务端：无 UI，定时驱动阶段推进）
    headless = false,
    headlessDelay = 0,

    -- 回调
    onInfoRevealed = nil,      -- (round, publicInfo, skillInfo)
    onBidRevealed = nil,       -- (revealIndex, playerIdx, amount)
    onJudgeResult = nil,       -- (judgeResult)
    onItemRevealed = nil,      -- (itemIndex, item)
    onBidPlaced = nil,         -- (playerIdx, amount) 实时竞拍
    onWarehouseOpen = nil,     -- () 开箱开始
    onGameOver = nil,          -- () 游戏结束
    onTiebreakStart = nil,     -- (tiebreakPlayers)
    onAISealedBidConfirmed = nil, -- (playerIdx) AI暗标出价已确认
}

--- 根据物品品质获取揭示间隔
local function GetRevealDelay(item)
    if item and item.rarity then
        return engine.ITEM_REVEAL_BY_RARITY[item.rarity] or engine.ITEM_REVEAL_INTERVAL
    end
    return engine.ITEM_REVEAL_INTERVAL
end

-- ============================================================================
-- 初始化和开始
-- ============================================================================

function AuctionEngine.Init(playerCharIdx, regionId, diffIdx, warehouseTypeId, playersConfig)
    engineGeneration = engineGeneration + 1
    engine.diffIdx = diffIdx or 1
    engine.regionId = regionId
    _GameState.Init(playerCharIdx, regionId, diffIdx, warehouseTypeId, playersConfig)
    -- 传入仓库类型ID（用于铁柱专精匹配）
    local warehouseData = _GameState.GetWarehouseData()
    local whTypeId = warehouseData and warehouseData.warehouseTypeId or nil
    _InfoSystem.Init(_GameState.GetWarehouseItems(), _GameState.GetPlayers(), whTypeId)
    _AIPlayer.Init()
    engine.initialized = true
    engine.bidCooldown = 0
    engine.gameOverFired = false
    print("[AuctionEngine] Initialized")
end

function AuctionEngine.StartGame()
    print("[AE-FLOW] StartGame called, loading cloud money...")
    local gen = engineGeneration
    -- 从云端加载资金，完成后扣除入场费并进入第1轮信息揭露
    _GameState.LoadCloudMoney(function()
        if engineGeneration ~= gen then
            print("[AE-GUARD] Stale LoadCloudMoney callback ignored (gen " .. gen .. " vs " .. engineGeneration .. ")")
            return
        end
        print("[AE-FLOW] LoadCloudMoney callback fired")
        -- 扣除入场费
        local region = nil
        for _, r in ipairs(Config.REGIONS) do
            if r.id == engine.regionId then region = r; break end
        end
        if region and region.difficulties then
            local diff = region.difficulties[engine.diffIdx]
            if diff and diff.entryFee > 0 then
                _GameState.SecureAddMoney(1, -diff.entryFee, "entry_fee")
                -- 注意：SecureAddMoney 内部已调用 SaveCloudMoney，不再重复调用
                print("[AuctionEngine] Entry fee deducted: " .. diff.entryFee)
            end
        end
        -- 消耗门票（按难度）
        if region and region.difficulties then
            local diff = region.difficulties[engine.diffIdx]
            if diff and diff.requiredTicket then
                local ok = SaveSystem.ConsumeTicket(diff.requiredTicket)
                if ok then
                    SaveSystem.AddTicketGameStat()
                    SaveSystem.MarkDirty()
                    print("[AuctionEngine] Ticket consumed: " .. diff.requiredTicket)
                end
            end
        end
        print("[AE-FLOW] About to EnterInfoReveal(1)")
        AuctionEngine.EnterInfoReveal(1)
        print("[AE-FLOW] EnterInfoReveal(1) done")
    end)
end

-- ============================================================================
-- 玩家操作
-- ============================================================================

-- 暗标出价（可反复修改）
function AuctionEngine.PlayerSealedBid(amount)
    if _GameState.GetPhase() ~= _GameState.PHASE.SEALED_BID then return false end
    return _GameState.PlaceSealedBid(1, amount)
end

-- 实时竞拍出价
function AuctionEngine.PlayerTiebreakBid(amount)
    if engine.bidCooldown > 0 then return false end
    if _GameState.GetPhase() ~= _GameState.PHASE.TIEBREAK_BID then return false end

    local ok, err = _GameState.PlaceTiebreakBid(1, amount)
    if ok then
        engine.bidCooldown = engine.BID_COOLDOWN_TIME
        if engine.onBidPlaced then
            engine.onBidPlaced(1, amount)
        end
    end
    return ok
end

-- ============================================================================
-- 每帧更新 - 核心状态机
-- ============================================================================

function AuctionEngine.Update(dt)
    if not engine.initialized then return end

    local phase = _GameState.GetPhase()

    if phase == _GameState.PHASE.WAREHOUSE_INTRO then
        engine.phaseDelay = engine.phaseDelay - dt
        if engine.phaseDelay <= 0 then
            -- 进入第1轮信息揭露
            AuctionEngine.EnterInfoReveal(1)
        end

    elseif phase == _GameState.PHASE.INFO_REVEAL then
        engine._infoRevealElapsed = (engine._infoRevealElapsed or 0) + dt
        if engine.headless then
            -- 无头模式：固定延迟后推进（无动画队列）
            engine.headlessDelay = engine.headlessDelay - dt
            if engine.headlessDelay <= 0 then
                _GameState.StartSealedBid()
                local ok, err = pcall(_AIPlayer.StartSealedBidThinking, _GameState, _InfoSystem)
                if not ok then
                    print("[AuctionEngine] ERROR in StartSealedBidThinking: " .. tostring(err))
                end
            end
        else
            -- 等待信息弹出动画队列全部播完再推进
            local CenterPanel = GetCenterPanel()
            local isAnim = CenterPanel.IsAnimating()
            -- 15秒超时：防止动画卡死导致永远无法推进
            local timedOut = engine._infoRevealElapsed >= 15.0
            if timedOut and isAnim then
                print("[AE-FLOW] INFO_REVEAL timeout after 15s, forcing CenterPanel reset")
                pcall(CenterPanel.ResetAnimation)
                isAnim = false
            end
            if not isAnim then
                _GameState.StartSealedBid()
                local ok, err = pcall(_AIPlayer.StartSealedBidThinking, _GameState, _InfoSystem)
                if not ok then
                    print("[AuctionEngine] ERROR in StartSealedBidThinking: " .. tostring(err))
                end
            end
        end

    elseif phase == _GameState.PHASE.SEALED_BID then
        _GameState.UpdateTimer(dt)
        -- AI 在此阶段内完成出价（通过回调通知 UI）
        -- 用 pcall 保护：即使 AI 代码出错，也不阻塞后续计时器检查和阶段推进
        local aiOk, aiErr = pcall(_AIPlayer.UpdateSealedBid, dt, _GameState, function(playerIdx, amount)
            local ok = _GameState.PlaceSealedBid(playerIdx, amount)
            if ok and engine.onAISealedBidConfirmed then
                engine.onAISealedBidConfirmed(playerIdx)
            end
        end)
        if not aiOk then
            print("[AuctionEngine] ERROR in AI UpdateSealedBid: " .. tostring(aiErr))
        end

        -- 检查是否所有人已出价
        local allBid = true
        local bidLocked = _GameState.GetBidLocked()
        local players = _GameState.GetPlayers()
        for i = 1, #players do
            if not bidLocked[i] then
                allBid = false
            end
        end

        local timerExpired = _GameState.GetTimer() <= 0
        if allBid or timerExpired then
            -- 全员已出价或时间到，锁定所有出价
            if timerExpired and not allBid then
                print("[AuctionEngine] SEALED_BID timeout: forcing finalize (not all bids placed)")
            end
            _GameState.FinalizeSealedBids()
            engine.phaseDelay = engine.BID_REVEAL_INTERVAL
            if engine.headless then
                engine.headlessDelay = engine.BID_REVEAL_INTERVAL
            end
        end

    elseif phase == _GameState.PHASE.BID_REVEAL then
        if engine.headless then
            -- 无头模式：定时逐个揭示出价
            engine.headlessDelay = engine.headlessDelay - dt
            if engine.headlessDelay <= 0 then
                local hasMore = _GameState.RevealNextBid()
                if hasMore then
                    local idx = _GameState.GetRevealIndex()
                    local order = _GameState.GetRevealOrder()
                    local pIdx = order[idx]
                    local bid = _GameState.GetSealedBids()[pIdx] or 0
                    if engine.onBidRevealed then
                        engine.onBidRevealed(idx, pIdx, bid)
                    end
                    engine.headlessDelay = engine.BID_REVEAL_INTERVAL
                else
                    -- 全部揭示完毕，执行判定
                    _GameState.PerformJudgment()
                    engine.phaseDelay = engine.JUDGE_DISPLAY_DURATION
                    if engine.onJudgeResult then
                        engine.onJudgeResult(_GameState.GetJudgeResult())
                    end
                end
            end
        else
            -- UI 驱动揭示动画，等待 UI 调用 FinishBidReveal()
            if engine.bidRevealDone then
                engine.bidRevealDone = false
                _GameState.PerformJudgment()
                engine.phaseDelay = engine.JUDGE_DISPLAY_DURATION
                if engine.onJudgeResult then
                    engine.onJudgeResult(_GameState.GetJudgeResult())
                end
            end
        end

    elseif phase == _GameState.PHASE.ROUND_JUDGE then
        engine.phaseDelay = engine.phaseDelay - dt
        if engine.phaseDelay <= 0 then
            local result = _GameState.GetJudgeResult()
            if result.passed then
                -- 有赢家 → 开箱
                _GameState.StartWarehouseOpen()
                local items = _GameState.GetWarehouseItems()
                engine.phaseDelay = GetRevealDelay(items[1])
                if engine.onWarehouseOpen then
                    engine.onWarehouseOpen()
                end
            elseif result.isTie then
                -- 第4轮平局 → 实时竞拍
                _GameState.SetupTiebreak()
                if engine.onTiebreakStart then
                    engine.onTiebreakStart(_GameState.GetTiebreakPlayers())
                end
            else
                -- 未决出 → 下一轮
                local nextRound = _GameState.GetCurrentRound() + 1
                AuctionEngine.EnterInfoReveal(nextRound)
            end
        end

    elseif phase == _GameState.PHASE.TIEBREAK_BID then
        -- 更新冷却
        if engine.bidCooldown > 0 then
            engine.bidCooldown = engine.bidCooldown - dt
        end
        -- 更新倒计时
        _GameState.UpdateTimer(dt)
        -- AI实时竞拍（pcall 保护，防止 AI 出错阻塞计时器检查）
        local tbOk, tbErr = pcall(_AIPlayer.UpdateTiebreak, dt, _GameState, function(playerIdx, amount)
            local ok = _GameState.PlaceTiebreakBid(playerIdx, amount)
            if ok and engine.onBidPlaced then
                engine.onBidPlaced(playerIdx, amount)
            end
        end)
        if not tbOk then
            print("[AuctionEngine] ERROR in AI UpdateTiebreak: " .. tostring(tbErr))
        end

        if _GameState.GetTimer() <= 0 then
            _GameState.EndTiebreak()
            _GameState.StartWarehouseOpen()
            local items = _GameState.GetWarehouseItems()
            engine.phaseDelay = GetRevealDelay(items[1])
            if engine.onWarehouseOpen then
                engine.onWarehouseOpen()
            end
        end

    elseif phase == _GameState.PHASE.WAREHOUSE_OPEN then
        engine.phaseDelay = engine.phaseDelay - dt
        if engine.phaseDelay <= 0 then
            local hasMore = _GameState.RevealNextItem()
            if hasMore then
                local idx = _GameState.GetRevealedItemIndex()
                local items = _GameState.GetWarehouseItems()
                local item = items[idx]
                if engine.onItemRevealed then
                    engine.onItemRevealed(idx, item)
                end
                engine.phaseDelay = GetRevealDelay(item)
            else
                -- 全部展示完 → 结算资金 → 游戏结束
                _GameState.SettleWarehouseValue()
                engine.phaseDelay = engine.GAME_OVER_DELAY
                _GameState.SetPhase(_GameState.PHASE.GAME_OVER)
                if engine.onGameOver and not engine.gameOverFired then
                    engine.gameOverFired = true
                    engine.onGameOver()
                end
            end
        end
    end
end

-- ============================================================================
-- 内部流程
-- ============================================================================

function AuctionEngine.EnterInfoReveal(round)
    -- 重置本轮信息揭示计时器（防止跨轮/跨局累积导致立即触发15秒超时）
    engine._infoRevealElapsed = 0

    -- 每轮开始重置道具使用限制
    PropSystem.ResetRoundUsage()

    _GameState.StartInfoReveal(round)
    local infos = _InfoSystem.GetRoundInfos(round)
    if engine.onInfoRevealed and infos then
        engine.onInfoRevealed(round, infos.publics, infos.skills)
    end

    -- 无头模式：用固定延迟替代动画队列驱动
    if engine.headless then
        engine.headlessDelay = engine.INFO_REVEAL_DURATION
    end
end

-- ============================================================================
-- 回调设置
-- ============================================================================

function AuctionEngine.SetOnInfoRevealed(fn)   engine.onInfoRevealed = fn end
function AuctionEngine.SetOnBidRevealed(fn)    engine.onBidRevealed = fn end
function AuctionEngine.SetOnJudgeResult(fn)    engine.onJudgeResult = fn end
function AuctionEngine.SetOnItemRevealed(fn)   engine.onItemRevealed = fn end
function AuctionEngine.SetOnBidPlaced(fn)      engine.onBidPlaced = fn end
function AuctionEngine.SetOnWarehouseOpen(fn)  engine.onWarehouseOpen = fn end
function AuctionEngine.SetOnGameOver(fn)       engine.onGameOver = fn end
function AuctionEngine.SetOnTiebreakStart(fn)  engine.onTiebreakStart = fn end
function AuctionEngine.SetOnAISealedBidConfirmed(fn) engine.onAISealedBidConfirmed = fn end

--- 设置无头模式（服务端无 UI，阶段推进由定时器驱动）
function AuctionEngine.SetHeadless(val)
    engine.headless = val
end

-- 暗标阶段能否出价
function AuctionEngine.CanSealedBid()
    return _GameState.GetPhase() == _GameState.PHASE.SEALED_BID
end

-- 实时竞拍能否出价
function AuctionEngine.CanTiebreakBid()
    return engine.bidCooldown <= 0
        and _GameState.GetPhase() == _GameState.PHASE.TIEBREAK_BID
        and _GameState.IsTiebreakParticipant(1)
end

-- UI 通知出价揭示动画全部完成
function AuctionEngine.FinishBidReveal()
    engine.bidRevealDone = true
end

-- 跳过开箱动画：一次性揭示所有剩余物品
function AuctionEngine.SkipWarehouseOpen()
    if _GameState.GetPhase() ~= _GameState.PHASE.WAREHOUSE_OPEN then return end
    local items = _GameState.GetWarehouseItems()
    while _GameState.GetRevealedItemIndex() < #items do
        local hasMore = _GameState.RevealNextItem()
        if hasMore and engine.onItemRevealed then
            local idx = _GameState.GetRevealedItemIndex()
            engine.onItemRevealed(idx, items[idx])
        end
        if not hasMore then break end
    end
    -- 结算资金 → 进入 GAME_OVER
    _GameState.SettleWarehouseValue()
    engine.phaseDelay = 0
    _GameState.SetPhase(_GameState.PHASE.GAME_OVER)
    if engine.onGameOver and not engine.gameOverFired then
        engine.gameOverFired = true
        engine.onGameOver()
    end
end

-- Debug: 跳过当前阶段倒计时
function AuctionEngine.DebugSkipTimer()
    engine.phaseDelay = 0
    _GameState.SetTimer(0)
end

-- Debug: 强制进入实时竞拍阶段（制造第5轮平局）
function AuctionEngine.DebugEnterTiebreak()
    local players = _GameState.GetPlayers()
    if not players or #players < 2 then return end

    -- 跳到第5轮
    _GameState.StartInfoReveal(5)

    -- 所有人出相同价，制造平局
    local tieBid = 10000
    for idx = 1, #players do
        _GameState.PlaceSealedBid(idx, tieBid)
    end
    _GameState.FinalizeSealedBids()

    -- 执行判定（会检测到平局）
    _GameState.PerformJudgment()

    -- 进入竞拍
    _GameState.SetupTiebreak()
    engine.phaseDelay = 0
    if engine.onTiebreakStart then
        engine.onTiebreakStart(_GameState.GetTiebreakPlayers())
    end

    print("[Debug] Forced tiebreak with bid=" .. tieBid)
end

return AuctionEngine
