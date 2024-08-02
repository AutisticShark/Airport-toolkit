#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
cat << "EOF"
Usage: 
./b2_backup.sh init --> First time setup for this script
./b2_backup.sh upgrade --> Upgrade b2 cli
./b2_backup.sh backup config1 config2 --> Backup your website & database to B2 Cloud Storage
EOF

[ $(id -u) != "0" ] && { echo "Error: You must be root to run this script!"; exit 1; }

do_check_os(){
    if [[ -f /etc/redhat-release ]]; then
        os_name="rhel"
    elif [[ -f /etc/lsb-release ]]; then
        os_name="ubuntu"
    elif [[ -f /etc/debian_version ]]; then
        os_name="debian"
    else
        echo -n "Unknown OS"
        exit 1
    fi
}

do_check_arch(){
    arch=$(arch)

    if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
        arch="x64"
    elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
        arch="arm64"
    else
        echo -n "Unknown arch"
        exit 1
    fi
}


do_init(){
    if [[ ${os_name} == "rhel" ]]; then
        dnf update -y
        dnf install xz zip -y
        dnf install python3-pip -y
    elif [[ ${os_name} == "ubuntu" || ${os_name} == "debian" ]]; then
        apt update -y
        apt install xz-utils zip -y
        apt install python3-pip -y
    fi

    pip3 install b2

    if [[ ${arch} == "x64" ]]; then
        mkdir 7z
        wget https://www.7-zip.org/a/7z2407-linux-x64.tar.xz
        tar -xf 7z2407-linux-x64.tar.xz -C 7z
        mv -f 7z/7zzs /usr/bin/7z
        rm -r 7z2407-linux-x64.tar.xz 7z
    elif [[ ${arch} == "arm64" ]]; then
        mkdir 7z
        wget https://www.7-zip.org/a/7z2407-linux-arm64.tar.xz
        tar -xf 7z2407-linux-arm64.tar.xz -C 7z
        mv -f 7z/7zzs /usr/bin/7z
        rm -r 7z2407-linux-arm64.tar.xz 7z
    fi
}

do_upgrade(){
    pip3 install --upgrade b2
}

do_reset_config(){
    unset backup_name b2_app_key_id b2_app_key b2_bucket_name db_name db_password db_user db_host website_dir compress_method
}

do_pack_db(){
    if [[ ${compress_method} == "7z" ]]; then
        db_file_sql="$(date +'%Y-%m-%d-%H-%M-%S')-$backup_name.sql"
        db_file_name="$(date +'%Y-%m-%d-%H-%M-%S')-$backup_name-db.7z"
        db_file_hash="$(date +'%Y-%m-%d-%H-%M-%S')-$backup_name-db.7z.sha3"
        mariadb-dump -u $db_user -p$db_password -h $db_host $db_name > $db_file_sql
        7z a -mx9 $db_file_name $db_file_sql
        openssl dgst -sha3-256 $db_file_name | awk '{print $2}' > $db_file_hash
        rm $db_file_sql
    elif [[ ${compress_method} == "zip" ]]; then
        db_file_sql="$(date +'%Y-%m-%d-%H-%M-%S')-$backup_name.sql"
        db_file_name="$(date +'%Y-%m-%d-%H-%M-%S')-$backup_name-db.zip"
        db_file_hash="$(date +'%Y-%m-%d-%H-%M-%S')-$backup_name-db.zip.sha3"
        mariadb-dump -u $db_user -p$db_password -h $db_host $db_name > $db_file_sql
        zip -r $db_file_name $db_file_sql
        openssl dgst -sha3-256 $db_file_name | awk '{print $2}' > $db_file_hash
        rm $db_file_sql
    else
        echo -n "Unknown compress method"
        exit 1
    fi
}

do_pack_website(){
    if [[ ${compress_method} == "7z" ]]; then
        website_file_name=$(date +'%Y-%m-%d-%H-%M-%S')-$backup_name-web.7z
        website_file_hash=$(date +'%Y-%m-%d-%H-%M-%S')-$backup_name-web.7z.sha3
        7z a -mx9 $website_file_name $website_dir
        openssl dgst -sha3-256 $website_file_name | awk '{print $2}' > $website_file_hash
    elif [[ ${compress_method} == "zip" ]]; then
        website_file_name=$(date +'%Y-%m-%d-%H-%M-%S')-$backup_name-web.zip
        website_file_hash=$(date +'%Y-%m-%d-%H-%M-%S')-$backup_name-web.zip.sha3
        zip -rqq $website_file_name $website_dir
        openssl dgst -sha3-256 $website_file_name | awk '{print $2}' > $website_file_hash
    else
        echo -n "Unknown compress method"
        exit 1
    fi
}

do_upload_b2(){
    b2 account authorize $b2_app_key_id $b2_app_key
    b2 file upload $b2_bucket_name $(pwd)/$website_file_name $website_file_name
    b2 file upload $b2_bucket_name $(pwd)/$website_file_hash $website_file_hash
    b2 file upload $b2_bucket_name $(pwd)/$db_file_name $db_file_name
    b2 file upload $b2_bucket_name $(pwd)/$db_file_hash $db_file_hash
    rm $website_file_name
    rm $website_file_hash
    rm $db_file_name
    rm $db_file_hash
}

if [[ $1 == "init" ]]; then
    do_check_os
    do_check_arch
    do_init
    exit 0
fi

if [[ $1 == "upgrade" ]]; then
    do_upgrade
    exit 0
fi

if [[ $1 == "backup" ]]; then
    shift
    path="$(dirname $0)"
    cd $path
    for config_file in $@; do
        echo "Reading config file $config_file"
        if test -f $config_file ; then
            . "$config_file"
            echo "Backing up $config_file"
            do_pack_db
            do_pack_website
            do_upload_b2
            do_reset_config
         else
            echo "Error: $config_file not found!"
            continue
        fi
    done
    exit 0
fi
