-- ============================================================================
-- UI/PropMallSection.lua - 商城分区模块（点券购买）
-- 包含：BuildMallItems、MallItemCard、BuildMallGrid、SwitchMallTab、RefreshMallGrid
-- ============================================================================
-- 使用方式：
--   local PropMallSection = require("UI.PropMallSection")
--   local mall = PropMallSection.Create(deps)
--   mall.mallHeader    → 固定标题+Tab栏 Panel
--   mall.mallSection   → 卡片容器 Panel（= mallGridPanel）
--   mall.refreshMall() → 购买后刷新当前 Tab 的卡片
-- ============================================================================

local UI = require("urhox-libs/UI")
local Utils = require("UI.Utils")
local SaveSystem = require("SaveSystem")
local Config = require("Config")
local Chests = require("Config.Chests")
local Props = require("Config.Props")
local PropCardWidget = require("UI.PropCardWidget")

local PropMallSection = {}

-- ============================================================================
-- Create(deps) → mall object
-- ============================================================================
-- deps 字段：
--   sz             : function(n)
--   openMallDialog : function(opts)  打开点券购买弹窗
-- ============================================================================
function PropMallSection.Create(deps)
    local sz             = deps.sz
    local openMallDialog = deps.openMallDialog

    -- ── 商城道具顺序常量 ─────────────────────────────────────
    local MALL_TICKET_ORDER = {
        "ticket_suburb",
        "ticket_industrial",
        "ticket_commercial",
        "ticket_port",
        "ticket_techpark",
        "ticket_culture",
        "ticket_deepsea",
        "ticket_private",
    }
    local MALL_CHEST_ORDER = { "chest_common", "chest_silver", "chest_gold" }

    local MALL_TABS = {
        { id = "all",    label = "全部" },
        { id = "ticket", label = "票券" },
        { id = "chest",  label = "礼盒" },
        { id = "gold",   label = "金色道具" },
        { id = "red",    label = "红色道具" },
    }
    local mallActiveTab = "all"

    -- ── 构建所有商城道具数据 ──────────────────────────────────
    local function BuildMallItems()
        local items = {}
        local ptBalance = SaveSystem.GetPointTickets()

        -- ① 票券
        for _, ticketId in ipairs(MALL_TICKET_ORDER) do
            local def = Config.TICKETS[ticketId]
            if def and def.ticketPrice then
                local price = def.ticketPrice
                local fakeDef = {
                    id        = ticketId,
                    name      = def.name,
                    desc      = "解锁对应区域仓库拍卖的限定入场券",
                    icon      = "🎫",
                    iconImage = def.icon,
                    tier      = "white",
                    price     = price,
                }
                items[#items + 1] = {
                    category = "ticket",
                    fakeDef  = fakeDef,
                    price    = price,
                    canAfford= ptBalance >= price,
                    getCount = function() return SaveSystem.GetTicketCount(ticketId) end,
                    onBuy    = function(qty) SaveSystem.AddTickets(ticketId, qty) end,
                }
            end
        end

        -- ② 礼盒
        for _, chestId in ipairs(MALL_CHEST_ORDER) do
            local def = Chests.BY_ID[chestId]
            if def and def.ticketPrice then
                local price = def.ticketPrice
                local fakeDef = {
                    id        = chestId,
                    name      = def.name,
                    desc      = def.desc or "随机开出十种品类藏品之一",
                    icon      = "🎁",
                    iconImage = def.iconImage or "",
                    tier      = def.tier or "white",
                    price     = price,
                }
                items[#items + 1] = {
                    category = "chest",
                    fakeDef  = fakeDef,
                    price    = price,
                    canAfford= ptBalance >= price,
                    getCount = function() return SaveSystem.GetPropCount(chestId) end,
                    onBuy    = function(qty) SaveSystem.AddProp(chestId, qty) end,
                }
            end
        end

        -- ③ 金色道具
        for _, p in ipairs(Props.LIST) do
            if p.tier == "gold" and p.mallPrice then
                local price = p.mallPrice
                items[#items + 1] = {
                    category = "gold",
                    fakeDef  = p,
                    price    = price,
                    canAfford= ptBalance >= price,
                    getCount = function() return SaveSystem.GetPropCount(p.id) end,
                    onBuy    = function(qty) SaveSystem.AddProp(p.id, qty) end,
                }
            end
        end

        -- ④ 红色道具
        for _, p in ipairs(Props.LIST) do
            if p.tier == "red" and p.mallPrice then
                local price = p.mallPrice
                items[#items + 1] = {
                    category = "red",
                    fakeDef  = p,
                    price    = price,
                    canAfford= ptBalance >= price,
                    getCount = function() return SaveSystem.GetPropCount(p.id) end,
                    onBuy    = function(qty) SaveSystem.AddProp(p.id, qty) end,
                }
            end
        end

        return items
    end

    -- ── 将一个商城 item 渲染为卡片 ───────────────────────────
    local function MallItemCard(item)
        local def        = item.fakeDef
        local isGameProp = def.inGame == true
        local ptIcon     = "image/point_ticket_icon_20260518210650.png"
        local priceColor = item.canAfford
            and { 100, 220, 255, 255 } or { 150, 150, 155, 200 }

        local function onClickHandler()
            Utils.PlayClick()
            local tc = PropCardWidget.TIER_COLORS[def.tier] or PropCardWidget.TIER_COLORS.white
            openMallDialog {
                name        = def.name,
                icon        = def.iconImage or "",
                iconText    = def.icon,
                desc        = def.desc or "",
                price       = item.price,
                canAfford   = item.canAfford,
                isGameProp  = isGameProp,
                tier        = def.tier,
                cardBg      = tc.cardBg,
                cardBorder  = tc.cardBorder,
                headerBg    = tc.headerBg,
                headerText  = tc.headerText,
                getCount    = item.getCount,
                onBuy       = item.onBuy,
            }
        end

        -- 对局内道具：用 ShopCard（带六边形）
        if isGameProp then
            return PropCardWidget.ShopCard {
                def    = def,
                count  = item.getCount(),
                width  = "31.5%",
                priceOverride = {
                    price     = item.price,
                    icon      = ptIcon,
                    fontColor = priceColor,
                },
                onClick = onClickHandler,
            }
        end

        -- 票券 / 礼盒：简单图片卡
        local count = item.getCount()
        return UI.Panel {
            width = "31.5%",
            flexDirection = "column",
            backgroundColor = { 28, 30, 40, 255 },
            borderWidth = 1,
            borderColor = { 55, 60, 78, 180 },
            overflow = "hidden",
            cursor = "pointer",
            onClick = onClickHandler,
            children = {
                -- 名称条
                UI.Panel {
                    width = "100%",
                    paddingVertical = sz(6), paddingHorizontal = sz(10),
                    backgroundColor = { 38, 40, 52, 255 },
                    children = {
                        UI.Label {
                            text = def.name,
                            fontSize = sz(12), fontWeight = "bold",
                            fontColor = { 220, 222, 230, 255 },
                            numberOfLines = 1,
                        },
                    },
                },
                -- 图片区
                UI.Panel {
                    width = "100%",
                    height = sz(90),
                    alignItems = "center", justifyContent = "center",
                    padding = sz(8),
                    children = {
                        def.iconImage ~= "" and UI.Panel {
                            width = "80%", height = "80%",
                            backgroundImage = def.iconImage,
                            backgroundFit = "contain",
                            pointerEvents = "none",
                        } or UI.Label {
                            text = def.icon or "?",
                            fontSize = sz(36),
                            pointerEvents = "none",
                        },
                        -- 数量角标（右下）
                        UI.Panel {
                            position = "absolute", right = sz(6), bottom = sz(4),
                            pointerEvents = "none",
                            children = {
                                UI.Label {
                                    text = "×" .. count,
                                    fontSize = sz(12),
                                    fontColor = { 180, 185, 195, 220 },
                                },
                            },
                        },
                    },
                },
                -- 价格底栏
                UI.Panel {
                    width = "100%",
                    flexDirection = "row", alignItems = "center", justifyContent = "center",
                    gap = sz(4),
                    paddingVertical = sz(6), paddingHorizontal = sz(10),
                    backgroundColor = { 22, 24, 34, 255 },
                    borderTopWidth = 1, borderColor = { 55, 60, 78, 180 },
                    children = {
                        UI.Panel {
                            width = sz(16), height = sz(16),
                            backgroundImage = ptIcon,
                            backgroundFit = "contain",
                        },
                        UI.Label {
                            text = tostring(item.price),
                            fontSize = sz(13), fontWeight = "bold",
                            fontColor = priceColor,
                        },
                    },
                },
            },
        }
    end

    -- ── 卡片容器 ─────────────────────────────────────────────
    ---@type any
    local mallGridPanel = nil

    local function BuildMallGrid(tabId)
        local allItems = BuildMallItems()
        local filtered = {}
        for _, item in ipairs(allItems) do
            if tabId == "all" or item.category == tabId then
                filtered[#filtered + 1] = item
            end
        end
        local cards = {}
        for _, item in ipairs(filtered) do
            cards[#cards + 1] = MallItemCard(item)
        end
        return cards
    end

    local mallTabRefs = {}

    local function RefreshMallGrid()
        if mallGridPanel then
            local newCards = BuildMallGrid(mallActiveTab)
            mallGridPanel:RemoveAllChildren()
            for _, card in ipairs(newCards) do
                mallGridPanel:AddChild(card)
            end
        end
    end

    local function SwitchMallTab(tabId)
        if mallActiveTab == tabId then return end
        mallActiveTab = tabId
        for _, ref in ipairs(mallTabRefs) do
            local isActive = ref.id == tabId
            ref.panel.props.backgroundColor = isActive
                and { 60, 130, 200, 240 } or { 28, 32, 44, 200 }
            ref.lbl.props.fontColor = isActive
                and { 255, 255, 255, 255 } or { 160, 165, 180, 200 }
        end
        RefreshMallGrid()
    end

    -- ── 构建 Tab 栏 ──────────────────────────────────────────
    local tabBarChildren = {}
    for _, tab in ipairs(MALL_TABS) do
        local isActive = tab.id == mallActiveTab
        local lbl = UI.Label {
            text      = tab.label,
            fontSize  = sz(11), fontWeight = isActive and "bold" or "normal",
            fontColor = isActive and { 255, 255, 255, 255 } or { 160, 165, 180, 200 },
        }
        local tabPanel = UI.Panel {
            paddingHorizontal = sz(10), paddingVertical = sz(6),
            backgroundColor   = isActive and { 60, 130, 200, 240 } or { 28, 32, 44, 200 },
            borderRadius      = sz(4),
            cursor            = "pointer",
            onClick           = function() SwitchMallTab(tab.id) end,
            children          = { lbl },
        }
        mallTabRefs[#mallTabRefs + 1] = { id = tab.id, panel = tabPanel, lbl = lbl }
        tabBarChildren[#tabBarChildren + 1] = tabPanel
    end

    mallGridPanel = UI.Panel {
        width = "100%",
        flexDirection = "row", flexWrap = "wrap",
        gap = sz(10), padding = sz(12),
        children = BuildMallGrid(mallActiveTab),
    }

    local mallHeader = UI.Panel {
        width = "100%",
        flexDirection = "column",
        children = {
            -- 标题行
            UI.Panel {
                width = "100%",
                flexDirection = "row", alignItems = "center",
                paddingLeft = sz(14), paddingRight = sz(16), paddingVertical = sz(8),
                backgroundColor = { 20, 22, 32, 230 },
                borderBottomWidth = 1,
                borderColor = { 50, 55, 70, 150 },
                children = {
                    UI.Panel { width = sz(3), height = sz(16), backgroundColor = { 100, 210, 255, 255 }, borderRadius = sz(2) },
                    UI.Panel { width = sz(8) },
                    UI.Label { text = "商城", fontSize = sz(14), fontWeight = "bold", fontColor = { 230, 230, 235, 255 } },
                },
            },
            -- Tab 筛选栏
            UI.Panel {
                width = "100%",
                flexDirection = "row", flexWrap = "wrap",
                gap = sz(6), paddingHorizontal = sz(12), paddingVertical = sz(8),
                backgroundColor = { 18, 20, 30, 220 },
                borderBottomWidth = 1,
                borderColor = { 45, 50, 65, 150 },
                children = tabBarChildren,
            },
        },
    }

    return {
        mallHeader   = mallHeader,
        mallSection  = mallGridPanel,
        refreshMall  = RefreshMallGrid,
    }
end

return PropMallSection
