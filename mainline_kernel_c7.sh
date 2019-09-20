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
echo "Mainline kernel and related packages maintenance script for CentOS 7 x64"
[ $(id -u) != "0" ] && { echo "Error: You must be root to run this script!"; exit 1; }

do_elrepo(){
    echo "Install and configure the elrepo"
    rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
	rpm -Uvh http://www.elrepo.org/elrepo-release-7.0-4.el7.elrepo.noarch.rpm
}

do_kernel(){
    echo "Install mainline kernel"
    yum --enablerepo=elrepo-kernel install kernel-ml -y
    grub2-set-default 0
}

do_headers(){
    echo "Install mainline kernel-headers and clean the default one"
    yum remove kernel-headers -y
    yum --enablerepo=elrepo-kernel install kernel-ml-headers -y
    yum group install "Development Tools" -y
}

do_tools(){
    echo "Install mainline kernel-tools and clean the default one"
    yum remove kernel-tools kernel-tools-libs -y
    yum --enablerepo=elrepo-kernel install kernel-ml-tools kernel-ml-tools-libs -y
}

do_enable_bbr(){
    echo "Enable BBR module"
    modprobe tcp_bbr
    echo "tcp_bbr" | tee --append /etc/modules-load.d/modules.conf
    echo "Configure BBR in sysctl.conf"
    echo "net.core.default_qdisc=fq" | tee --append /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" | tee --append /etc/sysctl.conf
    sysctl -p
}

do_status_check(){
    echo "Current running kernel:"
    uname -r
    echo "BBR module status:"
    lsmod | grep bbr
    echo "BBR system configuration status:"
    sysctl net.ipv4.tcp_available_congestion_control
    sysctl net.ipv4.tcp_congestion_control
    echo "Kernel related rpm packages:"
    rpm -qa | grep kernel
    echo "System booting kernel options:"
    egrep ^menuentry /etc/grub2.cfg | cut -f 2 -d \'
}

do_update_kernel(){
    echo "Upgrade mainline kernel and related packages"
    yum --enablerepo=elrepo-kernel update kernel-ml kernel-ml-headers kernel-ml-tools-libs -y
}

do_reboot(){
    echo "System require a reboot to complete the mainline kernel installation process, press Y to continue, or press any key else to exit this script."
    read is_reboot
    if [[ ${is_reboot} == "y" || ${is_reboot} == "Y" ]]; then
        reboot
    else
        echo "Reboot has been canceled..."
	    exit 0
    fi      
}

if [[ $1 == "status" ]]; then
    do_status_check
    exit 1
fi
if [[ $1 == "bbr" ]]; then
    do_enable_bbr
    exit 1
fi
if [[ $1 == "update" ]]; then
    do_update_kernel
    exit 1
fi
do_elrepo
do_kernel
do_headers
do_tools
do_reboot
