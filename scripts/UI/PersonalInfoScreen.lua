-- ============================================================================
-- UI/PersonalInfoScreen.lua - 个人信息全屏页（编排者）
-- ============================================================================
-- 拆分后文件结构：
--   PersonalInfoUtils.lua   - 常量、格式化、图标辅助
--   PersonalInfoTab.lua     - 信息 Tab（统计数据）
--   PersonalInfoDetail.lua  - 对局详情全屏页
--   PersonalInfoHistory.lua - 对局历史 Tab（VirtualList）
--   PersonalInfoScreen.lua  - 编排者（本文件），仅包含 Show() 和导航回调
-- ============================================================================

---@diagnostic disable: undefined-global

local UI = require("urhox-libs/UI")
local UIState = require("UI.UIState")
local Utils = require("UI.Utils")

local InfoTab    = require("UI.PersonalInfoTab")
local Detail     = require("UI.PersonalInfoDetail")
local History    = require("UI.PersonalInfoHistory")

local PersonalInfoScreen = {}

-- ESC 回调（由 GameController 统一处理）
PersonalInfoScreen._goBack           = nil
PersonalInfoScreen._goBackFromDetail = nil
PersonalInfoScreen._initialTab       = 1   -- Show() 打开时起始 tab（用完即重置）

function PersonalInfoScreen.GoBack()
    if PersonalInfoScreen._goBack then PersonalInfoScreen._goBack() end
end
function PersonalInfoScreen.GoBackFromDetail()
    if PersonalInfoScreen._goBackFromDetail then PersonalInfoScreen._goBackFromDetail() end
end

-- ============================================================================
-- 公开接口：全屏切换
-- ============================================================================

function PersonalInfoScreen.Show(onBackCallback)
    UIState.currentScreen = "personal_info"
    local sz = Utils.sz

    local startTab = PersonalInfoScreen._initialTab or 1
    PersonalInfoScreen._initialTab = 1

    local activeTab  = 1
    local sidebarRefs = {}

    local contentContainer = UI.Panel {
        flexGrow = 1, flexShrink = 1,
        flexDirection = "column",
        overflow = "hidden",
    }

    -- 详情页回调：ShowMatchDetail 替换整个 UI 树，返回时必须重建页面
    local function OnShowDetail(rec)
        UIState.currentScreen = "personal_info_detail"
        PersonalInfoScreen._goBackFromDetail = function()
            PersonalInfoScreen._goBackFromDetail = nil
            PersonalInfoScreen._initialTab = 2   -- 返回后直接打开对局 tab
            PersonalInfoScreen.Show(onBackCallback)
        end
        Detail.ShowMatchDetail(rec, PersonalInfoScreen._goBackFromDetail)
    end

    -- 预构建两个 tab 内容
    local infoTabContent = UI.ScrollView {
        width = "100%", flexGrow = 1,
        paddingHorizontal = sz(20), paddingTop = sz(16),
        children = { InfoTab.Build() },
    }

    local function GoBackFn()
        Utils.PlayClick()
        UIState.currentScreen = "menu"
        if onBackCallback then
            onBackCallback()
        else
            local GameController = require("UI.GameController")
            GameController.ShowMenu()
        end
    end

    local historyTabContent = UI.Panel {
        width = "100%", flexGrow = 1, flexShrink = 1, flexDirection = "column",
        paddingHorizontal = sz(8), paddingTop = sz(8),
        children = { History.Build(OnShowDetail, GoBackFn) },
    }

    local tabContents   = { infoTabContent, historyTabContent }
    local currentContent = tabContents[1]
    contentContainer:AddChild(currentContent)

    local function SwitchTab(idx)
        if activeTab == idx then return end
        contentContainer:RemoveChild(currentContent)
        activeTab    = idx
        currentContent = tabContents[idx]
        contentContainer:AddChild(currentContent)
        for i, ref in ipairs(sidebarRefs) do
            local isActive = (i == idx)
            ref.panel.props.backgroundColor = isActive and { 200, 230, 0, 255 } or { 60, 62, 70, 180 }
            ref.bar.props.backgroundColor   = isActive and { 255, 255, 255, 255 } or { 0, 0, 0, 0 }
            ref.lbl.props.fontColor         = isActive and { 10, 10, 10, 255 } or { 180, 180, 185, 220 }
        end
    end

    if startTab ~= 1 then SwitchTab(startTab) end

    -- 侧边栏 tabs
    local tabDefs = { { label = "信息" }, { label = "对局" } }
    local sidebarItemWidgets = {}
    for i, def in ipairs(tabDefs) do
        local isActive = (i == activeTab)
        local barWidget = UI.Panel {
            width = sz(4), flexShrink = 0,
            backgroundColor = isActive and { 255, 255, 255, 255 } or { 0, 0, 0, 0 },
        }
        local lblWidget = UI.Label {
            text = def.label,
            fontSize = sz(14), fontWeight = "bold",
            fontColor = isActive and { 10, 10, 10, 255 } or { 180, 180, 185, 220 },
        }
        local itemPanel = UI.Panel {
            width = "100%",
            flexDirection = "row", alignItems = "stretch",
            borderRadius = sz(4), overflow = "hidden",
            backgroundColor = isActive and { 200, 230, 0, 255 } or { 60, 62, 70, 180 },
            cursor = "pointer",
            onClick = function() Utils.PlayClick(); SwitchTab(i) end,
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

    local function GoBack()
        Utils.PlayClick()
        UIState.currentScreen = "menu"
        PersonalInfoScreen._goBack = nil
        if onBackCallback then
            onBackCallback()
        else
            local GameController = require("UI.GameController")
            GameController.ShowMenu()
        end
    end
    PersonalInfoScreen._goBack = GoBack

    local sidebar = UI.Panel {
        width = sz(140), flexShrink = 0,
        flexDirection = "column",
        paddingTop = sz(4), paddingHorizontal = sz(8), gap = sz(4),
        children = {
            UI.Panel {
                width = "100%", flexDirection = "column", gap = sz(4),
                children = sidebarItemWidgets,
            },
        },
    }

    -- 顶栏
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
                        width = sz(22), height = sz(22),
                        backgroundImage = "image/nav_stats_20260515210551.png",
                        backgroundFit = "contain",
                    },
                    UI.Panel { width = 1, height = sz(20), backgroundColor = { 180, 185, 200, 80 } },
                    UI.Label {
                        text = "信息",
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
                onClick = GoBack,
                children = {
                    UI.Label {
                        text = "✕", fontSize = sz(18), fontWeight = "bold",
                        fontColor = { 180, 220, 0, 230 },
                    },
                },
            },
        },
    }

    -- 主布局
    UI.SetRoot(UI.Panel {
        width = "100%", height = "100%",
        backgroundImage = "image/task_bg_20260516170303.jpg",
        backgroundFit = "cover",
        children = {
            UI.Panel {
                position = "absolute",
                left = 0, top = 0, right = 0, bottom = 0,
                backdropBlur = 40,
                backgroundColor = { 6, 8, 16, 200 },
            },
            UI.SafeAreaView {
                edges = "all", width = "100%", height = "100%",
                children = {
                    UI.Panel {
                        width = "100%", height = "100%",
                        flexDirection = "column",
                        children = {
                            topBar,
                            UI.Panel {
                                width = "100%", flexGrow = 1, flexShrink = 1,
                                flexDirection = "row",
                                overflow = "hidden",
                                children = { sidebar, contentContainer },
                            },
                            UI.Panel {
                                width = "100%",
                                paddingHorizontal = sz(8), paddingVertical = sz(9),
                                borderTopWidth = 1, borderColor = { 255, 255, 255, 10 },
                                children = {
                                    UI.Button {
                                        text = "返回",
                                        width = sz(120), paddingVertical = sz(7),
                                        fontSize = sz(13), fontWeight = "bold",
                                        fontColor = { 195, 215, 40, 230 },
                                        backgroundColor = { 195, 215, 40, 20 },
                                        hoverBackgroundColor = { 195, 215, 40, 50 },
                                        pressedBackgroundColor = { 195, 215, 40, 110 },
                                        borderWidth = 1, borderColor = { 195, 215, 40, 160 },
                                        borderRadius = sz(4),
                                        onClick = GoBack,
                                    },
                                },
                            },
                        },
                    },
                },
            },
        },
    })
end

return PersonalInfoScreen
