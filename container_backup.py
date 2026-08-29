#!/usr/bin/env python3
import argparse
import hashlib
import os
import platform
import shlex
import shutil
import subprocess
import sys
from datetime import datetime

try:
    from b2sdk.v2.exception import B2Error
    from b2sdk.v2 import B2Api, InMemoryAccountInfo
except ImportError:
    # Handle import error gracefully if B2 SDK is not yet installed
    B2Error = Exception
    B2Api = None
    InMemoryAccountInfo = None

# --- Helper Functions ---

def check_root():
    """Exit if the script is not run as root."""
    if os.geteuid() != 0:
        print("Error: You must be root to run this script!", file=sys.stderr)
        sys.exit(1)

def run_command(command, capture_output=False, text=True, stdout=None, **kwargs):
    """
    Helper to run a subprocess, with better error reporting.
    Exits the script on failure.
    """
    command = [str(c) for c in command]
    print(f"Executing: {' '.join(shlex.quote(c) for c in command)}")
    try:
        result = subprocess.run(
            command,
            check=True,
            capture_output=capture_output,
            text=text,
            stdout=stdout,
            **kwargs
        )
        return result
    except FileNotFoundError:
        print(f"Error: Command '{command[0]}' not found. Is it installed and in your PATH?", file=sys.stderr)
        sys.exit(1)
    except subprocess.CalledProcessError as e:
        print(f"Error running command: {' '.join(command)}", file=sys.stderr)
        if capture_output:
            if e.stdout:
                print(f"STDOUT:\n{e.stdout}", file=sys.stderr)
            if e.stderr:
                print(f"STDERR:\n{e.stderr}", file=sys.stderr)
        sys.exit(e.returncode)

def get_os_name():
    """Detects the OS distribution."""
    if os.path.exists('/etc/redhat-release'):
        return "rhel"
    elif os.path.exists('/etc/debian_version'):
        return "debian"
    else:
        plat = platform.system().lower()
        if "linux" in plat:
            return "debian"
        print("Unknown OS", file=sys.stderr)
        sys.exit(1)

def parse_config(file_path):
    """Parses key="value" config file, supporting multi-line quoted strings and comments."""
    config = {}
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()

        lines = content.splitlines()
        current_key = None
        current_val = []
        in_quote = False
        quote_char = None

        for line in lines:
            stripped = line.strip()
            if not in_quote:
                if not stripped or stripped.startswith('#'):
                    continue
                if '=' in stripped:
                    key, val = stripped.split('=', 1)
                    key = key.strip()
                    val = val.strip()
                    if (val.startswith('"') and not (val.endswith('"') and len(val) > 1 and not val.endswith('\\"'))) or \
                       (val.startswith("'") and not (val.endswith("'") and len(val) > 1 and not val.endswith("\\'"))):
                        in_quote = True
                        quote_char = val[0]
                        current_key = key
                        current_val = [val[1:]]
                    else:
                        config[key] = val.strip('\'"')
                else:
                    print(f"Warning: Skipping malformed line in {file_path}: {line}")
            else:
                if stripped.endswith(quote_char):
                    in_quote = False
                    current_val.append(stripped[:-1])
                    config[current_key] = "\n".join(current_val).strip()
                    current_key = None
                    current_val = []
                    quote_char = None
                else:
                    current_val.append(line)
        if current_key and current_val:
            config[current_key] = "\n".join(current_val).strip()
    except FileNotFoundError:
        print(f"Error: Config file not found at {file_path}", file=sys.stderr)
        sys.exit(1)
    except IOError as e:
        print(f"Error reading config file {file_path}: {e}", file=sys.stderr)
        sys.exit(1)
    return config

def get_container_tasks(config):
    """
    Extracts a list of container backup tasks from config.
    Each task is a dict: {'container_name': str, 'data_locations': [str, ...]}
    """
    tasks = []

    # 1. Check for 'containers' block/list (e.g. "nginx:/path/data1, /path/data2\nmysql:/path/db")
    if 'containers' in config and config['containers']:
        raw_containers = config['containers']
        raw_lines = raw_containers.replace(';', '\n').splitlines()
        for line in raw_lines:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            if ':' in line or '=' in line:
                sep = ':' if ':' in line else '='
                c_name, paths_str = line.split(sep, 1)
                c_name = c_name.strip()
                raw_paths = [p.strip() for p in paths_str.replace(';', ',').split(',') if p.strip()]
                expanded_paths = []
                for p in raw_paths:
                    colon_parts = p.split(':')
                    i = 0
                    while i < len(colon_parts):
                        part = colon_parts[i]
                        # Handle Windows drive letters like C:\ without treating colon as delimiter
                        if len(part) == 1 and part.isalpha() and i + 1 < len(colon_parts) and (colon_parts[i+1].startswith('\\') or colon_parts[i+1].startswith('/')):
                            expanded_paths.append(f"{part}:{colon_parts[i+1]}")
                            i += 2
                        else:
                            if part.strip():
                                expanded_paths.append(part.strip())
                            i += 1
                if c_name and expanded_paths:
                    tasks.append({'container_name': c_name, 'data_locations': expanded_paths})

    # 2. Check for numbered keys: container_1 / container_name_1 and data_location_1 / data_1
    i = 1
    while True:
        c_name = config.get(f'container_name_{i}') or config.get(f'container_{i}')
        d_loc = config.get(f'data_location_{i}') or config.get(f'data_{i}')
        if c_name and d_loc:
            paths = [p.strip() for p in d_loc.replace(';', ',').split(',') if p.strip()]
            tasks.append({'container_name': c_name, 'data_locations': paths})
            i += 1
        else:
            break

    # 3. Check for top-level container_name and data_location
    if not tasks and 'container_name' in config and 'data_location' in config:
        raw_names = [n.strip() for n in config['container_name'].replace(';', ',').split(',') if n.strip()]
        raw_paths = [p.strip() for p in config['data_location'].replace(';', ',').split(',') if p.strip()]

        if len(raw_names) == 1:
            # Single container with one or multiple data locations
            tasks.append({'container_name': raw_names[0], 'data_locations': raw_paths})
        elif len(raw_names) == len(raw_paths):
            # Multiple containers mapped 1:1 to data locations
            for c_name, d_path in zip(raw_names, raw_paths):
                tasks.append({'container_name': c_name, 'data_locations': [d_path]})
        else:
            print(f"Warning: Count mismatch between container_name ({len(raw_names)}) and data_location ({len(raw_paths)}).", file=sys.stderr)

    return tasks

# --- Core Logic Functions ---

def do_init():
    """First time setup for this script."""
    print("--- Starting First Time Setup (init) ---")
    os_name = get_os_name()

    print(f"Detected OS: {os_name}")

    # Install packages
    if os_name == "rhel":
        run_command(["dnf", "update", "-y"])
        run_command(["dnf", "install", "xz", "zip", "python3-pip", "-y"])
    elif os_name == "debian":  # Covers Ubuntu as well
        run_command(["apt", "update", "-y"])
        run_command(["apt", "install", "xz-utils", "zip", "python3-pip", "-y"])

    # Install b2 CLI / SDK
    run_command(["pip3", "install", "b2", "--break-system-packages", "--ignore-installed", "--root-user-action", "ignore"])

    print("--- Initialization Complete ---")

def do_upgrade():
    """Upgrade b2 cli."""
    print("--- Upgrading b2 CLI ---")
    run_command(["pip3", "install", "--upgrade", "b2", "--break-system-packages", "--ignore-installed", "--root-user-action", "ignore"])
    print("--- Upgrade Complete ---")

def do_backup(config_files):
    """Backup container data based on config files."""
    if B2Api is None:
        print("Error: b2 sdk is not installed. Please run 'init' first.", file=sys.stderr)
        sys.exit(1)

    # Change to script's directory to match standard toolkit behavior
    script_path = os.path.dirname(os.path.realpath(__file__))
    os.chdir(script_path)
    print(f"Changed directory to {script_path}")

    for config_file in config_files:
        print(f"\n--- Processing config: {config_file} ---")
        config = parse_config(config_file)

        # Validate essential config keys
        required_keys = [
            'docker_host',
            'b2_app_key_id',
            'b2_app_key',
            'b2_bucket_name',
            'compress_method'
        ]
        missing_keys = [key for key in required_keys if key not in config or not config[key]]
        if missing_keys:
            print(f"Error: Config file {config_file} is missing required keys: {missing_keys}", file=sys.stderr)
            continue

        tasks = get_container_tasks(config)
        if not tasks:
            print(f"Error: No container definitions found in {config_file}. Please specify 'container_name' & 'data_location' or 'containers'.", file=sys.stderr)
            continue

        files_to_upload = []
        for task in tasks:
            c_name = task['container_name']
            d_locs = task['data_locations']
            print(f"\nBacking up container '{c_name}' (paths: {', '.join(d_locs)}) on host '{config['docker_host']}'...")
            packed_files = pack_container_data(config, c_name, d_locs)
            if packed_files:
                files_to_upload.extend(packed_files)

        # Upload all generated files to B2
        if files_to_upload:
            print(f"\nUploading {len(files_to_upload)} files to B2...")
            upload_to_b2(config, files_to_upload)
        else:
            print("No files generated for upload.")

        print(f"--- Finished processing {config_file} ---")

def pack_container_data(config, container_name, data_locations):
    """
    Packs and compresses container data directory/directories or files.
    Returns a list of generated file paths (archive and hash).
    """
    timestamp = datetime.now().strftime('%Y-%m-%d-%H-%M-%S')
    docker_host = config['docker_host']
    compress_method = config['compress_method']

    if compress_method not in ['xz', 'zip']:
        print(f"Error: Unknown compress method '{compress_method}'. Supported methods are 'xz' and 'zip'.", file=sys.stderr)
        return []

    # Validate that at least one data location exists
    valid_paths = []
    for loc in data_locations:
        abs_path = os.path.abspath(loc)
        if os.path.exists(abs_path):
            valid_paths.append(abs_path)
        else:
            print(f"Warning: Container data location '{abs_path}' does not exist, skipping this path.", file=sys.stderr)

    if not valid_paths:
        print(f"Error: None of the specified data locations for container '{container_name}' exist!", file=sys.stderr)
        return []

    base_filename = f"{timestamp}-{docker_host}-{container_name}-data"

    is_all_files = all(os.path.isfile(p) for p in valid_paths)
    if compress_method == 'xz':
        if len(valid_paths) == 1 and is_all_files:
            archive_filename = f"{base_filename}.xz"
        else:
            archive_filename = f"{base_filename}.tar.xz"
    else:  # zip
        archive_filename = f"{base_filename}.zip"

    hash_filename = f"{archive_filename}.sha3"

    try:
        # Step 1: Compress the container data
        print(f"Compressing using {compress_method} for container '{container_name}'...")

        if compress_method == 'xz':
            if len(valid_paths) == 1 and is_all_files:
                with open(archive_filename, 'wb') as f_out:
                    compress_cmd = ["xz", "-c", "-9", valid_paths[0]]
                    run_command(compress_cmd, stdout=f_out)
            else:
                compress_cmd = ["tar", "-cJf", archive_filename]
                for p in valid_paths:
                    p_dir = os.path.dirname(p)
                    b_name = os.path.basename(p)
                    compress_cmd.extend(["-C", p_dir, b_name])
                run_command(compress_cmd)
        elif compress_method == 'zip':
            archive_abs_path = os.path.abspath(archive_filename)
            for p in valid_paths:
                p_dir = os.path.dirname(p)
                b_name = os.path.basename(p)
                compress_cmd = ["zip", "-rqq", archive_abs_path, b_name]
                run_command(compress_cmd, cwd=p_dir)

        # Step 2: Generate SHA3-256 hash
        if shutil.which("openssl"):
            hash_result = run_command(["openssl", "dgst", "-sha3-256", archive_filename], capture_output=True)
            file_hash = hash_result.stdout.split('=')[-1].strip()
        else:
            hasher = hashlib.sha3_256()
            with open(archive_filename, 'rb') as f:
                for chunk in iter(lambda: f.read(65536), b""):
                    hasher.update(chunk)
            file_hash = hasher.hexdigest()

        with open(hash_filename, 'w') as f:
            f.write(file_hash)

        return [archive_filename, hash_filename]

    except Exception as e:
        print(f"Error during packaging for container '{container_name}': {e}", file=sys.stderr)
        if os.path.exists(archive_filename):
            os.remove(archive_filename)
        if os.path.exists(hash_filename):
            os.remove(hash_filename)
        return []

def upload_to_b2(config, files_to_upload):
    """Authorizes and uploads files to B2 using the b2sdk, then cleans them up."""
    print("Initializing and authorizing B2 account...")
    info = InMemoryAccountInfo()
    b2_api = B2Api(info)
    try:
        b2_api.authorize_account("production", config['b2_app_key_id'], config['b2_app_key'])
        bucket = b2_api.get_bucket_by_name(config['b2_bucket_name'])

        for file_path in files_to_upload:
            if os.path.exists(file_path):
                remote_filename = os.path.basename(file_path)
                print(f"Uploading {file_path} to {config['b2_bucket_name']} as {remote_filename}...")
                bucket.upload_local_file(
                    local_file=file_path,
                    file_name=remote_filename,
                )
            else:
                print(f"Warning: File {file_path} not found for upload, skipping.", file=sys.stderr)

        print("Cleaning up local backup files...")
        for file_path in files_to_upload:
            if os.path.exists(file_path):
                os.remove(file_path)

    except (B2Error, OSError) as e:
        print(f"Error during B2 operation or file cleanup: {e}", file=sys.stderr)
        sys.exit(1)

# --- Main Execution ---

def main():
    """Main function to parse arguments and execute commands."""
    if platform.system().lower() != "windows":
        check_root()

    parser = argparse.ArgumentParser(
        description="Python script to backup Docker container data to B2 Cloud Storage.\nUsage:\n  container_backup.py init\n  container_backup.py upgrade\n  container_backup.py backup <config1> [config2 ...]",
        formatter_class=argparse.RawTextHelpFormatter
    )
    subparsers = parser.add_subparsers(dest='command', required=True, help='Available commands')

    parser_init = subparsers.add_parser('init', help='First time setup (installs compression tools and B2 SDK)')
    parser_init.set_defaults(func=do_init)

    parser_upgrade = subparsers.add_parser('upgrade', help='Upgrade B2 CLI / SDK')
    parser_upgrade.set_defaults(func=do_upgrade)

    parser_backup = subparsers.add_parser('backup', help='Run container data backup to B2')
    parser_backup.add_argument('config_files', nargs='+', help='One or more config files to process')
    parser_backup.set_defaults(func=do_backup)

    args = parser.parse_args()

    if args.command == 'backup':
        args.func(args.config_files)
    else:
        args.func()

if __name__ == '__main__':
    main()
