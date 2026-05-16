-- ============================================================================
-- Config/Props.lua - 竞拍道具配置
-- ============================================================================

local Props = {}

-- 道具效果类型
Props.EFFECT = {
    SHOW_RARITY_CELL_COUNT  = "show_rarity_cell_count",   -- 显示指定品质物品的总格数
    SHOW_RARITY_ITEM_COUNT  = "show_rarity_item_count",   -- 显示指定品质物品的总数量
    SHOW_RANDOM_SILHOUETTE  = "show_random_silhouette",   -- 随机显示N件物品轮廓
    SHOW_SIZE_AVG_VALUE     = "show_size_avg_value",      -- 显示指定占位格数物品的平均价值
    SHOW_RANDOM_ITEM_INFO   = "show_random_item_info",    -- 随机显示一件物品的信息
    SHOW_RARITY_AVG_VALUE   = "show_rarity_avg_value",    -- 显示指定品质物品的总/均价值
}

-- 道具列表（按品质从低到高排序：白→绿→蓝→紫→红）
Props.LIST = {
    -- ── 白色品质 ──────────────────────────────
    {
        id = "scout_white_green_cells",
        name = "初级鉴定仪",
        desc = "显示所有绿色和白色品质物品的总格数",
        icon = "📦",
        iconImage = "image/prop_geo_01_20260515201141.png",
        effectType = Props.EFFECT.SHOW_RARITY_CELL_COUNT,
        effectParams = { rarities = { "white", "green" } },
        price = 1500,         -- 白色品质
        tier = "white",
        maxStack = 99,
    },
    {
        id = "scout_green_count",
        name = "绿品探测器",
        desc = "显示所有绿色品质物品的总数量",
        icon = "🔍",
        iconImage = "image/prop_geo_02_20260515201156.png",
        effectType = Props.EFFECT.SHOW_RARITY_ITEM_COUNT,
        effectParams = { rarities = { "green" } },
        price = 1500,         -- 白色品质
        tier = "white",
        maxStack = 99,
    },
    {
        id = "random_item_info",
        name = "物品侦察仪",
        desc = "随机显示一件物品的信息",
        icon = "🔎",
        iconImage = "image/prop_geo_03_20260515201255.png",
        effectType = Props.EFFECT.SHOW_RANDOM_ITEM_INFO,
        effectParams = {},
        price = 1500,         -- 白色品质
        tier = "white",
        maxStack = 99,
    },
    {
        id = "xray_2_silhouette",
        name = "轮廓探测器",
        desc = "随机显示两件物品的轮廓",
        icon = "👁️",
        iconImage = "image/prop_geo_04_20260515201138.png",
        effectType = Props.EFFECT.SHOW_RANDOM_SILHOUETTE,
        effectParams = { count = 2 },
        price = 1500,         -- 白色品质
        tier = "white",
        maxStack = 99,
    },
    {
        id = "appraise_green_value",
        name = "绿品估价仪",
        desc = "显示绿色品质物品的价值",
        icon = "💚",
        iconImage = "image/prop_geo_05_20260515201136.png",
        effectType = Props.EFFECT.SHOW_RARITY_AVG_VALUE,
        effectParams = { rarity = "green" },
        price = 1500,         -- 白色品质
        tier = "white",
        maxStack = 99,
    },
    -- ── 绿色品质 ──────────────────────────────
    {
        id = "xray_4_silhouette",
        name = "透视镜",
        desc = "随机显示4件物品轮廓",
        icon = "👁️",
        iconImage = "image/prop_geo_06_20260515201345.png",
        effectType = Props.EFFECT.SHOW_RANDOM_SILHOUETTE,
        effectParams = { count = 4 },
        price = 2500,         -- 绿色品质
        tier = "green",
        maxStack = 99,
    },
    {
        id = "scout_blue_cells",
        name = "中级鉴定仪",
        desc = "显示所有蓝色品质物品的总格数",
        icon = "📊",
        iconImage = "image/prop_geo_07_20260515201144.png",
        effectType = Props.EFFECT.SHOW_RARITY_CELL_COUNT,
        effectParams = { rarities = { "blue" } },
        price = 2500,         -- 绿色品质
        tier = "green",
        maxStack = 99,
    },
    -- ── 紫色品质 ──────────────────────────────
    {
        id = "appraise_4cell_value",
        name = "大件估价器",
        desc = "显示占位4格物品的平均价值",
        icon = "💎",
        iconImage = "image/prop_geo_08_new_20260515204523.png",
        effectType = Props.EFFECT.SHOW_SIZE_AVG_VALUE,
        effectParams = { cellCount = 4 },
        price = 30000,        -- 紫色品质
        tier = "purple",
        dailyLimit = 1,       -- 蓝色及以上每日限购1
        maxStack = 99,
    },
}

-- 按 id 索引
Props.BY_ID = {}
for _, item in ipairs(Props.LIST) do
    Props.BY_ID[item.id] = item
end

return Props
