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
echo "Shadowsocksr server installation script for Ubuntu 18.04 x64"
[ $(id -u) != "0" ] && { echo "Error: You must be root to run this script!"; exit 1; }
ARG_NUM=$#
TEMP=`getopt -o hvV --long is_auto:,connection_method:,is_mu:,webapi_url:,webapi_token:,db_ip:,db_name:,db_user:,db_password:,node_id:-- "$@" 2>/dev/null`
[ $? != 0 ] && echo "ERROR: unknown argument!" && exit 1
eval set -- "${TEMP}"
while :; do
  [ -z "$1" ] && break;
  case "$1" in
	--is_auto)
      is_auto=y; shift 1
      [ -d "/soft/shadowsocks" ] && { echo "Shadowsocksr server software is already exist"; exit 1; }
      ;;
    --connection_method)
      connection_method=$2; shift 2
      [[ ! ${connection_method} =~ ^[1-2]$ ]] && { echo "Bad answer! Please only input number 1~2"; exit 1; }
      ;;
    --is_mu)
      is_mu=y; shift 1
      ;;
    --webapi_url)
      webapi_url=$2; shift 2
      ;;
    --webapi_token)
      webapi_token=$2; shift 2
      ;;
    --db_ip)
      db_ip=$2; shift 2
      ;;
    --db_name)
      db_name=$2; shift 2
      ;;
    --db_user)
      db_user=$2; shift 2
      ;;
    --db_password)
      db_password=$2; shift 2
      ;;
    --node_id)
      node_id=$2; shift 2
      ;;
    --)
      shift
      ;;
    *)
      echo "ERROR: unknown argument!" && exit 1
      ;;
  esac
done
if [[ ${is_auto} != "y" ]]; then
	echo "Press Y for continue the installation process, or press any key else to exit."
	read is_install
	if [[ ${is_install} != "y" && ${is_install} != "Y" ]]; then
    	echo -e "Installation has been canceled..."
    	exit 0
	fi
fi
echo "Checking the universe repository configuration..."
apt install software-properties-common && apt-add-repository universe
echo "Updating exsit package..."
apt clean all && apt autoremove -y && apt update && apt upgrade -y && apt dist-upgrade -y
echo "Installing necessary package..."
apt install git python python-setuptools python-pip build-essential ntpdate htop -y
echo "Please select correct system timezone for your node."
dpkg-reconfigure tzdata
echo "Installing libsodium..."
wget https://codeload.github.com/jedisct1/libsodium/tar.gz/1.0.18-RELEASE
tar xf 1.0.18-RELEASE && cd libsodium-1.0.18-RELEASE
./configure && make -j2 && make install
echo /usr/local/lib > /etc/ld.so.conf.d/usr_local_lib.conf
ldconfig
cd ../ && rm -rf libsodium* 1.0.18*
if [ ! -d "/soft" ]; then
	mkdir /soft
else
	echo "/soft directory is already exist..."
fi
cd /soft
echo "Checking if there any exist Shadowsocksr server software..."
if [ ! -d "shadowsocks" ]; then
	echo "Installing Shadowsocksr server from GitHub..."
	cd /tmp && git clone -b manyuser https://github.com/NimaQu/shadowsocks.git
	mv -f shadowsocks /soft
else
	while :; do echo
		echo -n "The Shadowsocksr server software is already exsit! Do you want to upgrade it?(Y/N)"
		read is_mu
		if [[ ${is_mu} != "y" && ${is_mu} != "Y" && ${is_mu} != "N" && ${is_mu} != "n" ]]; then
			echo -n "Bad answer! Please only input number Y or N"
		elif [[ ${is_mu} == "y" && ${is_mu} == "Y" ]]; then
			echo "Upgrading Shadowsocksr server software..."
			cd shadowsocks && git pull
			break
		else
			exit 0
		fi
	done
fi
cd /soft/shadowsocks
python -m pip install --upgrade pip setuptools
python -m pip install -r requirements.txt
echo "Generating config file..."
cp apiconfig.py userapiconfig.py
cp config.json user-config.json
if [[ ${is_auto} != "y" ]]; then
	#Choose the connection method
	while :; do echo
		echo -e "Please select the way your node server connection method:"
		echo -e "\t1. WebAPI"
		echo -e "\t2. Remote Database"
		read -p "Please input a number:(Default 2 press Enter) " connection_method
		[ -z ${connection_method} ] && connection_method=2
		if [[ ! ${connection_method} =~ ^[1-2]$ ]]; then
			echo "Bad answer! Please only input number 1~2"
		else
			break
		fi			
	done
	while :; do echo
		echo -n "Do you want to enable multi user in single port feature?(Y/N)"
		read is_mu
		if [[ ${is_mu} != "y" && ${is_mu} != "Y" && ${is_mu} != "N" && ${is_mu} != "n" ]]; then
			echo -n "Bad answer! Please only input number Y or N"
		else
			break
		fi
	done
fi
do_mu(){
	if [[ ${is_auto} != "y" ]]; then
		echo -n "Please enter MU_SUFFIX:"
		read mu_suffix
		echo -n "Please enter MU_REGEX:"
		read mu_regex
		echo "Writting MU config..."
	fi
	sed -i -e "s/MU_SUFFIX = 'zhaoj.in'/MU_SUFFIX = '${mu_suffix}'/g" -e "s/MU_REGEX = 'zhaoj.in'/MU_REGEX = '${mu_regex}'/g" userapiconfig.py
}
do_modwebapi(){
	if [[ ${is_auto} != "y" ]]; then
		echo -n "Please enter WebAPI url:"
		read webapi_url
		echo -n "Please enter WebAPI token:"
		read webapi_token
		echo -n "Server node ID:"
		read node_id
	fi
	if [[ ${is_mu} == "y" || ${is_mu} == "Y" ]]; then
		do_mu
	fi
	echo "Writting connection config..."
	sed -i -e "s/NODE_ID = 0/NODE_ID = ${node_id}/g" -e "s%WEBAPI_URL = 'https://zhaoj.in'%WEBAPI_URL = '${webapi_url}'%g" -e "s/WEBAPI_TOKEN = 'glzjin'/WEBAPI_TOKEN = '${webapi_token}'/g" userapiconfig.py
}
do_glzjinmod(){
	if [[ ${is_auto} != "y" ]]; then
		sed -i -e "s/'modwebapi'/'glzjinmod'/g" userapiconfig.py
		echo -n "Please enter DB server's IP address:"
		read db_ip
		echo -n "DB name:"
		read db_name
		echo -n "DB username:"
		read db_user
		echo -n "DB password:"
		read db_password
		echo -n "Server node ID:"
		read node_id
	fi
	if [[ ${is_mu} == "y" || ${is_mu} == "Y" ]]; then
		do_mu
	fi
	echo "Writting connection config..."
	sed -i -e "s/NODE_ID = 0/NODE_ID = ${node_id}/g" -e "s/MYSQL_HOST = '127.0.0.1'/MYSQL_HOST = '${db_ip}'/g" -e "s/MYSQL_USER = 'ss'/MYSQL_USER = '${db_user}'/g" -e "s/MYSQL_PASS = 'ss'/MYSQL_PASS = '${db_password}'/g" -e "s/MYSQL_DB = 'shadowsocks'/MYSQL_DB = '${db_name}'/g" userapiconfig.py
}
if [[ ${is_auto} != "y" ]]; then
	#Do the configuration
	if [ "${connection_method}" == '1' ]; then
		do_modwebapi
	elif [ "${connection_method}" == '2' ]; then
		do_glzjinmod
	fi
fi
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
do_service(){
	echo "Writting system config..."
	wget https://raw.githubusercontent.com/SuicidalCat/Airport-toolkit/master/ssr_node.service
	chmod 754 ssr_node.service && mv ssr_node.service /etc/systemd/system
	echo "Starting SSR Node Service..."
	systemctl enable ssr_node && systemctl start ssr_node
}
while :; do echo
	echo -n "Do you want to enable BBR feature(from mainline kernel) and optimizate the system?(Y/N)"
	read is_bbr
	if [[ ${is_bbr} != "y" && ${is_bbr} != "Y" && ${is_bbr} != "N" && ${is_bbr} != "n" ]]; then
		echo -n "Bad answer! Please only input number Y or N"
	else
		break
	fi
done
while :; do echo
	echo -n "Do you want to register SSR Node as system service?(Y/N)"
	read is_service
	if [[ ${is_service} != "y" && ${is_service} != "Y" && ${is_service} != "N" && ${is_service} != "n" ]]; then
		echo -n "Bad answer! Please only input number Y or N"
	else
		break
	fi
done
if [[ ${is_bbr} == "y" || ${is_bbr} == "Y" ]]; then
	do_bbr
fi
if [[ ${is_service} == "y" || ${is_service} == "Y" ]]; then
	do_service
fi
echo "Installation complete, please run python /soft/shadowsocks/server.py to test."
