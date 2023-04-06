#!/usr/bin/bash
cat << "EOF"
TrojanX server installation script for RHEL/Fedora
Author: M1Screw
Github: https://github.com/M1Screw/Airport-toolkit
Usage:
./trojan_node.sh install --> Install TrojanX server
./trojan_node.sh config --> Configure TrojanX server
./trojan_node.sh update --> Update TrojanX server
./trojan_node.sh uninstall --> Uninstall TrojanX server
EOF

[ $(id -u) != "0" ] && { echo "Error: You must be root to run this script!"; exit 1; }

do_install_trojan_server(){
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
    echo "Installing TrojanX server..."
    dnf install trojan-server -y
}
do_install_acme(){
    read -p "Please input your email: " email
    echo "Installing acme.sh..."
    wget -O -  https://get.acme.sh | sh -s email=$email
}
do_config(){
    read -p "Please input your node port(443): " node_port
    read -p "Please input your node id: " node_id
    read -p "Please input your mu key: " mu_key
    read -p "Please input your panel url(https://example.com/mod_mu): " panel_url
    while :; do echo
	    echo -e "Please select your cert mode:"
	    echo -e "\t1. Manual"
	    echo -e "\t2. Auto - Cloudflare DNS"
        echo -e "\t3. Auto - Amazon Route53 DNS"
        echo -e "\t4. Auto - DNSPod DNS"
        echo -e "\t5. Auto - Aliyun DNS"
	    read -p "Please input a number:(Default 2 press Enter) " cert_mode
	    [ -z ${cert_mode} ] && cert_mode=2
	    if [[ ! ${cert_mode} =~ ^[1-5]$ ]]; then
		    echo "Bad answer! Please only input number 1~5"
	    else
		    if [[ ${cert_mode} == 1 ]]; then
                read -p "Please input your domain name: " domain
                read -p "Please input your cert path(/path/to/fullchain_cert.pem): " cert_path
                read -p "Please input your key path(/path/to/cert.key): " key_path
                cp $cert_path /etc/trojan-server/cert.pem
                cp $key_path /etc/trojan-server/cert.key
                break
            elif [[ ${cert_mode} == 2 ]]; then
                read -p "Please input your domain name: " domain
                read -p "Please input your Cloudflare key: " cf_key
                read -p "Please input your Cloudflare email: " cf_email
                CF_Key=$cf_key CF_Email=$cf_email ~/.acme.sh/acme.sh --issue --dns dns_cf -d $domain
                ~/.acme.sh/acme.sh --install-cert -d $domain --key-file /etc/trojan-server/cert.key --fullchain-file /etc/trojan-server/cert.pem
                ~/.acme.sh/acme.sh --to-pkcs8 -d $domain
                cat /root/.acme.sh/${domain}_ecc/$domain.pkcs8 > /etc/trojan-server/cert.key
                break
            elif [[ ${cert_mode} == 3 ]]; then
                read -p "Please input your domain name: " domain
                read -p "Please input your Amazon Route53 access key id: " route53_key_id
                read -p "Please input your Amazon Route53 access key: " route53_key
                AWS_ACCESS_KEY_ID=$route53_key_id AWS_SECRET_ACCESS_KEY=$route53_key ~/.acme.sh/acme.sh --issue --dns dns_aws -d $domain
                ~/.acme.sh/acme.sh --install-cert -d $domain --key-file /etc/trojan-server/cert.key --fullchain-file /etc/trojan-server/cert.pem
                ~/.acme.sh/acme.sh --to-pkcs8 -d $domain
                cat /root/.acme.sh/${domain}_ecc/$domain.pkcs8 > /etc/trojan-server/cert.key
                break
            elif [[ ${cert_mode} == 4 ]]; then
                read -p "Please input your domain name: " domain
                read -p "Please input your DNSPod id: " dnspod_id
                read -p "Please input your DNSPod key: " dnspod_key
                DP_Id=$dnspod_id DP_Key=$dnspod_key bash ~/.acme.sh/acme.sh --issue --dns dns_dp -d $domain
                ~/.acme.sh/acme.sh --install-cert -d $domain --key-file /etc/trojan-server/cert.key --fullchain-file /etc/trojan-server/cert.pem
                ~/.acme.sh/acme.sh --to-pkcs8 -d $domain
                cat /root/.acme.sh/${domain}_ecc/$domain.pkcs8 > /etc/trojan-server/cert.key
                break
            elif [[ ${cert_mode} == 5 ]]; then
                read -p "Please input your domain name: " domain
                read -p "Please input your Aliyun key: " aliyun_key
                read -p "Please input your Aliyun secret: " aliyun_secret
                Ali_Key=$aliyun_key Ali_Secret=$aliyun_secret ~/.acme.sh/acme.sh --issue --dns dns_ali -d $domain
                ~/.acme.sh/acme.sh --install-cert -d $domain --key-file /etc/trojan-server/cert.key --fullchain-file /etc/trojan-server/cert.pem
                ~/.acme.sh/acme.sh --to-pkcs8 -d $domain
                cat /root/.acme.sh/${domain}_ecc/$domain.pkcs8 > /etc/trojan-server/cert.key
                break
            fi
	    fi			
    done
    sed -i -e "s/0.0.0.0:443/0.0.0.0:$node_port/g" \
    -e 's/"id": 1/"id": '"$node_id"'/g' \
    -e "s/example-key/$mu_key/g" \
    -e "s|https://example.com/mod_mu|$panel_url|g" \
    -e 's/"example.com":/"'"$domain"'":/g' \
    -e "s/example.pem/cert.pem/g" \
    -e "s/example.key/cert.key/g" \
    /etc/trojan-server/sspanel.json
    systemctl start trojan-server
    systemctl enable trojan-server
}
do_uninstall_trojan_server(){
    systemctl stop trojan-server
    systemctl disable trojan-server
    dnf remove trojan-server -y
    dnf clean all
    rm -rf /etc/trojan-server
    rm -rf /etc/yum.repos.d/sspanel.repo
}
do_uninstall_acme(){
    ~/.acme.sh/acme.sh --uninstall
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
    echo "Updating TrojanX server..."
    dnf update trojan-server -y
    echo "Updating acme.sh..."
    ~/.acme.sh/acme.sh --upgrade
}
if [[ $1 == "install" ]]; then
    do_install_trojan_server
    do_install_acme
    exit 0
fi
if [[ $1 == "uninstall" ]]; then
    do_uninstall_trojan_server
    do_uninstall_acme
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
