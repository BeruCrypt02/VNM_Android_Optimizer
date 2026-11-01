# MkVenomPro Android Optimizer

A clean-room Android application built with Kotlin, Jetpack Compose and Material 3.

## Project rules
- This repository contains no Magisk/KernelSU/APatch module payloads and no legacy shell scripts.
- Feature concepts were independently reimplemented as native Android application architecture; no original add-on files, code, artwork, or WebUI assets are bundled.
- Root is required for privileged kernel/system tuning. Shizuku may be supported for limited shell operations where Android permits it; it is not treated as a root replacement.
- Device capability detection is read-only. Unsupported controls must remain unavailable.
- Thermal throttling and platform thermal safety mechanisms must never be disabled.
- Every future write operation must capture the original value, verify the write, and provide a restore path.

## Current alpha foundation
- Native Compose dashboard with dark neon visual language.
- Read-only device scan: Android build, SoC properties, root availability, CPU policies, GPU interface, thermal zones and readable I/O schedulers.
- Feature map for CPU/GPU, WALT/scheduler, I/O, RAM, refresh rate, charging care, Doze, freezer and app management.
- No tuning writes or package removals are enabled in this foundation build.

## Build
Open in Android Studio with JDK 17 and Android SDK 35, then run `:app:assembleDebug`.

The GitHub Actions workflow builds a debug APK and stores it as a workflow artifact. It does not upload to GoFile; GoFile upload requires an authorized upload integration/token.
