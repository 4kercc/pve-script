#!/bin/bash

# 用法检查
if [ "$#" -lt 2 ]; then
    echo "用法: $0 <vmid1> <vmid2> ... <days_to_keep>"
    exit 1
fi

# 获取参数
DAYS_TO_KEEP="${@: -1}"  # 最后一个参数
VMIDS=("${@:1:$#-1}")    # 除最后一个参数外的所有参数

# 获取当前日期时间，作为快照名
NOW=$(date +"%Y%m%d-%H%M%S")
SNAPSHOT_NAME="auto-$NOW"

# 获取当前时间戳（秒）
NOW_TS=$(date +%s)

echo "当前快照名: $SNAPSHOT_NAME"
echo "将删除超过 $DAYS_TO_KEEP 天前的快照"

# 遍历每个 VM ID
for VMID in "${VMIDS[@]}"; do
    echo "处理 VM $VMID"

    # 创建快照
    echo "  ➤ 正在创建快照..."
    qm snapshot "$VMID" "$SNAPSHOT_NAME" -description "Auto snapshot on $NOW" --vmstate 0

    # 获取该 VM 所有快照信息
    echo "  ➤ 检查旧快照..."
    qm listsnapshot "$VMID" | grep '^auto-' | while read -r line; do
        SNAP_NAME=$(echo "$line" | awk '{print $1}')

        # 从快照名中提取时间字符串
        SNAP_DATE=$(echo "$SNAP_NAME" | sed -n 's/auto-\([0-9]\{8\}-[0-9]\{6\}\)/\1/p')
        if [[ -z "$SNAP_DATE" ]]; then
            continue
        fi

        # 将快照名转为时间戳
        SNAP_TS=$(date -d "${SNAP_DATE:0:8} ${SNAP_DATE:9:2}:${SNAP_DATE:11:2}:${SNAP_DATE:13:2}" +%s)
        AGE=$(( (NOW_TS - SNAP_TS) / 86400 ))

        if (( AGE > DAYS_TO_KEEP )); then
            echo "  ⚠️ 删除过期快照 $SNAP_NAME (${AGE}天前)"
            qm delsnapshot "$VMID" "$SNAP_NAME" --force 1
        fi
    done

    echo ""
done

echo "✅ 所有任务完成。"
