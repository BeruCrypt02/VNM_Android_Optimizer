#!/system/bin/sh
# Game spoofer: makes the phone report itself as a Samsung Galaxy S24 Ultra (SM-S928B).
#   spoof_ctl.sh status   -> mode=on|off  model=<current ro.product.model>  rp=1|0
#   spoof_ctl.sh on|off   -> saved, applied right away (restart the game afterwards)
#   spoof_ctl.sh boot     -> called early at boot; applies the saved mode (default off)

STATE_DIR=${STATE_DIR:-/data/adb/mkvp_tools}
MODEF=$STATE_DIR/spoof_mode
ORIG=$STATE_DIR/spoof_orig
MODEL=SM-S928B
PROPS="ro.product.model ro.product.odm.model ro.product.system.model ro.product.vendor.model"

mkdir -p "$STATE_DIR" 2>/dev/null

RP=""
for c in resetprop /data/adb/ksu/bin/resetprop /data/adb/ap/bin/resetprop /data/adb/magisk/resetprop; do
    if command -v "$c" >/dev/null 2>&1; then RP="$c"; break; fi
    [ -x "$c" ] && { RP="$c"; break; }
done

get_mode() {
    _m=$(cat "$MODEF" 2>/dev/null | tr -d ' \r\n\t')
    [ "$_m" = "on" ] && echo on || echo off
}
set_mode() { echo "$1" > "$MODEF.tmp" && mv -f "$MODEF.tmp" "$MODEF"; }

# remember the real values once, before we ever change them
snapshot() {
    [ -s "$ORIG" ] && return
    : > "$ORIG.tmp"
    for p in $PROPS; do
        v=$(getprop "$p")
        [ -n "$v" ] && [ "$v" != "$MODEL" ] && echo "$p=$v" >> "$ORIG.tmp"
    done
    [ -s "$ORIG.tmp" ] && mv -f "$ORIG.tmp" "$ORIG" || rm -f "$ORIG.tmp"
}

apply_on() {
    [ -n "$RP" ] || return 1
    snapshot
    for p in $PROPS; do "$RP" -n "$p" "$MODEL" >/dev/null 2>&1; done
}
apply_off() {
    [ -n "$RP" ] || return 1
    [ -s "$ORIG" ] || return 0
    while IFS== read -r k v; do
        case "$k" in ro.product.*model) [ -n "$v" ] && "$RP" -n "$k" "$v" >/dev/null 2>&1 ;; esac
    done < "$ORIG"
}

case "$1" in
status)
    echo "mode=$(get_mode)"
    echo "model=$(getprop ro.product.model)"
    [ -n "$RP" ] && echo "rp=1" || echo "rp=0"
    ;;
on)  set_mode on;  apply_on  && echo OK || echo "ERR resetprop not found (applies after reboot)" ;;
off) set_mode off; apply_off && echo OK || echo "ERR resetprop not found (applies after reboot)" ;;
boot)
    [ "$(get_mode)" = "on" ] && apply_on
    exit 0
    ;;
*) echo "usage: spoof_ctl.sh status | on | off | boot"; exit 1 ;;
esac
