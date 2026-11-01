#!/system/bin/sh
# Fast-charge fix: removes the charge throttle (battery/charge_control_limit -> 0) and keeps it there.
#   charge_ctl.sh status -> mode=on|off  running=0|1  limit=<now>  temp=<tenths C>  watts=<approx>
#   charge_ctl.sh on     -> saved, daemon started right away, started again after every boot
#   charge_ctl.sh off    -> saved, daemon stopped, original throttle value put back, NOT applied on next boot
#   charge_ctl.sh boot   -> boot service: starts the daemon unless the switch is OFF (default ON)
#   charge_ctl.sh daemon -> internal loop
# Safety: the limit is only forced while the battery is below 42.0 C; above that the system's own value is restored.
DIR=$(cd "${0%/*}" 2>/dev/null && pwd); [ -n "$DIR" ] || DIR=${0%/*}
STATE=/data/adb/spinel_toolkit; MODEF=$STATE/charge_mode; ORIG=$STATE/charge_orig; PIDF=$STATE/charge.pid
PS=/sys/class/power_supply
NODE=$PS/battery/charge_control_limit
TEMP=$PS/battery/temp
MAXT=420
mkdir -p "$STATE" 2>/dev/null
get_mode() { _m=$(cat "$MODEF" 2>/dev/null | tr -d ' \r\n\t'); [ "$_m" = "off" ] && echo off || echo on; }
set_mode() { echo "$1" > "$MODEF.tmp" && mv -f "$MODEF.tmp" "$MODEF"; }
alive() { _p=$(cat "$PIDF" 2>/dev/null | tr -d ' \r\n\t'); case "$_p" in ''|*[!0-9]*) return 1 ;; esac; kill -0 "$_p" 2>/dev/null && grep -q "charge_ctl" "/proc/$_p/cmdline" 2>/dev/null; }
stop_daemon() {
  _p=$(cat "$PIDF" 2>/dev/null | tr -d ' \r\n\t')
  case "$_p" in ''|*[!0-9]*) ;; *) kill "$_p" 2>/dev/null ;; esac
  rm -f "$PIDF"
}
start_daemon() {
  alive && return 0
  nohup sh "$DIR/charge_ctl.sh" daemon >/dev/null 2>&1 </dev/null &
}
case "$1" in
status)
  echo "mode=$(get_mode)"
  alive && echo "running=1" || echo "running=0"
  echo "limit=$(cat "$NODE" 2>/dev/null)"
  echo "temp=$(cat "$TEMP" 2>/dev/null)"
  V=$(cat $PS/usb/voltage_now 2>/dev/null); I=$(cat $PS/sc-cp-master/current_now 2>/dev/null)
  case "$V$I" in *[!0-9]*|'') ;; *)
    # charge-pump input: usb voltage (mV) * charge-pump current (mA) / 1e6 = W
    [ "$V" -gt 100 ] 2>/dev/null && echo "watts=$(( V * I / 1000000 ))" ;; esac ;;
on)
  [ -w "$NODE" ] || { echo "ERR $NODE not found or not writable"; exit 1; }
  set_mode on || { echo "ERR cannot save mode"; exit 1; }
  start_daemon
  sleep 2
  alive && echo "OK running" || { echo "ERR daemon did not start"; exit 1; } ;;
off)
  set_mode off || { echo "ERR cannot save mode"; exit 1; }
  stop_daemon
  sleep 1
  O=$(cat "$ORIG" 2>/dev/null | tr -d ' \r\n\t')
  case "$O" in ''|*[!0-9]*) O=8 ;; esac
  [ -w "$NODE" ] && echo "$O" > "$NODE" 2>/dev/null
  alive && { echo "ERR daemon still running"; exit 1; }
  echo "OK stopped" ;;
boot)
  [ "$(get_mode)" = "off" ] && exit 0
  start_daemon ;;
daemon)
  alive && exit 0
  echo $$ > "$PIDF"
  until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 3; done
  # remember the system's own value once (only if it is not already our forced 0)
  if [ ! -s "$ORIG" ]; then
    c=$(cat "$NODE" 2>/dev/null | tr -d ' \r\n\t')
    case "$c" in ''|*[!0-9]*|0) ;; *) echo "$c" > "$ORIG" ;; esac
  fi
  while [ "$(cat "$MODEF" 2>/dev/null | tr -d ' \r\n\t')" != "off" ]; do
    t=$(cat "$TEMP" 2>/dev/null | tr -d ' \r\n\t')
    case "$t" in ''|*[!0-9-]*) t=0 ;; esac
    if [ "$t" -lt "$MAXT" ]; then
      [ "$(cat "$NODE" 2>/dev/null | tr -d ' \r\n\t')" != "0" ] && echo 0 > "$NODE" 2>/dev/null
    else
      O=$(cat "$ORIG" 2>/dev/null | tr -d ' \r\n\t'); case "$O" in ''|*[!0-9]*) O=8 ;; esac
      echo "$O" > "$NODE" 2>/dev/null
    fi
    sleep 1
  done
  rm -f "$PIDF" ;;
*) echo "usage: charge_ctl.sh status|on|off|boot"; exit 1 ;;
esac
