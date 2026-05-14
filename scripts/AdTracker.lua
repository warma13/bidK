-- ============================================================================
-- AdTracker.lua - 广告观看事件总线
-- 职责：维护当日/累计观看计数，通知所有已注册的 hook
--
-- 设计原则：
--   - AdTracker 不做云端持久化，仅维护运行时内存计数
--   - 各业务模块（AdCardPanel 等）自行管理云端同步
--   - hook 通过 RegisterHook 注册，Record() 时统一触发
--   - hook 内的崩溃被 pcall 捕获并打印，不影响其他 hook
-- ============================================================================

---@diagnostic disable: undefined-global

local AdTracker = {}

-- ============================================================================
-- 内部状态
-- ============================================================================
local hooks = {}            ---@type table<string, fun(todayCount:integer, totalCount:integer)>
local todayCount = 0
local totalCount = 0
local lastDate   = ""

local function TodayStr()
    return os.date("%Y-%m-%d")
end

local function CheckDailyReset()
    local today = TodayStr()
    if lastDate ~= today then
        todayCount = 0
        lastDate   = today
    end
end

-- ============================================================================
-- Hook 管理
-- ============================================================================

--- 注册一个 hook，在每次 Record() 时被调用
--- hook 签名：function(todayCount, totalCount)
---@param name string   唯一名称，重复注册会覆盖
---@param fn   fun(todayCount:integer, totalCount:integer)
function AdTracker.RegisterHook(name, fn)
    hooks[name] = fn
    print("[AdTracker] Hook registered: " .. name)
end

--- 移除一个 hook
---@param name string
function AdTracker.UnregisterHook(name)
    hooks[name] = nil
end

-- ============================================================================
-- 记录一次广告观看（成功）
-- ============================================================================

function AdTracker.Record()
    CheckDailyReset()
    todayCount = todayCount + 1
    totalCount = totalCount + 1

    print("[AdTracker] Record: today=" .. todayCount .. " total=" .. totalCount)

    for name, fn in pairs(hooks) do
        local ok, err = pcall(fn, todayCount, totalCount)
        if not ok then
            print("[AdTracker] Hook '" .. name .. "' error: " .. tostring(err))
        end
    end
end

-- ============================================================================
-- 查询接口（供 hook 实现方按需使用）
-- ============================================================================

---@return integer
function AdTracker.GetTodayCount()  return todayCount end

---@return integer
function AdTracker.GetTotalCount()  return totalCount end

return AdTracker
