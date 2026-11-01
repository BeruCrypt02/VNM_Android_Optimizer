# Clean-room migration map

The source archives were reviewed outside this public project. No original module archive, extracted script, executable payload, or original WebUI asset is shipped here.

## Reference feature families mapped for independent implementation

- Optimizer v1.1: package catalog/labels, package disable and restore, debloat review, performance profiles, persistent profile guard.
- HyperCool v1.6: performance and battery profiles, charge telemetry/control, thermal guard, configuration, cache/database maintenance, restore.
- Ultimate Tools Spinel: CPU/GPU tuning, I/O/memory tuning, SELinux, ROM/device profile spoofing, ReZygisk, MiTool, FOD diagnostics, sensors, package operations, charging, device/ROM information.

## Current migration state

Implemented in this revision: dashboard redesign, root shell execution, CPU cpufreq governor discovery and reversible governor writes, current-user package disable/enable/uninstall, battery snapshot, SELinux status readout.

Pending: USB ADB host protocol, Wireless Debugging pairing/session, APK/split APK deployment, file transfer, logcat, screenshots, process monitor, GPU/frequency/I/O/memory tuning, charging controls, SELinux mode controls, spoof profiles, ReZygisk/MiTool integrations, FOD control, sensor diagnostics, curated debloat catalog, package backup/restore, cache/database maintenance.

Only OTG Fix and Brightness Fix are excluded. Every other feature family remains in scope.
