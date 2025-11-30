# ☁️ Cloudflare Configuration

**Service:** Cloudflare DNS & API \
**Role:** DNS Management, DDNS Updates, SSL Challenges \
**Related Service:** Caddy Reverse Proxy

This details the specific configuration required on the Cloudflare Dashboard to generate a secure, functional API Token for Caddy.

## 1\. API Token Creation Strategy

We use a **Scoped API Token**, not the Global API Key. This is a security best practice, if this token is leaked, it can only affect DNS records for one specific domain, not our entire Cloudflare account.

### **Step-by-Step Workflow**

1.  **Log in** to the [Cloudflare Dashboard](https://dash.cloudflare.com/).
2.  Click the **User Icon** (top right) \> **My Profile**.
3.  Select **API Tokens** from the left sidebar.
4.  Click the **Create Token** button.
5.  Find the **"Edit zone DNS"** template and click **Use template**.

### **Permissions Configuration (CRITICAL)**

The default template is *insufficient* for our setup because the `caddy-dynamicdns` plugin requires the ability to "Read" the Zone metadata to find the Zone ID.

We must modify the permissions list to match this **exact** configuration:

| Permission Type | Permission Name | Access Level | Purpose |
| :--- | :--- | :--- | :--- |
| **Zone** | **DNS** | **Edit** | Allows Caddy to update `A` records (DDNS) and create `TXT` records (SSL). |
| **Zone** | **Zone** | **Read** | **Critical Fix:** Allows Caddy to lookup the "Zone ID" for `mydomain.xyz`. |

*(Note: If `Zone:Zone:Read` is missing, Caddy will fail with `expected 1 zone, got 0` error).*

### **Zone Resources**

Restrict this token so it cannot touch any other domains we might own.

  * **Operator:** `Include`
  * **Type:** `Specific zone`
  * **Value:** `mydomain.xyz`

### **Finalize**

1.  Click **Continue to summary**.
2.  Click **Create Token**.
3.  **Copy the token immediately.** You will never see it again.

-----

## 2\. DNS Records Setup

These records are "Grey Clouded" (DNS Only) to bypass Cloudflare's proxy and allow direct streaming performance.

| Type | Name | Content | Proxy Status | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| **A** | `jellyfin` | `1.1.1.1` (Placeholder) | **DNS Only** | Media Streaming |
| **A** | `requests` | `1.1.1.1` (Placeholder) | **DNS Only** | Jellyseerr |
| **A** | `gotify` | `1.1.1.1` (Placeholder) | **DNS Only** | Notifications |

*(Note: Caddy's `dynamic_dns` module will automatically update the `1.1.1.1` IP to our actual home IP).*

### **⚠️ Critical: Delete All AAAA (IPv6) Records**

We must **manually delete** any AAAA records for these subdomains.

**The "Mobile Network" + "Android/iOS App" Reason:**

  * **The Problem:** 4G/5G mobile networks are "IPv6-First." If an AAAA record exists, Android/iOS will try to connect via IPv6 by default.
  * **The Failure:** If our Docker host's IPv6 routing is imperfect (common with residential ISPs), the connection will hang and fail. The Jellyfin app will report "Connection Cannot Be Established."
  * **The Fix:** By deleting AAAA records, we force the phone to use the robust **IPv4** route, which guarantees connectivity.

-----

## 3\. Secret Management

The generated API token is stored in the `caddy` stack's environment file.

**File:** `/mnt/pool01/dockerapps/caddy/.env`

```bash
CLOUDFLARE_API_TOKEN=<PASTE_YOUR_TOKEN_HERE>
```

