#!/system/bin/sh
# Shared adb host environment (same server/keys as flash_ctl.sh). Source it: . adbenv.sh
DIR=$(cd "${0%/*}" 2>/dev/null && pwd); [ -n "$DIR" ] || DIR=${0%/*}
MOD=${DIR%/scripts}
STATE=/data/adb/spinel_toolkit
TOOLS=$STATE/tools
HOMEDIR=$STATE/adbhome
mkdir -p "$TOOLS" "$HOMEDIR/.android" 2>/dev/null
export HOME="$HOMEDIR" ANDROID_USER_HOME="$HOMEDIR/.android" ANDROID_SDK_HOME="$HOMEDIR" TMPDIR=/data/local/tmp ANDROID_ADB_SERVER_PORT=5038
TERMUX_USR=/data/data/com.termux/files/usr
pfx() { case "$1" in "$TERMUX_USR"/*) echo "env LD_LIBRARY_PATH=$TERMUX_USR/lib" ;; esac; }
to() { _t=$1; shift; if command -v timeout >/dev/null 2>&1; then timeout "$_t" "$@"; else "$@"; fi; }
find_tool() {
  for _p in "$TOOLS/$1" "$MOD/tools/$1" "$TERMUX_USR/bin/$1" "/data/local/tmp/$1" "/system/xbin/$1" "/system/bin/$1" "/vendor/bin/$1"; do
    [ -f "$_p" ] && { [ -x "$_p" ] || chmod 755 "$_p" 2>/dev/null; [ -x "$_p" ] && { echo "$_p"; return 0; }; }
  done
  _p=$(command -v "$1" 2>/dev/null); [ -n "$_p" ] && { echo "$_p"; return 0; }; return 1
}
ADB=$(find_tool adb)
okser() { case "$1" in ''|*[!A-Za-z0-9._:-]*) echo "ERR bad serial"; exit 1 ;; esac; }
# A <serial> args...  -> run adb against the target
A() { _s=$1; shift; to 15 $(pfx "$ADB") "$ADB" -s "$_s" "$@"; }
# start the adb server detached so it never keeps the caller's pipe open (that would hang the WebUI)
[ -n "$ADB" ] || { echo "ERR adb not installed (Flash tab -> Import tools)"; exit 1; }
to 10 $(pfx "$ADB") "$ADB" start-server >/dev/null 2>&1 </dev/null
