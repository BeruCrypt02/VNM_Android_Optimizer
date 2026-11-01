#!/system/bin/sh
# MkVenomPro engine boot dispatcher.
# Replaces the Magisk / KernelSU / APatch *module* loader: the app installs the engine into its own
# folder (/data/adb/mkvp/engine) and this script is started at boot by
#   - /data/adb/post-fs-data.d/mkvp_engine.sh  (stage: post-fs-data)
#   - /data/adb/service.d/mkvp_engine.sh       (stage: service)
#   - the app's own BOOT_COMPLETED receiver     (stage: late = both, whatever did not run yet)
# usage: boot.sh post-fs-data | service | late
ENG=${0%/*}
case "$ENG" in /*) ;; *) ENG=$(cd "$ENG" 2>/dev/null && pwd) ;; esac
export PATH=/system/bin:/system/xbin:/vendor/bin:/data/adb/ksu/bin:/data/adb/ap/bin:/data/adb/magisk:$PATH
BASE=/data/adb/mkvp
LOG=$BASE/boot.log

[ -f "$BASE/disable" ] && exit 0

log() {
  echo "$(date '+%F %T') [$1] $2" >> "$LOG" 2>/dev/null
  if [ "$(wc -l < "$LOG" 2>/dev/null)" -gt 400 ] 2>/dev/null; then
    tail -n 200 "$LOG" > "$LOG.tmp" 2>/dev/null && mv -f "$LOG.tmp" "$LOG"
  fi
}

# ---- SELinux rules (what sepolicy.rule does for a module) ----
apply_sepolicy() {
  R="$ENG/tools/sepolicy.rule"; [ -f "$R" ] || return 0
  if command -v magiskpolicy >/dev/null 2>&1 && magiskpolicy --live --apply "$R" >/dev/null 2>&1; then log sepolicy "magiskpolicy ok"; return 0; fi
  if command -v ksud >/dev/null 2>&1 && ksud sepolicy apply "$R" >/dev/null 2>&1; then log sepolicy "ksud ok"; return 0; fi
  for P in magiskpolicy supolicy; do
    command -v "$P" >/dev/null 2>&1 || continue
    while IFS= read -r L; do
      [ -z "$L" ] && continue
      "$P" --live "$L" >/dev/null 2>&1
    done < "$R"
    log sepolicy "$P line by line"; return 0
  done
  log sepolicy "no policy tool found (the service stage retries)"
}

# ---- system.prop (what a module's system.prop does) ----
load_props() {
  F="$1"; [ -f "$F" ] || return 0
  while IFS= read -r L || [ -n "$L" ]; do
    case "$L" in ''|'#'*) continue ;; esac
    K=${L%%=*}; V=${L#*=}
    [ -n "$K" ] || continue
    if command -v resetprop >/dev/null 2>&1; then resetprop -n "$K" "$V" >/dev/null 2>&1
    else case "$K" in ro.*) ;; *) setprop "$K" "$V" >/dev/null 2>&1 ;; esac; fi
  done < "$F"
}

is_mounted() { awk -v d="$1" '$5==d{f=1} END{exit !f}' /proc/self/mountinfo 2>/dev/null; }

# ---- replaces magic mount for <module>/system/... ----
#  file that already exists in the ROM  -> bind mount over it
#  file that does not exist in the ROM  -> read-only overlayfs on its folder (lowerdir = ours : ROM's)
mount_tree() {
  T="$1/system"; [ -d "$T" ] || return 0
  OV=/dev/.mkvp_ovl.$$; : > "$OV"
  find "$T" -type f 2>/dev/null | while IFS= read -r f; do
    rel=${f#"$T"/}
    case "${rel%%/*}" in
      product|vendor|system_ext|odm|oem|mi_ext|vendor_dlkm|odm_dlkm|system_dlkm|my_*) dst="/$rel" ;;
      *) dst="/system/$rel" ;;
    esac
    if [ -f "$dst" ]; then
      is_mounted "$dst" && continue
      mount -o bind "$f" "$dst" >/dev/null 2>&1 && log mount "bind $dst" || log mount "bind FAILED $dst"
    else
      echo "${f%/*}|${dst%/*}" >> "$OV"
    fi
  done
  sort -u "$OV" 2>/dev/null | while IFS='|' read -r s d; do
    [ -d "$d" ] || { log mount "skip $d (not on this ROM)"; continue; }
    is_mounted "$d" && continue
    if mount -t overlay overlay -o "lowerdir=$s:$d" "$d" >/dev/null 2>&1; then log mount "overlay $d"
    else log mount "overlay FAILED $d"; fi
  done
  rm -f "$OV"
}

stage_postfs() {
  log postfs "start (engine $ENG)"
  apply_sepolicy
  load_props "$ENG/tools/system.prop"
  [ -f "$ENG/tools/post-fs-data.sh" ] && ( sh "$ENG/tools/post-fs-data.sh" ) >/dev/null 2>&1
  [ -f "$ENG/thermal/post-fs-data.sh" ] && ( sh "$ENG/thermal/post-fs-data.sh" ) >/dev/null 2>&1
  mount_tree "$ENG/tools"
  mount_tree "$ENG/thermal"
  log postfs "done"
}

stage_service() {
  log service "start"
  apply_sepolicy
  [ -f "$ENG/tools/service.sh" ] && nohup sh "$ENG/tools/service.sh" >/dev/null 2>&1 </dev/null &
  [ -f "$ENG/thermal/service.sh" ] && nohup sh "$ENG/thermal/service.sh" >/dev/null 2>&1 </dev/null &
  log service "launched"
}

once() { # once <stage> -> true only the first time in this boot (/dev is a tmpfs)
  M=/dev/.mkvp_stage_$1
  [ -e "$M" ] && return 1
  : > "$M"; return 0
}

case "$1" in
  post-fs-data) once post-fs-data && stage_postfs ;;
  service)      once service && stage_service ;;
  late)
    once post-fs-data && stage_postfs
    once service && stage_service ;;
  *) echo "usage: boot.sh post-fs-data|service|late"; exit 1 ;;
esac
exit 0
