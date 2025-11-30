# 🏠 Homepage (Dashboard)

**Role:** Central Dashboard & Status Monitor \
**URL:** `http://172.20.0.25:3000` (Internal) \
**Location:** `/mnt/pool01/dockerapps/homepage` \
**Network:** `dockerapps-net` (Static IP: `172.20.0.25`) \
**Compose File:** `compose.yml`

Homepage provides a unified interface to monitor service status, resource usage, and integration stats. It is the "Single Pane of Glass" for the entire server.

-----

## 1\. Docker Configuration Logic

The container is configured to run securely as a non-root user while maintaining visibility into the host system.

**File:** `compose.yml`

```yaml
networks:
  dockerapps-net:
    external: true

services:
  homepage:
    image: ghcr.io/gethomepage/homepage:latest
    container_name: homepage
    hostname: homepage
    networks:
      dockerapps-net:
        ipv4_address: 172.20.0.25
        ipv6_address: 2001:db8:abc2::25
    ports:
      - 3000:3000
    # For Secrets
    env_file:
      - .env
    environment:
      - PUID=1000
      - PGID=958
      - TZ=Asia/Singapore
      # Allow connections from LAN and Localhost
      - HOMEPAGE_ALLOWED_HOSTS=*
    volumes:
      - ./config:/app/config
      - ./config/icons:/app/public/icons #upload own icons at local folder and reflect it at the services side with /icons/imagename.png
      - /var/run/docker.sock:/var/run/docker.sock
      # --- MOUNT DISKS ---
      - /mnt/pool01/media:/mnt/media_disk:ro
      - /mnt/pool01/dockerapps:/mnt/dockerapps_disk:ro
    restart: unless-stopped
```
-----

## 2\. Integrations (`services.yaml`)

```yaml
- Media:
    - Jellyfin:
        icon: jellyfin.png
        href: http://172.20.0.10:8096
        description: Media Server
        container: jellyfin
        widget:
          type: jellyfin
          url: http://172.20.0.10:8096
          key: {{HOMEPAGE_VAR_JELLYFIN_KEY}}
          enableBlocks: true

    - Jellyseerr:
        icon: jellyseerr.png
        href: http://172.20.0.12:5055
        description: Request Manager
        container: jellyseerr
        widget:
          type: jellyseerr
          url: http://172.20.0.12:5055
          key: {{HOMEPAGE_VAR_JELLYSEERR_KEY}}

- Automation:
    - Radarr:
        icon: radarr.png
        href: http://172.20.0.13:7878
        description: Movie Manager
        container: radarr
        widget:
          type: radarr
          url: http://172.20.0.13:7878
          key: {{HOMEPAGE_VAR_RADARR_KEY}}

    - Sonarr:
        icon: sonarr.png
        href: http://172.20.0.14:8989
        description: TV Manager
        container: sonarr
        widget:
          type: sonarr
          url: http://172.20.0.14:8989
          key: {{HOMEPAGE_VAR_SONARR_KEY}}

    - Bazarr:
        icon: bazarr.png
        href: http://172.20.0.15:6767
        description: Subtitles
        container: bazarr
        widget:
          type: bazarr
          url: http://172.20.0.15:6767
          key: {{HOMEPAGE_VAR_BAZARR_KEY}}

    - Prowlarr:
        icon: prowlarr.png
        href: http://172.20.0.20:9696
        description: Indexer Manager
        container: prowlarr
        widget:
          type: prowlarr
          url: http://172.20.0.20:9696
          key: {{HOMEPAGE_VAR_PROWLARR_KEY}}

    - Profilarr:
        icon: profilarr.png
        href: http://172.20.0.19:7777
        description: Trash Guides Sync
        container: profilarr
        #widget:
        #  type: profilarr
        #  url: http://172.20.0.19:7777

    - Gluetun:
        icon: gluetun.png
        href: "#"
        description: VPN Gateway
        container: gluetun
        widget:
          type: gluetun
          url: http://172.20.0.11:8000

    - Transmission:
        icon: transmission.png
        href: http://172.20.0.11:9091
        description: VPN Torrent Client
        container: transmission
        widget:
          type: transmission
          url: http://172.20.0.11:9091
          username: {{HOMEPAGE_VAR_TRANS_USER}}
          password: {{HOMEPAGE_VAR_TRANS_PASS}}

    - QBittorrent:
        icon: qbittorrent.png
        href: http://172.20.0.11:8080
        description: VPN Torrent Client
        container: qbittorrent
        widget:
          type: qbittorrent
          url: http://172.20.0.11:8080
          username: {{HOMEPAGE_VAR_QBIT_USER}}
          password: {{HOMEPAGE_VAR_QBIT_PASS}}

- Management:
    - Portainer:
        icon: portainer.png
        href: https://172.20.0.17:9443
        description: Docker UI
        container: portainer

    - Gotify:
        icon: gotify.png
        href: http://172.20.0.16:80
        description: Notifications
        container: gotify
        widget:
          type: gotify
          url: http://172.20.0.16:80
          key: {{HOMEPAGE_VAR_GOTIFY_KEY}}

    - Caddy:
        icon: caddy.png
        href: http://172.20.0.23
        description: Reverse Proxy
        container: caddy
        
    - CrowdSec:
        icon: crowdsec.png
        href: http://172.20.0.24:8080
        description: Security Brain
        container: crowdsec
        widget:
          type: crowdsec
          url: http://172.20.0.24:8080
          username: {{HOMEPAGE_VAR_CROWDSEC_USER}}
          password: {{HOMEPAGE_VAR_CROWDSEC_PASS}}
          fields: ["alerts", "bans"]
        
    - Dozzle:
        icon: dozzle.png
        href: http://172.20.0.26:8080
        description: Log Viewer
        container: dozzle

    - WUD:
        icon: /icons/wud.png
        href: http://172.20.0.27:3001
        description: Update Notifier
        container: wud
        widget:
          type: whatsupdocker
          url: http://172.20.0.27:3001
          
```

We use **Environment Variables** (secrets) to keep API keys out of version control.

### **A. Secure Credential Management**

Instead of hardcoding keys, we use placeholders like `{{HOMEPAGE_VAR_JELLYFIN_KEY}}`.

  * **Source:** These variables are defined in `.env`
  * **Usage:** Homepage automatically substitutes them at runtime.

### **B. Integration Types**

| Service | Method | Key Type | Example Config |
| :--- | :--- | :--- | :--- |
| **Jellyfin** | API | API Key | `key: {{HOMEPAGE_VAR_JELLYFIN_KEY}}` |
| **Arr Stack** | API | API Key | `key: {{HOMEPAGE_VAR_RADARR_KEY}}` |
| **Gotify** | API | **Client Token** (`C...`) | `key: {{HOMEPAGE_VAR_GOTIFY_KEY}}` |
| **CrowdSec** | LAPI | **Machine Creds** | `username: {{...USER}}` / `password: {{...PASS}}` |
| **Torrent** | Web UI | User/Pass | `username: {{...USER}}` / `password: {{...PASS}}` |

### **C. Special Case: CrowdSec**

Unlike other apps, the CrowdSec widget connects directly to the Local API (LAPI). It requires the **Machine Login/Password**, not an API key.

  * **Where to find credentials:** `/mnt/pool01/dockerapps/crowdsec/config/local_api_credentials.yaml` on the host.

-----

## 3\. Widget Configuration (`widgets.yaml`)

We separate resource monitoring into logical groups for clarity.

```yaml
# System Stats (CPU/RAM)
- resources: 
    label: System
    expanded: true 
    cpu: true 
    memory: true 

# Storage Stats (Specific LVM Volumes)
# These paths must match the volume mounts in compose.yml
- resources:
    label: Storage - Media 
    disk:
      - /mnt/media_disk

- resources:
    label: Storage - Games
    disk:
      - /mnt/games_disk

- resources:
    label: Storage - Dockerapps
    disk:
      - /app/config

# for my main dockerapps folder, where homepage (and rest of the other services/containers resides, 
#the path is as per how in compose file is for the
#volumes:
#      - ./config:/app/config
#
```

-----

## 4\. Troubleshooting Guide

### **Issue 1: "API Error" on Storage Widgets**

  * **Symptom:** The disk bar shows "API Error" instead of usage stats.
  * **Cause:** The path defined in `widgets.yaml` (e.g., `/mnt/media_disk`) does not exist inside the container.
  * **Fix:** Ensure you have mounted the volume in `compose.yml` (`- /mnt/pool01/media:/mnt/media_disk:ro`) AND recreated the container (`docker compose up -d --force-recreate`).

### **Issue 2: "Host validation failed"**

  * **Symptom:** A white screen with this error message when loading the dashboard.
  * **Cause:** Security feature blocking unknown domains/IPs.
  * **Fix:** Set `HOMEPAGE_ALLOWED_HOSTS=*` in `compose.yml`.

### **Issue 3: Docker Stats Missing / Permission Denied**

  * **Symptom:** Container status dots are grey/missing, or logs show `EACCES /var/run/docker.sock`.
  * **Cause:** The container user (1000) cannot read the host's Docker socket (owned by root/docker).
  * **Fix:** Set `PGID` in `compose.yml` to match the host's docker group ID.
      * Run `getent group docker` on host to find the ID (e.g., 958).

### **Issue 4: CrowdSec Widget Error**

  * **Symptom:** Widget shows error or fails to load.
  * **Cause:** Often caused by using a Bouncer API Key instead of Machine Credentials, or because the `local_api_credentials.yaml` file changed (if the DB was wiped).
  * **Fix:** Verify the username/password in `.env` matches the *current* contents of `local_api_credentials.yaml`.
