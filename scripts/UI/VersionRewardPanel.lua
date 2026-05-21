-- ============================================================================
-- UI/VersionRewardPanel.lua - 版本更新奖励系统（按钮 + 弹窗 + 云端读写）
-- 每个版本所有用户可领取一次，支持领取最新三个版本的奖励
-- ============================================================================

---@diagnostic disable: undefined-global

local UI = require("urhox-libs/UI")
local Config = require("Config")
local RewardSlotWidget = require("UI.RewardSlot")
local Utils = require("UI.Utils")
local MoneyHUD = require("UI.MoneyHUD")
local MoneyManager = require("MoneyManager")
local SaveSystem = require("SaveSystem")
local Props = require("Config.Props")
local PropSystem = require("PropSystem")
local SaveFramework = require("SaveFramework")
local PropCardWidget = require("UI.PropCardWidget")

local VersionRewardPanel = {}

-- 延迟引用 MenuScreen，避免循环依赖（MenuScreen require VersionRewardPanel，
-- 因此这里不能在模块顶层 require MenuScreen）
local function NotifyMenuBadges()
    local ok, MenuScreen = pcall(require, "UI.MenuScreen")
    if ok and MenuScreen and MenuScreen.RefreshBadges then
        MenuScreen.RefreshBadges()
    end
end

local C = Config.COLORS

-- ============================================================================
-- 版本公告（原位于 MenuScreen，统一迁移到此处）
-- ============================================================================
VersionRewardPanel.ANNOUNCEMENTS = {
    {
        date  = "2026-05-16",
        title = "v1.5 更新公告",
        items = {
            "新增道具系统，可在商店购买情报道具辅助竞拍",
            "优化界面显示与操作体验",
        },
    },
}

-- ============================================================================
-- 版本奖励配置
-- 按版本号从新到旧排列，只保留最新 3 个版本
-- ============================================================================

local VERSION_REWARDS = {
    {
        version = "1.1.22",
        coins = 0,
        label = "v1.1.22 更新奖励",
        props = {
            { id = "xray_4_silhouette",      count = 3 },
            { id = "scout_blue_cells",        count = 3 },
            { id = "dual_item_reveal",        count = 3 },
            { id = "avg_cell_blue",           count = 3 },
            { id = "avg_cell_purple",         count = 3 },
            { id = "avg_cell_white_green",    count = 3 },
            { id = "total_value_green",       count = 3 },
            { id = "prop_box_green",          count = 3 },
            { id = "collectible_cloisonne_tea",  count = 3 },
            { id = "collectible_vintage_car",    count = 3 },
            { id = "collectible_herbal_atlas",   count = 3 },
        },
    },
}

-- 云端键名前缀：ver_reward_1_0_7 = 1 表示已领取
local function CloudKey(version)
    return "ver_reward_" .. version:gsub("%.", "_")
end

-- ============================================================================
-- 状态
-- ============================================================================

local cloudLoaded = false
local claimedMap = {}   -- { ["1.0.7"] = true, ... }
local popupVisible = false

-- UI 引用
local popupOverlay = nil
local rewardRows = {}   -- { btn, statusLabel } per version
local btnBadge = nil     -- 按钮上的红点

-- ============================================================================
-- 初始化（从云端加载已领取记录）
-- ============================================================================

function VersionRewardPanel.Init()
    cloudLoaded = false
    claimedMap = {}

    if not clientCloud then
        cloudLoaded = true
        return
    end

    local batch = clientCloud:BatchGet()
    for _, vr in ipairs(VERSION_REWARDS) do
        batch:Key(CloudKey(vr.version))
    end
    batch:Fetch({
        ok = function(values, iscores)
            for _, vr in ipairs(VERSION_REWARDS) do
                local key = CloudKey(vr.version)
                local val = iscores[key]
                if val and val > 0 then
                    claimedMap[vr.version] = true
                end
            end
            cloudLoaded = true
            VersionRewardPanel.RefreshAll()
            print("[VersionReward] Cloud loaded, claimed: " .. VersionRewardPanel.ClaimedCount() .. "/" .. #VERSION_REWARDS)
        end,
        error = function(code, reason)
            cloudLoaded = true
            print("[VersionReward] Cloud load failed: " .. tostring(reason))
        end,
    })
end

function VersionRewardPanel.ClaimedCount()
    local count = 0
    for _, vr in ipairs(VERSION_REWARDS) do
        if claimedMap[vr.version] then count = count + 1 end
    end
    return count
end

local function HasUnclaimedRewards()
    if not cloudLoaded then return false end
    for _, vr in ipairs(VERSION_REWARDS) do
        if not claimedMap[vr.version] then return true end
    end
    return false
end

-- ============================================================================
-- 领取奖励
-- ============================================================================

local function ClaimReward(vr, idx)
    if not cloudLoaded or claimedMap[vr.version] then return end

    local row = rewardRows[idx]
    if row and row.btn then row.btn:SetDisabled(true) end

    -- 先发放道具（本地）
    if vr.props and #vr.props > 0 then
        for _, pr in ipairs(vr.props) do
            SaveSystem.AddProp(pr.id, pr.count)
        end
    end

    -- 通过统一入口加金币 + 持久化（自动乐观更新 + 失败回滚）
    MoneyManager.AddMoneyFromMenu(vr.coins, "版本奖励", {
        batchSetup = function(batch)
            batch:SetInt(CloudKey(vr.version), 1)
            -- 道具数据写入云端
            SaveSystem.WriteToBatch(batch)
        end,
        ok = function()
            claimedMap[vr.version] = true
            -- 发放角色币
            if vr.charCoins and vr.charCoins > 0 then
                SaveSystem.AddCharacterCoins(vr.charCoins)
                SaveSystem.Save()
            end
            VersionRewardPanel.RefreshAll()
            Utils.PlaySfx("bid_success")
            print("[VersionReward] Claimed " .. vr.version .. " props + " .. vr.coins .. " coins")
        end,
        error = function(code, reason)
            -- 回滚道具
            if vr.props and #vr.props > 0 then
                for _, pr in ipairs(vr.props) do
                    SaveSystem.AddProp(pr.id, -pr.count)
                end
            end
            if row and row.btn then row.btn:SetDisabled(false) end
            print("[VersionReward] Claim failed: " .. tostring(reason))
        end,
    })
end

-- ============================================================================
-- 刷新 UI
-- ============================================================================

function VersionRewardPanel.RefreshAll()
    -- 刷新弹窗内各行 — 脏检查，避免无意义 SetStyle 吞掉点击事件
    for i, vr in ipairs(VERSION_REWARDS) do
        local row = rewardRows[i]
        if row then
            local claimed = claimedMap[vr.version] and true or false
            if claimed ~= row.lastClaimed then
                row.lastClaimed = claimed
                if claimed then
                    row.btn:SetDisabled(true)
                    row.btn:SetText("已领取")
                else
                    row.btn:SetDisabled(false)
                    if vr.coins and vr.coins > 0 then
                        row.btn:SetText("领取 " .. Utils.FormatMoney(vr.coins))
                    else
                        row.btn:SetText("领取")
                    end
                end
            end
        end
    end

    -- 刷新按钮红点
    if btnBadge then
        btnBadge:SetVisible(HasUnclaimedRewards())
    end

    -- 通知 MenuScreen 刷新顶层红点（async 数据到位后补显）
    NotifyMenuBadges()
end

-- ============================================================================
-- 创建 UI
-- ============================================================================

function VersionRewardPanel.CreateButton()
    local sz = Utils.sz
    -- 重置弹窗状态，防止跨界面残留
    popupVisible = false

    btnBadge = UI.Panel {
        position = "absolute",
        right = -3, top = -3,
        width = sz(10), height = sz(10),
        borderRadius = sz(5),
        backgroundColor = { 255, 60, 60, 255 },
        visible = false,
        pointerEvents = "none",
    }

    -- 云端已加载时立即刷新红点状态
    if cloudLoaded then
        btnBadge:SetVisible(HasUnclaimedRewards())
    end

    return UI.Panel {
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
            popupVisible = not popupVisible
            if popupOverlay then
                popupOverlay:SetVisible(popupVisible)
                if popupVisible then VersionRewardPanel.RefreshAll() end
            end
        end,
        children = {
            UI.Panel {
                width = sz(26), height = sz(26),
                backgroundImage = "image/nav_reward_20260515210532.png",
                backgroundFit = "contain",
                pointerEvents = "none",
                children = { btnBadge },
            },
            UI.Label {
                text = "版本奖励",
                fontSize = sz(11), fontColor = { 200, 205, 220, 200 },
                pointerEvents = "none",
            },
        },
    }
end

function VersionRewardPanel.CreatePopup()
    local sz = Utils.sz
    -- 构建每个版本的奖励行
    local rowChildren = {}
    rewardRows = {}

    for i, vr in ipairs(VERSION_REWARDS) do
        local claimBtn = UI.Button {
            text = "加载中...",
            width = sz(120), height = sz(30), fontSize = sz(11),
            variant = "primary",
            disabled = true,
            onClick = function()
                Utils.PlayClick()
                ClaimReward(vr, i)
            end,
        }

        rewardRows[i] = { btn = claimBtn }

        rowChildren[#rowChildren + 1] = UI.Panel {
            width = "100%",
            flexDirection = "row",
            alignItems = "center",
            justifyContent = "space-between",
            paddingVertical = sz(6),
            children = {
                UI.Panel {
                    flexDirection = "column", gap = sz(2),
                    flexShrink = 1,
                    children = {
                        UI.Label {
                            text = vr.label,
                            fontSize = sz(13), fontColor = C.textPrimary,
                        },
                        -- 奖励内容：道具或金币
                        (function()
                            if vr.props and #vr.props > 0 then
                                local propItems = {}
                                for _, pr in ipairs(vr.props) do
                                    local pInfo = Props.BY_ID[pr.id]
                                    if pInfo then
                                        table.insert(propItems, PropCardWidget.RewardPropItem {
                                            def = pInfo, count = pr.count,
                                        })
                                    end
                                end
                                return UI.Panel {
                                    flexDirection = "row", flexWrap = "wrap", gap = sz(6),
                                    children = propItems,
                                }
                            end
                            if vr.coins and vr.coins > 0 then
                                return UI.Panel {
                                    flexDirection = "row", alignItems = "center", gap = sz(4),
                                    children = {
                                        UI.Panel {
                                            width = sz(14), height = sz(14),
                                            backgroundImage = Utils.GetIcon("coin"),
                                            backgroundFit = "contain",
                                            flexShrink = 0,
                                        },
                                        UI.Label {
                                            text = Utils.FormatMoney(vr.coins),
                                            fontSize = sz(12), fontColor = { 255, 220, 100, 255 },
                                        },
                                    },
                                }
                            end
                            return nil
                        end)(),
                    },
                },
                claimBtn,
            },
        }

        -- 分隔线（最后一行不加）
        if i < #VERSION_REWARDS then
            rowChildren[#rowChildren + 1] = UI.Panel {
                width = "100%", height = 1,
                backgroundColor = { 60, 70, 100, 100 },
            }
        end
    end

    local popupContent = UI.Panel {
        width = sz(380),
        backgroundColor = C.bgPanel,
        borderRadius = 0,
        padding = sz(20), gap = sz(10),
        flexDirection = "column",
        alignItems = "center",
        children = {
            UI.Label {
                text = "版本更新奖励", fontSize = sz(16), fontWeight = "bold",
                fontColor = C.textPrimary,
            },
            UI.Panel { width = "100%", height = 1, backgroundColor = { 60, 70, 100, 150 } },
            UI.Panel {
                width = "100%", flexDirection = "column",
                children = rowChildren,
            },
            UI.Button {
                text = "关闭", width = "100%", height = sz(36), fontSize = sz(13),
                variant = "secondary",
                onClick = function()
                    Utils.PlayClick()
                    popupVisible = false
                    if popupOverlay then popupOverlay:SetVisible(false) end
                end,
            },
        },
    }

    popupOverlay = UI.Panel {
        position = "absolute",
        left = 0, top = 0,
        width = "100%", height = "100%",
        backgroundColor = { 0, 0, 0, 120 },
        justifyContent = "center",
        alignItems = "center",
        visible = false,
        onClick = function()
            popupVisible = false
            popupOverlay:SetVisible(false)
        end,
        children = {
            UI.Panel {
                onClick = function() end,
                children = { popupContent },
            },
        },
    }

    return popupOverlay
end

-- ============================================================================
-- 创建内嵌内容视图（供 RewardScreen 使用，包含公告 + 版本奖励列表）
-- ============================================================================

function VersionRewardPanel.CreateContent()
    local sz = Utils.sz
    rewardRows = {}

    -- 公告区域
    local annItemNodes = {}
    for _, ann in ipairs(VersionRewardPanel.ANNOUNCEMENTS) do
        table.insert(annItemNodes, UI.Panel {
            width = "100%", flexDirection = "row", alignItems = "center",
            gap = sz(6), marginBottom = sz(4),
            children = {
                UI.Panel { width = sz(3), height = sz(14), backgroundColor = { 255, 200, 60, 255 }, borderRadius = sz(2), flexShrink = 0 },
                UI.Label {
                    text = ann.title .. "  " .. ann.date,
                    fontSize = sz(13), fontColor = { 255, 220, 120, 255 }, fontWeight = "bold",
                },
            },
        })
        for _, item in ipairs(ann.items) do
            table.insert(annItemNodes, UI.Panel {
                width = "100%", flexDirection = "row", alignItems = "flex-start",
                gap = sz(6), marginBottom = sz(5),
                children = {
                    UI.Label { text = "•", fontSize = sz(12), fontColor = { 160, 200, 255, 220 }, marginTop = sz(1), flexShrink = 0 },
                    UI.Label { text = item, fontSize = sz(12), fontColor = { 210, 215, 230, 240 }, flexShrink = 1 },
                },
            })
        end
    end

    local annSection = UI.Panel {
        width = "100%", flexShrink = 0,
        borderRadius = sz(6),
        borderWidth = 1, borderColor = { 60, 75, 120, 150 },
        marginBottom = sz(10),
        overflow = "hidden",
        children = {
            -- 背景纹理
            UI.Panel {
                position = "absolute", left = 0, top = 0,
                width = "100%", height = "100%",
                backgroundImage = "image/bg_texture_minimal_20260519075800.jpg",
                backgroundFit = "cover",
                pointerEvents = "none",
            },
            -- 深色遮罩
            UI.Panel {
                position = "absolute", left = 0, top = 0,
                width = "100%", height = "100%",
                backgroundColor = { 18, 22, 40, 185 },
                pointerEvents = "none",
            },
            -- 内容
            UI.Panel {
                width = "100%", flexDirection = "column",
                padding = sz(14), gap = sz(0),
                children = {
                    UI.Panel {
                        width = "100%", flexDirection = "row", alignItems = "center",
                        gap = sz(6), marginBottom = sz(8),
                        children = {
                            UI.Label { text = "版本公告", fontSize = sz(15), fontColor = { 230, 230, 245, 255 }, fontWeight = "bold" },
                        },
                    },
                    table.unpack(annItemNodes),
                },
            },
        },
    }

    -- 奖励格子（道具专用：PropCardWidget.HexIcon 作为图标内容）
    local function RewardSlot(pInfo, count)
        local tier = PropCardWidget.GetTierColors(pInfo)
        return RewardSlotWidget.Make({
            size       = 52,
            customIcon = PropCardWidget.HexIcon {
                frameSize = sz(36),
                hexTint   = tier.hexTint,
                iconImage = pInfo.iconImage,
                iconText  = pInfo.icon,
            },
            count = "×" .. tostring(count or 1),
        }, sz)
    end

    -- 版本奖励行
    local rowChildren = {}
    for i, vr in ipairs(VERSION_REWARDS) do
        local claimBtn = UI.Button {
            text = "加载中...",
            width = sz(72), height = sz(40), fontSize = sz(13),
            fontWeight = "bold",
            variant = "primary", disabled = true,
            onClick = function() Utils.PlayClick(); ClaimReward(vr, i) end,
        }
        rewardRows[i] = { btn = claimBtn }

        -- 奖励格子
        local rewardContent
        if vr.props and #vr.props > 0 then
            local slots = {}
            for _, pr in ipairs(vr.props) do
                local pInfo = Props.BY_ID[pr.id]
                if pInfo then
                    slots[#slots + 1] = RewardSlot(pInfo, pr.count)
                end
            end
            rewardContent = UI.Panel {
                flexDirection = "row", flexWrap = "wrap", gap = sz(4),
                pointerEvents = "none",
                children = slots,
            }
        elseif vr.coins and vr.coins > 0 then
            rewardContent = UI.Panel {
                flexDirection = "row", alignItems = "center", gap = sz(4),
                pointerEvents = "none",
                children = {
                    UI.Panel { width = sz(14), height = sz(14), backgroundImage = Utils.GetIcon("coin"), backgroundFit = "contain", flexShrink = 0 },
                    UI.Label { text = Utils.FormatMoney(vr.coins), fontSize = sz(12), fontColor = { 255, 220, 100, 255 } },
                },
            }
        else
            rewardContent = UI.Panel {}
        end

        rowChildren[#rowChildren + 1] = UI.Panel {
            width = "100%", flexDirection = "row", alignItems = "center",
            paddingVertical = sz(12), paddingLeft = sz(14), paddingRight = sz(12),
            backgroundImage = "image/task_row_bg_20260516173338.png",
            backgroundFit = "cover",
            marginBottom = sz(8),
            borderRadius = sz(6),
            overflow = "hidden",
            children = {
                -- 左侧竖线装饰
                UI.Panel {
                    width = sz(3), alignSelf = "stretch", flexShrink = 0,
                    backgroundColor = { 90, 95, 110, 160 },
                    marginRight = sz(12),
                    borderRadius = sz(2),
                    pointerEvents = "none",
                },
                -- 中间：版本标签 + 奖励格子
                UI.Panel {
                    flex = 1, flexShrink = 1,
                    flexDirection = "column", gap = sz(8),
                    justifyContent = "center",
                    pointerEvents = "none",
                    children = {
                        UI.Label { text = vr.label, fontSize = sz(13), fontColor = C.textPrimary, fontWeight = "bold", pointerEvents = "none" },
                        rewardContent,
                    },
                },
                -- 右侧：领取按钮
                claimBtn,
            },
        }
    end

    local content = UI.Panel {
        width = "100%", height = "100%",
        flexDirection = "column",
        children = {
            -- 标题行
            UI.Panel {
                width = "100%", flexShrink = 0,
                flexDirection = "row", alignItems = "center", gap = sz(8),
                paddingBottom = sz(10),
                borderBottomWidth = 1, borderColor = { 50, 60, 100, 120 },
                marginBottom = sz(10),
                children = {
                    UI.Label { text = "版本奖励", fontSize = sz(16), fontColor = C.textPrimary, fontWeight = "bold" },
                },
            },
            -- 可滚动内容
            UI.ScrollView {
                width = "100%", flex = 1, flexShrink = 1, scrollY = true,
                scrollbarInteractive = false,
                children = {
                    UI.Panel {
                        width = "100%", flexDirection = "column",
                        children = {
                            annSection,
                            -- 版本奖励区
                            UI.Panel {
                                width = "100%", flexShrink = 0,
                                flexDirection = "column", gap = sz(2),
                                children = rowChildren,
                            },
                        },
                    },
                },
            },
        },
    }

    if cloudLoaded then VersionRewardPanel.RefreshAll() end
    return content
end

function VersionRewardPanel.HasClaimable()
    return HasUnclaimedRewards()
end

return VersionRewardPanel
