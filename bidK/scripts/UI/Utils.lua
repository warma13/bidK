-- ============================================================================
-- UI/Utils.lua - 工具函数（格式化、消息提示、音效）
-- ============================================================================

local Config = require("Config")

local Utils = {}

-- ============================================================================
-- 音效系统
-- ============================================================================

local sounds = {}
local bgmNode = nil
local currentBgmId = nil

--- 区域 → BGM 文件映射
local regionBgmMap = {
    oldtown    = "audio/bgm_oldtown.ogg",
    techpark   = "audio/bgm_techpark.ogg",
    bondedport = "audio/bgm_bondedport.ogg",
}
local defaultBgm = "audio/bgm_grocery.ogg"

---@type Scene
local scene_ = nil

function Utils.LoadSounds()
    -- 先停掉旧 BGM，防止切换 scene 后多 BGM 同时播放
    if bgmNode then
        bgmNode:Remove()
        bgmNode = nil
    end
    currentBgmId = nil

    scene_ = Scene()
    local sfxNames = { "bid_place", "bid_success", "bid_fail", "round_start", "timer_tick", "game_over", "ui_click" }
    for _, name in ipairs(sfxNames) do
        local sound = cache:GetResource("Sound", "audio/sfx/" .. name .. ".ogg")
        if sound then
            sounds[name] = sound
        end
    end
    -- 默认播放通用 BGM（大厅）
    Utils.PlayBgm(nil)
end

--- 根据区域ID切换 BGM
---@param regionId string|nil nil=默认BGM
function Utils.PlayBgm(regionId)
    local bgmPath = (regionId and regionBgmMap[regionId]) or defaultBgm
    if currentBgmId == bgmPath then return end
    currentBgmId = bgmPath

    -- 停止并移除旧 BGM 节点
    if bgmNode then
        local oldSource = bgmNode:GetComponent("SoundSource")
        if oldSource then oldSource:Stop() end
        bgmNode:Remove()
        bgmNode = nil
    end

    local bgmSound = cache:GetResource("Sound", bgmPath)
    if bgmSound and scene_ then
        bgmSound.looped = true
        bgmNode = scene_:CreateChild("BGM")
        local source = bgmNode:CreateComponent("SoundSource")
        source.soundType = SOUND_MUSIC
        source:SetGain(0.3)
        source:Play(bgmSound)
    end
end

function Utils.PlaySfx(name)
    local sound = sounds[name]
    if not sound or not scene_ then return end
    local node = scene_:CreateChild("SFX")
    local source = node:CreateComponent("SoundSource")
    source.soundType = SOUND_EFFECT
    source:SetGain(0.6)
    source.autoRemoveMode = REMOVE_NODE
    source:Play(sound)
end

function Utils.GetScene()
    return scene_
end

--- 播放 UI 点击音效（便捷方法）
function Utils.PlayClick()
    Utils.PlaySfx("ui_click")
end

-- ============================================================================
-- 图标资源映射
-- ============================================================================

local ICON_MAP = {
    coin = "金币.png",
}

--- 获取图标资源路径
---@param name string 图标名称（如 "coin"）
---@return string
function Utils.GetIcon(name)
    return ICON_MAP[name] or ""
end

-- ============================================================================
-- UI 缩放系数（基于屏幕逻辑高度，440px 为基准）
-- ============================================================================

--- 返回缩放系数（≥1.0，PC 上会变大，手机保持基准）
function Utils.GetScale()
    local dpr = graphics:GetDPR()
    local screenH = graphics:GetHeight() / dpr
    return math.max(1.0, screenH / 440)
end

--- 缩放尺寸：将设计基准值按屏幕比例放大
---@param base number 在 440px 高度下的基准像素
---@return number
function Utils.sz(base)
    return math.floor(base * Utils.GetScale())
end

-- ============================================================================
-- 格式化
-- ============================================================================

--- 精确金额（千分位，不缩写）：180,000,000
function Utils.FormatMoneyExact(amount)
    local s = tostring(math.floor(amount))
    local result = ""
    local count = 0
    for i = #s, 1, -1 do
        count = count + 1
        result = s:sub(i, i) .. result
        if count % 3 == 0 and i > 1 then
            result = "," .. result
        end
    end
    return result
end

function Utils.FormatMoney(amount)
    if amount >= 100000000 then
        -- ≥ 1亿
        return string.format("%.1f亿", amount / 100000000)
    elseif amount >= 10000 then
        -- ≥ 1万
        return string.format("%.1f万", amount / 10000)
    end
    local s = tostring(math.floor(amount))
    local result = ""
    local count = 0
    for i = #s, 1, -1 do
        count = count + 1
        result = s:sub(i, i) .. result
        if count % 3 == 0 and i > 1 then
            result = "," .. result
        end
    end
    return result
end

-- ============================================================================
-- 网格缩略图（可复用）
-- ============================================================================

local UI_LAZY = nil -- 延迟加载 UI 模块，避免循环依赖

local function getUI()
    if not UI_LAZY then UI_LAZY = require("urhox-libs/UI") end
    return UI_LAZY
end

--- 创建一个 W×H 网格缩略图控件
--- 返回 { widget, cells, update(w, h, color) }
---@param maxCols number 最大列数（如 5）
---@param maxRows number 最大行数（如 5）
---@param cellSize number 每格像素大小（如 5）
---@param cellGap number 格间距（如 1）
---@param opts? table 可选配置 { fillColor, emptyColor, position, right, bottom }
---@return table { widget: UIWidget, update: fun(w:number, h:number, color?:table) }
function Utils.CreateGridThumb(maxCols, maxRows, cellSize, cellGap, opts)
    local UI = getUI()
    opts = opts or {}
    local fillColor = opts.fillColor or { 200, 210, 220, 220 }
    local emptyColor = opts.emptyColor or { 60, 70, 90, 120 }

    local cells = {}
    local rowWidgets = {}
    for r = 1, maxRows do
        cells[r] = {}
        local rowChildren = {}
        for c = 1, maxCols do
            local cell = UI.Panel {
                width = cellSize, height = cellSize,
                borderRadius = 0,
                backgroundColor = emptyColor,
            }
            cells[r][c] = cell
            rowChildren[c] = cell
        end
        rowWidgets[r] = UI.Panel {
            flexDirection = "row",
            gap = cellGap,
            children = rowChildren,
        }
    end

    local widget = UI.Panel {
        position = opts.position,
        right = opts.right,
        bottom = opts.bottom,
        flexDirection = "column",
        gap = cellGap,
        children = rowWidgets,
    }

    local function update(w, h, color)
        local fc = color or fillColor
        for r = 1, maxRows do
            for c = 1, maxCols do
                if r <= h and c <= w then
                    cells[r][c]:SetStyle({ backgroundColor = fc })
                else
                    cells[r][c]:SetStyle({ backgroundColor = emptyColor })
                end
            end
        end
    end

    return { widget = widget, cells = cells, update = update }
end

-- ============================================================================
-- 消息提示
-- ============================================================================

function Utils.ShowMessage(text)
    local FloatingMessage = require("UI.FloatingMessage")
    FloatingMessage.Show(text)
end

-- 保留接口兼容，不再需要外部设置
function Utils.SetMessageRefs(_msgLabel) end
Utils._messageTimer = 0
function Utils.UpdateMessageTimer(_dt) end

return Utils
