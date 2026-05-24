-- ============================================================================
-- WG/RngGrid.lua - 确定性 RNG + 格子系统
-- ============================================================================

local Config = require("Config")

local COLS     = Config.GAME.LootColumns
local MAX_ROWS = Config.GAME.LootMaxRows

local M = {}

-- ============================================================================
-- 本地 RNG（xorshift32，支持种子，用于联机时确定性复现仓库）
-- ============================================================================
local _rngState = 0

--- 用 seed 初始化 RNG 状态
function M.seedRng(seed)
    _rngState = (seed ~= 0) and (seed & 0xFFFFFFFF) or 2463534242
end

--- rng()     → float [0, 1)
--- rng(a, b) → integer [a, b]
--- rng(n)    → integer [1, n]
function M.rng(a, b)
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
-- 格子系统（2D 网格，支持 m×n 物品放置）
-- ============================================================================

--- 创建空网格：grid[row][col] = 0 表示空，>0 表示被某物品占用（存物品序号）
function M.createGrid()
    local grid = {}
    for r = 1, MAX_ROWS do
        grid[r] = {}
        for c = 1, COLS do
            grid[r][c] = 0
        end
    end
    return grid
end

--- 检查 (row, col) 位置能否放置 w×h 的物品
function M.canPlace(grid, row, col, w, h)
    if col + w - 1 > COLS then return false end
    if row + h - 1 > MAX_ROWS then return false end
    for r = row, row + h - 1 do
        for c = col, col + w - 1 do
            if grid[r][c] ~= 0 then return false end
        end
    end
    return true
end

--- 在 (row, col) 放置物品，标记为 itemIdx
function M.placeItem(grid, row, col, w, h, itemIdx)
    for r = row, row + h - 1 do
        for c = col, col + w - 1 do
            grid[r][c] = itemIdx
        end
    end
end

--- 计算某位置的"缝隙得分"：周围（上下左右）已被占用的格子越多，得分越高
local function gapScore(grid, row, col, w, h)
    local score = 0
    for c = col, col + w - 1 do
        if row > 1 then
            if grid[row - 1][c] ~= 0 then score = score + 1 end
        else
            score = score + 1
        end
        if row + h <= MAX_ROWS then
            if grid[row + h][c] ~= 0 then score = score + 1 end
        end
    end
    for r = row, row + h - 1 do
        if col > 1 then
            if grid[r][col - 1] ~= 0 then score = score + 1 end
        else
            score = score + 1
        end
        if col + w <= COLS then
            if grid[r][col + w] ~= 0 then score = score + 1 end
        end
    end
    return score
end

--- 计算当前已使用的最大行号
function M.getUsedRows(grid)
    for r = MAX_ROWS, 1, -1 do
        for c = 1, COLS do
            if grid[r][c] ~= 0 then return r end
        end
    end
    return 0
end

--- 寻找最佳放置位置（优先填充已使用区域的空隙）
--- @return number|nil row, number|nil col
function M.findBestPosition(grid, w, h)
    local usedRows = M.getUsedRows(grid)

    if usedRows > 0 then
        local bestRow, bestCol = nil, nil
        local bestScore = -1
        for r = 1, usedRows do
            for c = 1, COLS do
                if M.canPlace(grid, r, c, w, h) then
                    local score = gapScore(grid, r, c, w, h)
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

    local startRow = usedRows + 1
    for r = startRow, MAX_ROWS do
        for c = 1, COLS do
            if M.canPlace(grid, r, c, w, h) then
                return r, c
            end
        end
    end

    return nil, nil
end

--- 统计已占用的格子数
function M.countOccupied(grid)
    local count = 0
    for r = 1, MAX_ROWS do
        for c = 1, COLS do
            if grid[r][c] ~= 0 then count = count + 1 end
        end
    end
    return count
end

return M
