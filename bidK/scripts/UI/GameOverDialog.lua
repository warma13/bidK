-- ============================================================================
-- UI/GameOverDialog.lua - 结算界面（简约风，左侧浮动信息 + 中间操作面板）
-- 含回收系统：品质筛选 + 快捷回收 + 返回自动打包
-- ============================================================================

local UI = require("urhox-libs/UI")
local Config = require("Config")
local GameState = require("GameState")
local AuctionEngine = require("AuctionEngine")
local Utils = require("UI.Utils")
local UIState = require("UI.UIState")
local SaveSystem = require("SaveSystem")
local WarehouseGrid = require("WarehouseGrid")
local RecycleManager = require("RecycleManager")
local WarehouseUpgrade = require("Config.WarehouseUpgrade")
local MoneyHUD = require("UI.MoneyHUD")
local PlayerListPanel = require("UI.PlayerListPanel")
local MenuScreen -- 延迟加载，避免循环依赖

local GameOverDialog = {}

local refs = UIState.refs

local GS = GameState

---@type table|nil
local settlementPanel = nil
---@type table|nil
local centerActionPanel = nil

-- 回收状态
local recycleState = {
    selectedRarities = {},  -- { white=true, green=true, ... }
    recycledItems = {},     -- 已回收的物品列表
    recycledTotal = 0,      -- 已回收总金额
    lootItems = {},         -- 本局战利品（从 GameState 获取）
}

-- 动画状态
local anim = {
    lootTarget = 0,
    lootDisplay = 0,
    profitTarget = 0,
    profitDisplay = 0,
    winnerPaid = 0,
    lootLabel = nil,
    profitLabel = nil,
    bonusInfoLabel = nil,
    -- 中间面板引用
    skipBtn = nil,
    returnBtn = nil,
    recyclePanel = nil,     -- 回收面板
    recycleBtnRef = nil,    -- 回收按钮引用
    recycleCountLabel = nil, -- 回收件数标签
    recycleValueLabel = nil, -- 回收金额标签
    bonusPanel = nil,
    bonusAmountLabel = nil,
}

local ROLL_SPEED = 6.0

--- 返回主页（处理物品入库逻辑）
local function GoHome()
    -- 本地处理物品入库
    local winner = GS.GetWinner()
    local mySlot = 1
    if winner == mySlot and SaveSystem.IsReady() then
        -- 收集未被回收的物品
        local remaining = {}
        local recycledSet = {}
        for _, item in ipairs(recycleState.recycledItems) do
            recycledSet[item] = true
        end
        for _, item in ipairs(recycleState.lootItems) do
            if not recycledSet[item] then
                remaining[#remaining + 1] = item
            end
        end

        if #remaining > 0 then
            -- 创建仓库网格，加载现有物品
            local capacity = SaveSystem.GetWarehouseCapacity()
            local gridInst = WarehouseGrid.Create(capacity)
            local existingItems = SaveSystem.GetItems()
            WarehouseGrid.Rebuild(gridInst, existingItems)

            -- 尝试放入新物品，空间不足时自动回收
            local placed, autoRecycled, autoRecycledValue =
                RecycleManager.AutoRecycleForFit(remaining, WarehouseGrid, gridInst)

            -- 自动回收的物品变现
            if autoRecycledValue > 0 then
                GS.SecureAddMoney(mySlot, autoRecycledValue, "auto_recycle")
                print("[GameOverDialog] Auto-recycled " .. #autoRecycled
                    .. " items for " .. autoRecycledValue)
            end

            -- 放入仓库的物品保存到存档
            if #placed > 0 then
                SaveSystem.AddWonItems(placed)
            end
            SaveSystem.SaveNow()
        end
    end

    -- 正常返回，清除挂起结算数据
    local PendingSettlement = require("PendingSettlement")
    PendingSettlement.Clear()

    GameOverDialog.Hide()
    -- 统一退出路径：通过 GameSession.Exit() 恢复云端保存 + 导航回大厅
    local GameSession = require("GameSession")
    GameSession.Exit()
end

local confirmModal_ = nil
local function ConfirmGoHome()
    if confirmModal_ then return end
    confirmModal_ = UI.Modal {
        title = "确认返回",
        size = "sm",
        onClose = function()
            confirmModal_ = nil
        end,
        children = {
            UI.Label { text = "确定要返回竞拍大厅吗？", fontSize = 14 },
        },
    }
    local footer = UI.Panel {
        flexDirection = "row",
        justifyContent = "flex-end",
        gap = 10, width = "100%",
    }
    footer:AddChild(UI.Button {
        text = "取消", variant = "secondary",
        onClick = function()
            Utils.PlayClick()
            confirmModal_:Close()
            confirmModal_ = nil
        end,
    })
    footer:AddChild(UI.Button {
        text = "确定", variant = "primary",
        onClick = function()
            Utils.PlayClick()
            confirmModal_:Close()
            confirmModal_ = nil
            GoHome()
        end,
    })
    confirmModal_:SetFooter(footer)
    confirmModal_:Open()
end

--- 计算本局福利金额：赢家亏损的 1/10
local function CalcBonus()
    local totalValue = GS.GetWarehouseTotalValue()
    local winnerPaid = GS.GetWinnerPaid()
    local profit = totalValue - winnerPaid
    if profit >= 0 then
        return 0
    end
    return math.floor(math.abs(profit) / 10)
end

--- 初始化回收品质筛选（默认全选，除了红色）
local function initRecycleRarities()
    recycleState.selectedRarities = {}
    for _, r in ipairs(Config.RARITY) do
        if r.id == "red" then
            recycleState.selectedRarities[r.id] = false
        else
            recycleState.selectedRarities[r.id] = true
        end
    end
end

--- 计算当前筛选下可回收的物品数和金额
local function calcRecyclePreview()
    local count = 0
    local value = 0
    local recycledSet = {}
    for _, item in ipairs(recycleState.recycledItems) do
        recycledSet[item] = true
    end
    for _, item in ipairs(recycleState.lootItems) do
        if not recycledSet[item] then
            local rarity = item.rarity or "white"
            if recycleState.selectedRarities[rarity] then
                count = count + 1
                value = value + RecycleManager.GetRecycleValue(item)
            end
        end
    end
    return count, value
end

--- 更新回收按钮上的文字
local function updateRecycleUI()
    local count, value = calcRecyclePreview()
    if anim.recycleCountLabel then
        anim.recycleCountLabel:SetText("快捷回收(" .. count .. "件)")
    end
    if anim.recycleValueLabel and anim.recycleValueRow then
        if count > 0 then
            anim.recycleValueLabel:SetText("+" .. Utils.FormatMoney(value))
            anim.recycleValueLabel:SetVisible(true)
            anim.recycleValueRow:SetVisible(true)
        else
            anim.recycleValueLabel:SetVisible(false)
            anim.recycleValueRow:SetVisible(false)
        end
    end
end

--- 执行回收
local function doRecycle()
    -- 本地回收
    local recycledSet = {}
    for _, item in ipairs(recycleState.recycledItems) do
        recycledSet[item] = true
    end

    local newRecycled = {}
    local newValue = 0
    for _, item in ipairs(recycleState.lootItems) do
        if not recycledSet[item] then
            local rarity = item.rarity or "white"
            if recycleState.selectedRarities[rarity] then
                newRecycled[#newRecycled + 1] = item
                newValue = newValue + RecycleManager.GetRecycleValue(item)
            end
        end
    end

    if #newRecycled == 0 then return end

    -- 加到已回收列表
    for _, item in ipairs(newRecycled) do
        recycleState.recycledItems[#recycleState.recycledItems + 1] = item
    end
    -- 金额加到钱包（回收不改变总价值和利润，只是物品变现金）
    GS.SecureAddMoney(1, newValue, "manual_recycle")
    -- 刷新左上角金币显示（游戏界面用的是 PlayerListPanel 的金币标签）
    PlayerListPanel.Update()

    -- 同步更新云端挂起数据（兜底保障）
    local PendingSettlement = require("PendingSettlement")
    PendingSettlement.UpdateRecycled(newRecycled, recycleState.lootItems, newValue)

    print("[GameOverDialog] Recycled " .. #newRecycled .. " items for " .. newValue)

    -- 更新 UI
    updateRecycleUI()
end

--- 创建品质菱形筛选按钮
local function createRarityFilter()
    local btns = {}
    for _, r in ipairs(Config.RARITY) do
        local isSelected = recycleState.selectedRarities[r.id]
        local rc = r.color
        -- 选中：浅色填充 + 品质色边框
        local lightBg = { math.min(255, rc[1] + 140), math.min(255, rc[2] + 140), math.min(255, rc[3] + 140), 200 }
        -- 未选中：几乎透明填充 + 暗边框
        local dimBg = { rc[1], rc[2], rc[3], 30 }
        local borderColor = { rc[1], rc[2], rc[3], isSelected and 255 or 80 }
        local diamond = UI.Panel {
            width = 16, height = 16,
            backgroundColor = isSelected and lightBg or dimBg,
            borderWidth = 2,
            borderColor = borderColor,
            borderRadius = 2,
            rotate = 45,
        }
        local btn = UI.Panel {
            width = 28, height = 28,
            justifyContent = "center",
            alignItems = "center",
            cursor = "pointer",
            children = { diamond },
            onClick = function()
                Utils.PlayClick()
                recycleState.selectedRarities[r.id] = not recycleState.selectedRarities[r.id]
                local sel = recycleState.selectedRarities[r.id]
                diamond:SetStyle({
                    backgroundColor = sel and lightBg or dimBg,
                    borderColor = { rc[1], rc[2], rc[3], sel and 255 or 80 },
                })
                updateRecycleUI()
            end,
        }
        btns[r.id] = btn
    end

    -- 将按钮排成一行
    local children = {}
    for _, r in ipairs(Config.RARITY) do
        children[#children + 1] = btns[r.id]
    end
    return children
end

--- 显示结算面板（开箱阶段或 GAME_OVER 阶段均可调用）
function GameOverDialog.Show()
    if settlementPanel then return end

    local winner = GS.GetWinner()
    local winnerPaid = GS.GetWinnerPaid()
    local players = GS.GetPlayers()
    local warehouseName = GS.GetWarehouseName()
    local C = Config.COLORS
    local winnerPlayer = players[winner] or players[1]

    -- 初始化回收状态
    initRecycleRarities()
    recycleState.recycledItems = {}
    recycleState.recycledTotal = 0
    -- 保存本局战利品引用
    do
        recycleState.lootItems = GS.GetWarehouseItems and GS.GetWarehouseItems() or {}
    end

    -- 计算被动效果加成
    local discountRate = GS.GetDiscountRate(winner)
    local valueBonus = GS.GetValueBonus(winner)
    local discountSaved = 0
    if discountRate > 0 then
        local originalPay = math.floor(winnerPaid / (1 - discountRate))
        discountSaved = originalPay - winnerPaid
    end

    -- 构建被动效果说明文本
    local bonusTexts = {}
    if discountRate > 0 then
        bonusTexts[#bonusTexts + 1] = "折扣节省: " .. Utils.FormatMoney(discountSaved) .. " (" .. string.format("%.0f%%", discountRate * 100) .. ")"
    end
    if valueBonus > 0 then
        bonusTexts[#bonusTexts + 1] = "价值加成: +" .. string.format("%.0f%%", valueBonus * 100)
    end

    -- 初始化动画状态
    anim.winnerPaid = winnerPaid
    anim.lootTarget = 0
    anim.lootDisplay = 0
    anim.profitTarget = -winnerPaid
    anim.profitDisplay = -winnerPaid
    anim.valueBonus = valueBonus

    anim.lootLabel = UI.Label {
        text = Utils.FormatMoney(0),
        fontSize = 22,
        fontColor = { 255, 255, 255, 255 },
        fontWeight = "bold",
    }

    anim.profitLabel = UI.Label {
        text = "-" .. Utils.FormatMoney(winnerPaid),
        fontSize = 24,
        fontColor = C.danger,
        fontWeight = "bold",
    }

    anim.bonusInfoLabel = UI.Label {
        text = #bonusTexts > 0 and table.concat(bonusTexts, "  |  ") or "",
        fontSize = 11,
        fontColor = { 255, 220, 100, 200 },
        visible = #bonusTexts > 0,
    }

    -- ====== 左侧浮动信息面板（无背景） ======
    settlementPanel = UI.Panel {
        id = "settlementOverlay",
        position = "absolute",
        left = 0, top = 0,
        width = "44%", height = "100%",
        paddingVertical = "12%",
        paddingHorizontal = "5%",
        flexDirection = "column",
        justifyContent = "center",
        gap = 12,
        pointerEvents = "box-none",
        children = {
            UI.Label {
                text = warehouseName or "未知仓库",
                fontSize = 12,
                fontColor = { 180, 190, 210, 180 },
            },
            UI.Label {
                text = "对局结束",
                fontSize = 28,
                fontColor = { 255, 255, 255, 255 },
                fontWeight = "bold",
            },
            UI.Panel {
                width = 60, height = 2,
                backgroundColor = { 255, 255, 255, 80 },
                marginTop = 4, marginBottom = 4,
            },
            UI.Panel {
                flexDirection = "row", alignItems = "center", gap = 8,
                children = {
                    UI.Panel {
                        width = 40, height = 40,
                        backgroundImage = (winnerPlayer.character and winnerPlayer.character.avatar) or "",
                        backgroundFit = "cover",
                        borderRadius = 0,
                        flexShrink = 0,
                    },
                    UI.Panel {
                        flexDirection = "column", gap = 2,
                        children = {
                            UI.Label {
                                text = "赢家",
                                fontSize = 10,
                                fontColor = { 180, 190, 210, 140 },
                            },
                            UI.Label {
                                text = winnerPlayer.name,
                                fontSize = 16,
                                fontColor = { 255, 255, 255, 255 },
                                fontWeight = "bold",
                            },
                        }
                    },
                }
            },
            UI.Panel { height = 8 },
            UI.Panel {
                flexDirection = "column", gap = 2,
                children = {
                    UI.Label {
                        text = "拍得花费",
                        fontSize = 10,
                        fontColor = { 180, 190, 210, 140 },
                    },
                    UI.Label {
                        text = Utils.FormatMoney(winnerPaid),
                        fontSize = 22,
                        fontColor = { 255, 255, 255, 255 },
                        fontWeight = "bold",
                    },
                }
            },
            UI.Panel {
                flexDirection = "column", gap = 2,
                children = {
                    UI.Label {
                        text = "战利品价值",
                        fontSize = 10,
                        fontColor = { 180, 190, 210, 140 },
                    },
                    anim.lootLabel,
                }
            },
            UI.Panel {
                flexDirection = "column", gap = 2,
                children = {
                    UI.Label {
                        text = "利润",
                        fontSize = 10,
                        fontColor = { 180, 190, 210, 140 },
                    },
                    anim.profitLabel,
                }
            },
            anim.bonusInfoLabel,
        }
    }

    -- ====== 中间操作面板 ======

    -- 跳过动画按钮
    anim.skipBtn = UI.Button {
        text = "跳过动画",
        width = 160, height = 42,
        fontSize = 14,
        onClick = function()
            Utils.PlayClick()
            AuctionEngine.SkipWarehouseOpen()
        end,
    }

    -- ====== 回收面板（赢家专用，GAME_OVER 阶段显示） ======
    anim.recycleCountLabel = UI.Label {
        text = "快捷回收(0件)",
        fontSize = 13,
        fontColor = { 255, 255, 255, 255 },
        fontWeight = "bold",
    }

    anim.recycleValueLabel = UI.Label {
        text = "",
        fontSize = 11,
        fontColor = { 255, 200, 50, 255 },
        visible = false,
    }

    anim.recycleValueRow = UI.Panel {
        flexDirection = "row",
        alignItems = "center",
        justifyContent = "center",
        gap = 2,
        visible = false,
        children = {
            UI.Panel {
                width = 14, height = 14,
                backgroundImage = Utils.GetIcon("coin"),
                backgroundFit = "contain",
                flexShrink = 0,
            },
            anim.recycleValueLabel,
        },
    }

    local rarityFilterBtns = createRarityFilter()

    anim.recyclePanel = UI.Panel {
        flexDirection = "column",
        alignItems = "center",
        gap = 8,
        visible = false,
        children = {
            -- 品质筛选行
            UI.Panel {
                flexDirection = "row",
                alignItems = "center",
                gap = 2,
                children = rarityFilterBtns,
            },
            -- 回收按钮
            UI.Button {
                width = 180, height = 38,
                fontSize = 13,
                onClick = function()
                    Utils.PlayClick()
                    doRecycle()
                end,
                children = {
                    UI.Panel {
                        flexDirection = "column",
                        alignItems = "center",
                        gap = 1,
                        children = {
                            anim.recycleCountLabel,
                            anim.recycleValueRow,
                        },
                    },
                },
            },
        }
    }

    -- 返回按钮
    anim.returnBtn = UI.Button {
        text = "返回",
        width = 160, height = 42,
        fontSize = 14,
        variant = "primary",
        visible = false,
        onClick = function() Utils.PlayClick() ConfirmGoHome() end,
    }

    -- 本局福利面板（别人赢下仓库时显示）
    anim.bonusAmountLabel = UI.Label {
        text = "0",
        fontSize = 22,
        fontColor = { 255, 220, 100, 255 },
        fontWeight = "bold",
    }
    anim.bonusPanel = UI.Panel {
        flexDirection = "column",
        alignItems = "center",
        gap = 8,
        visible = false,
        children = {
            UI.Label {
                text = "本局福利",
                fontSize = 14,
                fontColor = { 255, 255, 255, 200 },
            },
            UI.Panel {
                flexDirection = "row", alignItems = "center", gap = 6,
                children = {
                    anim.bonusAmountLabel,
                },
            },
            (function()
                anim.bonusBtn = UI.Button {
                    text = "领取并返回",
                    width = 160, height = 42,
                    fontSize = 14,
                    variant = "primary",
                    onClick = function() Utils.PlayClick() ConfirmGoHome() end,
                }
                return anim.bonusBtn
            end)(),
        }
    }

    centerActionPanel = UI.Panel {
        id = "centerActionPanel",
        position = "absolute",
        left = "30%", top = 0,
        width = "34%", height = "100%",
        flexDirection = "column",
        justifyContent = "center",
        alignItems = "center",
        gap = 10,
        pointerEvents = "box-none",
        children = {
            anim.skipBtn,
            anim.recyclePanel,
            anim.returnBtn,
            anim.bonusPanel,
        }
    }

    if refs.gameRoot then
        refs.gameRoot:AddChild(settlementPanel)
        refs.gameRoot:AddChild(centerActionPanel)
    end
end

--- 当物品被揭示时调用，累加战利品价值
function GameOverDialog.OnItemRevealed(item)
    if not settlementPanel then return end
    local val = item.realValue or Config.GetItemRealValue(item)
    local bonus = anim.valueBonus or 0
    local bonusVal = math.floor(val * (1 + bonus))
    anim.lootTarget = anim.lootTarget + bonusVal
    anim.profitTarget = anim.lootTarget - anim.winnerPaid
end

--- 进入 GAME_OVER 阶段时调用
function GameOverDialog.OnGameOver()
    if not settlementPanel then return end
    local C = Config.COLORS

    -- 确保最终值正确（含价值加成）
    local totalValue = GS.GetWarehouseTotalValue()
    local bonus = anim.valueBonus or 0
    local boostedTotal = math.floor(totalValue * (1 + bonus))
    anim.lootTarget = boostedTotal
    anim.profitTarget = boostedTotal - anim.winnerPaid

    -- 隐藏跳过按钮
    if anim.skipBtn then
        anim.skipBtn:SetVisible(false)
    end

    -- 判断赢家是否是玩家本人
    local winner = GS.GetWinner()
    local mySlot = 1
    if winner == mySlot then
        -- 玩家本人赢了 → 显示回收面板和返回按钮
        if anim.recyclePanel then
            anim.recyclePanel:SetVisible(true)
            updateRecycleUI()
        end
        if anim.returnBtn then anim.returnBtn:SetVisible(true) end
    else
        -- 别人赢了 → 显示本局福利
        local loseBonus = CalcBonus()
        if anim.bonusAmountLabel then
            if loseBonus > 0 then
                anim.bonusAmountLabel:SetText(Utils.FormatMoney(loseBonus))
                if anim.bonusBtn then anim.bonusBtn:SetText("领取并返回") end
            else
                anim.bonusAmountLabel:SetText("无")
                if anim.bonusBtn then anim.bonusBtn:SetText("返回") end
            end
        end
        if anim.bonusPanel then anim.bonusPanel:SetVisible(true) end
    end
end

--- 每帧更新数字滚动动画
function GameOverDialog.Update(dt)
    if not settlementPanel then return end
    local C = Config.COLORS

    -- 战利品价值滚动
    if math.abs(anim.lootDisplay - anim.lootTarget) > 1 then
        anim.lootDisplay = anim.lootDisplay + (anim.lootTarget - anim.lootDisplay) * math.min(1, ROLL_SPEED * dt)
        if math.abs(anim.lootDisplay - anim.lootTarget) < 10 then
            anim.lootDisplay = anim.lootTarget
        end
    else
        anim.lootDisplay = anim.lootTarget
    end

    -- 利润滚动
    if math.abs(anim.profitDisplay - anim.profitTarget) > 1 then
        anim.profitDisplay = anim.profitDisplay + (anim.profitTarget - anim.profitDisplay) * math.min(1, ROLL_SPEED * dt)
        if math.abs(anim.profitDisplay - anim.profitTarget) < 10 then
            anim.profitDisplay = anim.profitTarget
        end
    else
        anim.profitDisplay = anim.profitTarget
    end

    if anim.lootLabel then
        anim.lootLabel:SetText(Utils.FormatMoney(math.floor(anim.lootDisplay)))
    end

    if anim.profitLabel then
        local displayProfit = math.floor(anim.profitDisplay)
        local profitColor = displayProfit >= 0 and C.success or C.danger
        local profitPrefix = displayProfit >= 0 and "+" or "-"
        local profitText = profitPrefix .. Utils.FormatMoney(math.abs(displayProfit))
        anim.profitLabel:SetText(profitText)
        anim.profitLabel:SetStyle({ fontColor = profitColor })
    end
end

function GameOverDialog.Hide()
    if settlementPanel then
        settlementPanel:Remove()
        settlementPanel = nil
    end
    if centerActionPanel then
        centerActionPanel:Remove()
        centerActionPanel = nil
    end
    anim.lootLabel = nil
    anim.profitLabel = nil
    anim.bonusInfoLabel = nil
    anim.valueBonus = 0
    anim.skipBtn = nil
    anim.returnBtn = nil
    anim.recyclePanel = nil
    anim.recycleCountLabel = nil
    anim.recycleValueLabel = nil
    anim.recycleValueRow = nil
    anim.bonusPanel = nil
    anim.bonusAmountLabel = nil
    -- 清理回收状态
    recycleState.selectedRarities = {}
    recycleState.recycledItems = {}
    recycleState.recycledTotal = 0
    recycleState.lootItems = {}
end

function GameOverDialog.IsVisible()
    return settlementPanel ~= nil
end

return GameOverDialog
