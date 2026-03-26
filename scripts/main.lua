-- ============================================================================
-- main.lua - 拍卖之王 入口文件
-- ============================================================================

local Module = require("network.Standalone")

function Start()
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
