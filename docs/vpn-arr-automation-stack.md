# 🤖 Service: Automation Stack (`vpn-arr-stack`)

**Location:** `/mnt/pool01/dockerapps/vpn-arr-stack/` \
**Network:** `dockerapps-net` (Management) & `service:gluetun` (Downloads)

This stack is the engine of the media server. It handles finding, downloading, renaming, and organizing content. It relies on a "Two-Zone" network architecture to ensure no traffic leaks outside the VPN.

-----

**File:** [`compose`](/vpn-arr-stack/compose.yml)

## 1\. The VPN Gateway (Zone 2)

These services are **inside the VPN bubble**. They do not have their own IP addresses; they share the network stack of the `gluetun` container.

### **A. Gluetun (The Gateway)**

  * **Role:** VPN Tunnel & Firewall. All download traffic MUST go through here.
  * **Static IP:** `172.20.0.11`
  * **Provider:** AirVPN (WireGuard).
  * **Ports Open:**
      * `8080` (qBittorrent Web UI)
      * `9091` (Transmission Web UI)
      * *Note: These ports are mapped on the Gluetun container, but forward traffic to the services "attached" to it.*
  * **Critical Config:**
      * `devices: /dev/net/tun` (Required for VPN).
      * `sysctls: net.ipv6.conf.all.disable_ipv6=0` (Enables IPv6 inside the tunnel).
      * **Healthcheck:** The container has a built-in healthcheck. Dependent services (`depends_on`) will NOT start until the VPN tunnel is fully established.

#### **🔧 Advanced: Control Server (API Access)**
Enabled to allow the **Homepage** dashboard to query the VPN status (Real Public IP & Port Forwarding status) via a secure API. More info [here on Glutun's Wiki](https://github.com/qdm12/gluetun-wiki/blob/main/setup/advanced/control-server.md)

1.  **Generate API Key:**
    Run this temporary command to generate a random, secure key:
    ```bash
    docker run --rm qmcgaw/gluetun genkey
    ```
2.  **Configuration File:**
    Created `auth/config.toml` in the local gluetun directory. This defines a "homepage" role with read-only access to specific endpoints.
    * **File:** `/dockerapps/gluetun/auth/config.toml`
    * **Content:**
        ```toml
        [[roles]]
        name = "homepage"
        auth = "apikey"
        apikey = "YOUR_GENERATED_KEY_HERE"
        routes = [
            "GET /v1/publicip/ip",
            "GET /v1/portforward"
        ]
        ```
3.  **Docker Mount:**
    Ensured the auth folder is mounted in `compose.yml`:
    `- ./gluetun/auth:/gluetun/auth:ro`

### **B. qBittorrent (Primary Downloader)**

  * **Role:** Torrent client.
  * **Network Mode:** `service:gluetun` (No IP).
  * **Web UI:** Accessed via `http://172.20.0.11:8080`.
  * **Storage:** Maps `/mnt/pool01/media:/media` to allow atomic moves to the library.
  * **Port Forwarding:** Configured/Added in AirVpn's Client Area Settings and double check that the specified AirVpn's Port number shows up in Qbit's settings under "Connection"->"Port used for incoming connections").

### **C. Transmission (Secondary Downloader)**

  * **Role:** Backup/Alternative client.
  * **Network Mode:** `service:gluetun` (No IP).
  * **Web UI:** Accessed via `http://172.20.0.11:9091`.
  * **Storage:** Maps `/mnt/pool01/media:/media`.
  * **Port Forwarding:** Uses AirVPN Port `<RESERVED_PORT>`.

-----

## 2\. The Managers (Zone 1)

These services are **outside the VPN** on the standard `dockerapps-net`. They manage the library and talk to the download clients via the local gateway.

### **A. Radarr (Movies)**

  * **Static IP:** `172.20.0.13`
  * **Port:** `7878`
  * **Role:** Managing Movie collection.
  * **Critical Settings:**
      * **Root Folders:** `/media/movies` (Standard) and `/media/anime-movies` (Anime).
      * **Remote Path Mapping:** Maps Host `172.20.0.1` Path `/media` to Local Path `/media`.
      * **Tags:** Auto-tags "Animation" genre with `anime`.

### **B. Sonarr (TV Shows)**

  * **Static IP:** `172.20.0.14`
  * **Port:** `8989`
  * **Role:** Managing TV Series.
  * **Critical Settings:**
      * **Root Folders:** `/media/shows` (Standard) and `/media/anime-shows` (Anime).
      * **Remote Path Mapping:** Maps Host `172.20.0.1` Path `/media` to Local Path `/media`.
      * **Tags:** Auto-tags "Anime" series type with `anime`.

### **C. Bazarr (Subtitles)**

  * **Static IP:** `172.20.0.15`
  * **Port:** `6767`
  * **Role:** Downloads subtitles for existing media.
  * **Connection:** Connects to Radarr/Sonarr to see what files need subtitles.

-----

## 3\. The Indexers & Utilities

### **A. Prowlarr (Indexer Manager)**

  * **Static IP:** `172.20.0.20`
  * **Port:** `9696`
  * **Role:** Manages torrent trackers and syncs them to Radarr/Sonarr.
  * **DNS Fix:** Configured with `dns: [1.1.1.1, 8.8.8.8]` to bypass host DNS issues.
  * **Proxy:** Uses `flaresolverr` to bypass Cloudflare protections on trackers.

### **B. FlareSolverr (Captcha Solver)**

  * **Static IP:** `172.20.0.21`
  * **Port:** `8191`
  * **Role:** Solves Cloudflare challenges for Prowlarr/Jackett.

### **C. Jackett (Useful Proxy)**

  * **Static IP:** `172.20.0.22`
  * **Port:** `9117`
  * **Role:** Used *only* for specific trackers that Prowlarr struggles with.
  * **Integration:** Added to Prowlarr as a "Generic Torznab" indexer.

### **D. Profilarr (Quality Settings & Custom Formats)**

  * **Static IP:** `172.20.0.19`
  * **Port:** `5000`
  * **Role:** Automatically syncs optimal quality profiles and custom formats to Radarr/Sonarr.

-----

## 4\. Maintenance

### **Dependencies & Startup**

The `compose.yml` defines strict dependencies:

1.  **Gluetun** starts first.
2.  **Download Clients** wait for `service_healthy` from Gluetun.
3.  **Managers (Radarr/Sonarr)** wait for Download Clients.
4.  **Profilarr** waits for Radarr/Sonarr.

**To Update the Entire Stack:**

```bash
cd /mnt/pool01/dockerapps/vpn-arr-stack
docker compose pull
docker compose up -d --force-recreate
```

*(This will briefly interrupt downloads and the VPN connection).*

## 5\. .env (saved alongside the compose file)

The `.env` elements that are align with what we have in our stack can be found in [.env-example](/vpn-arr-stack/.env.example)

---

</br>

# 📂 Automation alongside a Folder Strucuture

Section below explains the "Atomic Move" strategy and the complete lifecycle of a media request.

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
