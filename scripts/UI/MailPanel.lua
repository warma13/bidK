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
    elseif reward.type == "ticket" then
        SaveSystem.AddTickets(reward.ticketId, reward.amount or 1)
        SaveFW.MarkDirty("save_system")
    end
end

-- ============================================================================
-- 主入口
-- ============================================================================
function MailPanel.Show(onBackCallback)
    UIState.currentScreen = "mail"
    local sz    = Utils.sz

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
                body     = "您开箱获得的【" .. (m.name or "物品") .. "】因仓库空间不足无法放入，请领取后存入仓库。",
                -- 标记为溢出邮件，领取走特殊逻辑
                isOverflow  = true,
                overflowItem = m,
                -- 奖励展示用字段
                reward   = {
                    type    = "_overflow_item",
                    _item   = m,
                },
            }
        end
        -- 系统邮件
        local sysMails = Config.MAILS or {}
        for _, m in ipairs(sysMails) do
            result[#result + 1] = m
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
        UIState.currentScreen = "menu"
        if onBackCallback then
            onBackCallback()
        else
            local GameController = require("UI.GameController")
            GameController.ShowMenu()
        end
    end

    -- ── 构建奖励格子区 ────────────────────────────────────────────────────────
    local function BuildRewardArea(mail)
        mailRewardContainer:ClearChildren()
        if not mail or not mail.reward then return end

        local reward = mail.reward
        local cell   ---@type table
        local claimBtn ---@type table

        -- ── 溢出邮件（开箱仓库满）────────────────────────────────────────────
        if mail.isOverflow then
            local item = mail.overflowItem
            -- 用物品图片显示格子
            cell = RewardSlot.Make({
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
                    -- 刷新邮件列表（溢出邮件已消费）
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
                backgroundColor = C.claimBg,
                hoverBackgroundColor = C.claimHv,
                cursor = "pointer",
                onClick = DoClaimOverflow,
                children = {
                    UI.Label { text = "领取", fontSize = sz(13), fontWeight = "bold", fontColor = C.claimText },
                },
            }

        -- ── 普通系统邮件 ──────────────────────────────────────────────────────
        else
            local isClaimed = SaveSystem.IsMailClaimed(mail.id)
            local icon      = RewardIcon(reward)
            local count     = RewardCount(reward)
            local name      = RewardName(reward)

            local function DoClaim()
                Utils.PlayClick()
                if not SaveSystem.ClaimMail(mail.id) then return end
                GiveReward(reward)
                FloatingMsg.Show("已领取：" .. name .. " " .. count)
                BuildMailContent(mail)
                BuildMailList()
            end

            -- 格子（使用共享 RewardSlot 组件）
            cell = RewardSlot.FromReward(reward, sz)

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
                    backgroundColor = C.claimBg,
                    hoverBackgroundColor = C.claimHv,
                    cursor = "pointer",
                    onClick = DoClaim,
                    children = {
                        UI.Label { text = "领取", fontSize = sz(13), fontWeight = "bold", fontColor = C.claimText },
                    },
                }
            end
        end

        mailRewardContainer:AddChild(UI.Panel {
            width = "100%",
            flexDirection = "column",
            gap = sz(6),
            paddingHorizontal = sz(14), paddingVertical = sz(10),
            backgroundColor = C.rewardBg,
            borderTopWidth = 1, borderColor = C.rewardBdr,
            children = {
                -- 顶行：标题
                UI.Label { text = "邮件附件", fontSize = sz(11), fontColor = C.dateText },
                -- 底行：格子横排 + 领取按钮
                UI.Panel {
                    width = "100%",
                    flexDirection = "row", alignItems = "center",
                    gap = sz(8),
                    children = {
                        cell,
                        UI.Panel { flexGrow = 1 },
                        claimBtn,
                    },
                },
            },
        })
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

    -- ── 构建邮件列表 ──────────────────────────────────────────────────────────
    BuildMailList = function()
        rowPanels = {}
        mailListContainer:ClearChildren()
        -- 每次重建列表时刷新邮件数据（溢出邮件可能已变化）
        mails = BuildMailList_GetMails()

        if #mails == 0 then
            mailListContainer:AddChild(UI.Panel {
                width = "100%", flexGrow = 1,
                alignItems = "center", justifyContent = "center",
                children = {
                    UI.Label { text = "暂无邮件", fontSize = sz(13), fontColor = C.noMailText },
                },
            })
            return
        end

        local rows = {}
        for _, mail in ipairs(mails) do
            local m         = mail
            local isRead    = SaveSystem.IsMailRead(m.id)
            local isClaimed = SaveSystem.IsMailClaimed(m.id)
            local isSelected = (selectedMail and selectedMail.id == m.id)
            local hasReward  = m.reward ~= nil
            local showDot    = not isRead or (hasReward and not isClaimed)

            -- 未读圆点
            local dot = UI.Panel {
                width = sz(6), height = sz(6),
                borderRadius = sz(3), flexShrink = 0,
                marginTop = sz(2),
                backgroundColor = showDot and C.unreadDot or { 0, 0, 0, 0 },
            }

            -- 有奖励角标
            local badge
            if hasReward then
                badge = UI.Panel {
                    paddingHorizontal = sz(5), paddingVertical = sz(1),
                    backgroundColor = isClaimed and { 40, 42, 52, 160 } or C.rewardBg,
                    borderWidth = 1,
                    borderColor = isClaimed and C.divider or C.rewardBdr,
                    borderRadius = sz(2),
                    children = {
                        UI.Label {
                            text = isClaimed and "已领取" or "有附件",
                            fontSize = sz(9), fontWeight = "bold",
                            fontColor = isClaimed and C.claimedText or C.rewardText,
                        },
                    },
                }
            end

            rows[#rows + 1] = UI.Panel {
                width = "100%",
                flexDirection = "row", alignItems = "flex-start",
                gap = sz(8),
                paddingHorizontal = sz(10), paddingVertical = sz(9),
                marginBottom = sz(4),
                backgroundColor = isSelected and C.rowActive or { 0, 0, 0, 0 },
                borderWidth = 1,
                borderColor = isSelected and { 195, 215, 40, 120 } or C.rowBdr,
                borderRadius = sz(4),
                cursor = "pointer",
                hoverBackgroundColor = isSelected and C.rowActive or C.rowHover,
                onClick = function()
                    Utils.PlayClick()
                    SelectRow(m.id)
                    selectedMail = m
                    BuildMailContent(m)
                end,
                children = {
                    dot,
                    UI.Panel {
                        flexGrow = 1, flexShrink = 1,
                        flexDirection = "column", gap = sz(4),
                        children = {
                            -- 标题行 + 附件角标
                            UI.Panel {
                                width = "100%",
                                flexDirection = "row", alignItems = "center", gap = sz(6),
                                children = {
                                    UI.Label {
                                        text = m.title or "",
                                        fontSize = sz(12),
                                        fontWeight = isRead and "normal" or "bold",
                                        fontColor = isRead and C.dimText or C.title,
                                        flexShrink = 1,
                                    },
                                    badge or UI.Panel { width = 0 },
                                },
                            },
                            -- 发件人 + 过期时间
                            UI.Panel {
                                flexDirection = "row", alignItems = "center", gap = sz(8),
                                children = {
                                    UI.Label { text = m.sender or "", fontSize = sz(10), fontColor = C.sender },
                                    UI.Label { text = m.expiry or "", fontSize = sz(10), fontColor = C.expiry },
                                },
                            },
                        },
                    },
                },
            }
            rowPanels[m.id] = rows[#rows]
        end

        mailListContainer:AddChild(UI.ScrollView {
            width = "100%", flexGrow = 1,
            paddingHorizontal = sz(6), paddingTop = sz(6),
            children = rows,
        })
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
            elseif m.reward and not SaveSystem.IsMailClaimed(m.id) then
                if SaveSystem.ClaimMail(m.id) then
                    GiveReward(m.reward)
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
                width = sz(110), paddingVertical = sz(7),
                fontSize = sz(13), fontWeight = "bold",
                fontColor = C.claimText,
                backgroundColor = C.claimBg,
                hoverBackgroundColor = C.claimHv,
                pressedBackgroundColor = C.claimPr,
                borderRadius = sz(4),
                onClick = ClaimAll,
            },
            UI.Label {
                text = string.format("%d/%d 封", total - unread, total),
                fontSize = sz(11), fontColor = C.dateText,
            },
        },
    }

    -- ── SetRoot ───────────────────────────────────────────────────────────────
    UI.SetRoot(UI.SafeAreaView {
        edges = "all", width = "100%", height = "100%",
        children = {
            UI.Panel {
                width = "100%", height = "100%",
                backgroundImage = "image/task_bg_20260516170303.jpg",
                backgroundFit = "cover",
                flexDirection = "column",
                children = {
                    UI.Panel {
                        position = "absolute", left = 0, top = 0, right = 0, bottom = 0,
                        backdropBlur = 40, backgroundColor = C.bg,
                    },
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
    })
end

return MailPanel
