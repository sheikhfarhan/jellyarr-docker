# 🛡️ Host Firewall (Firewalld) Security

**Role:** Prevent Lateral Movement \
**Mechanism:** Firewalld Direct Rules (iptables `DOCKER-USER` chain)

Since we have a few services exposed to the internet, especially so Jellyfin through a web server (caddy), the idea is to prevent a compromised container from accessing the local home network ("Lateral Movement")and we use a **Software VLAN** strategy. This is necessary because Docker's default networking bypasses standard Firewalld zones.

## 1\. The Strategy

We insert a rule into the `DOCKER-USER` chain, which Docker guarantees is evaluated *before* its own permissive rules.

  * **Block:** Any **NEW** connection starting *from* Docker (`172.20.0.0/24`) going *to* LAN (`192.168.0.0/24`).
  * **Allow:** Established connections (replies to requests we initiated from the LAN).

## 2\. Implementation Commands

**1. Create the Chain (Prevent Race Conditions):**
We explicitly create the chain so Firewalld manages it, preventing errors during reloads.

```bash
sudo firewall-cmd --permanent --direct --add-chain ipv4 filter DOCKER-USER
```

**2. Add the Isolation Rule:**
This drops any *new* traffic leaving Docker destined for our home network.

```bash
sudo firewall-cmd --permanent --direct --add-rule ipv4 filter DOCKER-USER 0 -s 172.20.0.0/24 -d 192.168.0.0/24 -m conntrack --ctstate NEW -j DROP
```

**3. Allow LAN Access (Open Ports):**
We explicitly open ports for local devices to access services (since the default might be restrictive).

```bash
sudo firewall-cmd --permanent --add-port=8096/tcp  # Jellyfin (Local Direct Play)
sudo firewall-cmd --permanent --add-service=http   # Caddy (80)
sudo firewall-cmd --permanent --add-service=https  # Caddy (443)
```

**4. Apply Changes:**

```bash
sudo firewall-cmd --reload
sudo systemctl restart docker
```

*(Note: Restarting Docker is required once to ensure it sees the new Firewalld chain structure).*

-----

## 3\. Functional Verification

To confirm the isolation works, try to ping our router from inside a container.

```bash
docker exec -it jellyfin ping 192.168.0.1
```

  * **Success:** `100% packet loss` (The ping should hang or timeout).
  * **Failure:** If it pings successfully, the rule is not active.

-----

## 4\. Audit & Configuration Verification

Since Direct Rules do not show up in standard zone lists, use these commands to check our configuration.

**View Active Direct Rules:**

```bash
sudo firewall-cmd --direct --get-all-rules
```

*Expectation: You should see the `ipv4 filter DOCKER-USER ... DROP` rule listed.*

**View Permanent Configuration File:**

```bash
cat /etc/firewalld/direct.xml
```

*Expectation: This XML file contains the persistent definition of our `DOCKER-USER` chain and rules.*