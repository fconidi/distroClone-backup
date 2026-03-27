# DistroClone Backup & Restore

**Graphical incremental rootfs backup and restore tool for Debian-based systems. Companion to DistroClone.**

![Version](https://img.shields.io/badge/version-1.2-blue)
![License](https://img.shields.io/badge/license-GPL--3.0-green)
![Platform](https://img.shields.io/badge/platform-Debian%20%7C%20Ubuntu%20%7C%20Mint%20%7C%20LMDE-purple)
![Languages](https://img.shields.io/badge/languages-EN%20IT%20DE%20FR%20ES-orange)


<img width="128" height="136" alt="distroclone-bkp-logo" src="https://github.com/user-attachments/assets/56772e98-77e4-4b32-9053-b7f197855c24" />


## What is DistroClone Backup?

**DistroClone Backup & Restore** is a GTK/YAD graphical tool that creates and manages backups of the running system's `rootfs` on any Debian-based distribution — Debian, Ubuntu, Linux Mint, LMDE, Elementary OS, SysLinuxOS, ZorinOS, and derivatives.

It was designed as the **companion to DistroClone** (the live ISO builder), but works perfectly as a standalone tool: protect your system with scheduled incremental backups and restore it in minutes whenever something goes wrong. A btrfs backend enables versioned snapshots with configurable retention.

> **Current version:** 1.2 | **License:** GPL-3.0 | **Author:** Franco Conidi aka edmond

---

## Why use it?

- Just ran a system update and something broke? **Restore in one click.**
- Want to test experimental software safely? **Back up first.**
- Using DistroClone to build custom ISOs? **Protect the system between builds.**
- Want nightly automatic backups without touching crontab manually? **The graphical scheduler handles it.**

---

## Features

| Feature | Description |
|---|---|
| 💾 **Full Backup** | Complete rootfs clone via rsync. Base for incremental runs. |
| ⚡ **Incremental Backup** | Only modified files are transferred — fast and storage-efficient. |
| 🔄 **Safe Restore** | Rolls back system files while always protecting `/home`, `/root`, `/boot/efi`. |
| 🗓️ **Cron Scheduler** | Schedule automatic backups (daily / weekly / monthly) from the GUI — no manual crontab editing. |
| 📸 **Btrfs Snapshots** | Automatic versioning with configurable max retention on btrfs filesystems. |
| 🔔 **Desktop Notifications** | Optional notify-send alert when a scheduled backup completes. |
| 📁 **Configurable Cache Dir** | Store the cache on any path: internal partition, external USB drive, NFS mount. |
| 🏠 **/home Inclusion** | Option to include `/home` in the backup scope, with a clear warning about size and time impact. |
| 📋 **Real-time Log** | Every operation is shown live in a log window and saved to `/var/log/distroclone-backup.log`. |
| 🌍 **Multilanguage** | Auto-detected from system locale: English, Italiano, Deutsch, Français, Español. |

---

## Installation — Step by Step

### Requirements

- Debian-based OS (Debian Bookworm+, Ubuntu 22.04+, Mint, LMDE, Elementary OS, SysLinuxOS, ZorinOS 18…)
- At least 5–15 GB of free space on the backup destination
- Dependencies installed automatically: `yad`, `rsync`, `imagemagick`
- Recommended: `btrfs-progs` for snapshot versioning

---

### Step 1 — Download the .deb package

Grab the latest release from the GitHub releases page or from [edmond's weblog](https://www.francoconidi.it):

```bash
wget https://github.com/fconidi/distroclone-tools/releases/download/v1.2/distroclone-backup_1.2_all.deb
```

---

### Step 2 — Install the package

```bash
sudo dpkg -i distroclone-backup_1.2_all.deb
sudo apt install -f
```

The second command automatically resolves and installs any missing dependencies (`yad`, `rsync`, `imagemagick`).

---

### Step 3 — (Optional) Install btrfs-progs for snapshot versioning

If your cache destination is on a btrfs filesystem, install the btrfs tools to enable automatic versioned snapshots:

```bash
sudo apt install btrfs-progs
```

---

### Step 4 — Launch DistroClone Backup

Find **DistroClone Backup** in your application menu under the **System** category, or launch it from a terminal:

```bash
distroClone-backup
```

The main dashboard opens, showing your detected distro, kernel, current cache status, and active cron schedule.

---

### Step 5 — (Optional) Configure the cache directory

Click **Settings** to change the cache location. The default is `/mnt`. Point it to an external USB drive or an NFS mount for offsite protection — the subfolder `.rootfs_cache` is created automatically.

> ⚠️ Make sure the destination has enough free space. A typical Debian desktop rootfs is 5–15 GB.

---

### Step 6 — Run a Full Backup

Click **Full Backup**. This clones the entire rootfs via rsync into:

```
<cache-dir>/<distro>_live/.rootfs_cache
```

Progress is shown live in the log window. Typical duration: 5–20 minutes depending on system size.

> **Important:** a full backup is required before incremental backups can be used.

---

### Step 7 — Schedule automatic backups

Click **Schedule Backup** and choose:

- **Frequency:** daily, weekly, or monthly
- **Day** (if weekly)
- **Hour** (0–23)
- **Desktop notification** on completion (optional)

Save — the crontab entry is written automatically. To run a silent incremental backup manually (as used internally by cron):

```bash
distroClone-backup --incremental-silent
```

---

### Step 8 — Restore the system

Click **Restore System**. The confirmation dialog shows:

- Backup date
- Saved distro and kernel
- Cache size
- Protected paths: `/home` ✓ `/root` ✓ `/boot/efi` ✓

Confirm, and rsync overwrites system files from the cache. **Reboot when done.**

**Btrfs users:** click *Restore from Snapshot* to pick any previously versioned state from the list.

---

## Dependencies

| Package | Role | Status |
|---|---|---|
| `yad` | GTK graphical dialog toolkit | Required |
| `rsync` | Filesystem synchronisation engine | Required |
| `imagemagick` | UI image generation | Required |
| `distroclone` | Companion ISO builder | Recommended |
| `btrfs-progs` | Btrfs snapshot versioning | Recommended |

---

## Installed File Structure

```
/usr/bin/distroClone-backup              ← launcher script
/usr/share/distroclone-backup/
    distroclone-backup.sh                ← main script
    distroclone-bkp-logo.png             ← application logo
/usr/share/applications/
    distroclone-backup.desktop           ← desktop menu entry
/usr/share/icons/hicolor/
    48x48/apps/distroclone-backup.png
    128x128/apps/distroclone-backup.png
    256x256/apps/distroclone-backup.png
/var/log/distroclone-backup.log          ← operations log
```

---

## Supported Languages

Auto-detected from the system `$LANG` variable:

🇬🇧 English · 🇮🇹 Italiano · 🇩🇪 Deutsch · 🇫🇷 Français · 🇪🇸 Español

---

## How It Works (technical)

1. **Full backup:** `rsync` copies the rootfs excluding virtual filesystems (`/proc`, `/sys`, `/dev`), caches, temporary directories, and snap folders.
2. **Incremental backup:** `rsync --checksum` transfers only files that changed since the last cache run.
3. **Btrfs snapshots:** after each backup a btrfs subvolume snapshot is created; older ones are pruned according to the configured retention limit.
4. **Restore:** `rsync` in reverse — from cache to rootfs — with `--exclude` applied to `/home`, `/root`, `/boot/efi`.
5. **Cron:** the entry is written directly into the root crontab via `crontab -l` piped into `crontab -`.

---

## Changelog

| Version | Notes |
|---|---|
| **1.2** | Btrfs snapshots with configurable retention, custom cache directory, optional `/home` inclusion, desktop notifications, persistent settings |
| **1.1** | First public release: full/incremental backup, safe restore, graphical cron scheduler, multilanguage support (5 languages) |

---

## Links

- 🌐 Blog: [www.syslinuxos.com](https://www.syslinuxos.com)
- 🌐 Author's site: [www.francoconidi.it](https://www.francoconidi.it)
- 📧 Contact: fconidi@gmail.com
- 🛡️ Related project: **DistroClone** — live ISO builder for Debian-based systems

---

*Published by Franco Conidi aka edmond — GPL-3.0-or-later*
