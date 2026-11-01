#!/system/bin/sh
# SELinux mode switch (Device tab).
#   selinux_ctl.sh status              -> mode=enforcing|permissive|disabled saved=enforcing|permissive|none
#   selinux_ctl.sh enforcing|permissive -> applies right now, verified by reading it back, and remembered for the next boot
#   selinux_ctl.sh boot                -> boot service: re-applies the remembered choice (nothing happens if you never switched)
STATE=${SPINEL_STATE:-/data/adb/mkvp_tools}; MODEF=$STATE/selinux_mode
mkdir -p "$STATE" 2>/dev/null
cur() { getenforce 2>/dev/null | tr 'A-Z' 'a-z' | tr -d ' \r\n'; }
saved() { _s=$(cat "$MODEF" 2>/dev/null | tr -d ' \r\n\t'); case "$_s" in enforcing|permissive) echo "$_s" ;; *) echo none ;; esac; }
apply() { # enforcing|permissive -> 0 ok
  case "$1" in enforcing) _v=1 ;; permissive) _v=0 ;; *) return 2 ;; esac
  [ "$(cur)" = "$1" ] && return 0
  _e=$( { setenforce "$_v"; } 2>&1 ) || ERRT=$_e
  [ "$(cur)" = "$1" ]
}
case "$1" in
status) echo "mode=$(cur)"; echo "saved=$(saved)" ;;
enforcing|permissive)
  if apply "$1"; then
    echo "$1" > "$MODEF.tmp" && mv -f "$MODEF.tmp" "$MODEF"
    echo "OK $1"
  else
    echo "ERR the kernel refused: SELinux is still $(cur)${ERRT:+ ($ERRT)}"; exit 1
  fi ;;
boot)
  S=$(saved); [ "$S" = none ] && exit 0
  until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 3; done
  apply "$S" ;;
*) echo "usage: selinux_ctl.sh status|enforcing|permissive|boot"; exit 1 ;;
esac
