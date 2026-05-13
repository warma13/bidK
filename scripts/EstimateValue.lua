-- ============================================================================
-- EstimateValue.lua - 仓库估价算法（统一模块）
-- 支持两种模式：
--   "min"      : 最低估价（保守，用于出价上限保护）
--   "expected" : 期望估价（中性，用于仓库质量判断）
-- 动态加载当前仓库类型对应的物品池，按品类权重计算池均价
--
-- 【重要提示：与 warehouseValue 的关系】
-- WarehouseGenerator 的分层设计中，warehouseValue 是"高点"（约 80-87 分位），
-- 大多数仓库实际价值约为 warehouseValue 的 0.66× 左右（加权均值）。
-- 因此本模块的 CalculateExpected() 返回的期望估价通常会低于 warehouseValue，
-- 这是符合设计预期的——AI 估价反映物品条件期望，不以 warehouseValue 为锚点。
-- ============================================================================

local Config = require("Config")

local EstimateValue = {}

-- ============================================================================
-- 依赖注入：GameState（多房间隔离时由 RoomInstance 注入正确的实例）
-- ============================================================================

---@type table GameState 模块引用（通过 Init 注入）
local _GameState = nil

--- 注入依赖（必须在使用前调用）
---@param gameState table GameState 模块
function EstimateValue.InjectDeps(gameState)
    _GameState = gameState
end

-- ============================================================================
-- 查找表缓存（按仓库类型缓存）
-- ============================================================================

--- 缓存结构: tableCache[whTypeId] = { min = {...}, avg = {...}, poolAvg = number }
local tableCache = {}

--- 构建指定仓库类型的 min 和 avg 查找表
--- 直接从 Config.WAREHOUSE_TYPES[whTypeId] 读取 categoryWeights + allowedCategories
---@param whTypeId string 仓库类型ID
---@return table tables { min, avg, poolAvg }
local function buildTables(whTypeId)
    if tableCache[whTypeId] then return tableCache[whTypeId] end

    -- 从 Config.WAREHOUSE_TYPES 获取仓库配置，fallback 到 suburb_basement
    local whCfg = Config.WAREHOUSE_TYPES[whTypeId]
    if not whCfg then
        whTypeId = "suburb_basement"
        if tableCache[whTypeId] then return tableCache[whTypeId] end
        whCfg = Config.WAREHOUSE_TYPES[whTypeId] or {}
    end

    -- 解析 allowedCategories
    local allowed = nil
    if whCfg.allowedCategories then
        allowed = {}
        for _, catId in ipairs(whCfg.allowedCategories) do
            allowed[catId] = true
        end
    end

    -- 从 ItemPool 获取所有品类，按 allowedCategories 过滤
    local itemPoolMod = require("Config.Warehouses.ItemPool")
    local allCategories = {}
    for _, cat in ipairs(itemPoolMod.categories) do
        if not allowed or allowed[cat.id] then
            allCategories[#allCategories + 1] = cat
        end
    end

    -- 权重：与 WarehouseGenerator.getPool() 保持一致
    -- 当 whCfg.categoryWeights 存在时，不在其中的品类权重为 0（不会出现在仓库中）
    -- 否则使用 ItemPool 默认权重
    local categoryWeights = {}
    for _, cat in ipairs(allCategories) do
        local cw
        if whCfg.categoryWeights then
            cw = whCfg.categoryWeights[cat.id] or 0
        else
            cw = itemPoolMod.categoryWeights[cat.id] or 1
        end
        categoryWeights[cat.id] = cw
    end

    -- 过滤掉权重为 0 的品类（与 WarehouseGenerator 一致：这些品类不会出现在仓库中）
    local filteredCategories = {}
    for _, cat in ipairs(allCategories) do
        if categoryWeights[cat.id] > 0 then
            filteredCategories[#filteredCategories + 1] = cat
        end
    end
    allCategories = filteredCategories

    -- === min 查找表（用于最低估价） ===
    local qualityMinValue = {}       -- { [quality] = minValue }
    local qualitySizeMinValue = {}   -- { ["quality:WxH"] = minValue }

    -- === avg 查找表（用于期望估价） ===
    local categoryAvg = {}           -- { [catId] = avgValue }
    local categorySizeAvg = {}       -- { ["catId:WxH"] = avgValue }
    local categoryQualityAvg = {}    -- { ["catId:quality"] = avgValue }
    local qualityAvgWeighted = {}    -- { [quality] = 按品类权重加权的均价 }

    -- 池均价计算用的临时数据
    local totalCatWeight = 0

    -- 品质全局聚合（按品类权重加权）
    local qualitySumWeighted = {}    -- { [quality] = 加权价值总和 }
    local qualityCountWeighted = {}  -- { [quality] = 加权计数 }

    for _, cat in ipairs(allCategories) do
        local catId = cat.id
        local catWeight = categoryWeights[catId] or 1
        totalCatWeight = totalCatWeight + catWeight

        -- 品类内统计
        local catSum = 0
        local catCount = 0
        local sizeSum = {}    -- { ["WxH"] = sum }
        local sizeCount = {}  -- { ["WxH"] = count }
        local qualSum = {}    -- { [quality] = sum }
        local qualCount = {}  -- { [quality] = count }

        for _, item in ipairs(cat.items) do
            local q = item.quality
            local v = item.value
            local w = item.cols
            local h = item.rows

            -- min 表
            if not qualityMinValue[q] or v < qualityMinValue[q] then
                qualityMinValue[q] = v
            end
            local sizeKey = q .. ":" .. w .. "x" .. h
            if not qualitySizeMinValue[sizeKey] or v < qualitySizeMinValue[sizeKey] then
                qualitySizeMinValue[sizeKey] = v
            end

            -- 品类内 avg 聚合
            catSum = catSum + v
            catCount = catCount + 1

            local sk = w .. "x" .. h
            sizeSum[sk] = (sizeSum[sk] or 0) + v
            sizeCount[sk] = (sizeCount[sk] or 0) + 1

            qualSum[q] = (qualSum[q] or 0) + v
            qualCount[q] = (qualCount[q] or 0) + 1

            -- 品质全局加权聚合
            qualitySumWeighted[q] = (qualitySumWeighted[q] or 0) + v * catWeight
            qualityCountWeighted[q] = (qualityCountWeighted[q] or 0) + catWeight
        end

        -- 品类均价
        if catCount > 0 then
            categoryAvg[catId] = catSum / catCount
        end

        -- 品类+尺寸均价
        for sk, sum in pairs(sizeSum) do
            categorySizeAvg[catId .. ":" .. sk] = sum / sizeCount[sk]
        end

        -- 品类+品质均价
        for q, sum in pairs(qualSum) do
            categoryQualityAvg[catId .. ":" .. q] = sum / qualCount[q]
        end
    end

    -- 品质全局加权均价（无品类信息时使用）
    for q, sum in pairs(qualitySumWeighted) do
        qualityAvgWeighted[q] = sum / qualityCountWeighted[q]
    end

    -- 池均价 = Σ(品类概率 × 品类均价)
    local poolAvg = 0
    if totalCatWeight > 0 then
        for _, cat in ipairs(allCategories) do
            local catId = cat.id
            local catWeight = categoryWeights[catId] or 1
            local catAvg = categoryAvg[catId] or 0
            poolAvg = poolAvg + (catWeight / totalCatWeight) * catAvg
        end
    end

    -- 池加权中位数（robust estimator，不受极端高价物品影响）
    -- 将每个物品按品类权重展开后取中位数
    local weightedValues = {}
    for _, cat in ipairs(allCategories) do
        local catId = cat.id
        local catWeight = categoryWeights[catId] or 1
        for _, item in ipairs(cat.items) do
            for _ = 1, catWeight do
                weightedValues[#weightedValues + 1] = item.value
            end
        end
    end
    table.sort(weightedValues)
    local poolMedian = 0
    if #weightedValues > 0 then
        local mid = math.ceil(#weightedValues / 2)
        poolMedian = weightedValues[mid]
    end

    -- 池几何均价（poolAvg 与 poolMedian 的几何平均）
    -- 物品价值分布通常为极端右偏（白色 100 到红色 2800万），
    -- 算术均值被高价物品严重拉高，中位数被大量廉价物品严重拉低；
    -- 几何均价（sqrt(avg × median)）是更合理的单件价值估计
    local poolGeoMean = 0
    if poolAvg > 0 and poolMedian > 0 then
        poolGeoMean = math.sqrt(poolAvg * poolMedian)
    else
        poolGeoMean = math.max(poolAvg, poolMedian)
    end

    -- 每格最低价密度：池内所有物品中 value/cells 的最小值（白色最低价 / 最大格子数 的保守估计）
    -- 用途：totalCells × minValuePerCell = 整个仓库的绝对最低价下界
    local minValuePerCell = math.huge
    for _, cat in ipairs(allCategories) do
        for _, item in ipairs(cat.items) do
            local cells = (item.cols or 1) * (item.rows or 1)
            if cells > 0 then
                local density = item.value / cells
                if density < minValuePerCell then
                    minValuePerCell = density
                end
            end
        end
    end
    if minValuePerCell == math.huge then minValuePerCell = 0 end

    -- 每格品质最低价密度：{ [rarityId] = minValue/cell }
    local qualityMinValuePerCell = {}
    for q, minV in pairs(qualityMinValue) do
        -- 对应品质下 1×1 物品的最低价（保守取 qualityMinValue / 1）
        -- 实际上用品质 × 尺寸最小密度更准确，但 qualityMinValue 本身已是最保守的
        qualityMinValuePerCell[q] = minV  -- 1×1 时每格就等于最低价
    end

    local tables = {
        min = {
            qualityMinValue = qualityMinValue,
            qualitySizeMinValue = qualitySizeMinValue,
        },
        avg = {
            categoryAvg = categoryAvg,
            categorySizeAvg = categorySizeAvg,
            categoryQualityAvg = categoryQualityAvg,
            qualityAvgWeighted = qualityAvgWeighted,
        },
        poolAvg = poolAvg,
        poolMedian = poolMedian,
        poolGeoMean = poolGeoMean,
        minValuePerCell = minValuePerCell,
        qualityMinValuePerCell = qualityMinValuePerCell,
    }
    tableCache[whTypeId] = tables
    return tables
end

-- ============================================================================
-- 取值函数
-- ============================================================================

--- min 模式：查询某品质+尺寸的最低价
local function getMinValue(tables, quality, w, h)
    local min = tables.min
    local key = quality .. ":" .. w .. "x" .. h
    return min.qualitySizeMinValue[key] or min.qualityMinValue[quality] or 0
end

--- expected 模式：根据信息层级查询条件期望值
--- @param tables table 查找表
--- @param level number 信息层级 0-3
--- @param item table 仓库物品 { category, rarity, w, h, realValue }
--- @return number 条件期望值
local function getExpectedValue(tables, level, item)
    local avg = tables.avg

    if level >= 3 then
        -- L3：精确值
        return item.realValue or 0
    end

    local cat = item.category
    local q = item.rarity
    local sk = item.w .. "x" .. item.h

    -- 对于未完全揭示的物品，使用 poolGeoMean（几何均价）作为 fallback
    -- poolMedian 被大量廉价物品拉低，poolAvg 被少量极高价物品拉高；
    -- 几何均价 sqrt(poolAvg × poolMedian) 取两者均衡，更接近实际每件物品的期望贡献
    local fallback = tables.poolGeoMean

    if level >= 2 then
        -- L2：已知品质（通常也知道品类）
        if cat then
            local key = cat .. ":" .. q
            if avg.categoryQualityAvg[key] then
                return avg.categoryQualityAvg[key]
            end
        end
        -- 无品类信息，回退到全池品质加权均价
        return avg.qualityAvgWeighted[q] or fallback
    end

    if level >= 1 then
        -- L1：已知轮廓/尺寸（通常也知道品类）
        if cat then
            local key = cat .. ":" .. sk
            if avg.categorySizeAvg[key] then
                return avg.categorySizeAvg[key]
            end
            -- 该品类无匹配尺寸，回退到品类均价
            return avg.categoryAvg[cat] or fallback
        end
        return fallback
    end

    -- L0：只知道品类
    if cat then
        return avg.categoryAvg[cat] or fallback
    end

    -- 未知：池加权中位数（robust fallback）
    return fallback
end

-- ============================================================================
-- 从信息流收集约束（min 模式专用）
-- ============================================================================

--- 收集品质数量约束 { [rarityId] = count }
local function collectRarityCounts(publicInfos, skillInfos)
    local known = {}

    local function extract(info)
        if info.rarityId and info.rarityCount then
            known[info.rarityId] = info.rarityCount
        end
    end

    local function extractAll(info)
        extract(info)
        if info.extraInfos then
            for _, extra in ipairs(info.extraInfos) do
                extract(extra)
            end
        end
    end

    for _, info in ipairs(publicInfos) do extractAll(info) end
    for _, info in ipairs(skillInfos) do extractAll(info) end
    return known
end

--- 收集价值区间提示的最大下界
local function collectValueHintLow(publicInfos, skillInfos)
    local bestLow = 0

    local function check(info)
        if info.valueLow and info.valueLow > bestLow then bestLow = info.valueLow end
    end

    for _, info in ipairs(publicInfos) do check(info) end
    for _, info in ipairs(skillInfos) do
        check(info)
        if info.extraInfos then
            for _, extra in ipairs(info.extraInfos) do check(extra) end
        end
    end
    return bestLow
end

--- 收集 total_cells / avg_cells_per_item 信息：返回 { totalCells, totalCount } 或 nil
--- 优先选格子数最多的（信息最充分），多轮信息取 totalCells 最大值
local function collectTotalCellsInfo(publicInfos, skillInfos)
    local bestTotalCells = nil
    local bestTotalCount = nil

    local function check(info)
        if info.type == "total_cells" and info.totalCells and info.totalCount then
            if not bestTotalCells or info.totalCells > bestTotalCells then
                bestTotalCells = info.totalCells
                bestTotalCount = info.totalCount
            end
        end
        if info.type == "avg_cells_per_item" and info.avgCellsPerItem and info.totalCount then
            -- avg × count = totalCells 的另一种来源
            local tc = math.floor(info.avgCellsPerItem * info.totalCount + 0.5)
            if not bestTotalCells or tc > bestTotalCells then
                bestTotalCells = tc
                bestTotalCount = info.totalCount
            end
        end
    end

    for _, info in ipairs(publicInfos) do check(info) end
    for _, info in ipairs(skillInfos) do
        check(info)
        if info.extraInfos then
            for _, extra in ipairs(info.extraInfos) do check(extra) end
        end
    end

    if bestTotalCells and bestTotalCount then
        return { totalCells = bestTotalCells, totalCount = bestTotalCount }
    end
    return nil
end

--- 收集 random_avg_value 信息：返回仓库质量比值（sampleAvgValue / poolGeoMean），或 nil
--- 比值 > 1 = 好仓（样品均价高于池几何均价），比值 < 1 = 坏仓
--- 用于调整未知物品的期望估价方向，不用作绝对下限
local function collectSampleQualityRatio(publicInfos, skillInfos, poolGeoMean)
    if not poolGeoMean or poolGeoMean <= 0 then return nil end
    local bestSampleAvg = nil
    local function check(info)
        if info.type == "random_avg_value" and info.sampleAvgValue and info.sampleAvgValue > 0 then
            if not bestSampleAvg or info.sampleAvgValue > bestSampleAvg then
                bestSampleAvg = info.sampleAvgValue
            end
        end
    end
    for _, info in ipairs(publicInfos) do check(info) end
    for _, info in ipairs(skillInfos) do
        check(info)
        if info.extraInfos then
            for _, extra in ipairs(info.extraInfos) do check(extra) end
        end
    end
    if not bestSampleAvg then return nil end
    return bestSampleAvg / poolGeoMean
end

--- 收集 L0V 技能信息中的已知批次总价值约束
--- 返回 [{ totalValue, itemIdxs }] 列表
local function collectKnownLotValues(skillInfos)
    local lots = {}
    local function extract(info)
        if info.knownTotalValue and info.coveredItemIdxs and #info.coveredItemIdxs > 0 then
            lots[#lots + 1] = {
                totalValue = info.knownTotalValue,
                itemIdxs   = info.coveredItemIdxs,
            }
        end
    end
    for _, info in ipairs(skillInfos) do
        extract(info)
        if info.extraInfos then
            for _, extra in ipairs(info.extraInfos) do extract(extra) end
        end
    end
    return lots
end

-- ============================================================================
-- 核心算法：最低估价 (min 模式)
-- ============================================================================

--- 计算已知信息下的仓库预估最低总价
--- @param infoState table 信息状态 { publicInfos, skillInfos, itemRevealLevels }
--- @param whTypeId string|nil 仓库类型ID（nil=使用 grocery）
--- @return number estimatedMin 预估最低价
--- @return number knownCount 已揭晓物品数（level 2+3）
--- @return number totalCount 总物品数
function EstimateValue.Calculate(infoState, whTypeId)
    local items = _GameState.GetWarehouseItems()
    if not items or #items == 0 then
        return 0, 0, 0
    end

    if not infoState then
        return 0, 0, #items
    end

    local tables = buildTables(whTypeId or "suburb_basement")

    local publicInfos = infoState.publicInfos or {}
    local skillInfos = infoState.skillInfos or {}
    local revealLevels = infoState.itemRevealLevels or {}

    -- 按揭示等级分三档
    local fullyRevealed = {}     -- level 3：价值已知
    local qualityRevealed = {}   -- level 2：品质+尺寸已知
    local unknownItems = {}      -- level 0-1：品质未知

    for _, item in ipairs(items) do
        local level = revealLevels[item.idx] or 0
        if level >= 3 then
            fullyRevealed[#fullyRevealed + 1] = item
        elseif level >= 2 then
            qualityRevealed[#qualityRevealed + 1] = item
        else
            unknownItems[#unknownItems + 1] = item
        end
    end

    local knownCount = #fullyRevealed + #qualityRevealed

    -- 追踪每件物品的当前最低估价（供 L0V 约束使用）
    local perItemMin = {}  -- [item.idx] = 当前最低估价

    -- 累加已知物品的最低估价
    local totalMin = 0

    -- level 3：直接用真实价值
    for _, item in ipairs(fullyRevealed) do
        local v = item.realValue or 0
        totalMin = totalMin + v
        perItemMin[item.idx] = v
    end

    -- level 2：用该品质+尺寸在物品池中的最低价
    for _, item in ipairs(qualityRevealed) do
        local v = getMinValue(tables, item.rarity, item.w, item.h)
        totalMin = totalMin + v
        perItemMin[item.idx] = v
    end

    -- 仓库质量信号：用于调整 L0/L1 未知物品估值
    -- min 模式：仅在坏仓（ratio < 1）时向下收紧，好仓保持保守不动
    local qualityRatio = collectSampleQualityRatio(publicInfos, skillInfos, tables.poolGeoMean)
    local unknownMult = 1.0
    if qualityRatio and qualityRatio < 1.0 then
        -- 阻尼：取平方根，防止小样本极端偏低拖垮整体
        unknownMult = math.sqrt(qualityRatio)
    end

    -- 处理未知物品（通过品质名额约束）
    local rarityCounts = collectRarityCounts(publicInfos, skillInfos)

    if next(rarityCounts) then
        local remaining = {}
        for rarId, count in pairs(rarityCounts) do
            remaining[rarId] = count
        end

        for _, item in ipairs(fullyRevealed) do
            if remaining[item.rarity] then
                remaining[item.rarity] = remaining[item.rarity] - 1
                if remaining[item.rarity] <= 0 then remaining[item.rarity] = nil end
            end
        end
        for _, item in ipairs(qualityRevealed) do
            if remaining[item.rarity] then
                remaining[item.rarity] = remaining[item.rarity] - 1
                if remaining[item.rarity] <= 0 then remaining[item.rarity] = nil end
            end
        end

        local quotas = {}
        for rarId, count in pairs(remaining) do
            for _ = 1, count do
                quotas[#quotas + 1] = rarId
            end
        end

        if #quotas > 0 then
            local whiteBase = 0
            local itemWhiteCost = {}
            for i, item in ipairs(unknownItems) do
                local wc = getMinValue(tables, "white", item.w, item.h)
                itemWhiteCost[i] = wc
                whiteBase = whiteBase + wc
                perItemMin[item.idx] = wc  -- 初始按 white 记录
            end

            local quotasByRarity = {}
            for _, rarId in ipairs(quotas) do
                quotasByRarity[rarId] = (quotasByRarity[rarId] or 0) + 1
            end

            local assigned = {}
            for rarId, count in pairs(quotasByRarity) do
                local candidates = {}
                for i, item in ipairs(unknownItems) do
                    if not assigned[i] then
                        local rarCost = getMinValue(tables, rarId, item.w, item.h)
                        local delta = rarCost - itemWhiteCost[i]
                        candidates[#candidates + 1] = { idx = i, item = item, delta = delta, rarCost = rarCost }
                    end
                end
                table.sort(candidates, function(a, b) return a.delta < b.delta end)
                local take = math.min(count, #candidates)
                for j = 1, take do
                    local c = candidates[j]
                    assigned[c.idx] = true
                    whiteBase = whiteBase + c.delta
                    perItemMin[c.item.idx] = c.rarCost  -- 更新为分配到的稀有度最低价
                end
            end

            -- 坏仓信号：对未知物品整体向下收紧（min 模式仅在 ratio<1 时生效）
            totalMin = totalMin + whiteBase * unknownMult
        else
            for _, item in ipairs(unknownItems) do
                local v = getMinValue(tables, "white", item.w, item.h) * unknownMult
                totalMin = totalMin + v
                perItemMin[item.idx] = v
            end
        end
    else
        for _, item in ipairs(unknownItems) do
            local v = getMinValue(tables, "white", item.w, item.h) * unknownMult
            totalMin = totalMin + v
            perItemMin[item.idx] = v
        end
    end

    -- L0V 约束：已知批次总价值作为下界
    -- 若某技能揭示"白绿蓝共X件总价Y"，则这些物品的最低估价之和至少为 Y
    local knownLots = collectKnownLotValues(skillInfos)
    for _, lot in ipairs(knownLots) do
        local lotCurrentSum = 0
        for _, idx in ipairs(lot.itemIdxs) do
            lotCurrentSum = lotCurrentSum + (perItemMin[idx] or 0)
        end
        if lotCurrentSum < lot.totalValue then
            totalMin = totalMin + (lot.totalValue - lotCurrentSum)
        end
    end

    -- totalCells 约束：总格子数 × 每格最低价密度 = 绝对最低价下界
    -- "总格数乘以价值最低价，那不就是最低价吗"
    local cellsInfo = collectTotalCellsInfo(publicInfos, skillInfos)
    if cellsInfo then
        local cellsFloor = cellsInfo.totalCells * tables.minValuePerCell
        if cellsFloor > totalMin then
            totalMin = cellsFloor
        end
    end

    local hintLow = collectValueHintLow(publicInfos, skillInfos)
    return math.max(totalMin, hintLow), knownCount, #items
end

-- ============================================================================
-- 核心算法：期望估价 (expected 模式)
-- ============================================================================

--- 计算已知信息下的仓库期望总价值（中性无偏估价）
--- 每件物品根据信息层级取条件期望值，未知物品取池加权中位数
--- @param infoState table 信息状态 { publicInfos, skillInfos, itemRevealLevels }
--- @param whTypeId string|nil 仓库类型ID（nil=使用 grocery）
--- @return number expectedTotal 期望总价值
--- @return number poolAvg 池均价（单件期望）—— 兼容旧接口
--- @return number itemCount 物品总数
--- @return number poolMedian 池加权中位数（robust estimator）
function EstimateValue.CalculateExpected(infoState, whTypeId)
    local items = _GameState.GetWarehouseItems()
    if not items or #items == 0 then
        return 0, 0, 0, 0
    end

    local tables = buildTables(whTypeId or "suburb_basement")

    if not infoState then
        -- 无信息状态，全部按几何均价估算（比中位数更准确的 L0 估计）
        return tables.poolGeoMean * #items, tables.poolAvg, #items, tables.poolMedian
    end

    local revealLevels = infoState.itemRevealLevels or {}
    local publicInfos = infoState.publicInfos or {}
    local skillInfos  = infoState.skillInfos  or {}

    -- 仓库质量信号：好仓/坏仓调整 L0/L1 未知物品的期望估价
    -- expected 模式双向生效（阻尼平方根），L2/L3 已有具体信息不受影响
    local qualityRatio = collectSampleQualityRatio(publicInfos, skillInfos, tables.poolGeoMean)
    local dampedMult = 1.0
    if qualityRatio then
        dampedMult = math.sqrt(qualityRatio)
        -- 限制范围，防止极端样本歪曲整体
        dampedMult = math.max(0.5, math.min(2.0, dampedMult))
    end

    local expectedTotal = 0
    for _, item in ipairs(items) do
        local level = revealLevels[item.idx] or 0
        local est = getExpectedValue(tables, level, item)
        -- L0/L1 物品尚无品质/精确信息，按仓库质量信号调整
        if level < 2 then
            est = est * dampedMult
        end
        expectedTotal = expectedTotal + est
    end

    return expectedTotal, tables.poolAvg, #items, tables.poolMedian
end

-- ============================================================================
-- 辅助接口
-- ============================================================================

--- 获取指定仓库类型的池均价
--- @param whTypeId string|nil 仓库类型ID
--- @return number poolAvg
function EstimateValue.GetPoolAverage(whTypeId)
    local tables = buildTables(whTypeId or "suburb_basement")
    return tables.poolAvg
end

--- 获取指定仓库类型的池加权中位数（robust estimator）
--- @param whTypeId string|nil 仓库类型ID
--- @return number poolMedian
function EstimateValue.GetPoolMedian(whTypeId)
    local tables = buildTables(whTypeId or "suburb_basement")
    return tables.poolMedian
end

--- 清除指定仓库类型的查找表缓存（供外部调用，一般不需要）
--- @param whTypeId string|nil 仓库类型ID（nil=清除所有）
function EstimateValue.ClearCache(whTypeId)
    if whTypeId then
        tableCache[whTypeId] = nil
    else
        tableCache = {}
    end
end

return EstimateValue
