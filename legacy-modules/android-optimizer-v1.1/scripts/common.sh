#!/system/bin/sh
# Shared paths + logging helpers for HyperOS Perfkeeper

MODDIR=/data/adb/modules/mkvenompro_android_optimizer
CONF="$MODDIR/perfkeeper.conf"

# Log goes to INTERNAL STORAGE (not /data/adb) so the user can find it
# with any file manager / send it over without needing root tools.
LOGDIR="/sdcard/HyperOSPerfKeeper"
LOG="$LOGDIR/perfkeeper.log"

mkdir -p "$LOGDIR" 2>/dev/null

log() {
  mkdir -p "$LOGDIR" 2>/dev/null
  echo "$(date '+%Y-%m-%d %H:%M:%S') | $1" >> "$LOG"
  # keep the log from growing forever: cap at ~1000 lines
  if [ "$(wc -l < "$LOG" 2>/dev/null)" -gt 1000 ] 2>/dev/null; then
    tail -n 500 "$LOG" > "$LOG.tmp" 2>/dev/null && mv "$LOG.tmp" "$LOG"
  fi
}

# Read a key from perfkeeper.conf (key=value lines). Returns default if missing.
conf_get() {
  key="$1"; default="$2"
  if [ -f "$CONF" ]; then
    val=$(grep -m1 "^$key=" "$CONF" | cut -d'=' -f2-)
    [ -n "$val" ] && { echo "$val"; return; }
  fi
  echo "$default"
}

# True (exit 0) if the screen is currently off. Used to gate heavier/riskier
# maintenance (like db VACUUM) so it never runs while the user is actively
# using the phone. Falls back to "assume off" if dumpsys is unavailable,
# so maintenance still runs on devices where this check can't be made.
is_screen_off() {
  state=$(dumpsys power 2>/dev/null | grep -m1 "mWakefulness=")
  [ -z "$state" ] && return 0
  case "$state" in
    *mWakefulness=Awake*) return 1 ;;
    *) return 0 ;;
  esac
}

# True (exit 0) if at least $1 days passed since the unix-seconds timestamp
# stored in $2 (missing/empty file counts as "due now").
days_since_stamp() {
  need_days="$1"; stamp_file="$2"
  [ -f "$stamp_file" ] || return 0
  last=$(cat "$stamp_file" 2>/dev/null)
  case "$last" in ''|*[!0-9]*) return 0 ;; esac
  now=$(date +%s)
  elapsed_days=$(( (now - last) / 86400 ))
  [ "$elapsed_days" -ge "$need_days" ]
}
