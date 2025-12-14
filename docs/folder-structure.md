# 🌳 Directory Map & Replication

## The "Golden" Directory Tree

This hierarchy reflects the live server state. It respects the "Two-Zone" network and the "Atomic Move" storage layout.

```text
/mnt/pool01/
├── dockerapps/                      # (LV: lv_dockerapps - 60GB)
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
│   │   └── wud/
│   │       └── store/               # WUD state & history
│   │
│   ├── caddy/                       # Security Ingress
│   │   ├── compose.yml
│   │   ├── .env   
│   │   ├── Caddyfile
│   │   ├── Dockerfile
│   │   ├── data/
│   │   ├── config/
│   │   └── logs/
│   │   │   └── access.log
│   │   │   └── caddy.log
│   │   └── goaccess/
│   │   │   └── data/
│   │   │   └── html/
│   │   │         └── index.html
│   │   └── maxmind/
│   │   │   └── GeoLite2-Country.mmdb
│   │
│   ├── crowdsec/                    # Security Brain
│   │   ├── compose.yml
│   │   ├── .env   
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
│   └── vpn-arr-stack/               # Automation Engine
│       ├── compose.yml
│       ├── .env   
│       ├── gluetun/
│       │   ├── config/              # Disposable (servers.json)
│       │   └── auth/                # Secrets (config.toml)
│       ├── radarr/
│       ├── sonarr/
│       ├── ... (other arr apps)
│       └── profilarr/
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

## 2\. Rapid Reconstruction Script

To recreate this exact folder structure on a new machine (after mounting our LVM), run this command block. It creates the skeleton directories and sets the correct permissions.

### **A. Create the `media` Structure (The "Atomic" Layer)**

```bash
# Create the media hierarchy
sudo mkdir -p /mnt/pool01/media/{movies,shows,anime-movies,anime-shows}
sudo mkdir -p /mnt/pool01/media/downloads/{incomplete,radarr,sonarr,radarr-anime,sonarr-anime}

# Set Permissions (Critical for Container Access)
sudo chown -R 1000:1000 /mnt/pool01/media
sudo chmod -R 775 /mnt/pool01/media
```

### **B. Create the `dockerapps` Structure**

```bash
# Create Base
sudo mkdir -p /mnt/pool01/dockerapps

# Create Service Folders
cd /mnt/pool01/dockerapps
mkdir -p scripts docs

# Utilities Stack
# Create specific subfolders for the services that need persistence
mkdir -p utilities/homepage/config
mkdir -p utilities/portainer/data
mkdir -p utilities/wud/store
# (Note: Dozzle and Socket-Proxy are stateless, so they don't need folders)

# Security & Core
mkdir -p caddy/{config,data,logs} #we want the logs folder to be user-owned
mkdir -p crowdsec/{config,data}
mkdir -p gotify/data

# Media Core
mkdir -p jellyfin/{jellyfin-config,jellyfin-cache,jellyseerr-config}

# Automation Engine (VPN & Arrs)
# Create separate Auth folder for Gluetun
mkdir -p vpn-arr-stack/gluetun/{config,auth}
# Create config folders for all *Arr apps
mkdir -p vpn-arr-stack/{radarr,sonarr,prowlarr,bazarr,qbittorrent,transmission,jackett,flaresolverr,profilarr}/config

# 3. Set Permissions (The "Golden Command")
# Ensure our user (1000) owns everything so containers don't crash
sudo chown -R 1000:1000 /mnt/pool01/dockerapps
```

-----

## 3\. Validation

After running the scripts, verify the structure matches your expectations:

```bash
tree -d -L 3 /mnt/pool01
```

*(may need to install `tree` with `sudo pacman -S tree`)*

---
<br>

# 📂 Folder Structure & Automation

This document explains the "Atomic Move" strategy and the complete lifecycle of a media request.

## 1\. The "Atomic Move" Principle (Hardlinks)

For hardlinks to work, the **Download Client** (qBittorrent/Transmission) and the **Media Manager** (Radarr/Sonarr) must perceive the file as existing on the **same file system**.

We achieve this by mapping the **root** of the LVM volume (`/mnt/pool01/media`) to the **same internal path** (`/media`) in every single container.

  * **Host Path:** `/mnt/pool01/media`
  * **Container Path:** `/media`

### **Why this matters (The "Magic")**

By having one media volume that contains both our `/media/downloads` folder and our `/media/movies` folder, the system can use **Hardlinks**.

  * This means our file can be "in" our seeding folder and our library folder at the **exact same time**.
  * It uses **zero (0) extra disk space**.
  * The move is **instant** (atomic), even for a 50GB file.

-----

## 2\. Workflow: The Lifecycle of a Request

Here is the step-by-step journey of a file through our system:

1.  **The Request:**
    From **Jellyseerr**, a user selects a movie or show. Jellyseerr sends this request to **Radarr** (or Sonarr) to find it.

2.  **The Hand-off:**
    Radarr searches its indexers (via Prowlarr). When it finds a match, it sends the job to our **default download client** (e.g., qBittorrent).

3.  **Tagging & Categorization:**

      * **Standard:** Radarr assigns the category `radarr`.
      * **Anime:** If the movie has the tag `anime` (auto-tagged by genre), Radarr assigns the category `radarr-anime` and uses the specific `qBittorrent (Anime)` client.

4.  **The Download:**
    qBittorrent downloads the file.

      * It places chunks in `/media/downloads/incomplete` while active.
      * It moves the final file to `/media/downloads/radarr` (or `radarr-anime`) when finished.

5.  **The Check-up:**
    Radarr knows it gave that job to qBittorrent. It periodically asks the qBittorrent API: *"How is that job with the category 'radarr' doing?"*

6.  **The Report:**
    qBittorrent's API eventually reports back: *"The job is 100% complete, and the files are located at `/media/downloads/radarr/My.Movie.2025.mkv`."*

7.  **The Import (Hardlink):**
    Radarr then knows exactly where the file is. Because of our **Remote Path Mapping**, it knows that `/media` on the download client is the same as `/media` on its own file system.

      * It goes to that path.
      * It performs a **Hardlink** to `/media/movies/My Movie (2025)/`.
      * The file now exists in *both* places, but takes up space only *once*.

-----

## 3\. Directory Layout

The structure is organized to separate "raw" downloads from "clean" library files while keeping them on the same partition.

```text
/mnt/pool01/media/
├── downloads/               # Raw Ingest Zone
│   ├── incomplete/          # Temporary folder for active downloads
│   ├── radarr/              # Completed Movies (qBit Category: radarr)
│   ├── sonarr/              # Completed TV Shows (qBit Category: sonarr)
│   ├── radarr-anime/        # Completed Anime Movies (qBit Category: radarr-anime)
│   └── sonarr-anime/        # Completed Anime TV (qBit Category: sonarr-anime)
│
├── movies/                  # Clean Movie Library (Hardlinks)
├── shows/                   # Clean TV Library (Hardlinks)
├── anime-movies/            # Clean Anime Movie Library
└── anime-shows/             # Clean Anime TV Library
```

## 4\. Remote Path Mapping (Critical)

**This setting must be configured in BOTH Radarr AND Sonarr (under Settings \> Download Clients).**

Because the Download Clients live inside the `gluetun` VPN container (IP `172.20.0.11`) and the \*Arr apps live on the app network (IP `172.20.0.13+`), the \*Arr apps view the downloader as a "Remote" host.

To prevent them from trying to download files over the network (which is slow and breaks hardlinks), we explicitly tell them the paths are local.

  * **Host:** `172.20.0.1` (Gateway IP used to talk to clients)
  * **Remote Path:** `/media`
  * **Local Path:** `/media`
