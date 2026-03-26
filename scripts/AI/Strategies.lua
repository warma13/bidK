-- ============================================================================
-- AI/Strategies.lua - AI 出价策略（意图判定 + 角色策略 + 数字风格化）
-- 从 AIPlayer.lua 提取的纯计算逻辑，无内部状态
-- ============================================================================

local Config = require("Config")

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
-- 第一层：意图判定
-- ============================================================================

--- 判定 AI 本轮的出价意图
--- 弃权基于价值判断（"这仓库不值得"），而非资金是否充裕
---@param playerIdx number
---@param player table
---@param round number
---@param estimate number 该 AI 的估值（已锚定 expectedValue）
---@param pumpActive table { [playerIdx] = true }
---@param expectedValue number 区域期望值（行业常识）
---@return string intent
---@return table pumpActive (可能被修改)
function Strategies.DecideIntent(playerIdx, player, round, estimate, pumpActive, expectedValue)
    local p = player.personality
    if not p then return INTENT.COMPETE, pumpActive end

    local maxRounds = Config.GAME.MaxRounds
    local ev = expectedValue or 100000

    -- 弃权判定：估值远低于区域期望 → 认为这个仓库是垃圾，不值得竞争
    -- valueRatio < resignThreshold 表示"信息揭示后发现比预期差太多"
    local valueRatio = estimate / ev
    if round >= 2 and valueRatio < p.resignThreshold then
        return INTENT.RESIGN, pumpActive
    end

    -- 观察前几轮出价：别人出价远超估值时才考虑弃权
    -- 关键认知：高倍率轮次（×2.0, ×1.6）别人出高价反而不可怕，
    -- 因为倍率门槛会阻止他们获胜。AI 只需要维持自己的出价即可。
    -- 只有当别人出价超过估值的 120%（"他愿意亏本买"）且到了中后期轮次，
    -- 倍率降低后真的可能被赢走时，才考虑放弃。
    local roundBids = _GameState.GetRoundBids()
    if round >= 3 then
        local prevBids = roundBids[round - 1]
        if prevBids then
            local maxOtherBid = 0
            for idx, bid in pairs(prevBids) do
                if idx ~= playerIdx and bid > maxOtherBid then
                    maxOtherBid = bid
                end
            end
            -- 只在中后期（round>=3）且对手出价超过估值120%时才考虑弃权
            if maxOtherBid > estimate * 1.2 and round < maxRounds then
                -- 概率也降低：30%（越往后越不愿意退出）
                local resignChance = 0.30 - (round - 3) * 0.10
                if math.random() < math.max(resignChance, 0.10) then
                    return INTENT.RESIGN, pumpActive
                end
            end
        end
    end

    -- 孤注一掷判定（赌徒型在最后一轮可能搏一把）
    if p.style == "gambler" and round >= maxRounds then
        if valueRatio > 0.5 then
            if math.random() < 0.5 then return INTENT.DESPERATION, pumpActive end
        end
    end

    -- 抬价判定（前2轮可能抬价）
    if round <= 2 and p.pumpTendency > 0 then
        if math.random() < p.pumpTendency then
            pumpActive[playerIdx] = true
            return INTENT.PUMP, pumpActive
        end
    end
    -- 抬价后：有概率弃权退出，不再是必然弃权
    if pumpActive[playerIdx] and round >= 3 then
        pumpActive[playerIdx] = nil
        -- 50% 弃权退出，50% 转为正常竞争（也许抬到一半发现仓库真不错）
        if math.random() < 0.5 then
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
--- 综合三层信息：历史出价 + 博弈推算 + AI自身估值反推对手行为
---@param round number 当前轮次
---@param playerIdx number 当前 AI 的索引
---@param expectedValue number 区域期望值
---@param estimate number AI 基于自身信息的仓库估值
---@return number estimatedSecondBid 预估第二高出价
local function estimateSecondBid(round, playerIdx, expectedValue, estimate)
    local infoRatio = estimate / math.max(expectedValue, 1)
    local infoModifier = math.max(0.6, math.min(1.5, infoRatio))
    infoModifier = 1.0 + (infoModifier - 1.0) * 0.5

    local roundBids = _GameState.GetRoundBids()

    if round >= 2 and roundBids[round - 1] then
        local otherBids = {}
        for idx, bid in pairs(roundBids[round - 1]) do
            if idx ~= playerIdx and bid > 0 then
                otherBids[#otherBids + 1] = bid
            end
        end
        table.sort(otherBids, function(a, b) return a > b end)

        if #otherBids >= 1 then
            local escalation = 1.0 + 0.10 + math.random() * 0.10
            return otherBids[1] * escalation * infoModifier
        end
    end

    -- 第1轮或无历史数据：博弈推算
    -- 新框架下典型第1轮出价 ≈ expectedValue × 50%底价 + 少量position上浮 ≈ 55%
    local typicalBidRatio = 0.55
    return expectedValue * typicalBidRatio * infoModifier
end

--- 计算当前轮次的最低获胜出价
---@param round number
---@param playerIdx number
---@param expectedValue number
---@param estimate number AI 基于自身信息的仓库估值
---@return number minWinBid 最低获胜线
---@return number multiplier 当前轮倍率
---@return number estSecond 预估第二高出价
local function calcMinWinBid(round, playerIdx, expectedValue, estimate)
    local multiplier = Config.GAME.Multipliers[round] or 1.0
    if round >= Config.GAME.MaxRounds then
        multiplier = 1.01
    end
    local estSecond = estimateSecondBid(round, playerIdx, expectedValue, estimate)
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
---@param estimate number AI 的估值（已随信息浮动，可高于或低于 expectedValue）
---@param player table 玩家对象
---@param round number 当前轮次
---@param expectedValue number 区域期望值
---@param playerIdx number AI 索引
---@param opts table|nil 策略定制 { floorRatio, positionLow, positionHigh, allInStyle }
---@return number
local function baseCompeteBid(estimate, player, round, expectedValue, playerIdx, opts)
    opts = opts or {}
    local p = player.personality

    -- ========== 第一阶段：底价 ==========
    -- 底价 = expectedValue × floorRatio（性格微调的保底参与价）
    local floorRatio = opts.floorRatio or 0.50
    local floor = expectedValue * floorRatio

    -- 信息上浮底价：如果 estimate > expectedValue，说明信息显示仓库比平均好
    -- 用 estimate 中超出 expectedValue 的部分来上浮底价
    if estimate > expectedValue then
        local infoBonus = (estimate - expectedValue) * 0.30  -- 超出部分的30%上浮底价
        floor = floor + infoBonus
    end

    -- ========== 第二阶段：综合价格 ==========
    -- 在底价和 AI 估值之间取位置，性格决定偏向哪端
    -- positionLow=0 → 贴底价（保守），positionHigh=1 → 贴估值（激进）
    local posLow = opts.positionLow or p.bidLow
    local posHigh = opts.positionHigh or p.bidHigh
    local position = posLow + math.random() * (posHigh - posLow)

    -- 综合价格 = floor + (estimate - floor) × position
    -- 当 estimate > floor 时，综合价格在 floor 和 estimate 之间
    -- 当 estimate < floor 时，AI 认为仓库比预期差，但既然决定 COMPETE 就不低于底价
    local compositePrice
    if estimate >= floor then
        compositePrice = floor + (estimate - floor) * position
    else
        -- 信息显示仓库差：在底价附近微调（底价的 90%~100%），不会大幅下探
        -- 真正觉得不值的会在 DecideIntent 中选择 RESIGN
        compositePrice = floor * (0.90 + position * 0.10)
    end

    -- ========== 第三阶段：梭哈判断 ==========
    if expectedValue > 0 and playerIdx then
        local minWinBid, multiplier, estSecond = calcMinWinBid(round, playerIdx, expectedValue, estimate)

        local allIn = shouldAllIn(round, multiplier, compositePrice, estimate, minWinBid, player, {
            style = opts.allInStyle or p.style,
            money = player.money,
        })

        if allIn then
            -- 梭哈：出到 minWinBid 附近，但不超过 AI 估值
            local margin = 1.02 + math.random() * 0.06
            local allInBid = minWinBid * margin
            allInBid = math.min(allInBid, estimate)  -- 不超过估值（不亏本）
            -- 至少出综合价格（梭哈不可能比不梭哈低）
            return math.max(allInBid, compositePrice)
        end
    end

    -- 不梭哈：出综合价格，参考他人出价微调
    local roundBids = _GameState.GetRoundBids()
    if round >= 2 and roundBids[round - 1] then
        local otherBids = {}
        for idx, bid in pairs(roundBids[round - 1]) do
            if idx ~= playerIdx and bid > 0 then
                otherBids[#otherBids + 1] = bid
            end
        end
        if #otherBids > 0 then
            table.sort(otherBids, function(a, b) return a > b end)
            local avgOther = 0
            for _, b in ipairs(otherBids) do avgOther = avgOther + b end
            avgOther = avgOther / #otherBids
            -- 如果综合价格远低于他人平均（差超过30%），适当上调以保持竞争力
            if compositePrice < avgOther * 0.70 then
                compositePrice = compositePrice * (1.05 + math.random() * 0.10)
            end
        end
    end

    return compositePrice
end

--- 角色策略表
local strategyMap = {}

-- 顾千鹤（信息驱动型）
strategyMap["info_driven"] = function(estimate, player, round, playerIdx, aiInfoState, expectedValue)
    local bid = baseCompeteBid(estimate, player, round, expectedValue, playerIdx)

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

    -- 主动技能：全仓透视 reveal_top3
    local ch = player.character
    if ch.activeSkill and ch.activeSkill.effect == "reveal_top3" then
        local skillUses = _GameState.GetActiveSkillUses()[playerIdx] or 0
        if skillUses > 0 and round >= 2 then
            _GameState.UseActiveSkill(playerIdx)
            print("[AIPlayer] " .. player.name .. " uses reveal_top3!")

            -- 获取价值第2~4高的物品信息（跳过最高价值）
            local topItems = _InfoSystem.RevealTopItems(3, 1)

            -- 将揭示信息注入 AI 的信息状态（level 3 = 完全揭示）
            if aiInfoState and topItems then
                for _, info in ipairs(topItems) do
                    if info.revealedItem and info.revealedItem.idx then
                        aiInfoState.itemRevealLevels[info.revealedItem.idx] = 3
                    end
                end

                -- 基于新信息重算估值，以新估值调整出价
                local newEstMin = _EstimateValue.Calculate(aiInfoState)
                local evForCalc = expectedValue or _GameState.GetExpectedValue()
                local items = _GameState.GetWarehouseItems()
                local totalCount = items and #items or 1
                local newKnown = 0
                for _ in pairs(aiInfoState.itemRevealLevels) do newKnown = newKnown + 1 end

                local confidence = newKnown / totalCount
                local projected = newEstMin / math.max(confidence, 0.01)
                local blend = math.sqrt(confidence)
                local newEstimate = evForCalc * (1 - blend) + projected * blend

                print("[AIPlayer] " .. player.name .. " reveal_top3 → newEstimate="
                    .. math.floor(newEstimate) .. " (was " .. math.floor(estimate) .. ")")

                -- 用新估值重新计算出价
                bid = baseCompeteBid(newEstimate, player, round, expectedValue, playerIdx)
                -- 信息充分 → 可以更激进
                if confidence > 0.3 then
                    bid = bid * (1 + (confidence - 0.3) * 0.5)
                end
            end
        end
    end

    return bid
end

-- 沈惊鸿（博弈型）
strategyMap["gambler"] = function(estimate, player, round, playerIdx, aiInfoState, expectedValue)
    local bid = baseCompeteBid(estimate, player, round, expectedValue, playerIdx)

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

    local ch = player.character
    if ch.activeSkill and ch.activeSkill.effect == "all_in" then
        local skillUses = _GameState.GetActiveSkillUses()[playerIdx] or 0
        if skillUses > 0 and round >= 3 and estimate > 0 then
            if bid / estimate > 0.4 or round >= Config.GAME.MaxRounds then
                _GameState.UseActiveSkill(playerIdx)
                print("[AIPlayer] " .. player.name .. " uses all_in!")
            end
        end
    end

    return bid
end

-- 苏巧巧（套利型）
strategyMap["arbitrage"] = function(estimate, player, round, playerIdx, aiInfoState, expectedValue)
    local bid = baseCompeteBid(estimate, player, round, expectedValue, playerIdx)

    local pe = player.character.passiveEffect
    if pe and pe.type == "discount" then
        bid = bid * (1 + pe.discountRate)
    end

    return bid
end

-- 钱伯年（资金管理型）
-- 银行家特色：底价更低（45%），position 更保守，后期轮次通过 opts 渐进放开
strategyMap["banker"] = function(estimate, player, round, playerIdx, aiInfoState, expectedValue)
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
strategyMap["grower"] = function(estimate, player, round, playerIdx, aiInfoState, expectedValue)
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
    })
end

-- 陈老根（累积压力型）
-- 累积型特色：stacks 给予微小折扣（经验老道，知道"差不多就行"），但有下限保护
strategyMap["veteran"] = function(estimate, player, round, playerIdx, aiInfoState, expectedValue)
    local bid = baseCompeteBid(estimate, player, round, expectedValue, playerIdx)

    local stacks = _GameState.GetBidBoostStacks()[playerIdx] or 0
    if stacks > 0 then
        -- 每层 stacks 减 2%，最多减 10%（5 层封顶）
        local discount = math.min(stacks * 0.02, 0.10)
        bid = bid * (1 - discount)
    end

    return bid
end

-- 沈玉珂/吴鉴之（精准狙击型）
strategyMap["sniper"] = function(estimate, player, round, playerIdx, aiInfoState, expectedValue)
    local bid = baseCompeteBid(estimate, player, round, expectedValue, playerIdx)

    local bonus = _GameState.GetValueBonus(playerIdx)
    if bonus > 0 then
        bid = bid * (1 + bonus * 0.5)
    end

    return bid
end

-- 赵铁柱（专精赌博型）
-- 专精型特色：有专精加成时激进，没有时略保守但不会大幅砍价
strategyMap["specialist"] = function(estimate, player, round, playerIdx, aiInfoState, expectedValue)
    local bid
    local bonus = _GameState.GetValueBonus(playerIdx)
    if bonus > 0 then
        -- 有专精加成：底价标准，但出价更激进
        bid = baseCompeteBid(estimate, player, round, expectedValue, playerIdx, {
            floorRatio = 0.55,
            allInStyle = "specialist",
        })
        bid = bid * 1.20
    else
        -- 无专精加成：底价略低于标准，保守但不会砍半
        bid = baseCompeteBid(estimate, player, round, expectedValue, playerIdx, {
            floorRatio = 0.42,
            allInStyle = "specialist",
        })
    end

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
---@return number
function Strategies.CalculateBid(intent, playerIdx, player, round, estimate, aiInfoState, expectedValue)
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

    if intent == INTENT.PUMP then
        -- 抬价 + 倍率联动：高倍率轮次，精准卡位让对手无法达到倍率差距
        if expectedValue and expectedValue > 0 then
            local minWinBid, multiplier, estSecond = calcMinWinBid(round, playerIdx, expectedValue, estimate)
            if multiplier >= 1.6 then
                -- 高倍率轮次：出一个"不太低"的价格，让对手难以达到 2 倍差距
                -- 目标：出到预估第二名的 60~80%，抬高整体价位但不让自己赢
                local pumpBid = estSecond * (0.60 + math.random() * 0.20)
                return math.max(pumpBid, 0)
            end
        end
        local pumpBid = estimate * (0.55 + math.random() * 0.25)
        return math.max(pumpBid, 0)
    end

    if intent == INTENT.DESPERATION then
        -- 孤注一掷 + 倍率感知：确保出价能过线
        if expectedValue and expectedValue > 0 then
            local minWinBid = calcMinWinBid(round, playerIdx, expectedValue, estimate)
            local desperationBid = estimate * (0.90 + math.random() * 0.30)
            -- 至少要过获胜线
            return math.max(desperationBid, minWinBid * 1.05)
        end
        local desperationRatio = 0.90 + math.random() * 0.30
        return estimate * desperationRatio
    end

    -- 正常竞争：策略计算（倍率逻辑已内置在 baseCompeteBid 中）
    local strategyFn = strategyMap[p.style]
    local baseBid
    if strategyFn then
        baseBid = strategyFn(estimate, player, round, playerIdx, aiInfoState, expectedValue)
    else
        baseBid = baseCompeteBid(estimate, player, round, expectedValue, playerIdx)
    end

    return baseBid
end

-- ============================================================================
-- 公共：仓库质量乘数
-- ============================================================================

--- 根据期望估价与池均价的比值，计算质量乘数
--- 所有策略共用，在 AIPlayer 的出价流程中统一应用
---@param expectedTotal number 基于信息层级的期望总价值
---@param poolAvg number 池均价（单件）
---@param itemCount number 物品总数
---@param personality table 角色性格（需要 qualitySensUp, qualitySensDown）
---@return number multiplier 质量乘数 [0.5, 1.5]
function Strategies.ComputeQualityMultiplier(expectedTotal, poolAvg, itemCount, personality)
    if poolAvg <= 0 or itemCount <= 0 then return 1.0 end

    local qualityRatio = expectedTotal / (itemCount * poolAvg)
    local sensUp = personality.qualitySensUp or 0.3
    local sensDown = personality.qualitySensDown or 0.3

    local multiplier
    if qualityRatio >= 1.0 then
        multiplier = 1.0 + sensUp * (qualityRatio - 1.0)
    else
        -- sensDown 是正数，ratio < 1.0 时 (ratio - 1.0) 为负，乘数自然 < 1.0
        multiplier = 1.0 + sensDown * (qualityRatio - 1.0)
    end

    -- 限制范围
    return math.max(0.5, math.min(1.5, multiplier))
end

return Strategies
