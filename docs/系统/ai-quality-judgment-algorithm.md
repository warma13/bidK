# AI 仓库质量判断算法

## 1. 概述

所有 AI 角色共享一个仓库质量判断层，在策略出价之后、数字风格化之前，根据已知信息判断当前仓库的质量好坏，对出价施加一个乘数调整。

出价流程：

```
第一层：意图判定（compete/resign/bluff/pump/desperation）
第二层：角色策略计算 → rawBid
    ↓
  质量乘数 → rawBid × qualityMultiplier      ← 仅 compete / desperation 意图
    ↓
第三层：随机波动 ±8%
第四层：数字风格化 → finalBid
```

---

## 2. 动态池均价

每种仓库类型对应一个物品池模块，在 `EstimateValue.lua` 中注册：

```lua
warehouseModules = {
    grocery  = "Config.Warehouses.ItemPool",
    repair   = "Config.Warehouses.Repair",
    storage  = "Config.Warehouses.Storage",
    techpark = "Config.Warehouses.TechPark",
}
```

池均价按品类权重加权计算：

```
品类均价 = Σ(该品类所有物品 value) / 该品类物品数量
poolAvg  = Σ(品类概率 × 品类均价)
品类概率 = categoryWeights[catId] / Σ(categoryWeights)
```

不同仓库类型有不同的 `categoryWeights`，因此池均价不同。按 `warehouseTypeId` 缓存，首次计算后复用。

---

## 3. 条件期望值

对仓库中每件物品，根据 AI 当前掌握的信息层级（L0 ~ L3），查表得到一个条件期望值：

| 层级 | 已知信息 | 期望值取法 |
|------|---------|-----------|
| 未知 | 无 | `poolAvg` |
| L0 | 品类 | `categoryAvg[catId]`，无则回退 `poolAvg` |
| L1 | 品类 + 尺寸 | `categorySizeAvg["catId:WxH"]`，无则回退 `categoryAvg[catId]` |
| L2 | 品质（通常含品类） | `categoryQualityAvg["catId:quality"]`，无品类则用 `qualityAvgWeighted[quality]` |
| L3 | 完全揭示 | `item.realValue`（精确值） |

查找表在 `EstimateValue.buildTables()` 中按仓库类型一次性构建并缓存：

- `categoryAvg[catId]` — 品类均价
- `categorySizeAvg["catId:WxH"]` — 品类 + 尺寸均价
- `categoryQualityAvg["catId:quality"]` — 品类 + 品质均价
- `qualityAvgWeighted[quality]` — 全池该品质的品类加权均价（L2 无品类信息时回退用）

---

## 4. 期望估价与质量比率

`EstimateValue.CalculateExpected(infoState, whTypeId)` 遍历仓库所有物品，按各自信息层级求和：

```
expectedTotal = Σ getExpectedValue(tables, level, item)   对每件物品
```

质量比率：

```
qualityRatio = expectedTotal / (itemCount × poolAvg)
```

- `> 1`：已知信息暗示仓库好于平均
- `< 1`：已知信息暗示仓库差于平均
- `≈ 1`：信息不足或仓库质量中等

天然置信度：未知物品的条件期望值就是 `poolAvg`，与分母互相抵消，ratio 自然趋向 1.0。揭示越多，偏离空间越大。

---

## 5. 质量乘数

`Strategies.ComputeQualityMultiplier(expectedTotal, poolAvg, itemCount, personality)` 计算乘数：

```lua
qualityRatio = expectedTotal / (itemCount * poolAvg)

if qualityRatio >= 1.0 then
    multiplier = 1.0 + sensUp * (qualityRatio - 1.0)
else
    multiplier = 1.0 + sensDown * (qualityRatio - 1.0)
end

multiplier = clamp(multiplier, 0.5, 1.5)
```

非对称设计：`sensUp` 控制好仓库时的出价上浮强度，`sensDown` 控制差仓库时的出价下压强度。

clamp 到 `[0.5, 1.5]` 防止单件高价物品（如红色 18,000,000）导致 ratio 飙升，确保质量判断只是调节因子。

---

## 6. 角色敏感度参数

每个角色的 `personality` 中配置 `qualitySensUp` 和 `qualitySensDown`：

| # | 角色 | 策略风格 | sensUp | sensDown | 设计意图 |
|---|------|---------|--------|----------|---------|
| 1 | 林远舟 | info_driven | 0.50 | 0.50 | 对称理性反应 |
| 2 | 赵沐瑶 | grower | 0.20 | 0.50 | 渐进型，好仓库保守，差仓库敏感 |
| 3 | 钱思远 | banker | 0.15 | 0.70 | 极度厌恶亏损，差仓库果断压价 |
| 4 | 顾千鹤 | info_driven | 0.50 | 0.50 | 对称理性反应 |
| 5 | 沈玉珂 | sniper | 0.60 | 0.70 | 双向高敏感，最依赖质量判断 |
| 6 | 周正霆 | specialist | 0.40 | 0.50 | 中等反应，专精加成是主要差异化 |
| 7 | 方逸尘 | gambler | 0.60 | 0.25 | 好仓库猛冲，差仓库也不太退 |
| 8 | 韩墨璃 | veteran | 0.30 | 0.60 | 偏保守，老手心态稳 |
| 9 | 孙弈辰 | grower | 0.20 | 0.50 | 同赵沐瑶 |
| 10 | 吴鉴之 | sniper | 0.60 | 0.70 | 同沈玉珂 |
| 11 | 何启明 | arbitrage | 0.35 | 0.30 | 有折扣被动兜底，两侧温和 |

---

## 7. 数据流

```
WarehouseGenerator 生成物品 (含 category, rarity, w, h, realValue)
       │
       ▼
InfoSystem.Init(warehouseItems, players, warehouseTypeId)
       │
       ▼
  每轮揭示信息（公开 L0/L1/L2 + 角色技能 L2/L3）
       │
       ▼
InfoEstimation.ComputeEstimate(playerIdx, round, infoSystem, infoStates, expectedValue, warehouseTypeId)
       │
       ├──→ EstimateValue.Calculate(infoState, whTypeId)
       │         → 最低估价 + knownCount + totalCount（出价上限保护）
       │
       ├──→ EstimateValue.CalculateExpected(infoState, whTypeId)
       │         → expectedTotal + poolAvg + itemCount（质量判断用）
       │
       ▼
  返回: estimate, secureValue, expectedTotal, poolAvg, itemCount
       │
       ▼
AIPlayer.DecideSealedBid()
       │
       ├── Strategies.DecideIntent()         → intent
       ├── Strategies.CalculateBid()         → rawBid
       ├── Strategies.ComputeQualityMultiplier(expectedTotal, poolAvg, itemCount, personality)
       │                                     → rawBid × qualityMultiplier
       ├── ±8% 随机波动
       └── Strategies.StylizeNumber()        → finalBid
```

---

## 8. 与最低估价的关系

`EstimateValue` 模块统一支持两种模式，共享同一套查找表构建逻辑：

| | Calculate（min 模式） | CalculateExpected（expected 模式） |
|---|---|---|
| 用途 | 出价上限保护 | 仓库质量判断 |
| 未知物品 | 白色最低价（最悲观） | poolAvg（中性） |
| L2 物品 | 该品质+尺寸的最低价 | 该品质的均价 |
| 设计偏向 | 保守 | 无偏 |
| 调用方 | InfoEstimation → estimate → 出价 | InfoEstimation → qualityMultiplier → 调整出价 |

---

## 9. 边界情况

| 场景 | 处理 |
|------|------|
| 仓库所有物品未知 | 所有条件期望值 = poolAvg，ratio = 1.0，乘数 = 1.0 |
| L1 在品类中找不到匹配尺寸 | 回退到品类均价 |
| L2 无品类信息 | 用全池品质加权均价 `qualityAvgWeighted[quality]` |
| 单件红色物品导致 ratio 极大 | clamp 到 1.5 |
| poolAvg 或 itemCount 为 0 | 返回乘数 1.0 |
| 仓库类型不在 warehouseModules 中 | fallback 到 grocery |
