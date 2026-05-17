-- ============================================================================
-- MoneyManager.lua - 安全资金操作 + 云端持久化（注册到 SaveFramework）
-- ============================================================================
-- 重构后架构：
--   通过 SaveFramework.Register("money", ...) 注册 load/save
--   不再独立发起 clientCloud 请求
--   SaveCloudMoney → SaveFramework.MarkDirty("money")
--   AddMoneyFromMenu / PersistMenuMoney → SaveFramework.DirectSave
--   PauseForGame / ResumeAfterGame → 由 SaveFramework 统一管理（移除自身实现）
-- ============================================================================

local SaveFramework = require("SaveFramework")

local MoneyManager = {}

-- 注入的上下文（由 GameState.Init 调用 Setup 设置）
local ctx = nil  -- { state, secureMoney, AntiCheat }
local onMoneyChanged = nil
local isServerMode = false  -- 服务端模式：跳过 clientCloud 操作

local MODULE_NAME = "money"

--- 排行榜缩放因子：iscores 以"万"为单位
local RANK_SCALE = 10000
--- iscores 32 位有符号整数上限
local INT32_MAX = 2147483647

---@diagnostic disable: undefined-global

-- ============================================================================
-- 统一排行榜上传（含条件过滤）
-- ============================================================================

--- 将一组统计数据写入 batch（对应指定 suffix）
local function UploadStatsWithSuffix(batch, sfx, profit, loss, maxProfit, maxLoss, redItems, games, wins)
    local winRatePct    = games > 0 and (wins / games * 100) or 0
    local winRateBP     = math.max(0, math.min(10000, math.floor(winRatePct * 100 + 0.5)))
    local winRateEncoded = winRateBP * 100000 + math.min(99999, games)

    if profit > 0 then
        batch:SetInt("money_rank"         .. sfx, MoneyManager.ToRankValue(profit))
    end
    if loss > 0 then
        batch:SetInt("loss_rank"          .. sfx, MoneyManager.ToRankValue(loss))
    end
    if redItems > 0 then
        batch:SetInt("red_items_rank"     .. sfx, redItems)
    end
    if maxProfit > 0 then
        batch:SetInt("single_profit_rank" .. sfx, MoneyManager.ToRankValue(maxProfit))
    end
    if maxLoss > 0 then
        batch:SetInt("single_loss_rank"   .. sfx, MoneyManager.ToRankValue(maxLoss))
    end
    if games > 0 then
        batch:SetInt("win_rate_rank"      .. sfx, winRateEncoded)
    end
end

local function UploadAllRanks(batch)
    local SaveSystem = require("SaveSystem")
    local stats = SaveSystem.GetStats()
    if not stats then return end

    local now = os.time()

    -- 删除上一个周期的过期 key
    local RANK_KEYS = {
        "money_rank", "loss_rank", "red_items_rank",
        "single_profit_rank", "single_loss_rank",
        "win_rate_rank",
    }
    local prevSuffixes = {
        "_d" .. os.date("%Y%m%d", now - 86400),
        "_w" .. os.date("%Y%W",   now - 7 * 86400),
        "_m" .. os.date("%Y%m",   now - 32 * 86400),
    }
    for _, sfx in ipairs(prevSuffixes) do
        for _, rk in ipairs(RANK_KEYS) do
            batch:Delete(rk .. sfx)
        end
    end

    -- 总榜：用全量累计数据
    UploadStatsWithSuffix(batch, "",
        stats.totalProfit  or 0,
        stats.totalLoss    or 0,
        stats.maxProfit    or 0,
        stats.maxLoss      or 0,
        stats.redItemsWon  or 0,
        stats.totalGames   or 0,
        stats.wins         or 0)

    -- 日/周/月榜：用各自周期的独立统计
    local periods = {
        { period = "day",   sfx = "_d" .. os.date("%Y%m%d", now) },
        { period = "week",  sfx = "_w" .. os.date("%Y%W",   now) },
        { period = "month", sfx = "_m" .. os.date("%Y%m",   now) },
    }
    for _, p in ipairs(periods) do
        local ps = SaveSystem.GetPeriodStats(p.period)
        if ps and ps.games > 0 then
            UploadStatsWithSuffix(batch, p.sfx,
                ps.profit    or 0,
                ps.loss      or 0,
                ps.maxProfit or 0,
                ps.maxLoss   or 0,
                ps.red       or 0,  -- 各时间段独立统计的红色藏品数
                ps.games     or 0,
                ps.wins      or 0)
        end
    end
end

-- ============================================================================
-- SaveFramework 注册
-- ============================================================================

SaveFramework.Register(MODULE_NAME, {
    cloudKeys = {
        -- 基础存储
        "player_money", "money_cleanup_done",
        -- 总榜（固定 key，load 时需要读取）
        "money_rank", "loss_rank", "red_items_rank",
        "single_profit_rank", "single_loss_rank",
        "win_rate_rank",
        -- 日/周/月榜使用动态日期 key（上传时动态生成，不在此预声明）
    },
    speculativeKeys = {},

    -- 从 BatchGet 返回的 values/iscores 中恢复金币
    load = function(values, iscores)
        local MoneyHUD = require("UI.MoneyHUD")
        local Config = require("Config")
        local cleanupDone = values.money_cleanup_done

        -- 优先从 values 读（新格式，无上限）
        local saved = values.player_money
        local loaded = false
        if saved and type(saved) == "number" and saved > 0 then
            MoneyHUD.SetMoney(math.floor(saved))
            print("[MoneyManager] Cloud money loaded (values): " .. math.floor(saved))
            loaded = true
        else
            -- 回退旧 iscores（兼容老玩家）
            local oldSaved = iscores.player_money
            if oldSaved and oldSaved > 0 then
                MoneyHUD.SetMoney(oldSaved)
                print("[MoneyManager] Cloud money loaded (legacy iscores): " .. oldSaved)
                loaded = true
                -- 标记脏，让下次保存时迁移到新格式
                SaveFramework.MarkDirty(MODULE_NAME)
            else
                print("[MoneyManager] No cloud money, using default: " .. Config.GAME.StartingMoney)
            end
        end

        -- 一次性清理：异常金币（>1千亿）重置为0
        local currentMoney = MoneyHUD.GetMoney()
        if not cleanupDone and currentMoney > 12500000000 then
            print("[MoneyManager] CLEANUP: money " .. currentMoney .. " exceeds 12.5B, resetting to 0")
            MoneyHUD.SetMoney(0)
            SaveFramework.MarkDirty(MODULE_NAME)
        end

        -- 初始化金币审计账本
        require("MoneyLedger").Init(MoneyHUD.GetMoney())
    end,

    -- 往 BatchSet 的 batch 上追加金币数据
    save = function(batch)
        local MoneyHUD = require("UI.MoneyHUD")
        local amount = MoneyHUD.GetMoney()
        batch:Set("player_money", amount)

        -- 上传所有榜单（含条件过滤）
        UploadAllRanks(batch)
    end,

    -- 无云端数据时初始化默认值
    defaults = function()
        local Config = require("Config")
        local MoneyHUD = require("UI.MoneyHUD")
        MoneyHUD.SetMoney(Config.GAME.StartingMoney)
        require("MoneyLedger").Init(MoneyHUD.GetMoney())
        print("[MoneyManager] Defaults applied, money=" .. Config.GAME.StartingMoney)
    end,
})

-- ============================================================================
-- 基础设置
-- ============================================================================

--- 设置服务端模式（跳过 clientCloud 读写）
function MoneyManager.SetServerMode(enabled)
    isServerMode = enabled
end

--- 注入运行时上下文（每次 GameState.Init 时调用）
function MoneyManager.Setup(context)
    ctx = context
end

function MoneyManager.SetOnMoneyChanged(fn)
    onMoneyChanged = fn
end

--- 主动触发资金变动通知（供 GameState.Init 等场景调用）
function MoneyManager.NotifyMoneyChanged(playerIdx, value)
    if onMoneyChanged then onMoneyChanged(playerIdx, value) end
end

-- ============================================================================
-- 安全资金操作（AntiCheat 集成）
-- ============================================================================

function MoneyManager.ValidateMoney(playerIdx)
    local sv = ctx.secureMoney[playerIdx]
    local player = ctx.state.players[playerIdx]
    if sv and player then
        local secureVal = sv.get()
        if secureVal ~= player.money then
            print("[AntiCheat] WARNING: Player " .. playerIdx .. " money tampered! "
                .. player.money .. " -> restoring to " .. secureVal)
            player.money = secureVal
        end
    end
end

--- 账本核算
function MoneyManager.LedgerAudit()
    if not ctx then return end
    local player = ctx.state.players[1]
    if not player or not player.isHuman then return end

    local MoneyLedger = require("MoneyLedger")
    if not MoneyLedger.IsInitialized() then return end

    local actualMoney = player.money
    local ok, expectedBalance, msg = MoneyLedger.Verify(actualMoney)
    if not ok then
        print("[MoneyLedger] TAMPER DETECTED! Correcting " .. actualMoney .. " -> " .. expectedBalance)
        player.money = expectedBalance
        if ctx.secureMoney[1] then
            ctx.secureMoney[1].set(expectedBalance)
        end
        if onMoneyChanged then onMoneyChanged(1, expectedBalance) end
        MoneyManager.SaveCloudMoney()
    end
end

--- 安全修改资金
function MoneyManager.SecureSetMoney(playerIdx, newValue, source, context)
    local player = ctx.state.players[playerIdx]
    if not player then return end
    newValue = math.floor(newValue)

    local oldValue = player.money
    player.money = newValue
    if ctx.secureMoney[playerIdx] then
        ctx.secureMoney[playerIdx].set(newValue)
    end
    if playerIdx == 1 and player.isHuman then
        local MoneyLedger = require("MoneyLedger")
        MoneyLedger.Record(source or "unknown_set", newValue - oldValue, oldValue, newValue, context)

        if onMoneyChanged then onMoneyChanged(1, newValue) end
        MoneyManager.SaveCloudMoney()
    end
end

--- 安全增减资金
function MoneyManager.SecureAddMoney(playerIdx, delta, source, context)
    MoneyManager.ValidateMoney(playerIdx)
    local player = ctx.state.players[playerIdx]
    if not player then return end
    MoneyManager.SecureSetMoney(playerIdx, player.money + delta, source, context)
end

-- ============================================================================
-- 排行榜工具
-- ============================================================================

function MoneyManager.ToRankValue(amount)
    local v = math.floor(amount / RANK_SCALE)
    if v > INT32_MAX then v = INT32_MAX end
    return v
end

-- ============================================================================
-- 云端资金持久化 → 委托 SaveFramework
-- ============================================================================

--- 兼容旧接口：LoadCloudMoney 不再独立加载（由 SaveFramework.Init 统一加载）
function MoneyManager.LoadCloudMoney(callback)
    -- 数据已由 SaveFramework.Init 加载完毕，直接回调
    print("[MoneyManager] LoadCloudMoney: data already loaded by SaveFramework")
    if callback then callback() end
end

--- 保存人类玩家资金 → 标记脏
function MoneyManager.SaveCloudMoney()
    if isServerMode then return end
    SaveFramework.MarkDirty(MODULE_NAME)
end

--- 对局暂停/恢复 → 已统一到 SaveFramework（保留空壳兼容旧调用方）
function MoneyManager.PauseForGame()
    -- SaveFramework.PauseForGame() 由 SaveSystem.PauseForGame() 调用
    print("[MoneyManager] PauseForGame (delegated to SaveFramework)")
end

function MoneyManager.ResumeAfterGame()
    -- SaveFramework.ResumeAfterGame() 由 SaveSystem.ResumeAfterGame() 调用
    print("[MoneyManager] ResumeAfterGame (delegated to SaveFramework)")
end

-- ============================================================================
-- 菜单上下文金币操作 → 使用 SaveFramework.DirectSave
-- ============================================================================

--- 菜单上下文加减金币
function MoneyManager.AddMoneyFromMenu(delta, label, opts)
    opts = opts or {}
    local MoneyHUD = require("UI.MoneyHUD")
    local MoneyLedger = require("MoneyLedger")

    local oldMoney = MoneyHUD.GetMoney()
    local newTotal = math.max(0, math.floor(oldMoney + delta))

    -- 审计记账
    MoneyLedger.Record(label or "menu_unknown", delta, oldMoney, newTotal)

    -- 乐观更新本地缓存
    MoneyHUD.SetMoney(newTotal)

    -- 云端持久化：通过 SaveFramework.DirectSave
    SaveFramework.DirectSave(label or "menu_money", function(batch)
        batch:Set("player_money", newTotal)
        -- 上传所有榜单（含条件过滤）
        UploadAllRanks(batch)
        -- 允许调用方追加额外字段
        if opts.batchSetup then
            opts.batchSetup(batch)
        end
    end, {
        ok = function()
            print("[MoneyManager] MenuMoney saved: " .. oldMoney .. " → " .. newTotal .. " (" .. label .. ")")
            if not opts.silent then
                pcall(function()
                    local FloatingMessage = require("UI.FloatingMessage")
                    FloatingMessage.Show("已保存")
                end)
            end
            if opts.ok then opts.ok() end
        end,
        error = function(code, reason)
            print("[MoneyManager] MenuMoney save FAILED: " .. tostring(reason) .. " — rolling back")
            MoneyHUD.SetMoney(oldMoney)
            if opts.error then opts.error(code, reason) end
        end,
    })
end

--- 菜单上下文持久化当前金币
function MoneyManager.PersistMenuMoney(label, opts)
    opts = opts or {}
    local MoneyHUD = require("UI.MoneyHUD")
    local amount = MoneyHUD.GetMoney()

    SaveFramework.DirectSave(label or "persist_money", function(batch)
        batch:Set("player_money", amount)
        -- 上传所有榜单（含条件过滤）
        UploadAllRanks(batch)
    end, {
        ok = function()
            print("[MoneyManager] PersistMenuMoney saved: " .. amount .. " (" .. label .. ")")
            pcall(function()
                local FloatingMessage = require("UI.FloatingMessage")
                FloatingMessage.Show("已保存")
            end)
            if opts.ok then opts.ok() end
        end,
        error = function(code, reason)
            print("[MoneyManager] PersistMenuMoney FAILED: " .. tostring(reason))
            if opts.error then opts.error(code, reason) end
        end,
    })
end

return MoneyManager
