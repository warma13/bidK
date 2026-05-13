-- ============================================================================
-- Config/Warehouses/ItemPool.lua - 统一物品池聚合器
-- 聚合 10 个品类文件，提供全区域共享的统一物品池
-- 各仓库通过 allowedCategories + categoryWeights 控制品类筛选和权重
-- ============================================================================

local Antique    = require("Config.Categories.Antique")
local Daily      = require("Config.Categories.Daily")
local Energy     = require("Config.Categories.Energy")
local Transport  = require("Config.Categories.Transport")
local Tech       = require("Config.Categories.Tech")
local Art        = require("Config.Categories.Art")
local Jewel      = require("Config.Categories.Jewel")
local Mechanical = require("Config.Categories.Mechanical")
local Fashion    = require("Config.Categories.Fashion")
local Biotech    = require("Config.Categories.Biotech")

local ItemPool = {}

-- 默认品类权重（通用仓库/杂货铺使用）
ItemPool.categoryWeights = {
    antique    = 25,   -- 古董
    energy     = 35,   -- 能源（主力品类）
    tech       = 30,   -- 科技
    art        = 5,    -- 艺术
    jewel      = 5,    -- 珠宝
    transport  = 5,    -- 交通
    mechanical = 5,    -- 机械
    daily      = 0,    -- 日用（仅港口/沉船类仓库启用）
    fashion    = 0,    -- 服饰奢品（仅特定仓库启用）
    biotech    = 0,    -- 医疗（仅特定仓库启用）
}

-- 统一品类列表
ItemPool.categories = {
    { id = "antique",    name = "古董",   icon = "", items = Antique.items },
    { id = "daily",      name = "日用",   icon = "", items = Daily.items },
    { id = "energy",     name = "能源",   icon = "", items = Energy.items },
    { id = "transport",  name = "交通",   icon = "", items = Transport.items },
    { id = "tech",       name = "科技",   icon = "", items = Tech.items },
    { id = "art",        name = "艺术",   icon = "", items = Art.items },
    { id = "jewel",      name = "珠宝",   icon = "", items = Jewel.items },
    { id = "mechanical", name = "机械",   icon = "", items = Mechanical.items },
    { id = "fashion",    name = "服饰",   icon = "", items = Fashion.items },
    { id = "biotech",    name = "医疗",   icon = "", items = Biotech.items },
}

return ItemPool
