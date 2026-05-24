-- ============================================================================
-- UI/PersonalInfoUtils.lua
-- 个人信息页共享工具：常量、格式化函数、图标辅助
-- ============================================================================

---@diagnostic disable: undefined-global

local UI = require("urhox-libs/UI")
local Utils = require("UI.Utils")

local PersonalInfoUtils = {}

-- ── 常量 ──────────────────────────────────────────────────────────────────────

PersonalInfoUtils.RARITY_COLORS = {
    red    = { 235, 80,  60,  255 },
    gold   = { 220, 180, 60,  255 },
    purple = { 170, 100, 230, 255 },
    blue   = { 80,  150, 230, 255 },
    green  = { 80,  200, 120, 255 },
    white  = { 190, 192, 200, 255 },
}

PersonalInfoUtils.PROP_HEX_TINT = {
    white  = { 190, 192, 200, 220 },
    green  = { 80,  230, 120, 255 },
    blue   = { 80,  160, 255, 255 },
    purple = { 200, 100, 255, 255 },
    red    = { 255,  80,  80, 255 },
}

PersonalInfoUtils.COIN_IMG = "金币.png"

-- ── 格式化工具 ─────────────────────────────────────────────────────────────────

function PersonalInfoUtils.FormatPlayTime(seconds)
    seconds = math.floor(seconds or 0)
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    if h > 0 then return h .. "小时" .. m .. "分钟"
    elseif m > 0 then return m .. "分钟"
    else return seconds .. "秒" end
end

function PersonalInfoUtils.FormatNum(n)
    n = math.floor(n or 0)
    local abs = math.abs(n)
    if abs >= 100000000 then return string.format("%.1f亿", n / 100000000)
    elseif abs >= 10000  then return string.format("%.1f万", n / 10000) end
    local neg = n < 0
    local s, result, count = tostring(abs), "", 0
    for i = #s, 1, -1 do
        count = count + 1
        result = s:sub(i, i) .. result
        if count % 3 == 0 and i > 1 then result = "," .. result end
    end
    return neg and ("-" .. result) or result
end

function PersonalInfoUtils.FormatPct(num, denom)
    if not denom or denom == 0 then return "0.0%" end
    return string.format("%.1f%%", num / denom * 100)
end

function PersonalInfoUtils.FormatDate(ts)
    if not ts or ts == 0 then return "—" end
    return os.date("%Y-%m-%d %H:%M", ts)
end

-- ── 图标辅助 ───────────────────────────────────────────────────────────────────

-- 生成内联金币图标 Panel（正方形，backgroundFit contain）
function PersonalInfoUtils.CoinIcon(size)
    return UI.Panel {
        width = size, height = size, flexShrink = 0,
        backgroundImage = PersonalInfoUtils.COIN_IMG,
        backgroundFit = "contain",
    }
end

-- 生成道具六边形图标（hexW×hexH 容器，内含六边形框 + 道具图）
-- propDef: Props.BY_ID[id] 或 nil（空格时传 nil）
-- hexW/hexH: 六边形容器尺寸（保持 78:90 比例）
-- iconSize: 内部图标尺寸
function PersonalInfoUtils.MakePropHexIcon(propDef, hexW, hexH, iconSize)
    local tint = propDef and (PersonalInfoUtils.PROP_HEX_TINT[propDef.tier] or PersonalInfoUtils.PROP_HEX_TINT.white)
                          or { 120, 122, 135, 80 }  -- 空格：灰暗
    local inner
    if propDef then
        if (propDef.iconImage or "") ~= "" then
            inner = UI.Panel {
                width = iconSize, height = iconSize,
                backgroundImage = propDef.iconImage,
                backgroundFit = "contain",
            }
        else
            inner = UI.Label {
                text = propDef.icon or "?",
                fontSize = iconSize * 0.75,
                textAlign = "center",
            }
        end
    end
    local children = {
        UI.Panel {
            position = "absolute",
            width = hexW, height = hexH,
            backgroundImage = "image/ui_hex_frame_trimmed.png",
            backgroundFit = "fill",
            imageTint = tint,
        },
    }
    if inner then children[#children + 1] = inner end
    return UI.Panel {
        width = hexW, height = hexH,
        alignItems = "center", justifyContent = "center",
        children = children,
    }
end

return PersonalInfoUtils
