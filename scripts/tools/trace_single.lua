-- trace_single.lua - 追踪单次仓库生成的 filler/premium 每步选品
-- 直接复用 WarehouseGenerator 逻辑但加入详细日志

function Start()
local ok, err = pcall(function()

local Config = require("Config")

-- 找到顶级区
local region
for _, r in ipairs(Config.REGIONS) do
    if r.id == "private" then region = r; break end
end
if not region then
    print("ERROR: region topVault not found")
    engine:Exit()
    return
end

local diff = region.difficulties[1]
local warehouseValue = diff.warehouseValue or diff.expectedValue
local types = region.warehouseTypes
local whTypeId = types[1]
local whType = Config.WAREHOUSE_TYPES[whTypeId]

print("=== 追踪单次生成 ===")
print(string.format("区域: %s, 仓库: %s, warehouseValue=%s", region.name, whType.name, warehouseValue))

-- 加载物品池统计
local itemPoolMod = require("Config.Warehouses.ItemPool")
local pool = itemPoolMod.categories
local allPrices = {}
for _, cat in ipairs(pool) do
    for _, item in ipairs(cat.items) do
        allPrices[#allPrices + 1] = item.value
    end
end
table.sort(allPrices)
print(string.format("物品池: %d 件, 中位数=%d, P90=%d", #allPrices, allPrices[math.floor(#allPrices*0.5)], allPrices[math.floor(#allPrices*0.9)]))

-- 统计各价位段物品数
local brackets = {0, 10000, 50000, 100000, 500000, 1000000, 5000000, 10000000, 100000000}
for bi = 1, #brackets - 1 do
    local lo, hi = brackets[bi], brackets[bi+1]
    local cnt = 0
    for _, v in ipairs(allPrices) do
        if v >= lo and v < hi then cnt = cnt + 1 end
    end
    if cnt > 0 then
        print(string.format("  [%s ~ %s): %d 件",
            lo >= 10000 and string.format("%.0f万", lo/10000) or tostring(lo),
            hi >= 10000 and string.format("%.0f万", hi/10000) or tostring(hi), cnt))
    end
end

-- 模拟 tier 分布下的 premium 预算
-- 用 normal tier 作例子
print("")
print("=== 以 normal tier 为例 ===")
local tier = { id = "normal", multMin = 0.65, multMax = 1.00, fillerRatio = 0.75, budgetK = 0.8 }
local mult = (tier.multMin + tier.multMax) / 2
local targetValue = warehouseValue * mult
local fillerCount = math.floor(40 * tier.fillerRatio)
local premiumCount = 40 - fillerCount
local fillerBudget = math.floor(targetValue * tier.fillerRatio * tier.fillerRatio * 0.5)
local premiumBudget = targetValue - fillerBudget
local targetPerPick = premiumBudget / premiumCount

print(string.format("targetValue = %.1f万", targetValue / 10000))
print(string.format("fillerCount = %d, premiumCount = %d", fillerCount, premiumCount))
print(string.format("fillerBudget = %.1f万 (%.1f%%)", fillerBudget / 10000, fillerBudget / targetValue * 100))
print(string.format("premiumBudget = %.1f万 (%.1f%%)", premiumBudget / 10000, premiumBudget / targetValue * 100))
print(string.format("targetPerPick = %.1f万", targetPerPick / 10000))

-- 分析在 targetPerPick 下，硬截断和高斯核的效果
local cutoff40 = targetPerPick * 0.4
local lowerBound60 = targetPerPick * 0.6
local itemCap = math.min(premiumBudget, targetPerPick * 8.0)
print(string.format("硬截断(40%%): %.1f万", cutoff40 / 10000))
print(string.format("软下限(60%%): %.1f万", lowerBound60 / 10000))
print(string.format("itemCap(8x): %.1f万", itemCap / 10000))

-- 统计各截断后剩余物品数
local aboveCutoff = 0
local aboveLower = 0
local belowCap = 0
local inRange = 0
for _, v in ipairs(allPrices) do
    if v >= cutoff40 then aboveCutoff = aboveCutoff + 1 end
    if v >= lowerBound60 then aboveLower = aboveLower + 1 end
    if v <= itemCap then belowCap = belowCap + 1 end
    if v >= cutoff40 and v <= itemCap then inRange = inRange + 1 end
end
print(string.format("截断后 >= %.1f万: %d 件", cutoff40/10000, aboveCutoff))
print(string.format("软下限 >= %.1f万: %d 件", lowerBound60/10000, aboveLower))
print(string.format("<= itemCap %.1f万: %d 件", itemCap/10000, belowCap))
print(string.format("有效范围内: %d 件", inRange))

-- 模拟高斯核权重分布（用 K=0.8）
print("")
print("=== budgetWeight(K=0.8) 在有效范围内的分布 ===")
local function budgetWeight(value, target, k)
    if target <= 0 then return 1 end
    local ratio = math.log(value / target)
    return math.exp(-k * ratio * ratio)
end

local weightBuckets = {}
local bucketNames = {"40%-60%", "60%-80%", "80%-100%", "100%-150%", "150%-300%", "300%+"}
local bucketLo = {0.4, 0.6, 0.8, 1.0, 1.5, 3.0}
local bucketHi = {0.6, 0.8, 1.0, 1.5, 3.0, 100}
for i = 1, #bucketNames do weightBuckets[i] = { count = 0, totalBW = 0, totalValue = 0 } end

for _, v in ipairs(allPrices) do
    if v >= cutoff40 and v <= itemCap then
        local ratio = v / targetPerPick
        for bi = 1, #bucketNames do
            if ratio >= bucketLo[bi] and ratio < bucketHi[bi] then
                local bw = budgetWeight(v, targetPerPick, 0.8)
                weightBuckets[bi].count = weightBuckets[bi].count + 1
                weightBuckets[bi].totalBW = weightBuckets[bi].totalBW + bw
                weightBuckets[bi].totalValue = weightBuckets[bi].totalValue + v
                break
            end
        end
    end
end

local grandTotalBW = 0
for _, b in ipairs(weightBuckets) do grandTotalBW = grandTotalBW + b.totalBW end

for i, name in ipairs(bucketNames) do
    local b = weightBuckets[i]
    if b.count > 0 then
        local avgBW = b.totalBW / b.count
        local pctOfTotal = b.totalBW / grandTotalBW * 100
        local avgValue = b.totalValue / b.count
        print(string.format("  %s: %d件, avgBW=%.3f, 占总权重%.1f%%, 平均价%.1f万",
            name, b.count, avgBW, pctOfTotal, avgValue/10000))
    end
end

-- 计算加权期望选品价值
local expectedValue = 0
for _, v in ipairs(allPrices) do
    if v >= cutoff40 and v <= itemCap then
        local bw = budgetWeight(v, targetPerPick, 0.8)
        -- 注意：这里没有考虑 catWeight 和 itemWeight，只是粗略估计
        expectedValue = expectedValue + v * bw
    end
end
expectedValue = expectedValue / grandTotalBW
print(string.format("\n加权期望选品价值(不含catWeight): %.1f万  (目标: %.1f万)", expectedValue/10000, targetPerPick/10000))

-- 实际运行一次 Generate 看结果
print("")
print("=== 实际运行 Generate ===")
local WG = require("WarehouseGenerator")
local result = WG.Generate("private", nil, 1, 42)
print(string.format("目标总价: %.1f万  实际总价: %.1f万  利用率: %.1f%%",
    result.targetValue/10000, result.totalValue/10000, result.totalValue/result.targetValue*100))
print(string.format("Tier: %s  件数: %d  格子: %d", result.tier, result.itemCount, result.totalCells))

-- 按价值排序打印所有物品
local vals = {}
for _, item in ipairs(result.items) do
    vals[#vals + 1] = item.realValue
end
table.sort(vals)
print(string.format("物品价值: min=%.1f万, max=%.1f万", vals[1]/10000, vals[#vals]/10000))
-- 打印最贵的10件
print("最贵10件:")
for i = #vals, math.max(1, #vals - 9), -1 do
    print(string.format("  #%d: %.1f万", #vals - i + 1, vals[i]/10000))
end

end) -- pcall
if not ok then
    log:Write(LOG_ERROR, "[trace] " .. tostring(err))
end
engine:Exit()
end
