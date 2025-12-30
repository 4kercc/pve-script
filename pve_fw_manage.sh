#!/bin/bash

# 自动管理 PVE cluster.fw 防火墙规则
# 功能：
# 1. 输入一个或多个源 IP / IP 段（逗号分隔）
# 2. 输入一个或多个目标端口（逗号分隔）
# 3. 自动写入 cluster.fw，避免重复
# 4. 提示重载防火墙

CLUSTER_FW="/etc/pve/firewall/cluster.fw"
IPSET_NAME="mgmt-ipv4"

# 检查 root 权限
if [[ $EUID -ne 0 ]]; then
    echo "请使用 root 运行此脚本"
    exit 1
fi

# 输入源 IP 或网段
read -p "请输入允许访问的源 IP 或 IP 段（多个用逗号分隔，如 1.1.1.1,192.168.1.0/24）: " SRC_INPUT
if [[ -z "$SRC_INPUT" ]]; then
    echo "源 IP/IP 段不能为空"
    exit 1
fi

# 输入目标端口
read -p "请输入允许访问的目标端口（多个用逗号分隔，如 8006,22）: " DST_INPUT
if [[ -z "$DST_INPUT" ]]; then
    echo "目标端口不能为空"
    exit 1
fi

# 创建 IPSET 段落（如果不存在）
if ! grep -q "^\[IPSET $IPSET_NAME\]" "$CLUSTER_FW"; then
    echo "IPSET $IPSET_NAME 不存在，正在创建..."
    echo -e "\n[IPSET $IPSET_NAME]" >> "$CLUSTER_FW"
fi

# 处理每个源 IP / IP 段
IFS=',' read -ra SRC_ARRAY <<< "$SRC_INPUT"
for SRC in "${SRC_ARRAY[@]}"; do
    # 去掉空格
    SRC=$(echo "$SRC" | xargs)
    # 检查是否已存在
    if ! grep -q "^$SRC" "$CLUSTER_FW"; then
        echo "添加源 IP/IP段: $SRC"
        sed -i "/^\[IPSET $IPSET_NAME\]/a $SRC" "$CLUSTER_FW"
    else
        echo "源 $SRC 已存在，无需重复添加"
    fi
done

# 创建 RULES 段落（如果不存在）
if ! grep -q "^\[RULES\]" "$CLUSTER_FW"; then
    echo "RULES 段不存在，正在创建..."
    echo -e "\n[RULES]" >> "$CLUSTER_FW"
fi

# 处理每个目标端口
IFS=',' read -ra PORT_ARRAY <<< "$DST_INPUT"
for PORT in "${PORT_ARRAY[@]}"; do
    PORT=$(echo "$PORT" | xargs)
    RULE="IN ACCEPT -source +$IPSET_NAME -p tcp --dport $PORT"
    # 检查规则是否已存在
    if ! grep -qF "$RULE" "$CLUSTER_FW"; then
        echo "添加规则: 源 $SRC_INPUT 允许访问端口 $PORT"
        sed -i "/^\[RULES\]/a $RULE" "$CLUSTER_FW"
    else
        echo "规则已存在: $RULE"
    fi
done
pve-firewall restart
echo "操作完成，规则已经生效"
