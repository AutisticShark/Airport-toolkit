#!/usr/bin/env python3
import argparse
import os
import platform
import shlex
import subprocess
import sys
from datetime import datetime

from b2sdk.v2.exception import B2Error
from b2sdk.v2 import B2Api, InMemoryAccountInfo

# --- Helper Functions ---

def check_root():
    """Exit if the script is not run as root."""
    if os.geteuid() != 0:
        print("Error: You must be root to run this script!", file=sys.stderr)
        sys.exit(1)

def run_command(command, capture_output=False, text=True, **kwargs):
    """
    Helper to run a subprocess, with better error reporting.
    Exits the script on failure.
    """
    # Ensure all parts of the command are strings
    command = [str(c) for c in command]
    print(f"Executing: {' '.join(shlex.quote(c) for c in command)}")
    try:
        result = subprocess.run(
            command,
            check=True,
            capture_output=capture_output,
            text=text,
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
    # Check for debian/ubuntu variants
    elif os.path.exists('/etc/debian_version'):
        return "debian"
    else:
        print("Unknown OS", file=sys.stderr)
        sys.exit(1)

def get_arch():
    """Detects the system architecture."""
    arch = platform.machine()
    if arch in ("x86_64", "x64", "amd64"):
        return "x64"
    elif arch in ("aarch64", "arm64"):
        return "arm64"
    else:
        print(f"Unknown or unsupported architecture: {arch}", file=sys.stderr)
        sys.exit(1)

def parse_config(file_path):
    """Parses the simple key="value" config file."""
    config = {}
    try:
        with open(file_path, 'r') as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith('#'):
                    continue
                try:
                    key, value = line.split('=', 1)
                    # Strip whitespace and quotes from value
                    value = value.strip().strip('"\'')
                    config[key.strip()] = value
                except ValueError:
                    print(f"Warning: Skipping malformed line in {file_path}: {line}")
                    continue
    except FileNotFoundError:
        print(f"Error: Config file not found at {file_path}", file=sys.stderr)
        sys.exit(1)
    except IOError as e:
        print(f"Error reading config file {file_path}: {e}", file=sys.stderr)
        sys.exit(1)
    return config

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
    elif os_name == "debian": # Covers Ubuntu as well
        run_command(["apt", "update", "-y"])
        run_command(["apt", "install", "xz-utils", "zip", "python3-pip", "-y"])

    # Install b2 CLI
    run_command(["pip3", "install", "b2", "--break-system-packages", "--root-user-action"])
    
    print("--- Initialization Complete ---")


def do_upgrade():
    """Upgrade b2 cli."""
    print("--- Upgrading b2 CLI ---")
    run_command(["pip3", "install", "--upgrade", "b2", "--break-system-packages", "--root-user-action"])
    print("--- Upgrade Complete ---")


def do_backup(config_files, target='all'):
    """Backup websites & databases based on config files."""
    # Change to script's directory to match shell script behavior
    script_path = os.path.dirname(os.path.realpath(__file__))
    os.chdir(script_path)
    print(f"Changed directory to {script_path}")

    for config_file in config_files:
        print(f"\n--- Processing config: {config_file} ---")
        config = parse_config(config_file)
        
        # Validate essential config keys
        required_keys = ['backup_name', 'b2_app_key_id', 'b2_app_key', 'b2_bucket_name', 'compress_method']
        if not all(key in config for key in required_keys):
            print(f"Error: Config file {config_file} is missing one or more required keys: {required_keys}", file=sys.stderr)
            continue

        files_to_upload = []
        
        # 1. Pack Database
        if target in ['all', 'db']:
            if all(key in config and config[key] for key in ['db_name', 'db_user', 'db_host']):
                print("Backing up database...")
                db_files = pack_item(config, 'db')
                if db_files:
                    files_to_upload.extend(db_files)
            else:
                print("Skipping database backup (db config missing or incomplete).")

        # 2. Pack Website
        if target in ['all', 'web']:
            if 'website_dir' in config and config['website_dir']:
                print("Backing up website...")
                web_files = pack_item(config, 'web')
                if web_files:
                    files_to_upload.extend(web_files)
            else:
                print("Skipping website backup (website_dir not set).")
        
        # 3. Upload to B2
        if files_to_upload:
            print("Uploading files to B2...")
            upload_to_b2(config, files_to_upload)
        else:
            print("No files to upload.")

        print(f"--- Finished processing {config_file} ---")


def pack_item(config, item_type):
    """
    Generic packing function for database ('db') or website ('web').
    Returns a list of generated file paths (archive and hash).
    """
    timestamp = datetime.now().strftime('%Y-%m-%d-%H-%M-%S')
    backup_name = config['backup_name']
    compress_method = config['compress_method']
    
    if compress_method not in ['xz', 'zip']:
        print(f"Error: Unknown compress method '{compress_method}'. Supported methods are 'xz' and 'zip'.", file=sys.stderr)
        return []

    base_filename = f"{timestamp}-{backup_name}-{item_type}"
    
    # Determine archive filename based on compression method
    if compress_method == 'xz':
        # For websites, we create a tarball, so .tar.xz is conventional
        if item_type == 'web':
            archive_filename = f"{base_filename}.tar.xz"
        else: # For db, it's a single sql file
            archive_filename = f"{base_filename}.sql.xz"
    else: # zip
        archive_filename = f"{base_filename}.zip"

    hash_filename = f"{archive_filename}.sha3"
    
    source_path = None
    try:
        # Step 1: Create source data (dump for DB, use dir for web)
        if item_type == 'db':
            source_path = f"{timestamp}-{backup_name}.sql"
            db_password = config.get('db_password', '')
            dump_cmd = ["mariadb-dump", "-u", config['db_user'], f"-p{db_password}", "-h", config['db_host'], config['db_name']]
            with open(source_path, 'w') as f:
                run_command(dump_cmd, stdout=f)
        elif item_type == 'web':
            source_path = config['website_dir']

        # Step 2: Compress the data
        print(f"Compressing using {compress_method}...")
        if compress_method == 'xz':
            if item_type == 'web':
                # To avoid storing full paths in the tar, change dir to the parent of the source
                parent_dir = os.path.dirname(os.path.abspath(source_path))
                base_name = os.path.basename(source_path)
                compress_cmd = ["tar", "-cJf", archive_filename, "-C", parent_dir, base_name]
                run_command(compress_cmd)
            else: # db
                # Compress the single .sql file, sending output to stdout and capturing it
                with open(archive_filename, 'wb') as f_out:
                    compress_cmd = ["xz", "-c", "-9", source_path]
                    run_command(compress_cmd, stdout=f_out)
        elif compress_method == 'zip':
            compress_cmd = ["zip", "-rqq", archive_filename, source_path]
            run_command(compress_cmd)

        # Step 3: Generate hash
        hash_result = run_command(["openssl", "dgst", "-sha3-256", archive_filename], capture_output=True)
        file_hash = hash_result.stdout.split('=')[-1].strip()
        with open(hash_filename, 'w') as f:
            f.write(file_hash)

        # Return the archive and hash file for uploading
        return [archive_filename, hash_filename]
    finally:
        # Clean up intermediate files (like the .sql dump)
        if item_type == 'db' and source_path and os.path.exists(source_path):
            os.remove(source_path)


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
    check_root()

    parser = argparse.ArgumentParser(
        description="Python script to backup website & database to B2 Cloud Storage.\nUsage:\n  b2_backup.py init\n  b2_backup.py upgrade\n  b2_backup.py backup [--target {all,db,web} | --web | --db] <config1> [config2 ...]",
        formatter_class=argparse.RawTextHelpFormatter
    )
    subparsers = parser.add_subparsers(dest='command', required=True, help='Available commands')

    parser_init = subparsers.add_parser('init', help='First time setup for this script')
    parser_init.set_defaults(func=do_init)

    parser_upgrade = subparsers.add_parser('upgrade', help='Upgrade b2 cli')
    parser_upgrade.set_defaults(func=do_upgrade)

    parser_backup = subparsers.add_parser('backup', help='Backup your website & database to B2 Cloud Storage')
    target_group = parser_backup.add_mutually_exclusive_group()
    target_group.add_argument('--target', choices=['all', 'db', 'web'], default='all', help='Specify what to backup: all (default), db, or web.')
    target_group.add_argument('--web', action='store_const', const='web', dest='target', help='Shortcut to backup only the website.')
    target_group.add_argument('--db', action='store_const', const='db', dest='target', help='Shortcut to backup only the database.')
    parser_backup.add_argument('config_files', nargs='+', help='One or more config files to process')
    parser_backup.set_defaults(func=do_backup)

    args = parser.parse_args()
    
    if args.command == 'backup':
        args.func(args.config_files, args.target)
    else:
        args.func()

if __name__ == '__main__':
    main()