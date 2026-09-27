# CLAUDE.md

Project notes for Claude Code working on `distroclone-tools`.

## Overview

Two Debian packages maintained here:

- **distroClone** — universal live ISO builder. Clones running Debian-based system into bootable live ISO with Calamares installer integration. Source tree: `distroClone_<ver>_all/`. Main logic: `usr/share/distroClone/DistroClone.sh` (~3500 lines, bash, multilingual: EN/IT/FR/ES/DE/PT).
- **distroclone-backup** — companion rsync-based backup tool with btrfs snapshot versioning. Distributed only as `.deb` here (no source tree); managed in separate repo.

Author: Franco Conidi (edmond) <fconidi@gmail.com>. License: GPL-3.0-or-later.

## Layout

```
distroClone_<ver>_all/        Debian package source tree (one per version)
  DEBIAN/control              Package metadata. Recommends calamares (NOT Depends).
  DEBIAN/postinst, postrm     Maintainer scripts (sudoers, polkit).
  usr/bin/distroClone         Entry wrapper.
  usr/share/distroClone/
    DistroClone.sh            Main logic. All build steps [1/30]–[30/30].
    *.png                     Branding (logo, welcome, installer).
  usr/share/applications/     Desktop entries.
  usr/share/icons/hicolor/    App icons (48/128/256).
  usr/share/polkit-1/         Polkit policy (pkexec auth).
  usr/share/man/man1/         Man page.
distroClone_<ver>_all.deb     Built package (gitignored).
distroclone-backup_*.deb      Companion tool binary.
docs/index.html               GitHub Pages landing page.
CHANGELOG.md                  Keep a Changelog format, SemVer.
```

## Build / rebuild .deb

```
dpkg-deb --root-owner-group -b distroClone_<ver>_all distroClone_<ver>_all.deb
```

`--root-owner-group` mandatory: source tree is `1000:1000`, package must be `root:root`.

Inspect:
```
dpkg-deb -I distroClone_<ver>_all.deb       # control
dpkg-deb -c distroClone_<ver>_all.deb       # contents
```

Install locally:
```
sudo dpkg -i distroClone_<ver>_all.deb
```

## Version policy

- SemVer. Bumps go in `CHANGELOG.md` (Keep a Changelog format).
- For fix-only patches, version may be locked on user request — patch source tree + rebuild without bumping.
- Version string lives in: `DEBIAN/control` (Version field), `DistroClone.sh` (search "1.3.x" comments/branding strings), directory name `distroClone_<ver>_all/`.

## DistroClone.sh structure (key sections)

- Lines ~280–1300: i18n message tables (EN/IT/FR/ES/DE/PT). `MSG_*` variables, language picked from `$LANG`.
- Line ~1416–1420: host runtime apt install. Pulls `calamares calamares-settings-debian live-boot live-config grub-efi-amd64 ...` on every launch. Means host can purge calamares post-build; reinstalled next run.
- Step 16 (~line 2256): chroot live-system config. `apt install` inside build chroot.
- Step 16 (~line 2354–2378): live ISO desktop entry — removes `calamares-install-debian.desktop`, creates `install-system.desktop` (Name=Install System).
- Step 17 (~line 2650): heredoc `calamares-grub-install.sh` — runs inside Calamares chroot at install time. Detects LUKS via `/etc/fstab`, configures GRUB+crypttab, rebuilds initramfs.
- Step 17 (~line 3030): heredoc `remove-live-admin.service` — runs on first boot of installed system. Purges live-boot/calamares/build-tools, removes admin user, regenerates initramfs.
- Step 19–20 (~line 3130): kernel + initrd selection for ISO live boot. `sort -V | tail -n1` picks highest version.
- Step 30 (~line 3530): host post-build cleanup. Removes `/mnt/<distro>_live/` work dirs + `Install Debian` autostart/launcher residue.

## Gotchas

- `update-initramfs` is **disabled in Calamares chroot** (detects live system via host-bound `/proc/cmdline`). Must use low-level `mkinitramfs -o /boot/initrd.img-<ver> <ver>` for non-LUKS path. See lines 2870-2881.
- `calamares` in `Recommends:` not `Depends:` (control file). Purge-safe; runtime reinstalls.
- `live-boot` package's hooks add live-init scripts to any rebuilt initrd. Purge live-boot before rebuilding initramfs on installed target.
- Workaround for broken installed kernel: `apt-get install --reinstall linux-image-<ver>`. `update-initramfs -c -t -k <ver>` does NOT fix it (live-boot leftovers + incomplete `/lib/modules`).
- systemd `ExecStart=` does not expand globs. For wildcard package purge use `bash -c 'apt-get purge "calamares*"'`.
- FAT32 EFI partition is case-insensitive — old `syslinuxos` and new `SysLinuxOS` dirs collide. Lowercase scan + remove before `grub-install` (lines 2780-2791).
- `dpkg-deb` build emits package name in lowercase (`distroclone`) despite `Package: distroClone` in control. Pre-existing, harmless.

## Don'ts

- Never bump version unless user asks — patches stay on existing version.
- Don't add `CLAUDE.md`-driven changes to `DistroClone.sh` without user request; this file documents only.
- Don't commit `.deb` files (`.gitignore` excludes them).
- Don't write to `distroClone*/` paths via `git add -A`; gitignore excludes the tree, but the `.deb` artifact path is shared with the source tree pattern.
