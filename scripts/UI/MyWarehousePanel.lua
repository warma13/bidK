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
local WarehouseGrid = require("WarehouseGrid")
local RecycleManager = require("RecycleManager")
local ImageCache = require("urhox-libs/UI/Core/ImageCache")

local Panel = {}

-- 内部引用

local levelLabel = nil
local capacityLabel = nil
local upgradeBtn = nil
local upgradePopup = nil
local emptyPanel = nil

-- 格子系统
local COLS = 10
local gridSlots = {}       -- slotIdx → UI.Panel
local gridContainer = nil  -- 格子网格容器
local itemImages = {}       -- 图片叠加层面板池
local imageToItem = {}      -- 图片面板 idx → item
local MAX_ITEM_IMAGES = 120
local gridInst = nil        -- WarehouseGrid 实例
local gridMap = nil         -- gridMap[r][c] = item 或 nil

-- 物品信息浮层
local infoOverlay = nil
local infoNameLabel = nil
local infoPriceLabel = nil
local infoCoinIcon = nil

-- 筛选状态
local activeFilters = {
    rarity = nil,
    category = nil,
}
local rarityBtns = {}
local categoryBtns = {}

-- 数据
local allItems = {}

-- 根节点引用（用于添加弹窗）
local refs_root = nil

-- 返回主菜单回调
local onBackCallback = nil

-- 出售模式
local isSellMode = false
local selectedItems = {}      -- item ref → true
local checkboxes = {}         -- 勾选框面板池
local sellBar = nil           -- 底部出售操作栏
local sellCountLabel = nil
local sellValueLabel = nil
local sellModeBtn = nil
local sellConfirmPopup = nil

-- 勾选框面板池
local MAX_CHECKBOXES = 120
local checkboxPanels = {}     -- idx → UI.Panel（绝对定位的勾选框）
local checkboxToItem = {}     -- idx → item

-- 前向声明
local refreshCards
local updateLevelDisplay
local refreshGridDisplay

-- ============================================================================
-- 出售模式逻辑
-- ============================================================================

local function getSelectedList()
    local list = {}
    for item, _ in pairs(selectedItems) do
        list[#list + 1] = item
    end
    return list
end

local function getSelectedCount()
    local n = 0
    for _ in pairs(selectedItems) do n = n + 1 end
    return n
end

local function getSelectedTotalValue()
    local total = 0
    for item, _ in pairs(selectedItems) do
        total = total + RecycleManager.GetRecycleValue(item)
    end
    return total
end

local function updateSellBar()
    if not sellBar then return end
    local count = getSelectedCount()
    local value = getSelectedTotalValue()
    if sellCountLabel then
        sellCountLabel:SetText("已选 " .. count .. " 件")
    end
    if sellValueLabel then
        sellValueLabel:SetText(Utils.FormatMoney(value))
    end
end

local function updateCheckboxVisuals()
    for i = 1, MAX_CHECKBOXES do
        local cb = checkboxPanels[i]
        if cb and cb:IsVisible() then
            local item = checkboxToItem[i]
            if item and selectedItems[item] then
                cb:SetStyle({
                    backgroundColor = { 50, 180, 80, 230 },
                    borderColor = { 80, 220, 120, 255 },
                })
                -- 更新勾选标记
                if cb._checkLabel then
                    cb._checkLabel:SetText("✓")
                end
            else
                cb:SetStyle({
                    backgroundColor = { 0, 0, 0, 120 },
                    borderColor = { 150, 160, 180, 180 },
                })
                if cb._checkLabel then
                    cb._checkLabel:SetText("")
                end
            end
        end
    end
end

local function toggleItemSelection(item)
    if not item then return end
    if selectedItems[item] then
        selectedItems[item] = nil
    else
        selectedItems[item] = true
    end
    updateCheckboxVisuals()
    updateSellBar()
end

local function exitSellMode()
    isSellMode = false
    selectedItems = {}
    if sellBar then sellBar:SetVisible(false) end
    if sellModeBtn then
        sellModeBtn:SetStyle({
            backgroundColor = { 52, 56, 68, 180 },
        })
        if sellModeBtn._label then
            sellModeBtn._label:SetText("出售物品")
        end
    end
    -- 隐藏所有勾选框
    for i = 1, MAX_CHECKBOXES do
        if checkboxPanels[i] then
            checkboxPanels[i]:SetVisible(false)
        end
    end
    -- 恢复信息浮层
    if infoOverlay then infoOverlay:SetVisible(false) end
end

local function hideSellConfirm()
    if sellConfirmPopup then
        sellConfirmPopup:SetVisible(false)
        sellConfirmPopup:Remove()
        sellConfirmPopup = nil
    end
end

local function doSell()
    local list = getSelectedList()
    if #list == 0 then return end

    local totalValue = getSelectedTotalValue()
    -- 增加金币
    local curMoney = MoneyHUD.GetMoney()
    MoneyHUD.SetMoney(curMoney + totalValue)
    -- 从存档移除
    SaveSystem.RemoveItems(list)

    -- 刷新数据
    allItems = SaveSystem.GetItems()
    table.sort(allItems, function(a, b)
        return (a.wonAt or 0) > (b.wonAt or 0)
    end)

    hideSellConfirm()
    exitSellMode()
    updateLevelDisplay()
    refreshCards()
    Utils.ShowMessage("出售成功！获得 " .. Utils.FormatMoney(totalValue) .. " 金币")
end

local function showSellConfirm()
    local count = getSelectedCount()
    if count == 0 then
        Utils.ShowMessage("请先选择要出售的物品")
        return
    end
    local totalValue = getSelectedTotalValue()

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
            doSell()
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
            hideSellConfirm()
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
                    UI.Label {
                        text = "可获得",
                        fontSize = 13,
                        fontColor = { 180, 185, 200, 220 },
                    },
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
            UI.Panel {
                width = "100%", height = 1,
                backgroundColor = { 60, 65, 80, 200 },
            },
            UI.Panel {
                width = "100%",
                flexDirection = "row",
                justifyContent = "center",
                gap = 12,
                children = { cancelBtn, confirmBtn },
            },
        },
    }

    hideSellConfirm()

    sellConfirmPopup = UI.Panel {
        position = "absolute",
        left = 0, top = 0, right = 0, bottom = 0,
        backgroundColor = { 0, 0, 0, 160 },
        justifyContent = "center",
        alignItems = "center",
        visible = true,
        onClick = function()
            Utils.PlayClick()
            hideSellConfirm()
        end,
        children = {
            UI.Panel {
                onClick = function() end,
                children = { card },
            },
        },
    }

    if refs_root then
        refs_root:AddChild(sellConfirmPopup)
    end
end

local function enterSellMode()
    isSellMode = true
    selectedItems = {}
    if sellBar then sellBar:SetVisible(true) end
    if sellModeBtn then
        sellModeBtn:SetStyle({
            backgroundColor = { 140, 60, 60, 220 },
        })
        if sellModeBtn._label then
            sellModeBtn._label:SetText("取消出售")
        end
    end
    updateSellBar()
    -- 刷新显示勾选框
    Panel._needPositionUpdate()
    refreshGridDisplay()
end

local function toggleSellMode()
    if isSellMode then
        exitSellMode()
        refreshGridDisplay()
    else
        enterSellMode()
    end
end

-- ============================================================================
-- 工具函数
-- ============================================================================

local function applyFilters(items)
    local result = {}
    for _, item in ipairs(items) do
        local pass = true
        if activeFilters.rarity and item.rarity ~= activeFilters.rarity then
            pass = false
        end
        if activeFilters.category and item.category ~= activeFilters.category then
            pass = false
        end
        if pass then result[#result + 1] = item end
    end
    return result
end

local function updateFilterStyles()
    for id, btn in pairs(rarityBtns) do
        if id == activeFilters.rarity then
            btn:SetStyle({ borderColor = { 255, 255, 255, 200 }, borderWidth = 2 })
        else
            btn:SetStyle({ borderColor = { 70, 75, 88, 120 }, borderWidth = 1 })
        end
    end
    for id, btn in pairs(categoryBtns) do
        if id == activeFilters.category then
            btn:SetStyle({
                backgroundColor = { 75, 85, 115, 220 },
                borderColor = { 140, 155, 185, 220 },
            })
        else
            btn:SetStyle({
                backgroundColor = { 42, 47, 58, 180 },
                borderColor = { 65, 72, 85, 120 },
            })
        end
    end
end

-- ============================================================================
-- 格子系统：构建网格 + 放置物品
-- ============================================================================

--- 根据筛选后的物品列表构建网格显示
local function buildGrid(filteredItems)
    -- 创建 WarehouseGrid 实例（用于放置计算）
    local capacity = SaveSystem.GetWarehouseCapacity()
    -- 如果筛选后物品少，也至少要显示足够的行
    local totalCells = capacity
    gridInst = WarehouseGrid.Create(totalCells)

    -- 按物品已有的 gridX/gridY 优先放置，否则自动放置
    WarehouseGrid.Rebuild(gridInst, filteredItems)

    -- 构建网格映射 gridMap[r][c] = item
    local rows = gridInst.rows
    gridMap = {}
    for r = 1, rows do
        gridMap[r] = {}
        for c = 1, COLS do
            gridMap[r][c] = nil
        end
    end

    for _, item in ipairs(gridInst.items) do
        local gx = item.gridX
        local gy = item.gridY
        local w = item.w or 1
        local h = item.h or 1
        if gx and gy then
            for r = gy, gy + h - 1 do
                for c = gx, gx + w - 1 do
                    if gridMap[r] then
                        gridMap[r][c] = item
                    end
                end
            end
        end
    end

    return rows
end

--- 刷新格子显示（样式 + 图片）
refreshGridDisplay = function()
    if not gridInst or not gridMap then return end
    local rows = gridInst.rows

    -- 重置所有格子外观
    for slotIdx, slot in pairs(gridSlots) do
        local r = math.ceil(slotIdx / COLS)
        local c = slotIdx - (r - 1) * COLS
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
    imageToItem = {}
    for i = 1, MAX_ITEM_IMAGES do
        if itemImages[i] then
            itemImages[i]:SetVisible(false)
            itemImages[i]._imagePath = nil
            itemImages[i]._originSlot = nil
            itemImages[i]._endSlot = nil
        end
    end

    -- 设置有物品的格子样式
    local imgIdx = 0
    local processedItems = {} -- 避免重复处理同一物品

    for r = 1, rows do
        for c = 1, COLS do
            local slotIdx = (r - 1) * COLS + c
            local slot = gridSlots[slotIdx]
            if not slot then goto nextCell end

            local item = gridMap[r] and gridMap[r][c]
            if not item then goto nextCell end

            local rar = Config.GetRarity(item.rarity)
            local w = item.w or 1
            local h = item.h or 1
            local isOrigin = (item.gridX == c and item.gridY == r)

            -- 计算外轮廓边框（隐藏物品内部共享边）
            local bTop = (r == item.gridY) and 1 or 0
            local bBottom = (r == item.gridY + h - 1) and 1 or 0
            local bLeft = (c == item.gridX) and 1 or 0
            local bRight = (c == item.gridX + w - 1) and 1 or 0

            slot:SetStyle({
                borderColor = rar.color,
                borderWidth = { top = bTop * 2, right = bRight * 2, bottom = bBottom * 2, left = bLeft * 2 },
                backgroundColor = { rar.color[1], rar.color[2], rar.color[3], 30 },
            })

            -- 原点格子放置图片
            if isOrigin and not processedItems[item] then
                processedItems[item] = true
                if item.image and item.image ~= "" then
                    imgIdx = imgIdx + 1
                    if imgIdx <= MAX_ITEM_IMAGES then
                        local endSlotIdx = (item.gridY + h - 2) * COLS + (item.gridX + w - 1)
                        local originSlot = gridSlots[slotIdx]
                        local endSlot = gridSlots[endSlotIdx]
                        if originSlot and endSlot then
                            imageToItem[imgIdx] = item
                            itemImages[imgIdx]._imagePath = item.image
                            itemImages[imgIdx]._originSlot = originSlot
                            itemImages[imgIdx]._endSlot = endSlot
                            itemImages[imgIdx]:SetVisible(true)
                        end
                    end
                end
            end

            ::nextCell::
        end
    end

    -- 重置勾选框
    checkboxToItem = {}
    for i = 1, MAX_CHECKBOXES do
        if checkboxPanels[i] then
            checkboxPanels[i]:SetVisible(false)
        end
    end

    -- 出售模式时显示勾选框
    if isSellMode then
        local cbIdx = 0
        local processedCb = {}
        for r = 1, rows do
            for c = 1, COLS do
                local item = gridMap[r] and gridMap[r][c]
                if item and not processedCb[item] then
                    local isOrigin = (item.gridX == c and item.gridY == r)
                    if isOrigin then
                        processedCb[item] = true
                        cbIdx = cbIdx + 1
                        if cbIdx <= MAX_CHECKBOXES and checkboxPanels[cbIdx] then
                            checkboxToItem[cbIdx] = item
                            checkboxPanels[cbIdx]:SetVisible(true)
                        end
                    end
                end
            end
        end
        updateCheckboxVisuals()
    end
end

--- 更新图片面板和勾选框的位置（基于 slot 布局）
local function _updateImagePositions()
    local gridLayout = gridContainer and gridContainer:GetAbsoluteLayout() or nil
    if not gridLayout then return end

    for i = 1, MAX_ITEM_IMAGES do
        local img = itemImages[i]
        if not img or not img:IsVisible() then goto nextImg end
        local oSlot = img._originSlot
        local eSlot = img._endSlot
        if not oSlot or not eSlot then goto nextImg end

        local oL = oSlot:GetAbsoluteLayout()
        local eL = eSlot:GetAbsoluteLayout()
        local pad = 2
        local imgX = oL.x - gridLayout.x
        local imgY = oL.y - gridLayout.y
        local imgW = eL.x + eL.w - oL.x
        local imgH = eL.y + eL.h - oL.y
        img:SetStyle({
            left = imgX + pad,
            top = imgY + pad,
            width = imgW - pad * 2,
            height = imgH - pad * 2,
        })
        ::nextImg::
    end

    -- 更新勾选框位置（右上角）
    if isSellMode then
        for i = 1, MAX_CHECKBOXES do
            local cb = checkboxPanels[i]
            if cb and cb:IsVisible() then
                local item = checkboxToItem[i]
                if item and item.gridX and item.gridY then
                    local w = item.w or 1
                    local rightCol = item.gridX + w - 1
                    local slotIdx = (item.gridY - 1) * COLS + rightCol
                    local slot = gridSlots[slotIdx]
                    if slot then
                        local sL = slot:GetAbsoluteLayout()
                        local cbSize = 14
                        cb:SetStyle({
                            left = (sL.x - gridLayout.x) + (sL.w - cbSize) - 1,
                            top = (sL.y - gridLayout.y) + 1,
                            width = cbSize,
                            height = cbSize,
                        })
                    end
                end
            end
        end
    end
end

-- ============================================================================
-- 前向声明（已在文件顶部）
-- ============================================================================

-- ============================================================================
-- 仓库升级相关
-- ============================================================================

updateLevelDisplay = function()
    local level = SaveSystem.GetWarehouseLevel()
    local capacity = SaveSystem.GetWarehouseCapacity()
    local usedCells = 0
    for _, item in ipairs(allItems) do
        local w = item.w or 1
        local h = item.h or 1
        usedCells = usedCells + (w * h)
    end
    if levelLabel then
        levelLabel:SetText("Lv." .. level)
    end
    if capacityLabel then
        capacityLabel:SetText(usedCells .. "/" .. capacity .. " 格")
    end
    if upgradeBtn then
        upgradeBtn:SetVisible(level < WarehouseUpgrade.MAX_LEVEL)
    end
end

local function hideUpgradePopup()
    if upgradePopup then
        upgradePopup:SetVisible(false)
    end
end

local function doUpgrade()
    local gold = MoneyHUD.GetMoney()
    local success, err = SaveSystem.UpgradeWarehouse(gold, function(amount)
        MoneyHUD.SetMoney(gold - amount)
    end)
    if success then
        allItems = SaveSystem.GetItems()
        table.sort(allItems, function(a, b)
            return (a.wonAt or 0) > (b.wonAt or 0)
        end)
        updateLevelDisplay()
        refreshCards()
        hideUpgradePopup()
        Utils.ShowMessage("升级成功！仓库已扩容至 " .. SaveSystem.GetWarehouseCapacity() .. " 格")
    end
end

local function showUpgradePopup()
    local level = SaveSystem.GetWarehouseLevel()
    if level >= WarehouseUpgrade.MAX_LEVEL then return end

    local gold = MoneyHUD.GetMoney()
    local canUpgrade, details = WarehouseUpgrade.CheckUpgrade(level, allItems, gold)
    local cost = WarehouseUpgrade.GetUpgradeCost(level)
    if not cost or not details then return end

    local nextCapacity = WarehouseUpgrade.GetCapacity(level + 1)

    local contentChildren = {}

    contentChildren[#contentChildren + 1] = UI.Label {
        text = "仓库升级 Lv." .. level .. " → Lv." .. (level + 1),
        fontSize = 16,
        fontColor = { 255, 220, 100, 255 },
        fontWeight = "bold",
        textAlign = "center",
        width = "100%",
    }

    contentChildren[#contentChildren + 1] = UI.Label {
        text = "容量: " .. WarehouseUpgrade.GetCapacity(level) .. " → " .. nextCapacity .. " 格 (+" .. (nextCapacity - WarehouseUpgrade.GetCapacity(level)) .. ")",
        fontSize = 12,
        fontColor = { 180, 190, 210, 220 },
        textAlign = "center",
        width = "100%",
        marginBottom = 8,
    }

    contentChildren[#contentChildren + 1] = UI.Panel {
        width = "100%", height = 1,
        backgroundColor = { 60, 65, 80, 200 },
        marginBottom = 8,
    }

    contentChildren[#contentChildren + 1] = UI.Label {
        text = "需要消耗",
        fontSize = 13,
        fontColor = { 160, 168, 185, 220 },
        width = "100%",
        marginBottom = 6,
    }

    for _, req in ipairs(details.items) do
        local rar = Config.GetRarity(req.rarity)
        local statusColor = req.ok
            and { 100, 220, 120, 255 }
            or  { 255, 80, 80, 255 }
        local statusText = req.have .. "/" .. req.need

        contentChildren[#contentChildren + 1] = UI.Panel {
            width = "100%",
            flexDirection = "row",
            alignItems = "center",
            gap = 6,
            paddingVertical = 3,
            children = {
                UI.Label {
                    text = "◆",
                    fontSize = 12,
                    fontColor = rar.color,
                },
                UI.Label {
                    text = req.name,
                    fontSize = 12,
                    fontColor = { 210, 215, 225, 255 },
                    flexGrow = 1,
                },
                UI.Label {
                    text = statusText,
                    fontSize = 12,
                    fontColor = statusColor,
                },
            },
        }
    end

    local goldColor = details.gold.ok
        and { 255, 220, 100, 255 }
        or  { 255, 80, 80, 255 }
    local goldStatus = Utils.FormatMoney(details.gold.have) .. "/" .. Utils.FormatMoney(details.gold.need)

    contentChildren[#contentChildren + 1] = UI.Panel {
        width = "100%",
        flexDirection = "row",
        alignItems = "center",
        gap = 6,
        paddingVertical = 3,
        marginTop = 4,
        children = {
            UI.Panel {
                width = 12, height = 12,
                backgroundImage = Utils.GetIcon("coin"),
                backgroundFit = "contain",
            },
            UI.Label {
                text = "金币",
                fontSize = 12,
                fontColor = { 210, 215, 225, 255 },
                flexGrow = 1,
            },
            UI.Label {
                text = goldStatus,
                fontSize = 12,
                fontColor = goldColor,
            },
        },
    }

    contentChildren[#contentChildren + 1] = UI.Panel {
        width = "100%", height = 1,
        backgroundColor = { 60, 65, 80, 200 },
        marginTop = 10,
        marginBottom = 10,
    }

    local confirmBtn = UI.Button {
        text = canUpgrade and "确认升级" or "材料不足",
        width = 120, height = 34,
        fontSize = 13,
        fontWeight = "bold",
        backgroundColor = canUpgrade
            and { 50, 140, 80, 240 }
            or  { 80, 80, 80, 200 },
        fontColor = canUpgrade
            and { 255, 255, 255, 255 }
            or  { 120, 120, 120, 200 },
        borderRadius = 0,
        borderWidth = 1,
        borderColor = canUpgrade
            and { 80, 200, 120, 200 }
            or  { 100, 100, 100, 150 },
        onClick = function()
            if canUpgrade then
                Utils.PlayClick()
                doUpgrade()
            end
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
            hideUpgradePopup()
        end,
    }

    contentChildren[#contentChildren + 1] = UI.Panel {
        width = "100%",
        flexDirection = "row",
        justifyContent = "center",
        gap = 12,
        children = { cancelBtn, confirmBtn },
    }

    local card = UI.Panel {
        width = 320,
        backgroundColor = { 30, 34, 44, 250 },
        borderRadius = 0,
        borderWidth = 1,
        borderColor = { 90, 100, 130, 200 },
        padding = { 20, 16 },
        flexDirection = "column",
        gap = 4,
        children = contentChildren,
    }

    if upgradePopup then
        upgradePopup:SetVisible(false)
        upgradePopup:Remove()
    end

    upgradePopup = UI.Panel {
        position = "absolute",
        left = 0, top = 0, right = 0, bottom = 0,
        backgroundColor = { 0, 0, 0, 160 },
        justifyContent = "center",
        alignItems = "center",
        visible = true,
        onClick = function()
            Utils.PlayClick()
            hideUpgradePopup()
        end,
        children = {
            UI.Panel {
                onClick = function() end,
                children = { card },
            },
        },
    }

    return upgradePopup
end

-- ============================================================================
-- 刷新网格显示
-- ============================================================================

refreshCards = function()
    local filtered = applyFilters(allItems)
    if #filtered == 0 then
        if gridContainer then gridContainer:SetVisible(false) end
        emptyPanel:SetVisible(true)
        -- 隐藏信息浮层
        if infoOverlay then infoOverlay:SetVisible(false) end
    else
        emptyPanel:SetVisible(false)
        if gridContainer then gridContainer:SetVisible(true) end

        -- 构建网格数据
        buildGrid(filtered)
        -- 刷新格子显示
        refreshGridDisplay()
    end
end



-- ============================================================================
-- 显示（全屏页面）
-- ============================================================================

function Panel.Show(onBack)
    onBackCallback = onBack
    UIState.currentScreen = "warehouse"

    -- 从 SaveSystem 加载物品（不再重新排序，保持存档中的顺序）
    allItems = SaveSystem.GetItems()

    -- 重置筛选
    activeFilters.rarity = nil
    activeFilters.category = nil
    rarityBtns = {}
    categoryBtns = {}

    -- 重置出售模式
    isSellMode = false
    selectedItems = {}
    checkboxPanels = {}
    checkboxToItem = {}
    sellBar = nil
    sellCountLabel = nil
    sellValueLabel = nil
    sellModeBtn = nil
    sellConfirmPopup = nil

    -- ── 创建格子网格 ────────────────────────────────
    local capacity = SaveSystem.GetWarehouseCapacity()
    local totalRows = math.ceil(capacity / COLS)

    gridSlots = {}
    local gridRowWidgets = {}
    for r = 1, totalRows do
        local rowChildren = {}
        for c = 1, COLS do
            local slotIdx = (r - 1) * COLS + c
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
                    Utils.PlayClick()
                    Panel._OnSlotClick(slotIdx)
                end,
            }
            gridSlots[slotIdx] = slot
            rowChildren[c] = slot
        end
        gridRowWidgets[r] = UI.Panel {
            width = "100%",
            flexDirection = "row",
            children = rowChildren,
        }
    end

    -- 图片叠加面板池
    itemImages = {}
    local itemImageWidgets = {}
    for i = 1, MAX_ITEM_IMAGES do
        local idx = i
        local imgPanel = UI.Panel {
            position = "absolute",
            width = 32, height = 32,
            visible = false,
            onClick = function()
                Utils.PlayClick()
                local item = imageToItem[idx]
                if item then
                    if isSellMode then
                        toggleItemSelection(item)
                    else
                        Panel._ShowItemInfo(item)
                    end
                end
            end,
        }
        imgPanel._imagePath = nil
        imgPanel._originSlot = nil
        imgPanel._endSlot = nil

        -- NanoVG 自定义渲染图片（与 LootPanel 相同模式）
        function imgPanel:Render(nvg)
            local imgPath = self._imagePath
            local oSlot = self._originSlot
            local eSlot = self._endSlot
            if not imgPath or not oSlot or not eSlot then return end

            local oL = oSlot:GetAbsoluteLayout()
            local eL = eSlot:GetAbsoluteLayout()
            -- 整个多格区域（无内缩），用于画品质色底色覆盖 slot 间缝隙
            local fullX = oL.x
            local fullY = oL.y
            local fullW = eL.x + eL.w - oL.x
            local fullH = eL.y + eL.h - oL.y
            if fullW <= 0 or fullH <= 0 then return end

            -- 画品质色底色矩形（覆盖整个多格区域，盖住 slot 间的亚像素缝隙）
            local item = imageToItem[idx]
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

            -- contain 缩放
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

        itemImages[i] = imgPanel
        itemImageWidgets[#itemImageWidgets + 1] = imgPanel
    end

    -- 勾选框面板池
    checkboxPanels = {}
    checkboxToItem = {}
    local checkboxWidgets = {}
    for i = 1, MAX_CHECKBOXES do
        local cbIdx = i
        local checkLabel = UI.Label {
            text = "",
            fontSize = 10,
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
                local item = checkboxToItem[cbIdx]
                if item then
                    toggleItemSelection(item)
                end
            end,
            children = { checkLabel },
        }
        cbPanel._checkLabel = checkLabel
        checkboxPanels[i] = cbPanel
        checkboxWidgets[#checkboxWidgets + 1] = cbPanel
    end

    -- 信息浮层（点击物品时在底部显示物品名+价格）
    infoNameLabel = UI.Label {
        text = "",
        fontSize = 11,
        fontColor = { 220, 225, 235, 255 },
        maxLines = 1,
        pointerEvents = "none",
    }
    infoCoinIcon = UI.Panel {
        width = 10, height = 10,
        backgroundImage = Utils.GetIcon("coin"),
        backgroundFit = "contain",
        pointerEvents = "none",
    }
    infoPriceLabel = UI.Label {
        text = "",
        fontSize = 10,
        fontColor = { 255, 220, 100, 255 },
        pointerEvents = "none",
    }

    local infoDateLabel = UI.Label {
        text = "",
        fontSize = 8,
        fontColor = { 120, 125, 140, 160 },
        pointerEvents = "none",
    }

    -- 将 infoDateLabel 保存供后续使用
    Panel._infoDateLabel = infoDateLabel

    infoOverlay = UI.Panel {
        position = "absolute",
        left = 0, bottom = 0, right = 0,
        height = 28,
        backgroundColor = { 20, 24, 32, 230 },
        borderWidth = { top = 1 },
        borderColor = { 80, 130, 170, 80 },
        flexDirection = "row",
        alignItems = "center",
        justifyContent = "center",
        gap = 6,
        paddingHorizontal = 8,
        visible = false,
        pointerEvents = "none",
        children = {
            infoNameLabel,
            UI.Panel { width = 1, height = 14, backgroundColor = { 80, 85, 100, 120 }, pointerEvents = "none" },
            infoCoinIcon,
            infoPriceLabel,
            infoDateLabel,
        },
    }

    -- 组合格子 + 图片层 + 信息浮层
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
    gridChildren[#gridChildren + 1] = infoOverlay

    gridContainer = UI.Panel {
        id = "warehouseGridContainer",
        width = "100%",
        flexDirection = "column",
        paddingRight = 8,
        borderWidth = { left = 1, top = 1 },
        borderColor = { 80, 130, 170, 60 },
        children = gridChildren,
    }

    -- gridContainer 的 Render：更新图片位置
    local needPositionUpdate = true
    function gridContainer:Render(nvg)
        self:RenderFullBackground(nvg)
        if needPositionUpdate then
            needPositionUpdate = false
            _updateImagePositions()
        end
    end

    -- 给 gridContainer 注册 PostLayout 来刷新图片位置
    Panel._needPositionUpdate = function()
        needPositionUpdate = true
    end

    -- ── 顶部栏 ──────────────────────────────────────
    local backBtn = UI.Button {
        text = "< 返回",
        width = 80, height = 32,
        fontSize = 13,
        backgroundColor = { 40, 44, 55, 220 },
        fontColor = { 190, 195, 210, 255 },
        borderWidth = 1,
        borderColor = { 80, 85, 100, 160 },
        borderRadius = 0,
        onClick = function()
            Utils.PlayClick()
            if onBackCallback then onBackCallback() end
        end,
    }

    local titleLabel = UI.Label {
        text = "我的仓库", fontSize = 18,
        fontColor = { 225, 228, 235, 255 },
        fontWeight = "bold",
    }

    levelLabel = UI.Label {
        text = "Lv.1", fontSize = 14,
        fontColor = { 255, 220, 100, 255 },
        fontWeight = "bold",
    }

    capacityLabel = UI.Label {
        text = "0/28", fontSize = 12,
        fontColor = { 160, 170, 190, 220 },
    }

    upgradeBtn = UI.Panel {
        height = 26,
        paddingHorizontal = 10,
        borderRadius = 0,
        backgroundColor = { 50, 110, 70, 220 },
        borderWidth = 1,
        borderColor = { 80, 180, 110, 200 },
        justifyContent = "center", alignItems = "center",
        onClick = function()
            Utils.PlayClick()
            local popup = showUpgradePopup()
            if popup and refs_root then
                refs_root:AddChild(popup)
            end
        end,
        children = {
            UI.Label {
                text = "升级仓库 ↑", fontSize = 11,
                fontColor = { 220, 255, 230, 255 },
                fontWeight = "bold",
                pointerEvents = "none",
            },
        },
    }

    local topBar = UI.Panel {
        width = "100%",
        height = 44,
        backgroundColor = { 30, 33, 40, 255 },
        flexDirection = "row",
        alignItems = "center",
        paddingHorizontal = 12,
        gap = 12,
        children = {
            backBtn,
            titleLabel,
            levelLabel,
            UI.Panel { width = 1, height = 20, backgroundColor = { 60, 65, 80, 150 } },
            capacityLabel,
            upgradeBtn,
            UI.Panel { flexGrow = 1 },
            MoneyHUD.CreatePanel(),
        },
    }

    -- ── 左侧筛选栏 ─────────────────────────────────
    local qualityChildren = {}
    for _, rar in ipairs(Config.RARITY) do
        local btn = UI.Panel {
            width = 30, height = 30,
            borderRadius = 0,
            borderWidth = 1,
            borderColor = { 70, 75, 88, 120 },
            backgroundColor = { rar.color[1], rar.color[2], rar.color[3], 35 },
            justifyContent = "center", alignItems = "center",
            onClick = function()
                Utils.PlayClick()
                if activeFilters.rarity == rar.id then
                    activeFilters.rarity = nil
                else
                    activeFilters.rarity = rar.id
                end
                updateFilterStyles()
                refreshCards()
            end,
            children = {
                UI.Label {
                    text = "\u{25C6}", fontSize = 14,
                    fontColor = rar.color,
                    pointerEvents = "none",
                },
            },
        }
        rarityBtns[rar.id] = btn
        qualityChildren[#qualityChildren + 1] = btn
    end

    local qualitySection = UI.Panel {
        width = "100%",
        flexDirection = "column", gap = 6,
        alignItems = "center",
        children = {
            UI.Label { text = "品质", fontSize = 11, fontColor = { 110, 118, 135, 180 } },
            UI.Panel {
                flexDirection = "row", flexWrap = "wrap", gap = 4,
                justifyContent = "center",
                children = qualityChildren,
            },
        },
    }

    local categoryChildren = {}
    for _, cat in ipairs(Config.CATEGORIES) do
        local btn = UI.Panel {
            width = "46%",
            paddingVertical = 4,
            borderRadius = 0,
            borderWidth = 1,
            borderColor = { 65, 72, 85, 120 },
            backgroundColor = { 42, 47, 58, 180 },
            justifyContent = "center", alignItems = "center",
            onClick = function()
                Utils.PlayClick()
                if activeFilters.category == cat.id then
                    activeFilters.category = nil
                else
                    activeFilters.category = cat.id
                end
                updateFilterStyles()
                refreshCards()
            end,
            children = {
                UI.Label {
                    text = cat.name, fontSize = 11,
                    fontColor = { 170, 178, 192, 220 },
                    pointerEvents = "none",
                },
            },
        }
        categoryBtns[cat.id] = btn
        categoryChildren[#categoryChildren + 1] = btn
    end

    local categorySection = UI.Panel {
        width = "100%",
        flexDirection = "column", gap = 6,
        alignItems = "center",
        children = {
            UI.Label { text = "分类", fontSize = 11, fontColor = { 110, 118, 135, 180 } },
            UI.Panel {
                width = "100%",
                flexDirection = "row", flexWrap = "wrap", gap = 4,
                justifyContent = "center",
                children = categoryChildren,
            },
        },
    }

    local clearBtn = UI.Panel {
        width = "100%", height = 28,
        borderRadius = 0,
        backgroundColor = { 52, 56, 68, 180 },
        justifyContent = "center", alignItems = "center",
        marginTop = 8,
        onClick = function()
            Utils.PlayClick()
            activeFilters.rarity = nil
            activeFilters.category = nil
            updateFilterStyles()
            refreshCards()
        end,
        children = {
            UI.Label {
                text = "清除筛选", fontSize = 11,
                fontColor = { 150, 158, 170, 200 },
                pointerEvents = "none",
            },
        },
    }

    local organizeBtn = UI.Panel {
        width = "100%", height = 28,
        borderRadius = 0,
        backgroundColor = { 52, 56, 68, 180 },
        justifyContent = "center", alignItems = "center",
        marginTop = 4,
        onClick = function()
            Utils.PlayClick()
            -- 备份原始位置（用 item 引用做 key，排序后仍能对应）
            local backup = {}
            for _, item in ipairs(allItems) do
                backup[item] = { gridX = item.gridX, gridY = item.gridY }
            end
            -- 清除所有物品的网格位置
            for _, item in ipairs(allItems) do
                item.gridX = nil
                item.gridY = nil
            end
            -- 按品质降序、面积降序排序
            local rarIdx = {}
            for i, r in ipairs(Config.RARITY) do rarIdx[r.id] = i end
            table.sort(allItems, function(a, b)
                local ra = rarIdx[a.rarity] or 0
                local rb = rarIdx[b.rarity] or 0
                if ra ~= rb then return ra > rb end
                local sa = (a.w or 1) * (a.h or 1)
                local sb = (b.w or 1) * (b.h or 1)
                return sa > sb
            end)
            refreshCards()
            -- 检查是否所有物品都放置成功
            local allPlaced = true
            for _, item in ipairs(allItems) do
                if not item.gridX or not item.gridY then
                    allPlaced = false
                    break
                end
            end
            if allPlaced then
                SaveSystem.Save()
                Utils.ShowMessage("仓库已整理")
            else
                -- 回滚：恢复原始位置
                for _, item in ipairs(allItems) do
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
                text = "整理仓库", fontSize = 11,
                fontColor = { 180, 200, 255, 220 },
                pointerEvents = "none",
            },
        },
    }

    local sellBtnLabel = UI.Label {
        text = "出售物品", fontSize = 11,
        fontColor = { 255, 180, 180, 220 },
        pointerEvents = "none",
    }
    sellModeBtn = UI.Panel {
        width = "100%", height = 28,
        borderRadius = 0,
        backgroundColor = { 52, 56, 68, 180 },
        justifyContent = "center", alignItems = "center",
        marginTop = 4,
        onClick = function()
            Utils.PlayClick()
            toggleSellMode()
        end,
        children = { sellBtnLabel },
    }
    sellModeBtn._label = sellBtnLabel

    local sidebar = UI.Panel {
        width = 110,
        flexDirection = "column",
        alignItems = "center",
        gap = 12,
        padding = { 10, 8 },
        backgroundColor = { 26, 29, 36, 255 },
        children = {
            qualitySection,
            categorySection,
            clearBtn,
            organizeBtn,
            sellModeBtn,
        },
    }

    -- ── 空状态 ──────────────────────────────────────
    emptyPanel = UI.Panel {
        position = "absolute",
        left = 0, top = 0, right = 0, bottom = 0,
        justifyContent = "center",
        alignItems = "center",
        gap = 10,
        visible = false,
        backgroundColor = { 22, 25, 32, 255 },
        children = {
            UI.Label {
                text = "仓库空空如也",
                fontSize = 18,
                fontColor = { 160, 165, 180, 200 },
            },
            UI.Label {
                text = "赢得竞拍即可获得物品",
                fontSize = 13,
                fontColor = { 120, 125, 140, 150 },
            },
        },
    }

    -- ── 底部出售操作栏 ────────────────────────────────
    sellCountLabel = UI.Label {
        text = "已选 0 件",
        fontSize = 12,
        fontColor = { 200, 205, 220, 255 },
    }
    local sellValueCoinIcon = UI.Panel {
        width = 12, height = 12,
        backgroundImage = Utils.GetIcon("coin"),
        backgroundFit = "contain",
    }
    sellValueLabel = UI.Label {
        text = "0",
        fontSize = 13,
        fontColor = { 255, 220, 100, 255 },
        fontWeight = "bold",
    }
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
            showSellConfirm()
        end,
        children = {
            UI.Label {
                text = "出售",
                fontSize = 12,
                fontColor = { 255, 255, 255, 255 },
                fontWeight = "bold",
                pointerEvents = "none",
            },
        },
    }
    sellBar = UI.Panel {
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
            sellCountLabel,
            UI.Panel { flexGrow = 1 },
            sellValueCoinIcon,
            sellValueLabel,
            UI.Panel { width = 8 },
            sellConfirmBtn,
        },
    }

    -- ── 内容区域 ────────────────────────────────────
    local contentArea = UI.Panel {
        width = "30%",
        flexShrink = 0,
        flexDirection = "column",
        backgroundColor = { 22, 25, 32, 255 },
        children = {
            emptyPanel,
            UI.ScrollView {
                width = "100%",
                flexGrow = 1,
                flexBasis = 0,
                scrollY = true,
                scrollbarInteractive = false,
                children = { gridContainer },
            },
            sellBar,
        },
    }

    -- ── 左侧区域（侧栏 + 空白） ────────────────────
    local leftArea = UI.Panel {
        flexGrow = 1,
        flexShrink = 1,
        flexBasis = 0,
        flexDirection = "row",
        backgroundColor = { 22, 25, 32, 255 },
        children = {
            sidebar,
            UI.Panel { flexGrow = 1 }, -- 留空
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
            leftArea,
            UI.Panel { width = 1, backgroundColor = { 50, 55, 68, 200 } },
            contentArea,
        },
    }

    -- ── 全屏根 ──────────────────────────────────────
    local root = UI.Panel {
        width = "100%", height = "100%",
        backgroundColor = { 18, 18, 22, 255 },
        flexDirection = "column",
        children = {
            topBar,
            UI.Panel { width = "100%", height = 1, backgroundColor = { 50, 55, 68, 200 }, borderRadius = 0 },
            body,
        },
    }

    refs_root = root
    UI.SetRoot(root)

    updateLevelDisplay()
    refreshCards()

    print("[MyWarehousePanel] Show grid layout. Items: " .. #allItems)
end

-- ============================================================================
-- 格子点击 → 显示物品信息
-- ============================================================================

function Panel._OnSlotClick(slotIdx)
    if not gridMap then return end
    local r = math.ceil(slotIdx / COLS)
    local c = slotIdx - (r - 1) * COLS
    local item = gridMap[r] and gridMap[r][c]
    if item then
        if isSellMode then
            toggleItemSelection(item)
        else
            Panel._ShowItemInfo(item)
        end
    else
        -- 点空格子隐藏信息
        if not isSellMode and infoOverlay then infoOverlay:SetVisible(false) end
    end
end

function Panel._ShowItemInfo(item)
    if not infoOverlay or not item then return end

    local rar = Config.GetRarity(item.rarity)
    infoNameLabel:SetText(item.name or "")
    infoNameLabel:SetStyle({ fontColor = rar.color })
    infoPriceLabel:SetText(Utils.FormatMoney(item.baseValue or 0))

    if item.wonAt and item.wonAt > 0 then
        local dateStr = os.date("%m/%d", item.wonAt)
        Panel._infoDateLabel:SetText(dateStr)
        Panel._infoDateLabel:SetVisible(true)
    else
        Panel._infoDateLabel:SetVisible(false)
    end

    infoOverlay:SetVisible(true)
end

return Panel
