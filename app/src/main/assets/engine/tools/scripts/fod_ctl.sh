#!/system/bin/sh
# FOD fix on/off, saved and applied right away (full revert of the boot-time parts after a reboot).
#   fod_ctl.sh status -> mode=on|off / running=0|1 (fingerprint watcher) / overlay=<state>
#   fod_ctl.sh on | off
DIR=$(cd "${0%/*}" 2>/dev/null && pwd); [ -n "$DIR" ] || DIR=${0%/*}
FOD=${DIR%/scripts}/fod
STATE=/data/adb/mkvp_tools; MODEF=$STATE/fod_mode
OVL=com.spinel.fod.overlay
mkdir -p "$STATE" 2>/dev/null
get_mode() { _m=$(cat "$MODEF" 2>/dev/null | tr -d ' \r\n\t'); [ "$_m" = "off" ] && echo off || echo on; }
set_mode() { echo "$1" > "$MODEF.tmp" && mv -f "$MODEF.tmp" "$MODEF"; }
watcher_up() { ps -A -o ARGS 2>/dev/null | grep -v grep | grep -qF "fod/fpwatch.sh"; }
ovl_state() { cmd overlay list --user 0 2>/dev/null | grep -F "$OVL" | head -n 1 | tr -d '\r'; }
case "$1" in
status)
  echo "mode=$(get_mode)"
  watcher_up && echo "running=1" || echo "running=0"
  echo "overlay=$(ovl_state)" ;;
on)
  set_mode on || { echo "ERR cannot save mode"; exit 1; }
  pkill -f "fod/service.sh" 2>/dev/null
  # service.sh redoes everything (node, sensor props, fpwatch, overlay enable); it waits a few seconds first
  nohup sh "$FOD/service.sh" >/dev/null 2>&1 </dev/null &
  cmd overlay enable --user 0 "$OVL" >/dev/null 2>&1
  echo "OK starting" ;;
off)
  set_mode off || { echo "ERR cannot save mode"; exit 1; }
  pkill -f "fod/service.sh" 2>/dev/null
  pkill -f "fod/fpwatch.sh" 2>/dev/null
  [ -x "$FOD/bin/fodctl" ] && "$FOD/bin/fodctl" 10 0 >/dev/null 2>&1
  cmd overlay disable --user 0 "$OVL" >/dev/null 2>&1
  watcher_up && { echo "ERR watcher still running"; exit 1; }
  echo "OK stopped" ;;
*) echo "usage: fod_ctl.sh status|on|off"; exit 1 ;;
esac
