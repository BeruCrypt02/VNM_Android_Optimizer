#!/system/bin/sh
# ReZygisk (bundled, unmodified zip) on/off from the Modules tab. Default = OFF = not installed, nothing on the phone.
#   rezygisk_ctl.sh status -> mode=on|off installed=0|1 running=0|1 leftover=<count> version= bundled=
#   rezygisk_ctl.sh on     -> wipes any old ReZygisk files, then flashes the bundled zip fresh (KernelSU / APatch / Magisk). Reboot needed.
#   rezygisk_ctl.sh off    -> force-deletes EVERY file ReZygisk has on the phone and checks that nothing is left.
#                             (a copy already loaded in memory disappears at the next reboot)
DIR=$(cd "${0%/*}" 2>/dev/null && pwd); [ -n "$DIR" ] || DIR=${0%/*}
RZ=${DIR%/scripts}/rezygisk; ZIP=$RZ/ReZygisk.zip
STATE=${SPINEL_STATE:-/data/adb/spinel_toolkit}; MODEF=$STATE/rezygisk_mode
ADB=${RZ_ADB:-/data/adb}
MOD=${RZ_MODDIR:-$ADB/modules/rezygisk}
# everything ReZygisk's installer / boot scripts create
ALLP="$MOD $ADB/modules_update/rezygisk $ADB/post-fs-data.d/rezygisk.sh $ADB/post-mount.d/rezygisk.sh $ADB/service.d/rezygisk.sh $ADB/rezygisk"
TMPZ=/data/local/tmp/rezygisk_install.zip
mkdir -p "$STATE" 2>/dev/null
get_mode() { _m=$(cat "$MODEF" 2>/dev/null | tr -d ' \r\n\t'); [ "$_m" = "on" ] && echo on || echo off; }
set_mode() { echo "$1" > "$MODEF.tmp" && mv -f "$MODEF.tmp" "$MODEF"; }
# KernelSU / Magisk unpack into modules_update first and move it into modules at the next reboot
installed() { [ -f "$MOD/module.prop" ] || [ -f "$ADB/modules_update/rezygisk/module.prop" ]; }
running() { ps -A -o ARGS 2>/dev/null | grep -v grep | grep -qiE 'zygiskd|rezygisk'; }
prop() { grep -m1 "^$2=" "$1" 2>/dev/null | cut -d= -f2-; }
T=""; command -v timeout >/dev/null 2>&1 && T="timeout 180"

# force-delete every ReZygisk file (immutable flag / stuck mounts are cleared first)
purge() {
  for _p in $ALLP; do
    [ -e "$_p" ] || [ -L "$_p" ] || continue
    chattr -R -i "$_p" 2>/dev/null
    rm -rf "$_p" 2>/dev/null
    if [ -e "$_p" ]; then umount -l "$_p" 2>/dev/null; rm -rf "$_p" 2>/dev/null; fi
  done
  rm -f "$TMPZ" "$STATE/rezygisk_install.log" 2>/dev/null
  # ReZygisk created these folders; only removed when empty so other modules' scripts are never touched
  rmdir "$ADB/post-fs-data.d" "$ADB/post-mount.d" 2>/dev/null
  return 0
}
leftovers() { for _p in $ALLP; do { [ -e "$_p" ] || [ -L "$_p" ]; } && echo "$_p"; done; }

do_install() {
  [ -f "$ZIP" ] || { echo "ERR the bundled ReZygisk zip is missing"; return 1; }
  cp -f "$ZIP" "$TMPZ" 2>/dev/null || { echo "ERR cannot copy the zip to /data/local/tmp"; return 1; }
  chmod 644 "$TMPZ" 2>/dev/null
  _rc=1
  if [ -x /data/adb/ksud ]; then $T /data/adb/ksud module install "$TMPZ" 2>&1; _rc=$?
  elif command -v ksud >/dev/null 2>&1; then $T ksud module install "$TMPZ" 2>&1; _rc=$?
  elif [ -x /data/adb/ap/bin/apd ]; then $T /data/adb/ap/bin/apd module install "$TMPZ" 2>&1; _rc=$?
  elif command -v magisk >/dev/null 2>&1; then $T magisk --install-module "$TMPZ" 2>&1; _rc=$?
  else echo "ERR no root manager installer found (ksud / apd / magisk)"; fi
  rm -f "$TMPZ"
  return $_rc
}

case "$1" in
status)
  echo "mode=$(get_mode)"
  installed && echo "installed=1" || echo "installed=0"
  _vp="$MOD/module.prop"; [ -f "$_vp" ] || _vp="$ADB/modules_update/rezygisk/module.prop"
  echo "version=$(prop "$_vp" version)"
  running && echo "running=1" || echo "running=0"
  echo "leftover=$(leftovers | wc -l | tr -d ' ')"
  echo "bundled=$(cat "$RZ/BUNDLED_VERSION" 2>/dev/null)" ;;
on)
  set_mode on || { echo "ERR cannot save mode"; exit 1; }
  purge                      # always flash onto a clean slate
  do_install > "$STATE/rezygisk_install.log" 2>&1; R=$?
  tail -n 6 "$STATE/rezygisk_install.log"
  if [ "$R" = 0 ] || installed; then echo "OK flashed - reboot to start it"
  else set_mode off; purge; echo "ERR flashing failed (nothing was left behind)"; exit 1; fi ;;
off|remove)
  set_mode off || { echo "ERR cannot save mode"; exit 1; }
  purge
  L=$(leftovers)
  if [ -n "$L" ]; then echo "ERR could not delete: $L"; exit 1; fi
  if running; then echo "OK all ReZygisk files deleted - reboot to unload the copy still in memory"
  else echo "OK all ReZygisk files deleted"; fi ;;
*) echo "usage: rezygisk_ctl.sh status|on|off"; exit 1 ;;
esac
