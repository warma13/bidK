-- ============================================================================
-- UI/LobbyScreen.lua - 竞拍大厅（选角色/仓库/难度/道具）
-- ============================================================================

local UI = require("urhox-libs/UI")
local Config = require("Config")
local UIState = require("UI.UIState")
local MoneyHUD = require("UI.MoneyHUD")
local Utils = require("UI.Utils")
local DebugPanel = require("UI.DebugPanel")
local SaveSystem = require("SaveSystem")

local FloatingMessage = require("UI.FloatingMessage")
local LobbyScreen = {}

---@param regionIdx number
---@param onBackCallback fun()
---@param onStartCallback fun(regionId: string, charIdx: number, diffIdx: number)
function LobbyScreen.Show(regionIdx, onBackCallback, onStartCallback)
    UIState.currentScreen = "lobby"
    UIState.selectedRegionIdx = regionIdx

    local C = Config.COLORS
    local region = Config.REGIONS[regionIdx]
    if not region then return end

    -- 从存档读取上次选择的场次
    local settings = SaveSystem.GetSettings()
    local lastDiffKey = "lastDiff_" .. region.id
    local savedDiffIdx = settings[lastDiffKey]
    local difficulties = region.difficulties or {}
    if savedDiffIdx and savedDiffIdx >= 1 and savedDiffIdx <= #difficulties then
        UIState.selectedDifficultyIdx = savedDiffIdx
    else
        UIState.selectedDifficultyIdx = 1
    end

    local selectedCharIdx = UIState.selectedCharIdx or 1

    --- 判断角色是否处于锁定状态
    local function isCharLocked(ch)
        if not ch.locked then return false end
        return not SaveSystem.IsCharacterUnlocked(ch.id)
    end

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

    -- 前向声明（解锁按钮 onClick 中引用）
    local avatarLockOverlays = {}
    local refreshCharInfo  -- 后面赋值

    -- 角色币显示（图标 + 数字）
    local charCoinText = UI.Label {
        text = "", fontSize = 10,
        fontColor = { 255, 200, 80, 255 },
    }
    local charCoinLabel = UI.Panel {
        flexDirection = "row", alignItems = "center", gap = 4,
        visible = false,
        children = {
            UI.Panel {
                width = 14, height = 14,
                backgroundImage = Config.CHARACTER_COIN_ICON,
                backgroundFit = "contain", flexShrink = 0,
            },
            charCoinText,
        },
    }

    -- 解锁按钮
    local unlockBtn = UI.Button {
        text = "解锁", width = "100%", height = 28,
        fontSize = 11, variant = "primary",
        visible = false,
        onClick = function()
            Utils.PlayClick()
            local ch = Config.CHARACTERS[selectedCharIdx]
            if not ch or not ch.locked then return end
            local cost = ch.unlockCost or 20
            if SaveSystem.GetCharacterCoins() < cost then
                FloatingMessage.Show("角色币不足，需要 " .. cost .. " 个")
                return
            end
            if not SaveSystem.SpendCharacterCoins(cost) then
                FloatingMessage.Show("角色币不足")
                return
            end
            SaveSystem.UnlockCharacter(ch.id)
            SaveSystem.MarkDirty()
            -- 刷新 UI
            avatarLockOverlays[selectedCharIdx]:SetVisible(false)
            refreshCharInfo()
            FloatingMessage.Show("🎉 成功解锁 " .. ch.name .. "!")
        end,
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
        text = "", fontSize = 10,
        fontColor = { 160, 220, 160, 255 }, flexShrink = 0,
    }
    local assetReqLabel = UI.Label {
        text = "", fontSize = 10,
        fontColor = { 180, 180, 220, 255 }, flexShrink = 0,
    }
    local ticketIcon = UI.Panel {
        width = 20, height = 12,
        backgroundFit = "contain",
        flexShrink = 0, display = "none",
    }
    local ticketLabel = UI.Label {
        text = "", fontSize = 10,
        fontColor = { 255, 200, 80, 255 }, flexShrink = 0,
    }

    -- 开始行动按钮（提前创建以便 refreshDiffSelection 更新文本）
    local startBtnRef = UI.Button {
        text = "开始行动",
        variant = "primary",
        width = 160, height = 44,
        fontSize = 15,
        onClick = function()
            Utils.PlayClick()
            -- 检查角色是否锁定
            local selChar = Config.CHARACTERS[selectedCharIdx]
            if selChar and isCharLocked(selChar) then
                FloatingMessage.Show("该角色尚未解锁")
                return
            end
            local diffs = region.difficulties or {}
            local diff = diffs[UIState.selectedDifficultyIdx]
            if diff then
                local currentMoney = MoneyHUD.GetMoney()
                -- 检查入场费
                if diff.entryFee > 0 and currentMoney < diff.entryFee then
                    print("[LobbyScreen] Insufficient funds for entry fee")
                    return
                end
                -- 检查资产需求
                local assetReq = diff.assetRequirement or 0
                if assetReq > 0 and currentMoney < assetReq then
                    print("[LobbyScreen] Insufficient assets: need " .. assetReq .. ", have " .. currentMoney)
                    return
                end
            end
            -- 检查门票（按难度）
            if diff and diff.requiredTicket then
                if SaveSystem.GetTicketCount(diff.requiredTicket) <= 0 then
                    Utils.ShowMessage("需要持有" .. (diff.ticketLabel or "门票") .. "才能进入")
                    print("[LobbyScreen] No ticket: " .. diff.requiredTicket)
                    return
                end
            end
            if onStartCallback then
                onStartCallback(region.id, selectedCharIdx, UIState.selectedDifficultyIdx)
            end
        end,
    }

    local function refreshDiffSelection()
        local diffs = region.difficulties or {}
        for i = 1, maxDiffCount do
            if i <= #diffs then
                diffBtns[i]:SetStyle({ display = "flex" })
                diffBtnLabels[i]:SetText(diffs[i].label)
                if i == UIState.selectedDifficultyIdx then
                    diffBtns[i]:SetStyle({
                        borderColor = C.accent, borderWidth = 2,
                        backgroundColor = { 50, 55, 85, 240 },
                    })
                else
                    diffBtns[i]:SetStyle({
                        borderColor = { 60, 65, 80, 150 }, borderWidth = 1,
                        backgroundColor = { 35, 40, 60, 180 },
                    })
                end
            else
                diffBtns[i]:SetStyle({ display = "none" })
            end
        end
        local diff = diffs[UIState.selectedDifficultyIdx]
        if diff then
            if diff.entryFee <= 0 then
                entryFeeLabel:SetText("入场费: 免费")
                entryFeeLabel:SetStyle({ fontColor = { 160, 220, 160, 255 } })
            else
                entryFeeLabel:SetText("入场费: " .. Utils.FormatMoney(diff.entryFee))
                entryFeeLabel:SetStyle({ fontColor = { 255, 220, 100, 255 } })
            end
            -- 资产需求显示（使用 assetRequirement 字段，0 表示无门槛）
            local assetReq = diff.assetRequirement or 0
            if assetReq > 0 then
                local currentMoney = MoneyHUD.GetMoney()
                assetReqLabel:SetText("资产需求: " .. Utils.FormatMoney(assetReq))
                assetReqLabel:SetStyle({ display = "flex" })
                if currentMoney >= assetReq then
                    assetReqLabel:SetStyle({ fontColor = { 160, 220, 160, 255 } })
                else
                    assetReqLabel:SetStyle({ fontColor = { 255, 100, 100, 255 } })
                end
            else
                assetReqLabel:SetText("")
                assetReqLabel:SetStyle({ display = "none" })
            end
            -- 门票显示（按难度）
            if diff.requiredTicket then
                local count = SaveSystem.GetTicketCount(diff.requiredTicket)
                local ticketConf = Config.TICKETS[diff.requiredTicket]
                ticketLabel:SetText("×" .. count)
                ticketLabel:SetStyle({ display = "flex" })
                -- 更新门票图标
                if ticketConf and ticketConf.icon then
                    ticketIcon:SetStyle({ display = "flex", backgroundImage = ticketConf.icon })
                else
                    ticketIcon:SetStyle({ display = "none" })
                end
                if count > 0 then
                    ticketLabel:SetStyle({ fontColor = { 255, 200, 80, 255 } })
                else
                    ticketLabel:SetStyle({ fontColor = { 255, 100, 100, 255 } })
                end
            else
                ticketLabel:SetStyle({ display = "none" })
                ticketIcon:SetStyle({ display = "none" })
            end
            -- 更新开始按钮文本
            startBtnRef:SetText("开始行动 · " .. diff.label)
        end
    end

    local diffRow = {}
    for i = 1, maxDiffCount do
        local label = UI.Label { text = "", fontSize = 14, fontColor = C.textPrimary, textAlign = "center" }
        diffBtnLabels[i] = label
        local idx = i
        local btn = UI.Panel {
            height = 36, paddingHorizontal = 18,
            backgroundColor = { 35, 40, 60, 180 },
            borderRadius = 18, borderWidth = 1,
            borderColor = C.gridSlotBorder,
            justifyContent = "center", alignItems = "center",
            cursor = "pointer", flexShrink = 0,
            onClick = function()
                Utils.PlayClick()
                UIState.selectedDifficultyIdx = idx
                SaveSystem.UpdateSettings({ [lastDiffKey] = idx })
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

    refreshCharInfo = function()
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

        -- 锁定状态 UI
        local locked = isCharLocked(ch)
        if locked then
            local cost = ch.unlockCost or 20
            local coins = SaveSystem.GetCharacterCoins()
            charCoinText:SetText(coins .. "/" .. cost)
            charCoinLabel:SetVisible(true)
            if coins >= cost then
                charCoinText:SetStyle({ fontColor = { 100, 255, 100, 255 } })
            else
                charCoinText:SetStyle({ fontColor = { 255, 200, 80, 255 } })
            end
            unlockBtn:SetText("解锁 (" .. cost .. ")")
            unlockBtn:SetVisible(true)
            unlockBtn:SetDisabled(coins < cost)
        else
            charCoinLabel:SetVisible(false)
            unlockBtn:SetVisible(false)
        end

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
        -- 锁定遮罩
        local lockOverlay = UI.Panel {
            position = "absolute",
            left = 0, top = 0, width = "100%", height = "100%",
            backgroundColor = { 0, 0, 0, 160 },
            borderRadius = 4,
            justifyContent = "center", alignItems = "center",
            visible = isCharLocked(ch),
            children = {
                UI.Label { text = "🔒", fontSize = 18 },
            },
        }
        avatarLockOverlays[i] = lockOverlay

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
            children = { lockOverlay },
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
                    -- 角色币信息（锁定角色时显示）
                    charCoinLabel,
                    -- 解锁按钮（锁定角色时显示）
                    unlockBtn,
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
            -- 道具栏（暂时隐藏）
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
                width = "100%", height = Utils.sz(44), flexShrink = 0,
                paddingHorizontal = Utils.sz(12),
                flexDirection = "row", alignItems = "center",
                backgroundColor = { 0, 0, 0, 180 },
                children = {
                    -- 左侧：金币
                    MoneyHUD.CreatePanel(),
                    -- 中间标题（绝对定位居中）
                    UI.Panel {
                        position = "absolute", left = 0, right = 0, top = 0, bottom = 0,
                        flexDirection = "row", alignItems = "center", justifyContent = "center",
                        gap = Utils.sz(4),
                        pointerEvents = "none",
                        children = {
                            UI.Label { text = "竞拍大厅", fontSize = Utils.sz(16), fontColor = C.accent, fontWeight = "bold" },
                            UI.Label { text = "- " .. region.name, fontSize = Utils.sz(12), fontColor = C.textSecondary },
                        },
                    },
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
                width = "100%", flexShrink = 0,
                flexDirection = "row", alignItems = "flex-end",
                justifyContent = "space-between",
                paddingHorizontal = 12, paddingBottom = 8,
                children = {
                    -- 左侧：返回 + 仓库图标
                    UI.Panel {
                        height = 50,
                        flexDirection = "row", alignItems = "center",
                        backgroundColor = { 0, 0, 0, 180 },
                        borderRadius = 4, paddingHorizontal = 8,
                        gap = 8, flexShrink = 0,
                        children = {
                            UI.Button {
                                text = "←", fontSize = 18,
                                width = 40, height = 40,
                                onClick = function()
                                    Utils.PlayClick()
                                    if onBackCallback then onBackCallback() end
                                end,
                            },
                            UI.Panel {
                                flexDirection = "row", gap = 4, alignItems = "center",
                                children = warehouseIcons,
                            },
                        },
                    },
                    -- 右侧：场次选择 + 开始行动（三行）
                    UI.Panel {
                        flexDirection = "column", alignItems = "flex-end",
                        backgroundColor = { 0, 0, 0, 180 },
                        borderRadius = 4, paddingHorizontal = 10, paddingVertical = 8,
                        gap = 6, flexShrink = 0,
                        children = {
                            -- 第一行：场次按钮
                            UI.Panel {
                                flexDirection = "row", gap = 4, alignItems = "center",
                                children = diffRow,
                            },
                            -- 第二行：场次信息
                            UI.Panel {
                                flexDirection = "row", gap = 8, alignItems = "center",
                                children = {
                                    entryFeeLabel,
                                    assetReqLabel,
                                    ticketIcon,
                                    ticketLabel,
                                },
                            },
                            -- 第三行：开始按钮
                            startBtnRef,
                        },
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
            MoneyHUD.CreatePopup(),
        },
    }

    UI.SetRoot(UI.SafeAreaView {
        edges = "all", width = "100%", height = "100%",
        children = { finalRoot, DebugPanel.CreateHUD() },
    })

    -- 初始化
    refreshCharInfo()
    refreshWarehouseInfo()
    refreshDiffSelection()
end

return LobbyScreen
