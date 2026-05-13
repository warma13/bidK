-- ============================================================================
-- Config/Warehouses/Shipwreck.lua - 远洋货轮残骸物品配置
-- 复用 ItemPool + BondedPort 共享物品池，使用不同的品类权重
-- 侧重机械、古董品类，体现远洋货轮打捞品特色
-- ============================================================================

local Shipwreck = {}

-- 品类权重（远洋货轮残骸：侧重机械和古董）
Shipwreck.categoryWeights = {
    mechanical = 20,   -- 机械：船用发动机/起重设备/集装箱机械
    antique    = 18,   -- 古董：沉船古物/各国旧货
    tech       = 15,   -- 科技：航海电子设备/进口电器
    jewel      = 12,   -- 珠宝：旅客遗落/走私珠宝
    art        = 12,   -- 艺术：各国工艺品/画作
    transport  = 10,   -- 交通：船舶零件/进口汽车配件
    energy     = 8,    -- 能源：船用燃料设备/电池
    daily      = 5,    -- 日用：集装箱里的日常货物
}

-- 无独有物品，全部复用 BondedPort + ItemPool 的物品池
Shipwreck.categories = {}

return Shipwreck
