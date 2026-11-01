#!/system/bin/sh
# usage: engine_ctl.sh status | disable | enable | uninstall
ENG=${0%/*}
case "$ENG" in /*) ;; *) ENG=$(cd "$ENG" 2>/dev/null && pwd) ;; esac
export PATH=/system/bin:/system/xbin:/vendor/bin:/data/adb/ksu/bin:/data/adb/ap/bin:/data/adb/magisk:$PATH
BASE=/data/adb/mkvp

case "$1" in
status)
  [ -f "$ENG/thermal/module.prop" ] && [ -f "$ENG/tools/module.prop" ] && echo "installed=1" || echo "installed=0"
  [ -f "$BASE/disable" ] && echo "enabled=0" || echo "enabled=1"
  echo "version=$(cat /data/adb/mkvp_engine_version 2>/dev/null)"
  [ -x /data/adb/post-fs-data.d/mkvp_engine.sh ] && echo "hook_postfs=1" || echo "hook_postfs=0"
  [ -x /data/adb/service.d/mkvp_engine.sh ] && echo "hook_service=1" || echo "hook_service=0"
  ;;
disable)
  touch "$BASE/disable" "$ENG/thermal/disable" "$ENG/tools/disable"
  echo "OK disabled (ROM changes are given back at the next boot by the guard)" ;;
enable)
  rm -f "$BASE/disable" "$ENG/thermal/disable" "$ENG/tools/disable"
  echo "OK enabled (applies at the next boot)" ;;
uninstall)
  # same cleanup the old module uninstallers did, then remove every trace of the engine
  [ -f "$ENG/tools/uninstall.sh" ] && sh "$ENG/tools/uninstall.sh" >/dev/null 2>&1
  [ -f "$ENG/thermal/uninstall.sh" ] && sh "$ENG/thermal/uninstall.sh" >/dev/null 2>&1
  rm -f /data/adb/post-fs-data.d/mkvp_engine.sh /data/adb/service.d/mkvp_engine.sh
  rm -f /data/adb/mkvp_engine_version
  rm -rf "$BASE"
  echo "OK engine removed (reboot to clear the mounts)" ;;
*) echo "usage: engine_ctl.sh status|disable|enable|uninstall"; exit 1 ;;
esac
exit 0
