#!/usr/bin/env python3
"""
拍卖之王 - 角色强度模拟器
模拟 4个AI × N场竞拍，统计每个角色的各项数据

用法:
  python3 simulate_characters.py [场次数=10000000] [随机种子=42]
  python3 simulate_characters.py 1000000        # 100万场快速验证
  python3 simulate_characters.py 10000000       # 1000万场完整统计

输出:
  每个角色的胜率、平均ROI、平均估值误差、平均信息覆盖、平均赢轮次
"""

import random
import math
import re
import os
import sys
import time
import json
from collections import defaultdict

# ─────────────────────────────────────────────────────────────
# 0. 路径配置
# ─────────────────────────────────────────────────────────────
SCRIPT_DIR   = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
CATEGORIES_DIR = os.path.join(PROJECT_ROOT, "Config", "Categories")

# ─────────────────────────────────────────────────────────────
# 1. 解析 Lua 物品池
# ─────────────────────────────────────────────────────────────
def parse_items_from_lua(filepath, category_id):
    """从 Lua 品类文件中提取 {name, rows, cols, quality, value, weight}"""
    with open(filepath, encoding="utf-8") as f:
        content = f.read()

    # 按行提取：寻找含 quality = "..." 的 { } 块（同一行或多行短格式）
    # 大多数物品定义在单行，少数跨行。先把多行紧凑化
    content = re.sub(r'\n\s+', ' ', content)  # 把缩进换行合并成空格

    items = []
    # 匹配每个 { ... } 块（非贪婪，不跨大括号）
    for block in re.finditer(r'\{([^{}]+)\}', content):
        s = block.group(1)
        def get(key, default=None):
            m = re.search(r'\b' + key + r'\s*=\s*(["\w.]+)', s)
            if not m:
                return default
            v = m.group(1).strip('"')
            return v

        quality = get("quality")
        if quality is None:
            continue
        name  = get("name", "")
        rows  = int(get("rows", 1))
        cols  = int(get("cols", 1))
        value = int(float(get("value", 0)))
        weight = int(float(get("weight", 1)))
        if value <= 0:
            continue
        items.append({
            "name":     name,
            "rows":     rows,
            "cols":     cols,
            "quality":  quality,
            "value":    value,
            "weight":   weight,
            "category": category_id,
            "cells":    rows * cols,
        })
    return items

CATEGORY_FILES = {
    "antique":    "Antique.lua",
    "daily":      "Daily.lua",
    "energy":     "Energy.lua",
    "transport":  "Transport.lua",
    "tech":       "Tech.lua",
    "art":        "Art.lua",
    "jewel":      "Jewel.lua",
    "mechanical": "Mechanical.lua",
    "fashion":    "Fashion.lua",
    "biotech":    "Biotech.lua",
}

# 默认品类权重（通用仓库）
DEFAULT_CAT_WEIGHTS = {
    "antique": 25, "energy": 30, "tech": 25, "art": 8,
    "jewel": 8, "transport": 10, "mechanical": 8,
    "daily": 0, "fashion": 0, "biotech": 0,
}

print("正在加载物品池...", end=" ", flush=True)
ALL_ITEMS = []      # 全部物品列表
CAT_ITEMS = {}      # {category_id: [item, ...]}

for cat_id, fname in CATEGORY_FILES.items():
    path = os.path.join(CATEGORIES_DIR, fname)
    items = parse_items_from_lua(path, cat_id)
    CAT_ITEMS[cat_id] = items
    ALL_ITEMS.extend(items)

print(f"共 {len(ALL_ITEMS)} 件物品", flush=True)

# ─────────────────────────────────────────────────────────────
# 2. 构建估值查找表
# ─────────────────────────────────────────────────────────────
# 品质排序
QUALITY_ORDER = ["white", "green", "blue", "purple", "gold", "red"]
QUALITY_RANK  = {q: i for i, q in enumerate(QUALITY_ORDER)}

# 计算加权平均
def weighted_avg(items_list, key="value"):
    total_w, total_v = 0, 0
    for it in items_list:
        w = it["weight"]
        total_w += w
        total_v += it[key] * w
    return (total_v / total_w) if total_w > 0 else 0

# 池全局加权均价
POOL_AVG = weighted_avg(ALL_ITEMS)

# rarityAvgValue[quality] = 该品质加权均价
RARITY_AVG = {}
for q in QUALITY_ORDER:
    items_q = [it for it in ALL_ITEMS if it["quality"] == q]
    if items_q:
        RARITY_AVG[q] = weighted_avg(items_q)

# categoryRelative[cat] = 该品类均价 / 池均价
CAT_RELATIVE = {}
for cat_id, items_c in CAT_ITEMS.items():
    if items_c and DEFAULT_CAT_WEIGHTS.get(cat_id, 0) > 0:
        CAT_RELATIVE[cat_id] = weighted_avg(items_c) / POOL_AVG

# categoryRarityAvg[(cat, quality)] = 该品类+品质组合加权均价
CAT_RARITY_AVG = {}
for cat_id, items_c in CAT_ITEMS.items():
    for q in QUALITY_ORDER:
        items_cq = [it for it in items_c if it["quality"] == q]
        if items_cq:
            CAT_RARITY_AVG[(cat_id, q)] = weighted_avg(items_cq)

# ─────────────────────────────────────────────────────────────
# 3. 仓库分层系统
# ─────────────────────────────────────────────────────────────
WAREHOUSE_TIERS = [
    {"id": "trash",    "weight": 25, "multMin": 0.25, "multMax": 0.40},
    {"id": "junk",     "weight": 23, "multMin": 0.35, "multMax": 0.55},
    {"id": "poor",     "weight": 22, "multMin": 0.50, "multMax": 0.75},
    {"id": "normal",   "weight": 13, "multMin": 0.65, "multMax": 1.00},
    {"id": "good",     "weight":  9, "multMin": 1.00, "multMax": 1.80},
    {"id": "treasure", "weight":  6, "multMin": 1.80, "multMax": 3.20},
    {"id": "jackpot",  "weight":  2, "multMin": 3.20, "multMax": 5.50},
]
TIER_TOTAL_WEIGHT = sum(t["weight"] for t in WAREHOUSE_TIERS)

# Tier 先验乘数 P40
PRIOR_PCT = 0.40
def compute_tier_prior():
    total = TIER_TOTAL_WEIGHT
    target = total * PRIOR_PCT
    acc = 0
    for t in WAREHOUSE_TIERS:
        prev = acc
        acc += t["weight"]
        if acc >= target:
            prog = (target - prev) / t["weight"]
            return t["multMin"] + (t["multMax"] - t["multMin"]) * prog
    return 0.50
TIER_PRIOR_MULT = compute_tier_prior()  # ≈ 0.456

def roll_tier(rng):
    r = rng.random() * TIER_TOTAL_WEIGHT
    acc = 0
    for t in WAREHOUSE_TIERS:
        acc += t["weight"]
        if r <= acc:
            return t
    return WAREHOUSE_TIERS[2]

# 区域参考（均值期望价值）
REGIONS = [
    {"id": "suburb",     "warehouseValue": 45000},
    {"id": "industrial", "warehouseValue": 80000},
    {"id": "commercial", "warehouseValue": 400000},
    {"id": "port",       "warehouseValue": 1000000},
    {"id": "techpark",   "warehouseValue": 2000000},
    {"id": "culture",    "warehouseValue": 5000000},
    {"id": "deepsea",    "warehouseValue": 8000000},
]

# 构建物品采样池（按默认权重 × item.weight 的有效权重采样）
SAMPLE_ITEMS = []   # 仅含 weight>0 类别的物品
SAMPLE_WEIGHTS = [] # 对应的综合权重

for it in ALL_ITEMS:
    cat_w = DEFAULT_CAT_WEIGHTS.get(it["category"], 0)
    if cat_w > 0:
        SAMPLE_ITEMS.append(it)
        SAMPLE_WEIGHTS.append(cat_w * it["weight"])

# 预计算累积权重，用于快速加权随机采样
_CUM_W = []
_total_w = 0
for w in SAMPLE_WEIGHTS:
    _total_w += w
    _CUM_W.append(_total_w)

def sample_item(rng):
    """按权重采样一件物品"""
    r = rng.random() * _total_w
    lo, hi = 0, len(_CUM_W) - 1
    while lo < hi:
        mid = (lo + hi) // 2
        if _CUM_W[mid] < r:
            lo = mid + 1
        else:
            hi = mid
    return SAMPLE_ITEMS[lo]

# 各品类物品按 quality_rank 排序（用于 highest_N 目标选择）
CAT_SORTED_BY_QUALITY = {}
for cat_id, items_c in CAT_ITEMS.items():
    CAT_SORTED_BY_QUALITY[cat_id] = sorted(items_c,
        key=lambda x: QUALITY_RANK.get(x["quality"], 0), reverse=True)

# ─────────────────────────────────────────────────────────────
# 4. 角色数据（硬编码，与 Config/Characters.lua 保持一致）
# ─────────────────────────────────────────────────────────────
CHARACTERS = [
    # ── 免费角色 ─────────────────────────────────────────────
    {
        "id": 2, "name": "赵沐瑶", "locked": False,
        "revealEvents": [
            {"trigger": "round_1",      "target": "highest_1",         "category": "energy",  "level": "L2"},
            {"trigger": "round_2",      "target": "category_all",      "category": "energy",  "level": "L0"},
            {"trigger": "from_round_3", "target": "category_random_3", "category": "energy",  "level": "L1"},
        ],
        "personality": {"bidLow": 0.35, "bidHigh": 0.65, "resignThreshold": 0.25, "qualitySensUp": 0.20, "qualitySensDown": 0.50},
    },
    {
        "id": 1, "name": "林远舟", "locked": False,
        "revealEvents": [
            {"trigger": "round_1", "target": "category_all",      "category": "antique", "level": "L0"},
            {"trigger": "round_3", "target": "category_random_2", "category": "antique", "level": "L1"},
            {"trigger": "round_5", "target": "category_random_1", "category": "antique", "level": "L2_hint"},
        ],
        "personality": {"bidLow": 0.40, "bidHigh": 0.70, "resignThreshold": 0.25, "qualitySensUp": 0.50, "qualitySensDown": 0.50},
    },
    {
        "id": 3, "name": "钱思远", "locked": False,
        "revealEvents": [
            {"trigger": "round_1", "target": "category_all",      "category": "tech", "level": "L0"},
            {"trigger": "round_2", "target": "category_random_2", "category": "tech", "level": "L1"},
            {"trigger": "round_4", "target": "category_random_1", "category": "tech", "level": "L2_hint"},
        ],
        "personality": {"bidLow": 0.30, "bidHigh": 0.55, "resignThreshold": 0.20, "qualitySensUp": 0.15, "qualitySensDown": 0.70},
    },
    {
        "id": 4, "name": "顾清韵", "locked": False,
        "revealEvents": [
            {"trigger": "round_1", "target": "category_random_3", "category": "art", "level": "L1"},
            {"trigger": "round_2", "target": "category_all",      "category": "art", "level": "L0"},
            {"trigger": "round_4", "target": "category_random_2", "category": "art", "level": "L2"},
        ],
        "personality": {"bidLow": 0.40, "bidHigh": 0.70, "resignThreshold": 0.25, "qualitySensUp": 0.50, "qualitySensDown": 0.50},
    },
    {
        "id": 7, "name": "方逸尘", "locked": False,
        "revealEvents": [
            {"trigger": "round_1", "target": "category_all",      "category": "transport", "level": "L0"},
            {"trigger": "round_3", "target": "category_random_2", "category": "transport", "level": "L1"},
            {"trigger": "round_5", "target": "category_random_1", "category": "transport", "level": "L2_hint"},
        ],
        "personality": {"bidLow": 0.35, "bidHigh": 0.65, "resignThreshold": 0.20, "qualitySensUp": 0.60, "qualitySensDown": 0.25},
    },
    {
        "id": 8, "name": "韩墨璃", "locked": False,
        "revealEvents": [
            {"trigger": "round_1",     "target": "category_all",      "category": ["antique", "art"], "level": "L0"},
            {"trigger": "every_round", "target": "category_random_1", "category": ["antique", "art"], "level": "L2_hint"},
        ],
        "personality": {"bidLow": 0.35, "bidHigh": 0.60, "resignThreshold": 0.20, "qualitySensUp": 0.30, "qualitySensDown": 0.60},
    },
    {
        "id": 9, "name": "孙弈辰", "locked": False,
        "revealEvents": [
            {"trigger": "round_1", "target": "category_all",      "category": ["energy", "tech"], "level": "L0"},
            {"trigger": "round_3", "target": "category_random_2", "category": ["energy", "tech"], "level": "L1"},
            {"trigger": "round_5", "target": "category_random_1", "category": ["energy", "tech"], "level": "L2_hint"},
        ],
        "personality": {"bidLow": 0.30, "bidHigh": 0.55, "resignThreshold": 0.25, "qualitySensUp": 0.20, "qualitySensDown": 0.50},
    },
    # ── 锁定角色 ─────────────────────────────────────────────
    {
        "id": 10, "name": "吴鉴之", "locked": True,
        "revealEvents": [
            {"trigger": "round_1",      "target": "highest_3", "category": None, "level": "L2_hint"},
            {"trigger": "from_round_2", "target": "random_2",  "category": None, "level": "L2_hint"},
            {"trigger": "round_4",      "target": "highest_1", "category": None, "level": "L2"},
        ],
        "personality": {"bidLow": 0.40, "bidHigh": 0.75, "resignThreshold": 0.30, "qualitySensUp": 0.60, "qualitySensDown": 0.70},
    },
    {
        "id": 12, "name": "陆鉴", "locked": True,
        "revealEvents": [
            {"trigger": "round_1",      "target": "random_5",      "category": None, "level": "L1"},
            {"trigger": "from_round_2", "target": "random_2",      "category": None, "level": "L2"},
            {"trigger": "round_4",      "target": "rare_random_3", "category": None, "level": "L1"},
        ],
        "personality": {"bidLow": 0.40, "bidHigh": 0.70, "resignThreshold": 0.25, "qualitySensUp": 0.45, "qualitySensDown": 0.55},
    },
    {
        "id": 13, "name": "慕寒星", "locked": True,
        "revealEvents": [
            {"trigger": "every_round", "target": "random_2", "category": None, "level": "L2"},
        ],
        "personality": {"bidLow": 0.42, "bidHigh": 0.72, "resignThreshold": 0.30, "qualitySensUp": 0.55, "qualitySensDown": 0.65},
    },
    {
        "id": 14, "name": "陆时晴", "locked": True,
        "revealEvents": [
            {"trigger": "round_1",      "target": "random_5", "category": None, "level": "L2_hint"},
            {"trigger": "from_round_2", "target": "random_2", "category": None, "level": "L2_hint"},
        ],
        "personality": {"bidLow": 0.33, "bidHigh": 0.62, "resignThreshold": 0.20, "qualitySensUp": 0.35, "qualitySensDown": 0.40},
    },
    {
        "id": 16, "name": "江识玉", "locked": True,
        "revealEvents": [
            {"trigger": "round_1",      "target": "highest_1",         "category": None,    "level": "L2_hint"},
            {"trigger": "round_1",      "target": "category_random_4", "category": "jewel", "level": "L1"},
            {"trigger": "from_round_2", "target": "category_random_2", "category": "jewel", "level": "L2_hint"},
            {"trigger": "round_4",      "target": "highest_2",         "category": None,    "level": "L2_hint"},
        ],
        "personality": {"bidLow": 0.38, "bidHigh": 0.68, "resignThreshold": 0.28, "qualitySensUp": 0.50, "qualitySensDown": 0.60},
    },
    {
        "id": 17, "name": "贺明珏", "locked": True,
        "revealEvents": [
            {"trigger": "round_1", "target": "category_all", "category": "jewel", "level": "L2"},
        ],
        "personality": {"bidLow": 0.42, "bidHigh": 0.78, "resignThreshold": 0.35, "qualitySensUp": 0.60, "qualitySensDown": 0.70},
    },
    {
        "id": 18, "name": "谢怀仁", "locked": True,
        "revealEvents": [
            {"trigger": "round_1",      "target": "category_all",      "category": "biotech", "level": "L2_hint"},
            {"trigger": "from_round_2", "target": "category_random_2", "category": "biotech", "level": "L2"},
            {"trigger": "round_5",      "target": "category_all",      "category": "biotech", "level": "L2"},
        ],
        "personality": {"bidLow": 0.36, "bidHigh": 0.66, "resignThreshold": 0.25, "qualitySensUp": 0.45, "qualitySensDown": 0.55},
    },
    {
        "id": 15, "name": "程云裳", "locked": True,
        "revealEvents": [
            {"trigger": "round_1",      "target": "category_all",      "category": "fashion", "level": "L2"},
            {"trigger": "from_round_2", "target": "random_1",          "category": None,      "level": "L2_hint"},
            {"trigger": "round_4",      "target": "category_random_1", "category": "fashion", "level": "L3"},
        ],
        "personality": {"bidLow": 0.40, "bidHigh": 0.75, "resignThreshold": 0.30, "qualitySensUp": 0.55, "qualitySensDown": 0.65},
    },
    {
        "id": 11, "name": "何启明", "locked": True,
        "revealEvents": [
            {"trigger": "every_round", "target": "random_3",  "category": None, "level": "L2_hint"},
            {"trigger": "round_3",     "target": "highest_3", "category": None, "level": "L1"},
        ],
        "personality": {"bidLow": 0.40, "bidHigh": 0.70, "resignThreshold": 0.25, "qualitySensUp": 0.35, "qualitySensDown": 0.30},
    },
    {
        "id": 5, "name": "沈玉珂", "locked": True,
        "revealEvents": [
            {"trigger": "round_1", "target": "category_all",      "category": "jewel", "level": "L0"},
            {"trigger": "round_2", "target": "category_random_2", "category": "jewel", "level": "L3"},
            {"trigger": "round_4", "target": "category_random_2", "category": "jewel", "level": "L2_hint"},
        ],
        "personality": {"bidLow": 0.40, "bidHigh": 0.80, "resignThreshold": 0.35, "qualitySensUp": 0.60, "qualitySensDown": 0.70},
    },
    {
        "id": 19, "name": "裴锦书", "locked": True,
        "revealEvents": [
            {"trigger": "round_1",      "target": "category_all", "category": "daily", "level": "L2"},
            {"trigger": "from_round_2", "target": "random_2",     "category": None,    "level": "L2"},
            {"trigger": "round_5",      "target": "category_all", "category": "daily", "level": "L3"},
        ],
        "personality": {"bidLow": 0.45, "bidHigh": 0.82, "resignThreshold": 0.40, "qualitySensUp": 0.70, "qualitySensDown": 0.75},
    },
    {
        "id": 6, "name": "周正霆", "locked": True,
        "revealEvents": [
            {"trigger": "round_1", "target": "category_all",      "category": "mechanical", "level": "L0"},
            {"trigger": "round_2", "target": "category_all",      "category": "mechanical", "level": "L1"},
            {"trigger": "round_3", "target": "category_random_2", "category": "mechanical", "level": "L3"},
            {"trigger": "round_4", "target": "category_random_1", "category": "mechanical", "level": "L3"},
            {"trigger": "round_5", "target": "random_2",          "category": None,         "level": "L2_hint"},
        ],
        "personality": {"bidLow": 0.35, "bidHigh": 0.70, "resignThreshold": 0.25, "qualitySensUp": 0.40, "qualitySensDown": 0.50},
    },
]

NUM_CHARS = len(CHARACTERS)

# ─────────────────────────────────────────────────────────────
# 5. 揭示逻辑
# ─────────────────────────────────────────────────────────────
LEVEL_NUMERIC = {"L0": 0, "L1": 1, "L2_hint": 2, "L2": 3, "L3": 4}

RARE_QUALITIES = {"purple", "gold", "red"}


def apply_reveal(items, known_levels, event, rng):
    """
    将 revealEvent 应用到 items，更新 known_levels[item_idx]。
    known_levels: list[int], 与 items 同长，初始全为 0
    """
    trigger  = event["trigger"]
    target   = event["target"]
    category = event["category"]
    lvl      = LEVEL_NUMERIC.get(event["level"], 0)

    # 确定候选物品集合
    if category is None:
        candidates = list(range(len(items)))
    elif isinstance(category, list):
        candidates = [i for i, it in enumerate(items) if it["category"] in category]
    else:
        candidates = [i for i, it in enumerate(items) if it["category"] == category]

    if not candidates:
        return

    # 根据 target 选出目标索引列表
    if target == "all" or target == "category_all":
        targets = candidates

    elif target.startswith("highest_"):
        n = int(target.split("_")[1])
        # 按 quality_rank 降序
        sorted_cands = sorted(candidates,
            key=lambda i: QUALITY_RANK.get(items[i]["quality"], 0), reverse=True)
        targets = sorted_cands[:n]

    elif target.startswith("rare_random_"):
        n = int(target.split("_")[2])
        rare_cands = [i for i in candidates
                      if items[i]["quality"] in RARE_QUALITIES]
        if rare_cands:
            rng.shuffle(rare_cands)
            targets = rare_cands[:n]
        else:
            targets = []

    elif target.startswith("random_"):
        n = int(target.split("_")[1])
        cpy = candidates[:]
        rng.shuffle(cpy)
        targets = cpy[:n]

    elif target.startswith("category_random_"):
        n = int(target.split("_")[2])
        cpy = candidates[:]
        rng.shuffle(cpy)
        targets = cpy[:n]

    else:
        targets = []

    # 升级已知等级（只升不降）
    for i in targets:
        if lvl > known_levels[i]:
            known_levels[i] = lvl


def apply_reveals_up_to_round(items, char, up_to_round, rng):
    """
    模拟到第 up_to_round 轮结束时，该角色对 items 的已知等级。
    返回 known_levels: list[int]
    """
    known = [0] * len(items)
    for round_num in range(1, up_to_round + 1):
        for evt in char["revealEvents"]:
            trig = evt["trigger"]
            if trig == "every_round":
                apply_reveal(items, known, evt, rng)
            elif trig == f"round_{round_num}":
                apply_reveal(items, known, evt, rng)
            elif trig.startswith("from_round_"):
                n = int(trig.split("_")[2])
                if round_num >= n:
                    apply_reveal(items, known, evt, rng)
    return known


# ─────────────────────────────────────────────────────────────
# 6. 估值计算
# ─────────────────────────────────────────────────────────────

def estimate_total(items, known_levels, expected_value):
    """
    给定 items + known_levels，估算仓库总价值。
    使用 tier-prior baseline + 逐级升精 的方法（与 EstimateValue.lua 一致）

    expected_value: 该区域的 warehouseValue（AI 事先知晓的行情）
    """
    n = len(items)
    if n == 0:
        return expected_value

    # baseline: 用 P40 tier prior × expected_value / n  → per-item 先验
    baseline_per = expected_value * TIER_PRIOR_MULT / n

    total_est = 0.0
    l3_count  = 0
    l3_hypo_sum = 0.0   # L3物品的"假设只有L2时"估值
    l3_real_sum = 0.0   # L3物品的实际值

    for i, it in enumerate(items):
        lv = known_levels[i]
        q  = it["quality"]
        c  = it["category"]

        if lv >= 4:      # L3 精确值
            est = float(it["value"])
            hypo = baseline_per * (RARITY_AVG.get(q, POOL_AVG) / POOL_AVG)
            l3_count += 1
            l3_hypo_sum += hypo
            l3_real_sum += est

        elif lv >= 3:    # L2 知品质+品类
            cr_key = (c, q)
            pool_rarity_avg = RARITY_AVG.get(q, POOL_AVG)
            cr_avg = CAT_RARITY_AVG.get(cr_key, pool_rarity_avg)
            est = max(cr_avg, pool_rarity_avg)

        elif lv >= 2:    # L2_hint 仅知品质
            est = RARITY_AVG.get(q, POOL_AVG)

        elif lv >= 1:    # L1 知品类
            cr = CAT_RELATIVE.get(c, 1.0)
            est = baseline_per * cr

        else:            # L0 仅知数量/不知
            est = baseline_per

        total_est += est

    # 质量推断修正（≥3 件 L3 已知时）
    if l3_count >= 3 and l3_hypo_sum > 0:
        raw_ratio = l3_real_sum / l3_hypo_sum
        raw_ratio = max(0.3, min(3.0, raw_ratio))
        sample_w  = min(1.0, l3_count / max(n, 1))
        damp      = min(1.0, sample_w * 2)
        quality_ratio = 1.0 + (raw_ratio - 1.0) * damp
        quality_ratio = max(0.5, min(2.0, quality_ratio))
        # 只修正 L0/L1 物品（已知物品不需要修正）
        for i, it in enumerate(items):
            lv = known_levels[i]
            if lv < 2:
                old_est = (baseline_per * CAT_RELATIVE.get(it["category"], 1.0)
                           if lv >= 1 else baseline_per)
                total_est += old_est * (quality_ratio - 1.0)

    return total_est


# ─────────────────────────────────────────────────────────────
# 7. 游戏倍率
# ─────────────────────────────────────────────────────────────
MULTIPLIERS = {1: 2.0, 2: 1.6, 3: 1.4, 4: 1.2, 5: 1.01}
MAX_ROUNDS = 5

# ─────────────────────────────────────────────────────────────
# 8. 单场模拟
# ─────────────────────────────────────────────────────────────

def simulate_session(char_combo, region_wv, rng):
    """
    模拟一场竞拍。
    char_combo: [char0, char1, char2, char3]  —— 4个AI角色
    region_wv: 该区域的 warehouseValue
    返回 (winner_idx, win_round, win_bid, true_value, bids_per_round, estimates_per_char)

    estimates_per_char[ci][round] = 第 ci 个AI在第 round 轮的估值
    """
    # (a) 生成仓库物品：15~25 件
    n_items = rng.randint(15, 25)
    items = [sample_item(rng) for _ in range(n_items)]

    true_value = sum(it["value"] for it in items)

    # 期望值：AI先验 = 区域 warehouseValue（已知行情）
    expected_value = region_wv

    # (b) 每个AI的出价历史（记录每轮出价）
    #     bids[ci] = float  (当前轮的出价)
    #     previous_bids[round][ci] = 上一轮出价
    prev_round_bids = {}   # {round: {ci: bid}}
    active = [True, True, True, True]  # 是否仍在竞拍

    # 存储每个角色每轮的估值（用于统计）
    estimates_by_char_round = [[0.0] * (MAX_ROUNDS + 1) for _ in range(4)]

    winner_idx   = -1
    win_round    = -1
    win_bid      = 0.0

    for round_num in range(1, MAX_ROUNDS + 1):
        multiplier = MULTIPLIERS[round_num]

        # 计算每个AI本轮的估值和出价
        round_bids = {}
        for ci, char in enumerate(char_combo):
            if not active[ci]:
                round_bids[ci] = 0.0
                continue

            known = apply_reveals_up_to_round(items, char, round_num, rng)
            est   = estimate_total(items, known, expected_value)
            estimates_by_char_round[ci][round_num] = est

            p = char["personality"]
            bid_ratio = rng.uniform(p["bidLow"], p["bidHigh"])

            # 质量信号：已知物品均价 vs 池均价，影响是否弃权
            known_items = [(items[i], known[i]) for i in range(len(items)) if known[i] >= 2]
            if len(known_items) >= 2:
                known_avg = sum(it["value"] for it, _ in known_items) / len(known_items)
                quality_signal = (known_avg - POOL_AVG) / max(POOL_AVG, 1)
                # 负质量信号下有概率弃权
                resign_thresh = p["resignThreshold"]
                if quality_signal < -(1.0 - resign_thresh):
                    if round_num >= 2:  # 第1轮不弃权
                        active[ci] = False
                        round_bids[ci] = 0.0
                        continue

            bid = est * bid_ratio
            # 小幅随机扰动（模拟数字风格化）
            bid = bid * rng.uniform(0.97, 1.03)
            round_bids[ci] = bid

        prev_round_bids[round_num] = round_bids

        # 判断本轮是否有人赢
        active_bids = [(ci, round_bids[ci]) for ci in range(4) if active[ci] and round_bids[ci] > 0]
        if not active_bids:
            break

        active_bids.sort(key=lambda x: -x[1])
        highest_ci,  highest_bid  = active_bids[0]
        second_bid = active_bids[1][1] if len(active_bids) >= 2 else 0

        # 胜出条件：最高出价 / 第二高 >= 倍率
        if second_bid <= 0 or (highest_bid / max(second_bid, 1)) >= multiplier:
            winner_idx = highest_ci
            win_round  = round_num
            win_bid    = highest_bid
            break

    # 若5轮都没分出胜负（极罕见），取最高出价者
    if winner_idx == -1:
        all_final = [(ci, prev_round_bids.get(MAX_ROUNDS, {}).get(ci, 0)) for ci in range(4)]
        all_final.sort(key=lambda x: -x[1])
        winner_idx = all_final[0][0]
        win_round  = MAX_ROUNDS
        win_bid    = all_final[0][1]

    return winner_idx, win_round, win_bid, true_value, estimates_by_char_round


# ─────────────────────────────────────────────────────────────
# 9. 主模拟循环
# ─────────────────────────────────────────────────────────────

def make_empty_stats():
    """创建空统计结构（聚合模式，不存列表，支持 JSON 序列化和跨批次累加）"""
    stats = {}
    for ch in CHARACTERS:
        cname = ch["name"]
        stats[cname] = {
            "sessions":        0,
            "wins":            0,
            "win_round_sum":   0,
            "profit_sum":      0.0,
            "roi_sum":         0.0,
            "roi_sq_sum":      0.0,
            "overpay_count":   0,   # win_bid > true_value 次数
            "est_err_sum":     0.0,
            "est_err_count":   0,
            # ROI 直方图：用于估算百分位（桶宽 0.5，范围 0~50）
            "roi_hist":        [0] * 100,
        }
    return stats

def merge_stats(base, addition):
    """将 addition 的统计合并到 base 中（原地修改 base）"""
    for cname, a in addition.items():
        b = base[cname]
        b["sessions"]      += a["sessions"]
        b["wins"]          += a["wins"]
        b["win_round_sum"] += a["win_round_sum"]
        b["profit_sum"]    += a["profit_sum"]
        b["roi_sum"]       += a["roi_sum"]
        b["roi_sq_sum"]    += a["roi_sq_sum"]
        b["overpay_count"] += a["overpay_count"]
        b["est_err_sum"]   += a["est_err_sum"]
        b["est_err_count"] += a["est_err_count"]
        for i in range(100):
            b["roi_hist"][i] += a["roi_hist"][i]
    return base

def save_stats(stats, total_sessions, filepath):
    """保存统计到 JSON 文件"""
    data = {"total_sessions": total_sessions, "stats": stats}
    with open(filepath, "w", encoding="utf-8") as f:
        json.dump(data, f)

def load_stats(filepath):
    """从 JSON 文件加载统计，返回 (stats, total_sessions)"""
    with open(filepath, encoding="utf-8") as f:
        data = json.load(f)
    return data["stats"], data["total_sessions"]

def run_simulation(n_sessions, seed=42, base_stats=None, base_sessions=0):
    """
    运行 n_sessions 场模拟。
    base_stats: 已有统计（可选，用于分批累加）
    base_sessions: 已跑场次数（影响进度显示）
    """
    rng = random.Random(seed)
    stats = make_empty_stats()

    start_t = time.time()
    report_every = max(1, n_sessions // 20)
    total_for_display = (base_sessions or 0) + n_sessions

    for sess in range(n_sessions):
        if sess > 0 and sess % report_every == 0:
            elapsed = time.time() - start_t
            pct     = ((base_sessions or 0) + sess) / total_for_display * 100
            eta     = elapsed / sess * (n_sessions - sess)
            print(f"  {pct:.0f}%  ({(base_sessions or 0)+sess:,}/{total_for_display:,})  "
                  f"已用 {elapsed:.1f}s  预计剩余 {eta:.1f}s", flush=True)

        combo_indices = rng.sample(range(NUM_CHARS), 4)
        combo = [CHARACTERS[i] for i in combo_indices]
        region = rng.choice(REGIONS)
        wv = region["warehouseValue"]

        winner_idx, win_round, win_bid, true_value, est_by_cr = simulate_session(combo, wv, rng)

        for slot_idx, char_idx in enumerate(combo_indices):
            cname = combo[slot_idx]["name"]
            st = stats[cname]
            st["sessions"] += 1

            final_round = MAX_ROUNDS
            est_final = est_by_cr[slot_idx][final_round]
            if est_final > 0 and true_value > 0:
                err = abs(est_final - true_value) / true_value
                st["est_err_sum"]   += err
                st["est_err_count"] += 1

            if slot_idx == winner_idx:
                st["wins"] += 1
                st["win_round_sum"] += win_round
                profit = true_value - win_bid
                st["profit_sum"] += profit
                if win_bid > 0:
                    roi = true_value / win_bid
                    st["roi_sum"]    += roi
                    st["roi_sq_sum"] += roi * roi
                    if profit < 0:
                        st["overpay_count"] += 1
                    # ROI 直方图（桶宽 0.5，0~50）
                    b = int(roi * 2)
                    st["roi_hist"][b if b < 100 else 99] += 1

    print()
    if base_stats is not None:
        merge_stats(base_stats, stats)
        return base_stats
    return stats


# ─────────────────────────────────────────────────────────────
# 10. 输出报告
# ─────────────────────────────────────────────────────────────

def roi_percentile_from_hist(roi_hist, p):
    """从 ROI 直方图估算第 p 百分位（桶宽 0.5）"""
    total = sum(roi_hist)
    if total == 0:
        return 0.0
    target = total * p / 100.0
    acc = 0
    for i, cnt in enumerate(roi_hist):
        acc += cnt
        if acc >= target:
            return (i + 0.5) * 0.5  # 桶中点
    return len(roi_hist) * 0.5

def print_report(stats, n_sessions):
    print()
    print("=" * 90)
    print(f"  拍卖之王 角色强度模拟报告   (共 {n_sessions:,} 场)")
    print("=" * 90)

    free_chars   = [ch for ch in CHARACTERS if not ch["locked"]]
    locked_chars = [ch for ch in CHARACTERS if ch["locked"]]

    def print_section(chars, title):
        print(f"\n{'─'*90}")
        print(f"  {title}")
        print(f"{'─'*90}")
        header = (f"  {'角色':<8}  {'场次':>8}  {'胜率':>6}  "
                  f"{'均ROI':>7}  {'均盈亏':>10}  {'超付%':>6}  "
                  f"{'均赢轮':>6}  {'估值误差':>8}  "
                  f"{'ROI_P25':>8}  {'ROI_P75':>8}")
        print(header)
        print(f"  {'─'*8}  {'─'*8}  {'─'*6}  {'─'*7}  {'─'*10}  {'─'*6}  {'─'*6}  {'─'*8}  {'─'*8}  {'─'*8}")

        rows = []
        for ch in chars:
            cname = ch["name"]
            st = stats[cname]
            n  = st["sessions"]
            w  = st["wins"]
            win_rate      = w / max(n, 1) * 100
            avg_roi       = st["roi_sum"] / max(w, 1)
            avg_profit    = st["profit_sum"] / max(w, 1)
            overpay_rate  = st["overpay_count"] / max(w, 1) * 100
            avg_win_round = st["win_round_sum"] / max(w, 1)
            est_err       = st["est_err_sum"] / max(st["est_err_count"], 1) * 100
            roi_p25 = roi_percentile_from_hist(st["roi_hist"], 25)
            roi_p75 = roi_percentile_from_hist(st["roi_hist"], 75)

            rows.append((cname, n, win_rate, avg_roi, avg_profit,
                         overpay_rate, avg_win_round, est_err, roi_p25, roi_p75))

        rows.sort(key=lambda x: -x[2])
        for row in rows:
            (cname, n, win_rate, avg_roi, avg_profit,
             overpay_rate, avg_win_round, est_err, roi_p25, roi_p75) = row
            print(f"  {cname:<8}  {n:>8,}  {win_rate:>5.1f}%  "
                  f"{avg_roi:>7.3f}  {avg_profit:>+10,.0f}  {overpay_rate:>5.1f}%  "
                  f"{avg_win_round:>6.2f}  {est_err:>7.1f}%  "
                  f"{roi_p25:>8.3f}  {roi_p75:>8.3f}")

    print_section(free_chars,   "【免费角色】")
    print_section(locked_chars, "【锁定角色】")

    # 综合排名
    print(f"\n{'─'*90}")
    print("  综合胜率排名（全部角色）")
    print(f"{'─'*90}")
    all_rows = []
    for ch in CHARACTERS:
        cname = ch["name"]
        st = stats[cname]
        n  = st["sessions"]
        w  = st["wins"]
        all_rows.append((cname, "🔒" if ch["locked"] else "🆓",
                         w / max(n, 1) * 100,
                         st["roi_sum"] / max(w, 1)))
    all_rows.sort(key=lambda x: -x[2])
    for rank, (name, icon, wr, roi) in enumerate(all_rows, 1):
        bar = "█" * int(wr / 2) + "░" * (20 - int(wr / 2))
        print(f"  #{rank:>2}  {icon} {name:<8}  {bar}  {wr:.1f}%  ROI={roi:.3f}")

    print()
    print("  列说明:")
    print("    胜率  = 赢得竞拍的场次 / 被分配的场次")
    print("    均ROI = 平均(真实价值/成交价)，>1表示赚钱")
    print("    均盈亏= 平均(真实价值 - 成交价)，正数表示买到便宜货")
    print("    均亏损%= 赢得竞拍中成交价>真实价值的比例（超付率）")
    print("    均赢轮= 平均在第几轮赢得竞拍")
    print("    估值误差= 第5轮时 |估值-真实价值|/真实价值 的平均值")
    print("    ROI_P25/P75 = ROI 的四分位数")
    print()


# ─────────────────────────────────────────────────────────────
# 11. 入口
# ─────────────────────────────────────────────────────────────
# 用法:
#   完整运行:    python3 simulate_characters.py 10000000
#   分批运行:    python3 simulate_characters.py --batch 500000 [save_file]
#   打印已有结果: python3 simulate_characters.py --report [save_file]
# ─────────────────────────────────────────────────────────────
SAVE_FILE = os.path.join(SCRIPT_DIR, "sim_stats.json")

if __name__ == "__main__":
    args = sys.argv[1:]

    # --report 模式：直接打印已保存的结果
    if args and args[0] == "--report":
        fpath = args[1] if len(args) > 1 else SAVE_FILE
        stats, total = load_stats(fpath)
        print(f"从 {fpath} 加载，共 {total:,} 场")
        print_report(stats, total)
        sys.exit(0)

    # --batch 模式：运行一批并保存
    if args and args[0] == "--batch":
        batch_n = int(args[1]) if len(args) > 1 else 500_000
        fpath   = args[2] if len(args) > 2 else SAVE_FILE
        seed_offset = 0

        # 加载已有进度
        if os.path.exists(fpath):
            base_stats, base_sessions = load_stats(fpath)
            seed_offset = base_sessions  # 用已跑场次作为种子偏移，保证不重复
            print(f"续跑模式：已有 {base_sessions:,} 场，继续跑 {batch_n:,} 场")
        else:
            base_stats, base_sessions = make_empty_stats(), 0
            print(f"新建模拟：跑 {batch_n:,} 场")

        t0 = time.time()
        stats = run_simulation(batch_n, seed=42 + seed_offset,
                               base_stats=base_stats, base_sessions=base_sessions)
        elapsed = time.time() - t0
        total = base_sessions + batch_n

        save_stats(stats, total, fpath)
        print(f"批次完成，耗时 {elapsed:.1f}s（{batch_n/elapsed:,.0f} 场/秒）")
        print(f"累计 {total:,} 场，已保存至 {fpath}")
        print_report(stats, total)
        sys.exit(0)

    # 普通模式：直接运行指定场次
    n_sessions = int(args[0]) if args else 10_000_000
    seed       = int(args[1]) if len(args) > 1 else 42

    print(f"拍卖之王 角色强度模拟器")
    print(f"物品池: {len(ALL_ITEMS)} 件  角色数: {NUM_CHARS}  场次: {n_sessions:,}  种子: {seed}")
    print(f"每场从 {NUM_CHARS} 个角色中随机分配4个不同角色给4个AI")
    print(f"Tier先验乘数(P40) = {TIER_PRIOR_MULT:.4f}  池均价 = {POOL_AVG:,.0f}")
    print()
    print("模拟中...")

    t0 = time.time()
    stats = run_simulation(n_sessions, seed)
    elapsed = time.time() - t0

    print(f"模拟完成，耗时 {elapsed:.1f}s（{n_sessions/elapsed:,.0f} 场/秒）")
    print_report(stats, n_sessions)
