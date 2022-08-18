#!/usr/bin/bash
cat << "EOF"
shadowsocks-mod server installation script for RHEL/Fedora
Author: M1Screw
Github: https://github.com/M1Screw/Airport-toolkit
Usage:
./ssr_node.sh install --> Install shadowsocks-mod server
./ssr_node.sh config --> Configure shadowsocks-mod server
./ssr_node.sh update --> Update shadowsocks-mod server
EOF

[ $(id -u) != "0" ] && { echo "Error: You must be root to run this script!"; exit 1; }

do_install_shadowsocks_server(){
    echo "Detecting CPU Architecture..."
    cpu_arch=$(uname -m)
    if [[ $cpu_arch != "x86_64" && $cpu_arch != "aarch64" ]]
    then
        echo "Error: Unsupported CPU Architecture!"
        exit 1
    fi
    echo "Detecting OS..."
    os_release=$(cat /etc/os-release | grep "^ID=" | awk -F '=' '{print $2}' | tr -d '"')
    os_version=$(cat /etc/os-release | grep "^VERSION_ID=" | awk -F '=' '{print $2}' | tr -d '"')
    if [[ $os_release != "rhel" && $os_release != "centos" && $os_release != "rocky" && $os_release != "fedora" ]]
    then
        echo "Error: Unsupported OS!"
        exit 1
    fi
    if [[ $os_release == "rhel" || $os_release != "centos" || $os_release != "rocky" ]]
    then
        if [[ $os_version != "8"* &&  $os_version != "9"* ]]
        then
            echo "Error: Unsupported OS version!"
            exit 1
        fi
    fi
    if [ $os_release == "fedora" ]
    then
        if [[ $os_version != "34" && $os_version != "35" && $os_version != "36" ]]
        then
            echo "Error: Unsupported OS version!"
            exit 1
        fi
    fi
    echo "Installing dependency && Updating current installed package..."
    dnf update -y
    dnf install wget -y
    echo "Installing DNF repo..."
    if [ $os_release == "fedora" ]
    then
        wget -O /etc/yum.repos.d/sspanel.repo https://mirror.sspanel.org/repo/fedora.repo
    else
        wget -O /etc/yum.repos.d/sspanel.repo https://mirror.sspanel.org/repo/rhel.repo
    fi
    echo "Installing shadowsocks-mod server..."
    dnf install shadowsocks-server -y
}
do_config(){
    read -p "Please input your node id: " node_id
    read -p "Please input your mu key: " mu_key
    read -p "Please input your panel url(https://example.com): " panel_url
    read -p "Please input your mu suffix(zhaoj.in): " mu_suffix
    read -p "Please input your mu regex(%5m%id.%suffix): " mu_regex
    cp /opt/shadowsocks-server/apiconfig.py /opt/shadowsocks-server/userapiconfig.py
    sed -i -e 's/NODE_ID = 0/NODE_ID = $node_id/g' -e 's/example-key/$mu_key/g' -e 's|https://example.com|$panel_url|g' -e 's/zhaoj.in/$mu_suffix/g' -e 's/%5m%id.%suffix/$mu_regex/g' /opt/shadowsocks-server/userapiconfig.py
    systemctl start shadowsocks-server
    systemctl enable shadowsocks-server
}
do_update(){
    os_release=$(cat /etc/os-release | grep "^ID=" | awk -F '=' '{print $2}')
    echo "Updating SSPanel-UIM RPM Repository..."
    if [ $os_release == "fedora" ]
    then
        wget -O /etc/yum.repos.d/sspanel.repo https://mirror.sspanel.org/repo/fedora.repo
    else
        wget -O /etc/yum.repos.d/sspanel.repo https://mirror.sspanel.org/repo/rhel.repo
    fi
    echo "Updating shadowsocks-mod server..."
    dnf update shadowsocks-server -y
}
if [[ $1 == "install" ]]; then
    do_install_shadowsocks_server
    exit 0
fi
if [[ $1 == "config" ]]; then
    do_config
    exit 0
fi
if [[ $1 == "update" ]]; then
    do_update
    exit 0
fi
