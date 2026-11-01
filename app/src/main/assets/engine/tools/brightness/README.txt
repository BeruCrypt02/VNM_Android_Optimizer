Spinel Brightness Controller v3.0

Whole-slider remap
  The framework float is converted back to the slider position (inverse of Android's HLG slider).
  From PK upward the backlight is lifted from the stock value to MAX in a smooth curve, slew limited by RAMP_MS.

Single writer (no flicker)
  The HAL's writes to /sys/class/leds/lcd-backlight/brightness are redirected to /dev/spinel_bd/brightness
  (bind mount) and the daemon is the only writer of the real node.
  Safety nets: if something still writes the real node ("leak") or nothing arrives in the redirect file
  ("deaf"), the daemon removes the mount and continues in the older rewrite mode.

Thermal derate
  DERATE limits the output by board_sensor_temp so MAX can be used without bypassing thermal protection.

Log:    /data/adb/modules/spinel_brightness_controller/brightnessd.log  (first line shows the mode)
Stop:   touch /data/adb/modules/spinel_brightness_controller/stop; pkill brightnessd   (the mount is removed)
Panic:  disable/remove the module in the manager, reboot. If the screen ever stays at a fixed brightness:
        umount -l /sys/class/leds/lcd-backlight/brightness
