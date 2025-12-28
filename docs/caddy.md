# Service: Caddy (Reverse Proxy)

**Version:** 3.1 (Snippets & Authentik Integration)

## 1. Architecture Overview

| Service       | Role                      | Key Function                                                                        |
| :------------ | :------------------------ | :---------------------------------------------------------------------------------- |
| **Caddy**     | **Reverse Proxy**         | The "Front Door". Handles SSL, Geo-Blocking (Layer 1), and Traffic Routing.         |
| **CrowdSec**  | **Intrusion Detection**   | The "Brain". Reads logs, detects attacks, and instructs Caddy to ban IPs (Layer 2). |
| **MaxMind**   | **GeoIP**                 | Provides Geo-Data for Caddy (blocking) and GoAccess (mapping). Auto-updates weekly. |
| **Authentik** | **Identity Provider**     | Centralized SSO for protecting internal services.                                   |

---
</br>

# Service: MaxMind (GeoIP Provider)

**Role:** Geo-IP Database Provider  
**Mechanism:** Sidecar Auto-Updater  
**Location:** `/mnt/pool01/dockerapps/caddy/maxmind`

Instead of manually downloading `.mmdb` files and uploading them to the server, we use an official MaxMind "Sidecar" container. This container runs on a schedule, downloads the latest databases, and places them into a **Shared Volume** that both Caddy and GoAccess can read.

## 1. The Shared Volume Strategy

This is an architectural decision that I prefer to have. We do not copy files between containers. We mount a single host directory to multiple containers.

- **Host Path:** `./maxmind` (Relative to the Caddy folder)
- **MaxMind Container:** Writes to `/usr/share/GeoIP`
- **Caddy Container:** Reads from `/etc/caddy/maxmind` (ReadOnly)

## 2. Configuration

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

## 3. First-Run Setup & Credentials

To enable this, we registered a free account at MaxMind and generated a License Key. These secrets are stored in the `.env` file.

- **Note:** On the very first run, Caddy might fail to start because the `.mmdb` file doesn't exist yet. The fix is to let the MaxMind container run for \~30 seconds to finish the download, then restart Caddy.

---
</br>

# Service: Caddy (Secure Reverse Proxy)

**Location:** `/mnt/pool01/dockerapps/caddy/` \
**Network:** `dockerapps-net` (Static IP: `172.20.0.23`) \
**Ports:** `80` & `443` (Directly exposed to Host)

This service is the **"Front Door"** of the server. It handles all incoming traffic from the public internet, secures it with SSL, filters it through security layers (GeoIP + CrowdSec), and routes it to the correct internal service.

---

## 1. The Custom Build Strategy (`Dockerfile`)

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

---

## 2. Container Configuration

The Compose file orchestrates the build and runtime environment.

**Key Configuration Points:**

- **Network:** Uses `dockerapps-net` with a Static IP (`.23`) so other containers can trust it as a known proxy.
- **Ports:** Maps `80:80` and `443:443` directly to the host to handle incoming web traffic.
- **Volumes:**
  - **`./logs`**: Critical for CrowdSec (the "Brain") to read the access logs generated here.
  - **`./maxmind`**: Now mounts the shared folder from the auto-updater instead of a static file.

**File:** [`compose`](/caddy/compose.yml)

---

## 3. Configuration Logic (`Caddyfile`) & Snippets

The `Caddyfile` uses **Snippets** to define reusable logic blocks. This avoids repetition and ensures consistency across all subdomains.

**File:** [`Caddyfile`](/caddy/Caddyfile)

### A. Global Options & Dynamic DNS

- **Dynamic DNS:** Automatically updates the A-records for subdomains to match the home IP. We explicitly set `versions ipv4` to prevent IPv6 connection issues on mobile networks.
- **CrowdSec:** Connects to the CrowdSec "Brain" container (`http://crowdsec:8080`) to fetch ban lists.

### B. Snippets (The "Building Blocks")

We define three core snippets that are imported into our site blocks:

#### 1. `(logging)` - Log Management

Handles log formatting and optimization.

- **Internal Bypass:** Skips writing logs for local traffic (`172.20.0.0/24`, `192.168.0.0/16`) to save disk space and reduce noise for CrowdSec.
- **Format:** JSON (required for CrowdSec parsing).

#### 2. `(security)` - The Defense Layer

- **Geo-Block:** Instantly rejects any IP **NOT** from Singapore (SG) using the local MaxMind database.
- **CrowdSec:** If the IP passes the geo-check, it is checked against the CrowdSec blocklist.

#### 3. `(authentik)` - The Doorman

- **Forward Auth:** Forwards the request to Authentik (`http://authentik-server:9000`) for verification.
- **Headers:** detailed header copying to pass user info to the downstream app.

### C. Site Logic (How it comes together)

Each domain simply "imports" the necessary logic.

**Example: Protected Service (Jellyseerr)**

```yaml
requests.{$ROOT_DOMAIN} {
    tls { ... }

    import logging      # 1. Enable Logging
    import security     # 2. Check GeoIP & CrowdSec
    import authentik    # 3. Require Login

    reverse_proxy http://jellyseerr:5055
}
```

**Example: Complex Service (Gotify with API Bypass)**

Gotify is unique because the Android App cannot handle the Authentik login flow. We must allow API paths to bypass Authentik while protecting only the Web UI.


```yaml
gotify.{$ROOT_DOMAIN} {
    import logging
    import security # GeoIP + CrowdSec are still enforced for EVERYONE

    # 1. Define API paths (Bypass Authentik)
    @api {
        path /message* /application* /client* /stream* /plugin* /current* /version* /static*
    }

    # 2. Handle API calls (Direct Proxy)
    handle @api {
        reverse_proxy http://gotify:80
    }

    # 3. Handle Web UI (Require Authentik)
    handle {
        import authentik
        reverse_proxy http://gotify:80
    }
}

```

---

## 4. Authentik Service & Integration

We expose Authentik's own interface so users can log in.

**Domain:** `auth.{$ROOT_DOMAIN}`

```yaml
auth.{$ROOT_DOMAIN} {
    tls { ... }

    # We import security (GeoIP + CrowdSec) but NOT authentik
    # (Authentik cannot protect itself!)
    import security

    reverse_proxy http://authentik-server:9000
}
```

---

## 5. Maintenance Commands

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

---