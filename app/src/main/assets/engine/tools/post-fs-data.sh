#!/system/bin/sh
MODDIR=${0%/*}

# FOD switch off (Modules tab) -> skip the FOD props + bind mounts
FOD_OFF=0; [ "$(cat /data/adb/mkvp_tools/fod_mode 2>/dev/null | tr -d ' \r\n\t')" = "off" ] && FOD_OFF=1

# Props (must NOT source service.sh here - it waits for boot_completed and would block boot)
if [ "$FOD_OFF" = 1 ]; then :
elif command -v resetprop >/dev/null 2>&1; then
    resetprop vendor.fingerprint.aidl.support 1
    resetprop persist.sys.oplus.anim_level 1
else
    setprop vendor.fingerprint.aidl.support 1
    setprop persist.sys.oplus.anim_level 1
fi

# Bind-mount Oplus optical FOD & water ripple feature XMLs onto /my_product (only if target exists)
for f in com.oppo.features_allnet_android.xml oplus.product.display_features.xml; do
    SRC="$MODDIR/system/my_product/etc/permissions/$f"
    DST="/my_product/etc/permissions/$f"
    if [ "$FOD_OFF" != 1 ] && [ -f "$SRC" ] && [ -f "$DST" ]; then
        mount -o bind "$SRC" "$DST"
    fi
done

# Game spoofer (Galaxy S24 Ultra model props) - on/off is stored by the WebUI
[ -f "$MODDIR/scripts/spoof_ctl.sh" ] && sh "$MODDIR/scripts/spoof_ctl.sh" boot >/dev/null 2>&1
