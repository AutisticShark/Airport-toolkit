#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
cat << "EOF"
shadowsocks-mod server installation script for RHEL/CentOS Stream 9 x86_64
Author: M1Screw
Github: https://github.com/M1Screw/Airport-toolkit                                 
EOF

[ $(id -u) != "0" ] && { echo "Error: You must be root to run this script!"; exit 1; }

