#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
cat << "EOF"
Usage: 
./pve_backup.sh init --> First time setup for this script
./pve_backup.sh upgrade --> Upgrade b2 cli
./pve_backup.sh backup --> Sync Proxmox VM Backups to B2 Cloud Storage
EOF

[ $(id -u) != "0" ] && { echo "Error: You must be root to run this script!"; exit 1; }

# Config
b2_app_key_id=""
b2_app_key=""
# Use b2://your-bucket-name/ as bucket name
b2_bucket_name=""

do_init(){
    apt update -y
    apt install python3-pip -y
    pip3 install b2 --break-system-packages
}

do_upgrade(){
    pip3 install --upgrade b2 --break-system-packages
}

do_upload_b2(){
    b2 account authorize $b2_app_key_id $b2_app_key
    b2 sync --delete /var/lib/vz/dump/* $b2_bucket_name
}

if [[ $1 == "init" ]]; then
    do_init
    exit 0
fi

if [[ $1 == "upgrade" ]]; then
    do_upgrade
    exit 0
fi

if [[ $1 == "backup" ]]; then
    do_upload_b2
    exit 0
fi
