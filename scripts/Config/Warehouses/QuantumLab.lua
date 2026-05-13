-- ============================================================================
-- Config/Warehouses/QuantumLab.lua - 量子实验室仓库配置
-- 前沿科学风格，启用 5 个品类（无古董、日用、交通）
-- 物品已合并到 Config/Categories/ 对应品类文件
-- ============================================================================

local QuantumLab = {}

-- 品类权重
QuantumLab.categoryWeights = {
    tech       = 28,   -- 量子计算/实验设备
    energy     = 22,   -- 实验室能源模块
    mechanical = 18,   -- 精密仪器/机械臂
    art        = 12,   -- 学术艺术藏品
    jewel      = 8,    -- 稀有材料/矿石样本
}

-- 限定品类（实验室风格，无古董/日用/交通/服饰）
QuantumLab.allowedCategories = { "tech", "energy", "mechanical", "art", "jewel" }

return QuantumLab
