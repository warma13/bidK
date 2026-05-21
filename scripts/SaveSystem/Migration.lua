-- ============================================================================
-- SaveSystem/Migration.lua - 存档版本迁移
-- ============================================================================

local Migration = {}

local CURRENT_VERSION = 3  -- 与 SaveSystem.lua 保持同步

local MIGRATIONS = {
    -- v1 → v2: 用当前物品池价格更新已保存物品的 baseValue
    [1] = function(data)
        local pools = {
            require("Config.Warehouses.ItemPool"),
            require("Config.Warehouses.QuantumLab"),
            require("Config.Warehouses.BondedPort"),
            require("Config.Warehouses.DataCenter"),
        }
        local priceMap = {}
        for _, pool in ipairs(pools) do
            if pool.categories then
                for _, cat in ipairs(pool.categories) do
                    if cat.items then
                        for _, item in ipairs(cat.items) do
                            if item.name and item.value then
                                priceMap[item.name] = item.value
                            end
                        end
                    end
                end
            end
        end
        local updated = 0
        if data.items then
            for _, item in ipairs(data.items) do
                local newPrice = priceMap[item.name]
                if newPrice and newPrice ~= item.baseValue then
                    item.baseValue = newPrice
                    updated = updated + 1
                end
            end
        end
        print("[SaveSystem] Migration v1→v2: updated " .. updated .. " item prices")
    end,

    -- v2 → v3: 将旧 port_1000w / port_5000w 门票兑换为深海打捞站 + 文化艺术区指定门票
    -- 兑换比例：旧门票总张数 n，各发 n×5 张新门票
    [2] = function(data)
        data.tickets = data.tickets or {}
        local old1000w = data.tickets["port_1000w"] or 0
        local old5000w = data.tickets["port_5000w"] or 0
        local n = old1000w + old5000w
        if n > 0 then
            local reward = n * 5
            data.tickets["ticket_deepsea"]  = (data.tickets["ticket_deepsea"]  or 0) + reward
            data.tickets["ticket_culture"]  = (data.tickets["ticket_culture"]  or 0) + reward
            data.tickets["port_1000w"] = nil
            data.tickets["port_5000w"] = nil
            print("[SaveSystem] Migration v2→v3: 旧门票 " .. n .. " 张 → 深海/文化各 " .. reward .. " 张")
        else
            print("[SaveSystem] Migration v2→v3: 无旧门票，跳过")
        end
    end,
}

--- 执行版本迁移，直到 data.version 达到 CURRENT_VERSION
---@param data table  存档数据（就地修改）
function Migration.Run(data)
    while data.version < CURRENT_VERSION do
        local fn = MIGRATIONS[data.version]
        if fn then
            fn(data)
            data.version = data.version + 1
            print("[SaveSystem] Migrated to v" .. data.version)
        else
            break
        end
    end
end

return Migration
