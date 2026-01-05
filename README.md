# 🐳 Media Server (Jellyfin + \*Arr Stack + Caddy)

> **"A fully automated media stack running on Arch Linux (CachyOS)."**

![Status](https://img.shields.io/badge/Status-Production-success)
![OS](<https://img.shields.io/badge/OS-CachyOS_(Arch)-blue>)
![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker&logoColor=white)
![Security](https://img.shields.io/badge/Security-CrowdSec_%2B_Authentik-red)

This repository documents the architecture and configuration of a self-hosted media server. Unlike standard "copy-paste" stacks, this system features a **custom "Split-Network" architecture** that isolates P2P traffic within a VPN bubble while maintaining direct access for media streaming and management.

![homepage dashboard](/assets/homepage-dashboard1.png)

---

## Key Features

### 1. 🛡️ The "Two-Zone" Network

We physically separate the network stacks.

- **Zone 1 (Trusted App Net):** Services like Jellyfin, Radarr, and Caddy run on a custom bridge (`172.20.0.0/24`) with **Static IPs** for reliability.
- **Zone 2 (VPN Bubble):** Download clients (qBittorrent, Transmission) have **NO** IP address of their own. They share the network stack of a `gluetun` container, forcing 100% of bytes through the AirVPN WireGuard tunnel.

### 2. ⚡ "Atomic Moves" (Hardlinks)

Storage is efficient but (as per for my use-case and preference), no redundancies.

- By mapping the host's LVM volume (`/mnt/pool01/media`) to the exact same path (`/media`) inside every container, we utilize **Hardlinks**.
- A 50GB remix file moving from "Downloads" to "Library" takes **0 seconds** and **0 extra bytes** of disk space.

### 3. 🔐 Defense-in-Depth

Layering security elements, since we do have exposed services to the internet.

- **Layer 1:** **Firewalld** blocks containers from scanning our home LAN (`192.168.x.x`).
- **Layer 2:** **Caddy** acts as the ingress, backed by **GeoIP** (Singapore Only) blocking.
- **Layer 3:** **CrowdSec** acts as the "Brain," reading logs and banning malicious IPs automatically.
- **Layer 4:** **Authentik** provides centralized SSO for interfaces.

---

## 🖥️ System Specifications

| Component   | Detail                                   |
| :---------- | :--------------------------------------- |
| **OS**      | CachyOS (Arch Linux Optimized)           |
| **MOBO**    | X870 Asrock Pro Rs                       |
| **CPU**     | AMD Ryzen 5 7600X                        |
| **RAM**     | 32GB DDR5                                |
| **GPU**     | Radeon RX 5600 XT (Transcoding / SR-IOV) |
| **Storage** | 2x 1TB NVMe LVM Pool (`/mnt/pool01`) + 1 x 500GB Crucial SSD for VMs   |
| **Network** | Marvell AQC113C 10GbE                    |

---

## 📚 Documentation Index

Click the links below for deep-dives into specific components of the stack.

### 🚀 Getting Started

| Topic                                            | Description                                                                                      |
| :----------------------------------------------- | :----------------------------------------------------------------------------------------------- |
| **[Deployment Guide](docs/from-zero.md)**        | **Read This First.** The "Invisible" Host-OS setups required before running `docker compose up`. |
| **[Folder Structure](docs/folder-structure.md)** | The "Golden Tree" directory map ensuring Atomic Moves work.                                      |
| **[Network Architecture](docs/networking.md)**   | Understanding the `dockerapps-net` vs. `service:gluetun` design.                                 |
| **[Storage & LVM](docs/storage.md)**             | How the NVMe pool is managed and mounted.                                                        |

### 🧩 Application Stacks

| Stack                 | Services                             | Documentation                                |
| :-------------------- | :----------------------------------- | :------------------------------------------- |
| **Media Core**        | Jellyfin, Jellyseerr                 | **[Docs](docs/jellyfin-stack.md)**           |
| **Automation Engine** | Gluetun, Radarr, Sonarr, Bazarr      | **[Docs](docs/vpn-arr-automation-stack.md)** |
| **Indexers**          | Prowlarr, FlareSolverr, Jackett      | **[Docs](docs/indexers.md)**                 |
| **Notifications**     | Gotify, Webhooks                     | **[Docs](docs/gotify.md)**                   |
| **Management**        | Portainer, Dozzle, WUD, Socket Proxy | **[Docs](docs/utilities.md)**                |

### 🔒 Security & Connectivity

| Service        | Role                             | Documentation                         |
| :------------- | :------------------------------- | :------------------------------------ |
| **Caddy**      | Reverse Proxy, SSL, Geo-Blocking | **[Docs](docs/caddy.md)**             |
| **VoidAuth**   | Identity Provider (SSO), 2FA     | **[Docs](docs/sso-authentication.md)**|
| **CrowdSec**   | IPS / Intrusion Detection System | **[Docs](docs/crowdsec.md)**          |
| **Firewalld**  | Host Firewall Rules              | **[Docs](docs/security-firewall.md)** |
| **Cloudflare** | DNS & API Management             | **[Docs](docs/cloudflare-setup.md)**  |

### 📊 Monitoring & Maintenance

| Topic               | Description                    | Link                                |
| :------------------ | :----------------------------- | :---------------------------------- |
| **GoAccess**        | Real-time Access Log Analytics | **[Docs](docs/goaccess.md)**        |
| **Beszel**          | Lightweight Server Monitoring  | **[Docs](docs/beszel-setup.md)**    |
| **Kopia**           | Offsite Backups                | **[Docs](docs/kopia-setup.md)**     |
| **Troubleshooting** | Common errors and fixes        | **[Docs](docs/troubleshooting.md)** |

---

## 🛠️ Management Scripts

Convenience scripts located in `/scripts` to manage the stack.

- **Start/Restart All Stacks:**

  ```bash
  ./scripts/start-stacks.sh
  ```

  _Forces recreation of containers to ensure config changes are picked up._

- **Update All Images:**

  ```bash
  ./scripts/pull-all.sh
  ```

---

## 📜 Static IP Allocation Map

A quick reference for the `172.20.0.0/24` subnet.

<details>
<summary>Click to Expand</summary>

| IP Address    | Service       | Stack       | Port   |
| :------------ | :------------ | :---------- | :----- |
| `172.20.0.1`  | **Gateway**   | -           | -      |
| `172.20.0.10` | Jellyfin      | `jellyfin`  | 8096   |
| `172.20.0.11` | Gluetun       | `vpn-arr`   | -      |
| `172.20.0.12` | Jellyseerr    | `jellyfin`  | 5055   |
| `172.20.0.13` | Radarr        | `vpn-arr`   | 7878   |
| `172.20.0.14` | Sonarr        | `vpn-arr`   | 8989   |
| `172.20.0.15` | Bazarr        | `vpn-arr`   | 6767   |
| `172.20.0.16` | Gotify        | `gotify`    | 80     |
| `172.20.0.17` | Arcane        | `utilities` | 3552   |
| `172.20.0.19` | Profilarr     | `vpn-arr`   | 5000   |
| `172.20.0.20` | Prowlarr      | `vpn-arr`   | 9696   |
| `172.20.0.21` | FlareSolverr  | `vpn-arr`   | 8191   |
| `172.20.0.23` | Caddy         | `caddy`     | 80/443 |
| `172.20.0.24` | CrowdSec      | `crowdsec`  | 8080   |
| `172.20.0.25` | Homepage      | `utilities` | 3000   |
| `172.20.0.26` | Dozzle        | `utilities` | 8080   |
| `172.20.0.27` | WUD           | `utilities` | 3001   |
| `172.20.0.28` | Socket Proxy  | `utilities` | 2375   |
| `172.20.0.29` | GoAccess      | `goaccess`  | 7890   |
| `172.20.0.31` | Beszel        | `utilities` | 8090   |
| `172.20.0.37` | VoidAuth      | `caddy`     | 3002  |

</details>

---

## 📸 Gallery

<details>
<summary><b>Homepage Dashboard</b></summary>

![homepage dashboard](/assets/homepage-dashboard1.png)

</details>

<details>
<summary><b>VoidAuth Login</b></summary>

![VoidAuth landing](/assets/voidauth-landingpage.png)

</details>
