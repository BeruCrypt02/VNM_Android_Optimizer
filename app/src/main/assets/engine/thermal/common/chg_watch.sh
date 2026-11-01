#!/system/bin/sh
# MkVenomPro Optimizer - charge limit keeper (only started when "Charge limit ~80%" is ON).
# The charger driver resets night_charging to 0 on every unplug, so a one-shot
# write is lost at the next replug. This loop sets it again while a charger is
# connected. It only sleeps and reads two sysfs files: no wakelock, and it does
# not wake the phone from deep sleep (sleep timers are frozen in suspend).
# Usage: chg_watch.sh <night_charging node>
NC=$1
HC_DATA=/data/adb/mkvp_thermal
MODDIR=/data/adb/mkvp/engine/thermal
PIDF=$HC_DATA/chg_watch.pid
STATE=$HC_DATA/chg_watch.state

[ -n "$NC" ] && [ -e "$NC" ] || exit 1
# one instance only
_old=$(cat "$PIDF" 2>/dev/null)
case "$_old" in ''|*[!0-9]*) ;; *)
  [ "$_old" != "$$" ] && grep -q chg_watch "/proc/$_old/cmdline" 2>/dev/null && exit 0 ;;
esac
echo $$ > "$PIDF"

online() {
  for _p in /sys/class/power_supply/usb/online /sys/class/power_supply/wireless/online \
            /sys/class/power_supply/dc/online /sys/class/power_supply/ac/online; do
    [ "$(cat "$_p" 2>/dev/null)" = 1 ] && return 0
  done
  return 1
}

_n=0
while :; do
  # stop when the module is disabled or being removed
  [ -f "$MODDIR/disable" ] || [ -f "$MODDIR/remove" ] || [ ! -d "$MODDIR" ] && break
  if online && [ "$(cat "$NC" 2>/dev/null)" != 1 ]; then
    if { echo 1 > "$NC"; } 2>/dev/null; then
      _n=$((_n + 1))
      echo "set=$_n last=$(date '+%Y-%m-%d %H:%M:%S')" > "$STATE"
    fi
  fi
  sleep 15
done
rm -f "$PIDF"
# module disabled/removed: do not leave the 80% cap stuck on
[ -f "$MODDIR/disable" ] || [ -f "$MODDIR/remove" ] || [ ! -d "$MODDIR" ] && { echo 0 > "$NC"; } 2>/dev/null
exit 0
