#!/system/bin/sh
# Battery + charger + screen refresh rate, one "KEY|a|b|c" line each, for the WebUI.
S=${SYSFS:-/sys}
PS=$S/class/power_supply
rd() { _v=""; [ -r "$1" ] && read -r _v < "$1" 2>/dev/null; echo "$_v"; }
B=$PS/battery
echo "BAT|$(rd $B/capacity)|$(rd $B/status)|$(rd $B/voltage_now)|$(rd $B/current_now)|$(rd $B/temp)|$(rd $B/health)|$(rd $B/technology)|$(rd $B/cycle_count)"
U=$PS/usb
echo "USB|$(rd $U/online)|$(rd $U/voltage_now)|$(rd $U/current_now)|$(rd $U/voltage_max)|$(rd $U/current_max)|$(rd $U/real_type)"
[ -d "$PS/ac" ] && echo "AC|$(rd $PS/ac/online)"

# --- memory ---
awk '/^MemTotal:/{t=$2} /^MemAvailable:/{a=$2} /^SwapTotal:/{st=$2} /^SwapFree:/{sf=$2} /^MemFree:/{f=$2} END{ if(a=="") a=f; print "MEM|" t "|" a "|" st "|" sf }' "${PROCFS:-/proc}/meminfo" 2>/dev/null

# --- internal storage (/data = what Settings calls "storage"), in KB ---
STO=$(df -k "${DFPATH:-/data}" 2>/dev/null | tail -n 1 | awk '{print $2 "|" $3 "|" $4}')
echo "STO|$STO"

# --- current screen refresh rate ---
HZ=""
if [ -z "$SYSFS" ]; then
    HZ=$(dumpsys SurfaceFlinger 2>/dev/null | grep -m1 -E "refresh-rate +:" | grep -oE "[0-9]+(\.[0-9]+)?" | head -n1)
    if [ -z "$HZ" ]; then
        D=$(dumpsys display 2>/dev/null)
        ID=$(echo "$D" | grep -m1 -oE "mActiveModeId=[0-9]+" | cut -d= -f2)
        [ -n "$ID" ] && HZ=$(echo "$D" | grep -oE "id=$ID,[^}]*fps=[0-9.]+" | head -n1 | grep -oE "fps=[0-9.]+" | cut -d= -f2)
    fi
fi
echo "HZ|$HZ"
