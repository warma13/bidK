-- ============================================================================
-- PropSystem.lua - 竞拍道具系统
-- ============================================================================
-- 职责：
--   1. 道具背包管理（购买/使用/查询库存）
--   2. 道具效果计算（根据仓库数据生成信息文本）
--   3. 对局内道具使用（SEALED_BID 阶段，每局每道具限用一次）
-- ============================================================================

local Config = require("Config")
local Props = require("Config.Props")
local SaveSystem = require("SaveSystem")

local PropSystem = {}

-- 对局内已使用的道具 id 集合（每局重置）
local usedThisGame = {}

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
end

--- 本局是否已使用过该道具
---@param propId string
---@return boolean
function PropSystem.IsUsedThisGame(propId)
    return usedThisGame[propId] == true
end

--- 使用道具（对局中调用），返回生成的信息文本和 reveals
---@param propId string
---@param warehouseItems table 当前仓库的藏品列表
---@return boolean success
---@return table|nil info  { text=string, reveals=table|nil }
---@return string|nil errMsg
function PropSystem.Use(propId, warehouseItems)
    local def = Props.BY_ID[propId]
    if not def then return false, nil, "道具不存在" end

    if usedThisGame[propId] then
        return false, nil, "本局已使用过"
    end

    local cur = PropSystem.GetCount(propId)
    if cur <= 0 then
        return false, nil, "库存不足"
    end

    -- 计算效果
    local info = PropSystem.ComputeEffect(def, warehouseItems)
    if not info then
        return false, nil, "计算效果失败"
    end

    -- 扣减库存并标记已使用
    SaveSystem.AddProp(propId, -1)
    SaveSystem.Save()
    usedThisGame[propId] = true

    print("[PropSystem] Used " .. def.name .. ": " .. info.text)
    return true, info
end

-- ============================================================================
-- 效果计算
-- ============================================================================

--- 根据道具定义和仓库藏品计算效果
---@param def table 道具定义（来自 Props.LIST）
---@param warehouseItems table 仓库藏品列表
---@return table|nil info { text=string, reveals=table|nil }
function PropSystem.ComputeEffect(def, warehouseItems)
    local etype = def.effectType
    local params = def.effectParams

    if etype == Props.EFFECT.SHOW_RARITY_CELL_COUNT then
        return PropSystem._EffectRarityCellCount(params, warehouseItems)
    elseif etype == Props.EFFECT.SHOW_RARITY_ITEM_COUNT then
        return PropSystem._EffectRarityItemCount(params, warehouseItems)
    elseif etype == Props.EFFECT.SHOW_RANDOM_SILHOUETTE then
        return PropSystem._EffectRandomSilhouette(params, warehouseItems)
    elseif etype == Props.EFFECT.SHOW_SIZE_AVG_VALUE then
        return PropSystem._EffectSizeAvgValue(params, warehouseItems)
    end

    return nil
end

--- 显示指定品质藏品的总格数
function PropSystem._EffectRarityCellCount(params, warehouseItems)
    local rarSet = {}
    local rarNames = {}
    for _, r in ipairs(params.rarities) do
        rarSet[r] = true
        local rar = Config.GetRarity(r)
        rarNames[#rarNames + 1] = rar.name
    end

    local totalCells = 0
    for _, item in ipairs(warehouseItems) do
        if rarSet[item.rarity] then
            local cells = (item.w or 1) * (item.h or 1)
            totalCells = totalCells + cells
        end
    end

    local qualityStr = table.concat(rarNames, "和")
    local text = qualityStr .. "品质藏品共占 " .. totalCells .. " 格"
    return { text = text, icon = "" }
end

--- 显示指定品质藏品的总数量
function PropSystem._EffectRarityItemCount(params, warehouseItems)
    local rarSet = {}
    local rarNames = {}
    for _, r in ipairs(params.rarities) do
        rarSet[r] = true
        local rar = Config.GetRarity(r)
        rarNames[#rarNames + 1] = rar.name
    end

    local count = 0
    for _, item in ipairs(warehouseItems) do
        if rarSet[item.rarity] then
            count = count + 1
        end
    end

    local qualityStr = table.concat(rarNames, "和")
    local text = qualityStr .. "品质藏品共有 " .. count .. " 件"
    return { text = text, icon = "" }
end

--- 随机显示N件藏品轮廓
function PropSystem._EffectRandomSilhouette(params, warehouseItems)
    local n = params.count or 4
    -- 随机选择 n 件
    local candidates = {}
    for _, item in ipairs(warehouseItems) do
        candidates[#candidates + 1] = item
    end
    -- Fisher-Yates 洗牌
    for i = #candidates, 2, -1 do
        local j = math.random(1, i)
        candidates[i], candidates[j] = candidates[j], candidates[i]
    end

    local selected = {}
    local reveals = {}
    for i = 1, math.min(n, #candidates) do
        selected[#selected + 1] = candidates[i]
        if candidates[i].idx then
            reveals[#reveals + 1] = { itemIdx = candidates[i].idx, targetLevel = 1 }
        end
    end

    local text = "透视了 " .. #selected .. " 件藏品的轮廓"
    return { text = text, icon = "", reveals = reveals }
end

--- 显示占位N格藏品的平均价值
function PropSystem._EffectSizeAvgValue(params, warehouseItems)
    local targetCells = params.cellCount or 4
    local totalValue = 0
    local count = 0

    for _, item in ipairs(warehouseItems) do
        local cells = (item.w or 1) * (item.h or 1)
        if cells >= targetCells then
            local val = item.realValue or Config.GetItemRealValue(item)
            totalValue = totalValue + val
            count = count + 1
        end
    end

    local avgValue = 0
    if count > 0 then
        avgValue = math.floor(totalValue / count)
    end

    local function formatVal(v)
        if v >= 10000 then
            return string.format("%.1f万", v / 10000)
        end
        return tostring(math.floor(v))
    end

    local text = "占位≥" .. targetCells .. "格的藏品共 " .. count .. " 件，平均价值 " .. formatVal(avgValue)
    return { text = text, icon = "" }
end

return PropSystem
