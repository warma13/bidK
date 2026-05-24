-- ============================================================================
-- UI/LobbyScreen.lua - 竞拍大厅（选角色/仓库/难度/道具）
-- ============================================================================

local UI               = require("urhox-libs/UI")
local Config           = require("Config")
local UIState          = require("UI.UIState")
local MoneyHUD         = require("UI.MoneyHUD")
local Utils            = require("UI.Utils")

local SaveSystem       = require("SaveSystem")
local FloatingMessage  = require("UI.FloatingMessage")
local UnlockCharDialog = require("UI.UnlockCharDialog")

local LobbyScreen = {}

---@param regionIdx number
---@param onBackCallback fun()
---@param onStartCallback fun(regionId: string, charIdx: number, diffIdx: number, whTypeId: string)
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
        text = "", fontSize = Utils.sz(11),
        fontColor = C.accent, fontWeight = "bold",
    }
    local charNameLabel = UI.Label {
        text = "", fontSize = Utils.sz(18),
        fontColor = C.textPrimary, fontWeight = "bold",
    }
    local charDescLabel = UI.Label {
        text = "", fontSize = Utils.sz(10),
        fontColor = C.textSecondary, lineHeight = 1.5,
        whiteSpace = "normal", width = "100%", flexShrink = 1,
    }
    local charSkillLabel = UI.Label {
        text = "", fontSize = Utils.sz(10),
        fontColor = { 180, 220, 255, 255 }, lineHeight = 1.3,
        whiteSpace = "normal", width = "100%", flexShrink = 1,
    }

    -- 前向声明（解锁按钮 onClick 中引用）
    local avatarLockOverlays = {}
    local refreshCharInfo  -- 后面赋值

    -- -------------------------------------------------------------------------
    -- 解锁弹窗（复用 UnlockCharDialog 模块）
    -- -------------------------------------------------------------------------
    local unlockDialog = UnlockCharDialog.Create({
        sz = Utils.sz,
        onUnlocked = function(ch)
            avatarLockOverlays[selectedCharIdx]:SetVisible(false)
            refreshCharInfo()
            FloatingMessage.Show("🎉 成功解锁 " .. ch.name .. "!")
        end,
    })

    -- 解锁按钮
    local unlockBtn = UI.Panel {
        flexDirection = "row", alignItems = "center", justifyContent = "center",
        gap = Utils.sz(6), width = "100%", height = Utils.sz(28),
        backgroundColor = { 100, 80, 15, 230 },
        borderRadius = Utils.sz(6), borderWidth = 1,
        borderColor = { 180, 148, 50, 200 },
        cursor = "pointer", visible = false,
        onClick = function()
            Utils.PlayClick()
            local ch = Config.CHARACTERS[selectedCharIdx]
            if not ch or not isCharLocked(ch) then return end
            unlockDialog.show(ch)
        end,
        children = {
            UI.Panel {
                width = Utils.sz(14), height = Utils.sz(14),
                backgroundImage = "image/point_ticket_icon_20260518210650.png",
                backgroundFit = "contain", flexShrink = 0,
            },
            UI.Label {
                text = "300 点券  解锁",
                fontSize = Utils.sz(11), fontWeight = "bold",
                fontColor = { 255, 225, 80, 255 },
            },
        },
    }

    -- =========================================================================
    -- 右侧：仓库信息控件
    -- =========================================================================
    local warehouseNameLabel = UI.Label {
        text = "", fontSize = Utils.sz(14),
        fontColor = C.accent, fontWeight = "bold",
    }
    local warehouseDescLabel = UI.Label {
        text = "", fontSize = Utils.sz(10),
        fontColor = C.textSecondary, lineHeight = 1.3,
        whiteSpace = "normal", width = "100%", flexShrink = 1,
    }
    -- 仓库指定门票显示（非神秘仓库时显示，用 SetVisible 控制）
    local whTicketIcon = UI.Panel {
        width = Utils.sz(16), height = Utils.sz(16),
        backgroundFit = "contain",
        flexShrink = 0, visible = false,
    }
    local whTicketLabel = UI.Label {
        text = "", fontSize = Utils.sz(10),
        fontColor = { 255, 200, 80, 255 }, flexShrink = 0, visible = false,
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
        text = "", fontSize = Utils.sz(10),
        fontColor = { 160, 220, 160, 255 }, flexShrink = 0,
    }
    local assetReqLabel = UI.Label {
        text = "", fontSize = Utils.sz(10),
        fontColor = { 180, 180, 220, 255 }, flexShrink = 0,
    }
    local ticketIcon = UI.Panel {
        width = Utils.sz(20), height = Utils.sz(12),
        backgroundFit = "contain",
        flexShrink = 0, display = "none",
    }
    local ticketLabel = UI.Label {
        text = "", fontSize = Utils.sz(10),
        fontColor = { 255, 200, 80, 255 }, flexShrink = 0,
    }

    -- 仓库选择状态（提前声明，供开始行动按钮闭包引用）
    local selectedWhTypeIdx = 1

    -- 开始行动按钮（提前创建以便 refreshDiffSelection 更新文本）
    local startBtnRef = UI.Button {
        text = "开始行动",
        variant = "primary",
        textColor = { 20, 25, 10, 255 },
        fontWeight = "bold",
        width = Utils.sz(160), height = Utils.sz(46),
        fontSize = Utils.sz(15),
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
            -- 检查仓库指定门票：非神秘仓库需要消耗一张区域指定券
            if selectedWhTypeIdx ~= 1 and region.ticket then
                if SaveSystem.GetTicketCount(region.ticket) <= 0 then
                    local ticketConf = Config.TICKETS[region.ticket]
                    local ticketName = (ticketConf and ticketConf.name) or "指定券"
                    Utils.ShowMessage("需要持有「" .. ticketName .. "」才能指定仓库")
                    print("[LobbyScreen] No warehouse ticket: " .. region.ticket)
                    return
                end
            end
            if onStartCallback then
                -- 第1个位置（神秘仓库）→ 传 nil，由外部走轮盘抽选动画
                -- 其他位置（指定仓库）→ 先消耗区域指定券，再直接传固定类型
                local whTypeId
                if selectedWhTypeIdx == 1 then
                    whTypeId = nil  -- 交给 GameController.ShowMapSelection 触发轮盘
                else
                    -- 消耗一张区域指定券
                    if region.ticket then
                        SaveSystem.ConsumeTicket(region.ticket)
                        SaveSystem.AddTicketGameStat()
                    end
                    whTypeId = region.warehouseTypes[selectedWhTypeIdx]
                end
                onStartCallback(region.id, selectedCharIdx, UIState.selectedDifficultyIdx, whTypeId)
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
        local label = UI.Label { text = "", fontSize = Utils.sz(14), fontColor = C.textPrimary, textAlign = "center" }
        diffBtnLabels[i] = label
        local idx = i
        local btn = UI.Panel {
            height = Utils.sz(36), paddingHorizontal = Utils.sz(18),
            backgroundColor = { 35, 40, 60, 180 },
            borderRadius = Utils.sz(18), borderWidth = 1,
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
            width = Utils.sz(32), height = Utils.sz(32),
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
        unlockBtn:SetVisible(locked)

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
            width = Utils.sz(48), height = Utils.sz(48), flexShrink = 0,
            backgroundImage = ch.avatar,
            backgroundFit = "cover",
            borderRadius = Utils.sz(4), borderWidth = 1,
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
    -- 仓库选择状态
    -- =========================================================================
    -- selectedWhTypeIdx 已在上方提前声明
    ---@type Panel|nil
    local lobbyRootRef = nil

    -- 刷新仓库信息面板（名字 + 描述）
    local function refreshWarehouseInfo()
        local typeId = region.warehouseTypes[selectedWhTypeIdx]
        local wt = typeId and Config.WAREHOUSE_TYPES[typeId]
        if wt then
            warehouseNameLabel:SetText(wt.name or typeId)
            warehouseDescLabel:SetText(wt.desc or region.desc or "")
        else
            warehouseNameLabel:SetText(region.name)
            warehouseDescLabel:SetText(region.desc or "")
        end

        -- 仓库指定门票：神秘仓库（idx=1）免费；其他显示区域门票数量
        local ticketId = region.ticket
        if selectedWhTypeIdx == 1 or not ticketId then
            -- 神秘仓库 / 无门票配置：隐藏
            whTicketIcon:SetVisible(false)
            whTicketLabel:SetVisible(false)
        else
            local ticketConf = Config.TICKETS[ticketId]
            local count = SaveSystem.GetTicketCount(ticketId)
            -- 更新图标
            if ticketConf and ticketConf.icon then
                whTicketIcon:SetStyle({ backgroundImage = ticketConf.icon })
                whTicketIcon:SetVisible(true)
            else
                whTicketIcon:SetVisible(false)
            end
            -- 更新数量文字和颜色
            local ticketName = (ticketConf and ticketConf.name) or "指定券"
            whTicketLabel:SetText(ticketName .. " ×" .. count)
            if count > 0 then
                whTicketLabel:SetStyle({ fontColor = { 255, 200, 80, 255 } })
            else
                whTicketLabel:SetStyle({ fontColor = { 255, 100, 100, 255 } })
            end
            whTicketLabel:SetVisible(true)
        end
    end

    -- =========================================================================
    -- 底部：仓库类型图标（可点击切换）
    -- =========================================================================
    -- whIconPanels[i] = { panel, nameLabel }  用于刷新高亮和名字显示
    local whIconPanels = {}

    local function refreshWhIcons()
        for i, entry in ipairs(whIconPanels) do
            local panel      = entry.panel
            local nameLabel  = entry.nameLabel
            local iconWidget = entry.iconWidget
            if i == selectedWhTypeIdx then
                -- 激活：黄绿背景 + 显示名字 + 图标变黑
                panel:SetStyle({
                    backgroundColor = { 180, 220, 80, 255 },
                    paddingRight = 10,
                })
                nameLabel:SetVisible(true)
                if iconWidget then
                    iconWidget:SetStyle({ imageTint = { 0, 0, 0, 255 } })
                end
            else
                -- 未激活：透明背景 + 隐藏名字 + 图标恢复白色
                panel:SetStyle({
                    backgroundColor = { 0, 0, 0, 0 },
                    paddingRight = 0,
                })
                nameLabel:SetVisible(false)
                if iconWidget then
                    iconWidget:SetStyle({ imageTint = { 255, 255, 255, 255 } })
                end
            end
        end
    end

    -- 构建图标列表（含分割线）
    local warehouseIconItems = {}
    for i, key in ipairs(region.warehouseTypes) do
        local wt = Config.WAREHOUSE_TYPES[key]
        if wt then
            local nameLabel = UI.Label {
                text = wt.name or key,
                fontSize = Utils.sz(11), fontColor = { 20, 25, 10, 255 },
                fontWeight = "bold",
                flexShrink = 0,
                visible = false,  -- 默认隐藏，激活后显示
            }
            -- icon 支持图片路径或 emoji 文字
            local isImgIcon = wt.icon and wt.icon ~= "" and wt.icon:sub(1, 6) == "image/"
            local iconWidget
            if isImgIcon then
                iconWidget = UI.Panel {
                    width = Utils.sz(28), height = Utils.sz(28),
                    backgroundImage = wt.icon,
                    backgroundFit = "contain",
                    imageTint = { 255, 255, 255, 255 },
                    flexShrink = 0,
                }
            else
                iconWidget = UI.Label {
                    text = (wt.icon and wt.icon ~= "") and wt.icon or "🏚",
                    fontSize = Utils.sz(20), textAlign = "center",
                    flexShrink = 0,
                }
            end
            local idx = i
            local iconPanel = UI.Panel {
                height = Utils.sz(44),
                paddingLeft = Utils.sz(10), paddingRight = 0,
                paddingVertical = 0,
                backgroundColor = { 0, 0, 0, 0 },
                borderRadius = Utils.sz(6),
                flexDirection = "row",
                justifyContent = "center", alignItems = "center",
                gap = Utils.sz(6), flexShrink = 0,
                cursor = "pointer",
                onTap = function()
                    Utils.PlayClick()
                    selectedWhTypeIdx = idx
                    -- 切换背景图
                    local selKey = region.warehouseTypes[idx]
                    local selWt = selKey and Config.WAREHOUSE_TYPES[selKey]
                    local newBg = (selWt and selWt.bg and selWt.bg ~= "") and selWt.bg
                                  or ((region.bg and region.bg ~= "") and region.bg or nil)
                    if lobbyRootRef then
                        lobbyRootRef:SetStyle({ backgroundImage = newBg })
                    end
                    refreshWarehouseInfo()
                    refreshWhIcons()
                end,
                children = { iconWidget, nameLabel },
            }
            whIconPanels[i] = { panel = iconPanel, nameLabel = nameLabel, iconWidget = iconWidget }
            warehouseIconItems[#warehouseIconItems + 1] = iconPanel

            -- 除最后一项外，每个图标后加竖线分隔
            if i < #region.warehouseTypes then
                warehouseIconItems[#warehouseIconItems + 1] = UI.Panel {
                    width = 1, height = Utils.sz(24), flexShrink = 0,
                    backgroundColor = { 80, 85, 100, 160 },
                }
            end
        end
    end

    -- =========================================================================
    -- 构建左侧面板（头像列表 + 角色详情，左右分栏）
    -- =========================================================================
    local leftPanel = UI.Panel {
        width = Utils.sz(280), flexShrink = 0,
        flexDirection = "row", gap = Utils.sz(8),
        overflow = "hidden",
        backgroundColor = { 15, 18, 28, 180 },
        borderRadius = Utils.sz(4),
        padding = Utils.sz(8),
        children = {
            -- 左列：头像两列网格滚动列表
            UI.ScrollView {
                width = Utils.sz(108), flexShrink = 0,
                scrollX = false, scrollY = true,
                showScrollbar = false,
                children = {
                    UI.Panel {
                        width = "100%",
                        flexDirection = "row",
                        flexWrap = "wrap",
                        gap = Utils.sz(4),
                        children = avatarPanels,
                    },
                },
            },
            -- 右列：选中角色详情
            UI.Panel {
                flexGrow = 1, flexShrink = 1,
                flexDirection = "column", gap = Utils.sz(4),
                children = {
                    -- 称号
                    UI.Panel {
                        flexDirection = "row", alignItems = "center", gap = Utils.sz(3),
                        flexShrink = 0,
                        children = {
                            UI.Panel { width = Utils.sz(3), height = Utils.sz(12), backgroundColor = C.accent, flexShrink = 0 },
                            charTitleLabel,
                        },
                    },
                    -- 名字
                    charNameLabel,
                    -- 描述
                    charDescLabel,
                    -- 技能
                    charSkillLabel,
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
        flexDirection = "column", gap = Utils.sz(8),
        children = {
            -- 仓库信息卡
            UI.Panel {
                width = "100%",
                backgroundColor = { 30, 35, 55, 220 },
                borderRadius = 0, borderWidth = 1,
                borderColor = C.gridSlotBorder,
                padding = Utils.sz(8), gap = Utils.sz(4),
                flexDirection = "column", flexShrink = 0,
                children = {
                    UI.Label { text = "仓库信息", fontSize = Utils.sz(10), fontColor = C.textMuted },
                    warehouseNameLabel,
                    warehouseDescLabel,
                    UI.Panel {
                        flexDirection = "row", alignItems = "center", gap = Utils.sz(4),
                        children = { whTicketIcon, whTicketLabel },
                    },
                    UI.Panel {
                        flexDirection = "row", justifyContent = "space-between",
                        children = {
                            UI.Label { text = "拍卖轮数", fontSize = Utils.sz(10), fontColor = C.textMuted },
                            UI.Label { text = tostring(Config.GAME.MaxRounds), fontSize = Utils.sz(10), fontColor = C.textPrimary },
                        },
                    },
                    UI.Panel {
                        flexDirection = "row", justifyContent = "space-between",
                        children = {
                            UI.Label { text = "竞拍人数", fontSize = Utils.sz(10), fontColor = C.textMuted },
                            UI.Label { text = tostring(Config.GAME.MaxPlayers) .. "人", fontSize = Utils.sz(10), fontColor = C.textPrimary },
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
    -- 初始背景：优先第一个仓库类型的 bg，回退到 region.bg
    local firstWhKey = region.warehouseTypes and region.warehouseTypes[1]
    local firstWt = firstWhKey and Config.WAREHOUSE_TYPES[firstWhKey]
    local lobbyBg = (firstWt and firstWt.bg and firstWt.bg ~= "") and firstWt.bg
                    or ((region.bg and region.bg ~= "") and region.bg or nil)
    local lobbyRoot = UI.Panel {
        width = "100%", height = "100%",
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
                padding = Utils.sz(10), gap = Utils.sz(10),
                overflow = "hidden",
                children = {
                    -- 左列：角色头像列表 + 详情（内部左右分栏）
                    leftPanel,

                    -- 中列：角色全身立绘
                    centerPortraitPanel,

                    -- 右列：可滚动配置面板
                    UI.ScrollView {
                        width = Utils.sz(280), flexShrink = 0,
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
                paddingHorizontal = Utils.sz(12), paddingBottom = Utils.sz(8),
                children = {
                    -- 左侧：返回按钮（独立在外） + 仓库图标栏
                    UI.Panel {
                        flexDirection = "row", alignItems = "center",
                        gap = Utils.sz(8), flexShrink = 1,
                        children = {
                            -- 返回按钮（独立，不在仓库容器内）
                            UI.Button {
                                text = "←", fontSize = Utils.sz(18),
                                width = Utils.sz(44), height = Utils.sz(44),
                                flexShrink = 0,
                                pressedBackgroundColor = { 40, 50, 80, 255 },
                                onClick = function()
                                    Utils.PlayClick()
                                    if onBackCallback then onBackCallback() end
                                end,
                            },
                            -- 仓库图标栏（圆角容器，自适应宽度，可横向滚动）
                            UI.ScrollView {
                                flexShrink = 1,
                                height = Utils.sz(52),
                                scrollX = true, scrollY = false,
                                showScrollbar = false,
                                backgroundColor = { 15, 18, 25, 210 },
                                borderRadius = Utils.sz(26),
                                paddingHorizontal = Utils.sz(8),
                                children = {
                                    UI.Panel {
                                        flexDirection = "row", gap = 0,
                                        alignItems = "center",
                                        height = Utils.sz(52),
                                        children = warehouseIconItems,
                                    },
                                },
                            },
                        },
                    },
                    -- 右侧：场次选择 + 开始行动（三行）
                    UI.Panel {
                        flexDirection = "column", alignItems = "flex-end",
                        backgroundColor = { 0, 0, 0, 180 },
                        borderRadius = Utils.sz(4), paddingHorizontal = Utils.sz(10), paddingVertical = Utils.sz(8),
                        gap = Utils.sz(6), flexShrink = 0,
                        children = {
                            -- 第一行：场次按钮
                            UI.Panel {
                                flexDirection = "row", gap = Utils.sz(4), alignItems = "center",
                                children = diffRow,
                            },
                            -- 第二行：场次信息
                            UI.Panel {
                                flexDirection = "row", gap = Utils.sz(8), alignItems = "center",
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
            unlockDialog.panel,
        },
    }

    local bgPanel = UI.Panel {
        width = "100%", height = "100%",
        backgroundColor = C.bgDark,
        backgroundImage = lobbyBg,
        backgroundFit = "cover",
        children = {
            UI.SafeAreaView {
                edges = "all", width = "100%", height = "100%",
                children = { finalRoot },
            },
        },
    }
    -- 绑定引用，供仓库切换时更新背景
    lobbyRootRef = bgPanel
    UI.SetRoot(bgPanel)

    -- 初始化
    refreshCharInfo()
    refreshWarehouseInfo()
    refreshWhIcons()
    refreshDiffSelection()
end

return LobbyScreen
