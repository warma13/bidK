-- ============================================================================
-- UI/Warehouse/UpgradePanel.lua - 仓库升级弹窗
-- 依赖 ctx（共享上下文），由 MyWarehousePanel 初始化并传入
-- ============================================================================

local UI = require("urhox-libs/UI")
local Utils = require("UI.Utils")
local MoneyHUD = require("UI.MoneyHUD")
local MoneyManager = require("MoneyManager")
local SaveSystem = require("SaveSystem")
local WarehouseUpgrade = require("Config.WarehouseUpgrade")

local UpgradePanel = {}

-- ============================================================================
-- 等级/容量显示
-- ============================================================================

function UpgradePanel.UpdateLevelDisplay(ctx)
    local level = SaveSystem.GetWarehouseLevel()
    local capacity = SaveSystem.GetWarehouseCapacity()
    local usedCells = 0
    for _, item in ipairs(ctx.allItems) do
        local w = item.w or 1
        local h = item.h or 1
        usedCells = usedCells + (w * h)
    end
    if ctx.levelLabel then
        ctx.levelLabel:SetText("Lv." .. level)
    end
    if ctx.capacityLabel then
        local rows = WarehouseUpgrade.GetRows(level)
        ctx.capacityLabel:SetText(usedCells .. "/" .. capacity .. " 格 (" .. rows .. "行)")
    end
    if ctx.upgradeBtn then
        ctx.upgradeBtn:SetVisible(level < WarehouseUpgrade.MAX_LEVEL)
    end
end

-- ============================================================================
-- 升级操作
-- ============================================================================

local function hideUpgradePopup(ctx)
    if ctx.upgradePopup then
        ctx.upgradePopup:SetVisible(false)
    end
end

local function doUpgrade(ctx)
    local gold = MoneyHUD.GetMoney()
    local success, err = SaveSystem.UpgradeWarehouse(gold, function(amount)
        MoneyHUD.SetMoney(gold - amount)
    end)
    if success then
        MoneyManager.PersistMenuMoney("warehouse_upgrade", {
            ok = function()
                print("[Warehouse] Upgrade money persisted")
            end,
            error = function(code, reason)
                print("[Warehouse] Upgrade money persist FAILED: " .. tostring(reason))
            end,
        })

        ctx.allItems = SaveSystem.GetItems()
        table.sort(ctx.allItems, function(a, b)
            return (a.wonAt or 0) > (b.wonAt or 0)
        end)
        UpgradePanel.UpdateLevelDisplay(ctx)
        ctx._refreshCards()
        hideUpgradePopup(ctx)
        local newRows = WarehouseUpgrade.GetRows(SaveSystem.GetWarehouseLevel())
        Utils.ShowMessage("升级成功！仓库已扩展至 " .. newRows .. " 行（" .. SaveSystem.GetWarehouseCapacity() .. " 格）")
    end
end

function UpgradePanel.ShowPopup(ctx)
    local level = SaveSystem.GetWarehouseLevel()
    if level >= WarehouseUpgrade.MAX_LEVEL then return end

    local gold = MoneyHUD.GetMoney()
    local canUpgrade, details = WarehouseUpgrade.CheckUpgrade(level, gold)
    local cost = WarehouseUpgrade.GetUpgradeCost(level)
    if not cost or not details then return end

    local curRows  = WarehouseUpgrade.GetRows(level)
    local nextRows = WarehouseUpgrade.GetRows(level + 1)
    local addRows  = nextRows - curRows
    local nextCapacity = WarehouseUpgrade.GetCapacity(level + 1)

    local goldColor = details.gold.ok
        and { 255, 220, 100, 255 }
        or  { 255, 80, 80, 255 }

    local confirmBtn = UI.Button {
        text = canUpgrade and "确认升级" or "金币不足",
        width = 120, height = 34,
        fontSize = 13,
        fontWeight = "bold",
        backgroundColor = canUpgrade
            and { 50, 140, 80, 240 }
            or  { 80, 80, 80, 200 },
        fontColor = canUpgrade
            and { 255, 255, 255, 255 }
            or  { 120, 120, 120, 200 },
        borderRadius = 0,
        borderWidth = 1,
        borderColor = canUpgrade
            and { 80, 200, 120, 200 }
            or  { 100, 100, 100, 150 },
        onClick = function()
            if canUpgrade then
                Utils.PlayClick()
                doUpgrade(ctx)
            end
        end,
    }

    local cancelBtn = UI.Button {
        text = "取消",
        width = 80, height = 34,
        fontSize = 13,
        backgroundColor = { 55, 60, 72, 220 },
        fontColor = { 180, 185, 200, 255 },
        borderRadius = 0,
        borderWidth = 1,
        borderColor = { 80, 85, 100, 160 },
        onClick = function()
            Utils.PlayClick()
            hideUpgradePopup(ctx)
        end,
    }

    local card = UI.Panel {
        width = 320,
        backgroundColor = { 30, 34, 44, 250 },
        borderRadius = 0,
        borderWidth = 1,
        borderColor = { 90, 100, 130, 200 },
        padding = { 20, 16 },
        flexDirection = "column",
        gap = 4,
        children = {
            UI.Label {
                text = "仓库升级 Lv." .. level .. " → Lv." .. (level + 1),
                fontSize = 16,
                fontColor = { 255, 220, 100, 255 },
                fontWeight = "bold",
                textAlign = "center",
                width = "100%",
            },
            UI.Label {
                text = "行数: " .. curRows .. " → " .. nextRows .. " 行 (+" .. addRows .. "行)",
                fontSize = 12,
                fontColor = { 180, 190, 210, 220 },
                textAlign = "center",
                width = "100%",
            },
            UI.Label {
                text = "容量: " .. WarehouseUpgrade.GetCapacity(level) .. " → " .. nextCapacity .. " 格",
                fontSize = 12,
                fontColor = { 150, 160, 180, 200 },
                textAlign = "center",
                width = "100%",
                marginBottom = 8,
            },
            UI.Panel { width = "100%", height = 1, backgroundColor = { 60, 65, 80, 200 }, marginBottom = 8 },
            UI.Label {
                text = "升级费用",
                fontSize = 13,
                fontColor = { 160, 168, 185, 220 },
                width = "100%",
                marginBottom = 6,
            },
            UI.Panel {
                width = "100%",
                flexDirection = "row",
                alignItems = "center",
                gap = 6,
                paddingVertical = 3,
                children = {
                    UI.Panel {
                        width = 14, height = 14,
                        backgroundImage = Utils.GetIcon("coin"),
                        backgroundFit = "contain",
                    },
                    UI.Label {
                        text = Utils.FormatMoney(cost.gold),
                        fontSize = 14,
                        fontColor = goldColor,
                        fontWeight = "bold",
                        flexGrow = 1,
                    },
                    UI.Label {
                        text = details.gold.ok and "足够" or "不足",
                        fontSize = 12,
                        fontColor = details.gold.ok
                            and { 100, 220, 120, 255 }
                            or  { 255, 80, 80, 255 },
                    },
                },
            },
            UI.Panel { width = "100%", height = 1, backgroundColor = { 60, 65, 80, 200 }, marginTop = 10, marginBottom = 10 },
            UI.Panel {
                width = "100%",
                flexDirection = "row",
                justifyContent = "center",
                gap = 12,
                children = { cancelBtn, confirmBtn },
            },
        },
    }

    -- 移除旧弹窗
    if ctx.upgradePopup then
        ctx.upgradePopup:SetVisible(false)
        ctx.upgradePopup:Remove()
    end

    ctx.upgradePopup = UI.Panel {
        position = "absolute",
        left = 0, top = 0, right = 0, bottom = 0,
        backgroundColor = { 0, 0, 0, 160 },
        justifyContent = "center",
        alignItems = "center",
        visible = true,
        onClick = function()
            Utils.PlayClick()
            hideUpgradePopup(ctx)
        end,
        children = {
            UI.Panel { onClick = function() end, children = { card } },
        },
    }

    return ctx.upgradePopup
end

return UpgradePanel
