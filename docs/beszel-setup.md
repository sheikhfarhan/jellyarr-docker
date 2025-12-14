# 📘 Beszel Monitoring Stack (Docker + LVM Support)

## 1\. Objective

Deploy a lightweight, low-overhead monitoring solution (**Beszel**) that can:

1.  Reside within the `dockerapps-net` internal network.
2.  Route Docker socket traffic via a **Socket Proxy**.
3.  Accurately monitor my **LVM Logical Volumes** (Disk I/O and Usage).

## 2\. Architecture

  * **Beszel Hub:** The dashboard/server. Stores data in a local volume.
  * **Beszel Agent:** The metric collector. Connects to the Hub via internal Docker IP.
  * **Socket Proxy:** Acts as a gatekeeper, allowing the Agent to read Docker stats without mounting the raw `/var/run/docker.sock`.

## 3\. Critical Configuration Details

### A. The "Stateless" Agent

We do not persist agent data. The Agent is configured purely via Environment Variables (`KEY`) and connects to the Hub.

### B. The LVM Mapping Solution (The "Device Mapper" Trick)

Standard volume mounting (e.g., `/mnt/pool01/media`) provides **Disk Usage** (Space) but fails to provide **Disk I/O** (Speed) because the container cannot link the mount path to the underlying kernel device.

**The Fix:**

1.  We found the Kernel Device Name for our LVMs using `lsblk` and `ls -l /dev/mapper`.
      * `dockerapps` LV mapped to `dm-0`
      * `media` LV mapped to `dm-2`
2.  We created empty "anchor" folders (`.beszel`) on the drives to mount safely.
3.  We used the special Beszel mount syntax:
      * `/source/path:/extra-filesystems/<KERNEL_DEVICE_ID>__<PRETTY_NAME>`
      * Documentation from Beszel - https://beszel.dev/guide/additional-disks and https://beszel.dev/guide/common-issues#finding-the-correct-filesystem

### C. Future Proofing (Warning)

If I were to migrate this setup to a new server, **`dm-0` and `dm-2` might change**.
**Before deploying:** Always run:

```bash
ls -l /dev/mapper
```

Check which `dm-X` corresponds to my LVMs and update `compose.yaml` accordingly.

-----

## 4\. Deployment Guide

### Step 0: Create manually the required folders:

Run while in utilities
```bash
mkdir -p beszel/{data,beszel_agent_data}
```

### Step 1: Create Anchor Folders

Run on host to allow safe mounting:

```bash
# Create hidden anchor folders
mkdir -p /mnt/pool01/dockerapps/.beszel
mkdir -p /mnt/pool01/media/.beszel
```

### Step 2: Docker Compose Configuration

Add to our `utilities`stack. Note the static IPs to match our network scheme.

```yaml
services:
  # ... (Socket Proxy service must be running) ...

  # ------------------------------------------------
  # BESZEL HUB (Dashboard)
  # ------------------------------------------------
  beszel-hub:
    image: henrygd/beszel:latest
    container_name: beszel-hub
    hostname: beszel-hub
    networks:
      dockerapps-net:
        ipv4_address: 172.20.0.31
        ipv6_address: 2001:db8:abc2::31
    ports:
      - 8090:8090
    volumes:
      - ./beszel/data:/beszel_data
    restart: unless-stopped

  # ------------------------------------------------
  # BESZEL AGENT (Collector)
  # ------------------------------------------------
  beszel-agent:
    image: henrygd/beszel-agent:latest
    container_name: beszel-agent
    hostname: beszel-agent
    networks:
      dockerapps-net:
        ipv4_address: 172.20.0.32
        ipv6_address: 2001:db8:abc2::32
    environment:
      # Port for the Agent to listen on (Default 45876)
      - LISTEN=45876
      # Secrets provided by Hub (Add System -> Docker)
      - KEY=${MEDIASVR_PUBLIC_KEY}
      - TOKEN=${MEDIASVR_TOKEN}
      # Connection details
      - HUB_URL=http://172.20.0.31:8090
      # Use Socket Proxy for Docker Stats (Security)
      - DOCKER_HOST=tcp://socket-proxy:2375
      # Force the Main Chart to look at my actual CachyOS Root - to change accordingly for new system
      # (This prevents it from accidentally monitoring the container overlay)
      - FILESYSTEM=/dev/nvme0n1p2
      
    volumes:
      # 1. Root Filesystem (Read-Only) - to change accordingly for new system
      # We mount root so the agent can read the stats defined in FILESYSTEM
      - /:/extra-filesystems/nvme0n1p2__CachyOS:ro

      # 2. Docker Apps (dm-0) - to change accordingly for new system
      # Confirmed via lsblk that DockerApps is on this LVM
      - /mnt/pool01/dockerapps/.beszel:/extra-filesystems/dm-0__DockerApps:ro

      # 3. Media (dm-2) - to change accordingly for new system
      # Confirmed via lsblk that Media is on this LVM
      - /mnt/pool01/media/.beszel:/extra-filesystems/dm-2__Media:ro

      # 4. Games Folder (Optional)
      # If I want to monitor this, create the .beszel folder first:
      # mkdir -p /mnt/pool01/games/.beszel
      # Then uncomment the line below
      # - /mnt/pool01/games/.beszel:/extra-filesystems/dm-1__Games:ro

      # Optional: System Bus for systemd monitoring
      - /var/run/dbus/system_bus_socket:/var/run/dbus/system_bus_socket:ro
    restart: unless-stopped
    depends_on:
      - socket-proxy
      - beszel-hub
```

### Step 3: Alerts Setup (Gotify)

Beszel uses the **Shoutrrr** notification library. This means we do not configure a raw HTTP POST request; instead, we use a formatted Connection URL.

### A. Get the Token

1.  Open Gotify Web UI.
2.  Click **Apps** $\rightarrow$ **Create Application**.
3.  Name it `Beszel` and copy the **Token** (e.g., `A-k9L2...`).

### B. Configure Beszel Hub

1.  Open Beszel Dashboard $\rightarrow$ **Settings** $\rightarrow$ **Notifications**.
2.  Click **Add Notification**.
3.  **Name:** `Gotify`
4.  **URL:** Use the Shoutrrr schema:
    ```text
    gotify://gotify:80/<PASTE-YOUR-TOKEN-HERE>/?DisableTLS=yes
    ```
      * `gotify://` tells Beszel to use the Gotify protocol.
      * `gotify:80` targets the container hostname inside the `dockerapps-net` network.
      * Since we are sending to our locally hosted gotify, have to add the /?DisplayTLS=yes at the end. If we are sending to our https:gotify.domain.xyz instead then the input should be `gotify://gotify.domain.xyz/<PASTE-YOUR-TOKEN-HERE>`
5.  **Test:** Should receive a notification immediately.

### C. Recommended Thresholds

Set specific "System" view (Bell icon).

| Resource | Condition | Duration | Reason |
| :--- | :--- | :--- | :--- |
| **Status** | `Status != Up` | `0m` | Immediate alert if server/agent goes offline. |
| **Disk (Docker)** | `Usage > 85%` | `0m` | Clean up images/logs before `dm-0` fills up. |
| **Disk (Media)** | `Usage > 90%` | `0m` | Media drive (`dm-2`) is less critical, can run fuller. |
| **CPU** | `Usage > 90%` | `10m` | Ignore short transcoding spikes; alert on hung processes. |
| **Memory** | `Usage > 95%` | `5m` | Linux caches RAM aggressively; 90% is often normal. |

-----

