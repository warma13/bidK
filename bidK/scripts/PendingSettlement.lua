-- ============================================================================
-- PendingSettlement.lua - 对局结算挂起保障
-- ============================================================================
-- 防止玩家结算后杀进程导致物品丢失的兜底机制：
--   1. SettleWarehouseValue 后立刻 DirectSave 物品列表到云端
--   2. 玩家回收物品时同步更新云端数据
--   3. 玩家正常返回大厅时清除云端挂起数据
--   4. 下次登录时检测残留数据，自动走回收入库流程
-- ============================================================================

local SaveFramework = require("SaveFramework")

local PendingSettlement = {}

-- ============================================================================
-- 常量
-- ============================================================================

local MODULE_NAME = "pending_settlement"
local CLOUD_KEY   = "pending_stl"       -- 云端 key（简短节省空间）

-- ============================================================================
-- 内部状态
-- ============================================================================

---@type table|nil  挂起的结算数据（登录时从云端加载）
local pendingData = nil

-- ============================================================================
-- SaveFramework 注册（启动时加载挂起数据）
-- ============================================================================

SaveFramework.Register(MODULE_NAME, {
    cloudKeys = { CLOUD_KEY },

    load = function(values)
        local raw = values[CLOUD_KEY]
        if not raw then
            pendingData = nil
            print("[PendingSettlement] No pending data in cloud")
            return
        end
        -- raw 可能是 table 或 json string
        if type(raw) == "string" then
            if #raw == 0 then
                pendingData = nil
                return
            end
            local ok, parsed = pcall(cjson.decode, raw)
            if ok and type(parsed) == "table" then
                pendingData = parsed
            else
                print("[PendingSettlement] Failed to decode pending data")
                pendingData = nil
                return
            end
        elseif type(raw) == "table" then
            pendingData = raw
        else
            pendingData = nil
            return
        end
        -- 校验基本结构
        if not pendingData.items or type(pendingData.items) ~= "table" then
            print("[PendingSettlement] Invalid pending data (no items)")
            pendingData = nil
            return
        end
        print("[PendingSettlement] Loaded pending data: " .. #pendingData.items
            .. " items, recycled=" .. (pendingData.recycledCount or 0))
    end,

    save = function(batch)
        -- 框架统一保存时：如果有挂起数据就写入，没有就清空
        if pendingData then
            local ok, json = pcall(cjson.encode, pendingData)
            if ok then
                batch:Set(CLOUD_KEY, json)
            end
        else
            batch:Set(CLOUD_KEY, "")
        end
    end,

    defaults = function()
        pendingData = nil
        print("[PendingSettlement] Defaults applied (no pending)")
    end,
})

-- ============================================================================
-- 核心 API
-- ============================================================================

--- 对局结算后立即保存物品列表到云端（使用 DirectSave 绕过对局暂停）
---@param lootItems table[] 仓库中的物品列表
---@param settlementInfo table { winner, winnerPaid, warehouseName, profit }
function PendingSettlement.Save(lootItems, settlementInfo)
    -- 序列化物品（只保留关键字段，节省空间）
    local items = {}
    for _, item in ipairs(lootItems) do
        items[#items + 1] = {
            n = item.name,
            r = item.rarity,
            w = item.w or 1,
            h = item.h or 1,
            v = item.realValue or item.baseValue or item.value or 0,
            c = item.category or "",
            i = item.image or "",
            d = item.desc or "",
        }
    end

    pendingData = {
        items = items,
        recycledIndexes = {},   -- 已回收物品的索引集合
        recycledCount = 0,
        recycledTotal = 0,      -- 已回收金额（仅记录，不重复发放）
        timestamp = os.time(),
        winner = settlementInfo.winner or 0,
        winnerPaid = settlementInfo.winnerPaid or 0,
        warehouseName = settlementInfo.warehouseName or "",
    }

    local ok, json = pcall(cjson.encode, pendingData)
    if not ok then
        print("[PendingSettlement] Encode failed: " .. tostring(json))
        return
    end

    -- DirectSave 绕过 PauseForGame
    SaveFramework.DirectSave("pending_stl_save", function(batch)
        batch:Set(CLOUD_KEY, json)
    end, {
        silent = true, -- 对局中自动保存，不提示用户
        ok = function()
            print("[PendingSettlement] Saved " .. #items .. " items to cloud")
        end,
        error = function(code, reason)
            print("[PendingSettlement] Save FAILED: " .. tostring(reason))
        end,
    })
end

--- 玩家回收物品时更新挂起数据
---@param recycledItems table[] 本次回收的物品（原始引用）
---@param lootItems table[] 完整的战利品列表（用于索引匹配）
---@param recycledValue number 本次回收的金额
function PendingSettlement.UpdateRecycled(recycledItems, lootItems, recycledValue)
    if not pendingData then return end

    -- 通过 lootItems 定位回收物品在 pendingData.items 中的索引
    -- recycledItems 是对 lootItems 中对象的引用，找出在 lootItems 中的位置
    local recycledSet = {}
    for _, item in ipairs(recycledItems) do
        recycledSet[item] = true
    end

    for idx, item in ipairs(lootItems) do
        if recycledSet[item] and not pendingData.recycledIndexes[tostring(idx)] then
            pendingData.recycledIndexes[tostring(idx)] = true
            pendingData.recycledCount = (pendingData.recycledCount or 0) + 1
        end
    end
    pendingData.recycledTotal = (pendingData.recycledTotal or 0) + recycledValue

    -- DirectSave 更新云端
    local ok, json = pcall(cjson.encode, pendingData)
    if not ok then
        print("[PendingSettlement] UpdateRecycled encode failed")
        return
    end

    SaveFramework.DirectSave("pending_stl_recycle", function(batch)
        batch:Set(CLOUD_KEY, json)
    end, {
        silent = true, -- 对局中自动保存，不提示用户
        ok = function()
            print("[PendingSettlement] Updated recycled: count=" .. pendingData.recycledCount
                .. " total=" .. pendingData.recycledTotal)
        end,
        error = function(code, reason)
            print("[PendingSettlement] UpdateRecycled FAILED: " .. tostring(reason))
        end,
    })
end

--- 正常返回大厅时清除挂起数据
function PendingSettlement.Clear()
    pendingData = nil

    -- DirectSave 清空云端（写空字符串）
    SaveFramework.DirectSave("pending_stl_clear", function(batch)
        batch:Set(CLOUD_KEY, "")
    end, {
        silent = true, -- 返回大厅清理，不提示用户
        ok = function()
            print("[PendingSettlement] Cleared pending data from cloud")
        end,
        error = function(code, reason)
            print("[PendingSettlement] Clear FAILED: " .. tostring(reason))
            -- 标记脏数据，框架恢复后会重试
            SaveFramework.MarkDirty(MODULE_NAME)
        end,
    })
end

--- 是否有挂起的结算数据
---@return boolean
function PendingSettlement.HasPending()
    return pendingData ~= nil and pendingData.items ~= nil and #pendingData.items > 0
end

--- 获取挂起数据摘要（用于 UI 展示）
---@return table|nil { totalItems, unrecycledCount, unrecycledValue, warehouseName, timestamp }
function PendingSettlement.GetSummary()
    if not PendingSettlement.HasPending() then return nil end

    local total = #pendingData.items
    local unrecycledCount = 0
    local unrecycledValue = 0

    for idx, item in ipairs(pendingData.items) do
        if not pendingData.recycledIndexes[tostring(idx)] then
            unrecycledCount = unrecycledCount + 1
            unrecycledValue = unrecycledValue + (item.v or 0)
        end
    end

    return {
        totalItems = total,
        unrecycledCount = unrecycledCount,
        unrecycledValue = unrecycledValue,
        warehouseName = pendingData.warehouseName or "",
        timestamp = pendingData.timestamp or 0,
    }
end

--- 自动回收：将所有未回收的物品走入库 + 自动回收流程
--- 返回回收结果信息供 UI 展示
---@return table { placed: number, recycledCount: number, recycledValue: number }
function PendingSettlement.AutoRecover()
    if not PendingSettlement.HasPending() then
        return { placed = 0, recycledCount = 0, recycledValue = 0 }
    end

    local SaveSystem = require("SaveSystem")
    local WarehouseGrid = require("WarehouseGrid")
    local RecycleManager = require("RecycleManager")
    local GameState = require("GameState")

    -- 收集未回收的物品（还原为完整格式）
    local remaining = {}
    for idx, item in ipairs(pendingData.items) do
        if not pendingData.recycledIndexes[tostring(idx)] then
            remaining[#remaining + 1] = {
                name = item.n or "",
                rarity = item.r or "white",
                w = item.w or 1,
                h = item.h or 1,
                baseValue = item.v or 0,
                realValue = item.v or 0,
                category = item.c or "",
                image = item.i or "",
                desc = item.d or "",
            }
        end
    end

    if #remaining == 0 then
        -- 所有物品已在上次被回收，只需清除挂起数据
        PendingSettlement.Clear()
        return { placed = 0, recycledCount = 0, recycledValue = 0 }
    end

    -- 创建仓库网格
    local capacity = SaveSystem.GetWarehouseCapacity()
    local gridInst = WarehouseGrid.Create(capacity)
    local existingItems = SaveSystem.GetItems()
    WarehouseGrid.Rebuild(gridInst, existingItems)

    -- 自动回收适配
    local placed, autoRecycled, autoRecycledValue =
        RecycleManager.AutoRecycleForFit(remaining, WarehouseGrid, gridInst)

    -- 自动回收的物品变现（直接加到云端金币）
    if autoRecycledValue > 0 then
        -- 使用 MoneyManager 的菜单上下文加钱（非对局状态）
        local MoneyManager = require("MoneyManager")
        MoneyManager.AddMoneyFromMenu(autoRecycledValue, "auto_recover_recycle")
    end

    -- 放入仓库的物品保存到存档
    if #placed > 0 then
        SaveSystem.AddWonItems(placed)
    end

    -- 保存存档
    SaveSystem.SaveNow()

    local result = {
        placed = #placed,
        recycledCount = #autoRecycled,
        recycledValue = autoRecycledValue,
    }

    print("[PendingSettlement] AutoRecover: placed=" .. result.placed
        .. " recycled=" .. result.recycledCount
        .. " value=" .. result.recycledValue)

    -- 清除挂起数据
    PendingSettlement.Clear()

    return result
end

return PendingSettlement
