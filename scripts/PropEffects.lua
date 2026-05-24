-- ============================================================================
-- PropEffects.lua - 道具效果计算函数
-- ============================================================================
-- 职责：实现所有 Props.EFFECT 类型对应的具体效果逻辑
--   - 输入：effectParams + warehouseItems
--   - 输出：{ text, icon, reveals?, type?, sampleAvgValue? }
-- ============================================================================

local Config = require("Config")

local PropEffects = {}

-- 品质优先级（用于比较高低）
local RARITY_RANK = { white = 1, green = 2, blue = 3, purple = 4, red = 5 }

-- 格式化金额（≥1万显示为"X.X万"）
local function formatVal(v)
    if v >= 10000 then
        return string.format("%.1f万", v / 10000)
    end
    return tostring(math.floor(v))
end

-- Fisher-Yates 原地洗牌（返回同一个 table）
local function shuffle(t)
    for i = #t, 2, -1 do
        local j = math.random(1, i)
        t[i], t[j] = t[j], t[i]
    end
    return t
end

-- ── 白/绿品质效果 ────────────────────────────────────────────────────────────

--- 显示指定品质藏品的总格数
function PropEffects.RarityCellCount(params, warehouseItems)
    local rarSet, rarNames = {}, {}
    for _, r in ipairs(params.rarities) do
        rarSet[r] = true
        local rar = Config.GetRarity(r)
        rarNames[#rarNames + 1] = rar and rar.name or r
    end

    local totalCells = 0
    for _, item in ipairs(warehouseItems) do
        if rarSet[item.rarity] then
            totalCells = totalCells + (item.w or 1) * (item.h or 1)
        end
    end

    local text = table.concat(rarNames, "和") .. "品质物品共占 " .. totalCells .. " 格"
    return {
        text = text, icon = "",
        type = "rarity_total_cells",
        rarities = params.rarities,
        totalCells = totalCells,
    }
end

--- 显示指定品质物品的总数量
function PropEffects.RarityItemCount(params, warehouseItems)
    local rarSet, rarNames = {}, {}
    for _, r in ipairs(params.rarities) do
        rarSet[r] = true
        local rar = Config.GetRarity(r)
        rarNames[#rarNames + 1] = rar and rar.name or r
    end

    local count = 0
    for _, item in ipairs(warehouseItems) do
        if rarSet[item.rarity] then count = count + 1 end
    end

    local text = table.concat(rarNames, "和") .. "品质物品共有 " .. count .. " 件"
    return {
        text = text, icon = "",
        type = "quality_count",
        rarityId = params.rarities[1],   -- 当前所有该类道具均为单品质
        rarityCount = count,
    }
end

--- 随机显示N件物品轮廓（L1）
function PropEffects.RandomSilhouette(params, warehouseItems)
    local n = params.count or 4
    local candidates = shuffle({ table.unpack(warehouseItems) })

    local reveals = {}
    local picked = math.min(n, #candidates)
    for i = 1, picked do
        if candidates[i].idx then
            reveals[#reveals + 1] = { itemIdx = candidates[i].idx, targetLevel = 1 }
        end
    end

    return { text = "透视了 " .. picked .. " 件物品的轮廓", icon = "", reveals = reveals }
end

--- 显示占位N格物品的平均价值
function PropEffects.SizeAvgValue(params, warehouseItems)
    local targetCells = params.cellCount or 4
    local totalValue, count = 0, 0

    for _, item in ipairs(warehouseItems) do
        if (item.w or 1) * (item.h or 1) == targetCells then
            totalValue = totalValue + (item.realValue or Config.GetItemRealValue(item))
            count = count + 1
        end
    end

    if count == 0 then
        return { text = "仓库中暂无占位" .. targetCells .. "格的物品", icon = "" }
    end

    local avgValue = math.floor(totalValue / count)
    return {
        text = "占位" .. targetCells .. "格物品平均价值 " .. formatVal(avgValue),
        icon = "",
        type = "random_avg_value",
        sampleAvgValue = avgValue,
        sampleCellCount = targetCells,   -- 用于 AI 对比同尺寸池均价，而非全池均价
        sampleCount = count,             -- 实际 N格物品件数，供 sampleCoverageDamp 精确计算
        totalCount = #warehouseItems,    -- 仓库总件数
    }
end

--- 随机显示一件物品的完整信息（L3）
function PropEffects.RandomItemInfo(params, warehouseItems)
    if #warehouseItems == 0 then
        return { text = "仓库中没有物品", icon = "" }
    end

    local item = warehouseItems[math.random(1, #warehouseItems)]
    local rar = Config.GetRarity(item.rarity)
    local val = item.realValue or Config.GetItemRealValue(item)

    local reveals = {}
    if item.idx then
        reveals[#reveals + 1] = { itemIdx = item.idx, targetLevel = 4 }
    end

    local text = "看透：" .. item.name .. "（" .. (rar and rar.name or item.rarity) .. "，" .. formatVal(val) .. "）"
    return { text = text, icon = "", reveals = reveals, revealedItem = item }
end

--- 随机显示N件物品的完整信息（L3）
function PropEffects.RandomItemInfoMulti(params, warehouseItems)
    local n = params.count or 2
    if #warehouseItems == 0 then
        return { text = "仓库中没有物品", icon = "" }
    end

    local candidates = shuffle({ table.unpack(warehouseItems) })
    local lines, reveals = {}, {}
    local picked = math.min(n, #candidates)

    for i = 1, picked do
        local item = candidates[i]
        local rar = Config.GetRarity(item.rarity)
        local val = item.realValue or Config.GetItemRealValue(item)
        lines[#lines + 1] = item.name .. "（" .. (rar and rar.name or item.rarity) .. "，" .. formatVal(val) .. "）"
        if item.idx then
            reveals[#reveals + 1] = { itemIdx = item.idx, targetLevel = 4 }
        end
    end

    return {
        text = "看透 " .. picked .. " 件：" .. table.concat(lines, "；"),
        icon = "", reveals = reveals,
    }
end

--- 显示指定品质物品的总数量、总价值（可选均价）
--- params.showTotalOnly=true 时只显示总价值
function PropEffects.RarityAvgValue(params, warehouseItems)
    local rarity = params.rarity or "green"
    local rar = Config.GetRarity(rarity)
    local rarName = rar and rar.name or rarity

    local totalValue, count = 0, 0
    for _, item in ipairs(warehouseItems) do
        if item.rarity == rarity then
            totalValue = totalValue + (item.realValue or Config.GetItemRealValue(item))
            count = count + 1
        end
    end

    if count == 0 then
        return { text = rarName .. "品质物品共 0 件，总价值 0", icon = "" }
    end

    local avgValue = math.floor(totalValue / count)
    local text
    if params.showTotalOnly then
        text = rarName .. "品质物品共 " .. count .. " 件，总价值 " .. formatVal(totalValue)
    else
        text = rarName .. "品质物品共 " .. count .. " 件，总价值 " .. formatVal(totalValue) .. "，均价 " .. formatVal(avgValue)
    end

    return {
        text = text, icon = "",
        type = "random_avg_value",
        sampleAvgValue = avgValue,
        sampleRarity = rarity,           -- 用于 AI 对比同品质池均价，而非全池均价
    }
end

--- 显示指定品质物品的平均格数
function PropEffects.RarityAvgCellCount(params, warehouseItems)
    local rarSet, rarNames = {}, {}
    for _, r in ipairs(params.rarities) do
        rarSet[r] = true
        local rar = Config.GetRarity(r)
        rarNames[#rarNames + 1] = rar and rar.name or r
    end

    local totalCells, count = 0, 0
    for _, item in ipairs(warehouseItems) do
        if rarSet[item.rarity] then
            totalCells = totalCells + (item.w or 1) * (item.h or 1)
            count = count + 1
        end
    end

    local qualityStr = table.concat(rarNames, "和")
    if count == 0 then
        return { text = qualityStr .. "品质物品暂无数据", icon = "" }
    end

    local avgCellCount = totalCells / count
    local text = qualityStr .. "品质物品平均占 " .. string.format("%.1f", avgCellCount) .. " 格"
    return {
        text = text, icon = "",
        type = "rarity_avg_cell_count",
        rarities = params.rarities,
        avgCellCount = avgCellCount,
    }
end

-- ── 蓝色品质效果（每日商店）──────────────────────────────────────────────────

--- 显示仓库中最高品质物品的轮廓（L1）
function PropEffects.TopRaritySilhouette(params, warehouseItems)
    if #warehouseItems == 0 then
        return { text = "仓库中没有物品", icon = "" }
    end

    -- 找出最高品质等级
    local topRank = 0
    for _, item in ipairs(warehouseItems) do
        local rank = RARITY_RANK[item.rarity] or 0
        if rank > topRank then topRank = rank end
    end

    -- 收集所有最高品质物品，随机选一件揭示轮廓
    local topItems = {}
    for _, item in ipairs(warehouseItems) do
        if (RARITY_RANK[item.rarity] or 0) == topRank then
            topItems[#topItems + 1] = item
        end
    end

    local picked = topItems[math.random(1, #topItems)]
    local reveals = {}
    if picked.idx then
        reveals[#reveals + 1] = { itemIdx = picked.idx, targetLevel = 1 }
    end

    local rar = Config.GetRarity(picked.rarity)
    local rarName = rar and rar.name or picked.rarity
    local text = "已显示一件" .. rarName .. "品质物品的轮廓"
    return { text = text, icon = "", reveals = reveals }
end

--- 显示仓库中占格最多的物品的轮廓（L1）
function PropEffects.LargestItemSilhouette(params, warehouseItems)
    if #warehouseItems == 0 then
        return { text = "仓库中没有物品", icon = "" }
    end

    local maxCells = 0
    for _, item in ipairs(warehouseItems) do
        local cells = (item.w or 1) * (item.h or 1)
        if cells > maxCells then maxCells = cells end
    end

    -- 收集所有最大格物品，随机选一件揭示轮廓
    local largeItems = {}
    for _, item in ipairs(warehouseItems) do
        if (item.w or 1) * (item.h or 1) == maxCells then
            largeItems[#largeItems + 1] = item
        end
    end

    local picked = largeItems[math.random(1, #largeItems)]
    local reveals = {}
    if picked.idx then
        reveals[#reveals + 1] = { itemIdx = picked.idx, targetLevel = 1 }
    end

    local text = "已显示一件占位最多（" .. maxCells .. " 格）的物品轮廓"
    return { text = text, icon = "", reveals = reveals }
end

--- 显示指定品类（或随机一个）的所有物品轮廓（L1）
--- params.categoryId: 指定品类 id（nil 则随机）
--- params.categoryName: 品类中文名（用于显示文本）
function PropEffects.CategorySilhouette(params, warehouseItems)
    if #warehouseItems == 0 then
        return { text = "仓库中没有物品", icon = "" }
    end

    local chosen     = params.categoryId
    local chosenName = params.categoryName

    if not chosen then
        -- 统计仓库中实际存在的品类，随机选一个
        local catSet, catList = {}, {}
        for _, item in ipairs(warehouseItems) do
            local cat = item.category or "unknown"
            if not catSet[cat] then
                catSet[cat] = true
                catList[#catList + 1] = cat
            end
        end
        chosen = catList[math.random(1, #catList)]
    end

    local catItems, reveals = {}, {}
    for _, item in ipairs(warehouseItems) do
        if (item.category or "unknown") == chosen then
            catItems[#catItems + 1] = item
            if item.idx then
                reveals[#reveals + 1] = { itemIdx = item.idx, targetLevel = 1 }
            end
        end
    end

    if #catItems == 0 then
        local name = chosenName or chosen
        return { text = name .. "品类：仓库中暂无此类物品", icon = "" }
    end

    local name = chosenName or chosen
    local text = "已显示" .. name .. "品类物品的轮廓"
    return { text = text, icon = "", reveals = reveals }
end

-- ── 紫色高阶效果 ──────────────────────────────────────────────────────────────

--- 显示仓库中所有物品的总数量
function PropEffects.TotalItemCount(params, warehouseItems)
    local count = #warehouseItems
    return {
        text = "仓库共有 " .. count .. " 件物品", icon = "",
        type = "total_item_count",
        totalCount = count,
    }
end

--- 随机显示N件物品的品质（L2_hint：只知品质，不暴露轮廓）
function PropEffects.RandomQualityMulti(params, warehouseItems)
    local n = params.count or 8
    if #warehouseItems == 0 then
        return { text = "仓库中没有物品", icon = "" }
    end

    local candidates = shuffle({ table.unpack(warehouseItems) })
    local reveals = {}
    local picked = math.min(n, #candidates)

    for i = 1, picked do
        local item = candidates[i]
        if item.idx then
            reveals[#reveals + 1] = { itemIdx = item.idx, targetLevel = 2 }
        end
    end

    return { text = "感知了 " .. picked .. " 件物品的品质", icon = "", reveals = reveals }
end

--- 随机显示一件最高品质物品的价值（纯文字）
function PropEffects.TopRarityItemValue(params, warehouseItems)
    if #warehouseItems == 0 then
        return { text = "仓库中没有物品", icon = "" }
    end

    -- 找出最高品质等级
    local topRank = 0
    for _, item in ipairs(warehouseItems) do
        local rank = RARITY_RANK[item.rarity] or 0
        if rank > topRank then topRank = rank end
    end

    -- 收集所有最高品质物品，随机选一件
    local topItems = {}
    for _, item in ipairs(warehouseItems) do
        if (RARITY_RANK[item.rarity] or 0) == topRank then
            topItems[#topItems + 1] = item
        end
    end

    local item = topItems[math.random(1, #topItems)]
    local rar = Config.GetRarity(item.rarity)
    local rarName = rar and rar.name or item.rarity
    local val = item.realValue or Config.GetItemRealValue(item)

    return {
        text = rarName .. "品质物品价值 " .. formatVal(val), icon = "",
        type = "quality_avg_value",
        rarityId = item.rarity,
        rarityAvgValue = val,
        isSingleTopItem = true,          -- 标记：这是仓库内最高品质的单件价格，而非品质均价
    }
end

--- 显示占格最多的物品的完整信息（L4）
function PropEffects.LargestItemInfo(params, warehouseItems)
    if #warehouseItems == 0 then
        return { text = "仓库中没有物品", icon = "" }
    end

    local maxCells = 0
    for _, item in ipairs(warehouseItems) do
        local cells = (item.w or 1) * (item.h or 1)
        if cells > maxCells then maxCells = cells end
    end

    -- 收集所有最大件，随机选一件揭示完整信息
    local largeItems = {}
    for _, item in ipairs(warehouseItems) do
        if (item.w or 1) * (item.h or 1) == maxCells then
            largeItems[#largeItems + 1] = item
        end
    end

    local item = largeItems[math.random(1, #largeItems)]
    local rar = Config.GetRarity(item.rarity)
    local val = item.realValue or Config.GetItemRealValue(item)

    local reveals = {}
    if item.idx then
        reveals[#reveals + 1] = { itemIdx = item.idx, targetLevel = 4 }
    end

    local text = "重器：" .. item.name .. "（" .. (rar and rar.name or item.rarity) .. "，占" .. maxCells .. "格，" .. formatVal(val) .. "）"
    return { text = text, icon = "", reveals = reveals, revealedItem = item }
end

-- ── 金色高阶效果 ──────────────────────────────────────────────────────────────

--- 显示仓库中所有物品的总格数
function PropEffects.TotalCellCount(params, warehouseItems)
    local total = 0
    for _, item in ipairs(warehouseItems) do
        total = total + (item.w or 1) * (item.h or 1)
    end
    return {
        text = "仓库物品共占 " .. total .. " 格", icon = "",
        type = "total_cell_count",
        totalCells = total,
    }
end

--- 显示仓库中所有红色物品的轮廓（L1）
function PropEffects.RedItemSilhouette(params, warehouseItems)
    local reveals = {}
    for _, item in ipairs(warehouseItems) do
        if item.rarity == "red" and item.idx then
            reveals[#reveals + 1] = { itemIdx = item.idx, targetLevel = 1 }
        end
    end

    if #reveals == 0 then
        return { text = "仓库中暂无红色品质物品", icon = "" }
    end

    return { text = "已显示红色品质物品的轮廓", icon = "", reveals = reveals }
end

--- 显示占格最多的前N件物品的完整信息（L4）
function PropEffects.TopNLargestInfo(params, warehouseItems)
    local n = (params and params.topN) or 3
    if #warehouseItems == 0 then
        return { text = "仓库中没有物品", icon = "" }
    end

    -- 按格数降序排列
    local sorted = { table.unpack(warehouseItems) }
    table.sort(sorted, function(a, b)
        return (a.w or 1) * (a.h or 1) > (b.w or 1) * (b.h or 1)
    end)

    local reveals, lines = {}, {}
    local picked = math.min(n, #sorted)
    for i = 1, picked do
        local item = sorted[i]
        local rar = Config.GetRarity(item.rarity)
        local val = item.realValue or Config.GetItemRealValue(item)
        local cells = (item.w or 1) * (item.h or 1)
        lines[#lines + 1] = item.name .. "（" .. (rar and rar.name or item.rarity) .. "，" .. cells .. "格，" .. formatVal(val) .. "）"
        if item.idx then
            reveals[#reveals + 1] = { itemIdx = item.idx, targetLevel = 4 }
        end
    end

    return {
        text = "前" .. picked .. "大件：" .. table.concat(lines, "；"),
        icon = "", reveals = reveals,
    }
end

--- 随机显示一件最高品质物品的完整信息（L4）
function PropEffects.TopRarityFullInfo(params, warehouseItems)
    if #warehouseItems == 0 then
        return { text = "仓库中没有物品", icon = "" }
    end

    -- 找出最高品质等级
    local topRank = 0
    for _, item in ipairs(warehouseItems) do
        local rank = RARITY_RANK[item.rarity] or 0
        if rank > topRank then topRank = rank end
    end

    -- 收集所有最高品质物品，随机选一件
    local topItems = {}
    for _, item in ipairs(warehouseItems) do
        if (RARITY_RANK[item.rarity] or 0) == topRank then
            topItems[#topItems + 1] = item
        end
    end

    local item = topItems[math.random(1, #topItems)]
    local rar = Config.GetRarity(item.rarity)
    local val = item.realValue or Config.GetItemRealValue(item)

    local reveals = {}
    if item.idx then
        reveals[#reveals + 1] = { itemIdx = item.idx, targetLevel = 4 }
    end

    local rarName = rar and rar.name or item.rarity
    local text = "极品鉴定：" .. item.name .. "（" .. rarName .. "，" .. formatVal(val) .. "）"
    return { text = text, icon = "", reveals = reveals, revealedItem = item }
end

return PropEffects
