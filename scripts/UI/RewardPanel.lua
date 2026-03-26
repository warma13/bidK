-- ============================================================================
-- UI/RewardPanel.lua - 储钱罐系统（按钮 + 弹窗 + 云端读写）
-- ============================================================================

local UI = require("urhox-libs/UI")
local Config = require("Config")
local MoneyHUD = require("UI.MoneyHUD")
local MoneyManager = require("MoneyManager")
local Utils = require("UI.Utils")
local AntiCheat = require("AntiCheat")

local RewardPanel = {}

local C = Config.COLORS

-- 配置
local COINS_PER_HOUR = 100000   -- 每小时 10 万
local MAX_HOURS = 6             -- 最多累积 6 小时

-- 状态（用 SecureValue 保护关键数值，防止内存篡改）
local secureLastRewardTime = AntiCheat.SecureValue(0)  -- 受保护的上次领取时间
local cloudLoaded = false       -- 云端数据是否已加载
local isCheater = false         -- 是否永久封禁
local popupVisible = false

-- UI 引用
local btnLabel = nil
local popupOverlay = nil
local popupAmountLabel = nil
local popupTimeLabel = nil
local popupCollectBtn = nil
local popupCheaterLabel = nil

-- 刷新计时
local refreshTimer = 0

-- ============================================================================
-- 工具函数
-- ============================================================================

local function CalcAccumulated()
    local lrt = secureLastRewardTime.get()
    if not cloudLoaded or lrt <= 0 or isCheater then
        return 0, 0
    end
    local now = os.time()
    local elapsed = now - lrt  -- 秒
    if elapsed < 0 then
        return 0, 0
    end
    local hours = math.min(elapsed / 3600, MAX_HOURS)
    local coins = math.floor(hours * COINS_PER_HOUR)
    return coins, elapsed
end

local function FormatDuration(seconds)
    if seconds <= 0 then return "0 分钟" end
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    if h > 0 and m > 0 then
        return h .. " 小时 " .. m .. " 分钟"
    elseif h > 0 then
        return h .. " 小时"
    else
        return m .. " 分钟"
    end
end

--- 将玩家标记为作弊并永久写入云端
local function BanPlayer()
    isCheater = true
    secureLastRewardTime.set(0)  -- 清零受保护时间
    if clientCloud then
        clientCloud:SetInt("reward_banned", 1)
    end
    print("[RewardPanel] Player permanently banned from rewards")
end

local function RefreshPopup()
    if not popupAmountLabel then return end

    if isCheater then
        popupAmountLabel:SetText("0")
        popupTimeLabel:SetText("")
        popupCheaterLabel:SetVisible(true)
        popupCollectBtn:SetDisabled(true)
        popupCollectBtn:SetText("不可领取")
        return
    end

    popupCheaterLabel:SetVisible(false)

    if not cloudLoaded then
        popupAmountLabel:SetText("加载中...")
        popupTimeLabel:SetText("")
        popupCollectBtn:SetDisabled(true)
        popupCollectBtn:SetText("加载中")
        return
    end

    if secureLastRewardTime.get() <= 0 then
        popupAmountLabel:SetText("0")
        popupTimeLabel:SetText("开始计时中")
        popupCollectBtn:SetDisabled(true)
        popupCollectBtn:SetText("暂无奖励")
        return
    end

    local coins, elapsed = CalcAccumulated()
    popupAmountLabel:SetText(Utils.FormatMoney(coins))
    local cappedElapsed = math.min(elapsed, MAX_HOURS * 3600)
    popupTimeLabel:SetText("已累积 " .. FormatDuration(cappedElapsed) ..
        (elapsed >= MAX_HOURS * 3600 and " (已满)" or ""))

    if coins > 0 then
        popupCollectBtn:SetDisabled(false)
        popupCollectBtn:SetText("领取 " .. Utils.FormatMoney(coins))
    else
        popupCollectBtn:SetDisabled(true)
        popupCollectBtn:SetText("暂无奖励")
    end
end

local function RefreshButton()
    if not btnLabel then return end
    if not cloudLoaded then
        btnLabel:SetText("...")
        return
    end
    if isCheater then
        btnLabel:SetText("奖励")
        return
    end
    local coins = CalcAccumulated()
    if coins > 0 then
        btnLabel:SetText(Utils.FormatMoney(coins))
    else
        btnLabel:SetText("奖励")
    end
end

-- ============================================================================
-- 云端读写
-- ============================================================================

function RewardPanel.Init()
    cloudLoaded = false
    isCheater = false
    secureLastRewardTime.set(0)

    if not clientCloud then
        print("[RewardPanel] clientCloud not available")
        cloudLoaded = true
        return
    end

    clientCloud:BatchGet()
        :Key("last_reward_time")
        :Key("reward_banned")
        :Fetch({
            ok = function(values, iscores)
                -- 检查永久封禁标记
                local banned = iscores.reward_banned
                if banned and banned > 0 then
                    isCheater = true
                    print("[RewardPanel] Player is permanently banned")
                    cloudLoaded = true
                    RefreshButton()
                    return
                end

                local saved = iscores.last_reward_time
                if saved and saved > 0 then
                    secureLastRewardTime.set(saved)
                    -- 反作弊：本机时间 < 云端记录 → 永久封禁
                    if os.time() < secureLastRewardTime.get() then
                        BanPlayer()
                    end
                else
                    -- 首次：写入当前时间开始计时
                    local now = os.time()
                    secureLastRewardTime.set(now)
                    clientCloud:SetInt("last_reward_time", now)
                    print("[RewardPanel] First time, initialized: " .. now)
                end
                cloudLoaded = true
                RefreshButton()
                print("[RewardPanel] Cloud loaded, lastRewardTime=" .. secureLastRewardTime.get())
            end,
            error = function(code, reason)
                print("[RewardPanel] Cloud load failed: " .. tostring(reason))
                cloudLoaded = true
                RefreshButton()
            end,
        })
end

local function CollectReward()
    if not cloudLoaded or isCheater then return end
    local coins = CalcAccumulated()
    if coins <= 0 then return end

    -- 用 SecureValue 保护领取金额，防止内存篡改
    local secureCoins = AntiCheat.SecureValue(coins)

    -- 校验：重新计算一次并与受保护值比对
    local verifyCoins = CalcAccumulated()
    if secureCoins.get() ~= verifyCoins then
        print("[AntiCheat] WARNING: Reward coins tampered! Expected "
            .. verifyCoins .. " got " .. secureCoins.get())
        BanPlayer()
        RefreshPopup()
        return
    end

    local coinsToCollect = secureCoins.get()
    local now = os.time()
    secureLastRewardTime.set(now)

    -- 云端加金币 + 更新领取时间
    if clientCloud then
        local newTotal = MoneyHUD.GetMoney() + coinsToCollect
        clientCloud:BatchSet()
            :Set("player_money", newTotal)
            :SetInt("money_rank", MoneyManager.ToRankValue(newTotal))
            :SetInt("last_reward_time", now)
            :Save("储钱罐", {
                ok = function()
                    MoneyHUD.SetMoney(newTotal)
                    print("[RewardPanel] Collected " .. coinsToCollect)
                end,
                error = function(code, reason)
                    print("[RewardPanel] Save failed: " .. tostring(reason))
                    -- 回滚本地时间
                    secureLastRewardTime.set(secureLastRewardTime.get() - (os.time() - now))
                end,
            })
    end

    Utils.PlaySfx("bid_success")
    MoneyHUD.SetMoney(MoneyHUD.GetMoney() + coinsToCollect)

    -- 关闭弹窗
    popupVisible = false
    if popupOverlay then popupOverlay:SetVisible(false) end
    RefreshButton()
end

-- ============================================================================
-- 创建 UI
-- ============================================================================

function RewardPanel.CreateButton()
    btnLabel = UI.Label {
        text = "...",
        fontSize = 11,
        fontColor = { 255, 220, 100, 255 },
        fontWeight = "bold",
    }

    return UI.Panel {
        flexDirection = "row",
        alignItems = "center",
        gap = 5,
        paddingHorizontal = 10,
        paddingVertical = 6,
        backgroundColor = { 0, 0, 0, 140 },
        borderRadius = 0,
        cursor = "pointer",
        onClick = function()
            Utils.PlayClick()
            popupVisible = not popupVisible
            if popupOverlay then
                popupOverlay:SetVisible(popupVisible)
                if popupVisible then RefreshPopup() end
            end
        end,
        children = {
            UI.Panel {
                width = 16, height = 16,
                backgroundImage = Utils.GetIcon("coin"),
                backgroundFit = "contain",
                flexShrink = 0,
            },
            btnLabel,
        },
    }
end

function RewardPanel.CreatePopup()
    popupAmountLabel = UI.Label {
        text = "0", fontSize = 28, fontWeight = "bold",
        fontColor = { 255, 220, 100, 255 },
    }

    popupTimeLabel = UI.Label {
        text = "", fontSize = 12, fontColor = C.textMuted,
    }

    popupCollectBtn = UI.Button {
        text = "领取", width = "100%", height = 40, fontSize = 14,
        variant = "primary",
        onClick = function() CollectReward() end,
    }

    popupCheaterLabel = UI.Label {
        text = "检测到时钟异常，领取功能已永久禁用",
        fontSize = 12, fontColor = C.danger,
        visible = false,
    }

    local popupContent = UI.Panel {
        width = 280,
        backgroundColor = C.bgPanel,
        borderRadius = 0,
        padding = 20, gap = 14,
        flexDirection = "column",
        alignItems = "center",
        children = {
            UI.Label {
                text = "储钱罐", fontSize = 16, fontWeight = "bold",
                fontColor = C.textPrimary,
            },
            UI.Panel { width = "100%", height = 1, backgroundColor = { 60, 70, 100, 150 } },
            UI.Panel {
                flexDirection = "row", alignItems = "center", gap = 8,
                children = {
                    UI.Panel {
                        width = 24, height = 24,
                        backgroundImage = Utils.GetIcon("coin"),
                        backgroundFit = "contain",
                        flexShrink = 0,
                    },
                    popupAmountLabel,
                },
            },
            popupTimeLabel,
            UI.Label {
                text = "每小时 " .. Utils.FormatMoney(COINS_PER_HOUR) .. "，最多累积 " .. MAX_HOURS .. " 小时",
                fontSize = 10, fontColor = C.textMuted,
            },
            popupCheaterLabel,
            popupCollectBtn,
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
-- 帧更新
-- ============================================================================

function RewardPanel.Update(dt)
    refreshTimer = refreshTimer + dt
    if refreshTimer >= 1.0 then
        refreshTimer = 0
        RefreshButton()
        if popupVisible then
            RefreshPopup()
        end
    end
end

return RewardPanel
