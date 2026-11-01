# Reference analysis — clean-room implementation plan

This document records a behavioral and structural analysis of all three supplied root add-ons. It is not a redistribution of their source. The public project contains no original WebRoot, shell scripts, binary payloads, installer assets, or bundled third-party modules.

## 1. Sources inspected

| Reference | Inspected structure | Notable contents |
|---|---|---|
| MkVenomPro Android Optimizer v1.1 | module metadata, installer/boot scripts, scripts/, webroot/ | curated debloat catalogs, package-label workflow, performance profile application/keeper, package restore, WebUI status and actions |
| HyperCool v1.6 | README, module lifecycle scripts, common/*.sh, config defaults, webroot/index.html | large single-document WebUI, per-feature config, backup/restore/revert, status/logging, heat/battery/system/more feature groups |
| Ultimate Tools Spinel | installer/module scripts, scripts/, service hooks, system overlays, webroot/* | broad system toolkit, debloat/restore, CPU/GPU, charge, SELinux, ROM spoof, ReZygisk, MiTool, FOD, sensors, USB/ADB/Fastboot, touchpad, logs |

## 2. HyperCool v1.6 — WebRoot analysis

The WebRoot is a single-page interface with a persistent navigation state and feature forms grouped into three main settings areas plus tools:

- Home/dashboard: device detection, battery/CPU thermal readings, preview-mode bridge status, summary and refresh.
- Kernel tab: heat and kernel controls, grouped into individually enabled options rather than one global optimization switch.
- System tab: protected/background app policies, Doze/device_config, network scanning, app standby/freezer, package disable lists and system telemetry controls.
- More tab: secondary scheduler, I/O, RAM, multitasking, GMS-safe-freeze, tracking, log/diagnostic and cache options; manual RAM/junk cleanup actions.
- Tools tab: configuration backup, restore/import, reset-to-recommended, boot log, revert system changes, save, save-and-reboot.
- App picker: searchable package list with selected count and explicit Done/Cancel.
- State model: unsaved-change indicator; persisted configuration; per-feature last-boot status; preview mode when the privileged bridge is absent.

Behavioral design worth improving and carrying forward independently:

1. Each feature has its own switch and a clear description of what it changes.
2. Disabled switches must produce no writes.
3. Save and apply are separate from editing; boot application is reported per feature.
4. Original system values are backed up and restored when a feature is disabled or the module is removed.
5. Kernel values that naturally reset on reboot are distinguished from persistent Android settings.
6. App selection is searchable and protected system defaults are excluded from restrictive actions.
7. Cleanup operations are explicit actions, not hidden background behavior; the result and timestamp are reported.
8. Configuration import is reviewable before it is saved.
9. Preview mode clearly states that no privileged operation will run.

HyperCool's README describes multiple long-running/periodic exceptions (charge-limit keeper and cache keeper) as distinct from one-shot boot changes. A new implementation should make background workers opt-in, bounded, cancellable, and visible, rather than silently copying the original behavior.

## 3. Ultimate Tools Spinel — WebRoot analysis

The UI is a multi-tab control surface with these functional areas:

- Debloat: installed package search/list, selection, optional UI removal, operation status.
- Restore: detect removed packages, select restore, restore all, show command output.
- Performance: CPU/GPU governor and frequency discovery, apply-all profile, reset defaults.
- OTG / brightness / FOD / charge / spoof / ReZygisk: status, saved-vs-running state, device support messages and feature-specific toggles. OTG Fix and Brightness Fix are excluded from this requested app scope; FOD, charge, spoofing and ReZygisk remain in scope.
- Device: battery, charger, RAM, storage, refresh rate and SELinux state.
- Sensors: hardware sensor inventory and refresh.
- Terminal/logs: root command entry, output, command history controls, log viewer and copy.
- Flash/ADB: external target device state, ADB/Fastboot mode, tool import/status, MiTool integration, install/sideload/flash/boot/erase/wipe/lock/unlock actions and job cancellation.
- USB manager: connected target information, screenshot, remote file browsing, pull/push/delete.
- Touchpad: remote pointer/touch interaction, preview image, connection controls and sensitivity/direct mode settings.
- General log: refresh and copy.

Important architecture distinction: the phone running this app is the ADB host/controller; the connected phone is the target. USB Host enumeration is not itself the ADB protocol. A clean implementation needs a real USB transport, ADB authentication/packet framing, and a separate Fastboot transport. UI elements must be disabled unless that transport is actually available.

## 4. Optimizer v1.1 — WebRoot analysis

The WebRoot emphasizes package management and restore, performance profiles, status and logs. Its curated catalog files are split by ROM family (common, generic, MIUI, One UI, ColorOS). The app-side implementation should treat these as reviewed package metadata, not blindly execute a mass-removal script. Every package action needs a confirmation and a restore record; the default launcher, dialer, SMS, keyboard and core system services need protection.

## 5. Feature inventory across the three references

| Feature | Reference evidence | Clean-room app status in this source |
|---|---|---|
| Root shell / privilege check | all modules | Basic runner and root check implemented; requires device verification |
| Curated debloat and package labels | Optimizer + Spinel | Basic installed-app list and package actions; curated catalog/labels pending |
| Restore removed packages | Optimizer + Spinel | `install-existing` action added to core; UI and end-to-end verification pending |
| CPU policy/governor | HyperCool + Spinel + Optimizer | Discovery, governor write, backup and restore implemented |
| CPU min/max frequency | HyperCool/Spinel | Pending safe range validation and UI |
| GPU devfreq/KGSL | HyperCool/Spinel | Pending device-specific node adapters |
| I/O scheduler | HyperCool/Spinel | Pending |
| VM/RAM/zRAM/LMK | HyperCool/Spinel | Pending |
| Thermal monitoring/caps | HyperCool/Spinel | Basic zone detection only; control profiles pending |
| Charge telemetry/current limit/night charge | HyperCool/Spinel | Android battery snapshot only; charge control pending |
| Doze/app standby/protected apps/freezer | HyperCool | Pending |
| Network scan/data saver/telemetry | HyperCool | Pending |
| Cache/junk/database maintenance | HyperCool | Pending; must be explicit and data-safe |
| SELinux state | Spinel | Read-only status implemented |
| SELinux mode changes | Spinel | Not implemented; not a universal performance feature |
| ROM/device spoof profiles | Spinel | Pending; compatibility and app-integrity implications need review |
| ReZygisk | Spinel | Pending; no third-party binary is bundled |
| MiTool | Spinel | Pending; external tool dependency must be disclosed |
| FOD diagnostics/control | Spinel | Pending; device/overlay-specific |
| Sensors/camera/fingerprint diagnostics | Spinel | Pending |
| USB ADB host | Spinel | Pending real ADB protocol transport |
| Wireless Debugging | app requirements | Pending pairing/connect protocol |
| APK/split APK deployment | Spinel/app requirements | Pending |
| Fastboot | Spinel | Pending; destructive actions require target verification and confirmation |
| Remote file manager/screenshots | Spinel | Pending |
| Touchpad/input forwarding | Spinel | Pending |
| Logcat/process monitor | Spinel | Pending |
| Backup/import/export/revert | HyperCool + Spinel | Pending unified implementation |
| Theme/navigation | HyperCool design inspiration | Compose app shell implemented independently |

## 6. Clean-room rules and exclusions

- Only OTG Fix and Brightness Fix are excluded from the requested feature scope.
- Do not bundle original ZIPs, extracted WebRoot HTML/CSS/JS, original shell scripts, proprietary binaries, or ReZygisk payloads in this app source.
- Reimplement observable behavior and user workflows independently; do not copy source code or assets.
- Third-party integrations (for example ReZygisk or MiTool) require separately reviewed licensing, version compatibility and explicit installation/import handling.
- Every device-specific write must detect the actual node, read the original value, validate the allowed value, write once, read back, and offer restore.
- Unsupported controls must say unsupported; no fake success states.
- No optimization is applied automatically merely because root is granted. User-selected feature switches govern all writes.

## 7. Test handoff status

This package is a source checkpoint for the user's Android/Gradle build and device testing, not a finished feature-complete release. The source currently implements the Compose shell, root runner, CPU governor discovery/change/restore, package actions, battery snapshot and SELinux status. The table above is the authoritative pending-work list. Build and runtime status must be filled from the user's actual build/test results; no APK build is claimed here.
