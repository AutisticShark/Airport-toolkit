#!/usr/bin/env bash
COUNTRY="ir"
IPTABLES=/sbin/iptables
EGREP=/bin/egrep
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
cat << "EOF"
   _____       _      _     __      ________      __ 
  / ___/__  __(_)____(_)___/ /___ _/ / ____/___ _/ /_
  \__ \/ / / / / ___/ / __  / __ `/ / /   / __ `/ __/
 ___/ / /_/ / / /__/ / /_/ / /_/ / / /___/ /_/ / /_  
/____/\__,_/_/\___/_/\__,_/\__,_/_/\____/\__,_/\__/  
                                                     
Author: SuicidalCat
Github: https://github.com/SuicidalCat/Airport-toolkit                                  
EOF
echo "Blocking Iran IP address script"
[ $(id -u) != "0" ] && { echo "Error: You must be root to run this script"; exit 1; }
resetrules() {
$IPTABLES -F
$IPTABLES -t nat -F
$IPTABLES -t mangle -F
$IPTABLES -X
}

resetrules

for c in $COUNTRY
do
        country_file=$c.zone

        IPS=$($EGREP -v "^#|^$" $country_file)
        for ip in $IPS
        do
           echo "blocking $ip"
           $IPTABLES -A INPUT -s $ip -j DROP
        done
done

exit 0