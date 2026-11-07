# DistroClone Backup and Restore

<img width="256" height="272" alt="dcb-logo" src="https://github.com/user-attachments/assets/ea61af26-e79f-4e86-b60e-7a22a8bd31ab" />

Graphical incremental rootfs backup and restore tool for Debian-based systems.
Companion to DistroClone, the live ISO builder.

Version: 1.4.0 | License: GPL-3.0-or-later | Author: Franco Conidi aka edmond

---

**What is DistroClone Backup**

DistroClone Backup and Restore is a GTK/YAD graphical tool that creates and manages
backups of the running system rootfs on any Debian-based distribution — Debian, Ubuntu,
Linux Mint, LMDE, Elementary OS, SysLinuxOS, ZorinOS, and derivatives.

It was designed as the companion to DistroClone but works perfectly as a standalone
tool. Protect your system with scheduled incremental backups and restore it in minutes
whenever something goes wrong. A btrfs backend with Snapper integration enables
versioned snapshots with automatic retention management.

---

**Features**

Full Backup
    Complete rootfs clone via rsync. Serves as the base for all incremental runs.

Incremental Backup
    Only modified files are transferred — fast and storage-efficient.

Safe Restore
    Rolls back system files while always protecting /home, /root, and /boot/efi.
    Before it starts, the backup is checked: it must be a complete system of the
    same distribution, and filesystems mounted elsewhere (a separate /boot, /data,
    /srv...) are never touched. /home is restored only if the backup contains it.
    A confirmation box must be ticked, and the boot files are refreshed afterwards
    (update-initramfs and update-grub).

Cron Scheduler
    Schedule automatic backups (daily, weekly, or monthly) from the GUI.
    No manual crontab editing required.

Btrfs + Snapper Integration
    On btrfs destinations with Snapper installed, each backup creates a Snapper
    snapshot (dedicated config "distroclone-backup") with automatic retention.
    Fallback to raw btrfs snapshots without Snapper, or classic rsync on ext4/xfs.

Desktop Notifications
    Optional notify-send alert when a scheduled backup completes.

Configurable Cache Directory
    Store the cache on any path: internal partition, external USB drive, NFS mount.

/home Inclusion
    Option to include /home in the backup scope.

Real-time Log
    Every operation is shown live in a log window and saved to
    /var/log/distroclone-backup.log. The Stop button cancels a running transfer.

Multilanguage
    Auto-detected from system locale: English, Italiano, Deutsch, Francais, Espanol,
    Russian.

---

**Requirements**

- Debian-based OS (Debian Bookworm or later, Ubuntu 22.04 or later, Mint, LMDE,
  Elementary OS, SysLinuxOS, ZorinOS 18 or later)
- At least 5 to 15 GB of free space on the backup destination
- Required dependencies, installed automatically: yad, rsync, pkexec (polkit), util-linux, cron
- Recommended: btrfs-progs, snapper (for snapshot versioning on btrfs)

---

**Installation**

Step 1 — Via SysLinuxOS APT repository (recommended)

    curl -fsSL https://fconidi.github.io/SysLinuxOS-Tools/client/install-repo.sh | sudo bash
    sudo apt install distroclone-backup

Step 2 — Direct .deb download

    wget https://github.com/fconidi/distroClone-backup/releases/download/v1.4.0/distroclone-backup_1.4.0_all.deb
    sudo apt install -y ./distroclone-backup_1.4.0_all.deb

Step 3 — Install snapper (optional, for versioned snapshots on btrfs)

    sudo apt install snapper btrfs-progs

Step 4 — Launch DistroClone Backup

Find DistroClone Backup in the application menu under the System category,
or launch it from a terminal:

    distroclone-backup

---

**Dependencies**

- yad            — GTK graphical dialog toolkit (required)
- rsync          — Filesystem synchronisation engine (required)
- pkexec         — Administrator rights through polkit (required)
- util-linux     — flock, findmnt, runuser (required)
- cron           — Scheduled backups (required)
- libnotify-bin  — Desktop notification after a scheduled backup (recommended)
- distroclone    — Companion ISO builder (recommended)
- btrfs-progs    — Btrfs snapshot versioning (recommended)
- snapper        — Managed snapshot retention on btrfs (recommended)

---

**Installed File Structure**

    /usr/bin/distroclone-backup
    /usr/bin/distroClone-backup  (compatibility symlink)
    /usr/share/distroclone-backup/
        distroclone-backup.sh
        distroclone-bkp-logo.png
    /usr/share/applications/
        distroclone-backup.desktop
    /usr/share/polkit-1/actions/
        com.syslinuxos.distroclone-backup.policy
    /etc/distroclone-backup/
        settings.conf        (cache location, snapshots to keep, home, notifications)
        exclude.list         (optional: extra rsync exclude patterns, one per line)
    /usr/share/icons/hicolor/
        48x48/apps/distroclone-backup.png
        128x128/apps/distroclone-backup.png
        256x256/apps/distroclone-backup.png
    /var/log/distroclone-backup.log

---

**Security and configuration**

The program asks polkit for administrator rights when it starts (one password
prompt); no passwordless sudo rules are installed. Settings live in the
root-owned /etc/distroclone-backup/settings.conf, which is the only file the
scheduled job reads. The files are parsed as plain data and every value is
validated. Settings kept by earlier versions in a user's home are imported once.

To keep extra paths out of backup and restore, list rsync patterns that start
with / in /etc/distroclone-backup/exclude.list, for example:

    /home/*/.cache
    /var/lib/docker/*

The cache is created readable by root only. Locations on FAT, exFAT or NTFS are
refused because those filesystems drop Linux owners and permissions. A first
full backup needs free space for the whole system.

---

**Supported Languages**

English, Italiano, Deutsch, Francais, Espanol, Russian.
Auto-detected from LC_ALL, LC_MESSAGES or LANG (then LANGUAGE).

---

**Links**

- Blog:          https://www.syslinuxos.com
- Author's site: https://www.francoconidi.it
- Contact:       fconidi@gmail.com
- APT repo:      https://fconidi.github.io/SysLinuxOS-Tools
- Related:       DistroClone — live ISO builder https://github.com/fconidi/distroClone

---

Published by Franco Conidi aka edmond — GPL-3.0-or-later
