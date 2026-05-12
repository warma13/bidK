-- ============================================================================
-- GameLoop.lua - 扁平线性帧更新调度器
--
-- 职责：
--   1. 心跳诊断（每秒打印一次，确认引擎存活）
--   2. 三层 Update 调度：always → screen → in-game
--   3. pcall 隔离：每个模块独立保护，单模块崩溃不影响其他
--
-- 设计原则：
--   - 不持有任何游戏状态
--   - 不做业务决策（哪些面板更新由 GameController 自己管理）
--   - 只负责"按顺序、安全地调用各模块的 Update"
-- ============================================================================

local AppPhase = require("AppPhase")

local GameLoop = {}

-- ============================================================================
-- pcall 保护工具
-- ============================================================================

--- 安全调用，捕获异常并打印，不中断后续模块
---@param label string
---@param fn function
---@return boolean ok
local function SafeCall(label, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then
        print("[GameLoop-ERROR] " .. label .. ": " .. tostring(err))
    end
    return ok
end



-- ============================================================================
-- 模块注册表
-- ============================================================================

-- always: 无论在什么屏幕都需要每帧运行的模块
-- 格式: { label = string, update = function(dt) }
local alwaysModules = {}

-- screen: 特定屏幕的更新函数（按 UIState.currentScreen 分发）
-- 格式: { [screenName] = { { label, update } } }
local screenModules = {}

-- inGame: 仅在 AppPhase.IN_GAME 时运行的模块
-- 格式: { label = string, update = function(dt) }
local inGameModules = {}

--- 注册"始终运行"的模块
---@param label string
---@param updateFn function
function GameLoop.RegisterAlways(label, updateFn)
    alwaysModules[#alwaysModules + 1] = { label = label, update = updateFn }
end

--- 注册特定屏幕的更新模块
---@param screenName string
---@param label string
---@param updateFn function
function GameLoop.RegisterScreen(screenName, label, updateFn)
    if not screenModules[screenName] then
        screenModules[screenName] = {}
    end
    local list = screenModules[screenName]
    list[#list + 1] = { label = label, update = updateFn }
end

--- 注册"仅对局中"的模块
---@param label string
---@param updateFn function
function GameLoop.RegisterInGame(label, updateFn)
    inGameModules[#inGameModules + 1] = { label = label, update = updateFn }
end

-- ============================================================================
-- 主 Update
-- ============================================================================

---@param dt number
function GameLoop.Update(dt)
    -- 1) always 层：所有界面都需运行的模块
    for i = 1, #alwaysModules do
        local m = alwaysModules[i]
        SafeCall(m.label, m.update, dt)
    end

    -- 2) screen 层：按当前屏幕分发
    local UIState = require("UI.UIState")
    local screenName = UIState.currentScreen
    local screenList = screenModules[screenName]
    if screenList then
        for i = 1, #screenList do
            local m = screenList[i]
            SafeCall(m.label, m.update, dt)
        end
    end

    -- 3) in-game 层：仅对局中
    if AppPhase.IsInGame() then
        for i = 1, #inGameModules do
            local m = inGameModules[i]
            SafeCall(m.label, m.update, dt)
        end
    end
end

return GameLoop
