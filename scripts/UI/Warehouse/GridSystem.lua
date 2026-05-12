-- ============================================================================
-- UI/Warehouse/GridSystem.lua - 仓库格子系统
-- 负责 buildGrid / refreshGridDisplay / _updateImagePositions
-- 依赖 ctx（共享上下文），由 MyWarehousePanel 初始化并传入
-- ============================================================================

local Config = require("Config")
local SaveSystem = require("SaveSystem")
local WarehouseGrid = require("WarehouseGrid")

local GridSystem = {}

-- ============================================================================
-- 构建网格数据（计算布局）
-- ============================================================================

function GridSystem.BuildGrid(ctx, filteredItems)
    local capacity = SaveSystem.GetWarehouseCapacity()
    ctx.gridInst = WarehouseGrid.Create(capacity)
    WarehouseGrid.Rebuild(ctx.gridInst, filteredItems)

    local rows = ctx.gridInst.rows
    ctx.gridMap = {}
    for r = 1, rows do
        ctx.gridMap[r] = {}
        for c = 1, ctx.COLS do
            ctx.gridMap[r][c] = nil
        end
    end

    for _, item in ipairs(ctx.gridInst.items) do
        local gx = item.gridX
        local gy = item.gridY
        local w = item.w or 1
        local h = item.h or 1
        if gx and gy then
            for r = gy, gy + h - 1 do
                for c = gx, gx + w - 1 do
                    if ctx.gridMap[r] then
                        ctx.gridMap[r][c] = item
                    end
                end
            end
        end
    end

    return rows
end

-- ============================================================================
-- 刷新格子显示（样式 + 图片层 + 勾选框）
-- ============================================================================

function GridSystem.RefreshDisplay(ctx)
    if not ctx.gridInst or not ctx.gridMap then return end
    local rows = ctx.gridInst.rows

    -- 重置所有格子外观
    for slotIdx, slot in pairs(ctx.gridSlots) do
        local r = math.ceil(slotIdx / ctx.COLS)
        local c = slotIdx - (r - 1) * ctx.COLS
        if r <= rows then
            slot:SetVisible(true)
            slot:SetStyle({
                borderColor = { 80, 130, 170, 60 },
                borderWidth = { right = 1, bottom = 1 },
                backgroundColor = { 0, 0, 0, 0 },
            })
        else
            slot:SetVisible(false)
        end
    end

    -- 重置图片层
    ctx.imageToItem = {}
    for i = 1, ctx.MAX_ITEM_IMAGES do
        if ctx.itemImages[i] then
            ctx.itemImages[i]:SetVisible(false)
            ctx.itemImages[i]._imagePath = nil
            ctx.itemImages[i]._originSlot = nil
            ctx.itemImages[i]._endSlot = nil
        end
    end

    -- 绘制物品格子样式和图片
    local imgIdx = 0
    local processedItems = {}

    for r = 1, rows do
        for c = 1, ctx.COLS do
            local slotIdx = (r - 1) * ctx.COLS + c
            local slot = ctx.gridSlots[slotIdx]
            if not slot then goto nextCell end

            local item = ctx.gridMap[r] and ctx.gridMap[r][c]
            if not item then goto nextCell end

            local rar = Config.GetRarity(item.rarity)
            local w = item.w or 1
            local h = item.h or 1
            local isOrigin = (item.gridX == c and item.gridY == r)

            local bTop    = (r == item.gridY)         and 1 or 0
            local bBottom = (r == item.gridY + h - 1) and 1 or 0
            local bLeft   = (c == item.gridX)         and 1 or 0
            local bRight  = (c == item.gridX + w - 1) and 1 or 0

            slot:SetStyle({
                borderColor = rar.color,
                borderWidth = { top = bTop * 2, right = bRight * 2, bottom = bBottom * 2, left = bLeft * 2 },
                backgroundColor = { rar.color[1], rar.color[2], rar.color[3], 30 },
            })

            if isOrigin and not processedItems[item] then
                processedItems[item] = true
                if item.image and item.image ~= "" then
                    imgIdx = imgIdx + 1
                    if imgIdx <= ctx.MAX_ITEM_IMAGES then
                        local endSlotIdx = (item.gridY + h - 2) * ctx.COLS + (item.gridX + w - 1)
                        local originSlot = ctx.gridSlots[slotIdx]
                        local endSlot = ctx.gridSlots[endSlotIdx]
                        if originSlot and endSlot then
                            ctx.imageToItem[imgIdx] = item
                            ctx.itemImages[imgIdx]._imagePath = item.image
                            ctx.itemImages[imgIdx]._originSlot = originSlot
                            ctx.itemImages[imgIdx]._endSlot = endSlot
                            ctx.itemImages[imgIdx]:SetVisible(true)
                        end
                    end
                end
            end

            ::nextCell::
        end
    end

    -- 重置勾选框
    ctx.checkboxToItem = {}
    for i = 1, ctx.MAX_CHECKBOXES do
        if ctx.checkboxPanels[i] then
            ctx.checkboxPanels[i]:SetVisible(false)
        end
    end

    -- 出售模式显示勾选框
    if ctx.isSellMode then
        local cbIdx = 0
        local processedCb = {}
        for r = 1, rows do
            for c = 1, ctx.COLS do
                local item = ctx.gridMap[r] and ctx.gridMap[r][c]
                if item and not processedCb[item] then
                    local isOrigin = (item.gridX == c and item.gridY == r)
                    if isOrigin then
                        processedCb[item] = true
                        cbIdx = cbIdx + 1
                        if cbIdx <= ctx.MAX_CHECKBOXES and ctx.checkboxPanels[cbIdx] then
                            ctx.checkboxToItem[cbIdx] = item
                            ctx.checkboxPanels[cbIdx]:SetVisible(true)
                        end
                    end
                end
            end
        end
        -- 同步勾选视觉
        ctx._updateCheckboxVisuals()
    end
end

-- ============================================================================
-- 更新图片面板和勾选框的绝对位置（每帧/布局变化时调用）
-- ============================================================================

function GridSystem.UpdateImagePositions(ctx)
    local gridLayout = ctx.gridContainer and ctx.gridContainer:GetAbsoluteLayout() or nil
    if not gridLayout then return end

    for i = 1, ctx.MAX_ITEM_IMAGES do
        local img = ctx.itemImages[i]
        if not img or not img:IsVisible() then goto nextImg end
        local oSlot = img._originSlot
        local eSlot = img._endSlot
        if not oSlot or not eSlot then goto nextImg end

        local oL = oSlot:GetAbsoluteLayout()
        local eL = eSlot:GetAbsoluteLayout()
        local pad = 2
        img:SetStyle({
            left  = oL.x - gridLayout.x + pad,
            top   = oL.y - gridLayout.y + pad,
            width = (eL.x + eL.w - oL.x) - pad * 2,
            height = (eL.y + eL.h - oL.y) - pad * 2,
        })
        ::nextImg::
    end

    if ctx.isSellMode then
        for i = 1, ctx.MAX_CHECKBOXES do
            local cb = ctx.checkboxPanels[i]
            if cb and cb:IsVisible() then
                local item = ctx.checkboxToItem[i]
                if item and item.gridX and item.gridY then
                    local w = item.w or 1
                    local rightCol = item.gridX + w - 1
                    local slotIdx = (item.gridY - 1) * ctx.COLS + rightCol
                    local slot = ctx.gridSlots[slotIdx]
                    if slot then
                        local sL = slot:GetAbsoluteLayout()
                        local cbSize = 14
                        cb:SetStyle({
                            left   = (sL.x - gridLayout.x) + (sL.w - cbSize) - 1,
                            top    = (sL.y - gridLayout.y) + 1,
                            width  = cbSize,
                            height = cbSize,
                        })
                    end
                end
            end
        end
    end
end

return GridSystem
