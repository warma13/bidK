-- ============================================================================
-- Config/Props.lua - 竞拍道具配置
-- ============================================================================

local Props = {}

-- 道具效果类型
Props.EFFECT = {
    SHOW_RARITY_CELL_COUNT     = "show_rarity_cell_count",      -- 显示指定品质物品的总格数
    SHOW_RARITY_ITEM_COUNT     = "show_rarity_item_count",      -- 显示指定品质物品的总数量
    SHOW_RANDOM_SILHOUETTE     = "show_random_silhouette",      -- 随机显示N件物品轮廓
    SHOW_SIZE_AVG_VALUE        = "show_size_avg_value",         -- 显示指定占位格数物品的平均价值
    SHOW_RANDOM_ITEM_INFO      = "show_random_item_info",       -- 随机显示一件物品的信息
    SHOW_RARITY_AVG_VALUE      = "show_rarity_avg_value",       -- 显示指定品质物品的总/均价值
    SHOW_RARITY_AVG_CELL_COUNT   = "show_rarity_avg_cell_count",   -- 显示指定品质物品的平均格数
    SHOW_RANDOM_ITEM_INFO_MULTI  = "show_random_item_info_multi",  -- 随机显示N件物品的完整信息
    SHOW_TOP_RARITY_SILHOUETTE   = "show_top_rarity_silhouette",   -- 显示最高品质物品的轮廓
    SHOW_LARGEST_ITEM_SILHOUETTE = "show_largest_item_silhouette", -- 显示占格最多物品的轮廓
    SHOW_CATEGORY_SILHOUETTE     = "show_category_silhouette",     -- 显示指定品类物品的轮廓
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
    {
        id = "dual_item_reveal",
        name = "双重侦察仪",
        desc = "随机显示两件物品的完整信息",
        icon = "🔭",
        iconImage = "image/prop_geo_09_20260516195128.png",
        effectType = Props.EFFECT.SHOW_RANDOM_ITEM_INFO_MULTI,
        effectParams = { count = 2 },
        price = 2500,         -- 绿色品质
        tier = "green",
        maxStack = 99,
    },
    {
        id = "avg_cell_blue",
        name = "蓝品格数仪",
        desc = "显示蓝色品质物品的平均格数",
        icon = "📐",
        iconImage = "image/prop_geo_10_20260516200521.png",
        effectType = Props.EFFECT.SHOW_RARITY_AVG_CELL_COUNT,
        effectParams = { rarities = { "blue" } },
        price = 2500,         -- 绿色品质
        tier = "green",
        maxStack = 99,
    },
    {
        id = "avg_cell_purple",
        name = "紫品格数仪",
        desc = "显示紫色品质物品的平均格数",
        icon = "📏",
        iconImage = "image/prop_geo_11_20260516195657.png",
        effectType = Props.EFFECT.SHOW_RARITY_AVG_CELL_COUNT,
        effectParams = { rarities = { "purple" } },
        price = 2500,         -- 绿色品质
        tier = "green",
        maxStack = 99,
    },
    {
        id = "avg_cell_white_green",
        name = "低品格数仪",
        desc = "显示白色和绿色品质物品的平均格数",
        icon = "📋",
        iconImage = "image/prop_geo_12_20260516195707.png",
        effectType = Props.EFFECT.SHOW_RARITY_AVG_CELL_COUNT,
        effectParams = { rarities = { "white", "green" } },
        price = 2500,         -- 绿色品质
        tier = "green",
        maxStack = 99,
    },
    {
        id = "total_value_green",
        name = "绿品总价仪",
        desc = "显示绿色品质物品的总价值",
        icon = "💰",
        iconImage = "image/prop_geo_13_20260516195658.png",
        effectType = Props.EFFECT.SHOW_RARITY_AVG_VALUE,
        effectParams = { rarity = "green", showTotalOnly = true },
        price = 2500,         -- 绿色品质
        tier = "green",
        maxStack = 99,
    },
    -- ── 蓝色品质（每日商店）──────────────────────────────
    {
        id = "top_rarity_silhouette",
        name = "极品探测仪",
        desc = "显示仓库中最高品质物品的轮廓",
        icon = "🔭",
        iconImage = "image/prop_geo_14_20260516212237.png",
        effectType = Props.EFFECT.SHOW_TOP_RARITY_SILHOUETTE,
        effectParams = {},
        price = 8000,
        tier = "blue",
        dailyLimit = 1,
        maxStack = 99,
        dailyShop = true,
    },
    {
        id = "largest_item_silhouette",
        name = "大件透视仪",
        desc = "显示仓库中占格最多的物品的轮廓",
        icon = "📐",
        iconImage = "image/prop_geo_15_20260516212038.png",
        effectType = Props.EFFECT.SHOW_LARGEST_ITEM_SILHOUETTE,
        effectParams = {},
        price = 8000,
        tier = "blue",
        dailyLimit = 1,
        maxStack = 99,
        dailyShop = true,
    },
    {
        id = "purple_total_value",
        name = "紫品估值仪",
        desc = "显示仓库中紫色品质物品的总价值",
        icon = "💜",
        iconImage = "image/prop_geo_16_20260516212040.png",
        effectType = Props.EFFECT.SHOW_RARITY_AVG_VALUE,
        effectParams = { rarity = "purple", showTotalOnly = true },
        price = 8000,
        tier = "blue",
        dailyLimit = 1,
        maxStack = 99,
        dailyShop = true,
    },
    -- ── 蓝色品质（每日商店）- 品类透视镜 ──────────────────────────────
    {
        id = "cat_silhouette_antique",
        name = "古董透视镜",
        desc = "显示仓库中所有古董品类物品的轮廓",
        icon = "🏺",
        iconImage = "image/prop_cat_antique.png",
        effectType = Props.EFFECT.SHOW_CATEGORY_SILHOUETTE,
        effectParams = { categoryId = "antique", categoryName = "古董" },
        price = 8000, tier = "blue", dailyLimit = 1, maxStack = 99, dailyShop = true,
    },
    {
        id = "cat_silhouette_daily",
        name = "日用透视镜",
        desc = "显示仓库中所有日用品类物品的轮廓",
        icon = "🧴",
        iconImage = "image/prop_cat_daily.png",
        effectType = Props.EFFECT.SHOW_CATEGORY_SILHOUETTE,
        effectParams = { categoryId = "daily", categoryName = "日用" },
        price = 8000, tier = "blue", dailyLimit = 1, maxStack = 99, dailyShop = true,
    },
    {
        id = "cat_silhouette_energy",
        name = "能源透视镜",
        desc = "显示仓库中所有能源品类物品的轮廓",
        icon = "⚡",
        iconImage = "image/prop_cat_energy.png",
        effectType = Props.EFFECT.SHOW_CATEGORY_SILHOUETTE,
        effectParams = { categoryId = "energy", categoryName = "能源" },
        price = 8000, tier = "blue", dailyLimit = 1, maxStack = 99, dailyShop = true,
    },
    {
        id = "cat_silhouette_transport",
        name = "交通透视镜",
        desc = "显示仓库中所有交通品类物品的轮廓",
        icon = "🚗",
        iconImage = "image/prop_cat_transport.png",
        effectType = Props.EFFECT.SHOW_CATEGORY_SILHOUETTE,
        effectParams = { categoryId = "transport", categoryName = "交通" },
        price = 8000, tier = "blue", dailyLimit = 1, maxStack = 99, dailyShop = true,
    },
    {
        id = "cat_silhouette_tech",
        name = "科技透视镜",
        desc = "显示仓库中所有科技品类物品的轮廓",
        icon = "💻",
        iconImage = "image/prop_cat_tech.png",
        effectType = Props.EFFECT.SHOW_CATEGORY_SILHOUETTE,
        effectParams = { categoryId = "tech", categoryName = "科技" },
        price = 8000, tier = "blue", dailyLimit = 1, maxStack = 99, dailyShop = true,
    },
    {
        id = "cat_silhouette_art",
        name = "艺术透视镜",
        desc = "显示仓库中所有艺术品类物品的轮廓",
        icon = "🎨",
        iconImage = "image/prop_cat_art.png",
        effectType = Props.EFFECT.SHOW_CATEGORY_SILHOUETTE,
        effectParams = { categoryId = "art", categoryName = "艺术" },
        price = 8000, tier = "blue", dailyLimit = 1, maxStack = 99, dailyShop = true,
    },
    {
        id = "cat_silhouette_jewel",
        name = "珠宝透视镜",
        desc = "显示仓库中所有珠宝品类物品的轮廓",
        icon = "💎",
        iconImage = "image/prop_cat_jewel.png",
        effectType = Props.EFFECT.SHOW_CATEGORY_SILHOUETTE,
        effectParams = { categoryId = "jewel", categoryName = "珠宝" },
        price = 8000, tier = "blue", dailyLimit = 1, maxStack = 99, dailyShop = true,
    },
    {
        id = "cat_silhouette_mechanical",
        name = "机械透视镜",
        desc = "显示仓库中所有机械品类物品的轮廓",
        icon = "⚙️",
        iconImage = "image/prop_cat_mechanical.png",
        effectType = Props.EFFECT.SHOW_CATEGORY_SILHOUETTE,
        effectParams = { categoryId = "mechanical", categoryName = "机械" },
        price = 8000, tier = "blue", dailyLimit = 1, maxStack = 99, dailyShop = true,
    },
    {
        id = "cat_silhouette_fashion",
        name = "服饰透视镜",
        desc = "显示仓库中所有服饰品类物品的轮廓",
        icon = "👗",
        iconImage = "image/prop_cat_fashion.png",
        effectType = Props.EFFECT.SHOW_CATEGORY_SILHOUETTE,
        effectParams = { categoryId = "fashion", categoryName = "服饰" },
        price = 8000, tier = "blue", dailyLimit = 1, maxStack = 99, dailyShop = true,
    },
    {
        id = "cat_silhouette_biotech",
        name = "医疗透视镜",
        desc = "显示仓库中所有医疗品类物品的轮廓",
        icon = "🧬",
        iconImage = "image/prop_cat_biotech.png",
        effectType = Props.EFFECT.SHOW_CATEGORY_SILHOUETTE,
        effectParams = { categoryId = "biotech", categoryName = "医疗" },
        price = 8000, tier = "blue", dailyLimit = 1, maxStack = 99, dailyShop = true,
    },
    -- ── 紫色品质（每日商店）──────────────────────────────
    {
        id = "appraise_4cell_value",
        name = "大件估价器",
        desc = "显示占位4格物品的平均价值",
        icon = "💎",
        iconImage = "image/prop_geo_08_new_20260515204523.png",
        effectType = Props.EFFECT.SHOW_SIZE_AVG_VALUE,
        effectParams = { cellCount = 4 },
        price = 30000,
        tier = "purple",
        dailyLimit = 1,
        maxStack = 99,
        dailyShop = true,
    },
    {
        id = "gold_rarity_cell_count",
        name = "金品占格仪",
        desc = "显示仓库中所有金色品质物品的总格数",
        icon = "🟨",
        iconImage = "image/prop_geo_17_20260516212039.png",
        effectType = Props.EFFECT.SHOW_RARITY_CELL_COUNT,
        effectParams = { rarities = { "gold" } },
        price = 30000,
        tier = "purple",
        dailyLimit = 1,
        maxStack = 99,
        dailyShop = true,
    },
    {
        id = "gold_rarity_item_count",
        name = "金品计数仪",
        desc = "显示仓库中所有金色品质物品的总数量",
        icon = "🏅",
        iconImage = "image/prop_geo_17_20260516212039.png",
        effectType = Props.EFFECT.SHOW_RARITY_ITEM_COUNT,
        effectParams = { rarities = { "gold" } },
        price = 30000,
        tier = "purple",
        dailyLimit = 1,
        maxStack = 99,
        dailyShop = true,
    },
    {
        id = "gold_rarity_avg_cell_count",
        name = "金品格数仪",
        desc = "显示仓库中金色品质物品的平均格数",
        icon = "📊",
        iconImage = "image/prop_geo_17_20260516212039.png",
        effectType = Props.EFFECT.SHOW_RARITY_AVG_CELL_COUNT,
        effectParams = { rarities = { "gold" } },
        price = 30000,
        tier = "purple",
        dailyLimit = 1,
        maxStack = 99,
        dailyShop = true,
    },
    {
        id = "gold_rarity_total_value",
        name = "金品估值仪",
        desc = "显示仓库中所有金色品质物品的总价值",
        icon = "💛",
        iconImage = "image/prop_geo_17_20260516212039.png",
        effectType = Props.EFFECT.SHOW_RARITY_AVG_VALUE,
        effectParams = { rarity = "gold", showTotalOnly = true },
        price = 30000,
        tier = "purple",
        dailyLimit = 1,
        maxStack = 99,
        dailyShop = true,
    },
}

-- 按 id 索引
Props.BY_ID = {}
for _, item in ipairs(Props.LIST) do
    Props.BY_ID[item.id] = item
end

return Props
