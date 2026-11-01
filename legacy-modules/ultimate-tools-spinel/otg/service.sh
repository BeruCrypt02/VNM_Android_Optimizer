#!/system/bin/sh
# USB OTG source-mode controller  (v3.0)
#
# Mode is stored in /data/adb/spinel_toolkit/otg_mode  ("on" or "off"), set from the WebUI.
#   on  = force preferred_role=source for as long as the phone is up (OTG fix)
#   off = force preferred_role=sink   for as long as the phone is up (OTG disabled)
# The mode is read ONCE when this service starts, so a change made in the WebUI
# only takes effect after the next reboot. The mode that is really running is
# published in otg_active so the WebUI can show "pending reboot".

STATE_DIR=/data/adb/spinel_toolkit
CFG=$STATE_DIR/otg_mode
ACTIVE=$STATE_DIR/otg_active
LOG=/data/local/tmp/usb_otg_enable.log
PIDF=/data/local/tmp/spinel_otg.pid
P=/sys/class/typec/port0
PREF=$P/preferred_role
PTYPE=$P/port_type
ONLINE=/sys/class/power_supply/usb/online

mkdir -p "$STATE_DIR" 2>/dev/null

# --- single instance: stop an older copy of this service before taking over ---
if [ -f "$PIDF" ]; then
    OLD=$(cat "$PIDF" 2>/dev/null)
    case "$OLD" in ''|*[!0-9]*) OLD="" ;; esac
    if [ -n "$OLD" ] && [ "$OLD" != "$$" ] && grep -qF "$0" "/proc/$OLD/cmdline" 2>/dev/null; then
        kill "$OLD" 2>/dev/null
    fi
fi
echo $$ > "$PIDF"
rm -f "$ACTIVE"

log() { echo "$(date '+%F %T') $*" >> "$LOG"; }

until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 2; done
C=0
while [ ! -e "$PREF" ] && [ "$C" -lt 30 ]; do sleep 2; C=$((C+1)); done
if [ ! -e "$PREF" ]; then
    echo na > "$ACTIVE"
    echo "$(date '+%F %T') typec port0 not found" >> "$LOG"
    exit 1
fi

# --- the mode is re-read every cycle: a WebUI change applies within ~1 s, no reboot ---
getmode() {
    M=$(cat "$CFG" 2>/dev/null | tr -d ' \r\n\t')
    case "$M" in on|off) ;; *) M=on ;; esac
    echo "$M"
}

: > "$LOG"
log "started v3.1 (mode switches live)"

apply_on() {
    read CUR < "$PREF" 2>/dev/null
    if [ "$CUR" != "source" ]; then
        echo source > "$PREF" 2>/dev/null
        log "preferred_role was '$CUR' -> source"
    fi
    read PT < "$PTYPE" 2>/dev/null
    case "$PT" in
        *"[dual]"*) ;;
        *) echo dual > "$PTYPE" 2>/dev/null; log "port_type was '$PT' -> dual" ;;
    esac
}

kick() {
    echo dual > "$PTYPE" 2>/dev/null
    echo sink > "$PREF" 2>/dev/null
    sleep 0.5
    echo source > "$PREF" 2>/dev/null
    log "kick: $1 (pref=$(tr -d '\n' < $PREF) pwr=$(tr -d '\n' < $P/power_role) data=$(tr -d '\n' < $P/data_role))"
}

PREV=""; LAST=0; CH=0
while true; do
    MODE=$(getmode)
    if [ "$MODE" != "$PREV" ]; then
        echo "$MODE" > "$ACTIVE"
        log "mode -> $MODE"
        if [ "$MODE" = "on" ]; then apply_on; kick "mode switched to on"; fi
        PREV=$MODE; CH=0
    fi
    if [ "$MODE" = "off" ]; then
        read CUR < "$PREF" 2>/dev/null
        if [ "$CUR" != "sink" ]; then
            echo sink > "$PREF" 2>/dev/null
            CH=$((CH+1)); [ "$CH" -le 20 ] && log "preferred_role was '$CUR' -> sink"
        fi
        sleep 1
        continue
    fi
    apply_on
    read NOW < "$ONLINE" 2>/dev/null
    case "$NOW" in 0|1) ;; *) NOW=0 ;; esac
    if [ "$NOW" != "$LAST" ]; then
        log "online $LAST -> $NOW"
        if [ "$NOW" = "0" ]; then
            kick "unplug +0s"
            sleep 2; apply_on; kick "unplug +2s"
            sleep 3; apply_on; kick "unplug +5s"
        fi
        LAST=$NOW
    fi
    sleep 0.5
done
