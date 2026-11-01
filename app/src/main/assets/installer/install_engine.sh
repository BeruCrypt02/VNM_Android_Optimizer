#!/system/bin/sh
# usage: install_engine.sh <engine_dir> <version>
# Installs the engine as an add-on of the app: /data/adb/mkvp/engine/{thermal,tools}.
# No Magisk / KernelSU / APatch module is created. Boot is handled by boot.sh through the
# standard /data/adb/post-fs-data.d + service.d hooks and by the app's own boot receiver.
SRC="$1"; VER="$2"
export PATH=/system/bin:/system/xbin:/vendor/bin:/data/adb/ksu/bin:/data/adb/ap/bin:/data/adb/magisk:$PATH

BASE=/data/adb/mkvp
ENG=$BASE/engine

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

mkdir -p "$ENG" || abort "cannot create $ENG"
chmod 0755 "$BASE" "$ENG" 2>/dev/null

install_one() {
  NAME="$1"; OLDID="$2"
  MODPATH="$ENG/$NAME"
  OLDMOD="/data/adb/modules/$OLDID"
  KEEP="/data/local/tmp/.mkvp_keep_$NAME"
  rm -rf "$KEEP"; mkdir -p "$KEEP"
  # keep the user's settings across updates (and carry them over from the old module version)
  for f in systemperf.conf removed_packages.txt brightness/config.conf; do
    for from in "$MODPATH" "$OLDMOD"; do
      if [ -f "$from/$f" ]; then mkdir -p "$KEEP/$(dirname "$f")"; cp -f "$from/$f" "$KEEP/$f"; break; fi
    done
  done
  mkdir -p "$MODPATH" || abort "cannot create $MODPATH"
  cp -a "$SRC/$NAME/." "$MODPATH/" || abort "copy failed for $NAME"
  (cd "$KEEP" && find . -type f | while read -r f; do mkdir -p "$MODPATH/$(dirname "$f")"; cp -f "$KEEP/$f" "$MODPATH/$f"; done)
  rm -rf "$KEEP"
  mkdir -p "$MODPATH/webroot"
  rm -f "$MODPATH/disable" "$MODPATH/remove"
  export MODPATH
  cd "$MODPATH" || abort "cd failed"
  if [ -f "$MODPATH/customize.sh" ]; then
    ( . "$MODPATH/customize.sh" ) || abort "customize failed for $NAME"
  fi
  set_perm_recursive "$MODPATH" 0 0 0755 0644
  restorecon -R "$MODPATH" 2>/dev/null
  find "$MODPATH" -name '*.sh' -exec chmod 0755 {} + 2>/dev/null
  chmod 0755 "$MODPATH/brightness/bin/brightnessd" "$MODPATH/fod/bin/fodctl" 2>/dev/null
  echo "- $NAME installed"

  # retire the old root-manager module (its uninstall.sh would restore apps / wipe settings: neutralise it)
  if [ -d "$OLDMOD" ]; then
    printf '#!/system/bin/sh\nexit 0\n' > "$OLDMOD/uninstall.sh" 2>/dev/null
    chmod 0755 "$OLDMOD/uninstall.sh" 2>/dev/null
    touch "$OLDMOD/disable" "$OLDMOD/remove" 2>/dev/null
    echo "- old module '$OLDID' will be removed at the next reboot (settings carried over)"
  fi
}

install_one thermal mkvp_thermal
install_one tools mkvp_tools

# engine-level scripts
cp -f "$SRC/boot.sh" "$ENG/boot.sh" || abort "copy failed for boot.sh"
cp -f "$SRC/engine_ctl.sh" "$ENG/engine_ctl.sh" || abort "copy failed for engine_ctl.sh"
chmod 0755 "$ENG/boot.sh" "$ENG/engine_ctl.sh"
rm -f "$BASE/disable"

# boot hooks (standard root-manager script folders, not modules)
mkdir -p /data/adb/post-fs-data.d /data/adb/service.d
printf '#!/system/bin/sh\n[ -f /data/adb/mkvp/engine/boot.sh ] && sh /data/adb/mkvp/engine/boot.sh post-fs-data\nexit 0\n' > /data/adb/post-fs-data.d/mkvp_engine.sh
printf '#!/system/bin/sh\n[ -f /data/adb/mkvp/engine/boot.sh ] && sh /data/adb/mkvp/engine/boot.sh service\nexit 0\n' > /data/adb/service.d/mkvp_engine.sh
chmod 0755 /data/adb/post-fs-data.d/mkvp_engine.sh /data/adb/service.d/mkvp_engine.sh
restorecon /data/adb/post-fs-data.d/mkvp_engine.sh /data/adb/service.d/mkvp_engine.sh 2>/dev/null
echo "- boot hooks installed"

echo "$VER" > /data/adb/mkvp_engine_version
chmod 0644 /data/adb/mkvp_engine_version
exit 0
