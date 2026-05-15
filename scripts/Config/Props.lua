-- ============================================================================
-- Config/Props.lua - 竞拍道具配置
-- ============================================================================

local Props = {}

-- 道具效果类型
Props.EFFECT = {
    SHOW_RARITY_CELL_COUNT  = "show_rarity_cell_count",   -- 显示指定品质藏品的总格数
    SHOW_RARITY_ITEM_COUNT  = "show_rarity_item_count",   -- 显示指定品质藏品的总数量
    SHOW_RANDOM_SILHOUETTE  = "show_random_silhouette",   -- 随机显示N件藏品轮廓
    SHOW_SIZE_AVG_VALUE     = "show_size_avg_value",      -- 显示指定占位格数藏品的平均价值
}

-- 道具列表
Props.LIST = {
    {
        id = "scout_white_green_cells",
        name = "初级鉴定仪",
        desc = "显示所有绿色和白色品质藏品的总格数",
        icon = "📦",
        iconImage = "image/prop_icon_scanner_basic_20260515133521.png",
        effectType = Props.EFFECT.SHOW_RARITY_CELL_COUNT,
        effectParams = { rarities = { "white", "green" } },
        price = 1500,         -- 白色品质
        maxStack = 99,
    },
    {
        id = "scout_green_count",
        name = "绿品探测器",
        desc = "显示所有绿色品质藏品的总数量",
        icon = "🔍",
        iconImage = "image/prop_icon_detector_20260515133225.png",
        effectType = Props.EFFECT.SHOW_RARITY_ITEM_COUNT,
        effectParams = { rarities = { "green" } },
        price = 1500,         -- 白色品质
        maxStack = 99,
    },
    {
        id = "xray_4_silhouette",
        name = "透视镜",
        desc = "随机显示4件藏品轮廓",
        icon = "👁️",
        iconImage = "image/prop_icon_xray_20260515133226.png",
        effectType = Props.EFFECT.SHOW_RANDOM_SILHOUETTE,
        effectParams = { count = 4 },
        price = 2500,         -- 绿色品质
        maxStack = 99,
    },
    {
        id = "scout_blue_cells",
        name = "中级鉴定仪",
        desc = "显示所有蓝色品质藏品的总格数",
        icon = "📊",
        iconImage = "image/prop_icon_scanner_mid_20260515133225.png",
        effectType = Props.EFFECT.SHOW_RARITY_CELL_COUNT,
        effectParams = { rarities = { "blue" } },
        price = 2500,         -- 绿色品质
        maxStack = 99,
    },
    {
        id = "appraise_4cell_value",
        name = "大件估价器",
        desc = "显示占位4格藏品的平均价值",
        icon = "💎",
        iconImage = "image/prop_icon_appraiser_20260515133227.png",
        effectType = Props.EFFECT.SHOW_SIZE_AVG_VALUE,
        effectParams = { cellCount = 4 },
        price = 30000,        -- 紫色品质
        maxStack = 99,
    },
}

-- 按 id 索引
Props.BY_ID = {}
for _, item in ipairs(Props.LIST) do
    Props.BY_ID[item.id] = item
end

return Props
