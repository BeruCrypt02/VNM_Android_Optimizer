#!/system/bin/sh
# Restore every package this module ever removed, when the module
# itself is uninstalled from Magisk -- keeps the debloat fully reversible.
MODDIR=/data/adb/modules/mkvenompro_android_optimizer
LIST="$MODDIR/removed_packages.txt"
if [ -f "$LIST" ]; then
  sort -u "$LIST" | while read -r pkg; do
    [ -z "$pkg" ] && continue
    pm install-existing "$pkg" >/dev/null 2>&1
  done
fi
