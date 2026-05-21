-- ============================================================================
-- UI/WarehouseItemListPanel.lua - 仓库物品卡片浏览面板
-- 左侧筛选栏（品质/分类/尺寸） + 右侧卡片网格（图片+名称+价格）
-- ============================================================================

local UI = require("urhox-libs/UI")
local Config = require("Config")
local GameState = require("GameState")
local UIState = require("UI.UIState")
local WarehouseGenerator = require("WarehouseGenerator")
local Utils = require("UI.Utils")

local Panel = {}

local GS = GameState

-- 内部状态
local panel = nil
local titleLabel = nil
local countLabel = nil

-- 初始品质过滤（来自 level2 点击）
local baseFilterRarity = nil

-- 交互筛选状态
local activeFilters = {
    rarity = nil,
    category = nil,
    sizeKey = nil,
}

-- 筛选按钮引用
local rarityBtns = {}
local categoryBtns = {}
local sizeBtns = {}
local sizeContainer = nil

-- VirtualList 相关
local virtualList = nil
local CARD_ROW_HEIGHT = 118  -- 每行高度（含卡片和间距）
local COLS = 2                -- 每行列数

-- 当前基础候选物品（去重排序后，含 baseFilter）
local currentCandidates = {}

-- 已知的尺寸列表（从仓库数据动态收集）
local ALL_SIZES = {
    "1x1", "2x1", "1x2", "2x2", "3x1", "1x3",
    "3x2", "2x3", "3x3", "4x2", "2x4", "4x3",
    "3x4", "4x4", "5x5",
}

-- ============================================================================
-- 工具函数
-- ============================================================================

--- 收集当前仓库类型的完整物品池并排序
---@return table
local function collectItems()
    local warehouseData = GS.GetWarehouseData()
    if not warehouseData or not warehouseData.warehouseTypeId then return {} end

    local pool = WarehouseGenerator.GetItemPool(warehouseData.warehouseTypeId)
    if not pool or #pool == 0 then return {} end

    -- 排序：面积升序，同面积按价值升序
    table.sort(pool, function(a, b)
        local areaA = (a.w or 1) * (a.h or 1)
        local areaB = (b.w or 1) * (b.h or 1)
        if areaA ~= areaB then return areaA < areaB end
        return (a.value or 0) < (b.value or 0)
    end)

    return pool
end

--- 应用交互筛选
---@param candidates table
---@return table
local function applyFilters(candidates)
    local result = {}
    for _, item in ipairs(candidates) do
        local pass = true
        if activeFilters.rarity and item.rarity ~= activeFilters.rarity then
            pass = false
        end
        if activeFilters.category and item.category ~= activeFilters.category then
            pass = false
        end
        if activeFilters.sizeKey then
            local sk = (item.w or 1) .. "x" .. (item.h or 1)
            if sk ~= activeFilters.sizeKey then
                pass = false
            end
        end
        if pass then result[#result + 1] = item end
    end
    return result
end

--- 更新筛选按钮的视觉状态
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
    for key, btn in pairs(sizeBtns) do
        if key == activeFilters.sizeKey then
            btn:SetStyle({ borderColor = { 255, 255, 255, 200 }, borderWidth = 2 })
        else
            btn:SetStyle({ borderColor = { 65, 72, 85, 120 }, borderWidth = 1 })
        end
    end
end

--- 将 flat 物品列表转为行数据（每行 COLS 个）
local function makeRowData(items)
    local rows = {}
    for i = 1, #items, COLS do
        local row = {}
        for c = 0, COLS - 1 do
            row[c + 1] = items[i + c]  -- 可能为 nil（最后一行不足）
        end
        rows[#rows + 1] = row
    end
    return rows
end

--- 绑定单张卡片
local function bindCard(cw, item)
    if not item then
        cw.panel:SetVisible(false)
        return
    end

    local rar = Config.GetRarity(item.rarity)

    -- 图片
    if item.image and item.image ~= "" then
        cw.imagePanel:SetStyle({
            backgroundImage = item.image,
            backgroundFit = "contain",
            backgroundColor = { 25, 28, 35, 255 },
        })
        cw.fallbackLabel:SetVisible(false)
    else
        cw.imagePanel:SetStyle({
            backgroundImage = "",
            backgroundColor = { 35, 40, 52, 255 },
        })
        cw.fallbackLabel:SetText(item.name:sub(1, 6))
        cw.fallbackLabel:SetVisible(true)
    end

    -- 品质色边框
    cw.panel:SetStyle({
        borderColor = { rar.color[1], rar.color[2], rar.color[3], 140 },
    })

    -- 名称
    cw.nameLabel:SetText(item.name)
    cw.nameLabel:SetStyle({ fontColor = rar.color })

    -- 尺寸缩略图
    cw.sizeThumb.update(item.w or 1, item.h or 1)

    -- 价格
    cw.priceLabel:SetText(Utils.FormatMoney(item.value or item.realValue or 0))

    cw.panel:SetVisible(true)
end

--- 创建单张卡片 widget（供 VirtualList createItem 使用）
local function createCardWidget()
    local fallbackLabel = UI.Label {
        text = "",
        fontSize = 11,
        fontColor = { 100, 110, 130, 160 },
        textAlign = "center",
        pointerEvents = "none",
        visible = false,
    }

    local imagePanel = UI.Panel {
        width = "100%",
        height = 72,
        borderRadius = 0,
        backgroundColor = { 25, 28, 35, 255 },
        justifyContent = "center",
        alignItems = "center",
        children = { fallbackLabel },
    }

    local nameLabel = UI.Label {
        text = "", fontSize = 11,
        fontColor = { 220, 225, 235, 255 },
        maxLines = 1,
        width = "100%",
        textAlign = "center",
        pointerEvents = "none",
    }

    local coinIcon = UI.Panel {
        width = 10, height = 10,
        backgroundImage = Utils.GetIcon("coin"),
        backgroundFit = "contain",
    }

    local priceLabel = UI.Label {
        text = "", fontSize = 10,
        fontColor = { 255, 220, 100, 255 },
        pointerEvents = "none",
    }

    local sizeThumb = Utils.CreateGridThumb(5, 5, 4, 1, {
        fillColor = { 180, 195, 215, 200 },
        emptyColor = { 60, 70, 90, 80 },
        position = "absolute",
        right = 1, bottom = 1,
    })

    imagePanel:AddChild(sizeThumb.widget)

    local card = UI.Panel {
        flexBasis = "47%",
        flexGrow = 1,
        borderRadius = 0,
        borderWidth = 1,
        borderColor = { 65, 75, 95, 140 },
        backgroundColor = { 36, 40, 50, 240 },
        flexDirection = "column",
        overflow = "hidden",
        children = {
            imagePanel,
            UI.Panel {
                width = "100%",
                padding = { 4, 5 },
                gap = 2,
                flexDirection = "column",
                alignItems = "center",
                children = {
                    nameLabel,
                    UI.Panel {
                        flexDirection = "row",
                        alignItems = "center",
                        gap = 3,
                        children = { coinIcon, priceLabel },
                    },
                },
            },
        },
    }

    return {
        panel = card,
        imagePanel = imagePanel,
        fallbackLabel = fallbackLabel,
        nameLabel = nameLabel,
        priceLabel = priceLabel,
        sizeThumb = sizeThumb,
    }
end

--- 刷新 VirtualList 数据
local function refreshCards()
    local filtered = applyFilters(currentCandidates)
    countLabel:SetText(#filtered .. "/" .. #currentCandidates .. " 件")

    if virtualList then
        local rowData = makeRowData(filtered)
        virtualList:SetData(rowData)
    end
end


-- ============================================================================
-- 创建
-- ============================================================================

function Panel.Create()
    -- 面板高度 = 屏幕逻辑高度 84%，减去 headerBar(~46px)、分隔线(1px)、边框(4px)
    local logH = graphics:GetHeight() / graphics:GetDPR()
    local vlistH = math.floor(logH * 0.84 - 51)

    -- ── 标题栏 ──────────────────────────────────────

    titleLabel = UI.Label {
        text = "仓库物品总览", fontSize = 14,
        fontColor = { 225, 228, 235, 255 },
        fontWeight = "bold",
    }

    countLabel = UI.Label {
        text = "", fontSize = 11,
        fontColor = { 150, 158, 170, 200 },
        flexGrow = 1, flexShrink = 1,
    }

    local closeBtn = UI.Panel {
        width = 26, height = 26,
        justifyContent = "center", alignItems = "center",
        borderRadius = 0,
        onClick = function() Utils.PlayClick() Panel.Hide() end,
        children = {
            UI.Label { text = "✕", fontSize = 14, fontColor = { 150, 155, 168, 220 } },
        },
    }

    local headerBar = UI.Panel {
        width = "100%",
        backgroundColor = { 40, 43, 52, 255 },
        flexDirection = "row",
        alignItems = "center",
        padding = { 10, 12 },
        gap = 6,
        children = { titleLabel, countLabel, closeBtn },
    }

    -- ── 左侧筛选栏 ─────────────────────────────────

    -- 品质筛选
    local qualityChildren = {}
    rarityBtns = {}
    for _, rar in ipairs(Config.RARITY) do
        local btn = UI.Panel {
            width = 26, height = 26,
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
                    text = "◆", fontSize = 13,
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
        flexDirection = "column", gap = 4,
        children = {
            UI.Label { text = "品质", fontSize = 10, fontColor = { 110, 118, 135, 180 } },
            UI.Panel {
                width = "100%",
                flexDirection = "row", flexWrap = "wrap", gap = 3,
                children = qualityChildren,
            },
        },
    }

    -- 品类筛选
    local categoryChildren = {}
    categoryBtns = {}
    for _, cat in ipairs(Config.CATEGORIES) do
        local btn = UI.Panel {
            paddingHorizontal = 6, paddingVertical = 3,
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
                    text = cat.name, fontSize = 10,
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
        flexDirection = "column", gap = 4,
        children = {
            UI.Label { text = "分类", fontSize = 10, fontColor = { 110, 118, 135, 180 } },
            UI.Panel {
                width = "100%",
                flexDirection = "row", flexWrap = "wrap", gap = 3,
                children = categoryChildren,
            },
        },
    }

    -- 尺寸筛选（全部尺寸始终可见，使用 5×5 网格缩略图）
    local sizeChildren = {}
    sizeBtns = {}
    local SIZE_THUMB_GRID = 5 -- 统一 5×5 网格
    local SIZE_THUMB_CELL = 5 -- 每格像素
    local SIZE_THUMB_GAP = 1  -- 格间距
    for _, sk in ipairs(ALL_SIZES) do
        local w, h = sk:match("(%d+)x(%d+)")
        w, h = tonumber(w), tonumber(h)
        local thumb = Utils.CreateGridThumb(
            SIZE_THUMB_GRID, SIZE_THUMB_GRID,
            SIZE_THUMB_CELL, SIZE_THUMB_GAP,
            { fillColor = { 180, 190, 210, 220 }, emptyColor = { 40, 45, 55, 100 } }
        )
        thumb.update(w, h)
        local btn = UI.Panel {
            padding = 4,
            borderRadius = 0,
            borderWidth = 1,
            borderColor = { 65, 72, 85, 120 },
            backgroundColor = { 42, 47, 58, 180 },
            justifyContent = "center", alignItems = "center",
            onClick = function()
                Utils.PlayClick()
                if activeFilters.sizeKey == sk then
                    activeFilters.sizeKey = nil
                else
                    activeFilters.sizeKey = sk
                end
                updateFilterStyles()
                refreshCards()
            end,
            children = { thumb.widget },
        }
        sizeBtns[sk] = btn
        sizeChildren[#sizeChildren + 1] = btn
    end

    sizeContainer = UI.Panel {
        width = "100%",
        flexDirection = "row", flexWrap = "wrap", gap = 3,
        children = sizeChildren,
    }

    local sizeSection = UI.Panel {
        width = "100%",
        flexDirection = "column", gap = 4,
        children = {
            UI.Label { text = "尺寸", fontSize = 10, fontColor = { 110, 118, 135, 180 } },
            sizeContainer,
        },
    }

    -- 清除筛选
    local clearBtn = UI.Panel {
        width = "100%", height = 24,
        borderRadius = 0,
        backgroundColor = { 52, 56, 68, 180 },
        justifyContent = "center", alignItems = "center",
        marginTop = 6,
        onClick = function()
            Utils.PlayClick()
            activeFilters.rarity = nil
            activeFilters.category = nil
            activeFilters.sizeKey = nil
            updateFilterStyles()
            refreshCards()
        end,
        children = {
            UI.Label {
                text = "清除筛选", fontSize = 10,
                fontColor = { 150, 158, 170, 200 },
                pointerEvents = "none",
            },
        },
    }

    local sidebar = UI.Panel {
        width = 100,
        flexDirection = "column",
        gap = 10,
        padding = { 8, 6 },
        backgroundColor = { 30, 33, 40, 255 },
        children = {
            qualitySection,
            categorySection,
            sizeSection,
            clearBtn,
        },
    }

    -- ── 右侧卡片网格（VirtualList） ─────────────────

    virtualList = UI.VirtualList {
        width = "100%",
        height = vlistH,
        data = {},
        itemHeight = CARD_ROW_HEIGHT,
        itemGap = 6,
        poolBuffer = 3,
        createItem = function()
            local card1 = createCardWidget()
            local card2 = createCardWidget()
            local row = UI.Panel {
                width = "100%",
                height = CARD_ROW_HEIGHT,
                flexDirection = "row",
                gap = 6,
                paddingHorizontal = 6,
                children = { card1.panel, card2.panel },
            }
            row._cards = { card1, card2 }
            return row
        end,
        bindItem = function(widget, rowData, index)
            local cards = widget._cards
            for c = 1, COLS do
                bindCard(cards[c], rowData[c])
            end
        end,
    }

    local contentArea = UI.Panel {
        flexGrow = 1,
        flexShrink = 1,
        flexBasis = 0,
        flexDirection = "column",
        backgroundColor = { 26, 29, 36, 255 },
        children = { virtualList },
    }

    -- ── 组合面板主体 ────────────────────────────────

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

    panel = UI.Panel {
        position = "absolute",
        right = "36%",
        top = "6%",
        width = 400,
        height = "84%",
        borderRadius = 0,
        borderWidth = 2,
        borderColor = { 55, 60, 72, 220 },
        flexDirection = "column",
        overflow = "hidden",
        visible = false,
        children = {
            headerBar,
            UI.Panel { width = "100%", height = 1, backgroundColor = { 50, 55, 68, 200 }, borderRadius = 0 },
            body,
        },
    }

    return panel
end

-- ============================================================================
-- 显示 / 隐藏
-- ============================================================================

--- 显示/隐藏 backdrop（需要与 ItemDetailPanel 协同）
local function ShowBackdrop()
    local bd = UIState.refs.panelBackdrop
    if bd then bd:SetVisible(true) end
end

local function HideBackdropIfAllClosed()
    local bd = UIState.refs.panelBackdrop
    if not bd then return end
    local idp = UIState.refs.itemDetailPanel
    local idpVisible = idp and idp:IsVisible()
    if not idpVisible then
        bd:SetVisible(false)
    end
end

--- 显示面板
---@param filterRarity string|nil nil=全部, "white"/"blue"/etc=预选品质
---@param sizeKey string|nil nil=不限, "2x1"/"3x2"/etc=预选尺寸
function Panel.Show(filterRarity, sizeKey)
    if not panel then return end

    baseFilterRarity = filterRarity

    -- 重置交互筛选：预选品质和尺寸
    activeFilters.rarity = filterRarity
    activeFilters.category = nil
    activeFilters.sizeKey = sizeKey or nil

    -- 收集完整物品池（筛选通过 activeFilters 交互实现）
    currentCandidates = collectItems()

    if #currentCandidates == 0 then return end

    -- 标题
    if filterRarity then
        local rar = Config.GetRarity(filterRarity)
        titleLabel:SetText(rar.name .. "品质物品")
        titleLabel:SetStyle({ fontColor = rar.color })
    else
        titleLabel:SetText("仓库物品总览")
        titleLabel:SetStyle({ fontColor = { 225, 228, 235, 255 } })
    end

    -- 更新筛选按钮样式
    updateFilterStyles()

    -- 填充卡片
    refreshCards()

    ShowBackdrop()
    panel:SetVisible(true)
end

function Panel.Hide()
    if panel then panel:SetVisible(false) end
    baseFilterRarity = nil
    HideBackdropIfAllClosed()
end

function Panel.IsVisible()
    return panel ~= nil and panel:IsVisible()
end

function Panel.Toggle(filterRarity, sizeKey)
    if Panel.IsVisible() and baseFilterRarity == filterRarity then
        Panel.Hide()
    else
        Panel.Show(filterRarity, sizeKey)
    end
end

return Panel
