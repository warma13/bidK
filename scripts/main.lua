-- ============================================================================
-- main.lua - 拍卖之王 入口文件（模式分发）
-- ============================================================================
-- 根据运行模式加载对应模块：
--   服务端模式 → network/Server.lua
--   客户端模式 → network/Client.lua
--   单机模式   → network/Standalone.lua
-- ============================================================================

---@type { Start: fun(), Stop: fun()?, HandleUpdate: fun(eventType: string, eventData: UpdateEventData)? }
local Module

function Start()
    if IsServerMode() then
        Module = require("network.Server")
        print("[main] Running in SERVER mode")
    elseif IsNetworkMode() then
        Module = require("network.Client")
        print("[main] Running in CLIENT mode")
    else
        Module = require("network.Standalone")
        print("[main] Running in STANDALONE mode")
    end

    Module.Start()

    -- 注册帧更新
    SubscribeToEvent("Update", "HandleUpdate")
end

function Stop()
    if Module and Module.Stop then
        Module.Stop()
    end
end

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    if Module and Module.HandleUpdate then
        Module.HandleUpdate(eventType, eventData)
    end
end
