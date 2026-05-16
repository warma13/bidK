-- ============================================================================
-- SaveFramework.lua - 统一存档框架（注册制 + 单次云端加载 + 批量保存）
-- ============================================================================
-- 核心思路（来自 4 层存档架构）：
--   1. 调度：注册制，每个模块 Register 自己的 load/save/defaults
--   2. 所有权：数据由各模块 local 变量持有，框架不存储业务数据
--   3. 脏标记：模块修改数据后调用 MarkDirty，框架延迟合并保存
--   4. 效率：单次 BatchGet 加载所有模块，单次 BatchSet 保存所有脏模块
--
-- 解决的核心问题：
--   旧架构中 MoneyHUD / SaveSystem / AdCardPanel / SettingsPanel 各自独立
--   调用 clientCloud，启动时 5+ 个并发云端操作 → 引擎卡死
--   新架构：启动时 1 次 BatchGet，保存时 1 次 BatchSet
-- ============================================================================

---@diagnostic disable: undefined-global

local SaveFramework = {}

-- ============================================================================
-- 注册表
-- ============================================================================

local modules = {}          -- { name -> moduleConfig }
local moduleOrder = {}      -- 注册顺序（保证加载/保存顺序确定）
local initialized = false
local initGeneration = 0    -- 防止重复 Init 的回调冲突

-- ============================================================================
-- 脏标记 + 自动保存
-- ============================================================================

local dirtySet = {}         -- { name -> true }
local hasDirty = false
local dirtyTimer = 0
local DIRTY_DELAY = 5       -- 脏数据延迟合并（秒）

local autoSaveTimer = 0
local SAVE_INTERVAL = 30    -- 自动保存间隔（秒）

-- ============================================================================
-- 对局暂停
-- ============================================================================

local gamePaused = false
local pendingSave = false   -- 对局中积累的脏数据，结束后一次性保存

-- ============================================================================
-- 写入并发控制
-- ============================================================================

local writeInFlight = false -- 是否有 BatchSet 正在进行
local pendingFlush = false  -- writeInFlight 期间又有新的保存请求

-- DirectSave 等待队列：{ label, setup, opts }
-- 当 writeInFlight 时 DirectSave 入队，写操作完成后依次执行
local directSaveQueue = {}

-- ============================================================================
-- Generation 计数器（防幽灵回调）
-- 每次发出新保存请求时递增；回调验证自己是否是当前代
-- ============================================================================

local writeGeneration = 0       -- 当前写代次
local WRITE_TIMEOUT = 15        -- 单次写超时（秒）
local writeTimeoutTimer = 0     -- 距本次写操作已过去的时间
local writeTimerActive = false  -- 是否在计时

-- ============================================================================
-- 熔断机制
-- ============================================================================

local consecutiveFailures = 0   -- 连续写失败次数
local WARN_THRESHOLD = 3        -- 连续失败多少次后显示警告
local CIRCUIT_BREAK = 6         -- 连续失败多少次后暂停自动保存
local circuitBroken = false     -- 熔断状态
local warningShown = false      -- 警告横幅是否已显示

-- ============================================================================
-- 重试
-- ============================================================================

local retryCount = 0
local retryTimer = 0
local MAX_RETRY = 3
local RETRY_INTERVAL = 10
local needRetry = false

-- ============================================================================
-- "保存中..." 提示（不对后台自动保存显示）
-- ============================================================================

local SILENT_LABELS = {
    dirty_delay = true,
    auto_save = true,
    retry = true,
    pending_flush = true,
    resume_after_game = true,
}

local function ShowSaving(label)
    if SILENT_LABELS[label] then return end
    pcall(function()
        local FloatingMessage = require("UI.FloatingMessage")
        FloatingMessage.Show("保存中...")
    end)
end

-- ============================================================================
-- 熔断警告横幅（NanoVG 覆盖层，渲染在最顶层）
-- ============================================================================

local warningVg = nil
local warningBannerInitialized = false

local function InitWarningBanner()
    if warningBannerInitialized then return end
    warningBannerInitialized = true
    -- 注册 NanoVG 渲染事件
    SubscribeToEvent("NanoVGRender", "HandleSaveWarningRender")
end

function HandleSaveWarningRender()
    if not warningShown then return end
    if not warningVg then
        warningVg = pcall(function()
            local UI = require("urhox-libs/UI")
            warningVg = UI.GetNVGContext()
        end)
        -- 第二次尝试直接赋值
        if not warningVg or type(warningVg) == "boolean" then
            local ok, UI = pcall(require, "urhox-libs/UI")
            if ok and UI then warningVg = UI.GetNVGContext() end
        end
    end
    if not warningVg then return end

    local dpr = graphics:GetDPR()
    local w = graphics:GetWidth() / dpr
    local h = graphics:GetHeight() / dpr

    nvgBeginFrame(warningVg, w, h, dpr)

    -- 红色横幅背景（屏幕顶部）
    local bannerH = 36
    nvgBeginPath(warningVg)
    nvgRect(warningVg, 0, 0, w, bannerH)
    nvgFillColor(warningVg, nvgRGBA(200, 30, 30, 230))
    nvgFill(warningVg)

    -- 文字
    nvgFontFace(warningVg, "sans")
    nvgFontSize(warningVg, 14)
    nvgTextAlign(warningVg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(warningVg, nvgRGBA(255, 255, 255, 255))
    nvgText(warningVg, w / 2, bannerH / 2, "⚠ 云端存档异常，请检查网络后刷新页面")

    nvgEndFrame(warningVg)
end

local function ShowWarningBanner()
    if warningShown then return end
    warningShown = true
    InitWarningBanner()
    print("[SaveFramework] ⚠ Warning banner shown (consecutive failures: " .. consecutiveFailures .. ")")
end

local function HideWarningBanner()
    if not warningShown then return end
    warningShown = false
    print("[SaveFramework] Warning banner hidden (save recovered)")
end

-- 写操作成功后的公共清理
local function OnWriteSuccess(gen, dirtyNames)
    if gen ~= writeGeneration then
        print("[SaveFramework] Stale ok callback (gen " .. gen .. " vs " .. writeGeneration .. "), ignored")
        return false  -- 旧代次，调用方应 return
    end
    writeInFlight = false
    writeTimerActive = false
    retryCount = 0
    needRetry = false
    consecutiveFailures = 0
    if warningShown then HideWarningBanner() end
    if circuitBroken then
        circuitBroken = false
        print("[SaveFramework] Circuit breaker reset")
    end
    return true
end

-- 写操作失败后的公共处理
local function OnWriteFailure(gen, reason)
    if gen ~= writeGeneration then
        print("[SaveFramework] Stale error callback (gen " .. gen .. "), ignored")
        return false
    end
    writeInFlight = false
    writeTimerActive = false
    needRetry = true
    consecutiveFailures = consecutiveFailures + 1
    print("[SaveFramework] Write failure #" .. consecutiveFailures .. ": " .. tostring(reason))

    if consecutiveFailures >= WARN_THRESHOLD then
        ShowWarningBanner()
    end
    if consecutiveFailures >= CIRCUIT_BREAK then
        if not circuitBroken then
            circuitBroken = true
            print("[SaveFramework] 🔴 Circuit breaker OPEN: auto-save suspended")
        end
    end
    return true
end

-- ============================================================================
-- 注册模块
-- ============================================================================

--- 注册一个存档模块
---@param name string 模块名（唯一标识）
---@param config table { cloudKeys, speculativeKeys, load, save, defaults, onSaved }
function SaveFramework.Register(name, config)
    if modules[name] then
        print("[SaveFramework] WARNING: overwriting module '" .. name .. "'")
    end
    modules[name] = {
        cloudKeys       = config.cloudKeys or {},        -- BatchGet 时需要的 key 列表
        speculativeKeys = config.speculativeKeys or {},  -- 投机性 key（可能不存在，用于分片预取）
        load            = config.load,                   -- function(values, iscores) 从云端数据恢复
        save            = config.save,                   -- function(batch) 往 batch 上追加 Set/SetInt
        defaults        = config.defaults,               -- function() 无云端数据时初始化默认值
        onSaved         = config.onSaved,                -- function() 云端保存成功后回调（可选）
    }
    moduleOrder[#moduleOrder + 1] = name
    print("[SaveFramework] Registered module: " .. name)
end

-- ============================================================================
-- 初始化（单次 BatchGet 加载所有模块的云端数据）
-- ============================================================================

function SaveFramework.Init(onReady)
    if initialized then
        if onReady then onReady(true) end
        return
    end

    initGeneration = initGeneration + 1
    local gen = initGeneration

    -- 收集所有 key（去重）
    local allKeys = {}
    local seen = {}
    for _, name in ipairs(moduleOrder) do
        local mod = modules[name]
        for _, key in ipairs(mod.cloudKeys) do
            if not seen[key] then
                seen[key] = true
                allKeys[#allKeys + 1] = key
            end
        end
        for _, key in ipairs(mod.speculativeKeys) do
            if not seen[key] then
                seen[key] = true
                allKeys[#allKeys + 1] = key
            end
        end
    end

    print("[SaveFramework] Init: " .. #moduleOrder .. " modules, " .. #allKeys .. " cloud keys")

    if not clientCloud or #allKeys == 0 then
        -- 无 clientCloud 或无 key，用默认值
        for _, name in ipairs(moduleOrder) do
            local mod = modules[name]
            if mod.defaults then pcall(mod.defaults) end
        end
        initialized = true
        print("[SaveFramework] Init OK (no cloud)")
        if onReady then onReady(true) end
        return
    end

    -- 单次 BatchGet
    local batch = clientCloud:BatchGet()
    for _, key in ipairs(allKeys) do
        batch:Key(key)
    end

    batch:Fetch({
        ok = function(values, iscores)
            if gen ~= initGeneration then return end

            -- 按注册顺序分发给各模块（pcall 隔离：一个模块崩溃不影响其他模块）
            for _, name in ipairs(moduleOrder) do
                local mod = modules[name]
                if mod.load then
                    local ok, err = pcall(mod.load, values, iscores)
                    if not ok then
                        print("[SaveFramework] load ERROR [" .. name .. "]: " .. tostring(err))
                        if mod.defaults then pcall(mod.defaults) end
                    end
                end
            end

            initialized = true
            print("[SaveFramework] Init OK, all modules loaded")
            if onReady then onReady(true) end
        end,
        error = function(code, reason)
            if gen ~= initGeneration then return end
            print("[SaveFramework] Init FAILED: " .. tostring(reason))

            -- 云端加载失败时不调用 defaults()，各模块的 local 变量已有声明时的合理初始值
            -- 关键：不设置 saveConfirmed = true，防止空数据在网络恢复后覆盖云端真实存档
            initialized = true
            if onReady then onReady(false) end
        end,
    })
end

function SaveFramework.IsReady()
    return initialized
end

-- ============================================================================
-- 脏标记
-- ============================================================================

function SaveFramework.MarkDirty(name)
    if not modules[name] then return end
    dirtySet[name] = true
    hasDirty = true
    dirtyTimer = DIRTY_DELAY
end

-- ============================================================================
-- 保存（所有脏模块合并为一次 BatchSet）
-- ============================================================================

function SaveFramework.Save(label)
    if not initialized or not clientCloud then return end

    -- 熔断：只停掉定时轮询式保存，重试路径和用户主动保存不受影响
    local pollLabels = { dirty_delay = true, auto_save = true, resume_after_game = true }
    if circuitBroken and pollLabels[label or ""] then
        print("[SaveFramework] Circuit broken, skipping poll-save: " .. tostring(label))
        return
    end

    -- 收集脏模块
    local dirtyNames = {}
    for _, name in ipairs(moduleOrder) do
        if dirtySet[name] then
            dirtyNames[#dirtyNames + 1] = name
        end
    end

    if #dirtyNames == 0 then return end

    -- 并发控制：如果有写入正在进行，排队
    if writeInFlight then
        pendingFlush = true
        return
    end

    writeInFlight = true

    -- 递增 generation，使旧回调失效
    writeGeneration = writeGeneration + 1
    local myGen = writeGeneration

    -- 启动超时计时器
    writeTimerActive = true
    writeTimeoutTimer = 0

    -- 用户主动触发的保存显示"保存中..."
    ShowSaving(label or "fw_save")

    local batch = clientCloud:BatchSet()

    for _, name in ipairs(dirtyNames) do
        local mod = modules[name]
        if mod.save then
            local ok, err = pcall(mod.save, batch)
            if not ok then
                print("[SaveFramework] save ERROR [" .. name .. "]: " .. tostring(err))
            end
        end
    end

    local dirtyStr = table.concat(dirtyNames, ",")
    batch:Save(label or "fw_save", {
        ok = function()
            if not OnWriteSuccess(myGen, dirtyNames) then return end

            -- 清除已保存模块的脏标记
            for _, name in ipairs(dirtyNames) do
                dirtySet[name] = nil
            end
            -- 重新检查是否还有脏模块（保存期间可能有新的 MarkDirty）
            hasDirty = false
            for _ in pairs(dirtySet) do hasDirty = true; break end

            print("[SaveFramework] Save OK [" .. dirtyStr .. "]")

            -- 回调各模块
            for _, name in ipairs(dirtyNames) do
                local mod = modules[name]
                if mod.onSaved then pcall(mod.onSaved) end
            end

            pcall(function()
                local FloatingMessage = require("UI.FloatingMessage")
                FloatingMessage.Show("已保存")
            end)

            -- DirectSave 等待队列优先（用户主动操作）
            if #directSaveQueue > 0 then
                local next = table.remove(directSaveQueue, 1)
                SaveFramework.DirectSave(next.label, next.setup, next.opts)
                return
            end
            -- 如果保存期间有新的保存请求，立即执行
            if pendingFlush then
                pendingFlush = false
                SaveFramework.Save("pending_flush")
            end
        end,
        error = function(code, reason)
            if not OnWriteFailure(myGen, reason) then return end
            print("[SaveFramework] Save FAILED [" .. dirtyStr .. "]: " .. tostring(reason))

            if pendingFlush then
                pendingFlush = false
            end
            -- 写失败时也要冲刷 DirectSave 队列
            if #directSaveQueue > 0 then
                local next = table.remove(directSaveQueue, 1)
                SaveFramework.DirectSave(next.label, next.setup, next.opts)
            end
        end,
    })
end

function SaveFramework.SaveNow(label)
    dirtyTimer = 0
    SaveFramework.Save(label or "save_now")
end

-- ============================================================================
-- 直通批量保存（用于 AddMoneyFromMenu 等需要自定义回调的场景）
-- 绕过脏标记系统，直接执行一次 BatchSet，带 ok/error 回调
-- ============================================================================

--- @param label string 描述
--- @param setup function(batch) 调用方往 batch 上追加 Set/SetInt
--- @param opts table { ok?: function, error?: function(code,reason) }
function SaveFramework.DirectSave(label, setup, opts)
    opts = opts or {}
    if not clientCloud then
        if opts.ok then opts.ok() end
        return
    end

    -- 并发控制：有写操作在进行时，入队等待，不立即失败
    if writeInFlight then
        print("[SaveFramework] DirectSave queued (write in flight): " .. label)
        directSaveQueue[#directSaveQueue + 1] = { label = label, setup = setup, opts = opts }
        return
    end

    writeInFlight = true

    -- 递增 generation，使旧回调失效
    writeGeneration = writeGeneration + 1
    local myGen = writeGeneration

    -- 启动超时计时器
    writeTimerActive = true
    writeTimeoutTimer = 0

    -- DirectSave 均为用户主动操作，显示"保存中..."
    if not opts.silent then
        ShowSaving(label)
    end

    local batch = clientCloud:BatchSet()
    setup(batch)

    batch:Save(label, {
        ok = function()
            if not OnWriteSuccess(myGen, nil) then return end
            if opts.ok then opts.ok() end
            -- 先冲刷 DirectSave 等待队列（用户主动操作优先）
            if #directSaveQueue > 0 then
                local next = table.remove(directSaveQueue, 1)
                SaveFramework.DirectSave(next.label, next.setup, next.opts)
                return
            end
            -- 再处理 framework 层的脏数据保存
            if pendingFlush then
                pendingFlush = false
                SaveFramework.Save("pending_flush")
            end
        end,
        error = function(code, reason)
            if not OnWriteFailure(myGen, reason) then return end
            if opts.error then opts.error(code, reason) end
            -- 写失败时也要冲刷队列，否则队列永远堵塞
            if #directSaveQueue > 0 then
                local next = table.remove(directSaveQueue, 1)
                SaveFramework.DirectSave(next.label, next.setup, next.opts)
            end
        end,
    })
end

-- ============================================================================
-- 对局暂停/恢复
-- ============================================================================

function SaveFramework.PauseForGame()
    gamePaused = true
    pendingSave = false
    print("[SaveFramework] PAUSED for game session")
end

function SaveFramework.ResumeAfterGame()
    gamePaused = false
    print("[SaveFramework] RESUMED")
    if pendingSave or hasDirty then
        pendingSave = false
        SaveFramework.Save("resume_after_game")
    end
end

-- ============================================================================
-- 每帧更新
-- ============================================================================

function SaveFramework.Update(dt)
    if not initialized then return end

    -- 超时检测：写操作 15 秒未回调则主动解锁
    if writeTimerActive and writeInFlight then
        writeTimeoutTimer = writeTimeoutTimer + dt
        if writeTimeoutTimer >= WRITE_TIMEOUT then
            writeTimerActive = false
            -- 先递增 generation，防止迟到的旧回调后来扰乱状态
            writeGeneration = writeGeneration + 1
            writeInFlight = false
            consecutiveFailures = consecutiveFailures + 1
            print("[SaveFramework] ⏰ Write timeout after " .. WRITE_TIMEOUT
                .. "s (gen advanced to " .. writeGeneration .. ")")

            if consecutiveFailures >= WARN_THRESHOLD then ShowWarningBanner() end
            if consecutiveFailures >= CIRCUIT_BREAK and not circuitBroken then
                circuitBroken = true
                print("[SaveFramework] 🔴 Circuit breaker OPEN (from timeout)")
            end

            -- 超时后如果有待冲刷请求，延迟一帧处理
            if pendingFlush then
                pendingFlush = false
                needRetry = true   -- 走重试路径，不立即再发
            end
            if #directSaveQueue > 0 then
                local next = table.remove(directSaveQueue, 1)
                SaveFramework.DirectSave(next.label, next.setup, next.opts)
            end
        end
    end

    if gamePaused then
        if hasDirty then pendingSave = true end
        return
    end

    -- 脏标记延迟保存
    if hasDirty and dirtyTimer > 0 then
        dirtyTimer = dirtyTimer - dt
        if dirtyTimer <= 0 then
            SaveFramework.Save("dirty_delay")
        end
    end

    -- 自动保存
    autoSaveTimer = autoSaveTimer + dt
    if autoSaveTimer >= SAVE_INTERVAL then
        autoSaveTimer = 0
        if hasDirty then
            SaveFramework.Save("auto_save")
        end
    end

    -- 重试（指数退避：3s / 9s / 27s）
    if needRetry then
        retryTimer = retryTimer + dt
        local backoff = RETRY_INTERVAL * (3 ^ (retryCount))  -- 3,9,27
        if retryTimer >= backoff and retryCount < MAX_RETRY then
            retryTimer = 0
            retryCount = retryCount + 1
            print("[SaveFramework] Retry " .. retryCount .. "/" .. MAX_RETRY
                .. " (backoff " .. backoff .. "s)")
            SaveFramework.Save("retry")
        elseif retryCount >= MAX_RETRY then
            needRetry = false   -- 超出重试上限，等下次 MarkDirty 重新触发
        end
    end
end

return SaveFramework
