# Changelog

All notable changes to DistroClone Backup and Restore are documented in this file.

Format follows Keep a Changelog (https://keepachangelog.com/en/1.0.0/).
Versioning follows Semantic Versioning (https://semver.org/).

---

Version 1.2 — 2026-03-28 (updated with bug fixes)

Fixed

    Cron mode — wrong cache path and missing btrfs snapshot support (--incremental-silent)

        CACHE_BASE was hardcoded to /mnt/<distro>_live/.rootfs_cache, ignoring both
        the directory configured via Settings and the correct _backup suffix.
        The cron now reads ~/.config/distroclone-backup/settings.conf from the first
        real user (uid 1000–65533) who has a configuration file, then derives
        CACHE_BASE_DIR, MAX_SNAPSHOTS, and all dependent paths from it.

        Cron mode never called is_btrfs(), create_snapshot(), or prune_snapshots().
        Automatic nightly backups on btrfs destinations now create a read-only snapshot
        before rsync and prune snapshots beyond MAX_SNAPSHOTS, exactly as the GUI does.

        If the snapshot step fails the rsync still proceeds so the backup is never skipped.

        Claude-related directories added to the cron rsync exclusion list, consistent
        with the GUI backup path:
          /home/*/.config/Claude, /home/*/.claude, /home/*/.claude.json,
          /home/*/.cache/claude-desktop-debian, and the /root equivalents.

    Delete Cache — snapshot subvolumes left orphaned on btrfs

        do_delete_cache called rm -rf on $ROOTFS_CACHE and $CACHE_META but never
        touched $SNAPSHOTS_DIR. On btrfs, rm -rf cannot remove subvolumes and silently
        fails, leaving read-only snapshots occupying disk space with no way to remove
        them without btrfs subvolume delete.

        The function now iterates over every @* snapshot in $SNAPSHOTS_DIR, deletes
        each with btrfs subvolume delete (falling back to rm -rf on non-btrfs), removes
        the .meta sidecar, then removes $SNAPSHOTS_DIR itself. The main cache subvolume
        is also deleted via btrfs subvolume delete when applicable.

---

Version 1.2 — 2025-03-27

Added

Btrfs snapshot versioning

    New is_btrfs() function — detects whether the cache destination resides on a btrfs
    filesystem.

    New init_btrfs_subvolume() — initialises .rootfs_cache as a btrfs subvolume on the
    first full backup. Warns if an existing non-subvolume cache is found.

    New create_snapshot() — creates a read-only btrfs snapshot of the cache before each
    backup run, named @YYYY-MM-DD_HH:MM. Writes a .meta sidecar with date, distro,
    kernel, and size.

    New list_snapshots() — enumerates available snapshots sorted oldest to newest.

    New prune_snapshots() — automatically deletes snapshots beyond the MAX_SNAPSHOTS
    retention limit after each backup. On non-btrfs destinations the legacy mkdir path
    is preserved.

Restore from Snapshot (do_restore_snapshot)

    New GUI dialog lists all available snapshots in a YAD table with columns:
    name, date, distro, size.

    Confirmation dialog shows snapshot name and protected paths before proceeding.

    Restore uses rsync with the same exclusion rules as the standard restore:
    /home, /root, /boot/efi, virtual filesystems, and snap directories are always
    protected.

    The Restore from Snapshot button appears in the main dashboard only when the
    cache is on btrfs and at least one snapshot exists.

Settings — advanced options (step 2 dialog)

    Settings redesigned as a two-step flow:
      Step 1: directory selection (unchanged behaviour).
      Step 2: new advanced options dialog with a numeric spinner for
              Max snapshots to keep (0 = disabled, default 3, range 0 to 20).

    MAX_SNAPSHOTS variable persisted to the configuration file alongside CACHE_BASE_DIR.

    SNAPSHOTS_DIR variable (${CACHE_BASE}/.snapshots) derived automatically from the
    configured cache base.

Main dashboard

    New Versioning status line:
      - "Versioning active (btrfs)" with snapshot count when on btrfs.
      - "Versioning not available (non-btrfs)" on standard filesystems.

    Window height increased from 500 to 540 px to accommodate the new status line.

    Window title updated to v1.2.

Multilanguage strings — all 5 languages (EN, IT, DE, FR, ES)

    New strings added in every supported language:

    S_SETTINGS_MAX_SNAPS     — Label for the max-snapshots spinner
    S_BTRFS_AVAILABLE        — Dashboard status: btrfs versioning active
    S_BTRFS_NOT_AVAILABLE    — Dashboard status: non-btrfs destination
    S_BTRFS_NOT_SUBVOL_WARN  — Warning when existing cache is not a btrfs subvolume
    S_SNAPSHOTS_NONE         — "No snapshots" label
    S_SNAPSHOTS_COUNT        — "N snapshots available" label
    S_BTN_RESTORE_SNAP       — Restore from Snapshot button label
    S_SNAP_CREATING          — Log line: snapshot creation in progress
    S_SNAP_CREATED           — Log line: snapshot created successfully
    S_SNAP_PRUNING           — Log line: pruning old snapshots
    S_SNAP_SELECT_TITLE      — Snapshot selector dialog title
    S_SNAP_SELECT_TEXT       — Snapshot selector dialog header text
    S_SNAP_NO_SNAPS          — Warning when no snapshots are available
    S_SNAP_ERR_TITLE         — Snapshot error dialog title
    S_SNAP_ERR_TEXT          — Snapshot error dialog body

Package

    Recommends field in DEBIAN/control extended with btrfs-progs.

    postinst sudoers block adds passwordless rules for /usr/bin/btrfs and /sbin/btrfs
    for the sudo group.

Changed

    Settings dialog step 1 — removed --image and --image-on-top from the
    directory-selection YAD call; branding image moved to step 2 only.

    Full backup flow — btrfs path branches on is_btrfs(): subvolume init, snapshot,
    and prune before rsync; mkdir -p fallback preserved for non-btrfs.

    Configuration file — now stores two keys (CACHE_BASE_DIR, MAX_SNAPSHOTS)
    instead of one.

    Main dashboard layout — button row extended with conditional Restore from Snapshot
    entry (action code 45).

---

Version 1.1 — 2024

First public release.

Added

    Full rootfs backup via rsync with real-time log window.

    Incremental backup — transfers only files modified since the last full backup.

    Safe system restore — rsync from cache to /, with hard exclusions on /home,
    /root, /boot/efi, virtual filesystems, and snap directories.

    Graphical cron scheduler (daily, weekly, or monthly) with configurable hour
    and optional desktop notification.

    Silent cron mode: distroClone-backup --incremental-silent

    Operations log at /var/log/distroclone-backup.log.

    Cache stored under <cache-dir>/<distro>_live/.rootfs_cache (default base: /mnt).

    YAD-based dashboard showing distro, kernel, cache status, and active cron schedule.

    Multilanguage interface — auto-detected from LANG:
    English, Italiano, Deutsch, Francais, Espanol.

    Desktop menu entry (distroclone-backup.desktop, System category).

    Application icons at 48x48, 128x128, 256x256 px.

    Package dependencies: yad, rsync, imagemagick.

---

Links

- https://www.syslinuxos.com
- https://www.francoconidi.it
- fconidi@gmail.com

Maintained by Franco Conidi aka edmond — GPL-3.0-or-later
