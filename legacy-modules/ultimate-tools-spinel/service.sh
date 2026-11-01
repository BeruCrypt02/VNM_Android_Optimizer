#!/system/bin/sh
# Launcher: starts the parts independently so one failing never blocks the others
MODDIR=${0%/*}
# make sure root may write the cpufreq sysfs nodes even when sepolicy.rule was not loaded (best effort)
for P in magiskpolicy supolicy ksud; do
    command -v "$P" >/dev/null 2>&1 || continue
    case "$P" in
        ksud) ksud sepolicy patch "allow su sysfs_type file { getattr open read write setattr }" >/dev/null 2>&1 ;;
        *) "$P" --live "allow su sysfs_type file { getattr open read write setattr }" "allow su sysfs_devices_system_cpu file { getattr open read write setattr }" >/dev/null 2>&1 ;;
    esac
    break
done
nohup sh "$MODDIR/optimizer.sh" >/dev/null 2>&1 &
nohup sh "$MODDIR/otg/service.sh" >/dev/null 2>&1 &
nohup sh "$MODDIR/fod/service.sh" >/dev/null 2>&1 &
nohup sh "$MODDIR/brightness/service.sh" >/dev/null 2>&1 &
nohup sh "$MODDIR/scripts/gov.sh" daemon >/dev/null 2>&1 &
# SELinux mode: only re-applied when you switched it in the Device tab
nohup sh "$MODDIR/scripts/selinux_ctl.sh" boot >/dev/null 2>&1 &
# Fast-charge fix: ON by default, only skipped when you switched it OFF in the Modules tab
nohup sh "$MODDIR/scripts/charge_ctl.sh" boot >/dev/null 2>&1 &
