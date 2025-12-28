# 📊 Service: GoAccess - Logging Analytics

**Location:** `/mnt/pool01/dockerapps/logging` \
**Network:** `dockerapps-net` \
**URL:** `http://192.168.0.100:7890` (LAN Only / "Dark Mode")

GoAccess is a real-time web log analyzer that provides a visual dashboard for the Caddy reverse proxy.

> **⚠️ Architecture Note:** Unlike standard setups, this stack is **decoupled** from the main Caddy gateway. It runs in its own folder/compose file with a dedicated frontend and backend.

---

## 1. Docker Configuration

This stack consists of two separate containers working in tandem to overcome the "Chef vs. Waiter" problem.

**File:** [`compose.yml`](/goaccess/compose.yml)

| Service | Container Name | Port (Host) | Role | Description |
| :--- | :--- | :--- | :--- | :--- |
| **GoAccess** | `goaccess` | `7891` | **Backend** | Analyzes logs and streams live data via WebSocket. |
| **Report Server** | `goaccess-webui` | `7890` | **Frontend** | A lightweight Caddy instance that serves the static HTML dashboard. |

---

## 2. Architecture & Traffic Flow

To support **Real-Time Updates** without exposing the dashboard to the public internet, we use a split-port architecture:

1.  **The "Visit" (Frontend):**
    * **User Action:** We visit `http://192.168.0.100:7890` in our browser.
    * **Handler:** The `goaccess-webui` container serves the `index.html` file.
    * *Note:* This file is just a static "skeleton" of the dashboard.

2.  **The "Stream" (Backend):**
    * **System Action:** The JavaScript inside `index.html` wakes up and opens a data pipe.
    * **Handler:** It connects to `ws://192.168.0.100:7891` (The `goaccess` container).
    * **Result:** Live log data is pushed to the browser via WebSocket.

---

## 3. Configuration Guide (Crucial Flags)

The `goaccess` command in `compose.yml` uses specific flags to make this LAN-only setup work. **Do not change these** unless the network topology changes.

| Flag | Value | Purpose |
| :--- | :--- | :--- |
| `--real-time-html` | `Enabled` | Tells GoAccess to generate a file that listens for updates. |
| `--ws-url` | `ws://192.168.0.100:7891` | **Critical:** Defines the WebSocket endpoint. Must use `ws://` (Unencrypted) and the backend port `7891`. |
| `--origin` | `http://192.168.0.100:7890` | **Security:** Strict Allow-list. Only allows connections initiated from the Frontend Dashboard URL. |

### Volume Mounts (Dependencies)
This stack relies on files located in the sibling `../caddy` directory:
* **Logs:** `../caddy/logs:/var/log/caddy:ro` (Read-only access to access.log)
* **MaxMind:** `../caddy/maxmind:/srv/maxmind:ro` (Shared GeoIP database)

---

## 4. Troubleshooting

### 🔴 WebSocket Connection Failed
* **Symptoms:** Dashboard loads but shows a red disconnected icon.
* **Cause:** The browser cannot reach Port `7891`.
* **Fix:** Ensure `--ws-url` uses `ws://` (not `wss://`) and that port `7891` is exposed in `compose.yml`.

### 🔴 HTTP Error 400 (Bad Request)
* **Symptoms:** Console shows `Unexpected response code: 400`.
* **Cause:** Origin Mismatch. The browser is visiting from an IP/URL that doesn't match the `--origin` flag.
* **Fix:** Update `--origin` in `compose.yml` to match our exact browser URL (e.g., `http://192.168.0.100:7890`).

### 🔴 Dashboard Not Updating (Stale File)
* **Symptoms:** Configuration changes (like ports) aren't reflected in the browser.
* **Cause:** GoAccess didn't overwrite the old `index.html`.
* **Fix:**
    1.  Delete the file: `rm ./html/index.html`
    2.  Restart container: `docker-compose up -d --force-recreate`
    3.  Hard Refresh Browser