# 🌐 Network Architecture

## 1\. Overview: The "Two-Zone" Security Model

The server uses a custom "Split-Network" architecture to isolate traffic while maintaining ease of access. This design prevents IP leaks for downloads while ensuring high-performance access for media streaming.

  * **Zone 1: The "App Network" (`dockerapps-net`)**
      * **Purpose:** Trusted, internal communication.
      * **Access:** Containers in this zone can talk to each other and the Caddy reverse proxy.
      * **Internet Access:** Uses the host's standard internet connection (Singapore IP).
        
  * **Zone 2: The "VPN Bubble" (`service:gluetun`)**
      * **Purpose:** Secure, leak-proof tunnel for P2P downloads.
      * **Access:** Containers here have **NO** IP address of their own. They share the network stack of the `gluetun` container.
      * **Internet Access:** All traffic is forced through the AirVPN WireGuard tunnel.
   
-----

### 🛡️ Zone 2: The VPN Automation Bubble

### Provider Selection: AirVPN

We utilize **AirVPN** for this stack because it is one of the few providers that supports **Port Forwarding** and **WireGuard** simultaneously.

### Procurement & Configuration Workflow

1.  Sign Up: Created an account and purchased a subscription at [airvpn.org](https://airvpn.org).
2.  Config Generator:
      * Navigated to **Client Area** \> **Config Generator**.
      * **OS:** Selected "Linux".
      * **Protocol:** Selected **"WireGuard"** (Critical for speed/CPU efficiency).
      * **Server Selection:** Selected **Netherlands** (primary for privacy/speed balance) and **Singapore** (as a low-latency backup).
3.  Key Generation:
      * Generated the configuration.
      * Extracted the **Private Key**, **Preshared Key**, and **Addresses** (IPv4/IPv6) from the generated `.conf` file or UI.
4.  Port Forwarding (Critical):
      * Navigated to **Client Area** \> **Ports**.
      * Generated **two** separate ports:
          * Port A (e.g., `xxxxx`) for qBittorrent.
          * Port B (e.g., `xxxxx`) for Transmission.
      * *Note: These specific port numbers must be entered into the `.env` file and the download clients.*

### Environmental Configuration ([`.env.example`](vpn-arr-stack/.env-example))

This file defines the connection details for the `gluetun` container.

-----

## 2\. Host Networking Configuration

Before Docker containers can communicate or resolve DNS properly, the host system (CachyOS) requires specific configuration adjustments.

### **A. Docker Daemon (`daemon.json`)**

We modify the daemon to enable global IPv6 support and set reliable fallback DNS servers. This fixes common "Connection Refused" errors during container startup.

  * **File Location:** `/etc/docker/daemon.json`
  * **Configuration:**
    ```json
    {
      "ipv6": true,
      "fixed-cidr-v6": "2001:db8:abc1::/64",
      "experimental": true,
      "ip6tables": true,
      "dns": [
        "1.1.1.1",
        "8.8.8.8"
      ]
    }
    ```
  * **Apply Command:** `sudo systemctl restart docker`

### **B. Custom Bridge Network (`dockerapps-net`)**

We create an external bridge network with manually defined subnets. This allows us to assign **Static IPs** to containers, which is critical for Caddy and Homepage reliability.

  * **Creation Command:**
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
-----

## 3\. Static IP Allocation Map

Every service is assigned a permanent IP address to prevent DNS resolution delays and ensure Caddy always finds the correct upstream target.

**Subnet:** `172.20.0.x`

-----

## 4\. Special Networking Logic

### **A. The VPN "Sidecar" Pattern**

  * **Services:** `qbittorrent`, `transmission`
  * **Configuration:** `network_mode: "service:gluetun"`
  * **Workflow:** These containers do not have their own IP. They are "attached" to Gluetun like a sidecar.
      * **Outbound:** All traffic exits via `172.20.0.11` -\> `tun0` interface (VPN).
      * **Inbound:** Ports `8080` and `9091` are mapped on the **Gluetun container**, not the torrent containers.
  * **Healthcheck:** Dependent services wait for Gluetun's internal healthcheck to pass before starting, preventing leaks.

### **B. DNS Resolution Strategy**

  * **General Containers:** Use the host's Docker resolver (forwarding to `1.1.1.1` via `daemon.json`).
  * **VPN Containers:** Use AirVPN's internal DNS (pushed via WireGuard).
  * **Prowlarr:** Explicitly configured with `dns: [1.1.1.1, 8.8.8.8]` in `compose` to ensure it can resolve indexer domains reliably without using the VPN tunnel (avoiding "Bad Neighbor" blocks).

### **C. Caddy Ingress (Reverse Proxy)**

  * **Public Ports:** Ports `80` and `443` are forwarded from the Router -\> Host -\> Caddy Container (`172.20.0.23`).
  * **Internal Routing:** Caddy proxies traffic to internal IPs (e.g., `http://jellyfin:8096`) over the bridge network.
  * **DDNS:** Caddy automatically updates the A-records for the subdomains to match the home public IP.
