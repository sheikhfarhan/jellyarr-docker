#!/bin/bash
echo "--- 🐳 Pulling Updates for All Stacks ---"

# Define your stacks
STACKS=(
  "caddy"
  "crowdsec"
  "goaccess"
  "gotify"
  "jellyfin"
  "kopia"
  "utilities"
  "vpn-arr-stack"
)

BASE_DIR="/mnt/pool01/dockerapps"

for stack in "${STACKS[@]}"; do
  if [ -d "$BASE_DIR/$stack" ]; then
    echo "⬇️  Checking $stack..."
    cd "$BASE_DIR/$stack" || continue

    docker compose pull
    
    echo "✅  $stack updated."
    echo "-----------------------------------"
  else
    echo "⚠️  Folder $stack not found!"
  fi
done

echo "🎉 All images prepared! Run 'start-all' or restart specific services to apply."