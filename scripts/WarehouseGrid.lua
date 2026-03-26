-- ============================================================================
-- WarehouseGrid.lua - 玩家仓库 2D 网格管理
-- 纯数据模块，无 UI 依赖。管理物品在 m×n 网格中的放置、移除、查询。
-- 仓库容量等级决定总格子数，按固定列数自动计算行数。
-- ============================================================================

local WarehouseGrid = {}

-- 列数（从配置读取）
local Config = require("Config")
local COLS = Config.GAME.WarehouseColumns

-- ============================================================================
-- 内部工具
-- ============================================================================

--- 创建空网格 grid[r][c] = false
---@param rows number
---@return boolean[][]
local function createEmptyGrid(rows)
    local grid = {}
    for r = 1, rows do
        grid[r] = {}
        for c = 1, COLS do
            grid[r][c] = false
        end
    end
    return grid
end

--- 检查 (row, col) 能否放置 w×h 物品
local function canPlaceAt(grid, rows, row, col, w, h)
    if col + w - 1 > COLS then return false end
    if row + h - 1 > rows then return false end
    for r = row, row + h - 1 do
        for c = col, col + w - 1 do
            if grid[r][c] then return false end
        end
    end
    return true
end

--- 标记 (row, col) w×h 区域为已占用
local function markOccupied(grid, row, col, w, h, occupied)
    for r = row, row + h - 1 do
        for c = col, col + w - 1 do
            grid[r][c] = occupied
        end
    end
end

-- ============================================================================
-- 网格实例
-- ============================================================================

---@class WarehouseGridInstance
---@field grid boolean[][]
---@field rows number
---@field totalCells number
---@field usedCells number
---@field items table[]  -- { gridX, gridY, w, h, ... }

--- 创建网格实例
---@param totalCells number 总格子数（如 28, 42, 56）
---@return WarehouseGridInstance
function WarehouseGrid.Create(totalCells)
    local rows = math.ceil(totalCells / COLS)
    -- 实际可用格子数 = rows * COLS（可能略大于 totalCells）
    -- 但我们精确限制到 totalCells
    local inst = {
        grid = createEmptyGrid(rows),
        rows = rows,
        cols = COLS,
        totalCells = totalCells,
        usedCells = 0,
        items = {},  -- 已放置的物品列表
    }
    return inst
end

--- 检查某位置能否放下 w×h 物品
---@param inst WarehouseGridInstance
---@param row number 行 (1-based)
---@param col number 列 (1-based)
---@param w number 宽度（列数）
---@param h number 高度（行数）
---@return boolean
function WarehouseGrid.CanPlaceAt(inst, row, col, w, h)
    -- 检查放置后不超过 totalCells 上限
    local newCells = w * h
    if inst.usedCells + newCells > inst.totalCells then
        return false
    end
    return canPlaceAt(inst.grid, inst.rows, row, col, w, h)
end

--- 自动寻找第一个可放置位置（从上到下、从左到右扫描）
---@param inst WarehouseGridInstance
---@param w number
---@param h number
---@return number|nil row
---@return number|nil col
function WarehouseGrid.FindPosition(inst, w, h)
    local newCells = w * h
    if inst.usedCells + newCells > inst.totalCells then
        return nil, nil
    end
    for r = 1, inst.rows do
        for c = 1, COLS do
            if canPlaceAt(inst.grid, inst.rows, r, c, w, h) then
                return r, c
            end
        end
    end
    return nil, nil
end

--- 检查是否能放下一个 w×h 物品（不关心具体位置）
---@param inst WarehouseGridInstance
---@param w number
---@param h number
---@return boolean
function WarehouseGrid.CanFit(inst, w, h)
    local r, c = WarehouseGrid.FindPosition(inst, w, h)
    return r ~= nil
end

--- 放置物品到指定位置
---@param inst WarehouseGridInstance
---@param item table 物品数据（需要有 w, h 字段）
---@param row number
---@param col number
---@return boolean success
function WarehouseGrid.PlaceAt(inst, item, row, col)
    local w = item.w or 1
    local h = item.h or 1
    if not WarehouseGrid.CanPlaceAt(inst, row, col, w, h) then
        return false
    end
    markOccupied(inst.grid, row, col, w, h, true)
    inst.usedCells = inst.usedCells + (w * h)
    -- 记录物品的网格位置
    item.gridX = col
    item.gridY = row
    inst.items[#inst.items + 1] = item
    return true
end

--- 自动放置物品（自动找位置）
---@param inst WarehouseGridInstance
---@param item table
---@return boolean success
---@return number|nil row
---@return number|nil col
function WarehouseGrid.AutoPlace(inst, item)
    local w = item.w or 1
    local h = item.h or 1
    local row, col = WarehouseGrid.FindPosition(inst, w, h)
    if not row then
        return false, nil, nil
    end
    WarehouseGrid.PlaceAt(inst, item, row, col)
    return true, row, col
end

--- 移除物品
---@param inst WarehouseGridInstance
---@param item table
---@return boolean
function WarehouseGrid.Remove(inst, item)
    local gx = item.gridX
    local gy = item.gridY
    if not gx or not gy then return false end
    local w = item.w or 1
    local h = item.h or 1
    markOccupied(inst.grid, gy, gx, w, h, false)
    inst.usedCells = inst.usedCells - (w * h)
    item.gridX = nil
    item.gridY = nil
    -- 从 items 列表移除
    for i = #inst.items, 1, -1 do
        if inst.items[i] == item then
            table.remove(inst.items, i)
            break
        end
    end
    return true
end

--- 批量自动放置多个物品（返回成功放入的和放不下的）
---@param inst WarehouseGridInstance
---@param items table[]
---@return table[] placed 成功放入的物品
---@return table[] overflow 放不下的物品
function WarehouseGrid.AutoPlaceMany(inst, items)
    local placed = {}
    local overflow = {}
    for _, item in ipairs(items) do
        local ok = WarehouseGrid.AutoPlace(inst, item)
        if ok then
            placed[#placed + 1] = item
        else
            overflow[#overflow + 1] = item
        end
    end
    return placed, overflow
end

--- 获取已用格子数
---@param inst WarehouseGridInstance
---@return number
function WarehouseGrid.GetUsedCells(inst)
    return inst.usedCells
end

--- 获取总格子数
---@param inst WarehouseGridInstance
---@return number
function WarehouseGrid.GetTotalCells(inst)
    return inst.totalCells
end

--- 获取剩余格子数
---@param inst WarehouseGridInstance
---@return number
function WarehouseGrid.GetFreeCells(inst)
    return inst.totalCells - inst.usedCells
end

--- 获取已放置的物品列表
---@param inst WarehouseGridInstance
---@return table[]
function WarehouseGrid.GetItems(inst)
    return inst.items
end

--- 清空网格
---@param inst WarehouseGridInstance
function WarehouseGrid.Clear(inst)
    inst.grid = createEmptyGrid(inst.rows)
    inst.usedCells = 0
    inst.items = {}
end

--- 从已有物品列表重建网格（SaveSystem 加载后调用）
---@param inst WarehouseGridInstance
---@param items table[] 含 gridX, gridY, w, h 的物品列表
---@return table[] failed 放置失败的物品（数据损坏时）
function WarehouseGrid.Rebuild(inst, items)
    WarehouseGrid.Clear(inst)
    local failed = {}
    for _, item in ipairs(items) do
        local w = item.w or 1
        local h = item.h or 1
        local gx = item.gridX
        local gy = item.gridY
        if gx and gy and canPlaceAt(inst.grid, inst.rows, gy, gx, w, h) then
            markOccupied(inst.grid, gy, gx, w, h, true)
            inst.usedCells = inst.usedCells + (w * h)
            inst.items[#inst.items + 1] = item
        else
            -- 尝试自动放置
            local row, col = WarehouseGrid.FindPosition(inst, w, h)
            if row then
                markOccupied(inst.grid, row, col, w, h, true)
                inst.usedCells = inst.usedCells + (w * h)
                item.gridX = col
                item.gridY = row
                inst.items[#inst.items + 1] = item
            else
                failed[#failed + 1] = item
            end
        end
    end
    return failed
end

--- 获取列数
---@return number
function WarehouseGrid.GetCols()
    return COLS
end

return WarehouseGrid
