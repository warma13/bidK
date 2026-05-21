-- ============================================================================
-- UI/MenuScreen.lua - 主菜单屏幕
-- ============================================================================

---@diagnostic disable: undefined-global

local UI = require("urhox-libs/UI")
local Config = require("Config")
local UIState = require("UI.UIState")
local MoneyHUD = require("UI.MoneyHUD")
local Utils = require("UI.Utils")
local LeaderboardPanel = require("UI.LeaderboardPanel")
local DebugPanel = require("UI.DebugPanel")
local SettingsPanel = require("UI.SettingsPanel")
local AdCardPanel = require("UI.AdCardPanel")
local OnlineRewardPanel = require("UI.OnlineRewardPanel")
local StatsPanel = require("UI.StatsPanel")
local PersonalInfoScreen = require("UI.PersonalInfoScreen")
local VersionRewardPanel = require("UI.VersionRewardPanel")
local RewardScreen = require("UI.RewardScreen")
local TaskPanel = require("UI.TaskPanel")
local SeasonPassPanel = require("UI.SeasonPassPanel")
local TicketTooltip = require("UI.TicketTooltip")
local MailPanel = require("UI.MailPanel")
local SaveSystem = require("SaveSystem")

local MenuScreen = {}

-- ============================================================================
-- 版本公告（权威数据来自 VersionRewardPanel，此处直接引用避免重复维护）
-- ============================================================================
local ANNOUNCEMENTS = VersionRewardPanel.ANNOUNCEMENTS

-- ============================================================================
-- 动态红点刷新（在 Show() 之后、async 数据到位时调用）
-- ============================================================================

--- @type any
local _badgeReward = nil   -- 奖励中心红点 Panel
--- @type any
local _badgeBorderReward = nil  -- 奖励中心按钮（需要更新边框色）
--- @type any
local _badgePass   = nil   -- 通行证红点 Panel
--- @type any
local _badgeBorderPass = nil    -- 通行证按钮（需要更新边框色）

--- 当任何面板的 async 数据加载完成后调用此函数刷新红点可见性
function MenuScreen.RefreshBadges()
    local hasReward = AdCardPanel.HasClaimable()
        or OnlineRewardPanel.HasClaimable()
        or VersionRewardPanel.HasClaimable()
    local hasPass = SeasonPassPanel.HasClaimable()

    if _badgeReward then
        _badgeReward:SetVisible(hasReward)
    end
    if _badgeBorderReward then
        _badgeBorderReward:SetStyle({ borderColor = hasReward and { 220, 80, 80, 200 } or { 70, 85, 130, 160 } })
    end
    if _badgePass then
        _badgePass:SetVisible(hasPass)
    end
    if _badgeBorderPass then
        _badgeBorderPass:SetStyle({ borderColor = hasPass and { 220, 80, 80, 200 } or { 70, 85, 130, 160 } })
    end
end

local function CreateAnnouncementButton(announcementOverlay)
    local sz = Utils.sz
    local visible = false

    local btn = UI.Panel {
        paddingHorizontal = sz(10), paddingVertical = sz(4),
        flexDirection = "column",
        alignItems = "center", justifyContent = "center",
        gap = sz(2),
        cursor = "pointer",
        backgroundColor = { 20, 24, 38, 180 },
        borderWidth = 1,
        borderColor = { 70, 85, 130, 160 },
        borderRadius = sz(6),
        onClick = function()
            Utils.PlayClick()
            visible = not visible
            announcementOverlay:SetVisible(visible)
        end,
        children = {
            UI.Panel {
                width = sz(26), height = sz(26),
                backgroundImage = "image/nav_announce_20260515210730.png",
                backgroundFit = "contain",
                pointerEvents = "none",
            },
            UI.Label {
                text = "公告",
                fontSize = sz(11), fontColor = { 200, 205, 220, 200 },
                pointerEvents = "none",
            },
        },
    }
    return btn
end

local function CreateAnnouncementPopup()
    local sz = Utils.sz
    local visible = false

    -- 公告条目列表
    local itemNodes = {}
    for _, ann in ipairs(ANNOUNCEMENTS) do
        -- 标题行
        table.insert(itemNodes, UI.Panel {
            width = "100%",
            flexDirection = "row",
            alignItems = "center",
            gap = sz(6),
            marginBottom = sz(4),
            children = {
                UI.Panel {
                    width = sz(3), height = sz(14),
                    backgroundColor = { 255, 200, 60, 255 },
                    borderRadius = sz(2), flexShrink = 0,
                },
                UI.Label {
                    text = ann.title .. "  " .. ann.date,
                    fontSize = sz(12),
                    fontColor = { 255, 220, 120, 255 },
                    fontWeight = "bold",
                },
            },
        })
        -- 条目
        for _, item in ipairs(ann.items) do
            table.insert(itemNodes, UI.Panel {
                width = "100%",
                flexDirection = "row",
                alignItems = "flex-start",
                gap = sz(6),
                marginBottom = sz(5),
                children = {
                    UI.Label {
                        text = "•",
                        fontSize = sz(12),
                        fontColor = { 160, 200, 255, 220 },
                        marginTop = sz(1), flexShrink = 0,
                    },
                    UI.Label {
                        text = item,
                        fontSize = sz(12),
                        fontColor = { 210, 215, 230, 240 },
                        flexShrink = 1,
                    },
                },
            })
        end
    end

    ---@type any
    local overlay = nil
    overlay = UI.Panel {
        position = "absolute",
        left = 0, top = 0, right = 0, bottom = 0,
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = { 0, 0, 0, 140 },
        visible = false,
        onClick = function()
            visible = false
            overlay:SetVisible(false)
        end,
        children = {
            UI.Panel {
                onClick = function() end, -- 阻止点穿
                width = sz(340),
                backgroundColor = { 18, 22, 35, 250 },
                borderRadius = sz(8),
                borderWidth = 1,
                borderColor = { 60, 75, 120, 180 },
                overflow = "hidden",
                children = {
                    -- 标题栏
                    UI.Panel {
                        width = "100%",
                        paddingHorizontal = sz(14), paddingVertical = sz(10),
                        flexDirection = "row",
                        alignItems = "center",
                        justifyContent = "space-between",
                        backgroundColor = { 25, 30, 52, 255 },
                        borderBottomWidth = 1,
                        borderColor = { 50, 65, 110, 150 },
                        children = {
                            UI.Panel {
                                flexDirection = "row", alignItems = "center", gap = sz(6),
                                children = {
                                    UI.Label { text = "📢", fontSize = sz(15), pointerEvents = "none" },
                                    UI.Label {
                                        text = "版本公告",
                                        fontSize = sz(14),
                                        fontColor = { 230, 230, 245, 255 },
                                        fontWeight = "bold",
                                    },
                                },
                            },
                            UI.Button {
                                text = "✕",
                                width = sz(26), height = sz(26),
                                fontSize = sz(12),
                                backgroundColor = { 50, 55, 75, 200 },
                                fontColor = { 180, 185, 200, 230 },
                                borderRadius = sz(4),
                                onClick = function()
                                    Utils.PlayClick()
                                    visible = false
                                    overlay:SetVisible(false)
                                end,
                            },
                        },
                    },
                    -- 公告内容
                    UI.Panel {
                        width = "100%",
                        padding = sz(14),
                        flexDirection = "column",
                        gap = sz(0),
                        children = itemNodes,
                    },
                    -- 底部关闭按钮
                    UI.Panel {
                        width = "100%",
                        paddingBottom = sz(12), paddingTop = sz(4),
                        alignItems = "center",
                        children = {
                            UI.Button {
                                text = "知道了",
                                width = sz(90), height = sz(30),
                                fontSize = sz(12),
                                backgroundColor = { 255, 200, 60, 230 },
                                fontColor = { 20, 15, 5, 255 },
                                fontWeight = "bold",
                                borderRadius = sz(4),
                                onClick = function()
                                    Utils.PlayClick()
                                    visible = false
                                    overlay:SetVisible(false)
                                end,
                            },
                        },
                    },
                },
            },
        },
    }
    return overlay
end

function MenuScreen.Show(onStartCallback, onWarehouseCallback, onCharacterCallback, onPropCallback, onBackpackCallback)
    UIState.currentScreen = "menu"
    local C = Config.COLORS
    local sz = Utils.sz

    -- 左下角导航按钮组（合并为一行，竖线分隔）
    local function MakeNavItem(label, sub, onClickFn)
        return UI.Panel {
            height = "100%",
            flexDirection = "column",
            alignItems = "center", justifyContent = "center",
            gap = sz(2),
            paddingHorizontal = sz(18),
            cursor = "pointer",
            onClick = function()
                Utils.PlayClick()
                if onClickFn then onClickFn() end
            end,
            children = {
                UI.Label {
                    text = label,
                    fontSize = sz(10), fontWeight = "bold",
                    fontColor = { 235, 210, 135, 255 },
                    letterSpacing = 1,
                },
                UI.Label {
                    text = sub,
                    fontSize = sz(5),
                    fontColor = { 195, 162, 72, 200 },
                    letterSpacing = sz(1.5),
                },
            },
        }
    end

    local navBar = UI.Panel {
        position = "absolute", left = sz(8), bottom = sz(8),
        height = sz(38),
        flexDirection = "row",
        alignItems = "center",
        backgroundColor = { 18, 12, 6, 215 },
        borderWidth = 1,
        borderColor = { 110, 88, 45, 110 },
        borderRadius = sz(4),
        overflow = "hidden",
        children = {
            MakeNavItem("仓库", "STORAGE", onWarehouseCallback),
            -- 竖线分隔
            UI.Panel {
                width = 1, height = "60%",
                backgroundColor = { 110, 88, 45, 150 },
                flexShrink = 0,
            },
            MakeNavItem("角色", "CHARACTER", onCharacterCallback),
            -- 竖线分隔
            UI.Panel {
                width = 1, height = "60%",
                backgroundColor = { 110, 88, 45, 150 },
                flexShrink = 0,
            },
            MakeNavItem("商店", "STORE", onPropCallback),
            -- 竖线分隔
            UI.Panel {
                width = 1, height = "60%",
                backgroundColor = { 110, 88, 45, 150 },
                flexShrink = 0,
            },
            MakeNavItem("背包", "BAG", onBackpackCallback),
        },
    }

    local menuRoot = UI.Panel {
        width = "100%", height = "100%",
        backgroundColor = { 18, 18, 22, 255 },
        backgroundImage = "main_hall_bg_20260319134729.jpg",
        backgroundFit = "cover",
        children = {
            navBar,
            -- 右下角：排行榜 + 竞拍按钮组
            UI.Panel {
                position = "absolute",
                right = "2%", bottom = "2%",
                flexDirection = "column",
                alignItems = "flex-end",
                gap = Utils.sz(6),
                children = {
                    UI.Button {
                        text = "排行榜",
                        width = Utils.sz(120), height = Utils.sz(36),
                        fontSize = Utils.sz(14),
                        backgroundColor = { 0, 0, 0, 100 },
                        fontColor = { 220, 200, 140, 255 },
                        borderWidth = 1,
                        borderColor = { 160, 140, 80, 120 },
                        borderRadius = 0,
                        onClick = function()
                            Utils.PlayClick()
                            LeaderboardPanel.Show()
                        end,
                    },
                    UI.Button {
                        text = "竞拍 »",
                        width = Utils.sz(140), height = Utils.sz(55),
                        fontSize = Utils.sz(20),
                        fontWeight = "bold",
                        backgroundColor = { 200, 210, 0, 240 },
                        fontColor = { 15, 15, 10, 255 },
                        borderWidth = 0,
                        borderRadius = Utils.sz(4),
                        onClick = function()
                            Utils.PlayClick()
                            if onStartCallback then onStartCallback() end
                        end,
                    },
                },
            },
            UI.Panel {
                position = "absolute",
                left = Utils.sz(8), top = Utils.sz(8),
                flexDirection = "column",
                alignItems = "flex-start",
                gap = Utils.sz(5),
                children = {
                    -- 第一行：角色头像 + 玩家昵称/UID + 设置 + 金币
                    (function()
                        -- 角色头像（游戏角色）
                        local charIdx    = UIState.selectedCharIdx or 1
                        local chars      = Config.CHARACTERS or {}
                        local selChar    = chars[charIdx] or chars[1] or {}
                        local avatarPath = selChar.avatar or "Textures/characters/ye_lingxi.png"

                        -- 玩家昵称 + UID（异步填充）
                        local nickLbl = UI.Label {
                            text = "—",
                            fontSize = Utils.sz(13), fontWeight = "bold",
                            fontColor = { 235, 210, 135, 255 },
                            pointerEvents = "none",
                        }
                        local uidLbl = UI.Label {
                            text = "",
                            fontSize = Utils.sz(10),
                            fontColor = { 170, 155, 110, 200 },
                            pointerEvents = "none",
                        }
                        local myUserId = (lobby and lobby:GetMyUserId()) or 0
                        if myUserId ~= 0 then
                            uidLbl.text = "UID: " .. tostring(myUserId)
                            GetUserNickname({
                                userIds  = { myUserId },
                                onSuccess = function(nicks)
                                    if nicks and #nicks > 0 and nicks[1].nickname then
                                        nickLbl.text = nicks[1].nickname
                                    end
                                end,
                                onError = function() end,
                            })
                        else
                            nickLbl.text = "游客"
                        end

                        local playerInfoPanel = UI.Panel {
                            flexDirection = "row",
                            alignItems = "center",
                            gap = Utils.sz(8),
                            cursor = "pointer",
                            backgroundColor = { 18, 12, 6, 215 },
                            borderWidth = 1,
                            borderColor = { 110, 88, 45, 110 },
                            borderRadius = Utils.sz(4),
                            paddingRight = Utils.sz(10),
                            overflow = "hidden",
                            onClick = function()
                                Utils.PlayClick()
                                PersonalInfoScreen.Show()
                            end,
                            children = {
                                -- 角色头像
                                UI.Panel {
                                    width = Utils.sz(38), height = Utils.sz(38),
                                    borderRadius = 0,
                                    overflow = "hidden",
                                    flexShrink = 0,
                                    backgroundImage = avatarPath,
                                    backgroundFit = "cover",
                                },
                                -- 玩家昵称 + UID（纵向）
                                UI.Panel {
                                    flexDirection = "column",
                                    gap = Utils.sz(2),
                                    children = { nickLbl, uidLbl },
                                },
                            },
                        }

                        return UI.Panel {
                            flexDirection = "row",
                            alignItems = "center",
                            gap = Utils.sz(8),
                            children = {
                                playerInfoPanel,
                                SettingsPanel.CreateButton(),
                                -- 邮件按钮
                                (function()
                                    local hasUnclaimed = SaveSystem.GetUnclaimedMailCount() > 0
                                    local badge = UI.Panel {
                                        position = "absolute", top = Utils.sz(2), right = Utils.sz(2),
                                        width = Utils.sz(8), height = Utils.sz(8),
                                        borderRadius = Utils.sz(4),
                                        backgroundColor = { 210, 50, 50, 240 },
                                        visible = hasUnclaimed,
                                        pointerEvents = "none",
                                    }
                                    return UI.Panel {
                                        width = Utils.sz(36), height = Utils.sz(36),
                                        borderRadius = Utils.sz(6),
                                        backgroundColor = { 20, 24, 38, 180 },
                                        borderWidth = 1,
                                        borderColor = { 70, 85, 130, 160 },
                                        justifyContent = "center",
                                        alignItems = "center",
                                        cursor = "pointer",
                                        onClick = function()
                                            Utils.PlayClick()
                                            MailPanel.Show(function()
                                                MenuScreen.Show(onStartCallback, onWarehouseCallback, onCharacterCallback, onPropCallback, onBackpackCallback)
                                            end)
                                        end,
                                        children = {
                                            UI.Panel {
                                                width = Utils.sz(22), height = Utils.sz(22),
                                                backgroundImage = "image/nav_mail_20260520191948.png",
                                                backgroundSize = "contain",
                                            },
                                            badge,
                                        },
                                    }
                                end)(),
                                MoneyHUD.CreatePanel(),
                                MoneyHUD.CreateTicketPanel(),
                            },
                        }
                    end)(),
                    -- 第二行：奖励中心 + 公告 + 任务 + 通行证
                    UI.Panel {
                        flexDirection = "row",
                        alignItems = "center",
                        gap = Utils.sz(8),
                        children = {
                            -- 奖励中心（合并广告卡/在线奖励/版本奖励）
                            (function()
                                local hasReward = AdCardPanel.HasClaimable()
                                    or OnlineRewardPanel.HasClaimable()
                                    or VersionRewardPanel.HasClaimable()

                                -- 红点：始终创建，通过 SetVisible 动态控制
                                _badgeReward = UI.Panel {
                                    position = "absolute", top = Utils.sz(2), right = Utils.sz(2),
                                    width = Utils.sz(8), height = Utils.sz(8),
                                    borderRadius = Utils.sz(4),
                                    backgroundColor = { 230, 50, 50, 255 },
                                    visible = hasReward,
                                    pointerEvents = "none",
                                }

                                local btn = UI.Panel {
                                    paddingHorizontal = Utils.sz(10), paddingVertical = Utils.sz(4),
                                    flexDirection = "column", alignItems = "center",
                                    justifyContent = "center", gap = Utils.sz(2),
                                    cursor = "pointer",
                                    backgroundColor = { 20, 24, 38, 180 },
                                    borderWidth = 1, borderColor = hasReward and { 220, 80, 80, 200 } or { 70, 85, 130, 160 },
                                    borderRadius = Utils.sz(6),
                                    onClick = function()
                                        Utils.PlayClick()
                                        RewardScreen.Show(function()
                                            MenuScreen.Show(onStartCallback, onWarehouseCallback, onCharacterCallback, onPropCallback, onBackpackCallback)
                                        end)
                                    end,
                                    children = {
                                        UI.Panel {
                                            width = Utils.sz(26), height = Utils.sz(26),
                                            backgroundImage = "image/nav_reward_20260515210532.png",
                                            backgroundFit = "contain",
                                            pointerEvents = "none",
                                        },
                                        UI.Label {
                                            text = "奖励",
                                            fontSize = Utils.sz(11), fontColor = { 200, 205, 220, 200 },
                                            pointerEvents = "none",
                                        },
                                        _badgeReward,
                                    },
                                }
                                _badgeBorderReward = btn
                                return btn
                            end)(),
                            TaskPanel.CreateButton(),
                            -- 通行证入口按钮
                            (function()
                                local hasPass = SeasonPassPanel.HasClaimable()

                                -- 红点：始终创建，通过 SetVisible 动态控制
                                _badgePass = UI.Panel {
                                    position = "absolute", top = Utils.sz(2), right = Utils.sz(2),
                                    width = Utils.sz(8), height = Utils.sz(8),
                                    borderRadius = Utils.sz(4),
                                    backgroundColor = { 230, 50, 50, 255 },
                                    visible = hasPass,
                                    pointerEvents = "none",
                                }

                                local btn = UI.Panel {
                                    paddingHorizontal = Utils.sz(10), paddingVertical = Utils.sz(4),
                                    flexDirection = "column", alignItems = "center",
                                    justifyContent = "center", gap = Utils.sz(2),
                                    cursor = "pointer",
                                    backgroundColor = { 20, 24, 38, 180 },
                                    borderWidth = 1, borderColor = hasPass and { 220, 80, 80, 200 } or { 70, 85, 130, 160 },
                                    borderRadius = Utils.sz(6),
                                    onClick = function()
                                        Utils.PlayClick()
                                        SeasonPassPanel.Show(function()
                                            MenuScreen.Show(onStartCallback, onWarehouseCallback, onCharacterCallback, onPropCallback, onBackpackCallback)
                                        end)
                                    end,
                                    children = {
                                        UI.Panel {
                                            width = Utils.sz(26), height = Utils.sz(26),
                                            backgroundImage = "image/season_pass_icon_white_20260518191343.png",
                                            backgroundFit = "contain",
                                            pointerEvents = "none",
                                        },
                                        UI.Label {
                                            text = "通行证",
                                            fontSize = Utils.sz(11), fontColor = { 200, 205, 220, 200 },
                                            pointerEvents = "none",
                                        },
                                        _badgePass,
                                    },
                                }
                                _badgeBorderPass = btn
                                return btn
                            end)(),
                        },
                    },
                },
            },
            SettingsPanel.CreatePopup(),
            MoneyHUD.CreatePopup(),
            TaskPanel.CreatePopup(),
            TicketTooltip.CreateOverlay(),
            -- 排行榜全屏（置于最顶层，覆盖所有弹窗）
            LeaderboardPanel.Create(),
        }
    }
    UI.SetRoot(UI.SafeAreaView {
        edges = "all", width = "100%", height = "100%",
        children = { menuRoot, DebugPanel.CreateHUD() },
    })
end

return MenuScreen
