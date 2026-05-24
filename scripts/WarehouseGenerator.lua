-- ============================================================================
-- WarehouseGenerator.lua - 仓库生成算法（编排者）
-- 根据区域+仓库类型生成物品并放置到 m×n 格子中
-- ============================================================================

local Config        = require("Config")
local RngGrid       = require("WG.RngGrid")
local ItemPool      = require("WG.ItemPool")
local SessionParams = require("WG.SessionParams")

local WG = {}

local COLS     = Config.GAME.LootColumns
local MAX_ROWS = Config.GAME.LootMaxRows
local MAX_CELLS = COLS * MAX_ROWS

--- 生成一个仓库的物品列表和格子布局
--- @param regionId string|nil 区域ID（nil=随机选择）
--- @param warehouseTypeId string|nil 仓库类型ID（nil=根据区域随机选择）
--- @param diffIdx number|nil 难度索引（1-based，nil=默认第一个）
--- @param seed number|nil 随机种子（nil=自动生成；联机时传入相同 seed 可复现完全相同仓库）
--- @return table result { region, warehouseType, items, grid, totalCells, totalValue, usedRows, seed }
function WG.Generate(regionId, warehouseTypeId, diffIdx, seed)
    if not seed or seed == 0 then
        seed = math.random(1, 2147483647)
    end
    RngGrid.seedRng(seed)

    -- 1. 确定区域
    local region
    if regionId then
        for _, r in ipairs(Config.REGIONS) do
            if r.id == regionId then region = r; break end
        end
    end
    if not region then
        region = Config.REGIONS[RngGrid.rng(1, #Config.REGIONS)]
    end

    -- 2. 确定难度
    local difficulties = region.difficulties or {}
    local difficultyIdx = diffIdx or 1
    local difficulty = difficulties[difficultyIdx] or difficulties[1]
    if not difficulty then
        difficulty = { level = "normal", label = "普通", entryFee = 0, expectedValue = 100000, rarityWeights = { 55, 25, 12, 5, 3 } }
    end

    -- 3. 确定仓库类型
    local whTypeId = warehouseTypeId
    if not whTypeId then
        local types = region.warehouseTypes
        whTypeId = types[RngGrid.rng(1, #types)]
    end
    local whType = Config.WAREHOUSE_TYPES[whTypeId]
    if not whType then
        whTypeId = "suburb_basement"
        whType = Config.WAREHOUSE_TYPES[whTypeId]
    end

    -- 4. 合并参数
    local mergedWhType = {
        warehouseValue = difficulty.warehouseValue or difficulty.expectedValue,
        sizeWeights = whType.sizeWeights,
    }

    -- 5. 采样本局参数
    local targetValue, targetCells, targetItemCount, tier = SessionParams.sampleSessionParams(mergedWhType, whTypeId)

    -- ================================================================
    -- 两阶段选品
    -- ================================================================
    local poolMinPrice = ItemPool.getPool(whTypeId).poolMinValue

    local fillerCount  = math.max(1, math.floor(targetItemCount * tier.fillerRatio))
    local premiumCount = math.max(0, targetItemCount - fillerCount)
    local fillerValueFrac2 = tier.fillerRatio * tier.fillerRatio * 0.5
    local fillerCells = math.max(fillerCount, math.floor(targetCells * fillerValueFrac2))

    local fillerValueFrac = tier.fillerRatio * tier.fillerRatio * 0.5
    local fillerBudget    = math.max(fillerCount * poolMinPrice,
                                     math.floor(targetValue * fillerValueFrac))
    fillerBudget = math.min(fillerBudget, targetValue - premiumCount * poolMinPrice)
    fillerBudget = math.max(fillerCount * poolMinPrice, fillerBudget)

    local premiumBudget = targetValue - fillerBudget

    local selected = {}
    local totalSelectedCells = 0

    -- ── 阶段1：filler（多件廉价品）──
    local fillerBudgetRemain = fillerBudget
    local failCount = 0
    while #selected < fillerCount and failCount < 15 do
        if totalSelectedCells >= fillerCells then break end
        if fillerBudgetRemain <= 0 then break end

        local fillerRemain      = fillerCount - #selected
        local remainFillerCells = math.max(1, fillerCells - totalSelectedCells)
        local avgCells          = remainFillerCells / fillerRemain

        local dynWeights = SessionParams.blendedSizeWeights(avgCells, whType.sizeWeights)
        local dynWhType  = { sizeWeights = dynWeights }

        local perItemTarget = fillerBudgetRemain / fillerRemain
        local itemCap = math.min(fillerBudgetRemain, math.max(poolMinPrice, perItemTarget * 2.0))

        local fillerK = math.max(0.3, tier.budgetK * 0.4)
        local entry = ItemPool.pickFromPool(whTypeId, dynWhType, perItemTarget, itemCap, fillerK)
        local itemCells = entry.w * entry.h

        if totalSelectedCells + itemCells > fillerCells + 3 then
            local found = false
            for _ = 1, 8 do
                entry = ItemPool.pickFromPool(whTypeId, dynWhType, perItemTarget, itemCap, fillerK)
                itemCells = entry.w * entry.h
                if totalSelectedCells + itemCells <= fillerCells + 3 then
                    found = true; break
                end
            end
            if not found then failCount = failCount + 1; goto continuePhase1 end
        end

        if entry.item.value > fillerBudgetRemain then
            failCount = failCount + 1; goto continuePhase1
        end

        failCount = 0
        selected[#selected + 1] = entry
        totalSelectedCells = totalSelectedCells + itemCells
        fillerBudgetRemain = fillerBudgetRemain - entry.item.value
        ::continuePhase1::
    end

    -- ── 预算回收 ──
    premiumBudget = premiumBudget + fillerBudgetRemain

    -- ── 阶段2：premium（少件高价品）──
    local premiumBudgetRemain = premiumBudget
    local premiumSpent = 0
    local premiumPicked = 0
    failCount = 0
    while #selected < targetItemCount and failCount < 15 do
        if totalSelectedCells >= targetCells then break end
        if premiumBudgetRemain <= 0 then break end

        local premiumRemain = targetItemCount - #selected
        local remainCells   = math.max(1, targetCells - totalSelectedCells)
        local avgCells      = remainCells / premiumRemain

        local dynWeights = SessionParams.blendedSizeWeights(avgCells, whType.sizeWeights)
        local dynWhType  = { sizeWeights = dynWeights }

        local idealSpent = premiumBudget * (premiumPicked / math.max(1, premiumCount))
        local deficit = idealSpent - premiumSpent
        local baseTarget = premiumBudgetRemain / premiumRemain
        local chaseBoost = math.max(0, deficit * 0.8 / premiumRemain)
        local targetPerPick = math.max(1, baseTarget + chaseBoost)

        local capMult
        if premiumRemain <= 1 then
            capMult = 999
        elseif premiumRemain <= 3 then
            capMult = 15.0
        else
            capMult = 8.0
        end

        local itemCap = math.min(premiumBudgetRemain,
                                 math.max(poolMinPrice, targetPerPick * capMult))

        local deficitRatio = deficit > 0 and (deficit / math.max(1, premiumBudget)) or 0
        local minFloorPct = 0.15 + deficitRatio * 0.35
        local minValue = targetPerPick * minFloorPct
        minValue = math.min(minValue, itemCap * 0.6)
        local lowerBound = targetPerPick * 0.6

        local adaptiveK = tier.budgetK

        local entry = ItemPool.pickFromPool(whTypeId, dynWhType, targetPerPick, itemCap, adaptiveK, lowerBound, minValue)
        local itemCells = entry.w * entry.h

        if totalSelectedCells + itemCells > targetCells + 3 then
            local found = false
            for _ = 1, 8 do
                entry = ItemPool.pickFromPool(whTypeId, dynWhType, targetPerPick, itemCap, adaptiveK, lowerBound, minValue)
                itemCells = entry.w * entry.h
                if totalSelectedCells + itemCells <= targetCells + 3 then
                    found = true; break
                end
            end
            if not found then failCount = failCount + 1; goto continuePhase2 end
        end

        if entry.item.value > premiumBudgetRemain then
            failCount = failCount + 1; goto continuePhase2
        end

        failCount = 0
        selected[#selected + 1] = entry
        totalSelectedCells = totalSelectedCells + itemCells
        premiumBudgetRemain = premiumBudgetRemain - entry.item.value
        premiumSpent = premiumSpent + entry.item.value
        premiumPicked = premiumPicked + 1
        ::continuePhase2::
    end

    -- ── 阶段3：预算补充 (budget flush) ──
    local flushCellLimit = targetCells
    if premiumBudgetRemain > targetValue * 0.20 and totalSelectedCells >= targetCells - 2 then
        flushCellLimit = math.min(MAX_CELLS - 5, math.floor(targetCells * 2.0))
        flushCellLimit = math.max(flushCellLimit, targetCells + 20)
    end

    if premiumBudgetRemain > targetValue * 0.05 and totalSelectedCells < flushCellLimit - 2 then
        local flushMaxItems = 15
        local flushFails = 0
        while flushMaxItems > 0 and premiumBudgetRemain > poolMinPrice and totalSelectedCells < flushCellLimit and flushFails < 15 do
            local remainCells = math.max(1, flushCellLimit - totalSelectedCells)
            local avgCells = math.min(remainCells, 4)
            local dynWeights = SessionParams.blendedSizeWeights(avgCells, whType.sizeWeights)
            local dynWhType = { sizeWeights = dynWeights }

            local flushTarget = premiumBudgetRemain / math.max(1, flushMaxItems)
            local flushK = math.max(0.3, tier.budgetK * 0.5)
            local flushLowerBound = flushTarget * 0.3
            local entry = ItemPool.pickFromPool(whTypeId, dynWhType, flushTarget, premiumBudgetRemain, flushK, flushLowerBound, nil)
            local itemCells = entry.w * entry.h

            if totalSelectedCells + itemCells > flushCellLimit + 3 then
                flushFails = flushFails + 1
                goto continueFlush
            end
            if entry.item.value > premiumBudgetRemain then
                flushFails = flushFails + 1
                goto continueFlush
            end

            flushFails = 0
            selected[#selected + 1] = entry
            totalSelectedCells = totalSelectedCells + itemCells
            premiumBudgetRemain = premiumBudgetRemain - entry.item.value
            flushMaxItems = flushMaxItems - 1
            ::continueFlush::
        end
    end

    -- ================================================================
    -- 打乱顺序后统一放置
    -- ================================================================
    ItemPool.shuffle(selected)

    local items = {}
    local grid = RngGrid.createGrid()
    local occupiedCells = 0

    for _, entry in ipairs(selected) do
        local w = entry.w
        local h = entry.h
        local row, col = RngGrid.findBestPosition(grid, w, h)
        if row then
            local realValue = entry.item.value
            local item = {
                idx = #items + 1,
                name = entry.item.name,
                icon = entry.catIcon,
                w = w,
                h = h,
                rarity = entry.item.quality,
                baseValue = entry.item.value,
                realValue = realValue,
                gridRow = row,
                gridCol = col,
                category = entry.catId,
                categories = WG.BuildCategories(entry.catId, entry.item.extraCategories),
                image = entry.item.image,
                desc = entry.item.desc,
            }
            items[#items + 1] = item
            RngGrid.placeItem(grid, row, col, w, h, item.idx)
            occupiedCells = occupiedCells + (w * h)
        end
    end

    -- 计算实际使用的行数
    local usedRows = 0
    for r = MAX_ROWS, 1, -1 do
        for c = 1, COLS do
            if grid[r][c] ~= 0 then
                usedRows = r
                goto foundLastRow
            end
        end
    end
    ::foundLastRow::

    -- 计算总价值
    local totalValue = 0
    for _, item in ipairs(items) do
        totalValue = totalValue + item.realValue
    end

    local warehouseName = whType.name

    local result = {
        region = region,
        warehouseTypeId = whTypeId,
        warehouseTypeName = whType.name,
        warehouseName = warehouseName,
        tier = tier.id,
        items = items,
        grid = grid,
        totalCells = occupiedCells,
        targetCells = targetCells,
        targetItemCount = targetItemCount,
        targetValue = math.floor(targetValue),
        totalValue = totalValue,
        usedRows = usedRows,
        itemCount = #items,
        seed = seed,
    }

    local warehouseValue = difficulty.warehouseValue or difficulty.expectedValue
    local tierMult = totalValue / warehouseValue
    print("[WarehouseGenerator] Generated: " .. warehouseName .. " [TIER: " .. tier.id .. "]")
    print("  Region: " .. region.name .. ", Type: " .. whType.name .. ", Difficulty: " .. (difficulty.label or "?"))
    print("  Tier: " .. tier.id .. " (mult range: " .. tier.multMin .. "x ~ " .. tier.multMax .. "x"
        .. ", budgetK=" .. tier.budgetK .. ")")
    print("  Target: items=" .. targetItemCount .. ", value=" .. math.floor(targetValue)
        .. ", cells=" .. targetCells .. "/" .. MAX_CELLS
        .. " (" .. math.floor(targetCells/MAX_CELLS*100) .. "%)")
    print("  Actual: items=" .. #items .. ", cells=" .. occupiedCells .. ", value=" .. totalValue)
    print("  Rows used: " .. usedRows .. "/" .. MAX_ROWS)
    print("  Value ratio: " .. string.format("%.2fx", tierMult) .. " of warehouseValue (" .. warehouseValue .. ")")

    return result
end

--- 获取格子中某位置的物品信息
function WG.GetItemAt(result, row, col)
    local idx = result.grid[row] and result.grid[row][col]
    if not idx or idx == 0 then return nil end
    return result.items[idx]
end

--- 检查 (row, col) 是否为某物品的左上角
function WG.IsItemOrigin(result, row, col)
    local item = WG.GetItemAt(result, row, col)
    if not item then return false end
    return item.gridRow == row and item.gridCol == col
end

--- 打印格子布局（调试用）
function WG.DebugPrintGrid(result)
    print("=== Grid Layout (" .. COLS .. "x" .. result.usedRows .. ") ===")
    for r = 1, math.max(result.usedRows, 1) do
        local line = string.format("%2d |", r)
        for c = 1, COLS do
            local v = result.grid[r][c]
            if v == 0 then
                line = line .. " . "
            else
                line = line .. string.format("%2d ", v)
            end
        end
        print(line)
    end
    print("   +" .. string.rep("---", COLS))

    print("\n=== Items ===")
    for _, item in ipairs(result.items) do
        local rarityData = Config.GetRarity(item.rarity)
        print(string.format("  #%d %s [%s] %dx%d @(%d,%d) val=%d",
            item.idx, item.icon .. item.name, rarityData.name,
            item.w, item.h, item.gridRow, item.gridCol, item.realValue))
    end
end

--- 构建物品的 categories 数组：主品类 + extraCategories（去重）
function WG.BuildCategories(primaryCat, extraCategories)
    local cats = { primaryCat }
    if extraCategories then
        local seen = { [primaryCat] = true }
        for _, cat in ipairs(extraCategories) do
            if not seen[cat] then
                seen[cat] = true
                cats[#cats + 1] = cat
            end
        end
    end
    return cats
end

--- 获取指定仓库类型的完整物品池（用于物品浏览面板）
function WG.GetItemPool(whTypeId)
    local pool = ItemPool.getPool(whTypeId)
    if not pool then return {} end

    local result = {}
    for _, entry in ipairs(pool.allItems) do
        local t = entry.item
        result[#result + 1] = {
            name     = t.name,
            w        = t.cols,
            h        = t.rows,
            rarity   = t.quality,
            value    = t.value,
            image    = t.image or "",
            desc     = t.desc or "",
            category = entry.catId,
            categories = WG.BuildCategories(entry.catId, t.extraCategories),
        }
    end
    return result
end

return WG
