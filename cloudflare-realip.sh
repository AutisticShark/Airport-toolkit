#!/bin/bash
mkdir -p /etc/nginx/cloudflare

cloudflare_ip_file=${1:-/etc/nginx/cloudflare/realip.conf}
local_ip_list="cloudflare_origin_ips.txt" # Path to your local IP list file

echo "#Cloudflare" > $cloudflare_ip_file;
echo "" >> $cloudflare_ip_file;

while IFS= read -r i; do
        echo "set_real_ip_from $i;" >> $cloudflare_ip_file;
done < "$local_ip_list"

echo "" >> $cloudflare_ip_file;
echo "real_ip_header CF-Connecting-IP;" >> $cloudflare_ip_file;

nginx -t && systemctl reload nginx
