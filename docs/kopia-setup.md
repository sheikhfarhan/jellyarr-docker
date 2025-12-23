# 🛡️ Kopia Backup Strategy (Docker + Cloudflare R2)

## 1. Objective

Deploy a robust, encrypted, and deduplicated backup solution (**Kopia**) that:

1. Protects the "Brain" of the server (`/dockerapps` configs, databases, and compose files).
2. Offloads data to **Cloudflare R2** (S3-Compatible).
3. Utilizes a `.kopiaignore` policy to exclude junk (logs, cache, media).

## 2. Architecture

* **Kopia Host:** Runs as a Docker container at `/mnt/dockerapps/kopia`
* **Source:** `/mnt/pool01/dockerapps` (Mounted Read-Only to ensure backup integrity).
* **Destination:** Cloudflare R2 Bucket (Object Storage).
* **Encryption:** Client-side encryption (AES-256) before data leaves the server.

## 3. Critical Configuration Details

### A. The "Zero-Trust" Storage (Cloudflare R2)

We use Cloudflare R2 because it offers **S3 Compatibility**.

**R2 Connection Requirements:**

* **Endpoint:** `https://<CLOUDFLARE_ACCOUNT_ID>.r2.cloudflarestorage.com`
* **Bucket Name:** `media-server-backups` (Example)
* **Access Key ID:** Generated in R2 Dashboard.
* **Secret Access Key:** Generated in R2 Dashboard.

### B. The Exclusion Logic (`.kopiaignore`)

We place a `.kopiaignore` file at the **root** of our source directory (`/mnt/pool01/dockerapps/.kopiaignore`). This acts exactly like a `.gitignore`.

**Critical Exclusions Implemented:**

* `**/transcodes/`, `**/cache/**`, `**/.cache/**` & `**/MediaCover/`: Prevents backing up TBs of generated thumbnails or temp video files.
* `**/*.log`: Prevents backing up useless text logs.
* `**/crowdsec/hub/`: Prevents backing up downloaded ban lists (which can be re-downloaded).
* `.git/`: Ignores version control history inside sub-containers.

---

## 4. Deployment Guide

### Step 1: Cloudflare R2 Preparation

1. Log in to Cloudflare Dashboard  **R2**.
2. **Create Bucket:** Name it (e.g., `cachyos-dockerapps`).
3. **Manage R2 API Tokens**  **Create API Token**.
    * **Permissions:** `Object RW` (Read/Write).
    * **TTL:** `Forever`.
4. **Copy** the Access Key ID, Secret Access Key, and the Endpoint URL.

![](/assets/cloudflare-r2-token.png)

### Step 2: The Ignore File

Create the ignore file at the *root* of the source directory so Kopia respects it immediately.

**File:** [HERE](/.kopiaignore)

### Step 3: Docker Compose Configuration

```yaml
networks:
  dockerapps-net:
    external: true

services:
  kopia:
    image: kopia/kopia:latest
    container_name: kopia
    hostname: kopia
    networks:
      dockerapps-net:
        ipv4_address: 172.20.0.33
        ipv6_address: 2001:db8:abc2::33
    ports:
    # Expose locally for setup, then close it once Caddy is ready
      - 51515:51515
    # Enable FUSE for mounting snapshots (Optional but recommended)
    cap_add:
      - SYS_ADMIN
    devices:
      - /dev/fuse:/dev/fuse
    environment:
      - TZ=${TZ} 
      # This is the password to login to the Web UI
      - KOPIA_SERVER_USERNAME=${KOPIA_SERVER_USERNAME}
      - KOPIA_SERVER_PASSWORD=${KOPIA_SERVER_PASSWORD}
      # REPOSITORY ENCRYPTION KEY (CRITICAL)
      # This MUST match the encryption password we created in the UI setup step.
      # If this is missing, Kopia cannot start.
      - KOPIA_PASSWORD=${KOPIA_REPO_PASSWORD}
    volumes:
      # 1. Kopia State (Config & Cache)
      - ./config:/app/config
      - ./cache:/app/cache
      - ./logs:/app/logs
      # 2. SOURCE DATA (Mounting our DockerApps Pool)
      # We mount it to /source so Kopia sees the whole structure
      - /mnt/pool01/dockerapps:/source/dockerapps:ro
      # This is for when we want to restore to a particular folder first
      - /home/sfarhan/kopia-restores:/restore-target

    # Start Kopia in Server Mode
    command:
      - server
      - start
      - --insecure             # Allow HTTP (since we will use internal network -> Caddy later)
      - --address=0.0.0.0:51515
      - --override-hostname=mediaserver # Keeps host consistent in snapshots
      - --disable-csrf-token-checks
    restart: unless-stopped

```

### Step 4: Repository Initialization (First Run)

The container will start, but it won't be connected to R2 yet. We must initialize the repository.

1. Navigate to `http://172.20.0.35:51515` (or access via Reverse Proxy if Caddy setup is done).
2. Login with `admin` / `${KOPIA_SERVER_PASSWORD}`.
3. **Setup Repository**  Select **Amazon S3 Compatible**.
4. **Enter R2 Details:**
* **Endpoint:** `<ACCOUNT_ID>.r2.cloudflarestorage.com`
* **Access Key ID:** `<YOUR_KEY>`
* **Secret Access Key:** `<YOUR_SECRET>`
* **Bucket:** `cachyos-dockerapps`
* **Region:** `auto` (Cloudflare ignores region, but R2 usually expects 'auto' or 'us-east-1').

5. **Encryption Password:** Set a strong master password. **If lost, data is unrecoverable.** This password will be part of the compose file under `- KOPIA_PASSWORD=${KOPIA_REPO_PASSWORD}`**

### Step 5: Policy Configuration

Once connected, configure the policy for the `/source` directory.

* **Snapshot Frequency:** as needed
* **Retention (Keep):**
* Latest: `10`
* Hourly: `24`
* Daily: `7`
* Weekly: `4`
* Monthly: `12`
* Annual: `1`

* **Compression:** `zstd-fastest` (Good balance for text/databases).

---

## 5. Disaster Recovery Drill

To verify the setup, simulate a restoration.

**The Test:**

1. Spin up a fresh VM.
2. Install Kopia (Docker).
3. Connect to the **Existing Repository** (R2) using the config from Step 1.
4. Mount a restoration folder.
5. Run:

```bash
kopia snapshot restore <SNAPSHOT_ID> /restore-target
```
6. Verify `docker compose up -d` works in the restored folder.