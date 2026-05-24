-- ============================================================================
-- UI/BackpackScreen.lua - 背包页面（展示玩家拥有的道具）
-- 布局：左侧4列网格（可滚动）+ 右侧固定详情面板
-- ============================================================================

local UI = require("urhox-libs/UI")
local UIState = require("UI.UIState")
local Utils = require("UI.Utils")
local PropSystem = require("PropSystem")
local Props = require("Config.Props")
local Chests = require("Config.Chests")
local LootBoxPanel = require("UI.LootBoxPanel")
local PropCardWidget = require("UI.PropCardWidget")
local Config = require("Config")
local SaveSystem = require("SaveSystem")
local BackpackScreen = {}

-- ============================================================================
-- 弹窗状态（ESC 支持，本页无弹窗，保持接口一致）
-- ============================================================================

function BackpackScreen.HasOpenDialog() return false end
function BackpackScreen.DismissDialog() end

-- 品质颜色由 PropCardWidget 统一管理
local function GetTier(def)
    return PropCardWidget.GetTierColors(def)
end

local TIER_LABEL = { white = "白色", green = "绿色", blue = "蓝色", purple = "紫色" }

-- ============================================================================
-- 分类 Tab 定义
-- ============================================================================
local TABS = {
    { id = "all",     label = "全部道具" },
    { id = "prop",    label = "道具" },
    { id = "consume", label = "消耗" },
    { id = "ticket",  label = "门票" },
}

local function GetItemCategory(def)
    if def.isTicket then return "ticket" end
    if def.isChest  then return "consume" end
    return "prop"
end

-- ============================================================================
-- 主入口
-- ============================================================================

function BackpackScreen.Show(onBackCallback)
    UIState.currentScreen = "backpack"
    local sz = Utils.sz

    -- 过滤有库存的道具（保持 Props.LIST 顺序）
    local allOwnedItems = {}
    for _, def in ipairs(Props.LIST) do
        local cnt = PropSystem.GetCount(def.id)
        if cnt > 0 then
            allOwnedItems[#allOwnedItems + 1] = { def = def, count = cnt }
        end
    end
    -- 追加有库存的箱子（藏品礼盒 + 道具箱）
    for _, def in ipairs(Chests.LIST) do
        local cnt = PropSystem.GetCount(def.id)
        if cnt > 0 then
            allOwnedItems[#allOwnedItems + 1] = { def = def, count = cnt }
        end
    end

    -- 追加指定券（有库存的，作为普通格子卡片展示）
    do
        local seen = {}
        local function tryAddTicket(ticketId)
            if not ticketId or seen[ticketId] then return end
            seen[ticketId] = true
            local cnt  = SaveSystem.GetTicketCount(ticketId)
            if cnt <= 0 then return end
            local conf = Config.TICKETS and Config.TICKETS[ticketId]
            local fakeDef = {
                id           = ticketId,
                name         = conf and conf.name or ticketId,
                desc         = "拍卖场专属指定券，使用后可直接参与对应仓库的竞拍",
                icon         = "🎫",
                iconImage    = conf and conf.icon or nil,
                tier         = "white",
                isProp       = false,
                isTicket     = true,
                canUseInMenu = false,
            }
            allOwnedItems[#allOwnedItems + 1] = { def = fakeDef, count = cnt }
        end
        for _, region in ipairs(Config.REGIONS) do
            tryAddTicket(region.ticket)
            for _, diff in ipairs(region.difficulties or {}) do
                tryAddTicket(diff.requiredTicket)
            end
        end
    end

    -- 当前分类 Tab
    local activeTab = "all"

    local function FilterItems(tabId)
        if tabId == "all" then return allOwnedItems end
        local result = {}
        for _, item in ipairs(allOwnedItems) do
            if GetItemCategory(item.def) == tabId then
                result[#result + 1] = item
            end
        end
        return result
    end

    local ownedItems = FilterItems("all")

    -- ============================================================
    -- 右侧详情面板（状态驱动，选中变化时整体刷新内容区域）
    -- ============================================================

    -- 当前选中索引（1-based）
    local selectedIdx = #ownedItems > 0 and 1 or nil

    -- 右侧内容容器（动态替换子节点）
    ---@type any
    local detailContent = nil

    -- 卡片面板引用列表（数字索引），用于切换选中边框
    local cardRefs = {}
    -- 卡片面板引用（id 索引），用于开箱后局部隐藏
    local cardRefById = {}
    -- 数量角标 Label 引用，key = def.id，用于开箱后局部更新
    local countLabelRefs = {}

    -- 前向声明
    local SelectItem
    ---@type fun(item: any)
    local RefreshDetail

    -- 构建右侧详情内容
    local function BuildDetail(item)
        if not item then
            -- 空态
            return UI.Panel {
                width = "100%", flexGrow = 1,
                alignItems = "center", justifyContent = "center",
                flexDirection = "column", gap = sz(10),
                children = {
                    UI.Label { text = "🎒", fontSize = sz(36) },
                    UI.Label {
                        text = "请选择道具",
                        fontSize = sz(14),
                        fontColor = { 120, 125, 145, 160 },
                    },
                },
            }
        end

        local def   = item.def
        local count = item.count
        local tier  = GetTier(def)

        local canUseInMenu = def.canUseInMenu == true
        local isChest      = def.isChest == true
        -- 使用按钮文案
        local useLabel = isChest and "开 启 礼 盒" or "使 用"
        -- 使用按钮颜色：礼盒用金色，普通用黄绿色
        local useBtnBg = isChest and { 200, 168, 20, 255 } or { 185, 220, 0, 255 }

        return UI.Panel {
            width = "100%", flexGrow = 1,
            flexDirection = "column",
            children = {
                -- ── 道具名称 ─────────────────────────────────────
                UI.Panel {
                    width = "100%",
                    paddingHorizontal = sz(16), paddingTop = sz(18), paddingBottom = sz(6),
                    flexDirection = "column", gap = sz(6),
                    children = {
                        UI.Label {
                            text = def.name,
                            fontSize = sz(18), fontWeight = "bold",
                            fontColor = { 240, 235, 218, 255 },
                        },
                        UI.Panel {
                            flexDirection = "row", alignItems = "center", gap = sz(8),
                            children = {
                                UI.Label {
                                    text = "拥有：",
                                    fontSize = sz(13),
                                    fontColor = { 140, 145, 165, 200 },
                                },
                                UI.Panel {
                                    paddingHorizontal = sz(8), paddingVertical = sz(2),
                                    backgroundColor = { 40, 42, 55, 230 },
                                    borderRadius = sz(3),
                                    children = {
                                        UI.Label {
                                            text = tostring(count),
                                            fontSize = sz(13), fontWeight = "bold",
                                            fontColor = { 240, 235, 218, 255 },
                                        },
                                    },
                                },
                            },
                        },
                    },
                },
                -- 分隔线
                UI.Panel {
                    width = "100%", height = 1,
                    backgroundColor = { 55, 58, 72, 160 },
                    marginBottom = sz(10),
                },
                -- ── 描述 ─────────────────────────────────────────
                UI.Panel {
                    width = "100%",
                    paddingHorizontal = sz(16), paddingBottom = sz(14),
                    children = {
                        UI.Label {
                            text = def.desc,
                            fontSize = sz(13),
                            fontColor = { 170, 175, 195, 210 },
                            flexShrink = 1,
                        },
                    },
                },
                UI.Panel { flexGrow = 1 },
                -- ── 使用 / 开启按钮 ───────────────────────────────
                canUseInMenu and UI.Panel {
                    width = "100%",
                    padding = sz(12), paddingTop = sz(6),
                    children = {
                        UI.Panel {
                            width = "100%", height = sz(46),
                            backgroundColor = useBtnBg,
                            borderRadius = 0,
                            alignItems = "center", justifyContent = "center",
                            cursor = "pointer",
                            onClick = function()
                                Utils.PlayClick()
                                if isChest then
                                    -- 礼盒：弹开箱面板
                                    -- 捕获稳定引用（闭包，避免依赖循环变量）
                                    local capturedItem  = item
                                    local capturedDefId = def.id
                                    local panel = LootBoxPanel.Show(def, function()
                                        -- 关闭后局部更新：只改数量角标和右侧详情，不重建页面
                                        local newCount = PropSystem.GetCount(capturedDefId)
                                        -- 更新网格卡数量角标
                                        local lbl = countLabelRefs[capturedDefId]
                                        if lbl then
                                            if newCount > 0 then
                                                lbl.props.text = "×" .. newCount
                                            else
                                                -- 数量归零：隐藏整张卡片
                                                local cr = cardRefById[capturedDefId]
                                                if cr then cr:SetVisible(false) end
                                            end
                                        end
                                        -- 更新右侧详情面板（仅当前选中项为该礼盒时刷新）
                                        local selDef = selectedIdx and ownedItems[selectedIdx]
                                            and ownedItems[selectedIdx].def
                                        if selDef and selDef.id == capturedDefId then
                                            if newCount > 0 then
                                                capturedItem.count = newCount
                                                RefreshDetail(capturedItem)
                                            else
                                                RefreshDetail(nil)
                                            end
                                        end
                                    end)
                                    -- 挂到当前根节点最顶层
                                    UI.GetRoot():AddChild(panel)
                                end
                            end,
                            children = {
                                UI.Panel {
                                    position = "absolute",
                                    left = sz(8), top = 0, bottom = 0,
                                    width = sz(4),
                                    backgroundColor = { 255, 255, 255, 60 },
                                    pointerEvents = "none",
                                },
                                UI.Label {
                                    text = useLabel,
                                    fontSize = sz(16), fontWeight = "bold",
                                    fontColor = { 15, 15, 5, 255 },
                                    letterSpacing = sz(2),
                                },
                            },
                        },
                    },
                } or UI.Panel {},
            },
        }
    end

    -- ── 右侧面板容器 ──────────────────────────────────────────
    local rightPanel = UI.Panel {
        width = sz(200), flexShrink = 0,
        flexDirection = "column",
        backgroundColor = { 18, 20, 28, 230 },
        borderLeftWidth = 1,
        borderColor = { 50, 55, 70, 140 },
        padding = sz(12),
        children = {
            UI.Panel {
                width = "100%", flexGrow = 1,
                flexDirection = "column",
                -- 初始内容（选中第一个或空态）
                children = {
                    (function()
                        local initItem = ownedItems[1] or nil
                        local c = BuildDetail(initItem)
                        detailContent = c
                        return c
                    end)(),
                },
            },
        },
    }

    -- 右侧内容替换函数
    local rightInner = rightPanel.children[1]
    RefreshDetail = function(item)
        rightInner:RemoveChild(detailContent)
        detailContent = BuildDetail(item)
        rightInner:AddChild(detailContent)
    end

    -- ── 选中逻辑 ──────────────────────────────────────────────
    SelectItem = function(idx)
        -- 取消旧选中边框
        if selectedIdx and cardRefs[selectedIdx] then
            local old     = ownedItems[selectedIdx]
            local oldTier = old and GetTier(old.def) or PropCardWidget.TIER_COLORS.white
            cardRefs[selectedIdx].props.borderColor = oldTier.cardBorder
            cardRefs[selectedIdx].props.borderWidth = 1
        end
        selectedIdx = idx
        -- 应用新选中边框（黄绿色）
        if idx and cardRefs[idx] then
            cardRefs[idx].props.borderColor = { 200, 230, 0, 255 }
            cardRefs[idx].props.borderWidth  = 2
        end
        -- 刷新右侧面板
        RefreshDetail(ownedItems[idx])
    end

    -- ── 构建左侧卡片网格 ──────────────────────────────────────
    -- ── 左侧主体（空态 / 网格） ───────────────────────────────
    local leftBody
    if #ownedItems == 0 then
        leftBody = UI.Panel {
            width = "100%", flexGrow = 1,
            alignItems = "center", justifyContent = "center",
            flexDirection = "column", gap = sz(14),
            children = {
                UI.Panel {
                    width = sz(48), height = sz(48),
                    backgroundImage = "image/backpack_icon_white.png",
                    backgroundFit = "contain",
                },
                UI.Label {
                    text = "背包空空如也",
                    fontSize = sz(16), fontWeight = "bold",
                    fontColor = { 140, 145, 165, 200 },
                },
                UI.Label {
                    text = "前往道具商店购买情报道具吧",
                    fontSize = sz(13),
                    fontColor = { 100, 105, 120, 160 },
                },
            },
        }
    else
        -- Tab 引用列表（用于切换激活样式）
        local tabLabelRefs = {}
        local tabBarRefs   = {}
        -- 网格容器引用（Tab 切换时重建内容）
        ---@type any
        local gridInner = nil

        local function BuildCards(items)
            local cs = {}
            -- 重建 cardRefs / cardRefById / countLabelRefs
            cardRefs      = {}
            cardRefById   = {}
            countLabelRefs = {}
            selectedIdx   = #items > 0 and 1 or nil

            for i, item in ipairs(items) do
                local def2  = item.def
                local cnt2  = item.count
                local isSel = (i == selectedIdx)
                local countLabelOut = {}

                local card = PropCardWidget.BackpackCard {
                    def           = def2,
                    count         = cnt2,
                    selected      = isSel,
                    countLabelOut = countLabelOut,
                    onClick = function()
                        Utils.PlayClick()
                        SelectItem(i)
                    end,
                }
                countLabelRefs[def2.id] = countLabelOut[1]
                cardRefs[i]          = card
                cardRefById[def2.id] = card
                cs[i]                = card
            end
            return cs
        end

        local function SwitchTab(tabId)
            activeTab = tabId
            -- 更新 Tab 样式
            for _, t in ipairs(TABS) do
                local isActive = (t.id == tabId)
                if tabLabelRefs[t.id] then
                    tabLabelRefs[t.id].props.fontColor = isActive
                        and { 200, 230, 0, 255 }
                        or  { 160, 165, 185, 180 }
                    tabLabelRefs[t.id].props.fontWeight = isActive and "bold" or "normal"
                end
                if tabBarRefs[t.id] then
                    tabBarRefs[t.id].props.backgroundColor = isActive
                        and { 200, 230, 0, 255 }
                        or  { 0, 0, 0, 0 }
                end
            end
            -- 重建网格内容
            ownedItems = FilterItems(tabId)
            local newCards = BuildCards(ownedItems)
            if gridInner then
                gridInner:RemoveAllChildren()
                for _, c in ipairs(newCards) do
                    gridInner:AddChild(c)
                end
            end
            -- 刷新右侧
            RefreshDetail(ownedItems[selectedIdx])
        end

        -- 节标题 + Tab 行
        local tabChildren = {}
        for _, t in ipairs(TABS) do
            local isActive = (t.id == activeTab)
            local tabId = t.id
            local lbl = UI.Label {
                text = t.label,
                fontSize = sz(13),
                fontWeight = isActive and "bold" or "normal",
                fontColor = isActive and { 200, 230, 0, 255 } or { 160, 165, 185, 180 },
            }
            local bar = UI.Panel {
                width = "100%", height = sz(2),
                backgroundColor = isActive and { 200, 230, 0, 255 } or { 0, 0, 0, 0 },
                borderRadius = sz(1),
            }
            tabLabelRefs[t.id] = lbl
            tabBarRefs[t.id]   = bar
            tabChildren[#tabChildren + 1] = UI.Panel {
                paddingHorizontal = sz(10), paddingVertical = sz(6),
                flexDirection = "column", alignItems = "center", gap = sz(3),
                cursor = "pointer",
                onClick = function()
                    Utils.PlayClick()
                    SwitchTab(tabId)
                end,
                children = { lbl, bar },
            }
        end

        local sectionHeader = UI.Panel {
            width = "100%",
            flexDirection = "row", alignItems = "center",
            paddingLeft = sz(12),
            backgroundColor = { 20, 22, 32, 230 },
            borderBottomWidth = 1,
            borderColor = { 50, 55, 70, 150 },
            children = tabChildren,
        }

        -- 初始网格
        local initCards = BuildCards(ownedItems)
        gridInner = UI.Panel {
            width = "100%",
            flexDirection = "row", flexWrap = "wrap",
            gap = sz(10), padding = sz(12),
            children = initCards,
        }

        leftBody = UI.Panel {
            width = "100%", flexGrow = 1,
            flexDirection = "column",
            children = {
                sectionHeader,
                UI.ScrollView {
                    width = "100%", flexGrow = 1,
                    children = { gridInner },
                },
            },
        }
    end

    -- ── 顶栏 ─────────────────────────────────────────────────
    local topBar = UI.Panel {
        width = "100%", height = sz(50),
        flexDirection = "row", alignItems = "center",
        paddingHorizontal = sz(16),
        borderBottomWidth = 1, borderColor = { 50, 55, 70, 100 },
        children = {
            UI.Panel {
                flexDirection = "row", alignItems = "center", gap = sz(10),
                children = {
                    UI.Panel {
                        width = sz(24), height = sz(24),
                        backgroundImage = "image/backpack_icon_white.png",
                        backgroundFit = "contain",
                    },
                    UI.Panel { width = 1, height = sz(20), backgroundColor = { 180, 185, 200, 80 } },
                    UI.Label {
                        text = "背包",
                        fontSize = sz(18), fontWeight = "bold",
                        fontColor = { 240, 235, 220, 255 },
                    },
                },
            },
            UI.Panel { flexGrow = 1 },
            UI.Panel {
                width = sz(34), height = sz(34),
                borderRadius = sz(4),
                backgroundColor = { 40, 42, 55, 200 },
                borderWidth = 1, borderColor = { 70, 75, 90, 180 },
                alignItems = "center", justifyContent = "center",
                cursor = "pointer",
                onClick = function()
                    Utils.PlayClick()
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
    }

    -- ── 左下角返回按钮 ────────────────────────────────────────
    local returnBtn = UI.Panel {
        position = "absolute",
        left = sz(8), bottom = sz(8),
        paddingHorizontal = sz(8), paddingVertical = sz(4),
        children = {
            UI.Button {
                text = "返回",
                width = sz(80), paddingVertical = sz(7),
                fontSize = sz(13), fontWeight = "bold",
                fontColor = { 195, 215, 40, 230 },
                backgroundColor = { 195, 215, 40, 20 },
                hoverBackgroundColor = { 195, 215, 40, 50 },
                pressedBackgroundColor = { 195, 215, 40, 110 },
                borderWidth = 1, borderColor = { 195, 215, 40, 160 },
                borderRadius = 0,
                onClick = function()
                    Utils.PlayClick()
                    if onBackCallback then onBackCallback() end
                end,
            },
        },
    }

    -- ── 整体布局 ─────────────────────────────────────────────
    UI.SetRoot(UI.Panel {
        width = "100%", height = "100%",
        backgroundImage = "image/prop_shop_bg.jpg",
        backgroundFit = "cover",
        children = {
            -- 背景模糊层（全屏覆盖）
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
                            -- 主体
                            UI.Panel {
                                width = "100%", height = "100%",
                                flexDirection = "column",
                                children = {
                                    topBar,
                                    -- 内容区（左网格 + 右详情）
                                    UI.Panel {
                                        width = "100%", flexGrow = 1,
                                        flexDirection = "row",
                                        children = {
                                            -- 左侧（含节标题 + 网格）
                                            UI.Panel {
                                                flexGrow = 1, flexShrink = 1,
                                                flexDirection = "column",
                                                children = { leftBody },
                                            },
                                            -- 右侧详情面板
                                            rightPanel,
                                        },
                                    },
                                },
                            },
                            returnBtn,
                        },
                    },
                },
            },
        },
    })
end

return BackpackScreen
