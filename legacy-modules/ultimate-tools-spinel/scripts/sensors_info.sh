#!/system/bin/sh
# What the sensor stack of this GSI actually exposes. One "KEY|a|b|c" line each.
#   S|<name>|<vendor>|<type>     every sensor listed by sensorservice
#   HAL|<process names>          sensors HAL processes that are running
#   FP|<0/1>|<service>          fingerprint HAL registered?
#   CAM|<count>                  cameras the camera service reports
clean() { echo "$1" | tr -d '|' | tr '\r\n' '  '; }

if [ -n "$SENSOR_DUMP" ]; then DUMP=$(cat "$SENSOR_DUMP"); else DUMP=$(dumpsys sensorservice 2>/dev/null); fi
echo "$DUMP" | awk -F' [|] ' '
  /^ *0x[0-9a-fA-F]+\)/ && /type:/ {
    n=$1; sub(/^ *0x[0-9a-fA-F]+\) */,"",n)
    t=""
    for(i=2;i<=NF;i++) if ($i ~ /^type:/) { t=$i; sub(/^type: */,"",t); sub(/\(.*/,"",t) }
    gsub(/\|/,"",n)
    print "S|" n "|" $2 "|" t
  }'

if [ -z "$SENSOR_DUMP" ]; then
    HAL=$(ps -A 2>/dev/null | grep -i "sensors" | grep -v grep | awk '{print $NF}' | head -n 3 | tr '\n' ' ')
    echo "HAL|$(clean "$HAL")"
    FP=$(service list 2>/dev/null | grep -i fingerprint | head -n 1)
    if [ -n "$FP" ]; then echo "FP|1|$(clean "$FP")"; else echo "FP|0|"; fi
    CAM=$(dumpsys media.camera 2>/dev/null | grep -m1 -iE "Number of camera devices" | grep -oE "[0-9]+" | head -n1)
    echo "CAM|${CAM:-0}"
fi
