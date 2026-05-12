-- ============================================================================
-- UI/SettingsPanel.lua - 设置按钮 + 弹窗（音量调节 + 语音控制矩阵 + 兑换码）
-- ============================================================================

---@diagnostic disable: undefined-global

local UI = require("urhox-libs/UI")
local Config = require("Config")
local Utils = require("UI.Utils")
local MoneyHUD = require("UI.MoneyHUD")
local MoneyManager = require("MoneyManager")
local RedeemCode = require("RedeemCode")
local SaveSystem = require("SaveSystem")
local SaveFramework = require("SaveFramework")

local SettingsPanel = {}

local C = Config.COLORS

local MODULE_NAME = "redeem"

-- 状态
local popupVisible = false
local popupOverlay = nil
local bgmSlider = nil
local sfxSlider = nil

-- 手动保存冷却
local manualSaveCD = nil

-- 兑换码状态
local redeemInput = nil
local redeemStatusLabel = nil
local redeemBtn = nil
local redeemedBits = 0       -- 已兑换位掩码（从云端加载）
local cloudLoaded = false

-- 版本检测状态
local LOCAL_VERSION = Config.GAME.Version  -- 统一引用 Config
local VERSION_CHECK_KEY = "app_version"
local VERSION_CHECK_INTERVAL = 120   -- 定时检测间隔（秒）
local versionLabel = nil             -- 版本号显示
local versionStatusLabel = nil       -- 检测结果提示
local versionCheckBtn = nil          -- 手动检测按钮
local hasNewVersion = false          -- 是否检测到新版本
local lastCheckTime = 0              -- 上次检测时间
-- versionTimerHandle 已移除：版本检测改用 GameLoop.RegisterAlways 驱动

-- ============================================================================
-- 音量控制
-- ============================================================================

local function GetBgmVolume()
    return math.floor(audio:GetMasterGain(SOUND_MUSIC) * 100 + 0.5)
end

local function GetSfxVolume()
    return math.floor(audio:GetMasterGain(SOUND_EFFECT) * 100 + 0.5)
end

local function SetBgmVolume(percent)
    audio:SetMasterGain(SOUND_MUSIC, percent / 100)
end

local function SetSfxVolume(percent)
    local gain = percent / 100
    audio:SetMasterGain(SOUND_EFFECT, gain)
    audio:SetMasterGain(SOUND_VOICE, gain)   -- 语音跟随音效音量
end

-- ============================================================================
-- 设置持久化（通过 SaveSystem 云存储）
-- ============================================================================

--- 保存当前设置到 SaveSystem
local function SaveSettings()
    SaveSystem.UpdateSettings({
        bgmVolume = GetBgmVolume(),
        sfxVolume = GetSfxVolume(),
    })
end

--- 从 SaveSystem 恢复设置到引擎
local function ApplySettings()
    if not SaveSystem.IsReady() then return end
    local s = SaveSystem.GetSettings()
    if not s then return end

    -- 恢复音量
    if s.bgmVolume then SetBgmVolume(s.bgmVolume) end
    if s.sfxVolume then SetSfxVolume(s.sfxVolume) end

    print("[SettingsPanel] Applied settings: bgm=" .. tostring(s.bgmVolume)
        .. " sfx=" .. tostring(s.sfxVolume))
end

-- ============================================================================
-- 兑换码逻辑
-- ============================================================================

local function GetCurrentUserId()
    return lobby and lobby:GetMyUserId() or 0
end

local function SetRedeemStatus(text, color)
    if redeemStatusLabel then
        redeemStatusLabel:SetText(text)
        redeemStatusLabel:SetFontColor(color or C.textMuted)
        redeemStatusLabel:SetVisible(true)
    end
end

local function DoRedeem()
    if not redeemInput then return end
    local code = redeemInput:GetText()
    if not code or code == "" then
        SetRedeemStatus("请输入兑换码", C.danger)
        return
    end

    local userId = GetCurrentUserId()
    if userId == 0 then
        SetRedeemStatus("未登录，无法兑换", C.danger)
        return
    end

    if not cloudLoaded then
        SetRedeemStatus("数据加载中，请稍后", C.textMuted)
        return
    end

    -- 验证兑换码
    local result, err = RedeemCode.Verify(code, userId)
    if not result then
        if err == "invalid_format" then
            SetRedeemStatus("兑换码格式错误", C.danger)
        elseif err == "wrong_user" then
            SetRedeemStatus("该兑换码不属于当前账号", C.danger)
        else
            SetRedeemStatus("无效的兑换码", C.danger)
        end
        return
    end

    -- 检查是否已兑换
    if RedeemCode.IsRedeemed(redeemedBits, result.serial) then
        SetRedeemStatus("该兑换码已使用", C.textMuted)
        return
    end

    -- 执行兑换：加金币 + 标记已兑换
    local newBits = RedeemCode.MarkRedeemed(redeemedBits, result.serial)
    local coins = result.amount

    if redeemBtn then redeemBtn:SetDisabled(true) end

    MoneyManager.AddMoneyFromMenu(coins, "兑换码", {
        batchSetup = function(batch)
            batch:SetInt("redeemed_codes", newBits)
        end,
        ok = function()
            redeemedBits = newBits
            SetRedeemStatus("兑换成功！+" .. Utils.FormatMoney(coins), { 100, 220, 100, 255 })
            Utils.PlaySfx("bid_success")
            if redeemInput then redeemInput:Clear() end
            if redeemBtn then redeemBtn:SetDisabled(false) end
            print("[RedeemCode] Redeemed serial=" .. result.serial .. " amount=" .. coins)
        end,
        error = function(errCode, reason)
            SetRedeemStatus("兑换失败，请重试", C.danger)
            if redeemBtn then redeemBtn:SetDisabled(false) end
            print("[RedeemCode] Save failed: " .. tostring(reason))
        end,
    })
end

-- ============================================================================
-- SaveFramework 注册（替代独立 Init 云端加载 redeemed_codes）
-- ============================================================================

SaveFramework.Register(MODULE_NAME, {
    cloudKeys = { "redeemed_codes" },
    speculativeKeys = {},

    load = function(values, iscores)
        local bits = iscores["redeemed_codes"]
        if bits and bits > 0 then
            redeemedBits = bits
        end
        cloudLoaded = true
        print("[SettingsPanel] Loaded redeemed_codes: " .. redeemedBits)
    end,

    save = function(batch)
        batch:SetInt("redeemed_codes", redeemedBits)
    end,

    defaults = function()
        cloudLoaded = true
        print("[SettingsPanel] Using defaults for redeem")
    end,
})

-- ============================================================================
-- 版本检测逻辑
-- ============================================================================

--- 将版本号字符串编码为整数: "1.1.8" → 10108
local function EncodeVersion(verStr)
    local major, minor, patch = verStr:match("^(%d+)%.(%d+)%.(%d+)$")
    if not major then return 0 end
    return tonumber(major) * 10000 + tonumber(minor) * 100 + tonumber(patch)
end

--- 将整数解码为版本号字符串: 10108 → "1.1.8"
local function DecodeVersion(num)
    if not num or num <= 0 then return "0.0.0" end
    local major = math.floor(num / 10000)
    local minor = math.floor((num % 10000) / 100)
    local patch = num % 100
    return major .. "." .. minor .. "." .. patch
end

--- 执行版本检测（从云端拉取最高版本号）
local function DoVersionCheck()
    if not clientCloud then
        print("[VersionCheck] clientCloud not available")
        return
    end

    local localEncoded = EncodeVersion(LOCAL_VERSION)
    print("[VersionCheck] Checking... local=" .. LOCAL_VERSION .. " (" .. localEncoded .. ")")

    if versionCheckBtn then versionCheckBtn:SetDisabled(true) end

    -- 拉取排行榜第一名（最高版本号）
    clientCloud:GetRankList(VERSION_CHECK_KEY, 0, 1, {
        ok = function(rankList)
            lastCheckTime = os.time()
            local cloudVersion = 0
            if rankList and #rankList > 0 then
                cloudVersion = rankList[1].iscore[VERSION_CHECK_KEY] or 0
            end

            print("[VersionCheck] Cloud highest version: " .. DecodeVersion(cloudVersion) .. " (" .. cloudVersion .. ")")

            if localEncoded > cloudVersion then
                -- 本地版本更高，上传到云端
                clientCloud:SetInt(VERSION_CHECK_KEY, localEncoded, {
                    ok = function()
                        print("[VersionCheck] Uploaded version " .. LOCAL_VERSION)
                    end,
                    error = function(code, reason)
                        print("[VersionCheck] Upload failed: " .. tostring(reason))
                    end,
                })
                hasNewVersion = false
                if versionStatusLabel then
                    versionStatusLabel:SetText("当前已是最新版本 v" .. LOCAL_VERSION)
                    versionStatusLabel:SetFontColor({ 130, 200, 130, 255 })
                    versionStatusLabel:SetVisible(true)
                end
            elseif cloudVersion > localEncoded then
                -- 云端版本更高，提示更新
                hasNewVersion = true
                if versionStatusLabel then
                    versionStatusLabel:SetText("发现新版本 v" .. DecodeVersion(cloudVersion) .. "\n点击右上角三个点，再点下方\n重新启动更新版本")
                    versionStatusLabel:SetFontColor({ 255, 200, 80, 255 })
                    versionStatusLabel:SetVisible(true)
                end
            else
                -- 版本相同
                hasNewVersion = false
                if versionStatusLabel then
                    versionStatusLabel:SetText("当前已是最新版本 v" .. LOCAL_VERSION)
                    versionStatusLabel:SetFontColor({ 130, 200, 130, 255 })
                    versionStatusLabel:SetVisible(true)
                end
            end

            if versionCheckBtn then versionCheckBtn:SetDisabled(false) end
        end,
        error = function(code, reason)
            print("[VersionCheck] Check failed: " .. tostring(reason))
            if versionStatusLabel then
                versionStatusLabel:SetText("检测失败，请稍后重试")
                versionStatusLabel:SetFontColor(C.danger)
                versionStatusLabel:SetVisible(true)
            end
            if versionCheckBtn then versionCheckBtn:SetDisabled(false) end
        end,
    })
end

--- 启动定时检测
local _versionTimerRunning = false
local _initCheckDone = false

local function StartVersionTimer()
    _versionTimerRunning = true
end

-- 版本检测的内部更新（由 GameLoop.RegisterAlways 驱动，不直接订阅 Update 事件）
local function VersionCheckUpdate(_dt)
    -- 阶段1：首次初始化检测（仅执行一次）
    if not _initCheckDone then
        _initCheckDone = true
        DoVersionCheck()
        StartVersionTimer()
        return
    end
    -- 阶段2：定时检测
    if _versionTimerRunning then
        local now = os.time()
        if now - lastCheckTime >= VERSION_CHECK_INTERVAL then
            DoVersionCheck()
        end
    end
end

-- ============================================================================
-- 初始化（兼容性接口 - redeemed_codes 由 SaveFramework.Init 统一加载）
-- ============================================================================

function SettingsPanel.Init()
    -- 从 SaveSystem 恢复设置（SaveSystem.Init 在此之前已完成）
    ApplySettings()

    -- redeemed_codes 已由 SaveFramework.Init 的 BatchGet 加载完成
    -- cloudLoaded 由 load 回调设置
    if not cloudLoaded then
        print("[SettingsPanel] Init: waiting for SaveFramework load")
    end

    -- 通过 GameLoop 注册版本检测更新，避免直接 SubscribeToEvent("Update") 覆盖 main.lua 的 HandleUpdate
    local GameLoop = require("GameLoop")
    GameLoop.RegisterAlways("SettingsPanel.VersionCheck", VersionCheckUpdate)
end

-- ============================================================================
-- 创建 UI
-- ============================================================================

--- 创建左上角设置按钮
function SettingsPanel.CreateButton()
    local sz = Utils.sz
    -- 重置弹窗状态，防止跨界面残留
    popupVisible = false

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
            end
        end,
        children = {
            UI.Label {
                text = "设置",
                fontSize = sz(15), fontColor = { 200, 205, 220, 220 },
                pointerEvents = "none",
            },
        },
    }
end

--- 创建紧凑版设置按钮（用于游戏界面顶栏）
function SettingsPanel.CreateCompactButton()
    popupVisible = false
    return UI.Panel {
        height = 28,
        paddingHorizontal = 8,
        flexDirection = "row",
        alignItems = "center",
        cursor = "pointer",
        onClick = function()
            Utils.PlayClick()
            popupVisible = not popupVisible
            if popupOverlay then
                popupOverlay:SetVisible(popupVisible)
            end
        end,
        children = {
            UI.Label {
                text = "设置",
                fontSize = 12, fontColor = { 200, 205, 220, 200 },
                pointerEvents = "none",
            },
        },
    }
end

--- 创建设置弹窗
function SettingsPanel.CreatePopup()
    local sz = Utils.sz
    -- 从 SaveSystem 读取已保存的设置
    local saved = SaveSystem.IsReady() and SaveSystem.GetSettings() or nil
    local bgmVol = (saved and saved.bgmVolume) or GetBgmVolume()
    local sfxVol = (saved and saved.sfxVolume) or GetSfxVolume()

    -- 同步音量到引擎
    SetBgmVolume(bgmVol)
    SetSfxVolume(sfxVol)

    local bgmPctLabel = UI.Label { text = bgmVol .. "%", fontSize = sz(12), fontColor = C.textMuted }
    local sfxPctLabel = UI.Label { text = sfxVol .. "%", fontSize = sz(12), fontColor = C.textMuted }

    bgmSlider = UI.Slider {
        width = "100%",
        value = bgmVol,
        min = 0, max = 100, step = 1,
        onChange = function(self, v)
            SetBgmVolume(v)
            bgmPctLabel:SetText(math.floor(v + 0.5) .. "%")
            SaveSettings()
        end,
    }

    sfxSlider = UI.Slider {
        width = "100%",
        value = sfxVol,
        min = 0, max = 100, step = 1,
        onChange = function(self, v)
            SetSfxVolume(v)
            sfxPctLabel:SetText(math.floor(v + 0.5) .. "%")
            SaveSettings()
            Utils.PlaySfx("ui_click")
        end,
    }

    -- 兑换码输入
    redeemInput = UI.TextField {
        width = "100%", height = sz(34),
        placeholder = "输入兑换码",
        fontSize = sz(13),
    }

    redeemBtn = UI.Button {
        text = "兑换", width = "100%", height = sz(34), fontSize = sz(13),
        variant = "primary",
        onClick = function() DoRedeem() end,
    }

    redeemStatusLabel = UI.Label {
        text = "", fontSize = sz(11), fontColor = C.textMuted,
        visible = false,
    }

    -- 版本检测控件
    versionLabel = UI.Label {
        text = "当前版本: v" .. LOCAL_VERSION,
        fontSize = sz(12), fontColor = C.textMuted, flexShrink = 0,
    }

    versionCheckBtn = UI.Button {
        text = "检测新版本", width = "100%", height = sz(30), fontSize = sz(12),
        variant = "secondary",
        onClick = function()
            Utils.PlayClick()
            DoVersionCheck()
        end,
    }

    versionStatusLabel = UI.Label {
        text = "", fontSize = sz(11), fontColor = C.textMuted,
        visible = false, flexShrink = 0,
    }

    -- 如果已经检测到新版本，立即显示提示
    if hasNewVersion and versionStatusLabel then
        versionStatusLabel:SetText("有新版本可用\n点击右上角三个点，再点下方\n重新启动更新版本")
        versionStatusLabel:SetFontColor({ 255, 200, 80, 255 })
        versionStatusLabel:SetVisible(true)
    end

    local popupContent = UI.Panel {
        width = sz(310), height = "92%",
        backgroundColor = C.bgPanel,
        borderRadius = 0,
        paddingHorizontal = sz(16), paddingVertical = sz(10),
        gap = sz(6),
        flexDirection = "column",
        onClick = function() end,  -- 阻止点击穿透到遮罩层
        children = {
            -- 标题
            UI.Label {
                text = "设置", fontSize = sz(16), fontWeight = "bold",
                fontColor = C.textPrimary, flexShrink = 0,
            },
            UI.Panel { width = "100%", height = 1, backgroundColor = { 60, 70, 100, 150 }, flexShrink = 0 },
            -- BGM
            UI.Panel {
                width = "100%", flexShrink = 0, gap = sz(3), flexDirection = "column",
                children = {
                    UI.Panel {
                        flexDirection = "row", justifyContent = "space-between",
                        width = "100%",
                        children = {
                            UI.Label { text = "背景音乐", fontSize = sz(13), fontColor = C.textPrimary },
                            bgmPctLabel,
                        },
                    },
                    bgmSlider,
                },
            },
            -- SFX
            UI.Panel {
                width = "100%", flexShrink = 0, gap = sz(3), flexDirection = "column",
                children = {
                    UI.Panel {
                        flexDirection = "row", justifyContent = "space-between",
                        width = "100%",
                        children = {
                            UI.Label { text = "游戏音效", fontSize = sz(13), fontColor = C.textPrimary },
                            sfxPctLabel,
                        },
                    },
                    sfxSlider,
                },
            },
            -- 手动保存
            UI.Button {
                text = "手动保存", width = "100%", flex = 1, flexShrink = 1,
                minHeight = sz(24), maxHeight = sz(36),
                fontSize = sz(13),
                variant = "primary",
                onClick = function(self)
                    Utils.PlayClick()
                    local FloatingMessage = require("UI.FloatingMessage")
                    if not SaveSystem.IsReady() then
                        FloatingMessage.Show("存档未就绪")
                        return
                    end
                    local now = os.time()
                    if manualSaveCD and now - manualSaveCD < 10 then
                        local remain = 10 - (now - manualSaveCD)
                        FloatingMessage.Show(remain .. "秒后可再次保存")
                        return
                    end
                    manualSaveCD = now
                    SaveSystem.SaveNow()
                end,
            },
            -- 兑换码区域
            UI.Panel {
                width = "100%", flex = 1, flexShrink = 1,
                gap = sz(4), flexDirection = "column",
                children = {
                    UI.Label { text = "兑换码", fontSize = sz(13), fontColor = C.textPrimary, flexShrink = 0 },
                    redeemInput,
                    redeemBtn,
                    redeemStatusLabel,
                },
            },
            -- 版本检测区域
            UI.Panel {
                width = "100%", flexShrink = 0,
                gap = sz(4), flexDirection = "column",
                children = {
                    UI.Panel { width = "100%", height = 1, backgroundColor = { 60, 70, 100, 150 }, flexShrink = 0 },
                    versionLabel,
                    versionCheckBtn,
                    versionStatusLabel,
                },
            },
            -- 关闭按钮
            UI.Button {
                text = "关闭", width = "100%", flex = 1, flexShrink = 1,
                minHeight = sz(24), maxHeight = sz(36),
                fontSize = sz(13),
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
        children = { popupContent },
    }

    return popupOverlay
end

return SettingsPanel
