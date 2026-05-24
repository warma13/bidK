-- ============================================================================
-- UI/MapScreen.lua - 世界大地图选关界面（简化版：只显示地图和区域标记）
-- ============================================================================

local UI = require("urhox-libs/UI")
local Config = require("Config")
local UIState = require("UI.UIState")
local MoneyHUD = require("UI.MoneyHUD")
local Utils = require("UI.Utils")

local SettingsPanel = require("UI.SettingsPanel")

local MapScreen = {}

-- ===================== 建筑定位调试工具 =====================
local DEBUG_POSITION = false  -- 设为 true 开启调试拖拽
local debugState = {
    dragging = false,    -- 是否正在拖拽
    regionIdx = 0,       -- 当前拖拽的区域索引
    marker = nil,        -- 当前拖拽的 marker widget
    startMX = 0,         -- 拖拽开始时的鼠标 X（像素）
    startMY = 0,         -- 拖拽开始时的鼠标 Y（像素）
    origMapX = 0,        -- 拖拽开始时的 mapX
    origMapY = 0,        -- 拖拽开始时的 mapY
    positions = {},      -- { [i] = { mapX, mapY, name } }
    labels = {},         -- { [i] = coordLabel widget }
    summaryLabel = nil,  -- 右侧汇总文本 widget
}

local function updateSummaryText()
    if not debugState.summaryLabel then return end
    local lines = { "-- 建筑坐标 --" }
    for i, p in ipairs(debugState.positions) do
        lines[#lines + 1] = string.format(
            "%s: %.3f, %.3f", p.name, p.mapX, p.mapY
        )
    end
    debugState.summaryLabel:SetStyle({ text = table.concat(lines, "\n") })
end

local function updateCoordLabel(i)
    local lbl = debugState.labels[i]
    local p = debugState.positions[i]
    if lbl and p then
        lbl:SetStyle({ text = string.format("%.3f, %.3f", p.mapX, p.mapY) })
    end
end
-- ============================================================

---@param onBackCallback fun()
---@param onRegionSelected fun(regionIdx: number)
function MapScreen.Show(onBackCallback, onRegionSelected)
    UIState.currentScreen = "map"
    local C = Config.COLORS

    -- 使用 UI 框架的 base pixel 坐标空间（UI.GetWidth/GetHeight），
    -- 而非 graphics:GetWidth()/dpr（逻辑像素），两者在手机上不同
    local screenW = UI.GetWidth()
    local screenH = UI.GetHeight()
    local uiScale = UI.GetScale()  -- 用于调试拖拽时将鼠标物理坐标转为 UI 坐标
    local s = math.max(1.0, screenH / 720)
    local function sz(base) return math.floor(base * s) end

    -- 背景图 cover 定位：计算背景图 cover 后的实际显示尺寸和偏移
    -- 这样建筑百分比坐标始终相对于图片内容，不受屏幕比例影响
    local MAP_IMG_W, MAP_IMG_H = 1935, 1080
    local mapAspect = MAP_IMG_W / MAP_IMG_H
    local screenAspect = screenW / screenH
    local coverW, coverH
    if screenAspect > mapAspect then
        -- 屏幕更宽：图片按宽度撑满，高度溢出
        coverW = screenW
        coverH = screenW / mapAspect
    else
        -- 屏幕更窄：图片按高度撑满，宽度溢出
        coverH = screenH
        coverW = screenH * mapAspect
    end
    local coverOffX = (screenW - coverW) / 2  -- 负值表示图片左边超出屏幕
    local coverOffY = (screenH - coverH) / 2  -- 负值表示图片上边超出屏幕

    -- 初始化调试坐标
    debugState.positions = {}
    debugState.labels = {}
    for i, region in ipairs(Config.REGIONS) do
        debugState.positions[i] = { mapX = region.mapX, mapY = region.mapY, name = region.name }
    end

    -- 建筑图片 + 区域标记
    -- 定位策略：mapX/mapY 指向地块中心，建筑底部对齐到该中心点
    -- 每个区域可通过 imgW/imgH 自定义建筑尺寸
    local LABEL_H = sz(24)
    local DEF_IMG_W = 180  -- 默认建筑宽（未缩放）
    local DEF_IMG_H = 140  -- 默认建筑高（未缩放）

    local markerElements = {}
    for i, region in ipairs(Config.REGIONS) do
        local hasBuildingImg = region.buildingImg and region.buildingImg ~= ""
        local curW = sz(region.imgW or DEF_IMG_W)
        local curH = sz(region.imgH or DEF_IMG_H)
        local totalH = curH + LABEL_H

        -- 建筑图片容器（含描边层）
        local imgChild = nil
        ---@type table|nil
        local outlineRef = nil
        if hasBuildingImg then
            -- 描边：8 方向偏移同图副本，着色后叠在原图下方
            local OL = sz(2)  -- 描边粗细（像素）
            local OL_COLOR = { 80, 200, 255, 255 }  -- 青色描边
            local offsets = {
                { -OL, 0 }, { OL, 0 }, { 0, -OL }, { 0, OL },
                { -OL, -OL }, { OL, -OL }, { -OL, OL }, { OL, OL },
            }
            local olChildren = {}
            for _, off in ipairs(offsets) do
                olChildren[#olChildren + 1] = UI.Panel {
                    width = "100%", height = "100%",
                    position = "absolute",
                    left = off[1], top = off[2],
                    backgroundImage = region.buildingImg,
                    backgroundFit = "contain",
                    imageTint = OL_COLOR,
                    pointerEvents = "none",
                }
            end
            local outlineContainer = UI.Panel {
                width = "100%", height = "100%",
                position = "absolute", left = 0, top = 0,
                opacity = 0,
                transition = "opacity 0.15s easeOut",
                pointerEvents = "none",
                children = olChildren,
            }
            outlineRef = outlineContainer

            imgChild = UI.Panel {
                width = "100%", height = curH,
                position = "relative",
                pointerEvents = "none",
                children = {
                    outlineContainer,
                    -- 原始建筑图片（在描边层之上）
                    UI.Panel {
                        width = "100%", height = "100%",
                        backgroundImage = region.buildingImg,
                        backgroundFit = "contain",
                        pointerEvents = "none",
                    },
                },
            }
        end

        -- 调试坐标标签（显示在建筑下方）
        local coordLabel = nil
        if DEBUG_POSITION then
            coordLabel = UI.Label {
                text = string.format("%.3f, %.3f", region.mapX, region.mapY),
                fontSize = sz(9),
                fontColor = { 0, 255, 100, 255 },
                textAlign = "center",
                pointerEvents = "none",
            }
            debugState.labels[i] = coordLabel
        end

        -- 区域名称标签
        local labelChild = UI.Panel {
            width = "100%", height = LABEL_H,
            backgroundColor = { 10, 12, 20, 180 },
            borderWidth = 1,
            borderColor = { 220, 225, 235, 100 },
            justifyContent = "center", alignItems = "center",
            pointerEvents = "none",
            children = {
                UI.Label {
                    text = region.name, fontSize = sz(11),
                    fontColor = C.textPrimary, fontWeight = "bold",
                    textAlign = "center",
                    pointerEvents = "none",
                },
            },
        }

        local markerChildren = {}
        if imgChild then markerChildren[#markerChildren + 1] = imgChild end
        markerChildren[#markerChildren + 1] = labelChild
        if coordLabel then markerChildren[#markerChildren + 1] = coordLabel end

        -- 捕获循环变量用于闭包
        local regionIdx = i
        local regionMapX = region.mapX
        local regionMapY = region.mapY

        -- 定位：建筑图片中心对齐到平台中心(mapX,mapY)，标签在建筑下方
        -- 将图片坐标百分比转为屏幕像素（与 cover 对齐）
        local pixelX = math.floor(region.mapX * coverW + coverOffX)
        local pixelY = math.floor(region.mapY * coverH + coverOffY)

        local marker = UI.Panel {
            width = curW,
            height = hasBuildingImg and totalH or LABEL_H,
            position = "absolute",
            left = pixelX,
            top  = pixelY,
            marginLeft = -math.floor(curW / 2),
            marginTop  = hasBuildingImg and -math.floor(curH / 2) or -math.floor(LABEL_H / 2),
            alignItems = "center",
            cursor = "pointer",
            -- 悬浮动效：上浮 + 放大 + 轮廓描边
            scale = 1.0,
            translateY = 0,
            transition = DEBUG_POSITION and "" or "scale 0.25s easeOutBack, translateY 0.25s easeOut, opacity 0.15s easeOut",
            onPointerEnter = function(_, w)
                if not DEBUG_POSITION or not debugState.dragging then
                    w:SetStyle({ scale = 1.04, translateY = -3 })
                    if outlineRef then outlineRef:SetStyle({ opacity = 1 }) end
                end
            end,
            onPointerLeave = function(_, w)
                if not DEBUG_POSITION or not debugState.dragging then
                    w:SetStyle({ scale = 1.0, translateY = 0, opacity = 1.0 })
                    if outlineRef then outlineRef:SetStyle({ opacity = 0 }) end
                end
            end,
            onPointerDown = function(_, w)
                if DEBUG_POSITION then
                    -- 开始拖拽（鼠标物理坐标转 UI base pixel 坐标）
                    local mx = input:GetMousePosition().x / uiScale
                    local my = input:GetMousePosition().y / uiScale
                    debugState.dragging = true
                    debugState.regionIdx = regionIdx
                    debugState.marker = w
                    debugState.startMX = mx
                    debugState.startMY = my
                    debugState.origMapX = debugState.positions[regionIdx].mapX
                    debugState.origMapY = debugState.positions[regionIdx].mapY
                    w:SetStyle({ scale = 1.08, opacity = 0.9 })
                else
                    w:SetStyle({ scale = 0.95, opacity = 0.85 })
                end
            end,
            onPointerUp = function(_, w)
                if not DEBUG_POSITION then
                    w:SetStyle({ scale = 1.06, opacity = 1.0 })
                end
            end,
            onClick = function()
                if not DEBUG_POSITION then
                    Utils.PlayClick()
                    if onRegionSelected then
                        onRegionSelected(regionIdx)
                    end
                end
            end,
            children = markerChildren,
        }
        markerElements[#markerElements + 1] = marker
    end

    -- 调试：Update 事件处理拖拽
    if DEBUG_POSITION then
        SubscribeToEvent("Update", function()
            if not debugState.dragging then return end
            local mx = input:GetMousePosition().x / uiScale
            local my = input:GetMousePosition().y / uiScale
            -- 鼠标松开 → 结束拖拽
            if not input:GetMouseButtonDown(MOUSEB_LEFT) then
                debugState.dragging = false
                if debugState.marker then
                    debugState.marker:SetStyle({ scale = 1.0, opacity = 1.0 })
                end
                updateSummaryText()
                return
            end
            -- 计算新坐标（像素差 → 百分比差，相对于 cover 容器尺寸）
            local dx = mx - debugState.startMX
            local dy = my - debugState.startMY
            local newMapX = debugState.origMapX + dx / coverW
            local newMapY = debugState.origMapY + dy / coverH
            newMapX = math.max(0, math.min(1, newMapX))
            newMapY = math.max(0, math.min(1, newMapY))
            -- 更新位置
            debugState.positions[debugState.regionIdx].mapX = newMapX
            debugState.positions[debugState.regionIdx].mapY = newMapY
            debugState.marker:SetStyle({
                left = math.floor(newMapX * coverW + coverOffX),
                top  = math.floor(newMapY * coverH + coverOffY),
            })
            updateCoordLabel(debugState.regionIdx)
        end)
    end

    -- 调试汇总面板（右侧）
    local debugSummaryPanel = nil
    if DEBUG_POSITION then
        debugState.summaryLabel = UI.Label {
            text = "",
            fontSize = sz(9),
            fontColor = { 0, 255, 100, 255 },
            fontFamily = "monospace",
        }
        updateSummaryText()
        debugSummaryPanel = UI.Panel {
            position = "absolute",
            right = sz(8), top = sz(50),
            width = sz(160),
            padding = sz(6),
            backgroundColor = { 0, 0, 0, 200 },
            borderWidth = 1,
            borderColor = { 0, 255, 100, 80 },
            children = { debugState.summaryLabel },
        }
    end

    local mapChildren = { table.unpack(markerElements) }
    if debugSummaryPanel then
        mapChildren[#mapChildren + 1] = debugSummaryPanel
    end

    -- 地图层：全屏绝对定位，不受 SafeAreaView 影响
    -- 这样 cover 计算用的 screenW/screenH 与实际容器尺寸一致
    local mapLayer = UI.Panel {
        width = "100%", height = "100%",
        position = "absolute", left = 0, top = 0,
        overflow = "hidden",
        backgroundImage = Config.WORLD_MAP_BG,
        backgroundFit = "cover",
        children = mapChildren,
    }

    -- UI 浮层：放在 SafeAreaView 内，适配刘海/安全区域
    local uiOverlay = UI.Panel {
        width = "100%", height = "100%",
        pointerEvents = "box-none",  -- 自身透传，子控件可接收点击
        children = {
            -- 顶部栏（浮层，使用 Utils.sz 与竞拍大厅保持一致的视觉高度）
            UI.Panel {
                position = "absolute",
                top = 0, left = 0, right = 0,
                height = Utils.sz(44),
                paddingHorizontal = Utils.sz(12),
                flexDirection = "row", alignItems = "center",
                backgroundColor = { 0, 0, 0, 180 },
                pointerEvents = "auto",
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
            -- 底部返回按钮（浮层，与商店页同款样式）
            UI.Panel {
                position = "absolute",
                bottom = sz(6), left = sz(8),
                pointerEvents = "auto",
                children = {
                    UI.Button {
                        text = "返回",
                        paddingVertical = sz(7), paddingHorizontal = sz(16),
                        fontSize = sz(13), fontWeight = "bold",
                        fontColor = { 195, 215, 40, 230 },
                        backgroundColor = { 195, 215, 40, 20 },
                        hoverBackgroundColor = { 195, 215, 40, 50 },
                        pressedBackgroundColor = { 195, 215, 40, 110 },
                        borderWidth = 1, borderColor = { 195, 215, 40, 160 },
                        borderRadius = 0,
                        onClick = function()
                            Utils.PlayClick()
                            if onBackCallback then onBackCallback() end
                        end,
                    },
                },
            },
            SettingsPanel.CreatePopup(),
            MoneyHUD.CreatePopup(),
        }
    }

    UI.SetRoot(UI.Panel {
        width = "100%", height = "100%",
        backgroundColor = C.bgDark,
        children = {
            -- 第1层：地图背景+建筑（全屏，不在 SafeAreaView 内）
            mapLayer,
            -- 第2层：UI 浮层在 SafeAreaView 内（适配刘海）
            UI.SafeAreaView {
                edges = "all", width = "100%", height = "100%",
                pointerEvents = "box-none",  -- 自身透传，子控件可接收点击
                children = { uiOverlay },
            },
        },
    })
end

return MapScreen
