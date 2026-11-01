#!/system/bin/sh
MODDIR=${0%/*}
. "$MODDIR/scripts/common.sh"

while [ "$(getprop sys.boot_completed)" != "1" ]; do
  sleep 5
done
sleep 20

log "===== boot: HyperOS Perfkeeper v1.1 starting ====="
ROM_INFO="generic/AOSP-based"
[ -n "$(getprop ro.mi.os.version.name 2>/dev/null)" ] && ROM_INFO="HyperOS $(getprop ro.mi.os.version.name)"
[ -n "$(getprop ro.miui.ui.version.name 2>/dev/null)" ] && ROM_INFO="MIUI $(getprop ro.miui.ui.version.name)"
[ -n "$(getprop ro.build.version.oneui 2>/dev/null)" ] && ROM_INFO="Samsung OneUI $(getprop ro.build.version.oneui)"
[ -n "$(getprop ro.build.version.opporom 2>/dev/null)" ] && ROM_INFO="ColorOS $(getprop ro.build.version.opporom)"
log "device: $(getprop ro.product.model) | ROM: $ROM_INFO | android: $(getprop ro.build.version.release)"

sh "$MODDIR/scripts/apply_perf.sh"

(
  while true; do
    log "maintenance cycle: start"

    if [ "$(conf_get F2FS_GC_ENABLE 1)" = "1" ]; then
      for gc in /sys/fs/f2fs/*/gc_urgent; do
        [ -f "$gc" ] && echo 1 > "$gc" 2>/dev/null
      done
      sleep 60
      for gc in /sys/fs/f2fs/*/gc_urgent; do
        [ -f "$gc" ] && echo 0 > "$gc" 2>/dev/null
      done
      log "f2fs gc_urgent cycle done"
    fi

    if [ "$(conf_get FSTRIM_ENABLE 1)" = "1" ]; then
      fstrim /data >/dev/null 2>&1 && log "fstrim /data ok" || log "fstrim /data failed (unsupported?)"
      fstrim /cache >/dev/null 2>&1
    fi

    if [ "$(conf_get DB_VACUUM_ENABLE 1)" = "1" ] && command -v sqlite3 >/dev/null 2>&1; then
      VACUUM_DAYS=$(conf_get DB_VACUUM_INTERVAL_DAYS 7)
      IDLE_ONLY=$(conf_get DB_VACUUM_IDLE_ONLY 1)
      STAMP="$MODDIR/.last_vacuum"

      RUN_OK=1
      [ "$IDLE_ONLY" = "1" ] && ! is_screen_off && RUN_OK=0
      days_since_stamp "$VACUUM_DAYS" "$STAMP" || RUN_OK=0

      if [ "$RUN_OK" = "1" ]; then
        VACUUMED=0
        for db in /data/system/users/0/*.db \
                  /data/data/com.android.providers.contacts/databases/*.db \
                  /data/data/com.android.providers.media.module/databases/*.db; do
          [ -f "$db" ] || continue
          # Skip anything that isn't perfectly healthy right now instead of
          # forcing a VACUUM on it -- a busy/locked/corrupt db fails this
          # check cleanly rather than risking a stuck write.
          CHECK=$(sqlite3 "$db" "PRAGMA busy_timeout=3000; PRAGMA quick_check;" 2>/dev/null)
          if [ "$CHECK" = "ok" ]; then
            sqlite3 "$db" "PRAGMA busy_timeout=3000; VACUUM;" 2>/dev/null && VACUUMED=$((VACUUMED+1))
          else
            log "db vacuum: skipped $(basename "$db") (busy or quick_check failed)"
          fi
        done
        date +%s > "$STAMP" 2>/dev/null
        log "db vacuum done ($VACUUMED db(s) vacuumed)"
      else
        log "db vacuum: skipped this cycle (screen on or not due yet)"
      fi
    fi

    if [ "$(conf_get JUNK_CLEAN_ENABLE 1)" = "1" ]; then
      find /data/local/tmp -type f -mtime +7 -delete 2>/dev/null
      find /data/anr -type f -mtime +7 -delete 2>/dev/null
      log "junk clean done"
    fi

    # re-apply perf config each cycle in case another module/reboot reset it
    sh "$MODDIR/scripts/apply_perf.sh"

    log "maintenance cycle: end, sleeping 24h"
    sleep 86400
  done
) &
