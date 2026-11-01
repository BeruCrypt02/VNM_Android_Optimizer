package com.mkvenompro.optimizer.toolkit

enum class Risk { READ_ONLY, STATE_CHANGE, DESTRUCTIVE }
data class ReferenceCommand(val title: String, val command: String, val detail: String, val risk: Risk)

object ToolkitCatalog {
    val adb = listOf(
        ReferenceCommand("Connected devices", "adb devices -l", "Lists ADB-authorized devices.", Risk.READ_ONLY),
        ReferenceCommand("Android version", "adb shell getprop ro.build.version.release", "Reads Android release property.", Risk.READ_ONLY),
        ReferenceCommand("Device properties", "adb shell getprop", "Reads system properties.", Risk.READ_ONLY),
        ReferenceCommand("Recent logs", "adb logcat -d -t 1000", "Reads a limited recent log buffer.", Risk.READ_ONLY),
        ReferenceCommand("Package list", "adb shell pm list packages", "Lists installed package IDs.", Risk.READ_ONLY),
        ReferenceCommand("Reboot device", "adb reboot", "Restarts the connected device.", Risk.STATE_CHANGE),
        ReferenceCommand("Install APK", "adb install app.apk", "Installs an APK on the connected device.", Risk.STATE_CHANGE)
    )
    val fastboot = listOf(
        ReferenceCommand("Fastboot devices", "fastboot devices", "Lists devices in bootloader mode.", Risk.READ_ONLY),
        ReferenceCommand("Get product", "fastboot getvar product", "Reads the bootloader product identifier.", Risk.READ_ONLY),
        ReferenceCommand("Get current slot", "fastboot getvar current-slot", "Reads the active slot when supported.", Risk.READ_ONLY),
        ReferenceCommand("Reboot", "fastboot reboot", "Restarts the connected device.", Risk.STATE_CHANGE),
        ReferenceCommand("Erase partition", "fastboot erase <partition>", "Destructive operation; shown for awareness only.", Risk.DESTRUCTIVE),
        ReferenceCommand("Flash image", "fastboot flash <partition> <image>", "Firmware write; compatibility must be verified.", Risk.DESTRUCTIVE)
    )
}
