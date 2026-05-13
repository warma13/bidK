-- ============================================================================
-- UI/ItemDetailPanel.lua - 物品详情浮动面板（可复用工厂组件）
-- 三层分层设计（从浅到深）：
--   第一层（标题栏）：品质色◆ + 物品名 + X关闭      rgb(48,50,58)
--   第二层（内容区）：价格 | 品类 + 物品图片       rgb(35,38,44)
--   第三层（描述区）：灰色小字描述                    rgb(26,28,32)
--
-- 用法：
--   local detail = ItemDetailPanel.New({ onHide = function() ... end })
--   local widget = detail:GetWidget()   -- 插入 UI 树
--   detail:Show(item)
--   detail:Hide()
--   detail:IsVisible()
--   detail:GetCurrentItem()
--   detail:SetStyle({ left = 100, top = 50 })
-- ============================================================================

local UI = require("urhox-libs/UI")
local Config = require("Config")
local Utils = require("UI.Utils")
local ImageCache = require("urhox-libs/UI/Core/ImageCache")

local ItemDetailPanel = {}
ItemDetailPanel.__index = ItemDetailPanel

--- 创建一个独立的物品详情浮窗实例
---@param opts? { onShow?: function, onHide?: function, position?: string, left?: number|string, right?: number|string, top?: number|string, bottom?: number|string, width?: number }
---@return table instance
function ItemDetailPanel.New(opts)
    opts = opts or {}
    local self = setmetatable({}, ItemDetailPanel)

    self._onShow = opts.onShow
    self._onHide = opts.onHide
    self._currentItem = nil

    -- ── 第一层：标题栏（最浅） ──────────────────────

    self._titleDiamond = UI.Label {
        text = "◆", fontSize = 16,
        fontColor = { 180, 180, 180, 255 },
    }

    self._titleLabel = UI.Label {
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
            self:Hide()
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
        children = { self._titleDiamond, self._titleLabel, closeBtn },
    }

    -- ── 第二层：内容区（中间调） ────────────────────

    local coinIcon = UI.Panel {
        width = 14, height = 14,
        backgroundImage = Utils.GetIcon("coin"),
        backgroundFit = "contain",
    }

    self._valueLabel = UI.Label {
        text = "", fontSize = 12,
        fontColor = { 220, 225, 230, 255 },
    }

    self._categoryLabel = UI.Label {
        text = "", fontSize = 11,
        fontColor = { 120, 125, 135, 200 },
    }

    -- 5×5 占格缩略图
    self._gridThumbObj = Utils.CreateGridThumb(5, 5, 6, 1, {
        position = "absolute", right = 1, bottom = 1,
    })

    -- 图片区域
    self._imageContainer = UI.Panel {
        width = "100%",
        height = 130,
        borderRadius = 0,
        justifyContent = "center",
        alignItems = "center",
        overflow = "hidden",
        children = { self._gridThumbObj.widget },
    }
    -- 自定义 Render：contain 居中图片
    local imgContainer = self._imageContainer
    function imgContainer:Render(nvg)
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
    imgContainer._imagePath = nil

    local contentArea = UI.Panel {
        width = "100%",
        backgroundColor = { 35, 38, 44, 255 },
        borderRadius = 0,
        flexDirection = "column",
        padding = { 8, 10 },
        gap = 6,
        children = {
            UI.Panel {
                width = "100%",
                flexDirection = "row",
                alignItems = "center",
                gap = 4,
                children = { coinIcon, self._valueLabel, self._categoryLabel },
            },
            self._imageContainer,
        },
    }

    -- ── 第三层：描述区（最深） ──────────────────────

    self._descLabel = UI.Label {
        text = "", fontSize = 10,
        fontColor = { 120, 125, 135, 180 },
        width = "100%",
    }

    local descArea = UI.Panel {
        width = "100%",
        backgroundColor = { 26, 28, 32, 255 },
        borderRadius = 0,
        padding = { 8, 10 },
        children = { self._descLabel },
    }

    -- ── 主面板 ──────────────────────────────────────

    self._panel = UI.Panel {
        position = opts.position or "absolute",
        left = opts.left,
        right = opts.right or "36%",
        top = opts.top or "10%",
        bottom = opts.bottom,
        width = opts.width or 200,
        borderRadius = 0,
        borderWidth = 2,
        borderColor = { 58, 62, 72, 220 },
        flexDirection = "column",
        overflow = "hidden",
        visible = false,
        children = {
            headerBar,
            UI.Panel { width = "100%", height = 2, backgroundColor = { 58, 62, 72, 220 }, borderRadius = 0 },
            contentArea,
            descArea,
        },
    }

    return self
end

-- ============================================================================
-- 实例方法
-- ============================================================================

--- 获取 UI widget，用于插入 UI 树
function ItemDetailPanel:GetWidget()
    return self._panel
end

--- 显示物品详情
function ItemDetailPanel:Show(item)
    if not self._panel or not item then return end
    self._currentItem = item

    local rar = Config.GetRarity(item.rarity)
    local cat = Config.GetCategory(item.category)

    self._titleDiamond:SetStyle({ fontColor = rar.color })
    self._titleLabel:SetText(item.name)

    local val = item.realValue or 0
    self._valueLabel:SetText(Utils.FormatMoney(val))
    self._categoryLabel:SetText("| " .. (cat and cat.name or ""))

    self._imageContainer._imagePath = item.image or nil
    self._descLabel:SetText(item.desc or "")

    if self._gridThumbObj then
        self._gridThumbObj.update(item.w or 1, item.h or 1)
    end

    self._panel:SetVisible(true)
    if self._onShow then self._onShow(item) end
end

--- 隐藏面板
function ItemDetailPanel:Hide()
    if self._panel then self._panel:SetVisible(false) end
    self._currentItem = nil
    if self._onHide then self._onHide() end
end

--- 是否可见
function ItemDetailPanel:IsVisible()
    return self._panel ~= nil and self._currentItem ~= nil
end

--- 获取当前显示的物品
function ItemDetailPanel:GetCurrentItem()
    return self._currentItem
end

--- 设置面板样式（用于动态定位）
function ItemDetailPanel:SetStyle(style)
    if self._panel then self._panel:SetStyle(style) end
end

return ItemDetailPanel
