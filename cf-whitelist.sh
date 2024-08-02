#!/bin/bash
cloudflare_ip_file=${1:-/etc/nginx/cloudflare/whitelist}

echo "#Cloudflare" > $cloudflare_ip_file;
echo "" >> $cloudflare_ip_file;

echo "geo \$realip_remote_addr \$cloudflare_ip {" >> $cloudflare_ip_file;
echo "    default          0;" >> $cloudflare_ip_file;

echo "    # - IPv4" >> $cloudflare_ip_file;
for i in `curl -s -L https://www.cloudflare.com/ips-v4`; do
        echo "    $i 1;" >> $cloudflare_ip_file;
done

echo "" >> $cloudflare_ip_file;
echo "    # - IPv6" >> $cloudflare_ip_file;
for i in `curl -s -L https://www.cloudflare.com/ips-v6`; do
        echo "    $i 1;" >> $cloudflare_ip_file;
done

echo "}" >> $cloudflare_ip_file;

nginx -t && systemctl reload nginx
