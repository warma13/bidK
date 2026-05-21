-- ============================================================================
-- PropSystem.lua - 竞拍道具系统
-- ============================================================================
-- 职责：
--   1. 道具背包管理（购买/使用/查询库存）
--   2. 效果调度（委托 PropEffects.lua 处理具体逻辑）
--   3. 对局内道具使用（SEALED_BID 阶段，每轮限用一次）
-- ============================================================================

local Props = require("Config.Props")
local SaveSystem = require("SaveSystem")
local SaveFramework = require("SaveFramework")
local FX = require("PropEffects")   -- 效果计算模块

local PropSystem = {}

-- 对局内已使用的道具 id 集合（每局重置）
local usedThisGame = {}
-- 当前轮已使用过道具（每轮重置，限制每轮只用一次）
local usedThisRound = false

-- ============================================================================
-- 背包操作
-- ============================================================================

--- 获取某道具的库存数量
---@param propId string
---@return number
function PropSystem.GetCount(propId)
    return SaveSystem.GetPropCount(propId)
end

--- 购买道具（扣金币）
---@param propId string
---@param deductGoldFn fun(amount: number): boolean 扣金币回调，返回是否成功
---@return boolean success
---@return string|nil errMsg
function PropSystem.Buy(propId, deductGoldFn)
    local def = Props.BY_ID[propId]
    if not def then return false, "道具不存在" end

    local cur = PropSystem.GetCount(propId)
    if cur >= def.maxStack then return false, "已达上限" end

    if not deductGoldFn(def.price) then
        return false, "金币不足"
    end

    SaveSystem.AddProp(propId, 1)
    SaveSystem.Save()
    print("[PropSystem] Bought " .. def.name .. ", now have " .. PropSystem.GetCount(propId))
    return true
end

-- ============================================================================
-- 对局道具使用
-- ============================================================================

--- 对局开始时重置已使用记录
function PropSystem.ResetGameUsage()
    usedThisGame = {}
    usedThisRound = false
end

--- 每轮开始时重置本轮道具限制
function PropSystem.ResetRoundUsage()
    usedThisRound = false
end

--- 本轮是否已使用过道具（每轮只能用一次）
---@return boolean
function PropSystem.IsUsedThisRound()
    return usedThisRound == true
end

--- 本局是否已使用过该道具
---@param propId string
---@return boolean
function PropSystem.IsUsedThisGame(propId)
    return usedThisGame[propId] == true
end

--- 使用道具（对局中调用）
---@param propId string
---@param warehouseItems table 当前仓库的藏品列表
---@return boolean success
---@return table|nil info  { text, reveals?, type?, sampleAvgValue? }
---@return string|nil errMsg
function PropSystem.Use(propId, warehouseItems)
    local def = Props.BY_ID[propId]
    if not def then return false, nil, "道具不存在" end

    if usedThisRound then
        return false, nil, "本轮已使用过道具"
    end

    local cur = PropSystem.GetCount(propId)
    if cur <= 0 then
        return false, nil, "库存不足"
    end

    local info = PropSystem.ComputeEffect(def, warehouseItems)
    if not info then
        return false, nil, "计算效果失败"
    end

    SaveSystem.AddProp(propId, -1)
    SaveFramework.SaveNow("use_prop_" .. propId)
    usedThisRound = true
    usedThisGame[propId] = true

    info.propName      = def.name
    info.propIconImage = def.iconImage
    info.propTier      = def.tier

    print("[PropSystem] Used " .. def.name .. ": " .. info.text)
    return true, info
end

--- 给 AI 虚拟"使用"道具（不消耗背包，只记录当轮已用）
---@param propId string
---@param warehouseItems table
---@return boolean success
---@return table|nil info
---@return string|nil errMsg
function PropSystem.UseForAI(propId, warehouseItems)
    local def = Props.BY_ID[propId]
    if not def then return false, nil, "道具不存在" end
    local info = PropSystem.ComputeEffect(def, warehouseItems)
    if not info then return false, nil, "计算效果失败" end
    print("[PropSystem] AI Used " .. def.name .. ": " .. info.text)
    return true, info
end

-- ============================================================================
-- 效果调度（具体实现见 PropEffects.lua）
-- ============================================================================

local E = Props.EFFECT

--- 根据道具定义和仓库藏品计算效果
---@param def table 道具定义（来自 Props.LIST）
---@param warehouseItems table 仓库藏品列表
---@return table|nil info { text, icon, reveals?, type?, sampleAvgValue? }
function PropSystem.ComputeEffect(def, warehouseItems)
    local t = def.effectType
    local p = def.effectParams

    if     t == E.SHOW_RARITY_CELL_COUNT       then return FX.RarityCellCount(p, warehouseItems)
    elseif t == E.SHOW_RARITY_ITEM_COUNT        then return FX.RarityItemCount(p, warehouseItems)
    elseif t == E.SHOW_RANDOM_SILHOUETTE        then return FX.RandomSilhouette(p, warehouseItems)
    elseif t == E.SHOW_SIZE_AVG_VALUE           then return FX.SizeAvgValue(p, warehouseItems)
    elseif t == E.SHOW_RANDOM_ITEM_INFO         then return FX.RandomItemInfo(p, warehouseItems)
    elseif t == E.SHOW_RARITY_AVG_VALUE         then return FX.RarityAvgValue(p, warehouseItems)
    elseif t == E.SHOW_RARITY_AVG_CELL_COUNT    then return FX.RarityAvgCellCount(p, warehouseItems)
    elseif t == E.SHOW_RANDOM_ITEM_INFO_MULTI   then return FX.RandomItemInfoMulti(p, warehouseItems)
    elseif t == E.SHOW_TOP_RARITY_SILHOUETTE    then return FX.TopRaritySilhouette(p, warehouseItems)
    elseif t == E.SHOW_LARGEST_ITEM_SILHOUETTE  then return FX.LargestItemSilhouette(p, warehouseItems)
    elseif t == E.SHOW_CATEGORY_SILHOUETTE      then return FX.CategorySilhouette(p, warehouseItems)
    -- 紫色高阶
    elseif t == E.SHOW_TOTAL_ITEM_COUNT         then return FX.TotalItemCount(p, warehouseItems)
    elseif t == E.SHOW_RANDOM_QUALITY_MULTI     then return FX.RandomQualityMulti(p, warehouseItems)
    elseif t == E.SHOW_LARGEST_ITEM_INFO        then return FX.LargestItemInfo(p, warehouseItems)
    elseif t == E.SHOW_TOP_RARITY_ITEM_VALUE    then return FX.TopRarityItemValue(p, warehouseItems)
    -- 金色高阶
    elseif t == E.SHOW_TOTAL_CELL_COUNT         then return FX.TotalCellCount(p, warehouseItems)
    elseif t == E.SHOW_RED_ITEM_SILHOUETTE      then return FX.RedItemSilhouette(p, warehouseItems)
    elseif t == E.SHOW_TOP_N_LARGEST_INFO       then return FX.TopNLargestInfo(p, warehouseItems)
    elseif t == E.SHOW_TOP_RARITY_FULL_INFO     then return FX.TopRarityFullInfo(p, warehouseItems)
    end

    return nil
end

return PropSystem
