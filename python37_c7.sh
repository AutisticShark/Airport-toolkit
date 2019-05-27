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
    sleep 1
    if [ ! -e "Python-$python37_version.tgz" ]; then
        echo "Download failed!"
        exit 0
    else
        tar -zxf Python-$python37_version.tgz
        cd Python-$python37_version
    fi
else
    echo "Input error! You should enter version number like 3.7.x"
    exit 0
fi
#Get server total CPU core number
$cpu_core_num = $(cat /proc/cpuinfo | grep processor | wc -l)
echo "Clean yum cache..."
yum clean all && rm -rf /var/cache/yum
echo "Update system software..."
yum update -y
echo "Install compile tool..."
yum install gcc make -y
echo "Install necessary library..."
yum install zlib-devel bzip2-devel openssl-devel ncurses-devel sqlite-devel readline-devel tk-devel libffi-devel -y
echo "Start installation process..."
./configure prefix=/usr/local/python3 --enable-optimizations
make -j$cpu_core_num && make install
echo "Remove default python soft link..."
\rm /usr/bin/python
echo "Remove default python-pip soft link..."
\rm /usr/bin/pip
echo "Add python3.7 as system default python version..."
ln -s /usr/local/python3/bin/python3.7 /usr/bin/python
echo "Add pip3.7 as system default python-pip version..."
ln -s /usr/local/python3/bin/pip3.7 /usr/bin/pip
echo "Replace yum and related configuration to avoid fatal error..."
sed -i -e "s%#!/usr/bin/python%#!/usr/bin/python2%g" /usr/bin/yum