-- ============================================================================
-- UI/LootPanel.lua - 右侧仓库藏品面板（含流光绘制）
-- ============================================================================

local UI = require("urhox-libs/UI")
local Config = require("Config")
local GameState = require("GameState")
local UIState = require("UI.UIState")
local Utils = require("UI.Utils")
local EstimateValue = require("EstimateValue")
local WarehouseItemListPanel = require("UI.WarehouseItemListPanel")

--- 获取 GameSession 创建的 ItemDetailPanel 实例
local function getItemDetail()
    return UIState.itemDetail
end

local ImageCache = require("urhox-libs/UI/Core/ImageCache")

local LootPanel = {}

local GS = GameState
local SaveSystem = require("SaveSystem")

-- 图片面板索引 → 物品引用的映射（每帧 Update 时刷新）
local imageToItem = {}

-- ============================================================================
-- 性能优化：脏标记与增量追踪
-- ============================================================================
local lastActiveImageCount = 0  -- 上一帧活跃的图片面板数
local hitAreasDirty = true      -- 图片点击区域是否需要刷新
local level1Items = {}          -- 预计算的 level-1 物品列表（供 Render 使用）
local lastSlotLevels = {}       -- 增量更新：上次每个格子的揭示等级缓存

-- L2 品质提示：每件物品固定一个随机格子 { [itemIdx] = {dr, dc} }
-- dr/dc 为相对于物品左上角的偏移（0-based），首次到 L2 时确定，之后不变
local qualityHintSlots = {}

-- 图片位置布局缓存：物品 idx → {x, y, w, h}（仅在布局变化时更新）
local imgLayoutCache = {}
-- 上次 gridContainer 布局快照，用于检测 resize
local lastGridLayout = nil

-- 检测 gridContainer 布局是否发生变化；若变化则清空 imgLayoutCache 并返回 true
local function checkGridLayoutChanged(gridLayout)
    if not gridLayout then return false end
    if not lastGridLayout
        or lastGridLayout.x ~= gridLayout.x or lastGridLayout.y ~= gridLayout.y
        or lastGridLayout.w ~= gridLayout.w or lastGridLayout.h ~= gridLayout.h then
        lastGridLayout = { x = gridLayout.x, y = gridLayout.y, w = gridLayout.w, h = gridLayout.h }
        imgLayoutCache = {}
        return true
    end
    return false
end

local refs = UIState.refs
local C = Config.COLORS

-- ============================================================================
-- 创建
-- ============================================================================

-- 物品图片配置
local MAX_ITEM_IMAGES = 200  -- 最多同时显示的物品图片数

-- 流光线段配置
local MAX_GLOW_ITEMS = MAX_ITEM_IMAGES  -- 与物品数上限一致，不限制流光数量
local SEGMENT_COUNT = 10   -- 每个物品的线段片数（密集排列形成粗光线）
local SEG_SPACING = 3      -- 线段中心间距（沿周长方向，像素）
local SEG_THICK = 4        -- 线段粗细（垂直边框方向）
local GLOW_SPEED = 80      -- 流动速度（像素/秒）

-- 搜索图标旋转动画配置
local SEARCH_ORBIT_SPEED = 1.0  -- 旋转速度（圈/秒）

-- 周长位置 → 矩形边缘坐标 + 所在边
local function perimeterToXY(pos, w, h)
    local p = 2 * (w + h)
    pos = pos % p
    if pos < 0 then pos = pos + p end
    if pos < w then
        return pos, 0, "top"
    elseif pos < w + h then
        return w, pos - w, "right"
    elseif pos < w + h + w then
        return w - (pos - w - h), h, "bottom"
    else
        return 0, h - (pos - w - h - w), "left"
    end
end

function LootPanel.Create()
    local gridSlots = {}
    refs.lootSlots = {}
    refs.lootSlotIcons = {}
    local totalSlots = Config.GAME.LootColumns * Config.GAME.LootMaxRows
    local cols = Config.GAME.LootColumns
    for i = 1, totalSlots do
        local slotIdx = i
        local iconLabel = UI.Label { text = "", fontSize = 10, fontColor = C.textPrimary, visible = false }
        refs.lootSlotIcons[i] = iconLabel
        local slot = UI.Panel {
            aspectRatio = 1,
            flexGrow = 1,
            flexBasis = 0,
            borderRadius = 0,
            backgroundColor = { 0, 0, 0, 0 },
            borderWidth = { right = 1, bottom = 1 },
            borderColor = { 80, 130, 170, 60 },
            justifyContent = "center", alignItems = "center",
            onClick = function()
                Utils.PlayClick()
                LootPanel._OnSlotClick(slotIdx)
            end,
            children = { iconLabel }
        }
        refs.lootSlots[i] = slot
        gridSlots[i] = slot
    end

    -- 按行组织格子
    local rows = Config.GAME.LootMaxRows
    local gridRows = {}
    for r = 1, rows do
        local rowChildren = {}
        for c = 1, cols do
            local idx = (r - 1) * cols + c
            rowChildren[c] = gridSlots[idx]
        end
        gridRows[r] = UI.Panel {
            width = "100%",
            flexDirection = "row",
            children = rowChildren,
        }
    end

    -- 物品图片池：绝对定位面板，用于在格子上方叠加显示物品图片
    -- 不使用 backgroundImage（它不随布局缩放），改为自定义 Render 方法
    -- 在渲染时直接从 slot 读取实时布局，用 nvgImagePattern 手动绘制缩放图片
    refs.itemImages = {}
    local itemImageWidgets = {}
    for i = 1, MAX_ITEM_IMAGES do
        local idx = i
        local imgPanel = UI.Panel {
            position = "absolute",
            width = 32, height = 32,
            visible = false,
            onClick = function()
                Utils.PlayClick()
                local item = imageToItem[idx]
                if not item then return end
                -- 图片面板只在 L4 时显示，直接走 L4 逻辑（展示详情）
                -- 与 _OnSlotClick 的 level >= 4 分支保持一致
                local level = UIState.itemRevealLevels[item.idx] or 0
                if level >= 4 then
                    WarehouseItemListPanel.Hide()
                    local idp = getItemDetail()
                    if idp and idp:IsVisible()
                       and idp:GetCurrentItem()
                       and idp:GetCurrentItem().idx == item.idx then
                        idp:Hide()
                    elseif idp then
                        idp:Show(item)
                    end
                else
                    -- L2/L3：走槽点击逻辑（按品质+尺寸筛选）
                    local cols_ = Config.GAME.LootColumns
                    local slotIdx_ = (item.gridRow - 1) * cols_ + item.gridCol
                    LootPanel._OnSlotClick(slotIdx_)
                end
            end,
        }
        -- 自定义属性：渲染时用到
        imgPanel._imagePath = nil
        imgPanel._originSlot = nil
        imgPanel._endSlot = nil
        -- 重写 Render：在渲染时从 slot 实时读取布局，手动绘制缩放图片
        function imgPanel:Render(nvg)
            local imgPath = self._imagePath
            local oSlot = self._originSlot
            local eSlot = self._endSlot
            if not imgPath or not oSlot or not eSlot then return end

            local imgHandle = ImageCache.Get(imgPath)
            if not imgHandle or imgHandle <= 0 then return end
            local nativeW, nativeH = ImageCache.GetSize(imgPath)
            if nativeW <= 0 or nativeH <= 0 then return end

            -- 从 slot 实时布局算出图片绘制区域（渲染阶段，布局已是最新）
            local oL = oSlot:GetAbsoluteLayout()
            local eL = eSlot:GetAbsoluteLayout()
            local pad = 2
            local x = oL.x + pad
            local y = oL.y + pad
            local w = eL.x + eL.w - oL.x - pad * 2
            local h = eL.y + eL.h - oL.y - pad * 2
            if w <= 0 or h <= 0 then return end

            -- contain 缩放计算
            local imgRatio = nativeW / nativeH
            local boxRatio = w / h
            local drawX, drawY, drawW, drawH = x, y, w, h
            if imgRatio > boxRatio then
                drawW = w
                drawH = w / imgRatio
                drawY = y + (h - drawH) / 2
            else
                drawH = h
                drawW = h * imgRatio
                drawX = x + (w - drawW) / 2
            end

            local paint = nvgImagePattern(nvg, drawX, drawY, drawW, drawH, 0, imgHandle, 1)
            nvgBeginPath(nvg)
            nvgRect(nvg, x, y, w, h)
            nvgFillPaint(nvg, paint)
            nvgFill(nvg)
        end
        refs.itemImages[i] = imgPanel
        itemImageWidgets[#itemImageWidgets + 1] = imgPanel
    end

    -- 流光已改用 NanoVG 绘制，不再创建 Panel 池

    -- 组合网格行 + 图片层 + 流光点作为 children
    local gridChildren = {}
    for _, row in ipairs(gridRows) do
        gridChildren[#gridChildren + 1] = row
    end
    for _, img in ipairs(itemImageWidgets) do
        gridChildren[#gridChildren + 1] = img
    end

    local gridContainer = UI.Panel {
        id = "lootGridContainer",
        width = "100%",
        flexDirection = "column",
        paddingRight = 8,
        borderWidth = { left = 1, top = 1 },
        borderColor = { 80, 130, 170, 60 },
        children = gridChildren,
    }

    -- 在 gridContainer 上挂 Render，绘制搜索图标 + 流光动画（NanoVG 直绘）
    function gridContainer:Render(nvg)
        self:RenderFullBackground(nvg)
        local p = GS.GetPhase()
        local isOpen = (p == GS.PHASE.WAREHOUSE_OPEN or p == GS.PHASE.GAME_OVER)

        -- ====== 搜索图标绘制（仅 WAREHOUSE_OPEN 阶段，只在下一个待揭示物品上） ======
        -- NanoVG 在 Widget:Render 回调中使用全局绝对坐标
        if p == GS.PHASE.WAREHOUSE_OPEN then
            local items = GS.GetWarehouseItems()
            local nextIdx = GS.GetRevealedItemIndex() + 1
            local nextItem = items and items[nextIdx] or nil
            if nextItem then
                local iw = nextItem.w or 1
                local ih = nextItem.h or 1
                local originSlotIdx = (nextItem.gridRow - 1) * cols + nextItem.gridCol
                local endSlotIdx = (nextItem.gridRow + ih - 2) * cols + (nextItem.gridCol + iw - 1)
                local oSlot = refs.lootSlots[originSlotIdx]
                local eSlot = refs.lootSlots[endSlotIdx]
                if oSlot and eSlot then
                    local oL = oSlot:GetAbsoluteLayout()
                    local eL = eSlot:GetAbsoluteLayout()
                    local cx = (oL.x + eL.x + eL.w) / 2
                    local cy = (oL.y + eL.y + eL.h) / 2
                    local bw = eL.x + eL.w - oL.x
                    local bh = eL.y + eL.h - oL.y
                    local minDim = math.min(bw, bh)

                    local iconSize = minDim * 0.28
                    local orbitR = minDim * 0.2

                    local angle = UIState.glowTime * SEARCH_ORBIT_SPEED * math.pi * 2
                    local ix = cx + math.cos(angle) * orbitR
                    local iy = cy + math.sin(angle) * orbitR

                    local lensR = iconSize * 0.4
                    local handleLen = iconSize * 0.35
                    local strokeW = math.max(1.5, iconSize * 0.13)

                    nvgBeginPath(nvg)
                    nvgCircle(nvg, ix, iy, lensR)
                    nvgStrokeColor(nvg, nvgRGBA(200, 210, 220, 180))
                    nvgStrokeWidth(nvg, strokeW)
                    nvgStroke(nvg)

                    local hAngle = math.pi * 0.25
                    local hx1 = ix + math.cos(hAngle) * lensR
                    local hy1 = iy + math.sin(hAngle) * lensR
                    local hx2 = ix + math.cos(hAngle) * (lensR + handleLen)
                    local hy2 = iy + math.sin(hAngle) * (lensR + handleLen)
                    nvgBeginPath(nvg)
                    nvgMoveTo(nvg, hx1, hy1)
                    nvgLineTo(nvg, hx2, hy2)
                    nvgStrokeColor(nvg, nvgRGBA(200, 210, 220, 180))
                    nvgStrokeWidth(nvg, strokeW * 1.2)
                    nvgStroke(nvg)
                end
            end
        end

        -- ====== 流光动画绘制（竞拍阶段，level >= 1 的物品边框流光） ======
        if isOpen then return end  -- 开箱/结算阶段不画流光

        -- 流光开关检测
        local settings = SaveSystem.IsReady() and SaveSystem.GetSettings() or nil
        if settings and settings.glowEffect == false then return end

        local hasGlowItems = false
        for _, lv in pairs(UIState.itemRevealLevels) do
            if lv >= 1 then hasGlowItems = true; break end
        end
        if not hasGlowItems then return end

        local items = GS.GetWarehouseItems()
        local warehouseData = GS.GetWarehouseData()
        if not items or not warehouseData then return end

        -- cols 使用外层 Create() 中已声明的局部变量

        for itemIdx, level in pairs(UIState.itemRevealLevels) do
            if level < 1 then goto nextGlowItem end

            local item = items[itemIdx]
            if not item then goto nextGlowItem end

            local iw = item.w or 1
            local ih = item.h or 1

            -- L2：流光只绕 hint 格（1×1），不绕整个物品
            local glowOriginSlotIdx, glowEndSlotIdx
            if level == 2 then
                local hint = qualityHintSlots[itemIdx]
                if not hint then
                    -- 物品可能不在可见格子范围内，在此补充创建
                    hint = { dr = math.random(0, ih - 1), dc = math.random(0, iw - 1) }
                    qualityHintSlots[itemIdx] = hint
                end
                local hr = (item.gridRow - 1) + hint.dr + 1  -- 1-based
                local hc = (item.gridCol - 1) + hint.dc + 1  -- 1-based
                local hintSlotIdx = (hr - 1) * cols + hc
                glowOriginSlotIdx = hintSlotIdx
                glowEndSlotIdx    = hintSlotIdx
            else
                glowOriginSlotIdx = (item.gridRow - 1) * cols + item.gridCol
                glowEndSlotIdx    = (item.gridRow + ih - 2) * cols + (item.gridCol + iw - 1)
            end

            local originSlot = refs.lootSlots[glowOriginSlotIdx]
            local endSlot = refs.lootSlots[glowEndSlotIdx]
            if not originSlot or not endSlot then goto nextGlowItem end

            local oLayout = originSlot:GetAbsoluteLayout()
            local eLayout = endSlot:GetAbsoluteLayout()

            local x = oLayout.x
            local y = oLayout.y
            local bw = eLayout.x + eLayout.w - oLayout.x
            local bh = eLayout.y + eLayout.h - oLayout.y

            local perimeter = 2 * (bw + bh)
            if perimeter <= 0 then goto nextGlowItem end

            -- 颜色（L2+ 显示品质色，L1 显示灰蓝色）
            local rc, gc_, bc_
            if level >= 2 then
                local rar = Config.GetRarity(item.rarity)
                rc, gc_, bc_ = rar.color[1], rar.color[2], rar.color[3]
            else
                rc, gc_, bc_ = 120, 170, 220
            end

            local headPos = (UIState.glowTime * GLOW_SPEED) % perimeter

            for s = 1, SEGMENT_COUNT do
                local segPos = (headPos - (s - 1) * SEG_SPACING) % perimeter
                local sx, sy, edge = perimeterToXY(segPos, bw, bh)

                local t = (s - 1) / SEGMENT_COUNT
                local alpha = math.floor(220 * (1 - t * t))

                local segW, segH, segLeft, segTop
                if edge == "top" then
                    segW = SEG_SPACING + 2
                    segH = SEG_THICK
                    segLeft = x + sx - segW / 2
                    segTop = y - SEG_THICK / 2
                elseif edge == "right" then
                    segW = SEG_THICK
                    segH = SEG_SPACING + 2
                    segLeft = x + bw - SEG_THICK / 2
                    segTop = y + sy - segH / 2
                elseif edge == "bottom" then
                    segW = SEG_SPACING + 2
                    segH = SEG_THICK
                    segLeft = x + sx - segW / 2
                    segTop = y + bh - SEG_THICK / 2
                else -- left
                    segW = SEG_THICK
                    segH = SEG_SPACING + 2
                    segLeft = x - SEG_THICK / 2
                    segTop = y + sy - segH / 2
                end

                nvgBeginPath(nvg)
                nvgRect(nvg, segLeft, segTop, segW, segH)
                nvgFillColor(nvg, nvgRGBA(rc, gc_, bc_, alpha))
                nvgFill(nvg)
            end

            ::nextGlowItem::
        end
    end

    refs.gridContainer = gridContainer

    refs.estimateMinLabel = UI.Label {
        text = "", fontSize = 10, fontColor = { 255, 220, 100 }, flexShrink = 1,
    }

    return UI.Panel {
        id = "lootPanel",
        width = "34%", height = "100%",
        flexShrink = 1,
        backgroundColor = { 15, 20, 35, 140 },
        borderColor = { 80, 130, 170, 60 },
        borderWidth = { left = 1 },
        flexDirection = "column",
        overflow = "hidden",
        children = {
            -- 标题栏
            UI.Panel {
                width = "100%",
                flexDirection = "row", justifyContent = "space-between", alignItems = "center",
                flexShrink = 0,
                padding = { 8, 10 },
                backgroundColor = { 120, 30, 40, 160 },
                children = {
                    UI.Label { text = "战利品", fontSize = 13, fontColor = C.textPrimary, fontWeight = "bold" },
                    refs.estimateMinLabel,
                }
            },
            -- 网格区域
            UI.ScrollView {
                width = "100%",
                flexGrow = 1,
                flexBasis = 0,
                scrollY = true,
                scrollbarInteractive = false,
                children = { gridContainer },
            },

        }
    }
end

-- ============================================================================
-- 更新
-- ============================================================================

function LootPanel.Update()
    local phase = GS.GetPhase()
    local items = GS.GetWarehouseItems()
    local warehouseData = GS.GetWarehouseData()
    local revIdx = GS.GetRevealedItemIndex()
    local isOpen = (phase == GS.PHASE.WAREHOUSE_OPEN or phase == GS.PHASE.GAME_OVER)

    local cols = Config.GAME.LootColumns
    local maxRows = Config.GAME.LootMaxRows
    local grid = warehouseData and warehouseData.grid or nil

    -- 增量重置：只清理上一帧实际使用的图片面板（而非全部 200 个）
    imageToItem = {}
    for i = 1, lastActiveImageCount do
        if refs.itemImages[i] then
            refs.itemImages[i]:SetVisible(false)
            refs.itemImages[i]._imagePath = nil
            refs.itemImages[i]._originSlot = nil
            refs.itemImages[i]._endSlot = nil
        end
    end

    -- 清空 level-1 物品列表，本次扫描重新收集
    level1Items = {}

    -- 如果仓库数据变了（新对局），清空布局缓存
    if not warehouseData then
        imgLayoutCache = {}
        lastGridLayout = nil
    end

    local imgIdx = 0  -- 图片面板分配计数器
    local gridLayout = refs.gridContainer and refs.gridContainer:GetAbsoluteLayout() or nil

    -- 检测 grid 布局是否发生变化（resize 或首次加载），若变化则清空缓存
    local gridLayoutChanged = checkGridLayoutChanged(gridLayout)

    for r = 1, maxRows do
        for c = 1, cols do
            local slotIdx = (r - 1) * cols + c
            local iconW = refs.lootSlotIcons[slotIdx]
            if not iconW then goto nextSlot end

            local cellItemIdx = grid and grid[r] and grid[r][c] or 0
            local item = nil
            local isOrigin = false

            if cellItemIdx > 0 and cellItemIdx <= #items then
                item = items[cellItemIdx]
                isOrigin = (item.gridRow == r and item.gridCol == c)
            end

            -- 确定当前格子的揭示等级
            local level = 0
            if item then
                level = UIState.itemRevealLevels[item.idx] or 0
            end

            -- 增量优化：仅当格子 level 变化时才更新样式
            local levelChanged = (lastSlotLevels[slotIdx] ~= level)
            lastSlotLevels[slotIdx] = level

            if levelChanged then
                iconW:SetText("")
                iconW:SetVisible(false)
            end

            -- 对 level >= 1 的多格物品，计算外轮廓边框（隐藏内部共享边）
            local outerBorder
            if level >= 1 and item then
                local iw = item.w or 1
                local ih = item.h or 1
                if iw > 1 or ih > 1 then
                    local gr, gc_ = item.gridRow, item.gridCol
                    local bTop = (r == gr) and 1 or 0
                    local bBottom = (r == gr + ih - 1) and 1 or 0
                    local bLeft = (c == gc_) and 1 or 0
                    local bRight = (c == gc_ + iw - 1) and 1 or 0
                    if level >= 3 then
                        -- L3/L4: 粗品质色轮廓
                        outerBorder = { top = bTop * 2, right = bRight * 2, bottom = bBottom * 2, left = bLeft * 2 }
                    elseif level == 2 then
                        -- L2: 细灰色轮廓（只有品质提示格有品质色，其余灰色）
                        outerBorder = { top = bTop, right = bRight, bottom = bBottom, left = bLeft }
                    else
                        outerBorder = { top = bTop, right = bRight, bottom = bBottom, left = bLeft }
                    end
                end
            end

            -- L2 品质提示：确定/读取随机格子偏移
            local isQualityHintCell = false
            if level == 2 and item then
                local hint = qualityHintSlots[item.idx]
                if not hint then
                    -- 首次升到 L2 时随机固定一个格子
                    local iw = item.w or 1
                    local ih = item.h or 1
                    hint = { dr = math.random(0, ih - 1), dc = math.random(0, iw - 1) }
                    qualityHintSlots[item.idx] = hint
                end
                -- 判断当前格子是否是提示格
                local targetR = (item.gridRow - 1) + hint.dr
                local targetC = (item.gridCol - 1) + hint.dc
                isQualityHintCell = (r - 1 == targetR) and (c - 1 == targetC)
            end

            if level >= 4 then
                -- Level 4: 图片 + 品质边框（原 L3）
                local rar = Config.GetRarity(item.rarity)
                if isOrigin and item.image and gridLayout then
                    imgIdx = imgIdx + 1
                    if imgIdx <= MAX_ITEM_IMAGES then
                        imageToItem[imgIdx] = item
                        local originSlot = refs.lootSlots[slotIdx]
                        local endSlotIdx = (item.gridRow + item.h - 2) * cols + (item.gridCol + item.w - 1)
                        local endSlot = refs.lootSlots[endSlotIdx]
                        if originSlot and endSlot then
                            refs.itemImages[imgIdx]._imagePath = item.image
                            refs.itemImages[imgIdx]._originSlot = originSlot
                            refs.itemImages[imgIdx]._endSlot = endSlot
                            local cached = imgLayoutCache[item.idx]
                            if not cached or levelChanged or gridLayoutChanged then
                                local oLayout = originSlot:GetAbsoluteLayout()
                                local eLayout = endSlot:GetAbsoluteLayout()
                                cached = {
                                    x = oLayout.x - gridLayout.x,
                                    y = oLayout.y - gridLayout.y,
                                    w = eLayout.x + eLayout.w - oLayout.x,
                                    h = eLayout.y + eLayout.h - oLayout.y,
                                }
                                imgLayoutCache[item.idx] = cached
                            end
                            local pad = 2
                            refs.itemImages[imgIdx]:SetStyle({
                                left = cached.x + pad,
                                top = cached.y + pad,
                                width = cached.w - pad * 2,
                                height = cached.h - pad * 2,
                            })
                            refs.itemImages[imgIdx]:SetVisible(true)
                        end
                    end
                end
                if levelChanged then
                    refs.lootSlots[slotIdx]:SetStyle({
                        borderColor = rar.color,
                        borderWidth = outerBorder or 2,
                        backgroundColor = { rar.color[1], rar.color[2], rar.color[3], 40 },
                    })
                end

            elseif level == 3 then
                -- Level 3: 品质框（品质色覆盖整个 W×H）
                -- 从 L2 升上来时 levelChanged=true，所有格子都重绘，1×1 hint 自动被覆盖
                if levelChanged then
                    -- L2 的 hint 缓存已无用，释放
                    if isOrigin then qualityHintSlots[item.idx] = nil end
                    local rar = Config.GetRarity(item.rarity)
                    refs.lootSlots[slotIdx]:SetStyle({
                        borderColor = rar.color,
                        borderWidth = outerBorder or 2,
                        backgroundColor = { rar.color[1], rar.color[2], rar.color[3], 30 },
                    })
                end

            elseif level == 2 then
                -- Level 2: 品质提示 → 仅随机 1×1 格子显示品质色，其余格子与 L0 相同（不暴露轮廓）
                if levelChanged then
                    if isQualityHintCell then
                        local rar = Config.GetRarity(item.rarity)
                        refs.lootSlots[slotIdx]:SetStyle({
                            borderColor = rar.color,
                            borderWidth = 2,
                            backgroundColor = { rar.color[1], rar.color[2], rar.color[3], 50 },
                        })
                    else
                        -- 非 hint 格：完全恢复 L0 默认外观，不暴露物品形状
                        refs.lootSlots[slotIdx]:SetStyle({
                            borderColor = { 80, 130, 170, 60 },
                            borderWidth = { right = 1, bottom = 1 },
                            backgroundColor = { 0, 0, 0, 0 },
                        })
                    end
                end

            elseif level == 1 then
                -- Level 1: 位置已知，品质未知 → 灰色边框（搜索态）
                if levelChanged then
                    refs.lootSlots[slotIdx]:SetStyle({
                        borderColor = { 150, 160, 175, 120 },
                        borderWidth = outerBorder or 1,
                        backgroundColor = { 100, 110, 130, 35 },
                    })
                end
                -- 收集 level-1 原点物品，供 Render 绘制搜索图标
                if isOrigin then
                    local iw2 = item.w or 1
                    local ih2 = item.h or 1
                    local eIdx2 = (r + ih2 - 2) * cols + (c + iw2 - 1)
                    level1Items[#level1Items + 1] = {
                        item = item,
                        originSlotIdx = slotIdx,
                        endSlotIdx = eIdx2,
                    }
                end

            else
                -- Level 0: 隐藏（默认格子外观）
                if levelChanged then
                    refs.lootSlots[slotIdx]:SetStyle({
                        borderColor = { 80, 130, 170, 60 },
                        borderWidth = { right = 1, bottom = 1 },
                        backgroundColor = { 0, 0, 0, 0 },
                    })
                end
            end

            ::nextSlot::
        end
    end



    -- 预估最低价（仅在竞拍阶段且有已知信息时显示）
    if refs.estimateMinLabel then
        if isOpen then
            refs.estimateMinLabel:SetText("")
        else
            local estMin, knownCount, totalCount = EstimateValue.Calculate({
                publicInfos = UIState.revealedPublicInfos,
                skillInfos = UIState.revealedSkillInfos,
                itemRevealLevels = UIState.itemRevealLevels,
            }, GS.GetWarehouseTypeId())
            if estMin > 0 then
                refs.estimateMinLabel:SetText(
                    "预估最低价: " .. Utils.FormatMoney(estMin)
                )
            else
                refs.estimateMinLabel:SetText("")
            end
        end
    end

    -- 记录本帧活跃图片数，供下帧增量重置使用
    lastActiveImageCount = imgIdx
    -- 标记点击区域需要刷新
    hitAreasDirty = true
end

-- ============================================================================
-- 图片点击区域同步（每帧调用，确保 resize 后命中检测区域正确）
-- ============================================================================

function LootPanel.IsHitAreasDirty()
    return hitAreasDirty
end

function LootPanel.UpdateImageHitAreas()
    hitAreasDirty = false
    local gridLayout = refs.gridContainer and refs.gridContainer:GetAbsoluteLayout() or nil
    if not gridLayout then return end

    -- 检测 grid 是否 resize（复用 Update 中同一个函数）
    local gridChanged = checkGridLayoutChanged(gridLayout)

    for i = 1, lastActiveImageCount do
        local img = refs.itemImages[i]
        if not img or not img:IsVisible() then goto nextImg end

        local item = imageToItem[i]
        local cached = item and imgLayoutCache[item.idx] or nil

        -- 仅在缓存缺失或 grid resize 时重算
        if not cached or gridChanged then
            local oSlot = img._originSlot
            local eSlot = img._endSlot
            if not oSlot or not eSlot then goto nextImg end
            local oLayout = oSlot:GetAbsoluteLayout()
            local eLayout = eSlot:GetAbsoluteLayout()
            cached = {
                x = oLayout.x - gridLayout.x,
                y = oLayout.y - gridLayout.y,
                w = eLayout.x + eLayout.w - oLayout.x,
                h = eLayout.y + eLayout.h - oLayout.y,
            }
            if item then imgLayoutCache[item.idx] = cached end
        end

        local pad = 2
        img:SetStyle({
            left = cached.x + pad,
            top = cached.y + pad,
            width = cached.w - pad * 2,
            height = cached.h - pad * 2,
        })

        ::nextImg::
    end
end

-- ============================================================================
-- 边框流光（已改为 NanoVG 绘制，UpdateGlow 不再需要操作 Panel）
-- ============================================================================

function LootPanel.UpdateGlow()
    -- 流光已由 gridContainer:Render(nvg) 直接绘制，此函数保留空壳兼容调用
end

--- 重置增量缓存（新一局时调用）
function LootPanel.ResetCache()
    lastSlotLevels = {}
    lastActiveImageCount = 0
    level1Items = {}
    imageToItem = {}
    qualityHintSlots = {}
end

-- ============================================================================
-- 命中检测：根据屏幕坐标查找格子索引
-- ============================================================================

--- 根据绝对坐标 (x, y) 命中检测格子，返回 slotIdx 或 nil
function LootPanel.HitTestSlot(x, y)
    if not refs.lootSlots then return nil end
    for i = 1, #refs.lootSlots do
        local slot = refs.lootSlots[i]
        if slot then
            local l = slot:GetAbsoluteLayout()
            if x >= l.x and x <= l.x + l.w and y >= l.y and y <= l.y + l.h then
                return i
            end
        end
    end
    return nil
end

-- ============================================================================
-- 格子点击处理
-- ============================================================================

function LootPanel._OnSlotClick(slotIdx)
    local items = GS.GetWarehouseItems()
    local warehouseData = GS.GetWarehouseData()
    if not items or not warehouseData then return end
    local grid = warehouseData.grid
    if not grid then return end

    local cols = Config.GAME.LootColumns
    local r = math.ceil(slotIdx / cols)
    local c = slotIdx - (r - 1) * cols

    local cellItemIdx = grid[r] and grid[r][c] or 0

    -- 点击空白格子（level 0 或无物品）→ 关闭所有面板
    local idp = getItemDetail()
    if cellItemIdx <= 0 or cellItemIdx > #items then
        if idp then idp:Hide() end
        WarehouseItemListPanel.Hide()
        return
    end

    local item = items[cellItemIdx]
    local level = UIState.itemRevealLevels[item.idx] or 0

    if level == 0 then
        -- Level 0：无信息的格子视为空白，关闭面板
        if idp then idp:Hide() end
        WarehouseItemListPanel.Hide()
        return
    end

    local sizeKey = (item.w or 1) .. "x" .. (item.h or 1)

    if level == 1 then
        -- Level 1（灰色，品质未知）：按尺寸筛选展示物品（再次点击关闭）
        if idp then idp:Hide() end
        WarehouseItemListPanel.Toggle(nil, sizeKey, slotIdx)
    elseif level == 2 then
        -- Level 2（品质提示，1×1格子显示品质色）：只按品质筛选（轮廓未知，不传尺寸）
        if idp then idp:Hide() end
        WarehouseItemListPanel.Toggle(item.rarity, nil, slotIdx)
    elseif level == 3 then
        -- Level 3（品质框，W×H全覆盖品质色）：按品质+尺寸筛选展示物品
        if idp then idp:Hide() end
        WarehouseItemListPanel.Toggle(item.rarity, sizeKey, slotIdx)
    elseif level >= 4 then
        -- Level 4：展示物品详情
        WarehouseItemListPanel.Hide()
        if idp and idp:IsVisible()
           and idp:GetCurrentItem()
           and idp:GetCurrentItem().idx == item.idx then
            idp:Hide()
        elseif idp then
            idp:Show(item)
        end
    end
end

return LootPanel
