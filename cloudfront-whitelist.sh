#!/bin/bash
mkdir -p /etc/nginx/cloudfront

cloudfront_ip_file=${1:-/etc/nginx/cloudfront/whitelist.conf}
local_ip_list="cloudfront_origin_ips.txt" # Path to your local IP list file

echo "#CloudFront" > $cloudfront_ip_file;
echo "" >> $cloudfront_ip_file;

echo "geo \$realip_remote_addr \$cloudfront_ip {" >> $cloudfront_ip_file;
echo "    default 0;" >> $cloudfront_ip_file;

while IFS= read -r i; do
        echo "    $i 1;" >> $cloudfront_ip_file;
done < "$local_ip_list"

echo "}" >> $cloudfront_ip_file;

nginx -t && systemctl reload nginx
