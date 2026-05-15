-- ============================================================================
-- UI/VersionRewardPanel.lua - 版本更新奖励系统（按钮 + 弹窗 + 云端读写）
-- 每个版本所有用户可领取一次，支持领取最新三个版本的奖励
-- ============================================================================

---@diagnostic disable: undefined-global

local UI = require("urhox-libs/UI")
local Config = require("Config")
local Utils = require("UI.Utils")
local MoneyHUD = require("UI.MoneyHUD")
local MoneyManager = require("MoneyManager")
local SaveSystem = require("SaveSystem")

local VersionRewardPanel = {}

local C = Config.COLORS

-- ============================================================================
-- 版本奖励配置
-- 按版本号从新到旧排列，只保留最新 3 个版本
-- ============================================================================

local VERSION_REWARDS = {
    { version = "1.1.20", coins = 2000000, charCoins = 5, label = "v1.1.20 更新奖励" },
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

    -- 通过统一入口加金币 + 持久化（自动乐观更新 + 失败回滚）
    MoneyManager.AddMoneyFromMenu(vr.coins, "版本奖励", {
        batchSetup = function(batch)
            batch:SetInt(CloudKey(vr.version), 1)
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
            print("[VersionReward] Claimed " .. vr.version .. " +" .. vr.coins .. " coins, +" .. (vr.charCoins or 0) .. " charCoins")
        end,
        error = function(code, reason)
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
                    row.btn:SetText("领取 " .. Utils.FormatMoney(vr.coins))
                end
            end
        end
    end

    -- 刷新按钮红点
    if btnBadge then
        btnBadge:SetVisible(HasUnclaimedRewards())
    end
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
        height = sz(38),
        backgroundColor = { 0, 0, 0, 120 },
        borderRadius = 0,
        paddingHorizontal = sz(14),
        flexDirection = "row",
        alignItems = "center",
        cursor = "pointer",
        onClick = function()
            Utils.PlayClick()
            popupVisible = not popupVisible
            if popupOverlay then
                popupOverlay:SetVisible(popupVisible)
                if popupVisible then VersionRewardPanel.RefreshAll() end
            end
        end,
        children = {
            UI.Label {
                text = "版本奖励",
                fontSize = sz(15), fontColor = { 200, 205, 220, 220 },
                pointerEvents = "none",
            },
            btnBadge,
        },
    }
end

function VersionRewardPanel.CreatePopup()
    -- 构建每个版本的奖励行
    local rowChildren = {}
    rewardRows = {}

    for i, vr in ipairs(VERSION_REWARDS) do
        local claimBtn = UI.Button {
            text = "加载中...",
            width = 120, height = 30, fontSize = 11,
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
            paddingVertical = 6,
            children = {
                UI.Panel {
                    flexDirection = "column", gap = 2,
                    flexShrink = 1,
                    children = {
                        UI.Label {
                            text = vr.label,
                            fontSize = 13, fontColor = C.textPrimary,
                        },
                        UI.Panel {
                            flexDirection = "row", alignItems = "center", gap = 8,
                            children = {
                                UI.Panel {
                                    flexDirection = "row", alignItems = "center", gap = 4,
                                    children = {
                                        UI.Panel {
                                            width = 14, height = 14,
                                            backgroundImage = Utils.GetIcon("coin"),
                                            backgroundFit = "contain",
                                            flexShrink = 0,
                                        },
                                        UI.Label {
                                            text = Utils.FormatMoney(vr.coins),
                                            fontSize = 12, fontColor = { 255, 220, 100, 255 },
                                        },
                                    },
                                },
                                vr.charCoins and UI.Panel {
                                    flexDirection = "row", alignItems = "center", gap = 3,
                                    children = {
                                        UI.Panel {
                                            width = 14, height = 14,
                                            backgroundImage = Config.CHARACTER_COIN_ICON,
                                            backgroundFit = "contain",
                                            flexShrink = 0,
                                        },
                                        UI.Label {
                                            text = "+" .. vr.charCoins,
                                            fontSize = 12, fontColor = { 150, 200, 255, 255 },
                                        },
                                    },
                                } or nil,
                            },
                        },
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
        width = 300,
        backgroundColor = C.bgPanel,
        borderRadius = 0,
        padding = 20, gap = 10,
        flexDirection = "column",
        alignItems = "center",
        children = {
            UI.Label {
                text = "版本更新奖励", fontSize = 16, fontWeight = "bold",
                fontColor = C.textPrimary,
            },
            UI.Panel { width = "100%", height = 1, backgroundColor = { 60, 70, 100, 150 } },
            UI.Panel {
                width = "100%", flexDirection = "column",
                children = rowChildren,
            },
            UI.Button {
                text = "关闭", width = "100%", height = 36, fontSize = 13,
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

return VersionRewardPanel
