#!/system/bin/sh
# Browse / transfer files of the phone plugged into OTG (adb).
#   manage_ctl.sh ls <serial> <path>      -> D|name  / F|name|size
#   manage_ctl.sh pull <serial> <remote>  -> OK  (to /sdcard/Download/OTG_Pulled)   [synchronous, 10 min cap]
#   manage_ctl.sh push <serial> <local> <remotedir>
#   manage_ctl.sh rm|mkdir <serial> <remote>
. "${0%/*}/adbenv.sh"
okser "$2"; S=$2; CMD=$1; P=$3
case "$P" in *\'*|*\"*|*\`*|*\$*|*\;*|*\&*|*\|*|*\\*|*\<*|*\>*) echo "ERR bad characters in path"; exit 1 ;; esac
case "$CMD" in
ls)
  [ -n "$P" ] || P=/sdcard
  A "$S" shell "cd '$P' 2>/dev/null && ls -1Ap" 2>/dev/null | tr -d '\r' | head -n 3000 | while IFS= read -r n; do
    [ -n "$n" ] || continue
    case "$n" in */) echo "D|${n%/}" ;; *) echo "F|$n" ;; esac
  done ;;
pull)
  O=/sdcard/Download/OTG_Pulled; mkdir -p "$O"
  to 600 sh -c "$(pfx "$ADB") \"$ADB\" -s \"$S\" pull \"$P\" \"$O/\"" 2>&1 | tail -n 3; echo "OK -> $O" ;;
push)
  [ -e "$P" ] || { echo "ERR local file missing"; exit 1; }
  case "$4" in *\'*|*\"*|*\`*|*\$*|*\;*|*\&*|*\|*) echo "ERR bad destination"; exit 1 ;; esac
  to 600 sh -c "$(pfx "$ADB") \"$ADB\" -s \"$S\" push \"$P\" \"$4/\"" 2>&1 | tail -n 3 ;;
rm)
  case "$P" in ''|/|/sdcard|/sdcard/|/storage*|/data|/system*) echo "ERR refusing that path"; exit 1 ;; esac
  A "$S" shell "rm -rf '$P'" 2>&1; echo "OK" ;;
mkdir)
  A "$S" shell "mkdir -p '$P'" 2>&1; echo "OK" ;;
*) echo "usage: manage_ctl.sh ls|pull|push|rm|mkdir"; exit 1 ;;
esac
