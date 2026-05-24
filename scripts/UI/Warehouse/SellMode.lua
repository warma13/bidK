-- ============================================================================
-- UI/Warehouse/SellMode.lua - 仓库出售模式逻辑
-- 依赖 ctx（共享上下文），由 MyWarehousePanel 初始化并传入
-- ============================================================================

local UI = require("urhox-libs/UI")
local Utils = require("UI.Utils")
local RecycleManager = require("RecycleManager")
local MoneyManager = require("MoneyManager")
local MoneyHUD = require("UI.MoneyHUD")
local SaveSystem = require("SaveSystem")

local SellMode = {}

-- ============================================================================
-- 内部工具
-- ============================================================================

local function getSelectedList(ctx)
    local list = {}
    for item, _ in pairs(ctx.selectedItems) do
        list[#list + 1] = item
    end
    return list
end

local function getSelectedCount(ctx)
    local n = 0
    for _ in pairs(ctx.selectedItems) do n = n + 1 end
    return n
end

local function getSelectedTotalValue(ctx)
    local total = 0
    for item, _ in pairs(ctx.selectedItems) do
        total = total + RecycleManager.GetRecycleValue(item)
    end
    return total
end

-- ============================================================================
-- 勾选框视觉更新
-- ============================================================================

function SellMode.UpdateCheckboxVisuals(ctx)
    for i = 1, ctx.MAX_CHECKBOXES do
        local cb = ctx.checkboxPanels[i]
        if cb and cb:IsVisible() then
            local item = ctx.checkboxToItem[i]
            if item and ctx.selectedItems[item] then
                cb:SetStyle({
                    backgroundColor = { 50, 180, 80, 230 },
                    borderColor = { 80, 220, 120, 255 },
                })
                if cb._checkLabel then cb._checkLabel:SetText("✓") end
            else
                cb:SetStyle({
                    backgroundColor = { 0, 0, 0, 120 },
                    borderColor = { 150, 160, 180, 180 },
                })
                if cb._checkLabel then cb._checkLabel:SetText("") end
            end
        end
    end
end

-- ============================================================================
-- 出售栏数值更新
-- ============================================================================

function SellMode.UpdateSellBar(ctx)
    if not ctx.sellBar then return end
    local count = getSelectedCount(ctx)
    local value = getSelectedTotalValue(ctx)
    if ctx.sellCountLabel then
        ctx.sellCountLabel:SetText("已选 " .. count .. " 件")
    end
    if ctx.sellValueLabel then
        ctx.sellValueLabel:SetText(Utils.FormatMoney(value))
    end
end

-- ============================================================================
-- 切换物品选中状态
-- ============================================================================

function SellMode.ToggleItemSelection(ctx, item)
    if not item then return end
    if ctx.selectedItems[item] then
        ctx.selectedItems[item] = nil
    else
        ctx.selectedItems[item] = true
    end
    SellMode.UpdateCheckboxVisuals(ctx)
    SellMode.UpdateSellBar(ctx)
end

-- ============================================================================
-- 进入 / 退出出售模式
-- ============================================================================

function SellMode.Exit(ctx)
    ctx.isSellMode = false
    ctx.selectedItems = {}
    ctx.isDragSelecting = false
    ctx.dragSelectTouched = {}
    ctx.dragSelectPointerId = nil

    if ctx.sellBar then ctx.sellBar:SetVisible(false) end
    if ctx.sellModeBtn then
        ctx.sellModeBtn:SetStyle({ backgroundColor = { 52, 56, 68, 180 } })
        if ctx.sellModeBtn._label then
            ctx.sellModeBtn._label:SetText("出售物品")
        end
    end
    for i = 1, ctx.MAX_CHECKBOXES do
        if ctx.checkboxPanels[i] then
            ctx.checkboxPanels[i]:SetVisible(false)
        end
    end
    if ctx.detailInst then ctx.detailInst:Hide() end
end

function SellMode.Enter(ctx)
    -- 进入出售模式前关掉拖拽整理模式（两者互斥）
    if ctx.dragEnabled then
        ctx.dragEnabled = false
        if ctx.dragModeBtn then
            ctx.dragModeBtn:SetStyle({ backgroundColor = { 52, 56, 68, 180 } })
            if ctx.dragModeBtn._label then ctx.dragModeBtn._label:SetText("拖拽整理") end
        end
    end
    ctx.isSellMode = true
    ctx.selectedItems = {}
    if ctx.sellBar then ctx.sellBar:SetVisible(true) end
    if ctx.sellModeBtn then
        ctx.sellModeBtn:SetStyle({ backgroundColor = { 140, 60, 60, 220 } })
        if ctx.sellModeBtn._label then
            ctx.sellModeBtn._label:SetText("取消出售")
        end
    end
    SellMode.UpdateSellBar(ctx)
    ctx._needPositionUpdate()
    ctx._refreshGridDisplay()
end

function SellMode.Toggle(ctx)
    if ctx.isSellMode then
        SellMode.Exit(ctx)
        ctx._refreshGridDisplay()
    else
        SellMode.Enter(ctx)
    end
end

-- ============================================================================
-- 确认弹窗
-- ============================================================================

local function hideSellConfirm(ctx)
    if ctx.sellConfirmPopup then
        ctx.sellConfirmPopup:SetVisible(false)
        ctx.sellConfirmPopup:Remove()
        ctx.sellConfirmPopup = nil
    end
end

local function doSell(ctx)
    local list = getSelectedList(ctx)
    if #list == 0 then return end

    local totalValue = getSelectedTotalValue(ctx)

    MoneyManager.AddMoneyFromMenu(totalValue, "sell_items", {
        silent = true,
        skipSave = true,
    })

    SaveSystem.RemoveItems(list)
    SaveSystem.Save()

    ctx.allItems = SaveSystem.GetItems()
    table.sort(ctx.allItems, function(a, b)
        return (a.wonAt or 0) > (b.wonAt or 0)
    end)

    hideSellConfirm(ctx)
    SellMode.Exit(ctx)
    ctx._updateLevelDisplay()
    ctx._refreshCards()
end

function SellMode.ShowConfirm(ctx)
    local count = getSelectedCount(ctx)
    if count == 0 then
        Utils.ShowMessage("请先选择要出售的物品")
        return
    end
    local totalValue = getSelectedTotalValue(ctx)

    local confirmBtn = UI.Button {
        text = "确认出售",
        width = 110, height = 34,
        fontSize = 13,
        fontWeight = "bold",
        backgroundColor = { 180, 50, 50, 240 },
        fontColor = { 255, 255, 255, 255 },
        borderRadius = 0,
        borderWidth = 1,
        borderColor = { 220, 80, 80, 200 },
        onClick = function()
            Utils.PlayClick()
            doSell(ctx)
        end,
    }

    local cancelBtn = UI.Button {
        text = "取消",
        width = 80, height = 34,
        fontSize = 13,
        backgroundColor = { 55, 60, 72, 220 },
        fontColor = { 180, 185, 200, 255 },
        borderRadius = 0,
        borderWidth = 1,
        borderColor = { 80, 85, 100, 160 },
        onClick = function()
            Utils.PlayClick()
            hideSellConfirm(ctx)
        end,
    }

    local card = UI.Panel {
        width = 280,
        backgroundColor = { 30, 34, 44, 250 },
        borderRadius = 0,
        borderWidth = 1,
        borderColor = { 180, 80, 80, 200 },
        padding = { 20, 16 },
        flexDirection = "column",
        gap = 10,
        alignItems = "center",
        children = {
            UI.Label {
                text = "确认出售",
                fontSize = 16,
                fontColor = { 255, 100, 100, 255 },
                fontWeight = "bold",
                textAlign = "center",
                width = "100%",
            },
            UI.Panel {
                width = "100%", height = 1,
                backgroundColor = { 60, 65, 80, 200 },
            },
            UI.Label {
                text = "确定要出售选中的 " .. count .. " 件物品吗？",
                fontSize = 13,
                fontColor = { 200, 205, 215, 255 },
                textAlign = "center",
                width = "100%",
            },
            UI.Panel {
                flexDirection = "row",
                alignItems = "center",
                justifyContent = "center",
                gap = 4,
                children = {
                    UI.Label { text = "可获得", fontSize = 13, fontColor = { 180, 185, 200, 220 } },
                    UI.Panel {
                        width = 14, height = 14,
                        backgroundImage = Utils.GetIcon("coin"),
                        backgroundFit = "contain",
                    },
                    UI.Label {
                        text = Utils.FormatMoney(totalValue),
                        fontSize = 15,
                        fontColor = { 255, 220, 100, 255 },
                        fontWeight = "bold",
                    },
                },
            },
            UI.Panel { width = "100%", height = 1, backgroundColor = { 60, 65, 80, 200 } },
            UI.Panel {
                width = "100%",
                flexDirection = "row",
                justifyContent = "center",
                gap = 12,
                children = { cancelBtn, confirmBtn },
            },
        },
    }

    hideSellConfirm(ctx)

    ctx.sellConfirmPopup = UI.Panel {
        position = "absolute",
        left = 0, top = 0, right = 0, bottom = 0,
        backgroundColor = { 0, 0, 0, 160 },
        justifyContent = "center",
        alignItems = "center",
        visible = true,
        onClick = function()
            Utils.PlayClick()
            hideSellConfirm(ctx)
        end,
        children = {
            UI.Panel { onClick = function() end, children = { card } },
        },
    }

    if ctx.refs_root then
        ctx.refs_root:AddChild(ctx.sellConfirmPopup)
    end
end

-- ============================================================================
-- 滑动选择
-- ============================================================================

function SellMode.HitTestItemAtScreenPos(ctx, sx, sy)
    for i = 1, ctx.MAX_ITEM_IMAGES do
        local img = ctx.itemImages[i]
        if img and img:IsVisible() and ctx.imageToItem[i] then
            local oSlot = img._originSlot
            local eSlot = img._endSlot
            if oSlot and eSlot then
                local oL = oSlot:GetAbsoluteLayoutForHitTest()
                local eL = eSlot:GetAbsoluteLayoutForHitTest()
                if sx >= oL.x and sx <= eL.x + eL.w
                   and sy >= oL.y and sy <= eL.y + eL.h then
                    return ctx.imageToItem[i]
                end
            end
        end
    end
    return nil
end

function SellMode.StartDragSelect(ctx, item, touchId)
    ctx.isDragSelecting = true
    ctx.dragSelectTouched = {}
    ctx.dragSelectPointerId = touchId
    if item then
        ctx.dragSelectTouched[item] = true
        SellMode.ToggleItemSelection(ctx, item)
    end
end

function SellMode.UpdateDragSelect(ctx, sx, sy)
    if not ctx.isDragSelecting then return end
    local item = SellMode.HitTestItemAtScreenPos(ctx, sx, sy)
    if item and not ctx.dragSelectTouched[item] then
        ctx.dragSelectTouched[item] = true
        SellMode.ToggleItemSelection(ctx, item)
    end
end

function SellMode.EndDragSelect(ctx)
    ctx.isDragSelecting = false
    ctx.dragSelectTouched = {}
    ctx.dragSelectPointerId = nil
end

return SellMode
