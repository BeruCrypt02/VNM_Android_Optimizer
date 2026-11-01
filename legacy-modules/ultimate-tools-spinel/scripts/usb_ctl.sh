#!/system/bin/sh
# Background job runner for the USB tab. The WebUI never waits on adb:
#   usb_ctl.sh start <flash_ctl.sh|states_ctl.sh|manage_ctl.sh|mouse_ctl.sh> <args...>  -> "OK <id>" immediately
#   usb_ctl.sh poll <id>   -> state=running|done / --- / output
#   usb_ctl.sh clean
case "$0" in */*) DIR=$(cd "${0%/*}" 2>/dev/null && pwd) ;; *) DIR=$(pwd) ;; esac
ST=/data/adb/spinel_toolkit/usbjobs; mkdir -p "$ST" 2>/dev/null
case "$1" in
start)
  shift; S=$1; shift
  case "$S" in flash_ctl.sh|states_ctl.sh|manage_ctl.sh|mouse_ctl.sh) ;; *) echo "ERR script not allowed"; exit 1 ;; esac
  # only 'devices' may be run from flash_ctl here
  [ "$S" = flash_ctl.sh ] && [ "$1" != devices ] && { echo "ERR not allowed"; exit 1; }
  find "$ST" -type f -mmin +30 -exec rm -f {} \; 2>/dev/null
  ID="$(date +%s)$$"
  OUT="$ST/$ID.out"
  (
    if command -v timeout >/dev/null 2>&1; then timeout 700 sh "$DIR/$S" "$@" > "$OUT.tmp" 2>&1 < /dev/null
    else sh "$DIR/$S" "$@" > "$OUT.tmp" 2>&1 < /dev/null; fi
    mv -f "$OUT.tmp" "$OUT"
  ) > /dev/null 2>&1 < /dev/null &
  echo "OK $ID" ;;
poll)
  ID=$2; case "$ID" in ''|*[!0-9]*) echo "state=error"; exit 1 ;; esac
  if [ -f "$ST/$ID.out" ]; then echo "state=done"; echo "---"; head -c 200000 "$ST/$ID.out"
  else echo "state=running"; fi ;;
clean) rm -rf "$ST"; echo OK ;;
*) echo "usage: usb_ctl.sh start|poll|clean"; exit 1 ;;
esac
