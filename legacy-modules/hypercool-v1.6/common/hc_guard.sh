#!/system/bin/sh
# HyperCool guard (installed to /data/adb/service.d by HyperCool).
# Runs at every boot even while the module is disabled, so nothing is left behind:
#  - module disabled in the root manager: every recorded ROM change is given back
#    (your HyperCool settings are kept; enabling the module applies them again)
#  - module removed: final cleanup if uninstall.sh could not run, then this file deletes itself
MOD=/data/adb/modules/hypercool
D=/data/adb/hypercool
if [ ! -d "$MOD" ]; then
  # uninstall.sh normally restores everything; give it time, then clean up whatever is left
  sleep 180
  [ -f "$D/restore.sh" ] && sh "$D/restore.sh" --all --wait-boot --purge >/dev/null 2>&1
  rm -f "$0"
  exit 0
fi
[ -f "$MOD/disable" ] || exit 0
for _n in /sys/class/qcom-battery/night_charging /sys/class/power_supply/battery/night_charging; do
  [ -e "$_n" ] && { echo 0 > "$_n"; } 2>/dev/null
done
if [ -s "$D/backup/rom.bak" ] && [ -f "$D/restore.sh" ]; then
  sh "$D/restore.sh" --all --wait-boot >/dev/null 2>&1
  echo "$(date '+%Y-%m-%d %H:%M:%S') module disabled: ROM changes restored by the guard" >> "$D/boot.log"
fi
exit 0
