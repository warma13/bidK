-- ============================================================================
-- UI/Warehouse/DragHandler.lua - 仓库物品拖拽 UI 层
-- 负责：ghost 面板、目标格子高亮、指针事件路由
-- 依赖 ctx（共享上下文）和 DragState（逻辑层）
-- ============================================================================

local UI         = require("urhox-libs/UI")
local SaveSystem = require("SaveSystem")
local DragState  = require("WG.DragState")
local GridSystem = require("UI.Warehouse.GridSystem")

-- 本地快捷
local effW = function(item) return DragState.EffW(item) end
local effH = function(item) return DragState.EffH(item) end

local DragHandler = {}

-- ── 运行时状态（非持久化）──────────────────────────────────────────────────
local _ctx          = nil   -- ctx 引用（Init 时设置）
local _ghostPanel   = nil   -- 跟随手指的悬浮 ghost
local _ghostImg     = nil   -- ghost 内的图片区域
local _ghostLabel   = nil   -- ghost 内的名称标签
local _dragImgPanel = nil   -- 被拖拽物品对应的 imgPanel（拖拽中半透明）
local _dragPtId     = nil   -- 触控 ID（nil 表示鼠标）
local _hlCol        = nil   -- 当前高亮的目标列
local _hlRow        = nil   -- 当前高亮的目标行
local _hlRotate     = nil   -- 落放时应用的旋转状态（nil=不改变）

-- ── 辅助：命中测试，返回 (col, row) 或 nil ───────────────────────────────
-- 直接使用第一个和最后一个格子的绝对布局坐标，精确处理 border/padding 偏移
local function hitTestCell(ctx, screenX, screenY)
    local rows = ctx.gridInst and ctx.gridInst.rows or 0
    if rows <= 0 then return nil end

    -- 用首格和末格的实际屏幕坐标确定网格精确边界
    local s11 = ctx.gridSlots and ctx.gridSlots[1]
    if not s11 then return nil end
    local lastIdx = (rows - 1) * ctx.COLS + ctx.COLS
    local sNM = ctx.gridSlots[lastIdx]
    if not sNM then return nil end

    local l11 = s11:GetAbsoluteLayout()
    local lNM = sNM:GetAbsoluteLayout()
    if not l11 or l11.w <= 0 or l11.h <= 0 then return nil end

    local gridLeft   = l11.x
    local gridTop    = l11.y
    local gridRight  = lNM.x + lNM.w
    local gridBottom = lNM.y + lNM.h

    if screenX < gridLeft or screenX >= gridRight then return nil end
    if screenY < gridTop  or screenY >= gridBottom then return nil end

    -- 用首格的实际尺寸计算列/行（所有格子等宽等高）
    local slotW = l11.w
    local slotH = l11.h
    local col = math.floor((screenX - gridLeft) / slotW) + 1
    local row = math.floor((screenY - gridTop)  / slotH) + 1
    return math.max(1, math.min(col, ctx.COLS)),
           math.max(1, math.min(row, rows))
end

-- ── 辅助：根据放置位置计算推荐旋转状态
-- 返回建议的 rotated 值（true/false），或 nil 表示不需要旋转
local function calcAutoRotate(ctx, item, toX, toY)
    local bw = item.w or 1
    local bh = item.h or 1
    if bw == bh then return nil end  -- 正方形，旋转无意义

    local maxRows = ctx.gridInst and ctx.gridInst.rows or 0
    -- 当前有效尺寸
    local ew = effW(item)
    local eh = effH(item)
    -- 用边缘到墙的距离（整数格数），避免中心偏移带来的半格误差
    local distToRight  = ctx.COLS - (toX + ew - 1)   -- 右边缘到右墙
    local distToLeft   = toX - 1                       -- 左边缘到左墙
    local distToBottom = maxRows - (toY + eh - 1)      -- 下边缘到下墙
    local distToTop    = toY - 1                        -- 上边缘到上墙
    local distLR = math.min(distToLeft, distToRight)
    local distTB = math.min(distToTop,  distToBottom)

    if distLR <= distTB then
        -- 更靠近左右侧 → 偏好纵向（eh >= ew）
        -- 若当前宽 > 高（横向），需旋转
        if ew > eh then return not item.rotated end
    else
        -- 更靠近上下侧 → 偏好横向（ew >= eh）
        -- 若当前高 > 宽（纵向），需旋转
        if eh > ew then return not item.rotated end
    end
    return nil  -- 已是最优方向
end

-- ── 辅助：对给定旋转状态模拟全局装箱，返回 "ok"/"swap"/"fail"
-- 不修改 gridMap
local function tryPreviewWithRotation(ctx, item, toX, toY, rotated)
    -- 临时计算该旋转下的有效尺寸
    local bw, bh = item.w or 1, item.h or 1
    local w = rotated and bh or bw
    local h = rotated and bw or bh
    local maxRows = ctx.gridInst and ctx.gridInst.rows or 0

    if toX < 1 or toY < 1 or toX + w - 1 > ctx.COLS or toY + h - 1 > maxRows then
        return "fail"
    end

    -- 收集目标区域内所有其他物品（在该旋转下）
    local seen = {}
    local displaced = {}
    for r = toY, toY + h - 1 do
        for c = toX, toX + w - 1 do
            local other = ctx.gridMap[r] and ctx.gridMap[r][c] or nil
            if other and other ~= item and not seen[other] then
                seen[other] = true
                displaced[#displaced + 1] = other
            end
        end
    end

    if #displaced == 0 then return "ok" end

    -- 构建排除集（item + displaced），模拟清除状态
    local excluded = { [item] = true }
    for _, d in ipairs(displaced) do excluded[d] = true end

    table.sort(displaced, function(a, b)
        return (a.w or 1) * (a.h or 1) > (b.w or 1) * (b.h or 1)
    end)

    local extra = {}
    local function isFree(r, c)
        if r < 1 or c < 1 or r > maxRows or c > ctx.COLS then return false end
        if r >= toY and r <= toY + h - 1 and c >= toX and c <= toX + w - 1 then return false end
        local cell = ctx.gridMap[r] and ctx.gridMap[r][c] or nil
        if cell and not excluded[cell] then return false end
        if extra[r] and extra[r][c] then return false end
        return true
    end

    for _, it in ipairs(displaced) do
        local iw, ih = effW(it), effH(it)
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
                    placed = true; break
                end
            end
            if placed then break end
        end
        if not placed then return "fail" end
    end
    return "swap"
end

-- ── 辅助：检查在 (toX, toY) 放置 item 的预判结果
-- 返回 mode("ok"/"swap"/"fail"), finalRotated(true/false)
-- finalRotated 为 nil 表示保持当前旋转；否则为落放时应设定的旋转状态
-- 优先级：先尝试自动旋转后的方向，若失败再尝试当前方向
local function previewPlace(ctx, item, toX, toY)
    local curRotated = item.rotated
    local autoRot    = calcAutoRotate(ctx, item, toX, toY)  -- nil 或 true/false

    -- 是否有推荐旋转（且与当前不同）
    local wantRot    = (autoRot ~= nil) and (autoRot ~= curRotated)

    if wantRot then
        -- 先尝试推荐旋转
        local mode = tryPreviewWithRotation(ctx, item, toX, toY, autoRot)
        if mode ~= "fail" then
            return mode, autoRot  -- 推荐旋转可行
        end
    end

    -- 尝试当前旋转
    local mode = tryPreviewWithRotation(ctx, item, toX, toY, curRotated)
    if mode == "ok" then
        return "ok", curRotated
    end

    -- 当前旋转为 swap 或 fail 时，若 item 非方形且还没试过另一方向，也试一次
    -- 若另一方向能达到更优结果（ok > swap），则选择旋转
    if item.w ~= item.h and not wantRot then
        local altRot  = not curRotated
        local altMode = tryPreviewWithRotation(ctx, item, toX, toY, altRot)
        if altMode == "ok" then
            return "ok", altRot  -- 旋转后无需置换，优先
        elseif altMode == "swap" and mode ~= "swap" then
            return "swap", altRot  -- swap 优于 fail
        end
    end

    if mode ~= "fail" then
        return mode, curRotated
    end
    return "fail", curRotated
end

-- ── 辅助：高亮/清除目标格子 ───────────────────────────────────────────────
local COLOR_OK   = { 100, 220, 130, 140 }   -- 绿：普通移动可放
local COLOR_SWAP = {  80, 140, 255, 140 }   -- 蓝：互换可行
local COLOR_BAD  = { 220,  80,  80, 140 }   -- 红：不可放

-- 额外记录互换时 item 原始区域的高亮状态
local _hlOriginCol = nil
local _hlOriginRow = nil

local function clearHighlight(ctx)
    local item = DragState.GetDragItem()
    -- 清除目标区域高亮（用上次高亮时记录的旋转尺寸）
    if _hlCol and _hlRow and item then
        local bw, bh = item.w or 1, item.h or 1
        local w = (_hlRotate ~= nil) and (_hlRotate and bh or bw) or effW(item)
        local h = (_hlRotate ~= nil) and (_hlRotate and bw or bh) or effH(item)
        for r = _hlRow, _hlRow + h - 1 do
            for c = _hlCol, _hlCol + w - 1 do
                local slot = ctx.gridSlots[(r - 1) * ctx.COLS + c]
                if slot then slot:SetStyle({ backgroundColor = { 0, 0, 0, 0 } }) end
            end
        end
    end
    -- 清除原始区域高亮（互换时才有）
    if _hlOriginCol and _hlOriginRow and item then
        local w, h = effW(item), effH(item)
        for r = _hlOriginRow, _hlOriginRow + h - 1 do
            for c = _hlOriginCol, _hlOriginCol + w - 1 do
                local slot = ctx.gridSlots[(r - 1) * ctx.COLS + c]
                if slot then slot:SetStyle({ backgroundColor = { 0, 0, 0, 0 } }) end
            end
        end
    end
    _hlCol, _hlRow = nil, nil
    _hlOriginCol, _hlOriginRow = nil, nil
    _hlRotate = nil
end

-- mode: "ok" | "swap" | "fail"；finalRotated: 落放时的旋转状态
local function setHighlight(ctx, item, toX, toY, mode, finalRotated)
    clearHighlight(ctx)
    local color = (mode == "ok") and COLOR_OK or (mode == "swap") and COLOR_SWAP or COLOR_BAD
    -- 用 finalRotated 计算高亮尺寸（反映旋转后的占格）
    local bw, bh = item.w or 1, item.h or 1
    local w = (finalRotated ~= nil) and (finalRotated and bh or bw) or effW(item)
    local h = (finalRotated ~= nil) and (finalRotated and bw or bh) or effH(item)
    -- 高亮目标区域
    for r = toY, toY + h - 1 do
        for c = toX, toX + w - 1 do
            local slot = ctx.gridSlots[(r - 1) * ctx.COLS + c]
            if slot then slot:SetStyle({ backgroundColor = color }) end
        end
    end
    _hlCol, _hlRow = toX, toY
    _hlRotate = finalRotated
    -- 互换时同时高亮 item 原始区域
    if mode == "swap" then
        local ox, oy = DragState.GetOrigin()
        if ox and oy and (ox ~= toX or oy ~= toY) then
            -- 原始区域用 item 当前（未旋转前）的有效尺寸
            local ow, oh = effW(item), effH(item)
            for r = oy, oy + oh - 1 do
                for c = ox, ox + ow - 1 do
                    local slot = ctx.gridSlots[(r - 1) * ctx.COLS + c]
                    if slot then slot:SetStyle({ backgroundColor = COLOR_SWAP }) end
                end
            end
            _hlOriginCol, _hlOriginRow = ox, oy
        end
    end
end

-- ── 辅助：计算拖拽放置目标的左上角格子（以指针为中心对齐 item）─────────────
local function calcTargetOrigin(ctx, item, cursorCol, cursorRow)
    local w = effW(item)
    local h = effH(item)
    local maxRows = ctx.gridInst and ctx.gridInst.rows or 0
    local col = math.max(1, math.min(cursorCol - math.floor(w / 2), ctx.COLS  - w + 1))
    local row = math.max(1, math.min(cursorRow - math.floor(h / 2), maxRows - h + 1))
    return col, row
end

-- ── 懒创建 ghost 面板并添加到根节点（第一次拖拽时才调用）────────────────
local function ensureGhost(refs_root)
    if _ghostPanel then return end  -- 已创建则直接返回
    _ghostImg = UI.Panel {
        position = "absolute",
        left = 4, top = 4, right = 4, bottom = 20,
        backgroundFit = "contain",
        pointerEvents = "none",
    }
    _ghostLabel = UI.Label {
        position = "absolute",
        left = 0, right = 0, bottom = 3,
        textAlign = "center",
        fontSize = 9,
        fontColor = { 220, 225, 235, 210 },
        pointerEvents = "none",
    }
    _ghostPanel = UI.Panel {
        position  = "absolute",
        left = 0, top = 0,
        width = 60, height = 60,
        zIndex = 900,
        visible = false,
        pointerEvents = "none",
        borderRadius = 3,
        borderWidth = 2,
        borderColor = { 255, 255, 255, 150 },
        backgroundColor = { 30, 34, 44, 180 },  -- alpha 替代 opacity
        children = { _ghostImg, _ghostLabel },
    }
    if refs_root then refs_root:AddChild(_ghostPanel) end
end

-- ── 更新 ghost 位置和内容 ─────────────────────────────────────────────────
local function updateGhost(ctx, item, screenX, screenY)
    if not _ghostPanel or not ctx.gridContainer then return end
    local rootLayout = ctx.refs_root and ctx.refs_root:GetAbsoluteLayout() or nil
    if not rootLayout then return end

    -- 从首格布局获取精确格子尺寸（避免 paddingRight 导致的误差）
    local s1 = ctx.gridSlots and ctx.gridSlots[1]
    local sl = s1 and s1:GetAbsoluteLayout() or nil
    local cellSize = (sl and sl.w > 0) and sl.w or 40
    -- 用有效尺寸（考虑当前旋转状态，ghost 跟随变化）
    local w = effW(item)
    local h = effH(item)
    local ghostW = cellSize * w - 4
    local ghostH = cellSize * h - 4

    -- ghost 跟随手指，中心对齐（垂直略偏上，避免手指遮挡）
    local px = screenX - rootLayout.x - ghostW * 0.5
    local py = screenY - rootLayout.y - ghostH * 0.65

    _ghostPanel:SetStyle({
        left = px, top = py,
        width = ghostW, height = ghostH,
        visible = true,
    })
    if _ghostImg then
        _ghostImg:SetStyle({ backgroundImage = item.image or "" })
    end
    if _ghostLabel then
        _ghostLabel:SetStyle({ text = item.name or "" })
    end
end

local function hideGhost()
    if _ghostPanel then _ghostPanel:SetStyle({ visible = false }) end
end

-- ── 公开 API ──────────────────────────────────────────────────────────────

-- 在 MyWarehousePanel.Show() 末尾调用，仅存储 ctx 引用
-- ghost 面板采用懒创建策略，在第一次拖拽时才添加到 UI 树（避免 SetRoot 前 AddChild）
function DragHandler.Init(ctx)
    _ctx = ctx
    _ghostPanel = nil  -- 重置，确保下次打开面板时重新创建（refs_root 可能已更新）
    _ghostImg   = nil
    _ghostLabel = nil
end

-- 在各 imgPanel 的 onPointerDown 中调用
-- imgPanel：该物品对应的图片面板（用于拖拽中半透明）
function DragHandler.OnImgPointerDown(ctx, item, imgPanel, event)
    if not ctx.dragEnabled then return end
    if ctx.isSellMode then return end
    if DragState.GetState() ~= DragState.IDLE then return end

    if DragState.StartDrag(ctx, item) then
        -- 懒创建 ghost（此时 UI 已经挂载，AddChild 安全）
        ensureGhost(ctx.refs_root)
        _dragImgPanel = imgPanel
        _dragPtId     = event and event.pointerId or nil
        if imgPanel then imgPanel:SetStyle({ opacity = 0.2 }) end
        if event then updateGhost(ctx, item, event.x, event.y) end
    end
end

-- 每帧调用（Panel.Update 中）
function DragHandler.Update(ctx, dt)
    if DragState.GetState() ~= DragState.DRAGGING then return end
    local item = DragState.GetDragItem()
    if not item then return end

    -- 读取当前指针位置
    local sx, sy = 0, 0
    local stillDown = false

    local numTouches = input:GetNumTouches()
    if numTouches > 0 then
        for i = 0, numTouches - 1 do
            local touch = input:GetTouch(i)
            if touch and (_dragPtId == nil or touch.touchID == _dragPtId) then
                sx, sy = touch.position.x, touch.position.y
                stillDown = true
                break
            end
        end
    else
        if input:GetMouseButtonDown(MOUSEB_LEFT) then
            local pos = input:GetMousePosition()
            sx, sy = pos.x, pos.y
            stillDown = true
        end
    end

    if stillDown then
        updateGhost(ctx, item, sx, sy)

        -- 计算目标格子并更新高亮
        local col, row = hitTestCell(ctx, sx, sy)
        if col and row then
            local tCol, tRow = calcTargetOrigin(ctx, item, col, row)
            if tCol ~= _hlCol or tRow ~= _hlRow then
                local mode, rot = previewPlace(ctx, item, tCol, tRow)
                setHighlight(ctx, item, tCol, tRow, mode, rot)
            end
        else
            clearHighlight(ctx)
        end
    else
        -- 手指/鼠标抬起 → 落放
        DragHandler.Drop(ctx)
    end
end

-- 手指抬起时落放（DragHandler.Update 内部调用，外部通常不直接调用）
function DragHandler.Drop(ctx)
    local item = DragState.GetDragItem()
    if not item then return end

    -- 恢复 imgPanel 透明度（在 RefreshDisplay 之前，避免闪烁）
    if _dragImgPanel then
        _dragImgPanel:SetStyle({ opacity = 1.0 })
        _dragImgPanel = nil
    end

    if _hlCol and _hlRow then
        local ok = DragState.TryMove(ctx, item, _hlCol, _hlRow, _hlRotate)
        if ok then
            DragState.EndDrag()
            SaveSystem.MarkDirty()
        else
            -- 目标被占用（极少发生，理论上 canPlaceAt 已提前检测）
            DragState.CancelDrag(ctx)
        end
    else
        -- 手指抬起时不在有效格子上 → 取消，回原位
        DragState.CancelDrag(ctx)
    end

    clearHighlight(ctx)
    hideGhost()
    _dragPtId = nil

    -- 刷新格子样式和图片位置
    GridSystem.RefreshDisplay(ctx)
    GridSystem.UpdateImagePositions(ctx)
end

-- 主动取消拖拽（如切换到出售模式时调用）
function DragHandler.Cancel(ctx)
    if DragState.GetState() ~= DragState.DRAGGING then return end

    if _dragImgPanel then
        _dragImgPanel:SetStyle({ opacity = 1.0 })
        _dragImgPanel = nil
    end

    DragState.CancelDrag(ctx)
    clearHighlight(ctx)
    hideGhost()
    _dragPtId = nil

    GridSystem.RefreshDisplay(ctx)
    GridSystem.UpdateImagePositions(ctx)
end

return DragHandler
