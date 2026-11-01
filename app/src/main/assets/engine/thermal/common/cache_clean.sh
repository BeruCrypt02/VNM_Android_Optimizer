#!/system/bin/sh
# MkVenomPro Optimizer - app cache cleaner
#   cache_clean.sh run [force]  clean once now (force = ignore the minimum size)
#   cache_clean.sh keeper       daily auto clean (started at boot when "Auto clean app cache" is ON)
# Cleaning uses Android's own "pm trim-caches" (same as Settings > Storage > free up cache),
# so no app data is touched. The keeper only sleeps (15 min steps, frozen in deep sleep, no
# wakelock) and checks a timestamp; the actual clean runs once every 24 h at lowest priority.
export PATH=/system/bin:/system/xbin:/vendor/bin:/data/adb/ksu/bin:/data/adb/ap/bin:/data/adb/magisk:"$PATH"
HC_DATA=/data/adb/mkvp_thermal
MODDIR=/data/adb/mkvp/engine/thermal
LAST=$HC_DATA/cache_clean.last     # cleared_kb|apps_cleaned|epoch|apps_scanned
CHECK=$HC_DATA/cache_clean.check   # epoch of the last daily check
PIDF=$HC_DATA/cache_keeper.pid

cfgv() { sed -n "s/^$1=//p" "$HC_DATA/config.conf" 2>/dev/null | tail -n 1 | tr -d '\r'; }

# "package kb" for every app cache dir (internal + external storage)
measure() {
  du -sk /data/data/*/cache /data/media/0/Android/data/*/cache 2>/dev/null | awk '{
    p = $2; sub(/^\/data\/data\//, "", p); sub(/^\/data\/media\/0\/Android\/data\//, "", p); sub(/\/cache$/, "", p)
    s[p] += $1 } END { for (k in s) print k, s[k] }'
}

run_clean() {
  # one clean at a time (keeper and the WebUI button); a lock older than 10 min is stale
  _lk=$HC_DATA/.cc_lock
  if ! mkdir "$_lk" 2>/dev/null; then
    [ -n "$(find "$_lk" -maxdepth 0 -mmin +10 2>/dev/null)" ] || return 0
    rm -rf "$_lk"; mkdir "$_lk" 2>/dev/null || return 0
  fi
  _b=$HC_DATA/.cc_before; _a=$HC_DATA/.cc_after
  measure > "$_b"
  _tot=$(awk '{ t += $2 } END { print t + 0 }' "$_b")
  _min=$(cfgv x_cache_min); case "$_min" in ''|*[!0-9]*) _min=0 ;; esac
  date +%s > "$CHECK"
  if [ "$1" != force ] && [ $((_tot / 1024)) -lt "$_min" ]; then
    echo "$_tot|$(date +%s)" > "$HC_DATA/cache_clean.skip"
    rm -f "$_b"; rmdir "$_lk" 2>/dev/null; return 0
  fi
  pm trim-caches 999999999999999 </dev/null >/dev/null 2>&1
  sleep 2
  measure > "$_a"
  # cleared = sum of per-app decrease; apps = how many apps got smaller; n = apps scanned
  _res=$(awk 'NR == FNR { b[$1] = $2; n++; next } { a[$1] = $2 }
    END { for (k in b) { d = b[k] - ((k in a) ? a[k] : 0); if (d > 4) { c++; t += d } } print (t + 0) "|" (c + 0) "|" (n + 0) }' "$_b" "$_a")
  echo "${_res%\|*}|$(date +%s)|${_res##*\|}" > "$LAST"
  rm -f "$_b" "$_a" "$HC_DATA/cache_clean.skip"
  rmdir "$_lk" 2>/dev/null
}

keeper() {
  _old=$(cat "$PIDF" 2>/dev/null)
  case "$_old" in ''|*[!0-9]*) ;; *)
    [ "$_old" != "$$" ] && grep -q cache_clean "/proc/$_old/cmdline" 2>/dev/null && exit 0 ;;
  esac
  echo $$ > "$PIDF"
  while :; do
    # first check 15 min after start: keeps the heavy boot phase free
    sleep 900
    [ -f "$MODDIR/disable" ] || [ -f "$MODDIR/remove" ] || [ ! -d "$MODDIR" ] && break
    [ "$(cfgv x_cache_auto)" = 1 ] || break
    _now=$(date +%s)
    _last=$(cat "$CHECK" 2>/dev/null); case "$_last" in ''|*[!0-9]*) _last=0 ;; esac
    if [ "$_last" = 0 ]; then
      echo "$_now" > "$CHECK"          # first day starts now
    elif [ $((_now - _last)) -ge 86400 ]; then
      run_clean
    fi
  done
  rm -f "$PIDF"
}

case "$1" in
  run) run_clean "$2"; cat "$LAST" 2>/dev/null ;;
  keeper) keeper ;;
  *) echo "usage: cache_clean.sh run [force] | keeper" ;;
esac
