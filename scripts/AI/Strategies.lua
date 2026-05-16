-- ============================================================================
-- AI/Strategies.lua - AI 出价策略（意图判定 + 角色策略 + 数字风格化）
-- 从 AIPlayer.lua 提取的纯计算逻辑，无内部状态
-- ============================================================================

local Config = require("Config")
local Props = require("Config.Props")

local Strategies = {}

-- ============================================================================
-- 依赖注入（多房间隔离时由 RoomInstance 注入正确的实例）
-- ============================================================================

local _GameState = nil
local _InfoSystem = nil
local _EstimateValue = nil

--- 注入依赖（必须在使用前调用）
---@param gameState table GameState 模块
---@param infoSystem table InfoSystem 模块
---@param estimateValue table EstimateValue 模块
function Strategies.InjectDeps(gameState, infoSystem, estimateValue)
    _GameState = gameState
    _InfoSystem = infoSystem
    _EstimateValue = estimateValue
end

-- ============================================================================
-- 出价意图枚举
-- ============================================================================

Strategies.INTENT = {
    COMPETE     = "compete",
    RESIGN      = "resign",
    BLUFF       = "bluff",
    PUMP        = "pump",
    DESPERATION = "desperation",
}

local INTENT = Strategies.INTENT

-- ============================================================================
-- 弃权数字库
-- ============================================================================

local RESIGN_NUMBERS = {
    meme = { 886, 1314, 6666, 8888, 2333, 9999, 5555, 7777 },
    cute = { 520, 1314, 2333, 666, 888, 1024, 3344 },
    silent = { 0 },
}

--- 从弃权数字库中随机选一个
---@param style string "meme"|"cute"|"silent"
---@return number
local function pickResignNumber(style)
    local pool = RESIGN_NUMBERS[style] or RESIGN_NUMBERS.meme
    return pool[math.random(1, #pool)]
end

-- ============================================================================
-- 数字风格化（第三层）
-- ============================================================================

--- 将计算出的出价数字风格化为"人味"数字
---@param amount number 原始出价
---@param style string "precise"|"round"|"lucky"
---@return number 风格化后的出价
function Strategies.StylizeNumber(amount, style)
    if amount <= 0 then return 0 end

    if style == "round" then
        if amount >= 10000 then
            if math.random() < 0.7 then
                return math.floor(amount / 10000 + 0.5) * 10000
            else
                return math.floor(amount / 5000 + 0.5) * 5000
            end
        end
        return math.floor(amount / 1000 + 0.5) * 1000

    elseif style == "lucky" then
        local base = math.floor(amount / 1000) * 1000
        local choices = { base, base + 888, base - 112 }
        if amount >= 50000 and math.random() < 0.3 then
            local wan = math.floor(amount / 10000)
            local lucky = wan * 10000 + 8888
            if math.abs(lucky - amount) < amount * 0.15 then
                return lucky
            end
        end
        local best = base
        local bestDist = math.abs(base - amount)
        for _, c in ipairs(choices) do
            if c > 0 then
                local d = math.abs(c - amount)
                if d < bestDist then best = c; bestDist = d end
            end
        end
        return math.max(best, 0)

    else -- "precise"
        return math.floor(amount / 1000) * 1000
    end
end

-- ============================================================================
-- 对手行为分析（前置声明，供 DecideIntent 和 CalculateBid 使用）
-- ============================================================================

--- 分析所有对手的出价行为模式
--- 识别已弃权玩家、出价趋势、竞争强度
---@param round number 当前轮次
---@param playerIdx number 当前 AI 的索引
---@return table opponentInfo { activeCount, resignedCount, maxThreatBid, bidTrend, competitionLevel }
local function analyzeOpponents(round, playerIdx)
    local result = {
        activeCount = 0,      -- 仍在竞争的对手数量
        resignedCount = 0,    -- 已弃权的对手数量
        maxThreatBid = 0,     -- 最大威胁出价
        bidTrend = 0,         -- 出价趋势 (-1下降, 0平稳, +1上升)
        competitionLevel = 0.5, -- 竞争激烈程度 (0低, 1高)
    }

    local roundBids = _GameState.GetRoundBids()
    local players = _GameState.GetPlayers()
    if not players then return result end

    -- 统计上一轮各对手的出价状态
    local totalOthers = 0
    for idx, player in ipairs(players) do
        if idx ~= playerIdx then
            totalOthers = totalOthers + 1
        end
    end

    if round < 2 then
        -- 第1轮无历史数据，假设全部活跃
        result.activeCount = totalOthers
        result.competitionLevel = 0.5
        return result
    end

    -- 识别弃权玩家：连续出低价（<1000）或出0视为弃权
    local resignedSet = {}
    local RESIGN_THRESHOLD = 10000  -- 出价低于此值视为弃权意图

    if roundBids[round - 1] then
        for idx, bid in pairs(roundBids[round - 1]) do
            if idx ~= playerIdx then
                if bid < RESIGN_THRESHOLD then
                    -- 检查是否连续弃权（至少2轮低出价）
                    if round >= 3 and roundBids[round - 2] then
                        local prevBid = roundBids[round - 2][idx] or 0
                        if prevBid < RESIGN_THRESHOLD then
                            resignedSet[idx] = true
                        end
                    end
                    -- 单轮出0或出弃权梗数字也视为弃权
                    if bid == 0 or bid < 1000 then
                        resignedSet[idx] = true
                    end
                end
            end
        end
    end

    result.resignedCount = 0
    for _ in pairs(resignedSet) do
        result.resignedCount = result.resignedCount + 1
    end
    result.activeCount = totalOthers - result.resignedCount

    -- 计算活跃对手的最大威胁出价和出价趋势
    local prevMaxBid = 0
    local prevPrevMaxBid = 0

    if roundBids[round - 1] then
        for idx, bid in pairs(roundBids[round - 1]) do
            if idx ~= playerIdx and not resignedSet[idx] and bid > result.maxThreatBid then
                result.maxThreatBid = bid
            end
            if idx ~= playerIdx and not resignedSet[idx] and bid > prevMaxBid then
                prevMaxBid = bid
            end
        end
    end

    if round >= 3 and roundBids[round - 2] then
        for idx, bid in pairs(roundBids[round - 2]) do
            if idx ~= playerIdx and not resignedSet[idx] and bid > prevPrevMaxBid then
                prevPrevMaxBid = bid
            end
        end
    end

    -- 出价趋势：最近两轮最高出价的变化
    if prevPrevMaxBid > 0 and prevMaxBid > 0 then
        local change = (prevMaxBid - prevPrevMaxBid) / prevPrevMaxBid
        result.bidTrend = math.max(-1.0, math.min(1.0, change * 2))
    end

    -- 竞争激烈程度：活跃对手比例 × 出价集中度
    if totalOthers > 0 then
        local activeRatio = result.activeCount / totalOthers
        result.competitionLevel = activeRatio
        -- 如果出价趋势上升，竞争更激烈
        if result.bidTrend > 0 then
            result.competitionLevel = math.min(1.0, result.competitionLevel + result.bidTrend * 0.2)
        end
    end

    -- 道具使用置信度修正：
    -- 上一轮若有对手使用了道具且出高价，说明对方可能掌握更多仓库信息，
    -- 置信度按道具品质（tier）× 效果类型（effectType）双维度加权
    result.usedPropHighBid = 0
    result.usedPropCount = 0
    result.propConfidenceBoost = 0  -- 对威胁出价的置信度加权 [0, 0.4]

    -- 品质基础权重：品质越高 → 道具信息越精确 → 置信度越高
    local TIER_WEIGHT = {
        white  = 0.04,   -- 初级道具，信息粗糙
        green  = 0.08,   -- 中级道具，信息适中
        blue   = 0.13,   -- 蓝色道具
        purple = 0.20,   -- 紫色道具，信息精准（如大件估价器）
        red    = 0.30,   -- 红色道具（预留）
    }

    -- 效果类型修正系数：信息含量越高 → 系数越大
    local EFFECT_MULT = {
        [Props.EFFECT.SHOW_RARITY_CELL_COUNT]  = 0.6,  -- 只知道格数，间接推断
        [Props.EFFECT.SHOW_RARITY_ITEM_COUNT]  = 0.8,  -- 知道件数，略优
        [Props.EFFECT.SHOW_RANDOM_SILHOUETTE]  = 1.0,  -- 知轮廓（L1），直接揭示
        [Props.EFFECT.SHOW_RARITY_AVG_VALUE]   = 1.2,  -- 知某品质均价，定价信息
        [Props.EFFECT.SHOW_RANDOM_ITEM_INFO]   = 1.4,  -- 知一件物品详情（L2），精确
        [Props.EFFECT.SHOW_SIZE_AVG_VALUE]     = 1.6,  -- 知大件均价，针对高价物品
    }

    if round >= 2 and _GameState then
        local roundPropUsage = _GameState.GetRoundPropUsage()
        local prevPropUsage = roundPropUsage and roundPropUsage[round - 1]
        local prevBids = _GameState.GetRoundBids()[round - 1]

        if prevPropUsage and prevBids then
            local totalBoost = 0
            for idx, usage in pairs(prevPropUsage) do
                if idx ~= playerIdx then
                    result.usedPropCount = result.usedPropCount + 1
                    local bid = prevBids[idx] or 0
                    -- 出价高于最大威胁出价的 70%，视为"高价 + 用了道具"
                    if result.maxThreatBid > 0 and bid >= result.maxThreatBid * 0.7 then
                        result.usedPropHighBid = result.usedPropHighBid + 1

                        -- 按道具品质和效果类型计算本次贡献
                        local def = Props.BY_ID[usage.id]
                        local tierW  = (def and TIER_WEIGHT[def.tier]) or TIER_WEIGHT.white
                        local effMul = (def and EFFECT_MULT[def.effectType]) or 1.0
                        totalBoost = totalBoost + tierW * effMul
                    end
                end
            end

            -- 累加所有高价+道具对手的贡献，上限 0.4
            result.propConfidenceBoost = math.min(0.4, totalBoost)
        end
    end

    return result
end

--- 公开接口，供外部（AIPlayer）调用
Strategies.AnalyzeOpponents = analyzeOpponents

-- ============================================================================
-- 第一层：意图判定
-- ============================================================================

--- 判定 AI 本轮的出价意图
--- 弃权基于价值判断（"这仓库不值得"），而非资金是否充裕
--- 改进：利用质量信号和对手分析做更智能的决策
---@param playerIdx number
---@param player table
---@param round number
---@param estimate number 该 AI 的估值（已锚定 expectedValue）
---@param pumpActive table { [playerIdx] = true }
---@param expectedValue number 区域期望值（行业常识）
---@param analysis table|nil 质量分析结果 { qualitySignal, ... }
---@return string intent
---@return table pumpActive (可能被修改)
function Strategies.DecideIntent(playerIdx, player, round, estimate, pumpActive, expectedValue, analysis)
    local p = player.personality
    if not p then return INTENT.COMPETE, pumpActive end

    local maxRounds = Config.GAME.MaxRounds

    -- 对手分析
    local opponentInfo = analyzeOpponents(round, playerIdx)

    -- 弃权判定：基于质量信号而非 estimate/expectedValue 比值
    -- （因为 expectedValue 是行情标价，可能远高于实际仓库价值，比值无意义）
    -- 有足够信息时，质量差的仓库更容易放弃
    if round >= 2 and analysis and analysis.revealedCount >= 2 then
        -- 仓库质量很差（负质量信号）→ 有概率弃权
        local qualitySignal = analysis.qualitySignal
        local resignThreshold = p.resignThreshold

        -- qualitySignal < -0.3 说明揭示的物品品质/价值明显低于池均价
        if qualitySignal < -(1.0 - resignThreshold) then
            return INTENT.RESIGN, pumpActive
        end
    end

    -- 观察前几轮出价：对手出价远超估值时考虑弃权
    -- 改进：考虑活跃对手数量，仅1个对手时更愿意坚持
    local roundBids = _GameState.GetRoundBids()
    if round >= 3 then
        local prevBids = roundBids[round - 1]
        if prevBids then
            -- 用对手分析的最大威胁出价
            local maxOtherBid = opponentInfo.maxThreatBid

            if maxOtherBid > estimate * 1.2 and round < maxRounds then
                local resignChance = 0.30 - (round - 3) * 0.10
                -- 竞争少时更愿意坚持（只剩1个对手）
                if opponentInfo.activeCount <= 1 then
                    resignChance = resignChance * 0.5
                end
                -- 仓库质量好时更不愿放弃
                if analysis and analysis.qualitySignal > 0.3 then
                    resignChance = resignChance * 0.6
                end
                if math.random() < math.max(resignChance, 0.05) then
                    return INTENT.RESIGN, pumpActive
                end
            end
        end
    end

    -- 孤注一掷判定（赌徒型在最后一轮可能搏一把）
    if p.style == "gambler" and round >= maxRounds then
        -- 质量信号好时更倾向孤注一掷
        local despThreshold = 0.5
        if analysis and analysis.qualitySignal and analysis.qualitySignal > 0.2 then
            despThreshold = 0.65
        end
        -- 质量信号非负（仓库不差）时才考虑搏一把
        local qualOk = (not analysis) or (not analysis.qualitySignal) or (analysis.qualitySignal >= -0.2)
        if qualOk then
            if math.random() < despThreshold then return INTENT.DESPERATION, pumpActive end
        end
    end

    -- 抬价判定（前2轮可能抬价）
    if round <= 2 and p.pumpTendency > 0 then
        if math.random() < p.pumpTendency then
            pumpActive[playerIdx] = true
            return INTENT.PUMP, pumpActive
        end
    end
    -- 抬价后：有概率弃权退出
    -- 改进：如果抬价期间发现仓库质量好，更倾向转为竞争
    if pumpActive[playerIdx] and round >= 3 then
        pumpActive[playerIdx] = nil
        local stayChance = 0.50  -- 基础50%转为竞争
        if analysis and analysis.qualitySignal > 0.2 then
            stayChance = 0.70  -- 仓库好 → 70%留下竞争
        end
        if math.random() > stayChance then
            return INTENT.RESIGN, pumpActive
        end
    end

    -- 恐吓判定
    if round <= 2 and p.bluffTendency > 0 then
        if math.random() < p.bluffTendency then
            return INTENT.BLUFF, pumpActive
        end
    end
    if round >= 3 and p.bluffTendency > 0 then
        if math.random() < p.bluffTendency * 0.3 then
            return INTENT.BLUFF, pumpActive
        end
    end

    return INTENT.COMPETE, pumpActive
end

-- ============================================================================
-- 倍率感知：估算最低获胜出价（前置声明，供 baseCompeteBid 和策略函数使用）
-- ============================================================================

--- 估算当前轮次的"第二高出价"（用于计算最低获胜线）
--- 改进：过滤弃权对手、利用出价趋势建模
---@param round number 当前轮次
---@param playerIdx number 当前 AI 的索引
---@param expectedValue number 区域期望值
---@param estimate number AI 基于自身信息的仓库估值
---@param opponentInfo table|nil 对手分析结果
---@return number estimatedSecondBid 预估第二高出价
local function estimateSecondBid(round, playerIdx, expectedValue, estimate, opponentInfo)
    -- estimate 本身已融合 prior(poolAvg*itemCount) + 数据驱动
    -- 第1轮 fallback 直接用 estimate * ratio；有历史出价时用实际出价
    local infoModifier = 1.0

    local roundBids = _GameState.GetRoundBids()

    if round >= 2 and roundBids[round - 1] then
        -- 收集活跃对手的出价（排除弃权者）
        local activeBids = {}
        local resignedSet = {}

        -- 构建弃权集合
        if opponentInfo and opponentInfo.resignedCount > 0 then
            local RESIGN_THRESHOLD = 10000
            for idx, bid in pairs(roundBids[round - 1]) do
                if idx ~= playerIdx and (bid == 0 or bid < 1000) then
                    resignedSet[idx] = true
                elseif idx ~= playerIdx and bid < RESIGN_THRESHOLD and round >= 3 and roundBids[round - 2] then
                    local prevBid = roundBids[round - 2][idx] or 0
                    if prevBid < RESIGN_THRESHOLD then
                        resignedSet[idx] = true
                    end
                end
            end
        end

        for idx, bid in pairs(roundBids[round - 1]) do
            if idx ~= playerIdx and bid > 0 and not resignedSet[idx] then
                activeBids[#activeBids + 1] = bid
            end
        end
        table.sort(activeBids, function(a, b) return a > b end)

        if #activeBids >= 1 then
            -- 基础递增 10%~20%
            local escalation = 1.10 + math.random() * 0.10

            -- 利用出价趋势调整递增：上升趋势 → 对手可能出更多
            if opponentInfo and opponentInfo.bidTrend > 0.2 then
                escalation = escalation + opponentInfo.bidTrend * 0.08
            elseif opponentInfo and opponentInfo.bidTrend < -0.2 then
                escalation = escalation - 0.05  -- 下降趋势 → 对手可能减速
            end

            -- 道具置信度修正：上轮有对手用道具且出高价 → 对其出价更认真
            -- 逻辑：用了道具还出高价，说明对方可能真的掌握更多信息
            -- 但也有虚张声势可能，所以只加 propConfidenceBoost 的 50% 作为保守估计
            if opponentInfo and opponentInfo.propConfidenceBoost and opponentInfo.propConfidenceBoost > 0 then
                escalation = escalation + opponentInfo.propConfidenceBoost * 0.5
                print("[Strategies] propConfidenceBoost=" .. string.format("%.2f", opponentInfo.propConfidenceBoost)
                    .. " usedPropHighBid=" .. (opponentInfo.usedPropHighBid or 0)
                    .. " → escalation+" .. string.format("%.2f", opponentInfo.propConfidenceBoost * 0.5))
            end

            -- 加权：最近轮次的最高出价权重大，如有两轮数据则混合
            local latestMax = activeBids[1]

            if round >= 3 and roundBids[round - 2] then
                local prevActiveBids = {}
                for idx, bid in pairs(roundBids[round - 2]) do
                    if idx ~= playerIdx and bid > 0 and not resignedSet[idx] then
                        prevActiveBids[#prevActiveBids + 1] = bid
                    end
                end
                table.sort(prevActiveBids, function(a, b) return a > b end)
                if #prevActiveBids >= 1 then
                    -- 70% 权重给最近轮次, 30% 给前一轮
                    latestMax = latestMax * 0.7 + prevActiveBids[1] * 0.3
                end
            end

            return latestMax * escalation * infoModifier
        end
    end

    -- 第1轮或无活跃对手：基于估值推算
    local typicalBidRatio = 0.55
    -- 竞争低时预估也低
    if opponentInfo and opponentInfo.competitionLevel < 0.3 then
        typicalBidRatio = 0.45
    end
    return estimate * typicalBidRatio * infoModifier
end

--- 计算当前轮次的最低获胜出价
---@param round number
---@param playerIdx number
---@param expectedValue number
---@param estimate number AI 基于自身信息的仓库估值
---@param opponentInfo table|nil 对手分析结果
---@return number minWinBid 最低获胜线
---@return number multiplier 当前轮倍率
---@return number estSecond 预估第二高出价
local function calcMinWinBid(round, playerIdx, expectedValue, estimate, opponentInfo)
    local multiplier = Config.GAME.Multipliers[round] or 1.0
    if round >= Config.GAME.MaxRounds then
        multiplier = 1.01
    end
    local estSecond = estimateSecondBid(round, playerIdx, expectedValue, estimate, opponentInfo)
    return estSecond * multiplier, multiplier, estSecond
end

-- ============================================================================
-- 第二层：策略计算（按角色类型）
-- ============================================================================

-- ============================================================================
-- 梭哈决策：AI 是否要在本轮全力追赢
-- ============================================================================

--- 判断 AI 是否决定在本轮梭哈（全力追赢）
--- 返回 true = 梭哈（追赢），false = 不梭哈（出综合价格等后面轮次）
---@param round number 当前轮次
---@param multiplier number 当前轮倍率
---@param compositePrice number 综合价格
---@param estimate number AI 估值
---@param minWinBid number 赢所需的最低出价
---@param player table 玩家对象
---@param opts table|nil { style, money }
---@return boolean
local function shouldAllIn(round, multiplier, compositePrice, estimate, minWinBid, player, opts)
    opts = opts or {}
    local style = opts.style or (player.personality and player.personality.style) or "default"
    local money = opts.money or player.money or 0
    local maxRounds = Config.GAME.MaxRounds

    -- 赢的代价超过 AI 估值 → 绝不梭哈（会亏本）
    if minWinBid > estimate then return false end

    -- 赢的代价超过持有资金 → 追不起
    if minWinBid > money then return false end

    -- 基础梭哈倾向：倍率越低越愿意梭哈
    -- ×2.0 → 基础概率 10%, ×1.6 → 25%, ×1.4 → 40%, ×1.2 → 60%, ×1.01 → 85%
    local baseProb
    if multiplier >= 2.0 then
        baseProb = 0.10
    elseif multiplier >= 1.6 then
        baseProb = 0.25
    elseif multiplier >= 1.4 then
        baseProb = 0.40
    elseif multiplier >= 1.2 then
        baseProb = 0.60
    else
        baseProb = 0.85
    end

    -- 轮次压力：越往后越急（剩余机会越少）
    local roundPressure = (round - 1) / math.max(maxRounds - 1, 1)  -- 0~1
    baseProb = baseProb + roundPressure * 0.20

    -- 仓库质量：估值远高于期望 → 更值得抢
    -- compositePrice 已经体现了估值，如果 compositePrice 接近 minWinBid 说明差价不大，值得追
    local gapRatio = minWinBid / math.max(compositePrice, 1)
    if gapRatio < 1.3 then
        -- 差价小于30%，追一追就够了
        baseProb = baseProb + 0.15
    elseif gapRatio > 2.0 then
        -- 差价太大，追起来代价高
        baseProb = baseProb - 0.20
    end

    -- 性格调整
    if style == "gambler" then
        baseProb = baseProb + 0.20      -- 赌徒爱梭哈
    elseif style == "grower" then
        if round <= 2 then
            baseProb = baseProb - 0.25  -- 成长型前期绝不梭哈
        else
            baseProb = baseProb + 0.10  -- 后期果断
        end
    elseif style == "banker" then
        baseProb = baseProb - 0.15      -- 银行家保守
    elseif style == "sniper" then
        -- 狙击手：只在特定轮次梭哈（第3轮或最后轮次附近）
        if round == 3 or round >= maxRounds - 1 then
            baseProb = baseProb + 0.15
        else
            baseProb = baseProb - 0.20
        end
    end

    -- 资金充裕度：钱多更敢追
    if money > 0 and minWinBid / money < 0.3 then
        baseProb = baseProb + 0.10  -- 追赢只需不到30%的钱，风险低
    end

    -- 信息置信度：避免"盲梭"
    -- confidence = 已知品质物品数 / 总物品数
    -- 信息不足时降低梭哈意愿，避免 AI 在不了解仓库时就全押
    local infoConf = (opts.analysis and opts.analysis.confidence) or 0
    if infoConf < 0.5 then
        -- conf=0.0 → penalty -0.50（几乎没信息，大幅降低）
        -- conf=0.2 → penalty -0.30
        -- conf=0.3 → penalty -0.20
        -- conf=0.5 → penalty  0（已知一半物品，足够判断）
        local infoPenalty = (0.5 - infoConf) * 1.0
        baseProb = baseProb - infoPenalty
    end

    -- 估值膨胀惩罚：当 estimate 远超区域期望值时降低梭哈意愿
    -- 红色等高方差品质物品可能导致 estimate 被极度拉高，
    -- 但大多数仓库（75%概率 junk/poor/normal）实际价值远低于估值
    -- 如果 estimate > 2× expectedValue，说明 AI 可能过度乐观
    local ev = opts.expectedValue or 0
    if ev > 0 and estimate > ev * 2.0 then
        -- ratio=2.0 → penalty 0.0;  ratio=3.0 → penalty -0.15
        -- ratio=4.0 → penalty -0.30; ratio=5.0+ → penalty -0.45
        local ratio = estimate / ev
        local inflationPenalty = math.min(0.45, (ratio - 2.0) * 0.15)
        baseProb = baseProb - inflationPenalty
    end

    baseProb = math.max(0.0, math.min(1.0, baseProb))
    return math.random() < baseProb
end

-- ============================================================================
-- 核心出价函数：底价 → 综合价格 → 梭哈判断
-- ============================================================================

--- 通用 compete 出价
--- 三阶段框架：
---   1. 底价 = expectedValue × 50%（保底参与价），信息上浮
---   2. 综合价格 = 底价和 AI 估值之间，按性格取位置
---   3. 梭哈判断：是否追赢（出到 minWinBid），否则出综合价格
--- 改进：加入对手建模和质量自适应
---@param estimate number AI 的估值（已随信息浮动，可高于或低于 expectedValue）
---@param player table 玩家对象
---@param round number 当前轮次
---@param expectedValue number 区域期望值
---@param playerIdx number AI 索引
---@param opts table|nil 策略定制 { floorRatio, positionLow, positionHigh, allInStyle, analysis }
---@return number
local function baseCompeteBid(estimate, player, round, expectedValue, playerIdx, opts)
    opts = opts or {}
    local p = player.personality
    local analysis = opts.analysis

    -- 优先使用调用方已计算的对手分析结果，避免重复计算
    local opponentInfo = opts.opponentInfo or analyzeOpponents(round, playerIdx)

    -- ========== 倍率感知缩放 ==========
    -- 高倍率轮次（×2.0）说明赢家要付出高昂代价，AI 不应出太高比例
    -- 低倍率轮次（×1.01）几乎原价成交，可以出接近估值的价格
    -- bidScale 将 estimate 缩放为"愿意出的有效估值"
    local roundMultiplier = Config.GAME.Multipliers[round] or 1.0
    if round >= Config.GAME.MaxRounds then roundMultiplier = 1.01 end
    local bidScale = 1.0 / (1.0 + (roundMultiplier - 1.0) * 2.0)

    -- ========== 信息置信度缩放 ==========
    -- infoWeight ∈ [0, 1]（来自 InfoEstimation，L3=1.0, L2=0.7, L1=0.3, L0=0）
    -- confidenceFactor 将出价意愿限制在"已知信息比例"内：
    --   无信息（infoWeight=0）→ confidenceFactor=0.40（仅按先验的40%出价）
    --   25% 覆盖         → confidenceFactor=0.55
    --   50% 覆盖         → confidenceFactor=0.70
    --   100% 覆盖        → confidenceFactor=1.00
    -- 公式：0.40 + infoWeight × 0.60，线性插值
    local infoWeight = (analysis and analysis.infoWeight) or 0
    local confidenceFactor = 0.40 + infoWeight * 0.60
    local effectiveEstimate = estimate * bidScale * confidenceFactor

    -- ========== 第一阶段：底价 ==========
    -- 底价基于原始 estimate，按倍率动态调整底价比例：
    -- 倍率高（×2.0）→ floorRatio 低（~0.30），赢家要付双倍不值得硬拼
    -- 倍率低（×1.01）→ floorRatio 高（~0.80），几乎原价成交，底价贴近估值
    -- bidScale 接近1时 floorRatio 接近0.80；bidScale 接近0.33时 floorRatio 接近0.40
    -- 低倍率轮次（sealed bid）底价贴近估值；高倍率轮次保持低底价
    local floorRatio = opts.floorRatio or (0.40 + bidScale * 0.40)  -- range: [0.40, 0.80]
    -- 底价不能超过 effectiveEstimate（有效估值上限）
    local floor = math.min(estimate * floorRatio, effectiveEstimate * 0.95)

    -- 竞争自适应底价：对手少时底价可以更低（更有可能低价捡漏）
    if opponentInfo.activeCount <= 1 and round >= 3 then
        floor = floor * 0.90  -- 仅1个活跃对手，底价下调10%
    elseif opponentInfo.competitionLevel > 0.8 then
        floor = floor * 1.05  -- 竞争非常激烈，底价上调5%
    end

    -- ========== 第二阶段：综合价格 ==========
    local posLow = opts.positionLow or p.bidLow
    local posHigh = opts.positionHigh or p.bidHigh
    local position = posLow + math.random() * (posHigh - posLow)

    -- 质量信号微调位置：好仓库偏激进，差仓库偏保守
    if analysis and analysis.revealedCount >= 2 then
        position = position + analysis.qualitySignal * 0.10
        position = math.max(0, math.min(1, position))
    end

    local compositePrice
    if effectiveEstimate >= floor then
        compositePrice = floor + (effectiveEstimate - floor) * position
    else
        compositePrice = floor * (0.90 + position * 0.10)
    end

    -- ========== 第三阶段：梭哈判断 ==========
    if expectedValue > 0 and playerIdx then
        local minWinBid, multiplier, estSecond = calcMinWinBid(round, playerIdx, expectedValue, estimate, opponentInfo)

        local allIn = shouldAllIn(round, multiplier, compositePrice, estimate, minWinBid, player, {
            style = opts.allInStyle or p.style,
            money = player.money,
            analysis = analysis,
            expectedValue = expectedValue,
        })

        if allIn then
            local margin = 1.02 + math.random() * 0.06
            local allInBid = minWinBid * margin
            allInBid = math.min(allInBid, estimate)
            -- 梭哈出价不超过持有资金（shouldAllIn 只检查 minWinBid，margin 会导致超出）
            allInBid = math.min(allInBid, player.money)
            return math.max(allInBid, compositePrice)
        end
    end

    -- 不梭哈：出综合价格，参考活跃对手出价微调
    local roundBids = _GameState.GetRoundBids()
    if round >= 2 and roundBids[round - 1] then
        local activeBids = {}
        for idx, bid in pairs(roundBids[round - 1]) do
            if idx ~= playerIdx and bid > 0 then
                activeBids[#activeBids + 1] = bid
            end
        end
        if #activeBids > 0 then
            table.sort(activeBids, function(a, b) return a > b end)
            local avgOther = 0
            for _, b in ipairs(activeBids) do avgOther = avgOther + b end
            avgOther = avgOther / #activeBids
            -- 竞争力追赶：差超过30%时上调
            if compositePrice < avgOther * 0.70 then
                local catchUp = 1.05 + math.random() * 0.10
                -- 竞争激烈时追赶更积极
                if opponentInfo.competitionLevel > 0.6 then
                    catchUp = catchUp + 0.05
                end
                compositePrice = compositePrice * catchUp
            end
        end
    end

    return compositePrice
end

--- 角色策略表
local strategyMap = {}

-- 顾千鹤（信息驱动型）
strategyMap["info_driven"] = function(estimate, player, round, playerIdx, aiInfoState, expectedValue, analysis, opponentInfo)
    local bid = baseCompeteBid(estimate, player, round, expectedValue, playerIdx, { analysis = analysis, opponentInfo = opponentInfo })

    if aiInfoState then
        local knownCount = 0
        for _ in pairs(aiInfoState.itemRevealLevels) do knownCount = knownCount + 1 end
        local items = _GameState.GetWarehouseItems()
        local total = items and #items or 1
        local knownRatio = knownCount / total
        if knownRatio > 0.5 then
            bid = bid * (1 + (knownRatio - 0.5) * 0.5)
        end
    end

    return bid
end

-- 沈惊鸿（博弈型）
strategyMap["gambler"] = function(estimate, player, round, playerIdx, aiInfoState, expectedValue, analysis, opponentInfo)
    local bid = baseCompeteBid(estimate, player, round, expectedValue, playerIdx, { analysis = analysis, opponentInfo = opponentInfo })

    local roundBids = _GameState.GetRoundBids()
    if round >= 2 and roundBids[round - 1] then
        local maxOtherBid = 0
        for idx, b in pairs(roundBids[round - 1]) do
            if idx ~= playerIdx and b > maxOtherBid then
                maxOtherBid = b
            end
        end
        if maxOtherBid > 0 then
            local targetBid = maxOtherBid * (1.05 + math.random() * 0.10)
            bid = math.max(bid, targetBid * 0.9)
            bid = math.min(bid, targetBid * 1.1)
        end
    end

    return bid
end

-- 苏巧巧（套利型）
strategyMap["arbitrage"] = function(estimate, player, round, playerIdx, aiInfoState, expectedValue, analysis, opponentInfo)
    local bid = baseCompeteBid(estimate, player, round, expectedValue, playerIdx, { analysis = analysis, opponentInfo = opponentInfo })
    return bid
end

-- 钱伯年（资金管理型）
-- 银行家特色：底价更低（45%），position 更保守，后期轮次通过 opts 渐进放开
strategyMap["banker"] = function(estimate, player, round, playerIdx, aiInfoState, expectedValue, analysis, opponentInfo)
    -- 银行家底价比标准低，前期保守，后期利息攒够后激进
    local floorRatio
    if round <= 2 then
        floorRatio = 0.42  -- 前期特别保守
    elseif round == 3 then
        floorRatio = 0.48
    else
        floorRatio = 0.55  -- 后期攒了利息，愿意出更多
    end

    local bid = baseCompeteBid(estimate, player, round, expectedValue, playerIdx, {
        floorRatio = floorRatio,
        allInStyle = "banker",
        analysis = analysis,
        opponentInfo = opponentInfo,
    })

    -- 利息被动：前期利息收益好，稍微压低出价（等后面轮次更划算）
    local pe = player.character.passiveEffect
    if pe and pe.type == "interest" and round <= 2 then
        local interestGain = player.money * (pe.interestRate or 0)
        if interestGain > bid * 0.1 then
            bid = bid * 0.94
        end
    end

    return bid
end

-- 叶灵犀（成长型）
-- 成长型特色：前期底价压低攒资源，后期底价大幅提升，梭哈风格前期保守后期果断
strategyMap["grower"] = function(estimate, player, round, playerIdx, aiInfoState, expectedValue, analysis, opponentInfo)
    -- 成长型独特曲线：前期底价低，后期底价高于标准
    local floorRatio
    if round <= 1 then
        floorRatio = 0.38  -- 前期刻意压低
    elseif round == 2 then
        floorRatio = 0.44
    elseif round == 3 then
        floorRatio = 0.50
    elseif round == 4 then
        floorRatio = 0.58  -- 后期爆发
    else
        floorRatio = 0.65  -- 最后轮次最激进
    end

    return baseCompeteBid(estimate, player, round, expectedValue, playerIdx, {
        floorRatio = floorRatio,
        allInStyle = "grower",
        analysis = analysis,
        opponentInfo = opponentInfo,
    })
end

-- 陈老根（累积压力型）
strategyMap["veteran"] = function(estimate, player, round, playerIdx, aiInfoState, expectedValue, analysis, opponentInfo)
    local bid = baseCompeteBid(estimate, player, round, expectedValue, playerIdx, { analysis = analysis, opponentInfo = opponentInfo })
    return bid
end

-- 沈玉珂/吴鉴之（精准狙击型）
strategyMap["sniper"] = function(estimate, player, round, playerIdx, aiInfoState, expectedValue, analysis, opponentInfo)
    local bid = baseCompeteBid(estimate, player, round, expectedValue, playerIdx, { analysis = analysis, opponentInfo = opponentInfo })
    return bid
end

-- 赵铁柱（专精赌博型）
strategyMap["specialist"] = function(estimate, player, round, playerIdx, aiInfoState, expectedValue, analysis, opponentInfo)
    local bid = baseCompeteBid(estimate, player, round, expectedValue, playerIdx, {
        floorRatio = 0.42,
        allInStyle = "specialist",
        analysis = analysis,
        opponentInfo = opponentInfo,
    })
    return bid
end

-- ============================================================================
-- 第二层入口
-- ============================================================================

--- 根据意图和角色策略计算出价金额
---@param intent string 出价意图
---@param playerIdx number
---@param player table
---@param round number
---@param estimate number
---@param aiInfoState table|nil AI 的独立信息状态
---@param expectedValue number|nil 区域期望值（倍率感知用）
---@param analysis table|nil 质量分析结果（从 InfoEstimation.AnalyzeRevealed 获取）
---@return number
function Strategies.CalculateBid(intent, playerIdx, player, round, estimate, aiInfoState, expectedValue, analysis)
    local p = player.personality
    if not p then return 0 end

    if intent == INTENT.RESIGN then
        return pickResignNumber(p.resignStyle)
    end

    if intent == INTENT.BLUFF then
        local safeMax = estimate * (0.70 + math.random() * 0.20)
        local bluffMin = estimate * 0.50
        local bluffBid = bluffMin + math.random() * (safeMax - bluffMin)
        return math.max(bluffBid, 0)
    end

    -- 在入口计算一次对手分析，所有分支复用，避免重复调用
    local opponentInfo = analyzeOpponents(round, playerIdx)

    if intent == INTENT.PUMP then
        -- 抬价 + 倍率联动
        if expectedValue and expectedValue > 0 then
            local minWinBid, multiplier, estSecond = calcMinWinBid(round, playerIdx, expectedValue, estimate, opponentInfo)
            if multiplier >= 1.6 then
                local pumpBid = estSecond * (0.60 + math.random() * 0.20)
                return math.max(pumpBid, 0)
            end
        end
        local pumpBid = estimate * (0.55 + math.random() * 0.25)
        return math.max(pumpBid, 0)
    end

    if intent == INTENT.DESPERATION then
        -- 孤注一掷 + 倍率感知（上限为持有资金，避免被截断后多 AI 出价相同）
        local money = player.money or 0
        if expectedValue and expectedValue > 0 then
            local minWinBid = calcMinWinBid(round, playerIdx, expectedValue, estimate, opponentInfo)
            local desperationBid = estimate * (0.90 + math.random() * 0.30)
            desperationBid = math.min(math.max(desperationBid, minWinBid * 1.05), money)
            return desperationBid
        end
        local desperationRatio = 0.90 + math.random() * 0.30
        return math.min(estimate * desperationRatio, money)
    end

    -- 正常竞争：策略计算（将 analysis 和 opponentInfo 通过 opts 传递给 baseCompeteBid）
    local strategyFn = strategyMap[p.style]
    local baseBid
    if strategyFn then
        baseBid = strategyFn(estimate, player, round, playerIdx, aiInfoState, expectedValue, analysis, opponentInfo)
    else
        baseBid = baseCompeteBid(estimate, player, round, expectedValue, playerIdx, { analysis = analysis, opponentInfo = opponentInfo })
    end

    return baseBid
end

return Strategies
