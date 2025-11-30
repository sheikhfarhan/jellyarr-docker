#!/bin/bash
set -e # Stop immediately if any command fails

# Define Variables
SOURCE_DIR="/mnt/pool01/dockerapps"
DEST_DIR="onedrive:backup/cachyos/dockerapps"
CONFIG_FILE="/home/sfarhan/.config/rclone/rclone.conf"
EXCLUDE_FILE="/mnt/pool01/dockerapps/scripts/rclone-excludes.txt"
LOG_FILE="/home/sfarhan/rclone-backup.log"

echo "========================================================"
echo "Starting Docker Backup: $(date)"
echo "Source: $SOURCE_DIR"
echo "Destination: $DEST_DIR"
echo "========================================================"

# Run the Sync Command
# We use 'sudo' to read root-owned files (like Portainer data)
# We use '--config' to use YOUR OneDrive login
# We use '--log-file' to save the output for review

sudo rclone sync "$SOURCE_DIR" "$DEST_DIR" \
    --config "$CONFIG_FILE" \
    --exclude-from "$EXCLUDE_FILE" \
    --log-file "$LOG_FILE" \
    --log-level INFO \
    --checkers=16 \
    --transfers=8 \
    --delete-excluded

echo "Backup Complete: $(date)"
echo "========================================================"