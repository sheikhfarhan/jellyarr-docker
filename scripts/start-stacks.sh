#!/bin/bash
set -e # Exit immediately if any command fails

echo "--- Forcibly Re-creating All Docker Stacks ---"
echo "This will take a few minutes as all containers are rebuilt..."
echo ""

# Define the absolute path to our stacks
BASE_DIR="/mnt/pool01/dockerapps"

# --- Step 1: Core & Security Infrastructure ---
# We start these first so the network and security layers are ready.

echo "[1/9] Re-creating Gotify (Notifications)..."
cd $BASE_DIR/gotify && docker compose up -d --force-recreate

echo "[2/9] Re-creating CrowdSec (Security Brain)..."
cd $BASE_DIR/crowdsec && docker compose up -d --force-recreate

echo "[3/9] Re-creating Caddy (Reverse Proxy & Security)..."
cd $BASE_DIR/caddy && docker compose up -d --force-recreate

# --- Step 2: Management ---

echo "[4/9] Re-creating Management Stacks (Portainer)..."
cd $BASE_DIR/portainer && docker compose up -d --force-recreate
#cd $BASE_DIR/dockge && docker compose up -d --force-recreate

# --- Step 3: Media Core ---

echo "[5/9] Re-creating Jellyfin Stack (Media & Requests)..."
cd $BASE_DIR/jellyfin && docker compose up -d --force-recreate

# --- Step 4: Automation Engine ---
# This contains GlueTUN, Arr apps, Download clients, and Profilarr

echo "[6/9] Re-creating VPN-ARR-Stack..."
cd $BASE_DIR/vpn-arr-stack && docker compose up -d --force-recreate

# --- Step 5: Utilities ---

echo "[7/9] Re-creating WUD (Update Notifier)..."
cd $BASE_DIR/wud && docker compose up -d --force-recreate

echo "[8/9] Re-creating Dozzle (Logs)..."
cd $BASE_DIR/dozzle && docker compose up -d --force-recreate

echo "[9/9] Re-creating Homepage (Dashboard)..."
cd $BASE_DIR/homepage && docker compose up -d --force-recreate



echo ""
echo "--- All stacks re-created successfully! ---"
