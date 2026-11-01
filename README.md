# MkVenomPro Android Optimizer

Android application source built with Kotlin, Jetpack Compose and Material 3.

## Included in this source package

- Existing device, battery, installed-app, performance-interface and USB-host inspection screens retained.
- Persisted appearance setting: System / Dark / Light. The saved selection is loaded before the first Compose frame to avoid a theme flash at startup.
- App icon rendering through Drawable-to-Bitmap conversion.
- Original source archives for the three supplied legacy modules, plus extracted copies for code review, under `legacy-modules/`.
- GitHub Actions workflow using Java 17, Android SDK Platform 35 and Gradle 8.9.

## Important implementation status

This package is a preservation and UI-foundation update, **not a claim that every legacy feature has already been ported into the Android app**.

The current Android app still has inspection/reference functionality in several areas. A real phone-as-host controller (USB ADB transport, wireless pairing/connection, interactive shell, remote app deployment, file transfer and remote Logcat) requires a dedicated ADB transport implementation and device-side permission/connection handling. Those operations must not be represented by non-working buttons. The original module scripts are preserved as source material and are not automatically executed by the app.

Before enabling any legacy system-tuning action, it must be individually ported, checked for device compatibility, given clear permission requirements, and provided with backup/restore and failure handling. Unsupported or unavailable controls should remain disabled with an explanation rather than pretending to work.

## Build

- JDK 17
- Android SDK Platform 35
- Android Build Tools 35.0.0
- Gradle 8.9

Run:

```bash
gradle --no-daemon :app:assembleDebug
```

The debug APK is generated at:
`app/build/outputs/apk/debug/app-debug.apk`

## Package

`com.mkvenompro.optimizer`
