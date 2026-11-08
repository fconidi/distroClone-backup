# Changelog

All notable changes to DistroClone Backup and Restore are documented in this file.

Format follows Keep a Changelog (https://keepachangelog.com/en/1.0.0/).
Versioning follows Semantic Versioning (https://semver.org/).

---

Version 1.4.1 — 2026-11-08

Fixed

    Backup and Restore System no longer fail on systems whose os-release ID
    contains capital letters (for example SysLinuxOS).

Changed

    The checks added in 1.4.0 that refused an operation are removed: the free
    space check, the refusal of FAT, exFAT and NTFS locations, and the
    verification of the cache before a restore. Restore still needs an existing
    backup and never enters other mounted filesystems. The extra confirmation
    box before restore and deletion is removed; the "Yes" button confirms.

---

Version 1.4.0 — 2026-11-07

Security

    Administrator rights now come from polkit (pkexec); the package no longer
    installs passwordless sudo rules. An upgrade removes the old
    /etc/sudoers.d/distroclone-backup file.
    Settings moved to the root-owned /etc/distroclone-backup/settings.conf and
    are parsed as data. The scheduled job and the interface no longer run code
    taken from a user's home or from the backup disk.
    Cache metadata and snapshot metadata are parsed, not sourced; text coming
    from the disk is escaped before it is shown.
    The log file is no longer world-writable.

Fixed

    Restore never enters filesystems mounted on the running system (separate
    /boot, /data, /srv...): --delete used to wipe them.
    Restore is refused for a missing, incomplete or foreign cache, and /home
    is restored only if the backup was made with /home.
    The cache folder itself is excluded, so a cache outside /mnt and /media can
    no longer copy itself or be deleted by a restore.
    Locations on FAT, exFAT or NTFS are refused; a first full backup checks the
    free space.
    "Delete Cache" now finds snapper snapshots and reports failure instead of
    claiming success.
    Snapper output is read as CSV (distribution, date and size were empty).
    Old snapshots are pruned only after a successful copy.
    One operation at a time (lock shared by the interface and the schedule).
    Progress lines no longer pile up in a single log line.
    The scheduled job honours the "include /home" choice, no longer prints
    shell errors into the cron mail, and notifies the logged-in users.
    The schedule line no longer embeds translated text; the weekday is chosen
    by position, not by its translated name.
    Language detection follows LC_ALL, LC_MESSAGES and LANG.
    Unknown command-line options print help instead of opening the interface.

Changed

    Restore and deletion need a confirmation box to be ticked.
    The log window has a Stop button that cancels the transfer; errors show
    the last lines of the log.
    Restore refreshes the boot files (update-initramfs, update-grub).
    Keyboard shortcuts on the buttons; fixed colours replaced by theme colours.
    Extra exclude patterns can be listed in /etc/distroclone-backup/exclude.list.
    imagemagick is no longer needed; the schedule needs cron.
    New translated messages (EN, IT, DE, FR, ES, RU).

---

Version 1.3.6 — 2026-10-03

Fixed

    Install banner (postinst) still showed version 1.3.4

---

Version 1.3.5 — 2026-10-01

Added

    Russian (ru) translation, contributed by Андрей Ступак (Andrey Stupak)

---

Version 1.3.4 — 2026-06-17

Fixed

    Delete Cache fails on snapper-format btrfs snapshots

        v1.3.0 switched to snapper for versioning, which stores snapshots as
        numbered subdirectories (N/snapshot) rather than the legacy @YYYY-MM-DD_HH:MM
        flat format. The old do_delete_cache() only handled the @* flat format and
        attempted rm -rf on read-only btrfs subvolumes, which always fails with
        "Read-only file system".

        Fix: do_delete_cache() now handles both formats:
        – Snapper format: finds N/snapshot subvolumes depth-first and deletes each
          with btrfs subvolume delete before removing the numbered parent directory.
        – Legacy @* format: unchanged behaviour (btrfs subvolume delete + .meta sidecar).
        – .snapshots dir itself is now deleted with btrfs subvolume delete when it
          is a btrfs subvolume (snapper creates it as one), falling back to rm -rf.

    postinst version string hardcoded to 1.3.3

        The banner printed at the end of postinst said "DistroClone Backup 1.3.3
        installed" even on version 1.3.4 packages.
        Fix: updated to read the correct version.

---

Version 1.3.3 — 2026-06-12

Fixed

    Upgrade from any previous 1.3.x version fails — binary deleted mid-upgrade

        The postrm script of versions 1.3.0 and 1.3.1 deleted the wrapper at
        /usr/bin/distroclone-backup unconditionally. In an upgrade, dpkg executes
        the OLD postrm AFTER unpacking the new files, permanently deleting the
        binary just written by the new package and causing the new postinst to fail.
        Because the old postrm is already installed there is no way to fix it by
        patching the postrm — the fix must be in the new postinst.

        Fix: postinst is now self-healing. If /usr/bin/distroclone-backup is absent
        after unpacking (deleted by an old postrm), postinst recreates it as a
        two-line wrapper that exec-calls the real script at
        /usr/share/distroclone-backup/distroclone-backup.sh.

    Binary name policy fix

        The real script is now installed at /usr/share/distroclone-backup/
        distroclone-backup.sh (lowercase, consistent with Debian Policy 5.6.1).
        /usr/bin/distroclone-backup is the wrapper. A compatibility symlink
        /usr/bin/distroClone-backup (CamelCase) is provided for existing cron
        entries created by the GUI v1.x.

    postrm guarded with case remove|purge

        The postrm now guards deletions with case "$1" in remove|purge so
        files are removed only on actual remove/purge, not during upgrade.

---

Version 1.3.1 — 2026-05-20

Fixed

    "command not found" when invoking the tool by package name

        In v1.3.0 the binary was installed as /usr/bin/distroClone-backup
        (CamelCase), inconsistent with the package name, man page, and the
        /usr/share/distroclone-backup/ path.
        Fix: postinst creates a symlink /usr/bin/distroclone-backup ->
        distroClone-backup so both names work. The CamelCase binary is
        preserved for existing cron entries.

    .desktop Exec= now uses the lowercase name.

    postrm: removes the lowercase symlink on remove/purge.

---

Version 1.3.0 — 2026-05-16

Added

    Snapper-managed versioning on btrfs cache destinations

        A dedicated snapper config named "distroclone-backup" is created on the
        btrfs cache destination. Each backup creates a snapper snapshot; the
        retention policy is applied automatically by snapper. Enables browsing
        and restoring individual historical backups from snapper list / snapper
        undochange.

    Adaptive backend selection

        On a btrfs destination with snapper installed: snapper snapshot versioning.
        On a btrfs destination without snapper: raw btrfs snapshots (v1.2.2 behavior).
        On ext4/xfs or any non-btrfs destination: classic rsync without versioning.
        No regression on existing non-btrfs setups.

    Recommends: btrfs-progs, snapper

---

Version 1.2.2 — 2026-05-15

Fixed

    Critical restore bug — packages installed after last backup not removed

        Restore rsync did not use --delete, leaving the system in an inconsistent
        state: packages installed after the last backup had their binaries present
        on disk but were absent from the dpkg database.
        Fix: restore rsync now uses --delete --delete-after.

    Exclusion lists between backup and restore could diverge silently

        Root cause of the v0.x --delete data loss incident: asymmetric excludes
        made --delete unsafe. The exclusion set is now built by a shared
        build_common_excludes() function used by both backup and restore.
        /home, /root, /boot/efi, /snap, /var/log, /var/lib/apt/lists, and
        /etc/NetworkManager/system-connections are always excluded on both sides.

---

Version 1.2.1 — 2026-04-25

Fixed

    btrfs: full backup fails when parent cache directory does not exist

        init_btrfs_subvolume() called btrfs subvolume create $ROOTFS_CACHE without
        first creating the parent directory $CACHE_BASE. The subvolume create failed
        silently and rsync aborted with exit code 11.
        Fix: sudo mkdir -p "$CACHE_BASE" added before the subvolume create call.

---

Version 1.2 — 2026-03-28 (updated with bug fixes)

Fixed

    Cron mode — wrong cache path and missing btrfs snapshot support

        CACHE_BASE was hardcoded to /mnt/<distro>_live/.rootfs_cache. The cron
        now reads ~/.config/distroclone-backup/settings.conf from the first real
        user (uid 1000-65533) who has a configuration file, then derives
        CACHE_BASE_DIR, MAX_SNAPSHOTS, and all dependent paths.
        Cron mode now calls is_btrfs(), create_snapshot(), and prune_snapshots()
        so automatic nightly backups on btrfs destinations create versioned snapshots.

    Delete Cache — snapshot subvolumes left orphaned on btrfs

        do_delete_cache called rm -rf on $ROOTFS_CACHE and $CACHE_META but never
        touched $SNAPSHOTS_DIR. On btrfs, rm -rf cannot remove subvolumes.
        Fix: iterates every @* snapshot in $SNAPSHOTS_DIR, deletes each with
        btrfs subvolume delete (falling back to rm -rf on non-btrfs), removes
        the .meta sidecar, then removes $SNAPSHOTS_DIR. Main cache subvolume
        also deleted via btrfs subvolume delete when applicable.

---

Version 1.2 — 2025-03-27

Added

    Btrfs snapshot versioning
        New is_btrfs() — detects btrfs cache destination.
        New init_btrfs_subvolume() — creates .rootfs_cache as btrfs subvolume.
        New create_snapshot() — read-only snapshot @YYYY-MM-DD_HH:MM + .meta sidecar.
        New list_snapshots() — enumerates snapshots oldest to newest.
        New prune_snapshots() — deletes snapshots beyond MAX_SNAPSHOTS limit.

    Restore from Snapshot
        GUI dialog with snapshot list (name, date, distro, size).
        Same rsync exclusion rules as standard restore.
        Button visible only when cache is on btrfs with at least one snapshot.

    Settings advanced options (step 2 dialog)
        Numeric spinner for Max snapshots to keep (0 = disabled, default 3).
        MAX_SNAPSHOTS persisted to settings file alongside CACHE_BASE_DIR.

    Multilanguage strings added in all 5 languages (EN/IT/DE/FR/ES).

    Package: Recommends extended with btrfs-progs.
    postinst sudoers block adds rules for /usr/bin/btrfs and /sbin/btrfs.

---

Version 1.1 — 2024

First public release.

Added

    Full rootfs backup via rsync with real-time log window.
    Incremental backup — transfers only modified files.
    Safe restore — /home, /root, /boot/efi always protected.
    Graphical cron scheduler (daily, weekly, monthly).
    Silent cron mode: distroClone-backup --incremental-silent.
    YAD-based dashboard showing distro, kernel, cache status, active cron schedule.
    Multilanguage: English, Italiano, Deutsch, Francais, Espanol.
    Desktop menu entry (System category).

---

Links

- https://www.syslinuxos.com
- https://www.francoconidi.it
- fconidi@gmail.com

Maintained by Franco Conidi aka edmond — GPL-3.0-or-later
