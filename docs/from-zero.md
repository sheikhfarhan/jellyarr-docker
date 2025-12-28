## 🚀 Deployment Guide (Zero-to-Hero)

### Phase 1: Host Preparation

*Configure the OS before touching Docker.*

1.  **Install Dependencies:**

    ```bash
    sudo pacman -S docker docker-compose git firewalld
    sudo systemctl enable --now docker firewalld
    ```

2.  **Configure Docker Daemon (for IPv6 & DNS):**

      * **Why:** Enables IPv6 support. I use the subnet `2001:db8:abc1::/64` here for the **Default Bridge** (system-wide), which must be different from our custom network later.
      * **Action:** Create `/etc/docker/daemon.json`:

         ```json
         {
           "ipv6": true,
           "fixed-cidr-v6": "2001:db8:abc1::/64",
           "experimental": true,
           "ip6tables": true,
           "dns": ["1.1.1.1", "8.8.8.8"]
         }
         ```
      * **Apply:** `sudo systemctl restart docker`

3.  **Create the Network Infrastructure:**

      * Creates the `dockerapps-net` custom network with its own isolated IPv6 subnet (`abc2`).

         ```bash
         docker network create \
           --driver=bridge \
           --ipv6 \
           --subnet=172.20.0.0/24 \
           --gateway=172.20.0.1 \
           --subnet=2001:db8:abc2::/64 \
           --gateway=2001:db8:abc2::1 \
           dockerapps-net
         ```

4.  **Configure Firewall (Security & Access):**

      * **Allow:** Web (80/443) and Local Direct Play (8096).
      * **Block:** Prevents Docker containers (`172.20...`) from initiating connections to our Home LAN (`192.168...`), effectively creating a "Software VLAN."

         ```bash
         # 1. Open Required Ports
         sudo firewall-cmd --add-service=http --permanent
         sudo firewall-cmd --add-service=https --permanent
         sudo firewall-cmd --add-port=8096/tcp --permanent

         # 2. Create DOCKER-USER Chain (Prevents errors if Docker hasn't started yet)
         sudo firewall-cmd --permanent --direct --add-chain ipv4 filter DOCKER-USER

         # 3. Add Isolation Rule (Block Docker -> LAN)
         sudo firewall-cmd --permanent --direct --add-rule ipv4 filter DOCKER-USER 0 -s 172.20.0.0/24 -d 192.168.0.0/24 -m conntrack --ctstate NEW -j DROP

         # 4. Apply
         sudo firewall-cmd --reload
         ```

5.  **Identify Host IDs (For .env):**

      * Homepage and \*Arr apps need to know our user/group IDs.

         ```bash
         echo "PUID=$(id -u)"
         echo "PGID=$(id -g)"
         echo "DOCKER_GID=$(getent group docker | cut -d: -f3)"
         ```
    *(Save these numbers for our `.env` file in Phase 2).*

6.  **Cloudflare Preparation (DNS & API):**

    * **Why:** Caddy requires an API token to solve DNS challenges (for automatic SSL certificates) and to verify domain ownership. You also need to point your subdomains to this server’s IP address so Caddy can receive the traffic.
    * **Action 1 (Generate API Token & and Establish Zone DNS Edit and Read):**
    * **Action 2 (Create DNS Records):**
        * Create an **A Record** (IPv4) for *every* subdomain we would define in our Caddyfile (e.g., `jellyfin`, `requests`, `gotify`, `auth`).
    
    * Refer to [cloudflare-setup](/docs/cloudflare-setup.md) documentation for details

### **Why these matter:**

  * **Port 8096:** Ensures my phone can cast/play media without going through the reverse proxy loopback.
  * **Step 5:** Solves the "Permission Denied" error I faced with Homepage and the Widgets part, so I am doing this to get that DOCKER_GID before I even install Homepage\!
  * **Step 6:** If `Zone:Zone:Read` is missing, Caddy will fail with `expected 1 zone, got 0` error).

-----

### Phase 2: Repository & Structure

1.  **Clone Repo:**

    ```bash
    git clone git@github.com:sheikhfarhan/jellyarr-docker.git /mnt/pool01/dockerapps
    ```

2.  **Reconstruct Directories:**
    Run the script in [docs/folder-structure.md](docs/folder-structure.md) to create the empty config folders (e.g., `utilities/homepage/config`, `vpn-arr-stack/gluetun/auth`). 

    The idea is that the folders config/data/store within each of the main sub-folders for each of the services should be created by me/user so that docker root would not create on our behalf, coz if they do, that folder witll have root:root ownership.

3.  **Restore "Ignored" Assets:**

      * **GeoIP Database:** Required for Caddy.

        ```bash
        cd caddy #make sure we are in caddy dir
        wget "https://github.com/P3TERX/GeoLite.mmdb/raw/download/GeoLite2-Country.mmdb"
        sudo chown 1000:1000 GeoLite2-Country.mmdb
        cd ..
        ```

4.  **Create .env files (`.env`):**

      * **Critical:** We must create the `.env` file in **every** service folder that requires one. Refer to .env.example in each of the subfolder for each services/containers.
      
      
-----

### Phase 3: Initialization & Launch

1.  **Bootstrap CrowdSec (Generate Keys):**

      Before starting the full stack, start CrowdSec to generate the keys Caddy and Homepage need.

         ```bash
         # Start just CrowdSec when at crowdsec folder
         docker compose up -d 

         # 1. Generate Caddy Bouncer Key
         docker exec crowdsec cscli bouncers add caddy-bouncer
         # -> Paste this key into caddy/.env for CROWDSEC_API_KEY=

         # 2. Get Homepage Credentials
         # Run this still from /mnt/pool01/dockerapps/crowdsec
         cat config/local_api_credentials.yaml
         # Update HOMEPAGE_VAR_CROWDSEC_USER and _PASS in utilities/.env
         ```

2.  **Run the Startup Script:**

    ```bash
    ./scripts/start-stacks.sh
    ```

3.  **Configure Jellyfin Networking (CRITICAL for Mobile):**

      *Dashboard \> Networking:*
       * **LAN Networks:** `192.168.0.0/24, 172.20.0.0/24` (Enables local playback).
       * **Known Proxies:** `172.20.0.23` (Trusts Caddy).
       * **Published Server URIs:** `all=https://jellyfin.mydomain.xyz` (Fixes Android app connection).

4.  **Configure Portainer:**

      Add Environment -\> Docker Standalone -\> API.
      **URL:** `tcp://172.20.0.28:2375` (Connects via Socket Proxy).

5.  **Continue with Secrets** (`utilities/.env`, `vpn-arr-stack/.env` where needed). eg:

       ```bash
       nano utilities/.env
       # Add: API Keys for Radarr, Sonarr, Jellyfin (now that we have the other services up)
       # Add: Gotify Token
       # Add: Gluetun keys
       # ... 
       ```

    *Refer to .env.example in each of the sub-folder.*

    *I would also need to refer to the [docs](/docs) folder for granular details on specific services.*

### **Verification**

1.  **Check Caddy:**
    ```bash
    docker logs caddy
    ```
    * *Success:* Look for "certificate obtained" and "GeoIP loaded".

2.  **Check VPN (Security):**
    ```bash
    docker logs gluetun
    ```
    * *Success:* Look for "Public IP address is xxx.xxx.xxx.xxx" (Should show a VPN IP/Location, e.g., Netherlands).

3.  **Check External Access (Mobile):**
    * Disconnect phone from Wi-Fi (use 4G/5G).
    * Visit `https://jellyfin.mydomain.xyz`.
    * *Success:* The Jellyfin login page should load securely.
