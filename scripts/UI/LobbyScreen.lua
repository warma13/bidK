-- ============================================================================
-- UI/LobbyScreen.lua - 竞拍大厅（选角色/仓库/难度/道具）
-- ============================================================================

local UI = require("urhox-libs/UI")
local Config = require("Config")
local UIState = require("UI.UIState")
local MoneyHUD = require("UI.MoneyHUD")
local Utils = require("UI.Utils")
local DebugPanel = require("UI.DebugPanel")
local LobbyScreen = {}

---@param regionIdx number
---@param onBackCallback fun()
---@param onStartCallback fun(regionId: string, charIdx: number, diffIdx: number)
function LobbyScreen.Show(regionIdx, onBackCallback, onStartCallback)
    UIState.currentScreen = "lobby"
    UIState.selectedRegionIdx = regionIdx
    UIState.selectedDifficultyIdx = 1

    local C = Config.COLORS
    local region = Config.REGIONS[regionIdx]
    if not region then return end

    local selectedCharIdx = UIState.selectedCharIdx or 1

    -- =========================================================================
    -- 左侧右列：角色详情控件
    -- =========================================================================
    local charTitleLabel = UI.Label {
        text = "", fontSize = 11,
        fontColor = C.accent, fontWeight = "bold",
    }
    local charNameLabel = UI.Label {
        text = "", fontSize = 18,
        fontColor = C.textPrimary, fontWeight = "bold",
    }
    local charDescLabel = UI.Label {
        text = "", fontSize = 10,
        fontColor = C.textSecondary, lineHeight = 1.5,
        whiteSpace = "normal", width = "100%", flexShrink = 1,
    }
    local charSkillLabel = UI.Label {
        text = "", fontSize = 10,
        fontColor = { 180, 220, 255, 255 }, lineHeight = 1.3,
        whiteSpace = "normal", width = "100%", flexShrink = 1,
    }

    -- =========================================================================
    -- 右侧：仓库信息控件
    -- =========================================================================
    local warehouseNameLabel = UI.Label {
        text = "", fontSize = 14,
        fontColor = C.accent, fontWeight = "bold",
    }
    local warehouseDescLabel = UI.Label {
        text = "", fontSize = 10,
        fontColor = C.textSecondary, lineHeight = 1.3,
        whiteSpace = "normal", width = "100%", flexShrink = 1,
    }

    -- =========================================================================
    -- 难度选择
    -- =========================================================================
    local maxDiffCount = 0
    for _, r in ipairs(Config.REGIONS) do
        local n = r.difficulties and #r.difficulties or 0
        if n > maxDiffCount then maxDiffCount = n end
    end

    local diffBtns = {}
    local diffBtnLabels = {}
    local entryFeeLabel = UI.Label {
        text = "", fontSize = 11,
        fontColor = { 160, 220, 160, 255 },
    }
    local assetReqLabel = UI.Label {
        text = "", fontSize = 11,
        fontColor = { 180, 180, 220, 255 },
    }

    local function refreshDiffSelection()
        local difficulties = region.difficulties or {}
        for i = 1, maxDiffCount do
            if i <= #difficulties then
                diffBtns[i]:SetStyle({ display = "flex" })
                diffBtnLabels[i]:SetText(difficulties[i].label)
                if i == UIState.selectedDifficultyIdx then
                    diffBtns[i]:SetStyle({
                        borderColor = C.accent, borderWidth = 2,
                        backgroundColor = { 60, 65, 90, 240 },
                    })
                else
                    diffBtns[i]:SetStyle({
                        borderColor = C.gridSlotBorder, borderWidth = 1,
                        backgroundColor = { 35, 40, 60, 180 },
                    })
                end
            else
                diffBtns[i]:SetStyle({ display = "none" })
            end
        end
        local diff = difficulties[UIState.selectedDifficultyIdx]
        if diff then
            if diff.entryFee <= 0 then
                entryFeeLabel:SetText("入场费: 免费")
                entryFeeLabel:SetStyle({ fontColor = { 160, 220, 160, 255 } })
            else
                entryFeeLabel:SetText("入场费: " .. Utils.FormatMoney(diff.entryFee))
                entryFeeLabel:SetStyle({ fontColor = { 255, 220, 100, 255 } })
            end
            -- 资产需求显示（仅收费场次显示）
            local expectedVal = diff.expectedValue or 0
            if diff.entryFee > 0 and expectedVal > 0 then
                local currentMoney = MoneyHUD.GetMoney()
                assetReqLabel:SetText("资产需求: " .. Utils.FormatMoney(expectedVal))
                assetReqLabel:SetStyle({ display = "flex" })
                if currentMoney >= expectedVal then
                    assetReqLabel:SetStyle({ fontColor = { 160, 220, 160, 255 } })
                else
                    assetReqLabel:SetStyle({ fontColor = { 255, 100, 100, 255 } })
                end
            else
                assetReqLabel:SetStyle({ display = "none" })
            end
        end
    end

    local diffRow = {}
    for i = 1, maxDiffCount do
        local label = UI.Label { text = "", fontSize = 11, fontColor = C.textPrimary, textAlign = "center" }
        diffBtnLabels[i] = label
        local idx = i
        local btn = UI.Panel {
            height = 28, flexGrow = 1,
            backgroundColor = { 35, 40, 60, 180 },
            borderRadius = 0, borderWidth = 1,
            borderColor = C.gridSlotBorder,
            justifyContent = "center", alignItems = "center",
            cursor = "pointer",
            onClick = function()
                Utils.PlayClick()
                UIState.selectedDifficultyIdx = idx
                refreshDiffSelection()
            end,
            children = { label },
        }
        diffBtns[i] = btn
        diffRow[#diffRow + 1] = btn
    end

    -- =========================================================================
    -- 右侧：道具栏
    -- =========================================================================
    local pocketSlots = {}
    local POCKET_SIZE = 5
    for i = 1, POCKET_SIZE do
        pocketSlots[i] = UI.Panel {
            width = 32, height = 32,
            backgroundColor = { 45, 50, 70, 180 },
            borderRadius = 0, borderWidth = 1,
            borderColor = C.gridSlotBorder,
        }
    end

    -- =========================================================================
    -- 中间：角色全身立绘
    -- =========================================================================
    local portraitPanel = UI.Panel {
        width = "100%", height = "100%",
        backgroundImage = "",
        backgroundFit = "contain",
    }
    local centerPortraitPanel = UI.Panel {
        flexGrow = 1, flexShrink = 1,
        overflow = "hidden",
        children = { portraitPanel },
    }

    -- =========================================================================
    -- 左侧：角色头像列表
    -- =========================================================================
    local avatarPanels = {}

    local function refreshCharInfo()
        local ch = Config.CHARACTERS[selectedCharIdx]
        if not ch then return end

        charTitleLabel:SetText(ch.ability)
        charNameLabel:SetText(ch.name)

        charDescLabel:SetText(ch.desc or "")

        -- 专精品类提示
        local skillText = ""
        if ch.specialty then
            if type(ch.specialty) == "table" then
                local names = {}
                for _, c in ipairs(ch.specialty) do
                    local info = Config.GetCategory(c)
                    names[#names + 1] = info and info.name or c
                end
                skillText = "擅长: " .. table.concat(names, "、")
            else
                local info = Config.GetCategory(ch.specialty)
                skillText = "擅长: " .. (info and info.name or ch.specialty)
            end
        else
            skillText = "通才型: 不限品类"
        end
        charSkillLabel:SetText(skillText)

        -- 更新全身立绘
        if ch.portrait then
            portraitPanel:SetStyle({ backgroundImage = ch.portrait })
        end

        -- 更新头像高亮
        for i, panel in ipairs(avatarPanels) do
            if i == selectedCharIdx then
                panel:SetStyle({
                    borderColor = C.accent, borderWidth = 2,
                })
            else
                panel:SetStyle({
                    borderColor = { 60, 65, 80, 150 }, borderWidth = 1,
                })
            end
        end

        UIState.selectedCharIdx = selectedCharIdx
    end

    for i, ch in ipairs(Config.CHARACTERS) do
        local avatar = UI.Panel {
            width = 48, height = 48, flexShrink = 0,
            backgroundImage = ch.avatar,
            backgroundFit = "cover",
            borderRadius = 4, borderWidth = 1,
            borderColor = { 60, 65, 80, 150 },
            cursor = "pointer",
            onTap = function()
                Utils.PlayClick()
                selectedCharIdx = i
                refreshCharInfo()
            end,
        }
        avatarPanels[#avatarPanels + 1] = avatar
    end

    -- =========================================================================
    -- 刷新仓库信息
    -- =========================================================================
    local function refreshWarehouseInfo()
        local typeNames = {}
        for _, typeId in ipairs(region.warehouseTypes) do
            local wt = Config.WAREHOUSE_TYPES[typeId]
            if wt then typeNames[#typeNames + 1] = wt.name end
        end
        warehouseNameLabel:SetText(table.concat(typeNames, " / "))
        warehouseDescLabel:SetText(region.desc)
    end

    -- =========================================================================
    -- 底部：仓库类型图标
    -- =========================================================================
    local warehouseIcons = {}
    for _, key in ipairs(region.warehouseTypes) do
        local wt = Config.WAREHOUSE_TYPES[key]
        if wt then
            warehouseIcons[#warehouseIcons + 1] = UI.Panel {
                height = 40,
                paddingHorizontal = 8,
                backgroundColor = { 60, 65, 90, 240 },
                borderRadius = 0, borderWidth = 2,
                borderColor = C.accent,
                justifyContent = "center", alignItems = "center",
                flexShrink = 0,
                children = {
                    UI.Label {
                        text = wt.name or key,
                        fontSize = 10, fontColor = C.textPrimary,
                        textAlign = "center",
                    },
                },
            }
        end
    end

    -- =========================================================================
    -- 构建左侧面板（头像列表 + 角色详情，左右分栏）
    -- =========================================================================
    local leftPanel = UI.Panel {
        width = 220, flexShrink = 0,
        flexDirection = "row", gap = 8,
        overflow = "hidden",
        backgroundColor = { 15, 18, 28, 180 },
        borderRadius = 4,
        padding = 8,
        children = {
            -- 左列：头像滚动列表
            UI.ScrollView {
                width = 56, flexShrink = 0,
                scrollX = false, scrollY = true,
                showScrollbar = false,
                children = {
                    UI.Panel {
                        width = "100%",
                        flexDirection = "column", gap = 4,
                        children = avatarPanels,
                    },
                },
            },
            -- 右列：选中角色详情
            UI.Panel {
                flexGrow = 1, flexShrink = 1,
                flexDirection = "column", gap = 4,
                children = {
                    -- 称号
                    UI.Panel {
                        flexDirection = "row", alignItems = "center", gap = 3,
                        flexShrink = 0,
                        children = {
                            UI.Panel { width = 3, height = 12, backgroundColor = C.accent, flexShrink = 0 },
                            charTitleLabel,
                        },
                    },
                    -- 名字
                    charNameLabel,
                    -- 描述
                    charDescLabel,
                    -- 技能
                    charSkillLabel,
                },
            },
        },
    }

    -- =========================================================================
    -- 构建右侧面板
    -- =========================================================================
    local rightContent = UI.Panel {
        width = "100%",
        flexDirection = "column", gap = 8,
        children = {
            -- 仓库信息卡
            UI.Panel {
                width = "100%",
                backgroundColor = { 30, 35, 55, 220 },
                borderRadius = 0, borderWidth = 1,
                borderColor = C.gridSlotBorder,
                padding = 8, gap = 4,
                flexDirection = "column", flexShrink = 0,
                children = {
                    UI.Label { text = "仓库信息", fontSize = 10, fontColor = C.textMuted },
                    warehouseNameLabel,
                    warehouseDescLabel,
                    UI.Panel {
                        flexDirection = "row", justifyContent = "space-between",
                        children = {
                            UI.Label { text = "拍卖轮数", fontSize = 10, fontColor = C.textMuted },
                            UI.Label { text = tostring(Config.GAME.MaxRounds), fontSize = 10, fontColor = C.textPrimary },
                        },
                    },
                    UI.Panel {
                        flexDirection = "row", justifyContent = "space-between",
                        children = {
                            UI.Label { text = "竞拍人数", fontSize = 10, fontColor = C.textMuted },
                            UI.Label { text = tostring(Config.GAME.MaxPlayers) .. "人", fontSize = 10, fontColor = C.textPrimary },
                        },
                    },
                },
            },
            -- 选择场次
            UI.Panel {
                width = "100%",
                backgroundColor = { 30, 35, 55, 220 },
                borderRadius = 0, borderWidth = 1,
                borderColor = C.gridSlotBorder,
                padding = 8, gap = 4,
                flexDirection = "column", flexShrink = 0,
                children = {
                    UI.Label { text = "选择场次", fontSize = 10, fontColor = C.textMuted },
                    UI.Panel {
                        flexDirection = "row", gap = 4,
                        children = diffRow,
                    },
                    entryFeeLabel,
                    assetReqLabel,
                },
            },
            -- 道具栏
            UI.Panel {
                width = "100%",
                backgroundColor = { 30, 35, 55, 220 },
                borderRadius = 0, borderWidth = 1,
                borderColor = C.gridSlotBorder,
                padding = 8, gap = 4,
                flexDirection = "column", flexShrink = 0,
                children = {
                    UI.Panel {
                        flexDirection = "row", justifyContent = "space-between", alignItems = "center",
                        children = {
                            UI.Label { text = "口袋: 0/" .. POCKET_SIZE, fontSize = 10, fontColor = C.textMuted },
                            UI.Button {
                                text = "配置道具", fontSize = 10,
                                width = 64, height = 26,
                                onClick = function()
                                    Utils.PlayClick()
                                    print("[LobbyScreen] Configure items - TODO")
                                end,
                            },
                        },
                    },
                    UI.Panel {
                        flexDirection = "row", gap = 3,
                        children = pocketSlots,
                    },
                },
            },
        },
    }

    -- =========================================================================
    -- 主布局: column { topBar, contentRow, bottomBar }
    -- =========================================================================
    local lobbyBg = (region.bg and region.bg ~= "") and region.bg or nil
    local lobbyRoot = UI.Panel {
        width = "100%", height = "100%",
        backgroundColor = C.bgDark,
        backgroundImage = lobbyBg,
        backgroundFit = "cover",
        flexDirection = "column",
        children = {
            -- ==================== 顶部栏 ====================
            UI.Panel {
                width = "100%", height = 44, flexShrink = 0,
                paddingHorizontal = 12,
                flexDirection = "row", alignItems = "center",
                backgroundColor = { 0, 0, 0, 180 },
                gap = 8,
                children = {
                    UI.Label { text = "竞拍大厅", fontSize = 16, fontColor = C.accent, fontWeight = "bold" },
                    UI.Label { text = "- " .. region.name, fontSize = 12, fontColor = C.textSecondary },
                },
            },

            -- ==================== 中间内容区（三列） ====================
            UI.Panel {
                width = "100%", flexGrow = 1, flexShrink = 1,
                flexDirection = "row",
                padding = 10, gap = 10,
                overflow = "hidden",
                children = {
                    -- 左列：角色头像列表 + 详情（内部左右分栏）
                    leftPanel,

                    -- 中列：角色全身立绘
                    centerPortraitPanel,

                    -- 右列：可滚动配置面板
                    UI.ScrollView {
                        width = 220, flexShrink = 0,
                        scrollX = false, scrollY = true,
                        showScrollbar = false,
                        children = { rightContent },
                    },
                },
            },

            -- ==================== 底部栏 ====================
            UI.Panel {
                width = "100%", height = 56, flexShrink = 0,
                paddingHorizontal = 12,
                flexDirection = "row", alignItems = "center",
                backgroundColor = { 0, 0, 0, 180 },
                gap = 8,
                children = {
                    -- 返回按钮
                    UI.Button {
                        text = "←", fontSize = 18,
                        width = 40, height = 40,
                        onClick = function()
                            Utils.PlayClick()
                            if onBackCallback then onBackCallback() end
                        end,
                    },
                    -- 仓库类型图标
                    UI.Panel {
                        flexDirection = "row", gap = 4, alignItems = "center",
                        flexShrink = 1,
                        children = warehouseIcons,
                    },
                    -- 弹性填充
                    UI.Panel { flexGrow = 1 },
                    -- 开始行动按钮
                    UI.Button {
                        text = "开始行动",
                        variant = "primary",
                        width = 140, height = 44,
                        fontSize = 15,
                        onClick = function()
                            Utils.PlayClick()
                            local diffs = region.difficulties or {}
                            local diff = diffs[UIState.selectedDifficultyIdx]
                            if diff then
                                local currentMoney = MoneyHUD.GetMoney()
                                -- 检查入场费
                                if diff.entryFee > 0 and currentMoney < diff.entryFee then
                                    print("[LobbyScreen] Insufficient funds for entry fee")
                                    return
                                end
                                -- 检查资产需求（仅收费场次）
                                local expectedVal = diff.expectedValue or 0
                                if diff.entryFee > 0 and expectedVal > 0 and currentMoney < expectedVal then
                                    print("[LobbyScreen] Insufficient assets: need " .. expectedVal .. ", have " .. currentMoney)
                                    return
                                end
                            end
                            if onStartCallback then
                                onStartCallback(region.id, selectedCharIdx, UIState.selectedDifficultyIdx)
                            end
                        end,
                    },
                },
            },
        },
    }

    -- 创建最终根容器
    local finalRoot = UI.Panel {
        width = "100%", height = "100%",
        children = {
            lobbyRoot,
            MoneyHUD.CreatePanel(),
            DebugPanel.CreateHUD(),
        },
    }

    UI.SetRoot(finalRoot)

    -- 初始化
    refreshCharInfo()
    refreshWarehouseInfo()
    refreshDiffSelection()
end

return LobbyScreen
