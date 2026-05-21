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
local ticketLabel = nil   -- 点券 HUD 标签
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

--- 刷新点券 HUD 显示
function MoneyHUD.RefreshTickets()
    if ticketLabel then
        ticketLabel:SetText(tostring(SaveSystem.GetPointTickets()))
    end
end

--- 刷新 HUD 显示（金币 + 点券）
function MoneyHUD.Refresh()
    if moneyLabel then
        moneyLabel:SetText(Utils.FormatMoney(cachedMoney))
    end
    MoneyHUD.RefreshTickets()
end

--- 创建金币 HUD 面板（内联，由父容器控制位置）
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

--- 创建点券 HUD 面板（独立面板，与金币并排）
function MoneyHUD.CreateTicketPanel()
    local sz = Utils.sz
    ticketLabel = UI.Label {
        text = tostring(SaveSystem.GetPointTickets()),
        fontSize = sz(15),
        fontColor = { 120, 210, 255, 255 },
        fontWeight = "bold",
    }
    return UI.Panel {
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
                width = sz(18), height = sz(18),
                backgroundImage = "image/point_ticket_icon_20260518210650.png",
                backgroundFit = "contain",
                flexShrink = 0,
            },
            ticketLabel,
        },
    }
end

--- 创建资产弹窗
local watchAdBtn = nil
local watchAdAmountLabel = nil

function MoneyHUD.RefreshWatchAdBtn()
    -- 延迟 require 避免循环依赖
    local ok, AdCardPanel = pcall(require, "UI.AdCardPanel")
    if not ok then return end
    local canWatch = AdCardPanel.CanWatchAd()
    if watchAdBtn then
        watchAdBtn:SetDisabled(not canWatch)
    end
    if watchAdAmountLabel then
        local tier = AdCardPanel.GetCurrentTier()
        if tier and tier.coinsPerAd then
            watchAdAmountLabel:SetText("+" .. Utils.FormatMoney(tier.coinsPerAd))
        end
    end
end

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
            -- 点券行
            UI.Panel {
                width = "100%", flexDirection = "row",
                justifyContent = "space-between", alignItems = "center",
                children = {
                    UI.Panel {
                        flexDirection = "row", alignItems = "center", gap = sz(6),
                        children = {
                            UI.Panel {
                                width = sz(20), height = sz(20),
                                backgroundImage = "image/point_ticket_icon_20260518210650.png",
                                backgroundFit = "contain", flexShrink = 0,
                            },
                            UI.Label { text = "点券", fontSize = sz(13), fontColor = { 200, 205, 220, 255 } },
                        },
                    },
                    UI.Label {
                        id = "popup_point_tickets",
                        text = "0",
                        fontSize = sz(14), fontWeight = "bold",
                        fontColor = { 120, 210, 255, 255 },
                    },
                },
            },
            -- 分割线
            UI.Panel { width = "100%", height = 1, backgroundColor = { 80, 85, 110, 120 } },
            -- 看广告得金币（带图标，与 AdCardPanel watchBtn 样式一致）
            (function()
                local labelNode = UI.Label {
                    text = "看广告",
                    fontSize = sz(13), fontWeight = "bold", fontColor = { 20, 20, 20, 255 },
                }
                local watchAdCoinIcon = UI.Panel {
                    width = sz(16), height = sz(16),
                    backgroundImage = Utils.GetIcon("coin"),
                    backgroundFit = "contain", flexShrink = 0,
                }
                watchAdAmountLabel = UI.Label {
                    text = "",
                    fontSize = sz(13), fontWeight = "bold", fontColor = { 20, 20, 20, 255 },
                }
                local watchAdTicketIcon = UI.Panel {
                    width = sz(16), height = sz(16),
                    backgroundImage = "image/point_ticket_icon_20260518210650.png",
                    backgroundFit = "contain", flexShrink = 0,
                }
                local watchAdTicketQty = UI.Label {
                    text = "×10",
                    fontSize = sz(11), fontColor = { 20, 20, 20, 255 },
                }
                watchAdBtn = UI.Button {
                    width = "100%", height = sz(36),
                    variant = "primary",
                    onClick = function()
                        Utils.PlayClick()
                        MoneyHUD.HidePopup()
                        local AdCardPanel = require("UI.AdCardPanel")
                        if AdCardPanel.CanWatchAd() then
                            AdCardPanel.WatchAd()
                        end
                    end,
                    children = {
                        UI.Panel {
                            flexDirection = "row", alignItems = "center", gap = sz(4),
                            justifyContent = "center", width = "100%", height = "100%",
                            children = {
                                labelNode,
                                watchAdCoinIcon,
                                watchAdAmountLabel,
                                watchAdTicketIcon,
                                watchAdTicketQty,
                            },
                        },
                    },
                }
                return watchAdBtn
            end)(),
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
    -- 更新点券
    local ticketLbl = popupPanel:FindById("popup_point_tickets")
    if ticketLbl then
        ticketLbl:SetText(tostring(SaveSystem.GetPointTickets()))
    end
end

--- 显示/隐藏弹窗
local popupVisible = false

function MoneyHUD.TogglePopup()
    if not popupPanel then return end
    popupVisible = not popupVisible
    if popupVisible then
        refreshPopupContent()
        MoneyHUD.RefreshWatchAdBtn()
    end
    popupPanel:SetVisible(popupVisible)
end

function MoneyHUD.HidePopup()
    if popupPanel then
        popupVisible = false
        popupPanel:SetVisible(false)
    end
end

function MoneyHUD.IsPopupOpen()
    return popupVisible
end

return MoneyHUD
