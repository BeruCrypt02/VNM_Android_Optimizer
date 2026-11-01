#!/system/bin/sh
# ADB + fastboot HOST tools: flash / sideload / manage OTHER devices plugged into this phone over OTG.
#   flash_ctl.sh status                 -> adb= adbok= adbver= fastboot= fbok= fbver= datarole=
#   flash_ctl.sh import [dir]           -> copy adb + fastboot from storage into the persistent tools folder
#                                          (Termux "platform-tools" in /data/data/com.termux/files/usr/bin is used in place, no import needed)
#   flash_ctl.sh remove                 -> delete the imported tools
#   flash_ctl.sh usb                    -> ROLE|... and DEV|... lines (what the kernel sees on the USB port)
#   flash_ctl.sh devices                -> ADB|serial|state|info  and  FB|serial|mode
#   flash_ctl.sh files                  -> FILE|size|path of flashable files found in storage
#   flash_ctl.sh run <adb|fastboot> <serial|-> <args...>   -> background job (log + exit code)
#   flash_ctl.sh raw <adb|fastboot> <serial|-> "<line>"    -> same, free-form line (split on spaces)
#   flash_ctl.sh job                    -> running=0|1 / rc=<code> / --- / <log tail>
#   flash_ctl.sh cancel
#   flash_ctl.sh killserver

DIR=$(cd "${0%/*}" 2>/dev/null && pwd)
[ -n "$DIR" ] || DIR=${0%/*}
MOD=${DIR%/scripts}
STATE=/data/adb/spinel_toolkit
TOOLS=$STATE/tools
HOMEDIR=$STATE/adbhome
JOB=$STATE/flash_job

mkdir -p "$TOOLS" "$HOMEDIR/.android" 2>/dev/null

# Own adb server port + key store, so it never fights the phone's own adbd / another server
export HOME="$HOMEDIR"
export ANDROID_USER_HOME="$HOMEDIR/.android"
export ANDROID_SDK_HOME="$HOMEDIR"
export TMPDIR=/data/local/tmp
export ANDROID_ADB_SERVER_PORT=5038

# Termux (pkg/apt "platform-tools") keeps adb + fastboot here; they need Termux's libs
TERMUX_USR=/data/data/com.termux/files/usr
pfx() { case "$1" in "$TERMUX_USR"/*) echo "env LD_LIBRARY_PATH=$TERMUX_USR/lib" ;; esac; }

rd() { _v=""; [ -r "$1" ] && read -r _v < "$1" 2>/dev/null; echo "$_v"; }

# run with a time limit when `timeout` exists
to() {
    _t=$1; shift
    if command -v timeout >/dev/null 2>&1; then timeout "$_t" "$@"; else "$@"; fi
}

find_tool() {
    for _p in "$TOOLS/$1" "$MOD/tools/$1" "$TERMUX_USR/bin/$1" "/data/local/tmp/$1" "/system/xbin/$1" "/system/bin/$1" "/vendor/bin/$1"; do
        if [ -f "$_p" ]; then
            [ -x "$_p" ] || chmod 755 "$_p" 2>/dev/null
            [ -x "$_p" ] && { echo "$_p"; return 0; }
        fi
    done
    _p=$(command -v "$1" 2>/dev/null)
    [ -n "$_p" ] && [ -x "$_p" ] && { echo "$_p"; return 0; }
    return 1
}

tool_ver() {   # $1=path $2=adb|fastboot
    if [ "$2" = adb ]; then to 8 $(pfx "$1") "$1" version 2>&1 | head -n 2 | tr '\r\n' '  '
    else to 8 $(pfx "$1") "$1" --version 2>&1 | head -n 2 | tr '\r\n' '  '; fi
}

# ---- background job helpers -------------------------------------------------
job_alive() {
    [ -f "$JOB.pid" ] || return 1
    _jp=$(cat "$JOB.pid" 2>/dev/null)
    case "$_jp" in ''|*[!0-9]*) return 1 ;; esac
    [ ! -f "$JOB.rc" ] && kill -0 "$_jp" 2>/dev/null
}

job_start() {   # job_start <abs tool> args...
    if job_alive; then echo "ERR another job is still running"; return 1; fi
    : > "$JOB.log"; rm -f "$JOB.rc"
    {
        echo "\$ $*"
    } >> "$JOB.log"
    (
        $(pfx "$1") "$@" >> "$JOB.log" 2>&1 < /dev/null
        echo $? > "$JOB.rc"
    ) > /dev/null 2>&1 &
    echo $! > "$JOB.pid"
    echo "OK started"
}

resolve() {   # resolve <adb|fastboot> -> path or error
    case "$1" in adb|fastboot) ;; *) echo "ERR bad tool"; return 1 ;; esac
    T=$(find_tool "$1") || { echo "ERR $1 not installed (use Import tools)"; return 1; }
    return 0
}

case "$1" in
status)
    A=$(find_tool adb); F=$(find_tool fastboot)
    echo "adb=$A"
    if [ -n "$A" ]; then V=$(tool_ver "$A" adb); echo "adbver=$V"; case "$V" in *ersion*) echo "adbok=1" ;; *) echo "adbok=0" ;; esac; fi
    echo "fastboot=$F"
    if [ -n "$F" ]; then V=$(tool_ver "$F" fastboot); echo "fbver=$V"; case "$V" in *ersion*) echo "fbok=1" ;; *) echo "fbok=0" ;; esac; fi
    echo "datarole=$(rd /sys/class/typec/port0/data_role)"
    echo "toolsdir=$TOOLS"
    ;;

import)
    N=0; FAIL=0
    if [ -n "$2" ]; then DIRS="$2"; else DIRS="/sdcard/Download/spinel_tools /sdcard/Download/platform-tools /sdcard/Download /sdcard/spinel_tools /sdcard"; fi
    for NAME in adb fastboot; do
        SRC=""
        for D in $DIRS; do
            [ -d "$D" ] || continue
            if [ -f "$D/$NAME" ]; then SRC="$D/$NAME"; break; fi
            C=$(find "$D" -maxdepth 2 -type f -name "$NAME" 2>/dev/null | head -n 1)
            [ -n "$C" ] && { SRC="$C"; break; }
        done
        [ -n "$SRC" ] || { echo "MISS $NAME"; continue; }
        cp -f "$SRC" "$TOOLS/$NAME.new" 2>/dev/null && chmod 755 "$TOOLS/$NAME.new" && mv -f "$TOOLS/$NAME.new" "$TOOLS/$NAME" || { echo "ERR $NAME copy failed"; FAIL=1; continue; }
        V=$(tool_ver "$TOOLS/$NAME" "$NAME")
        case "$V" in
            *ersion*) echo "OK $NAME $SRC"; N=$((N+1)) ;;
            *) echo "ERR $NAME copied but will not run: $V"; FAIL=1 ;;
        esac
    done
    [ "$N" -gt 0 ] || [ "$FAIL" -eq 1 ] || echo "ERR nothing found - put the arm64 'adb' and 'fastboot' files in /sdcard/Download/spinel_tools/"
    ;;

remove)
    rm -f "$TOOLS/adb" "$TOOLS/fastboot"
    echo "OK removed"
    ;;

usb)
    sh "$DIR/otg_info.sh" 2>/dev/null | grep -E '^(ROLE|DEV)\|'
    ;;

devices)
    TMPO=/data/local/tmp/fl_dev.$$
    A=$(find_tool adb); F=$(find_tool fastboot)
    if [ -n "$A" ]; then
        # start the server fully detached first: a server forked inside a pipeline keeps the pipe open and hangs the WebUI
        to 10 $(pfx "$A") "$A" start-server >/dev/null 2>&1 </dev/null
        to 15 $(pfx "$A") "$A" devices -l > "$TMPO" 2>&1 </dev/null
        while read -r a b c; do
            case "$a" in ''|List|'*'|adb) continue ;; esac
            # a real line is "<serial> <state> ..."; log / error text ("[2026-.. ERROR ..") is not a device
            case "$a" in *[!A-Za-z0-9._:-]*) continue ;; esac
            case "$b" in device|offline|unauthorized|recovery|sideload|rescue|bootloader|authorizing|connecting|host|no) ;; *) continue ;; esac
            echo "ADB|$a|$b|$c"
        done < "$TMPO"
    fi
    if [ -n "$F" ]; then
        to 8 $(pfx "$F") "$F" devices > "$TMPO" 2>&1 </dev/null
        while read -r a b c; do
            case "$a" in ''|'<'*|'*'|fastboot) continue ;; esac
            # a real line is "<serial>  fastboot"; anything else (e.g. "[2026-.. ERROR ..") is fastboot's own log text
            case "$a" in *[!A-Za-z0-9._:-]*) continue ;; esac
            case "$b" in fastboot|fastbootd|bootloader) ;; *) continue ;; esac
            echo "FB|$a|$b"
        done < "$TMPO"
    fi
    rm -f "$TMPO"
    ;;

files)
    for D in /sdcard/Download /sdcard/Spinel_Flash /sdcard/spinel_tools /sdcard/Download/spinel_tools; do
        [ -d "$D" ] || continue
        find "$D" -maxdepth 2 -type f \( -name '*.img' -o -name '*.zip' -o -name '*.bin' -o -name '*.apk' -o -name '*.mbn' -o -name '*.elf' \) 2>/dev/null | while IFS= read -r f; do
            sz=$(wc -c < "$f" 2>/dev/null | tr -d ' ')
            echo "FILE|$sz|$f"
        done
    done | sort -u -t'|' -k3,3 | head -n 80
    ;;

run)
    resolve "$2" || exit 1
    TOOLNAME=$2; SER=$3; shift 3
    if [ "$SER" != "-" ] && [ -n "$SER" ]; then
        case "$SER" in *[!A-Za-z0-9._:-]*) echo "ERR bad serial"; exit 1 ;; esac
        job_start "$T" -s "$SER" "$@"
    else
        job_start "$T" "$@"
    fi
    ;;

raw)
    resolve "$2" || exit 1
    TOOLNAME=$2; SER=$3; LINE=$4
    [ -n "$LINE" ] || { echo "ERR empty command"; exit 1; }
    set -f
    # shellcheck disable=SC2086
    set -- $LINE
    # drop a leading tool name if the user typed it
    case "$1" in adb|fastboot) shift ;; esac
    if [ "$SER" != "-" ] && [ -n "$SER" ]; then
        case "$SER" in *[!A-Za-z0-9._:-]*) echo "ERR bad serial"; exit 1 ;; esac
        job_start "$T" -s "$SER" "$@"
    else
        job_start "$T" "$@"
    fi
    ;;

job)
    if job_alive; then echo "running=1"; else echo "running=0"; fi
    echo "rc=$(cat "$JOB.rc" 2>/dev/null)"
    echo "---"
    tail -n 400 "$JOB.log" 2>/dev/null
    ;;

cancel)
    if job_alive; then
        _jp=$(cat "$JOB.pid" 2>/dev/null)
        pkill -P "$_jp" 2>/dev/null
        kill "$_jp" 2>/dev/null
        sleep 0.3
        pkill -9 -P "$_jp" 2>/dev/null
        echo 130 > "$JOB.rc"
        echo "[cancelled]" >> "$JOB.log"
        echo "OK cancelled"
    else
        echo "OK nothing running"
    fi
    ;;

killserver)
    A=$(find_tool adb)
    [ -n "$A" ] && to 8 $(pfx "$A") "$A" kill-server >/dev/null 2>&1
    echo "OK"
    ;;

*)
    echo "usage: flash_ctl.sh status|import|remove|usb|devices|files|run|raw|job|cancel|killserver"
    exit 1
    ;;
esac
