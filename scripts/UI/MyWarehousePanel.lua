-- ============================================================================
-- UI/MyWarehousePanel.lua - 我的仓库（全屏页面）
-- 格子布局：物品占据实际 w×h 格子，图片通过 NanoVG 自定义渲染
-- ============================================================================

local UI = require("urhox-libs/UI")
local Config = require("Config")
local UIState = require("UI.UIState")
local Utils = require("UI.Utils")
local MoneyHUD = require("UI.MoneyHUD")
local SaveSystem = require("SaveSystem")

local WarehouseUpgrade = require("Config.WarehouseUpgrade")
local ImageCache = require("urhox-libs/UI/Core/ImageCache")
local ItemDetailPanel = require("UI.ItemDetailPanel")

local SellMode    = require("UI.Warehouse.SellMode")
local GridSystem  = require("UI.Warehouse.GridSystem")
local UpgradePanel = require("UI.Warehouse.UpgradePanel")

local Panel = {}

-- ============================================================================
-- 共享上下文（ctx）：所有子模块读写此表
-- ============================================================================

---@type table
local ctx = {
    -- 格子常量
    COLS = Config.GAME.WarehouseColumns,
    MAX_ITEM_IMAGES = 120,
    MAX_CHECKBOXES  = 120,

    -- 格子系统
    gridSlots    = {},
    gridContainer = nil,
    itemImages   = {},
    imageToItem  = {},
    gridInst     = nil,
    gridMap      = nil,

    -- 物品详情
    detailPanel = nil,
    detailInst  = nil,

    -- 筛选状态
    activeFilters = { rarity = nil, category = nil },
    rarityBtns    = {},
    categoryBtns  = {},

    -- 数据
    allItems = {},

    -- 根节点引用
    refs_root = nil,

    -- 返回主菜单回调
    onBackCallback = nil,

    -- 出售模式
    isSellMode       = false,
    selectedItems    = {},
    checkboxPanels   = {},
    checkboxToItem   = {},
    sellBar          = nil,
    sellCountLabel   = nil,
    sellValueLabel   = nil,
    sellModeBtn      = nil,
    sellConfirmPopup = nil,

    -- 勾选框显示引用
    levelLabel    = nil,
    capacityLabel = nil,
    upgradeBtn    = nil,
    upgradePopup  = nil,
    emptyPanel    = nil,

    -- 滑动选择状态
    isDragSelecting     = false,
    dragSelectTouched   = {},
    dragSelectPointerId = nil,

    -- 占位符，由 Show() 绑定
    _needPositionUpdate  = function() end,
    _refreshGridDisplay  = function() end,
    _refreshCards        = function() end,
    _updateLevelDisplay  = function() end,
    _updateCheckboxVisuals = function() end,
}

-- ============================================================================
-- 筛选工具（局部）
-- ============================================================================

local function applyFilters(items)
    local result = {}
    for _, item in ipairs(items) do
        local pass = true
        if ctx.activeFilters.rarity   and item.rarity   ~= ctx.activeFilters.rarity   then pass = false end
        if ctx.activeFilters.category and item.category ~= ctx.activeFilters.category then pass = false end
        if pass then result[#result + 1] = item end
    end
    return result
end

local function updateFilterStyles()
    for id, btn in pairs(ctx.rarityBtns) do
        if id == ctx.activeFilters.rarity then
            btn:SetStyle({ borderColor = { 255, 255, 255, 200 }, borderWidth = 2 })
        else
            btn:SetStyle({ borderColor = { 70, 75, 88, 120 }, borderWidth = 1 })
        end
    end
    for id, btn in pairs(ctx.categoryBtns) do
        if id == ctx.activeFilters.category then
            btn:SetStyle({ backgroundColor = { 75, 85, 115, 220 }, borderColor = { 140, 155, 185, 220 } })
        else
            btn:SetStyle({ backgroundColor = { 42, 47, 58, 180 }, borderColor = { 65, 72, 85, 120 } })
        end
    end
end

-- ============================================================================
-- refreshCards（含空状态切换）
-- ============================================================================

local function refreshCards()
    local filtered = applyFilters(ctx.allItems)
    if #filtered == 0 then
        if ctx.gridContainer then ctx.gridContainer:SetVisible(false) end
        ctx.emptyPanel:SetVisible(true)
        if ctx.detailInst then ctx.detailInst:Hide() end
    else
        ctx.emptyPanel:SetVisible(false)
        if ctx.gridContainer then ctx.gridContainer:SetVisible(true) end
        GridSystem.BuildGrid(ctx, filtered)
        GridSystem.RefreshDisplay(ctx)
    end
end

-- ============================================================================
-- 格子点击 → 显示物品信息
-- ============================================================================

function Panel._OnSlotClick(slotIdx)
    if not ctx.gridMap then return end
    local r = math.ceil(slotIdx / ctx.COLS)
    local c = slotIdx - (r - 1) * ctx.COLS
    local item = ctx.gridMap[r] and ctx.gridMap[r][c]
    if item then
        if ctx.isSellMode then
            SellMode.ToggleItemSelection(ctx, item)
        else
            Panel._ShowItemInfo(item)
        end
    else
        if not ctx.isSellMode and ctx.detailInst then ctx.detailInst:Hide() end
    end
end

function Panel._ShowItemInfo(item)
    if not item or not ctx.detailInst then return end
    if not item.realValue then
        item.realValue = item.baseValue or 0
    end
    if ctx.detailInst:IsVisible() and ctx.detailInst:GetCurrentItem() == item then
        ctx.detailInst:Hide()
        return
    end

    ctx.detailInst:Show(item)

    if ctx.detailPanel and item.gridX and item.gridY then
        local w = item.w or 1
        local h = item.h or 1
        local originIdx = (item.gridY - 1) * ctx.COLS + item.gridX
        local endIdx    = (item.gridY + h - 2) * ctx.COLS + (item.gridX + w - 1)
        local oSlot = ctx.gridSlots[originIdx]
        local eSlot = ctx.gridSlots[endIdx]
        local rootLayout = ctx.refs_root and ctx.refs_root:GetAbsoluteLayout() or nil
        if oSlot and eSlot and rootLayout then
            local oL = oSlot:GetAbsoluteLayout()
            local eL = eSlot:GetAbsoluteLayout()
            local itemRight = eL.x + eL.w - rootLayout.x
            local itemLeft  = oL.x - rootLayout.x
            local itemTop   = oL.y - rootLayout.y
            local panelW = 200
            local screenW = rootLayout.w

            local px, py
            if itemRight + panelW + 8 < screenW then
                px = itemRight + 4
            else
                px = itemLeft - panelW - 4
                if px < 0 then px = 4 end
            end
            py = itemTop
            ctx.detailPanel:SetStyle({ left = px, top = py, right = nil })
        end
    end
end

-- ============================================================================
-- 每帧更新：滑动选择轮询
-- ============================================================================

function Panel.Update(dt)
    if not ctx.isDragSelecting or not ctx.isSellMode then
        if ctx.isDragSelecting then SellMode.EndDragSelect(ctx) end
        return
    end

    local sx, sy = 0, 0
    local stillDown = false

    local numTouches = input:GetNumTouches()
    if numTouches > 0 then
        for i = 0, numTouches - 1 do
            local touch = input:GetTouch(i)
            if touch then
                sx = touch.position.x
                sy = touch.position.y
                stillDown = true
                break
            end
        end
    else
        if input:GetMouseButtonDown(MOUSEB_LEFT) then
            local pos = input:GetMousePosition()
            sx = pos.x
            sy = pos.y
            stillDown = true
        end
    end

    if stillDown then
        local s = UI.GetScale()
        SellMode.UpdateDragSelect(ctx, sx / s, sy / s)
    else
        SellMode.EndDragSelect(ctx)
    end
end

-- ============================================================================
-- 显示（全屏页面）
-- ============================================================================

function Panel.Show(onBack)
    ctx.onBackCallback = onBack
    UIState.currentScreen = "warehouse"

    -- 响应式缩放
    local dpr = graphics:GetDPR()
    local screenH = graphics:GetHeight() / dpr
    local s = math.max(1.0, screenH / 440)
    local function sz(base) return math.floor(base * s) end

    -- 加载物品
    ctx.allItems = SaveSystem.GetItems()

    -- 重置筛选
    ctx.activeFilters.rarity   = nil
    ctx.activeFilters.category = nil
    ctx.rarityBtns   = {}
    ctx.categoryBtns = {}

    -- 重置出售模式
    ctx.isSellMode         = false
    ctx.selectedItems      = {}
    ctx.isDragSelecting    = false
    ctx.dragSelectTouched  = {}
    ctx.dragSelectPointerId = nil
    ctx.checkboxPanels     = {}
    ctx.checkboxToItem     = {}
    ctx.sellBar          = nil
    ctx.sellCountLabel   = nil
    ctx.sellValueLabel   = nil
    ctx.sellModeBtn      = nil
    ctx.sellConfirmPopup = nil

    -- ── 创建格子网格 ────────────────────────────────
    local capacity = SaveSystem.GetWarehouseCapacity()
    local totalRows = math.ceil(capacity / ctx.COLS)

    ctx.gridSlots = {}
    local gridRowWidgets = {}
    for r = 1, totalRows do
        local rowChildren = {}
        for c = 1, ctx.COLS do
            local slotIdx = (r - 1) * ctx.COLS + c
            local slot = UI.Panel {
                aspectRatio = 1,
                flexGrow = 1,
                flexBasis = 0,
                borderRadius = 0,
                backgroundColor = { 0, 0, 0, 0 },
                borderWidth = { right = 1, bottom = 1 },
                borderColor = { 80, 130, 170, 60 },
                justifyContent = "center",
                alignItems = "center",
                onClick = function()
                    if not ctx.isSellMode then
                        Utils.PlayClick()
                        Panel._OnSlotClick(slotIdx)
                    end
                end,
                onPointerDown = function(event)
                    if not ctx.isSellMode then return end
                    if not ctx.gridMap then return end
                    local r2 = math.ceil(slotIdx / ctx.COLS)
                    local c2 = slotIdx - (r2 - 1) * ctx.COLS
                    local item = ctx.gridMap[r2] and ctx.gridMap[r2][c2]
                    if item then
                        Utils.PlayClick()
                        SellMode.StartDragSelect(ctx, item, event.pointerId)
                    end
                end,
            }
            ctx.gridSlots[slotIdx] = slot
            rowChildren[c] = slot
        end
        gridRowWidgets[r] = UI.Panel {
            width = "100%",
            flexDirection = "row",
            children = rowChildren,
        }
    end

    -- 图片叠加面板池
    ctx.itemImages  = {}
    ctx.imageToItem = {}
    local itemImageWidgets = {}
    for i = 1, ctx.MAX_ITEM_IMAGES do
        local idx = i
        local imgPanel = UI.Panel {
            position = "absolute",
            width = 32, height = 32,
            visible = false,
            onClick = function()
                if not ctx.isSellMode then
                    Utils.PlayClick()
                    local item = ctx.imageToItem[idx]
                    if item then Panel._ShowItemInfo(item) end
                end
            end,
            onPointerDown = function(event)
                if not ctx.isSellMode then return end
                Utils.PlayClick()
                local item = ctx.imageToItem[idx]
                SellMode.StartDragSelect(ctx, item, event.pointerId)
            end,
        }
        imgPanel._imagePath  = nil
        imgPanel._originSlot = nil
        imgPanel._endSlot    = nil

        function imgPanel:Render(nvg)
            local imgPath = self._imagePath
            local oSlot = self._originSlot
            local eSlot = self._endSlot
            if not imgPath or not oSlot or not eSlot then return end

            local oL = oSlot:GetAbsoluteLayout()
            local eL = eSlot:GetAbsoluteLayout()
            local fullX = oL.x
            local fullY = oL.y
            local fullW = eL.x + eL.w - oL.x
            local fullH = eL.y + eL.h - oL.y
            if fullW <= 0 or fullH <= 0 then return end

            local item = ctx.imageToItem[idx]
            if item then
                local rar = Config.GetRarity(item.rarity)
                if rar and rar.color then
                    nvgBeginPath(nvg)
                    nvgRect(nvg, fullX, fullY, fullW, fullH)
                    nvgFillColor(nvg, nvgRGBA(rar.color[1], rar.color[2], rar.color[3], 30))
                    nvgFill(nvg)
                end
            end

            local imgHandle = ImageCache.Get(imgPath)
            if not imgHandle or imgHandle <= 0 then return end
            local nativeW, nativeH = ImageCache.GetSize(imgPath)
            if nativeW <= 0 or nativeH <= 0 then return end

            local pad = 2
            local x = fullX + pad
            local y = fullY + pad
            local w = fullW - pad * 2
            local h = fullH - pad * 2
            if w <= 0 or h <= 0 then return end

            local imgRatio = nativeW / nativeH
            local boxRatio = w / h
            local drawX, drawY, drawW, drawH = x, y, w, h
            if imgRatio > boxRatio then
                drawW = w
                drawH = w / imgRatio
                drawY = y + (h - drawH) / 2
            else
                drawH = h
                drawW = h * imgRatio
                drawX = x + (w - drawW) / 2
            end

            local paint = nvgImagePattern(nvg, drawX, drawY, drawW, drawH, 0, imgHandle, 1)
            nvgBeginPath(nvg)
            nvgRect(nvg, x, y, w, h)
            nvgFillPaint(nvg, paint)
            nvgFill(nvg)
        end

        ctx.itemImages[i] = imgPanel
        itemImageWidgets[#itemImageWidgets + 1] = imgPanel
    end

    -- 勾选框面板池
    ctx.checkboxPanels = {}
    ctx.checkboxToItem = {}
    local checkboxWidgets = {}
    for i = 1, ctx.MAX_CHECKBOXES do
        local cbIdx = i
        local checkLabel = UI.Label {
            text = "", fontSize = 10,
            fontColor = { 255, 255, 255, 255 },
            fontWeight = "bold",
            pointerEvents = "none",
        }
        local cbPanel = UI.Panel {
            position = "absolute",
            width = 14, height = 14,
            visible = false,
            backgroundColor = { 0, 0, 0, 120 },
            borderWidth = 1,
            borderColor = { 150, 160, 180, 180 },
            borderRadius = 2,
            justifyContent = "center",
            alignItems = "center",
            onClick = function()
                Utils.PlayClick()
                local item = ctx.checkboxToItem[cbIdx]
                if item then SellMode.ToggleItemSelection(ctx, item) end
            end,
            children = { checkLabel },
        }
        cbPanel._checkLabel = checkLabel
        ctx.checkboxPanels[i] = cbPanel
        checkboxWidgets[#checkboxWidgets + 1] = cbPanel
    end

    -- 组合格子 + 图片层 + 勾选框
    local gridChildren = {}
    for _, row in ipairs(gridRowWidgets) do
        gridChildren[#gridChildren + 1] = row
    end
    for _, img in ipairs(itemImageWidgets) do
        gridChildren[#gridChildren + 1] = img
    end
    for _, cb in ipairs(checkboxWidgets) do
        gridChildren[#gridChildren + 1] = cb
    end

    ctx.gridContainer = UI.Panel {
        id = "warehouseGridContainer",
        width = "100%",
        flexDirection = "column",
        paddingRight = 8,
        borderWidth = { left = 1, top = 1 },
        borderColor = { 80, 130, 170, 60 },
        children = gridChildren,
    }

    local needPositionUpdate = true
    function ctx.gridContainer:Render(nvg)
        self:RenderFullBackground(nvg)
        if needPositionUpdate then
            needPositionUpdate = false
            GridSystem.UpdateImagePositions(ctx)
        end
    end

    ctx._needPositionUpdate = function()
        needPositionUpdate = true
    end

    -- 绑定子模块回调
    ctx._refreshGridDisplay = function()
        GridSystem.RefreshDisplay(ctx)
    end
    ctx._refreshCards = function()
        refreshCards()
    end
    ctx._updateLevelDisplay = function()
        UpgradePanel.UpdateLevelDisplay(ctx)
    end
    ctx._updateCheckboxVisuals = function()
        SellMode.UpdateCheckboxVisuals(ctx)
    end

    -- ── 顶部栏 ──────────────────────────────────────
    local backBtn = UI.Button {
        text = "< 返回",
        width = "100%", height = sz(26),
        flexShrink = 0,
        fontSize = sz(11),
        backgroundColor = { 40, 44, 55, 220 },
        fontColor = { 190, 195, 210, 255 },
        borderWidth = 1,
        borderColor = { 80, 85, 100, 160 },
        borderRadius = 0,
        onClick = function()
            Utils.PlayClick()
            if ctx.onBackCallback then ctx.onBackCallback() end
        end,
    }

    local titleLabel = UI.Label {
        text = "我的仓库", fontSize = sz(14),
        fontColor = { 225, 228, 235, 255 },
        fontWeight = "bold",
    }

    ctx.levelLabel = UI.Label {
        text = "Lv.1", fontSize = sz(11),
        fontColor = { 255, 220, 100, 255 },
        fontWeight = "bold",
    }

    ctx.capacityLabel = UI.Label {
        text = "0/28", fontSize = sz(10),
        fontColor = { 160, 170, 190, 220 },
    }

    ctx.upgradeBtn = UI.Panel {
        height = sz(22),
        paddingHorizontal = sz(8),
        borderRadius = 0,
        backgroundColor = { 50, 110, 70, 220 },
        borderWidth = 1,
        borderColor = { 80, 180, 110, 200 },
        justifyContent = "center", alignItems = "center",
        onClick = function()
            Utils.PlayClick()
            local popup = UpgradePanel.ShowPopup(ctx)
            if popup and ctx.refs_root then
                ctx.refs_root:AddChild(popup)
            end
        end,
        children = {
            UI.Label {
                text = "升级仓库 ↑", fontSize = sz(9),
                fontColor = { 220, 255, 230, 255 },
                fontWeight = "bold",
                pointerEvents = "none",
            },
        },
    }

    local topBar = UI.Panel {
        width = "100%",
        height = sz(36),
        backgroundColor = { 30, 33, 40, 255 },
        flexDirection = "row",
        alignItems = "center",
        paddingHorizontal = sz(10),
        gap = sz(8),
        children = {
            titleLabel,
            ctx.levelLabel,
            UI.Panel { width = 1, height = 20, backgroundColor = { 60, 65, 80, 150 } },
            ctx.capacityLabel,
            ctx.upgradeBtn,
            UI.Panel { flexGrow = 1 },
            MoneyHUD.CreatePanel(),
        },
    }

    -- ── 左侧筛选栏 ─────────────────────────────────
    local qualityChildren = {}
    for _, rar in ipairs(Config.RARITY) do
        local btn = UI.Panel {
            width = sz(22), height = sz(22),
            borderRadius = 0,
            borderWidth = 1,
            borderColor = { 70, 75, 88, 120 },
            backgroundColor = { rar.color[1], rar.color[2], rar.color[3], 35 },
            justifyContent = "center", alignItems = "center",
            onClick = function()
                Utils.PlayClick()
                if ctx.activeFilters.rarity == rar.id then
                    ctx.activeFilters.rarity = nil
                else
                    ctx.activeFilters.rarity = rar.id
                end
                updateFilterStyles()
                refreshCards()
            end,
            children = {
                UI.Label {
                    text = "\u{25C6}", fontSize = sz(10),
                    fontColor = rar.color,
                    pointerEvents = "none",
                },
            },
        }
        ctx.rarityBtns[rar.id] = btn
        qualityChildren[#qualityChildren + 1] = btn
    end

    local qualitySection = UI.Panel {
        width = "100%",
        flexDirection = "column", gap = sz(4),
        alignItems = "center",
        children = {
            UI.Label { text = "品质", fontSize = sz(9), fontColor = { 110, 118, 135, 180 } },
            UI.Panel {
                flexDirection = "row", flexWrap = "wrap", gap = sz(3),
                justifyContent = "center",
                children = qualityChildren,
            },
        },
    }

    local categoryChildren = {}
    for _, cat in ipairs(Config.CATEGORIES) do
        local btn = UI.Panel {
            width = "46%",
            paddingVertical = sz(3),
            borderRadius = 0,
            borderWidth = 1,
            borderColor = { 65, 72, 85, 120 },
            backgroundColor = { 42, 47, 58, 180 },
            justifyContent = "center", alignItems = "center",
            onClick = function()
                Utils.PlayClick()
                if ctx.activeFilters.category == cat.id then
                    ctx.activeFilters.category = nil
                else
                    ctx.activeFilters.category = cat.id
                end
                updateFilterStyles()
                refreshCards()
            end,
            children = {
                UI.Label {
                    text = cat.name, fontSize = sz(9),
                    fontColor = { 170, 178, 192, 220 },
                    pointerEvents = "none",
                },
            },
        }
        ctx.categoryBtns[cat.id] = btn
        categoryChildren[#categoryChildren + 1] = btn
    end

    local categorySection = UI.Panel {
        width = "100%",
        flexDirection = "column", gap = sz(4),
        alignItems = "center",
        children = {
            UI.Label { text = "分类", fontSize = sz(9), fontColor = { 110, 118, 135, 180 } },
            UI.Panel {
                width = "100%",
                flexDirection = "row", flexWrap = "wrap", gap = sz(3),
                justifyContent = "center",
                children = categoryChildren,
            },
        },
    }

    local clearBtn = UI.Panel {
        width = "100%", height = sz(22),
        borderRadius = 0,
        backgroundColor = { 52, 56, 68, 180 },
        justifyContent = "center", alignItems = "center",
        marginTop = sz(6),
        onClick = function()
            Utils.PlayClick()
            ctx.activeFilters.rarity   = nil
            ctx.activeFilters.category = nil
            updateFilterStyles()
            refreshCards()
        end,
        children = {
            UI.Label {
                text = "清除筛选", fontSize = sz(9),
                fontColor = { 150, 158, 170, 200 },
                pointerEvents = "none",
            },
        },
    }

    local organizeBtn = UI.Panel {
        width = "100%", height = sz(22),
        borderRadius = 0,
        backgroundColor = { 52, 56, 68, 180 },
        justifyContent = "center", alignItems = "center",
        marginTop = sz(3),
        onClick = function()
            Utils.PlayClick()
            local backup = {}
            for _, item in ipairs(ctx.allItems) do
                backup[item] = { gridX = item.gridX, gridY = item.gridY }
            end
            for _, item in ipairs(ctx.allItems) do
                item.gridX = nil
                item.gridY = nil
            end
            local rarIdx = {}
            for i, r in ipairs(Config.RARITY) do rarIdx[r.id] = i end
            table.sort(ctx.allItems, function(a, b)
                local ra = rarIdx[a.rarity] or 0
                local rb = rarIdx[b.rarity] or 0
                if ra ~= rb then return ra > rb end
                local sa = (a.w or 1) * (a.h or 1)
                local sb = (b.w or 1) * (b.h or 1)
                if sa ~= sb then return sa > sb end
                local ca = a.category or ""
                local cb = b.category or ""
                if ca ~= cb then return ca < cb end
                local na = a.name or ""
                local nb = b.name or ""
                if na ~= nb then return na < nb end
                return (a.wonAt or 0) > (b.wonAt or 0)
            end)
            refreshCards()
            local allPlaced = true
            for _, item in ipairs(ctx.allItems) do
                if not item.gridX or not item.gridY then
                    allPlaced = false
                    break
                end
            end
            if allPlaced then
                SaveSystem.MarkDirty()
            else
                for _, item in ipairs(ctx.allItems) do
                    local b = backup[item]
                    if b then
                        item.gridX = b.gridX
                        item.gridY = b.gridY
                    end
                end
                refreshCards()
                Utils.ShowMessage("仓库空间不足，无法整理")
            end
        end,
        children = {
            UI.Label {
                text = "整理仓库", fontSize = sz(9),
                fontColor = { 180, 200, 255, 220 },
                pointerEvents = "none",
            },
        },
    }

    local sellBtnLabel = UI.Label {
        text = "出售物品", fontSize = sz(9),
        fontColor = { 255, 180, 180, 220 },
        pointerEvents = "none",
    }
    ctx.sellModeBtn = UI.Panel {
        width = "100%", height = sz(22),
        borderRadius = 0,
        backgroundColor = { 52, 56, 68, 180 },
        justifyContent = "center", alignItems = "center",
        marginTop = sz(3),
        onClick = function()
            Utils.PlayClick()
            SellMode.Toggle(ctx)
        end,
        children = { sellBtnLabel },
    }
    ctx.sellModeBtn._label = sellBtnLabel

    local sidebarScroll = UI.ScrollView {
        width = "100%",
        flexGrow = 1,
        flexShrink = 1,
        flexBasis = 0,
        showScrollbar = false,
        children = {
            UI.Panel {
                width = "100%",
                flexDirection = "column",
                alignItems = "center",
                gap = sz(8),
                children = {
                    qualitySection,
                    categorySection,
                    clearBtn,
                    organizeBtn,
                    ctx.sellModeBtn,
                },
            },
        },
    }

    local sidebar = UI.Panel {
        width = sz(80),
        height = "100%",
        flexDirection = "column",
        alignItems = "center",
        padding = { sz(8), sz(6) },
        paddingBottom = sz(6),
        backgroundColor = { 26, 29, 36, 255 },
        flexShrink = 0,
        gap = sz(6),
        children = {
            sidebarScroll,
            backBtn,
        },
    }

    -- ── 空状态 ──────────────────────────────────────
    ctx.emptyPanel = UI.Panel {
        position = "absolute",
        left = 0, top = 0, right = 0, bottom = 0,
        justifyContent = "center",
        alignItems = "center",
        gap = 10,
        visible = false,
        backgroundColor = { 22, 25, 32, 255 },
        children = {
            UI.Label { text = "仓库空空如也", fontSize = 18, fontColor = { 160, 165, 180, 200 } },
            UI.Label { text = "赢得竞拍即可获得物品", fontSize = 13, fontColor = { 120, 125, 140, 150 } },
        },
    }

    -- ── 底部出售操作栏 ────────────────────────────────
    ctx.sellCountLabel = UI.Label { text = "已选 0 件", fontSize = 12, fontColor = { 200, 205, 220, 255 } }
    ctx.sellValueLabel = UI.Label { text = "0", fontSize = 13, fontColor = { 255, 220, 100, 255 }, fontWeight = "bold" }

    local sellConfirmBtn = UI.Panel {
        paddingHorizontal = 14,
        paddingVertical = 5,
        borderRadius = 0,
        backgroundColor = { 180, 50, 50, 230 },
        borderWidth = 1,
        borderColor = { 220, 80, 80, 200 },
        justifyContent = "center", alignItems = "center",
        onClick = function()
            Utils.PlayClick()
            SellMode.ShowConfirm(ctx)
        end,
        children = {
            UI.Label { text = "出售", fontSize = 12, fontColor = { 255, 255, 255, 255 }, fontWeight = "bold", pointerEvents = "none" },
        },
    }
    ctx.sellBar = UI.Panel {
        width = "100%",
        height = 36,
        flexShrink = 0,
        backgroundColor = { 30, 33, 42, 250 },
        borderWidth = { top = 1 },
        borderColor = { 180, 80, 80, 150 },
        flexDirection = "row",
        alignItems = "center",
        paddingHorizontal = 10,
        gap = 8,
        visible = false,
        children = {
            ctx.sellCountLabel,
            UI.Panel { flexGrow = 1 },
            UI.Panel { width = 12, height = 12, backgroundImage = Utils.GetIcon("coin"), backgroundFit = "contain" },
            ctx.sellValueLabel,
            UI.Panel { width = 8 },
            sellConfirmBtn,
        },
    }

    -- ── 内容区域 ───────────────────────────────────
    local contentArea = UI.Panel {
        flexGrow = 1,
        flexShrink = 1,
        flexBasis = 0,
        flexDirection = "column",
        backgroundColor = { 22, 25, 32, 255 },
        children = {
            ctx.emptyPanel,
            UI.ScrollView {
                width = "100%",
                flexGrow = 1,
                flexBasis = 0,
                scrollY = true,
                scrollbarInteractive = false,
                children = { ctx.gridContainer },
            },
            ctx.sellBar,
        },
    }

    -- ── 主体 ────────────────────────────────────────
    local body = UI.Panel {
        width = "100%",
        flexGrow = 1,
        flexBasis = 0,
        flexDirection = "row",
        overflow = "hidden",
        children = {
            sidebar,
            UI.Panel { width = 1, backgroundColor = { 50, 55, 68, 200 } },
            contentArea,
        },
    }

    -- ── 物品详情：全屏透明 backdrop + 浮窗实例 ─────────
    local detailBackdrop = UI.Panel {
        position = "absolute",
        left = 0, top = 0, right = 0, bottom = 0,
        backgroundColor = { 0, 0, 0, 1 },
        visible = false,
        onClick = function(self, event)
            local lx, ly = event.x, event.y
            local item = SellMode.HitTestItemAtScreenPos(ctx, lx, ly)
            if item then
                Panel._ShowItemInfo(item)
            else
                if ctx.detailInst then ctx.detailInst:Hide() end
            end
        end,
    }

    ctx.detailInst = ItemDetailPanel.New({
        position = "absolute",
        left = 0,
        top = 0,
        right = nil,
        onShow = function()
            detailBackdrop:SetVisible(true)
        end,
        onHide = function()
            detailBackdrop:SetVisible(false)
        end,
    })
    ctx.detailPanel = ctx.detailInst:GetWidget()
    detailBackdrop:SetVisible(false)

    -- ── 全屏根 ──────────────────────────────────────
    local root = UI.Panel {
        width = "100%", height = "100%",
        backgroundColor = { 18, 18, 22, 255 },
        flexDirection = "column",
        children = {
            topBar,
            UI.Panel { width = "100%", height = 1, backgroundColor = { 50, 55, 68, 200 }, borderRadius = 0 },
            body,
            detailBackdrop,
            ctx.detailPanel,
        },
    }

    ctx.refs_root = root
    local wrapper = UI.Panel {
        width = "100%", height = "100%",
        children = { root, MoneyHUD.CreatePopup() },
    }
    UI.SetRoot(UI.SafeAreaView {
        edges = "all", width = "100%", height = "100%",
        children = { wrapper },
    })

    UpgradePanel.UpdateLevelDisplay(ctx)
    refreshCards()

    print("[MyWarehousePanel] Show grid layout. Items: " .. #ctx.allItems)
end

return Panel
