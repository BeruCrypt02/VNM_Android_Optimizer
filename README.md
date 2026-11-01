# MkVenomPro Android Optimizer

Independent clean-room Android optimizer source. The app provides a refreshed Compose dashboard, device/battery status, root-aware CPU governor tuning with backup/restore, package actions, and a root diagnostics console.

## Requirements
- Android Studio / Gradle Android plugin environment
- Android SDK 35
- JDK 17
- Android 8.0+ (minSdk 26)

## Build

```bash
gradle --no-daemon :app:assembleDebug
```

## Root features
Root operations require a working `su` provider and explicit permission. CPU governor writes are restricted to discovered cpufreq governor nodes and preserve the original value for restoration. Package management actions affect the current Android user. Review all actions before approving root prompts.

## Scope and status
Only OTG Fix and Brightness Fix are excluded. Other requested features remain in scope; see `FEATURE_AUDIT.md` and `TOOLKIT_IMPLEMENTATION_STATUS.md` for exact implemented and pending status. Do not treat an inventory entry as a working feature.

## Clean-room policy
Reference module archives, extracted scripts, binary payloads, and original WebUI assets are not part of this public source. Functionality is being independently reimplemented.
