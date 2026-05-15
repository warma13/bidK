-- ============================================================================
-- UI/PropScreen.lua - 道具商店页（网格卡片布局）
-- ============================================================================
-- 布局参考：
--   左侧边栏：分类标签（道具商店 高亮）
--   顶栏：商店标题 + 货币显示 + 关闭按钮
--   主区域：3列网格卡片，可滚动
--   购买弹窗：详情 + 数量选择 + 售价 + 黄色购买按钮
-- ============================================================================

local UI = require("urhox-libs/UI")
local UIState = require("UI.UIState")
local Utils = require("UI.Utils")
local SaveSystem = require("SaveSystem")
local Props = require("Config.Props")
local PropSystem = require("PropSystem")
local MoneyManager = require("MoneyManager")
local MoneyHUD = require("UI.MoneyHUD")

local PropScreen = {}

-- ============================================================================
-- 常量
-- ============================================================================

local COIN_ICON = "金币.png"

-- ============================================================================
-- 状态
-- ============================================================================

local dialogPropIdx = nil   -- 购买确认弹窗对应的道具索引
local dialogBuyQty = 1      -- 弹窗中的购买数量

-- ============================================================================
-- 金币图标组件
-- ============================================================================

local function CoinIcon(size)
    return UI.Panel {
        width = size, height = size,
        backgroundImage = COIN_ICON,
        backgroundFit = "contain",
    }
end

-- ============================================================================
-- 价格层级颜色映射
-- ============================================================================

local function GetTierColors(price)
    if price <= 2000 then
        -- 白色/灰色 - 普通
        return {
            headerBg    = { 90, 90, 95, 255 },
            headerText  = { 220, 220, 220, 255 },
            cardBg      = { 38, 40, 48, 255 },
            cardBorder  = { 70, 72, 78, 180 },
            iconBg      = { 50, 52, 60, 255 },
            iconBorder  = { 90, 92, 100, 200 },
            priceBg     = { 32, 34, 42, 255 },
        }
    elseif price <= 5000 then
        -- 绿色 - 进阶
        return {
            headerBg    = { 45, 120, 80, 255 },
            headerText  = { 220, 255, 230, 255 },
            cardBg      = { 28, 45, 38, 255 },
            cardBorder  = { 50, 110, 75, 180 },
            iconBg      = { 35, 55, 48, 255 },
            iconBorder  = { 60, 130, 90, 200 },
            priceBg     = { 25, 40, 35, 255 },
        }
    else
        -- 紫色 - 稀有
        return {
            headerBg    = { 100, 50, 140, 255 },
            headerText  = { 235, 210, 255, 255 },
            cardBg      = { 35, 25, 48, 255 },
            cardBorder  = { 110, 60, 160, 180 },
            iconBg      = { 45, 32, 60, 255 },
            iconBorder  = { 130, 70, 180, 200 },
            priceBg     = { 30, 22, 42, 255 },
        }
    end
end

-- ============================================================================
-- 主入口
-- ============================================================================

function PropScreen.Show(onBackCallback)
    UIState.currentScreen = "prop"
    local sz = Utils.sz

    local function Rebuild()
        local myMoney = MoneyHUD.GetMoney()

        -- ── 左侧边栏：分类标签 ────────────────────────────────────────
        local sidebarCategories = {
            { label = "道具商店", active = true },
            { label = "商城",     active = false },
            { label = "神秘商店", active = false },
            { label = "兑换所",   active = false },
            { label = "每日商城", active = false },
        }
        local sidebarItems = {}
        for _, cat in ipairs(sidebarCategories) do
            table.insert(sidebarItems, UI.Panel {
                width = "100%",
                paddingVertical = sz(12),
                paddingHorizontal = sz(14),
                backgroundColor = cat.active
                    and { 200, 230, 0, 255 }
                    or  { 60, 62, 70, 180 },
                cursor = cat.active and "default" or "pointer",
                children = {
                    UI.Label {
                        text = cat.label,
                        fontSize = sz(14), fontWeight = "bold",
                        fontColor = cat.active
                            and { 10, 10, 10, 255 }
                            or  { 180, 180, 185, 220 },
                    },
                },
            })
        end

        local sidebar = UI.Panel {
            width = sz(140),
            flexShrink = 0,
            flexDirection = "column",
            backgroundColor = { 18, 20, 28, 200 },
            paddingTop = sz(70),
            gap = sz(2),
            children = sidebarItems,
        }

        -- ── 商品卡片 ──────────────────────────────────────────────────
        local cards = {}
        for i, p in ipairs(Props.LIST) do
            local count = PropSystem.GetCount(p.id)
            local tier = GetTierColors(p.price)

            table.insert(cards, UI.Panel {
                width = "31.5%",
                flexDirection = "column",
                backgroundColor = tier.cardBg,
                borderWidth = 1,
                borderColor = tier.cardBorder,
                overflow = "hidden",
                cursor = "pointer",
                onClick = function()
                    Utils.PlayClick()
                    dialogPropIdx = i
                    dialogBuyQty = 1
                    Rebuild()
                end,
                children = {
                    -- 名称条
                    UI.Panel {
                        width = "100%",
                        paddingVertical = sz(6),
                        paddingHorizontal = sz(10),
                        backgroundColor = tier.headerBg,
                        children = {
                            UI.Label {
                                text = p.name,
                                fontSize = sz(12), fontWeight = "bold",
                                fontColor = tier.headerText,
                            },
                        },
                    },
                    -- 图标区域
                    UI.Panel {
                        width = "100%",
                        height = sz(90),
                        alignItems = "center",
                        justifyContent = "center",
                        children = {
                            p.iconImage
                                and UI.Panel {
                                    width = sz(64), height = sz(64),
                                    backgroundImage = p.iconImage,
                                    backgroundFit = "contain",
                                }
                                or UI.Panel {
                                    width = sz(56), height = sz(56),
                                    borderRadius = sz(12),
                                    backgroundColor = tier.iconBg,
                                    borderWidth = 2,
                                    borderColor = tier.iconBorder,
                                    alignItems = "center",
                                    justifyContent = "center",
                                    children = {
                                        UI.Label {
                                            text = p.icon,
                                            fontSize = sz(28),
                                        },
                                    },
                                },
                            -- ×数量角标
                            UI.Panel {
                                position = "absolute",
                                right = sz(12), bottom = sz(4),
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
                        paddingVertical = sz(6),
                        paddingHorizontal = sz(10),
                        backgroundColor = tier.priceBg,
                        borderTopWidth = 1,
                        borderColor = tier.cardBorder,
                        flexDirection = "row",
                        alignItems = "center",
                        gap = sz(4),
                        children = {
                            CoinIcon(sz(16)),
                            UI.Label {
                                text = Utils.FormatMoney(p.price),
                                fontSize = sz(13), fontWeight = "bold",
                                fontColor = { 220, 200, 120, 255 },
                            },
                        },
                    },
                },
            })
        end

        -- ── 顶栏 ─────────────────────────────────────────────────────
        local topBar = UI.Panel {
            width = "100%", height = sz(50),
            flexDirection = "row",
            alignItems = "center",
            paddingHorizontal = sz(16),
            backgroundColor = { 15, 16, 22, 220 },
            borderBottomWidth = 1,
            borderColor = { 50, 55, 70, 150 },
            children = {
                -- 左侧：商店标题
                UI.Panel {
                    flexDirection = "row",
                    alignItems = "center",
                    gap = sz(8),
                    children = {
                        UI.Label {
                            text = "🏪",
                            fontSize = sz(20),
                        },
                        UI.Panel {
                            flexDirection = "column",
                            children = {
                                UI.Label {
                                    text = "商店",
                                    fontSize = sz(18), fontWeight = "bold",
                                    fontColor = { 240, 235, 220, 255 },
                                },
                                UI.Label {
                                    text = "STORE",
                                    fontSize = sz(8),
                                    fontColor = { 100, 105, 120, 150 },
                                },
                            },
                        },
                    },
                },
                UI.Panel { flexGrow = 1 },
                -- 右侧：货币 + 关闭
                UI.Panel {
                    flexDirection = "row",
                    alignItems = "center",
                    gap = sz(14),
                    children = {
                        -- 金币胶囊
                        UI.Panel {
                            flexDirection = "row",
                            alignItems = "center",
                            gap = sz(6),
                            paddingHorizontal = sz(10), paddingVertical = sz(5),
                            backgroundColor = { 0, 0, 0, 120 },
                            borderRadius = sz(14),
                            borderWidth = 1,
                            borderColor = { 100, 80, 20, 150 },
                            children = {
                                CoinIcon(sz(18)),
                                UI.Label {
                                    text = Utils.FormatMoney(myMoney),
                                    fontSize = sz(14), fontWeight = "bold",
                                    fontColor = { 255, 215, 55, 255 },
                                },
                            },
                        },
                        -- 关闭按钮
                        UI.Panel {
                            width = sz(34), height = sz(34),
                            borderRadius = sz(4),
                            backgroundColor = { 40, 42, 55, 200 },
                            borderWidth = 1,
                            borderColor = { 70, 75, 90, 180 },
                            alignItems = "center", justifyContent = "center",
                            cursor = "pointer",
                            onClick = function()
                                Utils.PlayClick()
                                if onBackCallback then onBackCallback() end
                            end,
                            children = {
                                UI.Label {
                                    text = "✕",
                                    fontSize = sz(18), fontWeight = "bold",
                                    fontColor = { 180, 220, 0, 230 },
                                },
                            },
                        },
                    },
                },
            },
        }

        -- ── 主内容区 ─────────────────────────────────────────────────
        local mainArea = UI.Panel {
            flexGrow = 1, flexShrink = 1,
            height = "100%",
            flexDirection = "column",
            children = {
                topBar,
                -- 副标题
                UI.Panel {
                    width = "100%",
                    paddingHorizontal = sz(16), paddingVertical = sz(8),
                    flexDirection = "row", alignItems = "center",
                    borderBottomWidth = 1,
                    borderColor = { 40, 42, 55, 120 },
                    children = {
                        UI.Label {
                            text = "全部商品",
                            fontSize = sz(14), fontWeight = "bold",
                            fontColor = { 220, 220, 225, 255 },
                        },
                        UI.Panel { width = sz(8) },
                        UI.Label {
                            text = #Props.LIST .. "件",
                            fontSize = sz(11),
                            fontColor = { 120, 125, 140, 180 },
                        },
                    },
                },
                -- 网格（可滚动）
                UI.ScrollView {
                    width = "100%", flexGrow = 1,
                    children = {
                        UI.Panel {
                            width = "100%",
                            flexDirection = "row",
                            flexWrap = "wrap",
                            gap = sz(10),
                            padding = sz(12),
                            children = cards,
                        },
                    },
                },
            },
        }

        -- ── 整体布局 ─────────────────────────────────────────────────
        local mainContent = UI.Panel {
            width = "100%", height = "100%",
            flexDirection = "row",
            backgroundColor = { 12, 14, 22, 255 },
            backgroundImage = "image/prop_shop_bg_20260515115825.png",
            backgroundFit = "cover",
            children = {
                sidebar,
                mainArea,
            },
        }

        -- ── 购买弹窗（参考图2样式） ──────────────────────────────────
        local dialogOverlay = nil
        if dialogPropIdx then
            local dp = Props.LIST[dialogPropIdx]
            if dp then
                local dMoney = MoneyHUD.GetMoney()
                local dOwned = PropSystem.GetCount(dp.id)
                local dMaxBuyable = dp.maxStack - dOwned
                local qty = math.max(1, math.min(dialogBuyQty, dMaxBuyable))
                local totalPrice = dp.price * qty
                local dCanAfford = dMoney >= totalPrice
                local dMaxed = dOwned >= dp.maxStack
                local dCanBuy = dCanAfford and not dMaxed

                local tier = GetTierColors(dp.price)

                -- 弹窗内容
                local dialogBox = UI.Panel {
                    width = sz(600),
                    flexDirection = "column",
                    backgroundColor = { 30, 32, 40, 250 },
                    borderRadius = sz(8),
                    borderWidth = 1,
                    borderColor = { 60, 62, 75, 200 },
                    overflow = "hidden",
                    onClick = function() end, -- 阻止穿透
                    children = {
                        -- ── 标题栏 ───────────────────────────────────
                        UI.Panel {
                            width = "100%", height = sz(44),
                            flexDirection = "row",
                            alignItems = "center",
                            paddingHorizontal = sz(16),
                            backgroundColor = { 25, 27, 35, 255 },
                            borderBottomWidth = 1,
                            borderColor = { 55, 58, 70, 180 },
                            children = {
                                CoinIcon(sz(18)),
                                UI.Panel { width = sz(8) },
                                UI.Label {
                                    text = "购买",
                                    fontSize = sz(16), fontWeight = "bold",
                                    fontColor = { 240, 235, 220, 255 },
                                },
                                UI.Panel { flexGrow = 1 },
                                -- X 关闭
                                UI.Panel {
                                    width = sz(30), height = sz(30),
                                    alignItems = "center", justifyContent = "center",
                                    cursor = "pointer",
                                    onClick = function()
                                        Utils.PlayClick()
                                        dialogPropIdx = nil
                                        Rebuild()
                                    end,
                                    children = {
                                        UI.Label {
                                            text = "✕",
                                            fontSize = sz(18), fontWeight = "bold",
                                            fontColor = { 180, 185, 200, 220 },
                                        },
                                    },
                                },
                            },
                        },

                        -- ── 道具信息区 ───────────────────────────────
                        UI.Panel {
                            width = "100%",
                            flexDirection = "row",
                            padding = sz(20),
                            gap = sz(20),
                            borderBottomWidth = 1,
                            borderColor = { 55, 58, 70, 120 },
                            children = {
                                -- 左：图标
                                UI.Panel {
                                    flexDirection = "column",
                                    alignItems = "center",
                                    gap = sz(4),
                                    children = {
                                        dp.iconImage
                                            and UI.Panel {
                                                width = sz(80), height = sz(80),
                                                backgroundImage = dp.iconImage,
                                                backgroundFit = "contain",
                                            }
                                            or UI.Panel {
                                                width = sz(80), height = sz(80),
                                                borderRadius = sz(8),
                                                backgroundColor = tier.iconBg,
                                                borderWidth = 2,
                                                borderColor = tier.iconBorder,
                                                alignItems = "center",
                                                justifyContent = "center",
                                                children = {
                                                    UI.Label {
                                                        text = dp.icon,
                                                        fontSize = sz(36),
                                                    },
                                                },
                                            },
                                        UI.Label {
                                            text = "×" .. dOwned,
                                            fontSize = sz(13), fontWeight = "bold",
                                            fontColor = { 200, 205, 215, 220 },
                                        },
                                    },
                                },
                                -- 右：名称 + 描述 + 已拥有
                                UI.Panel {
                                    flexGrow = 1, flexShrink = 1,
                                    flexDirection = "column",
                                    gap = sz(8),
                                    children = {
                                        UI.Label {
                                            text = dp.name,
                                            fontSize = sz(18), fontWeight = "bold",
                                            fontColor = { 240, 235, 215, 255 },
                                        },
                                        UI.Label {
                                            text = dp.desc,
                                            fontSize = sz(12),
                                            fontColor = { 160, 165, 180, 200 },
                                            flexShrink = 1,
                                        },
                                        UI.Panel { height = sz(4) },
                                        UI.Label {
                                            text = "已拥有: " .. dOwned,
                                            fontSize = sz(13),
                                            fontColor = { 140, 145, 160, 200 },
                                        },
                                    },
                                },
                            },
                        },

                        -- ── 购买数 + 售价 + 按钮 ─────────────────────
                        UI.Panel {
                            width = "100%",
                            flexDirection = "column",
                            padding = sz(20),
                            gap = sz(14),
                            children = {
                                -- 购买数标签
                                UI.Label {
                                    text = "购买数",
                                    fontSize = sz(13),
                                    fontColor = { 160, 165, 180, 200 },
                                },
                                -- 底部操作行：[-] [qty] [+] + 售价 + 购买按钮
                                UI.Panel {
                                    width = "100%",
                                    flexDirection = "row",
                                    alignItems = "center",
                                    gap = sz(12),
                                    children = {
                                        -- [-] 按钮
                                        UI.Panel {
                                            width = sz(36), height = sz(36),
                                            backgroundColor = { 55, 58, 68, 255 },
                                            borderRadius = sz(4),
                                            borderWidth = 1,
                                            borderColor = { 80, 82, 95, 200 },
                                            alignItems = "center", justifyContent = "center",
                                            cursor = qty > 1 and "pointer" or "default",
                                            onClick = function()
                                                if dialogBuyQty > 1 then
                                                    Utils.PlayClick()
                                                    dialogBuyQty = dialogBuyQty - 1
                                                    Rebuild()
                                                end
                                            end,
                                            children = {
                                                UI.Label {
                                                    text = "－",
                                                    fontSize = sz(18), fontWeight = "bold",
                                                    fontColor = qty > 1
                                                        and { 220, 220, 225, 255 }
                                                        or  { 80, 82, 95, 180 },
                                                },
                                            },
                                        },
                                        -- 数量显示
                                        UI.Panel {
                                            width = sz(60), height = sz(36),
                                            backgroundColor = { 45, 48, 58, 255 },
                                            borderRadius = sz(4),
                                            borderWidth = 1,
                                            borderColor = { 80, 82, 95, 200 },
                                            alignItems = "center", justifyContent = "center",
                                            children = {
                                                UI.Label {
                                                    text = tostring(qty),
                                                    fontSize = sz(16), fontWeight = "bold",
                                                    fontColor = { 240, 240, 245, 255 },
                                                },
                                            },
                                        },
                                        -- [+] 按钮
                                        UI.Panel {
                                            width = sz(36), height = sz(36),
                                            backgroundColor = { 55, 58, 68, 255 },
                                            borderRadius = sz(4),
                                            borderWidth = 1,
                                            borderColor = { 80, 82, 95, 200 },
                                            alignItems = "center", justifyContent = "center",
                                            cursor = qty < dMaxBuyable and "pointer" or "default",
                                            onClick = function()
                                                if dialogBuyQty < dMaxBuyable then
                                                    Utils.PlayClick()
                                                    dialogBuyQty = dialogBuyQty + 1
                                                    Rebuild()
                                                end
                                            end,
                                            children = {
                                                UI.Label {
                                                    text = "＋",
                                                    fontSize = sz(18), fontWeight = "bold",
                                                    fontColor = qty < dMaxBuyable
                                                        and { 220, 220, 225, 255 }
                                                        or  { 80, 82, 95, 180 },
                                                },
                                            },
                                        },
                                        -- 间距
                                        UI.Panel { width = sz(8) },
                                        -- 售价
                                        UI.Panel {
                                            flexDirection = "row",
                                            alignItems = "center",
                                            gap = sz(6),
                                            children = {
                                                UI.Label {
                                                    text = "售价:",
                                                    fontSize = sz(13),
                                                    fontColor = { 160, 165, 180, 200 },
                                                },
                                                CoinIcon(sz(18)),
                                                UI.Label {
                                                    text = Utils.FormatMoney(totalPrice)
                                                        .. "/" .. Utils.FormatMoney(dMoney),
                                                    fontSize = sz(14), fontWeight = "bold",
                                                    fontColor = dCanAfford
                                                        and { 240, 235, 215, 255 }
                                                        or  { 220, 80, 70, 255 },
                                                },
                                            },
                                        },
                                        -- 弹性空间
                                        UI.Panel { flexGrow = 1 },
                                        -- 购买按钮
                                        UI.Panel {
                                            width = sz(120), height = sz(40),
                                            backgroundColor = dCanBuy
                                                and { 230, 200, 30, 255 }
                                                or  { 60, 62, 70, 200 },
                                            borderRadius = sz(6),
                                            alignItems = "center", justifyContent = "center",
                                            cursor = dCanBuy and "pointer" or "default",
                                            onClick = function()
                                                if not dCanBuy then return end
                                                Utils.PlayClick()
                                                local buyQty = qty
                                                local buyTotal = dp.price * buyQty
                                                MoneyManager.AddMoneyFromMenu(-buyTotal, "buy_prop_" .. dp.id, {
                                                    silent = true,
                                                    batchSetup = function(batch)
                                                        SaveSystem.AddProp(dp.id, buyQty)
                                                        SaveSystem.WriteToBatch(batch)
                                                    end,
                                                    ok = function()
                                                        Utils.ShowMessage(dp.name .. " ×" .. buyQty .. " 购买成功")
                                                    end,
                                                    error = function()
                                                        SaveSystem.AddProp(dp.id, -buyQty)
                                                        Utils.ShowMessage("购买失败，请重试")
                                                    end,
                                                })
                                                dialogPropIdx = nil
                                                dialogBuyQty = 1
                                                Rebuild()
                                            end,
                                            children = {
                                                UI.Label {
                                                    text = dMaxed and "已达上限"
                                                        or (dCanAfford and "购买" or "余额不足"),
                                                    fontSize = sz(15), fontWeight = "bold",
                                                    fontColor = dCanBuy
                                                        and { 20, 20, 20, 255 }
                                                        or  { 110, 110, 115, 200 },
                                                },
                                            },
                                        },
                                    },
                                },
                            },
                        },
                    },
                }

                dialogOverlay = UI.Panel {
                    position = "absolute",
                    left = 0, top = 0, right = 0, bottom = 0,
                    backgroundColor = { 0, 0, 0, 140 },
                    backdropBlur = 80,
                    alignItems = "center", justifyContent = "center",
                    onClick = function()
                        dialogPropIdx = nil
                        dialogBuyQty = 1
                        Rebuild()
                    end,
                    children = { dialogBox },
                }
            end
        end

        -- ── 最终根节点 ───────────────────────────────────────────────
        UI.SetRoot(UI.SafeAreaView {
            edges = "all", width = "100%", height = "100%",
            children = {
                UI.Panel {
                    width = "100%", height = "100%",
                    children = {
                        mainContent,
                        dialogOverlay,
                    },
                },
            },
        })
    end

    Rebuild()
end

return PropScreen
