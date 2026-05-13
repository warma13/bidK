-- ============================================================================
-- Config/Warehouses/DataCenter.lua - 黑夜之城仓库配置
-- 赛博朋克风格，启用 5 个品类（无古董、日用）
-- 物品已合并到 Config/Categories/ 对应品类文件
-- ============================================================================

local DataCenter = {}

-- 品类权重
DataCenter.categoryWeights = {
    energy     = 25,   -- 核心能源模块
    transport  = 20,   -- 载具改装件 / 数据传输
    art        = 15,   -- 数字艺术 / 街头文化
    tech       = 25,   -- 黑客装备 / 初代遗物 / 义体饰品
    mechanical = 15,   -- 义体改装件
}

-- 限定品类（赛博风格，无古董/日用/珠宝）
DataCenter.allowedCategories = { "energy", "transport", "art", "tech", "mechanical" }

return DataCenter
