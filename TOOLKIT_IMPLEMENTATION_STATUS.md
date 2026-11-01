# Toolkit implementation status

Version 1.1.0 is an initial clean-room implementation pass, not a completed port of all reference functionality.

| Area | Status | Notes |
|---|---|---|
| Compose dashboard / theme | Implemented | New five-section layout; saved theme remains loaded before first frame |
| Root detection / command runner | Implemented | Root process and command I/O run off the UI thread |
| CPU policy discovery | Implemented | Reads exposed cpufreq policy values |
| CPU governor change | Implemented | Writes only discovered governor nodes; backs up original value; restore action |
| Package disable / enable / uninstall for user | Implemented | Root-gated; explicit app selection; package name validation |
| Battery snapshot | Implemented | Android BatteryManager status and health |
| SELinux status | Implemented | Read-only `getenforce` status |
| USB ADB Host | Not implemented | Requires dedicated USB ADB transport; USB host presence is not ADB support |
| Wireless ADB | Not implemented | Pairing and transport protocol are separate work |
| APK / split APK deployment | Not implemented | Requires target selection, validation, confirmation, result handling |
| File transfer / logcat / screenshot / process monitor | Not implemented | No placeholder success controls are shown |
| GPU / I/O / memory tuning | Not implemented | Requires per-node capability discovery and reversible writes |
| Charging controls | Not implemented | Device-specific; telemetry and writable controls must be distinguished |
| SELinux mode changes | Not implemented | State is read-only in this revision |
| Spoofing / ReZygisk / MiTool / FOD | Not implemented | Compatibility and integration work remains |
| Sensors / camera / fingerprint diagnostics | Not implemented | Not yet connected to device APIs |
| Debloat catalog / backup & restore | Not implemented | Must include protected-package safeguards and restore records |
| Database/cache maintenance | Not implemented | No automatic cleanup runs |

Only OTG Fix and Brightness Fix are excluded from the requested scope. Every other feature remains in scope.

Build note: a successful Android build validates compilation only; each feature also needs runtime verification on a rooted and/or target device.
