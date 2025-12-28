#!/bin/bash
set -e # Exit immediately if any command fails

echo "--- 🐳 Forcibly Re-creating All Docker Stacks ---"
echo "This will take a few minutes as all containers are rebuilt..."
echo ""

# Define the absolute path to our stacks
BASE_DIR="/mnt/pool01/dockerapps"

# --- Step 1: Core & Security Infrastructure ---
# We start these first so the network and security layers are ready.

echo "[1/8] Re-creating Gotify (Notifications)..."
cd $BASE_DIR/gotify && docker compose up -d --force-recreate

echo "[2/8] Re-creating CrowdSec (Security Brain)..."
cd $BASE_DIR/crowdsec && docker compose up -d --force-recreate

echo "[3/8] Re-creating Caddy (Reverse Proxy & Logs)..."
cd $BASE_DIR/caddy && docker compose up -d --force-recreate

# --- Step 2: Media Core ---

echo "[4/8] Re-creating Jellyfin Stack (Media & Requests)..."
cd $BASE_DIR/jellyfin && docker compose up -d --force-recreate

# --- Step 3: Automation Engine ---
# This contains GlueTUN, Arr apps, Download clients, and Profilarr

echo "[5/8] Re-creating VPN-ARR-Stack..."
cd $BASE_DIR/vpn-arr-stack && docker compose up -d --force-recreate

# --- Step 4: Utilities ---

echo "[6/8] Re-creating Management & Loggings Stack (Utilities)..."
cd $BASE_DIR/utilities && docker compose up -d --force-recreate

# --- Step 5: Backup Service ---

echo "[7/8] Re-creating Kopia..."
cd $BASE_DIR/kopia && docker compose up -d --force-recreate

# --- Step 6: Authentication ---

echo "[8/8] Re-creating Authentik..."
cd $BASE_DIR/authentik && docker compose up -d --force-recreate

echo ""
echo "--- All stacks re-created successfully! ---"
