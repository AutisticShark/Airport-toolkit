#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
cat << "EOF"
B2 Cloud Storage Backup script for RHEL 8+
Author: M1Screw
Github: https://github.com/M1Screw/Airport-toolkit
Usage: 
./b2_backup.sh init --> First time setup for this script
./b2_backup.sh backup config1 config2 --> Backup your website & database to B2 Cloud Storage
EOF

[ $(id -u) != "0" ] && { echo "Error: You must be root to run this script!"; exit 1; }

do_init(){
    dnf update -y
    dnf install gzip zip tar -y
    dnf install python3-pip -y
    pip3 install b2
}

do_reset_config(){
    unset backup_name b2_app_key_id b2_app_key b2_bucket_name db_name db_password db_user db_host website_dir compress_method
}

do_pack_db(){
    if [[ ${compress_method} == "gzip" ]]; then
        db_file_sql="$(date +'%Y-%m-%d-%H-%M-%S')-$backup_name.sql"
        db_file_name="$(date +'%Y-%m-%d-%H-%M-%S')-$backup_name-db.gz"
        mysqldump -u $db_user -p$db_password -h $db_host $db_name > $db_file_sql
        gzip -c $db_file_sql > $db_file_name
        rm $db_file_sql
    elif [[ ${compress_method} == "zip" ]]; then
        db_file_sql="$(date +'%Y-%m-%d-%H-%M-%S')-$backup_name.sql"
        db_file_name="$(date +'%Y-%m-%d-%H-%M-%S')-$backup_name-db.zip"
        mysqldump -u $db_user -p$db_password -h $db_host $db_name > $db_file_sql
        zip -r $db_file_name $db_file_sql
        rm $db_file_sql
    else
        echo -n "Unknown compress method"
        exit 1
    fi
}

do_pack_website(){
    if [[ ${compress_method} == "gzip" ]]; then
        website_file_name=$(date +'%Y-%m-%d-%H-%M-%S')-$backup_name-web.tar.gz
        tar -czf $website_file_name $website_dir
    elif [[ ${compress_method} == "zip" ]]; then
        website_file_name=$(date +'%Y-%m-%d-%H-%M-%S')-$backup_name-web.zip
        zip -rqq $website_file_name $website_dir
    else
        echo -n "Unknown compress method"
        exit 1
    fi
}

do_upload_b2(){
    b2 authorize-account $b2_app_key_id $b2_app_key
    b2 upload_file $b2_bucket_name $(pwd)/$website_file_name $website_file_name
    b2 upload_file $b2_bucket_name $(pwd)/$db_file_name $db_file_name
    rm $website_file_name
    rm $db_file_name
}

if [[ $1 == "init" ]]; then
    do_init
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
