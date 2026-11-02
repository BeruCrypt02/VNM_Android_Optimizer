#!/system/bin/sh
# VNM Optimizer - post-fs-data (blocking stage, kept minimal)
# Prepares the GMS Doze overlay BEFORE modules are mounted and sets
# non-persistent props. Nothing keeps running after this script exits.
MODDIR=${0%/*}
. "$MODDIR/common/functions.sh"

mkdir -p "$HC_DATA" "$HC_BAKDIR"
[ -f "$HC_CFG" ] || cp -f "$MODDIR/common/default.conf" "$HC_CFG"
# snapshot: this whole boot applies the config as it is right now
cp -f "$HC_CFG" "$HC_BOOTCFG"
HC_CFG=$HC_BOOTCFG

: > "$HC_LOG"
: > "$HC_PFD_STATUS"
HC_STATUS_OUT=$HC_PFD_STATUS
log "VNM Optimizer post-fs-data - $(getprop ro.product.device) / $(getprop ro.build.version.incremental)"

# ---------- GMS Doze: rebuild sysconfig overlay each boot ----------
rm -rf "$MODDIR/system"
if on gms_doze; then
  _n=0
  for _d in /system/etc/sysconfig /product/etc/sysconfig /system_ext/etc/sysconfig; do
    [ -d "$_d" ] || continue
    for _x in "$_d"/*.xml; do
      [ -f "$_x" ] || continue
      grep -q 'allow-in-power-save package="com.google.android.gms"' "$_x" || continue
      case "$_d" in
        /system/*) _t="$MODDIR$_d" ;;
        *) _t="$MODDIR/system$_d" ;;
      esac
      mkdir -p "$_t"
      grep -v 'allow-in-power-save package="com.google.android.gms"' "$_x" > "$_t/${_x##*/}"
      _n=$((_n + 1))
    done
  done
  if [ -d "$MODDIR/system" ]; then
    find "$MODDIR/system" -type d -exec chmod 755 {} + 2>/dev/null
    find "$MODDIR/system" -type f -exec chmod 644 {} + 2>/dev/null
    chcon -R u:object_r:system_file:s0 "$MODDIR/system" 2>/dev/null
  fi
  if [ "$_n" -gt 0 ]; then
    st gms_doze applied "GMS removed from Doze whitelist ($_n sysconfig file(s))"
  else
    st gms_doze skipped "GMS whitelist entry not found (already removed?)"
  fi
else
  st gms_doze off
fi

# ---------- Reduce logging (non-persistent, gone when turned off) ----------
if on log_reduce; then
  resetprop -n log.tag W
  st log_reduce applied "only Warning+ logs written"
else
  st log_reduce off
fi

# ---------- Debug / ramdump / trace props (runtime only, never persisted) ----------
if on debug_props; then
  _c=$(hc_props "$HC_DEBUG_PROPS")
  st debug_props applied "$_c debug/trace props set for this boot"
else
  st debug_props off
fi

# ---------- Extra logging props (runtime only) ----------
if on x_props; then
  _c=$(apply_props_file "$MODDIR/common/x_props.txt")
  st x_props applied "$_c extra logging props set for this boot"
else
  st x_props off
fi

# ---------- UI blur off (HyperOS/MIUI props) (GPU heat) - runtime props ----------
if on blur_off; then
  hc_props "$HC_BLUR_PROPS" >/dev/null
fi

exit 0
