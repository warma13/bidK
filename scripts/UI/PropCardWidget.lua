-- ============================================================================
-- UI/PropCardWidget.lua - 道具卡片公共组件
-- 统一 BackpackScreen、PropScreen、VersionRewardPanel 三处的六边形道具卡片渲染
-- ============================================================================

local UI = require("urhox-libs/UI")
local Utils = require("UI.Utils")

local PropCardWidget = {}

-- ============================================================================
-- 品质颜色表（white / green / blue / purple / gold / red）
-- 供使用方通过 PropCardWidget.GetTierColors(def) 获取
-- ============================================================================

PropCardWidget.TIER_COLORS = {
    white = {
        headerBg     = { 75, 78, 88, 255 },
        headerText   = { 210, 212, 220, 255 },
        cardBg       = { 34, 36, 44, 255 },
        cardBorder   = { 65, 68, 78, 180 },
        priceBg      = { 28, 30, 38, 255 },
        hexTint      = nil,
        accent       = { 200, 205, 215, 255 },
        selectBorder = { 200, 205, 215, 255 },
    },
    green = {
        headerBg     = { 30, 110, 65, 255 },
        headerText   = { 190, 255, 210, 255 },
        cardBg       = { 22, 38, 30, 255 },
        cardBorder   = { 40, 100, 65, 200 },
        priceBg      = { 18, 32, 26, 255 },
        hexTint      = { 80, 230, 120, 255 },
        accent       = { 80, 230, 120, 255 },
        selectBorder = { 80, 230, 120, 255 },
    },
    blue = {
        headerBg     = { 25, 80, 155, 255 },
        headerText   = { 190, 220, 255, 255 },
        cardBg       = { 18, 30, 55, 255 },
        cardBorder   = { 40, 85, 170, 200 },
        priceBg      = { 14, 24, 46, 255 },
        hexTint      = { 80, 160, 255, 255 },
        accent       = { 100, 175, 255, 255 },
        selectBorder = { 100, 175, 255, 255 },
    },
    purple = {
        headerBg     = { 85, 35, 130, 255 },
        headerText   = { 230, 200, 255, 255 },
        cardBg       = { 28, 18, 42, 255 },
        cardBorder   = { 100, 50, 155, 200 },
        priceBg      = { 22, 14, 35, 255 },
        hexTint      = { 200, 100, 255, 255 },
        accent       = { 200, 100, 255, 255 },
        selectBorder = { 200, 100, 255, 255 },
    },
    -- 礼盒/箱子（金色）
    gold = {
        headerBg     = { 100, 72, 15, 255 },
        headerText   = { 255, 230, 130, 255 },
        cardBg       = { 38, 28, 8, 255 },
        cardBorder   = { 160, 120, 30, 200 },
        priceBg      = { 30, 22, 8, 255 },
        hexTint      = { 255, 200, 60, 255 },
        accent       = { 255, 210, 60, 255 },
        selectBorder = { 255, 210, 60, 255 },
    },
    -- 极稀有（红色）
    red = {
        headerBg     = { 100, 20, 25, 255 },
        headerText   = { 255, 170, 175, 255 },
        cardBg       = { 40, 8, 12, 255 },
        cardBorder   = { 180, 40, 50, 200 },
        priceBg      = { 32, 6, 10, 255 },
        hexTint      = { 255, 80, 90, 255 },
        accent       = { 255, 90, 100, 255 },
        selectBorder = { 255, 90, 100, 255 },
    },
}

--- 根据道具定义获取对应品质颜色
---@param def table  道具配置（含 def.tier 字段）
function PropCardWidget.GetTierColors(def)
    return PropCardWidget.TIER_COLORS[def.tier] or PropCardWidget.TIER_COLORS.white
end

-- ============================================================================
-- HexIcon - 六边形框 + 道具图标（最小原子组件）
--
-- opts:
--   frameSize   number   六边形框外框尺寸（默认 70）
--   iconSize    number   内部图标尺寸（默认 frameSize * 0.51）
--   hexTint     color?   六边形着色（nil = 无色/白色）
--   iconImage   string?  图标图片路径
--   iconText    string?  无图片时的 fallback 文字/emoji
--   iconFontSize number? fallback 文字字号
-- ============================================================================

function PropCardWidget.HexIcon(opts)
    local sz = Utils.sz
    opts = opts or {}
    local frameSize  = opts.frameSize  or sz(70)
    local iconSize   = opts.iconSize   or math.floor(frameSize * 0.51)
    local hexW       = math.floor(frameSize * 0.87)   -- 六边形宽高比约 0.866
    local hexTint    = opts.hexTint
    local iconFontSize = opts.iconFontSize or math.floor(frameSize * 0.37)

    local iconNode = opts.iconImage
        and UI.Panel {
            width = iconSize, height = iconSize,
            backgroundImage = opts.iconImage,
            backgroundFit = "contain",
            pointerEvents = "none",
        }
        or UI.Label {
            text = opts.iconText or "?",
            fontSize = iconFontSize,
            pointerEvents = "none",
        }

    return UI.Panel {
        width = frameSize, height = frameSize,
        alignItems = "center", justifyContent = "center",
        pointerEvents = "none",
        children = {
            UI.Panel {
                position = "absolute",
                width = hexW, height = frameSize,
                backgroundImage = "image/ui_hex_frame_trimmed.png",
                backgroundFit = "fill",
                imageTint = hexTint,
                pointerEvents = "none",
            },
            iconNode,
        },
    }
end

-- ============================================================================
-- ShopCard - 商店卡片（名称条 + 图标区 + 价格底栏）
--
-- opts:
--   def         table    道具配置（.name, .tier, .iconImage, .icon, .price）
--   count       number   当前持有数量（右下角 ×N）
--   countLabel  ref?     [out] 若提供此字段，函数会将数量 Label 的引用写入 opts.countLabel
--   width       string?  卡片宽度（默认 "31.5%"）
--   frameSize   number?  六边形框尺寸（默认 sz(70)）
--   showPrice   bool?    是否显示价格底栏（默认 true）
--   boughtOverlay widget? 已购买遮罩（可选，传 nil 则不显示）
--   onClick     func?    点击回调
-- ============================================================================

function PropCardWidget.ShopCard(opts)
    local sz   = Utils.sz
    local def  = opts.def
    local tier = PropCardWidget.GetTierColors(def)
    local frameSize = opts.frameSize or sz(70)
    local iconSize  = math.floor(frameSize * 0.51)

    -- 数量角标
    local countLbl = UI.Label {
        text = "×" .. (opts.count or 0),
        fontSize = sz(12),
        fontColor = { 180, 185, 195, 220 },
    }
    if opts.countLabel ~= nil then
        -- 调用方传 table 用于接收引用：opts.countLabel = {}; 调用后 opts.countLabel[1] = lbl
        opts.countLabel[1] = countLbl
    end

    -- 图标区子节点
    local iconAreaChildren = {
        PropCardWidget.HexIcon {
            frameSize  = frameSize,
            iconSize   = iconSize,
            hexTint    = tier.hexTint,
            iconImage  = def.iconImage,
            iconText   = def.icon,
        },
        UI.Panel {
            position = "absolute",
            right = sz(12), bottom = sz(4),
            pointerEvents = "none",
            children = { countLbl },
        },
    }
    if opts.boughtOverlay then
        iconAreaChildren[#iconAreaChildren + 1] = opts.boughtOverlay
    end

    -- 子节点列表（名称条 + 图标区 [+ 价格条]）
    local cardChildren = {
        -- 名称条
        UI.Panel {
            width = "100%",
            paddingVertical = sz(6), paddingHorizontal = sz(10),
            backgroundColor = tier.headerBg,
            children = {
                UI.Label {
                    text = def.name,
                    fontSize = sz(12), fontWeight = "bold",
                    fontColor = tier.headerText,
                },
            },
        },
        -- 图标区
        UI.Panel {
            width = "100%", height = sz(90),
            alignItems = "center", justifyContent = "center",
            children = iconAreaChildren,
        },
    }

    -- 价格底栏（可选）
    -- opts.priceOverride = { price, icon, fontColor } 可覆盖默认金币价格
    local showPrice = (opts.showPrice ~= false)
    local priceOvr  = opts.priceOverride
    local displayPrice = priceOvr and priceOvr.price or def.price
    if showPrice and displayPrice then
        local priceIcon  = priceOvr and priceOvr.icon      or Utils.GetIcon("coin")
        local priceColor = priceOvr and priceOvr.fontColor  or { 220, 200, 120, 255 }
        local priceText  = priceOvr and tostring(priceOvr.price) or Utils.FormatMoney(def.price)
        cardChildren[#cardChildren + 1] = UI.Panel {
            width = "100%",
            paddingVertical = sz(6), paddingHorizontal = sz(10),
            backgroundColor = tier.priceBg,
            borderTopWidth = 1, borderColor = tier.cardBorder,
            flexDirection = "row", alignItems = "center", justifyContent = "center",
            gap = sz(4),
            children = {
                UI.Panel {
                    width = sz(16), height = sz(16),
                    backgroundImage = priceIcon,
                    backgroundFit = "contain",
                },
                UI.Label {
                    text = priceText,
                    fontSize = sz(13), fontWeight = "bold",
                    fontColor = priceColor,
                },
            },
        }
    end

    return UI.Panel {
        width = opts.width or "31.5%",
        flexDirection = "column",
        backgroundColor = tier.cardBg,
        borderWidth = 1, borderColor = tier.cardBorder,
        overflow = "hidden",
        cursor = opts.onClick and "pointer" or nil,
        onClick = opts.onClick,
        children = cardChildren,
    }
end

-- ============================================================================
-- BackpackCard - 背包卡片（名称条 + 图标区，支持礼盒/门票/道具三种图标样式）
--
-- opts:
--   def          table    道具配置
--   count        number   数量
--   selected     bool?    是否选中（影响描边颜色和宽度）
--   countLabelOut table?  [out] {[1] = label}，供外部刷新数量
--   onClick      func?    点击回调
-- ============================================================================

function PropCardWidget.BackpackCard(opts)
    local sz   = Utils.sz
    local def  = opts.def
    local tier = PropCardWidget.GetTierColors(def)
    local isSel = opts.selected and true or false

    -- 数量角标
    local countLbl = UI.Label {
        text = "×" .. (opts.count or 0),
        fontSize = sz(12), fontWeight = "bold",
        fontColor = tier.accent,
    }
    if opts.countLabelOut then
        opts.countLabelOut[1] = countLbl
    end

    -- 图标节点（礼盒/门票 vs 道具六边形框）
    local iconNode
    if def.isChest or def.isTicket then
        iconNode = UI.Panel {
            width = sz(62), height = sz(62),
            alignItems = "center", justifyContent = "center",
            pointerEvents = "none",
            children = {
                def.iconImage
                    and UI.Panel {
                        width  = def.isTicket and sz(54) or sz(56),
                        height = def.isTicket and sz(34) or sz(56),
                        backgroundImage = def.iconImage,
                        backgroundFit = "contain",
                        pointerEvents = "none",
                    }
                    or UI.Label { text = def.icon or "📦", fontSize = sz(36), pointerEvents = "none" },
            },
        }
    else
        iconNode = PropCardWidget.HexIcon {
            frameSize = sz(60),
            hexTint   = tier.hexTint,
            iconImage = def.iconImage,
            iconText  = def.icon,
        }
    end

    return UI.Panel {
        width = "23%",
        flexDirection = "column",
        backgroundColor = tier.cardBg,
        borderWidth  = isSel and 2 or 1,
        borderColor  = isSel and { 200, 230, 0, 255 } or tier.cardBorder,
        borderRadius = sz(2),
        overflow = "hidden",
        cursor = opts.onClick and "pointer" or nil,
        backgroundImage = "image/backpack_card_bg_20260518071322.png",
        backgroundFit = "cover",
        onClick = opts.onClick,
        children = {
            -- 名称条
            UI.Panel {
                width = "100%",
                paddingVertical = sz(5), paddingHorizontal = sz(4),
                alignItems = "center",
                borderBottomWidth = 1, borderColor = tier.cardBorder,
                children = {
                    UI.Label {
                        text = def.name,
                        fontSize = sz(11), fontWeight = "bold",
                        fontColor = tier.headerText,
                        textAlign = "center",
                    },
                },
            },
            -- 图标区（含数量角标）
            UI.Panel {
                width = "100%", height = sz(80),
                alignItems = "center", justifyContent = "center",
                children = {
                    iconNode,
                    UI.Panel {
                        position = "absolute",
                        right = sz(8), bottom = sz(4),
                        pointerEvents = "none",
                        children = { countLbl },
                    },
                },
            },
        },
    }
end

-- ============================================================================
-- RewardPropItem - 奖励列表中的内联道具条目（六边形图标 + 名称×数量，水平排列）
-- 用于 VersionRewardPanel 奖励行、OnlineRewardPanel 里程碑等
--
-- opts:
--   def        table   道具配置（.iconImage, .icon, .name, .tier）
--   count      number  数量
--   size       number? 六边形框尺寸（默认 sz(28)）
--   labelSize  number? 文字字号（默认 sz(11)）
-- ============================================================================

function PropCardWidget.RewardPropItem(opts)
    local sz   = Utils.sz
    local def  = opts.def
    local tier = PropCardWidget.GetTierColors(def)
    local frameSize = opts.size or sz(28)
    local labelSize = opts.labelSize or sz(11)

    return UI.Panel {
        flexDirection = "row", alignItems = "center", gap = sz(4),
        flexShrink = 0,
        children = {
            PropCardWidget.HexIcon {
                frameSize = frameSize,
                hexTint   = tier.hexTint,
                iconImage = def.iconImage,
                iconText  = def.icon,
            },
            UI.Label {
                text = def.name .. "×" .. (opts.count or 1),
                fontSize = labelSize, fontColor = tier.headerText,
            },
        },
    }
end

return PropCardWidget
