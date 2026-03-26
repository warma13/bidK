# 仓库生成算法技术文档

> 源码：`scripts/WarehouseGenerator.lua`

---

## 1. 总体架构

```
WG.Generate(regionId, warehouseTypeId, diffIdx)
        │
        ├── 1. 确定区域 (Config.REGIONS)
        ├── 2. 确定难度 → 获取经济参数 (expectedValue, rarityWeights)
        ├── 3. 确定仓库类型 → 获取结构参数 (sizeWeights)
        ├── 4. 采样本局参数 (targetValue, targetCells)
        ├── 5. 预算驱动循环：挑选物品 + 放置到格子
        └── 6. 输出结果
```

### 参数来源分离

| 参数类型 | 来源 | 具体字段 |
|---------|------|---------|
| 经济参数 | `region.difficulties[diffIdx]` | `expectedValue`, `rarityWeights` |
| 结构参数 | `Config.WAREHOUSE_TYPES[whTypeId]` | `sizeWeights` |

仓库类型**不控制**价值和稀有度分布，只控制物品的大小比例。

---

## 2. 格子系统

### 常量

```lua
COLS     = 10   -- 列数 (Config.GAME.WarehouseColumns)
MAX_ROWS = 20   -- 最大行数 (Config.GAME.WarehouseMaxRows)
MAX_CELLS = 200  -- 总格子数 = 10 × 20
```

### 数据结构

```lua
grid[row][col] = 0       -- 空格
grid[row][col] = itemIdx  -- 被第 itemIdx 号物品占用
```

行列均为 1-based 索引。

---

## 3. 本局参数采样 (`sampleSessionParams`)

每局开始前，从概率分布中采样两个核心参数：

### 3.1 填充率采样

```
fillRate ~ N(0.50, 0.12²)
```

- **中位数**：50%
- **标准差**：~12%
- **90% 置信区间**：[30%, 70%]（由 1.645σ = 0.20 推导）
- **硬限制**：[15%, 85%]

```lua
local fillRate = 0.50 + randNormal() * 0.12
fillRate = math.max(0.15, math.min(0.85, fillRate))
```

由此计算目标格子数：

```lua
targetCells = floor(MAX_CELLS * fillRate)
targetCells = clamp(targetCells, 10, MAX_CELLS - 10)  -- [10, 190]
```

### 3.2 目标价值采样

```
targetValue ~ N(expectedValue, (0.304 × expectedValue)²)
```

- **期望值**：来自难度配置的 `expectedValue`（如 50万场 = 500,000）
- **标准差**：`0.304 × expectedValue`
- **90% 置信区间**：`expectedValue ± 50%`（由 1.645σ = 0.50 × base 推导）
- **裁剪**：限制在当前格子数下的理论价值边界 `[boundMin, boundMax]` 内
- **下限保护**：不低于 `expectedValue × 10%`

### 3.3 理论价值边界 (`calcValueBounds`)

给定 `targetCells` 格子，通过贪心算法计算：

- **理论最低价**：按「单格价值升序」贪心填充（尽量选便宜的）
- **理论最高价**：按「单格价值降序」贪心填充（尽量选贵的）

用于裁剪 `targetValue` 到可达范围，避免采样出无法实现的目标。

---

## 4. 物品池系统

### 4.1 物品池加载

每种仓库类型对应一个物品配置模块：

```lua
local warehouseModules = {
    grocery  = "Config.Warehouses.ItemPool",
    repair   = "Config.Warehouses.Repair",
    storage  = "Config.Warehouses.Storage",
    techpark = "Config.Warehouses.TechPark",
}
```

模块加载后缓存在 `poolCache[whTypeId]` 中，结构为：

```lua
{
    sizeGroups = { {}, {}, {}, {}, {} },  -- 按尺寸分 5 组
    allItems   = { entry, entry, ... },    -- 全部物品
}
```

### 4.2 尺寸分组

物品按占格数映射到 5 个尺寸档位（`Config.ITEM_SIZE_GROUPS`）：

| 档位 | 占格数 | 典型尺寸 | sizeWeights 索引 |
|------|--------|---------|-----------------|
| 1 | 1 | 1x1 | sizeWeights[1] |
| 2 | 2-3 | 2x1, 1x2, 3x1, 1x3 | sizeWeights[2] |
| 3 | 4 | 2x2, 1x4, 4x1 | sizeWeights[3] |
| 4 | 6-8 | 2x3, 3x2, 2x4, 4x2 | sizeWeights[4] |
| 5 | 9+ | 3x3, 3x4, 4x4, 5x5 等 | sizeWeights[5] |

### 4.3 各仓库类型的 sizeWeights

```lua
-- sizeWeights = { 1格, 2格, 4格, 6格, 9格+ }
grocery  = { 35, 30, 20, 10, 5 }   -- 小件为主
repair   = { 30, 30, 22, 12, 6 }   -- 略偏小件
storage  = { 32, 28, 22, 12, 6 }   -- 均衡偏小
techpark = { 25, 25, 25, 15, 10 }  -- 均衡偏大
```

---

## 5. 物品选取算法 (`pickFromPool`)

每次选取物品分两步：

### 5.1 选尺寸档位

按 `sizeWeights` 加权随机选择一个尺寸组（1-5）。

### 5.2 选具体物品（预算制加权）

在选定的尺寸组内，通过**预算制权重**选取物品：

```
最终权重 = catWeight × budgetWeight(item.value, targetPerPick)
```

其中 `targetPerPick`（当前目标均价）实时计算：

```lua
local remainCells = targetCells - occupiedCells
local estRemainItems = max(1, ceil(remainCells / 2.5))
local targetPerPick = remainingBudget / estRemainItems
```

### 5.3 预算制权重函数 (`budgetWeight`)

核心公式——高斯型衰减：

```
budgetWeight(value, target) = exp(-k × (ln(value / target))²)
```

- `k = 1.5`，控制集中程度
- `value / target = 1` 时权重最大（= 1.0）
- 偏离越远，权重指数级衰减
- 对数比值保证对称性：贵 2 倍和便宜 2 倍的衰减相同

**直观理解**：

| value / target | ln(ratio) | 权重 |
|---------------|-----------|------|
| 1.0 | 0 | 1.000 |
| 0.7 或 1.4 | ±0.36 | 0.822 |
| 0.5 或 2.0 | ±0.69 | 0.487 |
| 0.3 或 3.3 | ±1.20 | 0.117 |
| 0.1 或 10.0 | ±2.30 | 0.003 |

效果：随着放置推进，`remainingBudget` 减少，`targetPerPick` 动态调整，算法自动在前期选高价物品、后期选低价物品（或反之），使总价值趋近目标。

### 5.4 去重机制

- 维护 `usedNames` 表，优先选取未出现过的物品名
- 如果该尺寸组的物品名全部用过，允许重名

---

## 6. 放置算法 (`findBestPosition`)

物品放置采用**两阶段缝隙填充**策略：

### 阶段 1：填充已使用区域的空隙

在已有物品的行范围（`1 ~ usedRows`）内扫描所有可放置位置，计算每个位置的**缝隙得分**，选最高分。

**缝隙得分** (`gapScore`)：统计物品区域四条边外侧相邻的已占用格子数。

```
得分越高 = 周围已有物品越多 = 填入后越紧凑
```

计算细节：
- 遍历物品的上边、下边、左边、右边的相邻格子
- 相邻格子已被占用 → +1 分
- 贴墙壁（行=1 或 列=1）也 → +1 分（鼓励靠边放置）
- 同分时取先扫描到的位置（靠上靠左优先）

### 阶段 2：新行放置

如果阶段 1 找不到位置，在 `usedRows + 1` 行开始向下找第一个能放下的位置（左上角优先）。

### 放置效果

这套算法产生**紧凑、不规则的布局**：
- 物品倾向于聚集在一起，不会出现大片空洞
- 大件物品可能嵌入小件之间的空隙
- 整体从上往下增长

---

## 7. 主循环流程

```lua
while occupiedCells < targetCells and failCount < MAX_FAILS do

    -- 1. 计算当前目标均价
    targetPerPick = remainingBudget / estRemainItems

    -- 2. 从物品池挑选（尺寸权重 + 预算权重）
    entry = pickFromPool(whTypeId, whType, usedNames, targetPerPick)

    -- 3. 超出检查：放入后超出 targetCells+5 格则换更小的
    if occupiedCells + itemCells > targetCells + 5 then
        -- 最多重试 8 次找更小物品
        -- 全部失败 → failCount++ → 跳过
    end

    -- 4. 寻找放置位置（缝隙优先）
    row, col = findBestPosition(grid, w, h)
    if not row then failCount++ → 跳过 end

    -- 5. 放置成功
    failCount = 0
    remainingBudget -= item.value
    occupiedCells += itemCells
    记录物品到 items[] 和 grid[][]
end
```

### 终止条件

| 条件 | 说明 |
|------|------|
| `occupiedCells >= targetCells` | 已达到目标占用格子数 |
| `failCount >= 10` | 连续 10 次无法放置（格子满/物品太大） |

### 超出容差

允许最后一个物品超出目标 **5 格**（`targetCells + 5`），避免因尺寸不匹配导致填充率偏低。超过 5 格则重试最多 8 次选更小物品。

---

## 8. 输出结构

```lua
{
    region           = { id, name, ... },      -- 区域信息
    warehouseTypeId  = "techpark",             -- 仓库类型ID
    warehouseTypeName = "AI独角兽总部",         -- 仓库类型名
    warehouseName    = "AI独角兽总部",          -- 仓库显示名
    items            = { item1, item2, ... },   -- 物品列表
    grid             = grid[row][col],          -- 格子占用矩阵
    totalCells       = 95,                      -- 实际占用格子数
    targetCells      = 100,                     -- 目标格子数
    targetValue      = 480000,                  -- 目标总价值
    totalValue       = 512000,                  -- 实际总价值
    usedRows         = 12,                      -- 使用行数
    itemCount        = 18,                      -- 物品数量
}
```

### 单个物品结构

```lua
{
    idx      = 1,              -- 序号（1-based）
    name     = "量子解密器",
    icon     = "",            -- 品类图标
    w        = 2,  h = 2,      -- 占格尺寸
    rarity   = "purple",       -- 稀有度
    baseValue = 7500,          -- 基础价值
    realValue = 7500,          -- 实际价值（当前等于基础价值）
    gridRow  = 3, gridCol = 5, -- 左上角格子坐标
    category = "tech",         -- 品类ID
    image    = "...",          -- 物品图片
    desc     = "...",          -- 物品描述
}
```

---

## 9. 辅助函数

| 函数 | 用途 |
|------|------|
| `WG.GetItemAt(result, row, col)` | 获取某格子位置的物品（nil=空格） |
| `WG.IsItemOrigin(result, row, col)` | 判断该格是否为物品的左上角 |
| `WG.DebugPrintGrid(result)` | 打印格子布局和物品列表（调试用） |
| `WG.GetItemPool(whTypeId)` | 获取指定仓库类型的完整物品池 |

---

## 10. 算法特性总结

| 特性 | 说明 |
|------|------|
| **填充率驱动** | 物品数量不固定，由填充率和物品尺寸自然决定 |
| **预算制平衡** | 高斯权重让总价值自动趋近目标，无需硬编码 |
| **局间差异大** | 填充率和目标价值都从正态分布采样，每局不同 |
| **紧凑布局** | 缝隙优先放置，物品聚集，视觉上更自然 |
| **去重** | 同名物品优先不重复，物品池耗尽才允许重名 |
| **容错** | 连续失败 10 次自动停止，超出 5 格容差 |
