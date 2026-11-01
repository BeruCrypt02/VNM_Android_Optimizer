#!/system/bin/sh
# Restore removed apps.
# Usage: restore_pkg.sh <pkg1> <pkg2> ...   -> restores only those
#        restore_pkg.sh                     -> auto-detects and restores
#                                               EVERY app missing for user 0
DIR=${0%/*}
. "$DIR/common.sh"
LIST="$MODDIR/removed_packages.txt"
TMP=/data/local/tmp

do_restore() {
  pkg="$1"
  if pm install-existing "$pkg" >/dev/null 2>&1; then
    log "restored: $pkg"
    [ -f "$LIST" ] && sed -i "/^${pkg}$/d" "$LIST" 2>/dev/null
  else
    log "restore failed: $pkg"
  fi
}

if [ "$#" -gt 0 ]; then
  for pkg in "$@"; do
    do_restore "$pkg"
  done
  exit 0
fi

# No args -> auto-detect everything currently missing for user 0.
# (Two `pm list packages` calls total, then a fast local diff --
# NOT one `pm list packages` call per candidate package, which is
# what made the naive version slow/prone to timing out on devices
# with a lot of installed apps.)
pm list packages -u | sed 's/^package://' > "$TMP/.hpk_all.txt"
pm list packages    | sed 's/^package://' > "$TMP/.hpk_installed.txt"
grep -vxFf "$TMP/.hpk_installed.txt" "$TMP/.hpk_all.txt" > "$TMP/.hpk_missing.txt" 2>/dev/null

COUNT=$(wc -l < "$TMP/.hpk_missing.txt" 2>/dev/null)
log "restore: auto-detected $COUNT missing package(s)"

if [ "$COUNT" -eq 0 ] 2>/dev/null; then
  log "restore: nothing to restore"
  rm -f "$TMP/.hpk_all.txt" "$TMP/.hpk_installed.txt" "$TMP/.hpk_missing.txt"
  exit 0
fi

while read -r pkg; do
  [ -z "$pkg" ] && continue
  do_restore "$pkg"
done < "$TMP/.hpk_missing.txt"

rm -f "$TMP/.hpk_all.txt" "$TMP/.hpk_installed.txt" "$TMP/.hpk_missing.txt"
