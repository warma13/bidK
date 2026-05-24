-- ============================================================================
-- AIPlayer.lua - AI 玩家逻辑（三层出价架构：意图→策略→风格化）
-- ============================================================================

local Config = require("Config")
local PropSystem = require("PropSystem")
local _AIEstimateValue = require("AI.EstimateValue")  -- 用于每局重置动态权重

local AIPlayer = {}

-- ============================================================================
-- 依赖注入（多房间隔离时由 RoomInstance 注入正确的实例）
-- ============================================================================

local _GameState = nil
local _AntiCheat = nil
local _Strategies = nil
local _InfoEstimation = nil
local _EstimateValue = nil  -- 保留参数槽兼容旧注入调用，内部不再使用（底价改用新算法）

--- 注入依赖（必须在使用前调用）
---@param gameState table GameState 模块
---@param strategies table AI.Strategies 模块
---@param infoEstimation table AI.InfoEstimation 模块
---@param antiCheat table AntiCheat 模块
---@param estimateValue table EstimateValue 模块（保留兼容，暂不使用）
function AIPlayer.InjectDeps(gameState, strategies, infoEstimation, antiCheat, estimateValue)
    _GameState = gameState
    _Strategies = strategies
    _InfoEstimation = infoEstimation
    _AntiCheat = antiCheat
    _EstimateValue = estimateValue
end

local INTENT  -- 延迟初始化，在 InjectDeps 后才可用

-- ============================================================================
-- 内部状态
-- ============================================================================

local ai = {
    thinkTimers = {},           -- { [playerIdx] = remainingTime }
    thinkDecided = {},          -- { [playerIdx] = true }
    pendingCount = 0,           -- 尚未决策的 AI 数量（避免每帧全量遍历）
    cachedEstimates = {},       -- { [playerIdx] = SecureValue }

    -- 质量判断缓存
    cachedExpected = {},        -- { [playerIdx] = { expectedTotal, poolAvg, itemCount } }

    -- 每个 AI 的独立信息状态
    infoStates = {},            -- { [playerIdx] = { publicInfos, skillInfos, itemRevealLevels } }

    -- 跨轮次记忆
    pumpActive = {},            -- { [playerIdx] = true } 本局正在执行抬价策略
    lastIntents = {},           -- { [playerIdx] = "compete"|"resign"|... } 上轮意图

    -- 实时竞拍计时器
    tiebreakTimers = {},

}

-- ============================================================================
-- 初始化
-- ============================================================================

function AIPlayer.Init()
    INTENT = _Strategies.INTENT
    ai.thinkTimers = {}
    ai.thinkDecided = {}
    ai.pendingCount = 0
    ai.cachedEstimates = {}
    ai.cachedExpected = {}
    ai.infoStates = {}
    ai.pumpActive = {}
    ai.lastIntents = {}
    ai.tiebreakTimers = {}
    -- 每局开始重置估值模块：不同仓库的 warehouseValue 不同
    -- 动态权重依赖 warehouseValue，必须在新仓库 Init 时重新计算
    _AIEstimateValue.Reset()
end

-- ============================================================================
-- 暗标出价 - 开始思考
-- ============================================================================

function AIPlayer.StartSealedBidThinking(gameState, infoSystem)
    local players = gameState.GetPlayers()
    local round = gameState.GetCurrentRound()
    local expectedValue = gameState.GetExpectedValue()

    -- 获取当前仓库类型
    local whData = gameState.GetWarehouseData()
    local whTypeId = whData and whData.warehouseTypeId or nil

    ai.pendingCount = 0  -- 重置待决策计数

    -- 按轮次计算 AI 思考时间范围（思考时间 = 开局后经过多少秒触发出价）
    -- 第1轮(60s)：在倒计时50~20秒时出价 → 经过 10~40 秒
    -- 后续轮(30s)：在倒计时20~5秒时出价  → 经过 10~25 秒
    local thinkMin, thinkMax
    if round == 1 then
        local total = Config.GAME.FirstRoundSeconds
        thinkMin = total - 50   -- 10
        thinkMax = total - 20   -- 40
    else
        local total = Config.GAME.SealedBidSeconds
        thinkMin = total - 20   -- 10
        thinkMax = total - 5    -- 25
    end

    for idx, player in ipairs(players) do
        if not player.isHuman then
            -- 随机思考时间（在区间内均匀分布）
            ai.thinkTimers[idx] = thinkMin + math.random() * (thinkMax - thinkMin)
            ai.thinkDecided[idx] = false
            ai.pendingCount = ai.pendingCount + 1

            -- 预初始化 infoState，让道具注入有容器可写
            if not ai.infoStates[idx] then
                ai.infoStates[idx] = { publicInfos = {}, skillInfos = {}, itemRevealLevels = {} }
            end

            -- AI 先尝试使用道具（顺序重要：必须在 ComputeEstimate 之前，
            -- 这样道具揭示的信息可以被本轮估值利用）
            AIPlayer._TryUseAIProp(idx, player, round, gameState)

            -- 用 InfoEstimation 模块计算估值（以池均价为先验锚点）
            -- 此时 infoStates[idx].skillInfos 中已含本轮道具信息
            local ok, estimate, secureSv, expectedTotal, poolAvg, itemCount =
                pcall(_InfoEstimation.ComputeEstimate, idx, round, infoSystem, ai.infoStates, expectedValue, whTypeId)
            if ok then
                ai.cachedEstimates[idx] = secureSv
                ai.cachedExpected[idx] = { expectedTotal = expectedTotal, poolAvg = poolAvg, itemCount = itemCount }
            else
                -- ComputeEstimate 出错，记录错误并使用安全降级值
                print("[AIPlayer] ERROR ComputeEstimate failed for " .. player.name .. ": " .. tostring(estimate))
                local NewEV = require("AI.EstimateValue")
                local fallbackEstimate = NewEV.GetTierPriorValue(expectedValue) * 0.08  -- tier修正后的 8%
                ai.cachedEstimates[idx] = _AntiCheat.SecureValue(fallbackEstimate)
                ai.cachedExpected[idx] = { expectedTotal = fallbackEstimate, poolAvg = 0, itemCount = 0 }
            end

            local state = ai.infoStates[idx]
            if ok then
                print("[AIPlayer] " .. player.name .. " (round " .. round ..
                    ") estimate=" .. math.floor(estimate) ..
                    " expectedValue=" .. expectedValue ..
                    " whTypeId=" .. tostring(whTypeId) ..
                    " expectedTotal=" .. math.floor(expectedTotal) ..
                    " poolAvg=" .. math.floor(poolAvg) ..
                    " itemCount=" .. itemCount ..
                    " (infos: " .. #state.publicInfos .. " public, " ..
                    #state.skillInfos .. " skill)")
            end
        end
    end
end

--- AI 尝试在本轮使用一个道具
---@param playerIdx number
---@param player table
---@param round number
---@param gameState table
function AIPlayer._TryUseAIProp(playerIdx, player, round, gameState)
    -- 根据性格决定使用道具的概率（aggressiveness: 激进型更积极）
    local p = player.personality
    local style = p and p.style or "info_driven"
    local useProb
    if style == "gambler" or style == "specialist" then
        useProb = 0.75  -- 激进/专家：大概率用道具
    elseif style == "banker" or style == "veteran" then
        useProb = 0.55  -- 稳健/老手：中等概率
    else
        useProb = 0.40  -- 其余：较低概率
    end
    -- 后期轮次更积极使用道具
    if round >= 3 then useProb = math.min(useProb + 0.20, 0.95) end
    -- 高价值仓库额外提高使用概率（treasure/jackpot 几乎必用）
    local whData = gameState.GetWarehouseData and gameState.GetWarehouseData()
    local whTier = whData and whData.tier or "normal"
    local tierBoost = ({ trash=0, junk=0, poor=0.05, normal=0.10,
                         good=0.15, treasure=0.25, jackpot=0.35 })[whTier] or 0
    useProb = math.min(useProb + tierBoost, 0.97)

    if math.random() > useProb then return end

    -- 查询本轮是否有可用道具
    local ap, apIdx = gameState.GetAIAvailableProp(playerIdx, round)
    if not ap then return end

    local warehouseItems = gameState.GetWarehouseItems()
    local ok, info = PropSystem.UseForAI(ap.id, warehouseItems)
    if not ok then return end

    -- 记录使用
    gameState.MarkAIPropUsed(playerIdx, apIdx)
    gameState.RecordPropUsage(round, playerIdx, ap.id, ap.def.name)
    print("[AIPlayer] " .. player.name .. " used prop: " .. ap.def.name)

    -- 把道具揭示信息注入 skillInfos，让 ComputeEstimate 能利用它
    -- （注意：_TryUseAIProp 在 ComputeEstimate 之前调用，所以顺序是正确的）
    local state = ai.infoStates[playerIdx]
    if state and info then
        state.skillInfos[#state.skillInfos + 1] = info
        -- 如果道具有揭示物品（reveals），立即更新 itemRevealLevels
        if info.reveals then
            local levels = state.itemRevealLevels
            for _, r in ipairs(info.reveals) do
                local cur = levels[r.itemIdx] or 0
                if r.targetLevel > cur then
                    levels[r.itemIdx] = r.targetLevel
                end
            end
        end
        -- 如果是单件物品详细信息（revealedItem），更新到 L3
        if info.revealedItem and info.revealedItem.idx then
            local cur = state.itemRevealLevels[info.revealedItem.idx] or 0
            if 3 > cur then state.itemRevealLevels[info.revealedItem.idx] = 3 end
        end
        print("[AIPlayer] " .. player.name .. " prop info injected into skillInfos"
            .. (info.type == "random_avg_value" and (" sampleAvgValue=" .. tostring(info.sampleAvgValue)) or "")
            .. (info.reveals and (" reveals=" .. #info.reveals) or ""))
    end
end

-- ============================================================================
-- 暗标出价 - 每帧更新
-- ============================================================================

function AIPlayer.UpdateSealedBid(dt, gameState, placeBidFn)
    -- 所有 AI 均已决策则跳过，避免每帧全量遍历
    if ai.pendingCount <= 0 then return end

    local players = gameState.GetPlayers()

    for idx, player in ipairs(players) do
        if not player.isHuman and not ai.thinkDecided[idx] then
            ai.thinkTimers[idx] = (ai.thinkTimers[idx] or 0) - dt
            if ai.thinkTimers[idx] <= 0 then
                local bidAmount = AIPlayer.DecideSealedBid(idx, player, gameState.GetCurrentRound())
                placeBidFn(idx, bidAmount)
                ai.thinkDecided[idx] = true
                ai.pendingCount = ai.pendingCount - 1
            end
        end
    end
end

--- 玩家已出价，压缩所有未出价 AI 的思考时间到 0~5 秒内
function AIPlayer.OnPlayerBidConfirmed()
    if ai.pendingCount <= 0 then return end  -- 已全部决策，无需处理
    local MAX_REMAINING = 5.0
    for idx, decided in pairs(ai.thinkDecided) do
        if not decided and ai.thinkTimers[idx] then
            if ai.thinkTimers[idx] > MAX_REMAINING then
                ai.thinkTimers[idx] = math.random() * MAX_REMAINING
            end
        end
    end
end

-- ============================================================================
-- 暗标出价 - 三层决策入口
-- ============================================================================

function AIPlayer.DecideSealedBid(playerIdx, player, round)
    local personality = player.personality
    if not personality then return 0 end

    -- 从缓存的估值中读取（由 StartSealedBidThinking 中 ComputeEstimate 计算）
    local expectedValue = _GameState.GetExpectedValue()
    local svEst = ai.cachedEstimates[playerIdx]
    local NewEV = require("AI.EstimateValue")
    local estimate = svEst and svEst.get() or (NewEV.GetTierPriorValue(expectedValue) * 0.15)  -- 降级：tier修正后的 15%

    -- 从信息状态中提取质量分析（由 InfoEstimation.ComputeEstimate 缓存）
    local aiInfoState = ai.infoStates[playerIdx]
    local analysis = aiInfoState and aiInfoState.analysis or nil

    -- 第一层：意图判定（基于价值判断，不基于资金）
    local intent
    intent, ai.pumpActive = _Strategies.DecideIntent(playerIdx, player, round, estimate, ai.pumpActive, expectedValue, analysis)
    ai.lastIntents[playerIdx] = intent

    -- 第二层：策略计算（含倍率感知）
    local bidAmount = _Strategies.CalculateBid(intent, playerIdx, player, round, estimate, aiInfoState, expectedValue, analysis)

    -- 注意：质量乘数已移除。三阶段框架中 estimate 已反映仓库质量，
    -- 再叠加质量乘数会导致"仓库差"被惩罚两次。

    -- 加入随机波动 ±5%（仅竞争/恐吓/抬价意图，幅度缩小避免破底价）
    if intent == INTENT.COMPETE or intent == INTENT.BLUFF or intent == INTENT.PUMP then
        bidAmount = bidAmount * (0.95 + math.random() * 0.10)
    end

    -- 限制不超过持有资金
    bidAmount = math.min(bidAmount, player.money)
    bidAmount = math.max(bidAmount, 0)

    -- 第三层：数字风格化（仅非弃权意图）
    if intent ~= INTENT.RESIGN then
        bidAmount = _Strategies.StylizeNumber(bidAmount, personality.numberStyle)
    end

    -- 底价保护：必须在风格化之后执行，防止风格化将数字向下取整绕过保底
    -- 仅对 COMPETE 意图生效，其他意图（BLUFF/PUMP/RESIGN）不受此约束
    if intent == INTENT.COMPETE or intent == INTENT.PUMP then
        -- 底价保护：COMPETE + PUMP 意图均需底价兜底
        -- PUMP 意图在前两轮可能基于 estSecond（上轮出价的 60-80%）出价，
        -- 如果上轮出价本身很低，PUMP 出价会极低，需要底价保护。
        --
        -- 底价比例随信息完整度动态提升：
        --   infoWeight=0（无信息）→ estimate × 0.25（前两轮）/ 0.15（后期）
        --   infoWeight=1（全揭示）→ estimate × 0.50（前两轮）/ 0.40（后期）
        -- 前两轮信息少但不应出价过低，基线从 0.15 提高到 0.25
        local infoWeight = (aiInfoState and aiInfoState.infoWeight) or 0
        local baseFloorRatio = (round <= 2) and 0.25 or 0.15
        local floorRatio = baseFloorRatio + infoWeight * 0.25
        local absoluteFloor = estimate * floorRatio

        if absoluteFloor > 0 and bidAmount < absoluteFloor then
            -- 加入个性化浮动，避免所有 AI 在同一底价收敛到完全相同的数值。
            -- 在 [absoluteFloor, absoluteFloor + extraRange×0.5] 区间内按角色出价倾向取位置。
            local extraRange = math.max(estimate - absoluteFloor, absoluteFloor * 0.30)
            local position = personality.bidLow + math.random() * (personality.bidHigh - personality.bidLow)
            local newBid = absoluteFloor + extraRange * position * 0.5
            print("[AIPlayer] floor applied: bid " .. math.floor(bidAmount)
                .. " -> " .. math.floor(newBid)
                .. " (floor=" .. math.floor(absoluteFloor)
                .. " floorRatio=" .. string.format("%.2f", floorRatio)
                .. " infoWeight=" .. string.format("%.2f", infoWeight)
                .. " estimate=" .. math.floor(estimate)
                .. " position=" .. string.format("%.2f", position) .. ")")
            bidAmount = newBid
        end
    end

    -- 最终限制
    bidAmount = math.min(bidAmount, player.money)
    bidAmount = math.max(bidAmount, 0)

    -- 打印倍率信息（含质量信号和对手分析）
    local mul = Config.GAME.Multipliers[round] or 1.0
    if round >= Config.GAME.MaxRounds then mul = 1.01 end
    local qualStr = ""
    if analysis then
        qualStr = " quality=" .. string.format("%.2f", analysis.qualitySignal or 0)
            .. " revealed=" .. (analysis.revealedCount or 0)
    end
    print("[AIPlayer] " .. player.name .. " (round " .. round ..
        ") intent=" .. intent ..
        " estimate=" .. math.floor(estimate) ..
        " bid=" .. bidAmount ..
        " multiplier=x" .. mul .. qualStr)

    return bidAmount
end

-- ============================================================================
-- 实时竞拍（tiebreak）- 性格驱动多维度差异化
-- ============================================================================

--- 根据性格和价格接近度选择加价百分比
local function SelectBidPercent(personality, ratio)
    local style = personality and personality.style or "info_driven"
    local r = math.random()

    if style == "gambler" then
        -- 赌徒：激进，偏好大幅加价
        if r < 0.2 then return 0.01
        elseif r < 0.5 then return 0.05
        else return 0.10 end
    elseif style == "sniper" then
        -- 狙击手：精准，多用最小加价
        if ratio < 0.7 then
            return r < 0.7 and 0.01 or 0.05
        else
            return 0.01
        end
    elseif style == "banker" then
        -- 银行家：保守，早期可稍大，后期谨慎
        if ratio < 0.5 then
            return r < 0.4 and 0.01 or 0.05
        else
            return 0.01
        end
    elseif style == "veteran" then
        -- 老手：灵活多变
        if ratio < 0.5 then
            if r < 0.3 then return 0.01
            elseif r < 0.7 then return 0.05
            else return 0.10 end
        else
            return r < 0.7 and 0.01 or 0.05
        end
    elseif style == "grower" then
        -- 成长型：稳健，小步递增
        return r < 0.7 and 0.01 or 0.05
    elseif style == "specialist" then
        -- 专家：中等策略
        if r < 0.5 then return 0.01
        elseif r < 0.85 then return 0.05
        else return 0.10 end
    elseif style == "arbitrage" then
        -- 套利：快速小幅试探
        return r < 0.6 and 0.01 or 0.05
    else
        -- 默认（info_driven 等）：均衡
        if r < 0.5 then return 0.01
        elseif r < 0.85 then return 0.05
        else return 0.10 end
    end
end

--- 计算渐进式放弃概率（价格越接近心理上限，放弃概率越高）
local function CalcGiveUpProb(personality, ratio)
    local resignTendency = personality and personality.resignThreshold or 0.25

    if ratio < 0.5 then
        return 0.05
    elseif ratio < 0.7 then
        return 0.10 + resignTendency * 0.3
    elseif ratio < 0.85 then
        return 0.25 + resignTendency * 0.5
    elseif ratio < 0.95 then
        return 0.45 + resignTendency * 0.4
    else
        return 0.75 + resignTendency * 0.25
    end
end

--- 计算下次出价间隔（性格决定节奏，接近上限时犹豫变慢）
local function CalcNextTimer(personality, ratio, remainingTime)
    local style = personality and personality.style or "info_driven"
    local baseMin, baseMax

    if style == "gambler" then
        baseMin, baseMax = 1.0, 3.0       -- 冲动型，出手快
    elseif style == "sniper" then
        baseMin, baseMax = 2.5, 5.0       -- 等待型，精准出击
        -- 最后时刻狙击
        if remainingTime < 3.0 then
            baseMin, baseMax = 0.3, 1.0
        end
    elseif style == "banker" then
        baseMin, baseMax = 2.0, 4.5       -- 稳健有节奏
    elseif style == "veteran" then
        baseMin, baseMax = 1.5, 4.0       -- 经验丰富，节奏多变
    elseif style == "grower" then
        baseMin, baseMax = 2.0, 5.0       -- 耐心型
    elseif style == "specialist" then
        baseMin, baseMax = 1.5, 3.5       -- 适中
    elseif style == "arbitrage" then
        baseMin, baseMax = 1.0, 3.0       -- 快速试探
    else
        baseMin, baseMax = 1.5, 4.0       -- 默认
    end

    -- 接近上限时犹豫（出手变慢）
    if ratio > 0.7 then
        local slowdown = 1.0 + (ratio - 0.7) * 3.0
        baseMin = baseMin * slowdown
        baseMax = baseMax * slowdown
    end

    return baseMin + math.random() * (baseMax - baseMin)
end

function AIPlayer.UpdateTiebreak(dt, gameState, placeBidFn)
    local players = gameState.GetPlayers()
    local tiebreakPlayers = gameState.GetTiebreakPlayers()
    local currentBid = gameState.GetCurrentBid()
    local currentBidder = gameState.GetCurrentBidder()
    local timer = gameState.GetTimer()

    for _, idx in ipairs(tiebreakPlayers) do
        local player = players[idx]
        if not player.isHuman then
            -- 已是最高出价者，短暂后再检查
            if idx == currentBidder then
                ai.tiebreakTimers[idx] = 1.0
            else
                ai.tiebreakTimers[idx] = (ai.tiebreakTimers[idx] or 0) - dt
                if ai.tiebreakTimers[idx] <= 0 then
                    local svEst = ai.cachedEstimates[idx]
                    local estimate = svEst and svEst.get() or _GameState.GetExpectedValue()
                    local p = player.personality
                    local maxWilling = estimate * (p and p.tiebreakMaxRatio or 1.5)
                    local ratio = maxWilling > 0 and (currentBid / maxWilling) or 1.0

                    -- 根据性格选择加价百分比
                    local pct = SelectBidPercent(p, ratio)
                    local inc = Config.CalcBidIncrement(currentBid, pct)
                    local nextBid = currentBid + inc

                    -- 渐进式放弃概率
                    local giveUpProb = CalcGiveUpProb(p, ratio)

                    if nextBid <= maxWilling and nextBid <= player.money and math.random() > giveUpProb then
                        placeBidFn(idx, nextBid)
                        print("[AI Tiebreak] " .. player.name .. " bids " .. nextBid
                            .. " (+" .. math.floor(pct * 100) .. "%, ratio=" .. string.format("%.2f", ratio) .. ")")
                    else
                        print("[AI Tiebreak] " .. player.name .. " holds"
                            .. " (ratio=" .. string.format("%.2f", ratio)
                            .. ", giveUp=" .. string.format("%.0f%%", giveUpProb * 100) .. ")")
                    end

                    -- 动态出价间隔
                    ai.tiebreakTimers[idx] = CalcNextTimer(p, ratio, timer)
                end
            end
        end
    end
end

-- ============================================================================
-- 获取 AI 出价意图（供 UI 播放对应语音）
-- ============================================================================

--- 获取指定 AI 上一次的出价意图
---@param playerIdx number
---@return string|nil "compete"|"resign"|"bluff"|"pump"|"desperation"
function AIPlayer.GetLastIntent(playerIdx)
    return ai.lastIntents[playerIdx]
end

return AIPlayer
