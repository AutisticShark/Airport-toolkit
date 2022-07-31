#!/usr/bin/bash
cat << "EOF"
Zabbix agent installation script for RHEL/CentOS Stream 9 x86_64
Author: M1Screw
Github: https://github.com/M1Screw/Airport-toolkit                                 
EOF

[ $(id -u) != "0" ] && { echo "Error: You must be root to run this script!"; exit 1; }

#Configuration
zabbix_release_60_url="https://repo.zabbix.com/zabbix/6.0/rhel/9/x86_64/zabbix-release-6.0-3.el9.noarch.rpm"
zabbix_release_62_url="https://repo.zabbix.com/zabbix/6.2/rhel/9/x86_64/zabbix-release-6.2-2.el9.noarch.rpm"
zabbix_config_file_path="/etc/zabbix/zabbix_agentd.conf"

while :; do echo
	echo -e "Please select Zabbix agent version you want to install:"
	echo -e "\t1. 6.0 LTS"
	echo -e "\t2. 6.2"
	read -p "Please input a number:(Default 2 press Enter) " zabbix_version
	[ -z ${zabbix_version} ] && zabbix_version=1
	if [[ ! ${zabbix_version} =~ ^[1-2]$ ]]; then
		echo "Bad answer! Please only input number 1~2"
	else
		break
	fi			
done

do_zabbix_agent_configure(){
    echo -n "Please enter Zabbix master's IP address:"
	read zabbix_master_ip
	echo -n "Please enter this server's hostname:"
	read agent_hostname
}

do_edit_zabbix_agent_config(){
    sed -i -e "s/Server=127.0.0.1/Server=$zabbix_master_ip/g" -e "s/ServerActive=127.0.0.1/ServerActive=$zabbix_master_ip/g" -e "s/Hostname=Zabbix server/Hostname=$agent_hostname/g" $zabbix_config_file_path
}

do_enable_and_start_zabbix_agent(){
    systemctl enable zabbix-agent
    systemctl restart zabbix-agent
}

do_install_zabbix_agent_60(){
    rpm -ivh $zabbix_release_60_url
    yum install zabbix-agent -y
}

do_install_zabbix_agent_62(){
    rpm -ivh $zabbix_release_62_url
    yum install zabbix-agent -y
}

do_zabbix_agent_configure

if [[ ${zabbix_version} == 1 ]]; then
    do_install_zabbix_agent_60
elif [[ ${zabbix_version} == 2 ]]; then
    do_install_zabbix_agent_62
fi

do_enable_and_start_zabbix_agent