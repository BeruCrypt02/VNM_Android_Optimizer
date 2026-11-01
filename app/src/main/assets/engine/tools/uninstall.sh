#!/system/bin/sh
# Restore every package the debloater removed, then undo the OTG + brightness overrides
MODDIR=/data/adb/mkvp/engine/tools
LIST="$MODDIR/removed_packages.txt"
if [ -f "$LIST" ]; then
  sort -u "$LIST" | while read -r pkg; do
    [ -z "$pkg" ] && continue
    pm install-existing "$pkg" >/dev/null 2>&1
  done
fi

# Governors: stop the re-apply service, put the boot-time governors back
GP=$(cat /data/local/tmp/spinel_gov.pid 2>/dev/null)
[ -n "$GP" ] && kill "$GP" 2>/dev/null
sh "$MODDIR/scripts/gov.sh" reset >/dev/null 2>&1
rm -f /data/local/tmp/spinel_gov.pid

# Fast-charge fix: stop the loop, put the throttle back
sh "$MODDIR/scripts/charge_ctl.sh" off >/dev/null 2>&1

# Touchpad tab: stop the ADB pointer worker
sh "$MODDIR/scripts/mouse_ctl.sh" stop >/dev/null 2>&1

# ADB/fastboot tab: stop any running job + adb server before the shared folder is wiped
sh "$MODDIR/scripts/flash_ctl.sh" cancel >/dev/null 2>&1
sh "$MODDIR/scripts/flash_ctl.sh" killserver >/dev/null 2>&1
pkill -f mkvp_tools/tools 2>/dev/null

# OTG: stop the service and put the port back to sink
OP=$(cat /data/local/tmp/spinel_otg.pid 2>/dev/null)
[ -n "$OP" ] && kill "$OP" 2>/dev/null
echo sink > /sys/class/typec/port0/preferred_role 2>/dev/null
rm -rf /data/adb/mkvp_tools
rm -f /data/local/tmp/usb_otg_enable.log /data/local/tmp/spinel_otg.pid

# Brightness: stop the daemon, then drop the backlight bind mount
touch "$MODDIR/brightness/stop" 2>/dev/null
pkill -f brightnessd 2>/dev/null
sleep 1
umount -l /sys/class/leds/lcd-backlight/brightness 2>/dev/null
