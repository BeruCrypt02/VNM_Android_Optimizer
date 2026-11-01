# MkVenomPro Android Optimizer

An independent Android device diagnostics and optimization-control project built with Kotlin and Jetpack Compose.

## Current build

- Material 3 interface with a floating capsule navigation bar.
- Dark, light, and system appearance modes persisted before the first Compose frame.
- Read-only device, kernel-interface, thermal-zone, I/O scheduler, root-availability, and battery inspection.
- Installed application inventory and launch.
- ADB/Fastboot command reference catalog and local partition-name notes.
- USB Host capability detection (not an ADB-over-USB implementation).

## Architecture and truthfulness

The phone running the app is intended to be the ADB Host/controller; a separately connected Android phone/tablet is the Target. USB ADB, Wireless ADB, and Fastboot require distinct transport implementations. The current source does not yet contain those transports, package deployment, remote package control, interactive shell, file transfer, Logcat, or screenshot capture. See [TOOLKIT_IMPLEMENTATION_STATUS.md](TOOLKIT_IMPLEMENTATION_STATUS.md) and [FEATURE_AUDIT.md](FEATURE_AUDIT.md).

The supplied feature references were reviewed for behavior and feature families, then excluded from the public source. No reference module source, scripts, archives, WebUI bundles, or artwork are redistributed here. All future implementations must be independent and capability-gated.

## Build

Open in Android Studio with JDK 17 and Android SDK Platform 35, then run `:app:assembleDebug`.

## Requirements

- Android 8.0 (API 26) or newer.
- Android Studio / Gradle environment with Android Gradle Plugin and Kotlin Compose plugin compatible with the project root build configuration.

## Safety

This source currently performs diagnostics and read-only discovery. It does not alter thermal protections, SELinux policy, charging behavior, kernel tuning values, or installed packages.


## Requested feature scope

Only OTG/USB fixes and brightness fixes/services are excluded. Fast Charge Control, SELinux mode management, Game Spoofer, ReZygisk-related functionality, MiTool-related tools, FOD diagnostics/fixes, and database maintenance remain in scope. Their presence in the scope does not mean they are already implemented; see `FEATURE_AUDIT.md` for current status.
