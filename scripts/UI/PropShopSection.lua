-- ============================================================================
-- UI/PropShopSection.lua - 道具商店 & 每日商店分区模块
-- 包含：BuildCards、MakeSectionHeader、RebuildDailySection
-- ============================================================================
-- 使用方式：
--   local PropShopSection = require("UI.PropShopSection")
--   local section = PropShopSection.Create(deps)
--   section.regularHeader     → 普通商店固定标题
--   section.dailyHeader       → 每日商店固定标题（初始值）
--   section.regularSection    → 普通商店卡片容器
--   section.dailySection      → 每日商店卡片容器（初始值）
--   section.rebuildDaily()    → 购买后重建每日分区
-- ============================================================================

local UI = require("urhox-libs/UI")
local Utils = require("UI.Utils")
local SaveSystem = require("SaveSystem")
local PropSystem = require("PropSystem")
local DailyShop = require("DailyShop")
local PropCardWidget = require("UI.PropCardWidget")
local AdHelper = require("AdHelper")
local FloatingMessage = require("UI.FloatingMessage")

local PropShopSection = {}

-- ============================================================================
-- Create(deps) → section object
-- ============================================================================
-- deps 字段：
--   sz                 : function(n)
--   dailyList          : table  { {def, slotIdx}, ... }  （外部持有，内部排序/修改）
--   cardCountLabels    : table  propId→label widget 引用
--   refreshLabelRef    : table  { lbl = widget or nil }  模块级倒计时 label
--   openShopDialog     : function(def, slotIdx)  打开金币购买弹窗
--   regularList        : table  普通商店 prop def 列表
--   onSectionRebuilt   : function(newDailySection, newDailyHeader)  每日重建后通知 PropScreen
-- ============================================================================
function PropShopSection.Create(deps)
    local sz               = deps.sz
    local dailyList        = deps.dailyList
    local cardCountLabels  = deps.cardCountLabels
    local refreshLabelRef  = deps.refreshLabelRef
    local openShopDialog   = deps.openShopDialog
    local regularList      = deps.regularList
    local onSectionRebuilt = deps.onSectionRebuilt

    -- ── 构建卡片网格 ──────────────────────────────────────────
    -- 每日商店时 list 元素为 {def, slotIdx}；普通商店时为 prop def
    local function BuildCards(list, isDaily)
        local cards = {}
        for i, entry in ipairs(list) do
            local p, slotIdx
            if isDaily then
                p       = entry.def
                slotIdx = entry.slotIdx
            else
                p       = entry
                slotIdx = nil
            end
            local count    = PropSystem.GetCount(p.id)
            local labelKey = isDaily and (p.id .. ":" .. i) or p.id
            local isBought = slotIdx
                and SaveSystem.GetDailySlotBought(slotIdx)
                or false

            local boughtOverlay = isBought and UI.Panel {
                position = "absolute",
                left = 0, top = 0, right = 0, bottom = 0,
                alignItems = "center", justifyContent = "center",
                opacity = 0.72,
                children = {
                    UI.Panel {
                        position = "absolute",
                        left = 0, top = 0, right = 0, bottom = 0,
                        backgroundImage = "image/task_row_bg_20260516173338.png",
                        backgroundFit = "cover",
                        backgroundColor = { 0, 0, 0, 60 },
                    },
                    UI.Label {
                        text = "已购买",
                        fontSize = sz(14), fontWeight = "bold",
                        fontColor = { 220, 50, 50, 255 },
                    },
                },
            } or nil

            local countLabelOut = {}
            local card = PropCardWidget.ShopCard {
                def           = p,
                count         = count,
                countLabel    = countLabelOut,
                boughtOverlay = boughtOverlay,
                onClick = function()
                    Utils.PlayClick()
                    openShopDialog(p, slotIdx)
                end,
            }
            cardCountLabels[labelKey] = countLabelOut[1]
            cardCountLabels[p.id]     = countLabelOut[1]
            cards[#cards + 1]         = card
        end
        return cards
    end

    -- ── 节标题行 ─────────────────────────────────────────────
    local function MakeSectionHeader(showRefresh)
        local rightWidget
        if showRefresh then
            local lbl = UI.Label {
                text = DailyShop.GetRefreshText(),
                fontSize = sz(12),
                fontColor = { 120, 160, 220, 200 },
            }
            -- 写入外部引用，让模块级 GameLoop 每秒更新
            refreshLabelRef.lbl = lbl

            local canRefresh = DailyShop.CanAdRefresh()
            local adBtn = UI.Panel {
                flexDirection = "row", alignItems = "center",
                paddingHorizontal = sz(8), paddingVertical = sz(3),
                backgroundColor = canRefresh and { 35, 70, 150, 180 } or { 30, 30, 36, 100 },
                borderRadius = sz(4),
                borderWidth = 1,
                borderColor = canRefresh and { 70, 120, 210, 180 } or { 45, 45, 55, 80 },
                onClick = canRefresh and function()
                    AdHelper.WatchRewardAd(
                        function()
                            DailyShop.DoAdRefresh()
                            local newRaw = DailyShop.GetAdRefreshedItems()
                            for i = 1, #dailyList do dailyList[i] = nil end
                            for i, p in ipairs(newRaw) do
                                dailyList[i] = { def = p, slotIdx = i }
                            end
                            -- 触发重建（内部调用下方 RebuildDailySection）
                            deps.rebuildDailyFn()
                            FloatingMessage.Show("每日商店已刷新")
                        end,
                        function(reason)
                            if reason ~= AdHelper.REASON_USER_CANCEL then
                                FloatingMessage.Show("广告播放失败，请稍后重试")
                            end
                        end
                    )
                end or nil,
                children = {
                    UI.Label {
                        text = canRefresh and "广告刷新" or "今日已刷新",
                        fontSize = sz(11),
                        fontColor = canRefresh and { 150, 195, 255, 220 } or { 70, 70, 80, 140 },
                    },
                },
            }

            rightWidget = UI.Panel {
                flexDirection = "row", alignItems = "center",
                gap = sz(10),
                children = { lbl, adBtn },
            }
        else
            rightWidget = UI.Panel {}
        end

        return UI.Panel {
            width = "100%",
            flexDirection = "row", alignItems = "center",
            paddingLeft = sz(14), paddingRight = sz(16), paddingVertical = sz(8),
            backgroundColor = { 20, 22, 32, 230 },
            borderBottomWidth = 1,
            borderColor = { 50, 55, 70, 150 },
            children = {
                UI.Panel {
                    width = sz(3), height = sz(16),
                    backgroundColor = { 200, 230, 0, 255 },
                    borderRadius = sz(2),
                },
                UI.Panel { width = sz(8) },
                UI.Label {
                    text = "商品",
                    fontSize = sz(14), fontWeight = "bold",
                    fontColor = { 230, 230, 235, 255 },
                },
                UI.Panel { flexGrow = 1 },
                rightWidget,
            },
        }
    end

    -- ── 初始构建 ─────────────────────────────────────────────
    local regularCards = BuildCards(regularList, false)
    local dailyCards   = BuildCards(dailyList, true)

    local regularHeader = MakeSectionHeader(false)
    local dailyHeader   = MakeSectionHeader(true)

    local regularSection = UI.Panel {
        width = "100%",
        flexDirection = "row", flexWrap = "wrap",
        gap = sz(10), padding = sz(12),
        children = regularCards,
    }

    local dailySection = UI.Panel {
        width = "100%",
        flexDirection = "row", flexWrap = "wrap",
        gap = sz(10), padding = sz(12),
        children = dailyCards,
    }

    -- ── 重建每日分区 ─────────────────────────────────────────
    local function RebuildDailySection()
        table.sort(dailyList, function(a, b)
            local aBought = SaveSystem.GetDailySlotBought(a.slotIdx)
            local bBought = SaveSystem.GetDailySlotBought(b.slotIdx)
            if aBought == bBought then return false end
            return not aBought
        end)
        -- 清空旧的 daily label 引用
        for k in pairs(cardCountLabels) do
            if type(k) == "string" and k:find(":") then
                cardCountLabels[k] = nil
            end
        end
        local newDailyCards = BuildCards(dailyList, true)
        local newDailySection = UI.Panel {
            width = "100%",
            flexDirection = "row", flexWrap = "wrap",
            gap = sz(10), padding = sz(12),
            children = newDailyCards,
        }
        local newDailyHeader = MakeSectionHeader(true)
        -- 通知 PropScreen 更新 sectionPanels/sectionHeaders
        if onSectionRebuilt then
            onSectionRebuilt(newDailySection, newDailyHeader)
        end
        dailySection = newDailySection
        dailyHeader  = newDailyHeader
    end

    -- 解决广告刷新按钮中的循环引用：在 deps 里挂一个可延迟赋值的 fn
    deps.rebuildDailyFn = RebuildDailySection

    return {
        regularHeader  = regularHeader,
        dailyHeader    = dailyHeader,
        regularSection = regularSection,
        dailySection   = dailySection,
        rebuildDaily   = RebuildDailySection,
    }
end

return PropShopSection
