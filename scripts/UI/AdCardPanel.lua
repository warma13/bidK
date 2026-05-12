-- ============================================================================
-- UI/AdCardPanel.lua - 广告卡系统（按钮 + 弹窗 + 云端 + 广告逻辑）
-- 看广告获取金币，累积卡点升级卡等级，每日里程碑奖励
-- ============================================================================

---@diagnostic disable: undefined-global

local UI = require("urhox-libs/UI")
local Config = require("Config")
local MoneyHUD = require("UI.MoneyHUD")
local MoneyManager = require("MoneyManager")
local SaveSystem = require("SaveSystem")
local SaveFramework = require("SaveFramework")
local Utils = require("UI.Utils")
local FloatingMessage = require("UI.FloatingMessage")

local AdCardPanel = {}

local C = Config.COLORS
local AC = Config.AD_CARD

-- ============================================================================
-- 云端键名
-- ============================================================================
local KEY_CARD_POINTS   = "adcard_points"      -- 累计卡点（int）
local KEY_DAILY_COUNT   = "adcard_daily_count"  -- 今日已看次数（int）
local KEY_DAILY_DATE    = "adcard_daily_date"   -- 今日日期字符串
local KEY_MILESTONE_BITS = "adcard_milestone"   -- 已领取里程碑位掩码（int）

local MODULE_NAME = "adcard"

-- ============================================================================
-- 模块状态
-- ============================================================================
local cloudLoaded = false
local cardPoints = 0       -- 累计卡点
local dailyCount = 0       -- 今日已看广告次数
local dailyDate = ""       -- 今日日期标记
local milestoneBits = 0    -- 已领取的里程碑位掩码
local watching = false     -- 正在播放广告

local popupVisible = false

-- UI 引用
local popupOverlay = nil
local btnBadge = nil
local btnLabel = nil
local watchBtn = nil
local watchBtnLabel = nil
local countLabel = nil
local cardNameLabel = nil
local cardPointsLabel = nil
local progressBar = nil
local nextTierLabel = nil
local milestoneRows = {}

-- ============================================================================
-- 辅助
-- ============================================================================

--- 获取当前卡等级信息
local function GetCurrentTier()
    local tiers = AC.CARD_TIERS
    local current = tiers[1]
    for i = #tiers, 1, -1 do
        if cardPoints >= tiers[i].pointsNeeded then
            current = tiers[i]
            break
        end
    end
    return current
end

--- 获取下一个卡等级信息（已满级则返回 nil）
local function GetNextTier()
    local tiers = AC.CARD_TIERS
    for i = 1, #tiers do
        if cardPoints < tiers[i].pointsNeeded then
            return tiers[i]
        end
    end
    return nil -- 已满级
end

--- 今天的日期字符串
local function TodayStr()
    return os.date("%Y-%m-%d")
end

--- 检查并执行每日重置
local function CheckDailyReset()
    local today = TodayStr()
    if dailyDate ~= today then
        dailyCount = 0
        milestoneBits = 0
        dailyDate = today
        return true
    end
    return false
end

--- 是否有可领取的里程碑
local function HasUnclaimedMilestones()
    if not cloudLoaded then return false end
    for i, ms in ipairs(AC.DAILY_MILESTONES) do
        local bit = 1 << (i - 1)
        if dailyCount >= ms.adsRequired and (milestoneBits & bit) == 0 then
            return true
        end
    end
    return false
end

--- 是否还能看广告
local function CanWatchAd()
    return cloudLoaded and dailyCount < AC.MAX_DAILY_ADS and not watching
end

-- ============================================================================
-- SaveFramework 注册（替代独立 Init 云端加载 + SaveCloudState）
-- ============================================================================

SaveFramework.Register(MODULE_NAME, {
    cloudKeys = { KEY_CARD_POINTS, KEY_DAILY_COUNT, KEY_DAILY_DATE, KEY_MILESTONE_BITS },
    speculativeKeys = {},

    load = function(values, iscores)
        cardPoints = iscores[KEY_CARD_POINTS] or 0
        dailyCount = iscores[KEY_DAILY_COUNT] or 0
        dailyDate = values[KEY_DAILY_DATE] or ""
        milestoneBits = iscores[KEY_MILESTONE_BITS] or 0

        -- 日期变更则重置
        CheckDailyReset()

        cloudLoaded = true
        -- pcall 保护：异步回调触发时 UI 可能已被 SetRoot 销毁
        pcall(AdCardPanel.RefreshAll)
        print("[AdCard] Cloud loaded: points=" .. cardPoints
            .. " daily=" .. dailyCount .. "/" .. AC.MAX_DAILY_ADS
            .. " tier=" .. GetCurrentTier().name)
    end,

    save = function(batch)
        batch:SetInt(KEY_CARD_POINTS, cardPoints)
        batch:SetInt(KEY_DAILY_COUNT, dailyCount)
        batch:Set(KEY_DAILY_DATE, dailyDate)
        batch:SetInt(KEY_MILESTONE_BITS, milestoneBits)
    end,

    defaults = function()
        cloudLoaded = true
        dailyDate = TodayStr()
        print("[AdCard] Using defaults")
    end,
})

-- ============================================================================
-- 初始化（兼容性接口 - 数据由 SaveFramework.Init 统一加载）
-- ============================================================================

function AdCardPanel.Init()
    -- 数据已由 SaveFramework.Init 的 BatchGet 加载完成
    -- 此函数仅做本地状态重置（cloudLoaded 由 load 回调设置）
    if not cloudLoaded then
        -- 还未被框架加载（理论上不应到这里，因为 Standalone 先调用 SaveFramework.Init）
        cardPoints = 0
        dailyCount = 0
        dailyDate = TodayStr()
        milestoneBits = 0
        print("[AdCard] Init: waiting for SaveFramework load")
    end
end

-- ============================================================================
-- 每帧更新（检查日期变更）
-- ============================================================================

local resetCheckTimer = 0

function AdCardPanel.Update(dt)
    resetCheckTimer = resetCheckTimer + dt
    if resetCheckTimer >= 60 then
        resetCheckTimer = 0
        if CheckDailyReset() then
            AdCardPanel.RefreshAll()
        end
    end
end

-- ============================================================================
-- 看广告
-- ============================================================================

local function WatchAd()
    -- 每日上限检查（带进度提示）
    if dailyCount >= AC.MAX_DAILY_ADS then
        pcall(FloatingMessage.Show, "今日广告次数已达上限 (" .. AC.MAX_DAILY_ADS .. "/" .. AC.MAX_DAILY_ADS .. ")")
        return
    end
    if not CanWatchAd() then return end

    watching = true
    if watchBtn then watchBtn:SetDisabled(true) end

    local function onAdDone(success)
        watching = false
        if not success then
            pcall(function() if watchBtn then watchBtn:SetDisabled(false) end end)
            pcall(FloatingMessage.Show, "需完整观看广告才能获得奖励")
            print("[AdCard] Ad failed or cancelled")
            return
        end

        -- 成功：增加今日次数
        dailyCount = dailyCount + 1

        -- 每次看广告获得 1 角色币
        SaveSystem.AddCharacterCoins(1)

        -- 看满每日上限时获得 1 卡点
        local earnedPoint = false
        if dailyCount == AC.MAX_DAILY_ADS then
            cardPoints = cardPoints + 1
            earnedPoint = true
        end

        -- 获取当前卡等级的金币奖励
        local tier = GetCurrentTier()
        local coins = tier.coinsPerAd

        -- 通过 MoneyManager 加金币 + 云端持久化
        MoneyManager.AddMoneyFromMenu(coins, "广告奖励", {
            batchSetup = function(batch)
                batch:SetInt(KEY_CARD_POINTS, cardPoints)
                batch:SetInt(KEY_DAILY_COUNT, dailyCount)
                batch:Set(KEY_DAILY_DATE, dailyDate)
                batch:SetInt(KEY_MILESTONE_BITS, milestoneBits)
            end,
            ok = function()
                -- pcall 保护：异步回调触发时 UI 可能已被 SetRoot 销毁
                pcall(AdCardPanel.RefreshAll)
                -- 成功 Toast：金币 + 角色币 + 进度
                local rewardMsg = "+" .. Utils.FormatMoney(coins) .. " 金币"
                if earnedPoint then
                    rewardMsg = rewardMsg .. "  +1 卡点!"
                end
                pcall(FloatingMessage.Show, rewardMsg)

                -- 进度提示
                if dailyCount < AC.MAX_DAILY_ADS then
                    pcall(FloatingMessage.Show, "今日进度 " .. dailyCount .. "/" .. AC.MAX_DAILY_ADS)
                else
                    pcall(FloatingMessage.Show, "今日广告已看完，获得 1 卡点!")
                end

                print("[AdCard] Ad reward: +" .. coins .. " coins, daily=" .. dailyCount)
            end,
            error = function()
                -- 回滚
                dailyCount = dailyCount - 1
                SaveSystem.AddCharacterCoins(-1)
                if earnedPoint then
                    cardPoints = cardPoints - 1
                end
                pcall(AdCardPanel.RefreshAll)
                pcall(FloatingMessage.Show, "奖励发放失败，请重试")
            end,
            silent = true,  -- 不让 MoneyManager 内部再弹 "已保存" Toast
        })
    end

    -- 调用广告 SDK
    if sdk then
        pcall(FloatingMessage.Show, "广告加载中...")
        sdk:ShowRewardVideoAd(function(result)
            onAdDone(result.success)
        end)
    else
        -- 无 SDK 时模拟（开发调试）
        pcall(FloatingMessage.Show, "广告不可用（调试模式）")
        print("[AdCard] No sdk, simulating ad success")
        onAdDone(true)
    end
end

-- ============================================================================
-- 领取里程碑奖励
-- ============================================================================

local function ClaimMilestone(msIndex)
    local ms = AC.DAILY_MILESTONES[msIndex]
    if not ms then return end

    local bit = 1 << (msIndex - 1)
    if (milestoneBits & bit) ~= 0 then return end -- 已领取
    if dailyCount < ms.adsRequired then return end -- 未达标

    -- 标记位
    milestoneBits = milestoneBits | bit

    -- 先在本地乐观更新门票和卡点（在 batchSetup 之前，确保同一次写入）
    if ms.bonusPoints then
        cardPoints = cardPoints + ms.bonusPoints
    end
    if ms.ticket then
        SaveSystem.AddTickets(ms.ticket, 1, true)  -- true = skipSave，不独立发起保存
    end

    MoneyManager.AddMoneyFromMenu(ms.coins, "里程碑" .. ms.adsRequired, {
        batchSetup = function(batch)
            batch:SetInt(KEY_CARD_POINTS, cardPoints)
            batch:SetInt(KEY_DAILY_COUNT, dailyCount)
            batch:Set(KEY_DAILY_DATE, dailyDate)
            batch:SetInt(KEY_MILESTONE_BITS, milestoneBits)
            -- 门票数据也由 SaveSystem 的脏标记一并写入
            SaveSystem.MarkDirty()
        end,
        ok = function()
            -- pcall 保护：异步回调触发时 UI 可能已被 SetRoot 销毁
            pcall(AdCardPanel.RefreshAll)
            pcall(Utils.PlaySfx, "bid_success")

            -- 里程碑奖励 Toast
            local rewardMsg = ms.label .. ": +" .. Utils.FormatMoney(ms.coins) .. " 金币"
            if ms.ticket then
                rewardMsg = rewardMsg .. " +门票"
            end
            if ms.bonusPoints then
                rewardMsg = rewardMsg .. " +" .. ms.bonusPoints .. " 卡点"
            end
            pcall(FloatingMessage.Show, rewardMsg)

            print("[AdCard] Milestone " .. ms.adsRequired .. " claimed!")
        end,
        error = function()
            -- 回滚本地乐观更新
            milestoneBits = milestoneBits & ~bit
            if ms.bonusPoints then
                cardPoints = cardPoints - ms.bonusPoints
            end
            if ms.ticket then
                SaveSystem.AddTickets(ms.ticket, -1, true)
            end
            pcall(AdCardPanel.RefreshAll)
            pcall(FloatingMessage.Show, "领取失败，请重试")
        end,
        silent = true,  -- 不让 MoneyManager 内部再弹 "已保存" Toast
    })
end

-- ============================================================================
-- 刷新 UI
-- ============================================================================

function AdCardPanel.RefreshAll()
    if not cloudLoaded then return end
    -- 安全检查：对局中 UI 已被 SetRoot 重建，AdCardPanel 的按钮/弹窗不存在于游戏界面
    -- 此时操作旧 UI 引用会崩溃，直接跳过；回到菜单时 CreateButton/CreatePopup 会重新创建
    local UIState = require("UI.UIState")
    if UIState.currentScreen == "game" then return end

    local tier = GetCurrentTier()
    local nextTier = GetNextTier()

    -- 按钮文字 & 红点
    if btnLabel then
        btnLabel:SetText(tier.name)
        btnLabel:SetStyle({ fontColor = tier.color })
    end
    if btnBadge then
        btnBadge:SetVisible(HasUnclaimedMilestones() or CanWatchAd())
    end

    -- 弹窗内容
    if cardNameLabel then
        cardNameLabel:SetText("当前等级: " .. tier.name)
        cardNameLabel:SetStyle({ fontColor = tier.color })
    end
    if cardPointsLabel then
        cardPointsLabel:SetText("卡点: " .. cardPoints)
    end

    -- 升级进度
    if nextTierLabel then
        if nextTier then
            local needed = nextTier.pointsNeeded - cardPoints
            nextTierLabel:SetText("距 " .. nextTier.name .. " 还需 " .. needed .. " 点")
            nextTierLabel:SetVisible(true)
        else
            nextTierLabel:SetText("已满级!")
            nextTierLabel:SetVisible(true)
        end
    end

    -- 升级进度条
    if progressBar then
        local ratio = 0
        if nextTier then
            local prevPts = tier.pointsNeeded
            local range = nextTier.pointsNeeded - prevPts
            if range > 0 then
                ratio = (cardPoints - prevPts) / range
            end
        else
            ratio = 1
        end
        progressBar:SetStyle({ width = math.floor(ratio * 100) .. "%" })
    end

    -- 看广告按钮
    if watchBtn then
        watchBtn:SetDisabled(not CanWatchAd())
    end
    if watchBtnLabel then
        if dailyCount >= AC.MAX_DAILY_ADS then
            watchBtnLabel:SetText("今日已看完")
        else
            watchBtnLabel:SetText("看广告 +" .. Utils.FormatMoney(tier.coinsPerAd) .. " 金币")
        end
    end
    if countLabel then
        countLabel:SetText("今日: " .. dailyCount .. "/" .. AC.MAX_DAILY_ADS)
    end

    -- 里程碑行 — 脏检查，避免无意义 SetStyle 吞掉点击事件
    for i, ms in ipairs(AC.DAILY_MILESTONES) do
        local row = milestoneRows[i]
        if row then
            local bit = 1 << (i - 1)
            local claimed = (milestoneBits & bit) ~= 0
            local unlocked = dailyCount >= ms.adsRequired

            local state = claimed and "claimed" or (unlocked and "unlocked" or "locked")
            if state ~= row.lastState then
                row.lastState = state
                if claimed then
                    row.btn:SetDisabled(true)
                    row.btn:SetText("已领取")
                elseif unlocked then
                    row.btn:SetDisabled(false)
                    row.btn:SetText("领取")
                else
                    row.btn:SetDisabled(true)
                    row.btn:SetText(ms.adsRequired .. "次")
                end
            end

            -- 进度条填充 — 脏检查
            local pct = math.min(100, math.floor(dailyCount / ms.adsRequired * 100))
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

function AdCardPanel.CreateButton()
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
        text = "广告卡",
        fontSize = sz(15), fontColor = { 200, 205, 220, 220 },
        pointerEvents = "none",
    }

    -- 云端已加载时立即刷新按钮文字和红点状态
    if cloudLoaded then
        local tier = GetCurrentTier()
        btnLabel:SetText(tier.name)
        btnLabel:SetStyle({ fontColor = tier.color })
        btnBadge:SetVisible(HasUnclaimedMilestones() or CanWatchAd())
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
                if popupVisible then AdCardPanel.RefreshAll() end
            end
        end,
        children = {
            btnLabel,
            btnBadge,
        },
    }
end

-- ============================================================================
-- 创建弹窗
-- ============================================================================

function AdCardPanel.CreatePopup()
    local sz = Utils.sz
    milestoneRows = {}

    -- 卡等级信息区
    cardNameLabel = UI.Label {
        text = "加载中...",
        fontSize = sz(18), fontWeight = "bold",
        fontColor = C.textPrimary,
    }

    cardPointsLabel = UI.Label {
        text = "卡点: 0",
        fontSize = sz(12), fontColor = { 180, 185, 200, 255 },
    }

    nextTierLabel = UI.Label {
        text = "",
        fontSize = sz(10), fontColor = C.textMuted,
        visible = false,
    }

    -- 升级进度条
    local progressFill = UI.Panel {
        width = "0%", height = "100%",
        backgroundColor = { 255, 200, 50, 255 },
        borderRadius = sz(4),
    }
    progressBar = progressFill

    local progressBarContainer = UI.Panel {
        width = "100%", height = sz(6),
        backgroundColor = { 50, 55, 70, 200 },
        borderRadius = sz(4),
        overflow = "hidden",
        children = { progressFill },
    }

    -- 卡等级一览（紧凑卡片式）
    local tierChildren = {}
    for idx, t in ipairs(AC.CARD_TIERS) do
        local isActive = cardPoints >= t.pointsNeeded
        tierChildren[#tierChildren + 1] = UI.Panel {
            flexDirection = "row", alignItems = "center", gap = sz(6),
            paddingVertical = sz(3), paddingHorizontal = sz(6),
            backgroundColor = isActive and { t.color[1], t.color[2], t.color[3], 25 } or { 0, 0, 0, 0 },
            borderRadius = sz(4),
            children = {
                -- 色标
                UI.Panel {
                    width = sz(4), height = sz(16),
                    borderRadius = sz(2),
                    backgroundColor = t.color,
                },
                -- 卡名
                UI.Label {
                    text = t.name,
                    fontSize = sz(11), fontWeight = "bold",
                    fontColor = isActive and { t.color[1], t.color[2], t.color[3], 255 } or C.textMuted,
                },
                -- 收益
                UI.Label {
                    text = "+" .. Utils.FormatMoney(t.coinsPerAd) .. "/次",
                    fontSize = sz(10),
                    fontColor = isActive and C.textPrimary or C.textMuted,
                    flex = 1,
                },
                -- 需求
                UI.Label {
                    text = t.pointsNeeded > 0 and (t.pointsNeeded .. "点") or "初始",
                    fontSize = sz(9),
                    fontColor = { 120, 125, 145, 200 },
                },
            },
        }
    end

    -- 看广告按钮
    watchBtnLabel = UI.Label {
        text = "看广告",
        fontSize = sz(13), fontWeight = "bold", fontColor = { 20, 20, 20, 255 },
    }

    local watchCharCoinIcon = UI.Panel {
        width = sz(16), height = sz(16),
        backgroundImage = Config.CHARACTER_COIN_ICON,
        backgroundFit = "contain", flexShrink = 0,
    }
    local watchCharCoinQty = UI.Label {
        text = "×1",
        fontSize = sz(11), fontColor = { 20, 20, 20, 255 },
    }

    watchBtn = UI.Button {
        width = "100%", height = sz(36),
        variant = "primary",
        disabled = true,
        onClick = function()
            WatchAd()
        end,
        children = {
            UI.Panel {
                flexDirection = "row", alignItems = "center", gap = sz(4),
                justifyContent = "center", width = "100%",
                children = { watchBtnLabel, watchCharCoinIcon, watchCharCoinQty },
            },
        },
    }

    countLabel = UI.Label {
        text = "今日: 0/" .. AC.MAX_DAILY_ADS,
        fontSize = sz(11), fontColor = C.textMuted,
        textAlign = "center", width = "100%",
    }

    -- 里程碑区域
    local msChildren = {}
    for i, ms in ipairs(AC.DAILY_MILESTONES) do
        local claimBtn = UI.Button {
            text = ms.adsRequired .. "次",
            width = sz(46), height = sz(22), fontSize = sz(9),
            variant = "primary",
            disabled = true,
            onClick = function()
                ClaimMilestone(i)
            end,
        }

        local msFill = UI.Panel {
            width = "0%", height = "100%",
            backgroundColor = { 80, 200, 120, 220 },
            borderRadius = sz(2),
        }

        milestoneRows[i] = { btn = claimBtn, progressFill = msFill }

        -- 构建奖励行子元素（金币 + 可选门票图标 + 可选卡点）
        local rewardRowChildren = {
            UI.Panel {
                width = sz(10), height = sz(10),
                backgroundImage = Utils.GetIcon("coin"),
                backgroundFit = "contain", flexShrink = 0,
            },
            UI.Label {
                text = Utils.FormatMoney(ms.coins),
                fontSize = sz(10), fontColor = { 255, 220, 100, 255 },
            },
        }
        if ms.ticket then
            local tConf = Config.TICKETS[ms.ticket]
            if tConf and tConf.icon then
                rewardRowChildren[#rewardRowChildren + 1] = UI.Panel {
                    width = sz(18), height = sz(11),
                    backgroundImage = tConf.icon,
                    backgroundFit = "contain", flexShrink = 0,
                    marginLeft = sz(4),
                }
                rewardRowChildren[#rewardRowChildren + 1] = UI.Label {
                    text = "×1",
                    fontSize = sz(9), fontColor = { 200, 210, 230, 200 },
                }
            end
        end
        if ms.bonusPoints then
            rewardRowChildren[#rewardRowChildren + 1] = UI.Label {
                text = "+" .. ms.bonusPoints .. "卡点",
                fontSize = sz(10), fontColor = { 255, 220, 100, 255 },
                marginLeft = sz(4),
            }
        end

        msChildren[#msChildren + 1] = UI.Panel {
            width = "100%",
            flex = 1, flexShrink = 1,
            flexDirection = "row",
            alignItems = "center",
            gap = sz(6),
            paddingVertical = sz(2), paddingHorizontal = sz(8),
            backgroundColor = i % 2 == 1 and { 40, 45, 65, 120 } or { 0, 0, 0, 0 },
            borderRadius = sz(4),
            children = {
                -- 里程碑图标
                UI.Label {
                    text = ms.adsRequired <= 10 and "🎁" or (ms.adsRequired <= 20 and "🎯" or "🏆"),
                    fontSize = sz(14),
                },
                -- 奖励描述+进度条
                UI.Panel {
                    flex = 1, flexShrink = 1,
                    flexDirection = "column", gap = sz(2),
                    children = {
                        UI.Panel {
                            flexDirection = "row", gap = sz(4), alignItems = "center",
                            children = {
                                UI.Label {
                                    text = ms.label,
                                    fontSize = sz(11), fontWeight = "bold", fontColor = C.textPrimary,
                                },
                            },
                        },
                        -- 奖励行（图标式）
                        UI.Panel {
                            flexDirection = "row", alignItems = "center", gap = sz(3),
                            children = rewardRowChildren,
                        },
                        -- 进度条
                        UI.Panel {
                            width = "100%", height = sz(3),
                            backgroundColor = { 50, 55, 70, 200 },
                            borderRadius = sz(2),
                            overflow = "hidden",
                            children = { msFill },
                        },
                    },
                },
                claimBtn,
            },
        }
    end

    -- ========== 左栏：卡等级 + 看广告 ==========
    local leftCol = UI.Panel {
        width = "45%",
        height = "100%",
        flexDirection = "column",
        gap = sz(4),
        children = {
            -- 标题行
            UI.Panel {
                width = "100%", flexShrink = 0,
                flexDirection = "row", alignItems = "center", gap = sz(6),
                children = {
                    UI.Label { text = "💳", fontSize = sz(16) },
                    UI.Label {
                        text = "广告金币卡",
                        fontSize = sz(15), fontWeight = "bold",
                        fontColor = { 255, 220, 100, 255 },
                    },
                },
            },
            -- 当前等级卡片
            UI.Panel {
                width = "100%", flexShrink = 0,
                backgroundColor = { 35, 40, 60, 200 },
                borderRadius = sz(6),
                padding = sz(8), gap = sz(4),
                flexDirection = "column",
                justifyContent = "center",
                borderWidth = 1, borderColor = { 70, 75, 100, 120 },
                children = {
                    cardNameLabel,
                    UI.Panel {
                        flexDirection = "row", alignItems = "center",
                        justifyContent = "space-between", width = "100%",
                        children = { cardPointsLabel, nextTierLabel },
                    },
                    progressBarContainer,
                },
            },
            -- 等级一览（弹性填充 + 滚动）
            UI.ScrollView {
                width = "100%", flex = 1, flexShrink = 1,
                scrollY = true,
                scrollbarInteractive = false,
                children = {
                    UI.Panel {
                        width = "100%",
                        flexDirection = "column", gap = sz(2),
                        children = tierChildren,
                    },
                },
            },
            -- 看广告区（底部固定）
            UI.Panel {
                width = "100%", flexShrink = 0,
                flexDirection = "column",
                justifyContent = "center",
                gap = sz(4),
                children = { watchBtn, countLabel },
            },
        },
    }

    -- ========== 右栏：每日里程碑 ==========
    local rightCol = UI.Panel {
        width = "52%",
        height = "100%",
        flexDirection = "column",
        gap = sz(4),
        children = {
            -- 标题行
            UI.Panel {
                width = "100%", flexShrink = 0,
                flexDirection = "row", alignItems = "center", gap = sz(6),
                children = {
                    UI.Label { text = "🎯", fontSize = sz(16) },
                    UI.Label {
                        text = "每日里程碑",
                        fontSize = sz(15), fontWeight = "bold",
                        fontColor = { 180, 220, 255, 255 },
                    },
                },
            },
            -- 里程碑列表（弹性填充）
            UI.Panel {
                width = "100%", flex = 1, flexShrink = 1,
                flexDirection = "column", gap = sz(2),
                overflow = "hidden",
                children = msChildren,
            },
        },
    }

    -- ========== 分割线 ==========
    local divider = UI.Panel {
        width = 1, backgroundColor = { 70, 80, 110, 150 },
    }

    local popupContent = UI.Panel {
        width = sz(600),
        height = "88%",
        backgroundColor = { 22, 25, 38, 250 },
        borderRadius = sz(8),
        borderWidth = 1, borderColor = { 60, 70, 100, 150 },
        padding = sz(16), gap = sz(12),
        flexDirection = "column",
        onClick = function() end, -- 阻止穿透
        children = {
            -- 两栏主体（占 90%，剩余给关闭按钮）
            UI.Panel {
                width = "100%",
                height = "90%",
                flexDirection = "row", gap = sz(14),
                children = { leftCol, divider, rightCol },
            },
            -- 关闭按钮（占 10%）
            UI.Button {
                text = "关闭", width = "100%", height = "10%", fontSize = sz(12),
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
            Utils.PlayClick()
            popupVisible = false
            popupOverlay:SetVisible(false)
        end,
        children = {
            popupContent,
        },
    }

    return popupOverlay
end

--- 关闭弹窗（供外部调用）
function AdCardPanel.HidePopup()
    if popupOverlay then
        popupVisible = false
        popupOverlay:SetVisible(false)
    end
end

-- ============================================================================
-- Debug 接口（仅供 DebugPanel 使用）
-- ============================================================================

function AdCardPanel.DebugGetCardPoints()    return cardPoints end
function AdCardPanel.DebugGetDailyCount()    return dailyCount end
function AdCardPanel.GetMilestoneBits()      return milestoneBits end
function AdCardPanel.GetDailyCount()         return dailyCount end
function AdCardPanel.GetDailyDate()          return dailyDate end

function AdCardPanel.DebugSetCardPoints(v)
    cardPoints = math.max(0, v)
    SaveFramework.MarkDirty(MODULE_NAME)
    AdCardPanel.RefreshAll()
end

function AdCardPanel.DebugSetDailyCount(v)
    dailyCount = math.max(0, math.min(v, AC.MAX_DAILY_ADS))
    SaveFramework.MarkDirty(MODULE_NAME)
    AdCardPanel.RefreshAll()
end

return AdCardPanel
