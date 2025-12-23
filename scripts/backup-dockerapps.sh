#!/bin/bash
set -e # Exit immediately if a command fails (safety)

# ========================================================
# CONFIGURATION
# ========================================================
SOURCE_DIR="/mnt/pool01/dockerapps"
DEST_DIR="onedrive:backup/cachyos/dockerapps"
CONFIG_FILE="/home/sfarhan/.config/rclone/rclone.conf"
EXCLUDE_FILE="/mnt/pool01/dockerapps/scripts/rclone-excludes.txt"
LOG_FILE="/home/sfarhan/rclone-backup.log"

# List of containers to stop (Space separated)
# INCLUDES: Arr Stack, Download Clients, Request Managers
SERVICES_TO_STOP="sonarr radarr prowlarr bazarr jackett qbittorrent transmission jellyseerr"

# ========================================================
# SAFETY FUNCTIONS
# ========================================================

# 1. Define the restart function
start_containers() {
    echo "--------------------------------------------------------"
    echo "POST-BACKUP: Restarting containers..."
    # We use '|| true' so the script finishes even if one fails to start
    docker start $SERVICES_TO_STOP || true
    echo "All services are back online."
}

# 2. Set the Trap
# This guarantees that 'start_containers' runs when the script exits,
# whether it finished successfully OR crashed/failed.
trap start_containers EXIT

# ========================================================
# BACKUP PROCESS
# ========================================================

echo "========================================================"
echo "Starting Docker Backup: $(date)"
echo "Source: $SOURCE_DIR"
echo "--------------------------------------------------------"

# 3. PRE-BACKUP: Stop the Services
echo "Stopping containers to ensure DB integrity..."
docker stop $SERVICES_TO_STOP || true
echo "Containers stopped. Starting sync..."

# 4. Run Rclone
# We rely on the 'trap' to restart containers after this finishes
sudo rclone sync "$SOURCE_DIR" "$DEST_DIR" \
    --config "$CONFIG_FILE" \
    --exclude-from "$EXCLUDE_FILE" \
    --log-file "$LOG_FILE" \
    --log-level INFO \
    --checkers=16 \
    --transfers=8 \
    --delete-excluded

echo "========================================================"
echo "Backup Process Complete: $(date)"
# Script exits here -> Trap triggers -> Containers restart