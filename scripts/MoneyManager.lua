-- ============================================================================
-- MoneyManager.lua - 安全资金操作 + 云端持久化
-- 从 GameState.lua 提取，通过 Setup(ctx) 注入上下文
-- ============================================================================

local MoneyManager = {}

-- 注入的上下文（由 GameState.Init 调用 Setup 设置）
local ctx = nil  -- { state, secureMoney, AntiCheat }
local onMoneyChanged = nil
local isServerMode = false  -- 服务端模式：跳过 clientCloud 操作

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

--- 校验玩家资金是否被篡改，被篡改则恢复
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

--- 安全修改资金（同时更新明文和 SecureValue，人类玩家自动云端保存）
function MoneyManager.SecureSetMoney(playerIdx, newValue)
    local player = ctx.state.players[playerIdx]
    if not player then return end
    newValue = math.floor(newValue)
    player.money = newValue
    if ctx.secureMoney[playerIdx] then
        ctx.secureMoney[playerIdx].set(newValue)
    end
    -- 人类玩家资金变动时自动保存到云端并通知 UI
    if playerIdx == 1 and player.isHuman then
        if onMoneyChanged then onMoneyChanged(1, newValue) end
        MoneyManager.SaveCloudMoney()
    end
end

--- 安全增减资金
function MoneyManager.SecureAddMoney(playerIdx, delta)
    MoneyManager.ValidateMoney(playerIdx)
    local player = ctx.state.players[playerIdx]
    if not player then return end
    MoneyManager.SecureSetMoney(playerIdx, player.money + delta)
end

-- ============================================================================
-- 云端资金持久化（clientCloud）
-- 存储策略：
--   values.player_money  → Set() 存真实金额（无上限）
--   iscores.money_rank   → SetInt() 存 floor(amount/10000)，用于排行榜排序
--   读取时优先 values，回退 iscores.player_money（兼容旧数据）
-- ============================================================================

---@diagnostic disable: undefined-global

--- 排行榜缩放因子：iscores 以"万"为单位
local RANK_SCALE = 10000
--- iscores 32 位有符号整数上限
local INT32_MAX = 2147483647

--- 将真实金额转为排行榜值（万为单位，cap 到 INT32_MAX）
function MoneyManager.ToRankValue(amount)
    local v = math.floor(amount / RANK_SCALE)
    if v > INT32_MAX then v = INT32_MAX end
    return v
end

--- 从云端加载资金（游戏初始化时调用，异步）
---@param callback function 加载完成后的回调
function MoneyManager.LoadCloudMoney(callback)
    if isServerMode or not clientCloud then
        if isServerMode then
            print("[MoneyManager] Server mode: skipping cloud load")
        else
            print("[MoneyManager] clientCloud not available, using default money")
        end
        if callback then callback() end
        return
    end

    clientCloud:BatchGet():Key("player_money"):Key("money_rank"):Fetch({
        ok = function(values, iscores)
            -- 优先从 values 读（新格式，无上限）
            local saved = values.player_money
            if saved and type(saved) == "number" and saved > 0 then
                local player = ctx.state.players[1]
                if player then
                    print("[MoneyManager] Cloud money loaded (values): " .. saved)
                    player.money = math.floor(saved)
                    if ctx.secureMoney[1] then ctx.secureMoney[1].set(player.money) end
                    if onMoneyChanged then onMoneyChanged(1, player.money) end
                end
            else
                -- 回退：从旧 iscores.player_money 读（兼容老玩家）
                local oldSaved = iscores.player_money
                if oldSaved and oldSaved > 0 then
                    local player = ctx.state.players[1]
                    if player then
                        print("[MoneyManager] Cloud money loaded (legacy iscores): " .. oldSaved)
                        player.money = oldSaved
                        if ctx.secureMoney[1] then ctx.secureMoney[1].set(oldSaved) end
                        if onMoneyChanged then onMoneyChanged(1, oldSaved) end
                        -- 迁移：立即写入新格式
                        MoneyManager.SaveCloudMoney()
                    end
                else
                    print("[MoneyManager] No cloud money found, using StartingMoney")
                end
            end
            if callback then callback() end
        end,
        error = function(code, reason)
            print("[MoneyManager] Cloud load failed: " .. tostring(reason) .. ", using default money")
            if callback then callback() end
        end,
    })
end

--- 保存人类玩家资金到云端（双写：values + iscores 排行榜）
function MoneyManager.SaveCloudMoney()
    if isServerMode or not clientCloud then return end
    local player = ctx.state.players[1]
    if not player or not player.isHuman then return end

    local amount = player.money
    clientCloud:BatchSet()
        :Set("player_money", amount)
        :SetInt("money_rank", MoneyManager.ToRankValue(amount))
        :Save("save_money", {
            ok = function()
                print("[MoneyManager] Cloud money saved: " .. amount .. " (rank=" .. MoneyManager.ToRankValue(amount) .. ")")
            end,
            error = function(code, reason)
                print("[MoneyManager] Cloud save failed: " .. tostring(reason))
            end,
        })
end

return MoneyManager
