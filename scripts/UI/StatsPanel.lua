-- ============================================================================
-- UI/StatsPanel.lua - 战绩统计面板（按钮 + 弹窗）
-- ============================================================================

---@diagnostic disable: undefined-global

local UI = require("urhox-libs/UI")
local Config = require("Config")
local Utils = require("UI.Utils")
local SaveSystem = require("SaveSystem")

local StatsPanel = {}

local C = Config.COLORS
local popupVisible = false
---@type table|nil
local popupOverlay = nil

-- ============================================================================
-- 格式化工具
-- ============================================================================

--- 格式化游戏时长：秒 → "X小时Y分钟" 或 "Y分钟"
local function FormatPlayTime(seconds)
    seconds = math.floor(seconds or 0)
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    if h > 0 then
        return h .. "小时" .. m .. "分钟"
    elseif m > 0 then
        return m .. "分钟"
    else
        return seconds .. "秒"
    end
end

--- 格式化大数字（万 / 亿）
local function FormatBig(n)
    n = math.floor(n or 0)
    local abs = math.abs(n)
    if abs >= 100000000 then
        return string.format("%.1f亿", n / 100000000)
    elseif abs >= 10000 then
        return string.format("%.1f万", n / 10000)
    end
    -- 千分位
    local neg = n < 0
    local s = tostring(abs)
    local result, count = "", 0
    for i = #s, 1, -1 do
        count = count + 1
        result = s:sub(i, i) .. result
        if count % 3 == 0 and i > 1 then result = "," .. result end
    end
    return neg and ("-" .. result) or result
end

--- 格式化精确数字（千分位）
local function FormatExact(n)
    n = math.floor(n or 0)
    local s = tostring(n)
    local result, count = "", 0
    for i = #s, 1, -1 do
        count = count + 1
        result = s:sub(i, i) .. result
        if count % 3 == 0 and i > 1 then result = "," .. result end
    end
    return result
end

--- 格式化百分比
local function FormatPct(num, denom)
    if not denom or denom == 0 then return "0.00%" end
    return string.format("%.2f%%", num / denom * 100)
end

-- ============================================================================
-- 统计项组件
-- ============================================================================

local function StatItem(label, value, highlight)
    local sz = Utils.sz
    local valColor = highlight and { 220, 195, 100, 255 } or { 240, 242, 248, 255 }
    return UI.Panel {
        flex = 1,
        flexDirection = "column",
        alignItems = "flex-start",
        paddingVertical = sz(12),
        paddingHorizontal = sz(16),
        children = {
            UI.Label {
                text = label,
                fontSize = sz(12),
                fontColor = { 140, 145, 160, 200 },
                marginBottom = sz(4),
            },
            UI.Label {
                text = value,
                fontSize = sz(20),
                fontWeight = "bold",
                fontColor = valColor,
            },
        },
    }
end

-- ============================================================================
-- 弹窗内容构建
-- ============================================================================

local function BuildContent()
    local sz = Utils.sz

    -- 读取统计数据
    local stats = SaveSystem.IsReady() and SaveSystem.GetStats() or {}
    local playTime = SaveSystem.GetPlayTime and SaveSystem.GetPlayTime() or 0
    -- playTime 还要加上存档里的累计值（SaveSystem.GetPlayTime 返回本次会话时长）
    -- 从存档 stats 里读累计时长（如果 SaveSystem 暴露了的话）
    local totalPlayTimeSec = playTime

    local totalGames   = stats.totalGames   or 0
    local wins         = stats.wins         or 0
    local totalProfit  = stats.totalProfit  or 0
    local maxProfit    = stats.maxProfit    or 0
    local highestBid   = stats.highestBid   or 0

    -- 计算总资产（仓库物品估值之和 + 当前金币）
    local totalAssets = 0
    local items = SaveSystem.IsReady() and SaveSystem.GetItems() or {}
    for _, item in ipairs(items) do
        totalAssets = totalAssets + (item.baseValue or 0)
    end
    -- 加上当前持有金币
    local okHUD, MoneyHUD = pcall(require, "UI.MoneyHUD")
    if okHUD and MoneyHUD and MoneyHUD.GetMoney then
        totalAssets = totalAssets + (MoneyHUD.GetMoney() or 0)
    end

    -- 胜率 = wins / totalGames
    local winRate   = FormatPct(wins, totalGames)
    -- 盈利比 = totalProfit / (所有竞拍总付款额) — 近似用 totalProfit / totalGames 的比例
    -- 简化：盈利比 = totalProfit / max(1, totalAssets-totalProfit) * 100%
    -- 实际使用：profit / winnerPaid（但 winnerPaid 未累计），改为 totalProfit / totalGames 对局平均
    local profitRatio = FormatPct(totalProfit, math.max(1, totalAssets))

    -- 行1：时长 / 局数 / 胜率 / 总资产
    -- 行2：盈利比 / 总盈利 / 单局最高 / 最高出价
    local rows = {
        {
            { label = "游戏时长",     value = FormatPlayTime(totalPlayTimeSec) },
            { label = "总竞拍局数",   value = FormatExact(totalGames) },
            { label = "竞拍成功率",   value = winRate },
            { label = "总资产",       value = FormatBig(totalAssets),    hi = true },
        },
        {
            { label = "总盈利比",     value = profitRatio },
            { label = "总盈利",       value = FormatExact(totalProfit),  hi = totalProfit > 0 },
            { label = "单局最高利润", value = FormatExact(maxProfit),    hi = maxProfit > 0 },
            { label = "最高出价",     value = FormatExact(highestBid) },
        },
    }

    local rowPanels = {}
    for _, row in ipairs(rows) do
        local items2 = {}
        for i, item in ipairs(row) do
            items2[#items2 + 1] = StatItem(item.label, item.value, item.hi)
            if i < #row then
                -- 分隔线
                items2[#items2 + 1] = UI.Panel {
                    width = 1, alignSelf = "stretch",
                    backgroundColor = { 255, 255, 255, 18 },
                }
            end
        end
        rowPanels[#rowPanels + 1] = UI.Panel {
            width = "100%",
            flexDirection = "row",
            backgroundColor = { 255, 255, 255, 5 },
            borderRadius = sz(4),
            children = items2,
        }
    end

    return UI.Panel {
        width = "100%",
        flexDirection = "column",
        gap = sz(2),
        children = rowPanels,
    }
end

-- ============================================================================
-- 公开接口
-- ============================================================================

--- 创建顶栏"战绩"按钮
function StatsPanel.CreateButton()
    local sz = Utils.sz
    popupVisible = false
    return UI.Panel {
        paddingHorizontal = sz(10), paddingVertical = sz(4),
        flexDirection = "column",
        alignItems = "center", justifyContent = "center",
        gap = sz(2),
        cursor = "pointer",
        backgroundColor = { 20, 24, 38, 180 },
        borderWidth = 1,
        borderColor = { 70, 85, 130, 160 },
        borderRadius = sz(6),
        onClick = function()
            Utils.PlayClick()
            popupVisible = not popupVisible
            if popupOverlay then
                popupOverlay:SetVisible(popupVisible)
                if popupVisible then
                    if popupOverlay._contentSlot then
                        local slot = popupOverlay._contentSlot
                        if slot._currentContent then
                            slot:RemoveChild(slot._currentContent)
                        end
                        local newContent = BuildContent()
                        slot._currentContent = newContent
                        slot:AddChild(newContent)
                    end
                end
            end
        end,
        children = {
            UI.Panel {
                width = sz(26), height = sz(26),
                backgroundImage = "image/nav_stats_20260515210551.png",
                backgroundFit = "contain",
                pointerEvents = "none",
            },
            UI.Label {
                text = "战绩",
                fontSize = sz(11), fontColor = { 200, 205, 220, 200 },
                pointerEvents = "none",
            },
        },
    }
end

--- 创建统计弹窗（放在 UI 树中）
function StatsPanel.CreatePopup()
    local sz = Utils.sz

    local initialContent = BuildContent()
    local contentSlot = UI.Panel {
        width = "100%",
        children = { initialContent },
    }
    contentSlot._currentContent = initialContent

    local popup = UI.Panel {
        position = "absolute",
        left = 0, top = 0, right = 0, bottom = 0,
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = { 0, 0, 0, 160 },
        visible = false,
        onClick = function()
            popupVisible = false
            if popupOverlay then popupOverlay:SetVisible(false) end
        end,
        children = {
            -- 弹窗卡片
            UI.Panel {
                width = sz(620),
                flexDirection = "column",
                backgroundColor = { 18, 20, 28, 248 },
                borderRadius = sz(6),
                borderWidth = 1,
                borderColor = { 80, 85, 100, 120 },
                overflow = "hidden",
                onClick = function() end, -- 阻止冒泡关闭
                children = {
                    -- 标题栏
                    UI.Panel {
                        width = "100%",
                        flexDirection = "row",
                        justifyContent = "space-between",
                        alignItems = "center",
                        paddingHorizontal = sz(20),
                        paddingVertical = sz(14),
                        backgroundColor = { 255, 255, 255, 8 },
                        children = {
                            UI.Label {
                                text = "战绩统计",
                                fontSize = sz(17),
                                fontWeight = "bold",
                                fontColor = { 220, 225, 240, 255 },
                            },
                            UI.Label {
                                text = "✕",
                                fontSize = sz(16),
                                fontColor = { 160, 165, 180, 200 },
                                cursor = "pointer",
                                onClick = function()
                                    popupVisible = false
                                    if popupOverlay then popupOverlay:SetVisible(false) end
                                end,
                            },
                        },
                    },
                    -- 分隔线
                    UI.Panel { width = "100%", height = 1, backgroundColor = { 255, 255, 255, 15 } },
                    -- 内容区
                    UI.Panel {
                        width = "100%",
                        padding = sz(12),
                        children = { contentSlot },
                    },
                },
            },
        },
    }

    -- 把 contentSlot 挂到 popup 上，方便刷新
    popup._contentSlot = contentSlot
    popupOverlay = popup
    return popup
end

return StatsPanel
