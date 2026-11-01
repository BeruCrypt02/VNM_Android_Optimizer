#!/system/bin/sh
# MkVenomPro Optimizer - late_start service
# ONE-SHOT: waits for boot, applies every enabled feature once, then exits.
# Changes made in the WebUI take effect next boot. The only thing that can keep
# running are the charge-limit keeper (common/chg_watch.sh, only while "Charge limit ~80%"
# is ON) and the daily cache keeper (common/cache_clean.sh, only while "Auto clean app cache" is ON).
MODDIR=${0%/*}
# shellcheck source=/dev/null
. "$MODDIR/common/functions.sh"

mkdir -p "$HC_DATA" "$HC_BAKDIR"
[ -f "$HC_CFG" ] || cp -f "$MODDIR/common/default.conf" "$HC_CFG"
# apply the snapshot taken at post-fs-data, so a WebUI save during boot waits for the next boot
[ -f "$HC_BOOTCFG" ] || cp -f "$HC_CFG" "$HC_BOOTCFG"
HC_CFG=$HC_BOOTCFG

# persist.* props set in post-fs-data can be overwritten when init loads stored
# persistent props (Magisk); set them again now, before system apps start
on debug_props && hc_props "$HC_DEBUG_PROPS" persist >/dev/null
on blur_off && hc_props "$HC_BLUR_PROPS" persist >/dev/null
on x_props && apply_props_file "$MODDIR/common/x_props.txt" persist >/dev/null

# ---------- wait for boot (bounded) ----------
_i=0
while [ "$(getprop sys.boot_completed)" != "1" ] && [ "$_i" -lt 240 ]; do
  sleep 2
  _i=$((_i + 2))
done

# Let the ROM finish its own boot-time tuning first, then apply on top.
_delay=$(rng apply_delay 30 10 120)
sleep "$_delay"

log "boot completed, applying after ${_delay}s delay"
if [ -f "$HC_PFD_STATUS" ]; then cp -f "$HC_PFD_STATUS" "$HC_STATUS"; else : > "$HC_STATUS"; fi
# shellcheck disable=SC2034
HC_STATUS_OUT=$HC_STATUS

# ---------- kernel: heat ----------
f_cpu_cap
f_prime_park
f_gpu_cap
f_gpu_idle
f_walt_tune
f_input_boost_off
f_bg_cpuset
f_blur_off_verify
f_charge_cool
f_charge_limit

# ---------- kernel: drain ----------
f_cpu_idle
f_ufs_pm
f_vm_tune
f_io_tune
f_debug_off
f_wakelock_block

# ---------- ROM: protected apps first, then restrictions ----------
f_bg_block
f_protect_apps
f_app_bucket

# ---------- ROM / system ----------
f_app_freezer
f_doze_aggr
f_devcfg_lock
f_gms_doze_verify
f_scan_off
f_net_save
f_standby
f_stats_reduce
f_tracking_off
f_debloat
f_joyose_off

# ---------- long battery ----------
f_saver_policy
f_saver_trigger
f_refresh_rate
f_anim_scale

# ---------- more: merged extras (all off unless enabled in the WebUI) ----------
f_x_sched
f_x_kquiet
f_x_net
f_x_io
f_x_xiaomi_fw
f_x_ram_opt
f_x_multitask
f_x_gms_freeze
f_x_log_nuke
f_x_track
f_x_diag
f_x_cache_auto
f_x_kpower
f_x_vm_lite

# ---------- bookkeeping ----------
cp -f "$HC_BOOTCFG" "$HC_DATA/last_applied.conf"
cp -f "$MODDIR/common/restore.sh" "$HC_DATA/restore.sh"
mkdir -p /data/adb/service.d
cp -f "$MODDIR/common/hc_guard.sh" /data/adb/service.d/.mkvp_guard.sh && chmod 0755 /data/adb/service.d/.mkvp_guard.sh
date '+%Y-%m-%d %H:%M:%S' > "$HC_DATA/last_boot"

_a=$(grep -c '=applied|' "$HC_STATUS")
_p=$(grep -c '=partial|' "$HC_STATUS")
_s=$(grep -c '=skipped|' "$HC_STATUS")
_f=$(grep -c '=failed|' "$HC_STATUS")
_o=$(grep -c '=off|' "$HC_STATUS")
log "done: $_a applied, $_p partial, $_s skipped, $_f failed, $_o off"

_desc="Heat and battery fix for Android - $(hc_soc_label) (one-shot at boot$(on charge_limit && echo ", charge-limit keeper running")). Last boot: $_a applied, $_p partial, $_s unsupported, $_f failed, $_o off. Configure in WebUI."
sed -i "s|^description=.*|description=$_desc|" "$MODDIR/module.prop"

exit 0
