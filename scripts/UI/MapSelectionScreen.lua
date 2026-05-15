-- ============================================================================
-- UI/MapSelectionScreen.lua - 随机地图抽选轮盘
-- ============================================================================
-- 老虎机式滚动动画，在候选仓库类型间随机抽选。
-- 通过 UI.RegisterGlobalComponent 注册，自动获得 Update/Render 调用。

local UI = require("urhox-libs/UI")
local Config = require("Config")
local Utils = require("UI.Utils")

local MapSelectionScreen = {}

-- ---------------------------------------------------------------------------
-- 状态
-- ---------------------------------------------------------------------------
local state = {
    active = false,
    elapsed = 0,
    scrollOffset = 0,
    selectedTypeId = nil,
    lastTickCard = -1,   -- 上一帧经过的卡片索引，用于触发 slot_tick
    warehouseTypes = {},    -- { {id, name, icon}, ... }
    cards = {},             -- 展开后卡片列表（重复多轮）
    onSelected = nil,
    phase = "idle",         -- idle | spinning | result | done
    resultTimer = 0,
    targetCardIdx = 0,
}

-- NanoVG 图片句柄缓存 { [iconPath] = handle }
local imageCache = {}

-- ---------------------------------------------------------------------------
-- 常量
-- ---------------------------------------------------------------------------
local CARD_W = 140
local CARD_H = 170
local CARD_GAP = 14
local CARD_STEP = CARD_W + CARD_GAP

local IMG_H = 120           -- 卡片内图片高度
local LABEL_H = 50          -- 卡片内名字区域高度

local TOTAL_LOOPS = 8       -- 滚动圈数
local SPIN_DURATION = 3.5   -- 滚动时长（秒）
local RESULT_DELAY = 1.2    -- 结果展示时长

-- 卡片颜色（按候选索引循环）
local CARD_COLORS = {
    { bg = { 30, 100, 180, 255 }, border = { 60, 140, 220, 255 } },
    { bg = { 140, 50, 160, 255 }, border = { 180, 80, 200, 255 } },
    { bg = { 20, 130, 100, 255 }, border = { 40, 170, 140, 255 } },
    { bg = { 160, 80, 30, 255 },  border = { 200, 120, 60, 255 } },
    { bg = { 150, 30, 50, 255 },  border = { 190, 60, 80, 255 } },
}

-- ---------------------------------------------------------------------------
-- easeOutCubic
-- ---------------------------------------------------------------------------
local function easeOutCubic(t)
    local u = 1 - t
    return 1 - u * u * u
end

-- ---------------------------------------------------------------------------
-- 构建卡片列表（候选重复多轮）
-- ---------------------------------------------------------------------------
local function buildCards(warehouseTypes)
    local cards = {}
    local typeCount = #warehouseTypes
    local totalCards = typeCount * (TOTAL_LOOPS + 2)
    for i = 1, totalCards do
        local idx = ((i - 1) % typeCount) + 1
        local wt = warehouseTypes[idx]
        cards[i] = {
            id = wt.id,
            name = wt.name,
            icon = wt.icon,
            colorIdx = ((idx - 1) % #CARD_COLORS) + 1,
        }
    end
    return cards
end

-- 获取/创建 NanoVG 图片句柄
local function getImage(nvg, path)
    if not path or path == "" then return nil end
    if imageCache[path] then return imageCache[path] end
    local handle = nvgCreateImage(nvg, path, 0)
    if handle and handle > 0 then
        imageCache[path] = handle
        return handle
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- 注册为 UI 全局组件（延迟注册，确保 UI.Init 已完成）
-- ---------------------------------------------------------------------------
local registered = false

local function ensureRegistered()
    if not registered then
        UI.RegisterGlobalComponent("MapSelection", MapSelectionScreen)
        registered = true
    end
end

-- ---------------------------------------------------------------------------
-- Show
-- ---------------------------------------------------------------------------

---@param regionId string
---@param warehouseTypes string[] 候选仓库类型ID列表
---@param onSelected fun(warehouseTypeId: string)
function MapSelectionScreen.Show(regionId, warehouseTypes, onSelected)
    ensureRegistered()

    local types = {}
    for _, typeId in ipairs(warehouseTypes) do
        local wt = Config.WAREHOUSE_TYPES[typeId]
        if wt then
            types[#types + 1] = { id = typeId, name = wt.name, icon = wt.icon }
        end
    end

    if #types == 0 then
        print("[MapSelection] No valid warehouse types, skipping")
        if onSelected then onSelected(warehouseTypes[1] or "grocery") end
        return
    end

    local selectedIdx = math.random(1, #types)
    local selectedType = types[selectedIdx]
    local typeCount = #types
    local targetCardIdx = TOTAL_LOOPS * typeCount + selectedIdx

    state.active = true
    state.elapsed = 0
    state.scrollOffset = 0
    state.selectedTypeId = selectedType.id
    state.warehouseTypes = types
    state.cards = buildCards(types)
    state.onSelected = onSelected
    state.phase = "spinning"
    state.resultTimer = 0
    state.targetCardIdx = targetCardIdx
    state.lastTickCard = -1

    print("[MapSelection] Show: " .. #types .. " types, selected=" .. selectedType.name)
    Utils.PlaySfx("slot_spin")
end

-- ---------------------------------------------------------------------------
-- Hide / IsActive
-- ---------------------------------------------------------------------------
function MapSelectionScreen.Hide()
    state.active = false
    state.phase = "idle"
end

function MapSelectionScreen.IsActive()
    return state.active
end

-- ---------------------------------------------------------------------------
-- Update（由 UI 全局组件自动调用）
-- ---------------------------------------------------------------------------
function MapSelectionScreen:Update(dt)
    if not state.active then return end

    if state.phase == "spinning" then
        state.elapsed = state.elapsed + dt

        local screenW = UI.GetWidth()
        local targetOffset = (state.targetCardIdx - 1) * CARD_STEP + CARD_W / 2 - screenW / 2

        if state.elapsed >= SPIN_DURATION then
            state.scrollOffset = targetOffset
            state.phase = "result"
            state.resultTimer = 0
            Utils.PlaySfx("slot_result")
            print("[MapSelection] Landed on: " .. state.selectedTypeId)
        else
            local t = state.elapsed / SPIN_DURATION
            state.scrollOffset = easeOutCubic(t) * targetOffset
            -- 每滑过一张卡播放一次 tick
            local cardIdx = math.floor(state.scrollOffset / CARD_STEP)
            if cardIdx ~= state.lastTickCard then
                state.lastTickCard = cardIdx
                Utils.PlaySfx("slot_tick")
            end
        end

    elseif state.phase == "result" then
        state.resultTimer = state.resultTimer + dt
        if state.resultTimer >= RESULT_DELAY then
            state.phase = "done"
            state.active = false
            if state.onSelected then
                state.onSelected(state.selectedTypeId)
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Render（由 UI 全局组件自动调用，nvg 由框架传入）
-- ---------------------------------------------------------------------------
function MapSelectionScreen:Render(nvg)
    if not state.active then return end

    local screenW = UI.GetWidth()
    local screenH = UI.GetHeight()
    local centerX = screenW / 2
    local centerY = screenH / 2

    -- ===== 背景遮罩 =====
    nvgBeginPath(nvg)
    nvgRect(nvg, 0, 0, screenW, screenH)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, 200))
    nvgFill(nvg)

    -- ===== 标题 =====
    local titleText = "随机地图抽选中..."
    if state.phase == "result" then
        titleText = "地图已选定!"
    end

    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, 28)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER_VISUAL + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(255, 255, 255, 255))
    nvgText(nvg, centerX, centerY - CARD_H / 2 - 40, titleText)

    -- ===== 卡片滚动区域（裁剪） =====
    local clipW = math.min(screenW - 40, 600)
    local clipH = CARD_H + 30
    local clipX = centerX - clipW / 2
    local clipY = centerY - clipH / 2

    nvgSave(nvg)
    nvgIntersectScissor(nvg, clipX, clipY, clipW, clipH)

    for i, card in ipairs(state.cards) do
        local cardCenterX = (i - 1) * CARD_STEP + CARD_W / 2 - state.scrollOffset
        local cardX = cardCenterX - CARD_W / 2

        -- 只绘制可见区域
        if cardX + CARD_W > clipX - CARD_STEP and cardX < clipX + clipW + CARD_STEP then
            local colors = CARD_COLORS[card.colorIdx]
            local distFromCenter = math.abs(cardCenterX - centerX)
            local isCenter = distFromCenter < CARD_STEP / 2

            -- 透明度：远离中心越透明
            local alpha = 255
            if not isCenter then
                local nd = math.min(distFromCenter / (clipW / 2), 1)
                alpha = math.floor(255 * (1 - nd * 0.6))
            end

            -- 缩放（result 阶段中央卡片脉冲放大）
            local sc = 1.0
            if state.phase == "result" and isCenter then
                sc = 1.06 + math.sin(state.resultTimer * 4) * 0.02
            end

            local sw = CARD_W * sc
            local sh = CARD_H * sc
            local sx = cardCenterX - sw / 2
            local sy = centerY - sh / 2

            local isSelected = state.phase == "result" and isCenter
            local borderW = isSelected and 3 or 2
            local cornerR = 8

            -- 卡片背景
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, sx, sy, sw, sh, cornerR)
            nvgFillColor(nvg, nvgRGBA(25, 30, 45, alpha))
            nvgFill(nvg)

            if isSelected then
                nvgStrokeColor(nvg, nvgRGBA(255, 215, 0, 255))
            else
                nvgStrokeColor(nvg, nvgRGBA(colors.border[1], colors.border[2], colors.border[3], alpha))
            end
            nvgStrokeWidth(nvg, borderW)
            nvgStroke(nvg)

            -- 图片区域
            local imgX = sx + 4
            local imgY = sy + 4
            local imgW = sw - 8
            local imgH2 = IMG_H * sc

            local imgHandle = getImage(nvg, card.icon)
            if imgHandle then
                -- 绘制图片
                local paint = nvgImagePattern(nvg, imgX, imgY, imgW, imgH2, 0, imgHandle, alpha / 255.0)
                nvgBeginPath(nvg)
                nvgRoundedRect(nvg, imgX, imgY, imgW, imgH2, cornerR - 2)
                nvgFillPaint(nvg, paint)
                nvgFill(nvg)
            else
                -- 无图片时显示渐变色块
                nvgBeginPath(nvg)
                nvgRoundedRect(nvg, imgX, imgY, imgW, imgH2, cornerR - 2)
                nvgFillColor(nvg, nvgRGBA(colors.bg[1], colors.bg[2], colors.bg[3], alpha))
                nvgFill(nvg)

                -- 无图提示
                nvgFontFace(nvg, "sans")
                nvgFontSize(nvg, 14 * sc)
                nvgTextAlign(nvg, NVG_ALIGN_CENTER_VISUAL + NVG_ALIGN_MIDDLE)
                nvgFillColor(nvg, nvgRGBA(255, 255, 255, math.floor(alpha * 0.5)))
                nvgText(nvg, imgX + imgW / 2, imgY + imgH2 / 2, "?")
            end

            -- "SELECT" 标签（选中时显示）
            if isSelected then
                local selW = 60
                local selH = 20
                local selX = imgX + imgW / 2 - selW / 2
                local selY = imgY + 6
                nvgBeginPath(nvg)
                nvgRoundedRect(nvg, selX, selY, selW, selH, 4)
                nvgFillColor(nvg, nvgRGBA(255, 215, 0, 230))
                nvgFill(nvg)

                nvgFontFace(nvg, "sans")
                nvgFontSize(nvg, 11)
                nvgTextAlign(nvg, NVG_ALIGN_CENTER_VISUAL + NVG_ALIGN_MIDDLE)
                nvgFillColor(nvg, nvgRGBA(20, 20, 20, 255))
                nvgText(nvg, selX + selW / 2, selY + selH / 2, "SELECT")
            end

            -- 名字标签区域
            local labelY = sy + sh - LABEL_H * sc
            nvgFontFace(nvg, "sans")
            nvgFontSize(nvg, 14 * sc)
            nvgTextAlign(nvg, NVG_ALIGN_CENTER_VISUAL + NVG_ALIGN_MIDDLE)
            local ta = isSelected and 255 or alpha
            nvgFillColor(nvg, nvgRGBA(255, 255, 255, ta))
            nvgText(nvg, cardCenterX, labelY + LABEL_H * sc / 2, card.name)
        end
    end

    nvgRestore(nvg)

    -- ===== 中央指示框 =====
    local indicW = CARD_W + 10
    local indicH = CARD_H + 10
    local indicX = centerX - indicW / 2
    local indicY = centerY - indicH / 2

    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, indicX, indicY, indicW, indicH, 10)
    nvgStrokeColor(nvg, nvgRGBA(255, 255, 255, 150))
    nvgStrokeWidth(nvg, 2)
    nvgStroke(nvg)

    -- 上三角
    local triSize = 10
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, centerX - triSize, indicY - 4)
    nvgLineTo(nvg, centerX + triSize, indicY - 4)
    nvgLineTo(nvg, centerX, indicY - 4 - triSize)
    nvgClosePath(nvg)
    nvgFillColor(nvg, nvgRGBA(255, 255, 255, 200))
    nvgFill(nvg)

    -- 下三角
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, centerX - triSize, indicY + indicH + 4)
    nvgLineTo(nvg, centerX + triSize, indicY + indicH + 4)
    nvgLineTo(nvg, centerX, indicY + indicH + 4 + triSize)
    nvgClosePath(nvg)
    nvgFillColor(nvg, nvgRGBA(255, 255, 255, 200))
    nvgFill(nvg)

    -- ===== 底部提示 =====
    nvgFontFace(nvg, "sans")
    nvgTextAlign(nvg, NVG_ALIGN_CENTER_VISUAL + NVG_ALIGN_MIDDLE)
    if state.phase == "spinning" then
        nvgFontSize(nvg, 14)
        nvgFillColor(nvg, nvgRGBA(200, 200, 200, 180))
        nvgText(nvg, centerX, centerY + CARD_H / 2 + 40, "正在随机抽选仓库地图...")
    elseif state.phase == "result" then
        nvgFontSize(nvg, 18)
        nvgFillColor(nvg, nvgRGBA(255, 215, 0, 255))
        local wt = Config.WAREHOUSE_TYPES[state.selectedTypeId]
        local name = wt and wt.name or state.selectedTypeId
        nvgText(nvg, centerX, centerY + CARD_H / 2 + 40, "本局地图: " .. name)
    end
end

return MapSelectionScreen
