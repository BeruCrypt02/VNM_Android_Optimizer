#!/system/bin/sh
# MiTool (MiForge) installer/launcher using Termux's own bash/curl.
#   mitool_ctl.sh status | install | run "<args>" | send "<text>" | stop | log
# install/run get a real stdin (a FIFO), so menu choices typed in the WebUI reach the tool via "send".
URL="https://raw.githubusercontent.com/MiForge/MiTool/main/install.sh"
TU=/data/data/com.termux/files/usr; TH=/data/data/com.termux/files/home
ST=/data/adb/mkvp_tools; LOGF=$ST/mitool.log; INF=$ST/mitool.in; mkdir -p "$ST"
tenv() { env -i HOME="$TH" PREFIX="$TU" PATH="$TU/bin:/system/bin:/system/xbin" LD_LIBRARY_PATH="$TU/lib" TMPDIR="$TU/tmp" TERM=xterm "$@"; }
findbin() { for n in mitool MiTool; do for d in "$TU/bin" "$TH/.local/bin" "$TH/MiTool" "$TH/.mitool" /data/local/tmp; do [ -x "$d/$n" ] && { echo "$d/$n"; return 0; }; done; done; return 1; }
isrun() { [ -f $ST/mitool.pid ] && kill -0 "$(cat $ST/mitool.pid)" 2>/dev/null; }
newin() { rm -f "$INF"; mkfifo "$INF" 2>/dev/null; chmod 600 "$INF" 2>/dev/null; }
case "$1" in
status)
  [ -x "$TU/bin/bash" ] && echo "termux=1" || echo "termux=0"
  B=$(findbin); echo "bin=$B"; echo "running=$([ -f $ST/mitool.pid ] && kill -0 $(cat $ST/mitool.pid) 2>/dev/null && echo 1 || echo 0)" ;;
install)
  [ -x "$TU/bin/bash" ] || { echo "ERR Termux not found (bash missing) - install Termux first, or run the curl line inside Termux yourself"; exit 1; }
  [ -x "$TU/bin/curl" ] || { echo "ERR curl missing in Termux: run 'pkg install curl' there"; exit 1; }
  isrun && { echo "ERR MiTool is already running - Stop it first"; exit 1; }
  newin
  ( exec 3<>"$INF"; tenv sh -c "curl -sS $URL | bash" > "$LOGF" 2>&1 <&3; echo "[exit $?]" >> "$LOGF"; rm -f "$INF" ) >/dev/null 2>&1 &
  echo $! > $ST/mitool.pid; echo "OK started" ;;
run)
  B=$(findbin) || { echo "ERR MiTool not found - install it first"; exit 1; }
  isrun && { echo "ERR MiTool is already running - Stop it first"; exit 1; }
  shift; newin
  ( exec 3<>"$INF"; tenv sh -c "'$B' $*" > "$LOGF" 2>&1 <&3; echo "[exit $?]" >> "$LOGF"; rm -f "$INF" ) >/dev/null 2>&1 &
  echo $! > $ST/mitool.pid; echo "OK started" ;;
send)
  isrun && [ -p "$INF" ] || { echo "ERR MiTool is not running"; exit 1; }
  shift; printf '%s\n' "$*" > "$INF"; echo "OK sent" ;;
stop)
  if [ -f $ST/mitool.pid ]; then
    P=$(cat $ST/mitool.pid); pkill -P "$P" 2>/dev/null; kill "$P" 2>/dev/null; rm -f $ST/mitool.pid "$INF"
  fi
  echo "OK stopped" ;;
log) tail -n 200 "$LOGF" 2>/dev/null ;;
*) echo "usage: mitool_ctl.sh status|install|run|send|stop|log"; exit 1 ;;
esac
