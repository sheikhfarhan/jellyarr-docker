# 🗄️ Storage & File Systems

This document details the Logical Volume Management (LVM) configuration that underpins the entire server. This abstraction layer allows for flexible resizing and management of the physical disks. Note that I am not going for any Raid setup. Personal preference is to maximise storage capacity - as the media content I considered not super critical data.

## 1\. LVM Configuration

The server aggregates my current 2 x 1TB physical NVMe drives into a single Volume Group (`vg_pool01`), which is then sliced into three logical volumes. I can replicate this to future HDDs set once I get my enclosure and the HDDs in.

  * **Volume Group:** `vg_pool01`
  * **Physical Volumes:** `/dev/nvme1n1p3`, `/dev/nvme0n1p4`, `/dev/nvme0n1p5`

### **Logical Volume Map**

| LV Name | Size | Mount Point | Purpose | File System |
| :--- | :--- | :--- | :--- | :--- |
| **`lv_dockerapps`** | 60GB | `/mnt/pool01/dockerapps` | **System Critical.** Stores all Docker Compose files, configurations (`config/`), scripts, and databases. | `ext4` |
| **`lv_games`** | 300GB | `/mnt/pool01/games` | **High Performance.** Dedicated storage for Steam/Lutris libraries. | `ext4` |
| **`lv_media`** | \~1.5TB | `/mnt/pool01/media` | **Mass Storage.** Stores all downloads, movies, and TV shows. Enables atomic moves. | `ext4` |

## 2\. Mounting & Persistence (`/etc/fstab`)

The logical volumes are configured to mount automatically at boot. The `nofail` option is used to prevent the entire server from hanging if a single storage volume fails.

```text
# /etc/fstab configuration
UUID=<UUID_DOCKERAPPS>  /mnt/pool01/dockerapps  ext4  defaults,nofail  0  2
UUID=<UUID_MEDIA>       /mnt/pool01/media       ext4  defaults,nofail  0  2
UUID=<UUID_GAMES>       /mnt/pool01/games       ext4  defaults,nofail  0  2
```

## 3\. Permissions Architecture

To avoid permission issues between the host and containers, all storage volumes are owned by the primary user, matching the `PUID=1000` and `PGID=1000` used in all Docker containers.

  * **Owner User:** `sfarhan` (UID 1000)
  * **Owner Group:** `sfarhan` (GID 1000)
  * **Command:** `sudo chown -R 1000:1000 /mnt/pool01`

## 4\. Cloud Backups

I would do weekly backups of only the dockerapps LV (`/mnt/pool01/dockerapps') rsync to my OneDrive account.

-----

