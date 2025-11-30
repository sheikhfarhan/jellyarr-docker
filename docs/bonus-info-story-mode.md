# 📖 BONUS INFO: Story Mode: The Lifecycle of a Request

Below traces the technical journey of a media request, detailing the handshakes, protocols, and file operations that occurs from the moment a user clicks "Request" to the moment they press "Play."

### **Chapter 1: The Request (HTTPS & Reverse Proxy)**
**User Action:** You open your phone and visit `https://requests.mydomain.xyz`.

1.  **DNS Resolution:** Your phone queries Cloudflare DNS. Cloudflare sees the record is "Grey Clouded" (DNS Only) and returns your **Home Public IP**.
2.  **The Handshake:** Your phone sends a `TCP SYN` packet to your home router on Port `443`.
3.  **The Doorman (Caddy):** Your router forwards the packet to the **CachyOS Host**, which passes it to the **Caddy Container** (`172.20.0.23`).
4.  **The Security Check:**
    * **GeoIP:** Caddy checks your IP against `GeoLite2-Country.mmdb`. Result: `SG`. **Pass.**
    * **CrowdSec:** Caddy asks the CrowdSec API (`http://crowdsec:8080`). Result: "Clean IP". **Pass.**
5.  **The Handoff:** Caddy terminates the SSL connection and opens a new, unencrypted HTTP connection internally to **Jellyseerr** at `http://172.20.0.12:5055`.
6.  **The UI:** Jellyseerr renders the interface. You search for *"Inception"* and click **Request**.

### **Chapter 2: The Hunt (API & Indexers)**
**System Action:** Jellyseerr needs to find the movie.

1.  **API Call:** Jellyseerr sends a `POST` request via HTTP to **Radarr** (`http://172.20.0.13:7878/api/v3/movie`).
2.  **The Search:** Radarr sees the new movie. It triggers a "Search" command. It talks to **Prowlarr** (`http://172.20.0.20:9696`) using the **Torznab** protocol.
3.  **The Proxy:** Prowlarr has a list of indexers. If an indexer is protected by Cloudflare, Prowlarr forwards the request to **FlareSolverr** (`http://172.20.0.21:8191`), which solves the JavaScript challenge and returns the cookies.
4.  **The Grab:** Radarr receives a list of releases. It evaluates them against Selected Quality Settings and Custom Formats (synced by **Profilarr**). It picks the best release (e.g., a 5GB 1080 Efficient).

### **Chapter 3: The Download (VPN & BitTorrent)**
**System Action:** Downloading the file securely.

1.  **The Dispatch:** Radarr sends the `.torrent` file (or magnet link) to **qBittorrent** via HTTP API (`http://172.20.0.1:8080`). It attaches the category `radarr`.
2.  **The Tunnel:** qBittorrent receives the job. However, qBittorrent has **no direct internet access**. It lives inside the **Gluetun** container's network stack.
3.  **Encapsulation:** qBittorrent initiates a P2P connection. Gluetun intercepts this traffic, encrypts it into **WireGuard** packets, and shoots it out of the `tun0` interface to the **AirVPN** server in the Netherlands.
4.  **The Swarm:** To the outside world, the traffic looks like it's coming from the AirVPN server. The file chunks start flying in, landing in the temporary folder `/media/downloads/incomplete`.

### **Chapter 4: The Atomic Move (Storage & Hardlinks)**
**System Action:** The download finishes.

1.  **Assembly:** qBittorrent reassembles the chunks into `Inception.mkv`. It moves the file to the "Completed" folder: `/media/downloads/radarr/Inception (2010)/`.
2.  **The Signal:** Radarr (which has been polling qBittorrent) sees the status change to "Completed."
3.  **The Magic Trick (Hardlink):**
    * Radarr looks at the file path reported by qBittorrent: `/media/downloads/radarr/...`
    * Radarr knows *its* library path is: `/media/movies/Inception (2010)/`
    * Because both paths start with `/media` (which maps to the same LVM volume `/mnt/pool01/media`), Radarr performs a **Hardlink** (`link()`).
    * **Result:** The file system creates a new "pointer" in the `movies` folder pointing to the *exact same physical data blocks* on the NVMe drive.
    * **Speed:** Instant (0.01 seconds).
    * **Space Used:** 0 bytes extra.

### **Chapter 5: The Premiere (Playback)**
**System Action:** You sit down to watch.

1.  **Notification:** Radarr sends a "Download Complete" webhook to **Jellyfin** (`http://172.20.0.10:8096`), telling it to scan the folder.
2.  **Discovery:** Jellyfin sees the new inode in `/media/movies`. It scrapes metadata (posters, actors) and adds it to the library.
3.  **Playback:** You press "Play" on your TV.
4.  **Direct Stream:** Since you are on the local network, your TV connects directly to Jellyfin. Jellyfin opens the file at `/media/movies/Inception.mkv` and streams the bits directly to your screen.

**Profit.**