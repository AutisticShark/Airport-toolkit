import json
import requests
import argparse

def extract_cdn_ips(cdn_type, output_txt_path):
    """
    Extracts IP prefixes for a specified CDN service (CloudFront or Cloudflare)
    and writes them to a text file.

    Args:
        cdn_type (str): The type of CDN ('cloudfront' or 'cloudflare').
        output_txt_path (str): The path for the output text file.
    """
    try:
        if cdn_type == 'cloudfront':
            json_url = 'https://ip-ranges.amazonaws.com/ip-ranges.json'

            print(f"Downloading IP ranges from {json_url}")
            response = requests.get(json_url)
            response.raise_for_status()  # Raise an HTTPError for bad responses (4xx or 5xx)
            data = response.json()
            
            ip_prefixes = []
            # Extract IPv4 prefixes
            if 'prefixes' in data:
                for prefix in data['prefixes']:
                    if prefix.get('service') == 'CLOUDFRONT':
                        ip_prefixes.append(prefix['ip_prefix'])

            # Extract IPv6 prefixes
            if 'ipv6_prefixes' in data:
                for prefix in data['ipv6_prefixes']:
                    if prefix.get('service') == 'CLOUDFRONT':
                        ip_prefixes.append(prefix['ipv6_prefix'])

        elif cdn_type == 'cloudfront-origin-shield':
            json_url = 'https://ip-ranges.amazonaws.com/ip-ranges.json'

            print(f"Downloading IP ranges from {json_url}")
            response = requests.get(json_url)
            response.raise_for_status()  # Raise an HTTPError for bad responses (4xx or 5xx)
            data = response.json()
            
            ip_prefixes = []
            # Extract IPv4 prefixes
            if 'prefixes' in data:
                for prefix in data['prefixes']:
                    if prefix.get('service') == 'CLOUDFRONT_ORIGIN_FACING':
                        ip_prefixes.append(prefix['ip_prefix'])

            # Extract IPv6 prefixes
            if 'ipv6_prefixes' in data:
                for prefix in data['ipv6_prefixes']:
                    if prefix.get('service') == 'CLOUDFRONT_ORIGIN_FACING':
                        ip_prefixes.append(prefix['ipv6_prefix'])

        elif cdn_type == 'cloudflare':
            ipv4_url = "https://www.cloudflare.com/ips-v4"
            ipv6_url = "https://www.cloudflare.com/ips-v6"

            print(f"Downloading IPv4 ranges from {ipv4_url}")
            ipv4_response = requests.get(ipv4_url)
            ipv4_response.raise_for_status()
            ipv4_prefixes = ipv4_response.text.strip().split('\n')

            print(f"Downloading IPv6 ranges from {ipv6_url}")
            ipv6_response = requests.get(ipv6_url)
            ipv6_response.raise_for_status()
            ipv6_prefixes = ipv6_response.text.strip().split('\n')

            ip_prefixes = ipv4_prefixes + ipv6_prefixes
        else:
            print(f"Error: Unknown CDN type '{cdn_type}'. Supported types are 'cloudfront', 'cloudfront-origin-shield' and 'cloudflare'.")
            return

    except requests.exceptions.RequestException as e:
        print(f"Error: Could not download JSON from {json_url}. {e}")
        return
    except FileNotFoundError:
        print(f"Error: File not found. This should not happen with direct URL downloads.")
        return
    except json.JSONDecodeError as e:
        print(f"Error: Could not decode JSON from the URL. {e}")
        return

    # Write the extracted IPs to the output file
    with open(output_txt_path, 'w') as f:
        for ip in ip_prefixes:
            f.write(f"{ip}\n")

    print(f"Successfully extracted {len(ip_prefixes)} {cdn_type} IP prefixes to {output_txt_path}")

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Download and extract CDN IP ranges.")
    parser.add_argument('--cdn',
                        choices=['cloudfront', 'cloudflare'],
                        required=True,
                        help="Specify the CDN provider to download IP ranges for.")
    parser.add_argument('--output',
                        default=None,
                        help="Optional: Specify the output text file name. Defaults to '<cdn_type>_origin_ips.txt'.")

    args = parser.parse_args()

    if args.output:
        output_file_name = args.output
    else:
        output_file_name = f"{args.cdn}_origin_ips.txt"

    extract_cdn_ips(args.cdn, output_file_name)
