# pve-script
收集一些pve脚本

build-vm.sh：
pve创建独立ip虚拟机


---
pve-snapshot.sh：

用法: pve-snapshot.sh<vmid1> <vmid2> ... <days_to_keep>

举例:  pve-snapshot.sh 101 102 103 3 #备份101,102,103虚拟机快照，保留三天

---
pve-check.sh 检查虚拟机状态，如果关机状态，就执行启动
