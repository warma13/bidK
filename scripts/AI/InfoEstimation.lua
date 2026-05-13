-- ============================================================================
-- AI/InfoEstimation.lua - AI 信息状态管理 + 揭示等级更新
-- 从 AIPlayer.lua 提取，管理每个 AI 的独立信息视角
-- ============================================================================

local InfoEstimation = {}

-- ============================================================================
-- 依赖注入（多房间隔离时由 RoomInstance 注入正确的实例）
-- ============================================================================

local _NewEstimateValue = require("AI.EstimateValue")  -- 新估值模块（相对比例算法）
local _OldEstimateValue = nil  -- 旧估值模块（注入，仅保留兼容）
local _AntiCheat = nil
local _GameState = nil

--- 注入依赖（必须在使用前调用）
---@param estimateValue table EstimateValue 模块（旧模块，保留兼容）
---@param antiCheat table AntiCheat 模块
---@param gameState table|nil GameState 模块（用于质量分析）
function InfoEstimation.InjectDeps(estimateValue, antiCheat, gameState)
    _OldEstimateValue = estimateValue
    _AntiCheat = antiCheat
    _GameState = gameState
end

-- ============================================================================
-- 揭示等级更新
-- ============================================================================

--- 根据信息中的 reveals 字段更新 itemRevealLevels
--- 同时收集 L0V 技能信息中的已知批次总价值（knownLotValues）
---@param infoState table { publicInfos, skillInfos, itemRevealLevels }
function InfoEstimation.UpdateRevealLevels(infoState)
    local levels = infoState.itemRevealLevels

    local function applyReveals(info)
        if info.reveals then
            for _, r in ipairs(info.reveals) do
                local cur = levels[r.itemIdx] or 0
                if r.targetLevel > cur then
                    levels[r.itemIdx] = r.targetLevel
                end
            end
        end
        if info.revealedItem and info.revealedItem.idx then
            local cur = levels[info.revealedItem.idx] or 0
            if 3 > cur then levels[info.revealedItem.idx] = 3 end
        end
    end

    local function applyAll(info)
        applyReveals(info)
        if info.extraInfos then
            for _, extra in ipairs(info.extraInfos) do
                applyReveals(extra)
            end
        end
    end

    for _, info in ipairs(infoState.publicInfos) do applyAll(info) end
    for _, info in ipairs(infoState.skillInfos) do applyAll(info) end

    -- 收集 L0V 技能信息：knownTotalValue + coveredItemIdxs
    -- L0V = 某品质批次的精确总价（如"白绿蓝共14件，总价值X"）
    -- 这是一个硬约束下界：这些物品加总至少值 knownTotalValue
    local knownLotValues = {}
    local function collectL0V(info)
        if info.knownTotalValue and info.coveredItemIdxs and #info.coveredItemIdxs > 0 then
            knownLotValues[#knownLotValues + 1] = {
                totalValue = info.knownTotalValue,
                itemIdxs   = info.coveredItemIdxs,
            }
        end
        if info.extraInfos then
            for _, extra in ipairs(info.extraInfos) do
                collectL0V(extra)
            end
        end
    end
    -- L0V 仅来自技能信息（角色私有）
    for _, info in ipairs(infoState.skillInfos) do collectL0V(info) end
    infoState.knownLotValues = knownLotValues
end

-- ============================================================================
-- 质量分析：从已揭示物品中提取质量信号（供策略模块使用）
-- ============================================================================

--- 品质权重映射（越高权重表示越稀有/有价值）
local RARITY_WEIGHT = {
    white  = 1.0,
    green  = 2.0,
    blue   = 3.5,
    purple = 5.0,
    gold   = 8.0,
    red    = 12.0,
}
local EXPECTED_AVG_RARITY = 2.0  -- 物品池大致的平均品质权重

--- 分析已揭示物品的质量信号
--- 返回 qualitySignal（-1.0 ~ +1.0）表示仓库质量偏离预期的方向
---@param infoState table { publicInfos, skillInfos, itemRevealLevels }
---@return table analysis { qualitySignal, confidence, revealedCount, highRarityCount }
local function analyzeRevealed(infoState)
    local result = {
        qualitySignal = 0,
        confidence = 0,
        revealedCount = 0,
        highRarityCount = 0,
    }

    if not _GameState then return result end

    local items = _GameState.GetWarehouseItems()
    if not items or #items == 0 then return result end

    local revealLevels = infoState.itemRevealLevels or {}

    -- 收集已揭示物品的品质信息
    local rarityWeightSum = 0
    local rarityCount = 0
    local highRarityCount = 0

    for _, item in ipairs(items) do
        local level = revealLevels[item.idx] or 0

        if level >= 2 then
            -- L2+: 知道品质
            local w = RARITY_WEIGHT[item.rarity] or 1.0
            rarityWeightSum = rarityWeightSum + w
            rarityCount = rarityCount + 1
            if w >= 3.5 then -- blue 及以上
                highRarityCount = highRarityCount + 1
            end
        end
    end

    result.revealedCount = rarityCount
    result.highRarityCount = highRarityCount

    -- 计算品质信号：平均品质偏差（品质比预期好 → 正值）
    if rarityCount >= 1 then
        local avgRarity = rarityWeightSum / rarityCount
        local rarityDev = (avgRarity - EXPECTED_AVG_RARITY) / EXPECTED_AVG_RARITY
        result.qualitySignal = math.max(-1.0, math.min(1.0, rarityDev))
    end

    -- 分析置信度 = 揭示比例
    result.confidence = rarityCount / #items

    return result
end

-- 保持公开接口兼容（Strategies 模块可能引用）
InfoEstimation.AnalyzeRevealed = function(infoState, warehouseTypeId)
    return analyzeRevealed(infoState)
end

-- ============================================================================
-- 估值计算
-- ============================================================================

--- 为某个 AI 构建/更新信息状态并计算估值
---
--- 新算法流程：
---   1. 收集信息 → 更新 itemRevealLevels
---   2. 确保 EstimateValue 已初始化
---   3. 调用 EstimateValue.Estimate(infoState, items, expectedValue)
---   4. 质量信号微调 ±15%
---   5. 不确定性波动（信息越多越小）
---
---@param playerIdx number
---@param round number
---@param infoSystem table { GetAllPublicInfos, GetPlayerSkillInfos }
---@param infoStates table 所有 AI 的 infoStates 引用
---@param expectedValue number 区域/难度的期望仓库价值（行业常识）
---@param warehouseTypeId string|nil 当前仓库类型
---@return number estimate 估值（用于出价）
---@return table cachedSecureValue AntiCheat SecureValue
---@return number expectedTotal 期望总价值
---@return number poolAvg 池均价（单件）
---@return number itemCount 物品总数
function InfoEstimation.ComputeEstimate(playerIdx, round, infoSystem, infoStates, expectedValue, warehouseTypeId)
    local state = infoStates[playerIdx]
    if not state then
        state = { publicInfos = {}, skillInfos = {}, itemRevealLevels = {} }
        infoStates[playerIdx] = state
    end

    -- 1. 收集信息 & 更新揭示等级
    state.publicInfos = infoSystem.GetAllPublicInfos(round)
    state.skillInfos = infoSystem.GetPlayerSkillInfos(playerIdx, round)
    InfoEstimation.UpdateRevealLevels(state)

    -- 2. 确保新估值模块已初始化
    if not _NewEstimateValue.IsInitialized() then
        _NewEstimateValue.Init(warehouseTypeId)
    end

    -- 3. 获取仓库物品并调用新估值算法
    local items = _GameState and _GameState.GetWarehouseItems() or {}
    local itemCount = #items

    local totalEstimate, l3Count
    totalEstimate, l3Count, itemCount = _NewEstimateValue.Estimate(state, items, expectedValue)

    local poolAvg = _NewEstimateValue.GetPoolAverage(warehouseTypeId)

    -- 4. 质量分析（供策略模块使用）
    local analysis = analyzeRevealed(state)
    state.analysis = analysis

    -- 5. 质量信号微调：好仓库适度上浮，差仓库适度下压
    local estimate = totalEstimate
    if analysis.revealedCount >= 1 then
        local qAdj = 1.0 + analysis.qualitySignal * 0.15  -- ±15% 范围
        estimate = estimate * qAdj
    end

    -- 6. 信息置信度（用于不确定性缩放）
    local revealLevels = state.itemRevealLevels or {}
    local infoWeight = 0
    if itemCount > 0 then
        for _, item in ipairs(items) do
            local level = revealLevels[item.idx] or 0
            if level >= 3 then
                infoWeight = infoWeight + 1.0
            elseif level >= 2 then
                infoWeight = infoWeight + 0.7
            elseif level >= 1 then
                infoWeight = infoWeight + 0.3
            end
        end
        infoWeight = infoWeight / itemCount
    end

    -- 7. 估价波动：±不确定性（信息越多越确定，轮次越多越确定）
    local uncertainty = 0.15 - (round - 1) * 0.02 - infoWeight * 0.08
    uncertainty = math.max(uncertainty, 0.02)
    estimate = estimate * (1 + (math.random() * 2 - 1) * uncertainty)

    -- 保底：不低于 expectedValue × tier先验 的 5%
    -- （tier先验 ≈ 0.65x，所以保底 ≈ expectedValue 的 3.25%）
    local tierPriorEV = _NewEstimateValue.GetTierPriorValue(expectedValue)
    estimate = math.max(estimate, tierPriorEV * 0.05)

    return estimate, _AntiCheat.SecureValue(estimate), totalEstimate, poolAvg, itemCount
end

return InfoEstimation
