#!/system/bin/sh
# MkVenomPro Optimizer - shared functions (sourced by post-fs-data.sh / service.sh)
# shellcheck disable=SC2034

export PATH=/system/bin:/system/xbin:/vendor/bin:/data/adb/ksu/bin:/data/adb/magisk:"$PATH"
HC_DATA=/data/adb/mkvp_thermal
HC_CFG=$HC_DATA/config.conf
HC_BOOTCFG=$HC_DATA/boot_config.conf
HC_STATUS=$HC_DATA/status.conf
HC_PFD_STATUS=$HC_DATA/status_pfd.conf
HC_LOG=$HC_DATA/boot.log
HC_BAKDIR=$HC_DATA/backup
HC_ROMBAK=$HC_BAKDIR/rom.bak
HC_OK=0
HC_FAIL=0

# restore_feature() comes from the standalone restorer
HC_LIB_ONLY=1
# shellcheck source=/dev/null
. "${MODDIR:-${0%/*}}/common/restore.sh"

# ================================================================ helpers
log() { echo "[$(date '+%H:%M:%S')] $*" >> "$HC_LOG"; }

# cfg <key> <default>  -> value from config (never sourced, safe parse)
cfg() {
  _v=$(sed -n "s/^$1=//p" "$HC_CFG" 2>/dev/null | tail -n 1 | tr -d '\r')
  if [ -n "$_v" ]; then echo "$_v"; else echo "$2"; fi
}
on() { [ "$(cfg "$1" 0)" = "1" ]; }
# num <key> <default> -> integer value or default
num() {
  _n=$(cfg "$1" "$2")
  case "$_n" in ''|*[!0-9]*) echo "$2" ;; *) echo "$_n" ;; esac
}
# rng <key> <default> <min> <max> -> integer clamped to range (0 is kept as "off")
rng() {
  _r=$(num "$1" "$2")
  [ "$_r" = 0 ] && { echo 0; return; }
  [ "$_r" -lt "$3" ] && _r=$3
  [ "$_r" -gt "$4" ] && _r=$4
  echo "$_r"
}
rd() { cat "$1" 2>/dev/null; }

# st <key> <state> [detail] ; state: applied|partial|skipped|failed|off
st() {
  echo "$1=$2|$3" >> "${HC_STATUS_OUT:-$HC_STATUS}"
  log "$1 -> $2${3:+ ($3)}"
}

cnt_reset() { HC_OK=0; HC_FAIL=0; HC_RO=0; }
HC_RO=0
# wtry <node> <value> : 0 = value is in place, 1 = rejected, 2 = node read-only, 3 = missing
wtry() {
  [ -e "$1" ] || return 3
  _cv=$(tr -s ' \t\n' '   ' < "$1" 2>/dev/null | sed 's/ *$//')
  _nv=$(echo "$2" | tr -s ' \t' '  ')
  [ -n "$_cv" ] && [ "$_cv" = "$_nv" ] && return 0
  { echo "$2" > "$1"; } 2>/dev/null && return 0
  _m=$(stat -c %a "$1" 2>/dev/null)
  case "$_m" in
    [2367]??|?[2367]??) ;;
    *)
      # owner has no write bit: some nodes still accept writes after chmod
      chmod u+w "$1" 2>/dev/null
      if { echo "$2" > "$1"; } 2>/dev/null; then chmod "$_m" "$1" 2>/dev/null; return 0; fi
      [ -n "$_m" ] && chmod "$_m" "$1" 2>/dev/null
      return 2 ;;
  esac
  return 1
}
# wn <node> <value> : write and count (ok / failed / read-only)
wn() {
  wtry "$1" "$2"
  case $? in
    0) HC_OK=$((HC_OK + 1)); return 0 ;;
    1) HC_FAIL=$((HC_FAIL + 1)); log "  rejected: $1 <- $2" ;;
    2) HC_RO=$((HC_RO + 1)); log "  read-only: $1" ;;
  esac
  return 1
}

# fin <key> [detail] [skip-detail] : turn counters into a status line
# read-only nodes are "unsupported", not failures: the kernel simply does not allow it
fin() {
  _ro=""
  [ "${HC_RO:-0}" -gt 0 ] && _ro="$HC_RO read-only node(s) left stock"
  if [ "$HC_OK" -gt 0 ] && [ "$HC_FAIL" -eq 0 ]; then st "$1" applied "$2${_ro:+; $_ro}"
  elif [ "$HC_OK" -gt 0 ]; then st "$1" partial "$HC_OK ok / $HC_FAIL rejected${_ro:+ / $_ro}${2:+; $2}"
  elif [ "$HC_FAIL" -gt 0 ]; then st "$1" failed "$HC_FAIL writes rejected${_ro:+, $_ro}; see boot.log"
  elif [ "${HC_RO:-0}" -gt 0 ]; then st "$1" skipped "read-only on this kernel ($HC_RO node(s))"
  else st "$1" skipped "${3:-not supported by this kernel/ROM}"
  fi
}
cnt_ok() { HC_OK=$((HC_OK + 1)); }
cnt_fail() { HC_FAIL=$((HC_FAIL + 1)); }

# ================================================================ runtime props
# Runtime only (resetprop -n): never written to persistent storage.
HC_DEBUG_PROPS="persist.vendor.ssr.enable_ramdumps=0 persist.sys.offlinelog.kernel=false persist.sys.offlinelog.logcat=false persist.sys.offlinelog.logcatkernel=false debug.atrace.tags.enableflags=0 persist.traced.enable=0 persist.ims.disableDebugLogs=1 persist.ims.disableQXDMLogs=1 persist.ims.disableIMSLogs=1 persist.ims.enableADBLogs=0 persist.data.qmi.adb_logmask=0 persist.debug.wfd.enable=0 persist.android.strictmode=0 profiler.force_disable_err_rpt=1 profiler.force_disable_ulog=1 libc.debug.malloc=0 vidc.debug.level=0 debug.egl.profiler=0 debug.sf.dump=0 debug.hwc.otf=0"
HC_BLUR_PROPS="ro.miui.has_real_blur=0 ro.miui.has_blur=0 ro.miui.backdrop_sampling_enabled=0 persist.sys.background_blur_supported=false persist.sysui.miui_blur_enabled=0 ro.surface_flinger.supports_background_blur=0 ro.sf.blurs_are_expensive=1 disableBlurs=1 enable_blurs_on_windows=0"

# hc_props <list> [persist-only] -> number of props set
hc_props() {
  _pc=0
  for _pv in $1; do
    if [ "$2" = persist ]; then case "$_pv" in persist.*) ;; *) continue ;; esac; fi
    resetprop -n "${_pv%%=*}" "${_pv#*=}" 2>/dev/null && _pc=$((_pc + 1))
  done
  echo "$_pc"
}

# ================================================================ CPU topology
hc_policy_by_max() { # $1 = min|max
  _best=""
  if [ "$1" = min ]; then _bm=999999999; else _bm=0; fi
  for _p in /sys/devices/system/cpu/cpufreq/policy*; do
    [ -d "$_p" ] || continue
    _m=$(rd "$_p/cpuinfo_max_freq"); [ -n "$_m" ] || continue
    if [ "$1" = min ] && [ "$_m" -lt "$_bm" ]; then _bm=$_m; _best=$_p; fi
    if [ "$1" = max ] && [ "$_m" -gt "$_bm" ]; then _bm=$_m; _best=$_p; fi
  done
  echo "$_best"
}
hc_little_policy() { hc_policy_by_max min; }

# ================================================================ HEAT (kernel)

f_cpu_cap() {
  _pct=$(num cpu_cap 0)
  # v1.0 used levels 1/2/3
  case "$_pct" in 1) _pct=95 ;; 2) _pct=88 ;; 3) _pct=80 ;; esac
  [ "$_pct" = 0 ] && { st cpu_cap off; return; }
  [ "$_pct" -lt 40 ] && _pct=40
  [ "$_pct" -ge 100 ] && { st cpu_cap off "100% = no cap"; return; }
  cnt_reset
  _little=$(hc_little_policy)
  _det=""; _lk=0; _ci=-1
  _lock=$(cfg cpu_cap_lock 1)
  # MediaTek: the PPM user limit is honoured by the MTK power/perf stack
  _ppm=/proc/ppm/policy/hard_userlimit_max_cpu_freq
  for _p in /sys/devices/system/cpu/cpufreq/policy*; do
    [ -d "$_p" ] || continue
    _ci=$((_ci + 1))
    [ "$_p" = "$_little" ] && continue
    _max=$(rd "$_p/cpuinfo_max_freq"); [ -n "$_max" ] || continue
    _tgt=$((_max * _pct / 100))
    _sel=0
    for _f in $(rd "$_p/scaling_available_frequencies"); do
      if [ "$_f" -le "$_tgt" ] && [ "$_f" -gt "$_sel" ]; then _sel=$_f; fi
    done
    [ "$_sel" = 0 ] && _sel=$_tgt
    if on_mtk_ok && [ -e "$_ppm" ] && { echo "$_ci $_sel" > "$_ppm"; } 2>/dev/null; then
      cnt_ok; _ppmok=1
    fi
    if wn "$_p/scaling_max_freq" "$_sel"; then
      _det="$_det ${_p##*/}=$((_sel / 1000))MHz"
      # lock: non-root ROM services (perf HAL, boosters) can no longer raise it; thermal
      # limits are kernel QoS requests and still apply. Permissions reset at reboot.
      [ "$_lock" = 1 ] && chmod 0444 "$_p/scaling_max_freq" 2>/dev/null && _lk=$((_lk + 1))
    fi
  done
  if [ "${_ppmok:-0}" = 1 ]; then
    _det="$_det, MediaTek PPM"
    [ "$_lock" = 1 ] && chmod 0444 "$_ppm" 2>/dev/null
  fi
  _ppmok=0
  [ "$_lk" -gt 0 ] && _det="$_det, locked"
  if [ -n "$_det" ]; then fin cpu_cap "${_pct}% cap:$_det"; else fin cpu_cap; fi
}

f_prime_park() {
  on prime_park || { st prime_park off; return; }
  on_qcom_ok || { st prime_park skipped "needs Qualcomm core_ctl (not on MediaTek)"; return; }
  cnt_reset
  _pp=$(hc_policy_by_max max)
  _lp=$(hc_little_policy)
  if [ -n "$_pp" ] && [ "$_pp" != "$_lp" ]; then
    _c=$(rd "$_pp/related_cpus" | awk '{print $1}')
    _cc=/sys/devices/system/cpu/cpu$_c/core_ctl
    if [ -f "$_cc/enable" ] && [ "$(rd "$_cc/enable")" = 0 ]; then
      fin prime_park "" "core_ctl is disabled on this cluster (enable=0), nothing to park with"
      return
    fi
    if [ -f "$_cc/max_cpus" ]; then
      [ -f "$_cc/min_cpus" ] && wn "$_cc/min_cpus" 0
      wn "$_cc/max_cpus" 0
      fin prime_park "cluster of cpu$_c parked via core_ctl (not offlined)"
      return
    fi
  fi
  fin prime_park "" "no core_ctl for the prime cluster"
}

f_gpu_cap() {
  _lvl=$(rng gpu_cap 0 1 4)
  [ "$_lvl" = 0 ] && { st gpu_cap off; return; }
  _k=/sys/class/kgsl/kgsl-3d0
  cnt_reset
  if [ ! -d "$_k" ] || ! on_qcom_ok; then
    if on_mtk_ok; then hc_gpu_cap_other "$_lvl"; else fin gpu_cap "" "no Adreno kgsl device"; fi
    return
  fi
  _fl=$(rd "$_k/devfreq/available_frequencies"; rd "$_k/gpu_available_frequencies")
  _fl=$(echo "$_fl" | tr ' ' '\n' | grep -E '^[0-9]+$' | sort -rnu)
  _nf=$(echo "$_fl" | grep -c .)
  _np=$(rd "$_k/num_pwrlevels"); case "$_np" in ''|*[!0-9]*) _np=$_nf ;; esac
  # safety: never remove more than half of the levels (v1.3 allowed 8 -> 205 MHz)
  _half=$((_np / 2)); [ "$_half" -lt 1 ] && _half=1
  _idx=$_lvl; [ "$_idx" -gt "$_half" ] && _idx=$_half
  _fq=$(echo "$_fl" | sed -n "$((_idx + 1))p")
  _how=""
  if wtry "$_k/max_pwrlevel" "$_idx"; then _how=max_pwrlevel
  elif [ -n "$_fq" ] && wtry "$_k/devfreq/max_freq" "$_fq"; then _how=devfreq/max_freq
  elif [ -n "$_fq" ] && wtry "$_k/max_gpuclk" "$_fq"; then _how=max_gpuclk
  fi
  if [ -n "$_how" ]; then cnt_ok
  elif [ -e "$_k/max_pwrlevel" ] || [ -e "$_k/devfreq/max_freq" ]; then cnt_fail; log "  gpu_cap: max_pwrlevel, devfreq/max_freq and max_gpuclk all rejected"
  fi
  _cut=""; [ "$_idx" -lt "$_lvl" ] && _cut=" (limited from $_lvl for safety)"
  fin gpu_cap "top $_idx level(s) removed${_fq:+, max $((_fq / 1000000)) MHz} via $_how$_cut"
}

# GPU cap for MediaTek (GED ceiling) or any Mali/other devfreq GPU
hc_gpu_dev() {
  for _d in /sys/class/devfreq/*; do
    case "${_d##*/}" in *mali*|*gpu*|*GPU*) ;; *) continue ;; esac
    [ -f "$_d/available_frequencies" ] && [ -f "$_d/max_freq" ] && { echo "$_d"; return 0; }
  done
  return 1
}
hc_gpu_cap_other() {
  # Mali / other devfreq GPU (MediaTek, Exynos, Tensor): devfreq max_freq takes a frequency in Hz
  _dv=$(hc_gpu_dev)
  [ -n "$_dv" ] || { fin gpu_cap "" "no Adreno kgsl or devfreq GPU (MediaTek GED-only kernels are not supported)"; return; }
  _fl=$(rd "$_dv/available_frequencies" | tr ' ' '\n' | grep -E '^[0-9]+$' | sort -rnu)
  _np=$(echo "$_fl" | grep -c .)
  _half=$((_np / 2)); [ "$_half" -lt 1 ] && _half=1
  _idx=$1; [ "$_idx" -gt "$_half" ] && _idx=$_half
  _fq=$(echo "$_fl" | sed -n "$((_idx + 1))p")
  [ -n "$_fq" ] && wn "$_dv/max_freq" "$_fq"
  _cut=""; [ "$_idx" -lt "$1" ] && _cut=" (limited from $1 for safety)"
  fin gpu_cap "top $_idx level(s) removed${_fq:+, max $((_fq / 1000000)) MHz} via devfreq ${_dv##*/}$_cut"
}

f_gpu_idle() {
  on gpu_idle || { st gpu_idle off; return; }
  _k=/sys/class/kgsl/kgsl-3d0
  _t=$(rng gpu_idle_timer 64 20 200)
  cnt_reset
  if [ ! -d "$_k" ] || ! on_qcom_ok; then
    on_mtk_ok || { fin gpu_idle "" "no Adreno kgsl device"; return; }
    # Mali (MediaTek/Exynos/Tensor): demand-driven power policy, never always_on
    for _pp in /sys/class/misc/mali0/device/power_policy /sys/devices/platform/*.mali/power_policy \
               /sys/devices/platform/soc/*.mali/power_policy /sys/devices/platform/mali*/power_policy; do
      [ -f "$_pp" ] || continue
      grep -q coarse_demand "$_pp" 2>/dev/null || continue
      case "$(rd "$_pp")" in *"[coarse_demand]"*) cnt_ok ;; *) wn "$_pp" coarse_demand ;; esac
      break
    done
    fin gpu_idle "Mali power_policy coarse_demand (GPU powers down when idle)" "no Adreno kgsl or Mali power_policy"
    return
  fi
  for _n in force_clk_on force_bus_on force_rail_on force_no_nap; do wn "$_k/$_n" 0; done
  wn "$_k/bus_split" 1
  wn "$_k/throttling" 1
  [ "$_t" -gt 0 ] && wn "$_k/idle_timer" "$_t"
  if [ "$_t" -gt 0 ]; then _td="idle_timer ${_t}ms"; else _td="idle_timer stock"; fi
  fin gpu_idle "$_td, GPU thermal throttling kept ON"
}

f_walt_tune() {
  on walt_tune || { st walt_tune off; return; }
  _hl=$(rng walt_hispeed_load 95 50 100)
  _ur=$(rng walt_up_rate 1000 100 20000)
  cnt_reset
  _wpl=0; _whl=0; _wur=0
  for _g in /sys/devices/system/cpu/cpufreq/policy*/walt /sys/devices/system/cpu/cpufreq/policy*/schedutil \
            /sys/devices/system/cpu/cpufreq/policy*/sugov_ext; do
    [ -d "$_g" ] || continue
    case "$_g" in */walt) on_qcom_ok || continue ;; */sugov_ext) on_mtk_ok || continue ;; esac
    [ -f "$_g/pl" ] && wn "$_g/pl" 0 && _wpl=1
    [ -f "$_g/rtg_boost_freq" ] && wn "$_g/rtg_boost_freq" 0 && _wpl=1
    [ -f "$_g/hispeed_load" ] && [ "$_hl" -gt 0 ] && wn "$_g/hispeed_load" "$_hl" && _whl=1
    [ -f "$_g/up_rate_limit_us" ] && [ "$_ur" -gt 0 ] && wn "$_g/up_rate_limit_us" "$_ur" && _wur=1
  done
  if [ "$(cfg walt_sched_boost_off 1)" = "1" ] && on_qcom_ok; then
    [ -f /proc/sys/walt/sched_boost ] && wn /proc/sys/walt/sched_boost 0
    [ -f /proc/sys/walt/sched_conservative_pl ] && wn /proc/sys/walt/sched_conservative_pl 1
  fi
  _wd=""
  [ "$_wpl" = 1 ] && _wd="pl off"
  [ "$_whl" = 1 ] && _wd="${_wd:+$_wd, }hispeed_load $_hl"
  [ "$_wur" = 1 ] && _wd="${_wd:+$_wd, }up_rate ${_ur}us"
  fin walt_tune "$_wd"
}

f_input_boost_off() {
  on input_boost_off || { st input_boost_off off; return; }
  cnt_reset
  _b=/proc/sys/walt/input_boost
  if on_qcom_ok && [ -f "$_b/input_boost_ms" ]; then
    wn "$_b/input_boost_ms" 0
    if [ -f "$_b/input_boost_freq" ]; then
      _z=""; for _x in $(rd "$_b/input_boost_freq"); do _z="$_z 0"; done
      [ -n "$_z" ] && wn "$_b/input_boost_freq" "${_z# }"
    fi
    [ -f "$_b/sched_boost_on_input" ] && wn "$_b/sched_boost_on_input" 0
  fi
  on_qcom_ok && for _n in /sys/module/cpu_boost/parameters/input_boost_ms \
            /sys/module/cpu_boost/parameters/powerkey_input_boost_ms \
            /sys/devices/system/cpu/cpu_boost/input_boost_ms; do
    [ -f "$_n" ] && wn "$_n" 0
  done
  # MediaTek perfmgr touch boost
  _tb=/proc/perfmgr/tchbst/user/usrtch
  on_mtk_ok && [ -f "$_tb" ] && { echo "enable 0" > "$_tb"; } 2>/dev/null && cnt_ok
  fin input_boost_off "kernel touch boost disabled"
}

f_bg_cpuset() {
  on bg_cpuset || { st bg_cpuset off; return; }
  _uc=$(rng bg_uclamp 50 10 100)
  cnt_reset
  _lp=$(hc_little_policy)
  _cpus=$(rd "$_lp/related_cpus")
  _first=$(echo "$_cpus" | awk '{print $1}')
  _last=$(echo "$_cpus" | awk '{print $NF}')
  _range=""
  if [ -n "$_first" ] && [ -n "$_last" ]; then
    _range="$_first-$_last"
    for _g in background system-background restricted; do
      [ -f "/dev/cpuset/$_g/cpus" ] || continue
      # only narrow: a group already inside the little cluster (e.g. 0-1) is left as is
      _mc=$(rd "/dev/cpuset/$_g/cpus" | tr ',' '\n' | sed 's/.*-//' | sort -n | tail -n 1)
      case "$_mc" in ''|*[!0-9]*) ;; *) [ "$_mc" -le "$_last" ] && { cnt_ok; continue; } ;; esac
      wn "/dev/cpuset/$_g/cpus" "$_range"
    done
  fi
  if [ "$_uc" -gt 0 ] && [ "$_uc" -lt 100 ]; then
    for _g in background restricted; do
      [ -f "/dev/cpuctl/$_g/cpu.uclamp.max" ] && wn "/dev/cpuctl/$_g/cpu.uclamp.max" "$_uc"
    done
  fi
  if [ "$_uc" -gt 0 ] && [ "$_uc" -lt 100 ]; then _ud="uclamp.max ${_uc}%"; else _ud="uclamp stock"; fi
  fin bg_cpuset "background -> CPU ${_range:-?}, $_ud"
}

f_blur_off_verify() {
  # props are set in post-fs-data; here only the persistent window-blur setting
  if on blur_off; then
    cnt_reset
    set_s blur_off global disable_window_blurs 1
    cmd window disable-blur 1 </dev/null >/dev/null 2>&1
    fin blur_off "window blur off + HyperOS blur props"
  else
    restore_feature blur_off
    st blur_off off
  fi
}

# Big-endian u32 array from a device-tree property -> decimal list
hc_dt_u32() {
  for _h in $(od -An -v -tx1 "$1" 2>/dev/null | awk '{ for (i = 1; i <= NF; i++) b[n++] = $i }
      END { for (i = 0; i + 3 < n; i += 4) print b[i] b[i+1] b[i+2] b[i+3] }'); do
    printf '%d ' "0x$_h"
  done
}

# Charge current limit through the charger thermal level (battery/charge_control_limit).
# Tested on marble HyperOS 3: constant_charge_current and restrict_cur are ignored,
# charge_control_limit takes effect and survives unplug/replug.
f_charge_cool() {
  _ma=$(num charge_cool 0)
  case "$_ma" in 1) _ma=3000 ;; 2) _ma=2000 ;; 3) _ma=1500 ;; esac
  [ "$_ma" = 0 ] && { st charge_cool off; return; }
  [ "$_ma" -lt 500 ] && _ma=500
  [ "$_ma" -gt 12000 ] && _ma=12000
  _ua=$((_ma * 1000))
  _n=/sys/class/power_supply/battery/charge_control_limit
  _mx=$(rd /sys/class/power_supply/battery/charge_control_limit_max)
  cnt_reset
  case "$_mx" in ''|*[!0-9]*|0) st charge_cool skipped "no charger thermal level (charge_control_limit) on this kernel"; return ;; esac
  [ -e "$_n" ] || { st charge_cool skipped "no charge_control_limit node"; return; }

  _lv=""; _lua=""; _tbl=""; _how=""
  _cal=$HC_DATA/charge_levels.conf
  # 0) level picked directly in the WebUI (charge_cool_level), used as-is
  _fl=$(num charge_cool_level 0)
  [ "$_fl" -ge "$_mx" ] && log "  charge_cool: level $_fl ignored (this charger has 0-$((_mx - 1)))"
  if [ "$_fl" -ge 1 ] && [ "$_fl" -lt "$_mx" ]; then
    _lv=$_fl; _how="chosen level"
    _m=$(sed -n "s/^$_fl=//p" "$_cal" 2>/dev/null | tail -n 1)
    case "$_m" in ''|*[!0-9]*) ;; *) _lua=$((_m * 1000)); _how="chosen level, measured" ;; esac
  fi
  # 1) measured table from the WebUI calibration (level=mA), most accurate
  if [ -z "$_lv" ] && [ -f "$_cal" ]; then
    _i=1
    while [ "$_i" -lt "$_mx" ]; do
      _m=$(sed -n "s/^$_i=//p" "$_cal" | tail -n 1)
      case "$_m" in ''|*[!0-9]*) ;; *)
        # ignore levels that (almost) stop charging
        if [ "$_m" -ge 300 ] && [ "$_m" -le "$_ma" ]; then _lv=$_i; _lua=$((_m * 1000)); break; fi ;;
      esac
      _i=$((_i + 1))
    done
    [ -n "$_lv" ] && _how="calibrated"
  fi
  # 2) current per level from the device tree (index 0 = no limit)
  if [ -z "$_lv" ]; then
    # exact property only (not *-step / wireless tables)
    _tf=$(find /proc/device-tree -name 'qcom,thermal-mitigation' 2>/dev/null | head -n 1)
    [ -n "$_tf" ] && _tbl=$(hc_dt_u32 "$_tf")
  fi
  if [ -z "$_lv" ] && [ -n "$_tbl" ]; then
    # qti_battery_charger: level 0 = no limit, DT element k = level k+1
    _i=0; _last=""; _lastua=""
    for _v in $_tbl; do
      _l=$((_i + 1))
      if [ "$_l" -lt "$_mx" ] && [ "$_v" -gt 0 ]; then
        _last=$_l; _lastua=$_v
        if [ -z "$_lv" ] && [ "$_v" -le "$_ua" ]; then _lv=$_l; _lua=$_v; fi
      fi
      _i=$((_i + 1))
    done
    # target below every non-zero level: use the lowest level that still charges
    [ -z "$_lv" ] && { _lv=$_last; _lua=$_lastua; }
    _how="DT table"
  fi
  if [ -z "$_lv" ]; then
    # no table: linear estimate between ~12 A (level 0) and level max-1.
    # Matches marble measurements (level 8 ~5.5 A, level 9 ~3.8 A); Calibrate is exact.
    _lv=$(( (12000 - _ma) * (_mx - 1) / 11500 ))
    [ "$_lv" -lt 1 ] && _lv=1
    _how="estimate - run Calibrate in the WebUI for exact mA"
  fi
  [ "$_lv" -ge "$_mx" ] && [ -z "$_lua" ] && _lv=$((_mx - 1))

  wn "$_n" "$_lv"
  sleep 2
  _rb=$(rd "$_n")
  if [ "$HC_OK" -gt 0 ] && [ "$_rb" != "$_lv" ]; then
    st charge_cool failed "level $_lv written but reads $_rb (overridden by mi_thermald)"
    return
  fi
  fin charge_cool "thermal level $_lv/$_mx${_lua:+ = $((_lua / 1000)) mA} ($_how); mi_thermald may set a stricter level when hot"
}

# Xiaomi "night charging": the charger stops at ~80% while the flag is set.
# Tested on marble: works (current drops to 0 above 80%), but the driver resets the
# flag to 0 on every unplug, so a small keeper sets it again while a charger is connected.
# pid file survives reboots: only trust it when that pid really is the keeper
hc_watch_pid() {
  _wp=$(cat "$HC_DATA/chg_watch.pid" 2>/dev/null)
  case "$_wp" in ''|*[!0-9]*) return 1 ;; esac
  grep -q chg_watch "/proc/$_wp/cmdline" 2>/dev/null && echo "$_wp"
}
hc_watch_stop() {
  _wp=$(hc_watch_pid) && kill "$_wp" 2>/dev/null
  rm -f "$HC_DATA/chg_watch.pid"
}
f_charge_limit() {
  hc_watch_stop
  on charge_limit || { rm -f "$HC_DATA/chg_watch.state"; st charge_limit off; return; }
  cnt_reset
  _nc=""
  for _n in /sys/class/qcom-battery/night_charging /sys/class/power_supply/battery/night_charging; do
    [ -e "$_n" ] && { _nc=$_n; break; }
  done
  [ -n "$_nc" ] || { st charge_limit skipped "no night_charging node on this kernel"; return; }
  # writable at all? (the keeper only re-writes the same value)
  if ! { echo 1 > "$_nc"; } 2>/dev/null; then
    chmod 0664 "$_nc" 2>/dev/null
    { echo 1 > "$_nc"; } 2>/dev/null || { st charge_limit failed "${_nc#/sys/class/} rejected the write"; return; }
  fi
  rm -f "$HC_DATA/chg_watch.state"
  if command -v nice >/dev/null 2>&1; then
    nohup nice -n 19 sh "$MODDIR/common/chg_watch.sh" "$_nc" >/dev/null 2>&1 &
  else
    nohup sh "$MODDIR/common/chg_watch.sh" "$_nc" >/dev/null 2>&1 &
  fi
  _i=0
  while [ "$_i" -lt 5 ] && ! hc_watch_pid >/dev/null; do sleep 1; _i=$((_i + 1)); done
  if _wp=$(hc_watch_pid); then
    st charge_limit applied "${_nc#/sys/class/}=1 on every plug-in, stops at ~80% (keeper pid $_wp, checks every 15 s)"
  else
    st charge_limit failed "keeper did not start; flag only set until the next unplug"
  fi
}

# ================================================================ DRAIN (kernel)

f_cpu_idle() {
  on cpu_idle || { st cpu_idle off; return; }
  cnt_reset
  if on_qcom_ok; then
    [ -f /sys/module/qcom_lpm/parameters/sleep_disabled ] && wn /sys/module/qcom_lpm/parameters/sleep_disabled N
    [ -f /sys/module/lpm_levels/parameters/sleep_disabled ] && wn /sys/module/lpm_levels/parameters/sleep_disabled 0
  fi
  # MediaTek: generic cpuidle states below cover mtk-cpuidle / psci idle states
  _re=0
  for _s in /sys/devices/system/cpu/cpu*/cpuidle/state*/disable; do
    [ -f "$_s" ] || continue
    if [ "$(rd "$_s")" = "1" ]; then wn "$_s" 0 && _re=$((_re + 1)); fi
  done
  [ "$HC_OK" = 0 ] && [ "$HC_FAIL" = 0 ] && [ -d /sys/devices/system/cpu/cpu0/cpuidle ] && HC_OK=1
  fin cpu_idle "deep idle states verified, $_re re-enabled"
}

f_ufs_pm() {
  on ufs_pm || { st ufs_pm off; return; }
  cnt_reset
  for _u in /sys/devices/platform/soc/*.ufshc /sys/devices/platform/*.ufshc \
            /sys/devices/platform/soc/*.ufshci /sys/devices/platform/*.ufshci; do
    [ -d "$_u" ] || continue
    case "$_u" in *.ufshci) on_mtk_ok || continue ;; *) on_qcom_ok || continue ;; esac
    for _n in clkgate_enable clkscale_enable hibern8_on_idle_enable; do
      [ -f "$_u/$_n" ] && wn "$_u/$_n" 1
    done
  done
  fin ufs_pm "UFS clock gating / scaling / hibern8"
}

f_vm_tune() {
  on vm_tune || { st vm_tune off; return; }
  _wb=$(rng vm_writeback 3000 500 6000)
  _sti=$(rng vm_stat_interval 10 1 60)
  _dbr=$(rng vm_dirty_bg 10 0 50)
  _dr=$(rng vm_dirty 30 0 80)
  cnt_reset
  _v=/proc/sys/vm
  [ "$_wb" -gt 0 ] && wn "$_v/dirty_writeback_centisecs" "$_wb"
  [ "$_wb" -gt 0 ] && wn "$_v/dirty_expire_centisecs" "$_wb"
  [ "$_dbr" -gt 0 ] && wn "$_v/dirty_background_ratio" "$_dbr"
  [ "$_dr" -gt 0 ] && wn "$_v/dirty_ratio" "$_dr"
  [ "$_sti" -gt 0 ] && wn "$_v/stat_interval" "$_sti"
  fin vm_tune "writeback $((_wb / 100))s, dirty ${_dbr}/${_dr}%, vmstat ${_sti}s"
}

f_io_tune() {
  on io_tune || { st io_tune off; return; }
  cnt_reset
  for _q in /sys/block/sd*/queue /sys/block/mmcblk*/queue /sys/block/dm-*/queue; do
    [ -d "$_q" ] || continue
    [ -f "$_q/iostats" ] && wn "$_q/iostats" 0
    [ -f "$_q/add_random" ] && wn "$_q/add_random" 0
  done
  fin io_tune "I/O accounting & entropy sampling off"
}

f_debug_off() {
  on debug_off || { st debug_off off; return; }
  cnt_reset
  wn /proc/sys/kernel/printk "0 4 1 4"
  [ -f /proc/sys/kernel/printk_devkmsg ] && wn /proc/sys/kernel/printk_devkmsg off
  [ -f /proc/sys/kernel/sched_schedstats ] && wn /proc/sys/kernel/sched_schedstats 0
  [ -f /proc/sys/kernel/nmi_watchdog ] && wn /proc/sys/kernel/nmi_watchdog 0
  [ -f /proc/sys/kernel/perf_cpu_time_max_percent ] && wn /proc/sys/kernel/perf_cpu_time_max_percent 2
  [ -f /proc/sys/debug/exception-trace ] && wn /proc/sys/debug/exception-trace 0
  on_qcom_ok && for _n in /sys/module/subsystem_restart/parameters/enable_ramdumps \
            /sys/module/subsystem_restart/parameters/enable_mini_ramdumps; do
    [ -f "$_n" ] && wn "$_n" 0
  done
  # MediaTek: kernel printk to UART off, MTK scheduler / perf tracers off
  on_mtk_ok && [ -f /proc/mtprintk ] && { { echo 0 > /proc/mtprintk; } 2>/dev/null && cnt_ok; }
  on_mtk_ok && for _n in /sys/module/mtk_sched/parameters/debug /sys/kernel/fpsgo/common/fpsgo_debug; do
    [ -f "$_n" ] && wn "$_n" 0
  done
  for _t in /sys/kernel/tracing/tracing_on /sys/kernel/debug/tracing/tracing_on; do
    [ -f "$_t" ] && wn "$_t" 0
  done
  _dm=0
  for _d in /sys/module/*/parameters/debug_mask; do
    [ -f "$_d" ] || continue
    [ "$(rd "$_d")" = "0" ] && continue
    { echo 0 > "$_d"; } 2>/dev/null && _dm=$((_dm + 1))
  done
  fin debug_off "log/trace/ramdump quiet, $_dm debug masks cleared"
}

# Wakelocks that carry push messages, calls, alarms or connectivity: blocking them
# delays notifications, so they are always removed from the blocklist.
hc_wl_notify() {
  _lw=$(echo "$1" | tr '[:upper:]' '[:lower:]')
  case "$_lw" in
    *rx*|*ipa*|*wow*|*netmgr*|*netlink*|*rmnet*|*qmi*|*ril*|*radio*|*modem*|*ims*|\
    *alarm*|*timerfd*|*fcm*|*gcm*|*push*|*bluetooth*|*_bt_*|*powermanager*|\
    *wlan_wake*|*wlan_ctrl*|*data*|*sms*|*call*) return 0 ;;
  esac
  return 1
}

f_wakelock_block() {
  on wakelock_block || { st wakelock_block off; return; }
  cnt_reset
  _wl=""; _kept=""
  for _w in $(cfg wl_list "" | tr ';' ' '); do
    if hc_wl_notify "$_w"; then _kept="$_kept $_w"; else _wl="${_wl:+$_wl;}$_w"; fi
  done
  [ -n "$_kept" ] && log "  wakelock_block: never blocked (notification path):$_kept"
  if [ -z "$_wl" ]; then
    st wakelock_block skipped "nothing left to block after removing notification wakelocks"
    return
  fi
  for _n in /sys/class/misc/boeffla_wakelock_blocker/wakelock_blocker \
            /sys/devices/virtual/misc/boeffla_wakelock_blocker/wakelock_blocker; do
    if [ -f "$_n" ]; then wn "$_n" "$_wl"; break; fi
  done
  fin wakelock_block "blocked: $_wl${_kept:+; kept for notifications:$_kept}" "kernel has no wakelock blocker (boeffla) support"
}

# ================================================================ ROM helpers

# set_s <feature> <namespace> <key> <value>  (settings, original backed up once)
set_s() {
  if ! grep -q "^$1|settings|$2|$3|" "$HC_ROMBAK" 2>/dev/null; then
    # no backup = no change (settings service not ready)
    _old=$(settings get "$2" "$3" </dev/null 2>/dev/null) || { cnt_fail; return 1; }
    echo "$1|settings|$2|$3|${_old:-null}" >> "$HC_ROMBAK"
  fi
  if settings put "$2" "$3" "$4" </dev/null >/dev/null 2>&1; then cnt_ok; else cnt_fail; fi
}
# set_d <feature> <namespace> <key> <value>  (device_config)
set_d() {
  if ! grep -q "^$1|devcfg|$2|$3|" "$HC_ROMBAK" 2>/dev/null; then
    _old=$(device_config get "$2" "$3" </dev/null 2>/dev/null) || { cnt_fail; return 1; }
    echo "$1|devcfg|$2|$3|${_old:-null}" >> "$HC_ROMBAK"
  fi
  if device_config put "$2" "$3" "$4" </dev/null >/dev/null 2>&1; then cnt_ok; else cnt_fail; fi
}
# rec <feature> <type> <ns> <key> : record a change once
rec() {
  grep -q "^$1|$2|$3|$4|" "$HC_ROMBAK" 2>/dev/null || echo "$1|$2|$3|$4|-" >> "$HC_ROMBAK"
}
has_rec() { grep -q "^$1|$2|$3|$4|" "$HC_ROMBAK" 2>/dev/null; }
# recv <feature> <type> <ns> <key> <original value> : like rec, keeps the original value
recv() {
  grep -q "^$1|$2|$3|$4|" "$HC_ROMBAK" 2>/dev/null || echo "$1|$2|$3|$4|$5" >> "$HC_ROMBAK"
}
# mode word from "cmd appops get" output ("OP: ignore; time=..." -> ignore), default if none
hc_opmode() {
  _om=$(echo "$1" | sed -n 's/.*: *\([a-z][a-z]*\).*/\1/p' | head -n 1)
  case "$_om" in allow|ignore|deny|default|foreground|errored) echo "$_om" ;; *) echo default ;; esac
}

# SoC family for the module description: qcom | mtk | other
hc_soc_type() {
  # the manufacturer prop is the most reliable signal
  case "$(getprop ro.soc.manufacturer)" in
    [Mm]ediatek*|MediaTek*|MTK) echo mtk; return ;;
    QTI|[Qq]ualcomm*) echo qcom; return ;;
  esac
  _sm="$(getprop ro.soc.manufacturer) $(getprop ro.board.platform) $(getprop ro.hardware)"
  if [ -d /sys/class/kgsl/kgsl-3d0 ] || echo "$_sm" | grep -qiE 'qti|qualcomm|qcom|msm|sm[0-9]|sdm|kona|lahaina|taro|kalama|pineapple|parrot|crow|bengal|holi|lito|trinket'; then
    echo qcom
  elif [ -d /proc/ppm ] || [ -d /proc/perfmgr ] || echo "$_sm" | grep -qiE 'mediatek|mt[0-9]'; then
    echo mtk
  else
    echo other
  fi
}
# Qualcomm-only and MediaTek-only paths never run on the other SoC
[ -n "$HC_SOC" ] || HC_SOC=$(hc_soc_type)
on_qcom_ok() { [ "$HC_SOC" != mtk ]; }   # Qualcomm paths: skipped on MediaTek
on_mtk_ok() { [ "$HC_SOC" != qcom ]; }   # MediaTek paths: skipped on Qualcomm
hc_soc_label() {
  case "$(hc_soc_type)" in
    qcom) echo "Device Qualcomm✓/MediaTek" ;;
    mtk) echo "Device Qualcomm/MediaTek✓" ;;
    *) echo "Device Qualcomm/MediaTek" ;;
  esac
}

pkg_installed() { [ -n "$(pm path "$1" </dev/null 2>/dev/null)" ]; }
pkg_disabled() { pm list packages -d </dev/null 2>/dev/null | grep -qx "package:$1"; }
valid_pkg() { case "$1" in ''|*[!A-Za-z0-9._]*) return 1 ;; esac; return 0; }

# Re-enable/undo packages of feature $1 that are no longer in list $2
prune_pkgs() {
  _pl=",$2,"
  [ -f "$HC_ROMBAK" ] || return 0
  grep "^$1|" "$HC_ROMBAK" | cut -d'|' -f4 | sort -u | while read -r _p; do
    [ "$_p" = "-" ] && continue
    case "$_pl" in *",$_p,"*) ;; *) restore_feature "$1" "$_p"; log "$1: reverted $_p" ;; esac
  done
}

# Disable packages listed in $2 under feature $1 (only records what IT disabled)
apply_pkgs() {
  _feat=$1
  cnt_reset
  prune_pkgs "$_feat" "$2"
  _dis=0; _already=0; _miss=0
  for _p in $(echo "$2" | tr ',' ' '); do
    valid_pkg "$_p" || continue
    if ! pkg_installed "$_p"; then _miss=$((_miss + 1)); continue; fi
    if has_rec "$_feat" pkg - "$_p"; then
      pkg_disabled "$_p" || pm disable-user --user 0 "$_p" </dev/null >/dev/null 2>&1
      _already=$((_already + 1)); cnt_ok; continue
    fi
    if pkg_disabled "$_p"; then _already=$((_already + 1)); cnt_ok; continue; fi
    if pm disable-user --user 0 "$_p" </dev/null >/dev/null 2>&1; then
      rec "$_feat" pkg - "$_p"
      _dis=$((_dis + 1)); cnt_ok
    else
      cnt_fail
    fi
  done
  _d="$_dis newly disabled, $_already already disabled, $_miss not installed"
  fin "$_feat" "$_d" "$_d"
}

# ================================================================ ROM: protected apps

# System defaults that must never be restricted
hc_default_apps() {
  _dl=$(cmd telecom get-default-dialer </dev/null 2>/dev/null)
  _sm=$(settings get secure sms_default_application </dev/null 2>/dev/null)
  _im=$(settings get secure default_input_method </dev/null 2>/dev/null | sed 's#/.*##')
  _hm=$(cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME </dev/null 2>/dev/null | grep / | tail -n 1 | sed 's#/.*##')
  for _x in "$_dl" "$_sm" "$_im" "$_hm"; do
    [ -n "$_x" ] && [ "$_x" != "null" ] && printf '%s,' "$_x"
  done
}

f_protect_apps() {
  _list=$(cfg protect_pkgs "")
  if ! on protect_apps; then restore_feature protect_apps; st protect_apps off; return; fi
  cnt_reset
  prune_pkgs protect_apps "$_list"
  _wlout=$(dumpsys deviceidle whitelist </dev/null 2>/dev/null)
  _n=0; _miss=0; _as=0
  for _p in $(echo "$_list" | tr ',' ' '); do
    valid_pkg "$_p" || continue
    if ! pkg_installed "$_p"; then _miss=$((_miss + 1)); continue; fi
    # 1) Doze / battery-optimization whitelist (persistent, recorded only if we added it)
    if ! echo "$_wlout" | grep -q ",$_p,"; then
      if dumpsys deviceidle whitelist +"$_p" </dev/null >/dev/null 2>&1; then rec protect_apps wl - "$_p"; fi
    fi
    # 2) background execution appops
    for _op in RUN_ANY_IN_BACKGROUND RUN_IN_BACKGROUND WAKE_LOCK; do
      _cur=$(cmd appops get "$_p" "$_op" </dev/null 2>/dev/null)
      case "$_cur" in *allow*) ;; *)
        _om=$(hc_opmode "$_cur")
        cmd appops set "$_p" "$_op" allow </dev/null >/dev/null 2>&1 && recv protect_apps appop "$_op" "$_p" "$_om" ;;
      esac
    done
    # 3) HyperOS/MIUI autostart (MIUI app-op 10008) - best effort
    _cur=$(cmd appops get "$_p" 10008 </dev/null 2>&1)
    case "$_cur" in *allow*) _as=$((_as + 1)) ;; *)
      _om=$(hc_opmode "$_cur")
      if cmd appops set "$_p" 10008 allow </dev/null >/dev/null 2>&1; then
        recv protect_apps appop 10008 "$_p" "$_om"; _as=$((_as + 1))
      fi ;;
    esac
    # 4) keep in the ACTIVE standby bucket for this boot
    am set-inactive "$_p" false </dev/null >/dev/null 2>&1
    am set-standby-bucket "$_p" active </dev/null >/dev/null 2>&1
    _n=$((_n + 1)); cnt_ok
  done
  _d="$_n protected (Doze whitelist + background + autostart $_as), $_miss not installed"
  fin protect_apps "$_d" "$_d"
}

# is <pkg> protected (user list + system defaults)?
hc_is_protected() {
  case ",$HC_PROTECTED," in *",$1,"*) return 0 ;; esac
  return 1
}

f_app_bucket() {
  _lvl=$(num app_bucket 0)
  if [ "$_lvl" = 0 ]; then restore_feature app_bucket; st app_bucket off; return; fi
  case "$_lvl" in 1) _b=rare ;; *) _b=restricted ;; esac
  _sdk=$(getprop ro.build.version.sdk)
  [ "$_b" = restricted ] && [ "${_sdk:-0}" -lt 30 ] && _b=rare
  HC_PROTECTED="$(hc_default_apps)$(on protect_apps && cfg protect_pkgs ""),android,com.android.systemui,com.android.phone,com.google.android.gms"
  case "$_b" in rare) _bn=40 ;; *) _bn=45 ;; esac
  _bgb=""; on bg_block && _bgb=$(cfg bg_block_pkgs "")
  _all=$(am get-standby-bucket </dev/null 2>/dev/null)
  cnt_reset
  _c=0; _sk=0
  for _p in $(pm list packages -3 </dev/null 2>/dev/null | cut -d: -f2); do
    valid_pkg "$_p" || continue
    if hc_is_protected "$_p"; then
      has_rec app_bucket bucket - "$_p" && restore_feature app_bucket "$_p"
      _sk=$((_sk + 1)); continue
    fi
    # handled by "Block background apps"
    case ",$_bgb," in *",$_p,"*) has_rec app_bucket bucket - "$_p" && restore_feature app_bucket "$_p"; _sk=$((_sk + 1)); continue ;; esac
    _cur=$(echo "$_all" | sed -n "s/^$_p: *//p" | head -n 1 | tr -d '[:space:]')
    # 5 exempted, 10 active: leave alone; already at target: nothing to do
    case "$_cur" in 5|10|active|ACTIVE) _sk=$((_sk + 1)); continue ;; esac
    # already there (set by Android or by you): not recorded, so turning off leaves it alone
    if [ "$_cur" = "$_bn" ]; then cnt_ok; continue; fi
    if am set-standby-bucket "$_p" "$_b" </dev/null >/dev/null 2>&1; then
      recv app_bucket bucket - "$_p" "$_cur"; _c=$((_c + 1)); cnt_ok
    fi
  done
  _d="$_c apps -> $_b bucket, $_sk protected/active skipped"
  fin app_bucket "$_d" "$_d"
}

# ================================================================ ROM: background-blocked apps
# Picked apps get no background execution: Android "Restricted" battery mode
# (RUN_ANY_IN_BACKGROUND / RUN_IN_BACKGROUND ignore), wakelocks ignored, removed from the
# user Doze whitelist, Xiaomi autostart off, Restricted standby bucket, and force-stopped
# at boot (stopped state: no alarms, jobs or broadcasts until you open the app).
# Protected apps and system defaults always win. Every change is recorded and undone.
HC_BGB_NEVER="android,com.android.systemui,com.android.phone,com.android.settings,com.google.android.gms,com.google.android.gsf,com.xiaomi.xmsf,com.miui.securitycenter,com.miui.powerkeeper,com.miui.home,me.weishu.kernelsu,com.rifsxd.ksunext,com.topjohnwu.magisk,me.bmax.apatch"
# "Bucket: 10" / "10" / "rare" -> number (empty when unknown)
hc_bucket_num() {
  _bv=$(echo "$1" | tr -d '[:space:]'); _bv=${_bv##*:}
  case "$_bv" in
    active|ACTIVE) echo 10 ;; working_set|WORKING_SET) echo 20 ;; frequent|FREQUENT) echo 30 ;;
    rare|RARE) echo 40 ;; restricted|RESTRICTED) echo 45 ;;
    ''|*[!0-9]*) echo "" ;; *) echo "$_bv" ;;
  esac
}
# packages bound by the system right now (accessibility, notification listeners, always-on VPN)
hc_bound_apps() {
  for _k in enabled_accessibility_services enabled_notification_listeners; do
    settings get secure "$_k" </dev/null 2>/dev/null | tr ':' '\n' | sed -n 's#^\([A-Za-z0-9._]*\)/.*#\1#p'
  done | sort -u | tr '\n' ','
  _vpn=$(settings get secure always_on_vpn_app </dev/null 2>/dev/null)
  [ -n "$_vpn" ] && [ "$_vpn" != null ] && printf '%s,' "$_vpn"
}
f_bg_block() {
  _list=$(cfg bg_block_pkgs "")
  if ! on bg_block || [ -z "$_list" ]; then
    restore_feature bg_block
    if on bg_block; then st bg_block off "no apps picked"; else st bg_block off; fi
    return
  fi
  cnt_reset
  prune_pkgs bg_block "$_list"
  HC_PROTECTED="$(hc_default_apps)$(hc_bound_apps)$(on protect_apps && cfg protect_pkgs ""),$HC_BGB_NEVER"
  _sdk=$(getprop ro.build.version.sdk)
  _wlout=$(dumpsys deviceidle whitelist </dev/null 2>/dev/null)
  _n=0; _sk=0; _miss=0
  for _p in $(echo "$_list" | tr ',' ' '); do
    valid_pkg "$_p" || continue
    if ! pkg_installed "$_p"; then _miss=$((_miss + 1)); continue; fi
    if hc_is_protected "$_p"; then
      restore_feature bg_block "$_p"; _sk=$((_sk + 1)); continue
    fi
    # 1) user battery-optimization whitelist entry (system entries are left alone)
    if echo "$_wlout" | grep -q "^user,$_p,"; then
      dumpsys deviceidle whitelist -"$_p" </dev/null >/dev/null 2>&1 && rec bg_block uwl - "$_p"
    fi
    # 2) background execution + wakelocks
    for _op in RUN_ANY_IN_BACKGROUND RUN_IN_BACKGROUND WAKE_LOCK; do
      _cur=$(cmd appops get "$_p" "$_op" </dev/null 2>/dev/null)
      case "$_cur" in *ignore*) ;; *)
        _om=$(hc_opmode "$_cur")
        if cmd appops set "$_p" "$_op" ignore </dev/null >/dev/null 2>&1; then
          recv bg_block appop "$_op" "$_p" "$_om"
        else
          cnt_fail
        fi ;;
      esac
    done
    # 3) HyperOS/MIUI autostart (MIUI app-op 10008) - best effort
    _cur=$(cmd appops get "$_p" 10008 </dev/null 2>&1)
    case "$_cur" in *ignore*|*deny*) ;; *)
      _om=$(hc_opmode "$_cur")
      cmd appops set "$_p" 10008 ignore </dev/null >/dev/null 2>&1 && recv bg_block appop 10008 "$_p" "$_om" ;;
    esac
    # 4) Restricted standby bucket (Android 11+), Rare on older
    if [ "${_sdk:-0}" -ge 30 ]; then _b=restricted; else _b=rare; fi
    # app_bucket may have moved it already: give that back first so the real original is recorded
    has_rec app_bucket bucket - "$_p" && restore_feature app_bucket "$_p"
    _ob=$(hc_bucket_num "$(am get-standby-bucket "$_p" </dev/null 2>/dev/null)")
    am set-standby-bucket "$_p" "$_b" </dev/null >/dev/null 2>&1 && recv bg_block bucket - "$_p" "$_ob"
    # 5) stop it now: stays stopped (no alarms/jobs/broadcasts) until opened
    am force-stop "$_p" </dev/null >/dev/null 2>&1
    _n=$((_n + 1)); cnt_ok
  done
  _d="$_n apps blocked in background, $_sk protected skipped, $_miss not installed"
  fin bg_block "$_d" "$_d"
}

# ================================================================ ROM: HyperOS

f_app_freezer() {
  on app_freezer || { restore_feature app_freezer; st app_freezer off; return; }
  cnt_reset
  set_s app_freezer global cached_apps_freezer enabled
  set_d app_freezer activity_manager_native_boot use_freezer true
  fin app_freezer "cached apps are frozen (0% CPU)"
}

DOZE_MODERATE="light_after_inactive_to=180000,light_pre_idle_to=180000,light_idle_to=900000,light_max_idle_to=1800000,inactive_to=600000,sensing_to=0,locating_to=0,motion_inactive_to=0,idle_after_inactive_to=0,quick_doze_delay_to=60000"
DOZE_AGGRESSIVE="light_after_inactive_to=15000,light_pre_idle_to=30000,light_idle_to=900000,light_max_idle_to=1800000,inactive_to=60000,sensing_to=0,locating_to=0,motion_inactive_to=0,idle_after_inactive_to=0,idle_pending_to=60000,quick_doze_delay_to=15000,idle_to=3600000,max_idle_to=21600000"
DOZE_MAXIMUM="light_after_inactive_to=0,light_pre_idle_to=5000,light_idle_to=3600000,light_max_idle_to=43200000,inactive_to=30000,sensing_to=0,locating_to=0,motion_inactive_to=0,idle_after_inactive_to=0,idle_pending_to=60000,quick_doze_delay_to=5000,idle_to=21600000,max_idle_to=172800000"

f_doze_aggr() {
  _lvl=$(num doze_aggr 0)
  if [ "$_lvl" = 0 ]; then restore_feature doze_aggr; st doze_aggr off; return; fi
  case "$_lvl" in
    1) _c=$DOZE_MODERATE; _nm=moderate ;;
    3) _c=$DOZE_MAXIMUM; _nm=maximum ;;
    4) _c=$(cfg doze_custom "$DOZE_AGGRESSIVE"); _nm=custom ;;
    *) _c=$DOZE_AGGRESSIVE; _nm=aggressive ;;
  esac
  _c=$(echo "$_c" | tr -d ' \t\r')
  # a level change must start from the original values again
  _prev=$(sed -n 's/^doze_aggr|meta|-|level|//p' "$HC_ROMBAK" 2>/dev/null | tail -n 1)
  if [ -n "$_prev" ] && [ "$_prev" != "$_nm:$_c" ]; then restore_feature doze_aggr; fi
  cnt_reset
  for _kv in $(echo "$_c" | tr ',' ' '); do
    _key=${_kv%%=*}; _val=${_kv#*=}
    case "$_key" in ''|*[!a-z_]*) continue ;; esac
    case "$_val" in ''|*[!0-9.]*) continue ;; esac
    set_d doze_aggr device_idle "$_key" "$_val"
  done
  # Android <= 11 and some ROMs still read the global string
  set_s doze_aggr global device_idle_constants "$_c"
  sed -i '/^doze_aggr|meta|/d' "$HC_ROMBAK" 2>/dev/null
  echo "doze_aggr|meta|-|level|$_nm:$_c" >> "$HC_ROMBAK"
  dumpsys deviceidle enable all </dev/null >/dev/null 2>&1
  fin doze_aggr "$_nm profile"
}

f_devcfg_lock() {
  if ! on devcfg_lock; then restore_feature devcfg_lock; st devcfg_lock off; return; fi
  cnt_reset
  if ! grep -q "^devcfg_lock|sync|" "$HC_ROMBAK" 2>/dev/null; then
    _cur=$(device_config get_sync_disabled_for_tests </dev/null 2>/dev/null)
    case "$_cur" in none|persistent|until_reboot) ;; *) _cur=none ;; esac
    echo "devcfg_lock|sync|-|-|$_cur" >> "$HC_ROMBAK"
  fi
  if device_config set_sync_disabled_for_tests persistent </dev/null >/dev/null 2>&1; then cnt_ok; else cnt_fail; fi
  fin devcfg_lock "server flag sync paused (keeps doze/freezer values)"
}

# GMS was removed from the system whitelist earlier (saved by Android in deviceidle.xml)?
hc_gms_unwl() { grep -q 'un-wl n="com.google.android.gms"' /data/system/deviceidle.xml 2>/dev/null; }

f_gms_doze_verify() {
  _g=com.google.android.gms
  if ! on gms_doze; then
    # Android keeps sys-whitelist removals across reboots, so they must be undone explicitly.
    if ! has_rec gms_doze syswl - "$_g" && hc_gms_unwl && \
       [ "$(sed -n 's/^gms_doze=//p' "$HC_DATA/last_applied.conf" 2>/dev/null)" = 1 ]; then
      # removed by an older MkVenomPro Optimizer build that did not record it
      dumpsys deviceidle sys-whitelist +"$_g" </dev/null >/dev/null 2>&1
      log "gms_doze: GMS returned to the system Doze whitelist (unrecorded removal)"
    fi
    restore_feature gms_doze
    return
  fi
  _mounted=none
  _gen=$(find "$MODDIR/system" -name '*.xml' 2>/dev/null | head -n 1)
  if [ -n "$_gen" ]; then
    _rel=${_gen#"$MODDIR"/system}
    case "$_rel" in /product/*|/system_ext/*) _live=$_rel ;; *) _live=/system$_rel ;; esac
    if grep -q "allow-in-power-save package=\"$_g\"" "$_live" 2>/dev/null; then _mounted=no; else _mounted=yes; fi
  fi
  # Removal from the SYSTEM whitelist. Android saves it in /data/system/deviceidle.xml
  # (survives reboots), so it is recorded and undone when the switch goes off / on uninstall.
  _wlo=$(dumpsys deviceidle whitelist </dev/null 2>/dev/null)
  if echo "$_wlo" | grep -q "^system,$_g,"; then
    dumpsys deviceidle sys-whitelist -"$_g" </dev/null >/dev/null 2>&1 && rec gms_doze syswl - "$_g"
  elif hc_gms_unwl && ! has_rec gms_doze syswl - "$_g"; then
    # already removed (older build of this module): record it so it can be undone
    rec gms_doze syswl - "$_g"
  fi
  # user battery-optimization whitelist: only touched (and recorded) if GMS is in it
  if echo "$_wlo" | grep -q "^user,$_g,"; then
    dumpsys deviceidle whitelist -"$_g" </dev/null >/dev/null 2>&1 && rec gms_doze uwl - "$_g"
  fi
  if dumpsys deviceidle whitelist </dev/null 2>/dev/null | grep -q "^system,$_g,"; then
    _rt=no
  else
    _rt=yes
  fi
  if [ "$_rt" = yes ]; then
    case "$_mounted" in
      yes) _d="overlay mounted + removed from the system whitelist" ;;
      *) _d="removed from the system Doze whitelist (restored when turned off)" ;;
    esac
    _state=applied
  elif [ "$_mounted" = yes ]; then
    _d="overlay mounted"; _state=applied
  else
    _d="GMS still in the system whitelist (sys-whitelist rejected, overlay not mounted)"; _state=failed
  fi
  sed -i "/^gms_doze=/d" "$HC_STATUS"
  st gms_doze "$_state" "$_d"
}

f_scan_off() {
  on scan_off || { restore_feature scan_off; st scan_off off; return; }
  cnt_reset
  set_s scan_off global wifi_scan_always_enabled 0
  set_s scan_off global ble_scan_always_enabled 0
  set_s scan_off global wifi_scan_throttle_enabled 1
  fin scan_off "Wi-Fi/Bluetooth background scanning off"
}

f_net_save() {
  on net_save || { restore_feature net_save; st net_save off; return; }
  cnt_reset
  set_s net_save global mobile_data_always_on 0
  set_s net_save global network_recommendations_enabled 0
  set_s net_save global wifi_wakeup_enabled 0
  fin net_save "mobile data no longer kept alive on Wi-Fi"
}

f_standby() {
  on standby || { restore_feature standby; st standby off; return; }
  cnt_reset
  set_s standby global app_standby_enabled 1
  set_s standby global adaptive_battery_management_enabled 1
  set_s standby global forced_app_standby_enabled 1
  set_s standby global app_auto_restriction_enabled 1
  fin standby "App Standby buckets & auto restriction enforced"
}

f_stats_reduce() {
  on stats_reduce || { restore_feature stats_reduce; st stats_reduce off; return; }
  cnt_reset
  set_s stats_reduce global battery_stats_constants "track_cpu_times_by_proc_state=false,track_cpu_active_cluster_time=false,read_binary_cpu_time=false,kernel_uid_readers_throttle_time=2000,external_stats_collection_rate_limit_ms=1200000,battery_level_collection_delay_ms=600000,procstate_change_collection_delay_ms=120000"
  set_s stats_reduce global binder_calls_stats "sampling_interval=600000000,detailed_tracking=disable,enabled=false,upload_data=false"
  set_s stats_reduce global looper_stats "enabled=false"
  set_d stats_reduce interaction_jank_monitor enabled false
  set_d stats_reduce activity_manager disable_app_profiler_pss_profiling true
  fin stats_reduce "less stats collection, jank monitor & PSS profiling off"
}

f_tracking_off() {
  on tracking_off || { restore_feature tracking_off; st tracking_off off; return; }
  cnt_reset
  for _k in network_watchlist_enabled tron_enabled gmscorestat_enabled clearcut_enabled \
            analytics_enabled uploading_enabled ga_collection_enabled; do
    set_s tracking_off global "$_k" 0
  done
  set_s tracking_off global limit_ad_tracking 1
  fin tracking_off "telemetry/upload switches off"
}

f_debloat() {
  if ! on debloat; then restore_feature debloat; st debloat off; return; fi
  apply_pkgs debloat "$(cfg debloat_pkgs "")"
}

f_joyose_off() {
  if ! on joyose_off; then restore_feature joyose_off; st joyose_off off; return; fi
  apply_pkgs joyose_off com.xiaomi.joyose
}

# ================================================================ LONG BATTERY

# Both Android 12+ keys and legacy keys; unknown keys are ignored by the parser.
SAVER_BALANCED="advertise_is_enabled=true,enable_datasaver=false,disable_launch_boost=true,disable_vibration=true,disable_animation=false,soundtrigger_mode=1,defer_full_backup=true,defer_keyvalue_backup=true,enable_firewall=true,location_mode=3,enable_brightness_adjustment=false,force_all_apps_standby=true,force_background_check=true,disable_optional_sensors=true,disable_aod=true,enable_quick_doze=true,enable_night_mode=true,datasaver_disabled=true,launch_boost_disabled=true,vibration_disabled=true,animation_disabled=false,soundtrigger_disabled=true,fullbackup_deferred=true,keyvaluebackup_deferred=true,firewall_disabled=false,gps_mode=3,adjust_brightness_disabled=true,optional_sensors_disabled=true,aod_disabled=true,quick_doze_enabled=true"
SAVER_EXTREME="advertise_is_enabled=true,enable_datasaver=false,disable_launch_boost=true,disable_vibration=true,disable_animation=true,soundtrigger_mode=2,defer_full_backup=true,defer_keyvalue_backup=true,enable_firewall=true,location_mode=2,enable_brightness_adjustment=true,adjust_brightness_factor=0.8,force_all_apps_standby=true,force_background_check=true,disable_optional_sensors=true,disable_aod=true,enable_quick_doze=true,enable_night_mode=true,datasaver_disabled=true,launch_boost_disabled=true,vibration_disabled=true,animation_disabled=true,soundtrigger_disabled=true,fullbackup_deferred=true,keyvaluebackup_deferred=true,firewall_disabled=false,gps_mode=2,adjust_brightness_disabled=false,optional_sensors_disabled=true,aod_disabled=true,quick_doze_enabled=true"

f_saver_policy() {
  _lvl=$(num saver_policy 0)
  if [ "$_lvl" = 0 ]; then restore_feature saver_policy; st saver_policy off; return; fi
  case "$_lvl" in
    2) _c=$SAVER_EXTREME; _nm=extreme ;;
    3) _c=$(cfg saver_constants "$SAVER_BALANCED"); _nm=custom ;;
    *) _c=$SAVER_BALANCED; _nm=balanced ;;
  esac
  case "$_c" in *[!A-Za-z0-9_=.,-]*) _c=$SAVER_BALANCED; _nm="balanced (custom string rejected)" ;; esac
  cnt_reset
  set_s saver_policy global battery_saver_constants "$_c"
  fin saver_policy "$_nm rules while Battery Saver is ON"
}

f_saver_trigger() {
  _lvl=$(rng saver_trigger 0 5 95)
  [ "$_lvl" = 0 ] && { restore_feature saver_trigger; st saver_trigger off; return; }
  cnt_reset
  set_s saver_trigger global automatic_power_save_mode 0
  set_s saver_trigger global low_power_trigger_level "$_lvl"
  fin saver_trigger "auto Battery Saver at ${_lvl}%"
}

f_refresh_rate() {
  _hz=$(rng refresh_rate 0 30 165)
  [ "$_hz" = 0 ] && { restore_feature refresh_rate; st refresh_rate off; return; }
  cnt_reset
  set_s refresh_rate system peak_refresh_rate "$_hz.0"
  if [ "$_hz" -lt 60 ]; then
    set_s refresh_rate system min_refresh_rate "$_hz.0"
  else
    # an earlier cap below 60 Hz lowered min_refresh_rate: give it back
    restore_feature refresh_rate min_refresh_rate
  fi
  set_s refresh_rate secure user_refresh_rate "$_hz"
  set_s refresh_rate secure miui_refresh_rate "$_hz"
  fin refresh_rate "peak ${_hz}Hz"
}

f_anim_scale() {
  _a=$(rng anim_scale 0 10 100)
  [ "$_a" = 0 ] && { restore_feature anim_scale; st anim_scale off; return; }
  if [ "$_a" -ge 100 ]; then _s=1.0; else _s=0.$(printf '%02d' "$_a" | sed 's/0$//'); fi
  cnt_reset
  set_s anim_scale global window_animation_scale "$_s"
  set_s anim_scale global transition_animation_scale "$_s"
  set_s anim_scale global animator_duration_scale "$_s"
  fin anim_scale "animation scale ${_s}x"
}

# ================================================================ MORE tab
# Extra features (safe ones default ON). Definitions live in common/xfeatures.sh.
. "${MODDIR:-/data/adb/mkvp/engine/thermal}/common/xfeatures.sh"
