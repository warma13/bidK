-- trace_premium_detail.lua - 详细追踪 premium 阶段每一步选品
-- 分析为什么高 tier 在高价区域利用率低

function Start()
local ok, err = pcall(function()

local Config = require("Config")
local WG = require("WarehouseGenerator")

-- 对每个区域的每个 tier 运行若干次模拟，统计利用率
local regions = {"suburb", "industrial", "commercial", "port", "techpark", "culture", "deepsea", "private"}
local tierNames = {"trash", "junk", "poor", "normal", "good", "treasure", "jackpot"}

-- 先做整体统计：每个区域每个 tier 的利用率
print("=== 按区域×Tier 利用率统计 (每组50次) ===")
print(string.format("%-12s  %-8s  %8s  %8s  %8s  %8s  %8s",
    "区域", "Tier", "目标均值", "实际均值", "利用率", "最低", "最高"))

-- 只测顶级区的所有 tier
local regionId = "private"
local region
for _, r in ipairs(Config.REGIONS) do
    if r.id == regionId then region = r; break end
end
local diff = region.difficulties[1]
local warehouseValue = diff.warehouseValue or diff.expectedValue

for _, tierName in ipairs(tierNames) do
    local totalTarget = 0
    local totalActual = 0
    local minUtil = 999
    local maxUtil = 0
    local trials = 50
    for t = 1, trials do
        local result = WG.Generate(regionId, nil, 1, t * 1000 + 1)
        -- 因为 tier 是随机的，我们需要检测是否匹配
        -- 直接用固定 seed 多跑取平均
    end
    -- 上面的方法不行，tier 是随机掷骰的
    -- 换个思路：跑足够多次，按 tier 分组统计
end

-- 正确方法：跑大量样本，按 tier 分组
local tierStats = {}
for _, tn in ipairs(tierNames) do
    tierStats[tn] = { targets = {}, actuals = {}, utils = {} }
end

local N = 500
for seed = 1, N do
    local result = WG.Generate(regionId, nil, 1, seed)
    local tn = result.tier
    if tierStats[tn] then
        local stats = tierStats[tn]
        stats.targets[#stats.targets + 1] = result.targetValue
        stats.actuals[#stats.actuals + 1] = result.totalValue
        stats.utils[#stats.utils + 1] = result.totalValue / result.targetValue
    end
end

for _, tn in ipairs(tierNames) do
    local stats = tierStats[tn]
    if #stats.utils > 0 then
        local sumTarget, sumActual, sumUtil = 0, 0, 0
        local minU, maxU = 999, 0
        for i, u in ipairs(stats.utils) do
            sumTarget = sumTarget + stats.targets[i]
            sumActual = sumActual + stats.actuals[i]
            sumUtil = sumUtil + u
            if u < minU then minU = u end
            if u > maxU then maxU = u end
        end
        local n = #stats.utils
        print(string.format("%-8s  n=%3d  目标=%.0f万  实际=%.0f万  利用率=%.1f%%  [%.1f%% ~ %.1f%%]",
            tn, n, sumTarget / n / 10000, sumActual / n / 10000, 
            sumUtil / n * 100, minU * 100, maxU * 100))
    end
end

-- 重点分析：找一个利用率低的 treasure/jackpot 个例
print("")
print("=== 查找低利用率个例 (treasure/jackpot, 利用率<85%) ===")
local worstSeed = nil
local worstUtil = 1.0
local worstTier = ""
for seed = 1, 1000 do
    local result = WG.Generate(regionId, nil, 1, seed)
    local util = result.totalValue / result.targetValue
    if (result.tier == "treasure" or result.tier == "jackpot" or result.tier == "good") and util < worstUtil then
        worstUtil = util
        worstSeed = seed
        worstTier = result.tier
    end
end

if worstSeed then
    print(string.format("最低利用率: seed=%d, tier=%s, 利用率=%.1f%%", worstSeed, worstTier, worstUtil * 100))
    
    -- 详细跑这个 seed 的结果
    local result = WG.Generate(regionId, nil, 1, worstSeed)
    print(string.format("目标: %.1f万  实际: %.1f万  件数: %d  格子: %d/%d",
        result.targetValue/10000, result.totalValue/10000, result.itemCount, result.totalCells, 200))
    
    -- 分析物品价值分布
    local vals = {}
    local totalVal = 0
    for _, item in ipairs(result.items) do
        vals[#vals + 1] = item.realValue
        totalVal = totalVal + item.realValue
    end
    table.sort(vals)
    
    local gap = result.targetValue - totalVal
    print(string.format("预算缺口: %.1f万 (%.1f%%)", gap/10000, gap/result.targetValue*100))
    
    -- 价值分段统计
    local brackets = {0, 10000, 50000, 100000, 500000, 1000000, 5000000}
    for bi = 1, #brackets do
        local lo = brackets[bi]
        local hi = brackets[bi + 1] or 999999999
        local cnt = 0
        local sum = 0
        for _, v in ipairs(vals) do
            if v >= lo and v < hi then cnt = cnt + 1; sum = sum + v end
        end
        if cnt > 0 then
            print(string.format("  [%.0f万~%.0f万): %d件, 合计%.1f万",
                lo/10000, hi >= 999999999 and 9999 or hi/10000, cnt, sum/10000))
        end
    end
    
    -- 打印最贵的 10 件
    print("  最贵5件:")
    for i = #vals, math.max(1, #vals - 4), -1 do
        print(string.format("    %.1f万", vals[i]/10000))
    end
end

-- 再分析所有区域的整体情况
print("")
print("=== 所有区域整体利用率 (每区域200次) ===")
for _, rid in ipairs(regions) do
    local rn = ""
    for _, r in ipairs(Config.REGIONS) do
        if r.id == rid then rn = r.name; break end
    end
    local sumUtil = 0
    local minU, maxU = 999, 0
    local cnt = 0
    for seed = 1, 200 do
        local result = WG.Generate(rid, nil, 1, seed)
        local u = result.totalValue / result.targetValue
        sumUtil = sumUtil + u
        cnt = cnt + 1
        if u < minU then minU = u end
        if u > maxU then maxU = u end
    end
    print(string.format("%-14s  avg=%.1f%%  [%.1f%% ~ %.1f%%]", rn, sumUtil/cnt*100, minU*100, maxU*100))
end

end) -- pcall
if not ok then
    log:Write(LOG_ERROR, "[trace] " .. tostring(err))
    print("ERROR: " .. tostring(err))
end
engine:Exit()
end
