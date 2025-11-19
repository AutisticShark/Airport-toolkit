#!/bin/bash
mkdir -p /etc/nginx/cloudfront

cloudfront_ip_file=${1:-/etc/nginx/cloudfront/realip.conf}
local_ip_list="cloudfront_origin_ips.txt" # Path to your local IP list file

echo "#CloudFront" > $cloudfront_ip_file;
echo "" >> $cloudfront_ip_file;

while IFS= read -r i; do
        echo "set_real_ip_from $i;" >> $cloudfront_ip_file;
done < "$local_ip_list"

echo "" >> $cloudfront_ip_file;
echo "real_ip_header X-Forwarded-For;" >> $cloudfront_ip_file;

nginx -t && systemctl reload nginx
