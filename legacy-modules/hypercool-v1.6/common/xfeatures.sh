#!/system/bin/sh
# HyperCool - "More" features (safe ones default ON).
# Everything here follows HyperCool rules: one-shot at boot, kernel values reset
# on reboot, every settings/device_config/package change is recorded in rom.bak
# and restored when the switch goes off or the module is removed.
# This file is sourced by common/functions.sh; it uses its helpers.

HC_XLISTS=${MODDIR:-/data/adb/modules/hypercool}/common

# apply_list <file> : write every "path|value" line, counted by wn()
apply_list() {
  [ -f "$1" ] || return 1
  while IFS= read -r _ln; do
    case "$_ln" in ''|'#'*) continue ;; esac
    _p=${_ln%%\|*}
    _v=${_ln#*\|}
    [ -n "$_p" ] && [ "$_p" != "$_v" ] || continue
    # vendor-specific nodes only on their own SoC family
    case "$_p" in *qcom*|*msm_*) on_qcom_ok || continue ;; *mtk*|*mediatek*) on_mtk_ok || continue ;; esac
    wn "$_p" "$_v"
  done < "$1"
}

# apply_props_file <file> [persist-only] : like hc_props but reads prop=value lines
apply_props_file() {
  [ -f "$1" ] || { echo 0; return; }
  _pc=0
  while IFS= read -r _ln; do
    case "$_ln" in ''|'#'*) continue ;; esac
    case "$_ln" in *=*) ;; *) continue ;; esac
    if [ "$2" = persist ]; then case "$_ln" in persist.*) ;; *) continue ;; esac; fi
    resetprop -n "${_ln%%=*}" "${_ln#*=}" 2>/dev/null && _pc=$((_pc + 1))
  done < "$1"
  echo "$_pc"
}

# ================================================================ MORE: kernel

# x_sched - scheduler, governor and schedtune tuning
f_x_sched() {
  on x_sched || { st x_sched off; return; }
  cnt_reset
  apply_list "$HC_XLISTS/x_kernel_list.txt"
  # governor rate limits (one 5 ms scheduling period)
  for _g in /sys/devices/system/cpu/cpufreq/policy*/schedutil \
            /sys/devices/system/cpu/cpu*/cpufreq/schedutil \
            /sys/devices/system/cpu/cpufreq/policy*/sugov_ext; do
    [ -d "$_g" ] || continue
    case "$_g" in */sugov_ext) on_mtk_ok || continue ;; esac
    # slower ramp-up only; a long down limit would keep clocks high (more drain)
    # "Calmer CPU governor" owns up_rate_limit_us when it is on
    [ -f "$_g/up_rate_limit_us" ] && ! on walt_tune && wn "$_g/up_rate_limit_us" 5000
    [ -f "$_g/hispeed_load" ] && wn "$_g/hispeed_load" 99
  done
  for _g in /sys/devices/system/cpu/cpufreq/policy*/interactive \
            /sys/devices/system/cpu/cpu*/cpufreq/interactive; do
    [ -d "$_g" ] || continue
    [ -f "$_g/go_hispeed_load" ] && wn "$_g/go_hispeed_load" 99
  done
  # schedtune: no foreground boost, no idle preference on top-app
  if [ -d /dev/stune/top-app ]; then
    wn /dev/stune/top-app/schedtune.prefer_idle 0
    wn /dev/stune/top-app/schedtune.boost 0
  fi
  fin x_sched "scheduler, governor and schedtune tuned" "no CFS/schedutil/schedtune tunables (WALT kernel: use Calmer CPU governor)"
}

# x_kquiet - leftover kernel logging/dumps
f_x_kquiet() {
  on x_kquiet || { st x_kquiet off; return; }
  cnt_reset
  apply_list "$HC_XLISTS/x_quiet_list.txt"
  for _p in /sys/devices/platform/*/snapshot_crashdumper; do
    [ -e "$_p" ] && wn "$_p" 0
  done
  for _p in /sys/module/*/parameters/qdf_log_dump_at_kernel_enable; do
    [ -e "$_p" ] && wn "$_p" N
  done
  for _p in /sys/fs/f2fs/*/iostat_enable; do
    [ -e "$_p" ] && wn "$_p" 0
  done
  fin x_kquiet "EDAC/BPF/ramdump/crash dumper output off"
}

# x_net - network stack tuning
f_x_net() {
  on x_net || { st x_net off; return; }
  cnt_reset
  apply_list "$HC_XLISTS/x_net_list.txt"
  fin x_net "TCP slow-start/metrics/FastOpen and inotify limits tuned"
}

# x_io - extra block queue tuning
f_x_io() {
  on x_io || { st x_io off; return; }
  cnt_reset
  for _b in /sys/block/*; do
    [ -d "$_b/queue" ] || continue
    case "${_b##*/}" in
      sd*|mmcblk*|nvme*)
        wn "$_b/queue/nomerges" 0
        wn "$_b/queue/rq_affinity" 1 ;;
    esac
  done
  fin x_io "nomerges/rq_affinity tuned"
}

# x_xiaomi_fw - Xiaomi MiGT/Metis boost frameworks off
f_x_xiaomi_fw() {
  on x_xiaomi_fw || { st x_xiaomi_fw off; return; }
  cnt_reset
  if [ -d /sys/module/migt ]; then
    wn /proc/sys/migt/enable_pkg_monitor 0
    wn /sys/module/migt/parameters/enable_pkg_monitor 0
    wn /sys/module/migt/parameters/glk_freq_limit_walt 0
    wn /sys/module/migt/parameters/boost_policy 0
    wn /sys/module/migt/parameters/glk_disable 1
    wn /sys/module/migt/parameters/force_stask_to_big 0
  fi
  if [ -d /sys/module/metis ]; then
    wn /sys/module/metis/parameters/suspend_vip_enable 0
    wn /sys/module/metis/parameters/mi_link_enable 0
    wn /sys/module/metis/parameters/mi_switch_enable 0
  fi
  fin x_xiaomi_fw "MiGT/Metis boost frameworks off" "MiGT/Metis not present on this device"
}

# ================================================================ MORE: RAM

# ro.lmk.* props: resetprop without -p is runtime only, the ROM values return on reboot
# (older builds deleted them on uninstall, which removed the ROM's own lmkd tuning)
x_set_prop_persist() {
  resetprop -n "$1" "$2" 2>/dev/null
}

# x_ram_opt - RAM optimizer: VM list, zram, LMK/minfree, lmkd, reclaim
f_x_ram_opt() {
  if ! on x_ram_opt; then
    restore_feature x_ram_opt
    rm -f "$HC_DATA/persist_props"
    st x_ram_opt off
    return
  fi
  cnt_reset
  _lvl=$(cfg x_ram_level 1)
  if [ "$_lvl" = 2 ]; then _lvlname=maximum; else _lvl=1; _lvlname=moderate; fi

  apply_list "$HC_XLISTS/x_ram_vm.txt"

  _tk=$(awk '/MemTotal/{print $2}' /proc/meminfo 2>/dev/null)
  _tk=${_tk:-0}

  # memory management flags (recorded, restored when the switch goes off)
  _sdk=$(getprop ro.build.version.sdk)
  if [ "${_sdk:-0}" -ge 30 ]; then
    set_d x_ram_opt runtime_native usap_pool_enabled false
  fi
  set_d x_ram_opt activity_manager use_compaction true

  # classic LMK minfree, scaled to RAM size and level
  if [ -f /sys/module/lowmemorykiller/parameters/minfree ]; then
    _p=$(( _tk / 4 ))
    if [ "$_lvl" = 2 ]; then
      _f1=$(( _p * 25 / 1000 )); _f2=$(( _p * 3 / 100 )); _f3=$(( _p * 4 / 100 ))
      _f4=$(( _p * 5 / 100 ));  _f5=$(( _p * 6 / 100 )); _f6=$(( _p * 8 / 100 ))
    else
      _f1=$(( _p * 15 / 1000 )); _f2=$(( _p / 50 ));       _f3=$(( _p * 25 / 1000 ))
      _f4=$(( _p * 3 / 100 ));   _f5=$(( _p * 35 / 1000 )); _f6=$(( _p / 20 ))
    fi
    wn /sys/module/lowmemorykiller/parameters/minfree \
      "$((_f1/4)),$((_f2/4)),$((_f3/4)),$((_f4/4)),$((_f5/4)),$((_f6/4))"
  fi

  # lmkd props (persistent -> tracked in $HC_DATA/persist_props, deleted on off/uninstall).
  # Classic in-kernel LMK is handled by minfree above; on lmkd systems tune ro.lmk.* instead.
  if [ ! -f /sys/module/lowmemorykiller/parameters/minfree ]; then
    if [ "$_lvl" = 2 ]; then
      x_set_prop_persist ro.lmk.low 900
      x_set_prop_persist ro.lmk.medium 600
    else
      x_set_prop_persist ro.lmk.low 1001
      x_set_prop_persist ro.lmk.medium 900
    fi
    x_set_prop_persist ro.lmk.critical 0
    if [ -f /proc/pressure/memory ]; then
      x_set_prop_persist ro.lmk.use_psi true
      if [ "$_lvl" = 2 ]; then
        x_set_prop_persist ro.lmk.psi_partial_stall_ms 70
        x_set_prop_persist ro.lmk.psi_complete_stall_ms 500
        x_set_prop_persist ro.lmk.thrashing_limit 60
        x_set_prop_persist ro.lmk.swap_util_max 80
        x_set_prop_persist ro.lmk.kill_heaviest_task true
      else
        x_set_prop_persist ro.lmk.psi_partial_stall_ms 200
        x_set_prop_persist ro.lmk.psi_complete_stall_ms 800
        x_set_prop_persist ro.lmk.thrashing_limit 100
        x_set_prop_persist ro.lmk.swap_util_max 100
        x_set_prop_persist ro.lmk.kill_heaviest_task false
      fi
    else
      x_set_prop_persist ro.lmk.use_psi false
    fi
    # lmkd reloads its props on reinit (Android 11+); SIGHUP would just kill it
    setprop lmkd.reinit 1 2>/dev/null
  fi

  # vendor memory-reclaim frameworks off
  for _n in /sys/module/process_reclaim/parameters/enable_process_reclaim \
            /sys/kernel/mi_reclaim/enable \
            /sys/kernel/mi_reclaim/greclaim_enable \
            /sys/kernel/low_free/low_free_enable \
            /sys/module/memplus_core/parameters/memory_plus_enabled \
            /proc/sys/vm/memory_plus \
            /sys/module/perfmgr/parameters/perfmgr_enable \
            /sys/module/opchain/parameters/opchain_enable; do
    [ -e "$_n" ] && wn "$_n" 0
  done

  fin x_ram_opt "VM/zram/LMK tuned for $_lvlname ($((_tk / 1024)) MB RAM)"
}

# x_multitask - cached-process limits profile
f_x_multitask() {
  _mt=$(cfg x_multitask 0)
  if [ "$_mt" = 0 ]; then
    if grep -q '^x_multitask|' "$HC_ROMBAK" 2>/dev/null; then
      restore_feature x_multitask
      cmd activity memory-factor reset </dev/null >/dev/null 2>&1
    fi
    rm -f "$HC_DATA/x_multitask.base"
    st x_multitask off
    return
  fi
  case "$_mt" in
    1) _mult=100; _mname=balanced ;;
    2) _mult=125; _mname=performance ;;
    3) _mult=75;  _mname=low-ram ;;
    *) st x_multitask skipped "unknown level $_mt"; return ;;
  esac
  cnt_reset
  # "dumpsys activity settings" lists "  max_cached_processes=32" (+ upper-case
  # internal CUR_* values that are not device_config keys)
  _cur=$(dumpsys activity settings </dev/null 2>/dev/null | sed -n 's/^ *max_cached_processes=\([0-9][0-9]*\).*/\1/p' | head -n 1)
  # stock value saved on the first run, so levels never compound across boots
  _base=$(cat "$HC_DATA/x_multitask.base" 2>/dev/null)
  case "$_base" in ''|*[!0-9]*) _base=$_cur; [ -n "$_base" ] && echo "$_base" > "$HC_DATA/x_multitask.base" ;; esac
  if [ -n "$_base" ]; then
    _nv=$(( _base * _mult / 100 )); [ "$_nv" -lt 8 ] && _nv=8
    if [ "$_mult" = 100 ]; then
      # Balanced = stock: give back any earlier value instead of pinning the stock one
      restore_feature x_multitask; cnt_ok
    else
      set_d x_multitask activity_manager max_cached_processes "$_nv"
    fi
  fi
  cmd activity memory-factor reset </dev/null >/dev/null 2>&1
  fin x_multitask "max_cached_processes ${_base:-?} -> ${_nv:-?} ($_mname)" "max_cached_processes not reported by this ROM"
}

# ================================================================ MORE: Google

# x_gms_freeze - disable the safe ads/tracking/analytics GMS components
f_x_gms_freeze() {
  if ! on x_gms_freeze; then
    restore_feature x_gms_freeze
    st x_gms_freeze off
    return
  fi
  cnt_reset
  # components dropped from the list (or from an older list) are enabled again
  prune_pkgs x_gms_freeze "$(grep -v '^#' "$HC_XLISTS/x_gms_safe.txt" | tr '\n' ',')"
  _dis=0; _alr=0; _miss=0
  # components already disabled (by you or another module) are left alone and not recorded
  _dcf=$HC_DATA/.gms_disabled
  dumpsys package com.google.android.gms </dev/null 2>/dev/null | \
    sed -n '/disabledComponents:/,/enabledComponents:/p' > "$_dcf"
  while IFS= read -r _c; do
    case "$_c" in ''|'#'*) continue ;; esac
    _pk=${_c%%/*}
    if ! pkg_installed "$_pk"; then _miss=$((_miss + 1)); continue; fi
    if pkg_disabled "$_pk"; then _alr=$((_alr + 1)); continue; fi
    if has_rec x_gms_freeze pkg - "$_c"; then
      pm disable --user 0 "$_c" </dev/null >/dev/null 2>&1
      _alr=$((_alr + 1)); cnt_ok; continue
    fi
    if grep -qx " *${_c#*/}" "$_dcf" 2>/dev/null; then _alr=$((_alr + 1)); cnt_ok; continue; fi
    if pm disable --user 0 "$_c" </dev/null >/dev/null 2>&1; then
      rec x_gms_freeze pkg - "$_c"
      _dis=$((_dis + 1)); cnt_ok
    else
      # class not present in this GMS version
      _miss=$((_miss + 1))
    fi
  done < "$HC_XLISTS/x_gms_safe.txt"
  rm -f "$_dcf"
  _d="$_dis newly disabled, $_alr already off, $_miss not in this GMS version"
  fin x_gms_freeze "$_d" "$_d"
}

# x_track - extended telemetry switches (keys HyperCool's tracking_off already
# sets are not repeated)
f_x_track() {
  if ! on x_track; then
    restore_feature x_track
    st x_track off
    return
  fi
  cnt_reset
  for _k in play_store_panel_logging_enabled clearcut_events clearcut_gcm \
            bugreport_in_power_menu; do
    set_s x_track global "$_k" 0
  done
  set_s x_track global gms_checkin_timeout_min 120
  fin x_track "extended GMS/usage telemetry off"
}

# ================================================================ MORE: logging

# x_log_nuke - deep log cleanup at boot (minus what HyperCool already does in
# debug_off / stats_reduce / scan_off)
f_x_log_nuke() {
  if ! on x_log_nuke; then
    restore_feature x_log_nuke
    st x_log_nuke off
    return
  fi
  cnt_reset
  _k=0
  # init services: "stop" (kill -9 only makes init restart them); leftover logcat dumpers are killed
  _svc="logcatd tcpdump traced_perf idd-logreader idd-logreadermain aplogd vendor.tcpdump vendor_tcpdump"
  on_qcom_ok && _svc="$_svc cnss_diag vendor.cnss_diag"
  on_mtk_ok && _svc="$_svc mobile_log_d emdlogger1 emdlogger2 emdlogger3 emdlogger5 mdlogger connsyslogger"
  for _s in $_svc; do
    case "$(getprop "init.svc.$_s")" in running|restarting) setprop ctl.stop "$_s" 2>/dev/null && _k=$((_k + 1)) ;; esac
  done
  for _p in $(pidof logcat 2>/dev/null); do kill "$_p" 2>/dev/null && _k=$((_k + 1)); done
  [ "$_k" -gt 0 ] && log "x_log_nuke: stopped $_k log service(s)/process(es)"
  logcat -c </dev/null >/dev/null 2>&1
  dmesg -c </dev/null >/dev/null 2>&1
  logcat -G 64k </dev/null >/dev/null 2>&1
  cmd activity logging disable-text </dev/null >/dev/null 2>&1
  cmd autofill set log_level off </dev/null >/dev/null 2>&1
  cmd display ab-logging-disable </dev/null >/dev/null 2>&1
  cmd display dmd-logging-disable </dev/null >/dev/null 2>&1
  cmd display dwb-logging-disable </dev/null >/dev/null 2>&1
  cmd input_method tracing stop </dev/null >/dev/null 2>&1
  cmd statusbar tracing stop </dev/null >/dev/null 2>&1
  for _wl in $(dumpsys window </dev/null 2>/dev/null | grep -E "^  (Proto|Logcat):" | sed 's/^  .*://'); do
    cmd window logging disable "$_wl" </dev/null >/dev/null 2>&1
    cmd window logging disable-text "$_wl" </dev/null >/dev/null 2>&1
  done
  cmd window logging disable </dev/null >/dev/null 2>&1
  cmd window logging disable-text </dev/null >/dev/null 2>&1
  cmd window tracing size 0 </dev/null >/dev/null 2>&1
  cmd voiceinteraction set-debug-hotword-logging false </dev/null >/dev/null 2>&1
  cmd wifi set-verbose-logging disabled -l 0 </dev/null >/dev/null 2>&1
  cnt_ok
  # earlier builds set netstats_poll_interval=60000 (default 30 min: 30x more polling)
  # and netstats_enabled=0 (breaks data usage / data limit): give them back
  restore_feature x_log_nuke netstats_enabled
  restore_feature x_log_nuke netstats_poll_interval
  restore_feature x_log_nuke netstats_persist_threshold
  restore_feature x_log_nuke netstats_global_alert_bytes
  # tags no longer in the list (older builds also disabled crash/ANR/tombstone) get their value back
  _tl=",$(grep -v '^#' "$HC_XLISTS/x_dropbox_tags.txt" 2>/dev/null | tr '\n' ','),"
  _dks=$(grep "^x_log_nuke|settings|global|dropbox:" "$HC_ROMBAK" 2>/dev/null | cut -d'|' -f4)
  for _dk in $_dks; do
    case "$_tl" in *",${_dk#dropbox:},"*) ;; *) restore_feature x_log_nuke "$_dk" ;; esac
  done
  # shellcheck disable=SC2013 # one tag per line
  for _t in $(grep -v '^#' "$HC_XLISTS/x_dropbox_tags.txt" 2>/dev/null); do
    case "$_t" in ''|'#'*) continue ;; esac
    set_s x_log_nuke global "dropbox:$_t" disabled
  done
  fin x_log_nuke "log daemons stopped, buffers shrunk, dropbox reports off"
}

# x_diag - vendor diagnostics off
f_x_diag() {
  if ! on x_diag; then
    restore_feature x_diag
    st x_diag off
    return
  fi
  cnt_reset
  for _s in charge_logger misight vendor.mi_misight; do
    case "$(getprop "init.svc.$_s")" in
      running|restarting) setprop ctl.stop "$_s" 2>/dev/null && cnt_ok ;;
    esac
  done
  setprop debug.sys.looper_stats_enabled false 2>/dev/null
  cmd looper_stats disable </dev/null >/dev/null 2>&1
  cnt_ok
  set_s x_diag system anr_debugging_mechanism 0
  set_s x_diag system send_security_reports 0
  # props only where the ROM already exposes them
  for _pv in persist.sys.stability.nativehangII.enable=false \
             persist.sys.turbosched.local.enable=false \
             persist.vendor.wifisalog.enable=false \
             persist.sys.offlinelog.bootlog=false \
             persist.vendor.camera.mawlog.aiasd=0; do
    [ -n "$(getprop "${_pv%%=*}")" ] && { resetprop -n "${_pv%%=*}" "${_pv#*=}" 2>/dev/null && cnt_ok; }
  done
  on_qcom_ok && wn /sys/module/msm_video/parameters/msm_vidc_debug 0
  on_qcom_ok && for _p in /sys/devices/platform/qcom,mmrm*/debug /sys/devices/platform/*/qcom,mmrm/debug; do
    [ -e "$_p" ] && wn "$_p" 0
  done
  fin x_diag "vendor log services and diagnostics off"
}

# ================================================================ MORE: storage

# x_cache_auto - daily app-cache clean (keeper: common/cache_clean.sh)
hc_cache_pid() {
  _cp=$(cat "$HC_DATA/cache_keeper.pid" 2>/dev/null)
  case "$_cp" in ''|*[!0-9]*) return 1 ;; esac
  grep -q cache_clean "/proc/$_cp/cmdline" 2>/dev/null && echo "$_cp"
}
f_x_cache_auto() {
  _cp=$(hc_cache_pid) && kill "$_cp" 2>/dev/null
  rm -f "$HC_DATA/cache_keeper.pid"
  on x_cache_auto || { st x_cache_auto off; return; }
  _mn=$(num x_cache_min 0)
  if command -v nice >/dev/null 2>&1; then
    nohup nice -n 19 sh "$MODDIR/common/cache_clean.sh" keeper >/dev/null 2>&1 &
  else
    nohup sh "$MODDIR/common/cache_clean.sh" keeper >/dev/null 2>&1 &
  fi
  _i=0
  while [ "$_i" -lt 5 ] && ! hc_cache_pid >/dev/null; do sleep 1; _i=$((_i + 1)); done
  if _cp=$(hc_cache_pid); then
    if [ "$_mn" -gt 0 ]; then _md="when app cache >= $_mn MB"; else _md="always"; fi
    st x_cache_auto applied "daily clean $_md (keeper pid $_cp, checks every 15 min while awake)"
  else
    st x_cache_auto failed "cache keeper did not start"
  fi
}

# ---------------------------------------------------------------- extra power saving

# x_kpower - kernel power-saving switches: power-efficient workqueues (unbound work runs on
# already-awake CPUs) and the battery_saver module of custom kernels.
# Kernel values: back to stock at the next reboot when switched off.
f_x_kpower() {
  on x_kpower || { st x_kpower off; return; }
  cnt_reset
  _d=""; _pw=""
  _wq=/sys/module/workqueue/parameters/power_efficient
  if [ -e "$_wq" ]; then
    # stock kernels expose it read-only (boot parameter); then only report its state
    wtry "$_wq" Y
    case $? in
      0) cnt_ok; _d="power-efficient workqueues on" ;;
      *) case "$(cat "$_wq" 2>/dev/null)" in
           Y|1) _pw="power-efficient workqueues already on (kernel)" ;;
           *) _pw="power-efficient workqueues: read-only in this kernel" ;;
         esac ;;
    esac
  fi
  _bs=/sys/module/battery_saver/parameters/enabled
  if [ -e "$_bs" ]; then
    if grep -q '[0-9]' "$_bs" 2>/dev/null; then _v=1; else _v=Y; fi
    wn "$_bs" "$_v" && _d="${_d:+$_d, }kernel battery_saver module on"
  fi
  fin x_kpower "${_d}${_pw:+; $_pw}" "no writable power_efficient / battery_saver node${_pw:+; $_pw}"
}

# x_vm_lite - less background memory work: no swap/zram read-ahead (page-cluster 0)
# and no proactive background compaction by kcompactd (compaction_proactiveness 0, kernel 5.9+).
f_x_vm_lite() {
  on x_vm_lite || { st x_vm_lite off; return; }
  cnt_reset
  _d=""
  [ -e /proc/sys/vm/page-cluster ] && wn /proc/sys/vm/page-cluster 0 && _d="swap read-ahead off"
  [ -e /proc/sys/vm/compaction_proactiveness ] && wn /proc/sys/vm/compaction_proactiveness 0 && \
    _d="${_d:+$_d, }proactive compaction off"
  fin x_vm_lite "$_d"
}
