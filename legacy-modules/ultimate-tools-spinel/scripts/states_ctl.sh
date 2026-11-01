#!/system/bin/sh
# Info + screenshots of the phone plugged into OTG (adb).
#   states_ctl.sh info <serial>   -> KEY=value lines (ONE adb call)
#   states_ctl.sh shot <serial>   -> OK <file>
#   states_ctl.sh preview <serial> -> OK  (live view for the Touchpad tab: webroot/shots/live.png only, nothing saved to /sdcard)
#   states_ctl.sh local           -> ROM info of THIS phone (no adb needed)
D0=${0%/*}
if [ "$1" = local ]; then getprop | sh "$D0/rom_detect.sh"; exit 0; fi
. "$D0/adbenv.sh"
T=/data/local/tmp/tgt
case "$1" in
info)
  okser "$2"; S=$2
  A "$S" shell 'getprop; echo "@@BAT"; dumpsys battery; echo "@@MEM"; grep -E "MemTotal|MemAvailable" /proc/meminfo; echo "@@DF"; df /data | tail -n 1; echo "@@WM"; wm size; wm density; echo "@@UP"; uptime -p; echo "@@ROOT"; (su -c id 2>/dev/null | head -c 30)' 2>/dev/null | tr -d '\r' > $T.all
  [ -s $T.all ] || { echo "ERR no answer (USB debugging ON? key accepted? screen unlocked?)"; exit 1; }
  awk -v b=$T '/^@@/{f=b"."substr($0,3);next}{print > (f?f:b".props")}' $T.all
  sh "$D0/rom_detect.sh" < $T.props
  g() { sed -n "s/^\[$1\]: \[\(.*\)\]$/\1/p" $T.props | head -n 1; }
  echo "BRAND=$(g ro.product.brand)"; echo "MODEL=$(g ro.product.model)"; echo "DEVICE=$(g ro.product.device)"
  echo "SOC=$(g ro.soc.model) $(g ro.board.platform)"
  echo "ABI=$(g ro.product.cpu.abi)"; echo "SERIAL=$S"
  echo "BOOTLOADER=$(g ro.boot.verifiedbootstate)"; echo "SLOT=$(g ro.boot.slot_suffix)"
  echo "ROOT=$(cat $T.ROOT 2>/dev/null)"
  echo "BAT=$(sed -n 's/^ *level: //p' $T.BAT 2>/dev/null)"
  echo "BATTEMP=$(sed -n 's/^ *temperature: //p' $T.BAT 2>/dev/null)"
  echo "CHG=$(grep -qE 'AC powered: true|USB powered: true|Wireless powered: true' $T.BAT 2>/dev/null && echo yes || echo no)"
  echo "RAM=$(awk '{printf "%s ", $2}' $T.MEM 2>/dev/null)"
  echo "DF=$(awk '{print $2" "$3" "$4}' $T.DF 2>/dev/null)"
  echo "SIZE=$(grep -i 'size' $T.WM 2>/dev/null | tail -n 1 | sed 's/.*: //')"
  echo "DENSITY=$(grep -i 'density' $T.WM 2>/dev/null | tail -n 1 | sed 's/.*: //')"
  echo "UPTIME=$(cat $T.UP 2>/dev/null)"
  rm -f $T.* 2>/dev/null
  ;;
shot)
  okser "$2"; S=$2
  D=/sdcard/Pictures/Spinel_Screenshots; mkdir -p "$D" "$MOD/webroot/shots" 2>/dev/null
  F="$D/shot_$(date +%Y%m%d_%H%M%S).png"
  to 25 $(pfx "$ADB") "$ADB" -s "$S" exec-out screencap -p > "$F.tmp" 2>/dev/null </dev/null
  if [ -s "$F.tmp" ] && head -c 4 "$F.tmp" | grep -q PNG; then
    mv -f "$F.tmp" "$F"; cp -f "$F" "$MOD/webroot/shots/last.png" 2>/dev/null
    echo "OK $F"
  else rm -f "$F.tmp"; echo "ERR screencap failed (screen locked / device not authorised?)"; fi
  ;;
preview)
  okser "$2"; S=$2
  mkdir -p "$MOD/webroot/shots" 2>/dev/null
  F="$MOD/webroot/shots/live"
  to 12 $(pfx "$ADB") "$ADB" -s "$S" exec-out screencap -p > "$F.tmp" 2>/dev/null </dev/null
  if [ -s "$F.tmp" ] && head -c 4 "$F.tmp" | grep -q PNG; then mv -f "$F.tmp" "$F.png"; echo OK
  else rm -f "$F.tmp"; echo "ERR screencap failed (screen off / locked, or phone not authorised)"; fi
  ;;
*) echo "usage: states_ctl.sh info|shot|preview <serial>|local"; exit 1 ;;
esac
