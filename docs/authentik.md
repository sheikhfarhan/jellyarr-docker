# 🔐 Service: Authentik (Identity Provider)

**Location:** `/mnt/pool01/dockerapps/authentik` \
**Network:** `dockerapps-net` (Static IP: `172.20.0.35` Server / `172.20.0.36` Worker) \
**URL:** `https://auth.domain.xyz` (Public) / `http://172.20.0.35:9000` (Internal)

## 0. Set Up Caddyfile for a site to "host" the Authentik Instance
Example: auth.domain.com - refer: [caddyfile](/caddy/Caddyfile)

<details close>
   <summary>Show: Landing Page when at auth.domain.xyz / Authentik Instance</summary>

   ![LandingPage](/assets/authentik-landingpage.png)

</details>
</br>

The use-case is mainly for external users to access my publicly-exposed website/domain infront of caddy's reverse proxy. For now, only need to secure the 
`requests.domain.xyz` domain that will bring them to the Jellyseerr service. I setup the `default-authentication-login` stage with a `52 weeks` settings for both `Session Duration` and `Remember Device` (to prevent annoyance).
</br>

For my few others self-hosted services which has public-URL-exposures, will also have the authentik instance securing the entry points.

<details close>
   <summary>Show: My Interface (admin)</summary>

   ![Admin Interface](/assets/authentik-admin-user-interface.png)

</details>

## 1. Docker Configuration

Official Documentation: [`https://docs.goauthentik.io/install-config/install/docker-compose/`](https://docs.goauthentik.io/install-config/install/docker-compose/)

The service is composed of three main containers: the Database (PostgreSQL), the Server (Management/API), and the Worker (Background tasks).

**File:** [`compose.yml`](/authentik/compose.yml)

## 2. Create a new Brand

1. **System** -> **Brands**.
2. Click **New Brand** and enter the created domain for external users to access.
3. **Brand Settings:** Choose the relevant images that you will upload to the local media folder.
3. Under `Default Flow`, revisit this part later to select newly created `custom-authentication-flow`.

<details close>
   <summary>Show: Brand Configs</summary>

   ![Brand Settings](/assets/authentik-create-brand.png)

</details>

## 3. Applications

I primarily use Authentik's "Proxy Provider" mode.

<details close>
   <Summary>Screenshot</summary>

![Applications List](/assets/authentik-applications.png)

</details>
</br>

_NOTE_: *I have pivoted GoAccess to LAN-only access*

| Application    | Provider Type  | 
| :------------- | :------------- | 
| **Gotify**     | Proxy Provider | 
| **Jellyseerr** | Proxy Provider |

---

## 4. Application Setup Guide

Creating a **Provider** and then an **Application**.

### Step 1: Create Provider

1. **Applications** -> **Providers**.
2. Click **Create** and select **Proxy Provider**.
3. **Configuration:**
   - **Name:** `Provider - <AppName>` (e.g., `Provider - Gotify`)
   - **Authorization flow:** `default-provider-authorization-implicit-consent` (Skips the "Approve this app" screen)
   - **Authentication mode:** `Forward auth (single application)`
   - **External Host:** The public URL (e.g., `https://gotify.domain.xyz`)

### Step 2: Create Application

1. Navigate to **Applications** -> **Applications**.
2. Click **Create**.
3. **Configuration:**
   - **Name:** `<AppName>` (e.g., `Gotify`)
   - **Slug:** `<app-slug>` (Auto-generated)
   - **Provider:** Select the provider created in Step 1.

---

## 5. Add Applications to Outpost

While "Providers" define *how* to authenticate, the **Outpost** is the actual component that *performs* the authentication. We use the **Embedded Outpost** (built into the main server) rather than deploying separate proxy containers.

**Critical Step:** After creating an application, we must explicitly link it to the Outpost, or the authentication service will not run for that app.

### Step 1: Link Applications
1. Navigate to **Applications** -> **Outposts**.
2. Locate the `authentik Embedded Outpost`.
3. Click the **Edit** (pencil) icon.
4. Under **Applications**, select the applications we want this outpost to manage (e.g., `GoAccess`, `Jellyseerr`). Use the arrow button to move them to the "Selected Applications" list.
5. Click **Update**.

<details close>
   <Summary>Screenshot</summary>

![outpost-setup1](/assets/authentik-outpost-settings.png)

</details>

</br>

_NOTE_: *I have pivoted GoAccess to LAN-only access*

### Step 2: Advanced Configuration (Reverse Proxy Fix)
To ensure the Outpost generates valid redirect URLs (instead of internal Docker IPs), we force the host URL in the advanced settings.

1. In the **Edit Outpost** screen, expand **Advanced Settings**.
2. locate the `authentik_host` key.
3. Set it to our public URL:

<details close>
   <Summary>Screenshot</summary>

![outpost-setup1](/assets/authentik-outpost-settings2.png)

</details>

## 6. Add/Tweak/Configure Authentication Flow and Stages

We use a custom authentication flow for users accessing the Media Server request portal (Jellyseerr).

1. Navigate to **Flows and Stages** -> **Flows**.
2. Click **default-source-authentication**.
3. **Configuration:**
   - **Name:** `<ServerName or Server "Purpose">` (e.g., `Family & Friends Media Server`) 
   - **Title:** `<This instance "Title">` (eg: FamilyFlix)
   - **Slug:** `<mediaserver-authentication-flow>` - it will be saved/updated as a new entry in the list of authentication-flow that we can use
   - **Behavior & Appearance Settings:**
      - **Compatibility mode:** `Enabled` (Increases compatibility with password managers).
      - **Background:** Upload a background in local dockerapps/authentik/media folder and use it for the Background setting

<details close>
   <summary>Show</summary>

   ![custom-authentication-flow](/assets/authentik-custom-authentication-flow.png)

</details>

## 7. User Management (External Users)

Create specific users for external access (e.g., family accessing Jellyseerr).

1. Navigate to **Directory** -> **Users**.
2. Click **Create**.
3. **Configuration:**
   - **Username:** `<username>`
   - **Name:** `<Full Name>`
   - **Email:** `<email@address.com>`
    - _Note:_ For **Password**, I am not bothering with the Invitation/Inbound Flow,so I created for my family and friends the password (same password that I gave them for Jellyseerr). Do this after the user is created and click on the user to enter the password for them.
4. **Attributes (The "External" Tag):**
   - _Note:_ Configure this user as **External** to limit their access to specific applications only.

## 8. Homepage Integration (API Token)

To allow the Homepage dashboard to display Authentik stats (or just to show the service status using a dedicated account), we use a service account and a permanent token.

<details close>
   <summary>Show: Homepage with Authentik</summary>

   ![Homepage-Authentik](/assets/authentik-homepage-widget.png)
</details>
</br>

Over at Homepage's `services.yaml` file, I added the following:

```YAML
    - Authentik:
        icon: authentik.png
        href: https://auth.{{HOMEPAGE_VAR_ROOT_DOMAIN}}
        description: Authentication
        container: authentik-server
        widget: 
          type: authentik
          url: http://authentik-server:9000
          key: {{HOMEPAGE_VAR_AUTHENTIK_API_TOKEN}}
          version: 2
```

### Step 1: Create Service Account

1. Go to **Directory** -> **Users**.
2. Create a new **Service Account** user with username `homepage-service`.
3. (Optional) Disable login for this user if it's API-only.

<details close>
   <summary>Show</summary>

   ![New Service Acount](/assets/authentik-service-account-user.png)

</details>

### Step 2: Generate Token

1. Go to **Directory** -> **Tokens & App Passwords**.
2. Click **Create**.
3. **Configuration:**
   - **Identifier:** `service-account-homepage-service-password`
   - **User:** `homepage-service`
   - **Intent:** `API Token` (Used to access the API programmatically)
   - **Expiring:** Turn **OFF** (to prevent broken widgets in the future).
4. **Copy the Token:** You will need this for the `homepage/services.yaml` configuration.

<details close>
   <summary>Show</summary>
   
   ![Token Details](/assets/authentik-token.png)

</details>



