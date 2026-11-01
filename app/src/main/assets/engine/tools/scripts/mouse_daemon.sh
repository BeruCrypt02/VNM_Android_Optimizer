#!/system/bin/sh
# Background worker of the Touchpad tab. Started by mouse_ctl.sh, never by hand.
#   mouse_daemon.sh adb <serial>        keep ONE adb shell open on the other phone and feed it lines
# The WebUI only ever appends a line to the FIFO (instant, never waits on adb or USB).
D0=${0%/*}
ST=${SPINEL_STATE:-/data/adb/mkvp_tools}
FIFO=$ST/mouse.fifo; PIDF=$ST/mouse.pid; CHF=$ST/mouse.child; LOGF=$ST/mouse.log; OUTF=$ST/mouse.out
MODE=$1; ARG=$2
log() { echo "$*" >> "$LOGF"; }

echo $$ > "$PIDF"
rm -f "$FIFO"
mkfifo "$FIFO" 2>/dev/null || { log "FAIL cannot create $FIFO"; exit 1; }
# open the FIFO read+write and keep it open: readers then never see EOF between two WebUI writes
exec 3<>"$FIFO"

case "$MODE" in
adb)
  exec >> "$OUTF" 2>&1
  . "$D0/adbenv.sh"        # sets $ADB + env, or prints ERR and exits
  okser "$ARG"
  log "STATE connecting $ARG"
  trap 'kill "$CH" 2>/dev/null; exit 0' TERM INT HUP
  # ONE persistent shell on the other phone; every later line from the FIFO is executed by it
  $(pfx "$ADB") "$ADB" -s "$ARG" shell 'echo "@@READY sdk=$(getprop ro.build.version.sdk) size=$(wm size 2>/dev/null | tail -n 1)"; exec sh' <&3 &
  CH=$!; echo "$CH" > "$CHF"
  wait "$CH"; RC=$?
  log "END adb rc=$RC"
  ;;
*) log "FAIL bad mode"; exit 1 ;;
esac
