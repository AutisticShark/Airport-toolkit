#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

[ $(id -u) != "0" ] && { echo "Error: You must be root to run this script!"; exit 1; }

#Check kernel version
kernel_version_full=$(uname -r)
kernel_version_numbers=${kernel_version_full%%[-+]*}
IFS='.' read -r version1 version2 version3 <<< "$kernel_version_numbers"

if [[ "$version1" -lt 4 || ("$version1" -eq 4 && "$version2" -lt 9) ]]; then
    echo -e "Kernel version $kernel_version_full is lower than 4.9 [\033[0;31m✗\033[0m]"
    exit 1
else
    echo -e "Kernel version $kernel_version_full is higher or equal to 4.9 [\033[0;32m✓\033[0m]"
fi

if [[ -f /etc/sysctl.d/bbr.conf ]]; then
    echo -e "bbr.sh script has already been configured [\033[0;32m✓\033[0m]"
    exit 0
else
    echo -e "/etc/sysctl.d/bbr.conf has been created [\033[0;32m✓\033[0m]"
    touch /etc/sysctl.d/bbr.conf
fi

default_qdisc=$(sysctl net.core.default_qdisc)

if [[ $default_qdisc != "cake" ]]; then
    echo "net.core.default_qdisc = cake" >> /etc/sysctl.d/bbr.conf
    sysctl --system &> /dev/null
fi

tcp_congestion_control=$(sysctl net.ipv4.tcp_congestion_control)

if [[ $tcp_congestion_control != "bbr" ]]; then
    echo "net.ipv4.tcp_congestion_control = bbr" >> /etc/sysctl.d/bbr.conf
    sysctl --system &> /dev/null
fi

echo -e "Successfully configured \033[0;32mbbr\033[0m as tcp congestion control and \033[0;32mcake\033[0m as default queuing discipline [\033[0;32m✓\033[0m]"
exit 0
