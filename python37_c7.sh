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
echo "Python3.7.x installation script for CentOS 7 x64"
#Check if the scripts is run as root
[ $(id -u) != "0" ] && { echo "Error: You must be root to run this script!"; exit 1; }
#Get python3.7 version by user input
echo -n "Please enter the version number of python3.7 you want to install:"
read python37_version
if [[ $python37_version == 3.7.* ]]; then
    echo "Download python source file..."
    wget https://www.python.org/ftp/python/$python37_version/Python-$python37_version.tgz
    if [ ! -f "$python37_version.tgz" ]; then
        echo "Download failed!"
        exit 0
    else
        tar -zxf $python37_version.tgz
#Get server total CPU core number
cpu_core_num = $(cat /proc/cpuinfo | grep processor | wc -l)
echo "Clean yum cache..."
yum clean all && rm -rf /var/cache/yum
echo "Update system software..."
yum update -y
echo "Install compile tool..."
yum install gcc make -y
echo "Install necessary library..."
yum install zlib-devel bzip2-devel openssl-devel ncurses-devel sqlite-devel readline-devel tk-devel libffi-devel -y

