-- ============================================================================
-- UI/ItemDetailPanel.lua - 物品详情浮动面板
-- 三层分层设计（从浅到深）：
--   第一层（标题栏）：品质色◆ + 物品名 + X关闭      rgb(48,50,58)
--   第二层（内容区）：价格 | 品类 + 物品图片       rgb(35,38,44)
--   第三层（描述区）：灰色小字描述                    rgb(26,28,32)
-- ============================================================================

local UI = require("urhox-libs/UI")
local Config = require("Config")
local GameState = require("GameState")
local Utils = require("UI.Utils")
local ImageCache = require("urhox-libs/UI/Core/ImageCache")

local ItemDetailPanel = {}

-- 内部引用
local panel = nil
local titleDiamond = nil
local titleLabel = nil
local valueLabel = nil
local categoryLabel = nil
local imageContainer = nil
local descLabel = nil

-- 5×5 占格缩略图（使用公用工具函数）
local gridThumbObj = nil

---@type table|nil
local currentItem = nil

-- ============================================================================
-- 创建
-- ============================================================================

function ItemDetailPanel.Create()
    -- ── 第一层：标题栏（最浅） ──────────────────────

    titleDiamond = UI.Label {
        text = "◆", fontSize = 16,
        fontColor = { 180, 180, 180, 255 },
    }

    titleLabel = UI.Label {
        text = "", fontSize = 14,
        fontColor = { 230, 230, 235, 255 },
        fontWeight = "bold",
        flexGrow = 1, flexShrink = 1,
    }

    local closeBtn = UI.Panel {
        width = 24, height = 24,
        justifyContent = "center", alignItems = "center",
        onClick = function()
            Utils.PlayClick()
            ItemDetailPanel.Hide()
        end,
        children = {
            UI.Label { text = "✕", fontSize = 13, fontColor = { 140, 145, 155, 200 } },
        }
    }

    local headerBar = UI.Panel {
        width = "100%",
        backgroundColor = { 48, 50, 58, 255 },
        borderRadius = 0,
        flexDirection = "row",
        alignItems = "center",
        padding = { 8, 10 },
        gap = 4,
        children = { titleDiamond, titleLabel, closeBtn },
    }

    -- ── 第二层：内容区（中间调） ────────────────────

    local coinIcon = UI.Panel {
        width = 14, height = 14,
        backgroundImage = Utils.GetIcon("coin"),
        backgroundFit = "contain",
    }

    valueLabel = UI.Label {
        text = "", fontSize = 12,
        fontColor = { 220, 225, 230, 255 },
    }

    categoryLabel = UI.Label {
        text = "", fontSize = 11,
        fontColor = { 120, 125, 135, 200 },
    }

    -- 5×5 占格缩略图（复用公用工具函数）
    gridThumbObj = Utils.CreateGridThumb(5, 5, 6, 1, {
        position = "absolute", right = 1, bottom = 1,
    })

    -- 图片区域
    imageContainer = UI.Panel {
        width = "100%",
        height = 130,
        borderRadius = 0,
        justifyContent = "center",
        alignItems = "center",
        overflow = "hidden",
        children = { gridThumbObj.widget },
    }
    -- 自定义 Render：contain 居中图片，不铺满
    function imageContainer:Render(nvg)
        local imgPath = self._imagePath
        if not imgPath then return end
        local imgHandle = ImageCache.Get(imgPath)
        if not imgHandle or imgHandle <= 0 then return end
        local nativeW, nativeH = ImageCache.GetSize(imgPath)
        if nativeW <= 0 or nativeH <= 0 then return end

        local layout = self:GetAbsoluteLayout()
        local boxX, boxY = layout.x, layout.y
        local boxW, boxH = layout.w, layout.h
        if boxW <= 0 or boxH <= 0 then return end

        local maxW = boxW * 0.80
        local maxH = boxH * 0.85
        local imgRatio = nativeW / nativeH
        local fitW, fitH
        if imgRatio > (maxW / maxH) then
            fitW = maxW
            fitH = maxW / imgRatio
        else
            fitH = maxH
            fitW = maxH * imgRatio
        end
        if nativeW < fitW then
            fitW = nativeW
            fitH = nativeH
        end

        local drawX = boxX + (boxW - fitW) / 2
        local drawY = boxY + (boxH - fitH) / 2

        local paint = nvgImagePattern(nvg, drawX, drawY, fitW, fitH, 0, imgHandle, 1)
        nvgBeginPath(nvg)
        nvgRect(nvg, drawX, drawY, fitW, fitH)
        nvgFillPaint(nvg, paint)
        nvgFill(nvg)
    end
    imageContainer._imagePath = nil

    local contentArea = UI.Panel {
        width = "100%",
        backgroundColor = { 35, 38, 44, 255 },
        borderRadius = 0,
        flexDirection = "column",
        padding = { 8, 10 },
        gap = 6,
        children = {
            -- 价格 | 品类
            UI.Panel {
                width = "100%",
                flexDirection = "row",
                alignItems = "center",
                gap = 4,
                children = { coinIcon, valueLabel, categoryLabel },
            },
            -- 图片 + 占格缩略图
            imageContainer,
        },
    }

    -- ── 第三层：描述区（最深） ──────────────────────

    descLabel = UI.Label {
        text = "", fontSize = 10,
        fontColor = { 120, 125, 135, 180 },
        width = "100%",
    }

    local descArea = UI.Panel {
        width = "100%",
        backgroundColor = { 26, 28, 32, 255 },
        borderRadius = 0,
        padding = { 8, 10 },
        children = { descLabel },
    }

    -- ── 主面板：外壳包裹三层 ────────────────────────

    panel = UI.Panel {
        position = "absolute",
        right = "36%",
        top = "10%",
        width = 200,
        borderRadius = 0,
        borderWidth = 2,
        borderColor = { 58, 62, 72, 220 },
        flexDirection = "column",
        overflow = "hidden",
        visible = false,
        children = {
            headerBar,
            -- 标题栏与内容区分隔线（与外边框同色同宽）
            UI.Panel { width = "100%", height = 2, backgroundColor = { 58, 62, 72, 220 }, borderRadius = 0 },
            contentArea,
            descArea,
        },
    }

    return panel
end

-- ============================================================================
-- 显示 / 隐藏
-- ============================================================================

function ItemDetailPanel.Show(item)
    if not panel or not item then return end
    currentItem = item

    local rar = Config.GetRarity(item.rarity)
    local cat = Config.GetCategory(item.category)

    titleDiamond:SetStyle({ fontColor = rar.color })
    titleLabel:SetText(item.name)

    local val = item.realValue or 0
    valueLabel:SetText(Utils.FormatMoney(val))
    categoryLabel:SetText("| " .. (cat and cat.name or ""))

    if item.image then
        imageContainer._imagePath = item.image
    else
        imageContainer._imagePath = nil
    end

    descLabel:SetText(item.desc or "")

    ItemDetailPanel._UpdateGridThumb(item)

    panel:SetVisible(true)
end

function ItemDetailPanel.Hide()
    if panel then panel:SetVisible(false) end
    currentItem = nil
end

function ItemDetailPanel.IsVisible()
    return panel ~= nil and currentItem ~= nil
end

function ItemDetailPanel.GetCurrentItem()
    return currentItem
end

-- ============================================================================
-- 5×5 占格缩略图
-- ============================================================================

function ItemDetailPanel._UpdateGridThumb(item)
    if gridThumbObj then
        gridThumbObj.update(item.w or 1, item.h or 1)
    end
end

return ItemDetailPanel
