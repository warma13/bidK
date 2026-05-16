-- UI/PopoverPatch.lua
-- 猴子补丁：覆盖 Popover.RenderPopoverContent，用 nvgTextBoxBounds 动态计算高度

local Popover = require("urhox-libs/UI/Widgets/Popover")
local Theme   = require("urhox-libs/UI/Core/Theme")
local UI      = require("urhox-libs/UI/Core/UI")

-- ============================================================================
-- 辅助：测量多行文本高度
-- nvgTextBoxBounds 返回 (minx, miny, maxx, maxy)，差值即文本包围盒高度
-- ============================================================================
local function measureTextBoxHeight(nvg, text, maxWidth)
    if not text or text == "" then return 0 end
    local bx0, by0, bx1, by1 = nvgTextBoxBounds(nvg, 0, 0, maxWidth, text)
    if by1 and by1 > (by0 or 0) then
        return by1 - by0
    end
    -- 降级估算：按中文字符宽约等于字号，换行数量
    local fontSize = Theme.FontSizeOf("body")
    local lineHeight = fontSize * 1.6
    local charsPerLine = math.max(1, math.floor(maxWidth / fontSize))
    local lines = 1
    for _ in text:gmatch("\n") do lines = lines + 1 end
    -- 粗估长度触发换行
    local rawLen = 0
    for _ in text:gmatch("[\0-\x7F\xC2-\xFD][\x80-\xBF]*") do rawLen = rawLen + 1 end
    lines = lines + math.floor(rawLen / charsPerLine)
    return lines * lineHeight
end

-- ============================================================================
-- 覆盖 RenderPopoverContent
-- ============================================================================
function Popover:RenderPopoverContent(nvg)
    local alpha = self.animating_ and self.animationProgress_ or 1

    local contentWidth  = self.maxWidth_
    local padding       = 16
    local paddingY      = 12
    local titleHeight   = 28
    local lineSpacing   = 6

    -- 先设置字体，再测量
    nvgFontSize(nvg, Theme.FontSizeOf("body"))
    nvgFontFace(nvg, Theme.FontFamily())

    local measuredH = 0
    if type(self.content_) == "string" then
        measuredH = measureTextBoxHeight(nvg, self.content_, contentWidth - padding * 2)
    end

    local contentHeight = paddingY * 2
    if self.title_ then
        contentHeight = contentHeight + titleHeight
        if measuredH > 0 then contentHeight = contentHeight + lineSpacing end
    end
    contentHeight = contentHeight + measuredH
    if contentHeight < 40 then contentHeight = 40 end

    -- 计算位置（使用类内部方法）
    local x, y = self:CalculatePosition(contentWidth, contentHeight)
    self.popoverBounds_ = { x = x, y = y, w = contentWidth, h = contentHeight }

    local borderRadius = self.props.borderRadius

    nvgSave(nvg)
    nvgGlobalAlpha(nvg, alpha)

    -- 阴影
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x + 2, y + 2, contentWidth, contentHeight, borderRadius)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, 30))
    nvgFill(nvg)

    -- 背景
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x, y, contentWidth, contentHeight, borderRadius)
    nvgFillColor(nvg, Theme.NvgColor("surface"))
    nvgFill(nvg)
    nvgStrokeColor(nvg, Theme.NvgColor("border"))
    nvgStrokeWidth(nvg, self.props.borderWidth or 1)
    nvgStroke(nvg)

    -- 箭头
    if self.showArrow_ then
        self:RenderArrow(nvg, x, y, contentWidth, contentHeight)
    end

    -- 标题
    local contentY = y + paddingY
    if self.title_ then
        nvgFontSize(nvg, Theme.FontSizeOf("body"))
        nvgFontFace(nvg, Theme.FontFamily())
        nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        nvgFillColor(nvg, Theme.NvgColor("text"))
        nvgText(nvg, x + padding, contentY, self.title_)
        contentY = contentY + titleHeight
        if measuredH > 0 then contentY = contentY + lineSpacing end
    end

    -- 内容文本
    if type(self.content_) == "string" then
        nvgFontSize(nvg, Theme.FontSizeOf("body"))
        nvgFontFace(nvg, Theme.FontFamily())
        nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        nvgFillColor(nvg, Theme.NvgColor("textSecondary"))
        nvgTextBox(nvg, x + padding, contentY, contentWidth - padding * 2, self.content_)
    elseif type(self.content_) == "function" then
        self.content_(nvg, x + padding, contentY, contentWidth - padding * 2, contentHeight - (contentY - y) - paddingY)
    end

    nvgRestore(nvg)
end

return Popover
