#!/bin/bash
mkdir -p /etc/nginx/cloudflare

cloudflare_ip_file=${1:-/etc/nginx/cloudflare/whitelist.conf}
local_ip_list="cloudflare_origin_ips.txt" # Path to your local IP list file

echo "#Cloudflare" > $cloudflare_ip_file;
echo "" >> $cloudflare_ip_file;

echo "geo \$realip_remote_addr \$cloudflare_ip {" >> $cloudflare_ip_file;
echo "    default 0;" >> $cloudflare_ip_file;

while IFS= read -r i; do
        echo "    $i 1;" >> $cloudflare_ip_file;
done < "$local_ip_list"

echo "}" >> $cloudflare_ip_file;

nginx -t && systemctl reload nginx
