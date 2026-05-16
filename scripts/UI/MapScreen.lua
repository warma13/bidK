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
        -- 用外层 Panel 做中心点定位，内层是实际按钮
        local marker = UI.Panel {
            width = sz(160), height = sz(40),
            positionType = "absolute",
            left = tostring(math.floor(region.mapX * 100)) .. "%",
            top  = tostring(math.floor(region.mapY * 100)) .. "%",
            marginLeft = -sz(80), marginTop = -sz(20),
            backgroundColor = { 10, 12, 20, 160 },
            borderRadius = 0, borderWidth = 1,
            borderColor = { 220, 225, 235, 120 },
            justifyContent = "center", alignItems = "center",
            cursor = "pointer",
            hoverStyle = {
                backgroundColor = { 30, 35, 50, 200 },
                borderColor = { 220, 225, 235, 200 },
            },
            onPointerDown = function(_, w)
                w:SetStyle({
                    backgroundColor = { 195, 215, 40, 120 },
                    borderColor = { 195, 215, 40, 255 },
                })
            end,
            onPointerUp = function(_, w)
                w:SetStyle({
                    backgroundColor = { 10, 12, 20, 160 },
                    borderColor = { 220, 225, 235, 120 },
                })
            end,
            onPointerLeave = function(_, w)
                w:SetStyle({
                    backgroundColor = { 10, 12, 20, 160 },
                    borderColor = { 220, 225, 235, 120 },
                })
            end,
            onClick = function()
                Utils.PlayClick()
                if onRegionSelected then
                    onRegionSelected(i)
                end
            end,
            children = {
                UI.Label {
                    text = region.name, fontSize = sz(13),
                    fontColor = C.textPrimary, fontWeight = "bold",
                    textAlign = "center",
                    pointerEvents = "none",
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
            -- 顶部栏（浮层，使用 Utils.sz 与竞拍大厅保持一致的视觉高度）
            UI.Panel {
                position = "absolute",
                top = 0, left = 0, right = 0,
                height = Utils.sz(44),
                paddingHorizontal = Utils.sz(12),
                flexDirection = "row", alignItems = "center",
                backgroundColor = { 0, 0, 0, 180 },
                children = {
                    -- 左侧：设置 + 金币
                    UI.Panel {
                        flexDirection = "row", alignItems = "center", gap = Utils.sz(8),
                        children = {
                            SettingsPanel.CreateButton(),
                            MoneyHUD.CreatePanel(),
                        },
                    },
                    -- 中间标题（绝对定位居中，不受左右元素影响）
                    UI.Panel {
                        position = "absolute", left = 0, right = 0, top = 0, bottom = 0,
                        flexDirection = "row", alignItems = "center", justifyContent = "center",
                        pointerEvents = "none",
                        children = {
                            UI.Label {
                                text = "选择竞拍区域", fontSize = Utils.sz(16),
                                fontColor = C.accent, fontWeight = "bold",
                            },
                        },
                    },
                },
            },
            -- 底部返回按钮（浮层）
            UI.Panel {
                position = "absolute",
                bottom = sz(6), left = sz(8),
                children = {
                    UI.Panel {
                        height = sz(30),
                        paddingHorizontal = sz(12),
                        backgroundColor = { 195, 215, 40, 20 },
                        borderWidth = 1,
                        borderColor = { 195, 215, 40, 160 },
                        flexDirection = "row",
                        alignItems = "center",
                        cursor = "pointer",
                        hoverStyle = { backgroundColor = { 195, 215, 40, 50 } },
                        onClick = function()
                            Utils.PlayClick()
                            if onBackCallback then onBackCallback() end
                        end,
                        children = {
                            UI.Label {
                                text = "返回",
                                fontSize = sz(12),
                                fontColor = { 195, 215, 40, 230 },
                                fontWeight = "bold",
                                pointerEvents = "none",
                            },
                        },
                    },
                },
            },
            SettingsPanel.CreatePopup(),
            MoneyHUD.CreatePopup(),
        }
    }
    UI.SetRoot(UI.SafeAreaView {
        edges = "all", width = "100%", height = "100%",
        children = { mapRoot, DebugPanel.CreateHUD() },
    })
end

return MapScreen
