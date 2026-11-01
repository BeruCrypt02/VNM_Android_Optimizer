#!/system/bin/sh
MODDIR=$(cd "${0%/*}" 2>/dev/null && pwd)
[ -n "$MODDIR" ] || MODDIR=${0%/*}
LOG="$MODDIR/brightnessd.log"
PIDF="$MODDIR/wrapper.pid"
MODEF=/data/adb/mkvp_tools/brightness_mode

until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 2; done
sleep 3

# The WebUI switch: "off" means do not start anything (also at every boot)
MODE=$(cat "$MODEF" 2>/dev/null | tr -d ' \r\n\t')
[ "$MODE" != "on" ] && exit 0

# Never run two writers: stop an older wrapper loop before taking over
OLD=$(cat "$PIDF" 2>/dev/null)
case "$OLD" in ''|*[!0-9]*) OLD="" ;; esac
if [ -n "$OLD" ] && [ "$OLD" != "$$" ] && grep -qF "brightness/service.sh" "/proc/$OLD/cmdline" 2>/dev/null; then
  kill "$OLD" 2>/dev/null
fi

MODE=$(cat "$MODEF" 2>/dev/null | tr -d ' \r\n\t')
[ "$MODE" != "on" ] && exit 0

rm -f "$MODDIR/stop"
pkill -f "$MODDIR/bin/brightnessd" 2>/dev/null
sleep 1
(
  : > "$LOG"
  while [ ! -f "$MODDIR/stop" ]; do
    "$MODDIR/bin/brightnessd" "$MODDIR/config.conf" >> "$LOG" 2>&1
    [ -f "$MODDIR/stop" ] && break
    echo "daemon exited ($?), restarting" >> "$LOG"
    sleep 2
  done
) &
echo $! > "$PIDF"
