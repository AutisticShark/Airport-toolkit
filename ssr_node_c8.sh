#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
cat << "EOF"
Author: M1Screw
Github: https://github.com/M1Screw/Airport-toolkit                                 
EOF
echo "Shadowsocksr server installation script for CentOS Stream 8 x64"
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
    --is_mu)
      is_mu=y; shift 1
      ;;
    --webapi_url)
      webapi_url=$2; shift 2
      ;;
    --webapi_token)
      webapi_token=$2; shift 2
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
echo "Checking if there is any existing shadowsocksr server installation..."
if [ -d "/soft/shadowsocks" ]; then
	while :; do echo
		echo -n "Detect exist shadowsocksr server installation! If you continue this install, all the previous configuration will be lost! Continue?(Y/N)"
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
echo "Configurating EPEL release..."
dnf install epel-release -y && dnf makecache
echo "Install necessary package..."
dnf install python3 python3-pip git htop chrony -y
echo "Disabling firewalld..."
systemctl stop firewalld && systemctl disable firewalld
echo "Setting system timezone..."
timedatectl set-timezone Asia/Taipei && systemctl enable chronyd && systemctl start chronyd
echo "Installing libsodium..."
dnf install libsodium -y
mkdir /soft
echo "Installing Shadowsocksr server from GitHub..."	
cd /tmp && git clone -b manyuser https://github.com/Anankke/shadowsocks-mod.git
mv shadowsocks-mod shadowsocks
mv -f shadowsocks /soft
cd /soft/shadowsocks
pip3 install --upgrade pip setuptools
pip install -r requirements.txt
echo "Generating config file..."
cp apiconfig.py userapiconfig.py
cp config.json user-config.json
if [[ ${is_auto} != "y" ]]; then
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
	sed -i -e "s/MU_SUFFIX = 'zhaoj.in'/MU_SUFFIX = '${mu_suffix}'/g" -e "s/MU_REGEX = '%5m%id.%suffix'/MU_REGEX = '${mu_regex}'/g" userapiconfig.py
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
	sed -i -e "s/NODE_ID = 0/NODE_ID = ${node_id}/g" -e "s%WEBAPI_URL = 'https://demo.sspanel.host'%WEBAPI_URL = '${webapi_url}'%g" -e "s/WEBAPI_TOKEN = 'sspanel'/WEBAPI_TOKEN = '${webapi_token}'/g" userapiconfig.py
}
do_modwebapi
do_service(){
	echo "Writting system config..."
	wget --no-check-certificate -O ssr_node.service https://raw.githubusercontent.com/Toxic-Cat/Airport-toolkit/master/ssr_node.service.el8
	chmod 664 ssr_node.service && mv ssr_node.service /etc/systemd/system
	echo "Starting SSR Node Service..."
	systemctl daemon-reload && systemctl enable ssr_node && systemctl start ssr_node
}
while :; do echo
	echo -n "Do you want to register SSR Node as system service?(Y/N)"
	read is_service
	if [[ ${is_service} != "y" && ${is_service} != "Y" && ${is_service} != "N" && ${is_service} != "n" ]]; then
		echo -n "Bad answer! Please only input number Y or N"
	else
		break
	fi
done
if [[ ${is_service} == "y" || ${is_service} == "Y" ]]; then
	do_service
fi
echo "System require a reboot to complete the installation process, press Y to continue, or press any key else to exit this script."
read is_reboot
if [[ ${is_reboot} == "y" || ${is_reboot} == "Y" ]]; then
  reboot
else
  echo -e "Reboot has been canceled..."
	exit 0
fi
