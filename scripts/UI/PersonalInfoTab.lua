-- ============================================================================
-- UI/PersonalInfoTab.lua
-- 个人信息页 - 信息 Tab（统计数据）
-- ============================================================================

---@diagnostic disable: undefined-global

local UI = require("urhox-libs/UI")
local UIState = require("UI.UIState")
local Utils = require("UI.Utils")
local SaveSystem = require("SaveSystem")
local Config = require("Config")
local PU = require("UI.PersonalInfoUtils")

local PersonalInfoTab = {}

local function StatCard(label, value, hiColor)
    local sz = Utils.sz
    return UI.Panel {
        flex = 1,
        flexDirection = "column",
        alignItems = "flex-start",
        paddingVertical = sz(14),
        paddingHorizontal = sz(18),
        backgroundColor = { 255, 255, 255, 5 },
        borderRadius = sz(4),
        children = {
            UI.Label {
                text = label,
                fontSize = sz(11),
                fontColor = { 140, 145, 160, 200 },
                marginBottom = sz(6),
            },
            UI.Label {
                text = tostring(value),
                fontSize = sz(20),
                fontWeight = "bold",
                fontColor = hiColor or { 240, 242, 248, 255 },
            },
        },
    }
end

function PersonalInfoTab.Build()
    local sz = Utils.sz
    local stats    = SaveSystem.IsReady() and SaveSystem.GetStats()    or {}
    local items    = SaveSystem.IsReady() and SaveSystem.GetItems()     or {}
    local playTime = (SaveSystem.GetPlayTime and SaveSystem.GetPlayTime()) or 0

    local totalGames  = stats.totalGames    or 0
    local wins        = stats.wins          or 0
    local totalProfit = stats.totalProfit   or 0
    local totalLoss   = stats.totalLoss     or 0
    local netProfit   = totalProfit - totalLoss
    local maxProfit   = stats.maxProfit     or 0
    local highestBid  = stats.highestBid    or 0
    local totalItems  = stats.totalItemsWon or 0

    local totalAssets = 0
    for _, item in ipairs(items) do
        totalAssets = totalAssets + (item.baseValue or 0)
    end
    local ok, MoneyHUD = pcall(require, "UI.MoneyHUD")
    if ok and MoneyHUD and MoneyHUD.GetMoney then
        totalAssets = totalAssets + (MoneyHUD.GetMoney() or 0)
    end

    local row1 = {
        { label = "游戏时长",   value = PU.FormatPlayTime(playTime),          color = nil },
        { label = "总竞拍局数", value = PU.FormatNum(totalGames),              color = nil },
        { label = "竞拍胜率",   value = PU.FormatPct(wins, totalGames),        color = { 100, 210, 150, 255 } },
        { label = "总资产",     value = PU.FormatNum(totalAssets),             color = { 220, 195, 100, 255 } },
    }
    local row2 = {
        { label = "总盈利",      value = (netProfit >= 0 and "+" or "") .. PU.FormatNum(netProfit),
                               color = netProfit > 0 and { 100, 220, 140, 255 }
                                    or netProfit < 0 and { 220, 100, 90,  255 }
                                    or nil },
        { label = "单局最高利润", value = PU.FormatNum(maxProfit),  color = maxProfit > 0 and { 100, 220, 140, 255 } or nil },
        { label = "最高出价",    value = PU.FormatNum(highestBid),  color = nil },
        { label = "收藏品总数",  value = PU.FormatNum(totalItems),  color = nil },
    }

    local function MakeRow(defs)
        local cells = {}
        for i, d in ipairs(defs) do
            cells[#cells + 1] = StatCard(d.label, d.value, d.color)
            if i < #defs then
                cells[#cells + 1] = UI.Panel { width = sz(4), backgroundColor = { 0, 0, 0, 0 } }
            end
        end
        return UI.Panel {
            width = "100%", flexDirection = "row", gap = sz(4),
            children = cells,
        }
    end

    -- 角色头像
    local charIdx = UIState.selectedCharIdx or 1
    local chars = Config.CHARACTERS or {}
    local selectedChar = chars[charIdx] or chars[1] or {}
    local charAvatarPath = selectedChar.avatar or "Textures/characters/ye_lingxi.png"

    local avatarPanel = UI.Panel {
        width = sz(58), height = sz(58),
        borderRadius = 0,
        overflow = "hidden",
        flexShrink = 0,
        backgroundColor = { 35, 38, 52, 255 },
        borderWidth = 2, borderColor = { 200, 230, 0, 100 },
        children = {
            UI.Panel {
                width = "100%", height = "100%",
                backgroundImage = charAvatarPath,
                backgroundFit = "cover",
            },
        },
    }

    local nicknameLbl = UI.Label {
        text = "—",
        fontSize = sz(16), fontWeight = "bold",
        fontColor = { 220, 225, 240, 255 },
    }
    local userIdLbl = UI.Label {
        text = "",
        fontSize = sz(11),
        fontColor = { 130, 135, 155, 200 },
    }

    local myUserId = (lobby and lobby:GetMyUserId()) or 0
    if myUserId ~= 0 then
        local UserCache = require("UserCache")
        userIdLbl.text = "ID: " .. tostring(myUserId)
        UserCache.GetNickname(myUserId, function(nick)
            nicknameLbl.text = nick
        end)
    else
        nicknameLbl.text = "游客"
    end

    local profileHeader = UI.Panel {
        width = "100%",
        flexDirection = "row",
        alignItems = "center",
        gap = sz(14),
        paddingVertical = sz(16),
        paddingHorizontal = sz(4),
        marginBottom = sz(6),
        borderBottomWidth = 1,
        borderColor = { 255, 255, 255, 10 },
        children = {
            avatarPanel,
            UI.Panel {
                flexGrow = 1, flexShrink = 1,
                flexDirection = "column",
                gap = sz(5),
                children = { nicknameLbl, userIdLbl },
            },
        },
    }

    return UI.Panel {
        width = "100%",
        flexDirection = "column",
        gap = sz(10),
        children = { profileHeader, MakeRow(row1), MakeRow(row2) },
    }
end

return PersonalInfoTab
