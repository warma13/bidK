-- ============================================================================
-- LootBox.lua - 礼盒开箱逻辑
-- ============================================================================
-- 职责：
--   1. 定义各礼盒的掉落表（按品质分层）
--   2. 从真实仓库藏品池（ItemPool）随机抽取
--   3. 写入存档（消耗礼盒 + 发放藏品到仓库）
-- ============================================================================

local Props       = require("Config.Props")
local Chests      = require("Config.Chests")
local ItemPool    = require("Config.Warehouses.ItemPool")
local SaveSystem  = require("SaveSystem")
local SaveFramework = require("SaveFramework")

local LootBox = {}

-- ============================================================================
-- 礼盒掉落概率表
-- tier = 品质层，weight = 权重（按比例）
-- 各礼盒档次：
--   chest_common  → 紫 + 金 + 红（还有紫）
--   chest_silver  → 金 + 红（出金和红）
--   chest_gold    → 红（只出红）
--   chest_s1      → 紫 + 金 + 红（赛季礼盒）
-- 红色内部：限定红(red_exclusive) 0.1%，普通红 99.9%（相对红色池内部）
-- ============================================================================
local CHEST_TIERS = {
    chest_common = {
        { quality = "purple", weight = 6500 },  -- 65%
        { quality = "gold",   weight = 3390 },  -- 33.9%
        { quality = "red",    weight =  100 },  -- 1%（普通红）
        { quality = "red_ex", weight =    1 },  -- 0.01% 赛季限定红（相当于 0.1% of red pool）
    },
    chest_silver = {
        { quality = "gold",   weight = 8990 },  -- 89.9%
        { quality = "red",    weight =  999 },  -- 9.99%
        { quality = "red_ex", weight =    1 },  -- 0.01% 赛季限定红
    },
    chest_gold = {
        { quality = "red",    weight = 9990 },  -- 99.9%
        { quality = "red_ex", weight =   10 },  -- 0.1% 赛季限定红
    },
    chest_s1 = {
        { quality = "purple", weight = 6500 },  -- 65%
        { quality = "gold",   weight = 3390 },  -- 33.9%
        { quality = "red",    weight =  100 },  -- 1%（普通红）
        { quality = "red_ex", weight =    1 },  -- 0.01% 赛季限定红
    },
}

-- 道具箱：直接指定品质层，从 Props 道具中随机抽取
local PROP_BOX_QUALITY = {
    prop_box_white  = "white",
    prop_box_green  = "green",
    prop_box_blue   = "blue",
    prop_box_purple = "purple",
}

-- 道具池缓存（按品质分层，排除箱子和藏品）
local propPoolCache = {}

local function BuildPropPools()
    if next(propPoolCache) then return end
    for _, q in ipairs({"white","green","blue","purple"}) do
        propPoolCache[q] = {}
    end
    for _, prop in ipairs(Props.LIST) do
        local q = prop.tier or "white"
        if propPoolCache[q] then
            propPoolCache[q][#propPoolCache[q] + 1] = prop
        end
    end
end

-- ============================================================================
-- 构建真实藏品池缓存（按 quality 分层，来自 ItemPool 所有品类）
-- ============================================================================
local itemPoolCache = {}
local redExclusiveCache = nil  -- 赛季限定红（weight 极低的红色物品）

local function BuildItemPools()
    if next(itemPoolCache) then return end
    -- 分层初始化
    for _, q in ipairs({"white","green","blue","purple","gold","red"}) do
        itemPoolCache[q] = {}
    end
    -- 遍历所有品类
    for _, cat in ipairs(ItemPool.categories) do
        for _, item in ipairs(cat.items) do
            local q = item.quality
            if itemPoolCache[q] then
                itemPoolCache[q][#itemPoolCache[q] + 1] = {
                    name      = item.name,
                    rarity    = q,
                    w         = item.cols,
                    h         = item.rows,
                    baseValue = item.value or 0,
                    category  = cat.id,
                    image     = item.image or "",
                    desc      = item.desc or "",
                    weight    = item.weight or 1,
                    exclusive = item.exclusive or false,
                }
            end
        end
    end
    -- 限定红：exclusive = true 的红色物品作为极稀有限定池
    redExclusiveCache = {}
    for _, entry in ipairs(itemPoolCache["red"]) do
        if entry.exclusive then
            redExclusiveCache[#redExclusiveCache + 1] = entry
        end
    end
    -- 如果没有配置限定红，用所有红色兜底
    if #redExclusiveCache == 0 then
        redExclusiveCache = itemPoolCache["red"]
    end
end

-- ============================================================================
-- 加权随机抽取（支持 weight 字段）
-- ============================================================================
local function WeightedRandomFromPool(pool)
    if #pool == 0 then return nil end
    local total = 0
    for _, e in ipairs(pool) do total = total + (e.weight or 1) end
    local r = math.random() * total
    local acc = 0
    for _, e in ipairs(pool) do
        acc = acc + (e.weight or 1)
        if r <= acc then return e end
    end
    return pool[#pool]
end

local function WeightedRandomTier(tiers)
    local total = 0
    for _, t in ipairs(tiers) do total = total + t.weight end
    local r = math.random() * total
    local acc = 0
    for _, t in ipairs(tiers) do
        acc = acc + t.weight
        if r <= acc then return t.quality end
    end
    return tiers[#tiers].quality
end

-- ============================================================================
-- 对外 API
-- ============================================================================

--- 开一个礼盒，返回即将获得的奖励信息（不写存档）
---@param chestId string
---@return table|nil result { type, quality, item? } 或 { type, quality, propId, prop }
---@return string|nil errMsg
function LootBox.Roll(chestId)
    -- ── 道具箱 ──────────────────────────────────────────
    local propQuality = PROP_BOX_QUALITY[chestId]
    if propQuality then
        BuildPropPools()
        local pool = propPoolCache[propQuality]
        if not pool or #pool == 0 then
            return nil, "道具池为空: " .. propQuality
        end
        local prop = pool[math.random(#pool)]
        if not prop then return nil, "道具抽取失败" end
        return {
            type    = "prop",
            quality = propQuality,
            propId  = prop.id,
            prop    = prop,
        }
    end

    -- ── 藏品箱 ──────────────────────────────────────────
    local tierDef = CHEST_TIERS[chestId]
    if not tierDef then return nil, "未知礼盒 " .. chestId end

    BuildItemPools()

    local quality = WeightedRandomTier(tierDef)

    local pool
    if quality == "red_ex" then
        pool = redExclusiveCache
        quality = "red"
    else
        pool = itemPoolCache[quality]
    end

    if not pool or #pool == 0 then
        return nil, "藏品池为空: " .. quality
    end

    local item = WeightedRandomFromPool(pool)
    if not item then return nil, "抽取失败" end

    return {
        type    = "collectible",
        item    = item,
        quality = quality,
    }
end

--- 消耗礼盒并发放奖励（写存档）
---@param chestId string
---@param result table  由 Roll() 返回
---@return string  "ok" | "overflow"  藏品是否因仓库满转入邮件
function LootBox.Commit(chestId, result)
    SaveSystem.AddProp(chestId, -1)
    if result.type == "prop" then
        -- 道具箱：发放道具
        SaveSystem.AddProp(result.propId, 1)
        SaveFramework.SaveNow("open_prop_box_" .. chestId)
        print(string.format("[LootBox] PropBox %s → %s (%s)",
            chestId, result.propId, result.quality))
        return "ok"
    else
        -- 藏品箱：检查仓库空间
        local item = result.item
        if SaveSystem.CanAddItemToWarehouse(item) then
            -- 放得下：直接写入仓库
            SaveSystem.AddWonItems({ item })
            SaveFramework.SaveNow("open_chest_" .. chestId)
            print(string.format("[LootBox] Opened %s → %s (%s, value=%d)",
                chestId, item.name, result.quality, item.baseValue))
            return "ok"
        else
            -- 放不下：转入溢出邮件
            SaveSystem.AddOverflowMailItem(item)
            SaveFramework.SaveNow("open_chest_overflow_" .. chestId)
            print(string.format("[LootBox] Overflow %s → %s (%s) → mail",
                chestId, item.name, result.quality))
            return "overflow"
        end
    end
end

--- 检查是否有库存
---@param chestId string
---@return boolean
function LootBox.HasStock(chestId)
    return SaveSystem.GetPropCount(chestId) > 0
end

return LootBox
