#!/system/bin/sh
# Brightness fix on/off, applied immediately and remembered across reboots.
#   brightness_ctl.sh status   -> mode=on|off / running=0|1 / info=<first line of daemon log>
#   brightness_ctl.sh on
#   brightness_ctl.sh off      -> stops the daemon AND removes its backlight bind mount

DIR=$(cd "${0%/*}" 2>/dev/null && pwd)
[ -n "$DIR" ] || DIR=${0%/*}
BR=${DIR%/scripts}/brightness
STATE_DIR=/data/adb/spinel_toolkit
MODEF=$STATE_DIR/brightness_mode
BL=/sys/class/leds/lcd-backlight/brightness

mkdir -p "$STATE_DIR" 2>/dev/null

get_mode() {
    _m=$(cat "$MODEF" 2>/dev/null | tr -d ' \r\n\t')
    [ "$_m" = "on" ] && echo on || echo off
}
set_mode() { echo "$1" > "$MODEF.tmp" && mv -f "$MODEF.tmp" "$MODEF"; }

# full command lines of all processes (Android toybox wants ARGS, procps wants args)
psargs() { ps -A -o ARGS 2>/dev/null || ps -A -o args 2>/dev/null || ps -A 2>/dev/null; }

is_running() { psargs | grep -v grep | grep -qF "brightnessd"; }

# a start that is still in its warm-up (or the restart loop) also counts as "already starting"
starter_active() { psargs | grep -v grep | grep -qF "brightness/service.sh"; }

# the daemon mounts in the init namespace, so try there as well
unmount_bl() {
    _i=0
    while grep -q " $BL " /proc/1/mounts 2>/dev/null && [ "$_i" -lt 5 ]; do
        umount -l "$BL" 2>/dev/null || nsenter -t 1 -m -- umount -l "$BL" 2>/dev/null
        _i=$((_i+1))
    done
}

stop_daemon() {
    touch "$BR/stop"                      # tells the wrapper loop not to restart it
    pkill -f "$BR/service.sh" 2>/dev/null # starters still warming up + the restart loop
    _w=$(cat "$BR/wrapper.pid" 2>/dev/null)
    case "$_w" in ''|*[!0-9]*) _w="" ;; esac
    [ -n "$_w" ] && grep -qF "brightness/service.sh" "/proc/$_w/cmdline" 2>/dev/null && kill "$_w" 2>/dev/null
    pkill -f "$BR/bin/brightnessd" 2>/dev/null
    _i=0
    while is_running && [ "$_i" -lt 6 ]; do sleep 0.5; _i=$((_i+1)); done
    is_running && { pkill -9 -f "$BR/bin/brightnessd" 2>/dev/null; sleep 0.5; }
    unmount_bl
}

case "$1" in
status)
    echo "mode=$(get_mode)"
    is_running && echo "running=1" || echo "running=0"
    echo "info=$(head -n1 "$BR/brightnessd.log" 2>/dev/null)"
    ;;
on)
    set_mode on || { echo "ERR cannot save mode"; exit 1; }
    if is_running || starter_active; then
        echo "OK already running"
    else
        nohup sh "$BR/service.sh" >/dev/null 2>&1 </dev/null &
        echo "OK starting"
    fi
    ;;
off)
    set_mode off || { echo "ERR cannot save mode"; exit 1; }
    stop_daemon
    is_running && { echo "ERR daemon still running"; exit 1; }
    echo "OK stopped"
    ;;
*)
    echo "usage: brightness_ctl.sh status|on|off"; exit 1 ;;
esac
