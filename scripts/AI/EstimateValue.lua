-- ============================================================================
-- AI/EstimateValue.lua - AI 仓库估值模块（相对比例算法 v3 - tier感知）
--
-- 核心思想：
--   先验锚定使用仓库分层系统(tier)的加权中位数，而非 expectedValue
--   baseline = expectedValue × TIER_PRIOR_MULT / itemCount
--   池数据仅用于不同稀有度/类别之间的 **相对比例**
--   L0~L3 逐级替换为更精确的估值
--
-- 三层估值：
--   L0: baseline（仅知数量，已含 tier 修正）
--   L1: baseline × categoryRelative（知轮廓/类别）
--   L2: baseline × rarityRelative（知品质/稀有度）
--   L3: realValue（精确值）
--
-- 质量推断：当 ≥3 件物品已知精确值(L3)时，
--   用已知物品的 "实际值/估计值" 比率修正未知物品的估值
-- ============================================================================

local Config = require("Config")

local EstimateValue = {}

-- ============================================================================
-- 仓库分层系统 (Tier) 先验参数
-- 与 WarehouseGenerator.lua 中的 WAREHOUSE_TIERS 保持一致
-- AI 用这些数据建立先验估值锚定
-- ============================================================================

-- Tier 分布（复制自 WarehouseGenerator）
local WAREHOUSE_TIERS = {
    { id = "junk",     weight = 22, multMin = 0.10, multMax = 0.30 },
    { id = "poor",     weight = 25, multMin = 0.30, multMax = 0.60 },
    { id = "normal",   weight = 28, multMin = 0.60, multMax = 1.25 },
    { id = "good",     weight = 15, multMin = 1.25, multMax = 2.10 },
    { id = "treasure", weight = 7,  multMin = 2.10, multMax = 3.50 },
    { id = "jackpot",  weight = 3,  multMin = 3.50, multMax = 5.50 },
}

--- 计算 tier 分布的先验乘数
--- 使用加权 P40 分位（比中位数更保守）
--- junk(22%) + poor(25%) = 47%，P40 落在 poor tier 后段 → ≈0.52x
local PRIOR_PERCENTILE = 0.40  -- 先验分位数（0.5=中位数，0.4=偏保守）

local function computeTierPriorMult()
    local totalWeight = 0
    for _, t in ipairs(WAREHOUSE_TIERS) do
        totalWeight = totalWeight + t.weight
    end
    local targetWeight = totalWeight * PRIOR_PERCENTILE
    local acc = 0
    for _, t in ipairs(WAREHOUSE_TIERS) do
        local prevAcc = acc
        acc = acc + t.weight
        if acc >= targetWeight then
            local progress = (targetWeight - prevAcc) / t.weight
            return t.multMin + (t.multMax - t.multMin) * progress
        end
    end
    return 0.50  -- fallback
end

--- 先验乘数：tier 分布的加权 P40 分位
--- 偏保守：AI 倾向于假设仓库低于中位数，避免高价值仓库过度出价
local TIER_PRIOR_MULT = computeTierPriorMult()

-- ============================================================================
-- 内部状态（Init 时构建）
-- ============================================================================

-- 稀有度相对比例: rarityRelative[rarity] = avg(该稀有度物品) / poolAvg
-- 表示该稀有度物品相对于池平均的价值倍率
local rarityRelative = {}

-- 稀有度绝对均价: rarityAvgValue[rarity] = avg(该稀有度物品的实际价值)
-- L2 估值直接使用此值，与 baseline 无关，避免低估
local rarityAvgValue = {}

-- 类别相对比例: categoryRelative[category] = avg(该类别物品) / poolAvg
local categoryRelative = {}

-- 池平均值（所有物品的算术平均，用于计算相对比例的基准）
local poolAvg = 0

-- 是否已初始化
local initialized = false

-- ============================================================================
-- 加载物品池数据
-- ============================================================================

--- 获取指定仓库类型的合并物品池
--- 直接从 Config.WAREHOUSE_TYPES 读取 categoryWeights/allowedCategories，物品来自 ItemPool
---@param warehouseTypeId string|nil
---@return table[] 物品列表 { rarity, category, value }
local function loadPool(warehouseTypeId)
    local whCfg = Config.WAREHOUSE_TYPES[warehouseTypeId or ""]
    -- fallback 到 suburb_basement（无 allowedCategories = 全品类）
    if not whCfg then
        whCfg = Config.WAREHOUSE_TYPES["suburb_basement"] or {}
    end

    local allowed = nil
    if whCfg.allowedCategories then
        allowed = {}
        for _, catId in ipairs(whCfg.allowedCategories) do
            allowed[catId] = true
        end
    end

    local itemPoolMod = require("Config.Warehouses.ItemPool")
    local allItems = {}

    for _, cat in ipairs(itemPoolMod.categories) do
        if not allowed or allowed[cat.id] then
            for _, item in ipairs(cat.items) do
                allItems[#allItems + 1] = {
                    rarity   = item.quality or "white",
                    category = cat.id,
                    value    = item.value or 0,
                    weight   = item.weight or 1,  -- 出现权重（权重越高越常见）
                }
            end
        end
    end

    return allItems
end

-- ============================================================================
-- 初始化：构建相对比例表
-- ============================================================================

--- 初始化估值模块，构建相对比例表
---@param warehouseTypeId string|nil 仓库类型
function EstimateValue.Init(warehouseTypeId)
    local pool = loadPool(warehouseTypeId)

    -- ===== 使用出现权重(weight)加权平均 =====
    -- 物品池中每个物品有 weight 字段，表示出现概率权重
    -- 例如：汉代陶俑(red, weight=500, value=5万) 比 阿波罗导航计算机(red, weight=1, value=1364万)
    -- 出现概率高 500 倍。AI 估计"随机红色物品值多少"应按此权重加权。

    -- 计算池加权平均值
    local totalWeightedValue = 0
    local totalWeight = 0
    for _, item in ipairs(pool) do
        totalWeightedValue = totalWeightedValue + item.value * item.weight
        totalWeight = totalWeight + item.weight
    end
    poolAvg = totalWeight > 0 and (totalWeightedValue / totalWeight) or 1

    -- 按稀有度分组，计算加权平均
    local rarityWeightedSum = {}   -- [rarity] = sum(value * weight)
    local rarityTotalWeight = {}   -- [rarity] = sum(weight)
    local rarityUnweightedSum = {} -- [rarity] = sum(value)  (仅用于日志对比)
    local rarityItemCount = {}     -- [rarity] = count
    for _, item in ipairs(pool) do
        local r = item.rarity
        rarityWeightedSum[r] = (rarityWeightedSum[r] or 0) + item.value * item.weight
        rarityTotalWeight[r] = (rarityTotalWeight[r] or 0) + item.weight
        rarityUnweightedSum[r] = (rarityUnweightedSum[r] or 0) + item.value
        rarityItemCount[r] = (rarityItemCount[r] or 0) + 1
    end

    rarityRelative = {}
    rarityAvgValue = {}
    for r, wSum in pairs(rarityWeightedSum) do
        local wAvg = wSum / rarityTotalWeight[r]                       -- 加权平均（按出现概率）
        local uAvg = rarityUnweightedSum[r] / rarityItemCount[r]       -- 无权重平均（仅日志）
        rarityRelative[r] = wAvg / poolAvg
        rarityAvgValue[r] = wAvg
        -- 日志：显示加权 vs 无权重的差异，方便调试
        if math.abs(wAvg - uAvg) / math.max(uAvg, 1) > 0.3 then
            print(string.format("[EstimateValue]   rarity %s WEIGHTED avg=%.0f vs UNWEIGHTED avg=%.0f (%.0f%% diff, %d items)",
                r, wAvg, uAvg, (wAvg - uAvg) / uAvg * 100, rarityItemCount[r]))
        end
    end

    -- 按类别分组，计算加权平均
    local catWeightedSum = {}
    local catTotalWeight = {}
    for _, item in ipairs(pool) do
        local c = item.category
        catWeightedSum[c] = (catWeightedSum[c] or 0) + item.value * item.weight
        catTotalWeight[c] = (catTotalWeight[c] or 0) + item.weight
    end

    categoryRelative = {}
    for c, wSum in pairs(catWeightedSum) do
        local wAvg = wSum / catTotalWeight[c]
        categoryRelative[c] = wAvg / poolAvg
    end

    initialized = true

    -- 调试日志
    print("[EstimateValue] Init warehouseTypeId=" .. tostring(warehouseTypeId)
        .. " poolSize=" .. #pool
        .. " poolAvg=" .. string.format("%.1f", poolAvg)
        .. " tierPriorMult=" .. string.format("%.3f", TIER_PRIOR_MULT))
    for r, rel in pairs(rarityRelative) do
        print("[EstimateValue]   rarity " .. r .. " relative=" .. string.format("%.3f", rel)
            .. " avgValue=" .. string.format("%.0f", rarityAvgValue[r] or 0))
    end
end

-- ============================================================================
-- 核心估值函数
-- ============================================================================

--- 估算仓库总价值
--- 每件物品根据信息层级获得不同精度的估值：
---   L0: baseline
---   L1: baseline × categoryRelative
---   L2: baseline × rarityRelative
---   L3: realValue（精确值）
--- 当 ≥3 件 L3 物品已知时，用质量比率修正未知物品
---
---@param infoState table { itemRevealLevels }
---@param items table[] 仓库物品列表（来自 GameState）
---@param expectedValue number 区域期望价值
---@return number totalEstimate 总估值
---@return number knownCount L3 物品数量
---@return number itemCount 物品总数
function EstimateValue.Estimate(infoState, items, expectedValue)
    if not items or #items == 0 then
        return expectedValue * TIER_PRIOR_MULT, 0, 0
    end

    local itemCount = #items
    -- 使用 tier 分布的加权中位数作为先验锚定（而非直接用 expectedValue）
    -- 这样 AI 对大多数仓库（junk/poor/normal，75%概率）不会严重高估
    local baseline = expectedValue * TIER_PRIOR_MULT / itemCount
    local revealLevels = infoState.itemRevealLevels or {}

    -- 第一遍：按信息层级估算每件物品
    local perItemEstimate = {}  -- [idx] = 估值
    local perItemLevel = {}     -- [idx] = 信息层级
    local l3Values = {}         -- L3 物品的 { estimate_before_l3, realValue }
    local l3Count = 0

    for _, item in ipairs(items) do
        local idx = item.idx
        local level = revealLevels[idx] or 0
        local est = baseline

        if level >= 3 then
            -- L3: 精确值
            est = item.realValue or item.value or baseline
            l3Count = l3Count + 1
        elseif level >= 2 then
            -- L2: 知品质 → 直接用池内该稀有度的真实均价（与 baseline 无关）
            -- 避免 baseline 过低导致 AI 低估已知稀有度物品
            -- 取 rarityAvgValue 和 baseline×rarityRelative 的较大值，确保先验不低于池均
            local rr = rarityRelative[item.rarity] or 1.0
            local poolRarityAvg = rarityAvgValue[item.rarity] or (poolAvg * rr)
            est = math.max(baseline * rr, poolRarityAvg)
        elseif level >= 1 then
            -- L1: 知轮廓/类别 → baseline × categoryRelative
            local cr = categoryRelative[item.category] or 1.0
            est = baseline * cr
        end
        -- L0: 直接用 baseline

        perItemEstimate[idx] = est
        perItemLevel[idx] = level

        -- 记录 L3 物品的"如果不是L3会估多少" vs "实际值"
        if level >= 3 then
            -- 假设只有 L2 信息时的估值
            local rr = rarityRelative[item.rarity] or 1.0
            local hypothetical = baseline * rr
            l3Values[#l3Values + 1] = {
                hypothetical = hypothetical,
                real = item.realValue or item.value or baseline,
            }
        end
    end

    -- 质量推断：当 ≥3 件 L3 已知时，计算质量比率
    local qualityRatio = 1.0
    if l3Count >= 3 then
        local sumHypo = 0
        local sumReal = 0
        for _, v in ipairs(l3Values) do
            sumHypo = sumHypo + v.hypothetical
            sumReal = sumReal + v.real
        end
        if sumHypo > 0 then
            qualityRatio = sumReal / sumHypo
            -- 限制修正范围 [0.3, 3.0]，避免极端偏差
            qualityRatio = math.max(0.3, math.min(3.0, qualityRatio))
        end
    end

    -- 仓库质量信号：用 random_avg_value 样品均价 vs 池均价判断好仓/坏仓
    -- 对 L0/L1 未知物品双向调整（阻尼平方根），L2/L3 已有具体信息不受影响
    local sampleDampedMult = 1.0
    local publicInfos = infoState.publicInfos or {}
    local skillInfos  = infoState.skillInfos  or {}
    for _, infos in ipairs({ publicInfos, skillInfos }) do
        for _, info in ipairs(infos) do
            if info.type == "random_avg_value" and info.sampleAvgValue and info.sampleAvgValue > 0 and poolAvg > 0 then
                local ratio = info.sampleAvgValue / poolAvg
                local dm = math.sqrt(ratio)
                dm = math.max(0.5, math.min(2.0, dm))
                -- 取影响最大的一条（离 1.0 最远）
                if math.abs(dm - 1.0) > math.abs(sampleDampedMult - 1.0) then
                    sampleDampedMult = dm
                end
            end
        end
    end

    -- 第二遍：应用质量修正，累加总估值
    local totalEstimate = 0
    for _, item in ipairs(items) do
        local idx = item.idx
        local level = perItemLevel[idx] or 0
        local est = perItemEstimate[idx] or baseline

        -- L3 物品不需要修正（已是精确值）
        -- 非 L3 物品：先应用 L3 质量推断修正，再应用样品均价信号
        if level < 3 then
            if l3Count >= 3 then
                est = est * qualityRatio
            end
            -- L0/L1：进一步应用仓库质量信号（L2 已有稀有度信息，不再调整）
            if level < 2 then
                est = est * sampleDampedMult
            end
        end

        totalEstimate = totalEstimate + est
    end

    -- L0V 约束：将已知批次总价值作为下界
    -- 若某角色技能揭示了"白绿蓝共X件总价Y"，则那些物品的估值之和至少要达到 Y
    -- 差额按比例分摊到被覆盖的物品上
    local knownLotValues = infoState.knownLotValues or {}
    if #knownLotValues > 0 then
        -- 构建 idx→当前估值 的快速查找表
        local idxToEst = {}
        for _, item in ipairs(items) do
            idxToEst[item.idx] = perItemEstimate[item.idx] or baseline
        end

        for _, lot in ipairs(knownLotValues) do
            -- 计算本批次物品当前的估值之和
            local currentLotSum = 0
            for _, idx in ipairs(lot.itemIdxs) do
                currentLotSum = currentLotSum + (idxToEst[idx] or 0)
            end

            -- 若当前估值低于已知总价，按比例提升各物品估值，并补偿 totalEstimate
            if currentLotSum < lot.totalValue and currentLotSum > 0 then
                local scale = lot.totalValue / currentLotSum
                local delta = 0
                for _, idx in ipairs(lot.itemIdxs) do
                    local oldEst = idxToEst[idx] or 0
                    local newEst = oldEst * scale
                    delta = delta + (newEst - oldEst)
                    idxToEst[idx] = newEst
                end
                totalEstimate = totalEstimate + delta
                print("[EstimateValue] L0V 约束: 批次" .. #lot.itemIdxs .. "件"
                    .. " 原估" .. string.format("%.0f", currentLotSum)
                    .. " 已知总价" .. string.format("%.0f", lot.totalValue)
                    .. " 提升 totalEstimate+" .. string.format("%.0f", delta))
            end
        end
    end

    return totalEstimate, l3Count, itemCount
end

-- ============================================================================
-- 辅助查询接口
-- ============================================================================

--- 获取池平均值（供外部使用）
---@param warehouseTypeId string|nil 未使用，保持接口兼容
---@return number
function EstimateValue.GetPoolAverage(warehouseTypeId)
    return poolAvg
end

--- 获取 tier 先验修正后的期望值
--- 即 expectedValue × TIER_PRIOR_MULT
---@param expectedValue number 区域/难度的原始期望值
---@return number 修正后的期望值
function EstimateValue.GetTierPriorValue(expectedValue)
    return expectedValue * TIER_PRIOR_MULT
end

--- 获取 tier 先验乘数
---@return number
function EstimateValue.GetTierPriorMult()
    return TIER_PRIOR_MULT
end

--- 获取池中位数（兼容旧接口，返回 poolAvg）
---@param warehouseTypeId string|nil
---@return number
function EstimateValue.GetPoolMedian(warehouseTypeId)
    return poolAvg  -- 新算法不依赖中位数，返回均值保持接口兼容
end

--- 获取稀有度相对比例表
---@return table { [rarity] = relative_ratio }
function EstimateValue.GetRarityRelative()
    return rarityRelative
end

--- 获取类别相对比例表
---@return table { [category] = relative_ratio }
function EstimateValue.GetCategoryRelative()
    return categoryRelative
end

--- 是否已初始化
---@return boolean
function EstimateValue.IsInitialized()
    return initialized
end

return EstimateValue
