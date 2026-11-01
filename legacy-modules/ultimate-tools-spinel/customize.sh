#!/system/bin/sh
ui_print "- Ultimate_Tools_Spinel v1.0"
ui_print "- ULTIMATE TOOLKIT AND GSI FIXES FOR REDMI NOTE 15 4G !"
ui_print "  * OTG FIX (on/off toggle in the WebUI)"
ui_print "  * FOD FIX (original fix by ImKaka, overlay variant)"
ui_print "  * DEBLOATER"
ui_print "  * PERFORMANCE IMPROVEMENTS"
ui_print "  * BRIGHTNESS FIX (on/off in the WebUI)"
ui_print "  * GAME SPOOFER (Galaxy S24 Ultra, off by default, switch in the WebUI)"
ui_print "  * ROOT TERMINAL + CPU/GPU GOVERNORS + CPU FREQUENCIES (WebUI)"
ui_print "  * BATTERY / RAM / STORAGE / SCREEN Hz / OTG DEVICE DETECTION (WebUI)"
ui_print "  * SENSOR CHECK + LOG VIEWER (WebUI)"
ui_print "  * ADB + FASTBOOT TAB: flash other devices over OTG (import your own arm64 adb/fastboot)"
ui_print "  * USB MANAGEMENT tab: files + info of a phone on OTG, ROM detection, MiTool"
ui_print "  * TOUCHPAD tab: this phone as a mouse/pointer for the phone on OTG (ADB pointer)"
ui_print "  * REZYGISK bundled in the Modules tab (OFF by default; ON flashes it, OFF deletes every file of it)"
ui_print "- By MKVENOM & LEINXCLEARS"

if [ -n "$ARCH" ] && [ "$ARCH" != "arm64" ]; then
  abort "! arm64 only (brightness daemon + FOD helper are arm64 binaries)"
fi

set_perm_recursive "$MODPATH" 0 0 0755 0644
for f in service.sh post-fs-data.sh optimizer.sh uninstall.sh otg/service.sh fod/service.sh \
         fod/fpwatch.sh fod/fpstate.sh fod/fod_on.sh fod/fod_off.sh fod/collect.sh \
         fod/config.sh fod/bin/fodctl brightness/service.sh brightness/bin/brightnessd scripts/gov.sh scripts/brightness_ctl.sh scripts/flash_ctl.sh scripts/usb_ctl.sh scripts/fod_ctl.sh scripts/rezygisk_ctl.sh scripts/selinux_ctl.sh scripts/adbenv.sh scripts/rom_detect.sh scripts/states_ctl.sh scripts/manage_ctl.sh scripts/mouse_ctl.sh scripts/mouse_daemon.sh scripts/mitool_ctl.sh scripts/spoof_ctl.sh scripts/charge_ctl.sh scripts/dev_info.sh scripts/otg_info.sh scripts/sensors_info.sh \
         scripts/common.sh scripts/apply_perf.sh scripts/debloat_run.sh \
         scripts/restore_pkg.sh scripts/extract_one.sh scripts/rebuild_labels.sh; do
  [ -e "$MODPATH/$f" ] && set_perm "$MODPATH/$f" 0 0 0755
done

# Persistent OTG setting (lives outside the module dir so updates keep it). Default = on.
mkdir -p /data/adb/spinel_toolkit /data/adb/spinel_toolkit/tools 2>/dev/null
[ -s /data/adb/spinel_toolkit/otg_mode ] || echo on > /data/adb/spinel_toolkit/otg_mode

# FOD fix default = on
[ -s /data/adb/spinel_toolkit/fod_mode ] || echo on > /data/adb/spinel_toolkit/fod_mode

# ReZygisk (bundled, optional) default = OFF: nothing is installed until you switch it on in the Modules tab
[ -s /data/adb/spinel_toolkit/rezygisk_mode ] || echo off > /data/adb/spinel_toolkit/rezygisk_mode

# Brightness module default = OFF (turn it on in the Modules tab)
[ -s /data/adb/spinel_toolkit/brightness_mode ] || echo off > /data/adb/spinel_toolkit/brightness_mode

# Spoofer default = OFF (turn it on in the Modules tab). Switched to off once by this update, then your choice is kept.
if [ ! -f /data/adb/spinel_toolkit/.spoof_default_off ]; then
  echo off > /data/adb/spinel_toolkit/spoof_mode; touch /data/adb/spinel_toolkit/.spoof_default_off
fi

# Log folder was renamed: carry the old log over
if [ -d "/sdcard/AOSP - LOGS" ] && [ ! -d "/sdcard/SYSTEM TOOLKIT - LOGS" ]; then
  mkdir -p "/sdcard/SYSTEM TOOLKIT - LOGS" 2>/dev/null
  [ -f "/sdcard/AOSP - LOGS/AOSP - LOGS.log" ] && mv "/sdcard/AOSP - LOGS/AOSP - LOGS.log" "/sdcard/SYSTEM TOOLKIT - LOGS/SYSTEM TOOLKIT - LOGS.log" 2>/dev/null
  rmdir "/sdcard/AOSP - LOGS" 2>/dev/null
fi

# --- module id changed (mkvenompro_android_optimizer -> spinel_toolkit): carry data over, retire the old copy ---
OLDID=mkvenompro_android_optimizer
OLDDIR=/data/adb/modules/$OLDID
if [ -d "$OLDDIR" ]; then
  ui_print "- Moving data from the old '$OLDID' module"
  # debloater list MUST move: the old uninstall would otherwise bring every removed app back
  [ -f "$OLDDIR/removed_packages.txt" ] && cp -f "$OLDDIR/removed_packages.txt" "$MODPATH/removed_packages.txt" 2>/dev/null
  [ -f "$OLDDIR/systemperf.conf" ] && cp -f "$OLDDIR/systemperf.conf" "$MODPATH/systemperf.conf" 2>/dev/null
  [ -f "$OLDDIR/brightness/config.conf" ] && cp -f "$OLDDIR/brightness/config.conf" "$MODPATH/brightness/config.conf" 2>/dev/null
  # the old uninstall.sh would restore apps and wipe the shared settings folder: make it do nothing
  printf '#!/system/bin/sh\nexit 0\n' > "$OLDDIR/uninstall.sh" 2>/dev/null
  chmod 0755 "$OLDDIR/uninstall.sh" 2>/dev/null
  touch "$OLDDIR/disable" "$OLDDIR/remove" 2>/dev/null
  ui_print "- Old module will disappear after the next reboot"
fi

# Older standalone copies would fight this one: turn them off
for OLD in usb_otg_enable spinel_fod_fix spinel_fod_fix_fod spinel_brightness_controller spoofingS24; do
  if [ -d "/data/adb/modules/$OLD" ]; then
    touch "/data/adb/modules/$OLD/disable"
    ui_print "- Old module '$OLD' disabled (you can remove it)"
  fi
done

# Stop any running old OTG + FOD helpers.
# NOTE: an old brightnessd is deliberately NOT killed here - it holds a bind mount on the
# backlight node and killing it would freeze the brightness. It stops on the next reboot.
for P in $(ps -A 2>/dev/null | grep -v grep | awk '{print $2}'); do
  CL=$(tr '\0' ' ' < /proc/$P/cmdline 2>/dev/null)
  case "$CL" in
    *usb_otg_enable*service.sh*|*spinel_fod_fix*fpwatch*) kill $P 2>/dev/null ;;
  esac
done

ui_print "- Reboot once so FOD, brightness and the optimizer load."
ui_print "- OTG toggle changes also apply after a reboot."
ui_print "- Flash tab: put arm64 adb + fastboot in /sdcard/Download/spinel_tools/ and tap Import."
ui_print "- Spoofer applies at boot; switching it in the WebUI is instant (restart the game)."
