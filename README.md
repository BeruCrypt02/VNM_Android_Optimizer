# MkVenomPro Android Optimizer

Root-powered Android app that combines:

- **Heat & battery tuning** – CPU/GPU caps, charge limit, doze/standby, cache and RAM cleaning, kernel and system tweaks (Qualcomm + MediaTek).
- **ADB & Fastboot over OTG** (like Bugjaeger): this phone is the USB host, the target phone must be plugged in. Popular ADB shell commands (device info, apps, input, settings, logs), reboot modes (recovery, bootloader, fastbootd, sideload, EDL, download), APK install, custom ADB command; fastboot getvar/unlock/lock/slots/erase/reboot presets, custom fastboot command and single-image flash. Needs neither root nor Shizuku.
- **Device tools** – debloater with restore bin, OTG fix, FOD fix, brightness fix, game spoofer, CPU/GPU governors and frequencies, SELinux switch, sensor check, battery/RAM/storage/refresh-rate info, root terminal, log viewer, ADB/fastboot flashing over OTG, USB manager, touchpad (this phone as a mouse for the phone on OTG), optional ReZygisk.

## How it works

The UI runs in a WebView and talks to root through a native `window.ksu` bridge (`exec`, `listPackages`, `getPackagesInfo`).
Boot-time work (sysfs/props, SELinux rules, overlays, FOD/brightness/OTG daemons) cannot be done by a normal app process, so the APK carries an **engine** (`mkvp_thermal`, `mkvp_tools`) under `app/src/main/assets/engine`. The app itself (it already has root) writes the engine to `/data/adb/mkvp/engine` on first launch - **no Magisk / KernelSU / APatch module is created**; reboot once afterwards.

Boot flow without the module loader: `engine/boot.sh` is started by `/data/adb/post-fs-data.d/mkvp_engine.sh` and `/data/adb/service.d/mkvp_engine.sh` (the standard script folders of Magisk, KernelSU and APatch). If those folders are not executed, the app's own `BootReceiver` (BOOT_COMPLETED) runs `boot.sh late` as a fallback. `boot.sh` replaces what the module loader did: it applies `sepolicy.rule`, loads `system.prop`, and bind/overlay-mounts the `system/` trees (FOD overlay APK, GMS Doze sysconfig). Every stage runs once per boot.

Old installs (`/data/adb/modules/mkvp_thermal`, `mkvp_tools`) are migrated automatically: settings and the removed-apps list are copied, the old module's uninstaller is neutralised and the module is flagged for removal.

Access backend: the app asks for **root** first; if there is none it falls back to **Shizuku** (shell mode, root-only features such as the engine and sysfs writes are unavailable). ADB/Fastboot host mode works with neither.

Requirements: Android 8+ (engine features need Android 11+), root (Magisk, KernelSU or APatch; the `post-fs-data.d` / `service.d` folders give the earliest boot, otherwise the app starts the engine after boot), arm64 for the brightness/FOD helpers.

## Build

GitHub Actions builds a signed release APK on every push (`.github/workflows/build.yml`) and attaches it to a release when you push a tag like `v1.0.0`.

For a stable signature (so updates install over each other) add these repository secrets: `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, optionally `KEY_PASSWORD`.

Local build (Gradle 8.7+, JDK 17, Android SDK 34): `gradle assembleRelease`.

## Uninstall

Modules tab > Engine > **Remove engine** (restores removed apps and ROM changes, deletes `/data/adb/mkvp` and the boot hooks), then uninstall the app. Manual: `su -c 'sh /data/adb/mkvp/engine/engine_ctl.sh uninstall'`.

See `NOTICE.md` for credits and third-party licenses.

## Hardware Info (Device Info HW style)
`info.html` (Tools > **Hardware** pill, or the button on the Device tab) reads everything live through root: dashboard, live monitor (per-core load/frequency, GPU, battery, hottest thermal zones), CPU (core types, governors, time in state), GPU, display (modes, panel), memory/zRAM, storage (UFS/eMMC health), partitions (by-name + dynamic), battery health, camera sensors, sensor list with vendor, Wi-Fi/Bluetooth/cellular/NFC/GNSS, audio + hardware codecs, drivers found in the kernel log, I2C/SPI buses, PMIC regulators, thermal, USB, system/security, features and all build props. Search box, copy, full report saved to `/sdcard/MKVP LOGS/` (MAC/SSID/serial hidden) and an LCD test. All shell lives in `assets/web/info_cmds.txt` (one `#### section` per page).

## ADB Sideload
ADB page > ADB tab > **ADB Sideload**: reboot the target to sideload (or open recovery > Apply update from ADB), choose a zip with the system file picker and send it. Implemented natively (`sideload-host` protocol in `AdbConnection.sideload`), no adb binary needed. The Flash tab shares the same picker (**Browse…**) for the binary-based tools.
