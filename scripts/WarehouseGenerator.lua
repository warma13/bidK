-- ============================================================================
-- WarehouseGenerator.lua - 仓库生成算法
-- 根据区域+仓库类型生成物品并放置到 m×n 格子中
-- ============================================================================

local Config = require("Config")

local WG = {}

-- 仓库类型配置直接从 Config.WAREHOUSE_TYPES[whTypeId] 读取（不再需要独立映射表）

-- 常量
local COLS = Config.GAME.LootColumns         -- 10
local MAX_ROWS = Config.GAME.LootMaxRows     -- 20
local MAX_CELLS = COLS * MAX_ROWS            -- 200

-- ============================================================================
-- 本地 RNG（xorshift32，支持种子，用于联机时确定性复现仓库）
-- 替代全局 math.random，避免影响游戏其他系统的随机状态
-- ============================================================================
local _rngState = 0

local function _seedRng(seed)
    _rngState = (seed ~= 0) and (seed & 0xFFFFFFFF) or 2463534242
end

--- rng()     → float [0, 1)
--- rng(a, b) → integer [a, b]
--- rng(n)    → integer [1, n]
local function rng(a, b)
    local x = _rngState
    x = (x ~ (x << 13)) & 0xFFFFFFFF
    x = (x ~ (x >> 17)) & 0xFFFFFFFF
    x = (x ~ (x << 5))  & 0xFFFFFFFF
    _rngState = x
    local r = x / 4294967296.0
    if a == nil then
        return r
    elseif b == nil then
        return math.floor(r * a) + 1
    else
        return a + math.floor(r * (b - a + 1))
    end
end

-- ============================================================================
-- 仓库分层系统（Tier）
-- 先掷骰决定本仓库的价值档位，再在档位区间内采样
--
-- 设计理念：warehouseValue（原 expectedValue）是"高点"而非平均值。
-- 大多数仓库（约 80-85%）实际价值低于 warehouseValue，
-- 只有少数宝藏/jackpot 仓库才会超过它，给玩家带来惊喜感。
--
-- 加权期望校验（multAvg = (multMin+multMax)/2）：
-- 25×0.10 + 23×0.25 + 22×0.50 + 13×0.83 + 9×1.40 + 6×2.50 + 2×4.35
-- = 2.50 + 5.75 + 11.00 + 10.79 + 12.60 + 15.00 + 8.70 = 66.34 / 100 ≈ 0.66×
-- 约 87% 的仓库(trash+junk+poor+normal)价值 ≤ warehouseValue；
-- 约 13% 可能超过（good 上限 1.80×，treasure 上限 3.20×，jackpot 上限 5.50×）
-- ============================================================================
local WAREHOUSE_TIERS = {
    { id = "trash",    weight = 25, multMin = 0.05, multMax = 0.15, fillerRatio = 0.95, budgetK = 2.0 },
    { id = "junk",     weight = 23, multMin = 0.15, multMax = 0.35, fillerRatio = 0.90, budgetK = 1.8 },
    { id = "poor",     weight = 22, multMin = 0.35, multMax = 0.65, fillerRatio = 0.82, budgetK = 1.6 },
    { id = "normal",   weight = 13, multMin = 0.65, multMax = 1.00, fillerRatio = 0.75, budgetK = 1.4 },
    { id = "good",     weight = 9,  multMin = 1.00, multMax = 1.80, fillerRatio = 0.60, budgetK = 1.0 },
    { id = "treasure", weight = 6,  multMin = 1.80, multMax = 3.20, fillerRatio = 0.45, budgetK = 0.7 },
    { id = "jackpot",  weight = 2,  multMin = 3.20, multMax = 5.50, fillerRatio = 0.35, budgetK = 0.5 },
}

--- 按权重随机选取仓库分层
--- @return table tier 选中的分层配置
local function rollTier()
    local totalWeight = 0
    for _, t in ipairs(WAREHOUSE_TIERS) do
        totalWeight = totalWeight + t.weight
    end
    local r = rng() * totalWeight
    local acc = 0
    for _, t in ipairs(WAREHOUSE_TIERS) do
        acc = acc + t.weight
        if r <= acc then return t end
    end
    return WAREHOUSE_TIERS[3] -- fallback: normal
end

-- ============================================================================
-- 预算制权重计算
-- 根据剩余预算和剩余件数，动态计算每件物品的选取权重
-- 核心思想：物品价值越接近"当前目标均价"，权重越高
-- ============================================================================

--- 计算物品的预算制权重
--- @param value number 物品价值
--- @param targetPerPick number 当前目标均价（剩余预算 / 剩余件数）
--- @param k number|nil 集中度参数，越大越集中在目标附近（默认 1.5）
--- @return number weight 选取权重
local function budgetWeight(value, targetPerPick, k)
    if targetPerPick <= 0 then targetPerPick = 1 end
    k = k or 1.5
    -- 用对数比值衡量偏离程度，对称处理贵和便宜的物品
    -- ratio=1 最佳，偏离越远权重越低
    -- 使用高斯型衰减：exp(-k * (ln(ratio))^2)
    local logRatio = math.log(value / targetPerPick)
    return math.exp(-k * logRatio * logRatio)
end

-- ============================================================================
-- 内部工具函数
-- ============================================================================

-- 根据权重数组随机选择一个索引（1-based）
local function weightedRandom(weights)
    local total = 0
    for i = 1, #weights do
        total = total + weights[i]
    end
    if total <= 0 then return 1 end
    local r = rng() * total
    local acc = 0
    for i = 1, #weights do
        acc = acc + weights[i]
        if r <= acc then return i end
    end
    return #weights
end

-- 在 min 和 max 之间取随机整数（含两端）
local function randInt(minVal, maxVal)
    return rng(minVal, maxVal)
end

-- ============================================================================
-- 格子系统（2D 网格，支持 m×n 物品放置）
-- ============================================================================

-- 创建空网格：grid[row][col] = 0 表示空，>0 表示被某物品占用（存物品序号）
local function createGrid()
    local grid = {}
    for r = 1, MAX_ROWS do
        grid[r] = {}
        for c = 1, COLS do
            grid[r][c] = 0
        end
    end
    return grid
end

-- 检查 (row, col) 位置能否放置 w×h 的物品
local function canPlace(grid, row, col, w, h)
    if col + w - 1 > COLS then return false end
    if row + h - 1 > MAX_ROWS then return false end
    for r = row, row + h - 1 do
        for c = col, col + w - 1 do
            if grid[r][c] ~= 0 then return false end
        end
    end
    return true
end

-- 在 (row, col) 放置物品，标记为 itemIdx
local function placeItem(grid, row, col, w, h, itemIdx)
    for r = row, row + h - 1 do
        for c = col, col + w - 1 do
            grid[r][c] = itemIdx
        end
    end
end

-- 计算某位置的"缝隙得分"：周围（上下左右）已被占用的格子越多，得分越高
-- 得分高 = 更紧凑，优先填入缝隙
local function gapScore(grid, row, col, w, h)
    local score = 0
    -- 检查物品区域的四条边（外侧相邻格子）
    for c = col, col + w - 1 do
        -- 上边
        if row > 1 then
            if grid[row - 1][c] ~= 0 then score = score + 1 end
        else
            score = score + 1  -- 贴顶边也算
        end
        -- 下边
        if row + h <= MAX_ROWS then
            if grid[row + h][c] ~= 0 then score = score + 1 end
        end
    end
    for r = row, row + h - 1 do
        -- 左边
        if col > 1 then
            if grid[r][col - 1] ~= 0 then score = score + 1 end
        else
            score = score + 1  -- 贴左边也算
        end
        -- 右边
        if col + w <= COLS then
            if grid[r][col + w] ~= 0 then score = score + 1 end
        end
    end
    return score
end

-- 计算当前已使用的最大行号
local function getUsedRows(grid)
    for r = MAX_ROWS, 1, -1 do
        for c = 1, COLS do
            if grid[r][c] ~= 0 then return r end
        end
    end
    return 0
end

-- 寻找最佳放置位置（优先填充已使用区域的空隙）
-- 返回 row, col 或 nil（放不下）
local function findBestPosition(grid, w, h)
    local usedRows = getUsedRows(grid)

    -- 阶段1：在已使用行范围内搜索（优先填充空隙）
    if usedRows > 0 then
        local bestRow, bestCol = nil, nil
        local bestScore = -1

        for r = 1, usedRows do
            for c = 1, COLS do
                if canPlace(grid, r, c, w, h) then
                    local score = gapScore(grid, r, c, w, h)
                    -- 同分时优先靠上靠左（自然扫描顺序即可，用 > 而非 >=）
                    if score > bestScore then
                        bestScore = score
                        bestRow = r
                        bestCol = c
                    end
                end
            end
        end

        if bestRow then return bestRow, bestCol end
    end

    -- 阶段2：在已使用行下方紧邻的新行放置
    local startRow = usedRows + 1
    for r = startRow, MAX_ROWS do
        for c = 1, COLS do
            if canPlace(grid, r, c, w, h) then
                return r, c
            end
        end
    end

    return nil, nil
end

-- 统计已占用的格子数
local function countOccupied(grid)
    local count = 0
    for r = 1, MAX_ROWS do
        for c = 1, COLS do
            if grid[r][c] ~= 0 then count = count + 1 end
        end
    end
    return count
end

-- ============================================================================
-- 物品生成（从统一物品池按仓库配置筛选）
-- ============================================================================

-- 缓存：whTypeId → { sizeGroups, allItems }
local poolCache = {}

-- entry 结构: { item=模板, catIcon=品类图标, catId=品类ID, w=列数, h=行数, catWeight=品类权重 }

--- 构建仓库物品池（统一池模式）
--- 直接从 Config.WAREHOUSE_TYPES[whTypeId] 读取 categoryWeights + allowedCategories
local function getPool(whTypeId)
    if poolCache[whTypeId] then return poolCache[whTypeId] end

    -- 如果找不到仓库类型，fallback 到 suburb_basement（最简单的通用仓库）
    local whCfg = Config.WAREHOUSE_TYPES[whTypeId]
    if not whCfg then
        whTypeId = "suburb_basement"
        if poolCache[whTypeId] then return poolCache[whTypeId] end
        whCfg = Config.WAREHOUSE_TYPES[whTypeId]
    end

    local sizeGroups = { {}, {}, {}, {}, {} }
    local allItems = {}

    local allowed = nil
    if whCfg.allowedCategories then
        allowed = {}
        for _, catId in ipairs(whCfg.allowedCategories) do
            allowed[catId] = true
        end
    end

    local itemPoolMod = require("Config.Warehouses.ItemPool")
    local seenNames = {}
    -- 仓库的主题标签加成表：{ tagId = bonusMult, ... }，无则为 nil
    local prefTags = whCfg.preferredTags

    for _, cat in ipairs(itemPoolMod.categories) do
        if not allowed or allowed[cat.id] then
            local catWeight
            if whCfg.categoryWeights then
                catWeight = whCfg.categoryWeights[cat.id] or 0
            else
                catWeight = itemPoolMod.categoryWeights[cat.id] or 1
            end
            if catWeight <= 0 then goto skipCategory end

            for _, item in ipairs(cat.items) do
                if seenNames[item.name] then goto skipItem end
                seenNames[item.name] = true

                local w = item.cols
                local h = item.rows

                -- 计算标签加成：取物品所有 tag 中命中 preferredTags 的最大 bonus
                local tagBonus = 1.0
                if prefTags and item.tags then
                    for _, tag in ipairs(item.tags) do
                        local bonus = prefTags[tag]
                        if bonus and bonus > tagBonus then
                            tagBonus = bonus
                        end
                    end
                end

                local entry = {
                    item = item,
                    catIcon = cat.icon,
                    catId = cat.id,
                    w = w,
                    h = h,
                    catWeight = catWeight,
                    tagBonus = tagBonus,
                }
                allItems[#allItems + 1] = entry

                local cells = w * h
                local groupIdx = Config.ITEM_SIZE_GROUPS[cells] or 1
                sizeGroups[groupIdx][#sizeGroups[groupIdx] + 1] = entry

                ::skipItem::
            end
        end
        ::skipCategory::
    end

    -- 计算池内最低单件价值（用于阶段1/3的价格上限基础）
    local poolMinValue = math.huge
    for _, e in ipairs(allItems) do
        if e.item.value < poolMinValue then
            poolMinValue = e.item.value
        end
    end
    if poolMinValue == math.huge then poolMinValue = 1 end

    local pool = { sizeGroups = sizeGroups, allItems = allItems, poolMinValue = poolMinValue }
    poolCache[whTypeId] = pool
    return pool
end

-- 从候选列表中按预算制权重加权随机选取
-- @param pool table 候选 entry 列表
-- @param targetPerPick number 当前目标均价
-- @param k number|nil budgetWeight 集中度参数
local function pickWeightedBudget(pool, targetPerPick, k)
    local total = 0
    for _, e in ipairs(pool) do
        local itemWeight = e.item.weight or 1
        e._dynWeight = e.catWeight * itemWeight * budgetWeight(e.item.value, targetPerPick, k) * (e.tagBonus or 1.0)
        total = total + e._dynWeight
    end
    if total <= 0 then return pool[1] end
    local r = rng() * total
    local acc = 0
    for _, e in ipairs(pool) do
        acc = acc + e._dynWeight
        if r <= acc then return e end
    end
    return pool[#pool]
end

-- 从候选列表中按品类权重×物品权重随机选取（不考虑预算，用于填充阶段）
-- @param pool table 候选 entry 列表
local function pickWeightedCategory(pool)
    local total = 0
    for _, e in ipairs(pool) do
        local itemWeight = e.item.weight or 1
        total = total + e.catWeight * itemWeight * (e.tagBonus or 1.0)
    end
    if total <= 0 then return pool[1] end
    local r = rng() * total
    local acc = 0
    for _, e in ipairs(pool) do
        local itemWeight = e.item.weight or 1
        acc = acc + e.catWeight * itemWeight * (e.tagBonus or 1.0)
        if r <= acc then return e end
    end
    return pool[#pool]
end

-- 从物品池中按尺寸权重选一个尺寸组，再从中选取物品
-- @param whTypeId string 仓库类型ID
-- @param whType table 仓库类型配置
-- @param usedNames table 已使用的物品名
-- @param targetPerPick number|nil 目标均价（nil=不考虑预算，仅按品类权重）
-- @param maxValue number|nil 单品价值上限（nil=不限制）
-- @param budgetK number|nil budgetWeight 集中度参数
local function pickFromPool(whTypeId, whType, usedNames, targetPerPick, maxValue, budgetK)
    local pool = getPool(whTypeId)

    local sizeWeights = whType.sizeWeights
    local attempts = 0
    while attempts < 10 do
        local groupIdx = weightedRandom(sizeWeights)
        local group = pool.sizeGroups[groupIdx]
        if #group > 0 then
            -- 过滤已使用的物品名 + 超价物品
            local available = {}
            for _, e in ipairs(group) do
                if not usedNames[e.item.name] and (not maxValue or e.item.value <= maxValue) then
                    available[#available + 1] = e
                end
            end
            if #available > 0 then
                if targetPerPick then
                    return pickWeightedBudget(available, targetPerPick, budgetK)
                else
                    return pickWeightedCategory(available)
                end
            end
            -- 该尺寸组全部用完，允许重名
            if targetPerPick then
                return pickWeightedBudget(group, targetPerPick, budgetK)
            else
                return pickWeightedCategory(group)
            end
        end
        attempts = attempts + 1
    end

    -- fallback: 从全池选取
    if targetPerPick then
        return pickWeightedBudget(pool.allItems, targetPerPick, budgetK)
    else
        return pickWeightedCategory(pool.allItems)
    end
end

-- Fisher-Yates 洗牌
local function shuffle(t)
    for i = #t, 2, -1 do
        local j = rng(1, i)
        t[i], t[j] = t[j], t[i]
    end
end

-- ============================================================================
-- 仓库期望生成算法
-- 每局目标价值不再固定，而是从分布中采样：
--   90% 落在 expectedValue ± 50%
--   10% 落在外部（可能是低价垃圾仓库或高价宝藏仓库）
-- 格子占比也是变量，中位数 50%，与目标价值耦合
-- ============================================================================

--- Box-Muller 变换生成标准正态随机数
local function randNormal()
    local u1 = rng()
    local u2 = rng()
    -- 避免 log(0)
    if u1 < 1e-10 then u1 = 1e-10 end
    return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2)
end

--- 计算物品池的理论价值边界（在给定格子数下）
--- @param whTypeId string 仓库类型ID
--- @param targetCells number 目标占用格子数
--- @return number minValue 理论最低总价
--- @return number maxValue 理论最高总价
local function calcValueBounds(whTypeId, targetCells)
    local pool = getPool(whTypeId)
    -- 收集所有物品的 { 单格价值, 占格数, 总价值 }
    local entries = {}
    for _, e in ipairs(pool.allItems) do
        local cells = e.w * e.h
        entries[#entries + 1] = {
            valuePerCell = e.item.value / cells,
            cells = cells,
            value = e.item.value,
        }
    end

    -- 按单格价值升序排列 → 贪心填充 = 理论最低价
    table.sort(entries, function(a, b) return a.valuePerCell < b.valuePerCell end)
    local minVal = 0
    local remainMin = targetCells
    for _, e in ipairs(entries) do
        if remainMin <= 0 then break end
        if e.cells <= remainMin then
            minVal = minVal + e.value
            remainMin = remainMin - e.cells
        end
    end

    -- 按单格价值降序排列 → 贪心填充 = 理论最高价
    local maxVal = 0
    local remainMax = targetCells
    for i = #entries, 1, -1 do
        local e = entries[i]
        if remainMax <= 0 then break end
        if e.cells <= remainMax then
            maxVal = maxVal + e.value
            remainMax = remainMax - e.cells
        end
    end

    return minVal, maxVal
end

--- 根据目标平均格子数，混合"理想尺寸权重"与仓库本身风格权重
--- @param avgCells number 目标平均每件格子数
--- @param baseWeights table 仓库基础 sizeWeights（5个组）
--- @return table 混合后的 sizeWeights
local function blendedSizeWeights(avgCells, baseWeights)
    -- 5组尺寸的大致中位格子数：1, 2, 4, 6, 9
    -- 根据 avgCells 确定"理想"权重
    local ideal
    if avgCells <= 1.3 then
        ideal = { 100,  0,  0,  0,  0 }
    elseif avgCells <= 1.8 then
        ideal = {  70, 30,  0,  0,  0 }
    elseif avgCells <= 2.5 then
        ideal = {  35, 55, 10,  0,  0 }
    elseif avgCells <= 3.5 then
        ideal = {  15, 40, 35, 10,  0 }
    elseif avgCells <= 5.0 then
        ideal = {   8, 22, 40, 25,  5 }
    elseif avgCells <= 6.5 then
        ideal = {   5, 12, 28, 40, 15 }
    else
        ideal = {   3,  8, 20, 35, 34 }
    end
    -- 70% 理想权重 + 30% 仓库风格，保留仓库特色
    local blended = {}
    for i = 1, 5 do
        blended[i] = ideal[i] * 0.7 + (baseWeights[i] or 0) * 0.3
    end
    return blended
end

--- 生成本局的目标参数（价值 + 格子数 + 件数 + 分层）
--- 使用分层系统：先掷骰决定 tier，再在 tier 区间内均匀采样
--- warehouseValue 是"高点"（约 80-87 分位），大多数仓库低于此值
--- @param whType table 仓库类型配置（需含 warehouseValue 字段）
--- @param whTypeId string 仓库类型ID
--- @return number targetValue 本局目标价值
--- @return number targetCells 本局目标占用格子数
--- @return number targetItemCount 本局目标物品件数
--- @return table tier 选中的分层配置
local function sampleSessionParams(whType, whTypeId)
    -- warehouseValue 是高点（ceiling），不是期望值
    local baseValue = whType.warehouseValue

    -- 0. 提前获取物品池，读取池内最低单价
    local pool = getPool(whTypeId)
    local poolMinValue = pool.poolMinValue  -- 池内最便宜的物品单价（e.g. 105）

    -- 1. 掷骰决定仓库分层
    local tier = rollTier()

    -- 2. 在 tier 倍率区间内采样目标价值（先算价值，再推件数）
    local mult = tier.multMin + rng() * (tier.multMax - tier.multMin)
    local targetValue = baseValue * mult
    -- 绝对保底：不低于 warehouseValue 的 2%
    targetValue = math.max(baseValue * 0.02, targetValue)

    -- 3. 采样理想件数（基准 40 件，正态分布）
    local baseCount = math.floor(40 + randNormal() * 6 + 0.5)
    baseCount = math.max(10, math.min(MAX_CELLS, baseCount))

    -- 4. 根据预算反推「最多买得起多少件」
    --    即使全选最廉价物品也不能超过 targetValue
    --    这解决了廉价仓库（1万场 trash）被迫生成几百万价值的根本问题
    local maxAffordableCount = math.floor(targetValue / poolMinValue)
    local targetItemCount = math.min(baseCount, math.max(3, maxAffordableCount))

    -- 5. 采样格子占比：与件数耦合，件数少则格子也少
    local fillRate = 0.50 + randNormal() * 0.12
    fillRate = math.max(0.20, math.min(0.80, fillRate))
    local targetCells = math.floor(MAX_CELLS * fillRate)
    -- 格子数上限：件数 × 5（平均每件最多 5 格，避免稀疏件数填满整仓）
    targetCells = math.min(targetCells, targetItemCount * 5)
    targetCells = math.max(targetItemCount, math.min(MAX_CELLS - 10, targetCells))

    -- 6. 用上界裁剪（不强制下界，让 tier 倍率完全控制价值）
    local _, boundMax = calcValueBounds(whTypeId, targetCells)
    targetValue = math.min(boundMax, targetValue)

    return targetValue, targetCells, targetItemCount, tier
end

-- ============================================================================
-- 主生成函数
-- ============================================================================

--- 生成一个仓库的物品列表和格子布局
--- @param regionId string|nil 区域ID（nil=随机选择）
--- @param warehouseTypeId string|nil 仓库类型ID（nil=根据区域随机选择）
--- @param diffIdx number|nil 难度索引（1-based，nil=默认第一个）
--- @param seed number|nil 随机种子（nil=自动生成；联机时传入相同 seed 可复现完全相同仓库）
--- @return table result { region, warehouseType, items, grid, totalCells, totalValue, usedRows, seed }
function WG.Generate(regionId, warehouseTypeId, diffIdx, seed)
    -- 种子处理：有种子用种子（联机复现），无种子从全局随机生成（单机模式）
    if not seed or seed == 0 then
        seed = math.random(1, 2147483647)
    end
    _seedRng(seed)
    -- 1. 确定区域
    local region
    if regionId then
        for _, r in ipairs(Config.REGIONS) do
            if r.id == regionId then region = r; break end
        end
    end
    if not region then
        region = Config.REGIONS[rng(1, #Config.REGIONS)]
    end

    -- 2. 确定难度（经济参数来源）
    local difficulties = region.difficulties or {}
    local difficultyIdx = diffIdx or 1
    local difficulty = difficulties[difficultyIdx] or difficulties[1]
    if not difficulty then
        -- fallback: 默认经济参数
        difficulty = { level = "normal", label = "普通", entryFee = 0, expectedValue = 100000, rarityWeights = { 55, 25, 12, 5, 3 } }
    end

    -- 3. 确定仓库类型（结构参数来源）
    local whTypeId = warehouseTypeId
    if not whTypeId then
        local types = region.warehouseTypes
        whTypeId = types[rng(1, #types)]
    end
    local whType = Config.WAREHOUSE_TYPES[whTypeId]
    if not whType then
        whTypeId = "suburb_basement"
        whType = Config.WAREHOUSE_TYPES[whTypeId]
    end

    -- 4. 合并参数：经济参数来自难度，结构参数来自仓库类型
    -- warehouseValue 是"高点"（约 80-87 分位），不是期望值
    -- 兼容旧字段名 expectedValue（如配置中尚未更名）
    local mergedWhType = {
        warehouseValue = difficulty.warehouseValue or difficulty.expectedValue,
        sizeWeights = whType.sizeWeights,
    }

    -- 5. 采样本局参数（目标价值 + 格子数 + 件数 + 分层）
    local targetValue, targetCells, targetItemCount, tier = sampleSessionParams(mergedWhType, whTypeId)

    -- ================================================================
    -- 两阶段选品：预算先显式分割，再各阶段独立硬约束
    --
    -- 核心保证：totalValue ≤ targetValue（数学严格成立）
    -- 原理：fillerBudget + premiumBudget = targetValue
    --       每阶段 itemCap = min(remainBudget, perItemTarget × K)
    --       → 每件不超过 remainBudget → 每阶段总价 ≤ 阶段预算
    --
    -- 阶段1（filler）：多件廉价品，填充视觉密度
    --   件数 = floor(targetItemCount × fillerRatio)
    --   预算 = targetValue × fillerRatio² × 0.5（平方确保占比小）
    --   单件上限 = min(fillerBudgetRemain, perItemTarget × 2)
    --
    -- 阶段2（premium）：少件高价品，构成价值主体
    --   件数 = targetItemCount - fillerCount
    --   预算 = targetValue - fillerBudget（剩余全部）
    --   单件上限 = min(premiumBudgetRemain, perItemTarget × 2.5)
    --   用 budgetWeight 精准命中目标均价
    -- ================================================================
    local poolMinPrice = getPool(whTypeId).poolMinValue

    local fillerCount  = math.max(1, math.floor(targetItemCount * tier.fillerRatio))
    local premiumCount = math.max(0, targetItemCount - fillerCount)
    -- 按价值比例分配格子（而非件数比例），确保 premium 阶段有足够格子放较大物品
    -- fillerRatio² × 0.5 = 价值占比，用于格子分配
    local fillerValueFrac2 = tier.fillerRatio * tier.fillerRatio * 0.5
    local fillerCells = math.max(fillerCount, math.floor(targetCells * fillerValueFrac2))

    -- 显式分割预算：filler 拿小头，premium 拿大头
    -- fillerRatio² × 0.5：trash(0.95²×0.5=0.45) → filler最多45%价值
    --                      jackpot(0.35²×0.5=0.06) → filler最多6%价值
    local fillerValueFrac = tier.fillerRatio * tier.fillerRatio * 0.5
    local fillerBudget    = math.max(fillerCount * poolMinPrice,
                                     math.floor(targetValue * fillerValueFrac))
    -- 确保 filler 预算不超过总预算（极端情况保护）
    fillerBudget = math.min(fillerBudget, targetValue - premiumCount * poolMinPrice)
    fillerBudget = math.max(fillerCount * poolMinPrice, fillerBudget)
    local premiumBudget = targetValue - fillerBudget

    local usedNames = {}
    local selected = {}
    local totalSelectedCells = 0

    -- ── 阶段1：filler（多件廉价品）──
    -- 目标：塞满 fillerCount 件便宜物品，总价 ≤ fillerBudget
    local fillerBudgetRemain = fillerBudget
    local failCount = 0
    while #selected < fillerCount and failCount < 15 do
        if totalSelectedCells >= fillerCells then break end
        if fillerBudgetRemain <= 0 then break end

        local fillerRemain     = fillerCount - #selected
        local remainFillerCells = math.max(1, fillerCells - totalSelectedCells)
        local avgCells         = remainFillerCells / fillerRemain

        -- 偏向小物品，保证件数
        local dynWeights = blendedSizeWeights(avgCells, whType.sizeWeights)
        local dynWhType  = { sizeWeights = dynWeights }

        -- 单件硬上限：不超过剩余预算，且不超过均价 × 2
        local perItemTarget = fillerBudgetRemain / fillerRemain
        local itemCap = math.min(fillerBudgetRemain, math.max(poolMinPrice, perItemTarget * 2.0))

        local entry = pickFromPool(whTypeId, dynWhType, usedNames, nil, itemCap)
        local itemCells = entry.w * entry.h

        -- 格子溢出重试
        if totalSelectedCells + itemCells > fillerCells + 3 then
            local found = false
            for _ = 1, 8 do
                entry = pickFromPool(whTypeId, dynWhType, usedNames, nil, itemCap)
                itemCells = entry.w * entry.h
                if totalSelectedCells + itemCells <= fillerCells + 3 then
                    found = true; break
                end
            end
            if not found then failCount = failCount + 1; goto continuePhase1 end
        end

        -- 价格溢出跳过（理论上不会发生，但做保护）
        if entry.item.value > fillerBudgetRemain then
            failCount = failCount + 1; goto continuePhase1
        end

        failCount = 0
        usedNames[entry.item.name] = true
        selected[#selected + 1] = entry
        totalSelectedCells = totalSelectedCells + itemCells
        fillerBudgetRemain = fillerBudgetRemain - entry.item.value
        ::continuePhase1::
    end

    -- ── 阶段2：premium（少件高价品）──
    -- 目标：选 premiumCount 件，总价 ≤ premiumBudget
    local premiumBudgetRemain = premiumBudget
    failCount = 0
    while #selected < targetItemCount and failCount < 15 do
        if totalSelectedCells >= targetCells then break end
        if premiumBudgetRemain <= 0 then break end

        local premiumRemain = targetItemCount - #selected
        local remainCells   = math.max(1, targetCells - totalSelectedCells)
        local avgCells      = remainCells / premiumRemain

        -- 允许大尺寸物品，保留仓库风格
        local dynWeights = blendedSizeWeights(avgCells, whType.sizeWeights)
        local dynWhType  = { sizeWeights = dynWeights }

        -- 预算均价引导（budgetWeight 核心参数）
        local targetPerPick = math.max(1, premiumBudgetRemain / premiumRemain)

        -- 单件硬上限：不超过剩余预算，且不超过均价 × 2.5
        -- × 2.5 允许少量贵物品存在，但剩余预算是绝对天花板
        local itemCap = math.min(premiumBudgetRemain,
                                 math.max(poolMinPrice, targetPerPick * 2.5))

        local entry = pickFromPool(whTypeId, dynWhType, usedNames, targetPerPick, itemCap, tier.budgetK)
        local itemCells = entry.w * entry.h

        -- 格子溢出重试（此时放弃预算约束，优先保证格子合法）
        if totalSelectedCells + itemCells > targetCells + 3 then
            local found = false
            for _ = 1, 8 do
                entry = pickFromPool(whTypeId, dynWhType, usedNames, targetPerPick, itemCap, tier.budgetK)
                itemCells = entry.w * entry.h
                if totalSelectedCells + itemCells <= targetCells + 3 then
                    found = true; break
                end
            end
            if not found then failCount = failCount + 1; goto continuePhase2 end
        end

        -- 价格溢出跳过（严格保护，不允许超 premiumBudgetRemain）
        if entry.item.value > premiumBudgetRemain then
            failCount = failCount + 1; goto continuePhase2
        end

        failCount = 0
        usedNames[entry.item.name] = true
        selected[#selected + 1] = entry
        totalSelectedCells = totalSelectedCells + itemCells
        premiumBudgetRemain = premiumBudgetRemain - entry.item.value
        ::continuePhase2::
    end

    -- ================================================================
    -- 打乱顺序后统一放置
    -- ================================================================
    shuffle(selected)

    local items = {}
    local grid = createGrid()
    local occupiedCells = 0

    for _, entry in ipairs(selected) do
        local w = entry.w
        local h = entry.h
        local row, col = findBestPosition(grid, w, h)
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
                image = entry.item.image,
                desc = entry.item.desc,
            }
            items[#items + 1] = item
            placeItem(grid, row, col, w, h, item.idx)
            occupiedCells = occupiedCells + (w * h)
        end
    end

    -- 5. 计算实际使用的行数
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

    -- 6. 计算总价值
    local totalValue = 0
    for _, item in ipairs(items) do
        totalValue = totalValue + item.realValue
    end

    -- 7. 生成仓库名称
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
        seed = seed,  -- 用于联机时编入房间码，传给其他玩家后可复现完全相同仓库
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
--- @param result table Generate() 返回的结果
--- @param row number 行号(1-based)
--- @param col number 列号(1-based)
--- @return table|nil item 物品信息，nil=空格
function WG.GetItemAt(result, row, col)
    local idx = result.grid[row] and result.grid[row][col]
    if not idx or idx == 0 then return nil end
    return result.items[idx]
end

--- 检查 (row, col) 是否为某物品的左上角
--- @return boolean
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

--- 获取指定仓库类型的完整物品池（用于物品浏览面板）
--- @param whTypeId string 仓库类型ID（如 "grocery"）
--- @return table[] 物品列表，每项含 { name, w, h, rarity, value, image, desc, category }
function WG.GetItemPool(whTypeId)
    local pool = getPool(whTypeId)
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
        }
    end
    return result
end

return WG
