#!/bin/bash

# === 环境参数 ===
STORAGE="local"  # Proxmox 存储名称，比如 local, local-lvm
BRIDGE="vmbr0"
QCOW2_TEMPLATE="/var/lib/vz/template/iso/debian11.qcow2"
GITHUB_URL="https://github.com/oneclickvirt/pve_kvm_images/releases/download/images/debian11.qcow2"

# === 1. 显示已有虚拟机列表 & 获取最大 VMID ===
echo "📋 当前服务器虚拟机列表如下："
qm list

MAX_ID=$(qm list | awk 'NR>1 {print $1}' | sort -n | tail -n1)
NEW_ID=$((MAX_ID+1))

echo -e "\n📌 当前最大 VM ID 为：$MAX_ID"
read -p "✅ 是否新建 VM ID 为 $NEW_ID？(y/n): " CONFIRM
if [[ "$CONFIRM" != "y" ]]; then
	    read -p "请输入新的 VM ID: " NEW_ID
fi

# === 防呆机制：检查 ID 是否已存在 ===
if qm list | awk '{print $1}' | grep -q "^${NEW_ID}$"; then
	    echo "❌ VM ID $NEW_ID 已存在，请重新选择 ID"
	        exit 1
fi

# === 2. 获取用户输入配置 ===
read -p "请输入虚拟机名称 (VM_NAME): " VM_NAME
read -p "请输入静态 IP 地址（如 192.168.100.123/24）: " STATIC_IP
read -p "请输入默认网关（如 192.168.100.1）: " GATEWAY
read -p "请输入 root 登录密码: " CI_PASSWORD

# === 固定资源配置 ===
MEMORY=2048
CORES=2

# === 3. 下载镜像（如果不存在）===
echo "📦 检查镜像是否存在：$QCOW2_TEMPLATE"
if [ ! -f "$QCOW2_TEMPLATE" ]; then
	    echo "🔽 镜像不存在，正在从 GitHub 下载..."
	        mkdir -p $(dirname "$QCOW2_TEMPLATE")
		    wget -O "$QCOW2_TEMPLATE" "$GITHUB_URL"
		        if [ $? -ne 0 ]; then
				        echo "❌ 下载失败，请检查网络连接或 GitHub 地址是否正确"
					        exit 1
						    fi
						        echo "✅ 下载完成：$QCOW2_TEMPLATE"
						else
							    echo "✅ 镜像已存在，跳过下载"
fi

# === 4. 创建 VM ===
echo "🚀 创建虚拟机 $VM_NAME (ID: $NEW_ID)"
qm create $NEW_ID --name "$VM_NAME" --cpu host --memory $MEMORY --cores $CORES --net0 virtio,bridge=$BRIDGE

# === 5. 准备磁盘并挂载 ===
VM_DISK_PATH="/var/lib/vz/images/$NEW_ID/vm-$NEW_ID-disk-0.qcow2"
mkdir -p /var/lib/vz/images/$NEW_ID/
cp "$QCOW2_TEMPLATE" "$VM_DISK_PATH"
qm set $NEW_ID --scsihw virtio-scsi-pci --scsi0 ${STORAGE}:$NEW_ID/vm-$NEW_ID-disk-0.qcow2
qm set $NEW_ID --boot c --bootdisk scsi0

# === 6. 配置 cloud-init 驱动和参数 ===
qm set $NEW_ID --ide2 ${STORAGE}:cloudinit
qm set $NEW_ID --ciuser root --cipassword "$CI_PASSWORD"
qm set $NEW_ID --ipconfig0 ip=$STATIC_IP,gw=$GATEWAY
qm set $NEW_ID --serial0 socket --vga serial0

# === 7. 启动虚拟机 ===
qm start $NEW_ID

# === 8. 提示信息 ===
echo -e "\n✅ 虚拟机已创建并启动："
echo " - VM ID：$NEW_ID"
echo " - 名称：$VM_NAME"
echo " - IP地址：$STATIC_IP"
echo " - 网关：$GATEWAY"
echo " - 登录用户：root"
echo " - 登录密码：$CI_PASSWORD"
