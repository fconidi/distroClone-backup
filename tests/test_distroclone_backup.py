"""Behaviour checks for distroclone-backup. External tools are stubs and no
disk, cache or crontab of the host is ever touched."""
import os
import re
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "distroclone-backup.sh"
LANGS = ("en", "it", "de", "fr", "es", "ru")


def bash(body, *args, env=None, cwd=None):
    full = {**os.environ, "LANG": "C.UTF-8"}
    for key in ("LC_ALL", "LC_MESSAGES", "LANGUAGE"):
        full.pop(key, None)
    full.update(env or {})
    return subprocess.run(["bash", "-c", 'source "$1"; ' + body, "bash", str(SCRIPT), *args],
                          text=True, capture_output=True, env=full, cwd=cwd)


def write_stub(directory, name, body):
    path = Path(directory, name)
    path.write_text("#!/bin/bash\n" + body)
    path.chmod(0o755)
    return path


class Fixture:
    """A scratch tree with stub commands first in PATH."""

    def __init__(self, test):
        self.dir = tempfile.TemporaryDirectory()
        test.addCleanup(self.dir.cleanup)
        self.root = Path(self.dir.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.calls = self.root / "calls"
        self.conf = self.root / "etc"
        self.cache_dir = self.root / "cache"
        self.cache_dir.mkdir()
        write_stub(self.bin, "rsync", f'echo "rsync $*" >> {self.calls}\nexit ${{RSYNC_STUB_RC:-0}}')
        write_stub(self.bin, "update-initramfs", f'echo "update-initramfs $*" >> {self.calls}')
        write_stub(self.bin, "update-grub", f'echo "update-grub $*" >> {self.calls}')
        write_stub(self.bin, "findmnt", textwrap_findmnt())
        write_stub(self.bin, "df", 'case "$*" in *used*) echo Used; echo 1000;; *avail*) echo Avail; echo "${DF_AVAIL:-100000}";; esac')

    def env(self, **extra):
        return {"PATH": f"{self.bin}:/usr/sbin:/usr/bin:/sbin:/bin", **extra}

    def prelude(self):
        return (f'PATH="{self.bin}:$PATH"; CONF_DIR="{self.conf}"; CONF_FILE="$CONF_DIR/settings.conf"; '
                f'EXCLUDE_FILE="$CONF_DIR/exclude.list"; LOG_FILE="{self.root}/log"; '
                f'LOCK_FILE="{self.root}/lock"; CACHE_BASE_DIR="{self.cache_dir}"; '
                'DISTRO_ID=testos; DISTRO_PRETTY="Test OS"; set_paths; ')


def textwrap_findmnt():
    return r'''case "$*" in
    *FSTYPE*) echo "${FS_STUB:-ext4}" ;;
    *TARGET*) printf '/\n/boot\n/data\n/proc\n' ;;
esac'''


class SafeParsingTests(unittest.TestCase):
    def test_settings_are_data_not_code(self):
        fx = Fixture(self)
        marker = fx.root / "pwned"
        conf = fx.root / "settings.conf"
        conf.write_text(f'CACHE_BASE_DIR="/mnt/$(touch {marker})"\nMAX_SNAPSHOTS=3; touch {marker}\n'
                        f'CACHE_BASE_DIR=/data/backups; touch {marker}\n')
        result = bash(f'parse_conf "{conf}"; echo "$CACHE_BASE_DIR|$MAX_SNAPSHOTS"')
        self.assertFalse(marker.exists())
        self.assertEqual(result.stdout.strip(), "/mnt|3")

    def test_valid_and_legacy_values_are_accepted(self):
        fx = Fixture(self)
        conf = fx.root / "settings.conf"
        conf.write_text('CACHE_BASE_DIR="/srv/my backups"\nMAX_SNAPSHOTS="7"\nINCLUDE_HOME=TRUE\nNOTIFY=FALSE\nOTHER=1\n')
        result = bash(f'parse_conf "{conf}"; echo "$CACHE_BASE_DIR|$MAX_SNAPSHOTS|$INCLUDE_HOME|$NOTIFY"')
        self.assertEqual(result.stdout.strip(), "/srv/my backups|7|TRUE|FALSE")
        conf.write_text("MAX_SNAPSHOTS=abc\nINCLUDE_HOME=maybe\n")
        result = bash(f'parse_conf "{conf}"; echo "$MAX_SNAPSHOTS|$INCLUDE_HOME"')
        self.assertEqual(result.stdout.strip(), "3|FALSE")
        link = fx.root / "link.conf"
        link.symlink_to(conf)
        self.assertNotEqual(bash(f'parse_conf "{link}"').returncode, 0)

    def test_directory_validation(self):
        good = ["/mnt", "/mnt/usb disk", "/srv/backup-1.2", "/run/media/user/DISK"]
        bad = ["/", "", "relative/dir", "/mnt/../etc", "/mnt/$(id)", "/mnt/`id`", "/mnt/a;b",
               "/mnt/a\nb", "/mnt/\"x\"", "/mnt/a'b"]
        for path in good:
            self.assertEqual(bash('valid_dir_path "$2"', path).returncode, 0, path)
        for path in bad:
            self.assertNotEqual(bash('valid_dir_path "$2"', path).returncode, 0, repr(path))

    def test_cache_metadata_is_parsed_never_sourced(self):
        fx = Fixture(self)
        marker = fx.root / "pwned"
        meta = fx.root / "meta"
        meta.write_text(f'META_DATE="$(touch {marker})"\nMETA_DISTRO="Evil\x1b[31m<b>"\nMETA_HOME=TRUE\n'
                        'META_KERNEL=6.1\nrm -rf /tmp/x\n')
        result = bash(f'CACHE_META="{meta}"; read_meta; printf "%s|%s|%s|%s" "$META_DATE" "$META_DISTRO" "$META_HOME" "$META_KERNEL"')
        self.assertFalse(marker.exists())
        date, distro, home, kernel = result.stdout.split("|")
        self.assertNotIn("\x1b", distro)
        self.assertEqual((home, kernel), ("TRUE", "6.1"))

    def test_markup_is_escaped(self):
        self.assertEqual(bash("esc '<b>&x</b>'").stdout, "&lt;b&gt;&amp;x&lt;/b&gt;")

    def test_no_privilege_shortcuts_remain_in_the_program(self):
        for number, line in enumerate(SCRIPT.read_text().splitlines(), 1):
            code = line.split("#")[0] if not line.lstrip().startswith("S_") else ""
            self.assertNotRegex(code, r"\bsudo\b", number)
            self.assertNotRegex(code, r"\beval\b", number)
            self.assertNotRegex(code, r"^\s*(source|\.)\s+(?!/etc/os-release)", number)


class LanguageTests(unittest.TestCase):
    def test_locale_precedence(self):
        for env, expected in [({"LC_ALL": "de_DE.UTF-8", "LANG": "C"}, "de"),
                              ({"LC_MESSAGES": "fr_FR.UTF-8", "LANG": "it_IT"}, "fr"),
                              ({"LANG": "C.UTF-8", "LANGUAGE": "it"}, "en"),
                              ({"LANG": "ru_RU.UTF-8"}, "ru"),
                              ({"LANG": "", "LANGUAGE": "es:en"}, "es"),
                              ({"LANG": "pt_BR"}, "en")]:
            result = subprocess.run(
                ["bash", "-c", 'source "$1"; detect_language', "bash", str(SCRIPT)],
                text=True, capture_output=True, env={"PATH": os.environ["PATH"], **env})
            self.assertEqual(result.stdout.strip(), expected, env)

    def test_every_language_defines_the_same_non_empty_strings(self):
        names = {}
        for lang in LANGS:
            result = bash(f'LANG_CODE={lang}; load_strings; for v in $(compgen -v S_); do '
                          '[ -n "${!v}" ] || echo "EMPTY $v"; echo "$v"; done')
            self.assertNotIn("EMPTY", result.stdout, lang)
            names[lang] = set(result.stdout.split())
        for lang in LANGS[1:]:
            self.assertEqual(names[lang], names["en"], lang)

    def test_color_dependent_markup_is_gone(self):
        self.assertNotRegex(SCRIPT.read_text(), r"color='#")

    def test_button_shortcuts_are_unique_in_every_language(self):
        for lang in LANGS:
            result = bash(f'LANG_CODE={lang}; load_strings; export LC_ALL=C.UTF-8; '
                          'mn_set "${S_BTN_EXIT}:99" "${S_BTN_BACKUP_FULL}:10" "${S_BTN_BACKUP_INC}:11" '
                          '"${S_BTN_RESTORE}:20" "${S_BTN_SCHEDULE}:40" "${S_BTN_SETTINGS}:50" '
                          '"${S_BTN_DELETE_CACHE}:30" "${S_BTN_RESTORE_SNAP}:45"; printf "%s\\n" "${MNB[@]}"')
            marks = []
            for label in result.stdout.splitlines():
                self.assertIn("_", label, (lang, label))
                marks.append(label[label.index("_") + 1].lower())
            self.assertEqual(len(marks), len(set(marks)), (lang, result.stdout))
            self.assertRegex(result.stdout, r":99\n", lang)

    def test_weekday_mapping_does_not_depend_on_translated_text(self):
        for lang in LANGS:
            result = bash(f'LANG_CODE={lang}; load_strings; IFS="!" read -ra d <<< "$S_CRON_DAYS"; '
                          'echo "$(day_to_dow "${d[0]}") $(day_to_dow "${d[6]}") $(day_to_dow nonsense)"')
            self.assertEqual(result.stdout.strip(), "1 0 1", lang)

    def test_schedule_expressions(self):
        result = bash('load_strings; echo "$(freq_to_cron "$S_CRON_FREQ_DAILY" 3 2)|$(freq_to_cron "$S_CRON_FREQ_WEEKLY" 3 2)'
                      '|$(freq_to_cron "$S_CRON_FREQ_MONTHLY" 3 2)"')
        self.assertEqual(result.stdout.strip(), "0 3 * * *|0 3 * * 2|0 3 1 * *")


class BackupEngineTests(unittest.TestCase):
    def run_cron(self, fx, conf_text=None, rsync_rc=0, extra=""):
        fx.conf.mkdir(exist_ok=True)
        if conf_text is not None:
            (fx.conf / "settings.conf").write_text(conf_text)
        base = fx.cache_dir / "testos_backup"
        (base / ".rootfs_cache").mkdir(parents=True, exist_ok=True)
        (base / ".backup_meta").write_text("META_DATE=old\n")
        body = fx.prelude() + extra + ' load_os_release() { :; }; parse_conf "$CONF_FILE"; set_paths; cron_main; echo "rc=$?"'
        return bash(body, env=fx.env(RSYNC_STUB_RC=str(rsync_rc)))

    def test_cron_backup_uses_the_root_owned_settings_and_protects_the_cache(self):
        fx = Fixture(self)
        result = self.run_cron(fx, f"CACHE_BASE_DIR={fx.cache_dir}\nMAX_SNAPSHOTS=3\n")
        self.assertIn("rc=0", result.stdout, result.stderr)
        call = fx.calls.read_text()
        self.assertIn("--delete", call)
        self.assertIn(f"--exclude={fx.cache_dir}/testos_backup", call)
        self.assertIn("--exclude=/home/*", call)
        self.assertTrue(call.strip().endswith(f"/ {fx.cache_dir}/testos_backup/.rootfs_cache"), call)
        meta = (fx.cache_dir / "testos_backup/.backup_meta").read_text()
        self.assertIn("META_HOME=FALSE", meta)
        self.assertNotIn("old", meta)

    def test_a_failed_copy_keeps_the_old_metadata_and_reports_failure(self):
        fx = Fixture(self)
        result = self.run_cron(fx, f"CACHE_BASE_DIR={fx.cache_dir}\n", rsync_rc=11)
        self.assertIn("rc=1", result.stdout)
        self.assertEqual((fx.cache_dir / "testos_backup/.backup_meta").read_text(), "META_DATE=old\n")

    def test_cron_refuses_to_start_without_a_complete_cache(self):
        fx = Fixture(self)
        fx.conf.mkdir()
        (fx.conf / "settings.conf").write_text(f"CACHE_BASE_DIR={fx.cache_dir}\n")
        result = bash(fx.prelude() + 'load_os_release() { :; }; parse_conf "$CONF_FILE"; set_paths; cron_main; echo "rc=$?"', env=fx.env())
        self.assertIn("rc=1", result.stdout)
        self.assertFalse(fx.calls.exists())

    def test_include_home_choice_is_honoured_by_cron(self):
        fx = Fixture(self)
        self.run_cron(fx, f"CACHE_BASE_DIR={fx.cache_dir}\nINCLUDE_HOME=TRUE\n")
        self.assertNotIn("--exclude=/home/*", fx.calls.read_text())
        self.assertIn("META_HOME=TRUE", (fx.cache_dir / "testos_backup/.backup_meta").read_text())

    def test_user_exclude_list_applies_to_backup_and_restore(self):
        fx = Fixture(self)
        fx.conf.mkdir()
        (fx.conf / "exclude.list").write_text("# comment\n/home/*/.cache\nnot-absolute\n/var/lib/foo/*\n")
        result = bash(fx.prelude() + 'build_backup_excludes FALSE; printf "%s\\n" "${EXCL[@]}"; echo ---; '
                      'build_restore_excludes FALSE; printf "%s\\n" "${EXCL[@]}"', env=fx.env())
        backup, restore = result.stdout.split("---")
        for part in (backup, restore):
            self.assertIn("--exclude=/home/*/.cache", part)
            self.assertIn("--exclude=/var/lib/foo/*", part)
            self.assertNotIn("not-absolute", part)

    def test_unsafe_locations_are_refused(self):
        fx = Fixture(self)
        result = bash(fx.prelude() + 'cache_fs_ok; echo "ext4=$?"; FS_STUB=vfat; export FS_STUB; cache_fs_ok; echo "vfat=$?"',
                      env=fx.env())
        self.assertIn("ext4=0", result.stdout)
        self.assertIn("vfat=1", result.stdout)
        result = bash(fx.prelude() + 'free_space_ok; echo "enough=$?"', env=fx.env(DF_AVAIL="100000"))
        self.assertIn("enough=0", result.stdout)
        result = bash(fx.prelude() + 'free_space_ok; echo "enough=$?"', env=fx.env(DF_AVAIL="900"))
        self.assertIn("enough=1", result.stdout)

    def test_a_cache_on_a_non_posix_disk_is_not_written(self):
        fx = Fixture(self)
        result = bash(fx.prelude() + 'load_strings; init_log; backup_core full FALSE; echo "rc=$? $BACKUP_ERR"',
                      env=fx.env(FS_STUB="exfat"))
        self.assertIn("rc=1", result.stdout)
        self.assertFalse(fx.calls.exists())

    def test_cancelling_stops_rsync(self):
        fx = Fixture(self)
        write_stub(fx.bin, "rsync", "sleep 30")
        result = bash(fx.prelude() + 'sleep 0.4 & LOG_PID=$!; rsync_run -a /x /y; echo "cancelled=$RSYNC_CANCELLED"',
                      env=fx.env())
        self.assertIn("cancelled=1", result.stdout)


class RestoreSafetyTests(unittest.TestCase):
    def make_tree(self, fx, name="src", os_id="testos", fstab=True, usr=True):
        tree = fx.root / name
        (tree / "etc").mkdir(parents=True)
        (tree / "etc/os-release").write_text(f'ID={os_id}\nNAME="X"\n')
        if fstab:
            (tree / "etc/fstab").write_text("# fstab\n")
        if usr:
            (tree / "usr/bin").mkdir(parents=True)
        return tree

    def test_only_a_complete_system_of_this_distribution_can_be_restored(self):
        fx = Fixture(self)
        good = self.make_tree(fx)
        cases = {"good": (good, 0),
                 "other distro": (self.make_tree(fx, "o", os_id="ubuntu"), 1),
                 "no fstab": (self.make_tree(fx, "f", fstab=False), 1),
                 "no usr": (self.make_tree(fx, "u", usr=False), 1),
                 "missing": (fx.root / "absent", 1)}
        link = fx.root / "link"
        link.symlink_to(good)
        cases["symlink"] = (link, 1)
        for label, (path, rc) in cases.items():
            result = bash(fx.prelude() + f'verify_restore_source "{path}"; echo $?', env=fx.env())
            self.assertEqual(result.stdout.strip(), str(rc), label)

    def test_restore_never_enters_other_mounted_filesystems(self):
        fx = Fixture(self)
        src = self.make_tree(fx)
        result = bash(fx.prelude() + f'LOG_FILE="{fx.root}/log"; restore_core "{src}" FALSE; echo "rc=$?"', env=fx.env())
        self.assertIn("rc=0", result.stdout, result.stderr)
        call = fx.calls.read_text().splitlines()[0]
        for protected in ("--exclude=/boot", "--exclude=/data", "--exclude=/home", "--exclude=/root"):
            self.assertIn(protected, call)
        self.assertIn("--delete-after", call)
        self.assertTrue(call.endswith(f"{src}/ /"), call)

    def test_home_is_only_restored_on_request(self):
        fx = Fixture(self)
        src = self.make_tree(fx)
        bash(fx.prelude() + f'restore_core "{src}" TRUE', env=fx.env())
        call = fx.calls.read_text().splitlines()[0]
        self.assertNotIn("--exclude=/home", call)
        self.assertNotIn("--exclude=/root", call)

    def test_boot_files_are_refreshed_only_after_a_successful_restore(self):
        fx = Fixture(self)
        src = self.make_tree(fx)
        bash(fx.prelude() + f'restore_core "{src}" FALSE', env=fx.env())
        text = fx.calls.read_text()
        self.assertIn("update-initramfs -u -k all", text)
        self.assertIn("update-grub", text)
        fx.calls.unlink()
        result = bash(fx.prelude() + f'restore_core "{src}" FALSE; echo "rc=$?"', env=fx.env(RSYNC_STUB_RC="23"))
        self.assertIn("rc=1", result.stdout)
        self.assertNotIn("update-grub", fx.calls.read_text())

    def test_delete_only_touches_the_expected_cache_paths(self):
        fx = Fixture(self)
        base = fx.cache_dir / "testos_backup"
        for target, rc in ((base / ".rootfs_cache", 0), (base / ".snapshots", 0),
                           (fx.cache_dir / "other", 1), (fx.root / "etc", 1)):
            result = bash(fx.prelude() + f'safe_cache_target "{target}"; echo $?', env=fx.env())
            self.assertEqual(result.stdout.strip(), str(rc), str(target))
        base.mkdir()
        link = base / "link"
        link.symlink_to(fx.root)
        self.assertEqual(bash(fx.prelude() + f'safe_cache_target "{link}"; echo $?', env=fx.env()).stdout.strip(), "1")

    def test_one_operation_at_a_time(self):
        fx = Fixture(self)
        body = fx.prelude() + 'acquire_lock && echo first; (acquire_lock && echo second || echo busy); release_lock'
        result = bash(body, env=fx.env())
        self.assertEqual(result.stdout.split(), ["first", "busy"])


class DialogFlowTests(unittest.TestCase):
    """Drive the real dialog functions with a scripted yad."""

    def setUp(self):
        self.fx = Fixture(self)
        write_stub(self.fx.bin, "yad",
                   f'echo "yad $*" >> {self.fx.root}/yad\n'
                   'case "$*" in *--text-info*) cat > /dev/null; exit 0 ;; *--info*) exit ${YAD_INFO_RC:-0} ;; esac\n'
                   'echo "$YAD_OUT"; exit ${YAD_RC:-0}')
        write_stub(self.fx.bin, "systemctl", f'echo "systemctl $*" >> {self.fx.calls}')
        self.base = self.fx.cache_dir / "testos_backup"
        cache = self.base / ".rootfs_cache"
        (cache / "etc").mkdir(parents=True)
        (cache / "usr/bin").mkdir(parents=True)
        (cache / "etc/fstab").write_text("x")
        (cache / "etc/os-release").write_text("ID=testos\n")
        (self.base / ".backup_meta").write_text("META_DATE=2026-10-01\nMETA_HOME=FALSE\n")

    def run_dialog(self, call, yad_out, yad_rc=0, **env):
        body = self.fx.prelude() + "init_log; " + call
        return bash(body, env=self.fx.env(YAD_OUT=yad_out, YAD_RC=str(yad_rc), **env))

    def rsync_calls(self):
        return [line for line in self.fx.calls.read_text().splitlines() if line.startswith("rsync")] \
            if self.fx.calls.exists() else []

    def test_restore_needs_the_confirmation_box(self):
        self.run_dialog("do_restore", "FALSE|FALSE|")
        self.assertEqual(self.rsync_calls(), [])

    def test_home_cannot_be_restored_from_a_backup_without_home(self):
        self.run_dialog("do_restore", "TRUE|TRUE|")
        self.assertEqual(self.rsync_calls(), [])

    def test_confirmed_restore_runs_and_can_reboot(self):
        self.run_dialog("do_restore", "FALSE|TRUE|")
        calls = self.rsync_calls()
        self.assertEqual(len(calls), 1)
        self.assertIn("--delete-after", calls[0])
        self.assertNotIn("systemctl", self.fx.calls.read_text())
        self.fx.calls.unlink()
        self.run_dialog("do_restore", "FALSE|TRUE|", YAD_INFO_RC="10")
        self.assertIn("systemctl reboot", self.fx.calls.read_text())

    def test_an_incomplete_cache_is_refused_before_any_dialog_asks(self):
        (self.base / ".backup_meta").unlink()
        self.run_dialog("do_restore", "FALSE|TRUE|")
        self.assertEqual(self.rsync_calls(), [])
        self.assertIn("--error", (self.fx.root / "yad").read_text())

    def test_delete_cache_needs_the_confirmation_box(self):
        self.run_dialog("do_delete_cache", "FALSE|")
        self.assertTrue((self.base / ".rootfs_cache").exists())
        self.run_dialog("do_delete_cache", "TRUE|")
        self.assertFalse((self.base / ".rootfs_cache").exists())
        self.assertFalse((self.base / ".backup_meta").exists())

    def test_backup_through_the_interface_writes_metadata_and_remembers_the_home_choice(self):
        self.run_dialog("INCLUDE_HOME=FALSE; do_backup incremental; cat \"$CONF_FILE\"", "TRUE|")
        meta = (self.base / ".backup_meta").read_text()
        self.assertIn("META_HOME=TRUE", meta)
        self.assertEqual(len(self.rsync_calls()), 1)
        self.assertNotIn("--exclude=/home/*", self.rsync_calls()[0])
        self.assertIn("INCLUDE_HOME=TRUE", (self.fx.conf / "settings.conf").read_text())

    def test_every_dialog_button_has_a_shortcut_and_confirmations_are_not_the_only_guard(self):
        self.run_dialog("do_restore", "FALSE|TRUE|")
        text = (self.fx.root / "yad").read_text()
        self.assertRegex(text, r"--button=_")


class RootStageTests(unittest.TestCase):
    """The stage started by pkexec: untrusted arguments, first start, exit."""

    def run_stage(self, args, env_extra=None):
        fx = Fixture(self)
        write_stub(fx.bin, "yad", f'echo "DISPLAY=$DISPLAY XAUTHORITY=$XAUTHORITY" >> {fx.root}/yad_env\n'
                   'echo "$YAD_OUT"; exit 99')
        write_stub(fx.bin, "flock", "exit 0")
        chosen = fx.root / "chosen"
        chosen.mkdir()
        body = (fx.prelude() + 'unset DISPLAY XAUTHORITY; load_os_release() { DISTRO_ID=testos; DISTRO_PRETTY=T; }; '
                f'gui_root_main {args}; echo "rc=$?"')
        result = bash(body, env=fx.env(YAD_OUT=str(chosen), **(env_extra or {})))
        return fx, chosen, result

    def test_first_start_stores_the_chosen_folder_and_the_window_can_be_closed(self):
        fx, chosen, result = self.run_stage('--lang it --display :1')
        self.assertIn(f"CACHE_BASE_DIR={chosen}", (fx.conf / "settings.conf").read_text(), result.stderr)
        self.assertIn("DISPLAY=:1", (fx.root / "yad_env").read_text())

    def test_display_arguments_are_validated(self):
        xauth = Path(tempfile.mkdtemp()) / "Xauthority"
        xauth.write_text("cookie")
        self.addCleanup(lambda: xauth.unlink())
        for display in ("localhost:0;id", "$(id)", "../x", "tcp/host:0"):
            fx, _, _ = self.run_stage(f"--display '{display}'")
            self.assertNotIn(display, (fx.root / "yad_env").read_text(), display)
        # root owns this file: refused when the caller is another user
        fx, _, _ = self.run_stage(f"--xauthority {xauth}", {"PKEXEC_UID": "12345"})
        self.assertNotIn("XAUTHORITY=/", (fx.root / "yad_env").read_text())
        fx, _, _ = self.run_stage(f"--xauthority {xauth}")
        self.assertIn(f"XAUTHORITY={xauth}", (fx.root / "yad_env").read_text())
        link = xauth.parent / "link"
        link.symlink_to(xauth)
        self.addCleanup(lambda: link.unlink())
        fx, _, _ = self.run_stage(f"--xauthority {link}")
        self.assertNotIn("XAUTHORITY=" + str(link), (fx.root / "yad_env").read_text())

    def test_a_folder_with_shell_characters_is_not_stored(self):
        fx = Fixture(self)
        write_stub(fx.bin, "yad", 'echo "$YAD_OUT"; exit 99')
        write_stub(fx.bin, "flock", "exit 0")
        bad = fx.root / "a$(touch pwned)b"
        bad.mkdir()
        body = fx.prelude() + 'load_os_release() { DISTRO_ID=testos; DISTRO_PRETTY=T; }; gui_root_main; echo "rc=$?"'
        bash(body, env=fx.env(YAD_OUT=str(bad)), cwd=fx.root)
        self.assertFalse((fx.root / "pwned").exists())
        self.assertFalse((fx.conf / "settings.conf").exists())


class VersioningTests(unittest.TestCase):
    def test_snapper_output_is_read_as_csv(self):
        fx = Fixture(self)
        write_stub(fx.bin, "snapper",
                   'echo "number;date;userdata"\n'
                   'echo "1;2026-10-01 10:00;distro=Debian 13,kernel=6.12,size_kb=5000"\n'
                   'echo "2;2026-10-02 10:00;distro=Debian 13,kernel=6.12,size_kb=5100"\n')
        for n in (1, 2):
            (fx.cache_dir / f"testos_backup/.rootfs_cache/.snapshots/{n}/snapshot").mkdir(parents=True)
        result = bash(fx.prelude() + 'list_snapper_snapshots; snapper_csv number,date,userdata | head -n1; '
                      'ud_get "distro=Debian 13,kernel=6.12,size_kb=5000" size_kb', env=fx.env())
        lines = result.stdout.splitlines()
        self.assertEqual(lines[0], f"1|{fx.cache_dir}/testos_backup/.rootfs_cache/.snapshots/1/snapshot")
        self.assertTrue(lines[1].startswith("2|"))
        self.assertTrue(lines[2].startswith("1;2026-10-01"))
        self.assertEqual(lines[3], "5000")

    def test_old_snapshots_are_pruned_only_after_a_good_copy(self):
        text = SCRIPT.read_text()
        core = text[text.index("backup_core() {"):text.index("restore_core() {")]
        self.assertLess(core.index("rsync_run"), core.index("prune_snapper_snapshots"))
        self.assertLess(core.index("rsync_run"), core.index("prune_snapshots"))


class ScheduleTests(unittest.TestCase):
    def test_schedule_lines_of_every_version_are_recognised_and_removed(self):
        fx = Fixture(self)
        store = fx.root / "crontab"
        store.write_text("0 5 * * * /usr/bin/other\n0 2 * * * /usr/bin/distroClone-backup --incremental-silent && notify-send 'x'\n"
                         "0 3 * * * /usr/bin/distroclone-backup --incremental-silent\n")
        write_stub(fx.bin, "crontab", f'if [ "$1" = "-l" ]; then cat {store}; else t=$(mktemp); cat > "$t"; cat "$t" > {store}; rm -f "$t"; fi')
        result = bash(fx.prelude() + 'cron_current | wc -l; cron_remove', env=fx.env())
        self.assertEqual(result.stdout.strip(), "2")
        self.assertEqual(store.read_text(), "0 5 * * * /usr/bin/other\n")

    def test_settings_of_earlier_versions_are_imported_once_and_validated(self):
        fx = Fixture(self)
        home = fx.root / "home/u"
        (home / ".config/distroclone-backup").mkdir(parents=True)
        (home / ".config/distroclone-backup/settings.conf").write_text(
            'CACHE_BASE_DIR="/srv/old"\nMAX_SNAPSHOTS="5"\n')
        result = bash(fx.prelude() + f'import_legacy_conf "{home}"; cat "$CONF_FILE"', env=fx.env())
        self.assertIn("CACHE_BASE_DIR=/srv/old", result.stdout)
        self.assertIn("MAX_SNAPSHOTS=5", result.stdout)
        (home / ".config/distroclone-backup/settings.conf").write_text('CACHE_BASE_DIR="/tmp/$(id)"\n')
        bash(fx.prelude() + f'import_legacy_conf "{home}"', env=fx.env())
        self.assertIn("/srv/old", (fx.conf / "settings.conf").read_text())

    def test_settings_file_is_written_atomically_and_world_readable(self):
        fx = Fixture(self)
        bash(fx.prelude() + 'MAX_SNAPSHOTS=4; INCLUDE_HOME=TRUE; write_conf', env=fx.env())
        path = fx.conf / "settings.conf"
        self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o644)
        self.assertEqual(sorted(p.name for p in fx.conf.iterdir()), ["settings.conf"])


class CommandLineTests(unittest.TestCase):
    def run_cli(self, *args):
        return subprocess.run(["bash", str(SCRIPT), *args], text=True, capture_output=True,
                              env={"PATH": os.environ["PATH"], "LANG": "C"})

    def test_help_and_version(self):
        self.assertIn("--incremental-silent", self.run_cli("--help").stdout)
        version = self.run_cli("--version").stdout.strip()
        self.assertRegex(version, r"^distroclone-backup \d+\.\d+\.\d+$")

    def test_unknown_options_never_open_the_interface(self):
        result = self.run_cli("--bogus")
        self.assertEqual(result.returncode, 2)
        self.assertIn("Usage", result.stderr)

    @unittest.skipIf(os.geteuid() == 0, "needs an unprivileged user")
    def test_cron_mode_requires_root(self):
        result = self.run_cli("--incremental-silent")
        self.assertEqual(result.returncode, 1)
        self.assertIn("must run as root", result.stderr)

    def test_package_metadata_matches_the_program(self):
        version = re.search(r'^DCB_VERSION="([^"]+)"', SCRIPT.read_text(), re.M)[1]
        control = (ROOT / "DEBIAN-control").read_text()
        self.assertIn(f"Version: {version}", control)
        self.assertNotIn("imagemagick", control)
        for needed in ("pkexec", "yad", "rsync", "util-linux", "cron"):
            self.assertIn(needed, control.split("Recommends:")[0])
        self.assertNotRegex(SCRIPT.read_text(), r"\bconvert\b")

    def test_no_personal_environment_names_in_the_program(self):
        text = SCRIPT.read_text().lower()
        for word in ("claude", "codex", "nextcloud"):
            self.assertNotIn(word, text)


if __name__ == "__main__":
    unittest.main()
