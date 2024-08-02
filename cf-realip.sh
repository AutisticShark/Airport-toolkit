#!/bin/bash
cloudflare_ip_file=${1:-/etc/nginx/cloudflare/realip}

echo "#Cloudflare" > $cloudflare_ip_file;
echo "" >> $cloudflare_ip_file;

echo "# - IPv4" >> $cloudflare_ip_file;
for i in `curl -s -L https://www.cloudflare.com/ips-v4`; do
        echo "set_real_ip_from $i;" >> $cloudflare_ip_file;
done

echo "" >> $cloudflare_ip_file;
echo "# - IPv6" >> $cloudflare_ip_file;
for i in `curl -s -L https://www.cloudflare.com/ips-v6`; do
        echo "set_real_ip_from $i;" >> $cloudflare_ip_file;
done

echo "" >> $cloudflare_ip_file;
echo "real_ip_header CF-Connecting-IP;" >> $cloudflare_ip_file;

nginx -t && systemctl reload nginx
