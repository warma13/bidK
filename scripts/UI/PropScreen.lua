-- ============================================================================
-- UI/PropScreen.lua - 道具商店页（编排器）
-- ============================================================================
-- 布局：
--   左侧边栏：道具商店 / 每日商店（可点击切换）/ 商城
--   顶栏：商店标题 + 货币显示 + 关闭按钮
--   主区域：3列网格卡片，可滚动
-- ============================================================================

local UI = require("urhox-libs/UI")
local UIState = require("UI.UIState")
local Utils = require("UI.Utils")
local SaveSystem = require("SaveSystem")
local Config = require("Config")
local Props = require("Config.Props")
local PropSystem = require("PropSystem")
local MoneyManager = require("MoneyManager")
local MoneyHUD = require("UI.MoneyHUD")
local DailyShop = require("DailyShop")
local GameLoop = require("GameLoop")
local FloatingMessage = require("UI.FloatingMessage")
local AdHelper = require("AdHelper")

local PropDialogs     = require("UI.PropDialogs")
local PropShopSection = require("UI.PropShopSection")
local PropMallSection = require("UI.PropMallSection")

local PropScreen = {}

-- ============================================================================
-- 倒计时更新（模块级）
-- ============================================================================

-- refreshLabelRef 由 PropShopSection 写入，PropScreen 通过这张表间接更新
local refreshLabelRef = { lbl = nil }
local _refreshAccum   = 0.0

GameLoop.RegisterScreen("prop", "PropScreenCountdown", function(dt)
    if not refreshLabelRef.lbl then return end
    _refreshAccum = _refreshAccum + dt
    if _refreshAccum >= 1.0 then
        _refreshAccum = _refreshAccum - 1.0
        refreshLabelRef.lbl.text = DailyShop.GetRefreshText()
    end
end)

-- ============================================================================
-- 常量 & 辅助
-- ============================================================================

local COIN_ICON = "金币.png"

local function CoinIcon(size)
    return UI.Panel {
        width = size, height = size,
        backgroundImage = COIN_ICON,
        backgroundFit = "contain",
    }
end

-- ============================================================================
-- 弹窗状态（模块级，供 ESC 处理使用）
-- ============================================================================

local activeCloseDialog = nil

function PropScreen.HasOpenDialog()
    return activeCloseDialog ~= nil
end

function PropScreen.DismissDialog()
    if activeCloseDialog then activeCloseDialog() end
end

-- ============================================================================
-- 主入口
-- ============================================================================

function PropScreen.Show(onBackCallback)
    UIState.currentScreen = "prop"
    local sz = Utils.sz

    -- ── 数据准备 ──────────────────────────────────────────────
    local regularList = {}
    for _, p in ipairs(Props.LIST) do
        local tier = p.tier or "white"
        if not p.dailyShop and (tier == "white" or tier == "green") then
            regularList[#regularList + 1] = p
        end
    end

    local rawDailyItems = (not DailyShop.CanAdRefresh())
        and DailyShop.GetAdRefreshedItems()
        or  DailyShop.GetTodayItems()
    local dailyList = {}
    for i, p in ipairs(rawDailyItems) do
        dailyList[i] = { def = p, slotIdx = i }
    end
    table.sort(dailyList, function(a, b)
        local aBought = SaveSystem.GetDailySlotBought(a.slotIdx)
        local bBought = SaveSystem.GetDailySlotBought(b.slotIdx)
        if aBought == bBought then return false end
        return not aBought
    end)

    local activeSection = 1
    local cardCountLabels = {}

    -- ── 弹窗挂载容器 ─────────────────────────────────────────
    local overlayContainer = UI.Panel {
        position = "absolute",
        left = 0, top = 0, right = 0, bottom = 0,
        pointerEvents = "box-none",
    }

    -- sectionPanels/sectionHeaders 前向引用（需在 onSectionRebuilt 回调中修改）
    local sectionPanels  = {}
    local sectionHeaders = {}
    ---@type any
    local sectionHeaderContainer = nil
    ---@type any
    local contentContainer = nil
    ---@type any
    local topBar = nil

    -- 前向声明引用表（必须在 dialogs 创建之前，供回调捕获）
    local rebuildDailyRef = { fn = function() end }
    local refreshMallRef  = { fn = function() end }

    -- ── 创建弹窗模块 ─────────────────────────────────────────
    local dialogs = PropDialogs.Create({
        overlayContainer = overlayContainer,
        setActiveClose   = function(fn) activeCloseDialog = fn end,
        clearActiveClose = function()   activeCloseDialog = nil end,
        coinIcon         = CoinIcon,
        sz               = sz,
        onDailyBought    = function(_slotIdx)
            -- 将由 shopSection.rebuildDaily 触发，通过 rebuildDailyRef 解决循环
            rebuildDailyRef.fn()
        end,
        onRegularBought  = function(defId, newOwned)
            for key, lbl in pairs(cardCountLabels) do
                if key == defId or key:sub(1, #defId) == defId then
                    lbl.text = "×" .. newOwned
                end
            end
        end,
        onMallBought     = function()
            if refreshMallRef.fn then refreshMallRef.fn() end
        end,
        getTopBarTicket  = function()
            return topBar and topBar:FindById("topbar_ticket_label")
        end,
    })

    -- ── 创建商店分区模块 ─────────────────────────────────────
    local shopDeps = {
        sz             = sz,
        dailyList      = dailyList,
        cardCountLabels= cardCountLabels,
        refreshLabelRef= refreshLabelRef,
        openShopDialog = dialogs.openShop,
        regularList    = regularList,
        rebuildDailyFn = function() end,  -- PropShopSection 内部会覆盖
        onSectionRebuilt = function(newDailySection, newDailyHeader)
            -- 若当前正显示每日商店，替换 contentContainer 中的旧 widget
            if activeSection == 2 then
                contentContainer:RemoveChild(sectionPanels[2])
                contentContainer:AddChild(newDailySection)
                sectionHeaderContainer:RemoveChild(sectionHeaders[2])
                sectionHeaderContainer:AddChild(newDailyHeader)
            end
            sectionPanels[2]  = newDailySection
            sectionHeaders[2] = newDailyHeader
        end,
    }
    local shopSection = PropShopSection.Create(shopDeps)
    rebuildDailyRef.fn = shopSection.rebuildDaily

    -- ── 创建商城模块 ─────────────────────────────────────────
    local mallModule = PropMallSection.Create({
        sz             = sz,
        openMallDialog = dialogs.openMall,
    })
    refreshMallRef.fn = mallModule.refreshMall

    -- ── 组装 sectionPanels / sectionHeaders ──────────────────
    sectionPanels  = {
        shopSection.regularSection,
        shopSection.dailySection,
        mallModule.mallSection,
    }
    sectionHeaders = {
        shopSection.regularHeader,
        shopSection.dailyHeader,
        mallModule.mallHeader,
    }

    sectionHeaderContainer = UI.Panel {
        width = "100%",
        children = { sectionHeaders[1] },
    }

    contentContainer = UI.Panel {
        width = "100%",
        flexDirection = "column",
        children = { sectionPanels[1] },
    }

    -- ── 侧边栏 ───────────────────────────────────────────────
    local sidebarEntries = {
        { label = "道具商店" },
        { label = "每日商店" },
        { label = "商城" },
    }
    local sidebarRefs = {}

    local function SwitchSection(idx)
        if activeSection == idx then return end
        contentContainer:RemoveChild(sectionPanels[activeSection])
        contentContainer:AddChild(sectionPanels[idx])
        sectionHeaderContainer:RemoveChild(sectionHeaders[activeSection])
        sectionHeaderContainer:AddChild(sectionHeaders[idx])
        activeSection = idx
        for i, ref in ipairs(sidebarRefs) do
            local isActive = (i == idx)
            ref.panel.props.backgroundColor = isActive and { 200, 230, 0, 255 } or { 60, 62, 70, 180 }
            ref.bar.props.backgroundColor   = isActive and { 255, 255, 255, 255 } or { 0, 0, 0, 0 }
            ref.lbl.props.fontColor         = isActive and { 10, 10, 10, 255 } or { 180, 180, 185, 220 }
        end
    end

    local sidebarItemWidgets = {}
    for i, entry in ipairs(sidebarEntries) do
        local isActive = (i == activeSection)
        local barWidget = UI.Panel {
            width = sz(4), flexShrink = 0,
            backgroundColor = isActive and { 255, 255, 255, 255 } or { 0, 0, 0, 0 },
        }
        local lblWidget = UI.Label {
            text = entry.label,
            fontSize = sz(14), fontWeight = "bold",
            fontColor = isActive and { 10, 10, 10, 255 } or { 180, 180, 185, 220 },
        }
        local itemPanel = UI.Panel {
            width = "100%",
            flexDirection = "row", alignItems = "stretch",
            borderRadius = sz(4), overflow = "hidden",
            backgroundColor = isActive and { 200, 230, 0, 255 } or { 60, 62, 70, 180 },
            cursor = "pointer",
            onClick = function()
                Utils.PlayClick()
                SwitchSection(i)
            end,
            children = {
                barWidget,
                UI.Panel {
                    flexGrow = 1,
                    paddingVertical = sz(12), paddingLeft = sz(12), paddingRight = sz(10),
                    children = { lblWidget },
                },
            },
        }
        sidebarRefs[i] = { panel = itemPanel, bar = barWidget, lbl = lblWidget }
        sidebarItemWidgets[i] = itemPanel
    end

    local sidebarChildren = {}
    for _, w in ipairs(sidebarItemWidgets) do
        sidebarChildren[#sidebarChildren + 1] = w
    end
    sidebarChildren[#sidebarChildren + 1] = UI.Panel { flexGrow = 1 }
    sidebarChildren[#sidebarChildren + 1] = UI.Panel {
        width = "100%",
        paddingHorizontal = sz(8), paddingVertical = sz(9),
        children = {
            UI.Button {
                text = "返回",
                width = "100%", paddingVertical = sz(7),
                fontSize = sz(13), fontWeight = "bold",
                fontColor = { 195, 215, 40, 230 },
                backgroundColor = { 195, 215, 40, 20 },
                hoverBackgroundColor = { 195, 215, 40, 50 },
                pressedBackgroundColor = { 195, 215, 40, 110 },
                borderWidth = 1, borderColor = { 195, 215, 40, 160 },
                borderRadius = 0,
                onClick = function()
                    Utils.PlayClick()
                    dialogs.close()
                    if onBackCallback then onBackCallback() end
                end,
            },
        },
    }

    local sidebar = UI.Panel {
        width = sz(140), flexShrink = 0,
        flexDirection = "column",
        paddingTop = sz(4), paddingHorizontal = sz(8), gap = sz(4),
        children = sidebarChildren,
    }

    -- ── 主内容区 ─────────────────────────────────────────────
    local mainArea = UI.Panel {
        flexGrow = 1, flexShrink = 1,
        flexDirection = "column",
        children = {
            sectionHeaderContainer,
            UI.ScrollView {
                width = "100%", flexGrow = 1,
                children = { contentContainer },
            },
        },
    }

    -- ── 顶栏 ─────────────────────────────────────────────────
    local assetPopupVisible = false
    local assetPopup = nil

    local function refreshAssetPopup()
        if not assetPopup then return end
        local ml = assetPopup:FindById("tb_popup_money")
        if ml then ml:SetText(Utils.FormatMoneyExact(MoneyHUD.GetMoney())) end
        local tl = assetPopup:FindById("tb_popup_tickets")
        if tl then tl:SetText(tostring(SaveSystem.GetPointTickets())) end
    end

    local function hideAssetPopup()
        if assetPopup then
            assetPopup:SetVisible(false)
            assetPopupVisible = false
        end
    end

    local function toggleAssetPopup()
        if not assetPopup then return end
        assetPopupVisible = not assetPopupVisible
        if assetPopupVisible then refreshAssetPopup() end
        assetPopup:SetVisible(assetPopupVisible)
    end

    local function buildAssetPopup()
        local watchAdBtnRef = nil
        local watchAdAmtRef = nil
        local popupContent = UI.Panel {
            width = sz(280),
            backgroundColor = { 30, 33, 48, 245 },
            borderRadius = sz(8), borderWidth = 1,
            borderColor = { 80, 85, 110, 180 },
            padding = sz(16), gap = sz(12),
            flexDirection = "column",
            onClick = function() end,
            children = {
                UI.Label {
                    text = "我的资产", fontSize = sz(16), fontWeight = "bold",
                    fontColor = { 255, 220, 100, 255 },
                    textAlign = "center", width = "100%",
                },
                UI.Panel { width = "100%", height = 1, backgroundColor = { 80, 85, 110, 120 } },
                -- 金币行
                UI.Panel {
                    width = "100%", flexDirection = "row",
                    justifyContent = "space-between", alignItems = "center",
                    children = {
                        UI.Panel {
                            flexDirection = "row", alignItems = "center", gap = sz(6),
                            children = {
                                UI.Panel { width = sz(20), height = sz(20), backgroundImage = Utils.GetIcon("coin"), backgroundFit = "contain", flexShrink = 0 },
                                UI.Label { text = "金币", fontSize = sz(13), fontColor = { 200, 205, 220, 255 } },
                            },
                        },
                        UI.Label { id = "tb_popup_money", text = Utils.FormatMoneyExact(MoneyHUD.GetMoney()), fontSize = sz(14), fontWeight = "bold", fontColor = { 255, 220, 100, 255 } },
                    },
                },
                -- 点券行
                UI.Panel {
                    width = "100%", flexDirection = "row",
                    justifyContent = "space-between", alignItems = "center",
                    children = {
                        UI.Panel {
                            flexDirection = "row", alignItems = "center", gap = sz(6),
                            children = {
                                UI.Panel { width = sz(20), height = sz(20), backgroundImage = "image/point_ticket_icon_20260518210650.png", backgroundFit = "contain", flexShrink = 0 },
                                UI.Label { text = "点券", fontSize = sz(13), fontColor = { 200, 205, 220, 255 } },
                            },
                        },
                        UI.Label { id = "tb_popup_tickets", text = tostring(SaveSystem.GetPointTickets()), fontSize = sz(14), fontWeight = "bold", fontColor = { 120, 210, 255, 255 } },
                    },
                },
                UI.Panel { width = "100%", height = 1, backgroundColor = { 80, 85, 110, 120 } },
                -- 看广告按钮
                (function()
                    local watchAdAmountLabel = UI.Label { text = "", fontSize = sz(13), fontWeight = "bold", fontColor = { 20, 20, 20, 255 } }
                    watchAdAmtRef = watchAdAmountLabel
                    local btn = UI.Button {
                        width = "100%", height = sz(36), variant = "primary",
                        onClick = function()
                            Utils.PlayClick()
                            hideAssetPopup()
                            local AdCardPanel = require("UI.AdCardPanel")
                            if AdCardPanel.CanWatchAd() then AdCardPanel.WatchAd() end
                        end,
                        children = {
                            UI.Panel {
                                flexDirection = "row", alignItems = "center", gap = sz(4),
                                justifyContent = "center", width = "100%", height = "100%",
                                children = {
                                    UI.Label { text = "看广告", fontSize = sz(13), fontWeight = "bold", fontColor = { 20, 20, 20, 255 } },
                                    UI.Panel { width = sz(16), height = sz(16), backgroundImage = Utils.GetIcon("coin"), backgroundFit = "contain", flexShrink = 0 },
                                    watchAdAmountLabel,
                                    UI.Panel { width = sz(16), height = sz(16), backgroundImage = "image/point_ticket_icon_20260518210650.png", backgroundFit = "contain", flexShrink = 0 },
                                    UI.Label { text = "×10", fontSize = sz(11), fontColor = { 20, 20, 20, 255 } },
                                },
                            },
                        },
                    }
                    watchAdBtnRef = btn
                    return btn
                end)(),
                -- 关闭按钮
                UI.Button {
                    text = "关闭", width = "100%", height = sz(36), fontSize = sz(13),
                    onClick = function() Utils.PlayClick(); hideAssetPopup() end,
                },
            },
        }
        -- 刷新广告按钮文字
        local ok, AdCardPanel = pcall(require, "UI.AdCardPanel")
        if ok and watchAdAmtRef then
            local tier = AdCardPanel.GetCurrentTier and AdCardPanel.GetCurrentTier()
            if tier and tier.coinsPerAd then
                watchAdAmtRef:SetText("+" .. Utils.FormatMoney(tier.coinsPerAd))
            end
            if watchAdBtnRef then
                watchAdBtnRef:SetDisabled(not AdCardPanel.CanWatchAd())
            end
        end

        assetPopup = UI.Panel {
            position = "absolute", left = 0, top = 0, width = "100%", height = "100%",
            backgroundColor = { 0, 0, 0, 150 },
            justifyContent = "center", alignItems = "center",
            visible = false,
            onClick = function() hideAssetPopup() end,
            children = {
                UI.Panel { justifyContent = "center", alignItems = "center", children = { popupContent } },
            },
        }
        return assetPopup
    end

    local myMoney = MoneyHUD.GetMoney()
    topBar = UI.Panel {
        width = "100%", height = sz(50),
        flexDirection = "row", alignItems = "center",
        paddingHorizontal = sz(16),
        borderBottomWidth = 1, borderColor = { 50, 55, 70, 100 },
        children = {
            UI.Panel {
                flexDirection = "row", alignItems = "center", gap = sz(10),
                children = {
                    UI.Panel {
                        width = sz(26), height = sz(26),
                        backgroundImage = "image/icon_cart.png",
                        backgroundFit = "contain",
                    },
                    UI.Panel { width = 1, height = sz(20), backgroundColor = { 180, 185, 200, 80 } },
                    UI.Label {
                        text = "商店",
                        fontSize = sz(18), fontWeight = "bold",
                        fontColor = { 240, 235, 220, 255 },
                    },
                },
            },
            UI.Panel { flexGrow = 1 },
            UI.Panel {
                flexDirection = "row", alignItems = "center", gap = sz(8),
                children = {
                    -- 金币
                    UI.Panel {
                        flexDirection = "row", alignItems = "center",
                        gap = sz(6), paddingHorizontal = sz(10), paddingVertical = sz(5),
                        backgroundColor = { 0, 0, 0, 120 },
                        borderRadius = sz(14), borderWidth = 1,
                        borderColor = { 100, 80, 20, 150 },
                        cursor = "pointer",
                        onClick = function() Utils.PlayClick(); toggleAssetPopup() end,
                        children = {
                            CoinIcon(sz(18)),
                            UI.Label {
                                text = Utils.FormatMoney(myMoney),
                                fontSize = sz(14), fontWeight = "bold",
                                fontColor = { 255, 215, 55, 255 },
                            },
                        },
                    },
                    -- 点券
                    UI.Panel {
                        flexDirection = "row", alignItems = "center",
                        gap = sz(6), paddingHorizontal = sz(10), paddingVertical = sz(5),
                        backgroundColor = { 0, 0, 0, 120 },
                        borderRadius = sz(14), borderWidth = 1,
                        borderColor = { 40, 120, 180, 150 },
                        cursor = "pointer",
                        onClick = function() Utils.PlayClick(); toggleAssetPopup() end,
                        children = {
                            UI.Panel {
                                width = sz(16), height = sz(16),
                                backgroundImage = "image/point_ticket_icon_20260518210650.png",
                                backgroundFit = "contain", flexShrink = 0,
                            },
                            UI.Label {
                                id = "topbar_ticket_label",
                                text = tostring(SaveSystem.GetPointTickets()),
                                fontSize = sz(14), fontWeight = "bold",
                                fontColor = { 100, 210, 255, 255 },
                            },
                        },
                    },
                    UI.Panel {
                        width = sz(34), height = sz(34),
                        borderRadius = sz(4),
                        backgroundColor = { 40, 42, 55, 200 },
                        borderWidth = 1, borderColor = { 70, 75, 90, 180 },
                        alignItems = "center", justifyContent = "center",
                        cursor = "pointer",
                        onClick = function()
                            Utils.PlayClick()
                            dialogs.close()
                            if onBackCallback then onBackCallback() end
                        end,
                        children = {
                            UI.Label {
                                text = "✕", fontSize = sz(18), fontWeight = "bold",
                                fontColor = { 180, 220, 0, 230 },
                            },
                        },
                    },
                },
            },
        },
    }

    -- 挂入资产弹窗
    overlayContainer:AddChild(buildAssetPopup())

    -- 关闭屏幕时清空倒计时引用
    local _origBack = onBackCallback
    onBackCallback = function()
        refreshLabelRef.lbl = nil
        if _origBack then _origBack() end
    end

    -- ── 整体布局 ─────────────────────────────────────────────
    UI.SetRoot(UI.Panel {
        width = "100%", height = "100%",
        backgroundImage = "image/prop_shop_bg.jpg",
        backgroundFit = "cover",
        children = {
            UI.Panel {
                position = "absolute",
                left = 0, top = 0, right = 0, bottom = 0,
                backdropBlur = 60,
                backgroundColor = { 8, 10, 20, 100 },
            },
            UI.SafeAreaView {
                edges = "all", width = "100%", height = "100%",
                children = {
                    UI.Panel {
                        width = "100%", height = "100%",
                        children = {
                            UI.Panel {
                                width = "100%", height = "100%",
                                flexDirection = "column",
                                children = {
                                    topBar,
                                    UI.Panel {
                                        width = "100%", flexGrow = 1,
                                        flexDirection = "row",
                                        children = { sidebar, mainArea },
                                    },
                                },
                            },
                            overlayContainer,
                        },
                    },
                },
            },
        },
    })
end

return PropScreen
