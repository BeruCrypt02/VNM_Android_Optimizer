#!/system/bin/sh
DIR=${0%/*}
. "$DIR/common.sh"
TSV="$MODDIR/label_entries.tsv"
LABELS="$MODDIR/webroot/app_labels.json"
[ -f "$TSV" ] || : > "$TSV"

awk -F'\t' '
  BEGIN { printf "{" }
  {
    val = $2;
    gsub(/\\/, "\\\\", val);
    gsub(/"/, "\\\"", val);
    if (NR > 1) printf ",";
    printf "\"%s\":\"%s\"", $1, val;
  }
  END { print "}" }
' "$TSV" > "$LABELS"

log "rebuild_labels: regenerated app_labels.json"
