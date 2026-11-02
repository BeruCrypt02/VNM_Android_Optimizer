#!/system/bin/sh
# VNM Optimizer - uninstall
# Kernel values reset by themselves on reboot. ROM changes (settings,
# device_config, disabled packages) are restored once Android has booted.
HC_DATA=/data/adb/mkvp_thermal
# stop the cache keeper
_cp=$(cat "$HC_DATA/cache_keeper.pid" 2>/dev/null)
case "$_cp" in ''|*[!0-9]*) ;; *) grep -q cache_clean "/proc/$_cp/cmdline" 2>/dev/null && kill "$_cp" 2>/dev/null ;; esac
# stop the charge-limit keeper and give the night charging flag back to the ROM
_wp=$(cat "$HC_DATA/chg_watch.pid" 2>/dev/null)
case "$_wp" in ''|*[!0-9]*) ;; *) grep -q chg_watch "/proc/$_wp/cmdline" 2>/dev/null && kill "$_wp" 2>/dev/null ;; esac
for _n in /sys/class/qcom-battery/night_charging /sys/class/power_supply/battery/night_charging; do
  [ -e "$_n" ] && { echo 0 > "$_n"; } 2>/dev/null
done
# the guard is not needed any more (restore below does the cleanup)
rm -f /data/adb/service.d/.mkvp_guard.sh
if [ -f "$HC_DATA/restore.sh" ]; then
  nohup sh "$HC_DATA/restore.sh" --all --wait-boot --purge >/dev/null 2>&1 &
else
  rm -rf "$HC_DATA"
fi
