-- ============================================================================
-- MoneyLedger.lua - 金币交易审计账本
-- 记录每一笔金币变动的来源、金额、前后余额，支持异常检测和云端上报
-- ============================================================================

local MoneyLedger = {}

-- ============================================================================
-- 配置
-- ============================================================================

MoneyLedger.MAX_ENTRIES = 200           -- 环形缓冲区大小
MoneyLedger.ANOMALY_THRESHOLD = 1e12   -- 单笔超过1万亿视为异常
MoneyLedger.UPLOAD_INTERVAL = 60       -- 云端上报间隔(秒)

-- ============================================================================
-- 内部状态
-- ============================================================================

local state = {
    entries = {},           -- 交易记录（环形缓冲区）
    seq = 1,                -- 递增序号
    sessionStart = 0,       -- 会话开始余额
    cumulativeDelta = 0,    -- 会话内累计变动
    anomalies = {},         -- 检测到的异常列表
    lastUploadTime = 0,     -- 上次上传时间
    initialized = false,
}

-- ============================================================================
-- 初始化
-- ============================================================================

--- 初始化账本（每次进入游戏/菜单加载完金币后调用）
---@param initialBalance number 当前余额
function MoneyLedger.Init(initialBalance)
    state.sessionStart = initialBalance or 0
    state.cumulativeDelta = 0
    state.seq = 1
    state.entries = {}
    state.anomalies = {}
    state.lastUploadTime = os.time()
    state.initialized = true
    print("[MoneyLedger] Initialized with balance: " .. state.sessionStart)
end

-- ============================================================================
-- 核心：记录交易
-- ============================================================================

--- 记录一笔金币变动
---@param source string 来源标签（如 "entry_fee", "round_winner_pay"）
---@param delta number 变动金额（正=加钱，负=扣钱）
---@param before number 变动前余额
---@param after number 变动后余额
---@param context? string 可选上下文信息（如轮次号）
function MoneyLedger.Record(source, delta, before, after, context)
    if not state.initialized then return end

    local entry = {
        id = state.seq,
        ts = os.time(),
        source = source or "unknown",
        delta = delta,
        before = before,
        after = after,
        context = context,
    }
    state.seq = state.seq + 1
    state.cumulativeDelta = state.cumulativeDelta + delta

    -- 环形缓冲区
    state.entries[#state.entries + 1] = entry
    if #state.entries > MoneyLedger.MAX_ENTRIES then
        table.remove(state.entries, 1)
    end

    -- 异常检测
    local anomaly = MoneyLedger.CheckAnomaly(source, delta, before, after)
    if anomaly then
        state.anomalies[#state.anomalies + 1] = anomaly
        print("[MoneyLedger] ANOMALY: " .. anomaly)
    end

    print("[MoneyLedger] #" .. entry.id .. " " .. source
        .. " delta=" .. delta .. " " .. before .. " -> " .. after
        .. (context and (" ctx=" .. context) or ""))
end

-- ============================================================================
-- 异常检测
-- ============================================================================

--- 检查单笔交易是否异常
---@param source string
---@param delta number
---@param before number
---@param after number
---@return string|nil 异常描述，无异常返回 nil
function MoneyLedger.CheckAnomaly(source, delta, before, after)
    -- 1. 算术一致性：after 应等于 before + delta
    if after ~= before + delta then
        return string.format("MATH_MISMATCH: %s before=%d delta=%d expected=%d actual=%d",
            source, before, delta, before + delta, after)
    end
    -- 2. 单笔金额阈值
    if math.abs(delta) > MoneyLedger.ANOMALY_THRESHOLD then
        return string.format("LARGE_JUMP: %s delta=%d (threshold=%g)",
            source, delta, MoneyLedger.ANOMALY_THRESHOLD)
    end
    -- 3. 余额为负
    if after < 0 then
        return string.format("NEGATIVE_BALANCE: %s after=%d", source, after)
    end
    -- 4. 来源未标注
    if source == "unknown" or source == "unknown_set" then
        return string.format("UNKNOWN_SOURCE: delta=%d %d -> %d", delta, before, after)
    end
    return nil
end

-- ============================================================================
-- 余额校验
-- ============================================================================

--- 校验累计变动是否与实际余额一致
---@param actualBalance number 当前实际余额
---@return boolean ok
---@return number expectedBalance 账本期望余额
---@return string|nil message 不一致时的描述
function MoneyLedger.Verify(actualBalance)
    if not state.initialized then return true, actualBalance end
    local expectedBalance = state.sessionStart + state.cumulativeDelta
    if expectedBalance ~= actualBalance then
        local msg = string.format("VERIFY_FAIL: expected=%d actual=%d diff=%d",
            expectedBalance, actualBalance, actualBalance - expectedBalance)
        state.anomalies[#state.anomalies + 1] = msg
        print("[MoneyLedger] " .. msg)
        return false, expectedBalance, msg
    end
    return true, expectedBalance
end

--- 获取账本期望余额
---@return number
function MoneyLedger.GetExpectedBalance()
    return state.sessionStart + state.cumulativeDelta
end

--- 是否已初始化
---@return boolean
function MoneyLedger.IsInitialized()
    return state.initialized
end

-- ============================================================================
-- 聚合摘要
-- ============================================================================

--- 按来源聚合交易记录
---@return table { [source] = { count, totalDelta } }
local function aggregateBySource()
    local agg = {}
    for _, e in ipairs(state.entries) do
        if not agg[e.source] then
            agg[e.source] = { count = 0, totalDelta = 0 }
        end
        agg[e.source].count = agg[e.source].count + 1
        agg[e.source].totalDelta = agg[e.source].totalDelta + e.delta
    end
    return agg
end

--- 获取会话摘要
---@return table
function MoneyLedger.GetSummary()
    return {
        sessionStart = state.sessionStart,
        cumulativeDelta = state.cumulativeDelta,
        expectedBalance = state.sessionStart + state.cumulativeDelta,
        entryCount = state.seq - 1,
        anomalyCount = #state.anomalies,
        anomalies = state.anomalies,
        bySource = aggregateBySource(),
    }
end

--- 获取所有异常记录
---@return string[]
function MoneyLedger.GetAnomalies()
    return state.anomalies
end

--- 获取最近的交易记录
---@return table[]
function MoneyLedger.GetEntries()
    return state.entries
end

-- ============================================================================
-- 云端上报
-- ============================================================================

--- 上传摘要到云端
function MoneyLedger.UploadSummary()
    ---@diagnostic disable: undefined-global
    if not clientCloud then return end

    local summary = MoneyLedger.GetSummary()
    summary.uploadedAt = os.time()

    clientCloud:BatchSet()
        :Set("money_ledger_summary", summary)
        :Save("ledger_upload", {
            ok = function()
                state.lastUploadTime = os.time()
                print("[MoneyLedger] Summary uploaded (entries=" .. summary.entryCount
                    .. ", anomalies=" .. summary.anomalyCount .. ")")
            end,
            error = function(code, reason)
                print("[MoneyLedger] Upload failed: " .. tostring(reason))
            end,
        })
end

--- 定时上传检查（在 Update 循环中调用）
function MoneyLedger.TryPeriodicUpload()
    if not state.initialized then return end
    local now = os.time()
    if now - state.lastUploadTime >= MoneyLedger.UPLOAD_INTERVAL then
        MoneyLedger.UploadSummary()
    end
end

return MoneyLedger
