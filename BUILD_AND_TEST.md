# Build and test handoff

## Environment
- Android Studio or Gradle 8.9+
- JDK 17
- Android SDK Platform 35 and Build Tools 35
- Android 8.0+ (API 26+)

## Build debug APK

```bash
gradle --no-daemon :app:assembleDebug
```

APK path:

```text
app/build/outputs/apk/debug/app-debug.apk
```

## Device test sequence

1. Install the debug APK and open it without granting root; confirm read-only screens work and privileged controls remain unavailable.
2. Grant root when prompted; confirm the root status is reported accurately.
3. Open Performance and record discovered CPU policies and available governors.
4. Apply one available governor only; confirm read-back matches the selected value.
5. Use Restore saved tuning values; confirm the original governor returns.
6. In Apps, test only with a non-essential test package: disable, enable, uninstall-for-user, then restore with `install-existing`.
7. Confirm package actions show their actual command result and do not claim success on non-zero exit.
8. Check battery and SELinux readouts against Android/system output.
9. Send build errors and runtime logs back with the device model, Android version, root manager/version and the exact step that failed.

Do not test debloat on launcher, System UI, dialer, SMS, keyboard, package installer, Settings, Google Play services, or other essential packages. Do not test unimplemented controls by manually writing unknown sysfs values.

## Termux upload workflow

After extracting the ZIP and entering the project directory:

```bash
git status --short
git add -A
git commit -m "Add clean-room optimizer source checkpoint"
git push origin main
```

If the repository is not cloned yet, clone your repository first and copy the extracted project contents into the repository root. Do not nest the project one directory deeper by mistake.
