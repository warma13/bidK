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

local SettingsPanel = {}

local C = Config.COLORS

-- 状态
local popupVisible = false
local popupOverlay = nil
local bgmSlider = nil
local sfxSlider = nil

-- 兑换码状态
local redeemInput = nil
local redeemStatusLabel = nil
local redeemBtn = nil
local redeemedBits = 0       -- 已兑换位掩码（从云端加载）
local cloudLoaded = false

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

    if clientCloud then
        local newTotal = MoneyHUD.GetMoney() + coins
        clientCloud:BatchSet()
            :Set("player_money", newTotal)
            :SetInt("money_rank", MoneyManager.ToRankValue(newTotal))
            :SetInt("redeemed_codes", newBits)
            :Save("兑换码", {
                ok = function()
                    redeemedBits = newBits
                    MoneyHUD.SetMoney(newTotal)
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
end

-- ============================================================================
-- 初始化（加载已兑换记录）
-- ============================================================================

function SettingsPanel.Init()
    -- 从 SaveSystem 恢复设置（SaveSystem.Init 在此之前已完成）
    ApplySettings()

    cloudLoaded = false
    redeemedBits = 0

    if not clientCloud then
        cloudLoaded = true
        return
    end

    clientCloud:Get("redeemed_codes", {
        ok = function(values, iscores)
            local bits = iscores.redeemed_codes
            if bits and bits > 0 then
                redeemedBits = bits
            end
            cloudLoaded = true
            print("[SettingsPanel] Loaded redeemed_codes: " .. redeemedBits)
        end,
        error = function(code, reason)
            cloudLoaded = true
            print("[SettingsPanel] Cloud load failed: " .. tostring(reason))
        end,
    })
end

-- ============================================================================
-- 创建 UI
-- ============================================================================

--- 创建左上角设置按钮
function SettingsPanel.CreateButton()
    return UI.Panel {
        backgroundColor = { 0, 0, 0, 120 },
        borderRadius = 0,
        paddingHorizontal = 10, paddingVertical = 5,
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
                fontSize = 11, fontColor = { 200, 205, 220, 220 },
            },
        },
    }
end

--- 创建设置弹窗
function SettingsPanel.CreatePopup()
    -- 从 SaveSystem 读取已保存的设置
    local saved = SaveSystem.IsReady() and SaveSystem.GetSettings() or nil
    local bgmVol = (saved and saved.bgmVolume) or GetBgmVolume()
    local sfxVol = (saved and saved.sfxVolume) or GetSfxVolume()

    -- 同步音量到引擎
    SetBgmVolume(bgmVol)
    SetSfxVolume(sfxVol)

    local bgmPctLabel = UI.Label { text = bgmVol .. "%", fontSize = 12, fontColor = C.textMuted }
    local sfxPctLabel = UI.Label { text = sfxVol .. "%", fontSize = 12, fontColor = C.textMuted }

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
        width = "100%", height = 34,
        placeholder = "输入兑换码",
        fontSize = 13,
    }

    redeemBtn = UI.Button {
        text = "兑换", width = "100%", height = 34, fontSize = 13,
        variant = "primary",
        onClick = function() DoRedeem() end,
    }

    redeemStatusLabel = UI.Label {
        text = "", fontSize = 11, fontColor = C.textMuted,
        visible = false,
    }

    local popupContent = UI.Panel {
        width = 310,
        backgroundColor = C.bgPanel,
        borderRadius = 0,
        padding = 20, gap = 14,
        flexDirection = "column",
        children = {
            UI.Label {
                text = "设置", fontSize = 16, fontWeight = "bold",
                fontColor = C.textPrimary,
            },
            UI.Panel { width = "100%", height = 1, backgroundColor = { 60, 70, 100, 150 } },
            -- BGM
            UI.Panel {
                width = "100%", gap = 6, flexDirection = "column",
                children = {
                    UI.Panel {
                        flexDirection = "row", justifyContent = "space-between",
                        width = "100%",
                        children = {
                            UI.Label { text = "背景音乐", fontSize = 13, fontColor = C.textPrimary },
                            bgmPctLabel,
                        },
                    },
                    bgmSlider,
                },
            },
            -- SFX
            UI.Panel {
                width = "100%", gap = 6, flexDirection = "column",
                children = {
                    UI.Panel {
                        flexDirection = "row", justifyContent = "space-between",
                        width = "100%",
                        children = {
                            UI.Label { text = "游戏音效", fontSize = 13, fontColor = C.textPrimary },
                            sfxPctLabel,
                        },
                    },
                    sfxSlider,
                },
            },
            -- 兑换码分隔线
            UI.Panel { width = "100%", height = 1, backgroundColor = { 60, 70, 100, 150 } },
            -- 兑换码区域
            UI.Panel {
                width = "100%", gap = 8, flexDirection = "column",
                children = {
                    UI.Label { text = "兑换码", fontSize = 13, fontColor = C.textPrimary },
                    redeemInput,
                    redeemBtn,
                    redeemStatusLabel,
                },
            },
            -- 关闭按钮
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

return SettingsPanel
