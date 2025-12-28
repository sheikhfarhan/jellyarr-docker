# 🌳 Directory Map & Replication

## The "Golden" Directory Tree

This hierarchy reflects my current live server state. It respects the "Two-Zone" network and the "Atomic Move" storage layout.

```text
/mnt/pool01/
├── dockerapps/                      # (LV: lv_dockerapps)
│   ├── scripts/                     # Automation scripts
│   ├── docs/                        # This documentation
│   ├── .env                         # Global secrets
│   │
│   ├── utilities/                   # Unified Management Stack
│   │   ├── compose.yml              # Controls Homepage, Portainer, WUD, Proxy
│   │   ├── .env                     # Secrets for management tools
│   │   ├── homepage/
│   │   │   └── config/              # YAML configs (services, widgets, settings)
│   │   ├── portainer/
│   │   │   └── data/                # Portainer database
│   │   ├── wud/
│   │   │   └── store/               # WUD state & history
│   │   ├── beszel/
│   │   │   └── data/                # Beszel Hub & Agent
│   │   │   └── beszel_agent_data/  
│   │   └── dozzle                   # Containers' Logs Viewer
│   │
│   ├── caddy/                       # Reverse Proxy and Security Ingress
│   │   ├── compose.yml
│   │   ├── .env   
│   │   ├── Caddyfile
│   │   ├── Dockerfile
│   │   ├── data/
│   │   ├── config/
│   │   ├── logs/
│   │   │   └── access.log
│   │   │   └── caddy.log
│   │   └── maxmind/
│   │       └── GeoLite2-Country.mmdb
│   │
│   ├── goaccess/                    # Loggings
│   │   ├── compose.yml
│   │   ├── .env      
│   │   ├──  data/
│   │   └── html/
│   │       └── index.html
│   │
│   ├── crowdsec/                    # Security Brain
│   │   ├── compose.yml
│   │   ├── .env   
│   │   ├── acquis.yaml 
│   │   ├── config/
│   │   └── data/
│   │
│   ├── gotify/                      # Notifications
│   │   ├── compose.yml
│   │   ├── .env   
│   │   └── data/
│   │
│   ├── jellyfin/                    # Media Core
│   │   ├── compose.yml
│   │   ├── .env   
│   │   ├── jellyfin-config/
│   │   ├── jellyfin-cache/
│   │   └── jellyseerr-config/
│   │
│   ├── vpn-arr-stack/               # Automation Engine
│   │   ├── compose.yml
│   │   ├── .env   
│   │   ├── gluetun/
│   │   │   ├── config/              # Disposable (servers.json)
│   │   │   └── auth/                # Secrets (config.toml)
│   │   ├── radarr/
│   │   ├── sonarr/
│   │   ├── ... (other arr apps)
│   │   └── profilarr/
│   │
│   ├── kopia/                       # Backup Engine
│   │   ├── compose.yml
│   │   ├── .env   
│   │   ├── config/
│   │   ├── cache/
│   │   └── logs/
│   │
│   └── authentik/                   # Authentication
│       ├── compose.yml
│       ├── .env   
│       ├── certs/
│       ├── database/
│       ├── media/
│       └── templates/
│   
├── media/                           # (LV: lv_media)
│   ├── downloads/                   # Ingest Zone
│   │   ├── incomplete/              # Active downloads
│   │   ├── radarr/                  # Completed Movies
│   │   ├── sonarr/                  # Completed TV
│   │   ├── radarr-anime/            # Completed Anime Movies
│   │   └── sonarr-anime/            # Completed Anime TV
│   ├── movies/                      # Library (Hardlinked)
│   ├── shows/                       # Library (Hardlinked)
│   ├── anime-movies/                # Library (Hardlinked)
│   └── anime-shows/                 # Library (Hardlinked)
│
└── games/                           # (LV: lv_games)
```

-----

## 2\. Rapid Reconstruction

To recreate the folder structure on a new machine (after mounting our LVM), run this command block. It creates the skeleton directories and sets the correct permissions.

### **A. Create the `media` Structure (The "Atomic" Layer)**

```bash
# Create the media hierarchy
sudo mkdir -p /mnt/pool01/media/{movies,shows,anime-movies,anime-shows}
sudo mkdir -p /mnt/pool01/media/downloads/{incomplete,radarr,sonarr,radarr-anime,sonarr-anime}

# Set Permissions (Critical for Container Access)
sudo chown -R $USER:$USER/mnt/pool01/media
sudo chmod -R 775 /mnt/pool01/media
```

### **B. Create the `dockerapps` Structure**

#### 1. Create the Base Directory:

```bash
sudo mkdir -p /mnt/pool01/dockerapps
```

#### 2. Create Service Folders:

```bash
cd /mnt/pool01/dockerapps
mkdir -p scripts docs
```

#### 3. Create the directories and empty .env files in each of the directories:**

  ```bash
  ./scripts/setup.dirs.sh
  ```

Script [here](/scripts/setup_dirs.sh)


#### 4. Set Permissions (The "Golden Command")

Ensure user owns everything so containers don't crash

```bash
sudo chown -R $USER:$USER /mnt/pool01/dockerapps
```

-----

## 3\. Validation

After running the scripts, verify the structure matches your expectations:

```bash
tree -d -L 3 /mnt/pool01
```

*(may need to install `tree` with `sudo pacman -S tree`)*