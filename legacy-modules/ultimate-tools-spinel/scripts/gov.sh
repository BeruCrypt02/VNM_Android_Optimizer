#!/system/bin/sh
# CPU / GPU governor + CPU cluster frequency control.
#
#   gov.sh status                          -> governors, machine-readable for the WebUI
#   gov.sh set cpu <all|policyN> <gov>
#   gov.sh set gpu <gov>
#   gov.sh fstatus                         -> per-cluster frequency limits for the WebUI
#   gov.sh reset                           -> forget saved choices, restore boot-time governors + full freq range
# (frequencies are status only: fstatus is read only, nothing re-applies a frequency limit)
#   gov.sh daemon                          -> boot service: re-applies saved choices (single instance)
#
# Saved choices live in $STATE_DIR/governors.conf (survive updates/reboots).
# Every value is checked against what the kernel offers, written, then read back.

STATE_DIR=${STATE_DIR:-/data/adb/spinel_toolkit}
CONF=$STATE_DIR/governors.conf
ORIG=$STATE_DIR/governors.orig
PIDF=${PIDF:-/data/local/tmp/spinel_gov.pid}
CPUROOT=${CPUROOT:-/sys/devices/system/cpu/cpufreq}
CPUBASE=${CPUBASE:-/sys/devices/system/cpu}
GPUROOT=${GPUROOT:-/sys/class}
# Shown when a kernel hides its list of governors (the write is still checked by reading it back)
GOV_FALLBACK="schedutil performance powersave ondemand conservative userspace"

mkdir -p "$STATE_DIR" 2>/dev/null

rd() { _v=""; [ -r "$1" ] && read -r _v < "$1" 2>/dev/null; echo "$_v"; }
has() { for _x in $1; do [ "$_x" = "$2" ] && return 0; done; return 1; }
valid_name() { case "$1" in ''|*[!A-Za-z0-9_.-]*) return 1 ;; *) return 0 ;; esac; }
is_num() { case "$1" in ''|*[!0-9]*) return 1 ;; *) return 0 ;; esac; }
avail_of() { _a=$(rd "$1"); [ -n "$_a" ] && echo "$_a" || echo "$GOV_FALLBACK"; }

# ---- CPU clusters: policyN (modern) or cpuN (old kernels) ----
cpu_names() {
    _found=0
    for d in "$CPUROOT"/policy[0-9]*; do
        [ -f "$d/scaling_governor" ] && { echo "${d##*/}"; _found=1; }
    done
    [ "$_found" = "1" ] && return
    for d in "$CPUBASE"/cpu[0-9]*; do
        [ -f "$d/cpufreq/scaling_governor" ] && echo "${d##*/}"
    done
}
cpu_dir() {
    case "$1" in
        policy[0-9]*) echo "$CPUROOT/$1" ;;
        cpu[0-9]*)    echo "$CPUBASE/$1/cpufreq" ;;
    esac
}

# ---- GPU: Adreno (kgsl) or Mali / other devfreq node ----
gpu_node() {
    [ -f "$GPUROOT/kgsl/kgsl-3d0/devfreq/governor" ] && { echo "$GPUROOT/kgsl/kgsl-3d0/devfreq"; return; }
    for d in "$GPUROOT"/devfreq/*; do
        [ -f "$d/governor" ] && [ -f "$d/available_governors" ] || continue
        case "${d##*/}" in *mali*|*gpu*|*GPU*|*kgsl*) echo "$d"; return ;; esac
    done
    for d in /sys/devices/platform/*mali*/devfreq/* /sys/devices/platform/*gpu*/devfreq/*; do
        [ -f "$d/governor" ] && [ -f "$d/available_governors" ] && { echo "$d"; return; }
    done
}

# ---- saved config (key=value) ----
conf_get() { grep -m1 "^$1=" "$CONF" 2>/dev/null | cut -d= -f2-; }
conf_set() {
    grep -v "^$1=" "$CONF" 2>/dev/null > "$CONF.tmp"
    echo "$1=$2" >> "$CONF.tmp"
    mv -f "$CONF.tmp" "$CONF"
}

# ---- write one governor, verified (0 ok, 2 not offered by kernel, 1 write failed) ----
put() {
    _av=$(rd "$2")
    if [ -n "$_av" ]; then has "$_av" "$3" || return 2; fi
    [ "$(rd "$1")" = "$3" ] && return 0
    chmod 0644 "$1" 2>/dev/null
    _t=0
    while [ "$_t" -lt 3 ]; do
        echo "$3" > "$1" 2>/dev/null
        [ "$(rd "$1")" = "$3" ] && return 0
        _t=$((_t+1)); sleep 0.1
    done
    return 1
}
put_cpu() {
    _d=$(cpu_dir "$1"); [ -n "$_d" ] || return 1
    put "$_d/scaling_governor" "$_d/scaling_available_governors" "$2"
}
put_gpu() {
    _n=$(gpu_node); [ -n "$_n" ] || return 1
    put "$_n/governor" "$_n/available_governors" "$1"
}

# ---- CPU frequency limits (kHz), verified ----
FERR=""; FWANT=""; FGOT=""; FNOTE=""; FDIRP=""
# write one value; remembers the kernel's error text (e.g. "Permission denied") in FERR
wr() {
    chmod 0644 "$1" 2>/dev/null
    _e=$( { echo "$2" > "$1"; } 2>&1 ) || FERR=$(echo "$_e" | head -n 1 | sed 's/^.*: //')
}
# vendor-level limits that sit above cpufreq and silently override it (MediaTek PPM)
vendor_limit() { # <policyN|cpuN> <min> <max>
    _u=/proc/ppm/policy/userlimit_cpu_freq
    [ -e "$_u" ] || return 0
    _i=0
    for _p in $(cpu_names); do [ "$_p" = "$1" ] && break; _i=$((_i+1)); done
    echo "$_i $2 $3" > "$_u" 2>/dev/null
}
write_range() { # <dir> <min> <max>   (keeps min <= max at every step)
    _w=$1; _cmin=$(rd "$_w/scaling_min_freq"); _cmax=$(rd "$_w/scaling_max_freq")
    if is_num "$_cmin" && [ "$3" -lt "$_cmin" ]; then
        wr "$_w/scaling_min_freq" "$2"; wr "$_w/scaling_max_freq" "$3"
    else
        wr "$_w/scaling_max_freq" "$3"; wr "$_w/scaling_min_freq" "$2"
    fi
}
# some ROMs lock these files with a bind mount or the immutable flag: undo both
unlock_freq() {
    for _f in "$1/scaling_min_freq" "$1/scaling_max_freq"; do
        _n=0
        while [ "$_n" -lt 5 ] && grep -q " $_f " /proc/self/mountinfo 2>/dev/null; do
            umount -l "$_f" 2>/dev/null || break
            _n=$((_n+1))
        done
        chattr -i "$_f" 2>/dev/null
    done
}
thermal_info() { # active cpu throttling + hottest zone (a cap that sysfs writes cannot beat)
    _o=""; _hot=0
    for _c in /sys/class/thermal/cooling_device*; do
        [ -d "$_c" ] || continue
        _ty=$(rd "$_c/type"); _cs=$(rd "$_c/cur_state")
        case "$_ty" in *cpu*|*CPU*|*freq*|*Freq*) is_num "$_cs" && [ "$_cs" -gt 0 ] && _o="$_o $_ty:$_cs/$(rd "$_c/max_state")" ;; esac
    done
    for _z in /sys/class/thermal/thermal_zone*; do
        _tv=$(rd "$_z/temp"); is_num "$_tv" && [ "$_tv" -gt "$_hot" ] && _hot=$_tv
    done
    echo "throttle=${_o:- none} hottest=$((_hot/1000))C"
}
diag_line() { # <dir>
    echo "diag: selinux=$(getenforce 2>/dev/null) ctx=$(cat /proc/self/attr/current 2>/dev/null | tr -d '\0') uid=$(id -u) file=$(stat -c '%a %U %C' "$1/scaling_max_freq" 2>/dev/null) ppm=$([ -e /proc/ppm/policy/userlimit_cpu_freq ] && echo yes || echo no) cpuinfo_max=$(rd "$1/cpuinfo_max_freq") $(thermal_info)"
}
# usage: put_freq <policyN|cpuN> <min> <max>  (0 ok, 1 failed, 3 bad range)
put_freq() {
    _d=$(cpu_dir "$1"); [ -n "$_d" ] || return 1
    _mn="$2"; _mx="$3"
    is_num "$_mn" && is_num "$_mx" || return 3
    [ "$_mn" -le "$_mx" ] || return 3
    FERR=""; FWANT="$_mn-$_mx"
    [ "$(rd "$_d/scaling_min_freq")" = "$_mn" ] && [ "$(rd "$_d/scaling_max_freq")" = "$_mx" ] && return 0
    _t=0
    while [ "$_t" -lt 3 ]; do
        write_range "$_d" "$_mn" "$_mx"
        [ "$(rd "$_d/scaling_min_freq")" = "$_mn" ] && [ "$(rd "$_d/scaling_max_freq")" = "$_mx" ] && return 0
        _t=$((_t+1)); sleep 0.15
    done
    # a ROM may lock the files (bind mount / immutable): unlock, retry; or a vendor layer clamps the range: set its limit too
    unlock_freq "$_d"; write_range "$_d" "$_mn" "$_mx"
    [ "$(rd "$_d/scaling_min_freq")" = "$_mn" ] && [ "$(rd "$_d/scaling_max_freq")" = "$_mx" ] && return 0
    vendor_limit "$1" "$_mn" "$_mx"; sleep 0.2
    write_range "$_d" "$_mn" "$_mx"
    [ "$(rd "$_d/scaling_min_freq")" = "$_mn" ] && [ "$(rd "$_d/scaling_max_freq")" = "$_mx" ] && return 0
    FGOT="$(rd "$_d/scaling_min_freq")-$(rd "$_d/scaling_max_freq")"
    return 1
}
# resolve tokens (-, hwmin, hwmax, number) for one cluster then write
# usage: freq_cluster <name> <min-token> <max-token>
freq_cluster() {
    _d=$(cpu_dir "$1"); [ -n "$_d" ] || return 1
    _hmin=$(rd "$_d/cpuinfo_min_freq"); _hmax=$(rd "$_d/cpuinfo_max_freq")
    case "$2" in
        -)     _a=$(rd "$_d/scaling_min_freq") ;;
        hwmin) _a="$_hmin" ;;
        hwmax) _a="$_hmax" ;;
        *)     _a="$2" ;;
    esac
    case "$3" in
        -)     _b=$(rd "$_d/scaling_max_freq") ;;
        hwmin) _b="$_hmin" ;;
        hwmax) _b="$_hmax" ;;
        *)     _b="$3" ;;
    esac
    is_num "$_a" && is_num "$_b" || return 3
    # stay inside what the hardware supports
    if is_num "$_hmin" && [ "$_a" -lt "$_hmin" ]; then _a="$_hmin"; fi
    if is_num "$_hmax" && [ "$_b" -gt "$_hmax" ]; then _b="$_hmax"; fi
    if is_num "$_hmax" && [ "$_a" -gt "$_hmax" ]; then _a="$_hmax"; fi
    put_freq "$1" "$_a" "$_b"; _r=$?
    [ "$_r" = "0" ] && return 0
    # the hardware range can list a step the kernel never offers (boost): retry with the highest step that is really available
    _top=0; _low=""
    for _f in $(rd "$_d/scaling_available_frequencies"); do
        is_num "$_f" || continue
        [ "$_f" -gt "$_top" ] && _top=$_f
        if [ -z "$_low" ] || [ "$_f" -lt "$_low" ]; then _low=$_f; fi
    done
    if [ "$_top" -gt 0 ] && { [ "$_b" -gt "$_top" ] || [ "$_a" -gt "$_top" ]; }; then
        [ "$_b" -gt "$_top" ] && _b=$_top
        [ "$_a" -gt "$_top" ] && _a=$_top
        FNOTE="capped to the highest available step $_top"
        put_freq "$1" "$_a" "$_b"; return $?
    fi
    return $_r
}

# first-ever run: remember what the phone booted with, so "reset" can go back
snapshot_orig() {
    [ -f "$ORIG" ] && return
    {
        for p in $(cpu_names); do
            echo "cpu_$p=$(rd "$(cpu_dir "$p")/scaling_governor")"
            echo "freq_$p=$(rd "$(cpu_dir "$p")/scaling_min_freq"),$(rd "$(cpu_dir "$p")/scaling_max_freq")"
        done
        _n=$(gpu_node); [ -n "$_n" ] && echo "gpu=$(rd "$_n/governor")"
    } > "$ORIG.tmp"
    mv -f "$ORIG.tmp" "$ORIG"
}

# re-apply a saved/original file (only writes when different)
apply_file() {
    [ -s "$1" ] || return 0
    while IFS== read -r k v; do
        case "$k" in
            cpu_*)  valid_name "$v" && put_cpu "${k#cpu_}" "$v" ;;
            gpu)    valid_name "$v" && put_gpu "$v" ;;
            freq_*) [ -n "$NOFREQ" ] && continue
                    _fa=${v%,*}; _fb=${v#*,}
                    is_num "$_fa" && is_num "$_fb" && freq_cluster "${k#freq_}" "$_fa" "$_fb" ;;
        esac
    done < "$1"
}

case "$1" in
status)
    snapshot_orig
    for p in $(cpu_names); do
        d=$(cpu_dir "$p")
        echo "CPU|$p|$(rd "$d/related_cpus")|$(rd "$d/scaling_governor")|$(avail_of "$d/scaling_available_governors")|$(conf_get "cpu_$p")"
    done
    n=$(gpu_node)
    if [ -n "$n" ]; then
        echo "GPU|${n##*/}|$(rd "$n/governor")|$(avail_of "$n/available_governors")|$(conf_get gpu)"
    else
        echo "GPU|none"
    fi
    ;;

fstatus)
    snapshot_orig
    for p in $(cpu_names); do
        d=$(cpu_dir "$p")
        echo "FREQ|$p|$(rd "$d/related_cpus")|$(rd "$d/scaling_cur_freq")|$(rd "$d/scaling_min_freq")|$(rd "$d/scaling_max_freq")|$(rd "$d/cpuinfo_min_freq")|$(rd "$d/cpuinfo_max_freq")|$(rd "$d/scaling_available_frequencies")|$(conf_get "freq_$p")"
    done
    ;;

set)
    snapshot_orig
    if [ "$2" = "cpu" ]; then
        TARGET="$3"; GOV="$4"
        valid_name "$GOV" || { echo "ERR bad governor"; exit 1; }
        OK=0; SKIP=0; FAIL=0; MATCH=0
        for p in $(cpu_names); do
            [ "$TARGET" = "all" ] || [ "$TARGET" = "$p" ] || continue
            MATCH=1
            put_cpu "$p" "$GOV"; R=$?
            if [ "$R" = "0" ]; then OK=$((OK+1)); conf_set "cpu_$p" "$GOV"
            elif [ "$R" = "2" ]; then SKIP=$((SKIP+1))
            else FAIL=$((FAIL+1)); fi
        done
        [ "$MATCH" = "1" ] || { echo "ERR no such cpu cluster"; exit 1; }
        if [ "$OK" = "0" ]; then
            if [ "$FAIL" -gt 0 ]; then echo "ERR kernel refused $GOV (failed=$FAIL)"
            else echo "ERR $GOV not offered by this kernel (skipped=$SKIP)"; fi
            exit 1
        fi
        echo "OK cpu applied=$OK skipped=$SKIP failed=$FAIL"
    elif [ "$2" = "gpu" ]; then
        GOV="$3"
        valid_name "$GOV" || { echo "ERR bad governor"; exit 1; }
        [ -n "$(gpu_node)" ] || { echo "ERR no gpu node"; exit 1; }
        put_gpu "$GOV"; R=$?
        if [ "$R" = "0" ]; then conf_set gpu "$GOV"; echo "OK gpu $GOV"
        elif [ "$R" = "2" ]; then echo "ERR $GOV not offered by this kernel"; exit 1
        else echo "ERR kernel refused $GOV"; exit 1; fi
    else
        echo "ERR usage"; exit 1
    fi
    ;;

reset)
    rm -f "$CONF"
    apply_file "$ORIG"
    # clusters with no remembered range go back to the full hardware range
    for p in $(cpu_names); do
        grep -q "^freq_$p=" "$ORIG" 2>/dev/null || freq_cluster "$p" hwmin hwmax
    done
    echo "OK reset"
    ;;

daemon)
    if [ -f "$PIDF" ]; then
        OLD=$(cat "$PIDF" 2>/dev/null)
        case "$OLD" in ''|*[!0-9]*) OLD="" ;; esac
        if [ -n "$OLD" ] && [ "$OLD" != "$$" ] && grep -qF "gov.sh" "/proc/$OLD/cmdline" 2>/dev/null; then
            kill "$OLD" 2>/dev/null
        fi
    fi
    echo $$ > "$PIDF"
    until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 3; done
    sleep 20          # let the vendor perf/thermal services finish their own boot tuning first
    snapshot_orig
    while true; do
        NOFREQ=1 apply_file "$CONF"
        sleep 15
    done
    ;;

*)
    echo "usage: gov.sh status | fstatus | set cpu <all|policyN> <gov> | set gpu <gov> | reset | daemon"
    exit 1
    ;;
esac
