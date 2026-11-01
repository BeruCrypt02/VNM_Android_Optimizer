#!/system/bin/sh
# Usage: debloat_run.sh <delete_ui:0|1> <pkg1> <pkg2> ...
DIR=${0%/*}
. "$DIR/common.sh"

DELETE_UI="$1"; shift
STATUS="$MODDIR/webroot/status.json"

log "debloat_run: starting on $# selected package(s), delete_ui=$DELETE_UI"
echo "{\"state\":\"running\",\"done\":0,\"total\":$#,\"results\":[]}" > "$STATUS"

i=0
RESULTS=""
for pkg in "$@"; do
  i=$((i+1))
  if pm uninstall --user 0 "$pkg" >/dev/null 2>&1; then
    log "removed: $pkg"
    echo "$pkg" >> "$MODDIR/removed_packages.txt"
    R="{\"pkg\":\"$pkg\",\"ok\":true}"
  else
    log "failed/not-present: $pkg"
    R="{\"pkg\":\"$pkg\",\"ok\":false}"
  fi
  [ -n "$RESULTS" ] && RESULTS="$RESULTS,"
  RESULTS="$RESULTS$R"
  echo "{\"state\":\"running\",\"done\":$i,\"total\":$#,\"results\":[$RESULTS]}" > "$STATUS"
done

echo "{\"state\":\"done\",\"done\":$i,\"total\":$#,\"results\":[$RESULTS]}" > "$STATUS"
log "debloat_run: finished ($i/$# processed)"

if [ "$DELETE_UI" = "1" ]; then
  rm -f "$MODDIR/webroot/curated_common.json" "$MODDIR/webroot/curated_miui.json" \
        "$MODDIR/webroot/curated_oneui.json" "$MODDIR/webroot/curated_coloros.json" \
        "$MODDIR/webroot/curated_generic.json"
  log "debloat_run: recommended-picks overlays deleted per user choice — full app list remains available"
fi
