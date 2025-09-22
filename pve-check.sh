#!/usr/bin/env bash
function check_and_restart() {
    vm_id="${1}"
    vm_ip="${2}"
    # curl --connect-timeout 5 -sSL "${vm_ip}" > /dev/null
    ping -c 1 "${vm_ip}" > /dev/null
    if [[ $? != 0 ]]; then
  now=`timedatectl status | grep 'Local time' | awk -F"Local time: " '{ print $2 }'`
  echo "[${now}] [NO] id = ${vm_id}, ip = ${vm_ip}"
        /usr/sbin/qm stop "${vm_id}"
        /usr/sbin/qm start "${vm_id}"
else
	echo VM "$vm_id" is runing!
    fi
}
function main() {
    vm_list=${1}
    for each in ${vm_list}; do
        vm_id=`echo "${each}" | awk -F: '{ print $1 }'`
        vm_ip=`echo "${each}" | awk -F: '{ print $2 }'`
  check_and_restart "${vm_id}" "${vm_ip}"
    done
}
# 需要检查的虚拟机列表，格式为 vm_id:vm_ip
vm_list="
101:198.46.1.1
103:198.46.1.2
102:198.46.1.3
"
# 打印时间
timedatectl status | grep 'Local time' | awk -F"Local time: " '{ print $2 }'
main "${vm_list}"
