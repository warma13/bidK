#!/bin/bash
# Move generated item images from /workspace/assets/image/ to their correct asset directories.
# Removes timestamps from filenames. Uses the LATEST version if multiple exist.

SRC_DIR="/workspace/assets/image"
ITEMS_DIR="/workspace/assets/items"

SUCCESS=0
FAIL=0
SKIP=0

# Function: find latest timestamped file for an item name, copy to target dir
move_item() {
    local item_name="$1"
    local target_dir="$2"

    # Find all matching files: {item_name}_{timestamp}.png
    local candidates=()
    while IFS= read -r -d '' f; do
        candidates+=("$f")
    done < <(find "$SRC_DIR" -maxdepth 1 -name "${item_name}_*.png" ! -name "*.meta" -print0 2>/dev/null)

    if [ ${#candidates[@]} -eq 0 ]; then
        echo "  [MISS] $item_name  -- no source file found"
        ((SKIP++))
        return
    fi

    # Sort by name descending to get latest timestamp first
    local latest
    latest=$(printf '%s\n' "${candidates[@]}" | sort -r | head -n1)

    # Create target directory
    mkdir -p "$target_dir"

    # Copy with timestamp removed
    local dest="${target_dir}/${item_name}.png"
    cp "$latest" "$dest"
    if [ $? -eq 0 ]; then
        echo "  [OK]   $item_name  <- $(basename "$latest")  -> $dest"
        ((SUCCESS++))
    else
        echo "  [FAIL] $item_name  -- copy failed"
        ((FAIL++))
    fi
}

echo "=============================================="
echo " Item Image Organizer"
echo "=============================================="
echo ""

# -----------------------------------------------
# Group 1: ItemPool.lua -> assets/items/{category}/
# -----------------------------------------------
echo "--- Group 1: ItemPool.lua (古董) ---"
for item in \
    "老铜碗" "竹编提篮" "铜水烟袋" "银耳挖" "老铜镜" \
    "汉代陶俑" "清代官帽" "老煤油炉" "铜烛剪" "铁路信号灯" \
    "船用汽笛" "瓦特蒸汽机零件" "法拉第线圈装置" "机械秒表" "老式相机" \
    "初代游戏机" "老唱片机" "爱迪生留声机部件" "达芬奇手稿残页" "砖雕花片"
do
    move_item "$item" "$ITEMS_DIR/古董"
done

echo ""
echo "--- Group 1: ItemPool.lua (艺术) ---"
for item in \
    "粗陶花瓶" "老年画原版" "民国月份牌" "清宫如意" "宋代瓷枕"
do
    move_item "$item" "$ITEMS_DIR/艺术"
done

echo ""
echo "--- Group 1: ItemPool.lua (珠宝) ---"
for item in \
    "银质发簪" "绿松石散珠" "老银锁片" "玛瑙扳指" "翡翠观音挂件" "老坑翡翠手镐"
do
    move_item "$item" "$ITEMS_DIR/珠宝"
done

echo ""
echo "--- Group 1: ItemPool.lua (机械) ---"
for item in \
    "手动缝纫机" "铜质天平" "航海六分仪" "老式显微镜" "蒸汽朋克机械钟" \
    "潜艇潜望镜" "老自行车铃" "马车灯" "老式摩托油箱" "黄铜船锚模型" \
    "古董摩托车" "老式火车模型"
do
    move_item "$item" "$ITEMS_DIR/机械"
done

# -----------------------------------------------
# Group 2: BondedPort.lua -> assets/items/保税区/
# -----------------------------------------------
echo ""
echo "--- Group 2: BondedPort.lua (保税区) ---"
for item in \
    "陈年黄酒坛" "古巴雪茄单支" "老窖原浆酒" "进口雪茄保湿柜" \
    "单瓶年份红酒" "日本限定清酒" "整箱进口红酒" "百年陈酿白兰地"
do
    move_item "$item" "$ITEMS_DIR/保税区"
done

# -----------------------------------------------
# Group 3: DataCenter.lua -> assets/items/数据中心/
# -----------------------------------------------
echo ""
echo "--- Group 3: DataCenter.lua (数据中心 - Energy) ---"
for item in \
    "旧等离子球" "太阳能电池板碎片" "军用夜光管" "工业级激光管" \
    "超导线圈组件" "核电站控制杆" "电磁悬浮陀螞" "信号干扰器外壳" "碳纳米管样品管"
do
    move_item "$item" "$ITEMS_DIR/数据中心"
done

echo ""
echo "--- Group 3: DataCenter.lua (数据中心 - Transport) ---"
for item in \
    "无人机涡轮引擎" "军用外骨骼脚踝" "磁浮列车制动器"
do
    move_item "$item" "$ITEMS_DIR/数据中心"
done

echo ""
echo "--- Group 3: DataCenter.lua (数据中心 - Art) ---"
for item in \
    "像素画打印件" "霓虹灯管字母" "赛博涂鸦模板" "全息投影名片盒" \
    "街头涂鸦墙砖" "动态光雕原件"
do
    move_item "$item" "$ITEMS_DIR/数据中心"
done

echo ""
echo "--- Group 3: DataCenter.lua (数据中心 - Tech) ---"
for item in \
    "加密U盘" "废旧VR手套" "生物芯片植入器" "脑电波耳机原型" \
    "军用无人机主板" "神经接口芯片"
do
    move_item "$item" "$ITEMS_DIR/数据中心"
done

echo ""
echo "--- Group 3: DataCenter.lua (数据中心 - Mechanical) ---"
for item in \
    "旧伺服电机" "气动缸筒" "精密减速器" "碳纤维机械臂段" \
    "仿生关节组件" "液压动力单元"
do
    move_item "$item" "$ITEMS_DIR/数据中心"
done

# -----------------------------------------------
# Summary
# -----------------------------------------------
echo ""
echo "=============================================="
echo " Summary"
echo "=============================================="
echo "  OK:   $SUCCESS"
echo "  MISS: $SKIP  (no source image found)"
echo "  FAIL: $FAIL"
echo "  Total items processed: $((SUCCESS + SKIP + FAIL))"
echo "=============================================="
