-- ============================================================================
-- UI/MoneyHUD.lua - 全局金币余额 HUD（右上角，所有界面可见）
-- ============================================================================
-- 重构后：
--   不再独立调用 clientCloud:Get 加载金币
--   金币由 MoneyManager 的 SaveFramework.Register("money") load 回调设置
--   MoneyHUD 仅作为运行时缓存 + UI 显示组件
-- ============================================================================

local UI = require("urhox-libs/UI")
local Config = require("Config")
local Utils = require("UI.Utils")
local MoneyManager = require("MoneyManager")
local SaveSystem = require("SaveSystem")

local MoneyHUD = {}

local moneyLabel = nil
local hudPanel = nil
local popupPanel = nil
local cachedMoney = Config.GAME.StartingMoney

--- 兼容旧接口：不再独立加载（由 SaveFramework.Init → MoneyManager.load 统一加载）
function MoneyHUD.LoadFromCloud(callback)
    print("[MoneyHUD] LoadFromCloud: data already loaded by SaveFramework")
    if callback then callback(cachedMoney) end
end

--- 获取缓存的金币数
function MoneyHUD.GetMoney()
    return cachedMoney
end

--- 更新缓存（由 MoneyManager load 回调 或 GameState 在资金变动时调用）
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

--- 创建 HUD 面板（内联，由父容器控制位置）
function MoneyHUD.CreatePanel()
    local sz = Utils.sz
    moneyLabel = UI.Label {
        text = Utils.FormatMoney(cachedMoney),
        fontSize = sz(15),
        fontColor = { 255, 220, 100, 255 },
        fontWeight = "bold",
    }
    hudPanel = UI.Panel {
        height = sz(34),
        flexDirection = "row",
        alignItems = "center",
        gap = sz(6),
        paddingHorizontal = sz(10),
        backgroundColor = { 0, 0, 0, 120 },
        borderRadius = sz(4),
        cursor = "pointer",
        onClick = function()
            Utils.PlayClick()
            MoneyHUD.TogglePopup()
        end,
        children = {
            UI.Panel {
                width = sz(20), height = sz(20),
                backgroundImage = Utils.GetIcon("coin"),
                backgroundFit = "contain",
                flexShrink = 0,
            },
            moneyLabel,
        },
    }
    return hudPanel
end

--- 创建资产弹窗
function MoneyHUD.CreatePopup()
    local sz = Utils.sz
    local popupContent = UI.Panel {
        width = sz(280),
        backgroundColor = { 30, 33, 48, 245 },
        borderRadius = sz(8), borderWidth = 1,
        borderColor = { 80, 85, 110, 180 },
        padding = sz(16), gap = sz(12),
        flexDirection = "column",
        onClick = function() end, -- 阻止冒泡关闭
        children = {
            -- 标题
            UI.Label {
                text = "我的资产",
                fontSize = sz(16), fontWeight = "bold",
                fontColor = { 255, 220, 100, 255 },
                textAlign = "center", width = "100%",
            },
            -- 分割线
            UI.Panel { width = "100%", height = 1, backgroundColor = { 80, 85, 110, 120 } },
            -- 金币行
            UI.Panel {
                width = "100%", flexDirection = "row",
                justifyContent = "space-between", alignItems = "center",
                children = {
                    UI.Panel {
                        flexDirection = "row", alignItems = "center", gap = sz(6),
                        children = {
                            UI.Panel {
                                width = sz(20), height = sz(20),
                                backgroundImage = Utils.GetIcon("coin"),
                                backgroundFit = "contain", flexShrink = 0,
                            },
                            UI.Label { text = "金币", fontSize = sz(13), fontColor = { 200, 205, 220, 255 } },
                        },
                    },
                    UI.Label {
                        id = "popup_money",
                        text = Utils.FormatMoneyExact(cachedMoney),
                        fontSize = sz(14), fontWeight = "bold",
                        fontColor = { 255, 220, 100, 255 },
                    },
                },
            },
            -- 角色币行
            UI.Panel {
                width = "100%", flexDirection = "row",
                justifyContent = "space-between", alignItems = "center",
                children = {
                    UI.Panel {
                        flexDirection = "row", alignItems = "center", gap = sz(6),
                        children = {
                            UI.Panel {
                                width = sz(20), height = sz(20),
                                backgroundImage = Config.CHARACTER_COIN_ICON,
                                backgroundFit = "contain", flexShrink = 0,
                            },
                            UI.Label { text = "角色币", fontSize = sz(13), fontColor = { 200, 205, 220, 255 } },
                        },
                    },
                    UI.Label {
                        id = "popup_char_coins",
                        text = "0",
                        fontSize = sz(14), fontWeight = "bold",
                        fontColor = { 255, 200, 80, 255 },
                    },
                },
            },
            -- 门票行
            UI.Panel {
                id = "popup_tickets_section",
                width = "100%", flexDirection = "column", gap = sz(6),
            },
            -- 关闭按钮
            UI.Button {
                text = "关闭", width = "100%", height = sz(36),
                fontSize = sz(13),
                onClick = function()
                    Utils.PlayClick()
                    MoneyHUD.HidePopup()
                end,
            },
        },
    }

    popupPanel = UI.Panel {
        position = "absolute",
        left = 0, top = 0, width = "100%", height = "100%",
        backgroundColor = { 0, 0, 0, 150 },
        justifyContent = "center", alignItems = "center",
        visible = false,
        onClick = function()
            MoneyHUD.HidePopup()
        end,
        children = {
            UI.Panel {
                justifyContent = "center", alignItems = "center",
                children = { popupContent },
            },
        },
    }
    return popupPanel
end

--- 刷新弹窗内容
local function refreshPopupContent()
    if not popupPanel then return end
    -- 更新金币
    local moneyLbl = popupPanel:FindById("popup_money")
    if moneyLbl then
        moneyLbl:SetText(Utils.FormatMoneyExact(cachedMoney))
    end
    -- 更新角色币
    local charCoinLbl = popupPanel:FindById("popup_char_coins")
    if charCoinLbl then
        charCoinLbl:SetText(tostring(SaveSystem.GetCharacterCoins()))
    end
    -- 更新门票区域
    local ticketSection = popupPanel:FindById("popup_tickets_section")
    if ticketSection then
        local ticketChildren = {}
        local sz = Utils.sz
        local seen = {}

        -- 辅助：添加一张门票行
        local function addTicketRow(ticketId)
            if not ticketId or seen[ticketId] then return end
            seen[ticketId] = true
            local count = SaveSystem.GetTicketCount(ticketId)
            local ticketConf = Config.TICKETS[ticketId]
            local ticketIconPath = ticketConf and ticketConf.icon or nil
            local ticketName = ticketConf and ticketConf.name or ticketId
            ticketChildren[#ticketChildren + 1] = UI.Panel {
                width = "100%", flexDirection = "row",
                justifyContent = "space-between", alignItems = "center",
                children = {
                    UI.Panel {
                        flexDirection = "row", alignItems = "center", gap = sz(6),
                        children = {
                            ticketIconPath and UI.Panel {
                                width = sz(28), height = sz(18),
                                backgroundImage = ticketIconPath,
                                backgroundFit = "contain", flexShrink = 0,
                            } or UI.Label { text = "🎫", fontSize = sz(16) },
                            UI.Label {
                                text = ticketName,
                                fontSize = sz(12),
                                fontColor = { 200, 205, 220, 255 },
                            },
                        },
                    },
                    UI.Label {
                        text = "×" .. count,
                        fontSize = sz(14), fontWeight = "bold",
                        fontColor = count > 0 and { 255, 200, 80, 255 } or { 255, 100, 100, 255 },
                    },
                },
            }
        end

        for _, region in ipairs(Config.REGIONS) do
            -- 区域指定门票（指定仓库类型所需）
            addTicketRow(region.ticket)
            -- 难度门票
            for _, diff in ipairs(region.difficulties or {}) do
                addTicketRow(diff.requiredTicket)
            end
        end
        if #ticketChildren == 0 then
            ticketSection:SetVisible(false)
        else
            ticketSection:SetVisible(true)
            ticketSection:ClearChildren()
            for _, child in ipairs(ticketChildren) do
                ticketSection:AddChild(child)
            end
        end
    end
end

--- 显示/隐藏弹窗
local popupVisible = false

function MoneyHUD.TogglePopup()
    if not popupPanel then return end
    popupVisible = not popupVisible
    if popupVisible then
        refreshPopupContent()
    end
    popupPanel:SetVisible(popupVisible)
end

function MoneyHUD.HidePopup()
    if popupPanel then
        popupVisible = false
        popupPanel:SetVisible(false)
    end
end

return MoneyHUD
