#!/system/bin/sh
DIR=${0%/*}
. "$DIR/common.sh"

# simple lock so WebUI toggle taps and the daily loop don't overlap
LOCK="/data/local/tmp/.hpk_apply_perf.lock"
i=0
while ! mkdir "$LOCK" 2>/dev/null; do
  i=$((i+1))
  [ "$i" -gt 20 ] && break
  sleep 0.5
done
trap 'rmdir "$LOCK" 2>/dev/null' EXIT

log "apply_perf: start"

# --- I/O scheduler ---
if [ "$(conf_get IO_SCHEDULER_ENABLE 1)" = "1" ]; then
  WANT=$(conf_get IO_SCHEDULER deadline)
  for q in /sys/block/*/queue/scheduler; do
    [ -f "$q" ] || continue
    AVAIL=$(cat "$q" 2>/dev/null | tr -d '[]')
    TOKEN=""
    for cand in "$WANT" "mq-$WANT" "${WANT#mq-}"; do
      for a in $AVAIL; do
        [ "$a" = "$cand" ] && TOKEN="$cand" && break 2
      done
    done
    if [ -n "$TOKEN" ]; then
      echo "$TOKEN" > "$q" 2>/dev/null
    fi
  done
  log "io scheduler -> $WANT (actual token written may be mq-$WANT depending on kernel)"
fi

# --- Swappiness ---
if [ "$(conf_get SWAPPINESS_ENABLE 1)" = "1" ]; then
  SW=$(conf_get SWAPPINESS 10)
  [ -f /proc/sys/vm/swappiness ] && echo "$SW" > /proc/sys/vm/swappiness 2>/dev/null
  log "swappiness -> $SW"
fi

# --- Dirty ratio / dirty background ratio (writeback tuning) ---
if [ "$(conf_get DIRTY_RATIO_ENABLE 1)" = "1" ]; then
  DR=$(conf_get DIRTY_RATIO 15)
  DBR=$(conf_get DIRTY_BG_RATIO 5)
  [ -f /proc/sys/vm/dirty_ratio ] && echo "$DR" > /proc/sys/vm/dirty_ratio 2>/dev/null
  [ -f /proc/sys/vm/dirty_background_ratio ] && echo "$DBR" > /proc/sys/vm/dirty_background_ratio 2>/dev/null
  log "dirty_ratio -> $DR, dirty_background_ratio -> $DBR"
fi

log "apply_perf: done"
