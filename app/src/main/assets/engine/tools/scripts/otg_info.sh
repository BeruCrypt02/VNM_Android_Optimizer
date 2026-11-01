#!/system/bin/sh
# USB-C roles + what is plugged in over OTG, one "KEY|a|b|c" line each, for the WebUI.
S=${SYSFS:-/sys}
P=$S/class/typec/port0
rd() { _v=""; [ -r "$1" ] && read -r _v < "$1" 2>/dev/null; echo "$_v"; }
clean() { echo "$1" | tr -d '|' | tr '\r\n' '  '; }

echo "ROLE|$(rd $P/preferred_role)|$(rd $P/power_role)|$(rd $P/data_role)|$(rd $P/port_type)|$(rd $S/class/usb_role/mt_usb-role-switch/role)|$(rd $S/class/power_supply/usb/usb_otg)|$(rd $S/class/power_supply/usb/online)"

BUS=$S/bus/usb/devices
for d in "$BUS"/*; do
    n=${d##*/}
    case "$n" in usb*|*:*) continue ;; esac
    [ -f "$d/idVendor" ] || continue

    ALL=""
    for i in "$BUS/$n":*; do
        [ -f "$i/bInterfaceClass" ] || continue
        ALL="$ALL $(rd "$i/bInterfaceClass"):$(rd "$i/bInterfaceSubClass"):$(rd "$i/bInterfaceProtocol")"
    done
    PRODUCT=$(rd "$d/product"); MANU=$(rd "$d/manufacturer")
    LOWER=$(echo "$MANU $PRODUCT" | tr 'A-Z' 'a-z')

    TYPE=other
    case "$ALL " in *" 09:"*) TYPE=hub ;; esac
    case "$ALL " in *" 07:"*) TYPE=printer ;; esac
    case "$ALL " in *" 02:"*|*" 0a:"*) TYPE=serial ;; esac
    case "$ALL " in *" e0:"*) TYPE=bluetooth ;; esac
    case "$ALL " in *" 0e:"*) TYPE=camera ;; esac
    case "$ALL " in *" 01:"*) TYPE=audio ;; esac
    case "$ALL " in *" 03:"*) TYPE=hid ;; esac
    case "$ALL " in *" 03:"*":02 "*|*" 03:"*":02") TYPE=mouse ;; esac
    case "$ALL " in *" 03:"*":01 "*|*" 03:"*":01") TYPE=keyboard ;; esac
    if [ "$TYPE" = "hid" ]; then
        case "$LOWER" in *game*|*pad*|*controller*|*xbox*|*dualshock*|*dualsense*|*joystick*) TYPE=gamepad ;; esac
    fi
    case "$ALL " in *" ff:42:01"*) TYPE=phone ;; esac
    case "$ALL " in *" 06:"*) TYPE=phone ;; esac
    case "$ALL " in *" 08:"*) TYPE=storage ;; esac

    echo "DEV|$n|$TYPE|$(rd "$d/idVendor"):$(rd "$d/idProduct")|$(clean "$MANU")|$(clean "$PRODUCT")|$(rd "$d/speed")|$(clean "$ALL")"
done

if [ -f /data/local/tmp/usb_otg_enable.log ]; then
    tail -n 8 /data/local/tmp/usb_otg_enable.log 2>/dev/null | while IFS= read -r l; do echo "LOG|$(clean "$l")"; done
fi
