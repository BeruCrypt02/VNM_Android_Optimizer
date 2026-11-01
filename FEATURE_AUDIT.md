# Clean-room feature audit

This project is an independent Android application. The three supplied archives were reviewed as behavioral/feature references only. Their source files, scripts, WebUI bundles, graphics, and archives are not included in this repository.

## Feature families identified during review

- Device/ROM inspection: SoC and ROM identification, kernel and sensor visibility, root capability detection.
- Performance diagnostics: CPU policy discovery, CPU/GPU frequency interface discovery, scheduler visibility, I/O scheduler visibility, memory and thermal reporting.
- Battery and background behavior: charge/health reporting, idle and Doze concepts, protected-app policy concepts, app standby and background restriction concepts.
- Application management: package inventory, curated package groups, safe exclusions, disable/restore workflows, backup/restore concepts.
- Maintenance and diagnostics: logs, storage/cache reporting, app/process diagnostics, configuration backup and restoration.
- Device connection and tools: ADB host/target workflow, wireless pairing, shell, deployment, file transfer, logcat, screenshots, and Fastboot capability discovery.

## Implementation truth table

| Capability | Current source status | Notes |
|---|---|---|
| Compose dashboard and floating capsule navigation | Implemented | UI navigation only |
| Dark/light/system theme persisted before Compose content | Implemented | Existing behavior retained |
| Device/kernel interface inspection | Implemented, read-only | OEM/kernel exposure varies |
| Battery service snapshot | Implemented, read-only | Not a battery-capacity estimator |
| Installed app inventory and launch | Implemented | No disable/uninstall action |
| USB host capability discovery | Implemented | Not USB ADB transport |
| Root availability detection | Implemented | Detection only; no privileged operation |
| ADB command reference | Implemented | Display only, not an ADB session |
| Fastboot command reference | Implemented | Display only, not a Fastboot session |
| Wireless ADB pairing/connect | Not implemented | Requires a separate ADB network transport and pairing flow |
| USB ADB host transport | Not implemented | USB Host capability is not an ADB protocol implementation |
| Interactive shell/custom command execution | Not implemented | No command-execution UI is exposed |
| APK/split APK deployment | Not implemented | No deployment flow is exposed |
| Remote app enable/disable/uninstall/restore | Not implemented | No package-control backend is exposed |
| File transfer, Logcat, screenshot capture | Not implemented | No connected-target session exists |
| Shizuku integration | Not implemented | No Shizuku dependency or permission flow |
| CPU/GPU governor/frequency writes | Not implemented | Read-only discovery only |
| Battery/Doze/app-standby tuning | Not implemented | No system values are modified |
| Backup/restore and debloat transaction engine | Not implemented | No package changes are made |
| Sensor/camera/fingerprint diagnostics | Not implemented | Not yet implemented |

## Safety and compatibility rules

- The phone running this app is the ADB Host/controller; a separately connected Android device is the Target.
- USB Host detection is not represented as USB ADB support. USB ADB and Wireless ADB require separate transports.
- Any future privileged operation must show target, exact changes, permission state, confirmation, result, and a verifiable restore path.
- Unsupported kernel nodes and OEM-specific features must be reported as unavailable; never infer support from a chipset name alone.
- The requested feature scope includes Fast Charge Control, SELinux mode management, Game Spoofer, ReZygisk-related management, MiTool-related tools, FOD diagnostics/fixes, and database maintenance. These are not excluded; each remains unimplemented until its own capability checks, compatibility handling, confirmation, and recovery behavior are implemented and tested.
- SELinux-related controls must clearly explain the security impact, require explicit user confirmation and suitable privilege, and must never silently persist a weaker policy.
- Explicitly excluded by the user: OTG/USB fixes and brightness fixes/services only.
