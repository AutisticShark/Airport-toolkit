#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
cat << "EOF"
TrojanX server installation script for RHEL/CentOS Stream 9 x86_64                                                           
Author: M1Screw
Github: https://github.com/M1Screw/Airport-toolkit
Usage: 
./trojan_node_c9.sh install --> Install TrojanX server
./trojan_node_c9.sh config --> Configure TrojanX server
./trojan_node_c9.sh update --> Update TrojanX server                           
EOF

[ $(id -u) != "0" ] && { echo "Error: You must be root to run this script!"; exit 1; }

