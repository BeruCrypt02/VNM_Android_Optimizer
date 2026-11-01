#!/system/bin/sh
ui_print "- MkVenomPro Android Optimizer & Debloater"
ui_print "- Open this module's WebUI from your Magisk/KernelSU/APatch manager"
ui_print "  to pick which apps to remove and toggle performance settings."
ui_print "- Log file (internal storage):"

set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/uninstall.sh" 0 0 0755
set_perm "$MODPATH/scripts/common.sh" 0 0 0755
set_perm "$MODPATH/scripts/apply_perf.sh" 0 0 0755
set_perm "$MODPATH/scripts/debloat_run.sh" 0 0 0755
set_perm "$MODPATH/scripts/restore_pkg.sh" 0 0 0755
set_perm "$MODPATH/scripts/extract_one.sh" 0 0 0755
set_perm "$MODPATH/scripts/rebuild_labels.sh" 0 0 0755
