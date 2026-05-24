-- ============================================================================
-- WG/DragState.lua - 仓库拖拽状态机 + 格子原子操作
-- 纯逻辑层，不依赖 UI；由 DragHandler 驱动
-- ============================================================================

local M = {}

M.IDLE     = "idle"
M.DRAGGING = "dragging"

local _state         = M.IDLE
local _item          = nil   -- 正在拖拽的物品
local _originX       = nil   -- 拖拽开始时 item.gridX
local _originY       = nil   -- 拖拽开始时 item.gridY
local _originRotated = nil   -- 拖拽开始时 item.rotated（取消时恢复）

-- 有效宽度（考虑旋转）
function M.EffW(item)
    return (item.rotated and (item.h or 1)) or (item.w or 1)
end
-- 有效高度（考虑旋转）
function M.EffH(item)
    return (item.rotated and (item.w or 1)) or (item.h or 1)
end

function M.GetState()    return _state   end
function M.GetDragItem() return _item    end
function M.GetOrigin()   return _originX, _originY end

-- 开始拖拽；ctx.dragEnabled 必须为 true
function M.StartDrag(ctx, item)
    if _state ~= M.IDLE then return false end
    if not ctx.dragEnabled then return false end
    if not item or not item.gridX or not item.gridY then return false end
    _state         = M.DRAGGING
    _item          = item
    _originX       = item.gridX
    _originY       = item.gridY
    _originRotated = item.rotated
    return true
end

-- ── 内部：收集目标区域内所有其他物品（不含 item 自身）────────────────────
local function collectDisplaced(ctx, item, toX, toY)
    local w = M.EffW(item)
    local h = M.EffH(item)
    local seen = {}
    local list = {}
    for r = toY, toY + h - 1 do
        for c = toX, toX + w - 1 do
            local other = ctx.gridMap[r] and ctx.gridMap[r][c] or nil
            if other and other ~= item and not seen[other] then
                seen[other] = true
                list[#list + 1] = other
            end
        end
    end
    return list
end

-- ── 内部：全局贪心装箱
-- 在整个网格空间内为 items 寻找空位，排除 A 的目标区域（toX/toY/tw/th）
-- 调用前 gridMap 中 A 和 displaced 已被清除（只剩背景物品）
-- 返回 assignments 表 { [item] = {newX, newY} } 或 nil 表示装箱失败
local function tryPackGlobal(ctx, items, toX, toY, tw, th)
    local maxRows = ctx.gridInst and ctx.gridInst.rows or 0
    -- 按面积降序，大物品先放
    local sorted = {}
    for _, it in ipairs(items) do sorted[#sorted + 1] = it end
    table.sort(sorted, function(a, b)
        return (a.w or 1) * (a.h or 1) > (b.w or 1) * (b.h or 1)
    end)

    -- extra：记录本轮已安排的格子（gridMap 已清空 displaced，无法依赖）
    local extra = {}
    local function isFree(r, c)
        if r < 1 or c < 1 or r > maxRows or c > ctx.COLS then return false end
        -- 不能放入 A 的目标区域
        if r >= toY and r <= toY + th - 1 and c >= toX and c <= toX + tw - 1 then
            return false
        end
        -- 背景物品（A 和 displaced 已清除，剩余的都是第三方）
        if ctx.gridMap[r] and ctx.gridMap[r][c] then return false end
        -- 本轮已安排的其他 displaced 物品
        if extra[r] and extra[r][c] then return false end
        return true
    end

    local assignments = {}
    for _, it in ipairs(sorted) do
        local iw = M.EffW(it)
        local ih = M.EffH(it)
        local placed = false
        for r = 1, maxRows - ih + 1 do
            for c = 1, ctx.COLS - iw + 1 do
                local free = true
                for dr = 0, ih - 1 do
                    for dc = 0, iw - 1 do
                        if not isFree(r + dr, c + dc) then free = false; break end
                    end
                    if not free then break end
                end
                if free then
                    for dr = 0, ih - 1 do
                        for dc = 0, iw - 1 do
                            if not extra[r + dr] then extra[r + dr] = {} end
                            extra[r + dr][c + dc] = true
                        end
                    end
                    assignments[it] = { c, r }
                    placed = true
                    break
                end
            end
            if placed then break end
        end
        if not placed then return nil end  -- 装箱失败
    end
    return assignments
end

-- 将 item 从当前格子移动到 (toX, toY)
-- wantRotate: true/false 强制设定落放后的旋转状态；nil 保持当前
-- • 目标全空      → 普通移动
-- • 目标有其他物品 → 尝试将被压物品全局装箱（多物品互换）
-- 成功返回 true, "move"|"swap"；失败回填原位并返回 false, reason
function M.TryMove(ctx, item, toX, toY, wantRotate)
    -- 如有旋转意图，先暂时应用（失败时恢复）
    local origRotated = item.rotated
    if wantRotate ~= nil then item.rotated = wantRotate end

    local w = M.EffW(item)
    local h = M.EffH(item)
    local fromX = item.gridX
    local fromY = item.gridY

    -- 边界检测（移动前先检查，不需要清格子）
    local maxRows = ctx.gridInst and ctx.gridInst.rows or 0
    if toX < 1 or toY < 1 or toX + w - 1 > ctx.COLS or toY + h - 1 > maxRows then
        item.rotated = origRotated
        return false, "out_of_bounds"
    end

    -- 收集目标区域内被压物品
    local displaced = collectDisplaced(ctx, item, toX, toY)

    if #displaced == 0 then
        -- ── 普通移动 ──────────────────────────────────────────────────────
        -- 清除旧格子（使用原始旋转下的尺寸）
        local fromW = origRotated and (item.h or 1) or (item.w or 1)
        local fromH = origRotated and (item.w or 1) or (item.h or 1)
        for r = fromY, fromY + fromH - 1 do
            for c = fromX, fromX + fromW - 1 do
                if ctx.gridMap[r] then ctx.gridMap[r][c] = nil end
            end
        end
        -- 写入新位置（使用新旋转下的尺寸，w/h 已在上面按 wantRotate 更新）
        item.gridX = toX
        item.gridY = toY
        for r = toY, toY + h - 1 do
            for c = toX, toX + w - 1 do
                if not ctx.gridMap[r] then ctx.gridMap[r] = {} end
                ctx.gridMap[r][c] = item
            end
        end
        return true, "move"
    end

    -- ── 互换移动：尝试装箱 ────────────────────────────────────────────────
    -- 临时清除 item 和所有被压物品的格子（用有效尺寸，覆盖当前占用范围）
    local function clearItem(it)
        local iw, ih = M.EffW(it), M.EffH(it)
        local ix, iy = it.gridX, it.gridY
        if not ix or not iy then return end
        for r = iy, iy + ih - 1 do
            for c = ix, ix + iw - 1 do
                if ctx.gridMap[r] then ctx.gridMap[r][c] = nil end
            end
        end
    end
    local function writeItem(it, nx, ny)
        local iw, ih = M.EffW(it), M.EffH(it)
        it.gridX = nx; it.gridY = ny
        for r = ny, ny + ih - 1 do
            for c = nx, nx + iw - 1 do
                if not ctx.gridMap[r] then ctx.gridMap[r] = {} end
                ctx.gridMap[r][c] = it
            end
        end
    end

    -- 保存原始位置（用于 rollback）
    local origPositions = { [item] = { fromX, fromY } }
    for _, d in ipairs(displaced) do
        origPositions[d] = { d.gridX, d.gridY }
    end

    -- item 先用 origRotated 的尺寸清除旧格子（wantRotate 尚未生效时清除）
    -- 注意：此时 item.rotated 已被设为 wantRotate（函数顶部），需临时还原再清
    local savedRotated = item.rotated
    item.rotated = origRotated
    clearItem(item)
    item.rotated = savedRotated
    for _, d in ipairs(displaced) do clearItem(d) end

    -- 全局搜索：为被压物品在整个网格中寻找空位（排除 A 的目标区域）
    local assignments = tryPackGlobal(ctx, displaced, toX, toY, w, h)
    if not assignments then
        -- 装箱失败 → 全部 rollback（含旋转）
        item.rotated = origRotated
        for it, pos in pairs(origPositions) do
            writeItem(it, pos[1], pos[2])
        end
        return false, "swap_no_fit"
    end

    -- 验证 item 能放到目标位置（现在格子已清空）
    for r = toY, toY + h - 1 do
        for c = toX, toX + w - 1 do
            if ctx.gridMap[r] and ctx.gridMap[r][c] then
                -- 有第三方物品残留（装箱未清干净，理论上不应发生）
                item.rotated = origRotated
                for it, pos in pairs(origPositions) do
                    writeItem(it, pos[1], pos[2])
                end
                return false, "target_blocked"
            end
        end
    end

    -- 写入 item 的新位置
    writeItem(item, toX, toY)
    -- 写入各被压物品的装箱结果
    for it, pos in pairs(assignments) do
        writeItem(it, pos[1], pos[2])
    end
    return true, "swap"
end

-- 恢复 item 到拖拽前位置，结束拖拽状态
function M.CancelDrag(ctx)
    if _item and _originX and _originY then
        local item = _item
        local ox, oy = _originX, _originY

        -- 清除 item 当前位置（用当前有效尺寸，拖拽中旋转可能已变）
        if item.gridX and item.gridY then
            local cw, ch = M.EffW(item), M.EffH(item)
            for r = item.gridY, item.gridY + ch - 1 do
                for c = item.gridX, item.gridX + cw - 1 do
                    if ctx.gridMap[r] then ctx.gridMap[r][c] = nil end
                end
            end
        end

        -- 恢复旋转状态，再用原始有效尺寸写回原点
        item.rotated = _originRotated
        local ow, oh = M.EffW(item), M.EffH(item)
        item.gridX = ox
        item.gridY = oy
        for r = oy, oy + oh - 1 do
            for c = ox, ox + ow - 1 do
                if not ctx.gridMap[r] then ctx.gridMap[r] = {} end
                ctx.gridMap[r][c] = item
            end
        end
    end
    _state         = M.IDLE
    _item          = nil
    _originX       = nil
    _originY       = nil
    _originRotated = nil
end

-- 落放成功后，仅重置追踪变量（item 已在新位置）
function M.EndDrag()
    _state   = M.IDLE
    _item    = nil
    _originX = nil
    _originY = nil
end

return M
