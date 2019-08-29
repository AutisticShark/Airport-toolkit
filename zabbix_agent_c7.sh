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
echo "Zabbix installation script for CentOS 7 x64"

[ $(id -u) != "0" ] && { echo "Error: You must be root to run this script!"; exit 1; }

#Configuration
zabbix_release_40_url = http://repo.zabbix.com/zabbix/4.0/rhel/7/x86_64/zabbix-release-4.0-2.el7.noarch.rpm
zabbix_release_41_url = http://repo.zabbix.com/zabbix/4.1/rhel/7/x86_64/zabbix-release-4.1-1.el7.noarch.rpm
zabbix_release_42_url = http://repo.zabbix.com/zabbix/4.2/rhel/7/x86_64/zabbix-release-4.2-2.el7.noarch.rpm
zabbix_release_43_url = http://repo.zabbix.com/zabbix/4.3/rhel/7/x86_64/zabbix-release-4.3-3.el7.noarch.rpm

while :; do echo
	echo -e "Please select Zabbix agent version you want to install:"
	echo -e "\t1. 4.0"
	echo -e "\t2. 4.1"
    echo -e "\t3. 4.2"
    echo -e "\t4. 4.3"
	read -p "Please input a number:(Default 1 press Enter) " connection_method
	[ -z ${connection_method} ] && connection_method=1
	if [[ ! ${connection_method} =~ ^[1-4]$ ]]; then
		echo "Bad answer! Please only input number 1~4"
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
    sed -i -e "s/Server=127.0.0.1/Server=$zabbix_master_ip/g" -e "s/ServerActive=127.0.0.1/ServerActive=$zabbix_master_ip/g" -e "s/Hostname=Zabbix server/Hostname=$agent_hostname/g" /etc/zabbix/zabbix_agentd.conf
}

do_install_zabbix_agent_40(){
    do_zabbix_agent_configure
    rpm -ivh $zabbix_release_40_url
    yum install zabbix-agent -y
    do_edit_zabbix_agent_config
}

do_install_zabbix_agent_41(){
    do_zabbix_agent_configure
    rpm -ivh $zabbix_release_41_url
    yum install zabbix-agent -y
    do_edit_zabbix_agent_config
}

do_install_zabbix_agent_42(){
    do_zabbix_agent_configure
    rpm -ivh $zabbix_release_42_url
    yum install zabbix-agent -y
    do_edit_zabbix_agent_config
}

do_install_zabbix_agent_43(){
    do_zabbix_agent_configure
    rpm -ivh $zabbix_release_43_url
    yum install zabbix-agent -y
    do_edit_zabbix_agent_config
}