#!/bin/bash
cd /mnt/pool01/dockerapps/caddy

echo "🔥 Force-rebuilding Caddy to pull latest plugins..."

# 1. Build with --no-cache to force xcaddy to download fresh plugin code
docker compose build --no-cache caddy

# 2. Recreate the container
docker compose up -d caddy

# 3. Clean up images created by the build process
docker image prune -f

echo "✅ Caddy rebuilt with latest plugins!"