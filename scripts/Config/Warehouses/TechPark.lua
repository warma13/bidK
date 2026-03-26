-- ============================================================================
-- Config/Warehouses/TechPark.lua - 科技产业园物品配置
-- 复用 ItemPool 共享物品池，使用不同的品类权重
-- 侧重科技、艺术、机械、珠宝品类
-- ============================================================================

local ItemPool = require("Config.Warehouses.ItemPool")

local TechPark = {}

-- 品类权重（科技产业园：侧重现代科技和工业品类）
TechPark.categoryWeights = {
    tech       = 25,   -- 科技（主力品类）
    art        = 20,   -- 艺术
    mechanical = 20,   -- 机械
    jewel      = 15,   -- 珠宝
    antique    = 10,   -- 古董
    energy     = 5,    -- 能源
    transport  = 5,    -- 交通
}

-- 直接复用 ItemPool 的品类列表
TechPark.categories = ItemPool.categories

return TechPark
