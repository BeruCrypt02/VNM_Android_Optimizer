#!/system/bin/sh
# usage: install_engine.sh <engine_dir> <version>
SRC="$1"; VER="$2"
export PATH=/system/bin:/system/xbin:/vendor/bin:/data/adb/ksu/bin:/data/adb/ap/bin:/data/adb/magisk:$PATH

ui_print() { echo "$@"; }
abort() { echo "$@"; exit 1; }
set_perm() { chown "$2:$3" "$1" 2>/dev/null; chmod "$4" "$1" 2>/dev/null; }
set_perm_recursive() {
  chown -R "$2:$3" "$1" 2>/dev/null
  find "$1" -type d -exec chmod "$4" {} + 2>/dev/null
  find "$1" -type f -exec chmod "$5" {} + 2>/dev/null
}

API=$(getprop ro.build.version.sdk)
case "$(getprop ro.product.cpu.abi)" in arm64*) ARCH=arm64 ;; armeabi*) ARCH=arm ;; x86_64*) ARCH=x64 ;; *) ARCH=x86 ;; esac
export API ARCH

install_one() {
  NAME="$1"; ID="$2"
  MODPATH="/data/adb/modules/$ID"
  KEEP="/data/local/tmp/.mkvp_keep_$ID"
  rm -rf "$KEEP"; mkdir -p "$KEEP"
  # keep the user's settings across updates
  for f in systemperf.conf removed_packages.txt brightness/config.conf; do
    if [ -f "$MODPATH/$f" ]; then mkdir -p "$KEEP/$(dirname "$f")"; cp -f "$MODPATH/$f" "$KEEP/$f"; fi
  done
  mkdir -p "$MODPATH" || abort "cannot create $MODPATH"
  cp -a "$SRC/$NAME/." "$MODPATH/" || abort "copy failed for $ID"
  (cd "$KEEP" && find . -type f | while read -r f; do cp -f "$KEEP/$f" "$MODPATH/$f"; done)
  rm -rf "$KEEP"
  mkdir -p "$MODPATH/webroot"
  rm -f "$MODPATH/disable" "$MODPATH/remove"
  export MODPATH
  cd "$MODPATH" || abort "cd failed"
  if [ -f "$MODPATH/customize.sh" ]; then
    ( . "$MODPATH/customize.sh" ) || abort "customize failed for $ID"
  fi
  set_perm_recursive "$MODPATH" 0 0 0755 0644
  restorecon -R "$MODPATH" 2>/dev/null
  find "$MODPATH" -name '*.sh' -exec chmod 0755 {} + 2>/dev/null
  chmod 0755 "$MODPATH/brightness/bin/brightnessd" "$MODPATH/fod/bin/fodctl" 2>/dev/null
  echo "- $ID installed"
}

install_one thermal mkvp_thermal
install_one tools mkvp_tools
echo "$VER" > /data/adb/mkvp_engine_version
chmod 0644 /data/adb/mkvp_engine_version
exit 0
