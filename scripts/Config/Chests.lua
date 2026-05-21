-- ============================================================================
-- Config/Chests.lua - 箱子/礼盒配置（藏品礼盒 + 道具箱）
-- 与 Props 完全分离，通过 BackpackScreen / LootBox / LootBoxPanel 使用
-- ============================================================================

local Chests = {}

Chests.LIST = {
    -- ── 藏品礼盒（开出藏品）──────────────────────────────────────────
    {
        id          = "chest_common",
        name        = "初级藏品礼盒",
        desc        = "开启可随机获得一件藏品，有极低概率获得红色稀有藏品",
        icon        = "🎁",
        iconImage   = "image/giftbox_luxury_20260517200306.png",
        tier        = "white",
        isChest     = true,
        canUseInMenu = true,
        maxStack    = 99,
        ticketPrice = 20,
    },
    {
        id          = "chest_silver",
        name        = "中级藏品礼盒",
        desc        = "开启可随机获得一件藏品，有极低概率获得红色稀有藏品",
        icon        = "🎁",
        iconImage   = "image/giftbox_luxury_20260517200306.png",
        tier        = "blue",
        isChest     = true,
        canUseInMenu = true,
        maxStack    = 99,
        ticketPrice = 30,
    },
    {
        id          = "chest_gold",
        name        = "高级藏品礼盒",
        desc        = "开启可随机获得一件藏品，有极低概率获得极稀有限定藏品",
        icon        = "🎁",
        iconImage   = "image/giftbox_luxury_20260517200306.png",
        tier        = "purple",
        isChest     = true,
        canUseInMenu = true,
        maxStack    = 99,
        ticketPrice = 40,
    },
    {
        id          = "chest_s1",
        name        = "通行证1期礼盒",
        desc        = "开启可随机获得一件藏品，有极低概率获得赛季稀有藏品",
        icon        = "🎁",
        iconImage   = "image/giftbox_luxury_20260517200306.png",
        tier        = "gold",
        isChest     = true,
        canUseInMenu = true,
        maxStack    = 99,
    },
    -- ── 道具箱（开出竞拍道具）────────────────────────────────────────
    {
        id          = "prop_box_white",
        name        = "白色道具箱",
        desc        = "开启可随机获得一件白色品质竞拍道具",
        icon        = "📦",
        iconImage   = "image/chest_luxury_20260517200416.png",
        tier        = "white",
        isChest     = true,
        isPropBox   = true,
        canUseInMenu = true,
        maxStack    = 99,
    },
    {
        id          = "prop_box_green",
        name        = "绿色道具箱",
        desc        = "开启可随机获得一件绿色品质竞拍道具",
        icon        = "📦",
        iconImage   = "image/chest_luxury_20260517200416.png",
        tier        = "green",
        isChest     = true,
        isPropBox   = true,
        canUseInMenu = true,
        maxStack    = 99,
    },
    {
        id          = "prop_box_blue",
        name        = "蓝色道具箱",
        desc        = "开启可随机获得一件蓝色品质竞拍道具",
        icon        = "📦",
        iconImage   = "image/chest_luxury_20260517200416.png",
        tier        = "blue",
        isChest     = true,
        isPropBox   = true,
        canUseInMenu = true,
        maxStack    = 99,
    },
    {
        id          = "prop_box_purple",
        name        = "紫色道具箱",
        desc        = "开启可随机获得一件紫色品质竞拍道具",
        icon        = "📦",
        iconImage   = "image/chest_luxury_20260517200416.png",
        tier        = "purple",
        isChest     = true,
        isPropBox   = true,
        canUseInMenu = true,
        maxStack    = 99,
    },
}

-- 按 id 索引
Chests.BY_ID = {}
for _, item in ipairs(Chests.LIST) do
    Chests.BY_ID[item.id] = item
end

return Chests
