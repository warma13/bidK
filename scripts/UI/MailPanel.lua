-- ============================================================================
-- UI/MailPanel.lua - 系统邮件收件箱
-- ============================================================================
-- 布局：
--   顶栏：邮件图标 + "邮件 | MAIL" + ✕
--   主体：[左栏 邮件列表] | 间距 | [右栏 上:正文 / 下:奖励格子]
--   底栏：[返回]  [全部领取]  封数
-- ============================================================================

---@diagnostic disable: undefined-global

local UI           = require("urhox-libs/UI")
local UIState      = require("UI.UIState")
local Utils        = require("UI.Utils")
local Config       = require("Config")
local RewardSlot   = require("UI.RewardSlot")
local SaveSystem   = require("SaveSystem")
local SaveFW       = require("SaveFramework")
local MoneyManager = require("MoneyManager")
local SeasonPass   = require("SeasonPass")
local FloatingMsg  = require("UI.FloatingMessage")

local MailPanel = {}

-- 当前活跃的返回函数（Show 时赋值，供外部 ESC 调用）
local goBackFn = nil

-- ─── 颜色 ────────────────────────────────────────────────────────────────────
local C = {
    bg          = { 6,   8,  16, 200 },
    topBorder   = { 50, 55,  70, 100 },
    panelBdr    = { 50, 55,  70,  90 },
    title       = { 240, 235, 220, 255 },
    headerSep   = { 180, 185, 200,  80 },
    closeBg     = { 40,  42,  55, 200 },
    closeBdr    = { 70,  75,  90, 180 },
    closeText   = { 180, 220,   0, 230 },
    listBg      = { 14,  16,  26, 210 },
    rowHover    = { 255, 255, 255,  12 },
    rowActive   = { 200, 230,   0,  22 },
    rowBdr      = { 50,  55,  70,  50 },
    unreadDot   = { 200, 230,   0, 255 },
    dimText     = { 160, 162, 170, 200 },
    sender      = { 200, 230,   0, 200 },
    dateText    = { 130, 135, 148, 200 },
    expiry      = { 140, 145, 155, 170 },
    bodyText    = { 205, 210, 220, 230 },
    rewardBg    = { 195, 215,  40,  14 },
    rewardBdr   = { 195, 215,  40,  80 },
    rewardText  = { 200, 230,   0, 255 },
    claimedText = { 100, 105, 115, 150 },
    cellBg      = { 30,  33,  44, 220 },
    cellBdr     = { 60,  65,  80, 160 },
    cellActive  = { 195, 215,  40,  30 },
    cellActBdr  = { 195, 215,  40, 180 },
    countText   = { 200, 230,   0, 230 },
    noMailText  = { 110, 115, 128, 170 },
    divider     = { 50,  55,  70,  70 },
    -- 底栏按钮
    backText    = { 195, 215,  40, 230 },
    backBg      = { 195, 215,  40,  20 },
    backBdr     = { 195, 215,  40, 160 },
    claimText   = {  10,  10,  10, 255 },
    claimBg     = { 195, 215,  40, 230 },
    claimHv     = { 215, 235,  60, 255 },
    claimPr     = { 175, 195,  20, 255 },
}

-- ─── 奖励辅助（统一走 Config 注册表）────────────────────────────────────────
local function RewardIcon(reward)  return Config.GetRewardIcon(reward)  end
local function RewardCount(reward) return Config.GetRewardCount(reward) end
local function RewardName(reward)  return Config.GetRewardName(reward)  end

-- ─── 发放奖励 ─────────────────────────────────────────────────────────────────
local function GiveReward(reward)
    if not reward then return end
    if reward.type == "coins" then
        MoneyManager.AddMoneyFromMenu(reward.amount, "邮件奖励", { skipSave = true })
        SaveFW.MarkDirty("save_system")
    elseif reward.type == "bp_exp" then
        SeasonPass.AddTaskXP(reward.amount, "邮件奖励")
    elseif reward.type == "point_tickets" then
        SaveSystem.AddPointTickets(reward.amount or 1)
    elseif reward.type == "ticket" then
        SaveSystem.AddTickets(reward.ticketId, reward.amount or 1)
        SaveFW.MarkDirty("save_system")
    elseif reward.type == "chest" and reward.chestId then
        SaveSystem.AddProp(reward.chestId, reward.amount or 1)
        SaveFW.MarkDirty("save_system")
    end
end

-- ============================================================================
-- 主入口
-- ============================================================================
function MailPanel.Show(onBackCallback)
    UIState.currentScreen = "mail"
    local sz    = Utils.sz

    local MAIL_CAP = 30  -- 最多保留邮件数量

    -- 合并系统邮件 + 溢出邮件（溢出邮件在前，更紧急）
    local function BuildMailList_GetMails()
        local result = {}
        -- 溢出邮件：开箱时仓库满导致的物品
        local overflows = SaveSystem.GetOverflowMails()
        for _, m in ipairs(overflows) do
            result[#result + 1] = {
                id       = m.id,
                title    = m.name or "仓库溢出物品",
                sender   = "系统",
                date     = os.date("%Y-%m-%d", m.wonAt or os.time()),
                expiry   = "",
                _sortTime = m.wonAt or 0,
                body     = "您开箱获得的【" .. (m.name or "物品") .. "】因仓库空间不足无法放入，请领取后存入仓库。",
                isOverflow  = true,
                overflowItem = m,
                reward   = {
                    type    = "_overflow_item",
                    _item   = m,
                },
            }
        end
        -- 系统邮件（按 date 字段排序，较新的在前）
        local sysMails = Config.MAILS or {}
        for i, m in ipairs(sysMails) do
            -- 附加排序时间戳（用 date 字符串比较，格式 YYYY-MM-DD 字典序即时序）
            local entry = {}
            for k, v in pairs(m) do entry[k] = v end
            entry._sortTime = m.date or ""
            entry._sortIdx  = i  -- 数组序号，越大越新
            -- veteranOnly 邮件：仅老玩家可见（存档创建日期 < 邮件日期）
            local dominated = false
            if m.veteranOnly then
                local created = SaveSystem.GetCreatedAt()  -- "YYYY-MM-DD"
                if created == "" or created >= (m.date or "") then
                    dominated = true  -- 新玩家或同日注册，跳过
                end
            end
            if not dominated and not SaveSystem.IsMailDismissed(m.id) then
                result[#result + 1] = entry
            end
        end
        -- 按时间降序（溢出邮件 _sortTime 是数字，系统邮件是字符串，分开比较：溢出在前）
        table.sort(result, function(a, b)
            -- 溢出邮件始终排在系统邮件前面
            local aIsOvf = a.isOverflow and 1 or 0
            local bIsOvf = b.isOverflow and 1 or 0
            if aIsOvf ~= bIsOvf then return aIsOvf > bIsOvf end
            -- 同类型按 _sortTime 降序（新→旧），同日期按数组序号降序
            local ta, tb = tostring(a._sortTime), tostring(b._sortTime)
            if ta ~= tb then return ta > tb end
            return (a._sortIdx or 0) > (b._sortIdx or 0)
        end)
        -- 超出上限：截断最旧的
        if #result > MAIL_CAP then
            local trimmed = {}
            for i = 1, MAIL_CAP do trimmed[i] = result[i] end
            result = trimmed
        end
        return result
    end

    local mails = BuildMailList_GetMails()

    -- ── 状态 ─────────────────────────────────────────────────────────────────
    local selectedMail = nil  ---@type table|nil
    local rowPanels    = {}   -- mail.id → row UI.Panel

    -- ── 选中行高亮（不重建列表）────────────────────────────────────────────────
    local function SelectRow(newId)
        local oldId = selectedMail and selectedMail.id
        if oldId and rowPanels[oldId] then
            rowPanels[oldId]:SetBackgroundColor({ 0, 0, 0, 0 })
            rowPanels[oldId]:SetBorderColor(C.rowBdr)
        end
        if newId and rowPanels[newId] then
            rowPanels[newId]:SetBackgroundColor(C.rowActive)
            rowPanels[newId]:SetBorderColor({ 195, 215, 40, 120 })
        end
    end

    -- ── 动态容器 ─────────────────────────────────────────────────────────────
    local mailListContainer = UI.Panel {
        width = "100%", flexGrow = 1, flexShrink = 1,
        flexDirection = "column", overflow = "hidden",
    }
    local mailBodyContainer = UI.Panel {
        width = "100%", flexGrow = 1, flexShrink = 1,
        flexDirection = "column", overflow = "hidden",
    }
    local mailRewardContainer = UI.Panel {
        width = "100%",
        flexDirection = "column", overflow = "hidden",
    }

    -- 前向声明
    local BuildMailList
    local BuildMailContent

    -- ── 关闭/返回 ─────────────────────────────────────────────────────────────
    local function GoBack()
        Utils.PlayClick()
        goBackFn = nil
        UIState.currentScreen = "menu"
        if onBackCallback then
            onBackCallback()
        else
            local GameController = require("UI.GameController")
            GameController.ShowMenu()
        end
    end
    goBackFn = GoBack

    -- ── 构建奖励格子区 ────────────────────────────────────────────────────────
    local function BuildRewardArea(mail)
        mailRewardContainer:ClearChildren()
        -- 统一：rewards 数组优先，否则降级到 reward 单项
        local hasAnyReward = (mail and mail.rewards and #mail.rewards > 0)
                          or (mail and mail.reward)
        if not mail or not hasAnyReward then return end

        local claimBtn ---@type table

        -- ── 溢出邮件（开箱仓库满）────────────────────────────────────────────
        if mail.isOverflow then
            local item = mail.overflowItem
            local cell = RewardSlot.Make({
                image       = item.image or "",
                count       = "",
                bgColor     = { 30, 33, 44, 220 },
                borderColor = { 120, 80, 40, 180 },
                label       = item.name,
            }, sz)

            local function DoClaimOverflow()
                Utils.PlayClick()
                local ok, err = SaveSystem.ClaimOverflowMail(mail.id)
                if ok then
                    FloatingMsg.Show("已领取：" .. (item.name or "物品"))
                    mails = BuildMailList_GetMails()
                    selectedMail = nil
                    BuildMailList()
                    BuildMailContent(nil)
                else
                    if err == "full" then
                        FloatingMsg.Show("仓库已满，无法领取")
                    else
                        FloatingMsg.Show("领取失败，请稍后重试")
                    end
                end
            end

            claimBtn = UI.Panel {
                paddingHorizontal = sz(20), paddingVertical = sz(8),
                borderRadius = sz(4),
                backgroundColor = C.claimBg, hoverBackgroundColor = C.claimHv,
                cursor = "pointer", onClick = DoClaimOverflow,
                children = {
                    UI.Label { text = "领取", fontSize = sz(13), fontWeight = "bold", fontColor = C.claimText },
                },
            }

            mailRewardContainer:AddChild(UI.Panel {
                width = "100%", flexDirection = "column", gap = sz(6),
                paddingHorizontal = sz(14), paddingVertical = sz(10),
                backgroundColor = C.rewardBg,
                borderTopWidth = 1, borderColor = C.rewardBdr,
                children = {
                    UI.Label { text = "邮件附件", fontSize = sz(11), fontColor = C.dateText },
                    UI.Panel {
                        width = "100%", flexDirection = "row", alignItems = "center", gap = sz(8),
                        children = { cell, UI.Panel { flexGrow = 1 }, claimBtn },
                    },
                },
            })

        -- ── 普通系统邮件（支持单 reward 和 rewards 数组）────────────────────
        else
            local isClaimed = SaveSystem.IsMailClaimed(mail.id)
            -- 统一为数组
            local rewardList = mail.rewards or { mail.reward }

            local function DoClaimAll()
                Utils.PlayClick()
                if not SaveSystem.ClaimMail(mail.id) then return end
                local names = {}
                for _, r in ipairs(rewardList) do
                    GiveReward(r)
                    names[#names + 1] = RewardName(r) .. " " .. RewardCount(r)
                end
                FloatingMsg.Show("已领取：" .. table.concat(names, "、"))
                BuildMailContent(mail)
                BuildMailList()
            end

            -- 格子行：每个奖励一个格子
            local cells = {}
            for _, r in ipairs(rewardList) do
                cells[#cells + 1] = RewardSlot.FromReward(r, sz)
            end
            cells[#cells + 1] = UI.Panel { flexGrow = 1 }  -- 弹性间距

            if isClaimed then
                claimBtn = UI.Panel {
                    paddingHorizontal = sz(16), paddingVertical = sz(8),
                    borderRadius = sz(4),
                    backgroundColor = { 40, 42, 55, 180 },
                    borderWidth = 1, borderColor = C.divider,
                    children = {
                        UI.Label { text = "已领取", fontSize = sz(12), fontWeight = "bold", fontColor = C.claimedText },
                    },
                }
            else
                claimBtn = UI.Panel {
                    paddingHorizontal = sz(20), paddingVertical = sz(8),
                    borderRadius = sz(4),
                    backgroundColor = C.claimBg, hoverBackgroundColor = C.claimHv,
                    cursor = "pointer", onClick = DoClaimAll,
                    children = {
                        UI.Label { text = "领取", fontSize = sz(13), fontWeight = "bold", fontColor = C.claimText },
                    },
                }
            end
            cells[#cells + 1] = claimBtn

            mailRewardContainer:AddChild(UI.Panel {
                width = "100%", flexDirection = "column", gap = sz(6),
                paddingHorizontal = sz(14), paddingVertical = sz(10),
                backgroundColor = C.rewardBg,
                borderTopWidth = 1, borderColor = C.rewardBdr,
                children = {
                    UI.Label { text = "邮件附件", fontSize = sz(11), fontColor = C.dateText },
                    UI.Panel {
                        width = "100%", flexDirection = "row",
                        alignItems = "center", gap = sz(8),
                        children = cells,
                    },
                },
            })
        end
    end

    -- ── 构建正文区 ────────────────────────────────────────────────────────────
    BuildMailContent = function(mail)
        mailBodyContainer:ClearChildren()
        mailRewardContainer:ClearChildren()

        if not mail then
            mailBodyContainer:AddChild(UI.Panel {
                width = "100%", flexGrow = 1,
                alignItems = "center", justifyContent = "center",
                children = {
                    UI.Label { text = "选择邮件以查看详情", fontSize = sz(13), fontColor = C.noMailText },
                },
            })
            return
        end

        SaveSystem.MarkMailRead(mail.id)

        -- 邮件头（发件人 + 日期 + 过期）
        mailBodyContainer:AddChild(UI.Panel {
            width = "100%",
            flexDirection = "column", gap = sz(6),
            paddingHorizontal = sz(14), paddingTop = sz(12), paddingBottom = sz(10),
            borderBottomWidth = 1, borderColor = C.divider,
            children = {
                UI.Label {
                    text = mail.title or "",
                    fontSize = sz(15), fontWeight = "bold",
                    fontColor = C.title, whiteSpace = "normal", width = "100%",
                },
                UI.Panel {
                    flexDirection = "row", gap = sz(14), alignItems = "center",
                    children = {
                        UI.Label { text = mail.sender or "", fontSize = sz(11), fontColor = C.sender },
                        UI.Label { text = mail.date   or "", fontSize = sz(11), fontColor = C.dateText },
                        UI.Label { text = mail.expiry or "", fontSize = sz(11), fontColor = C.expiry },
                    },
                },
            },
        })

        -- 正文（可滚动）
        mailBodyContainer:AddChild(UI.ScrollView {
            width = "100%", flexGrow = 1,
            children = {
                -- Panel 约束横向宽度，Label 才能正确换行
                UI.Panel {
                    width = "100%",
                    paddingHorizontal = sz(14), paddingVertical = sz(12),
                    children = {
                        UI.Label {
                            text = mail.body or "",
                            fontSize = sz(13), fontColor = C.bodyText,
                            width = "100%",
                            whiteSpace = "normal",
                        },
                    },
                },
            },
        })

        -- 奖励格子
        BuildRewardArea(mail)
    end

    -- ── 构建邮件列表（VirtualList）────────────────────────────────────────────
    -- 每行高度：paddingV(9)*2 + 标题行(12*1.4行高≈17) + gap(4) + 发件人行(10*1.4行高≈14) + 边框≈2
    local ROW_H    = sz(9) * 2 + sz(17) + sz(4) + sz(14) + sz(2)
    local ROW_GAP  = sz(4)
    local screenH  = graphics:GetHeight()
    -- 左栏可用高度 = 屏幕高 - 顶栏(50+1) - 底栏(paddingV*2 + btnPaddingV*2 + border=1) - 主体paddingV*2
    local listH    = screenH
                   - (sz(50) + 1)             -- 顶栏高度 + 底部border
                   - (sz(9)*2 + sz(7)*2 + 1)  -- 底栏: paddingVertical + button paddingV + 顶部border
                   - (sz(8) * 2)              -- 主体区 paddingVertical

    ---@type table|nil  当前 VirtualList 实例（用于 SetData 刷新）
    local mailVirtualList = nil

    -- 构建单行 widget（VirtualList createItem）
    local function CreateMailRow()
        local dot   = UI.Panel { width = sz(6), height = sz(6), borderRadius = sz(3), flexShrink = 0, marginTop = sz(2) }
        local badge = UI.Panel { paddingHorizontal = sz(5), paddingVertical = sz(1), borderRadius = sz(2), borderWidth = 1 }
        local badgeLbl = UI.Label { fontSize = sz(9), fontWeight = "bold" }
        badge:AddChild(badgeLbl)
        local titleLbl  = UI.Label { fontSize = sz(12), flexShrink = 1 }
        local senderLbl = UI.Label { fontSize = sz(10) }
        local expiryLbl = UI.Label { fontSize = sz(10) }

        local titleRow = UI.Panel {
            width = "100%", flexDirection = "row", alignItems = "center", gap = sz(6),
            children = { titleLbl, badge },
        }
        local metaRow = UI.Panel {
            flexDirection = "row", alignItems = "center", gap = sz(8),
            children = { senderLbl, expiryLbl },
        }
        local inner = UI.Panel {
            flexGrow = 1, flexShrink = 1,
            flexDirection = "column", gap = sz(4),
            children = { titleRow, metaRow },
        }
        local row = UI.Panel {
            width = "100%", height = ROW_H,
            flexDirection = "row", alignItems = "flex-start",
            gap = sz(8),
            paddingHorizontal = sz(10), paddingVertical = sz(9),
            borderWidth = 1, borderRadius = sz(4),
            cursor = "pointer",
            children = { dot, inner },
        }
        -- 缓存子控件引用，供 bindItem 使用
        row._dot       = dot
        row._badge     = badge
        row._badgeLbl  = badgeLbl
        row._titleLbl  = titleLbl
        row._senderLbl = senderLbl
        row._expiryLbl = expiryLbl
        return row
    end

    -- 数据绑定（VirtualList bindItem）
    local function BindMailRow(widget, m, _index)
        local isRead    = SaveSystem.IsMailRead(m.id)
        local hasReward = (m.rewards and #m.rewards > 0) or m.reward ~= nil
        local isClaimed = hasReward and SaveSystem.IsMailClaimed(m.id)
        local isSelected = selectedMail and selectedMail.id == m.id
        local showDot   = not isRead or (hasReward and not isClaimed)

        -- 圆点
        widget._dot:SetBackgroundColor(showDot and C.unreadDot or { 0, 0, 0, 0 })

        -- 角标
        if hasReward then
            widget._badge:SetVisible(true)
            widget._badge:SetBackgroundColor(isClaimed and { 40, 42, 52, 160 } or C.rewardBg)
            widget._badge:SetBorderColor(isClaimed and C.divider or C.rewardBdr)
            widget._badgeLbl:SetText(isClaimed and "已领取" or "有附件")
            widget._badgeLbl:SetFontColor(isClaimed and C.claimedText or C.rewardText)
        else
            widget._badge:SetVisible(false)
        end

        -- 标题
        widget._titleLbl:SetText(m.title or "")
        widget._titleLbl:SetProp("fontWeight", isRead and "normal" or "bold")
        widget._titleLbl:SetFontColor(isRead and C.dimText or C.title)

        -- 发件人 / 过期
        widget._senderLbl:SetText(m.sender or "")
        widget._senderLbl:SetFontColor(C.sender)
        widget._expiryLbl:SetText(m.expiry or "")
        widget._expiryLbl:SetFontColor(C.expiry)

        -- 选中高亮
        widget:SetBackgroundColor(isSelected and C.rowActive or { 0, 0, 0, 0 })
        widget:SetBorderColor(isSelected and { 195, 215, 40, 120 } or C.rowBdr)
        widget:SetProp("hoverBackgroundColor", isSelected and C.rowActive or C.rowHover)

        -- 记录到 rowPanels（用于 SelectRow 高亮切换）
        rowPanels[m.id] = widget
    end

    BuildMailList = function()
        rowPanels = {}
        mailListContainer:ClearChildren()
        -- 每次重建时刷新邮件数据
        mails = BuildMailList_GetMails()

        if #mails == 0 then
            mailListContainer:AddChild(UI.Panel {
                width = "100%", flexGrow = 1,
                alignItems = "center", justifyContent = "center",
                children = {
                    UI.Label { text = "暂无邮件", fontSize = sz(13), fontColor = C.noMailText },
                },
            })
            mailVirtualList = nil
            return
        end

        mailVirtualList = UI.VirtualList {
            width  = "100%",
            height = listH,     -- 左栏实际可用高度（屏幕高 - 顶栏 - 底栏 - padding）
            data        = mails,
            itemHeight  = ROW_H,
            itemGap     = ROW_GAP,
            paddingLeft = sz(6), paddingRight = sz(6), paddingTop = sz(6),
            createItem  = CreateMailRow,
            bindItem    = BindMailRow,
            onItemClick = function(m, _index, _widget)
                Utils.PlayClick()
                SelectRow(m.id)
                selectedMail = m
                BuildMailContent(m)
                -- 刷新该行已读状态（绿点 + 标题样式）
                if _widget then
                    local hasReward = (m.rewards and #m.rewards > 0) or m.reward ~= nil
                    local isClaimed = hasReward and SaveSystem.IsMailClaimed(m.id)
                    local showDot = hasReward and not isClaimed
                    _widget._dot:SetBackgroundColor(showDot and C.unreadDot or { 0, 0, 0, 0 })
                    _widget._titleLbl:SetProp("fontWeight", "normal")
                    _widget._titleLbl:SetFontColor(C.dimText)
                end
            end,
        }
        mailListContainer:AddChild(mailVirtualList)
    end

    -- ── 初始构建 ─────────────────────────────────────────────────────────────
    BuildMailList()
    BuildMailContent(nil)

    -- ── 全部领取 ─────────────────────────────────────────────────────────────
    local function ClaimAll()
        Utils.PlayClick()
        local count    = 0
        local fullHit  = false  -- 是否遇到仓库满
        local current  = BuildMailList_GetMails()

        for _, m in ipairs(current) do
            if m.isOverflow then
                -- 溢出邮件：检查仓库空间
                local ok, err = SaveSystem.ClaimOverflowMail(m.id)
                if ok then
                    count = count + 1
                elseif err == "full" then
                    fullHit = true
                    break  -- 仓库满就停止，后续都放不进去
                end
            elseif (m.rewards or m.reward) and not SaveSystem.IsMailClaimed(m.id) then
                if SaveSystem.ClaimMail(m.id) then
                    local rewardList = m.rewards or { m.reward }
                    for _, r in ipairs(rewardList) do GiveReward(r) end
                    count = count + 1
                end
            end
        end

        if fullHit then
            FloatingMsg.Show(count > 0
                and ("已领取 " .. count .. " 件，仓库已满，剩余无法领取")
                or "仓库已满，无法领取")
        else
            FloatingMsg.Show(count > 0 and ("已领取 " .. count .. " 封邮件奖励") or "暂无可领取奖励")
        end

        mails = BuildMailList_GetMails()
        selectedMail = nil
        BuildMailList()
        BuildMailContent(nil)
    end

    -- ── 顶栏 ─────────────────────────────────────────────────────────────────
    local topBar = UI.Panel {
        width = "100%", height = sz(50),
        flexDirection = "row", alignItems = "center",
        paddingHorizontal = sz(16),
        borderBottomWidth = 1, borderColor = C.topBorder,
        children = {
            UI.Panel {
                flexDirection = "row", alignItems = "center", gap = sz(10),
                children = {
                    UI.Panel {
                        width = sz(22), height = sz(22),
                        backgroundImage = "image/nav_mail_20260520191948.png",
                        backgroundFit = "contain",
                    },
                    UI.Panel { width = 1, height = sz(20), backgroundColor = C.headerSep },
                    UI.Label { text = "邮件",  fontSize = sz(18), fontWeight = "bold", fontColor = C.title },
                    UI.Label { text = "MAIL", fontSize = sz(11), fontColor = C.dateText },
                },
            },
            UI.Panel { flexGrow = 1 },
            UI.Panel {
                width = sz(34), height = sz(34),
                borderRadius = sz(4),
                backgroundColor = C.closeBg,
                borderWidth = 1, borderColor = C.closeBdr,
                alignItems = "center", justifyContent = "center",
                cursor = "pointer",
                onClick = GoBack,
                children = {
                    UI.Label { text = "✕", fontSize = sz(18), fontWeight = "bold", fontColor = C.closeText },
                },
            },
        },
    }

    -- ── 底栏 ─────────────────────────────────────────────────────────────────
    local total  = #mails
    -- 未读数：普通邮件未读 + 所有溢出邮件（溢出邮件始终算未领取）
    local unread = SaveSystem.GetUnreadMailCount() + #(SaveSystem.GetOverflowMails())

    local bottomBar = UI.Panel {
        width = "100%",
        flexDirection = "row", alignItems = "center",
        gap = sz(8),
        paddingHorizontal = sz(10), paddingVertical = sz(9),
        borderTopWidth = 1, borderColor = { 255, 255, 255, 10 },
        children = {
            UI.Button {
                text = "返回",
                width = sz(100), paddingVertical = sz(7),
                fontSize = sz(13), fontWeight = "bold",
                fontColor = C.backText,
                backgroundColor = C.backBg,
                hoverBackgroundColor = { 195, 215, 40, 50 },
                pressedBackgroundColor = { 195, 215, 40, 110 },
                borderWidth = 1, borderColor = C.backBdr,
                borderRadius = sz(4),
                onClick = GoBack,
            },
            UI.Panel { flexGrow = 1 },
            UI.Button {
                text = "全部领取",
                width = sz(100), paddingVertical = sz(7),
                fontSize = sz(13), fontWeight = "bold",
                fontColor = C.claimText,
                backgroundColor = C.claimBg,
                hoverBackgroundColor = C.claimHv,
                pressedBackgroundColor = C.claimPr,
                borderRadius = sz(4),
                onClick = ClaimAll,
            },
            UI.Button {
                text = "删除已读",
                width = sz(100), paddingVertical = sz(7),
                fontSize = sz(13), fontWeight = "bold",
                fontColor = C.backText,
                backgroundColor = C.backBg,
                hoverBackgroundColor = { 195, 215, 40, 50 },
                pressedBackgroundColor = { 195, 215, 40, 110 },
                borderWidth = 1, borderColor = C.backBdr,
                borderRadius = sz(4),
                onClick = function()
                    Utils.PlayClick()
                    local count = 0
                    local current = BuildMailList_GetMails()
                    for _, m in ipairs(current) do
                        if m.isOverflow then
                            -- 溢出邮件不删除
                        elseif SaveSystem.IsMailRead(m.id) then
                            -- 有未领取附件的不删除
                            local hasReward = (m.rewards and #m.rewards > 0) or m.reward ~= nil
                            if hasReward and not SaveSystem.IsMailClaimed(m.id) then
                                -- 跳过
                            else
                                SaveSystem.DismissMail(m.id)
                                count = count + 1
                            end
                        end
                    end
                    if count > 0 then
                        FloatingMsg.Show("已删除 " .. count .. " 封已读邮件")
                        mails = BuildMailList_GetMails()
                        selectedMail = nil
                        BuildMailList()
                        BuildMailContent(nil)
                    else
                        FloatingMsg.Show("没有可删除的邮件")
                    end
                end,
            },
            UI.Label {
                text = string.format("%d/%d 封", total - unread, total),
                fontSize = sz(11), fontColor = C.dateText,
            },
        },
    }

    -- ── SetRoot ───────────────────────────────────────────────────────────────
    UI.SetRoot(UI.Panel {
        width = "100%", height = "100%",
        backgroundImage = "image/task_bg_20260516170303.jpg",
        backgroundFit = "cover",
        children = {
            -- 高斯模糊遮罩（全屏覆盖）
            UI.Panel {
                position = "absolute", left = 0, top = 0, right = 0, bottom = 0,
                backdropBlur = 40, backgroundColor = C.bg,
            },
            UI.SafeAreaView {
                edges = "all", width = "100%", height = "100%",
                children = {
                    UI.Panel {
                        width = "100%", height = "100%",
                        flexDirection = "column",
                        children = {
                            topBar,
                    -- ── 主体：左右分栏 ────────────────────────────────────────
                    UI.Panel {
                        width = "100%", flexGrow = 1, flexShrink = 1,
                        flexDirection = "row",
                        paddingHorizontal = sz(10), paddingVertical = sz(8),
                        gap = sz(10),
                        overflow = "hidden",
                        children = {
                            -- 左栏：邮件列表
                            UI.Panel {
                                width = sz(280), flexShrink = 0,
                                flexDirection = "column",
                                backgroundColor = C.listBg,
                                borderWidth = 1, borderColor = C.panelBdr,
                                borderRadius = sz(6),
                                overflow = "hidden",
                                children = { mailListContainer },
                            },
                            -- 右栏：正文（上）+ 奖励（下）
                            UI.Panel {
                                flexGrow = 1, flexShrink = 1,
                                flexDirection = "column",
                                borderWidth = 1, borderColor = C.panelBdr,
                                borderRadius = sz(6),
                                overflow = "hidden",
                                children = {
                                    -- 正文区（可撑满）
                                    UI.Panel {
                                        width = "100%", flexGrow = 1, flexShrink = 1,
                                        flexDirection = "column",
                                        overflow = "hidden",
                                        children = { mailBodyContainer },
                                    },
                                    -- 奖励格子区（高度自适应内容）
                                    mailRewardContainer,
                                },
                            },
                        },
                    },
                            bottomBar,
                        },
                    },
                },
            },
        },
    })
end

function MailPanel.IsOpen()
    return UIState.currentScreen == "mail"
end

function MailPanel.GoBack()
    if goBackFn then goBackFn() end
end

return MailPanel
