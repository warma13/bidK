-- ============================================================================
-- AntiCheat.lua - 反作弊模块
-- 提供数值混淆、状态校验、行为监控三大能力，供其它模块调用
-- ============================================================================

local AntiCheat = {}

-- ============================================================================
-- 1. SecureValue — 数值混淆存储
--    用 XOR + 随机 salt 混淆，防止内存扫描和直接篡改
-- ============================================================================

local CHECKSUM_MAGIC = 0x5A3C7E1D

--- 生成随机 salt（正整数）
local function randomSalt()
    return math.random(100000, 999999999)
end

--- 计算校验值
---@param encoded integer
---@param salt integer
---@return integer
local function calcCheck(encoded, salt)
    return (encoded + salt) ~ CHECKSUM_MAGIC
end

--- 创建受保护的数值对象
---@param initialValue number
---@return table SecureValue { get, set, add }
function AntiCheat.SecureValue(initialValue)
    initialValue = initialValue or 0
    local salt = randomSalt()
    local intVal = math.floor(initialValue)
    local encoded = intVal ~ salt
    local check = calcCheck(encoded, salt)

    local sv = {}

    --- 读取值（自动校验，篡改返回 0）
    ---@return number
    function sv.get()
        local expected = calcCheck(encoded, salt)
        if check ~= expected then
            print("[AntiCheat] WARNING: SecureValue tampered! Resetting to 0.")
            -- 被篡改，重置
            salt = randomSalt()
            encoded = 0 ~ salt
            check = calcCheck(encoded, salt)
            return 0
        end
        return encoded ~ salt
    end

    --- 写入新值（重新生成 salt 和校验）
    ---@param newValue number
    function sv.set(newValue)
        salt = randomSalt()
        local intV = math.floor(newValue)
        encoded = intV ~ salt
        check = calcCheck(encoded, salt)
    end

    --- 增减值（便捷方法）
    ---@param delta number
    function sv.add(delta)
        local cur = sv.get()
        sv.set(cur + delta)
    end

    return sv
end

-- ============================================================================
-- 2. snapshot / verify — 状态快照完整性校验
--    在关键时刻记录数据指纹，之后验证是否被篡改
-- ============================================================================

local snapshots = {}

--- 对 table 计算简单哈希指纹
---@param t table
---@return integer
local function hashTable(t)
    local h = 0x811C9DC5  -- FNV offset basis
    for k, v in pairs(t) do
        local kh = 0
        if type(k) == "number" then
            kh = math.floor(k)
        elseif type(k) == "string" then
            for i = 1, #k do
                kh = ((kh << 5) + kh) + string.byte(k, i)
                kh = kh & 0x7FFFFFFF
            end
        end

        local vh = 0
        if type(v) == "number" then
            vh = math.floor(v)
        elseif type(v) == "boolean" then
            vh = v and 1 or 0
        elseif type(v) == "string" then
            for i = 1, #v do
                vh = ((vh << 5) + vh) + string.byte(v, i)
                vh = vh & 0x7FFFFFFF
            end
        elseif type(v) == "table" then
            vh = hashTable(v)
        end

        h = h ~ (kh * 16777619 + vh)
        h = h & 0x7FFFFFFF
    end
    return h
end

--- 记录数据快照
---@param key string 快照名称
---@param data table 要保护的数据
function AntiCheat.snapshot(key, data)
    snapshots[key] = hashTable(data)
end

--- 校验数据是否与快照一致
---@param key string 快照名称
---@param data table 当前数据
---@return boolean 一致返回 true
function AntiCheat.verify(key, data)
    local saved = snapshots[key]
    if not saved then
        return true  -- 无快照，跳过
    end
    local current = hashTable(data)
    if current ~= saved then
        print("[AntiCheat] WARNING: Data integrity check failed for '" .. key .. "'!")
        return false
    end
    return true
end

--- 清除快照
---@param key string|nil 为 nil 时清除全部
function AntiCheat.clearSnapshot(key)
    if key then
        snapshots[key] = nil
    else
        snapshots = {}
    end
end

-- ============================================================================
-- 3. recordBid / getReport — 行为监控
--    记录出价行为，检测异常模式
-- ============================================================================

local bidRecords = {}   -- { [playerIdx] = { { round, amount, money }, ... } }
local violations = {}   -- { [playerIdx] = { reason1, reason2, ... } }

--- 记录一次出价
---@param playerIdx integer
---@param round integer
---@param amount number
---@param money number 出价时持有资金
function AntiCheat.recordBid(playerIdx, round, amount, money)
    if not bidRecords[playerIdx] then
        bidRecords[playerIdx] = {}
        violations[playerIdx] = {}
    end

    local record = { round = round, amount = amount, money = money }
    bidRecords[playerIdx][#bidRecords[playerIdx] + 1] = record

    -- 检测异常
    if amount < 0 then
        violations[playerIdx][#violations[playerIdx] + 1] =
            "第" .. round .. "轮出价为负数(" .. amount .. ")"
    end

    if amount > money then
        violations[playerIdx][#violations[playerIdx] + 1] =
            "第" .. round .. "轮出价(" .. amount .. ")超过持有资金(" .. money .. ")"
    end

    -- 资金突增检测（与上一轮对比）
    local records = bidRecords[playerIdx]
    if #records >= 2 then
        local prev = records[#records - 1]
        local prevRemaining = prev.money - prev.amount
        -- 如果当前资金比上轮出价后剩余多出50%以上（排除利息等正常增长）
        if prevRemaining > 0 and money > prevRemaining * 1.5 then
            violations[playerIdx][#violations[playerIdx] + 1] =
                "第" .. round .. "轮资金异常增长(上轮剩余" .. math.floor(prevRemaining)
                .. ",本轮持有" .. math.floor(money) .. ")"
        end
    end
end

--- 获取玩家行为报告
---@param playerIdx integer
---@return table { suspicious: boolean, reasons: string[] }
function AntiCheat.getReport(playerIdx)
    local v = violations[playerIdx] or {}
    return {
        suspicious = #v > 0,
        reasons = v,
    }
end

--- 获取所有玩家的综合报告
---@return table { [playerIdx] = { suspicious, reasons } }
function AntiCheat.getAllReports()
    local reports = {}
    for idx, _ in pairs(bidRecords) do
        reports[idx] = AntiCheat.getReport(idx)
    end
    return reports
end

--- 重置所有记录（新游戏时调用）
function AntiCheat.reset()
    bidRecords = {}
    violations = {}
    snapshots = {}
end

return AntiCheat
