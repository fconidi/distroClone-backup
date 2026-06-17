#!/bin/bash
# ============================================================
#  DistroClone Backup & Restore — v1.3.1
#  Package: distroclone-backup
#  Usage: distroclone-backup   (alias di /usr/bin/distroClone-backup)
#  Cron:  distroclone-backup --incremental-silent
#
#  v1.3 — Versioning su cache btrfs gestita via snapper (config
#  dedicato "distroclone-backup"). Su filesystem non btrfs:
#  rsync classico, nessuna regressione. Senza snapper: fallback
#  a snapshot btrfs raw (comportamento v1.2.2).
# ============================================================

set -o pipefail
trap '' PIPE

# ════════════════════════════════════════════════════════════
#  LANGUAGE DETECTION & STRINGS
# ════════════════════════════════════════════════════════════
detect_language() {
    local lang="${LANG:-${LANGUAGE:-en}}"
    case "${lang:0:2}" in
        it) echo "it" ;;
        de) echo "de" ;;
        fr) echo "fr" ;;
        es) echo "es" ;;
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
        S_RESTORE_CONFIRM="<span color='#c62828'>Confermi il ripristino?</span>"
        S_RESTORE_LOG_TITLE="DistroClone — Avvio RIPRISTINO"
        S_RESTORE_LOG_FROM="Da cache"
        S_RESTORE_LOG_TO="Verso"
        S_RESTORE_LOG_PROTECTED="Protetti"
        S_RESTORE_RSYNC_START="→ rsync ripristino avviato..."
        S_RESTORE_OK_TITLE="DistroClone — Ripristino OK"
        S_RESTORE_OK_TEXT="<big><b>✓ Ripristino completato!</b></big>"
        S_RESTORE_OK_DATE="Il sistema è stato ripristinato al backup del"
        S_RESTORE_OK_PROTECTED="<b>Protetti:</b> /home ✓   /root ✓   /boot/efi ✓"
        S_RESTORE_OK_REBOOT="<span color='#c62828'><b>Riavviare il sistema.</b></span>"
        S_RESTORE_ERR_TITLE="DistroClone — Errore Ripristino"
        S_RESTORE_ERR_TEXT="<b>✗ Ripristino fallito!</b>"

        S_CRON_DIALOG_TITLE="DistroClone — Pianifica Backup"
        S_CRON_DIALOG_HEADER="<big><b>Pianificazione Backup Automatico</b></big>"
        S_CRON_STATUS_ACTIVE="<span color='#2e7d32'>● Pianificazione attiva</span>"
        S_CRON_STATUS_NONE="<span color='#c62828'>● Nessuna pianificazione attiva</span>"
        S_CRON_STATUS_NOCRON="<small>Nessun cronjob configurato</small>"
        S_CRON_HINT="<span color='#666666'><small>Il backup incrementale verrà eseguito automaticamente.\nRichiede che la cache esista (esegui prima Backup completo).</small></span>"
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
        S_DELETE_WARN="<span color='#c62828'>Irreversibile.\nVerrà rimossa anche la pianificazione cronjob.</span>"
        S_DELETE_OK_TITLE="DistroClone — Cache Eliminata"
        S_DELETE_OK_TEXT="✓ Cache eliminata.\n✓ Cronjob rimosso."

        S_SUDO_NEEDED="Permessi sudo necessari"
        S_LOG_CHECK="Verifica con"
        S_HOME_INCLUDE="Includi /home nel backup"
        S_HOME_INCLUDE_WARN="<span color='#e65100'><small>⚠ Aumenta notevolmente dimensioni e tempi</small></span>"
        S_HOME_INCLUDED="● /home inclusa nel backup"
        S_HOME_EXCLUDED="● /home esclusa (solo sistema)"
        S_BACKUP_OPT_TITLE="Opzioni Backup"
        S_BTN_BACKUP_START="Avvia backup!gtk-media-play:0"
        S_BTN_SETTINGS="Impostazioni!gtk-preferences"
        S_SETTINGS_TITLE="DistroClone — Impostazioni"
        S_SETTINGS_HEADER="<big><b>Impostazioni</b></big>"
        S_SETTINGS_CACHE_DIR="<b>Directory cache backup</b>"
        S_SETTINGS_CACHE_HINT="<span color='#666666'><small>Default: /mnt — Può essere un disco esterno, NFS, ecc.\nVerrà creata la sottocartella .rootfs_cache</small></span>"
        S_SETTINGS_SAVED="✓ Impostazioni salvate."
        S_SETTINGS_WARN_DIR="<span color='#c62828'>Directory non valida o non accessibile.</span>"
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
        S_RESTORE_CONFIRM="<span color='#c62828'>Wiederherstellung bestätigen?</span>"
        S_RESTORE_LOG_TITLE="DistroClone — WIEDERHERSTELLUNG"
        S_RESTORE_LOG_FROM="Von Cache"
        S_RESTORE_LOG_TO="Nach"
        S_RESTORE_LOG_PROTECTED="Geschützt"
        S_RESTORE_RSYNC_START="→ rsync Wiederherstellung gestartet..."
        S_RESTORE_OK_TITLE="DistroClone — Wiederherstellung OK"
        S_RESTORE_OK_TEXT="<big><b>✓ Wiederherstellung abgeschlossen!</b></big>"
        S_RESTORE_OK_DATE="System wiederhergestellt vom Backup:"
        S_RESTORE_OK_PROTECTED="<b>Geschützt:</b> /home ✓   /root ✓   /boot/efi ✓"
        S_RESTORE_OK_REBOOT="<span color='#c62828'><b>Bitte System neu starten.</b></span>"
        S_RESTORE_ERR_TITLE="DistroClone — Wiederherstellungsfehler"
        S_RESTORE_ERR_TEXT="<b>✗ Wiederherstellung fehlgeschlagen!</b>"

        S_CRON_DIALOG_TITLE="DistroClone — Backup planen"
        S_CRON_DIALOG_HEADER="<big><b>Automatisches Backup planen</b></big>"
        S_CRON_STATUS_ACTIVE="<span color='#2e7d32'>● Planung aktiv</span>"
        S_CRON_STATUS_NONE="<span color='#c62828'>● Keine Planung aktiv</span>"
        S_CRON_STATUS_NOCRON="<small>Kein Cronjob konfiguriert</small>"
        S_CRON_HINT="<span color='#666666'><small>Backup wird automatisch ausgeführt.\nErfordert vorhandenen Cache (zuerst Vollbackup).</small></span>"
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
        S_DELETE_WARN="<span color='#c62828'>Unwiderruflich.\nCronjob wird ebenfalls entfernt.</span>"
        S_DELETE_OK_TITLE="DistroClone — Cache gelöscht"
        S_DELETE_OK_TEXT="✓ Cache gelöscht.\n✓ Cronjob entfernt."

        S_SUDO_NEEDED="Sudo-Berechtigung erforderlich"
        S_LOG_CHECK="Überprüfen mit"
        S_HOME_INCLUDE="/home in Backup einbeziehen"
        S_HOME_INCLUDE_WARN="<span color='#e65100'><small>⚠ Erhöht Größe und Dauer erheblich</small></span>"
        S_HOME_INCLUDED="● /home im Backup enthalten"
        S_HOME_EXCLUDED="● /home ausgeschlossen (nur System)"
        S_BACKUP_OPT_TITLE="Backup-Optionen"
        S_BTN_BACKUP_START="Backup starten!gtk-media-play:0"
        S_BTN_SETTINGS="Einstellungen!gtk-preferences"
        S_SETTINGS_TITLE="DistroClone — Einstellungen"
        S_SETTINGS_HEADER="<big><b>Einstellungen</b></big>"
        S_SETTINGS_CACHE_DIR="<b>Backup-Cache-Verzeichnis</b>"
        S_SETTINGS_CACHE_HINT="<span color='#666666'><small>Standard: /mnt — Kann externe Festplatte, NFS usw. sein.\nUnterordner .rootfs_cache wird erstellt</small></span>"
        S_SETTINGS_SAVED="✓ Einstellungen gespeichert."
        S_SETTINGS_WARN_DIR="<span color='#c62828'>Ungültiges oder nicht zugängliches Verzeichnis.</span>"
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
        S_RESTORE_CONFIRM="<span color='#c62828'>Confirmer la restauration?</span>"
        S_RESTORE_LOG_TITLE="DistroClone — RESTAURATION"
        S_RESTORE_LOG_FROM="Du cache"
        S_RESTORE_LOG_TO="Vers"
        S_RESTORE_LOG_PROTECTED="Protégés"
        S_RESTORE_RSYNC_START="→ rsync restauration démarré..."
        S_RESTORE_OK_TITLE="DistroClone — Restauration OK"
        S_RESTORE_OK_TEXT="<big><b>✓ Restauration terminée!</b></big>"
        S_RESTORE_OK_DATE="Système restauré depuis la sauvegarde du"
        S_RESTORE_OK_PROTECTED="<b>Protégés:</b> /home ✓   /root ✓   /boot/efi ✓"
        S_RESTORE_OK_REBOOT="<span color='#c62828'><b>Veuillez redémarrer le système.</b></span>"
        S_RESTORE_ERR_TITLE="DistroClone — Erreur de restauration"
        S_RESTORE_ERR_TEXT="<b>✗ Restauration échouée!</b>"

        S_CRON_DIALOG_TITLE="DistroClone — Planifier la sauvegarde"
        S_CRON_DIALOG_HEADER="<big><b>Planification automatique</b></big>"
        S_CRON_STATUS_ACTIVE="<span color='#2e7d32'>● Planification active</span>"
        S_CRON_STATUS_NONE="<span color='#c62828'>● Aucune planification active</span>"
        S_CRON_STATUS_NOCRON="<small>Aucun cronjob configuré</small>"
        S_CRON_HINT="<span color='#666666'><small>La sauvegarde sera exécutée automatiquement.\nNécessite un cache existant (effectuez d'abord une sauvegarde complète).</small></span>"
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
        S_DELETE_WARN="<span color='#c62828'>Irréversible.\nLa tâche planifiée sera également supprimée.</span>"
        S_DELETE_OK_TITLE="DistroClone — Cache supprimé"
        S_DELETE_OK_TEXT="✓ Cache supprimé.\n✓ Tâche planifiée supprimée."

        S_SUDO_NEEDED="Permissions sudo requises"
        S_LOG_CHECK="Vérifier avec"
        S_HOME_INCLUDE="Inclure /home dans la sauvegarde"
        S_HOME_INCLUDE_WARN="<span color='#e65100'><small>⚠ Augmente considérablement la taille et la durée</small></span>"
        S_HOME_INCLUDED="● /home inclus dans la sauvegarde"
        S_HOME_EXCLUDED="● /home exclu (système uniquement)"
        S_BACKUP_OPT_TITLE="Options de sauvegarde"
        S_BTN_BACKUP_START="Lancer la sauvegarde!gtk-media-play:0"
        S_BTN_SETTINGS="Paramètres!gtk-preferences"
        S_SETTINGS_TITLE="DistroClone — Paramètres"
        S_SETTINGS_HEADER="<big><b>Paramètres</b></big>"
        S_SETTINGS_CACHE_DIR="<b>Répertoire du cache de sauvegarde</b>"
        S_SETTINGS_CACHE_HINT="<span color='#666666'><small>Défaut: /mnt — Peut être un disque externe, NFS, etc.\nLe sous-dossier .rootfs_cache sera créé</small></span>"
        S_SETTINGS_SAVED="✓ Paramètres enregistrés."
        S_SETTINGS_WARN_DIR="<span color='#c62828'>Répertoire invalide ou inaccessible.</span>"
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
        S_RESTORE_CONFIRM="<span color='#c62828'>¿Confirmar la restauración?</span>"
        S_RESTORE_LOG_TITLE="DistroClone — RESTAURACIÓN EN CURSO"
        S_RESTORE_LOG_FROM="Origen (caché)"
        S_RESTORE_LOG_TO="Destino"
        S_RESTORE_LOG_PROTECTED="Directorios protegidos"
        S_RESTORE_RSYNC_START="→ rsync: restauración iniciada..."
        S_RESTORE_OK_TITLE="DistroClone — Restauración correcta"
        S_RESTORE_OK_TEXT="<big><b>✓ Restauración finalizada!</b></big>"
        S_RESTORE_OK_DATE="Sistema restaurado desde la copia del"
        S_RESTORE_OK_PROTECTED="<b>Sin cambios:</b> /home ✓   /root ✓   /boot/efi ✓"
        S_RESTORE_OK_REBOOT="<span color='#c62828'><b>Es necesario reiniciar el sistema.</b></span>"
        S_RESTORE_ERR_TITLE="DistroClone — Error en la restauración"
        S_RESTORE_ERR_TEXT="<b>✗ La restauración ha fallado!</b>"

        S_CRON_DIALOG_TITLE="DistroClone — Programar copia de seguridad"
        S_CRON_DIALOG_HEADER="<big><b>Programar copia de seguridad automática</b></big>"
        S_CRON_STATUS_ACTIVE="<span color='#2e7d32'>● Tarea programada activa</span>"
        S_CRON_STATUS_NONE="<span color='#c62828'>● Sin tarea programada</span>"
        S_CRON_STATUS_NOCRON="<small>No hay ninguna tarea programada</small>"
        S_CRON_HINT="<span color='#666666'><small>La copia se ejecutará automáticamente en los horarios indicados.\nEs necesario tener un caché disponible (realice primero una copia completa).</small></span>"
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
        S_DELETE_WARN="<span color='#c62828'>Esta acción es irreversible.\nLa tarea programada también será eliminada.</span>"
        S_DELETE_OK_TITLE="DistroClone — Caché borrado"
        S_DELETE_OK_TEXT="✓ Caché borrado correctamente.\n✓ Tarea programada eliminada."

        S_SUDO_NEEDED="Se requieren permisos de administrador (sudo)"
        S_LOG_CHECK="Comprobar con"
        S_HOME_INCLUDE="Incluir /home en la copia de seguridad"
        S_HOME_INCLUDE_WARN="<span color='#e65100'><small>⚠ Aumenta considerablemente el tamaño y el tiempo</small></span>"
        S_HOME_INCLUDED="● /home incluido en la copia"
        S_HOME_EXCLUDED="● /home excluido (solo sistema)"
        S_BACKUP_OPT_TITLE="Opciones de copia de seguridad"
        S_BTN_BACKUP_START="Iniciar copia!gtk-media-play:0"
        S_BTN_SETTINGS="Ajustes!gtk-preferences"
        S_SETTINGS_TITLE="DistroClone — Ajustes"
        S_SETTINGS_HEADER="<big><b>Ajustes</b></big>"
        S_SETTINGS_CACHE_DIR="<b>Directorio de caché de copia de seguridad</b>"
        S_SETTINGS_CACHE_HINT="<span color='#666666'><small>Predeterminado: /mnt — Puede ser disco externo, NFS, etc.\nSe creará la subcarpeta .rootfs_cache</small></span>"
        S_SETTINGS_SAVED="✓ Ajustes guardados."
        S_SETTINGS_WARN_DIR="<span color='#c62828'>Directorio no válido o inaccesible.</span>"
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
        S_RESTORE_CONFIRM="<span color='#c62828'>Confirm restore?</span>"
        S_RESTORE_LOG_TITLE="DistroClone — RESTORE"
        S_RESTORE_LOG_FROM="From cache"
        S_RESTORE_LOG_TO="To"
        S_RESTORE_LOG_PROTECTED="Protected"
        S_RESTORE_RSYNC_START="→ rsync restore started..."
        S_RESTORE_OK_TITLE="DistroClone — Restore OK"
        S_RESTORE_OK_TEXT="<big><b>✓ Restore completed!</b></big>"
        S_RESTORE_OK_DATE="System restored from backup dated"
        S_RESTORE_OK_PROTECTED="<b>Protected:</b> /home ✓   /root ✓   /boot/efi ✓"
        S_RESTORE_OK_REBOOT="<span color='#c62828'><b>Please reboot the system.</b></span>"
        S_RESTORE_ERR_TITLE="DistroClone — Restore Error"
        S_RESTORE_ERR_TEXT="<b>✗ Restore failed!</b>"

        S_CRON_DIALOG_TITLE="DistroClone — Schedule Backup"
        S_CRON_DIALOG_HEADER="<big><b>Schedule Automatic Backup</b></big>"
        S_CRON_STATUS_ACTIVE="<span color='#2e7d32'>● Schedule active</span>"
        S_CRON_STATUS_NONE="<span color='#c62828'>● No schedule active</span>"
        S_CRON_STATUS_NOCRON="<small>No cronjob configured</small>"
        S_CRON_HINT="<span color='#666666'><small>Backup will run automatically at scheduled times.\nRequires existing cache (run Full Backup first).</small></span>"
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
        S_DELETE_WARN="<span color='#c62828'>Irreversible.\nCronjob schedule will also be removed.</span>"
        S_DELETE_OK_TITLE="DistroClone — Cache Deleted"
        S_DELETE_OK_TEXT="✓ Cache deleted.\n✓ Cronjob removed."

        S_SUDO_NEEDED="Sudo permissions required"
        S_LOG_CHECK="Verify with"
        S_HOME_INCLUDE="Include /home in backup"
        S_HOME_INCLUDE_WARN="<span color='#e65100'><small>⚠ Significantly increases size and time</small></span>"
        S_HOME_INCLUDED="● /home included in backup"
        S_HOME_EXCLUDED="● /home excluded (system only)"
        S_BACKUP_OPT_TITLE="Backup Options"
        S_BTN_BACKUP_START="Start Backup!gtk-media-play:0"
        S_BTN_SETTINGS="Settings!gtk-preferences"
        S_SETTINGS_TITLE="DistroClone — Settings"
        S_SETTINGS_HEADER="<big><b>Settings</b></big>"
        S_SETTINGS_CACHE_DIR="<b>Backup cache directory</b>"
        S_SETTINGS_CACHE_HINT="<span color='#666666'><small>Default: /mnt — Can be an external disk, NFS, etc.\nSubfolder .rootfs_cache will be created</small></span>"
        S_SETTINGS_SAVED="✓ Settings saved."
        S_SETTINGS_WARN_DIR="<span color='#c62828'>Invalid or inaccessible directory.</span>"
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
        ;;
    esac
}

# Carica stringhe
load_strings

# ── Mappa giorni della settimana → numero cron ───────────────
# Dipende dalla lingua
day_to_dow() {
    local day="$1"
    case "$LANG_CODE" in
        it) case "$day" in
                "Lunedì") echo 1 ;; "Martedì") echo 2 ;; "Mercoledì") echo 3 ;;
                "Giovedì") echo 4 ;; "Venerdì") echo 5 ;; "Sabato") echo 6 ;;
                "Domenica") echo 0 ;; *) echo 1 ;;
            esac ;;
        de) case "$day" in
                "Montag") echo 1 ;; "Dienstag") echo 2 ;; "Mittwoch") echo 3 ;;
                "Donnerstag") echo 4 ;; "Freitag") echo 5 ;; "Samstag") echo 6 ;;
                "Sonntag") echo 0 ;; *) echo 1 ;;
            esac ;;
        fr) case "$day" in
                "Lundi") echo 1 ;; "Mardi") echo 2 ;; "Mercredi") echo 3 ;;
                "Jeudi") echo 4 ;; "Vendredi") echo 5 ;; "Samedi") echo 6 ;;
                "Dimanche") echo 0 ;; *) echo 1 ;;
            esac ;;
        es) case "$day" in
                "Lunes") echo 1 ;; "Martes") echo 2 ;; "Miércoles") echo 3 ;;
                "Jueves") echo 4 ;; "Viernes") echo 5 ;; "Sábado") echo 6 ;;
                "Domingo") echo 0 ;; *) echo 1 ;;
            esac ;;
        *)  case "$day" in
                "Monday") echo 1 ;; "Tuesday") echo 2 ;; "Wednesday") echo 3 ;;
                "Thursday") echo 4 ;; "Friday") echo 5 ;; "Saturday") echo 6 ;;
                "Sunday") echo 0 ;; *) echo 1 ;;
            esac ;;
    esac
}

# ── Mappa frequenza → espressione cron ───────────────────────
freq_to_cron() {
    local freq="$1" hour="$2" dow="$3"
    if [ "$freq" = "$S_CRON_FREQ_DAILY" ];   then echo "0 $hour * * *"; fi
    if [ "$freq" = "$S_CRON_FREQ_WEEKLY" ];  then echo "0 $hour * * $dow"; fi
    if [ "$freq" = "$S_CRON_FREQ_MONTHLY" ]; then echo "0 $hour 1 * *"; fi
}

# ════════════════════════════════════════════════════════════
#  MODALITÀ SILENZIOSA PER CRON
# ════════════════════════════════════════════════════════════
if [[ "$1" == "--incremental-silent" ]]; then
    source /etc/os-release
    DISTRO_ID="${ID}"
    LOG_FILE="/var/log/distroclone-backup.log"

    # Fix: legge settings.conf dell'utente che ha schedulato il cron
    # Il cron gira come root; cerca il conf nell'home del primo utente reale
    # (uid 1000-65533) che abbia un settings.conf di distroclone-backup
    CRON_CONF=""
    while IFS= read -r user_home; do
        candidate="${user_home}/.config/distroclone-backup/settings.conf"
        if [ -f "$candidate" ]; then
            CRON_CONF="$candidate"
            break
        fi
    done < <(getent passwd | awk -F: '$3>=1000 && $3<65534 {print $6}')

    # Default; sovrascritti dal conf se trovato
    CACHE_BASE_DIR="/mnt"
    MAX_SNAPSHOTS=3
    [ -n "$CRON_CONF" ] && source "$CRON_CONF"

    # Fix: suffisso corretto _backup (non _live)
    CACHE_BASE="${CACHE_BASE_DIR}/${DISTRO_ID}_backup"
    ROOTFS_CACHE="${CACHE_BASE}/.rootfs_cache"
    CACHE_META="${CACHE_BASE}/.backup_meta"
    SNAPSHOTS_DIR="${CACHE_BASE}/.snapshots"

    _log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"; }

    _log "── Incremental backup (cron) ──"
    [ -n "$CRON_CONF" ] && _log "   Config: $CRON_CONF  →  Cache: $ROOTFS_CACHE"

    if [ ! -d "$ROOTFS_CACHE" ]; then
        _log "ERROR: cache not found: $ROOTFS_CACHE"
        exit 1
    fi

    # Versioning pre-rsync se il filesystem lo supporta
    _is_btrfs_cron()  { df --output=fstype "$CACHE_BASE_DIR" 2>/dev/null | grep -q "btrfs"; }
    _has_snapper_cron() { command -v snapper >/dev/null 2>&1; }

    _prune_snapshots_cron() {
        [ "${MAX_SNAPSHOTS:-3}" -le 0 ] && return
        local snaps
        mapfile -t snaps < <(find "$SNAPSHOTS_DIR" -maxdepth 1 -name '@*' -type d 2>/dev/null | sort)
        local count=${#snaps[@]}
        if [ "$count" -gt "$MAX_SNAPSHOTS" ]; then
            local to_delete=$(( count - MAX_SNAPSHOTS ))
            for (( i=0; i<to_delete; i++ )); do
                btrfs subvolume delete "${snaps[$i]}" >> "$LOG_FILE" 2>&1
                rm -f "${snaps[$i]}.meta" 2>/dev/null
                _log "   Pruned: $(basename "${snaps[$i]}")"
            done
        fi
    }

    if _is_btrfs_cron && _has_snapper_cron \
       && snapper -c distroclone-backup get-config >/dev/null 2>&1; then
        # v1.3: usa snapper se config dedicato disponibile
        local _size_kb
        _size_kb=$(du -sk "$ROOTFS_CACHE" 2>/dev/null | cut -f1)
        _log "→ Creating snapper snapshot (cron incremental)"
        if snapper -c distroclone-backup create \
                --type single \
                --description "distroclone-backup cron $(date '+%Y-%m-%d %H:%M')" \
                --userdata "distro=${PRETTY_NAME},kernel=$(uname -r),size_kb=${_size_kb}" \
                >> "$LOG_FILE" 2>&1; then
            _log "✓ Snapper snapshot created"
            snapper -c distroclone-backup cleanup number >> "$LOG_FILE" 2>&1 || true
        else
            _log "⚠ Snapper snapshot failed — continuing with rsync anyway"
        fi
    elif _is_btrfs_cron && btrfs subvolume show "$ROOTFS_CACHE" >/dev/null 2>&1; then
        # Fallback v1.2.2: snapshot btrfs raw
        local_snap="@$(date '+%Y-%m-%d_%H:%M')"
        mkdir -p "$SNAPSHOTS_DIR"
        _log "→ Creating snapshot: $local_snap"
        if btrfs subvolume snapshot -r "$ROOTFS_CACHE" "$SNAPSHOTS_DIR/$local_snap" >> "$LOG_FILE" 2>&1; then
            bash -c "cat > '$SNAPSHOTS_DIR/${local_snap}.meta'" <<EOF
SNAP_DATE="$(date '+%Y-%m-%d %H:%M:%S')"
SNAP_DISTRO="${PRETTY_NAME}"
SNAP_KERNEL="$(uname -r)"
SNAP_SIZE="$(du -sh "$SNAPSHOTS_DIR/$local_snap" 2>/dev/null | cut -f1)"
EOF
            _log "✓ Snapshot created: $local_snap"
            _prune_snapshots_cron
        else
            _log "⚠ Snapshot failed — continuing with rsync anyway"
        fi
    fi

    rsync -aAXH --numeric-ids --update --delete --one-file-system \
      --exclude=/dev/* --exclude=/proc/* --exclude=/sys/* \
      --exclude=/run/* --exclude=/tmp/* --exclude=/mnt/* \
      --exclude=/media/* --exclude=/lost+found --exclude=/swapfile \
      --exclude=/home/* --exclude=/root/* \
      --exclude=/boot/efi/* --exclude=/boot/efi \
      --exclude=/var/cache/apt/archives/* --exclude=/var/lib/apt/lists/* \
      --exclude=/var/log/* --exclude=/var/tmp/* \
      --exclude=/etc/NetworkManager/system-connections/* \
      --exclude=/usr/share/distroclone-backup \
      --exclude=/usr/bin/distroClone-backup \
      --exclude=/snap --exclude=/snap/* --exclude=/var/snap \
      --exclude=/var/lib/snapd \
      --exclude=/.snapshots --exclude=/.snapshots/* \
      --exclude=/var/lib/snapper \
      --exclude=/home/*/.config/Claude \
      --exclude=/home/*/.claude \
      --exclude=/home/*/.claude.json \
      --exclude=/home/*/.cache/claude-desktop-debian \
      --exclude=/root/.config/Claude \
      --exclude=/root/.claude \
      --exclude=/root/.claude.json \
      --exclude=/root/.cache/claude-desktop-debian \
      / "$ROOTFS_CACHE" >> "$LOG_FILE" 2>&1

    EXIT_CODE=$?
    if [ $EXIT_CODE -eq 0 ] || [ $EXIT_CODE -eq 24 ]; then
        bash -c "cat > '$CACHE_META'" <<EOF
META_DATE="$(date '+%Y-%m-%d %H:%M:%S')"
META_DISTRO="${PRETTY_NAME}"
META_SIZE="$(du -sh "$ROOTFS_CACHE" 2>/dev/null | cut -f1)"
META_KERNEL="$(uname -r)"
EOF
        _log "✓ Incremental backup completed  ($(du -sh "$ROOTFS_CACHE" 2>/dev/null | cut -f1))"
        exit 0
    else
        _log "✗ rsync error (exit: $EXIT_CODE)"
        exit 1
    fi
fi

# ════════════════════════════════════════════════════════════
#  MODALITÀ GRAFICA
# ════════════════════════════════════════════════════════════

REAL_USER="${USER:-$(whoami)}"
if [ "$EUID" -eq 0 ]; then
    REAL_USER="${SUDO_USER:-$(logname 2>/dev/null)}"
fi
REAL_UID=$(id -u "$REAL_USER" 2>/dev/null)

# ── Fix DISPLAY/XAUTHORITY per lancio da menu ────────────────
if [ -z "$DISPLAY" ]; then
    # Metodo 1: systemctl --user (funziona su GNOME, MATE, KDE, XFCE)
    if command -v systemctl >/dev/null 2>&1 && [ -n "$REAL_UID" ]; then
        eval "$(XDG_RUNTIME_DIR="/run/user/$REAL_UID" \
            systemctl --user show-environment 2>/dev/null | \
            grep -E '^(DISPLAY|XAUTHORITY)=' | sed 's/^/export /')"
    fi
    # Metodo 2: scansione /proc di tutti i processi dell'utente
    if [ -z "$DISPLAY" ] && [ -n "$REAL_UID" ]; then
        for envf in /proc/[0-9]*/environ; do
            [ "$(stat -c %u "$envf" 2>/dev/null)" = "$REAL_UID" ] || continue
            D=$(tr '\0' '\n' < "$envf" 2>/dev/null | grep '^DISPLAY=')
            [ -n "$D" ] && export "$D" && break
        done
    fi
    # Fallback
    [ -z "$DISPLAY" ] && export DISPLAY=":0"
fi

if [ -z "$XAUTHORITY" ]; then
    for _xa in \
        "/run/user/${REAL_UID}/gdm/Xauthority" \
        "/home/${REAL_USER}/.Xauthority" \
        "/tmp/.Xauthority"; do
        [ -f "$_xa" ] && export XAUTHORITY="$_xa" && break
    done
fi

# ── Verifica sudoers installato ──────────────────────────────
if [ ! -f "/etc/sudoers.d/distroclone-backup" ]; then
    yad --error \
        --title="DistroClone Backup" \
        ${TEMP_LOGO:+--window-icon="$TEMP_LOGO"} \
        --text="<b>Configurazione sudo mancante.</b>\n\nRiinstalla il pacchetto:\n<tt>sudo apt install ./distroclone-backup_1.0_all.deb</tt>\n\nPoi verifica:\n<tt>sudo -l | grep NOPASSWD</tt>" \
        --button="OK:0" --width=440 --height=200 --fixed --center 2>/dev/null
    exit 1
fi

for cmd in yad rsync convert; do
    command -v "$cmd" >/dev/null 2>&1 || sudo apt-get install -y "$cmd" -qq
done

source /etc/os-release
DISTRO_ID="${ID}"
DISTRO_PRETTY="${PRETTY_NAME}"

# ── Configurazione utente ────────────────────────────────────
CONF_DIR="${HOME}/.config/distroclone-backup"
CONF_FILE="${CONF_DIR}/settings.conf"
mkdir -p "$CONF_DIR" 2>/dev/null

# Carica impostazioni salvate o usa default
CACHE_BASE_DIR="/mnt"
MAX_SNAPSHOTS=3
[ -f "$CONF_FILE" ] && source "$CONF_FILE"

CACHE_BASE="${CACHE_BASE_DIR}/${DISTRO_ID}_backup"
ROOTFS_CACHE="${CACHE_BASE}/.rootfs_cache"
CACHE_META="${CACHE_BASE}/.backup_meta"
SNAPSHOTS_DIR="${CACHE_BASE}/.snapshots"
LOG_FILE="/var/log/distroclone-backup.log"

sudo touch "$LOG_FILE" 2>/dev/null
sudo chmod 666 "$LOG_FILE" 2>/dev/null

ICON_PKG="/usr/share/distroclone-backup/distroclone-bkp-logo.png"
ICON_INSTALLED="/usr/share/icons/hicolor/128x128/apps/distroclone-backup.png"
TEMP_LOGO="/tmp/distroclone-bkp-logo.png"

if [ -f "$ICON_PKG" ]; then
    # Priorità 1: logo personalizzato incluso nel pacchetto
    cp "$ICON_PKG" "$TEMP_LOGO" 2>/dev/null || TEMP_LOGO="$ICON_PKG"
elif [ -f "$ICON_INSTALLED" ]; then
    # Priorità 2: icona hicolor installata
    cp "$ICON_INSTALLED" "$TEMP_LOGO" 2>/dev/null || TEMP_LOGO="$ICON_INSTALLED"
elif command -v convert >/dev/null 2>&1; then
    # Priorità 3: generata al volo con convert (fallback)
    convert -size 128x128 xc:transparent \
        -fill '#1b5e20' -draw 'polygon 64,10 109,36 109,91 64,118 19,91 19,36' \
        -fill 'none' -strokewidth 3 -stroke '#388e3c' \
        -draw 'polygon 64,20 99,41 99,86 64,108 29,86 29,41' \
        -fill '#4caf50' -draw 'polygon 64,35 85,46 85,81 64,93 43,81 43,46' \
        -fill 'white' -font '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf' \
        -pointsize 28 -gravity center -annotate +0+0 'BKP' \
        "$TEMP_LOGO" 2>/dev/null || TEMP_LOGO=""
fi

# ── Primo avvio: nessun conf e nessuna cache → chiedi directory ──
if [ ! -f "$CONF_FILE" ] && [ ! -d "$ROOTFS_CACHE" ]; then
    FIRST_DIR=$(yad --file-selection --directory \
        --title="$S_SETTINGS_TITLE" \
        ${TEMP_LOGO:+--window-icon="$TEMP_LOGO"} \
        --filename="/mnt/" \
        --text="$S_SETTINGS_HEADER\n\n$S_SETTINGS_CACHE_DIR\n\n$S_SETTINGS_CACHE_HINT" \
        --button="$S_BTN_CANCEL:1" \
        --button="$S_BTN_OK" \
        --center 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$FIRST_DIR" ] && [ -d "$FIRST_DIR" ]; then
        CACHE_BASE_DIR="$FIRST_DIR"
        echo "CACHE_BASE_DIR=\"$CACHE_BASE_DIR\"" > "$CONF_FILE"
        CACHE_BASE="${CACHE_BASE_DIR}/${DISTRO_ID}_backup"
        ROOTFS_CACHE="${CACHE_BASE}/.rootfs_cache"
        CACHE_META="${CACHE_BASE}/.backup_meta"
    fi
fi

LOG_PID=""

log() {
    local ts; ts="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[$ts] $*" | tee -a "$LOG_FILE"
    { echo "[$ts] $*" >&3; } 2>/dev/null || true
}

open_log_window() {
    exec 3> >(yad --text-info \
        --title="$S_BACKUP_TITLE" \
        ${TEMP_LOGO:+--window-icon="$TEMP_LOGO"} \
        ${TEMP_LOGO:+--image="$TEMP_LOGO"} \
        --image-on-top \
        --back="#1a2e1a" --fore="#4caf50" \
        --fontname="Monospace 10" \
        --width=560 --height=400 \
        --tail --no-edit \
        --button="$S_BTN_CLOSE" \
        --center 2>/dev/null)
    LOG_PID=$!
}

close_log_window() {
    exec 3>&- 2>/dev/null || true
    if [ -n "$LOG_PID" ] && kill -0 "$LOG_PID" 2>/dev/null; then
        sleep 2; kill "$LOG_PID" 2>/dev/null
        wait "$LOG_PID" 2>/dev/null || true
    fi
    LOG_PID=""
}

read_meta() {
    if [ -f "$CACHE_META" ]; then
        source "$CACHE_META"
    else
        META_DATE="—"; META_DISTRO="—"; META_SIZE="—"; META_KERNEL="—"
    fi
}

write_meta() {
    sudo bash -c "cat > '$CACHE_META'" <<EOF
META_DATE="$(date '+%Y-%m-%d %H:%M:%S')"
META_DISTRO="$DISTRO_PRETTY"
META_SIZE="$(sudo du -sh "$ROOTFS_CACHE" 2>/dev/null | cut -f1)"
META_KERNEL="$(uname -r)"
EOF
}

############################################################
# BTRFS VERSIONING (raw btrfs + snapper integration v1.3+)
############################################################

# Nome del config snapper dedicato alla cache di backup.
SNAPPER_CFG_NAME="distroclone-backup"

# Verifica se la destinazione è su filesystem btrfs
is_btrfs() {
    df --output=fstype "$CACHE_BASE_DIR" 2>/dev/null | grep -q "btrfs"
}

# Verifica se snapper è installato
has_snapper() { command -v snapper >/dev/null 2>&1; }

# Determina il modello di versioning attivo per la cache corrente.
#   "snapper" → cache btrfs + snapper installato (v1.3+)
#   "btrfs"   → cache btrfs senza snapper (fallback v1.2.2)
#   "none"    → cache su fs non btrfs (ext4/xfs/…): nessun versioning
versioning_mode() {
    if ! is_btrfs; then echo "none"; return; fi
    if has_snapper; then echo "snapper"; return; fi
    echo "btrfs"
}

# Inizializza .rootfs_cache come subvolume btrfs (solo se non esiste ancora)
init_btrfs_subvolume() {
    if [ ! -d "$ROOTFS_CACHE" ]; then
        sudo mkdir -p "$CACHE_BASE"
        sudo btrfs subvolume create "$ROOTFS_CACHE" 2>/dev/null
        return 0
    fi
    if ! sudo btrfs subvolume show "$ROOTFS_CACHE" >/dev/null 2>&1; then
        log "$S_BTRFS_NOT_SUBVOL_WARN"
        return 1
    fi
    return 0
}

# Crea uno snapshot read-only della cache corrente
create_snapshot() {
    local snap_name="@$(date '+%Y-%m-%d_%H:%M')"
    sudo mkdir -p "$SNAPSHOTS_DIR"
    log "$S_SNAP_CREATING $snap_name"
    if sudo btrfs subvolume snapshot -r "$ROOTFS_CACHE" "$SNAPSHOTS_DIR/$snap_name" 2>/dev/null; then
        sudo bash -c "cat > '$SNAPSHOTS_DIR/${snap_name}.meta'" <<EOF
SNAP_DATE="$(date '+%Y-%m-%d %H:%M:%S')"
SNAP_DISTRO="$DISTRO_PRETTY"
SNAP_KERNEL="$(uname -r)"
SNAP_SIZE="$(sudo du -sh "$SNAPSHOTS_DIR/$snap_name" 2>/dev/null | cut -f1)"
EOF
        log "$S_SNAP_CREATED $SNAPSHOTS_DIR/$snap_name"
        return 0
    else
        log "$S_SNAP_ERR_TEXT"
        return 1
    fi
}

# Elenca snapshot disponibili (dal più vecchio al più recente)
list_snapshots() {
    [ -d "$SNAPSHOTS_DIR" ] || return
    find "$SNAPSHOTS_DIR" -maxdepth 1 -name '@*' -type d | sort
}

# Elimina gli snapshot in eccesso oltre MAX_SNAPSHOTS
prune_snapshots() {
    [ "${MAX_SNAPSHOTS:-3}" -le 0 ] && return
    local snaps
    mapfile -t snaps < <(list_snapshots)
    local count=${#snaps[@]}
    if [ "$count" -gt "$MAX_SNAPSHOTS" ]; then
        log "$S_SNAP_PRUNING"
        local to_delete=$(( count - MAX_SNAPSHOTS ))
        for (( i=0; i<to_delete; i++ )); do
            sudo btrfs subvolume delete "${snaps[$i]}" 2>/dev/null
            sudo rm -f "${snaps[$i]}.meta" 2>/dev/null
            log "  Removed: $(basename "${snaps[$i]}")"
        done
    fi
}

############################################################
# SNAPPER-BACKED VERSIONING (v1.3+)
# Quando snapper è disponibile, la cache è gestita come un
# subvolume con un config snapper dedicato. Gli snapshot
# vivono in $ROOTFS_CACHE/.snapshots/N/snapshot (RO).
############################################################

# Crea (se mancante) il config snapper per la cache e allinea
# NUMBER_LIMIT alle preferenze utente (MAX_SNAPSHOTS).
init_snapper_config() {
    init_btrfs_subvolume || return 1
    if ! sudo snapper -c "$SNAPPER_CFG_NAME" get-config >/dev/null 2>&1; then
        sudo snapper -c "$SNAPPER_CFG_NAME" create-config "$ROOTFS_CACHE" 2>/dev/null || return 1
        sudo snapper -c "$SNAPPER_CFG_NAME" set-config TIMELINE_CREATE=no            >/dev/null 2>&1 || true
        sudo snapper -c "$SNAPPER_CFG_NAME" set-config NUMBER_CLEANUP=yes             >/dev/null 2>&1 || true
    fi
    local lim="${MAX_SNAPSHOTS:-3}"
    [ "$lim" -le 0 ] && lim=999
    sudo snapper -c "$SNAPPER_CFG_NAME" set-config NUMBER_LIMIT="$lim"             >/dev/null 2>&1 || true
    sudo snapper -c "$SNAPPER_CFG_NAME" set-config NUMBER_LIMIT_IMPORTANT="$lim"  >/dev/null 2>&1 || true
    return 0
}

# Crea uno snapshot snapper della cache attuale.
# Userdata contiene metadati riusati al restore.
create_snapper_snapshot() {
    local size_kb
    size_kb=$(sudo du -sk "$ROOTFS_CACHE" 2>/dev/null | cut -f1)
    local desc
    desc="distroclone-backup $(date '+%Y-%m-%d %H:%M:%S')"
    log "$S_SNAP_CREATING"
    if sudo snapper -c "$SNAPPER_CFG_NAME" create \
            --type single \
            --description "$desc" \
            --userdata "distro=${DISTRO_PRETTY},kernel=$(uname -r),size_kb=${size_kb}" \
            >/dev/null 2>&1; then
        log "$S_SNAP_CREATED $desc"
        return 0
    else
        log "$S_SNAP_ERR_TEXT"
        return 1
    fi
}

# Elenca snapshot snapper come "NUMERO|PATH" (oldest → newest).
list_snapper_snapshots() {
    sudo snapper -c "$SNAPPER_CFG_NAME" list --type single --columns number 2>/dev/null \
        | awk 'NR>2 && $1 ~ /^[0-9]+$/ {print $1}' \
        | sort -n \
        | while read -r n; do
            [ "$n" -eq 0 ] && continue
            local p="$ROOTFS_CACHE/.snapshots/$n/snapshot"
            [ -d "$p" ] && echo "$n|$p"
          done
}

# Estrai un campo userdata per uno snapshot snapper specifico.
#   $1 = numero snapshot, $2 = chiave (es. distro, kernel, size_kb)
snapper_userdata_get() {
    local num="$1" key="$2"
    sudo snapper -c "$SNAPPER_CFG_NAME" list --type single --columns number,userdata 2>/dev/null \
        | awk -v n="$num" -v k="$key" '
            NR>2 && $1==n {
                # join the rest of fields as userdata string
                ud=$2; for (i=3;i<=NF;i++) ud=ud" "$i
                # parse comma-separated key=value pairs
                nKV=split(ud, kvs, ",")
                for (i=1;i<=nKV;i++) {
                    split(kvs[i], kv, "=")
                    gsub(/^[ \t]+|[ \t]+$/, "", kv[1])
                    if (kv[1]==k) { print kv[2]; exit }
                }
            }'
}

# Pruning gestito da snapper (NUMBER_LIMIT è già impostato in init).
prune_snapper_snapshots() {
    log "$S_SNAP_PRUNING"
    sudo snapper -c "$SNAPPER_CFG_NAME" cleanup number >/dev/null 2>&1 || true
}

# Lista unificata: ritorna "LABEL|PATH" per UI restore.
# - mode=snapper → "N|PATH"
# - mode=btrfs   → "@TIMESTAMP|PATH"
unified_list_snapshots() {
    local mode
    mode=$(versioning_mode)
    case "$mode" in
        snapper)
            list_snapper_snapshots
            ;;
        btrfs)
            local p
            for p in $(list_snapshots); do
                echo "$(basename "$p")|$p"
            done
            ;;
    esac
}

############################################################
# RSYNC EXCLUDES — condivise tra backup e restore
############################################################
# Mantenere simmetriche è critico: dal v1.2.2 il restore usa --delete,
# quindi ogni path escluso solo da un lato verrebbe cancellato sull'altro.
build_common_excludes() {
    COMMON_EXCL=(
        --exclude=/dev/* --exclude=/proc/* --exclude=/sys/*
        --exclude=/run/* --exclude=/tmp/* --exclude=/mnt/*
        --exclude=/media/* --exclude=/lost+found --exclude=/swapfile
        --exclude=/boot/efi --exclude=/boot/efi/*
        --exclude=/var/cache/apt/archives/* --exclude=/var/lib/apt/lists/*
        --exclude=/var/log/* --exclude=/var/tmp/*
        --exclude=/etc/NetworkManager/system-connections/*
        --exclude=/usr/share/distroclone-backup
        --exclude=/usr/bin/distroClone-backup
        --exclude=/snap --exclude=/snap/* --exclude=/var/snap
        --exclude=/var/lib/snapd
        # btrfs nested subvols (rootfs snapshots di syslinuxos-snapshots
        # e snapper-cache della cache backup). Difensivo: --one-file-system
        # già evita di attraversarli, ma --delete sul target potrebbe
        # rimuoverli senza questo escludi.
        --exclude=/.snapshots --exclude=/.snapshots/*
        --exclude=/var/lib/snapper
        --exclude=/home/*/.config/Claude
        --exclude=/home/*/.claude
        --exclude=/home/*/.claude.json
        --exclude=/home/*/.cache/claude-desktop-debian
        --exclude=/root/.config/Claude
        --exclude=/root/.claude
        --exclude=/root/.claude.json
        --exclude=/root/.cache/claude-desktop-debian
    )
}

############################################################
# BACKUP
############################################################
do_backup() {
    local MODE="$1"

    # ── Dialog opzioni backup ────────────────────────────────
    local OPT_RESULT
    OPT_RESULT=$(yad --form \
        --title="$S_APP_TITLE_WIN" \
        ${TEMP_LOGO:+--window-icon="$TEMP_LOGO"} \
        ${TEMP_LOGO:+--image="$TEMP_LOGO"} \
        --image-on-top \
        --width=480 --height=240 \
        --text="<big><b>$S_BACKUP_OPT_TITLE ($MODE)</b></big>\n\n$S_HOME_INCLUDE_WARN\n" \
        --separator="|" \
        --field="$S_HOME_INCLUDE:":CHK "FALSE" \
        --button="$S_BTN_CANCEL" \
        --button="$S_BTN_BACKUP_START:0" \
        --buttons-layout=spread \
        --center 2>/dev/null)

    [ $? -ne 0 ] && return

    local INCLUDE_HOME
    INCLUDE_HOME=$(echo "$OPT_RESULT" | cut -d'|' -f1)

    open_log_window
    log "══════════════════════════════════════════"
    log " DistroClone — BACKUP ($MODE)"
    log "══════════════════════════════════════════"
    log " Distro : $DISTRO_PRETTY"
    log " Kernel : $(uname -r)"
    log " Cache  : $ROOTFS_CACHE"
    if [ "$INCLUDE_HOME" = "TRUE" ]; then
        log " /home  : $S_HOME_INCLUDED"
    else
        log " /home  : $S_HOME_EXCLUDED"
    fi
    log "══════════════════════════════════════════"

    # ── Versioning: snapper (preferito) | btrfs raw | nessuno ─
    local MODE_V
    MODE_V=$(versioning_mode)
    log "Versioning mode: $MODE_V"
    case "$MODE_V" in
        snapper)
            if init_snapper_config; then
                create_snapper_snapshot
                prune_snapper_snapshots
            fi
            ;;
        btrfs)
            init_btrfs_subvolume
            if [ $? -eq 0 ] && sudo btrfs subvolume show "$ROOTFS_CACHE" >/dev/null 2>&1; then
                create_snapshot
                prune_snapshots
            fi
            ;;
        *)
            sudo mkdir -p "$ROOTFS_CACHE"
            ;;
    esac

    local RSYNC_OPTS="-aAXH --numeric-ids --one-file-system --delete"
    build_common_excludes
    local RSYNC_EXCL=("${COMMON_EXCL[@]}")

    # Aggiungi esclusione /home solo se non inclusa
    if [ "$INCLUDE_HOME" != "TRUE" ]; then
        RSYNC_EXCL+=(--exclude=/home/* --exclude=/root/*)
    fi

    if [ "$MODE" = "incremental" ]; then
        RSYNC_OPTS="$RSYNC_OPTS --update"
        log "$S_BACKUP_MODE_INC"
    else
        log "$S_BACKUP_MODE_FULL"
    fi
    log "$S_BACKUP_RSYNC_START"

    sudo rsync $RSYNC_OPTS "${RSYNC_EXCL[@]}" \
        --info=progress2 / "$ROOTFS_CACHE" 2>&1 | \
        while IFS= read -r line; do log "$line"; done

    local EXIT_CODE=${PIPESTATUS[0]}

    if [ $EXIT_CODE -eq 0 ] || [ $EXIT_CODE -eq 24 ]; then
        write_meta
        log ""; log "✓ Backup OK — $(sudo du -sh "$ROOTFS_CACHE" | cut -f1)"
        close_log_window
        yad --info \
            --title="$S_BACKUP_OK_TITLE" \
            ${TEMP_LOGO:+--window-icon="$TEMP_LOGO"} \
            ${TEMP_LOGO:+--image="$TEMP_LOGO"} \
            --text="$S_BACKUP_OK_TEXT\n\n\
<b>Distro:</b> $DISTRO_PRETTY\n\
<b>$S_KERNEL:</b> $(uname -r)\n\
<b>$S_BACKUP_OK_DATE:</b> $(date '+%Y-%m-%d %H:%M')\n\
<b>$S_BACKUP_OK_SIZE:</b> $(sudo du -sh "$ROOTFS_CACHE" | cut -f1)\n\
<b>$S_CACHE:</b> $ROOTFS_CACHE" \
            --button="$S_BTN_OK" --width=480 --height=240 \
            --fixed --center 2>/dev/null
    else
        log ""; log "✗ Backup ERROR (exit: $EXIT_CODE)"
        close_log_window
        yad --error \
            --title="$S_BACKUP_ERR_TITLE" \
            ${TEMP_LOGO:+--window-icon="$TEMP_LOGO"} \
            --text="$S_BACKUP_ERR_TEXT\n\nrsync exit code: $EXIT_CODE\n\n$S_LOG: $LOG_FILE" \
            --button="$S_BTN_OK" --width=400 --height=180 \
            --fixed --center 2>/dev/null
    fi
}

############################################################
# RESTORE — usa --delete con exclude simmetriche al backup,
# protegge /home /root /boot/efi /snap e gli altri path runtime
############################################################
do_restore() {
    read_meta

    # ── Dialog conferma con opzione ripristino /home ──────────
    OPT_RESULT=$(yad --form \
        --title="$S_RESTORE_TITLE" \
        ${TEMP_LOGO:+--window-icon="$TEMP_LOGO"} \
        ${TEMP_LOGO:+--image="$TEMP_LOGO"} \
        --image-on-top \
        --separator="|" \
        --text="$S_RESTORE_WARN_TITLE\n\n\
$S_RESTORE_WARN_TEXT\n\n\
$S_RESTORE_INFO_TITLE\n\
  • $S_RESTORE_INFO_DATE:    <b>$META_DATE</b>\n\
  • $S_RESTORE_INFO_DISTRO:  <b>$META_DISTRO</b>\n\
  • $S_RESTORE_INFO_KERNEL:  <b>$META_KERNEL</b>\n\
  • $S_RESTORE_INFO_SIZE:    <b>$META_SIZE</b>\n\n\
$S_HOME_INCLUDE_WARN\n" \
        --field="$S_HOME_INCLUDE:":CHK "FALSE" \
        --button="$S_BTN_CANCEL" \
        --button="$S_BTN_YES_RESTORE" \
        --buttons-layout=spread \
        --width=520 --height=500 --center 2>/dev/null)

    [ $? -ne 0 ] && return

    local RESTORE_HOME
    RESTORE_HOME=$(echo "$OPT_RESULT" | cut -d'|' -f1)

    # Exclude simmetriche al backup (necessario con --delete attivo)
    build_common_excludes
    local RSYNC_EXCL=("${COMMON_EXCL[@]}")
    # /home e /root: esclusi per default, ripristinati solo se richiesto
    if [ "$RESTORE_HOME" != "TRUE" ]; then
        RSYNC_EXCL+=(--exclude=/home --exclude=/home/* --exclude=/root --exclude=/root/*)
    fi

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

    sudo rsync -aAXH --numeric-ids --delete --delete-after \
        "${RSYNC_EXCL[@]}" \
        --info=progress2 \
        "$ROOTFS_CACHE/" / 2>&1 | \
        while IFS= read -r line; do log "$line"; done

    local EXIT_CODE=${PIPESTATUS[0]}

    if [ $EXIT_CODE -eq 0 ] || [ $EXIT_CODE -eq 24 ]; then
        log ""; log "✓ Restore OK"
        close_log_window

        # Testo protetti dinamico in base alla scelta
        if [ "$RESTORE_HOME" = "TRUE" ]; then
            PROTECTED_TEXT="<b>/boot/efi ✓   /snap ✓</b>"
        else
            PROTECTED_TEXT="$S_RESTORE_OK_PROTECTED"
        fi

        yad --info \
            --title="$S_RESTORE_OK_TITLE" \
            ${TEMP_LOGO:+--window-icon="$TEMP_LOGO"} \
            ${TEMP_LOGO:+--image="$TEMP_LOGO"} \
            --text="$S_RESTORE_OK_TEXT\n\n\
$S_RESTORE_OK_DATE\n<b>$META_DATE</b>\n\n\
${PROTECTED_TEXT}\n\n\
$S_RESTORE_OK_REBOOT" \
            --button="$S_BTN_REBOOT_NOW" \
            --button="$S_BTN_REBOOT_LATER" \
            --buttons-layout=spread \
            --width=480 --height=300 \
            --fixed --center 2>/dev/null
        [ $? -eq 10 ] && sudo reboot
    else
        log ""; log "✗ Restore ERROR (exit: $EXIT_CODE)"
        close_log_window
        yad --error \
            --title="$S_RESTORE_ERR_TITLE" \
            ${TEMP_LOGO:+--window-icon="$TEMP_LOGO"} \
            --text="$S_RESTORE_ERR_TEXT\n\nrsync exit code: $EXIT_CODE\n\n$S_LOG: $LOG_FILE" \
            --button="$S_BTN_OK" --width=400 --height=180 \
            --fixed --center 2>/dev/null
    fi
}

############################################################
# RESTORE DA SNAPSHOT
############################################################
do_restore_snapshot() {
    # Lista unificata: snapper se disponibile, altrimenti btrfs legacy.
    local snap_lines=()
    mapfile -t snap_lines < <(unified_list_snapshots)

    if [ ${#snap_lines[@]} -eq 0 ]; then
        yad --warning ${TEMP_LOGO:+--window-icon="$TEMP_LOGO"} \
            --title="$S_SNAP_SELECT_TITLE" \
            --text="$S_SNAP_NO_SNAPS" \
            --button="$S_BTN_OK" --width=380 --height=140 \
            --fixed --center 2>/dev/null
        return
    fi

    local MODE_V
    MODE_V=$(versioning_mode)

    # Costruisce lista per yad --list con metadati
    local list_args=()
    for line in "${snap_lines[@]}"; do
        local label snap_path
        label="${line%%|*}"
        snap_path="${line#*|}"
        local snap_date snap_distro snap_size
        if [ "$MODE_V" = "snapper" ]; then
            local size_kb
            snap_date=$(sudo snapper -c "$SNAPPER_CFG_NAME" list --type single --columns number,date 2>/dev/null \
                        | awk -v n="$label" 'NR>2 && $1==n {for(i=2;i<=NF;i++)printf "%s ",$i; print ""}' \
                        | sed 's/[[:space:]]*$//')
            snap_distro=$(snapper_userdata_get "$label" distro)
            size_kb=$(snapper_userdata_get "$label" size_kb)
            if [ -n "$size_kb" ] && [ "$size_kb" -gt 0 ] 2>/dev/null; then
                snap_size=$(numfmt --to=iec --suffix=B "$((size_kb*1024))" 2>/dev/null || echo "${size_kb}K")
            else
                snap_size=$(sudo du -sh "$snap_path" 2>/dev/null | cut -f1)
            fi
            [ -z "$snap_date" ]   && snap_date="—"
            [ -z "$snap_distro" ] && snap_distro="—"
            [ -z "$snap_size" ]   && snap_size="—"
            list_args+=("$snap_path" "snapper #$label" "$snap_date" "$snap_distro" "$snap_size")
        else
            local meta_file="${snap_path}.meta"
            if [ -f "$meta_file" ]; then
                source "$meta_file"
                snap_date="${SNAP_DATE:-—}"
                snap_distro="${SNAP_DISTRO:-—}"
                snap_size="${SNAP_SIZE:-—}"
            else
                snap_date="—"; snap_distro="—"; snap_size="—"
            fi
            list_args+=("$snap_path" "$label" "$snap_date" "$snap_distro" "$snap_size")
        fi
    done

    local SELECTED
    SELECTED=$(yad --list \
        --title="$S_SNAP_SELECT_TITLE" \
        ${TEMP_LOGO:+--window-icon="$TEMP_LOGO"} \
        --text="$S_SNAP_SELECT_TEXT\n" \
        --column="Path:HD" --column="Snapshot" --column="$S_RESTORE_INFO_DATE" \
        --column="$S_RESTORE_INFO_DISTRO" --column="$S_RESTORE_INFO_SIZE" \
        --width=640 --height=320 \
        --button="$S_BTN_CANCEL:1" \
        --button="$S_BTN_YES_RESTORE" \
        --center 2>/dev/null \
        "${list_args[@]}")

    [ $? -ne 0 ] && return
    local SNAP_PATH
    SNAP_PATH=$(echo "$SELECTED" | cut -d'|' -f1)
    [ -z "$SNAP_PATH" ] && return
    [ ! -d "$SNAP_PATH" ] && return

    # Conferma
    yad --question \
        --title="$S_SNAP_SELECT_TITLE" \
        ${TEMP_LOGO:+--window-icon="$TEMP_LOGO"} \
        --text="$S_RESTORE_WARN_TEXT\n\n<b>Snapshot:</b> $(basename "$SNAP_PATH")\n\n$S_RESTORE_CONFIRM" \
        --button="$S_BTN_CANCEL:1" \
        --button="$S_BTN_YES_RESTORE" \
        --width=460 --height=240 --fixed --center 2>/dev/null
    [ $? -ne 0 ] && return

    open_log_window
    log "══════════════════════════════════════════"
    log " DistroClone — RESTORE FROM SNAPSHOT"
    log " $S_RESTORE_LOG_FROM: $SNAP_PATH"
    log " $S_RESTORE_LOG_TO:   /"
    log "══════════════════════════════════════════"
    log "$S_RESTORE_RSYNC_START"

    build_common_excludes
    local RSYNC_EXCL=("${COMMON_EXCL[@]}")
    RSYNC_EXCL+=(--exclude=/home --exclude=/home/* --exclude=/root --exclude=/root/*)
    sudo rsync -aAXH --numeric-ids --delete --delete-after --info=progress2 \
        "${RSYNC_EXCL[@]}" \
        "$SNAP_PATH/" / 2>&1 | while IFS= read -r line; do log "$line"; done

    local EXIT_CODE=${PIPESTATUS[0]}

    if [ $EXIT_CODE -eq 0 ] || [ $EXIT_CODE -eq 24 ]; then
        log ""; log "✓ Restore from snapshot OK"
        close_log_window
        yad --info \
            --title="$S_RESTORE_OK_TITLE" \
            ${TEMP_LOGO:+--window-icon="$TEMP_LOGO"} \
            --text="$S_RESTORE_OK_TEXT\n\n<b>Snapshot:</b> $(basename "$SNAP_PATH")\n\n$S_RESTORE_OK_PROTECTED\n\n$S_RESTORE_OK_REBOOT" \
            --button="$S_BTN_REBOOT_LATER" \
            --button="$S_BTN_REBOOT_NOW" \
            --width=480 --height=280 --fixed --center 2>/dev/null
        [ $? -eq 10 ] && sudo reboot
    else
        log ""; log "✗ Restore ERROR (exit: $EXIT_CODE)"
        close_log_window
        yad --error \
            --title="$S_SNAP_ERR_TITLE" \
            ${TEMP_LOGO:+--window-icon="$TEMP_LOGO"} \
            --text="$S_SNAP_ERR_TEXT\n\nrsync exit code: $EXIT_CODE\n\n$S_LOG: $LOG_FILE" \
            --button="$S_BTN_OK" --width=400 --height=180 \
            --fixed --center 2>/dev/null
    fi
}

############################################################
# CRONJOB
############################################################
do_cronjob() {
    CURRENT_CRON=$(sudo crontab -l 2>/dev/null | grep "distroClone-backup" || echo "")
    if [ -n "$CURRENT_CRON" ]; then
        CRON_STATUS="$S_CRON_STATUS_ACTIVE"
        CRON_INFO="<small><tt>$CURRENT_CRON</tt></small>"
    else
        CRON_STATUS="$S_CRON_STATUS_NONE"
        CRON_INFO="$S_CRON_STATUS_NOCRON"
    fi

    RESULT=$(yad --form \
        --title="$S_CRON_DIALOG_TITLE" \
        ${TEMP_LOGO:+--window-icon="$TEMP_LOGO"} \
        ${TEMP_LOGO:+--image="$TEMP_LOGO"} \
        --image-on-top \
        --width=540 --height=460 \
        --text="$S_CRON_DIALOG_HEADER\n\n\
<b>Status:</b> $CRON_STATUS\n$CRON_INFO\n\n\
$S_CRON_HINT\n" \
        --separator="|" \
        --field="$S_CRON_FIELD_FREQ:":CB "$S_CRON_FREQ_DAILY!$S_CRON_FREQ_WEEKLY!$S_CRON_FREQ_MONTHLY" \
        --field="$S_CRON_FIELD_DAY:":CB "$S_CRON_DAYS" \
        --field="$S_CRON_FIELD_HOUR:":NUM "2!0..23!1!0" \
        --field="$S_CRON_FIELD_NOTIFY:":CHK "TRUE" \
        --button="$S_BTN_REMOVE" \
        --button="$S_BTN_CANCEL" \
        --button="$S_BTN_SAVE" \
        --buttons-layout=spread --center 2>/dev/null)

    local EXIT_CODE=$?

    if [ $EXIT_CODE -eq 20 ]; then
        sudo crontab -l 2>/dev/null | grep -v "distroClone-backup" | sudo crontab -
        yad --info ${TEMP_LOGO:+--window-icon="$TEMP_LOGO"} \
            --title="$S_CRON_REMOVED_TITLE" \
            --text="$S_CRON_REMOVED_TEXT\n\n<small><tt>sudo crontab -l</tt></small>" \
            --button="$S_BTN_OK" --width=380 --height=160 --fixed --center 2>/dev/null
        return
    fi
    [ $EXIT_CODE -ne 0 ] && return

    local FREQ WEEKDAY HOUR NOTIFY DOW CRON_EXPR CRON_LINE NOTIFY_CMD
    FREQ=$(echo "$RESULT"    | cut -d'|' -f1)
    WEEKDAY=$(echo "$RESULT" | cut -d'|' -f2)
    HOUR=$(echo "$RESULT"    | cut -d'|' -f3 | cut -d'.' -f1)
    NOTIFY=$(echo "$RESULT"  | cut -d'|' -f4)

    DOW=$(day_to_dow "$WEEKDAY")

    [ "$NOTIFY" = "TRUE" ] && \
        NOTIFY_CMD=" && notify-send 'DistroClone Backup' '$S_CRON_NOTIFY_MSG' --icon=distroclone-backup" || \
        NOTIFY_CMD=""

    CRON_EXPR=$(freq_to_cron "$FREQ" "$HOUR" "$DOW")
    CRON_LINE="$CRON_EXPR /usr/bin/distroClone-backup --incremental-silent$NOTIFY_CMD"
    ( sudo crontab -l 2>/dev/null | grep -v "distroClone-backup"; echo "$CRON_LINE" ) | sudo crontab -

    yad --info \
        --title="$S_CRON_SAVED_TITLE" \
        ${TEMP_LOGO:+--window-icon="$TEMP_LOGO"} \
        ${TEMP_LOGO:+--image="$TEMP_LOGO"} \
        --text="$S_CRON_SAVED_TEXT\n\n\
<b>$S_CRON_FREQ_LABEL:</b> $FREQ  |  <b>$S_CRON_HOUR_LABEL:</b> $HOUR:00\n\n\
<b>$S_CRON_EXPR_LABEL:</b>\n<small><tt>$CRON_LINE</tt></small>\n\n\
<small>$S_CRON_VERIFY: <tt>sudo crontab -l</tt>   $S_LOG: <tt>$LOG_FILE</tt></small>" \
        --button="$S_BTN_OK" --width=560 --height=290 \
        --fixed --center 2>/dev/null
}

############################################################
# ELIMINA CACHE
############################################################
do_delete_cache() {
    read_meta

    yad --question \
        --title="$S_DELETE_TITLE" \
        ${TEMP_LOGO:+--window-icon="$TEMP_LOGO"} \
        --text="$S_DELETE_TEXT\n\n\
<b>$S_DELETE_DATE:</b> $META_DATE\n\
<b>$S_DELETE_SIZE:</b> $META_SIZE\n\
<b>$S_DELETE_PATH:</b> $ROOTFS_CACHE\n\n\
$S_DELETE_WARN" \
        --button="$S_BTN_CANCEL" \
        --button="$S_BTN_DELETE_CONFIRM" \
        --buttons-layout=spread --width=440 --height=280 --center 2>/dev/null

    if [ $? -eq 0 ]; then
        # Elimina snapshot btrfs prima del rm -rf.
        # rm -rf non può rimuovere subvolumi btrfs read-only.
        # Due formati supportati:
        #   v1.2.2 raw:  $SNAPSHOTS_DIR/@YYYY-MM-DD_HH:MM  (subvolume diretto)
        #   v1.3 snapper: $SNAPSHOTS_DIR/N/snapshot         (subvolume annidato)
        if [ -d "$SNAPSHOTS_DIR" ]; then
            # Snapper format: N/snapshot (read-only subvolumes, foglie dell'albero)
            while IFS= read -r snap; do
                sudo btrfs subvolume delete "$snap" 2>/dev/null || true
            done < <(find "$SNAPSHOTS_DIR" -mindepth 2 -maxdepth 2 -name 'snapshot' -type d 2>/dev/null | sort)
            # Raw format: @* (vecchio v1.2.2)
            while IFS= read -r snap; do
                sudo btrfs subvolume delete "$snap" 2>/dev/null || true
                sudo rm -f "${snap}.meta" 2>/dev/null || true
            done < <(find "$SNAPSHOTS_DIR" -maxdepth 1 -name '@*' -type d 2>/dev/null | sort)
            # .snapshots è a sua volta un subvolume btrfs (snapper lo crea così)
            if sudo btrfs subvolume show "$SNAPSHOTS_DIR" >/dev/null 2>&1; then
                sudo btrfs subvolume delete "$SNAPSHOTS_DIR" 2>/dev/null || true
            else
                sudo rm -rf "$SNAPSHOTS_DIR" 2>/dev/null || true
            fi
        fi
        # Rimuove la cache principale (subvolume btrfs o directory normale)
        if sudo btrfs subvolume show "$ROOTFS_CACHE" >/dev/null 2>&1; then
            sudo btrfs subvolume delete "$ROOTFS_CACHE" 2>/dev/null || true
        else
            sudo rm -rf "$ROOTFS_CACHE" 2>/dev/null || true
        fi
        sudo rm -f "$CACHE_META" 2>/dev/null || true
        sudo crontab -l 2>/dev/null | grep -v "distroClone-backup" | sudo crontab - 2>/dev/null || true
        yad --info ${TEMP_LOGO:+--window-icon="$TEMP_LOGO"} \
            --title="$S_DELETE_OK_TITLE" \
            --text="$S_DELETE_OK_TEXT" \
            --button="$S_BTN_OK" --width=340 --height=140 --fixed --center 2>/dev/null
    fi
}

############################################################
# FUNZIONE: IMPOSTAZIONI
############################################################
do_settings() {
    local CURRENT_DIR="${CACHE_BASE_DIR:-/mnt}"

    # ── Passo 1: selezione directory ─────────────────────────
    local NEW_DIR
    NEW_DIR=$(yad --file-selection --directory \
        --title="$S_SETTINGS_TITLE" \
        ${TEMP_LOGO:+--window-icon="$TEMP_LOGO"} \
        --filename="${CURRENT_DIR}/" \
        --button="$S_BTN_CANCEL:1" \
        --button="$S_BTN_SAVE" \
        --center 2>/dev/null)

    [ $? -ne 0 ] && return
    [ -z "$NEW_DIR" ] && return

    if [ ! -d "$NEW_DIR" ]; then
        yad --warning ${TEMP_LOGO:+--window-icon="$TEMP_LOGO"} \
            --title="$S_SETTINGS_TITLE" \
            --text="$S_SETTINGS_WARN_DIR" \
            --button="$S_BTN_OK" --width=380 --height=140 \
            --fixed --center 2>/dev/null
        return
    fi

    # ── Passo 2: opzioni avanzate (max snapshot) ─────────────
    local ADV_RESULT
    ADV_RESULT=$(yad --form \
        --title="$S_SETTINGS_TITLE" \
        ${TEMP_LOGO:+--window-icon="$TEMP_LOGO"} \
        ${TEMP_LOGO:+--image="$TEMP_LOGO"} \
        --image-on-top \
        --width=480 --height=260 \
        --text="$S_SETTINGS_HEADER\n\n<b>$S_SETTINGS_CACHE_DIR:</b> <tt>$NEW_DIR</tt>\n\n$S_SETTINGS_CACHE_HINT\n" \
        --separator="|" \
        --field="$S_SETTINGS_MAX_SNAPS":NUM "${MAX_SNAPSHOTS:-3}!0..20!1!0" \
        --button="$S_BTN_CANCEL:1" \
        --button="$S_BTN_SAVE" \
        --center 2>/dev/null)

    [ $? -ne 0 ] && return

    local NEW_MAX_SNAPS
    NEW_MAX_SNAPS=$(echo "$ADV_RESULT" | cut -d'|' -f1)

    CACHE_BASE_DIR="$NEW_DIR"
    MAX_SNAPSHOTS="${NEW_MAX_SNAPS:-3}"

    # Salva nel conf file
    {
        echo "CACHE_BASE_DIR=\"$CACHE_BASE_DIR\""
        echo "MAX_SNAPSHOTS=\"$MAX_SNAPSHOTS\""
    } > "$CONF_FILE"

    # Aggiorna percorsi live
    CACHE_BASE="${CACHE_BASE_DIR}/${DISTRO_ID}_backup"
    ROOTFS_CACHE="${CACHE_BASE}/.rootfs_cache"
    CACHE_META="${CACHE_BASE}/.backup_meta"
    SNAPSHOTS_DIR="${CACHE_BASE}/.snapshots"

    yad --info ${TEMP_LOGO:+--window-icon="$TEMP_LOGO"} \
        --title="$S_SETTINGS_TITLE" \
        --text="$S_SETTINGS_SAVED\n\n<b>Cache:</b> <tt>$ROOTFS_CACHE</tt>" \
        --button="$S_BTN_OK" --width=440 --height=160 \
        --fixed --center 2>/dev/null
}

############################################################
# MENU PRINCIPALE — LOOP con array bash
############################################################
while true; do
    read_meta

    if [ -d "$ROOTFS_CACHE" ]; then
        CACHE_STATUS_TEXT="<span color='#2e7d32'>$S_CACHE_PRESENT</span>"
        CACHE_INFO_TEXT="$S_CACHE_DATA: <b>$META_DATE</b>   |   $S_CACHE_DISTRO: <b>$META_DISTRO</b>   |   $S_CACHE_SIZE: <b>$META_SIZE</b>"
    else
        CACHE_STATUS_TEXT="<span color='#c62828'>$S_CACHE_ABSENT</span>"
        CACHE_INFO_TEXT="$S_CACHE_RUN_FULL"
    fi

    CURRENT_CRON=$(sudo crontab -l 2>/dev/null | grep "distroClone-backup" || echo "")
    if [ -n "$CURRENT_CRON" ]; then
        CRON_INFO_TEXT="<span color='#2e7d32'>$S_CRON_ACTIVE</span>   <small><tt>$(echo "$CURRENT_CRON" | awk '{print $1,$2,$3,$4,$5}')</tt></small>"
    else
        CRON_INFO_TEXT="<span color='#888888'>$S_CRON_NONE</span>"
    fi

    # ── Stato versioning (snapper | btrfs raw | none) ────────
    MODE_V=$(versioning_mode)
    SNAP_COUNT=0
    case "$MODE_V" in
        snapper)
            SNAP_COUNT=$(unified_list_snapshots | wc -l)
            if [ "$SNAP_COUNT" -gt 0 ]; then
                BTRFS_TEXT="<span color='#1565c0'>$S_BTRFS_AVAILABLE   <small>(snapper · $SNAP_COUNT $S_SNAPSHOTS_COUNT)</small></span>"
            else
                BTRFS_TEXT="<span color='#1565c0'>$S_BTRFS_AVAILABLE   <small>(snapper · $S_SNAPSHOTS_NONE)</small></span>"
            fi
            ;;
        btrfs)
            SNAP_COUNT=$(list_snapshots | wc -l)
            if [ "$SNAP_COUNT" -gt 0 ]; then
                BTRFS_TEXT="<span color='#1565c0'>$S_BTRFS_AVAILABLE   <small>(btrfs raw · $SNAP_COUNT $S_SNAPSHOTS_COUNT)</small></span>"
            else
                BTRFS_TEXT="<span color='#1565c0'>$S_BTRFS_AVAILABLE   <small>(btrfs raw · $S_SNAPSHOTS_NONE)</small></span>"
            fi
            ;;
        *)
            BTRFS_TEXT="<span color='#888888'>$S_BTRFS_NOT_AVAILABLE</span>"
            ;;
    esac

    YAD_CMD=(
        yad --form
        --title="$S_APP_TITLE_WIN v1.3.0"
        ${TEMP_LOGO:+--window-icon="$TEMP_LOGO"}
        ${TEMP_LOGO:+--image="$TEMP_LOGO"}
        --image-on-top
        --width=660 --height=540
        --text="<big><b>$S_APP_TITLE</b></big>\n<i>$S_APP_SUBTITLE</i>\n\n<b>$S_SYSTEM:</b> $DISTRO_PRETTY  |  <b>$S_KERNEL:</b> $(uname -r)\n\n<b>$S_CACHE:</b>   $CACHE_STATUS_TEXT\n<span color='#555555'><small>$CACHE_INFO_TEXT</small></span>\n\n<b>Versioning:</b> $BTRFS_TEXT\n\n<b>$S_CRONJOB:</b> $CRON_INFO_TEXT\n\n<span color='#666666'><small>$S_CACHE: $ROOTFS_CACHE\n$S_LOG:   $LOG_FILE</small></span>\n"
        --button="${S_BTN_EXIT}:99"
        --button="${S_BTN_BACKUP_FULL}:10"
        --button="${S_BTN_BACKUP_INC}:11"
        --button="${S_BTN_RESTORE}:20"
        --button="${S_BTN_SCHEDULE}:40"
        --button="${S_BTN_SETTINGS}:50"
    )

    if [ -d "$ROOTFS_CACHE" ]; then
        YAD_CMD+=(--button="${S_BTN_DELETE_CACHE}:30")
    fi

    if is_btrfs && [ "$SNAP_COUNT" -gt 0 ]; then
        YAD_CMD+=(--button="${S_BTN_RESTORE_SNAP}:45")
    fi

    YAD_CMD+=(--buttons-layout=spread --center)

    "${YAD_CMD[@]}" 2>/dev/null
    EXIT_CODE=$?

    case $EXIT_CODE in
        10) do_backup "full" ;;
        11)
            if [ ! -d "$ROOTFS_CACHE" ]; then
                yad --warning ${TEMP_LOGO:+--window-icon="$TEMP_LOGO"} \
                    --title="$S_WARN_NO_CACHE_TITLE" \
                    --text="$S_WARN_NO_CACHE" \
                    --button="$S_BTN_OK" --width=380 --height=160 \
                    --fixed --center 2>/dev/null
            else
                do_backup "incremental"
            fi ;;
        20)
            if [ ! -d "$ROOTFS_CACHE" ]; then
                yad --warning ${TEMP_LOGO:+--window-icon="$TEMP_LOGO"} \
                    --title="$S_WARN_NO_CACHE_TITLE" \
                    --text="$S_WARN_NO_CACHE" \
                    --button="$S_BTN_OK" --width=380 --height=160 \
                    --fixed --center 2>/dev/null
            else
                do_restore
            fi ;;
        30) do_delete_cache ;;
        40) do_cronjob ;;
        45) do_restore_snapshot ;;
        50) do_settings ;;
        *)  break ;;
    esac

done

[ "$TEMP_LOGO" != "$ICON_PKG" ] && rm -f "$TEMP_LOGO" 2>/dev/null
exit 0
