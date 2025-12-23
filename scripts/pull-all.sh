#!/bin/bash
echo "--- 🐳 Pulling Updates for All Stacks ---"

# Define your stacks
STACKS=(
  "caddy"
  "crowdsec"
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

    # --- SPECIAL HANDLING FOR CADDY ---
    # Caddy is a custom build so we cannot 'pull' it.
    if [ "$stack" == "caddy" ]; then
        echo "Caddy Stack: Updating sidecars only..."
        
        # Note: Using SERVICE names from our compose file
        docker compose pull goaccess maxmind
        
        echo "⚠️  Skipping Caddy core (xcaddy custom build). Run 'rebuild-caddy.sh' to update modules/plugins."
    else
        # Standard behavior for all other stacks
        docker compose pull
    fi
    
    echo "✅  $stack updated."
    echo "-----------------------------------"
  else
    echo "⚠️  Folder $stack not found!"
  fi
done

echo "🎉 All images prepared! Run 'start-all' or restart specific services to apply."