-- ============================================================================
-- UI/MoneyHUD.lua - 全局金币余额 HUD（右上角，所有界面可见）
-- ============================================================================

local UI = require("urhox-libs/UI")
local Config = require("Config")
local Utils = require("UI.Utils")
local MoneyManager = require("MoneyManager")

local MoneyHUD = {}

local moneyLabel = nil
local hudPanel = nil
local cachedMoney = Config.GAME.StartingMoney

--- 从云端加载资金（仅在启动时调用一次）
function MoneyHUD.LoadFromCloud(callback)
    if not clientCloud then
        print("[MoneyHUD] clientCloud not available, using default")
        if callback then callback(cachedMoney) end
        return
    end

    clientCloud:Get("player_money", {
        ok = function(values, iscores)
            -- 优先从 values 读（新格式，无上限）
            local saved = values.player_money
            if saved and type(saved) == "number" and saved > 0 then
                cachedMoney = math.floor(saved)
                print("[MoneyHUD] Cloud money loaded (values): " .. cachedMoney)
            else
                -- 回退旧 iscores（兼容老玩家）
                local oldSaved = iscores.player_money
                if oldSaved and oldSaved > 0 then
                    cachedMoney = oldSaved
                    print("[MoneyHUD] Cloud money loaded (legacy iscores): " .. cachedMoney)
                    -- 迁移：主动写入新格式 + 排行榜
                    if clientCloud then
                        clientCloud:BatchSet()
                            :Set("player_money", cachedMoney)
                            :SetInt("money_rank", MoneyManager.ToRankValue(cachedMoney))
                            :Save("migrate_money")
                        print("[MoneyHUD] Migrated legacy data to new format")
                    end
                else
                    print("[MoneyHUD] No cloud money, using default: " .. cachedMoney)
                end
            end
            MoneyHUD.Refresh()
            if callback then callback(cachedMoney) end
        end,
        error = function(code, reason)
            print("[MoneyHUD] Cloud load failed: " .. tostring(reason))
            if callback then callback(cachedMoney) end
        end,
    })
end

--- 获取缓存的金币数
function MoneyHUD.GetMoney()
    return cachedMoney
end

--- 更新缓存（由 GameState 在资金变动时调用）
function MoneyHUD.SetMoney(amount)
    cachedMoney = amount
    MoneyHUD.Refresh()
end

--- 刷新 HUD 显示
function MoneyHUD.Refresh()
    if moneyLabel then
        moneyLabel:SetText(Utils.FormatMoney(cachedMoney))
    end
end

--- 创建 HUD 面板（绝对定位右上角）
function MoneyHUD.CreatePanel()
    moneyLabel = UI.Label {
        text = Utils.FormatMoney(cachedMoney),
        fontSize = 14,
        fontColor = { 255, 220, 100, 255 },
        fontWeight = "bold",
    }
    hudPanel = UI.Panel {
        position = "absolute",
        right = "2%", top = "2%",
        flexDirection = "row",
        alignItems = "center",
        gap = 5,
        paddingHorizontal = 10,
        paddingVertical = 5,
        backgroundColor = { 0, 0, 0, 120 },
        borderRadius = 0,
        children = {
            UI.Panel {
                width = 18, height = 18,
                backgroundImage = Utils.GetIcon("coin"),
                backgroundFit = "contain",
                flexShrink = 0,
            },
            moneyLabel,
        },
    }
    return hudPanel
end

return MoneyHUD
