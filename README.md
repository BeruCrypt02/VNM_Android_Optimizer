# MkVenomPro Android Optimizer

A clean-room Android device-inspection and maintenance dashboard built with Kotlin, Jetpack Compose and Material 3.

## Current features
- Device dashboard with Android version, model, chipset/platform and kernel information.
- Read-only CPU policy, GPU interface, thermal-zone and I/O scheduler discovery.
- Battery level, charging state and battery health information through Android APIs.
- Installed-app inventory with app icons, package names, launch action and system-app labels.
- Search and filter installed applications.
- ADB/Fastboot reference command catalog with risk labels. Commands are displayed for reference only and are **not executed**.
- Custom partition-name notes stored locally; no partition probing or flashing.
- Root availability indicator. Root is detected but never requested or used to modify the device.
- Dark neon interface and bottom navigation.

## Safety and scope
This app is intentionally inspection-first. It does not unlock bootloaders, flash partitions, install kernels, disable thermal protections, execute arbitrary shell commands, or uninstall/disable packages. ADB/Fastboot entries are educational references, not an execution console. Never flash firmware unless you have verified the exact device, build, partition layout and recovery path.

## Build
- Android Studio Ladybug or newer
- JDK 17
- Android SDK Platform 35
- Gradle 8.9

Open this folder in Android Studio and run the `app` configuration. CI builds a debug APK on pushes and pull requests.

## Package
`com.mkvenompro.optimizer`
