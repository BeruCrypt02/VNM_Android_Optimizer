# Clean-room feature audit

This public source contains independent Android-side implementations. It does not contain the reference ZIPs, extracted module folders, binaries, WebUI assets, or copied shell scripts.

## Scope retained

Only **OTG Fix** and **Brightness Fix** are excluded from the app scope. The following remain requested and must not be silently dropped:

- Android Optimizer v1.1: package inventory and curated debloat workflow, package backup/restore, performance profiles, persistent profile guard, package labels.
- HyperCool v1.6: performance/battery profiles, charge telemetry and supported charge controls, thermal guard/monitoring, cache/database maintenance with explicit review, restore path, configuration.
- Ultimate Tools Spinel: CPU/GPU governors and frequency interfaces, I/O scheduler, memory controls, SELinux, ROM/device spoof profiles, ReZygisk and MiTool integration/compatibility, FOD diagnostics, sensors, package controls, charging controls, device/ROM diagnostics, log/process tools.
- Additional app requirements: ADB Host USB transport, Wireless Debugging pairing/connect, shell, install/split APK, app management, file transfer, logcat, screenshot, process and device information.

## Implemented in this source revision

- New Compose dashboard with refreshed visual hierarchy, rounded cards, persistent theme selection, and five-section bottom navigation.
- CPU policy discovery and governor selection for exposed cpufreq policy nodes.
- Root command execution isolated on IO dispatcher.
- Original governor values are backed up before a change; a restore action is provided.
- Root-gated package disable/enable/uninstall-for-user actions with package-name validation.
- Battery status and health snapshot using Android BatteryManager.
- SELinux enforcement state readout.
- Explicit feature inventory and honest unavailable status for ADB transports.

## Not implemented / not verified yet

ADB USB protocol transport, Wireless Debugging pairing and ADB protocol session, APK/split APK install workflow, file transfer, logcat capture/export, screenshot capture, process monitor, full CPU/GPU frequency and I/O/memory profile controls, charge-control nodes, SELinux mode changes, spoofing, ReZygisk/MiTool integration, FOD control, sensor/camera/fingerprint diagnostics, curated debloat catalog and backup/restore archive workflow, database cleanup, and complete device-specific validation.

These are retained in scope. Their absence is not represented as a working button. Device-specific privileged operations require capability detection, explicit confirmation, backups, and post-write verification before being marked implemented.

## Exclusions

- OTG Fix
- Brightness Fix

No other requested feature is excluded by this audit.
