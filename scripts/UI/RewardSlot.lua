-- ============================================================================
-- UI/RewardSlot.lua  共享奖励格子组件
-- ============================================================================
-- 所有面板（MailPanel、AdCardPanel、OnlineRewardPanel、TaskPanel、
-- VersionRewardPanel）统一调用此模块，避免重复实现。
--
-- 对外 API:
--   RewardSlot.Make(opts, sz)            → UI.Panel  单个格子
--   RewardSlot.FromReward(reward, sz)    → UI.Panel  直接由 reward 表生成
--   RewardSlot.Row(slots, sz, gap)       → UI.Panel  横排格子组（flexDirection="row"）
-- ============================================================================

local UI     = require("urhox-libs/UI")
local Config = require("Config")

local RewardSlot = {}

-- 统一尺寸常量（基准：sz(46)，若调用方传入 sz 函数则自动缩放）
local SLOT_BASE    = 46
local ICON_BASE    = 30
local COUNT_FONT   = 9
local COUNT_RIGHT  = 2
local COUNT_BOTTOM = 1

-- 格子底图（全局统一）
local SLOT_BG = "image/backpack_card_bg_20260518071322.png"

-- 右下角数量文字颜色
local COUNT_COLOR = { 255, 228, 100, 255 }

-- 格子边框颜色
local BORDER_COLOR = { 100, 100, 105, 180 }

-- ──────────────────────────────────────────────────────────────────────────────
-- Make(opts, sz)
-- opts 字段：
--   image        string|nil   图标资源路径
--   iconText     string|nil   无图标时显示的 emoji / 文字
--   iconFontSize number|nil
--   iconColor    table|nil
--   count        string|nil   右下角文案（已格式化）
--   size         number|nil   格子边长（默认 SLOT_BASE，单位：sz 入参前的基准值）
--   onClick      fn|nil
--   tint         table|nil    底图着色
-- ──────────────────────────────────────────────────────────────────────────────
function RewardSlot.Make(opts, sz)
    local slotPx  = sz(opts.size or SLOT_BASE)
    local iconPx  = sz(math.floor((opts.size or SLOT_BASE) * ICON_BASE / SLOT_BASE))
    local cFont   = sz(COUNT_FONT)
    local cRight  = sz(COUNT_RIGHT)
    local cBottom = sz(COUNT_BOTTOM)

    local iconNode
    if opts.customIcon then
        -- 调用方直接传入已构建好的图标节点（如 PropCardWidget.HexIcon）
        iconNode = opts.customIcon
    elseif opts.image and opts.image ~= "" then
        iconNode = UI.Panel {
            width = iconPx, height = iconPx,
            backgroundImage = opts.image,
            backgroundFit   = "contain",
            pointerEvents   = "none",
        }
    else
        iconNode = UI.Label {
            text      = opts.iconText or "?",
            fontSize  = opts.iconFontSize or sz(14),
            fontWeight = "bold",
            fontColor = opts.iconColor or { 255, 255, 255, 255 },
            pointerEvents = "none",
        }
    end

    local children = { iconNode }

    if opts.count and opts.count ~= "" then
        children[#children + 1] = UI.Panel {
            position = "absolute", right = cRight, bottom = cBottom,
            pointerEvents = "none",
            children = {
                UI.Label {
                    text      = tostring(opts.count),
                    fontSize  = cFont,
                    fontColor = COUNT_COLOR,
                    pointerEvents = "none",
                },
            },
        }
    end

    return UI.Panel {
        width    = slotPx, height = slotPx,
        backgroundImage = SLOT_BG,
        backgroundFit   = "cover",
        imageTint       = opts.tint or { 255, 255, 255, 255 },
        borderWidth     = 1,
        borderColor     = opts.borderColor or BORDER_COLOR,
        borderRadius    = 0,
        alignItems      = "center",
        justifyContent  = "center",
        overflow        = "hidden",
        cursor          = opts.onClick and "pointer" or nil,
        onClick         = opts.onClick,
        children        = children,
    }
end

-- ──────────────────────────────────────────────────────────────────────────────
-- FromReward(reward, sz, extraOpts)
-- 直接由 reward = { type, amount, ticketId } 生成格子
-- extraOpts 可覆盖 size / onClick / tint 等
-- ──────────────────────────────────────────────────────────────────────────────
function RewardSlot.FromReward(reward, sz, extraOpts)
    local opts   = extraOpts or {}
    opts.image   = opts.image or Config.GetRewardIcon(reward)
    opts.count   = opts.count or Config.GetRewardCount(reward)
    return RewardSlot.Make(opts, sz)
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Row(slotPanels, sz, gap)
-- 将多个格子横排打包成一行
-- ──────────────────────────────────────────────────────────────────────────────
function RewardSlot.Row(slotPanels, sz, gap)
    return UI.Panel {
        flexDirection = "row",
        alignItems    = "center",
        gap           = sz(gap or 6),
        children      = slotPanels,
    }
end

return RewardSlot
