#!/system/bin/sh
# Touchpad tab controller: this phone as an ADB pointer for the phone plugged into its OTG port.
#   mouse_ctl.sh start adb <serial>  open one persistent adb shell on the other phone (it stays the OTG device)
#   mouse_ctl.sh stop                stop the session
#   mouse_ctl.sh status              key=value, fast, never touches adb
case "$0" in */*) D0=$(cd "${0%/*}" 2>/dev/null && pwd) ;; *) D0=$(pwd) ;; esac
SYS=${SYSFS:-/sys}
ST=${SPINEL_STATE:-/data/adb/mkvp_tools}
TC=$SYS/class/typec/port0
FIFO=$ST/mouse.fifo; PIDF=$ST/mouse.pid; CHF=$ST/mouse.child; LOGF=$ST/mouse.log; OUTF=$ST/mouse.out; MODEF=$ST/mouse.mode
mkdir -p "$ST" 2>/dev/null

rd() { _v=""; [ -r "$1" ] && read -r _v < "$1" 2>/dev/null; echo "$_v"; }
say() { echo "$*"; }
alive() { _p=$(cat "$PIDF" 2>/dev/null); case "$_p" in ''|*[!0-9]*) return 1 ;; esac; [ -d "/proc/$_p" ]; }
kill_pid_file() { # file, cmdline-pattern
  _p=$(cat "$1" 2>/dev/null)
  case "$_p" in ''|*[!0-9]*) ;; *)
    if grep -q "$2" "/proc/$_p/cmdline" 2>/dev/null; then kill "$_p" 2>/dev/null; sleep 0.3; kill -9 "$_p" 2>/dev/null; fi ;;
  esac
  rm -f "$1"
}
stop_daemon() { kill_pid_file "$PIDF" mouse_daemon; kill_pid_file "$CHF" adb; rm -f "$FIFO"; }

# ---------------------------------------------------------------- shared
launch_daemon() { # mode arg
  : > "$LOGF"; : > "$OUTF"; echo "$1" > "$MODEF"
  if command -v setsid >/dev/null 2>&1; then setsid sh "$D0/mouse_daemon.sh" "$1" "$2" </dev/null >/dev/null 2>&1 &
  else nohup sh "$D0/mouse_daemon.sh" "$1" "$2" </dev/null >/dev/null 2>&1 & fi
}
wait_log() { # seconds -> 0 when READY, 1 on FAIL/timeout/dead
  _n=$(( $1 * 5 )); _i=0
  while [ $_i -lt $_n ]; do
    grep -q '^READY' "$LOGF" 2>/dev/null && return 0
    grep -q '^FAIL' "$LOGF" 2>/dev/null && return 1
    sleep 0.2; _i=$((_i+1))
  done
  return 1
}

start_adb() {
  SER=$1
  case "$SER" in ''|*[!A-Za-z0-9._:-]*) say "ERR bad serial"; exit 1 ;; esac
  stop_daemon
  . "$D0/adbenv.sh"       # ERR + exit when adb is not installed
  say "== ADB pointer =="
  GS=$(to 10 $(pfx "$ADB") "$ADB" -s "$SER" get-state 2>&1 </dev/null | tr -d '\r' | tail -n 1)
  say "adb state: $GS"
  [ "$GS" = device ] || { say "ERR the phone is not in 'device' state (USB debugging ON? accept the key on it, unlock it)."; exit 1; }
  launch_daemon adb "$SER"
  i=0; OK=0
  while [ $i -lt 40 ]; do
    grep -q '@@READY' "$OUTF" 2>/dev/null && { OK=1; break; }
    alive || break
    sleep 0.3; i=$((i+1))
  done
  if [ "$OK" != 1 ]; then say "ERR no answer from the shell on the other phone"; tail -n 4 "$OUTF" 2>/dev/null; stop_daemon; exit 1; fi
  say "$(grep -m1 '@@READY' "$OUTF" | sed 's/@@READY //')"
  # prove that input injection is allowed (Xiaomi needs "USB debugging (Security settings)")
  : > "$ST/mouse.probe"
  printf '%s\n' 'input keyevent 0' > "$FIFO"
  sleep 2.5
  if tail -n 8 "$OUTF" 2>/dev/null | grep -qiE 'SecurityException|INJECT_EVENTS|permission'; then
    say "WARN the other phone refuses injected input. Enable Developer options > 'USB debugging (Security settings)' (Xiaomi/HyperOS) and try again."
    say "RESULT=denied"
  else
    say "RESULT=ok"; say "OK pointer session open"
  fi
}

case "$1" in
start)
  case "$2" in
    adb) start_adb "$3" ;;
    *) echo "usage: mouse_ctl.sh start adb <serial>"; exit 1 ;;
  esac ;;
stop)
  stop_daemon; echo none > "$MODEF"
  echo "OK stopped" ;;
status)
  MODE=$(cat "$MODEF" 2>/dev/null); [ -n "$MODE" ] || MODE=none
  A=0; alive && A=1
  R=0; echo "mode=$MODE"; echo "alive=$A"
  if [ "$A" = 1 ]; then
    case "$MODE" in
      adb) if grep -q '@@READY' "$OUTF" 2>/dev/null; then
             R=1; L=$(grep -m1 '@@READY' "$OUTF")
             echo "sdk=$(echo "$L" | sed -n 's/.*sdk=\([0-9]*\).*/\1/p')"
             echo "size=$(echo "$L" | sed -n 's/.*size=.*: *\([0-9]*x[0-9]*\).*/\1/p')"
           fi ;;
    esac
  fi
  echo "ready=$R"
  echo "role=$(rd "$TC/data_role")"
  echo "log=$(tail -n 1 "$LOGF" 2>/dev/null | tr -d '|\r')"
  echo "out=$(grep -v '@@READY' "$OUTF" 2>/dev/null | tail -n 3 | tr '\n\r' '  ' | head -c 300)"
  ;;
*) echo "usage: mouse_ctl.sh start|stop|status"; exit 1 ;;
esac
