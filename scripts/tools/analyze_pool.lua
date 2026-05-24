-- 分析物品池价格分布
function Start()
local ok, err = pcall(function()

local Config = require("Config")
local itemPoolMod = require("Config.Warehouses.ItemPool")

-- 收集所有物品价值
local allValues = {}
local seenNames = {}
for _, cat in ipairs(itemPoolMod.categories) do
    for _, item in ipairs(cat.items) do
        if not seenNames[item.name] then
            seenNames[item.name] = true
            allValues[#allValues + 1] = item.value
        end
    end
end

table.sort(allValues)
local N = #allValues

print(string.format("物品池总数: %d", N))
print(string.format("最低价: %d", allValues[1]))
print(string.format("最高价: %d", allValues[N]))

-- 分位数
local function pct(p)
    local idx = math.max(1, math.min(N, math.floor(p * N + 0.5)))
    return allValues[idx]
end
print(string.format("P10=%d  P25=%d  P50=%d  P75=%d  P90=%d  P95=%d  P99=%d",
    pct(0.10), pct(0.25), pct(0.50), pct(0.75), pct(0.90), pct(0.95), pct(0.99)))

-- 价格分布
local brackets = {1000, 5000, 10000, 50000, 100000, 200000, 500000, 1000000, 5000000, 10000000, 50000000}
for _, thresh in ipairs(brackets) do
    local count = 0
    for _, v in ipairs(allValues) do
        if v >= thresh then count = count + 1 end
    end
    print(string.format("  >= %10d: %4d 件 (%.1f%%)", thresh, count, count / N * 100))
end

-- 高价物品列表（>100万）
print("\n物品 > 100万:")
for _, cat in ipairs(itemPoolMod.categories) do
    for _, item in ipairs(cat.items) do
        if item.value >= 1000000 then
            print(string.format("  %s: %d (%.1f万)", item.name, item.value, item.value / 10000))
        end
    end
end

end)
if not ok then log:Write(LOG_ERROR, "[analyze] " .. tostring(err)) end
engine:Exit()
end
