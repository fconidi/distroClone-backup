#!/bin/bash
# ============================================================
#  DistroClone Backup & Restore
#  Package: distroclone-backup
#
#  Usage:  distroclone-backup                  graphical interface
#          distroclone-backup --incremental-silent
#                                              incremental backup for cron (root)
#          distroclone-backup --help | --version
#
#  The interface runs through polkit (pkexec) as root; the cron mode
#  reads only the root-owned /etc/distroclone-backup/settings.conf.
#  Versioning on a btrfs cache is managed through snapper (config
#  "distroclone-backup") with a fallback to raw btrfs snapshots; other
#  filesystems use plain rsync.
# ============================================================

DCB_VERSION="1.4.1"
DCB_SELF_INSTALLED="/usr/share/distroclone-backup/distroclone-backup.sh"

PATH=/usr/sbin:/usr/bin:/sbin:/bin
export PATH
set -o pipefail
trap '' PIPE
# bash 5.2 treats an unquoted "&" in a replacement as the matched text.
shopt -u patsub_replacement 2>/dev/null

# ════════════════════════════════════════════════════════════
#  LANGUAGE DETECTION & STRINGS
# ════════════════════════════════════════════════════════════
detect_language() {
    local lang="${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}"
    if [ -z "$lang" ]; then
        lang="${LANGUAGE%%:*}"
    fi
    case "${lang:0:2}" in
        it) echo "it" ;;
        de) echo "de" ;;
        fr) echo "fr" ;;
        es) echo "es" ;;
        ru) echo "ru" ;;
        *)  echo "en" ;;
    esac
}

LANG_CODE=$(detect_language)

load_strings() {
    case "$LANG_CODE" in
    # ── ITALIANO ─────────────────────────────────────────────
    it)
        S_APP_TITLE="DistroClone Backup &amp; Restore"
        S_APP_TITLE_WIN="DistroClone Backup & Restore"
        S_APP_SUBTITLE="Gestione cache rootfs incrementale"
        S_SYSTEM="Sistema"
        S_KERNEL="Kernel"
        S_CACHE="Cache"
        S_CRONJOB="Cronjob"
        S_LOG="Log"

        S_CACHE_PRESENT="● Cache presente"
        S_CACHE_ABSENT="● Nessuna cache presente"
        S_CACHE_RUN_FULL="Esegui prima un <b>Backup completo</b>."
        S_CACHE_DATA="Data"
        S_CACHE_DISTRO="Distro"
        S_CACHE_SIZE="Dim."

        S_CRON_ACTIVE="● Backup automatico attivo"
        S_CRON_NONE="● Nessun backup automatico pianificato"

        S_BTN_EXIT="Esci!gtk-quit"
        S_BTN_BACKUP_FULL="Backup completo!drive-harddisk"
        S_BTN_BACKUP_INC="Backup incrementale!gtk-refresh"
        S_BTN_RESTORE="Ripristina sistema!gtk-revert-to-saved"
        S_BTN_SCHEDULE="Pianifica backup!gtk-orientation-portrait"
        S_BTN_DELETE_CACHE="Elimina cache!gtk-delete"
        S_BTN_OK="OK:0"
        S_BTN_CANCEL="Annulla!gtk-cancel:1"
        S_BTN_SAVE="Salva!gtk-save:0"
        S_BTN_REMOVE="Rimuovi!gtk-delete:20"
        S_BTN_YES_RESTORE="Sì, Ripristina!gtk-revert-to-saved:0"
        S_BTN_DELETE_CONFIRM="Elimina!gtk-delete:0"
        S_BTN_REBOOT_NOW="Riavvia ora!system-restart:10"
        S_BTN_REBOOT_LATER="Riavvia dopo!gtk-ok:0"
        S_BTN_CLOSE="Chiudi:0"

        S_WARN_NO_CACHE_TITLE="DistroClone — Attenzione"
        S_WARN_NO_CACHE="Nessuna cache trovata.\n\nEsegui prima un <b>Backup completo</b>."

        S_BACKUP_TITLE="DistroClone Backup — Log"
        S_BACKUP_MODE_FULL="→ Modalità completa: clone intero filesystem"
        S_BACKUP_MODE_INC="→ Modalità incrementale: solo file modificati"
        S_BACKUP_RSYNC_START="→ rsync avviato..."
        S_BACKUP_OK_TITLE="DistroClone Backup — OK"
        S_BACKUP_OK_TEXT="<big><b>✓ Backup completato!</b></big>"
        S_BACKUP_OK_DATE="Data"
        S_BACKUP_OK_SIZE="Dimensione"
        S_BACKUP_ERR_TITLE="DistroClone Backup — Errore"
        S_BACKUP_ERR_TEXT="<b>✗ Backup fallito!</b>"

        S_RESTORE_TITLE="DistroClone — Conferma Ripristino"
        S_RESTORE_WARN_TITLE="<big><b>⚠ Ripristino Sistema</b></big>"
        S_RESTORE_WARN_TEXT="Stai per ripristinare il sistema dal backup.\n<b>I file di sistema verranno sovrascritti.</b>"
        S_RESTORE_SAFE="<b>Sono al sicuro:</b>"
        S_RESTORE_INFO_TITLE="<b>Informazioni backup:</b>"
        S_RESTORE_INFO_DATE="Data"
        S_RESTORE_INFO_DISTRO="Distro"
        S_RESTORE_INFO_KERNEL="Kernel"
        S_RESTORE_INFO_SIZE="Dim."
        S_RESTORE_CONFIRM="<b>Confermi il ripristino?</b>"
        S_RESTORE_LOG_TITLE="DistroClone — Avvio RIPRISTINO"
        S_RESTORE_LOG_FROM="Da cache"
        S_RESTORE_LOG_TO="Verso"
        S_RESTORE_LOG_PROTECTED="Protetti"
        S_RESTORE_RSYNC_START="→ rsync ripristino avviato..."
        S_RESTORE_OK_TITLE="DistroClone — Ripristino OK"
        S_RESTORE_OK_TEXT="<big><b>✓ Ripristino completato!</b></big>"
        S_RESTORE_OK_DATE="Il sistema è stato ripristinato al backup del"
        S_RESTORE_OK_PROTECTED="<b>Protetti:</b> /home ✓   /root ✓   /boot/efi ✓"
        S_RESTORE_OK_REBOOT="<b><b>Riavviare il sistema.</b></b>"
        S_RESTORE_ERR_TITLE="DistroClone — Errore Ripristino"
        S_RESTORE_ERR_TEXT="<b>✗ Ripristino fallito!</b>"

        S_CRON_DIALOG_TITLE="DistroClone — Pianifica Backup"
        S_CRON_DIALOG_HEADER="<big><b>Pianificazione Backup Automatico</b></big>"
        S_CRON_STATUS_ACTIVE="● Pianificazione attiva"
        S_CRON_STATUS_NONE="<b>● Nessuna pianificazione attiva</b>"
        S_CRON_STATUS_NOCRON="<small>Nessun cronjob configurato</small>"
        S_CRON_HINT="<small>Il backup incrementale verrà eseguito automaticamente.\nRichiede che la cache esista (esegui prima Backup completo).</small>"
        S_CRON_FIELD_FREQ="<b>Frequenza</b>"
        S_CRON_FIELD_DAY="<b>Giorno</b> (se settimanale)"
        S_CRON_FIELD_HOUR="<b>Ora esecuzione</b> (0-23)"
        S_CRON_FIELD_NOTIFY="Notifica desktop al termine"
        S_CRON_FREQ_DAILY="Giornaliero"
        S_CRON_FREQ_WEEKLY="Settimanale"
        S_CRON_FREQ_MONTHLY="Mensile"
        S_CRON_DAYS="Lunedì!Martedì!Mercoledì!Giovedì!Venerdì!Sabato!Domenica"
        S_CRON_REMOVED_TITLE="DistroClone — Cronjob rimosso"
        S_CRON_REMOVED_TEXT="✓ Pianificazione rimossa."
        S_CRON_SAVED_TITLE="DistroClone — Pianificazione salvata"
        S_CRON_SAVED_TEXT="<big><b>✓ Pianificazione salvata!</b></big>"
        S_CRON_FREQ_LABEL="Frequenza"
        S_CRON_HOUR_LABEL="Ora"
        S_CRON_EXPR_LABEL="Espressione cron"
        S_CRON_VERIFY="Verifica"
        S_CRON_NOTIFY_MSG="Backup completato"

        S_DELETE_TITLE="DistroClone — Elimina Cache"
        S_DELETE_TEXT="<b>Eliminare la cache di backup?</b>"
        S_DELETE_DATE="Data"
        S_DELETE_SIZE="Dim."
        S_DELETE_PATH="Percorso"
        S_DELETE_WARN="<b>Irreversibile.\nVerrà rimossa anche la pianificazione cronjob.</b>"
        S_DELETE_OK_TITLE="DistroClone — Cache Eliminata"
        S_DELETE_OK_TEXT="✓ Cache eliminata.\n✓ Cronjob rimosso."

        S_SUDO_NEEDED="Permessi sudo necessari"
        S_LOG_CHECK="Verifica con"
        S_HOME_INCLUDE="Includi /home nel backup"
        S_HOME_INCLUDE_WARN="<small>⚠ Aumenta notevolmente dimensioni e tempi</small>"
        S_HOME_INCLUDED="● /home inclusa nel backup"
        S_HOME_EXCLUDED="● /home esclusa (solo sistema)"
        S_BACKUP_OPT_TITLE="Opzioni Backup"
        S_BTN_BACKUP_START="Avvia backup!gtk-media-play:0"
        S_BTN_SETTINGS="Impostazioni!gtk-preferences"
        S_SETTINGS_TITLE="DistroClone — Impostazioni"
        S_SETTINGS_HEADER="<big><b>Impostazioni</b></big>"
        S_SETTINGS_CACHE_DIR="<b>Directory cache backup</b>"
        S_SETTINGS_CACHE_HINT="<small>Default: /mnt — Può essere un disco esterno, NFS, ecc.\nVerrà creata la sottocartella .rootfs_cache</small>"
        S_SETTINGS_SAVED="✓ Impostazioni salvate."
        S_SETTINGS_WARN_DIR="<b>Directory non valida o non accessibile.</b>"
        S_SETTINGS_MAX_SNAPS="<b>Max snapshot da mantenere</b> (0 = disabilitato):"

        S_BTRFS_AVAILABLE="● Versioning attivo (btrfs)"
        S_BTRFS_NOT_AVAILABLE="● Versioning non disponibile (non-btrfs)"
        S_BTRFS_NOT_SUBVOL_WARN="⚠ Cache esistente non è un subvolume btrfs — snapshot disabilitati"
        S_SNAPSHOTS_NONE="Nessuno snapshot"
        S_SNAPSHOTS_COUNT="snapshot disponibili"
        S_BTN_RESTORE_SNAP="Ripristina da Snapshot!gtk-go-back"
        S_SNAP_CREATING="→ Creazione snapshot in corso..."
        S_SNAP_CREATED="✓ Snapshot creato:"
        S_SNAP_PRUNING="→ Eliminazione snapshot più vecchi..."
        S_SNAP_SELECT_TITLE="DistroClone — Ripristina da Snapshot"
        S_SNAP_SELECT_TEXT="<big><b>Seleziona snapshot da ripristinare:</b></big>"
        S_SNAP_NO_SNAPS="Nessuno snapshot disponibile."
        S_SNAP_ERR_TITLE="DistroClone — Errore Snapshot"
        S_SNAP_ERR_TEXT="<b>✗ Operazione snapshot fallita!</b>"

        # ── added in 1.4.0 ──
        S_ERR_BUSY="Un'altra operazione di backup o ripristino è già in corso."
        S_ERR_NO_SPACE="Spazio libero insufficiente per un backup completo nella posizione scelta."
        S_ERR_FS="La posizione della cache usa un filesystem senza permessi Linux (FAT, exFAT o NTFS). Scegli un'altra posizione."
        S_ERR_CACHE_INCOMPLETE="La cache di backup manca, è incompleta o appartiene a un'altra distribuzione. Ripristino rifiutato."
        S_ERR_NO_HOME_BACKUP="Questo backup non contiene /home: impossibile ripristinare /home."
        S_ERR_AUTH="Autorizzazione di amministratore non riuscita o annullata."
        S_ERR_UNDERSTAND="Spunta prima la casella di conferma per continuare."
        S_UNDERSTAND_RESTORE="Ho capito che i file di sistema verranno sovrascritti"
        S_UNDERSTAND_DELETE="Ho capito che l'operazione non si può annullare"
        S_BTN_STOP="Ferma!gtk-stop:1"
        S_OP_CANCELLED="Operazione annullata."
        S_DELETE_ERR="Impossibile eliminare completamente la cache."
        S_VERSIONING_LABEL="Versioning"
        S_STATUS_LABEL="Stato"
        ;;

    # ── DEUTSCH ──────────────────────────────────────────────
    de)
        S_APP_TITLE="DistroClone Backup &amp; Restore"
        S_APP_TITLE_WIN="DistroClone Backup & Restore"
        S_APP_SUBTITLE="Inkrementelle Rootfs-Cache-Verwaltung"
        S_SYSTEM="System"
        S_KERNEL="Kernel"
        S_CACHE="Cache"
        S_CRONJOB="Cronjob"
        S_LOG="Log"

        S_CACHE_PRESENT="● Cache vorhanden"
        S_CACHE_ABSENT="● Kein Cache vorhanden"
        S_CACHE_RUN_FULL="Bitte zuerst ein <b>Vollbackup</b> durchführen."
        S_CACHE_DATA="Datum"
        S_CACHE_DISTRO="Distro"
        S_CACHE_SIZE="Größe"

        S_CRON_ACTIVE="● Automatisches Backup aktiv"
        S_CRON_NONE="● Kein automatisches Backup geplant"

        S_BTN_EXIT="Beenden!gtk-quit"
        S_BTN_BACKUP_FULL="Vollbackup!drive-harddisk"
        S_BTN_BACKUP_INC="Inkrementell!gtk-refresh"
        S_BTN_RESTORE="System wiederherstellen!gtk-revert-to-saved"
        S_BTN_SCHEDULE="Backup planen!gtk-orientation-portrait"
        S_BTN_DELETE_CACHE="Cache löschen!gtk-delete"
        S_BTN_OK="OK:0"
        S_BTN_CANCEL="Abbrechen!gtk-cancel:1"
        S_BTN_SAVE="Speichern!gtk-save:0"
        S_BTN_REMOVE="Entfernen!gtk-delete:20"
        S_BTN_YES_RESTORE="Ja, Wiederherstellen!gtk-revert-to-saved:0"
        S_BTN_DELETE_CONFIRM="Löschen!gtk-delete:0"
        S_BTN_REBOOT_NOW="Jetzt neu starten!system-restart:10"
        S_BTN_REBOOT_LATER="Später neu starten!gtk-ok:0"
        S_BTN_CLOSE="Schließen:0"

        S_WARN_NO_CACHE_TITLE="DistroClone — Warnung"
        S_WARN_NO_CACHE="Kein Cache gefunden.\n\nBitte zuerst ein <b>Vollbackup</b> durchführen."

        S_BACKUP_TITLE="DistroClone Backup — Log"
        S_BACKUP_MODE_FULL="→ Vollmodus: gesamtes Dateisystem klonen"
        S_BACKUP_MODE_INC="→ Inkrementell: nur geänderte Dateien"
        S_BACKUP_RSYNC_START="→ rsync gestartet..."
        S_BACKUP_OK_TITLE="DistroClone Backup — OK"
        S_BACKUP_OK_TEXT="<big><b>✓ Backup abgeschlossen!</b></big>"
        S_BACKUP_OK_DATE="Datum"
        S_BACKUP_OK_SIZE="Größe"
        S_BACKUP_ERR_TITLE="DistroClone Backup — Fehler"
        S_BACKUP_ERR_TEXT="<b>✗ Backup fehlgeschlagen!</b>"

        S_RESTORE_TITLE="DistroClone — Wiederherstellung bestätigen"
        S_RESTORE_WARN_TITLE="<big><b>⚠ Systemwiederherstellung</b></big>"
        S_RESTORE_WARN_TEXT="Sie sind dabei, das System aus dem Backup wiederherzustellen.\n<b>Systemdateien werden überschrieben.</b>"
        S_RESTORE_SAFE="<b>Geschützt:</b>"
        S_RESTORE_INFO_TITLE="<b>Backup-Informationen:</b>"
        S_RESTORE_INFO_DATE="Datum"
        S_RESTORE_INFO_DISTRO="Distro"
        S_RESTORE_INFO_KERNEL="Kernel"
        S_RESTORE_INFO_SIZE="Größe"
        S_RESTORE_CONFIRM="<b>Wiederherstellung bestätigen?</b>"
        S_RESTORE_LOG_TITLE="DistroClone — WIEDERHERSTELLUNG"
        S_RESTORE_LOG_FROM="Von Cache"
        S_RESTORE_LOG_TO="Nach"
        S_RESTORE_LOG_PROTECTED="Geschützt"
        S_RESTORE_RSYNC_START="→ rsync Wiederherstellung gestartet..."
        S_RESTORE_OK_TITLE="DistroClone — Wiederherstellung OK"
        S_RESTORE_OK_TEXT="<big><b>✓ Wiederherstellung abgeschlossen!</b></big>"
        S_RESTORE_OK_DATE="System wiederhergestellt vom Backup:"
        S_RESTORE_OK_PROTECTED="<b>Geschützt:</b> /home ✓   /root ✓   /boot/efi ✓"
        S_RESTORE_OK_REBOOT="<b><b>Bitte System neu starten.</b></b>"
        S_RESTORE_ERR_TITLE="DistroClone — Wiederherstellungsfehler"
        S_RESTORE_ERR_TEXT="<b>✗ Wiederherstellung fehlgeschlagen!</b>"

        S_CRON_DIALOG_TITLE="DistroClone — Backup planen"
        S_CRON_DIALOG_HEADER="<big><b>Automatisches Backup planen</b></big>"
        S_CRON_STATUS_ACTIVE="● Planung aktiv"
        S_CRON_STATUS_NONE="<b>● Keine Planung aktiv</b>"
        S_CRON_STATUS_NOCRON="<small>Kein Cronjob konfiguriert</small>"
        S_CRON_HINT="<small>Backup wird automatisch ausgeführt.\nErfordert vorhandenen Cache (zuerst Vollbackup).</small>"
        S_CRON_FIELD_FREQ="<b>Häufigkeit</b>"
        S_CRON_FIELD_DAY="<b>Wochentag</b> (wenn wöchentlich)"
        S_CRON_FIELD_HOUR="<b>Ausführungszeit</b> (0-23)"
        S_CRON_FIELD_NOTIFY="Desktop-Benachrichtigung"
        S_CRON_FREQ_DAILY="Täglich"
        S_CRON_FREQ_WEEKLY="Wöchentlich"
        S_CRON_FREQ_MONTHLY="Monatlich"
        S_CRON_DAYS="Montag!Dienstag!Mittwoch!Donnerstag!Freitag!Samstag!Sonntag"
        S_CRON_REMOVED_TITLE="DistroClone — Cronjob entfernt"
        S_CRON_REMOVED_TEXT="✓ Planung entfernt."
        S_CRON_SAVED_TITLE="DistroClone — Planung gespeichert"
        S_CRON_SAVED_TEXT="<big><b>✓ Planung gespeichert!</b></big>"
        S_CRON_FREQ_LABEL="Häufigkeit"
        S_CRON_HOUR_LABEL="Zeit"
        S_CRON_EXPR_LABEL="Cron-Ausdruck"
        S_CRON_VERIFY="Überprüfen"
        S_CRON_NOTIFY_MSG="Backup abgeschlossen"

        S_DELETE_TITLE="DistroClone — Cache löschen"
        S_DELETE_TEXT="<b>Backup-Cache löschen?</b>"
        S_DELETE_DATE="Datum"
        S_DELETE_SIZE="Größe"
        S_DELETE_PATH="Pfad"
        S_DELETE_WARN="<b>Unwiderruflich.\nCronjob wird ebenfalls entfernt.</b>"
        S_DELETE_OK_TITLE="DistroClone — Cache gelöscht"
        S_DELETE_OK_TEXT="✓ Cache gelöscht.\n✓ Cronjob entfernt."

        S_SUDO_NEEDED="Sudo-Berechtigung erforderlich"
        S_LOG_CHECK="Überprüfen mit"
        S_HOME_INCLUDE="/home in Backup einbeziehen"
        S_HOME_INCLUDE_WARN="<small>⚠ Erhöht Größe und Dauer erheblich</small>"
        S_HOME_INCLUDED="● /home im Backup enthalten"
        S_HOME_EXCLUDED="● /home ausgeschlossen (nur System)"
        S_BACKUP_OPT_TITLE="Backup-Optionen"
        S_BTN_BACKUP_START="Backup starten!gtk-media-play:0"
        S_BTN_SETTINGS="Einstellungen!gtk-preferences"
        S_SETTINGS_TITLE="DistroClone — Einstellungen"
        S_SETTINGS_HEADER="<big><b>Einstellungen</b></big>"
        S_SETTINGS_CACHE_DIR="<b>Backup-Cache-Verzeichnis</b>"
        S_SETTINGS_CACHE_HINT="<small>Standard: /mnt — Kann externe Festplatte, NFS usw. sein.\nUnterordner .rootfs_cache wird erstellt</small>"
        S_SETTINGS_SAVED="✓ Einstellungen gespeichert."
        S_SETTINGS_WARN_DIR="<b>Ungültiges oder nicht zugängliches Verzeichnis.</b>"
        S_SETTINGS_MAX_SNAPS="<b>Max. Snapshots behalten</b> (0 = deaktiviert):"

        S_BTRFS_AVAILABLE="● Versionierung aktiv (btrfs)"
        S_BTRFS_NOT_AVAILABLE="● Versionierung nicht verfügbar (kein btrfs)"
        S_BTRFS_NOT_SUBVOL_WARN="⚠ Bestehender Cache ist kein btrfs-Subvolume — Snapshots deaktiviert"
        S_SNAPSHOTS_NONE="Keine Snapshots"
        S_SNAPSHOTS_COUNT="Snapshots verfügbar"
        S_BTN_RESTORE_SNAP="Von Snapshot wiederherstellen!gtk-go-back"
        S_SNAP_CREATING="→ Snapshot wird erstellt..."
        S_SNAP_CREATED="✓ Snapshot erstellt:"
        S_SNAP_PRUNING="→ Alte Snapshots werden gelöscht..."
        S_SNAP_SELECT_TITLE="DistroClone — Von Snapshot wiederherstellen"
        S_SNAP_SELECT_TEXT="<big><b>Snapshot zur Wiederherstellung wählen:</b></big>"
        S_SNAP_NO_SNAPS="Keine Snapshots verfügbar."
        S_SNAP_ERR_TITLE="DistroClone — Snapshot-Fehler"
        S_SNAP_ERR_TEXT="<b>✗ Snapshot-Vorgang fehlgeschlagen!</b>"

        # ── added in 1.4.0 ──
        S_ERR_BUSY="Ein anderer Sicherungs- oder Wiederherstellungsvorgang läuft bereits."
        S_ERR_NO_SPACE="Nicht genügend freier Speicherplatz für eine vollständige Sicherung am gewählten Ort."
        S_ERR_FS="Der Cache-Ort verwendet ein Dateisystem ohne Linux-Berechtigungen (FAT, exFAT oder NTFS). Wählen Sie einen anderen Ort."
        S_ERR_CACHE_INCOMPLETE="Der Sicherungs-Cache fehlt, ist unvollständig oder stammt von einer anderen Distribution. Wiederherstellung abgelehnt."
        S_ERR_NO_HOME_BACKUP="Diese Sicherung enthält kein /home; /home kann nicht wiederhergestellt werden."
        S_ERR_AUTH="Die Administrator-Autorisierung ist fehlgeschlagen oder wurde abgebrochen."
        S_ERR_UNDERSTAND="Aktivieren Sie zuerst das Bestätigungsfeld, um fortzufahren."
        S_UNDERSTAND_RESTORE="Mir ist bewusst, dass Systemdateien überschrieben werden"
        S_UNDERSTAND_DELETE="Mir ist bewusst, dass dies nicht rückgängig gemacht werden kann"
        S_BTN_STOP="Stopp!gtk-stop:1"
        S_OP_CANCELLED="Vorgang abgebrochen."
        S_DELETE_ERR="Der Cache konnte nicht vollständig gelöscht werden."
        S_VERSIONING_LABEL="Versionierung"
        S_STATUS_LABEL="Status"
        ;;

    # ── FRANÇAIS ─────────────────────────────────────────────
    fr)
        S_APP_TITLE="DistroClone Backup &amp; Restore"
        S_APP_TITLE_WIN="DistroClone Backup & Restore"
        S_APP_SUBTITLE="Gestion du cache rootfs incrémentiel"
        S_SYSTEM="Système"
        S_KERNEL="Noyau"
        S_CACHE="Cache"
        S_CRONJOB="Tâche planifiée"
        S_LOG="Journal"

        S_CACHE_PRESENT="● Cache présent"
        S_CACHE_ABSENT="● Aucun cache présent"
        S_CACHE_RUN_FULL="Effectuez d'abord une <b>Sauvegarde complète</b>."
        S_CACHE_DATA="Date"
        S_CACHE_DISTRO="Distro"
        S_CACHE_SIZE="Taille"

        S_CRON_ACTIVE="● Sauvegarde automatique active"
        S_CRON_NONE="● Aucune sauvegarde automatique planifiée"

        S_BTN_EXIT="Quitter!gtk-quit"
        S_BTN_BACKUP_FULL="Sauvegarde complète!drive-harddisk"
        S_BTN_BACKUP_INC="Sauvegarde incrémentielle!gtk-refresh"
        S_BTN_RESTORE="Restaurer le système!gtk-revert-to-saved"
        S_BTN_SCHEDULE="Planifier!gtk-orientation-portrait"
        S_BTN_DELETE_CACHE="Supprimer le cache!gtk-delete"
        S_BTN_OK="OK:0"
        S_BTN_CANCEL="Annuler!gtk-cancel:1"
        S_BTN_SAVE="Enregistrer!gtk-save:0"
        S_BTN_REMOVE="Supprimer!gtk-delete:20"
        S_BTN_YES_RESTORE="Oui, Restaurer!gtk-revert-to-saved:0"
        S_BTN_DELETE_CONFIRM="Supprimer!gtk-delete:0"
        S_BTN_REBOOT_NOW="Redémarrer maintenant!system-restart:10"
        S_BTN_REBOOT_LATER="Redémarrer plus tard!gtk-ok:0"
        S_BTN_CLOSE="Fermer:0"

        S_WARN_NO_CACHE_TITLE="DistroClone — Attention"
        S_WARN_NO_CACHE="Aucun cache trouvé.\n\nEffectuez d'abord une <b>Sauvegarde complète</b>."

        S_BACKUP_TITLE="DistroClone Backup — Journal"
        S_BACKUP_MODE_FULL="→ Mode complet: clonage du système entier"
        S_BACKUP_MODE_INC="→ Mode incrémentiel: fichiers modifiés uniquement"
        S_BACKUP_RSYNC_START="→ rsync démarré..."
        S_BACKUP_OK_TITLE="DistroClone Backup — OK"
        S_BACKUP_OK_TEXT="<big><b>✓ Sauvegarde terminée!</b></big>"
        S_BACKUP_OK_DATE="Date"
        S_BACKUP_OK_SIZE="Taille"
        S_BACKUP_ERR_TITLE="DistroClone Backup — Erreur"
        S_BACKUP_ERR_TEXT="<b>✗ Sauvegarde échouée!</b>"

        S_RESTORE_TITLE="DistroClone — Confirmer la restauration"
        S_RESTORE_WARN_TITLE="<big><b>⚠ Restauration du système</b></big>"
        S_RESTORE_WARN_TEXT="Vous êtes sur le point de restaurer le système.\n<b>Les fichiers système seront écrasés.</b>"
        S_RESTORE_SAFE="<b>Protégés:</b>"
        S_RESTORE_INFO_TITLE="<b>Informations de sauvegarde:</b>"
        S_RESTORE_INFO_DATE="Date"
        S_RESTORE_INFO_DISTRO="Distro"
        S_RESTORE_INFO_KERNEL="Noyau"
        S_RESTORE_INFO_SIZE="Taille"
        S_RESTORE_CONFIRM="<b>Confirmer la restauration?</b>"
        S_RESTORE_LOG_TITLE="DistroClone — RESTAURATION"
        S_RESTORE_LOG_FROM="Du cache"
        S_RESTORE_LOG_TO="Vers"
        S_RESTORE_LOG_PROTECTED="Protégés"
        S_RESTORE_RSYNC_START="→ rsync restauration démarré..."
        S_RESTORE_OK_TITLE="DistroClone — Restauration OK"
        S_RESTORE_OK_TEXT="<big><b>✓ Restauration terminée!</b></big>"
        S_RESTORE_OK_DATE="Système restauré depuis la sauvegarde du"
        S_RESTORE_OK_PROTECTED="<b>Protégés:</b> /home ✓   /root ✓   /boot/efi ✓"
        S_RESTORE_OK_REBOOT="<b><b>Veuillez redémarrer le système.</b></b>"
        S_RESTORE_ERR_TITLE="DistroClone — Erreur de restauration"
        S_RESTORE_ERR_TEXT="<b>✗ Restauration échouée!</b>"

        S_CRON_DIALOG_TITLE="DistroClone — Planifier la sauvegarde"
        S_CRON_DIALOG_HEADER="<big><b>Planification automatique</b></big>"
        S_CRON_STATUS_ACTIVE="● Planification active"
        S_CRON_STATUS_NONE="<b>● Aucune planification active</b>"
        S_CRON_STATUS_NOCRON="<small>Aucun cronjob configuré</small>"
        S_CRON_HINT="<small>La sauvegarde sera exécutée automatiquement.\nNécessite un cache existant (effectuez d'abord une sauvegarde complète).</small>"
        S_CRON_FIELD_FREQ="<b>Fréquence</b>"
        S_CRON_FIELD_DAY="<b>Jour</b> (si hebdomadaire)"
        S_CRON_FIELD_HOUR="<b>Heure d'exécution</b> (0-23)"
        S_CRON_FIELD_NOTIFY="Notification bureau"
        S_CRON_FREQ_DAILY="Quotidien"
        S_CRON_FREQ_WEEKLY="Hebdomadaire"
        S_CRON_FREQ_MONTHLY="Mensuel"
        S_CRON_DAYS="Lundi!Mardi!Mercredi!Jeudi!Vendredi!Samedi!Dimanche"
        S_CRON_REMOVED_TITLE="DistroClone — Tâche supprimée"
        S_CRON_REMOVED_TEXT="✓ Planification supprimée."
        S_CRON_SAVED_TITLE="DistroClone — Planification enregistrée"
        S_CRON_SAVED_TEXT="<big><b>✓ Planification enregistrée!</b></big>"
        S_CRON_FREQ_LABEL="Fréquence"
        S_CRON_HOUR_LABEL="Heure"
        S_CRON_EXPR_LABEL="Expression cron"
        S_CRON_VERIFY="Vérifier"
        S_CRON_NOTIFY_MSG="Sauvegarde terminée"

        S_DELETE_TITLE="DistroClone — Supprimer le cache"
        S_DELETE_TEXT="<b>Supprimer le cache de sauvegarde?</b>"
        S_DELETE_DATE="Date"
        S_DELETE_SIZE="Taille"
        S_DELETE_PATH="Chemin"
        S_DELETE_WARN="<b>Irréversible.\nLa tâche planifiée sera également supprimée.</b>"
        S_DELETE_OK_TITLE="DistroClone — Cache supprimé"
        S_DELETE_OK_TEXT="✓ Cache supprimé.\n✓ Tâche planifiée supprimée."

        S_SUDO_NEEDED="Permissions sudo requises"
        S_LOG_CHECK="Vérifier avec"
        S_HOME_INCLUDE="Inclure /home dans la sauvegarde"
        S_HOME_INCLUDE_WARN="<small>⚠ Augmente considérablement la taille et la durée</small>"
        S_HOME_INCLUDED="● /home inclus dans la sauvegarde"
        S_HOME_EXCLUDED="● /home exclu (système uniquement)"
        S_BACKUP_OPT_TITLE="Options de sauvegarde"
        S_BTN_BACKUP_START="Lancer la sauvegarde!gtk-media-play:0"
        S_BTN_SETTINGS="Paramètres!gtk-preferences"
        S_SETTINGS_TITLE="DistroClone — Paramètres"
        S_SETTINGS_HEADER="<big><b>Paramètres</b></big>"
        S_SETTINGS_CACHE_DIR="<b>Répertoire du cache de sauvegarde</b>"
        S_SETTINGS_CACHE_HINT="<small>Défaut: /mnt — Peut être un disque externe, NFS, etc.\nLe sous-dossier .rootfs_cache sera créé</small>"
        S_SETTINGS_SAVED="✓ Paramètres enregistrés."
        S_SETTINGS_WARN_DIR="<b>Répertoire invalide ou inaccessible.</b>"
        S_SETTINGS_MAX_SNAPS="<b>Nombre max de snapshots à conserver</b> (0 = désactivé) :"

        S_BTRFS_AVAILABLE="● Versionnage actif (btrfs)"
        S_BTRFS_NOT_AVAILABLE="● Versionnage non disponible (non-btrfs)"
        S_BTRFS_NOT_SUBVOL_WARN="⚠ Le cache existant n'est pas un sous-volume btrfs — snapshots désactivés"
        S_SNAPSHOTS_NONE="Aucun snapshot"
        S_SNAPSHOTS_COUNT="snapshots disponibles"
        S_BTN_RESTORE_SNAP="Restaurer depuis snapshot!gtk-go-back"
        S_SNAP_CREATING="→ Création du snapshot..."
        S_SNAP_CREATED="✓ Snapshot créé :"
        S_SNAP_PRUNING="→ Suppression des anciens snapshots..."
        S_SNAP_SELECT_TITLE="DistroClone — Restaurer depuis snapshot"
        S_SNAP_SELECT_TEXT="<big><b>Sélectionnez le snapshot à restaurer :</b></big>"
        S_SNAP_NO_SNAPS="Aucun snapshot disponible."
        S_SNAP_ERR_TITLE="DistroClone — Erreur snapshot"
        S_SNAP_ERR_TEXT="<b>✗ Opération snapshot échouée !</b>"

        # ── added in 1.4.0 ──
        S_ERR_BUSY="Une autre opération de sauvegarde ou de restauration est déjà en cours."
        S_ERR_NO_SPACE="Espace libre insuffisant pour une sauvegarde complète à l'emplacement choisi."
        S_ERR_FS="L'emplacement du cache utilise un système de fichiers sans permissions Linux (FAT, exFAT ou NTFS). Choisissez un autre emplacement."
        S_ERR_CACHE_INCOMPLETE="Le cache de sauvegarde est absent, incomplet ou provient d'une autre distribution. Restauration refusée."
        S_ERR_NO_HOME_BACKUP="Cette sauvegarde ne contient pas /home : impossible de restaurer /home."
        S_ERR_AUTH="L'autorisation administrateur a échoué ou a été annulée."
        S_ERR_UNDERSTAND="Cochez d'abord la case de confirmation pour continuer."
        S_UNDERSTAND_RESTORE="Je comprends que les fichiers système seront écrasés"
        S_UNDERSTAND_DELETE="Je comprends que cette action est irréversible"
        S_BTN_STOP="Arrêter!gtk-stop:1"
        S_OP_CANCELLED="Opération annulée."
        S_DELETE_ERR="Le cache n'a pas pu être entièrement supprimé."
        S_VERSIONING_LABEL="Versionnage"
        S_STATUS_LABEL="État"
        ;;

    # ── ESPAÑOL ──────────────────────────────────────────────
    es)
        S_APP_TITLE="DistroClone Backup &amp; Restore"
        S_APP_TITLE_WIN="DistroClone Backup & Restore"
        S_APP_SUBTITLE="Gestión de caché rootfs incremental"
        S_SYSTEM="Sistema"
        S_KERNEL="Kernel"
        S_CACHE="Caché"
        S_CRONJOB="Tarea programada"
        S_LOG="Registro"

        S_CACHE_PRESENT="● Caché disponible"
        S_CACHE_ABSENT="● Sin caché disponible"
        S_CACHE_RUN_FULL="Realice primero una <b>copia de seguridad completa</b>."
        S_CACHE_DATA="Fecha"
        S_CACHE_DISTRO="Distro"
        S_CACHE_SIZE="Tamaño"

        S_CRON_ACTIVE="● Copia de seguridad automática activa"
        S_CRON_NONE="● Sin copia de seguridad automática programada"

        S_BTN_EXIT="Salir!gtk-quit"
        S_BTN_BACKUP_FULL="Copia completa!drive-harddisk"
        S_BTN_BACKUP_INC="Copia incremental!gtk-refresh"
        S_BTN_RESTORE="Restaurar sistema!gtk-revert-to-saved"
        S_BTN_SCHEDULE="Programar tarea!gtk-orientation-portrait"
        S_BTN_DELETE_CACHE="Borrar caché!gtk-delete"
        S_BTN_OK="OK:0"
        S_BTN_CANCEL="Cancelar!gtk-cancel:1"
        S_BTN_SAVE="Guardar!gtk-save:0"
        S_BTN_REMOVE="Quitar!gtk-delete:20"
        S_BTN_YES_RESTORE="Sí, restaurar!gtk-revert-to-saved:0"
        S_BTN_DELETE_CONFIRM="Borrar!gtk-delete:0"
        S_BTN_REBOOT_NOW="Reiniciar ahora!system-restart:10"
        S_BTN_REBOOT_LATER="Reiniciar después!gtk-ok:0"
        S_BTN_CLOSE="Cerrar:0"

        S_WARN_NO_CACHE_TITLE="DistroClone — Aviso"
        S_WARN_NO_CACHE="No se encontró ningún caché.\n\nRealice primero una <b>copia de seguridad completa</b>."

        S_BACKUP_TITLE="DistroClone Backup — Registro"
        S_BACKUP_MODE_FULL="→ Modo completo: clonando todo el sistema de archivos"
        S_BACKUP_MODE_INC="→ Modo incremental: solo archivos modificados"
        S_BACKUP_RSYNC_START="→ rsync en marcha..."
        S_BACKUP_OK_TITLE="DistroClone Backup — Correcto"
        S_BACKUP_OK_TEXT="<big><b>✓ Copia de seguridad finalizada!</b></big>"
        S_BACKUP_OK_DATE="Fecha"
        S_BACKUP_OK_SIZE="Tamaño"
        S_BACKUP_ERR_TITLE="DistroClone Backup — Error"
        S_BACKUP_ERR_TEXT="<b>✗ La copia de seguridad ha fallado!</b>"

        S_RESTORE_TITLE="DistroClone — Confirmar restauración"
        S_RESTORE_WARN_TITLE="<big><b>⚠ Restauración del sistema</b></big>"
        S_RESTORE_WARN_TEXT="Está a punto de restaurar el sistema desde la copia.\n<b>Los archivos del sistema serán sobrescritos.</b>"
        S_RESTORE_SAFE="<b>No se modificarán:</b>"
        S_RESTORE_INFO_TITLE="<b>Datos de la copia de seguridad:</b>"
        S_RESTORE_INFO_DATE="Fecha"
        S_RESTORE_INFO_DISTRO="Distro"
        S_RESTORE_INFO_KERNEL="Kernel"
        S_RESTORE_INFO_SIZE="Tamaño"
        S_RESTORE_CONFIRM="<b>¿Confirmar la restauración?</b>"
        S_RESTORE_LOG_TITLE="DistroClone — RESTAURACIÓN EN CURSO"
        S_RESTORE_LOG_FROM="Origen (caché)"
        S_RESTORE_LOG_TO="Destino"
        S_RESTORE_LOG_PROTECTED="Directorios protegidos"
        S_RESTORE_RSYNC_START="→ rsync: restauración iniciada..."
        S_RESTORE_OK_TITLE="DistroClone — Restauración correcta"
        S_RESTORE_OK_TEXT="<big><b>✓ Restauración finalizada!</b></big>"
        S_RESTORE_OK_DATE="Sistema restaurado desde la copia del"
        S_RESTORE_OK_PROTECTED="<b>Sin cambios:</b> /home ✓   /root ✓   /boot/efi ✓"
        S_RESTORE_OK_REBOOT="<b><b>Es necesario reiniciar el sistema.</b></b>"
        S_RESTORE_ERR_TITLE="DistroClone — Error en la restauración"
        S_RESTORE_ERR_TEXT="<b>✗ La restauración ha fallado!</b>"

        S_CRON_DIALOG_TITLE="DistroClone — Programar copia de seguridad"
        S_CRON_DIALOG_HEADER="<big><b>Programar copia de seguridad automática</b></big>"
        S_CRON_STATUS_ACTIVE="● Tarea programada activa"
        S_CRON_STATUS_NONE="<b>● Sin tarea programada</b>"
        S_CRON_STATUS_NOCRON="<small>No hay ninguna tarea programada</small>"
        S_CRON_HINT="<small>La copia se ejecutará automáticamente en los horarios indicados.\nEs necesario tener un caché disponible (realice primero una copia completa).</small>"
        S_CRON_FIELD_FREQ="<b>Frecuencia</b>"
        S_CRON_FIELD_DAY="<b>Día de la semana</b> (si es semanal)"
        S_CRON_FIELD_HOUR="<b>Hora de ejecución</b> (0-23)"
        S_CRON_FIELD_NOTIFY="Notificación en el escritorio"
        S_CRON_FREQ_DAILY="Diario"
        S_CRON_FREQ_WEEKLY="Semanal"
        S_CRON_FREQ_MONTHLY="Mensual"
        S_CRON_DAYS="Lunes!Martes!Miércoles!Jueves!Viernes!Sábado!Domingo"
        S_CRON_REMOVED_TITLE="DistroClone — Tarea eliminada"
        S_CRON_REMOVED_TEXT="✓ Tarea programada eliminada."
        S_CRON_SAVED_TITLE="DistroClone — Tarea guardada"
        S_CRON_SAVED_TEXT="<big><b>✓ Tarea programada guardada!</b></big>"
        S_CRON_FREQ_LABEL="Frecuencia"
        S_CRON_HOUR_LABEL="Hora"
        S_CRON_EXPR_LABEL="Expresión cron"
        S_CRON_VERIFY="Comprobar con"
        S_CRON_NOTIFY_MSG="Copia de seguridad finalizada"

        S_DELETE_TITLE="DistroClone — Borrar caché"
        S_DELETE_TEXT="<b>¿Borrar el caché de copia de seguridad?</b>"
        S_DELETE_DATE="Fecha"
        S_DELETE_SIZE="Tamaño"
        S_DELETE_PATH="Ruta"
        S_DELETE_WARN="<b>Esta acción es irreversible.\nLa tarea programada también será eliminada.</b>"
        S_DELETE_OK_TITLE="DistroClone — Caché borrado"
        S_DELETE_OK_TEXT="✓ Caché borrado correctamente.\n✓ Tarea programada eliminada."

        S_SUDO_NEEDED="Se requieren permisos de administrador (sudo)"
        S_LOG_CHECK="Comprobar con"
        S_HOME_INCLUDE="Incluir /home en la copia de seguridad"
        S_HOME_INCLUDE_WARN="<small>⚠ Aumenta considerablemente el tamaño y el tiempo</small>"
        S_HOME_INCLUDED="● /home incluido en la copia"
        S_HOME_EXCLUDED="● /home excluido (solo sistema)"
        S_BACKUP_OPT_TITLE="Opciones de copia de seguridad"
        S_BTN_BACKUP_START="Iniciar copia!gtk-media-play:0"
        S_BTN_SETTINGS="Ajustes!gtk-preferences"
        S_SETTINGS_TITLE="DistroClone — Ajustes"
        S_SETTINGS_HEADER="<big><b>Ajustes</b></big>"
        S_SETTINGS_CACHE_DIR="<b>Directorio de caché de copia de seguridad</b>"
        S_SETTINGS_CACHE_HINT="<small>Predeterminado: /mnt — Puede ser disco externo, NFS, etc.\nSe creará la subcarpeta .rootfs_cache</small>"
        S_SETTINGS_SAVED="✓ Ajustes guardados."
        S_SETTINGS_WARN_DIR="<b>Directorio no válido o inaccesible.</b>"
        S_SETTINGS_MAX_SNAPS="<b>Máx. snapshots a conservar</b> (0 = desactivado):"

        S_BTRFS_AVAILABLE="● Versionado activo (btrfs)"
        S_BTRFS_NOT_AVAILABLE="● Versionado no disponible (no btrfs)"
        S_BTRFS_NOT_SUBVOL_WARN="⚠ La caché existente no es un subvolumen btrfs — snapshots desactivados"
        S_SNAPSHOTS_NONE="Sin snapshots"
        S_SNAPSHOTS_COUNT="snapshots disponibles"
        S_BTN_RESTORE_SNAP="Restaurar desde Snapshot!gtk-go-back"
        S_SNAP_CREATING="→ Creando snapshot..."
        S_SNAP_CREATED="✓ Snapshot creado:"
        S_SNAP_PRUNING="→ Eliminando snapshots antiguos..."
        S_SNAP_SELECT_TITLE="DistroClone — Restaurar desde Snapshot"
        S_SNAP_SELECT_TEXT="<big><b>Selecciona el snapshot a restaurar:</b></big>"
        S_SNAP_NO_SNAPS="No hay snapshots disponibles."
        S_SNAP_ERR_TITLE="DistroClone — Error de Snapshot"
        S_SNAP_ERR_TEXT="<b>✗ ¡Operación de snapshot fallida!</b>"

        # ── added in 1.4.0 ──
        S_ERR_BUSY="Ya hay otra operación de copia de seguridad o restauración en curso."
        S_ERR_NO_SPACE="No hay espacio libre suficiente para una copia completa en la ubicación elegida."
        S_ERR_FS="La ubicación de la caché usa un sistema de archivos sin permisos de Linux (FAT, exFAT o NTFS). Elija otra ubicación."
        S_ERR_CACHE_INCOMPLETE="La caché de copia de seguridad falta, está incompleta o es de otra distribución. Restauración rechazada."
        S_ERR_NO_HOME_BACKUP="Esta copia no contiene /home, por lo que no se puede restaurar /home."
        S_ERR_AUTH="La autorización de administrador falló o se canceló."
        S_ERR_UNDERSTAND="Marque primero la casilla de confirmación para continuar."
        S_UNDERSTAND_RESTORE="Entiendo que los archivos del sistema se sobrescribirán"
        S_UNDERSTAND_DELETE="Entiendo que esta acción no se puede deshacer"
        S_BTN_STOP="Detener!gtk-stop:1"
        S_OP_CANCELLED="Operación cancelada."
        S_DELETE_ERR="No se pudo eliminar completamente la caché."
        S_VERSIONING_LABEL="Versionado"
        S_STATUS_LABEL="Estado"
        ;;

    # ── RUSSIAN — translation by Андрей Ступак (Andrey Stupak) ──
    ru)
        S_APP_TITLE="DistroClone Backup &amp; Restore"
        S_APP_TITLE_WIN="DistroClone Backup & Restore"
        S_APP_SUBTITLE="Инкрементальное управление кэшем корневой файловой системы"
        S_SYSTEM="Система"
        S_KERNEL="Ядро"
        S_CACHE="Кэш"
        S_CRONJOB="Cron-задача"
        S_LOG="Журнал"

        S_CACHE_PRESENT="● Кэш присутствует"
        S_CACHE_ABSENT="● Кэш отсутствует"
        S_CACHE_RUN_FULL="Пожалуйста, сначала выполните <b>Полное резервное копирование</b>."
        S_CACHE_DATA="Дата"
        S_CACHE_DISTRO="Дистрибутив"
        S_CACHE_SIZE="Размер"

        S_CRON_ACTIVE="● Автоматическое резервное копирование включено"
        S_CRON_NONE="● Автоматическое резервное копирование не запланировано"

        S_BTN_EXIT="Выход!gtk-quit"
        S_BTN_BACKUP_FULL="Полная копия!drive-harddisk"
        S_BTN_BACKUP_INC="Инкрементальная копия!gtk-refresh"
        S_BTN_RESTORE="Восстановить систему!gtk-revert-to-saved"
        S_BTN_SCHEDULE="Запланировать резервное копирование!gtk-orientation-portrait"
        S_BTN_DELETE_CACHE="Удалить кэш!gtk-delete"
        S_BTN_OK="OK:0"
        S_BTN_CANCEL="Отмена!gtk-cancel:1"
        S_BTN_SAVE="Сохранить!gtk-save:0"
        S_BTN_REMOVE="Удалить!gtk-delete:20"
        S_BTN_YES_RESTORE="Да, восстановить!gtk-revert-to-saved:0"
        S_BTN_DELETE_CONFIRM="Удалить!gtk-delete:0"
        S_BTN_REBOOT_NOW="Перезагрузить сейчас!system-restart:10"
        S_BTN_REBOOT_LATER="Перезагрузить позже!gtk-ok:0"
        S_BTN_CLOSE="Закрыть:0"

        S_WARN_NO_CACHE_TITLE="DistroClone — Внимание"
        S_WARN_NO_CACHE="Кэш не найден.\n\nПожалуйста, сначала запустите <b>Полное резервное копирование</b>."

        S_BACKUP_TITLE="DistroClone Резервное копирование — Журнал"
        S_BACKUP_MODE_FULL="→ Полный режим: клонирование всей файловой системы"
        S_BACKUP_MODE_INC="→ Инкрементальный режим: только измененные файлы"
        S_BACKUP_RSYNC_START="→ rsync запущен..."
        S_BACKUP_OK_TITLE="DistroClone Резервное копирование — OK"
        S_BACKUP_OK_TEXT="<big><b>✓ Резервное копирование завершено!</b></big>"
        S_BACKUP_OK_DATE="Дата"
        S_BACKUP_OK_SIZE="Размер"
        S_BACKUP_ERR_TITLE="DistroClone Резервное копирование — Ошибка"
        S_BACKUP_ERR_TEXT="<b>✗ Сбой резервного копирования!</b>"

        S_RESTORE_TITLE="DistroClone — Подтвердить восстановление"
        S_RESTORE_WARN_TITLE="<big><b>⚠ Восстановление системы</b></big>"
        S_RESTORE_WARN_TEXT="Вы собираетесь восстановить систему из резервной копии.\n<b>Системные файлы будут перезаписаны.</b>"
        S_RESTORE_SAFE="<b>Безопасно (не будет затронуто):</b>"
        S_RESTORE_INFO_TITLE="<b>Информация о резервной копии:</b>"
        S_RESTORE_INFO_DATE="Дата"
        S_RESTORE_INFO_DISTRO="Дистрибутив"
        S_RESTORE_INFO_KERNEL="Ядро"
        S_RESTORE_INFO_SIZE="Размер"
        S_RESTORE_CONFIRM="<b>Подтвердить восстановление?</b>"
        S_RESTORE_LOG_TITLE="DistroClone — ВОССТАНОВЛЕНИЕ"
        S_RESTORE_LOG_FROM="Из кэша"
        S_RESTORE_LOG_TO="В"
        S_RESTORE_LOG_PROTECTED="Защищено"
        S_RESTORE_RSYNC_START="→ rsync: Восстановление начато..."
        S_RESTORE_OK_TITLE="DistroClone — Восстановление выполнено успешно"
        S_RESTORE_OK_TEXT="<big><b>✓ Восстановление завершено!</b></big>"
        S_RESTORE_OK_DATE="Система восстановлена из резервной копии от"
        S_RESTORE_OK_PROTECTED="<b>Защищено:</b> /home ✓   /root ✓   /boot/efi ✓"
        S_RESTORE_OK_REBOOT="<b><b>Пожалуйста, перезагрузите систему.</b></b>"
        S_RESTORE_ERR_TITLE="DistroClone — Ошибка восстановления"
        S_RESTORE_ERR_TEXT="<b>✗ Сбой восстановления!</b>"

        S_CRON_DIALOG_TITLE="DistroClone — Резервное копирование по расписанию"
        S_CRON_DIALOG_HEADER="<big><b>Настроить расписание автоматического резервного копирования</b></big>"
        S_CRON_STATUS_ACTIVE="● Расписание активно"
        S_CRON_STATUS_NONE="<b>● Нет активного расписания</b>"
        S_CRON_STATUS_NOCRON="<small>Cron-задача не настроена</small>"
        S_CRON_HINT="<small>Резервное копирование будет выполняться автоматически по расписанию.\nТребуется существующий кэш (сначала выполните полное резервное копирование).</small>"
        S_CRON_FIELD_FREQ="<b>Частота</b>"
        S_CRON_FIELD_DAY="<b>День недели</b> (для еженедельного)"
        S_CRON_FIELD_HOUR="<b>Время запуска</b> (0-23)"
        S_CRON_FIELD_NOTIFY="Уведомление на рабочем столе"
        S_CRON_FREQ_DAILY="Ежедневно"
        S_CRON_FREQ_WEEKLY="Еженедельно"
        S_CRON_FREQ_MONTHLY="Ежемесячно"
        S_CRON_DAYS="Понедельник!Вторник!Среда!Четверг!Пятница!Суббота!Воскресенье"
        S_CRON_REMOVED_TITLE="DistroClone — Cron-задача удалена"
        S_CRON_REMOVED_TEXT="✓ Расписание удалено."
        S_CRON_SAVED_TITLE="DistroClone — Расписание сохранено"
        S_CRON_SAVED_TEXT="<big><b>✓ Расписание сохранено!</b></big>"
        S_CRON_FREQ_LABEL="Частота"
        S_CRON_HOUR_LABEL="Время"
        S_CRON_EXPR_LABEL="Выражение cron"
        S_CRON_VERIFY="Проверить"
        S_CRON_NOTIFY_MSG="Резервное копирование завершено"

        S_DELETE_TITLE="DistroClone — Удалить кэш"
        S_DELETE_TEXT="<b>Удалить кэш резервных копий?</b>"
        S_DELETE_DATE="Дата"
        S_DELETE_SIZE="Размер"
        S_DELETE_PATH="Путь"
        S_DELETE_WARN="<b>Действие необратимо.\nРасписание Cron-задач также будет удалено.</b>"
        S_DELETE_OK_TITLE="DistroClone — Кэш удален"
        S_DELETE_OK_TEXT="✓ Кэш удален.\n✓ Cron-задача удалена."

        S_SUDO_NEEDED="Требуются права sudo"
        S_LOG_CHECK="Проверить с помощью"
        S_HOME_INCLUDE="Включить /home в резервную копию"
        S_HOME_INCLUDE_WARN="<small>⚠ Значительно увеличивает размер и время создания копии</small>"
        S_HOME_INCLUDED="● /home включен в резервную копию"
        S_HOME_EXCLUDED="● /home исключен (только система)"
        S_BACKUP_OPT_TITLE="Параметры резервного копирования"
        S_BTN_BACKUP_START=" Начать резервное копирование!gtk-media-play:0"
        S_BTN_SETTINGS="Настройки!gtk-preferences"
        S_SETTINGS_TITLE="DistroClone — Настройки"
        S_SETTINGS_HEADER="<big><b>Настройки</b></big>"
        S_SETTINGS_CACHE_DIR="<b>Каталог кэша резервных копий</b>"
        S_SETTINGS_CACHE_HINT="<small>По умолчанию: /mnt — может быть внешним диском, NFS и т. д.\nБудет создана подпапка .rootfs_cache</small>"
        S_SETTINGS_SAVED="✓ Настройки сохранены."
        S_SETTINGS_WARN_DIR="<b>Недопустимый или недоступный каталог.</b>"
        S_SETTINGS_MAX_SNAPS="<b>Макс. количество сохраняемых снимков</b> (0 = отключено):"

        S_BTRFS_AVAILABLE="● Версионирование включено (btrfs)"
        S_BTRFS_NOT_AVAILABLE="● Управление версиями недоступно (не btrfs)"
        S_BTRFS_NOT_SUBVOL_WARN="⚠ Существующий кэш не является подтомом btrfs — создание снимков отключено"
        S_SNAPSHOTS_NONE="Нет снимков"
        S_SNAPSHOTS_COUNT="снимков доступно"
        S_BTN_RESTORE_SNAP="Восстановить из снимка!gtk-go-back"
        S_SNAP_CREATING="→ Создание снимка..."
        S_SNAP_CREATED="✓ Снимок создан:"
        S_SNAP_PRUNING="→ Очистка старых снимков..."
        S_SNAP_SELECT_TITLE="DistroClone — Восстановить из снимка"
        S_SNAP_SELECT_TEXT="<big><b>Выберите снимок для восстановления:</b></big>"
        S_SNAP_NO_SNAPS="Нет доступных снимков."
        S_SNAP_ERR_TITLE="DistroClone — Ошибка снимка"
        S_SNAP_ERR_TEXT="<b>✗ Операция со снимком завершилась ошибкой!</b>"

        # ── added in 1.4.0 ──
        S_ERR_BUSY="Другая операция резервного копирования или восстановления уже выполняется."
        S_ERR_NO_SPACE="Недостаточно свободного места для полного резервного копирования в выбранном месте."
        S_ERR_FS="Расположение кэша использует файловую систему без прав Linux (FAT, exFAT или NTFS). Выберите другое расположение."
        S_ERR_CACHE_INCOMPLETE="Кэш резервной копии отсутствует, неполон или относится к другому дистрибутиву. Восстановление отклонено."
        S_ERR_NO_HOME_BACKUP="Эта копия не содержит /home, поэтому восстановить /home невозможно."
        S_ERR_AUTH="Авторизация администратора не удалась или была отменена."
        S_ERR_UNDERSTAND="Сначала установите флажок подтверждения, чтобы продолжить."
        S_UNDERSTAND_RESTORE="Я понимаю, что системные файлы будут перезаписаны"
        S_UNDERSTAND_DELETE="Я понимаю, что это действие нельзя отменить"
        S_BTN_STOP="Стоп!gtk-stop:1"
        S_OP_CANCELLED="Операция отменена."
        S_DELETE_ERR="Не удалось полностью удалить кэш."
        S_VERSIONING_LABEL="Версионирование"
        S_STATUS_LABEL="Статус"
        ;;

    # ── ENGLISH (default) ────────────────────────────────────
    *)
        S_APP_TITLE="DistroClone Backup &amp; Restore"
        S_APP_TITLE_WIN="DistroClone Backup & Restore"
        S_APP_SUBTITLE="Incremental rootfs cache management"
        S_SYSTEM="System"
        S_KERNEL="Kernel"
        S_CACHE="Cache"
        S_CRONJOB="Cronjob"
        S_LOG="Log"

        S_CACHE_PRESENT="● Cache present"
        S_CACHE_ABSENT="● No cache present"
        S_CACHE_RUN_FULL="Please run a <b>Full Backup</b> first."
        S_CACHE_DATA="Date"
        S_CACHE_DISTRO="Distro"
        S_CACHE_SIZE="Size"

        S_CRON_ACTIVE="● Automatic backup active"
        S_CRON_NONE="● No automatic backup scheduled"

        S_BTN_EXIT="Exit!gtk-quit"
        S_BTN_BACKUP_FULL="Full Backup!drive-harddisk"
        S_BTN_BACKUP_INC="Incremental Backup!gtk-refresh"
        S_BTN_RESTORE="Restore System!gtk-revert-to-saved"
        S_BTN_SCHEDULE="Schedule Backup!gtk-orientation-portrait"
        S_BTN_DELETE_CACHE="Delete Cache!gtk-delete"
        S_BTN_OK="OK:0"
        S_BTN_CANCEL="Cancel!gtk-cancel:1"
        S_BTN_SAVE="Save!gtk-save:0"
        S_BTN_REMOVE="Remove!gtk-delete:20"
        S_BTN_YES_RESTORE="Yes, Restore!gtk-revert-to-saved:0"
        S_BTN_DELETE_CONFIRM="Delete!gtk-delete:0"
        S_BTN_REBOOT_NOW="Reboot now!system-restart:10"
        S_BTN_REBOOT_LATER="Reboot later!gtk-ok:0"
        S_BTN_CLOSE="Close:0"

        S_WARN_NO_CACHE_TITLE="DistroClone — Warning"
        S_WARN_NO_CACHE="No cache found.\n\nPlease run a <b>Full Backup</b> first."

        S_BACKUP_TITLE="DistroClone Backup — Log"
        S_BACKUP_MODE_FULL="→ Full mode: cloning entire filesystem"
        S_BACKUP_MODE_INC="→ Incremental mode: modified files only"
        S_BACKUP_RSYNC_START="→ rsync started..."
        S_BACKUP_OK_TITLE="DistroClone Backup — OK"
        S_BACKUP_OK_TEXT="<big><b>✓ Backup completed!</b></big>"
        S_BACKUP_OK_DATE="Date"
        S_BACKUP_OK_SIZE="Size"
        S_BACKUP_ERR_TITLE="DistroClone Backup — Error"
        S_BACKUP_ERR_TEXT="<b>✗ Backup failed!</b>"

        S_RESTORE_TITLE="DistroClone — Confirm Restore"
        S_RESTORE_WARN_TITLE="<big><b>⚠ System Restore</b></big>"
        S_RESTORE_WARN_TEXT="You are about to restore the system from backup.\n<b>System files will be overwritten.</b>"
        S_RESTORE_SAFE="<b>Safe (will not be touched):</b>"
        S_RESTORE_INFO_TITLE="<b>Backup information:</b>"
        S_RESTORE_INFO_DATE="Date"
        S_RESTORE_INFO_DISTRO="Distro"
        S_RESTORE_INFO_KERNEL="Kernel"
        S_RESTORE_INFO_SIZE="Size"
        S_RESTORE_CONFIRM="<b>Confirm restore?</b>"
        S_RESTORE_LOG_TITLE="DistroClone — RESTORE"
        S_RESTORE_LOG_FROM="From cache"
        S_RESTORE_LOG_TO="To"
        S_RESTORE_LOG_PROTECTED="Protected"
        S_RESTORE_RSYNC_START="→ rsync restore started..."
        S_RESTORE_OK_TITLE="DistroClone — Restore OK"
        S_RESTORE_OK_TEXT="<big><b>✓ Restore completed!</b></big>"
        S_RESTORE_OK_DATE="System restored from backup dated"
        S_RESTORE_OK_PROTECTED="<b>Protected:</b> /home ✓   /root ✓   /boot/efi ✓"
        S_RESTORE_OK_REBOOT="<b><b>Please reboot the system.</b></b>"
        S_RESTORE_ERR_TITLE="DistroClone — Restore Error"
        S_RESTORE_ERR_TEXT="<b>✗ Restore failed!</b>"

        S_CRON_DIALOG_TITLE="DistroClone — Schedule Backup"
        S_CRON_DIALOG_HEADER="<big><b>Schedule Automatic Backup</b></big>"
        S_CRON_STATUS_ACTIVE="● Schedule active"
        S_CRON_STATUS_NONE="<b>● No schedule active</b>"
        S_CRON_STATUS_NOCRON="<small>No cronjob configured</small>"
        S_CRON_HINT="<small>Backup will run automatically at scheduled times.\nRequires existing cache (run Full Backup first).</small>"
        S_CRON_FIELD_FREQ="<b>Frequency</b>"
        S_CRON_FIELD_DAY="<b>Day of week</b> (if weekly)"
        S_CRON_FIELD_HOUR="<b>Execution hour</b> (0-23)"
        S_CRON_FIELD_NOTIFY="Desktop notification"
        S_CRON_FREQ_DAILY="Daily"
        S_CRON_FREQ_WEEKLY="Weekly"
        S_CRON_FREQ_MONTHLY="Monthly"
        S_CRON_DAYS="Monday!Tuesday!Wednesday!Thursday!Friday!Saturday!Sunday"
        S_CRON_REMOVED_TITLE="DistroClone — Cronjob removed"
        S_CRON_REMOVED_TEXT="✓ Schedule removed."
        S_CRON_SAVED_TITLE="DistroClone — Schedule saved"
        S_CRON_SAVED_TEXT="<big><b>✓ Schedule saved!</b></big>"
        S_CRON_FREQ_LABEL="Frequency"
        S_CRON_HOUR_LABEL="Hour"
        S_CRON_EXPR_LABEL="Cron expression"
        S_CRON_VERIFY="Verify"
        S_CRON_NOTIFY_MSG="Backup completed"

        S_DELETE_TITLE="DistroClone — Delete Cache"
        S_DELETE_TEXT="<b>Delete backup cache?</b>"
        S_DELETE_DATE="Date"
        S_DELETE_SIZE="Size"
        S_DELETE_PATH="Path"
        S_DELETE_WARN="<b>Irreversible.\nCronjob schedule will also be removed.</b>"
        S_DELETE_OK_TITLE="DistroClone — Cache Deleted"
        S_DELETE_OK_TEXT="✓ Cache deleted.\n✓ Cronjob removed."

        S_SUDO_NEEDED="Sudo permissions required"
        S_LOG_CHECK="Verify with"
        S_HOME_INCLUDE="Include /home in backup"
        S_HOME_INCLUDE_WARN="<small>⚠ Significantly increases size and time</small>"
        S_HOME_INCLUDED="● /home included in backup"
        S_HOME_EXCLUDED="● /home excluded (system only)"
        S_BACKUP_OPT_TITLE="Backup Options"
        S_BTN_BACKUP_START="Start Backup!gtk-media-play:0"
        S_BTN_SETTINGS="Settings!gtk-preferences"
        S_SETTINGS_TITLE="DistroClone — Settings"
        S_SETTINGS_HEADER="<big><b>Settings</b></big>"
        S_SETTINGS_CACHE_DIR="<b>Backup cache directory</b>"
        S_SETTINGS_CACHE_HINT="<small>Default: /mnt — Can be an external disk, NFS, etc.\nSubfolder .rootfs_cache will be created</small>"
        S_SETTINGS_SAVED="✓ Settings saved."
        S_SETTINGS_WARN_DIR="<b>Invalid or inaccessible directory.</b>"
        S_SETTINGS_MAX_SNAPS="<b>Max snapshots to keep</b> (0 = disabled):"

        S_BTRFS_AVAILABLE="● Versioning active (btrfs)"
        S_BTRFS_NOT_AVAILABLE="● Versioning not available (non-btrfs)"
        S_BTRFS_NOT_SUBVOL_WARN="⚠ Existing cache is not a btrfs subvolume — snapshots disabled"
        S_SNAPSHOTS_NONE="No snapshots"
        S_SNAPSHOTS_COUNT="snapshots available"
        S_BTN_RESTORE_SNAP="Restore from Snapshot!gtk-go-back"
        S_SNAP_CREATING="→ Creating snapshot..."
        S_SNAP_CREATED="✓ Snapshot created:"
        S_SNAP_PRUNING="→ Pruning old snapshots..."
        S_SNAP_SELECT_TITLE="DistroClone — Restore from Snapshot"
        S_SNAP_SELECT_TEXT="<big><b>Select snapshot to restore from:</b></big>"
        S_SNAP_NO_SNAPS="No snapshots available."
        S_SNAP_ERR_TITLE="DistroClone — Snapshot Error"
        S_SNAP_ERR_TEXT="<b>✗ Snapshot operation failed!</b>"

        # ── added in 1.4.0 ──
        S_ERR_BUSY="Another backup or restore operation is already running."
        S_ERR_NO_SPACE="Not enough free space for a full backup at the chosen location."
        S_ERR_FS="The cache location uses a filesystem without Linux permissions (FAT, exFAT or NTFS). Choose another location."
        S_ERR_CACHE_INCOMPLETE="The backup cache is missing, incomplete or from another distribution. Restore refused."
        S_ERR_NO_HOME_BACKUP="This backup does not contain /home, so /home cannot be restored."
        S_ERR_AUTH="Administrator authorization failed or was cancelled."
        S_ERR_UNDERSTAND="Tick the confirmation box first to continue."
        S_UNDERSTAND_RESTORE="I understand that system files will be overwritten"
        S_UNDERSTAND_DELETE="I understand that this cannot be undone"
        S_BTN_STOP="Stop!gtk-stop:1"
        S_OP_CANCELLED="Operation cancelled."
        S_DELETE_ERR="The cache could not be fully deleted."
        S_VERSIONING_LABEL="Versioning"
        S_STATUS_LABEL="Status"
        ;;
    esac
}

# Load strings
load_strings

# ════════════════════════════════════════════════════════════
#  PATHS, SETTINGS, SAFE FILE PARSING
# ════════════════════════════════════════════════════════════
CONF_DIR="/etc/distroclone-backup"
CONF_FILE="$CONF_DIR/settings.conf"
EXCLUDE_FILE="$CONF_DIR/exclude.list"
LOG_FILE="/var/log/distroclone-backup.log"
LOCK_FILE="/run/lock/distroclone-backup.lock"
SNAPPER_CFG_NAME="distroclone-backup"
CRON_PATTERN='distro[cC]lone-backup'

CACHE_BASE_DIR="/mnt"
MAX_SNAPSHOTS=3
INCLUDE_HOME="FALSE"
NOTIFY="TRUE"

# Escape text before it goes into yad/Pango markup.
esc() {
    local s="$1"
    s="${s//&/&amp;}"; s="${s//</&lt;}"; s="${s//>/&gt;}"
    printf '%s' "$s"
}

# Drop control characters and keep short values from files on removable disks.
clean_value() {
    local v
    v=$(printf '%s' "$1" | tr -d '\000-\037\177')
    printf '%s' "${v:0:80}"
}

# A directory chosen by the user: absolute, plain characters, no "..".
valid_dir_path() {
    local p="$1" re='^/[A-Za-z0-9._/ +@:,%=-]*$'
    [[ "$p" =~ $re ]] || return 1
    [ "$p" != "/" ] || return 1
    [[ "/$p/" != *"/../"* ]] || return 1
    return 0
}

# Settings files are data, never code: only known keys, validated values.
parse_conf() {
    local file="$1" line key value
    [ -f "$file" ] && [ ! -L "$file" ] || return 1
    while IFS= read -r line || [ -n "$line" ]; do
        [[ "$line" =~ ^([A-Z_]+)=(.*)$ ]] || continue
        key="${BASH_REMATCH[1]}"; value="${BASH_REMATCH[2]}"
        # Files written by versions before 1.4 quote the value.
        if [[ "$value" =~ ^\"(.*)\"$ ]]; then value="${BASH_REMATCH[1]}"; fi
        case "$key" in
            CACHE_BASE_DIR) if valid_dir_path "$value"; then CACHE_BASE_DIR="$value"; fi ;;
            MAX_SNAPSHOTS)  if [[ "$value" =~ ^[0-9]{1,2}$ ]]; then MAX_SNAPSHOTS="$value"; fi ;;
            INCLUDE_HOME)   if [ "$value" = TRUE ] || [ "$value" = FALSE ]; then INCLUDE_HOME="$value"; fi ;;
            NOTIFY)         if [ "$value" = TRUE ] || [ "$value" = FALSE ]; then NOTIFY="$value"; fi ;;
        esac
    done < "$file"
    return 0
}

write_conf() {
    local tmp
    install -d -m 755 "$CONF_DIR" || return 1
    tmp=$(mktemp "$CONF_DIR/.settings.XXXXXX") || return 1
    {
        printf 'CACHE_BASE_DIR=%s\n' "$CACHE_BASE_DIR"
        printf 'MAX_SNAPSHOTS=%s\n' "$MAX_SNAPSHOTS"
        printf 'INCLUDE_HOME=%s\n' "$INCLUDE_HOME"
        printf 'NOTIFY=%s\n' "$NOTIFY"
    } > "$tmp"
    chmod 644 "$tmp"
    mv -f "$tmp" "$CONF_FILE"
}

# Carry the settings of earlier versions (kept in a user's home) over to the
# root-owned file, validating every value.
import_legacy_conf() {
    local first_home="${1:-}" home
    [ -f "$CONF_FILE" ] && return 0
    while IFS= read -r home; do
        [ -n "$home" ] || continue
        if parse_conf "$home/.config/distroclone-backup/settings.conf"; then
            write_conf
            return 0
        fi
    done < <({ [ -n "$first_home" ] && echo "$first_home"; getent passwd | awk -F: '$3>=1000 && $3<65534 {print $6}'; })
    return 0
}

load_os_release() {
    local ID="" PRETTY_NAME=""
    # shellcheck disable=SC1091
    . /etc/os-release
    DISTRO_ID="$ID"
    DISTRO_PRETTY="$PRETTY_NAME"
    [[ "$DISTRO_ID" =~ ^[A-Za-z0-9._-]+$ ]] || DISTRO_ID="linux"
}

set_paths() {
    CACHE_BASE="${CACHE_BASE_DIR}/${DISTRO_ID}_backup"
    ROOTFS_CACHE="${CACHE_BASE}/.rootfs_cache"
    CACHE_META="${CACHE_BASE}/.backup_meta"
    SNAPSHOTS_DIR="${CACHE_BASE}/.snapshots"
}

reset_meta() {
    META_DATE="—"; META_DISTRO="—"; META_SIZE="—"; META_KERNEL="—"; META_HOME="FALSE"
}

# Metadata is read from the cache disk: parse it, never source it.
read_meta() {
    reset_meta
    [ -f "$CACHE_META" ] && [ ! -L "$CACHE_META" ] || return 0
    local line key value
    while IFS= read -r line || [ -n "$line" ]; do
        [[ "$line" =~ ^(META_[A-Z]+)=(.*)$ ]] || continue
        key="${BASH_REMATCH[1]}"; value="${BASH_REMATCH[2]}"
        if [[ "$value" =~ ^\"(.*)\"$ ]]; then value="${BASH_REMATCH[1]}"; fi
        value=$(clean_value "$value")
        [ -n "$value" ] || continue
        case "$key" in
            META_DATE)   META_DATE="$value" ;;
            META_DISTRO) META_DISTRO="$value" ;;
            META_SIZE)   META_SIZE="$value" ;;
            META_KERNEL) META_KERNEL="$value" ;;
            META_HOME)   if [ "$value" = TRUE ]; then META_HOME="TRUE"; fi ;;
        esac
    done < "$CACHE_META"
}

write_meta() {
    local include_home="${1:-FALSE}" tmp size
    size=$(du -sh "$ROOTFS_CACHE" 2>/dev/null | cut -f1)
    tmp=$(mktemp "$CACHE_BASE/.backup_meta.XXXXXX") || return 1
    {
        printf 'META_DATE=%s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
        printf 'META_DISTRO=%s\n' "$(clean_value "$DISTRO_PRETTY")"
        printf 'META_SIZE=%s\n' "$size"
        printf 'META_KERNEL=%s\n' "$(uname -r)"
        printf 'META_HOME=%s\n' "$include_home"
    } > "$tmp"
    chmod 644 "$tmp"
    mv -f "$tmp" "$CACHE_META"
}

# Snapshot metadata of the raw btrfs mode (same rules as read_meta).
read_snap_meta() {
    SNAP_DATE="—"; SNAP_DISTRO="—"; SNAP_SIZE="—"
    local file="$1" line key value
    [ -f "$file" ] && [ ! -L "$file" ] || return 0
    while IFS= read -r line || [ -n "$line" ]; do
        [[ "$line" =~ ^(SNAP_[A-Z]+)=(.*)$ ]] || continue
        key="${BASH_REMATCH[1]}"; value="${BASH_REMATCH[2]}"
        if [[ "$value" =~ ^\"(.*)\"$ ]]; then value="${BASH_REMATCH[1]}"; fi
        value=$(clean_value "$value")
        [ -n "$value" ] || continue
        case "$key" in
            SNAP_DATE)   SNAP_DATE="$value" ;;
            SNAP_DISTRO) SNAP_DISTRO="$value" ;;
            SNAP_SIZE)   SNAP_SIZE="$value" ;;
        esac
    done < "$file"
}

# ── Logging ─────────────────────────────────────────────────
init_log() {
    if [ ! -e "$LOG_FILE" ]; then
        install -m 640 -o root -g adm /dev/null "$LOG_FILE" 2>/dev/null \
            || install -m 640 /dev/null "$LOG_FILE" 2>/dev/null || true
    fi
    chmod 640 "$LOG_FILE" 2>/dev/null || true
}

LOG_PID=""

log() {
    local line
    line="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    printf '%s\n' "$line" >> "$LOG_FILE" 2>/dev/null || true
    { printf '%s\n' "$line" >&3; } 2>/dev/null || true
}

# ── One operation at a time (cron and interface share the cache) ─
acquire_lock() {
    { exec 9>"$LOCK_FILE"; } 2>/dev/null || return 1
    flock -n 9
}
release_lock() { { exec 9>&-; } 2>/dev/null || true; }

# Keep only the shell-safe prefix of a name used in rsync patterns.
rsync_escape() {
    local s="$1" out="" c i
    for ((i=0; i<${#s}; i++)); do
        c="${s:i:1}"
        case "$c" in
            '['|']'|'\'|'*'|'?') out+="\\$c" ;;
            *) out+="$c" ;;
        esac
    done
    printf '%s' "$out"
}

# Cache and snapshot paths that "Delete cache" may remove.
safe_cache_target() {
    local p="$1"
    [ -n "$p" ] && [ ! -L "$p" ] || return 1
    case "$p" in
        "$CACHE_BASE_DIR/${DISTRO_ID}_backup/"*) ;;
        *) return 1 ;;
    esac
    [[ "/$p/" != *"/../"* ]]
}

# ════════════════════════════════════════════════════════════
#  BTRFS / SNAPPER VERSIONING
# ════════════════════════════════════════════════════════════
is_btrfs() {
    [ "$(findmnt -no FSTYPE -T "$CACHE_BASE_DIR" 2>/dev/null | head -n 1)" = "btrfs" ]
}

has_snapper() { command -v snapper >/dev/null 2>&1; }

# "snapper" | "btrfs" (raw snapshots) | "none"
versioning_mode() {
    if ! is_btrfs; then echo "none"; return; fi
    if has_snapper; then echo "snapper"; return; fi
    echo "btrfs"
}

init_btrfs_subvolume() {
    if [ ! -d "$ROOTFS_CACHE" ]; then
        install -d -m 700 "$CACHE_BASE"
        btrfs subvolume create "$ROOTFS_CACHE" >/dev/null 2>&1
        return 0
    fi
    if ! btrfs subvolume show "$ROOTFS_CACHE" >/dev/null 2>&1; then
        log "$S_BTRFS_NOT_SUBVOL_WARN"
        return 1
    fi
    return 0
}

create_snapshot() {
    local snap_name size
    snap_name="@$(date '+%Y-%m-%d_%H:%M')"
    install -d -m 700 "$SNAPSHOTS_DIR"
    log "$S_SNAP_CREATING $snap_name"
    if btrfs subvolume snapshot -r "$ROOTFS_CACHE" "$SNAPSHOTS_DIR/$snap_name" >/dev/null 2>&1; then
        size=$(du -sh "$SNAPSHOTS_DIR/$snap_name" 2>/dev/null | cut -f1)
        {
            printf 'SNAP_DATE=%s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
            printf 'SNAP_DISTRO=%s\n' "$(clean_value "$DISTRO_PRETTY")"
            printf 'SNAP_KERNEL=%s\n' "$(uname -r)"
            printf 'SNAP_SIZE=%s\n' "$size"
        } > "$SNAPSHOTS_DIR/${snap_name}.meta"
        log "$S_SNAP_CREATED $SNAPSHOTS_DIR/$snap_name"
        return 0
    fi
    log "$S_SNAP_ERR_TEXT"
    return 1
}

list_snapshots() {
    [ -d "$SNAPSHOTS_DIR" ] || return 0
    find "$SNAPSHOTS_DIR" -maxdepth 1 -name '@*' -type d | sort
}

prune_snapshots() {
    [ "${MAX_SNAPSHOTS:-3}" -le 0 ] && return 0
    local snaps count i to_delete
    mapfile -t snaps < <(list_snapshots)
    count=${#snaps[@]}
    if [ "$count" -gt "$MAX_SNAPSHOTS" ]; then
        log "$S_SNAP_PRUNING"
        to_delete=$(( count - MAX_SNAPSHOTS ))
        for (( i=0; i<to_delete; i++ )); do
            btrfs subvolume delete "${snaps[$i]}" >/dev/null 2>&1
            rm -f -- "${snaps[$i]}.meta" 2>/dev/null
            log "  Removed: $(basename "${snaps[$i]}")"
        done
    fi
}

init_snapper_config() {
    init_btrfs_subvolume || return 1
    if ! snapper -c "$SNAPPER_CFG_NAME" get-config >/dev/null 2>&1; then
        snapper -c "$SNAPPER_CFG_NAME" create-config "$ROOTFS_CACHE" >/dev/null 2>&1 || return 1
        snapper -c "$SNAPPER_CFG_NAME" set-config TIMELINE_CREATE=no >/dev/null 2>&1 || true
        snapper -c "$SNAPPER_CFG_NAME" set-config NUMBER_CLEANUP=yes >/dev/null 2>&1 || true
    fi
    local lim="${MAX_SNAPSHOTS:-3}"
    [ "$lim" -le 0 ] && lim=999
    snapper -c "$SNAPPER_CFG_NAME" set-config NUMBER_LIMIT="$lim" >/dev/null 2>&1 || true
    snapper -c "$SNAPPER_CFG_NAME" set-config NUMBER_LIMIT_IMPORTANT="$lim" >/dev/null 2>&1 || true
    return 0
}

create_snapper_snapshot() {
    local size_kb distro desc
    size_kb=$(du -sk "$ROOTFS_CACHE" 2>/dev/null | cut -f1)
    distro="${DISTRO_PRETTY//,/ }"
    distro="${distro//=/ }"
    desc="distroclone-backup $(date '+%Y-%m-%d %H:%M:%S')"
    log "$S_SNAP_CREATING"
    if snapper -c "$SNAPPER_CFG_NAME" create --type single --description "$desc" \
            --userdata "distro=${distro},kernel=$(uname -r),size_kb=${size_kb}" >/dev/null 2>&1; then
        log "$S_SNAP_CREATED $desc"
        return 0
    fi
    log "$S_SNAP_ERR_TEXT"
    return 1
}

# Machine-readable snapper table: "col1;col2;..." without header.
snapper_csv() {
    local out
    out=$(snapper -c "$SNAPPER_CFG_NAME" --csvout --separator ';' list --type single --columns "$1" 2>/dev/null) \
        || out=$(snapper -c "$SNAPPER_CFG_NAME" --machine-readable csv --separator ';' list --type single --columns "$1" 2>/dev/null) \
        || return 1
    printf '%s\n' "$out" | tail -n +2
}

# "N|PATH" lines, oldest first.
list_snapper_snapshots() {
    local n p
    snapper_csv number | awk -F';' '$1 ~ /^[0-9]+$/ && $1 > 0 {print $1}' | sort -n \
        | while read -r n; do
            p="$ROOTFS_CACHE/.snapshots/$n/snapshot"
            [ -d "$p" ] && echo "$n|$p"
        done
}

# One field of a "k=v,k=v" userdata string.
ud_get() {
    local ud="$1" key="$2" kv
    local IFS=','
    for kv in $ud; do
        if [ "${kv%%=*}" = "$key" ]; then printf '%s' "${kv#*=}"; return 0; fi
    done
    return 0
}

prune_snapper_snapshots() {
    log "$S_SNAP_PRUNING"
    snapper -c "$SNAPPER_CFG_NAME" cleanup number >/dev/null 2>&1 || true
}

unified_list_snapshots() {
    local mode p
    mode=$(versioning_mode)
    case "$mode" in
        snapper) list_snapper_snapshots ;;
        btrfs)
            while IFS= read -r p; do
                [ -n "$p" ] && echo "$(basename "$p")|$p"
            done < <(list_snapshots)
            ;;
    esac
}

# ════════════════════════════════════════════════════════════
#  RSYNC EXCLUDES — shared by backup and restore
# ════════════════════════════════════════════════════════════
# Both directions must skip the same paths: restore runs with --delete.
build_common_excludes() {
    EXCL=(
        '--exclude=/dev/*' '--exclude=/proc/*' '--exclude=/sys/*'
        '--exclude=/run/*' '--exclude=/tmp/*' '--exclude=/mnt/*'
        '--exclude=/media/*' '--exclude=/lost+found' '--exclude=/swapfile'
        '--exclude=/boot/efi' '--exclude=/boot/efi/*'
        '--exclude=/var/cache/apt/archives/*' '--exclude=/var/lib/apt/lists/*'
        '--exclude=/var/log/*' '--exclude=/var/tmp/*'
        '--exclude=/etc/NetworkManager/system-connections/*'
        '--exclude=/etc/distroclone-backup'
        '--exclude=/usr/share/distroclone-backup'
        '--exclude=/usr/bin/distroClone-backup'
        '--exclude=/snap' '--exclude=/snap/*' '--exclude=/var/snap'
        '--exclude=/var/lib/snapd'
        # btrfs nested subvolumes (system snapshots, snapper cache).
        '--exclude=/.snapshots' '--exclude=/.snapshots/*'
        '--exclude=/var/lib/snapper'
        "--exclude=$(rsync_escape "$CACHE_BASE")"
    )
    # Site-specific patterns: /etc/distroclone-backup/exclude.list (one per line).
    if [ -f "$EXCLUDE_FILE" ] && [ ! -L "$EXCLUDE_FILE" ]; then
        local line
        while IFS= read -r line || [ -n "$line" ]; do
            [[ "$line" =~ ^/[^[:cntrl:]]*$ ]] && EXCL+=("--exclude=$line")
        done < "$EXCLUDE_FILE"
    fi
}

build_backup_excludes() {
    build_common_excludes
    if [ "$1" != "TRUE" ]; then
        EXCL+=('--exclude=/home/*' '--exclude=/root/*')
    fi
}

# Restore: never enter another filesystem mounted on the live system
# (a separate /boot, /data, /srv…): its files are absent from the cache and
# --delete would wipe them.
build_restore_excludes() {
    build_common_excludes
    if [ "$1" != "TRUE" ]; then
        EXCL+=('--exclude=/home' '--exclude=/home/*' '--exclude=/root' '--exclude=/root/*')
    fi
    local t
    while IFS= read -r t; do
        [ -n "$t" ] && [ "$t" != "/" ] || continue
        EXCL+=("--exclude=$(rsync_escape "$t")")
    done < <(findmnt -lno TARGET 2>/dev/null)
}

# Run rsync, feeding its progress into the log; closing the log window
# (the Stop button) terminates the transfer. Result in RSYNC_RC.
RSYNC_RC=0
RSYNC_CANCELLED=0
rsync_run() {
    local fifo reader rsync_pid
    RSYNC_CANCELLED=0
    fifo=$(mktemp -u /run/distroclone-backup-fifo.XXXXXXXX)
    mkfifo -m 600 "$fifo" || { RSYNC_RC=1; return; }
    rsync "$@" >"$fifo" 2>&1 &
    rsync_pid=$!
    (
        tr '\r' '\n' <"$fifo" | while IFS= read -r line; do
            [ -n "$line" ] && log "$line"
        done
    ) &
    reader=$!
    while kill -0 "$rsync_pid" 2>/dev/null; do
        if [ -n "$LOG_PID" ] && ! kill -0 "$LOG_PID" 2>/dev/null; then
            kill -TERM "$rsync_pid" 2>/dev/null
            RSYNC_CANCELLED=1
            break
        fi
        sleep 0.5
    done
    wait "$rsync_pid"; RSYNC_RC=$?
    wait "$reader" 2>/dev/null
    rm -f -- "$fifo"
}

rsync_ok() { [ "$RSYNC_RC" -eq 0 ] || [ "$RSYNC_RC" -eq 24 ]; }

# ════════════════════════════════════════════════════════════
#  BACKUP / RESTORE ENGINE (shared by the interface and cron)
# ════════════════════════════════════════════════════════════
# $1 = full|incremental   $2 = TRUE|FALSE include /home and /root
# Returns 0 on success; BACKUP_ERR holds the S_ERR_* message otherwise.
BACKUP_ERR=""
backup_core() {
    local mode="$1" inc_home="$2" mode_v progress=()
    BACKUP_ERR=""
    if ! valid_dir_path "$CACHE_BASE_DIR" || [ ! -d "$CACHE_BASE_DIR" ]; then
        BACKUP_ERR="$S_SETTINGS_WARN_DIR"; return 1
    fi
    [ -n "$LOG_PID" ] && progress=(--info=progress2)

    mode_v=$(versioning_mode)
    log "Versioning mode: $mode_v"
    case "$mode_v" in
        snapper)
            if init_snapper_config && [ -f "$CACHE_META" ]; then
                create_snapper_snapshot
            fi
            ;;
        btrfs)
            if init_btrfs_subvolume && [ -f "$CACHE_META" ]; then
                create_snapshot
            fi
            ;;
        *)
            install -d -m 700 "$CACHE_BASE"
            install -d -m 755 "$ROOTFS_CACHE"
            ;;
    esac
    [ -d "$ROOTFS_CACHE" ] || install -d -m 755 "$ROOTFS_CACHE"
    chmod 700 "$CACHE_BASE" 2>/dev/null || true

    build_backup_excludes "$inc_home"
    local opts=(-aAXH --numeric-ids --one-file-system --delete)
    if [ "$mode" = "incremental" ]; then
        opts+=(--update)
        log "$S_BACKUP_MODE_INC"
    else
        log "$S_BACKUP_MODE_FULL"
    fi
    log "$S_BACKUP_RSYNC_START"
    rsync_run "${opts[@]}" "${EXCL[@]}" "${progress[@]}" / "$ROOTFS_CACHE"

    if [ "$RSYNC_CANCELLED" -eq 1 ]; then BACKUP_ERR="$S_OP_CANCELLED"; return 1; fi
    if rsync_ok; then
        write_meta "$inc_home"
        # Rotate only after a successful copy, so failed runs never push good
        # snapshots out of the retention window.
        case "$mode_v" in
            snapper) prune_snapper_snapshots ;;
            btrfs)   prune_snapshots ;;
        esac
        return 0
    fi
    BACKUP_ERR="rsync exit code: $RSYNC_RC"
    return 1
}

# $1 = source tree   $2 = TRUE|FALSE restore /home and /root
# Refreshes the boot files afterwards: the restored system may carry other
# kernels or modules than the ones the bootloader knows.
restore_core() {
    local src="$1" restore_home="$2" progress=()
    [ -n "$LOG_PID" ] && progress=(--info=progress2)
    build_restore_excludes "$restore_home"
    rsync_run -aAXH --numeric-ids --delete --delete-after "${EXCL[@]}" "${progress[@]}" "$src/" /
    if [ "$RSYNC_CANCELLED" -eq 1 ]; then BACKUP_ERR="$S_OP_CANCELLED"; return 1; fi
    if rsync_ok; then
        if command -v update-initramfs >/dev/null 2>&1; then
            log "→ update-initramfs -u -k all"
            update-initramfs -u -k all >> "$LOG_FILE" 2>&1 || log "⚠ update-initramfs failed"
        fi
        if command -v update-grub >/dev/null 2>&1; then
            log "→ update-grub"
            update-grub >> "$LOG_FILE" 2>&1 || log "⚠ update-grub failed"
        fi
        return 0
    fi
    BACKUP_ERR="rsync exit code: $RSYNC_RC"
    return 1
}

# ── Schedule helpers ─────────────────────────────────────────
cron_current() { crontab -l 2>/dev/null | grep -E "$CRON_PATTERN" || true; }
cron_remove() { crontab -l 2>/dev/null | grep -vE "$CRON_PATTERN" | crontab - 2>/dev/null || true; }

# Position of the chosen day in the (translated) list: Monday=1 … Sunday=0.
day_to_dow() {
    local chosen="$1" days d i=0
    IFS='!' read -ra days <<< "$S_CRON_DAYS"
    for d in "${days[@]}"; do
        i=$((i + 1))
        if [ "$d" = "$chosen" ]; then echo $(( i % 7 )); return; fi
    done
    echo 1
}

freq_to_cron() {
    local freq="$1" hour="$2" dow="$3"
    [ "$freq" = "$S_CRON_FREQ_DAILY" ]   && echo "0 $hour * * *"
    [ "$freq" = "$S_CRON_FREQ_WEEKLY" ]  && echo "0 $hour * * $dow"
    [ "$freq" = "$S_CRON_FREQ_MONTHLY" ] && echo "0 $hour 1 * *"
    return 0
}

# The cron job runs as root without a session: tell the logged-in users.
notify_users() {
    command -v notify-send >/dev/null 2>&1 && command -v runuser >/dev/null 2>&1 || return 0
    local d uid user
    for d in /run/user/*; do
        uid="${d##*/}"
        [[ "$uid" =~ ^[0-9]+$ ]] && [ "$uid" -ge 1000 ] && [ -S "$d/bus" ] || continue
        user=$(getent passwd "$uid" | cut -d: -f1)
        [ -n "$user" ] || continue
        runuser -u "$user" -- env "DBUS_SESSION_BUS_ADDRESS=unix:path=$d/bus" \
            notify-send 'DistroClone Backup' "$S_CRON_NOTIFY_MSG" --icon=distroclone-backup \
            >/dev/null 2>&1 || true
    done
}

# ════════════════════════════════════════════════════════════
#  CRON MODE
# ════════════════════════════════════════════════════════════
cron_main() {
    load_os_release
    parse_conf "$CONF_FILE"
    set_paths
    init_log
    log "── Incremental backup (cron) ──"
    log "   Cache: $ROOTFS_CACHE"

    if ! acquire_lock; then
        log "Another backup operation is running: skipped"
        return 0
    fi
    if [ ! -d "$ROOTFS_CACHE" ] || [ ! -f "$CACHE_META" ]; then
        log "ERROR: no complete cache found: $ROOTFS_CACHE (run a Full Backup first)"
        release_lock
        return 1
    fi
    if backup_core incremental "$INCLUDE_HOME"; then
        log "✓ Incremental backup completed  ($(du -sh "$ROOTFS_CACHE" 2>/dev/null | cut -f1))"
        release_lock
        [ "$NOTIFY" = "TRUE" ] && notify_users
        return 0
    fi
    log "✗ Backup error: $BACKUP_ERR"
    release_lock
    return 1
}

# ════════════════════════════════════════════════════════════
#  GRAPHICAL INTERFACE (runs as root, started through pkexec)
# ════════════════════════════════════════════════════════════
LOGO=""

# Give each button of a dialog its own Alt+key (first free letter).
MNB=()
mn_set() {
    MNB=()
    local used="" spec text rest i ch low out
    for spec in "$@"; do
        if [[ "$spec" == *'!'* ]]; then
            text="${spec%%!*}"; rest="!${spec#*!}"
        elif [[ "$spec" == *:* ]]; then
            text="${spec%:*}"; rest=":${spec##*:}"
        else
            text="$spec"; rest=""
        fi
        out="$text"
        for ((i=0; i<${#text}; i++)); do
            ch="${text:i:1}"
            [[ "$ch" =~ [[:alnum:]] ]] || continue
            low="${ch,,}"
            [[ "$used" == *"$low"* ]] && continue
            used+="$low"
            out="${text:0:i}_${text:i}"
            break
        done
        MNB+=("$out$rest")
    done
}

error_dialog() {
    mn_set "$S_BTN_OK"
    yad --error --title="$S_APP_TITLE_WIN" ${LOGO:+--window-icon="$LOGO"} \
        --text="$(esc "$1")" --button="${MNB[0]}" --width=440 --center 2>/dev/null
}

# Last log lines, escaped for markup, shown when an operation fails.
error_tail() {
    local t
    t=$(tail -n 8 "$LOG_FILE" 2>/dev/null | cut -c1-160)
    esc "$t"
}

open_log_window() {
    mn_set "$S_BTN_STOP"
    exec 3> >(yad --text-info \
        --title="$S_BACKUP_TITLE" \
        ${LOGO:+--window-icon="$LOGO"} \
        ${LOGO:+--image="$LOGO"} \
        --image-on-top \
        --fontname="Monospace 10" \
        --width=560 --height=400 \
        --tail --no-edit \
        --button="${MNB[0]}" \
        --center 2>/dev/null)
    LOG_PID=$!
}

close_log_window() {
    { exec 3>&-; } 2>/dev/null || true
    if [ -n "$LOG_PID" ] && kill -0 "$LOG_PID" 2>/dev/null; then
        sleep 2; kill "$LOG_PID" 2>/dev/null
        wait "$LOG_PID" 2>/dev/null || true
    fi
    LOG_PID=""
}

cleanup_gui() {
    trap - EXIT INT TERM
    [ -n "$LOG_PID" ] && kill "$LOG_PID" 2>/dev/null
    release_lock
    exit "${1:-0}"
}

############################################################
# BACKUP
############################################################
do_backup() {
    local MODE="$1" OPT_RESULT SEL

    mn_set "$S_BTN_CANCEL" "$S_BTN_BACKUP_START"
    OPT_RESULT=$(yad --form \
        --title="$S_APP_TITLE_WIN" \
        ${LOGO:+--window-icon="$LOGO"} \
        ${LOGO:+--image="$LOGO"} \
        --image-on-top \
        --width=480 --height=240 \
        --text="<big><b>$S_BACKUP_OPT_TITLE ($MODE)</b></big>\n\n$S_HOME_INCLUDE_WARN\n" \
        --separator="|" \
        --field="$S_HOME_INCLUDE:":CHK "$INCLUDE_HOME" \
        --button="${MNB[0]}" \
        --button="${MNB[1]}" \
        --buttons-layout=spread \
        --center 2>/dev/null)
    [ $? -ne 0 ] && return
    SEL=$(cut -d'|' -f1 <<< "$OPT_RESULT")
    [ "$SEL" = "TRUE" ] || SEL="FALSE"

    if ! acquire_lock; then error_dialog "$S_ERR_BUSY"; return; fi

    open_log_window
    log "══════════════════════════════════════════"
    log " DistroClone — BACKUP ($MODE)"
    log "══════════════════════════════════════════"
    log " Distro : $DISTRO_PRETTY"
    log " Kernel : $(uname -r)"
    log " Cache  : $ROOTFS_CACHE"
    if [ "$SEL" = "TRUE" ]; then
        log " /home  : $S_HOME_INCLUDED"
    else
        log " /home  : $S_HOME_EXCLUDED"
    fi
    log "══════════════════════════════════════════"

    if backup_core "$MODE" "$SEL"; then
        INCLUDE_HOME="$SEL"
        write_conf
        local size
        size=$(du -sh "$ROOTFS_CACHE" 2>/dev/null | cut -f1)
        log ""; log "✓ Backup OK — $size"
        close_log_window
        release_lock
        mn_set "$S_BTN_OK"
        yad --info \
            --title="$S_BACKUP_OK_TITLE" \
            ${LOGO:+--window-icon="$LOGO"} \
            ${LOGO:+--image="$LOGO"} \
            --text="$S_BACKUP_OK_TEXT\n\n\
<b>Distro:</b> $(esc "$DISTRO_PRETTY")\n\
<b>$S_KERNEL:</b> $(uname -r)\n\
<b>$S_BACKUP_OK_DATE:</b> $(date '+%Y-%m-%d %H:%M')\n\
<b>$S_BACKUP_OK_SIZE:</b> $size\n\
<b>$S_CACHE:</b> $(esc "$ROOTFS_CACHE")" \
            --button="${MNB[0]}" --width=480 --height=240 --center 2>/dev/null
    else
        log ""; log "✗ Backup ERROR: $BACKUP_ERR"
        close_log_window
        release_lock
        mn_set "$S_BTN_OK"
        yad --error \
            --title="$S_BACKUP_ERR_TITLE" \
            ${LOGO:+--window-icon="$LOGO"} \
            --text="$S_BACKUP_ERR_TEXT\n\n$(esc "$BACKUP_ERR")\n\n$S_LOG: $LOG_FILE\n\n<tt>$(error_tail)</tt>" \
            --button="${MNB[0]}" --width=480 --center 2>/dev/null
    fi
}

############################################################
# RESTORE — the cache must be a complete system of this distribution
############################################################
restore_done_dialogs() {  # $1 = TRUE|FALSE home restored   $2 = label text
    local protected
    if [ "$1" = "TRUE" ]; then
        protected="<b>/boot/efi ✓   /snap ✓</b>"
    else
        protected="$S_RESTORE_OK_PROTECTED"
    fi
    mn_set "$S_BTN_REBOOT_NOW" "$S_BTN_REBOOT_LATER"
    yad --info \
        --title="$S_RESTORE_OK_TITLE" \
        ${LOGO:+--window-icon="$LOGO"} \
        ${LOGO:+--image="$LOGO"} \
        --text="$S_RESTORE_OK_TEXT\n\n$2\n\n${protected}\n\n$S_RESTORE_OK_REBOOT" \
        --button="${MNB[0]}" \
        --button="${MNB[1]}" \
        --buttons-layout=spread \
        --width=480 --height=300 --center 2>/dev/null
    [ $? -eq 10 ] && systemctl reboot
}

do_restore() {
    read_meta
    if [ ! -f "$CACHE_META" ]; then
        error_dialog "$S_ERR_CACHE_INCOMPLETE"
        return
    fi

    local OPT_RESULT RESTORE_HOME
    mn_set "$S_BTN_CANCEL" "$S_BTN_YES_RESTORE"
    OPT_RESULT=$(yad --form \
        --title="$S_RESTORE_TITLE" \
        ${LOGO:+--window-icon="$LOGO"} \
        ${LOGO:+--image="$LOGO"} \
        --image-on-top \
        --separator="|" \
        --text="$S_RESTORE_WARN_TITLE\n\n\
$S_RESTORE_WARN_TEXT\n\n\
$S_RESTORE_INFO_TITLE\n\
  • $S_RESTORE_INFO_DATE:    <b>$(esc "$META_DATE")</b>\n\
  • $S_RESTORE_INFO_DISTRO:  <b>$(esc "$META_DISTRO")</b>\n\
  • $S_RESTORE_INFO_KERNEL:  <b>$(esc "$META_KERNEL")</b>\n\
  • $S_RESTORE_INFO_SIZE:    <b>$(esc "$META_SIZE")</b>\n\n\
$S_HOME_INCLUDE_WARN\n" \
        --field="$S_HOME_INCLUDE:":CHK "FALSE" \
        --button="${MNB[0]}" \
        --button="${MNB[1]}" \
        --buttons-layout=spread \
        --width=520 --height=500 --center 2>/dev/null)
    [ $? -ne 0 ] && return

    RESTORE_HOME=$(cut -d'|' -f1 <<< "$OPT_RESULT")
    [ "$RESTORE_HOME" = "TRUE" ] || RESTORE_HOME="FALSE"
    # --delete would erase every home directory if the backup never held them.
    if [ "$RESTORE_HOME" = "TRUE" ] && [ "$META_HOME" != "TRUE" ]; then
        error_dialog "$S_ERR_NO_HOME_BACKUP"
        return
    fi
    if ! acquire_lock; then error_dialog "$S_ERR_BUSY"; return; fi

    open_log_window
    log "══════════════════════════════════════════"
    log " $S_RESTORE_LOG_TITLE"
    log "══════════════════════════════════════════"
    log " $S_RESTORE_LOG_FROM  : $ROOTFS_CACHE"
    log " $S_RESTORE_LOG_TO    : /"
    if [ "$RESTORE_HOME" = "TRUE" ]; then
        log " /home  : $S_HOME_INCLUDED"
    else
        log " /home  : $S_HOME_EXCLUDED"
    fi
    log " $S_RESTORE_LOG_PROTECTED : /boot/efi /snap"
    log "══════════════════════════════════════════"
    log "$S_RESTORE_RSYNC_START"

    if restore_core "$ROOTFS_CACHE" "$RESTORE_HOME"; then
        log ""; log "✓ Restore OK"
        close_log_window
        release_lock
        restore_done_dialogs "$RESTORE_HOME" "$S_RESTORE_OK_DATE\n<b>$(esc "$META_DATE")</b>"
    else
        log ""; log "✗ Restore ERROR: $BACKUP_ERR"
        close_log_window
        release_lock
        mn_set "$S_BTN_OK"
        yad --error \
            --title="$S_RESTORE_ERR_TITLE" \
            ${LOGO:+--window-icon="$LOGO"} \
            --text="$S_RESTORE_ERR_TEXT\n\n$(esc "$BACKUP_ERR")\n\n$S_LOG: $LOG_FILE\n\n<tt>$(error_tail)</tt>" \
            --button="${MNB[0]}" --width=480 --center 2>/dev/null
    fi
}

############################################################
# RESTORE FROM SNAPSHOT
############################################################
do_restore_snapshot() {
    local snap_lines=() line label snap_path list_args=() MODE_V
    mapfile -t snap_lines < <(unified_list_snapshots)

    if [ ${#snap_lines[@]} -eq 0 ]; then
        mn_set "$S_BTN_OK"
        yad --warning ${LOGO:+--window-icon="$LOGO"} \
            --title="$S_SNAP_SELECT_TITLE" \
            --text="$S_SNAP_NO_SNAPS" \
            --button="${MNB[0]}" --width=380 --center 2>/dev/null
        return
    fi

    MODE_V=$(versioning_mode)
    local snap_date snap_distro snap_size size_kb info ud
    for line in "${snap_lines[@]}"; do
        label="${line%%|*}"
        snap_path="${line#*|}"
        if [ "$MODE_V" = "snapper" ]; then
            info=$(snapper_csv number,date,userdata | awk -F';' -v n="$label" '$1==n {print $2 ";" $3; exit}')
            snap_date="${info%%;*}"
            ud="${info#*;}"
            snap_distro=$(ud_get "$ud" distro)
            size_kb=$(ud_get "$ud" size_kb)
            if [[ "$size_kb" =~ ^[0-9]+$ ]] && [ "$size_kb" -gt 0 ]; then
                snap_size=$(numfmt --to=iec --suffix=B "$((size_kb*1024))" 2>/dev/null || echo "${size_kb}K")
            else
                snap_size=$(du -sh "$snap_path" 2>/dev/null | cut -f1)
            fi
            snap_date=$(clean_value "$snap_date"); snap_distro=$(clean_value "$snap_distro")
            [ -z "$snap_date" ]   && snap_date="—"
            [ -z "$snap_distro" ] && snap_distro="—"
            [ -z "$snap_size" ]   && snap_size="—"
            list_args+=("$snap_path" "snapper #$label" "$snap_date" "$snap_distro" "$snap_size")
        else
            read_snap_meta "${snap_path}.meta"
            list_args+=("$snap_path" "$label" "$SNAP_DATE" "$SNAP_DISTRO" "$SNAP_SIZE")
        fi
    done

    local SELECTED SNAP_PATH
    mn_set "$S_BTN_CANCEL" "$S_BTN_YES_RESTORE"
    SELECTED=$(yad --list \
        --title="$S_SNAP_SELECT_TITLE" \
        ${LOGO:+--window-icon="$LOGO"} \
        --text="$S_SNAP_SELECT_TEXT\n" \
        --column="Path:HD" --column="Snapshot" --column="$S_RESTORE_INFO_DATE" \
        --column="$S_RESTORE_INFO_DISTRO" --column="$S_RESTORE_INFO_SIZE" \
        --width=640 --height=320 \
        --button="${MNB[0]}" \
        --button="${MNB[1]}" \
        --center 2>/dev/null \
        "${list_args[@]}")
    [ $? -ne 0 ] && return
    SNAP_PATH=$(cut -d'|' -f1 <<< "$SELECTED")
    [ -z "$SNAP_PATH" ] && return

    # Only a path offered by the list is accepted, and it must be a whole system.
    local known=0
    for line in "${snap_lines[@]}"; do
        [ "${line#*|}" = "$SNAP_PATH" ] && known=1
    done
    if [ "$known" -ne 1 ]; then
        error_dialog "$S_ERR_CACHE_INCOMPLETE"
        return
    fi

    local CONFIRM
    mn_set "$S_BTN_CANCEL" "$S_BTN_YES_RESTORE"
    CONFIRM=$(yad --form \
        --title="$S_SNAP_SELECT_TITLE" \
        ${LOGO:+--window-icon="$LOGO"} \
        --separator="|" \
        --text="$S_RESTORE_WARN_TEXT\n\n<b>Snapshot:</b> $(esc "$(basename "$SNAP_PATH")")\n\n$S_RESTORE_CONFIRM\n" \
        --button="${MNB[0]}" \
        --button="${MNB[1]}" \
        --width=460 --height=240 --center 2>/dev/null)
    [ $? -ne 0 ] && return
    if ! acquire_lock; then error_dialog "$S_ERR_BUSY"; return; fi

    open_log_window
    log "══════════════════════════════════════════"
    log " DistroClone — RESTORE FROM SNAPSHOT"
    log " $S_RESTORE_LOG_FROM: $SNAP_PATH"
    log " $S_RESTORE_LOG_TO:   /"
    log "══════════════════════════════════════════"
    log "$S_RESTORE_RSYNC_START"

    if restore_core "$SNAP_PATH" "FALSE"; then
        log ""; log "✓ Restore from snapshot OK"
        close_log_window
        release_lock
        restore_done_dialogs "FALSE" "<b>Snapshot:</b> $(esc "$(basename "$SNAP_PATH")")"
    else
        log ""; log "✗ Restore ERROR: $BACKUP_ERR"
        close_log_window
        release_lock
        mn_set "$S_BTN_OK"
        yad --error \
            --title="$S_SNAP_ERR_TITLE" \
            ${LOGO:+--window-icon="$LOGO"} \
            --text="$S_SNAP_ERR_TEXT\n\n$(esc "$BACKUP_ERR")\n\n$S_LOG: $LOG_FILE\n\n<tt>$(error_tail)</tt>" \
            --button="${MNB[0]}" --width=480 --center 2>/dev/null
    fi
}

############################################################
# SCHEDULE
############################################################
do_cronjob() {
    local CURRENT_CRON CRON_STATUS CRON_INFO RESULT EXIT_CODE
    CURRENT_CRON=$(cron_current)
    if [ -n "$CURRENT_CRON" ]; then
        CRON_STATUS="$S_CRON_STATUS_ACTIVE"
        CRON_INFO="<small><tt>$(esc "$CURRENT_CRON")</tt></small>"
    else
        CRON_STATUS="$S_CRON_STATUS_NONE"
        CRON_INFO="$S_CRON_STATUS_NOCRON"
    fi

    mn_set "$S_BTN_REMOVE" "$S_BTN_CANCEL" "$S_BTN_SAVE"
    RESULT=$(yad --form \
        --title="$S_CRON_DIALOG_TITLE" \
        ${LOGO:+--window-icon="$LOGO"} \
        ${LOGO:+--image="$LOGO"} \
        --image-on-top \
        --width=540 --height=460 \
        --text="$S_CRON_DIALOG_HEADER\n\n\
<b>$S_STATUS_LABEL:</b> $CRON_STATUS\n$CRON_INFO\n\n\
$S_CRON_HINT\n" \
        --separator="|" \
        --field="$S_CRON_FIELD_FREQ:":CB "$S_CRON_FREQ_DAILY!$S_CRON_FREQ_WEEKLY!$S_CRON_FREQ_MONTHLY" \
        --field="$S_CRON_FIELD_DAY:":CB "$S_CRON_DAYS" \
        --field="$S_CRON_FIELD_HOUR:":NUM "2!0..23!1!0" \
        --field="$S_CRON_FIELD_NOTIFY:":CHK "$NOTIFY" \
        --button="${MNB[0]}" \
        --button="${MNB[1]}" \
        --button="${MNB[2]}" \
        --buttons-layout=spread --center 2>/dev/null)
    EXIT_CODE=$?

    if [ $EXIT_CODE -eq 20 ]; then
        cron_remove
        mn_set "$S_BTN_OK"
        yad --info ${LOGO:+--window-icon="$LOGO"} \
            --title="$S_CRON_REMOVED_TITLE" \
            --text="$S_CRON_REMOVED_TEXT\n\n<small><tt>crontab -l</tt></small>" \
            --button="${MNB[0]}" --width=380 --center 2>/dev/null
        return
    fi
    [ $EXIT_CODE -ne 0 ] && return

    local FREQ WEEKDAY HOUR NOTIFY_SEL DOW CRON_EXPR CRON_LINE
    FREQ=$(cut -d'|' -f1 <<< "$RESULT")
    WEEKDAY=$(cut -d'|' -f2 <<< "$RESULT")
    HOUR=$(cut -d'|' -f3 <<< "$RESULT" | cut -d'.' -f1)
    NOTIFY_SEL=$(cut -d'|' -f4 <<< "$RESULT")
    [[ "$HOUR" =~ ^[0-9]+$ ]] && [ "$HOUR" -le 23 ] || HOUR=2
    DOW=$(day_to_dow "$WEEKDAY")
    CRON_EXPR=$(freq_to_cron "$FREQ" "$HOUR" "$DOW")
    [ -n "$CRON_EXPR" ] || return

    # The notification choice lives in the root-owned settings, not in the crontab line.
    NOTIFY="FALSE"; [ "$NOTIFY_SEL" = "TRUE" ] && NOTIFY="TRUE"
    write_conf
    CRON_LINE="$CRON_EXPR /usr/bin/distroclone-backup --incremental-silent"
    ( crontab -l 2>/dev/null | grep -vE "$CRON_PATTERN"; echo "$CRON_LINE" ) | crontab -

    mn_set "$S_BTN_OK"
    yad --info \
        --title="$S_CRON_SAVED_TITLE" \
        ${LOGO:+--window-icon="$LOGO"} \
        ${LOGO:+--image="$LOGO"} \
        --text="$S_CRON_SAVED_TEXT\n\n\
<b>$S_CRON_FREQ_LABEL:</b> $(esc "$FREQ")  |  <b>$S_CRON_HOUR_LABEL:</b> $HOUR:00\n\n\
<b>$S_CRON_EXPR_LABEL:</b>\n<small><tt>$(esc "$CRON_LINE")</tt></small>\n\n\
<small>$S_CRON_VERIFY: <tt>crontab -l</tt>   $S_LOG: <tt>$LOG_FILE</tt></small>" \
        --button="${MNB[0]}" --width=560 --center 2>/dev/null
}

############################################################
# DELETE CACHE
############################################################
delete_cache_tree() {
    local snap
    # Snapshots first: rm cannot remove read-only btrfs subvolumes.
    #   snapper:  $ROOTFS_CACHE/.snapshots/N/snapshot   raw: $SNAPSHOTS_DIR/@*
    if [ -d "$ROOTFS_CACHE/.snapshots" ]; then
        while IFS= read -r snap; do
            safe_cache_target "$snap" && btrfs subvolume delete "$snap" >/dev/null 2>&1
        done < <(find "$ROOTFS_CACHE/.snapshots" -mindepth 2 -maxdepth 2 -name snapshot -type d 2>/dev/null | sort)
        btrfs subvolume delete "$ROOTFS_CACHE/.snapshots" >/dev/null 2>&1 || true
    fi
    if has_snapper && snapper -c "$SNAPPER_CFG_NAME" get-config >/dev/null 2>&1; then
        snapper -c "$SNAPPER_CFG_NAME" delete-config >/dev/null 2>&1 || true
    fi
    if [ -d "$SNAPSHOTS_DIR" ] && safe_cache_target "$SNAPSHOTS_DIR"; then
        while IFS= read -r snap; do
            safe_cache_target "$snap" || continue
            btrfs subvolume delete "$snap" >/dev/null 2>&1 || true
            rm -f -- "${snap}.meta" 2>/dev/null || true
        done < <(find "$SNAPSHOTS_DIR" -maxdepth 1 -name '@*' -type d 2>/dev/null | sort)
        if btrfs subvolume show "$SNAPSHOTS_DIR" >/dev/null 2>&1; then
            btrfs subvolume delete "$SNAPSHOTS_DIR" >/dev/null 2>&1 || true
        else
            rm -rf --one-file-system -- "$SNAPSHOTS_DIR" 2>/dev/null || true
        fi
    fi
    if safe_cache_target "$ROOTFS_CACHE"; then
        if btrfs subvolume show "$ROOTFS_CACHE" >/dev/null 2>&1; then
            btrfs subvolume delete "$ROOTFS_CACHE" >/dev/null 2>&1 || true
        else
            rm -rf --one-file-system -- "$ROOTFS_CACHE" 2>/dev/null || true
        fi
    fi
    [ ! -e "$ROOTFS_CACHE" ]
}

do_delete_cache() {
    read_meta
    local RES
    mn_set "$S_BTN_CANCEL" "$S_BTN_DELETE_CONFIRM"
    RES=$(yad --form \
        --title="$S_DELETE_TITLE" \
        ${LOGO:+--window-icon="$LOGO"} \
        --separator="|" \
        --text="$S_DELETE_TEXT\n\n\
<b>$S_DELETE_DATE:</b> $(esc "$META_DATE")\n\
<b>$S_DELETE_SIZE:</b> $(esc "$META_SIZE")\n\
<b>$S_DELETE_PATH:</b> $(esc "$ROOTFS_CACHE")\n\n\
$S_DELETE_WARN\n" \
        --button="${MNB[0]}" \
        --button="${MNB[1]}" \
        --buttons-layout=spread --width=440 --height=280 --center 2>/dev/null)
    [ $? -ne 0 ] && return
    if ! acquire_lock; then error_dialog "$S_ERR_BUSY"; return; fi

    if delete_cache_tree; then
        rm -f -- "$CACHE_META" 2>/dev/null || true
        cron_remove
        release_lock
        mn_set "$S_BTN_OK"
        yad --info ${LOGO:+--window-icon="$LOGO"} \
            --title="$S_DELETE_OK_TITLE" \
            --text="$S_DELETE_OK_TEXT" \
            --button="${MNB[0]}" --width=340 --center 2>/dev/null
    else
        release_lock
        error_dialog "$S_DELETE_ERR"
    fi
}

############################################################
# SETTINGS
############################################################
do_settings() {
    local CURRENT_DIR="${CACHE_BASE_DIR:-/mnt}" NEW_DIR ADV_RESULT NEW_MAX_SNAPS

    mn_set "$S_BTN_CANCEL" "$S_BTN_SAVE"
    NEW_DIR=$(yad --file-selection --directory \
        --title="$S_SETTINGS_TITLE" \
        ${LOGO:+--window-icon="$LOGO"} \
        --filename="${CURRENT_DIR}/" \
        --button="${MNB[0]}" \
        --button="${MNB[1]}" \
        --center 2>/dev/null)
    [ $? -ne 0 ] && return
    [ -z "$NEW_DIR" ] && return
    NEW_DIR="${NEW_DIR%/}"
    [ -n "$NEW_DIR" ] || NEW_DIR="/"

    if ! valid_dir_path "$NEW_DIR" || [ ! -d "$NEW_DIR" ] || [ -L "$NEW_DIR" ]; then
        mn_set "$S_BTN_OK"
        yad --warning ${LOGO:+--window-icon="$LOGO"} \
            --title="$S_SETTINGS_TITLE" \
            --text="$S_SETTINGS_WARN_DIR" \
            --button="${MNB[0]}" --width=380 --center 2>/dev/null
        return
    fi

    mn_set "$S_BTN_CANCEL" "$S_BTN_SAVE"
    ADV_RESULT=$(yad --form \
        --title="$S_SETTINGS_TITLE" \
        ${LOGO:+--window-icon="$LOGO"} \
        ${LOGO:+--image="$LOGO"} \
        --image-on-top \
        --width=480 --height=260 \
        --text="$S_SETTINGS_HEADER\n\n<b>$S_SETTINGS_CACHE_DIR:</b> <tt>$(esc "$NEW_DIR")</tt>\n\n$S_SETTINGS_CACHE_HINT\n" \
        --separator="|" \
        --field="$S_SETTINGS_MAX_SNAPS":NUM "${MAX_SNAPSHOTS:-3}!0..20!1!0" \
        --button="${MNB[0]}" \
        --button="${MNB[1]}" \
        --center 2>/dev/null)
    [ $? -ne 0 ] && return
    NEW_MAX_SNAPS=$(cut -d'|' -f1 <<< "$ADV_RESULT" | cut -d'.' -f1)
    [[ "$NEW_MAX_SNAPS" =~ ^[0-9]{1,2}$ ]] || NEW_MAX_SNAPS=3

    CACHE_BASE_DIR="$NEW_DIR"
    MAX_SNAPSHOTS="$NEW_MAX_SNAPS"
    write_conf
    set_paths

    mn_set "$S_BTN_OK"
    yad --info ${LOGO:+--window-icon="$LOGO"} \
        --title="$S_SETTINGS_TITLE" \
        --text="$S_SETTINGS_SAVED\n\n<b>Cache:</b> <tt>$(esc "$ROOTFS_CACHE")</tt>" \
        --button="${MNB[0]}" --width=440 --center 2>/dev/null
}

############################################################
# MAIN MENU
############################################################
no_cache_warning() {
    mn_set "$S_BTN_OK"
    yad --warning ${LOGO:+--window-icon="$LOGO"} \
        --title="$S_WARN_NO_CACHE_TITLE" \
        --text="$S_WARN_NO_CACHE" \
        --button="${MNB[0]}" --width=380 --center 2>/dev/null
}

menu_loop() {
    local CACHE_STATUS_TEXT CACHE_INFO_TEXT CURRENT_CRON CRON_INFO_TEXT BTRFS_TEXT
    local MODE_V SNAP_COUNT EXIT_CODE b
    local -a specs YAD_CMD
    while true; do
        read_meta

        if [ -d "$ROOTFS_CACHE" ]; then
            CACHE_STATUS_TEXT="$S_CACHE_PRESENT"
            CACHE_INFO_TEXT="$S_CACHE_DATA: <b>$(esc "$META_DATE")</b>   |   $S_CACHE_DISTRO: <b>$(esc "$META_DISTRO")</b>   |   $S_CACHE_SIZE: <b>$(esc "$META_SIZE")</b>"
        else
            CACHE_STATUS_TEXT="<b>$S_CACHE_ABSENT</b>"
            CACHE_INFO_TEXT="$S_CACHE_RUN_FULL"
        fi

        CURRENT_CRON=$(cron_current)
        if [ -n "$CURRENT_CRON" ]; then
            CRON_INFO_TEXT="$S_CRON_ACTIVE   <small><tt>$(esc "$(echo "$CURRENT_CRON" | awk '{print $1,$2,$3,$4,$5}')")</tt></small>"
        else
            CRON_INFO_TEXT="$S_CRON_NONE"
        fi

        MODE_V=$(versioning_mode)
        SNAP_COUNT=0
        case "$MODE_V" in
            snapper)
                SNAP_COUNT=$(unified_list_snapshots | wc -l)
                if [ "$SNAP_COUNT" -gt 0 ]; then
                    BTRFS_TEXT="$S_BTRFS_AVAILABLE   <small>(snapper · $SNAP_COUNT $S_SNAPSHOTS_COUNT)</small>"
                else
                    BTRFS_TEXT="$S_BTRFS_AVAILABLE   <small>(snapper · $S_SNAPSHOTS_NONE)</small>"
                fi
                ;;
            btrfs)
                SNAP_COUNT=$(list_snapshots | wc -l)
                if [ "$SNAP_COUNT" -gt 0 ]; then
                    BTRFS_TEXT="$S_BTRFS_AVAILABLE   <small>(btrfs raw · $SNAP_COUNT $S_SNAPSHOTS_COUNT)</small>"
                else
                    BTRFS_TEXT="$S_BTRFS_AVAILABLE   <small>(btrfs raw · $S_SNAPSHOTS_NONE)</small>"
                fi
                ;;
            *)
                BTRFS_TEXT="$S_BTRFS_NOT_AVAILABLE"
                ;;
        esac

        specs=("${S_BTN_EXIT}:99" "${S_BTN_BACKUP_FULL}:10" "${S_BTN_BACKUP_INC}:11"
               "${S_BTN_RESTORE}:20" "${S_BTN_SCHEDULE}:40" "${S_BTN_SETTINGS}:50")
        [ -d "$ROOTFS_CACHE" ] && specs+=("${S_BTN_DELETE_CACHE}:30")
        [ "$MODE_V" != "none" ] && [ "$SNAP_COUNT" -gt 0 ] && specs+=("${S_BTN_RESTORE_SNAP}:45")
        mn_set "${specs[@]}"

        YAD_CMD=(
            yad --form
            --title="$S_APP_TITLE_WIN $DCB_VERSION"
            ${LOGO:+--window-icon="$LOGO"}
            ${LOGO:+--image="$LOGO"}
            --image-on-top
            --width=660 --height=540
            --text="<big><b>$S_APP_TITLE</b></big>\n<i>$S_APP_SUBTITLE</i>\n\n<b>$S_SYSTEM:</b> $(esc "$DISTRO_PRETTY")  |  <b>$S_KERNEL:</b> $(uname -r)\n\n<b>$S_CACHE:</b>   $CACHE_STATUS_TEXT\n<small>$CACHE_INFO_TEXT</small>\n\n<b>$S_VERSIONING_LABEL:</b> $BTRFS_TEXT\n\n<b>$S_CRONJOB:</b> $CRON_INFO_TEXT\n\n<small>$S_CACHE: $(esc "$ROOTFS_CACHE")\n$S_LOG:   $LOG_FILE</small>\n"
        )
        for b in "${MNB[@]}"; do YAD_CMD+=(--button="$b"); done
        YAD_CMD+=(--buttons-layout=spread --center)

        "${YAD_CMD[@]}" 2>/dev/null
        EXIT_CODE=$?

        case $EXIT_CODE in
            10) do_backup "full" ;;
            11) if [ ! -d "$ROOTFS_CACHE" ]; then no_cache_warning; else do_backup "incremental"; fi ;;
            20) if [ ! -d "$ROOTFS_CACHE" ]; then no_cache_warning; else do_restore; fi ;;
            30) do_delete_cache ;;
            40) do_cronjob ;;
            45) do_restore_snapshot ;;
            50) do_settings ;;
            *)  break ;;
        esac
    done
}

# ── Root stage: started by pkexec (or by root directly) ──────
gui_root_main() {
    local display="" xauth="" lang=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --lang)       lang="${2:-}"; shift 2 || shift ;;
            --display)    display="${2:-}"; shift 2 || shift ;;
            --xauthority) xauth="${2:-}"; shift 2 || shift ;;
            *) shift ;;
        esac
    done
    if [[ "$lang" =~ ^(en|it|de|fr|es|ru)$ ]]; then LANG_CODE="$lang"; load_strings; fi
    export LC_ALL=C.UTF-8

    # pkexec starts with a clean environment: take the display from the
    # caller, but only in a validated form.
    local uid="${PKEXEC_UID:-${SUDO_UID:-}}" home=""
    if [[ "$uid" =~ ^[0-9]+$ ]]; then home=$(getent passwd "$uid" | cut -d: -f6); fi
    if [[ "$display" =~ ^:[0-9]{1,3}(\.[0-9]{1,2})?$ ]]; then export DISPLAY="$display"; fi
    if [ -n "$xauth" ] && [ -f "$xauth" ] && [ ! -L "$xauth" ] \
       && { [ -z "$uid" ] || [ "$(stat -c %u "$xauth" 2>/dev/null)" = "$uid" ]; }; then
        export XAUTHORITY="$xauth"
    fi

    local dep
    for dep in yad rsync flock findmnt; do
        command -v "$dep" >/dev/null 2>&1 || { echo "distroclone-backup: $dep is required" >&2; exit 1; }
    done

    load_os_release
    parse_conf "$CONF_FILE"
    import_legacy_conf "$home"
    parse_conf "$CONF_FILE"
    set_paths
    init_log

    if [ -f "/usr/share/distroclone-backup/distroclone-bkp-logo.png" ]; then
        LOGO="/usr/share/distroclone-backup/distroclone-bkp-logo.png"
    elif [ -f "/usr/share/icons/hicolor/128x128/apps/distroclone-backup.png" ]; then
        LOGO="/usr/share/icons/hicolor/128x128/apps/distroclone-backup.png"
    fi

    trap 'cleanup_gui 130' INT TERM
    trap 'cleanup_gui $?' EXIT

    # First start: ask where the cache lives.
    if [ ! -f "$CONF_FILE" ] && [ ! -d "$ROOTFS_CACHE" ]; then
        local FIRST_DIR
        mn_set "$S_BTN_CANCEL" "$S_BTN_OK"
        FIRST_DIR=$(yad --file-selection --directory \
            --title="$S_SETTINGS_TITLE" \
            ${LOGO:+--window-icon="$LOGO"} \
            --filename="/mnt/" \
            --text="$S_SETTINGS_HEADER\n\n$S_SETTINGS_CACHE_DIR\n\n$S_SETTINGS_CACHE_HINT" \
            --button="${MNB[0]}" \
            --button="${MNB[1]}" \
            --center 2>/dev/null)
        FIRST_DIR="${FIRST_DIR%/}"
        if [ -n "$FIRST_DIR" ] && valid_dir_path "$FIRST_DIR" && [ -d "$FIRST_DIR" ] && [ ! -L "$FIRST_DIR" ]; then
            CACHE_BASE_DIR="$FIRST_DIR"
            write_conf
            set_paths
        fi
    fi

    menu_loop
    exit 0
}

# ── User stage: ask polkit for the administrator rights ──────
gui_user_main() {
    if ! command -v yad >/dev/null 2>&1 || ! command -v rsync >/dev/null 2>&1; then
        echo "distroclone-backup: yad and rsync are required" >&2
        exit 1
    fi
    if [ "$EUID" -eq 0 ]; then
        gui_root_main --lang "$LANG_CODE" --display "${DISPLAY:-}" --xauthority "${XAUTHORITY:-}"
        return
    fi
    command -v pkexec >/dev/null 2>&1 || { echo "distroclone-backup: pkexec is required" >&2; exit 1; }

    # Launched from a menu the display variables may be missing.
    local l envf d uid xa
    uid=$(id -u)
    if [ -z "$DISPLAY" ] && command -v systemctl >/dev/null 2>&1; then
        while IFS= read -r l; do
            case "$l" in
                DISPLAY=*)    export DISPLAY="${l#DISPLAY=}" ;;
                XAUTHORITY=*) export XAUTHORITY="${l#XAUTHORITY=}" ;;
            esac
        done < <(XDG_RUNTIME_DIR="/run/user/$uid" systemctl --user show-environment 2>/dev/null \
                    | grep -E '^(DISPLAY|XAUTHORITY)=')
    fi
    if [ -z "$DISPLAY" ]; then
        for envf in /proc/[0-9]*/environ; do
            [ "$(stat -c %u "$envf" 2>/dev/null)" = "$uid" ] || continue
            d=$(tr '\0' '\n' < "$envf" 2>/dev/null | grep '^DISPLAY=' | head -n 1)
            if [ -n "$d" ]; then export DISPLAY="${d#DISPLAY=}"; break; fi
        done
    fi
    [ -z "$DISPLAY" ] && export DISPLAY=":0"
    if [ -z "$XAUTHORITY" ]; then
        for xa in "/run/user/${uid}/gdm/Xauthority" "$HOME/.Xauthority"; do
            if [ -f "$xa" ]; then export XAUTHORITY="$xa"; break; fi
        done
    fi

    local self="$DCB_SELF_INSTALLED" rc
    [ -x "$self" ] || self="$(readlink -f "$0")"
    pkexec "$self" --gui-root --lang "$LANG_CODE" --display "$DISPLAY" --xauthority "${XAUTHORITY:-}"
    rc=$?
    if [ "$rc" -eq 126 ] || [ "$rc" -eq 127 ]; then
        yad --error --title="$S_APP_TITLE_WIN" --text="$(esc "$S_ERR_AUTH")" \
            --button="OK:0" --center 2>/dev/null
    fi
    exit "$rc"
}

usage() {
    cat <<EOF
Usage: distroclone-backup [OPTION]
  (no option)            open the graphical interface
  --incremental-silent   incremental backup without interface (cron; root)
  --import-conf          import settings of earlier versions (root)
  --version              print the version
  --help                 print this help
EOF
}

main() {
    case "${1:-}" in
        "")                    gui_user_main ;;
        --gui-root)            shift; gui_root_main "$@" ;;
        --incremental-silent)
            [ "$EUID" -eq 0 ] || { echo "distroclone-backup: must run as root" >&2; exit 1; }
            cron_main
            exit $?
            ;;
        --import-conf)
            [ "$EUID" -eq 0 ] || { echo "distroclone-backup: must run as root" >&2; exit 1; }
            import_legacy_conf
            exit 0
            ;;
        --version)             echo "distroclone-backup $DCB_VERSION"; exit 0 ;;
        --help|-h)             usage; exit 0 ;;
        *)                     usage >&2; exit 2 ;;
    esac
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    main "$@"
fi
