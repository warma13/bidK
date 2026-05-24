-- ============================================================================
-- UI/ExtractionScreen.lua - 提取玩法主界面（重构版）
--
-- 两个视图：
--   地图视图（默认）：10 个容器俯视图，点击容器进入
--   战利品视图（容器内）：左=背包格子，右=容器战利品
-- ============================================================================

local UI            = require("urhox-libs/UI")
local Config        = require("Config")
local UIState       = require("UI.UIState")
local Utils         = require("UI.Utils")
local MoneyHUD      = require("UI.MoneyHUD")
local FloatingMsg   = require("UI.FloatingMessage")
local EM            = require("ExtractionMode")
local WG            = require("WarehouseGenerator")
local SaveSystem    = require("SaveSystem")
local SaveFramework = require("SaveFramework")
local LootPanel        = require("UI.LootPanel")
local GameState        = require("GameState")
local EstimateValue    = require("EstimateValue")
local ItemDetailPanel  = require("UI.ItemDetailPanel")

-- 提取模式复用 LootPanel，LootPanel 内部调用 EstimateValue，
-- EstimateValue 需要先注入 GameState 依赖（正常由 GameSession 注入，提取模式手动注入一次）
EstimateValue.InjectDeps(GameState)

local ExtractionScreen = {}

-- ============================================================================
-- 颜色 / 常量
-- ============================================================================
local STATUS_COLOR = {
    [EM.CS.SEALED]    = {  80,  80,  80, 220 },
    [EM.CS.OPENING]   = { 200, 160,  50, 220 },
    [EM.CS.OPEN]      = {  60, 160,  60, 220 },
    [EM.CS.SEARCHING] = {  60, 120, 200, 220 },
    [EM.CS.EMPTIED]   = {  50,  50,  50, 120 },
}
local STATUS_LABEL = {
    [EM.CS.SEALED]    = "封箱",
    [EM.CS.OPENING]   = "开箱中",
    [EM.CS.OPEN]      = "已开",
    [EM.CS.SEARCHING] = "搜索中",
    [EM.CS.EMPTIED]   = "已清空",
}
local PLAYER_COLOR = {
    { 255, 200,  50, 255 },
    { 220,  80,  80, 220 },
    {  80, 200,  80, 220 },
    { 100, 150, 220, 220 },
}
local PLAYER_LABEL = { "你", "AI甲", "AI乙", "AI丙" }
local CONTAINER_POSITIONS = {
    { 0.15, 0.20 }, { 0.50, 0.15 }, { 0.82, 0.18 },
    { 0.10, 0.50 }, { 0.40, 0.45 }, { 0.70, 0.42 },
    { 0.90, 0.55 }, { 0.20, 0.78 }, { 0.55, 0.75 },
    { 0.80, 0.80 },
}

-- ============================================================================
-- 模块状态
-- ============================================================================
---@type ExtractionSession|nil
local session_        = nil
local onExitCallback_ = nil
local selectedCid_    = 0
local tapTimes_       = {}
local refreshTimer_   = 0

-- UI 节点
local containerDots_    = {}
local backpackPanel_    = nil
local lootPanel_        = nil
local mapView_          = nil
local lootView_         = nil
local gameOverOverlay_  = nil
local isLootViewVisible_ = false   -- 视图状态标记（替代 GetVisible()）

-- 前置声明
local SwitchToLootView
local SwitchToMapView
local RefreshBackpack
local RefreshMapDots

--- 将容器物品布局为 LootPanel 兼容的仓库数据结构
---@param container table
---@return table warehouseData
local function BuildContainerWarehouse(container)
    local COLS = Config.GAME.LootColumns
    local ROWS = Config.GAME.LootMaxRows
    -- 初始化空网格（0 = 空格）
    local grid = {}
    for r = 1, ROWS do
        grid[r] = {}
        for c = 1, COLS do grid[r][c] = 0 end
    end

    -- 寻找能放下 w×h 物品的第一个可用位置（逐行扫描）
    local function findPos(w, h)
        for r = 1, ROWS - h + 1 do
            for c = 1, COLS - w + 1 do
                local ok = true
                for dr = 0, h - 1 do
                    for dc = 0, w - 1 do
                        if grid[r + dr][c + dc] ~= 0 then ok = false; break end
                    end
                    if not ok then break end
                end
                if ok then return r, c end
            end
        end
        return nil, nil
    end

    local items = {}
    local totalValue = 0
    for i, src in ipairs(container.items) do
        -- 浅拷贝，保留原始全部字段（w/h/idx/icon/image/rarity 等）
        local item = {}
        for k, v in pairs(src) do item[k] = v end
        item.idx = item.idx or i  -- 确保 idx 不为 nil

        local w = item.w or 1
        local h = item.h or 1
        local row, col = findPos(w, h)
        if row then
            item.gridRow = row
            item.gridCol = col
            items[#items + 1] = item
            -- 填充物品占据的所有格子
            local itemArrayIdx = #items
            for dr = 0, h - 1 do
                for dc = 0, w - 1 do
                    grid[row + dr][col + dc] = itemArrayIdx
                end
            end
            totalValue = totalValue + (item.baseValue or 0)
        end
        -- 若放不下则跳过（容器物品数量少，正常情况不会发生）
    end
    return {
        items         = items,
        grid          = grid,
        totalCells    = COLS * ROWS,
        totalValue    = totalValue,
        warehouseName = container.name or "容器",
    }
end

local function sz(n) return Utils.sz(n) end

--- 动态更新面板子节点（正确方式：RemoveAllChildren + AddChild）
local function SetChildren(panel, children)
    panel:RemoveAllChildren()
    for _, child in ipairs(children) do
        if child then panel:AddChild(child) end
    end
end

-- ============================================================================
-- 地图视图：容器点位
-- ============================================================================

local function MakeContainerDot(cid, dotNode)
    if not session_ then return end
    local summary = session_:GetContainerSummary(cid)
    if not summary then return end

    local color    = STATUS_COLOR[summary.status] or STATUS_COLOR[EM.CS.SEALED]
    local label    = STATUS_LABEL[summary.status] or "?"
    local isSelected = (cid == selectedCid_)

    -- 搜索者指示点
    local searcherDots = {}
    for _, idx in ipairs(summary.searchers) do
        searcherDots[#searcherDots + 1] = UI.Panel {
            width = sz(6), height = sz(6),
            borderRadius = sz(3),
            backgroundColor = PLAYER_COLOR[idx],
        }
    end

    -- 开箱进度条
    local progressBar = nil
    if summary.status == EM.CS.OPENING and summary.openTimer then
        local pct = math.max(0, math.min(1, 1 - summary.openTimer / EM.OPEN_TIME))
        progressBar = UI.Panel {
            width = sz(44), height = sz(3),
            backgroundColor = { 40, 40, 40, 180 },
            borderRadius = sz(1),
            overflow = "hidden",
            children = {
                UI.Panel {
                    width  = tostring(math.floor(pct * 100)) .. "%",
                    height = "100%",
                    backgroundColor = { 200, 160, 50, 255 },
                },
            },
        }
    end

    dotNode.backgroundColor = isSelected and { 55, 95, 170, 240 } or { 26, 36, 50, 220 }
    dotNode.borderWidth     = isSelected and 2 or 1
    dotNode.borderColor     = isSelected and { 100, 160, 255, 255 } or color

    SetChildren(dotNode, {
        UI.Panel {
            width = sz(12), height = sz(12),
            borderRadius = sz(6),
            backgroundColor = color,
            marginBottom = sz(1),
        },
        UI.Label {
            text = string.char(64 + cid),
            fontSize = sz(10), fontWeight = "bold",
            fontColor = { 220, 220, 220, 240 },
        },
        UI.Label {
            text = label,
            fontSize = sz(7),
            fontColor = { 155, 155, 155, 200 },
        },
        progressBar or UI.Panel { height = sz(3) },
        UI.Panel {
            flexDirection = "row", gap = sz(2),
            children = searcherDots,
        },
    })
end

local function BuildMapPanel()
    local dotNodes = {}
    for i = 1, EM.CONTAINER_COUNT do
        local pos = CONTAINER_POSITIONS[i]
        local cid = i   -- 闭包捕获
        dotNodes[i] = UI.Panel {
            position   = "absolute",
            left       = tostring(math.floor(pos[1] * 100)) .. "%",
            top        = tostring(math.floor(pos[2] * 100)) .. "%",
            width      = sz(54), height = sz(52),
            marginLeft = -sz(27), marginTop = -sz(26),
            alignItems = "center",
            onClick    = function()
                Utils.PlayClick()
                SwitchToLootView(cid)
            end,
        }
    end
    containerDots_ = dotNodes

    return UI.Panel {
        flex = 1,
        backgroundColor = { 17, 25, 35, 248 },
        borderRadius = sz(8),
        position = "relative",
        overflow = "hidden",
        children = dotNodes,
    }
end

RefreshMapDots = function()
    if not session_ then return end
    for cid = 1, EM.CONTAINER_COUNT do
        if containerDots_[cid] then
            MakeContainerDot(cid, containerDots_[cid])
        end
    end
end

-- ============================================================================
-- 背包面板（战利品视图左侧）
-- ============================================================================

RefreshBackpack = function()
    if not backpackPanel_ or not session_ then return end
    local items = session_:GetBackpack(1)
    local COLS  = 5
    local ROWS  = 4
    local TOTAL = COLS * ROWS

    -- 与 LootPanel.Create() 完全相同的格子构建方式：
    -- 每格 aspectRatio=1, flexGrow=1, flexBasis=0，按行组织
    local gridSlots = {}
    for i = 1, TOTAL do
        local item = items[i]
        if item then
            gridSlots[i] = UI.Panel {
                aspectRatio     = 1,
                flexGrow        = 1,
                flexBasis       = 0,
                borderRadius    = 0,
                backgroundColor = { 36, 56, 32, 180 },
                borderWidth     = { right = 1, bottom = 1 },
                borderColor     = { 68, 130, 55, 160 },
                justifyContent  = "center",
                alignItems      = "center",
                overflow        = "hidden",
                children = {
                    UI.Label {
                        text      = item.name:sub(1, 2),
                        fontSize  = sz(9), fontWeight = "bold",
                        fontColor = { 195, 230, 165, 240 },
                        textAlign = "center",
                    },
                },
            }
        else
            gridSlots[i] = UI.Panel {
                aspectRatio     = 1,
                flexGrow        = 1,
                flexBasis       = 0,
                borderRadius    = 0,
                backgroundColor = { 0, 0, 0, 0 },
                borderWidth     = { right = 1, bottom = 1 },
                borderColor     = { 80, 130, 170, 60 },
            }
        end
    end

    -- 按行组织（与 LootPanel.Create() 完全一致：行本身无额外边框）
    local gridRows = {}
    for r = 1, ROWS do
        local rowCells = {}
        for c = 1, COLS do
            rowCells[c] = gridSlots[(r - 1) * COLS + c]
        end
        gridRows[r] = UI.Panel {
            width         = "100%",
            flexDirection = "row",
            children      = rowCells,
        }
    end

    -- gridContainer：外层加 left=1, top=1 边框，与 LootPanel gridContainer 完全一致
    local gridContainer = UI.Panel {
        width         = "100%",
        flexDirection = "column",
        borderWidth   = { left = 1, top = 1 },
        borderColor   = { 80, 130, 170, 60 },
        children      = gridRows,
    }

    local totalVal = 0
    for _, it in ipairs(items) do totalVal = totalVal + (it.baseValue or 0) end

    local headerRow = UI.Panel {
        flexDirection  = "row",
        justifyContent = "space-between",
        alignItems     = "center",
        width          = "100%",
        marginBottom   = sz(6),
        children = {
            UI.Label {
                text      = string.format("背包  %d / 20", #items),
                fontSize  = sz(12), fontWeight = "bold",
                fontColor = { 165, 200, 145, 240 },
            },
            UI.Label {
                text      = Utils.FormatMoney(totalVal),
                fontSize  = sz(11),
                fontColor = { 145, 200, 95, 215 },
            },
        },
    }

    SetChildren(backpackPanel_, { headerRow, gridContainer })
end

-- ============================================================================
-- 战利品面板（直接复用 LootPanel + GameState）
-- ============================================================================

--- 将容器数据注入 GameState，并同步 UIState.itemRevealLevels，然后调用 LootPanel.Update()
local function LoadContainerIntoLootPanel(cid)
    if not session_ then return end
    local container = session_.containers[cid]
    if not container then return end

    -- 1. 构建迷你仓库布局
    local warehouseData = BuildContainerWarehouse(container)

    -- 2. 重置所有增量缓存，彻底清除上一个容器的残留状态
    LootPanel.ResetCache()
    UIState.ResetGameState()  -- 清空 itemRevealLevels = {}

    -- 2.5 ResetCache 把 lastActiveImageCount 归零，导致 Update 内清理循环不执行，
    --     旧图片面板会残留。这里直接手动隐藏全部图片面板。
    if UIState.refs and UIState.refs.itemImages then
        for i = 1, #UIState.refs.itemImages do
            local img = UIState.refs.itemImages[i]
            if img then img:SetVisible(false) end
        end
    end

    -- 3. 注入新仓库数据到 GameState
    GameState.SetExtractionWarehouse(warehouseData)

    -- 4. 先用全 level=0 渲染一帧，确保旧图标/格子彻底清空
    LootPanel.Update()

    -- 5. 根据当前已揭示情况设置 itemRevealLevels（用 item.idx 直接建映射，不依赖 pos 顺序）
    local visibleItems = session_:GetVisibleItems(cid)
    local revealedByIdx = {}
    for _, ri in ipairs(visibleItems) do
        if ri.item and ri.item.idx then
            revealedByIdx[ri.item.idx] = true
        end
    end
    for _, item in ipairs(warehouseData.items) do
        UIState.itemRevealLevels[item.idx] = revealedByIdx[item.idx] and 4 or 0
    end

    -- 6. 驱动渲染（带最新揭示状态）
    LootPanel.Update()
    RefreshBackpack()
end

-- ============================================================================
-- 视图切换
-- ============================================================================

SwitchToLootView = function(cid)
    if not session_ then return end
    selectedCid_ = cid
    local result = session_:PlayerEnterContainer(1, cid)
    if result == "need_open" then
        FloatingMsg.Show("开始开箱…")
    elseif result == "following" then
        FloatingMsg.Show("跟进！跳过开箱")
    elseif result == "done" then
        FloatingMsg.Show("该容器已清空")
    end
    isLootViewVisible_ = true
    mapView_:SetVisible(false)
    lootView_:SetVisible(true)
    if UIState.refs.panelBackdrop then UIState.refs.panelBackdrop:SetVisible(true) end
    LoadContainerIntoLootPanel(cid)
end

SwitchToMapView = function()
    if session_ then
        session_:PlayerLeaveContainer(1)
    end
    selectedCid_ = 0
    isLootViewVisible_ = false
    lootView_:SetVisible(false)
    mapView_:SetVisible(true)
    if UIState.refs.panelBackdrop then UIState.refs.panelBackdrop:SetVisible(false) end
    if UIState.itemDetail then UIState.itemDetail:Hide() end
    RefreshMapDots()
end

-- ============================================================================
-- 游戏结束弹窗
-- ============================================================================

local function ShowGameOverDialog(result)
    if not gameOverOverlay_ then return end
    local profit     = result.totalValue - result.entryFee
    local profitColor = profit >= 0 and { 120, 220, 100, 255 } or { 220, 100, 100, 255 }
    local profitSign  = profit >= 0 and "+" or ""

    local itemRows = {}
    for _, item in ipairs(result.items) do
        itemRows[#itemRows + 1] = UI.Panel {
            flexDirection  = "row",
            justifyContent = "space-between",
            paddingH = sz(8), paddingV = sz(3),
            children = {
                UI.Label { text = item.name, fontSize = sz(10),
                    fontColor = { 200, 200, 200, 220 } },
                UI.Label { text = Utils.FormatMoney(item.baseValue),
                    fontSize = sz(10), fontColor = { 180, 220, 120, 220 } },
            },
        }
    end
    if #itemRows == 0 then
        itemRows[1] = UI.Label {
            text      = "本次未取到任何物品",
            fontSize  = sz(11),
            fontColor = { 150, 150, 150, 180 },
        }
    end

    SetChildren(gameOverOverlay_, { UI.Panel {
            width = sz(300),
            backgroundColor = { 20, 24, 34, 252 },
            borderRadius    = sz(10),
            borderWidth     = 1,
            borderColor     = { 75, 88, 108, 200 },
            paddingH = sz(16), paddingV = sz(16),
            gap = sz(8),
            children = {
                UI.Label {
                    text      = "本次搜索结束",
                    fontSize  = sz(16), fontWeight = "bold",
                    fontColor = { 220, 210, 160, 255 },
                    textAlign = "center",
                },
                UI.Panel {
                    backgroundColor = { 28, 34, 46, 200 },
                    borderRadius = sz(6),
                    paddingH = sz(10), paddingV = sz(8),
                    gap = sz(4),
                    children = {
                        UI.Panel {
                            flexDirection = "row", justifyContent = "space-between",
                            children = {
                                UI.Label { text = "入场费", fontSize = sz(10),
                                    fontColor = { 155, 155, 155, 200 } },
                                UI.Label { text = "-" .. Utils.FormatMoney(result.entryFee),
                                    fontSize = sz(10), fontColor = { 220, 118, 95, 225 } },
                            },
                        },
                        UI.Panel {
                            flexDirection = "row", justifyContent = "space-between",
                            children = {
                                UI.Label { text = "物品价值", fontSize = sz(10),
                                    fontColor = { 155, 155, 155, 200 } },
                                UI.Label { text = Utils.FormatMoney(result.totalValue),
                                    fontSize = sz(10), fontColor = { 175, 218, 118, 225 } },
                            },
                        },
                        UI.Panel { height = 1, backgroundColor = { 58, 64, 80, 150 } },
                        UI.Panel {
                            flexDirection = "row", justifyContent = "space-between",
                            children = {
                                UI.Label { text = "盈亏", fontSize = sz(11), fontWeight = "bold",
                                    fontColor = { 200, 200, 200, 225 } },
                                UI.Label {
                                    text      = profitSign .. Utils.FormatMoney(profit),
                                    fontSize  = sz(12), fontWeight = "bold",
                                    fontColor = profitColor,
                                },
                            },
                        },
                    },
                },
                UI.Label { text = "取得物品：", fontSize = sz(10),
                    fontColor = { 155, 155, 155, 200 } },
                UI.Panel {
                    maxHeight = sz(120),
                    overflow  = "scroll",
                    gap       = sz(2),
                    children  = itemRows,
                },
                UI.Panel {
                    flexDirection = "row", gap = sz(8), marginTop = sz(4),
                    children = {
                        UI.Button {
                            text = "全部入库",
                            flex = 1, variant = "primary",
                            onClick = function()
                                Utils.PlayClick()
                                if #result.items > 0 then
                                    SaveSystem.AddWonItems(result.items)
                                    SaveFramework.MarkDirty("extraction_loot")
                                end
                                if onExitCallback_ then onExitCallback_() end
                            end,
                        },
                        UI.Button {
                            text = "丢弃离开",
                            flex = 1, variant = "secondary",
                            onClick = function()
                                Utils.PlayClick()
                                if onExitCallback_ then onExitCallback_() end
                            end,
                        },
                    },
                },
            },
        },
    })
    gameOverOverlay_:SetVisible(true)
end

-- ============================================================================
-- 帧更新（节流 0.1s）
-- ============================================================================

function ExtractionScreen.HandleUpdate(dt)
    if not session_ then return end
    session_:Update(dt)
    refreshTimer_ = refreshTimer_ + dt
    if refreshTimer_ < 0.1 then return end
    refreshTimer_ = 0

    UIState.glowTime = (UIState.glowTime or 0) + 0.1  -- 驱动 LootPanel 流光动画

    if isLootViewVisible_ then
        LootPanel.Update()
        RefreshBackpack()
    elseif mapView_ then
        RefreshMapDots()
    end
end

-- ============================================================================
-- 主入口
-- ============================================================================

function ExtractionScreen.Show(params)
    UIState.currentScreen = "extraction"
    local regionIdx = params.regionIdx or 1
    local diffIdx   = params.diffIdx   or 1
    onExitCallback_ = params.onBackCallback
    selectedCid_    = 0
    tapTimes_       = {}
    refreshTimer_   = 0

    local region     = Config.REGIONS[regionIdx]
    local difficulty = region and region.difficulties[diffIdx]
    local entryFee   = difficulty and difficulty.entryFee or 0

    local genResult = WG.Generate(region and region.id or "suburb", nil, diffIdx)
    local allItems  = (genResult and genResult.items) or {}

    session_ = EM.NewSession({
        regionId  = region and region.id or "suburb",
        entryFee  = entryFee,
        allItems  = allItems,
        onReveal  = function(cid, pos, item, byIdx)
            -- 同步到 UIState，驱动 LootPanel.Update() 显示该格
            if item and item.idx then
                UIState.itemRevealLevels[item.idx] = 4
            end
            FloatingMsg.Show((PLAYER_LABEL[byIdx] or "?") .. " 搜出：" .. item.name)
        end,
        onTake = function(cid, pos, item, byIdx)
            if byIdx == 1 then
                FloatingMsg.Show("取走：" .. item.name ..
                    "（" .. Utils.FormatMoney(item.baseValue) .. "）")
            else
                FloatingMsg.Show((PLAYER_LABEL[byIdx] or "?") .. " 取走了 " .. item.name)
            end
        end,
        onGameOver = function(result)
            ShowGameOverDialog(result)
        end,
        onBackpackFull = function(playerIdx)
            if playerIdx == 1 then FloatingMsg.Show("背包已满！无法拾取") end
        end,
    })

    -- =========================================================================
    -- 地图视图（默认显示）
    -- =========================================================================
    local mapArea = BuildMapPanel()

    local mapHeader = UI.Panel {
        flexDirection  = "row",
        alignItems     = "center",
        justifyContent = "space-between",
        width          = "100%",
        paddingH = sz(12), paddingV = sz(9),
        backgroundColor = { 10, 14, 22, 248 },
        borderBottomWidth = 1,
        borderBottomColor = { 38, 50, 68, 190 },
        children = {
            UI.Panel {
                gap = sz(2),
                children = {
                    UI.Label {
                        text      = (region and region.name or "搜索区") .. " · 搜索模式",
                        fontSize  = sz(14), fontWeight = "bold",
                        fontColor = { 220, 210, 160, 255 },
                    },
                    UI.Label {
                        text      = "入场费 " .. Utils.FormatMoney(entryFee) ..
                                    "　·  点击容器进入搜索",
                        fontSize  = sz(10),
                        fontColor = { 155, 138, 108, 195 },
                    },
                },
            },
            MoneyHUD.CreatePanel(),
        },
    }

    local mapBottom = UI.Panel {
        flexDirection  = "row",
        alignItems     = "center",
        justifyContent = "flex-end",
        width          = "100%",
        paddingH = sz(12), paddingV = sz(8),
        backgroundColor = { 10, 14, 22, 248 },
        borderTopWidth = 1,
        borderTopColor = { 38, 50, 68, 190 },
        children = {
            UI.Button {
                text   = "立即撤离",
                width  = sz(90), height = sz(34),
                fontSize = sz(11),
                backgroundColor = { 158, 68, 52, 235 },
                fontColor = { 255, 255, 255, 255 },
                borderRadius = sz(5),
                onClick = function()
                    if not session_ then return end
                    Utils.PlayClick()
                    session_:HumanExtract()
                end,
            },
        },
    }

    mapView_ = UI.Panel {
        position = "absolute",
        left = 0, top = 0, right = 0, bottom = 0,
        children = {
            mapHeader,
            UI.Panel {
                flex     = 1,
                paddingH = sz(8), paddingV = sz(6),
                children = { mapArea },
            },
            mapBottom,
        },
    }

    -- =========================================================================
    -- 战利品视图（进入容器后切换）
    -- =========================================================================
    backpackPanel_ = UI.Panel { width = "100%", gap = sz(4), children = {} }
    lootPanel_     = LootPanel.Create()
    -- 覆盖竞拍模式的 34% 宽度，改为 flex=1 与背包面板等宽
    lootPanel_:SetStyle({ width = nil, flex = 1, height = "100%" })

    local lootHeader = UI.Panel {
        flexDirection  = "row",
        alignItems     = "center",
        justifyContent = "space-between",
        width          = "100%",
        paddingH = sz(10), paddingV = sz(8),
        backgroundColor = { 10, 14, 22, 248 },
        borderBottomWidth = 1,
        borderBottomColor = { 38, 50, 68, 190 },
        children = {
            UI.Button {
                text   = "◀ 返回地图",
                width  = sz(85), height = sz(30),
                fontSize = sz(10),
                backgroundColor = { 34, 44, 60, 225 },
                fontColor = { 175, 198, 225, 235 },
                borderRadius = sz(4),
                onClick = function()
                    Utils.PlayClick()
                    SwitchToMapView()
                end,
            },
            UI.Label {
                text      = region and region.name or "搜索区",
                fontSize  = sz(12), fontWeight = "bold",
                fontColor = { 198, 198, 178, 225 },
            },
            MoneyHUD.CreatePanel(),
        },
    }

    local lootBottom = UI.Panel {
        flexDirection  = "row",
        alignItems     = "center",
        justifyContent = "flex-end",
        gap = sz(8),
        width          = "100%",
        paddingH = sz(10), paddingV = sz(8),
        backgroundColor = { 10, 14, 22, 248 },
        borderTopWidth = 1,
        borderTopColor = { 38, 50, 68, 190 },
        children = {
            UI.Button {
                text    = "退出容器",
                width   = sz(78), height = sz(30),
                fontSize = sz(10),
                variant = "secondary",
                onClick = function()
                    Utils.PlayClick()
                    SwitchToMapView()
                end,
            },
            UI.Button {
                text   = "立即撤离",
                width  = sz(82), height = sz(30),
                fontSize = sz(10),
                backgroundColor = { 158, 68, 52, 235 },
                fontColor = { 255, 255, 255, 255 },
                borderRadius = sz(5),
                onClick = function()
                    if not session_ then return end
                    Utils.PlayClick()
                    session_:HumanExtract()
                end,
            },
        },
    }

    lootView_ = UI.Panel {
        position = "absolute",
        left = 0, top = 0, right = 0, bottom = 0,
        visible  = false,
        children = {
            lootHeader,
            UI.Panel {
                flex          = 1,
                flexDirection = "row",
                gap           = sz(6),
                paddingH      = sz(8), paddingV = sz(6),
                overflow      = "hidden",
                children = {
                    -- 左：背包
                    UI.Panel {
                        flex = 1,
                        backgroundColor = { 13, 19, 13, 235 },
                        borderRadius    = sz(6),
                        paddingH = sz(10), paddingV = sz(10),
                        overflow = "scroll",
                        children = { backpackPanel_ },
                    },
                    -- 右：战利品（LootPanel 自带标题栏 + ScrollView）
                    lootPanel_,
                },
            },
            lootBottom,
        },
    }

    -- 游戏结束遮罩（预置，初始隐藏）
    gameOverOverlay_ = UI.Panel {
        position        = "absolute",
        left = 0, top = 0, right = 0, bottom = 0,
        backgroundColor = { 0, 0, 0, 165 },
        alignItems      = "center",
        justifyContent  = "center",
        visible         = false,
        children        = {},
    }

    -- 物品详情浮窗（复用竞拍模式的 ItemDetailPanel，挂到根节点最顶层）
    local itemDetail = ItemDetailPanel.New({})
    UIState.itemDetail = itemDetail
    UIState.refs.itemDetailPanel = itemDetail:GetWidget()

    -- 根节点（绝对定位子层叠加）
    local root = UI.Panel {
        width = "100%", height = "100%",
        backgroundColor = { 8, 12, 20, 255 },
        children = {
            mapView_,
            lootView_,
            gameOverOverlay_,
            UIState.refs.panelBackdrop,    -- 透明点击层（战利品视图激活时显示）
            UIState.refs.itemDetailPanel,  -- 浮窗覆盖在最顶层
        },
    }

    -- 透明点击层：命中 LootPanel 格子时弹出物品详情（与竞拍模式 panelBackdrop 相同模式）
    UIState.refs.panelBackdrop = UI.Panel {
        position = "absolute",
        left = 0, top = 0,
        width = "100%", height = "100%",
        backgroundColor = { 0, 0, 0, 0 },  -- 完全透明，仅捕获点击
        visible = false,
        onClick = function(self, event)
            local slotIdx = LootPanel.HitTestSlot(event.x, event.y)
            if slotIdx then
                Utils.PlayClick()
                LootPanel._OnSlotClick(slotIdx)
            else
                if UIState.itemDetail then UIState.itemDetail:Hide() end
            end
        end,
    }

    UI.SetRoot(root)
    RefreshMapDots()
end

return ExtractionScreen
