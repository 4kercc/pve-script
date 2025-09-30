#!/bin/bash

VMID="$1"

if [[ -z "$VMID" ]]; then
  echo "❌ 用法: bash $0 <VMID>"
  exit 1
fi

VM_CONF="/etc/pve/qemu-server/${VMID}.conf"
if [[ ! -f "$VM_CONF" ]]; then
  echo "❌ 虚拟机配置文件不存在: $VM_CONF"
  exit 1
fi

echo "🛑 正在关闭虚拟机 $VMID..."
qm shutdown "$VMID" >/dev/null 2>&1
sleep 5

# 等待虚拟机完全关闭
while qm status "$VMID" | grep -q "status: running"; do
  echo "⏳ 等待虚拟机关闭..."
  sleep 2
done

# 查找配置文件中挂载了 .raw 的磁盘
DISK_LINE=$(grep -E '^[a-z0-9]+[0-9]*: .*\.raw' "$VM_CONF")
if [[ -z "$DISK_LINE" ]]; then
  echo "❌ 未找到 .raw 格式的磁盘挂载项"
  exit 1
fi

# 解析磁盘信息
DISK_KEY=$(echo "$DISK_LINE" | cut -d: -f1)
DISK_VALUE=$(echo "$DISK_LINE" | cut -d: -f2- | xargs)
DISK_STORE=$(echo "$DISK_VALUE" | cut -d: -f1)
DISK_PATH_RAW=$(echo "$DISK_VALUE" | cut -d: -f2 | cut -d, -f1)

RAW_FILENAME=$(basename "$DISK_PATH_RAW")
VM_DIR="/var/lib/vz/images/${VMID}"
RAW_FULL_PATH="${VM_DIR}/${RAW_FILENAME}"

if [[ ! -f "$RAW_FULL_PATH" ]]; then
  echo "❌ RAW 文件不存在: $RAW_FULL_PATH"
  exit 1
fi

# 生成 .qcow2 文件路径
QCOW2_FILENAME="${RAW_FILENAME%.raw}.qcow2"
QCOW2_FULL_PATH="${VM_DIR}/${QCOW2_FILENAME}"

echo "🔄 正在转换为 qcow2 格式..."
qemu-img convert -f raw -O qcow2 "$RAW_FULL_PATH" "$QCOW2_FULL_PATH"
if [[ $? -ne 0 ]]; then
  echo "❌ 转换失败"
  exit 1
fi

# 替换配置文件中的 .raw 为 .qcow2
echo "📝 正在修改虚拟机配置..."
OLD_DISK_STRING="${DISK_STORE}:${DISK_PATH_RAW}"
NEW_DISK_STRING="${DISK_STORE}:${VMID}/${QCOW2_FILENAME}"
sed -i "s|${OLD_DISK_STRING}|${NEW_DISK_STRING}|" "$VM_CONF"

# 删除原始 raw 文件
echo "🧹 正在删除原始 .raw 文件..."
rm -f "$RAW_FULL_PATH"

# 启动虚拟机
echo "✅ 转换完成，正在启动虚拟机 $VMID..."
qm start "$VMID"
