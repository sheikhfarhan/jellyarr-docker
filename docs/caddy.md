**Version:** 2.0 (Post-GoAccess and Maxmind Integration)

## 1\. Architecture Overview

| Service | Role | Key Function |
| :--- | :--- | :--- |
| **Caddy** | **Reverse Proxy** | The "Front Door". Handles SSL, Geo-Blocking (Layer 1), and Traffic Routing. |
| **CrowdSec** | **Intrusion Detection** | The "Brain". Reads logs, detects attacks, and instructs Caddy to ban IPs (Layer 2). |
| **MaxMind** | **GeoIP** | Provides Geo-Data for Caddy (blocking) and GoAccess (mapping). Auto-updates weekly. |
| **GoAccess** | **Access Logs Analytics** | Real-time, WebSocket-based traffic visualization. |

-----

# Service: MaxMind (GeoIP Provider")

**Role:** Geo-IP Database Provider  
**Mechanism:** Sidecar Auto-Updater  
**Location:** `/mnt/pool01/dockerapps/caddy/maxmind`

Instead of manually downloading `.mmdb` files and uploading them to the server, we use an official MaxMind "Sidecar" container. This container runs on a schedule, downloads the latest databases, and places them into a **Shared Volume** that both Caddy and GoAccess can read.

## 1\. The Shared Volume Strategy

This is an architectural decision that I prefer to have. We do not copy files between containers. We mount a single host directory to multiple containers.

  * **Host Path:** `./maxmind` (Relative to the Caddy folder)
  * **MaxMind Container:** Writes to `/usr/share/GeoIP`
  * **Caddy Container:** Reads from `/etc/caddy/maxmind` (ReadOnly)
  * **GoAccess Container:** Reads from `/srv/maxmind` (ReadOnly)

## 2\. Configuration

The `maxmind` service is configured to check for updates every 72 hours.

```yaml
  maxmind:
    image: ghcr.io/maxmind/geoipupdate
    container_name: maxmind
    # Critical: Run as the same user as Caddy/GoAccess to prevent Permission Denied errors
    user: "${PUID}:${PGID}"
    networks:
      - dockerapps-net
    environment:
      - GEOIPUPDATE_ACCOUNT_ID=${MAXMIND_ACCOUNT_ID}
      - GEOIPUPDATE_LICENSE_KEY=${MAXMIND_LICENSE_KEY}
      - GEOIPUPDATE_EDITION_IDS=GeoLite2-Country
      - GEOIPUPDATE_FREQUENCY=72
    volumes:
      # Maps local 'maxmind' folder to the container's data folder
      - ./maxmind:/usr/share/GeoIP
    restart: unless-stopped
```

## 3\. First-Run Setup & Credentials

To enable this, we registered a free account at MaxMind and generated a License Key. These secrets are stored in the `.env` file:

```bash
MAXMIND_ACCOUNT_ID=123456
MAXMIND_LICENSE_KEY=abc123xyz
```

  * **Note:** On the very first run, Caddy might fail to start because the `.mmdb` file doesn't exist yet. The fix is to let the MaxMind container run for \~30 seconds to finish the download, then restart Caddy.

---

# Service: Caddy (Secure Reverse Proxy)

**Location:** `/mnt/pool01/dockerapps/caddy/` \
**Network:** `dockerapps-net` (Static IP: `172.20.0.23`) \
**Ports:** `80` & `443` (Directly exposed to Host) \

This service is the **"Front Door"** of the server. It handles all incoming traffic from the public internet, secures it with SSL, filters it through security layers (GeoIP + CrowdSec), and routes it to the correct internal service.

-----

## 1\. The Custom Build Strategy (`Dockerfile`)

Unlike other services where we pull a standard image, Caddy requires a **custom build**. This is because the standard Caddy image does not include the specific plugins we need for our security and automation logic.

**The Build Recipe:**

```dockerfile
FROM caddy:2-builder AS builder

RUN xcaddy build \
    --with github.com/caddy-dns/cloudflare \       # For SSL DNS Challenges & DDNS
    --with github.com/mholt/caddy-dynamicdns \     # For updating home IP (DDNS)
    --with github.com/hslatman/caddy-crowdsec-bouncer \ # For IP Reputation Blocking
    --with github.com/porech/caddy-maxmind-geolocation  # For Geo-Blocking

FROM caddy:latest
COPY --from=builder /usr/bin/caddy /usr/bin/caddy
```

**File:** [`Dockerfile`](/caddy/Dockerfile)

-----

## 2\. Container Configuration

The Compose file orchestrates the build and runtime environment.

**Key Configuration Points:**

  * **Network:** Uses `dockerapps-net` with a Static IP (`.23`) so other containers can trust it as a known proxy.
  * **Ports:** Maps `80:80` and `443:443` directly to the host to handle incoming web traffic.
  * **Volumes:**
      * **`./logs`**: Critical for CrowdSec (the "Brain") to read the access logs generated here.
      * **`./maxmind`**: Now mounts the shared folder from the auto-updater instead of a static file.

**File:** [`compose`](/caddy/compose.yml)

-----

## 3\. Configuration Logic (`Caddyfile`)

The `Caddyfile` is the brain of the proxy. It uses a "Global Options" block for server-wide settings and "Site Blocks" for specific domains.

### **A. Global Options**

  * **Dynamic DNS:** Automatically updates the A-records for subdomains to match the home IP.
        * **⚠️ IPv4 Only:** We explicitly set `versions ipv4`.
        * **Reason:** Without this, the plugin detects the container's private IPv6 address (e.g., `2001:db8...`) and pushes it to Cloudflare. Mobile phones (on 5G/LTE) prefer IPv6, try to connect to this unreachable private address, and fail to load the Jellyfin App.

        ```caddy
            # 1. Dynamic DNS
            dynamic_dns {
                provider cloudflare {env.CLOUDFLARE_API_TOKEN}
                domains {
                    {$ROOT_DOMAIN} jellyfin requests gotify logs ws-logs
                }
                # CRITICAL: Disable IPv6 to prevent mobile app connection failures
                versions ipv4
            }
        ```


  * **CrowdSec:** Connects to the CrowdSec "Brain" container (`http://crowdsec:8080`) to fetch ban lists.
  * **Logging:** Writes internal Caddy system logs to `caddy.log`.

### **B. Site Logic (Repeated for each subdomain)**

Each domain (e.g., `jellyfin.mydomain.xyz`) follows these pipeline:

1.  **SSL Termination (`tls`):**

      * Uses the `dns cloudflare` plugin to solve the Let's Encrypt challenge. This allows us to get certificates even though we are behind a residential IP.

2.  **Geo-Blocking (Layer 1 Security):**

      * **Matcher:** `@geo_sg` checks if the incoming IP is from **Singapore (SG)** using the local MaxMind database.
      * **Filter:** Traffic entering the `handle @geo_sg` block is allowed.
      * **Block:** Any traffic *not* matching this group falls through to the final `handle` block, which responds with **403 Access Denied**.

3.  **CrowdSec Check (Layer 2 Security):**

      * Inside the allowed block, the `route { crowdsec }` directive checks the IP against CrowdSec's database. If the IP is malicious (even if it's from Singapore), the connection is dropped.

4.  **Reverse Proxy (Routing):**

      * Forwards valid traffic to the internal static IP (e.g., `http://jellyfin:8096`).
      * **Header Fixes:**
          * `header_up X-Real-IP {remote_host}`: Tells Jellyfin the user's real IP.

5.  **Optimization (Log Filtering)**
    
     * To prevent **CrowdSec** from burning CPU by analyzing internal traffic (e.g., Homepage widgets checking status every second), I explicitly skip logging for local networks.
     * Configuration Logic:
         * **Define Internal Subnets:** We create a matcher `@internal` for `172.20.0.0/24` (Docker) and `192.168.0.0/16` (LAN).
         * **Skip Logging:** The directive `log_skip @internal` ensures these requests never hit the `access.log` file (remove this if would like to monitor internal traffic too).

## 4\. Environment & Secrets (`.env`)

Sensitive keys and Variables are passed into the container at runtime, keeping the config files safe for version control.

  * **`CLOUDFLARE_API_TOKEN`:** Used for DDNS updates and SSL challenges.
  * **`CROWDSEC_API_KEY`:** Generated from the CrowdSec container to authorize the bouncer.
  * **`ROOT_DOMAIN`:** Used to replace the root domain.
  * **`GoAccess Username & Password`:** Used For basic auth in Caddyfile for logs.mydomain.xyz
  * **`MAXMIND ACCOUNT ID & KEY`:** For allowing auto refresh of GeoIP database upstream
  
**File:** [`.env.example`](/caddy/.env.example)

----

## 4\. Maintenance Commands

**To Rebuild (Required if adding plugins):**

```bash
cd /mnt/pool01/dockerapps/caddy
docker compose build
docker compose up -d --force-recreate
```

[**Script for Auto-Build and Update xcaddy**](/scripts/update-build-xcaddy.sh)

**To Reload Config (Zero Downtime):**

```bash
docker compose exec caddy caddy reload --config /etc/caddy/Caddyfile
```

**To View Access Logs:**

```bash
tail -f /mnt/pool01/dockerapps/caddy/logs/access.log
```

-----

# 📊 Service: GoAccess (The Logs Dashboard)

**Role:** Real-time Log Analytics  
**Interface:** WebSocket Dashboard  
**Location:** `/mnt/pool01/dockerapps/caddy/goaccess`

GoAccess provides a visual dashboard of the `access.log` file generated by Caddy. It runs in "Real-Time" mode, which means it opens a WebSocket connection to the browser to push updates live.

## 1\. The "Split-Domain" Strategy

I encountered a significant security/usability conflict during setup. I wanted the dashboard to be **Password Protected** (BasicAuth), but browsers do not support sending Authentication headers over WebSocket connections easily, often leading to connection failures or login loops.

**The Solution:** I split the service into two distinct subdomains in Caddy.

1.  **`logs.mydomain.xyz` (The Viewer):**

      * **Protected:** Yes (BasicAuth + GeoIP).
      * **Function:** Serves the static HTML file (`index.html`).
      * **User Experience:** You must enter a password to see this page.

2.  **`ws-logs.mydomain.xyz` (The Data Stream):**

      * **Protected:** No (Open, but hidden).
      * **Function:** Pure WebSocket stream.
      * **Security:** Protected by **GeoIP only**. Since the URL is not guessed easily and only returns raw data packets to the specific HTML viewer, this is an acceptable trade-off for functionality.

## 2\. Solving the "400 Bad Request" (The Origin Fix)

The hardest part of this deployment was a persistent **400 Bad Request** error during the WebSocket handshake.

  * **The Cause:** GoAccess is strict about Cross-Origin Resource Sharing (CORS). The browser was loading the page from `https://logs.mydomain.xyz` but trying to connect to a WebSocket on `wss://ws-logs.mydomain.xyz`. GoAccess rejected this mismatch.
  * **The Fix:** I learnt that I had to explicitly tell GoAccess to trust the dashboard URL using the `--origin` flag.

**Correct Command in `compose.yml`:**

```yaml
    command: >
      /var/log/caddy/access.log
      --log-format=CADDY
      --real-time-html
      --addr=0.0.0.0
      --port=7890
      --output=/srv/report/index.html
      --db-path=/srv/data
      --persist
      --restore
      --geoip-database=/srv/maxmind/GeoLite2-Country.mmdb
      --ws-url=wss://ws-logs.${ROOT_DOMAIN}:443
      --origin='https://logs.${ROOT_DOMAIN}'  <-- CRITICAL FIX
```

## 3\. Folder Structure & Permissions

GoAccess requires persistence to avoid losing history on restart, and it needs a place to write the HTML report that Caddy can read.

**Required Folder Structure:**

```bash
/mnt/pool01/dockerapps/caddy/
├── goaccess/
│   ├── data/       # (Stores internal DB files)
│   └── html/       # (Stores the generated index.html)
```

**Volume Mapping:**

  * **Caddy:** Mounts `./goaccess/html:/srv/goaccess-report` (ReadOnly) to serve the HTML file to the user.
  * **GoAccess:** Mounts `./goaccess/html:/srv/report` (ReadWrite) to update the HTML file.

## 4\. Caddy Configuration for Split-Brain

We use two separate blocks in the `Caddyfile` to handle the split domains.

**Block 1: The Viewer (Protected)**

```caddy
logs.{$ROOT_DOMAIN} {
    # ... TLS & GeoIP ...
    handle @geo_sg {
        basicauth {
            {$LOGS_USER} {$LOGS_PASS_HASH}
        }
        root * /srv/goaccess-report
        file_server
    }
}
```

**Block 2: The Stream (Open)**

```caddy
ws-logs.{$ROOT_DOMAIN} {
    # ... TLS & GeoIP ...
    handle @geo_sg {
        # Proxies directly to the container port 7890
        reverse_proxy goaccess:7890
    }
}
```

## 5\. Verification

1.  Visit `https://logs.mydomain.xyz`.
2.  Open Developer Tools (F12) -\> Network -\> WS. We should see a status **101 Switching Protocols** and to check out the origin.