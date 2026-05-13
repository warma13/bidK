-- ============================================================================
-- UI/FloatingMessage.lua - 浮动消息提示
-- 文字从屏幕中上方出现，向上浮动并渐渐消失
-- 新消息会把旧消息挤到上面
-- ============================================================================

local UI = require("urhox-libs/UI")

local FloatingMessage = {}

--- @class FloatMsg
--- @field text string
--- @field age number
local messages = {}

---@type NVGContextWrapper
local vg = nil
local initialized = false

-- ── 视觉参数 ──────────────────────────────────────────────
local BASE_Y_RATIO   = 0.28    -- 基准位置：屏幕高度的 28%
local FLOAT_SPEED    = 25      -- 每秒向上浮动像素
local TOTAL_DURATION = 2.2     -- 总持续时间(秒)
local FADE_START     = 0.8     -- 开始淡出的时间点
local FONT_SIZE      = 16
local MSG_SPACING    = 30      -- 消息之间的间距
local BG_PAD_H       = 14      -- 背景水平内边距
local BG_PAD_V       = 5       -- 背景垂直内边距

-- ── 初始化 ────────────────────────────────────────────────

function FloatingMessage.Init()
    if initialized then return end
    vg = UI.GetNVGContext()
    if not vg then return end
    initialized = true
    SubscribeToEvent("NanoVGRender", "HandleFloatingMessageRender")
    -- 注意：不要在这里 SubscribeToEvent("Update")，
    -- 因为会覆盖 main.lua 的 HandleUpdate 导致游戏卡死。
    -- Update 由 Standalone.HandleUpdate 统一调用。
end

-- ── 公共接口 ──────────────────────────────────────────────

--- 显示一条浮动消息
---@param text string
function FloatingMessage.Show(text)
    if not initialized then FloatingMessage.Init() end
    if not vg then return end
    -- 最多保留 6 条，超出移除最老的
    while #messages >= 6 do
        table.remove(messages, 1)
    end
    table.insert(messages, {
        text = tostring(text),
        age  = 0,
    })
end

--- 每帧更新（从 GameController.HandleUpdate 调用）
---@param dt number
function FloatingMessage.Update(dt)
    for i = #messages, 1, -1 do
        local msg = messages[i]
        msg.age = msg.age + dt
        if msg.age >= TOTAL_DURATION then
            table.remove(messages, i)
        end
    end
end

-- ── NanoVG 渲染 ──────────────────────────────────────────

--- 全局事件处理函数
function HandleFloatingMessageRender()
    FloatingMessage.Render()
end

function FloatingMessage.Render()
    if #messages == 0 or not vg then return end

    local dpr = graphics:GetDPR()
    local w = graphics:GetWidth() / dpr
    local h = graphics:GetHeight() / dpr

    nvgBeginFrame(vg, w, h, dpr)

    nvgFontFace(vg, "sans")
    nvgFontSize(vg, FONT_SIZE)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    local baseY = h * BASE_Y_RATIO
    local cx = w / 2

    for i = #messages, 1, -1 do
        local msg = messages[i]
        local slot = #messages - i  -- 0 = 最新

        -- 位置：基准 + 被新消息挤上去的偏移 + 自然上浮
        local y = baseY - slot * MSG_SPACING - msg.age * FLOAT_SPEED

        -- 透明度：前 FADE_START 秒全不透明，之后线性淡出
        local alpha
        if msg.age < FADE_START then
            alpha = 1.0
        else
            alpha = 1.0 - (msg.age - FADE_START) / (TOTAL_DURATION - FADE_START)
        end
        alpha = math.max(0, math.min(1, alpha))
        local a = math.floor(alpha * 255)
        if a <= 0 then goto continue end

        -- 测量文本宽度
        local tw = nvgTextBounds(vg, 0, 0, msg.text) or 0
        local bgW = tw + BG_PAD_H * 2
        local bgH = FONT_SIZE + BG_PAD_V * 2

        -- 半透明背景药丸
        nvgBeginPath(vg)
        nvgRoundedRect(vg, cx - bgW / 2, y - bgH / 2, bgW, bgH, bgH / 2)
        nvgFillColor(vg, nvgRGBA(0, 0, 0, math.floor(110 * alpha)))
        nvgFill(vg)

        -- 文字
        nvgFillColor(vg, nvgRGBA(255, 255, 255, a))
        nvgText(vg, cx, y, msg.text)

        ::continue::
    end

    nvgEndFrame(vg)
end

return FloatingMessage
