-- ============================================================================
-- UI/MapScreen.lua - 世界大地图选关界面（简化版：只显示地图和区域标记）
-- ============================================================================

local UI = require("urhox-libs/UI")
local Config = require("Config")
local UIState = require("UI.UIState")
local MoneyHUD = require("UI.MoneyHUD")
local Utils = require("UI.Utils")
local DebugPanel = require("UI.DebugPanel")
local SettingsPanel = require("UI.SettingsPanel")
local VersionRewardPanel = require("UI.VersionRewardPanel")

local MapScreen = {}

---@param onBackCallback fun()
---@param onRegionSelected fun(regionIdx: number)
function MapScreen.Show(onBackCallback, onRegionSelected)
    UIState.currentScreen = "map"
    local C = Config.COLORS

    -- 响应式缩放：以手机逻辑高度 440px 为基准，PC 等比放大
    local dpr = graphics:GetDPR()
    local screenH = graphics:GetHeight() / dpr
    local s = math.max(1.0, screenH / 720)
    local function sz(base) return math.floor(base * s) end

    -- 区域标记
    local markerElements = {}
    for i, region in ipairs(Config.REGIONS) do
        local marker = UI.Panel {
            width = sz(120), height = sz(40),
            backgroundColor = { 40, 45, 70, 200 },
            borderRadius = 0, borderWidth = math.max(1, sz(2)),
            borderColor = { 200, 200, 220, 180 },
            justifyContent = "center", alignItems = "center",
            cursor = "pointer",
            positionType = "absolute",
            left = tostring(math.floor(region.mapX * 100)) .. "%",
            top = tostring(math.floor(region.mapY * 100)) .. "%",
            onClick = function()
                Utils.PlayClick()
                if onRegionSelected then
                    onRegionSelected(i)
                end
            end,
            children = {
                UI.Label {
                    text = region.name, fontSize = sz(13),
                    fontColor = C.textPrimary, fontWeight = "bold", textAlign = "center",
                },
            },
        }
        markerElements[#markerElements + 1] = marker
    end

    local mapRoot = UI.Panel {
        width = "100%", height = "100%",
        backgroundColor = C.bgDark,
        children = {
            -- 地图区域（全屏背景）
            UI.Panel {
                width = "100%", height = "100%",
                positionType = "relative",
                overflow = "hidden",
                backgroundImage = Config.WORLD_MAP_BG,
                backgroundFit = "cover",
                children = markerElements,
            },
            -- 顶部标题（浮层）
            UI.Panel {
                position = "absolute",
                top = 0, left = 0, right = 0,
                height = sz(32),
                backgroundColor = { 0, 0, 0, 100 },
                flexDirection = "row", alignItems = "center",
                justifyContent = "center",
                children = {
                    UI.Label { text = "选择竞拍区域", fontSize = sz(16), fontColor = C.textPrimary, fontWeight = "bold" },
                }
            },
            -- 底部返回按钮（浮层）
            UI.Panel {
                position = "absolute",
                bottom = sz(6), left = sz(8),
                children = {
                    UI.Button {
                        text = "← 返回",
                        width = sz(72), height = sz(30), fontSize = sz(12),
                        onClick = function()
                            Utils.PlayClick()
                            if onBackCallback then onBackCallback() end
                        end,
                    },
                },
            },
            MoneyHUD.CreatePanel(),
            UI.Panel {
                position = "absolute",
                left = sz(8), top = sz(6),
                flexDirection = "row",
                alignItems = "center",
                gap = sz(4),
                children = {
                    SettingsPanel.CreateButton(),
                    VersionRewardPanel.CreateButton(),
                },
            },
            SettingsPanel.CreatePopup(),
            VersionRewardPanel.CreatePopup(),
            DebugPanel.CreateHUD(),
        }
    }
    UI.SetRoot(UI.SafeAreaView {
        edges = "all", width = "100%", height = "100%",
        children = { mapRoot },
    })
end

return MapScreen
