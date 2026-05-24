-- ============================================================================
-- diagnose_premium.lua - 诊断 premium 阶段的选品行为
-- 对顶级私产托管区运行单次生成，打印每一步的详细信息
-- ============================================================================

function Start()
local ok, err = pcall(function()

local Config = require("Config")
local WG = require("WarehouseGenerator")

-- 启用诊断模式
WG._DIAGNOSE = true

-- 跑一次顶级区
local result = WG.Generate("topVault", nil, 1, 12345)

print("")
print("=== 诊断结果 ===")
print(string.format("区域: %s  仓库类型: %s", result.region, result.warehouseType))
print(string.format("目标总价: %.1f万  实际总价: %.1f万", result.targetValue/10000, result.totalValue/10000))
print(string.format("预算利用率: %.1f%%", result.totalValue / result.targetValue * 100))
print(string.format("物品件数: %d  占用格子: %d", result.itemCount, result.totalCells))
print(string.format("Tier: %s", result.tier))

-- 打印选中物品的价值分布
local values = {}
for _, item in ipairs(result.items) do
    values[#values + 1] = item.realValue
end
table.sort(values)

print("")
print("=== 物品价值分布 ===")
local sum = 0
for i, v in ipairs(values) do
    sum = sum + v
    if i <= 5 or i > #values - 5 or i == math.floor(#values/2) then
        print(string.format("  #%d: %s", i, v >= 10000 and string.format("%.1f万", v/10000) or tostring(v)))
    end
end

-- 统计价值区间
local brackets = {0, 1000, 10000, 100000, 500000, 1000000, 5000000, 100000000}
print("")
print("=== 价值区间分布 ===")
for bi = 1, #brackets - 1 do
    local lo, hi = brackets[bi], brackets[bi+1]
    local cnt = 0
    local bsum = 0
    for _, v in ipairs(values) do
        if v >= lo and v < hi then cnt = cnt + 1; bsum = bsum + v end
    end
    if cnt > 0 then
        print(string.format("  [%s ~ %s): %d件, 合计%s",
            lo >= 10000 and string.format("%.0f万", lo/10000) or tostring(lo),
            hi >= 10000 and string.format("%.0f万", hi/10000) or tostring(hi),
            cnt,
            bsum >= 10000 and string.format("%.1f万", bsum/10000) or tostring(bsum)))
    end
end

end) -- pcall
if not ok then
    log:Write(LOG_ERROR, "[diagnose] " .. tostring(err))
end
engine:Exit()
end
