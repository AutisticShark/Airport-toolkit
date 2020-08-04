#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
cat << "EOF"
 ______                               ____              __      
/\__  _\               __            /\  _`\           /\ \__   
\/_/\ \/   ___   __  _/\_\    ___    \ \ \/\_\     __  \ \ ,_\  
   \ \ \  / __`\/\ \/'\/\ \  /'___\   \ \ \/_/_  /'__`\ \ \ \/  
    \ \ \/\ \L\ \/>  </\ \ \/\ \__/    \ \ \L\ \/\ \L\.\_\ \ \_ 
     \ \_\ \____//\_/\_\\ \_\ \____\    \ \____/\ \__/.\_\\ \__\
      \/_/\/___/ \//\/_/ \/_/\/____/     \/___/  \/__/\/_/ \/__/
                                                                
Author: Toxic Cat
Github: https://github.com/Toxic-Cat/Airport-toolkit                                 
EOF
echo "Trojan cluster installation script for CentOS 8 x64"
[ $(id -u) != "0" ] && { echo "Error: You must be root to run this script!"; exit 1; }
echo -n "WebAPI url:"
read webapi_url
echo -n "WebAPI token:"
read webapi_token
echo -n "Server node ID:"
read node_id
while :; do echo
	echo -n "Do you want to enable BBR feature(using system kernel) and optimizate the system?(Y/N)"
	read is_bbr
	if [[ ${is_bbr} != "y" && ${is_bbr} != "Y" && ${is_bbr} != "N" && ${is_bbr} != "n" ]]; then
		echo -n "Bad answer! Please only input number Y or N"
	else
		break
	fi
done
echo "Checking if there is any existing trojan cluster installation..."
if [ -d "/soft/trojan-cluster" ]; then
	while :; do echo
		echo -n "Detect exist trojan cluster installation! If you continue this install, all the previous configuration will be lost! Continue?(Y/N)"
		read is_clean_old
		if [[ ${is_clean_old} != "y" && ${is_clean_old} != "Y" && ${is_clean_old} != "N" && ${is_clean_old} != "n" ]]; then
			echo -n "Bad answer! Please only input number Y or N"
		elif [[ ${is_clean_old} == "y" || ${is_clean_old} == "Y" ]]; then
			rm -rf /soft
			break
		else
			exit 0
		fi
	done
fi
echo "Updatin exsit package..."
dnf clean all && dnf update -y
do_bbr(){
	echo "Running system optimization and enable BBR..."
	echo "tcp_bbr" >> /etc/modules-load.d/modules.conf
	cat >> /etc/security/limits.conf << EOF
	* soft nofile 51200
	* hard nofile 51200
EOF
	ulimit -n 51200
	cat >> /etc/sysctl.conf << EOF
	fs.file-max = 51200
	net.core.default_qdisc = fq
	net.core.rmem_max = 67108864
	net.core.wmem_max = 67108864
	net.core.netdev_max_backlog = 250000
	net.core.somaxconn = 4096
	net.ipv4.tcp_congestion_control = bbr
	net.ipv4.tcp_syncookies = 1
	net.ipv4.tcp_tw_reuse = 1
	net.ipv4.tcp_fin_timeout = 30
	net.ipv4.tcp_keepalive_time = 1200
	net.ipv4.ip_local_port_range = 10000 65000
	net.ipv4.tcp_max_syn_backlog = 8192
	net.ipv4.tcp_max_tw_buckets = 5000
	net.ipv4.tcp_fastopen = 3
	net.ipv4.tcp_rmem = 4096 87380 67108864
	net.ipv4.tcp_wmem = 4096 65536 67108864
	net.ipv4.tcp_mtu_probing = 1
EOF
	sysctl -p
}
if [[ ${is_bbr} == "y" || ${is_bbr} == "Y" ]]; then
	do_bbr
fi

