-- ============================================================================
-- simulate_warehouse.lua - 仓库生成算法蒙特卡洛模拟
-- 对每个区域的每个难度运行 1000 次 Generate，统计：
--   - 平均总价值 / 标准差 / 变异系数(CV)
--   - 各 Tier 出现频率
--   - 价值分位数（P10, P25, P50, P75, P90）
--   - 平均物品件数 / 平均格子占用率
-- ============================================================================

function Start()
local ok, err = pcall(function()

local Config = require("Config")
local WG = require("WarehouseGenerator")

local N = 1000  -- 每个区域/难度的模拟次数

-- 屏蔽 WarehouseGenerator 内部日志（每次 Generate 打 7 行 × 1000 次 = 太多）
local _realPrint = print
local silenced = false
local function silencePrint()
    silenced = true
    print = function() end  -- no-op
end
local function restorePrint()
    silenced = false
    print = _realPrint
end

-- ── 工具函数 ──

local function median(sorted, p)
    local idx = p * (#sorted - 1) + 1
    local lo = math.floor(idx)
    local hi = math.ceil(idx)
    if lo == hi then return sorted[lo] end
    return sorted[lo] + (sorted[hi] - sorted[lo]) * (idx - lo)
end

local function formatMoney(v)
    if v >= 10000000 then
        return string.format("%.1f万", v / 10000)
    elseif v >= 10000 then
        return string.format("%.1f万", v / 10000)
    else
        return string.format("%d", v)
    end
end

-- ── 主模拟 ──

print("=" .. string.rep("=", 99))
print("仓库生成蒙特卡洛模拟  N=" .. N)
print("=" .. string.rep("=", 99))

for _, region in ipairs(Config.REGIONS) do
    for diffIdx, diff in ipairs(region.difficulties) do
        local warehouseValue = diff.warehouseValue or diff.expectedValue

        -- 从该区域随机选仓库类型（模拟真实游戏行为）
        -- 为公平对比，对区域内所有仓库类型聚合统计
        local values = {}
        local itemCounts = {}
        local cellCounts = {}
        local tierCounts = {}
        local totalTargetValues = {}
        local budgetUtils = {}  -- 预算利用率 = totalValue / targetValue

        silencePrint()
        for i = 1, N do
            -- 随机选一个仓库类型（与游戏一致）
            local types = region.warehouseTypes
            local whTypeId = types[math.random(1, #types)]

            local result = WG.Generate(region.id, whTypeId, diffIdx, i * 31337)

            values[i] = result.totalValue
            itemCounts[i] = result.itemCount
            cellCounts[i] = result.totalCells
            totalTargetValues[i] = result.targetValue
            budgetUtils[i] = result.targetValue > 0 and (result.totalValue / result.targetValue) or 0

            local tier = result.tier
            tierCounts[tier] = (tierCounts[tier] or 0) + 1
        end
        restorePrint()

        -- 统计
        local sum = 0
        local sumItems = 0
        local sumCells = 0
        local sumTarget = 0
        local sumBudgetUtil = 0
        for i = 1, N do
            sum = sum + values[i]
            sumItems = sumItems + itemCounts[i]
            sumCells = sumCells + cellCounts[i]
            sumTarget = sumTarget + totalTargetValues[i]
            sumBudgetUtil = sumBudgetUtil + budgetUtils[i]
        end
        local mean = sum / N
        local meanItems = sumItems / N
        local meanCells = sumCells / N
        local meanTarget = sumTarget / N
        local meanBudgetUtil = sumBudgetUtil / N

        local sumSq = 0
        for i = 1, N do
            local d = values[i] - mean
            sumSq = sumSq + d * d
        end
        local stddev = math.sqrt(sumSq / N)
        local cv = mean > 0 and (stddev / mean) or 0

        -- 排序求分位数
        table.sort(values)
        local p10 = median(values, 0.10)
        local p25 = median(values, 0.25)
        local p50 = median(values, 0.50)
        local p75 = median(values, 0.75)
        local p90 = median(values, 0.90)
        local minV = values[1]
        local maxV = values[N]

        -- 超过 warehouseValue 的比例
        local overCount = 0
        for i = 1, N do
            if values[i] > warehouseValue then
                overCount = overCount + 1
            end
        end
        local overRate = overCount / N * 100

        -- 输出
        print("")
        print(string.format("── %s [%s] ──  warehouseValue=%s",
            region.name, diff.label, formatMoney(warehouseValue)))
        print(string.format("  平均总价: %s  (%.2fx warehouseValue)",
            formatMoney(mean), mean / warehouseValue))
        print(string.format("  目标均价: %s  (%.2fx warehouseValue)",
            formatMoney(meanTarget), meanTarget / warehouseValue))
        print(string.format("  标准差:   %s  变异系数(CV): %.1f%%",
            formatMoney(stddev), cv * 100))
        print(string.format("  超过warehouseValue比例: %.1f%%", overRate))
        print(string.format("  分位数: P10=%s  P25=%s  P50=%s  P75=%s  P90=%s",
            formatMoney(p10), formatMoney(p25), formatMoney(p50),
            formatMoney(p75), formatMoney(p90)))
        print(string.format("  最小=%s  最大=%s  (%.1fx ~ %.1fx)",
            formatMoney(minV), formatMoney(maxV),
            minV / warehouseValue, maxV / warehouseValue))
        print(string.format("  预算利用率: %.1f%%  (实际总价/目标总价)", meanBudgetUtil * 100))
        print(string.format("  平均件数: %.1f  平均格子占用: %.0f/200 (%.0f%%)",
            meanItems, meanCells, meanCells / 200 * 100))

        -- Tier 分布
        local tierOrder = { "trash", "junk", "poor", "normal", "good", "treasure", "jackpot" }
        local tierLine = "  Tier分布:"
        for _, tid in ipairs(tierOrder) do
            local cnt = tierCounts[tid] or 0
            tierLine = tierLine .. string.format(" %s=%.1f%%", tid, cnt / N * 100)
        end
        print(tierLine)
    end
end

print("")
print("=" .. string.rep("=", 99))
print("模拟完成")
print("=" .. string.rep("=", 99))

end) -- pcall
if not ok then
    log:Write(LOG_ERROR, "[simulate] " .. tostring(err))
end
engine:Exit()
end -- Start
