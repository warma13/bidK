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
        -- pcall 保护：防止模块内部崩溃传播到引擎事件系统
        -- 引擎在收到 Lua 错误时会取消订阅该 handler，导致游戏永久卡死
        local ok, err = pcall(Module.HandleUpdate, eventType, eventData)
        if not ok then
            print("[FATAL] HandleUpdate error: " .. tostring(err))
        end
    end
end
