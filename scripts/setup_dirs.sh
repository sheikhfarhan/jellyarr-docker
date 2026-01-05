#!/bin/bash
set -e

# Usage: ./setup_dirs.sh [TARGET_DIR]
# If TARGET_DIR is not provided, defaults to current directory.

TARGET_DIR="${1:-.}"
# Convert to absolute path
TARGET_DIR=$(realpath "$TARGET_DIR")

echo "--- 📂 DockerApps Directory Setup ---"
echo "Target Base Directory: $TARGET_DIR"
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then
  echo "⚠️  WARNING: You are running this script as root!"
  echo "    Files and directories will be created with root:root ownership."
  echo "    This may cause permission issues if you intend to run containers as a standard user."
  echo "    It is recommended to run this script as the standard user who will run docker."
  echo ""
fi

confirm() {
    read -r -p "Proceed with creating directories and files in $TARGET_DIR? [y/N] " response
    case "$response" in
        [yY][eE][sS]|[yY]) 
            true
            ;;
        *)
            echo "Aborted."
            exit 1
            ;;
    esac
}

# Ask for confirmation if running interactively
if [ -t 0 ]; then
    confirm
fi

# Function to safely create a directory
create_dir() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        echo "✅ Created directory: $dir"
    else
        echo "👌 Directory exists: $dir"
    fi
}

# Function to safely create an empty file (touch)
create_file() {
    local file="$1"
    if [ ! -f "$file" ]; then
        mkdir -p "$(dirname "$file")"
        touch "$file"
        echo "✅ Created file: $file"
    else
        echo "👌 File exists: $file"
    fi
}

# Function to create an empty .env file if missing
create_env() {
    local env_file="$1/.env"
    if [ ! -f "$env_file" ]; then
        # Ensure parent dir exists
        mkdir -p "$1"
        touch "$env_file"
        echo "✉️  Created empty .env in: $1"
    else
        echo "👌 .env exists in: $1"
    fi
}

echo "--- Creating Service Directories and .env files ---"

# 1. Gotify
create_dir "$TARGET_DIR/gotify/data"
create_env "$TARGET_DIR/gotify"

# 2. Crowdsec
create_dir "$TARGET_DIR/crowdsec/config"
create_dir "$TARGET_DIR/crowdsec/data"
# Following the logic where the main acquis.yaml file (where we will parse caddy's access.log) is mounted specifically in the compose file
# at base of Crowdsec folder
create_file "$TARGET_DIR/crowdsec/acquis.yaml"
create_env "$TARGET_DIR/crowdsec"

# 3. Caddy
create_dir "$TARGET_DIR/caddy/data"
create_dir "$TARGET_DIR/caddy/config"
create_dir "$TARGET_DIR/caddy/logs"
create_dir "$TARGET_DIR/caddy/maxmind"
create_dir "$TARGET_DIR/caddy/voidauth/config"
create_dir "$TARGET_DIR/caddy/voidauth/db"
create_env "$TARGET_DIR/caddy"

# 4. Jellyfin & Jellyseerr
create_dir "$TARGET_DIR/jellyfin/jellyfin-config"
create_dir "$TARGET_DIR/jellyfin/jellyfin-cache"
create_dir "$TARGET_DIR/jellyfin/jellyseerr-config"
create_env "$TARGET_DIR/jellyfin"

# 5. VPN-Arr-Stack
create_dir "$TARGET_DIR/vpn-arr-stack/gluetun/config"
create_dir "$TARGET_DIR/vpn-arr-stack/gluetun/auth"
create_dir "$TARGET_DIR/vpn-arr-stack/qbittorrent/config"
create_dir "$TARGET_DIR/vpn-arr-stack/transmission/config"
create_dir "$TARGET_DIR/vpn-arr-stack/prowlarr/config"
create_dir "$TARGET_DIR/vpn-arr-stack/jackett/config"
create_dir "$TARGET_DIR/vpn-arr-stack/radarr/config"
create_dir "$TARGET_DIR/vpn-arr-stack/sonarr/config"
create_dir "$TARGET_DIR/vpn-arr-stack/bazarr/config"
create_dir "$TARGET_DIR/vpn-arr-stack/flaresolverr/config"
create_dir "$TARGET_DIR/vpn-arr-stack/profilarr/config"
create_env "$TARGET_DIR/vpn-arr-stack"

# 6. Utilities
create_dir "$TARGET_DIR/utilities/homepage/config"
create_dir "$TARGET_DIR/utilities/homepage/config/icons"
create_dir "$TARGET_DIR/utilities/wud/store"
create_dir "$TARGET_DIR/utilities/beszel/data"
create_dir "$TARGET_DIR/utilities/beszel/beszel_agent_data"
create_dir "$TARGET_DIR/utilities/dozzle"
create_dir "$TARGET_DIR/utilities/arcane/arcane-data"
create_env "$TARGET_DIR/utilities"

# 7. Kopia
create_dir "$TARGET_DIR/kopia/config"
create_dir "$TARGET_DIR/kopia/cache"
create_dir "$TARGET_DIR/kopia/logs"
create_env "$TARGET_DIR/kopia"

# 8. GoAccess
create_dir "$TARGET_DIR/goaccess/data"
create_dir "$TARGET_DIR/goaccess/html"
create_env "$TARGET_DIR/goaccess"

echo "--- Creating Root Level Files/Dirs ---"

# .beszel directory at root
create_dir "$TARGET_DIR/.beszel"

# .kopiaignore file at root
create_file "$TARGET_DIR/.kopiaignore"

echo ""
echo "✨ Directory setup complete!"
