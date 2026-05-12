-- ============================================================================
-- UI/OnlineRewardPanel.lua - 在线时长奖励系统（按钮 + 弹窗 + 云端）
-- 在线一定时长后可领取里程碑奖励，每日重置，在线时间云端持久化
-- ============================================================================

---@diagnostic disable: undefined-global

local UI = require("urhox-libs/UI")
local Config = require("Config")
local MoneyHUD = require("UI.MoneyHUD")
local MoneyManager = require("MoneyManager")
local Utils = require("UI.Utils")
local FloatingMessage = require("UI.FloatingMessage")
local SaveFramework = require("SaveFramework")

local OnlineRewardPanel = {}

local OC = Config.ONLINE_REWARD
local C = Config.COLORS

-- ============================================================================
-- 云端键名
-- ============================================================================
local KEY_CLAIMED_BITS  = "online_claimed"    -- 已领取里程碑位掩码（int）
local KEY_ONLINE_DATE   = "online_date"       -- 日期字符串（用于每日重置）
local KEY_ONLINE_SECS   = "online_secs"       -- 累计在线秒数（int）

local MODULE_NAME = "online_reward"

-- ============================================================================
-- 模块状态
-- ============================================================================
local cloudLoaded = false
local onlineSeconds = 0        -- 累计在线秒数（含云端恢复的）
local claimedBits = 0          -- 已领取的里程碑位掩码
local onlineDate = ""          -- 上次记录日期
local popupVisible = false

-- 云端同步
local CLOUD_SYNC_INTERVAL = 30 -- 每30秒同步一次在线时间到云端
local cloudSyncTimer = 0

-- UI 引用
local btnLabel = nil
local btnBadge = nil
local popupOverlay = nil
local milestoneRows = {}

-- ============================================================================
-- SaveFramework 注册
-- ============================================================================

SaveFramework.Register(MODULE_NAME, {
    cloudKeys = { KEY_CLAIMED_BITS, KEY_ONLINE_DATE, KEY_ONLINE_SECS },
    speculativeKeys = {},

    load = function(values, iscores)
        claimedBits  = iscores[KEY_CLAIMED_BITS] or 0
        onlineDate   = values[KEY_ONLINE_DATE] or ""
        local savedSecs = iscores[KEY_ONLINE_SECS] or 0

        local today = os.date("%Y-%m-%d")
        if onlineDate ~= today then
            claimedBits  = 0
            onlineDate   = today
            onlineSeconds = 0
            SaveFramework.MarkDirty(MODULE_NAME)
            print("[OnlineReward] Daily reset on load")
        else
            onlineSeconds = savedSecs
        end

        cloudLoaded = true
        pcall(OnlineRewardPanel.RefreshAll)
        print("[OnlineReward] Loaded: claimed=" .. claimedBits
            .. " secs=" .. math.floor(onlineSeconds))
    end,

    save = function(batch)
        batch:SetInt(KEY_CLAIMED_BITS, claimedBits)
        batch:SetInt(KEY_ONLINE_SECS, math.floor(onlineSeconds))
        batch:Set(KEY_ONLINE_DATE, onlineDate)
    end,

    defaults = function()
        cloudLoaded = true
        onlineDate  = os.date("%Y-%m-%d")
        print("[OnlineReward] Defaults applied")
    end,
})

-- ============================================================================
-- 工具函数
-- ============================================================================

local function TodayStr()
    return os.date("%Y-%m-%d")
end

--- 检查日期变更并重置
local function CheckDailyReset()
    local today = TodayStr()
    if onlineDate ~= today then
        claimedBits = 0
        onlineDate = today
        onlineSeconds = 0
        return true
    end
    return false
end

--- 当前在线分钟数
local function GetOnlineMinutes()
    return onlineSeconds / 60
end

--- 格式化在线时长显示
local function FormatDuration(totalSeconds)
    local h = math.floor(totalSeconds / 3600)
    local m = math.floor((totalSeconds % 3600) / 60)
    local s = math.floor(totalSeconds % 60)
    if h > 0 then
        return string.format("%d:%02d:%02d", h, m, s)
    else
        return string.format("%d:%02d", m, s)
    end
end

--- 是否有可领取的里程碑
local function HasUnclaimedMilestones()
    if not cloudLoaded then return false end
    local mins = GetOnlineMinutes()
    for i, ms in ipairs(OC.MILESTONES) do
        local bit = 1 << (i - 1)
        if mins >= ms.minutes and (claimedBits & bit) == 0 then
            return true
        end
    end
    return false
end

--- 同步在线时间（标记脏，由 SaveFramework 延迟保存）
local function SyncOnlineTimeToCloud()
    if not cloudLoaded then return end
    SaveFramework.MarkDirty(MODULE_NAME)
    print("[OnlineReward] Marked dirty, secs=" .. math.floor(onlineSeconds))
end

-- ============================================================================
-- 初始化（数据已由 SaveFramework.Init 的 BatchGet 统一加载）
-- ============================================================================

function OnlineRewardPanel.Init()
    cloudSyncTimer = 0
    -- 数据由 SaveFramework.load 回调设置，此处仅重置计时器
    -- 若 SaveFramework 已加载完成则立即刷新 UI
    if cloudLoaded then
        OnlineRewardPanel.RefreshAll()
    end
end

-- ============================================================================
-- 每帧更新
-- ============================================================================

local resetCheckTimer = 0

function OnlineRewardPanel.Update(dt)
    onlineSeconds = onlineSeconds + dt

    -- 更新按钮文字（仅在按钮存活时）
    -- UI.SetRoot() 会销毁旧 UI 树，btnLabel/btnBadge 变为野引用
    -- 通过 pcall 检测并置 nil，避免崩溃传播导致引擎取消 HandleUpdate 订阅
    if btnLabel then
        local ok = pcall(btnLabel.SetText, btnLabel, FormatDuration(onlineSeconds))
        if not ok then
            btnLabel = nil
            btnBadge = nil
        end
    end

    -- 以下功能需要云端数据
    if not cloudLoaded then return end

    -- 每分钟检查日期变更
    resetCheckTimer = resetCheckTimer + dt
    if resetCheckTimer >= 60 then
        resetCheckTimer = 0
        if CheckDailyReset() then
            OnlineRewardPanel.RefreshAll()
        end
    end

    -- 定期同步在线时间到云端
    cloudSyncTimer = cloudSyncTimer + dt
    if cloudSyncTimer >= CLOUD_SYNC_INTERVAL then
        cloudSyncTimer = 0
        SyncOnlineTimeToCloud()
    end

    -- 刷新红点（检测 stale ref 同上）
    if btnBadge then
        local ok = pcall(btnBadge.SetVisible, btnBadge, HasUnclaimedMilestones())
        if not ok then
            btnBadge = nil
            btnLabel = nil
        end
    end

    -- 弹窗打开时更新在线时长显示
    OnlineRewardPanel.UpdatePopupDuration()
end

-- ============================================================================
-- 领取里程碑奖励
-- ============================================================================

local function ClaimMilestone(msIndex)
    local ms = OC.MILESTONES[msIndex]
    if not ms then return end

    local bit = 1 << (msIndex - 1)
    if (claimedBits & bit) ~= 0 then return end
    if GetOnlineMinutes() < ms.minutes then return end

    claimedBits = claimedBits | bit

    -- 先在本地乐观更新门票（确保同一次云端写入）
    local SaveSystem = require("SaveSystem")
    if ms.ticket then
        SaveSystem.AddTickets(ms.ticket, 1, true)  -- skipSave
    end

    MoneyManager.AddMoneyFromMenu(ms.coins, "在线奖励" .. ms.label, {
        batchSetup = function(batch)
            batch:SetInt(KEY_CLAIMED_BITS, claimedBits)
            batch:Set(KEY_ONLINE_DATE, onlineDate)
            batch:SetInt(KEY_ONLINE_SECS, math.floor(onlineSeconds))
            -- 门票数据一并写入
            if ms.ticket then
                SaveSystem.MarkDirty()
            end
        end,
        ok = function()
            OnlineRewardPanel.RefreshAll()
            Utils.PlaySfx("bid_success")
            local rewardMsg = ms.label .. "在线奖励: +" .. Utils.FormatMoney(ms.coins)
            if ms.ticket then
                rewardMsg = rewardMsg .. " +门票"
            end
            FloatingMessage.Show(rewardMsg)
            print("[OnlineReward] Milestone " .. ms.label .. " claimed!")
        end,
        error = function()
            claimedBits = claimedBits & ~bit
            -- 回滚门票
            if ms.ticket then
                SaveSystem.AddTickets(ms.ticket, -1, true)
            end
            OnlineRewardPanel.RefreshAll()
            FloatingMessage.Show("领取失败，请重试")
        end,
    })
end

-- ============================================================================
-- 刷新 UI
-- ============================================================================

function OnlineRewardPanel.RefreshAll()
    if not cloudLoaded then return end

    local mins = GetOnlineMinutes()

    -- 按钮红点（防 stale ref）
    if btnBadge then
        local ok = pcall(btnBadge.SetVisible, btnBadge, HasUnclaimedMilestones())
        if not ok then btnBadge = nil; btnLabel = nil end
    end

    -- 里程碑行 — 只在状态变化时更新，避免每帧 SetStyle 吞掉点击事件
    for i, ms in ipairs(OC.MILESTONES) do
        local row = milestoneRows[i]
        if row then
            local bit = 1 << (i - 1)
            local claimed = (claimedBits & bit) ~= 0
            local unlocked = mins >= ms.minutes

            local state = claimed and "claimed" or (unlocked and "unlocked" or "locked")

            if state ~= row.lastState then
                row.lastState = state
                if claimed then
                    row.btn:SetDisabled(true)
                    row.btn:SetText("已领取")
                    row.btn:SetStyle({
                        backgroundColor = { 60, 65, 80, 150 },
                        fontColor = { 120, 130, 150, 200 },
                    })
                elseif unlocked then
                    row.btn:SetDisabled(false)
                    row.btn:SetText("领取")
                    row.btn:SetStyle({
                        backgroundColor = { 220, 170, 50, 230 },
                        fontColor = { 30, 20, 0, 255 },
                    })
                else
                    row.btn:SetDisabled(true)
                    row.btn:SetText(ms.label)
                    row.btn:SetStyle({
                        backgroundColor = { 50, 55, 70, 180 },
                        fontColor = { 120, 130, 150, 200 },
                    })
                end
            end

            -- 进度条 — 只在百分比变化时更新
            local pct = math.min(100, math.floor(mins / ms.minutes * 100))
            if pct ~= (row.lastPct or -1) then
                row.lastPct = pct
                row.progressFill:SetStyle({ width = pct .. "%" })
            end
        end
    end
end

-- ============================================================================
-- 创建按钮（工具栏内联）
-- ============================================================================

function OnlineRewardPanel.CreateButton()
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

    btnLabel = UI.Label {
        text = FormatDuration(onlineSeconds),
        fontSize = sz(15), fontColor = { 200, 205, 220, 220 },
        pointerEvents = "none",
    }

    -- 云端已加载时立即刷新红点状态
    if cloudLoaded then
        btnBadge:SetVisible(HasUnclaimedMilestones())
    end

    return UI.Panel {
        height = sz(38),
        backgroundColor = { 0, 0, 0, 120 },
        borderRadius = 0,
        paddingHorizontal = sz(14),
        flexDirection = "row",
        alignItems = "center",
        gap = sz(5),
        cursor = "pointer",
        onClick = function()
            Utils.PlayClick()
            popupVisible = not popupVisible
            if popupOverlay then
                popupOverlay:SetVisible(popupVisible)
                if popupVisible then OnlineRewardPanel.RefreshAll() end
            end
        end,
        children = {
            UI.Label {
                text = "⏱", fontSize = sz(15),
                pointerEvents = "none",
            },
            btnLabel,
            btnBadge,
        },
    }
end

-- ============================================================================
-- 创建弹窗（横向卡片网格）
-- ============================================================================

function OnlineRewardPanel.CreatePopup()
    local sz = Utils.sz
    milestoneRows = {}

    -- 卡片宽度：7 个里程碑，4+3 排列
    local cardW = sz(68)
    local cardGap = sz(6)

    -- 里程碑卡片
    local msChildren = {}
    for i, ms in ipairs(OC.MILESTONES) do
        -- 图标
        local icon = "🎁"
        if ms.minutes >= 60 then icon = "🏆"
        elseif ms.minutes >= 10 then icon = "🎯"
        end

        -- 进度条填充
        local msFill = UI.Panel {
            width = "0%", height = "100%",
            backgroundColor = { 100, 210, 100, 180 },
        }

        -- 领取按钮
        local claimBtn = UI.Button {
            text = ms.label,
            width = "100%", height = sz(18),
            fontSize = sz(8),
            backgroundColor = { 50, 55, 70, 180 },
            fontColor = { 120, 130, 150, 200 },
            borderRadius = sz(2),
            disabled = true,
            onClick = function()
                Utils.PlayClick()
                ClaimMilestone(i)
            end,
        }

        -- 动态构建卡片子元素，避免 nil 空洞
        local cardChildren = {
            UI.Label {
                text = icon, fontSize = sz(16),
                pointerEvents = "none",
            },
            UI.Label {
                text = ms.label,
                fontSize = sz(8), fontColor = { 180, 190, 220, 230 },
            },
            UI.Panel {
                flexDirection = "row", alignItems = "center",
                justifyContent = "center", gap = sz(1),
                children = {
                    UI.Panel {
                        width = sz(10), height = sz(10),
                        backgroundImage = Utils.GetIcon("coin"),
                    },
                    UI.Label {
                        text = Utils.FormatMoney(ms.coins),
                        fontSize = sz(8), fontColor = { 255, 220, 100, 255 },
                    },
                },
            },
        }
        if ms.ticket then
            local tConf = Config.TICKETS[ms.ticket]
            if tConf and tConf.icon then
                cardChildren[#cardChildren + 1] = UI.Panel {
                    flexDirection = "row", alignItems = "center",
                    justifyContent = "center", gap = sz(2),
                    children = {
                        UI.Panel {
                            width = sz(20), height = sz(12),
                            backgroundImage = tConf.icon,
                            backgroundFit = "contain", flexShrink = 0,
                        },
                        UI.Label {
                            text = "×1",
                            fontSize = sz(7), fontColor = { 180, 230, 255, 255 },
                        },
                    },
                }
            else
                cardChildren[#cardChildren + 1] = UI.Panel {
                    flexDirection = "row", alignItems = "center",
                    justifyContent = "center", gap = sz(2),
                    children = {
                        UI.Label {
                            text = "🎫",
                            fontSize = sz(8),
                            pointerEvents = "none",
                        },
                        UI.Label {
                            text = "×1",
                            fontSize = sz(7), fontColor = { 180, 230, 255, 255 },
                        },
                    },
                }
            end
        end
        cardChildren[#cardChildren + 1] = UI.Panel {
            width = "100%", height = sz(3),
            backgroundColor = { 30, 33, 48, 255 },
            borderRadius = sz(1),
            overflow = "hidden",
            children = { msFill },
        }
        cardChildren[#cardChildren + 1] = claimBtn

        local card = UI.Panel {
            width = cardW,
            flexDirection = "column",
            alignItems = "center",
            padding = sz(4),
            gap = sz(3),
            backgroundColor = { 35, 40, 58, 220 },
            borderWidth = 1,
            borderColor = { 55, 65, 95, 150 },
            borderRadius = sz(4),
            children = cardChildren,
        }

        milestoneRows[i] = { btn = claimBtn, progressFill = msFill }
        table.insert(msChildren, card)
    end

    -- 在线时长标签
    local durationLabel = UI.Label {
        text = FormatDuration(onlineSeconds),
        fontSize = sz(12), fontColor = { 100, 210, 255, 255 },
        fontWeight = "bold",
    }

    -- 弹窗内容
    local gridW = cardW * 4 + cardGap * 3 + sz(20)
    local popupContent = UI.Panel {
        width = gridW,
        backgroundColor = { 18, 22, 35, 245 },
        borderRadius = sz(6),
        borderWidth = 1,
        borderColor = { 50, 60, 100, 180 },
        overflow = "hidden",
        children = {
            -- 标题栏
            UI.Panel {
                width = "100%",
                paddingHorizontal = sz(10), paddingVertical = sz(6),
                flexDirection = "row", alignItems = "center",
                justifyContent = "space-between",
                backgroundColor = { 25, 30, 50, 230 },
                borderBottomWidth = 1,
                borderColor = { 50, 60, 100, 120 },
                children = {
                    UI.Panel {
                        flexDirection = "row", alignItems = "center", gap = sz(5),
                        children = {
                            UI.Label { text = "⏱", fontSize = sz(13), pointerEvents = "none" },
                            UI.Label {
                                text = "在线奖励",
                                fontSize = sz(11), fontColor = { 220, 225, 240, 255 },
                                fontWeight = "bold",
                            },
                        },
                    },
                    UI.Panel {
                        flexDirection = "row", alignItems = "center", gap = sz(4),
                        children = {
                            UI.Label {
                                text = "在线",
                                fontSize = sz(9), fontColor = { 130, 140, 170, 200 },
                            },
                            durationLabel,
                        },
                    },
                },
            },
            -- 卡片网格（flexWrap 横向排列）
            UI.Panel {
                width = "100%",
                flexDirection = "row",
                flexWrap = "wrap",
                justifyContent = "center",
                padding = sz(8),
                gap = cardGap,
                children = msChildren,
            },
            -- 关闭按钮
            UI.Panel {
                width = "100%",
                paddingBottom = sz(8), paddingTop = sz(2),
                justifyContent = "center", alignItems = "center",
                children = {
                    UI.Button {
                        text = "关闭",
                        width = sz(70), height = sz(22),
                        fontSize = sz(9),
                        backgroundColor = { 45, 50, 65, 220 },
                        fontColor = { 160, 170, 190, 230 },
                        borderRadius = sz(3),
                        borderWidth = 1,
                        borderColor = { 60, 70, 100, 120 },
                        onClick = function()
                            Utils.PlayClick()
                            popupVisible = false
                            if popupOverlay then popupOverlay:SetVisible(false) end
                        end,
                    },
                },
            },
        },
    }

    -- 全屏遮罩
    popupOverlay = UI.Panel {
        position = "absolute",
        left = 0, top = 0, right = 0, bottom = 0,
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = { 0, 0, 0, 140 },
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

    popupOverlay._durationLabel = durationLabel

    return popupOverlay
end

-- ============================================================================
-- 退出保存
-- ============================================================================

--- 立即同步在线时间（供外部调用，如游戏存档后）
function OnlineRewardPanel.SyncNow()
    cloudSyncTimer = 0
    SyncOnlineTimeToCloud()
end

--- 游戏退出时立即保存，避免最后一段时间丢失
function OnlineRewardPanel.Shutdown()
    if not cloudLoaded then return end
    SaveFramework.MarkDirty(MODULE_NAME)
    SaveFramework.SaveNow("online_time_final")
    print("[OnlineReward] Shutdown: SaveNow triggered, secs=" .. math.floor(onlineSeconds))
end

--- 弹窗打开时更新在线时长显示
function OnlineRewardPanel.UpdatePopupDuration()
    if not popupVisible or not popupOverlay then return end
    -- 只更新时间文本，RefreshAll 由状态变化驱动（避免每帧 SetStyle 吞点击）
    if popupOverlay._durationLabel then
        popupOverlay._durationLabel:SetText(FormatDuration(onlineSeconds))
    end
    -- 弹窗打开时也检查状态变化（内部有脏检查，不会无意义重刷）
    OnlineRewardPanel.RefreshAll()
end

function OnlineRewardPanel.GetClaimedBits()   return claimedBits end
function OnlineRewardPanel.GetOnlineDate()    return onlineDate end

return OnlineRewardPanel
