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

-- Tier 分布（复制自 WarehouseGenerator，2026-05-22 同步）
-- budgetK：budgetWeight 高斯核集中度，值越大物品价值越集中于目标均价附近
-- 此字段用于 computeDynWeight，模拟生成算法中实际的选品集中度
local WAREHOUSE_TIERS = {
    { id = "trash",    weight = 25, multMin = 0.25, multMax = 0.40, budgetK = 1.2 },
    { id = "junk",     weight = 23, multMin = 0.35, multMax = 0.55, budgetK = 1.0 },
    { id = "poor",     weight = 22, multMin = 0.50, multMax = 0.75, budgetK = 0.9 },
    { id = "normal",   weight = 13, multMin = 0.65, multMax = 1.00, budgetK = 0.8 },
    { id = "good",     weight = 9,  multMin = 1.00, multMax = 1.80, budgetK = 0.6 },
    { id = "treasure", weight = 6,  multMin = 1.80, multMax = 3.20, budgetK = 0.4 },
    { id = "jackpot",  weight = 2,  multMin = 3.20, multMax = 5.50, budgetK = 0.3 },
}

--- 计算 tier 分布的先验乘数
--- 使用加权 P40 分位（比中位数更保守）
--- trash(25%) + junk(23%) = 48%，P40 落在 junk tier 中段 → ≈0.46x
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

-- 尺寸均价: sizeAvgValue[cells] = avg(占位 cells 格的所有物品)
-- 用于修正 SizeAvgValue 道具产生的 random_avg_value 的比较基准
local sizeAvgValue = {}

-- 品类×品质均价: categoryRarityAvg["catId:rarity"] = 加权均价
-- 用于 L2（品质+轮廓）比 L2_hint（仅品质）更精确的估值
local categoryRarityAvg = {}

-- 池平均值（所有物品的算术平均，用于计算相对比例的基准）
local poolAvg = 0

-- 池内最低价物品价值（白品质中最便宜的，用于 sampleAvgValue 精确下界）
local poolMinValue = 0

-- 是否已初始化
local initialized = false

-- ============================================================================
-- 加载物品池数据
-- ============================================================================

-- 仓库 tier 期望件数（与 WarehouseGenerator 中 baseCount~40 对齐）
local EXPECTED_ITEM_COUNT = 35

--- 计算 budgetWeight（与 WarehouseGenerator 中相同公式）
--- 非对称高斯衰减：高于目标价衰减更慢，允许高价物品偶发出现
local function budgetWeightCalc(value, targetPerPick, k)
    if targetPerPick <= 0 then targetPerPick = 1 end
    k = k or 1.5
    local logRatio = math.log(value / targetPerPick)
    if logRatio > 0 then
        return math.exp(-(k * 0.5) * logRatio * logRatio)
    else
        return math.exp(-k * logRatio * logRatio)
    end
end

--- 计算物品在指定仓库类型下的动态出现期望权重
--- 跨所有 tier 加权：dynWeight = Σ(tierProb × budgetWeight_in_tier)
--- 这反映了物品在该仓库类型中实际被选中的期望频率：
---   - 差仓（trash/junk tier，warehouseValue 的 0.30~0.50 倍）中 targetPerPick 极低
---     → 高价物品（2800万）在 targetPerPick=6~10万 时权重趋近 0
---   - 好仓（treasure/jackpot tier，warehouseValue 的 2~5 倍）中 targetPerPick 高
---     → 高价物品才有一定出现概率
---@param value number 物品价值
---@param warehouseValue number 仓库期望价值（高点）
---@param catMult number 品类权重乘数
---@return number 动态权重
local function computeDynWeight(value, warehouseValue, catMult)
    local totalTierWeight = 0
    for _, t in ipairs(WAREHOUSE_TIERS) do
        totalTierWeight = totalTierWeight + t.weight
    end

    local dynWeight = 0
    for _, t in ipairs(WAREHOUSE_TIERS) do
        local tierProb = t.weight / totalTierWeight
        -- 用 tier 倍率中点估算 targetPerPick
        local multMid = (t.multMin + t.multMax) * 0.5
        local tierValue = warehouseValue * multMid
        -- 绝对保底（与 WarehouseGenerator 一致）
        tierValue = math.max(warehouseValue * 0.02, tierValue)
        local targetPerPick = tierValue / EXPECTED_ITEM_COUNT
        -- 使用 tier 的 budgetK（与生成时一致）
        local bw = budgetWeightCalc(value, targetPerPick, t.budgetK or 1.5)
        -- 硬截断：与 WarehouseGenerator.pickWeightedBudget 一致
        if value < targetPerPick * 0.4 then
            bw = 0
        end
        dynWeight = dynWeight + tierProb * bw
    end

    -- 最终权重 = 动态出现概率 × 品类权重（反映该仓库倾向哪类物品）
    return dynWeight * catMult
end

--- 获取指定仓库类型的合并物品池
--- 直接从 Config.WAREHOUSE_TYPES 读取 categoryWeights/allowedCategories，物品来自 ItemPool
---@param warehouseTypeId string|nil
---@param warehouseValue number|nil 仓库期望价值（用于动态权重计算）
---@return table[] 物品列表 { rarity, category, value, weight }
local function loadPool(warehouseTypeId, warehouseValue)
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

    -- 读取仓库的品类权重（categoryWeights 覆盖 ItemPool 默认值）
    -- 若没有配置则各品类等权（乘数 = 1）
    local catWeights = whCfg.categoryWeights or {}
    -- 若仓库明确指定了 categoryWeights，则未列出的品类 catMult=0（排除在统计池外）
    -- 这样专精仓库（如地下金库 jewel=65）不会被不相关品类污染均值
    local hasCatWeights = next(catWeights) ~= nil

    -- 是否使用动态权重：需要知道 warehouseValue 才能计算 targetPerPick
    -- 若 warehouseValue 未提供（≤0），退化到旧的固定权重模式
    local useDynWeight = warehouseValue and warehouseValue > 0

    local itemPoolMod = require("Config.Warehouses.ItemPool")
    local allItems = {}

    for _, cat in ipairs(itemPoolMod.categories) do
        if not allowed or allowed[cat.id] then
            local catMult
            if hasCatWeights then
                -- 明确指定了品类权重：未列出的品类不进入统计池
                catMult = catWeights[cat.id] or 0
            else
                -- 未指定品类权重：各品类等权
                catMult = 1
            end
            if catMult > 0 then
                for _, item in ipairs(cat.items) do
                    -- exclusive 物品（孤品/限定）不进入统计池
                    -- 这类物品极其稀有，均值不应被其拉高导致AI对普通仓库严重高估
                    if not item.exclusive then
                        local w
                        if useDynWeight then
                            -- 动态权重：用仓库生成算法的实际出现概率作为加权依据
                            -- 高价物品在差仓（targetPerPick低）中几乎不会出现，动态权重趋近0
                            -- 这解决了极端高价物品（追光者引擎原型2800万）污染rarityAvgValue的根本原因
                            w = computeDynWeight(item.value or 0, warehouseValue, catMult)
                        else
                            -- 回退：物品自身出现权重 × 仓库品类权重
                            w = (item.weight or 1) * catMult
                        end
                        if w > 0 then
                            allItems[#allItems + 1] = {
                                rarity   = item.quality or "white",
                                category = cat.id,
                                value    = item.value or 0,
                                weight   = w,
                            }
                        end
                    end
                end
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
---@param warehouseValue number|nil 仓库期望价值（用于动态权重，应传入难度的 warehouseValue）
function EstimateValue.Init(warehouseTypeId, warehouseValue)
    local pool = loadPool(warehouseTypeId, warehouseValue)

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

    -- 构建 sizeAvgValue[cells]（尺寸均价，Fix B 用）
    sizeAvgValue = {}
    local sizeWeightedSum = {}
    local sizeTotalWeight = {}
    for _, item in ipairs(pool) do
        local cells = (item.cols or 1) * (item.rows or 1)
        sizeWeightedSum[cells] = (sizeWeightedSum[cells] or 0) + item.value * item.weight
        sizeTotalWeight[cells] = (sizeTotalWeight[cells] or 0) + item.weight
    end
    for cells, wSum in pairs(sizeWeightedSum) do
        sizeAvgValue[cells] = wSum / sizeTotalWeight[cells]
    end

    -- 构建 categoryRarityAvg["catId:rarity"]（品类×品质均价，Fix A 用）
    categoryRarityAvg = {}
    local crWeightedSum = {}
    local crTotalWeight = {}
    for _, item in ipairs(pool) do
        local key = item.category .. ":" .. item.rarity
        crWeightedSum[key] = (crWeightedSum[key] or 0) + item.value * item.weight
        crTotalWeight[key]  = (crTotalWeight[key]  or 0) + item.weight
    end
    for key, wSum in pairs(crWeightedSum) do
        categoryRarityAvg[key] = wSum / crTotalWeight[key]
    end

    -- 池内最低价（用于 sampleAvgValue 精确下界）
    poolMinValue = math.huge
    for _, item in ipairs(pool) do
        if item.value < poolMinValue then
            poolMinValue = item.value
        end
    end
    if poolMinValue == math.huge then poolMinValue = 0 end

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

    -- 预处理：收集 quality_avg_value 信息，建立仓库内实际品质均价映射
    -- 用于 L2 估值时优先使用仓库实际数据，而非池统计数据
    local inWarehouseRarityAvg = {}  -- { [rarityId] = 仓库内实际均价 }
    do
        local publicInfos = infoState.publicInfos or {}
        local skillInfos  = infoState.skillInfos  or {}
        for _, infos in ipairs({ publicInfos, skillInfos }) do
            for _, info in ipairs(infos) do
                if info.type == "quality_avg_value" and info.rarityId and info.rarityAvgValue and info.rarityAvgValue > 0 then
                    -- 修复：isSingleTopItem（TopRarityItemValue 道具）揭示的是仓库内【最贵单件】的价值，
                    -- 将其用作品质均价会严重高估（最贵单件 ≫ 该品质所有物品均价）。
                    -- 0.65× 折扣依然不足，且概念上也是错误的，应完全排除。
                    if not info.isSingleTopItem then
                        if not inWarehouseRarityAvg[info.rarityId] or info.rarityAvgValue > inWarehouseRarityAvg[info.rarityId] then
                            inWarehouseRarityAvg[info.rarityId] = info.rarityAvgValue
                        end
                    end
                end
                if info.extraInfos then
                    for _, extra in ipairs(info.extraInfos) do
                        if extra.type == "quality_avg_value" and extra.rarityId and extra.rarityAvgValue and extra.rarityAvgValue > 0 then
                            if not extra.isSingleTopItem then
                                if not inWarehouseRarityAvg[extra.rarityId] or extra.rarityAvgValue > inWarehouseRarityAvg[extra.rarityId] then
                                    inWarehouseRarityAvg[extra.rarityId] = extra.rarityAvgValue
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- 提前声明 publicInfos / skillInfos，供后续 forEachInfo 等闭包使用
    local publicInfos = infoState.publicInfos or {}
    local skillInfos  = infoState.skillInfos  or {}

    -- 辅助：通过平均格数插值 sizeAvgValue，估算均价
    local function interpolateSizeAvg(avgCells)
        if not avgCells or avgCells <= 0 then return nil end
        local lo = math.floor(avgCells)
        local hi = math.ceil(avgCells)
        local loVal = sizeAvgValue[lo]
        local hiVal = sizeAvgValue[hi]
        if loVal and hiVal then
            local frac = avgCells - lo
            return loVal * (1 - frac) + hiVal * frac
        end
        return loVal or hiVal
    end

    -- 辅助：遍历所有 info（含 extraInfos），对匹配的 type 执行回调
    local function forEachInfo(callback)
        for _, infos in ipairs({ publicInfos, skillInfos }) do
            for _, info in ipairs(infos) do
                callback(info)
                if info.extraInfos then
                    for _, extra in ipairs(info.extraInfos) do
                        callback(extra)
                    end
                end
            end
        end
    end

    -- 预处理：收集 rarity_avg_cell_count 信息（角色道具产生）
    -- 利用 sizeAvgValue[cells] 插值，将"该品质平均占 N 格"转化为估计均价
    -- 仅在 inWarehouseRarityAvg 尚无该品质数据时填入（quality_avg_value 更精确，优先级更高）
    forEachInfo(function(info)
        if info.type == "rarity_avg_cell_count" and info.avgCellCount and info.avgCellCount > 0 and info.rarities then
            local estimatedAvg = interpolateSizeAvg(info.avgCellCount)
            if estimatedAvg and estimatedAvg > 0 then
                for _, r in ipairs(info.rarities) do
                    if not inWarehouseRarityAvg[r] then
                        inWarehouseRarityAvg[r] = estimatedAvg
                        print(string.format("[EstimateValue] rarity_avg_cell_count [%s]: avgCells=%.1f → estimatedAvg=%.0f",
                            r, info.avgCellCount, estimatedAvg))
                    end
                end
            end
        end
    end)

    -- 预处理：收集 quality_avg_cells / quality_total_cells（公开竞拍信息）
    -- 同样通过 sizeAvgValue 插值获得品质均价估计
    -- 同时 rarityCount 可补充 quality_count 配额信息
    local knownRarityCountsFromCells = {}  -- 从格子信息中提取的品质件数
    forEachInfo(function(info)
        if (info.type == "quality_avg_cells" or info.type == "quality_total_cells")
            and info.rarityId and info.rarityAvgCells and info.rarityAvgCells > 0 then
            local estimatedAvg = interpolateSizeAvg(info.rarityAvgCells)
            if estimatedAvg and estimatedAvg > 0 then
                if not inWarehouseRarityAvg[info.rarityId] then
                    inWarehouseRarityAvg[info.rarityId] = estimatedAvg
                    print(string.format("[EstimateValue] %s [%s]: avgCells=%d → estimatedAvg=%.0f",
                        info.type, info.rarityId, info.rarityAvgCells, estimatedAvg))
                end
            end
            -- 提取品质件数供 quality_count 配额修正使用
            if info.rarityCount and info.rarityCount > 0 then
                local cur = knownRarityCountsFromCells[info.rarityId] or 0
                if info.rarityCount > cur then
                    knownRarityCountsFromCells[info.rarityId] = info.rarityCount
                end
            end
        end
    end)

    -- 预处理：收集 total_cells / avg_cells_per_item（全仓平均格数）
    -- 通过 sizeAvgValue 插值获得全仓均价估计，用于修正 baseline
    -- 仅当估计均价显著偏离当前 baseline 时才应用（阻尼平方根，类似 sampleDampedMult）
    local cellsBaselineMult = 1.0
    do
        local bestAvgCells = nil
        forEachInfo(function(info)
            if info.type == "avg_cells_per_item" and info.avgCellsPerItem and info.avgCellsPerItem > 0 then
                bestAvgCells = info.avgCellsPerItem
            elseif info.type == "total_cells" and info.totalCells and info.totalCount and info.totalCount > 0 then
                local avg = info.totalCells / info.totalCount
                if not bestAvgCells then
                    bestAvgCells = avg
                end
            end
        end)
        if bestAvgCells then
            local estimatedAvg = interpolateSizeAvg(bestAvgCells)
            if estimatedAvg and estimatedAvg > 0 and poolAvg > 0 then
                local ratio = estimatedAvg / poolAvg
                -- 阻尼平方根，收窄范围 [0.7, 1.5]
                local dm = math.sqrt(ratio)
                dm = math.max(0.7, math.min(1.5, dm))
                cellsBaselineMult = dm
                print(string.format("[EstimateValue] cells baseline: avgCells=%.2f → estimatedAvg=%.0f → mult=%.3f",
                    bestAvgCells, estimatedAvg, dm))
            end
        end
    end

    -- 预计算已揭示比例，用于 L1/L2 damping
    -- 原则：信息量少时，单件揭示对估值的影响应该小（贝叶斯：后验靠近先验）
    -- revealedCount：已揭示至少 L1（知道类别/品质）的件数
    -- revealFraction：揭示比例，从 0→1
    -- l1l2DampFactor = min(1.0, revealFraction × 2)
    --   → 揭示 10%（2/20件）时 dampFactor=0.20，调整量只有满信息的 20%
    --   → 揭示 50%（10/20件）时 dampFactor=1.0，完全应用
    local revealedCount = 0
    for _, item in ipairs(items) do
        if (revealLevels[item.idx] or 0) >= 1 then
            revealedCount = revealedCount + 1
        end
    end
    local revealFraction = revealedCount / math.max(itemCount, 1)
    -- × 1.5：需要揭示 2/3 才达到满分（原来是 ×2，揭示 50% 即满分）
    -- ×2 时：程云裳在 priv_wardrobe 揭示 50% fashion 物品 → dampFactor=1.0（完全无 damping！）
    -- ×1.5 时：50% 覆盖 → dampFactor=0.75；67% 才达满分（更保守，抑制单轮大量揭示的估值膨胀）
    local l1l2DampFactor = math.min(1.0, revealFraction * 1.5)
    print(string.format("[EstimateValue] L1/L2 damping: revealed=%d/%d fraction=%.2f dampFactor=%.2f",
        revealedCount, itemCount, revealFraction, l1l2DampFactor))

    -- 第一遍：按信息层级估算每件物品
    local perItemEstimate = {}  -- [idx] = 估值
    local perItemLevel = {}     -- [idx] = 信息层级
    local l3Values = {}         -- L3 物品的 { estimate_before_l3, realValue }
    local l3Count = 0

    for _, item in ipairs(items) do
        local idx = item.idx
        local level = revealLevels[idx] or 0
        local est = baseline

        if level >= 4 then
            -- L4: 精确值
            est = item.realValue or item.value or baseline
            l3Count = l3Count + 1
        elseif level >= 3 then
            -- L2（numeric 3）：知品质+轮廓 → 同时知道 category，使用品类×品质均价
            -- 关键修复（在 Init 中已完成）：rarityAvgValue 改为品类等权均值，不再被极端品类主导。
            -- 这里：crAvg 可用时直接使用（最精确），不再与 rarityAvgValue 取 max（避免跨品类污染）。
            local rr = rarityRelative[item.rarity] or 1.0
            local crKey = item.category .. ":" .. item.rarity
            local crAvg = categoryRarityAvg[crKey]
            local poolRarityAvg = rarityAvgValue[item.rarity] or (poolAvg * rr)
            local warehouseRarityAvg = inWarehouseRarityAvg[item.rarity]
            -- crAvg 有值时直接用（品类×品质最精确，无跨类污染）
            -- 无 crAvg 时退化到 poolRarityAvg（已是品类等权均值，不再被极端品类主导）
            local infoEst = crAvg or poolRarityAvg
            if warehouseRarityAvg and warehouseRarityAvg > infoEst then
                infoEst = warehouseRarityAvg
            end
            -- L2：已知品质+轮廓，是较强信号，用 l1l2DampFactor 做插值
            est = baseline + (infoEst - baseline) * l1l2DampFactor
        elseif level >= 2 then
            -- L2_hint（numeric 2）：仅知品质，不知轮廓/category
            -- rarityAvgValue 已在 Init 中改为品类等权均值，rr 也随之修正，不再异常放大。
            local rr = rarityRelative[item.rarity] or 1.0
            local poolRarityAvg = rarityAvgValue[item.rarity] or (poolAvg * rr)
            local warehouseRarityAvg = inWarehouseRarityAvg[item.rarity]
            local infoEst = math.max(baseline * rr, poolRarityAvg)
            if warehouseRarityAvg and warehouseRarityAvg > infoEst then
                infoEst = warehouseRarityAvg
            end
            -- L2_hint：品质信号也做 damping
            est = baseline + (infoEst - baseline) * l1l2DampFactor
        elseif level >= 1 then
            -- L1: 知轮廓/类别 → 插值到 baseline × categoryRelative
            -- 信息量少时大幅压低调整量，避免一件古董把整仓估高 2.5×
            local cr = categoryRelative[item.category] or 1.0
            local infoEst = baseline * cr
            est = baseline + (infoEst - baseline) * l1l2DampFactor
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
    -- 关键：用样本比例 damping，避免少数高价样本驱动全仓估值大幅跳变
    -- sampleWeight = l3Count / itemCount（如3/20=0.15，damping 效果强；20/20=1.0，完全应用）
    -- appliedRatio = 1 + (rawRatio - 1) × sampleWeight × 2
    -- 这样4件样本最多贡献 (rawRatio-1)×40% 的修正，而非直接 ×rawRatio
    local qualityRatio = 1.0
    if l3Count >= 3 then
        local sumHypo = 0
        local sumReal = 0
        for _, v in ipairs(l3Values) do
            sumHypo = sumHypo + v.hypothetical
            sumReal = sumReal + v.real
        end
        if sumHypo > 0 then
            local rawRatio = sumReal / sumHypo
            rawRatio = math.max(0.3, math.min(3.0, rawRatio))
            -- 按样本覆盖率 damping：样本越少，修正越保守
            local sampleWeight = math.min(1.0, l3Count / math.max(itemCount, 1))
            -- ×2 使得 50% 样本时可以达到约 100% 修正（sampleWeight=0.5 → 完全应用）
            local dampFactor = math.min(1.0, sampleWeight * 2)
            qualityRatio = 1.0 + (rawRatio - 1.0) * dampFactor
            -- 收窄后的安全范围 [0.5, 2.0]（原来是 [0.3, 3.0]，过于激进）
            qualityRatio = math.max(0.5, math.min(2.0, qualityRatio))
        end
    end

    -- 仓库质量信号：用 random_avg_value 样品均价 vs 池均价判断好仓/坏仓
    -- 对 L0/L1 未知物品双向调整（阻尼平方根），L2/L3 已有具体信息不受影响
    --
    -- 置信度 damping（sampleCoverageDamp）：
    --   原则：抽样件数越少，样品均价对全仓估值的影响越小
    --   sampleCoverageDamp = min(1.0, sampleCount / itemCount × 4)
    --     抽 0 件 → damp=0（sqrt阻尼后的偏移量全部抹除，回到 ×1.0）
    --     抽 25% → damp=1.0（达到满分，sqrt阻尼仍保留）
    --     无 sampleCount 信息 → damp=0.3（保守默认）
    --   最终：dm_eff = 1 + (dm - 1) × damp，即对偏移量做线性折扣，不影响方向
    local sampleDampedMult = 1.0
    for _, infos in ipairs({ publicInfos, skillInfos }) do
        for _, info in ipairs(infos) do
            if info.type == "random_avg_value" and info.sampleAvgValue and info.sampleAvgValue > 0 then
                -- 选择正确的基准均价，避免子集均价和全池均价对比产生系统偏差：
                --   sampleRarity    → 该品质的池均价（RarityAvgValue 道具）
                --   sampleCellCount → 该尺寸的池均价（SizeAvgValue 道具）
                --   其他            → 全池均价（全局信息）
                local referenceAvg
                if info.sampleRarity then
                    referenceAvg = rarityAvgValue[info.sampleRarity] or poolAvg
                elseif info.sampleCellCount then
                    referenceAvg = sizeAvgValue[info.sampleCellCount] or poolAvg
                else
                    referenceAvg = poolAvg
                end
                if referenceAvg > 0 then
                    local ratio = info.sampleAvgValue / referenceAvg
                    local dm = math.sqrt(ratio)
                    -- 上限从 5.0 降至 2.5：避免极端比值（如藏书阁古董仓库）产生过大倍数
                    -- dm=5.0 意味着样品均价是池均价的25倍，对全仓估值过于激进
                    dm = math.max(0.5, math.min(2.5, dm))

                    -- 样本覆盖率 damping：抽样件数/总件数越低，信号越不可靠
                    -- 抽 50% 才达满分（×2 系数，原来是 ×4 即 25% 满分）
                    -- ×4 时：priv_wardrobe 的 25% 四格物品 → damp=1.0（完全无 damping！）
                    -- ×2 时：priv_wardrobe 的 25% 四格物品 → damp=0.5（中等 damping）
                    -- 无 sampleCount 信息 → 保守默认 0.3
                    local sampleCoverageDamp
                    if info.sampleCount and info.sampleCount > 0 and itemCount > 0 then
                        sampleCoverageDamp = math.min(1.0, (info.sampleCount / itemCount) * 2)
                    else
                        sampleCoverageDamp = 0.3  -- 无样本数信息时保守
                    end
                    -- 对 dm 的偏移量（dm-1）做线性折扣，方向不变
                    local dmEff = 1.0 + (dm - 1.0) * sampleCoverageDamp

                    if math.abs(dmEff - 1.0) > math.abs(sampleDampedMult - 1.0) then
                        sampleDampedMult = dmEff
                        print(string.format("[EstimateValue] sampleDampedMult: ratio=%.2f dm=%.3f sampleCov=%.2f dmEff=%.3f",
                            ratio, dm, sampleCoverageDamp, dmEff))
                    end
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

        -- L4 物品不需要修正（已是精确值）
        -- 非 L4 物品：先应用 L4 质量推断修正，再应用样品均价信号
        if level < 4 then
            if l3Count >= 3 then
                est = est * qualityRatio
            end
            -- L0/L1：进一步应用仓库质量信号（L2/L3 已有稀有度信息，不再调整）
            if level < 2 then
                est = est * sampleDampedMult * cellsBaselineMult
            end
        end

        totalEstimate = totalEstimate + est
    end

    -- ── quality_count 配额修正 ──────────────────────────────────────────────
    -- 若公开/技能信息中有"某品质共 N 件"，而其中部分物品尚未揭示（level < 2），
    -- 则这些未揭示物品的当前估值（baseline）应提升为对应品质的均价。
    -- 仅做加法补偿，不修改 perItemEstimate，避免影响后续 L0V 约束。
    do
        local knownRarityCounts = {}  -- [rarityId] = 已确认的最大件数
        -- 从 quality_count 收集
        forEachInfo(function(info)
            if info.type == "quality_count" and info.rarityId and info.rarityCount then
                local cur = knownRarityCounts[info.rarityId] or 0
                if info.rarityCount > cur then
                    knownRarityCounts[info.rarityId] = info.rarityCount
                end
            end
        end)
        -- 合并 quality_avg_cells / quality_total_cells 中提取的品质件数
        for rarId, count in pairs(knownRarityCountsFromCells) do
            local cur = knownRarityCounts[rarId] or 0
            if count > cur then
                knownRarityCounts[rarId] = count
            end
        end

        if next(knownRarityCounts) then
            -- 统计已揭示（level >= 2）的各品质件数
            local revealedByRarity = {}
            for _, item in ipairs(items) do
                local lv = perItemLevel[item.idx] or 0
                if lv >= 2 then
                    revealedByRarity[item.rarity] = (revealedByRarity[item.rarity] or 0) + 1
                end
            end

            -- 配额修正 damping：与 L1/L2 共用同一个 l1l2DampFactor
            -- 原理：quality_count 是一条仓库级统计信息（"有 N 件紫色"），
            --   但如果我们对整个仓库的揭示比例很低（revealFraction→0），
            --   这条信息的可信度应该被压低：它可能只是公开展示的部分，
            --   未揭示物品的品质分布仍高度不确定。
            -- 当 l1l2DampFactor=0（0件揭示）时，配额修正完全被抑制 → 全靠先验
            -- 当 l1l2DampFactor=1（≥50%揭示）时，配额修正完全生效 → 精确修正
            -- 例外：若某品质已有 ≥1 件被精确揭示（revealedByRarity[rarId] >= 1），
            --   说明这条品质信息已有实物佐证，damping 放宽到 max(damp, 0.5)
            for rarId, totalCount in pairs(knownRarityCounts) do
                local revealed = revealedByRarity[rarId] or 0
                local quota = math.max(0, totalCount - revealed)
                if quota > 0 then
                    -- 未揭示这 quota 件的期望值（按品质均价）
                    -- rarityAvgValue 已在 Init 中改为品类等权均值，不再被极端品类主导
                    local expectedPerItem = math.max(
                        rarityAvgValue[rarId] or 0,
                        inWarehouseRarityAvg[rarId] or 0
                    )
                    -- damping：无物品级揭示时，配额修正最多只贡献 l1l2DampFactor 比例
                    -- 若该品质已有实物揭示（revealed >= 1），放宽下限到 0.5
                    local quotaDamp = l1l2DampFactor
                    if revealed >= 1 then
                        quotaDamp = math.max(quotaDamp, 0.5)
                    end
                    -- 当前这 quota 件被估为 baseline（L0），差额 × quotaDamp 补入总估值
                    local boost = quota * math.max(0, expectedPerItem - baseline) * quotaDamp
                    if boost > 0 then
                        totalEstimate = totalEstimate + boost
                        print("[EstimateValue] quality_count 配额修正 [" .. rarId .. "]:"
                            .. " quota=" .. quota
                            .. " expectedPerItem=" .. string.format("%.0f", expectedPerItem)
                            .. " baseline=" .. string.format("%.0f", baseline)
                            .. " quotaDamp=" .. string.format("%.2f", quotaDamp)
                            .. " boost=" .. string.format("%.0f", boost))
                    end
                end
            end
        end
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

    -- sampleAvgValue 精确下界：
    -- 已知 sampleCount 件样品均价 = X：
    --   精确下界 = sampleCount × X + (totalCount - sampleCount) × poolMinValue
    -- 无 sampleCount 时回退到保守估算 × 0.25
    do
        local bestFloor = 0
        for _, infos in ipairs({ publicInfos, skillInfos }) do
            for _, info in ipairs(infos) do
                if info.type == "random_avg_value"
                    and info.sampleAvgValue and info.sampleAvgValue > 0
                    and not info.sampleRarity
                    and not info.sampleCellCount
                    and info.totalCount and info.totalCount > 0
                then
                    local tc = info.totalCount
                    local floor
                    if info.sampleCount and info.sampleCount > 0 then
                        local sc = math.min(info.sampleCount, tc)
                        floor = sc * info.sampleAvgValue + math.max(0, tc - sc) * poolMinValue
                    else
                        floor = tc * info.sampleAvgValue * 0.25
                    end
                    if floor > bestFloor then
                        bestFloor = floor
                    end
                end
            end
        end
        if bestFloor > totalEstimate then
            print("[EstimateValue] sampleAvgValue 精确下界: "
                .. string.format("%.0f", totalEstimate) .. " -> " .. string.format("%.0f", bestFloor))
            totalEstimate = bestFloor
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

--- 重置初始化状态（每局新仓库开始时调用）
--- 不同仓库的 warehouseValue 不同，导致动态权重不同，必须重新 Init
function EstimateValue.Reset()
    initialized = false
    rarityRelative  = {}
    rarityAvgValue  = {}
    categoryRelative = {}
    sizeAvgValue    = {}
    categoryRarityAvg = {}
    poolAvg         = 0
    poolMinValue    = 0
end

return EstimateValue
