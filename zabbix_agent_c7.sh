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
echo "Zabbix agent installation script for CentOS 7 x64"

[ $(id -u) != "0" ] && { echo "Error: You must be root to run this script!"; exit 1; }

#Configuration
zabbix_release_40_url = http://repo.zabbix.com/zabbix/4.0/rhel/7/x86_64/zabbix-release-4.0-2.el7.noarch.rpm
zabbix_release_50_url = http://repo.zabbix.com/zabbix/5.0/rhel/7/x86_64/zabbix-release-5.0-1.el7.noarch.rpm
zabbix_config_file_path = /etc/zabbix/zabbix_agentd.conf

while :; do echo
	echo -e "Please select Zabbix agent version you want to install:"
	echo -e "\t1. 4.0"
	echo -e "\t2. 5.0"
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

do_install_zabbix_agent_40(){
    rpm -ivh $zabbix_release_40_url
    yum install zabbix-agent -y
}

do_install_zabbix_agent_50(){
    rpm -ivh $zabbix_release_50_url
    yum install zabbix-agent -y
}

do_zabbix_agent_configure

if [[ ${zabbix_version} == 1 ]]; then
    do_install_zabbix_agent_40
elif [[ ${zabbix_version} == 2 ]]; then
    do_install_zabbix_agent_50
fi

do_enable_and_start_zabbix_agent