-- ============================================================================
-- UI/DebugPanel.lua - 调试面板 + 常驻HUD（用户ID / 版本号）
-- ============================================================================

---@diagnostic disable: undefined-global

local UI = require("urhox-libs/UI")
local GameState = require("GameState")
local AuctionEngine = require("AuctionEngine")
local SaveSystem = require("SaveSystem")
local SaveFramework = require("SaveFramework")
local MoneyHUD = require("UI.MoneyHUD")
local SettingsPanel = require("UI.SettingsPanel")
local Utils = require("UI.Utils")
local SeasonPass = require("SeasonPass")

local DebugPanel = {}

local Config = require("Config")
local VERSION = "v" .. Config.GAME.Version

-- 这些用户可显示完整调试面板
local DEBUG_USER_IDS = {
    [413248871] = true,
    [1564171575] = true,
}

local hudRoot = nil
local debugPanel = nil
local debugVisible = false
local userIdLabel = nil

-- 动态数值标签（每帧刷新）
local labels = {}

-- ============================================================================
-- 创建常驻 HUD（用户ID右上角 + 版本号左下角）
-- ============================================================================

--- 获取当前用户ID（多处 fallback）
local function GetMyUserId()
    if lobby then
        local uid = lobby:GetMyUserId()
        if uid ~= 0 then return uid end
    end
    local ok, gs = pcall(require, "GameState")
    if ok and gs.GetMyUserId then return gs.GetMyUserId() end
    return 0
end

function DebugPanel.CreateHUD()
    -- 每次重建 HUD 时重置 debugPanel，防止旧节点脱离 UI 树后 Toggle 失效
    debugPanel = nil
    debugVisible = false
    -- 右上角用户ID（独立可点击，不在 pointerEvents=none 容器内）
    local userIdBadge = UI.Panel {
        position = "absolute",
        right = 8, top = 6,
        backgroundColor = { 0, 0, 0, 100 },
        borderRadius = 0,
        paddingHorizontal = 8, paddingVertical = 3,
        onClick = function() DebugPanel.Toggle() end,
        children = {
            UI.Label {
                id = "debugUserIdLabel",
                text = "Guest",
                fontSize = 10, fontColor = { 180, 185, 200, 180 },
            },
        },
    }

    -- 其余装饰层（不拦截点击）
    local decorLayer = UI.Panel {
        position = "absolute",
        left = 0, top = 0,
        width = "100%", height = "100%",
        pointerEvents = "none",
        children = {
            -- 左下角：版本号
            UI.Panel {
                position = "absolute",
                left = 8, bottom = 6,
                backgroundColor = { 0, 0, 0, 100 },
                borderRadius = 0,
                paddingHorizontal = 8, paddingVertical = 3,
                children = {
                    UI.Label {
                        text = VERSION,
                        fontSize = 10, fontColor = { 180, 185, 200, 180 },
                    },
                },
            },
        },
    }

    -- hudRoot：box-none = 自身不拦截点击，但子节点可响应
    hudRoot = UI.Panel {
        position = "absolute",
        left = 0, top = 0,
        width = "100%", height = "100%",
        pointerEvents = "box-none",
        children = { decorLayer, userIdBadge },
    }
    userIdLabel = hudRoot:FindById("debugUserIdLabel")
    DebugPanel.RefreshUserId()
    return hudRoot
end

--- 刷新用户ID显示（当 lobby 延迟可用时调用）
function DebugPanel.RefreshUserId()
    local myUserId = GetMyUserId()
    local userId = myUserId ~= 0 and tostring(myUserId) or "Guest"
    if userIdLabel then
        userIdLabel:SetText(userId)
        -- debug 用户变金色
        if DEBUG_USER_IDS[myUserId] then
            userIdLabel:SetStyle({ fontColor = { 255, 200, 80, 220 } })
        end
    end
end

-- ============================================================================
-- 工具：创建一行「标签 + 减 + 当前值 + 加」
-- ============================================================================

local function FormatVal(v)
    if type(v) ~= "number" then return tostring(v or "—") end
    if math.abs(v) >= 10000 then return Utils.FormatMoney(v) end
    return tostring(math.floor(v))
end

local function MakeRow(opts)
    local sz   = Utils.sz
    local step = opts.step or 1

    local valLabel = UI.Label {
        text = FormatVal(opts.get()), fontSize = sz(11),
        fontColor = { 220, 230, 255, 255 },
        width = sz(70), textAlign = "center",
    }

    local function refresh()
        local ok, v = pcall(opts.get)
        valLabel:SetText(ok and FormatVal(v) or "—")
    end

    labels[opts.key] = { label = valLabel, get = opts.get }

    return UI.Panel {
        flexDirection = "row", alignItems = "center",
        width = "100%", gap = sz(4),
        children = {
            UI.Label {
                text = opts.label, fontSize = sz(11),
                fontColor = { 160, 170, 200, 255 },
                width = sz(90), flexShrink = 0,
            },
            UI.Button {
                text = "-", width = sz(28), height = sz(24), fontSize = sz(12),
                onClick = function()
                    Utils.PlayClick()
                    opts.add(-step)
                    refresh()
                end,
            },
            valLabel,
            UI.Button {
                text = "+", width = sz(28), height = sz(24), fontSize = sz(12),
                variant = "primary",
                onClick = function()
                    Utils.PlayClick()
                    opts.add(step)
                    refresh()
                end,
            },
        },
    }
end

-- ── 分割线 ────────────────────────────────────────────
local function Divider()
    return UI.Panel {
        width = "100%", height = 1,
        backgroundColor = { 80, 90, 120, 120 },
    }
end

-- ============================================================================
-- 创建 F8 调试面板
-- ============================================================================

function DebugPanel.CreateDebugPanel()
    local sz = Utils.sz
    local myUserId = lobby and lobby:GetMyUserId() or 0
    -- 非调试用户只创建游戏内原有的简单面板
    if not DEBUG_USER_IDS[myUserId] then
        return DebugPanel.CreateSimplePanel()
    end

    local AdCardPanel = require("UI.AdCardPanel")

    -- ---- 金币行 ----
    local moneyRow = MakeRow {
        key = "money", label = "金币",
        get = function() return MoneyHUD.GetMoney() end,
        add = function(delta)
            local p = GameState.GetPlayers()
            if p and p[1] then
                GameState.SecureAddMoney(1, delta, "debug", "debug_panel")
            else
                MoneyHUD.SetMoney(math.max(0, MoneyHUD.GetMoney() + delta))
                SaveFramework.MarkDirty("money")  -- MoneyManager.MODULE_NAME
            end
        end,
        step = 1000000,
    }

    -- ---- 卡点行 ----
    local cardPointsRow = MakeRow {
        key = "cardPoints", label = "卡点",
        get = function() return AdCardPanel.DebugGetCardPoints() end,
        add = function(delta)
            AdCardPanel.DebugSetCardPoints(AdCardPanel.DebugGetCardPoints() + delta)
        end,
        step = 10,
    }

    -- ---- 广告次数行 ----
    local adCountRow = MakeRow {
        key = "adCount", label = "广告次数",
        get = function() return AdCardPanel.DebugGetDailyCount() end,
        add = function(delta)
            AdCardPanel.DebugSetDailyCount(AdCardPanel.DebugGetDailyCount() + delta)
        end,
        step = 1,
    }

    -- ---- 角色币行 ----
    local charCoinRow = MakeRow {
        key = "charCoins", label = "角色币",
        get = function() return SaveSystem.GetCharacterCoins() end,
        add = function(delta)
            SaveSystem.DebugSetCharacterCoins(SaveSystem.GetCharacterCoins() + delta)
        end,
        step = 5,
    }

    -- ---- 点券行 ----
    local pointTicketRow = MakeRow {
        key = "pointTickets", label = "点券",
        get = function() return SaveSystem.GetPointTickets() end,
        add = function(delta)
            local cur = SaveSystem.GetPointTickets()
            if delta > 0 then
                SaveSystem.AddPointTickets(delta)
            elseif delta < 0 then
                SaveSystem.SpendPointTickets(math.min(-delta, cur))
            end
        end,
        step = 100,
    }

    -- ---- 礼盒行 ----
    local chestRow = MakeRow {
        key = "chest_s1", label = "1期礼盒",
        get = function() return SaveSystem.GetPropCount("chest_s1") end,
        add = function(delta)
            local cur = SaveSystem.GetPropCount("chest_s1")
            local nxt = math.max(0, cur + delta)
            SaveSystem.DebugSetProp("chest_s1", nxt)
        end,
        step = 1,
    }

    -- ---- 藏品箱行 ----
    local chestCommonRow = MakeRow {
        key = "chest_common", label = "初级藏品箱",
        get = function() return SaveSystem.GetPropCount("chest_common") end,
        add = function(delta)
            local cur = SaveSystem.GetPropCount("chest_common")
            SaveSystem.DebugSetProp("chest_common", math.max(0, cur + delta))
        end,
        step = 1,
    }
    local chestSilverRow = MakeRow {
        key = "chest_silver", label = "中级藏品箱",
        get = function() return SaveSystem.GetPropCount("chest_silver") end,
        add = function(delta)
            local cur = SaveSystem.GetPropCount("chest_silver")
            SaveSystem.DebugSetProp("chest_silver", math.max(0, cur + delta))
        end,
        step = 1,
    }
    local chestGoldRow = MakeRow {
        key = "chest_gold", label = "高级藏品箱",
        get = function() return SaveSystem.GetPropCount("chest_gold") end,
        add = function(delta)
            local cur = SaveSystem.GetPropCount("chest_gold")
            SaveSystem.DebugSetProp("chest_gold", math.max(0, cur + delta))
        end,
        step = 1,
    }

    -- ---- 道具箱行 ----
    local propBoxWhiteRow = MakeRow {
        key = "prop_box_white", label = "白色道具箱",
        get = function() return SaveSystem.GetPropCount("prop_box_white") end,
        add = function(delta)
            local cur = SaveSystem.GetPropCount("prop_box_white")
            SaveSystem.DebugSetProp("prop_box_white", math.max(0, cur + delta))
        end,
        step = 1,
    }
    local propBoxGreenRow = MakeRow {
        key = "prop_box_green", label = "绿色道具箱",
        get = function() return SaveSystem.GetPropCount("prop_box_green") end,
        add = function(delta)
            local cur = SaveSystem.GetPropCount("prop_box_green")
            SaveSystem.DebugSetProp("prop_box_green", math.max(0, cur + delta))
        end,
        step = 1,
    }
    local propBoxBlueRow = MakeRow {
        key = "prop_box_blue", label = "蓝色道具箱",
        get = function() return SaveSystem.GetPropCount("prop_box_blue") end,
        add = function(delta)
            local cur = SaveSystem.GetPropCount("prop_box_blue")
            SaveSystem.DebugSetProp("prop_box_blue", math.max(0, cur + delta))
        end,
        step = 1,
    }
    local propBoxPurpleRow = MakeRow {
        key = "prop_box_purple", label = "紫色道具箱",
        get = function() return SaveSystem.GetPropCount("prop_box_purple") end,
        add = function(delta)
            local cur = SaveSystem.GetPropCount("prop_box_purple")
            SaveSystem.DebugSetProp("prop_box_purple", math.max(0, cur + delta))
        end,
        step = 1,
    }

    -- ---- 门票行 ----
    local ticketRows = {}
    for tid, tcfg in pairs(Config.TICKETS) do
        local capturedId = tid
        ticketRows[#ticketRows + 1] = MakeRow {
            key = "ticket_" .. tid, label = tcfg.name:gsub("场门票", ""),
            get = function() return SaveSystem.GetTicketCount(capturedId) end,
            add = function(delta)
                local cur = SaveSystem.GetTicketCount(capturedId)
                SaveSystem.DebugSetTicket(capturedId, cur + delta)
            end,
            step = 1,
        }
    end

    -- ---- 组装 ----
    local children = {
        -- 标题行 + 关闭按钮
        UI.Panel {
            flexDirection = "row", alignItems = "center",
            justifyContent = "space-between", width = "100%",
            children = {
                UI.Label {
                    text = "Debug Panel", fontSize = sz(13),
                    fontColor = { 255, 200, 80, 255 }, fontWeight = "bold",
                },
                UI.Panel {
                    flexDirection = "row", alignItems = "center", gap = sz(6),
                    children = {
                        UI.Button {
                            text = "✕", width = sz(24), height = sz(24), fontSize = sz(13),
                            onClick = function() DebugPanel.Toggle() end,
                        },
                    },
                },
            },
        },
        -- 游戏内快捷按钮
        UI.Panel {
            flexDirection = "row", width = "100%", gap = sz(6),
            children = {
                UI.Button {
                    text = "跳过倒计时", flexGrow = 1, height = sz(28), fontSize = sz(11),
                    onClick = function()
                        Utils.PlayClick()
                        AuctionEngine.DebugSkipTimer()
                        Utils.ShowMessage("[Debug] 倒计时已跳过")
                    end,
                },
                UI.Button {
                    text = "进入竞拍", flexGrow = 1, height = sz(28), fontSize = sz(11),
                    onClick = function()
                        Utils.PlayClick()
                        AuctionEngine.DebugEnterTiebreak()
                        Utils.ShowMessage("[Debug] 已进入实时竞拍")
                        DebugPanel.Toggle()
                    end,
                },
            },
        },
        Divider(),
        -- 数值调整
        moneyRow,
        cardPointsRow,
        adCountRow,
        charCoinRow,
        pointTicketRow,
    }
    -- 门票
    for _, row in ipairs(ticketRows) do
        children[#children + 1] = row
    end

    -- 礼盒区块
    children[#children + 1] = Divider()
    children[#children + 1] = UI.Label {
        text = "礼盒 / 藏品箱", fontSize = sz(11),
        fontColor = { 255, 200, 80, 200 },
    }
    children[#children + 1] = chestRow
    children[#children + 1] = chestCommonRow
    children[#children + 1] = chestSilverRow
    children[#children + 1] = chestGoldRow

    -- 道具箱区块
    children[#children + 1] = UI.Label {
        text = "道具箱", fontSize = sz(11),
        fontColor = { 180, 220, 255, 200 },
    }
    children[#children + 1] = propBoxWhiteRow
    children[#children + 1] = propBoxGreenRow
    children[#children + 1] = propBoxBlueRow
    children[#children + 1] = propBoxPurpleRow

    -- 限定藏品区块
    children[#children + 1] = Divider()
    children[#children + 1] = UI.Label {
        text = "限定红藏品（直接入库）", fontSize = sz(11),
        fontColor = { 255, 100, 100, 220 },
    }
    local exclusiveItems = {
        { name = "霍普蓝钻",          value = 80000000 },
        { name = "百达翡丽Cal.89怀表", value = 35000000 },
        { name = "乾隆御制珐琅彩瓶",  value = 25000000 },
        { name = "达利原作油画",       value = 15000000 },
    }
    for _, def in ipairs(exclusiveItems) do
        local captureName  = def.name
        local captureValue = def.value
        children[#children + 1] = UI.Button {
            text = captureName .. "（" .. Utils.FormatMoney(captureValue) .. "）",
            width = "100%", height = sz(28), fontSize = sz(11),
            onClick = function()
                Utils.PlayClick()
                SaveSystem.AddWonItems({
                    { name = captureName, baseValue = captureValue }
                })
                SaveFramework.MarkDirty("debug_exclusive")
                Utils.ShowMessage("[Debug] 已添加：" .. captureName)
            end,
        }
    end

    -- 通行证 XP 区块
    local xpRow = MakeRow {
        key  = "seasonXP", label = "通行证XP",
        get  = function() return SeasonPass.GetXP() end,
        add  = function(delta) SeasonPass.DebugAddXP(delta) end,
        step = 1000,
    }
    children[#children + 1] = Divider()
    children[#children + 1] = UI.Label {
        text = "通行证", fontSize = sz(11),
        fontColor = { 255, 200, 80, 200 },
    }
    children[#children + 1] = xpRow

    -- 版本检测区块
    children[#children + 1] = Divider()

    local versionInfoLabel = UI.Label {
        id = "debugVersionInfo",
        text = "", fontSize = sz(10),
        fontColor = { 160, 170, 200, 255 },
        width = "100%",
    }
    labels["_versionInfo"] = {
        label = versionInfoLabel,
        get = function()
            local info = SettingsPanel.DebugGetVersionInfo()
            local status = info.hasNewVersion and "有新版本" or "已是最新"
            local lastCheck = info.lastCheckTime > 0
                and os.date("%H:%M:%S", info.lastCheckTime) or "未检测"
            return string.format(
                "本地: v%s (%d) | %s\n上次: %s | 定时: %s",
                info.localVersion, info.localEncoded, status,
                lastCheck, info.timerRunning and "开" or "关"
            )
        end,
    }
    children[#children + 1] = UI.Label {
        text = "版本检测", fontSize = sz(11),
        fontColor = { 255, 200, 80, 200 },
    }
    children[#children + 1] = versionInfoLabel
    children[#children + 1] = UI.Button {
        text = "手动检测版本", width = "100%", height = sz(28), fontSize = sz(11),
        onClick = function()
            Utils.PlayClick()
            SettingsPanel.DebugDoVersionCheck()
            Utils.ShowMessage("[Debug] 已触发版本检测")
        end,
    }

    children[#children + 1] = Divider()
    children[#children + 1] = UI.Button {
        text = "保存", width = "100%", height = sz(28), fontSize = sz(11),
        variant = "primary",
        onClick = function()
            Utils.PlayClick()
            SaveSystem.SaveNow()
            Utils.ShowMessage("[Debug] 已触发保存")
        end,
    }

    -- 面板外框
    local panelWidth  = sz(260)
    local panelHeight = sz(500)

    -- 内容滚动区（用 ScrollView 避免 overflow 吞掉点击事件）
    local scrollArea = UI.ScrollView {
        width = "100%", flexGrow = 1,
        children = {
            UI.Panel {
                width = "100%",
                flexDirection = "column",
                alignItems = "stretch",
                gap = sz(6),
                padding = sz(12),
            },
        },
    }
    -- 把 children 从第2项起（内容行）加入滚动区内容 Panel
    -- 第1项是标题行，单独放在面板顶部（固定不滚动）
    local titleRow  = children[1]
    local innerPanel = scrollArea.children[1]
    for i = 2, #children do
        innerPanel:AddChild(children[i])
    end

    debugPanel = UI.Panel {
        position = "absolute",
        left = "50%", top = "50%",
        marginLeft = -panelWidth / 2, marginTop = -panelHeight / 2,
        width = panelWidth,
        height = panelHeight,
        backgroundColor = { 12, 15, 26, 240 },
        borderRadius = sz(4),
        borderWidth = 1, borderColor = { 80, 90, 120, 180 },
        flexDirection = "column",
        alignItems = "stretch",
        visible = false,
        children = {
            -- 固定标题行
            UI.Panel {
                width = "100%",
                paddingHorizontal = sz(12), paddingTop = sz(12), paddingBottom = sz(6),
                flexDirection = "column", gap = sz(6),
                children = {
                    titleRow,
                    Divider(),
                },
            },
            -- 可滚动内容
            scrollArea,
        },
    }
    return debugPanel
end

-- ============================================================================
-- 简易面板（非调试用户）
-- ============================================================================

function DebugPanel.CreateSimplePanel()
    local sz = Utils.sz

    debugPanel = UI.Panel {
        position = "absolute",
        left = "50%", top = "50%",
        marginLeft = -sz(120), marginTop = -sz(60),
        width = sz(240),
        backgroundColor = { 15, 18, 30, 230 },
        borderRadius = 0,
        borderWidth = 1, borderColor = { 80, 90, 120, 150 },
        padding = sz(12), gap = sz(8),
        flexDirection = "column",
        alignItems = "center",
        visible = false,
        children = {
            UI.Label {
                text = "Debug", fontSize = sz(14),
                fontColor = { 255, 200, 80, 255 }, fontWeight = "bold",
            },
            UI.Button {
                text = "跳过倒计时", width = "100%", height = sz(32), fontSize = sz(12),
                onClick = function()
                    Utils.PlayClick()
                    AuctionEngine.DebugSkipTimer()
                    Utils.ShowMessage("[Debug] 倒计时已跳过")
                end,
            },
            UI.Button {
                text = "+1250万", width = "100%", height = sz(32), fontSize = sz(12),
                variant = "primary",
                onClick = function()
                    Utils.PlayClick()
                    GameState.AddMoney(1, 12500000)
                    Utils.ShowMessage("[Debug] +1250万")
                end,
            },
            UI.Button {
                text = "进入竞拍", width = "100%", height = sz(32), fontSize = sz(12),
                onClick = function()
                    Utils.PlayClick()
                    AuctionEngine.DebugEnterTiebreak()
                    Utils.ShowMessage("[Debug] 已进入实时竞拍")
                    DebugPanel.Toggle()
                end,
            },
        },
    }
    return debugPanel
end

-- ============================================================================
-- F8 / 点击切换（懒创建，鉴权）
-- ============================================================================

function DebugPanel.Toggle()
    local myUserId = GetMyUserId()
    if not DEBUG_USER_IDS[myUserId] then return end

    -- 懒创建：第一次 toggle 时才构建 panel 并挂到 hudRoot
    if not debugPanel and hudRoot then
        local panel = DebugPanel.CreateDebugPanel()
        hudRoot:AddChild(panel)
    end

    debugVisible = not debugVisible
    if debugPanel then
        debugPanel:SetVisible(debugVisible)
    end
end

-- ============================================================================
-- 帧更新（F8 按键 + 刷新数值标签）
-- ============================================================================

function DebugPanel.HandleUpdate()
    if input:GetKeyPress(KEY_F8) then
        DebugPanel.Toggle()
    end
    -- lobby 就绪后刷新一次用户ID显示
    if not DebugPanel._userIdRefreshed then
        local uid = GetMyUserId()
        if uid ~= 0 then
            DebugPanel.RefreshUserId()
            DebugPanel._userIdRefreshed = true
        end
    end

    if debugVisible then
        for _, entry in pairs(labels) do
            local ok, val = pcall(entry.get)
            if ok and entry.label then
                local txt = type(val) == "number"
                    and (math.abs(val) >= 10000 and Utils.FormatMoney(val) or tostring(math.floor(val)))
                    or tostring(val or "—")
                entry.label:SetText(txt)
            end
        end
    end
end

return DebugPanel
