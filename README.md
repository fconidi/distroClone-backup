
# DistroClone Backup and Restore



<img width="256" height="272" alt="dcb-logo" src="https://github.com/user-attachments/assets/ea61af26-e79f-4e86-b60e-7a22a8bd31ab" />



Graphical incremental rootfs backup and restore tool for Debian-based systems.
Companion to DistroClone, the live ISO builder.

Version: 1.2.1 | License: GPL-3.0-or-later | Author: Franco Conidi aka edmond

---

**What is DistroClone Backup**

DistroClone Backup and Restore is a GTK/YAD graphical tool that creates and manages
backups of the running system rootfs on any Debian-based distribution — Debian, Ubuntu,
Linux Mint, LMDE, Elementary OS, SysLinuxOS, ZorinOS, and derivatives.

It was designed as the companion to DistroClone but works perfectly as a standalone
tool. Protect your system with scheduled incremental backups and restore it in minutes
whenever something goes wrong. A btrfs backend enables versioned snapshots with
configurable retention.

---

**Features**

Full Backup
    Complete rootfs clone via rsync. Serves as the base for all incremental runs.

Incremental Backup
    Only modified files are transferred — fast and storage-efficient.

Safe Restore
    Rolls back system files while always protecting /home, /root, and /boot/efi.

Cron Scheduler
    Schedule automatic backups (daily, weekly, or monthly) from the GUI.
    No manual crontab editing required.

Btrfs Snapshots
    Automatic versioning with configurable maximum retention on btrfs filesystems.

Desktop Notifications
    Optional notify-send alert when a scheduled backup completes.

Configurable Cache Directory
    Store the cache on any path: internal partition, external USB drive, NFS mount.

/home Inclusion
    Option to include /home in the backup scope, with a clear warning about
    size and time impact.

Real-time Log
    Every operation is shown live in a log window and saved to
    /var/log/distroclone-backup.log.

Multilanguage
    Auto-detected from system locale: English, Italiano, Deutsch, Francais, Espanol.

---

**Requirements**

- Debian-based OS (Debian Bookworm or later, Ubuntu 22.04 or later, Mint, LMDE,
  Elementary OS, SysLinuxOS, ZorinOS 18 or later)
- At least 5 to 15 GB of free space on the backup destination
- Required dependencies, installed automatically: yad, rsync, imagemagick
- Recommended: btrfs-progs for snapshot versioning

---

**Installation — Step by Step**

Step 1 — Download the package

    wget https://github.com/fconidi/distroClone-backup/releases/download/v1.2.1/distroclone-backup_1.2.1_all.deb

Step 2 — Install the package

    sudo apt install -y ./distroclone-backup_1.2.1_all.deb
    or
    sudo dpkg -i distroclone-backup_1.2.1_all.deb
    sudo apt install -f

The second command automatically resolves and installs any missing dependencies.

Step 3 — Install btrfs-progs (optional, for snapshot versioning)

If your cache destination is on a btrfs filesystem, install the btrfs tools:

    sudo apt install btrfs-progs

Step 4 — Launch DistroClone Backup

Find DistroClone Backup in the application menu under the System category,
or launch it from a terminal:

    distroClone-backup

The main dashboard opens, showing your detected distro, kernel, current cache
status, and active cron schedule.


<img width="1407" height="503" alt="dcb-dash" src="https://github.com/user-attachments/assets/cbdd647a-8070-4d61-b369-ba592f44b7c8" />



Step 5 — Configure the cache directory (optional)

Click Settings to change the cache location. The default is /mnt.
Point it to an external USB drive or an NFS mount for offsite protection.
The subfolder .rootfs_cache is created automatically.


<img width="627" height="355" alt="dcb-setting" src="https://github.com/user-attachments/assets/b6e853ab-a10f-4af7-a50c-13b2d55ad1be" />



Note: make sure the destination has enough free space. A typical Debian desktop
rootfs occupies 5 to 15 GB.

Step 6 — Run a Full Backup

Click Full Backup. This clones the entire rootfs via rsync into:

    <cache-dir>/<distro>_live/.rootfs_cache

Progress is shown live in the log window. Typical duration: 5 to 20 minutes
depending on system size.



<img width="480" height="270" alt="dcb-full" src="https://github.com/user-attachments/assets/5fae6048-0b92-4524-8434-9a813a7e7784" />




A full backup is required before incremental backups can be used.

Step 7 — Schedule automatic backups

Click Schedule Backup and choose:

- Frequency: daily, weekly, or monthly
- Day of week (if weekly)
- Hour (0 to 23)
- Desktop notification on completion (optional)



<img width="540" height="487" alt="dcb-cron" src="https://github.com/user-attachments/assets/3dad565f-f634-44af-a35f-99101bd76776" />




Save — the crontab entry is written automatically.
To run a silent incremental backup manually (as used internally by cron):

    distroClone-backup --incremental-silent

Step 8 — Restore the system

Click Restore System. The confirmation dialog shows:

- Backup date
- Saved distro and kernel
- Cache size
- Protected paths: /home, /root, /boot/efi



<img width="522" height="556" alt="dcb-restore" src="https://github.com/user-attachments/assets/f32ffbaa-bd44-485c-8256-ea0730100255" />




Confirm, and rsync overwrites system files from the cache. Reboot when done.

Btrfs users: click Restore from Snapshot to pick any previously versioned
state from the list.

---

**Dependencies**

- yad            — GTK graphical dialog toolkit (required)
- rsync          — Filesystem synchronisation engine (required)
- imagemagick    — UI image generation (required)
- distroclone    — Companion ISO builder (recommended)
- btrfs-progs    — Btrfs snapshot versioning (recommended)

---

**Installed File Structure**

    /usr/bin/distroClone-backup
    /usr/share/distroclone-backup/
        distroclone-backup.sh
        distroclone-bkp-logo.png
    /usr/share/applications/
        distroclone-backup.desktop
    /usr/share/icons/hicolor/
        48x48/apps/distroclone-backup.png
        128x128/apps/distroclone-backup.png
        256x256/apps/distroclone-backup.png
    /var/log/distroclone-backup.log

---

**Supported Languages**

English, Italiano, Deutsch, Francais, Espanol.
Auto-detected from the system LANG variable.

---

**How It Works**

1. Full backup: rsync copies the rootfs excluding virtual filesystems (/proc, /sys,
   /dev), caches, temporary directories, and snap folders.

2. Incremental backup: rsync --checksum transfers only files that changed since
   the last cache run.

3. Btrfs snapshots: after each backup a btrfs subvolume snapshot is created,
   named @YYYY-MM-DD_HH:MM. Older snapshots are pruned according to the
   configured retention limit.

4. Restore: rsync in reverse — from cache to rootfs — with --exclude applied
   to /home, /root, and /boot/efi.

5. Cron: the entry is written directly into the root crontab via crontab -l
   piped into crontab -.

---

**Links**

- Blog:          https://www.syslinuxos.com
- Author's site: https://www.francoconidi.it
- Contact:       fconidi@gmail.com
- Related project: DistroClone — live ISO builder for Debian-based systems

---

Published by Franco Conidi aka edmond — GPL-3.0-or-later
