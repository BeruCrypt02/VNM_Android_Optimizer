# MkVenomPro Android Optimizer

Root-powered Android app that combines:

- **Heat & battery tuning** – CPU/GPU caps, charge limit, doze/standby, cache and RAM cleaning, kernel and system tweaks (Qualcomm + MediaTek).
- **ADB & Fastboot over OTG** (like Bugjaeger): this phone is the USB host, the target phone must be plugged in. Popular ADB shell commands (device info, apps, input, settings, logs), reboot modes (recovery, bootloader, fastbootd, sideload, EDL, download), APK install, custom ADB command; fastboot getvar/unlock/lock/slots/erase/reboot presets, custom fastboot command and single-image flash. Needs neither root nor Shizuku.
- **Device tools** – debloater with restore bin, OTG fix, FOD fix, brightness fix, game spoofer, CPU/GPU governors and frequencies, SELinux switch, sensor check, battery/RAM/storage/refresh-rate info, root terminal, log viewer, ADB/fastboot flashing over OTG, USB manager, touchpad (this phone as a mouse for the phone on OTG), optional ReZygisk.

## How it works

The UI runs in a WebView and talks to root through a native `window.ksu` bridge (`exec`, `listPackages`, `getPackagesInfo`).
Boot-time work (sysfs/props, SELinux rules, overlays, FOD/brightness/OTG daemons) cannot be done by a normal app, so the APK carries two small modules (`mkvp_thermal`, `mkvp_tools`) under `app/src/main/assets/engine`. On first launch the app offers to install them into `/data/adb/modules`; reboot once afterwards.

Access backend: the app asks for **root** first; if there is none it falls back to **Shizuku** (shell mode, root-only features such as the engine and sysfs writes are unavailable). ADB/Fastboot host mode works with neither.

Requirements: Android 8+ (engine features need Android 11+), root with module support (Magisk, KernelSU or APatch), arm64 for the brightness/FOD helpers.

## Build

GitHub Actions builds a signed release APK on every push (`.github/workflows/build.yml`) and attaches it to a release when you push a tag like `v1.0.0`.

For a stable signature (so updates install over each other) add these repository secrets: `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, optionally `KEY_PASSWORD`.

Local build (Gradle 8.7+, JDK 17, Android SDK 34): `gradle assembleRelease`.

## Uninstall

Remove `mkvp_thermal` and `mkvp_tools` in your root manager (their uninstall scripts restore removed apps and ROM changes), then uninstall the app.

See `NOTICE.md` for credits and third-party licenses.
