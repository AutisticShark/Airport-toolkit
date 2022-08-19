# Airport-toolkit
各類方便機場主進行安裝維護的 Shell Script。

所有 Script 除非特別説明，均需要 root 權限才能運行。    
末尾的 c8 代表該 Script 是針對 CentOS Stream/RHEL 8 編寫，c9 代表 CentOS Stream/RHEL 9，不帶則適用於 CentOS Stream/RHEL 8 以及 Fedora 34 以上的 OS。    
Script 均在 RHEL 8/9 的環境上進行測試。    

## Script 説明

b2_backup_c8.sh --> 用於備份你的 LNMP 站點與資料庫内容至 B2 Cloud Storage

bbr_*.sh --> 用於安裝 epelrepo 内核並啓用 BBR 加速

ssr_node.sh --> 用於安裝 shadowsocks-mod 服務端

trojan_node.sh --> 用於安裝 TrojanX 服務端

zabbix_agent_*.sh --> 用於安裝 Zabbix Agent
