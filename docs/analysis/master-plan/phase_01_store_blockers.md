# Phase 1: Store Submission Blockers (~5 days)

Items you literally cannot submit to App Store / Play Store without.

---

## P1-01 — Change bundle ID from `com.example.butlery` [CRIT]

**Source**: R03:F3-2, R06:6.1, R10:C5.1
**Files**: `android/app/build.gradle.kts:9,24`, `ios/Runner.xcodeproj/project.pbxproj:371,550,572`, `macos/Runner/Configs/AppInfo.xcconfig:11`, `linux/CMakeLists.txt`, `windows/runner/Runner.rc`, `google-services.json:12`, `GoogleService-Info.plist:12`, `.env.*`
**Fix**: Choose production ID (e.g., `se.butlery.app`), update all 11+ config files. Must be done before first submission — cannot change after.
**Effort**: 2h
**Pre-production note**: No existing installs, so package name change is straightforward.

---

## P1-02 — Configure release signing [CRIT]

**Source**: R02:C-04, R03:F3-3, R06:6.2, R10:C5.2
**Files**: `android/app/build.gradle.kts:36-38`
**Fix**: Generate production keystore (Android), configure Team ID + provisioning profile (iOS). Replace `signingConfigs.getByName("debug")` with production signing config.
**Effort**: 2-4h

---

## P1-03 — Remove orphan `NSFaceIDUsageDescription` [HIGH] [DONE]

**Source**: R02:C-09, R06:2.1 (implicit), R09:TS-025, R10:H5.1
**Files**: `ios/Runner/Info.plist:57-59`
**Fix**: Remove the `NSFaceIDUsageDescription` key-value pair. Biometric feature was deleted from scope.
**Effort**: 5 min

---

## P1-04 — No AAB build format in CI [HIGH]

**Source**: R02:C-01, R03:F1-2
**Files**: `build-validation.yml:87`
**Fix**: Change `flutter build apk` to `flutter build appbundle` (Google Play requires AAB). Keep APK as secondary output for testing.
**Effort**: 15 min

---

## P1-05 — Create iOS Privacy Manifest (`PrivacyInfo.xcprivacy`) [CRIT] [DONE]

**Source**: R09:TS-020, R09:TS-021
**Files**: `ios/Runner/` (new file)
**Fix**: Create `PrivacyInfo.xcprivacy` with:
- `NSPrivacyAccessedAPICategoryUserDefaults` (reason CA92.1)
- `NSPrivacyCollectedDataTypes` (email, name, photos, usage data, crash data, performance data)
- `NSPrivacyTracking: false`
Verify third-party pod privacy manifests are bundled (R09:TS-022).
**Effort**: 4h

---

## P1-06 — iOS deployment target too low [HIGH] [DONE]

**Source**: R05:dim6
**Files**: `ios/Runner.xcodeproj/project.pbxproj` (IPHONEOS_DEPLOYMENT_TARGET)
**Fix**: Raise from 12.0 to 13.0. Firebase packages are moving to 13+ minimum.
**Effort**: 30 min

---

## P1-07 — macOS deployment target too low [MED] [DONE]

**Source**: R05:dim6
**Files**: `macos/Runner.xcodeproj/project.pbxproj` (3 places: MACOSX_DEPLOYMENT_TARGET)
**Fix**: Raise from 10.14 to 10.15.
**Effort**: 15 min

---

## P1-08 — Update Windows Runner.rc placeholder metadata [LOW]

**Source**: R06:5.4
**Files**: `windows/runner/Runner.rc:92-96`
**Fix**: Replace `CompanyName "com.example"` and `LegalCopyright "Copyright (C) 2025 com.example"` with actual values.
**Effort**: 5 min

---

## ~~P1-09~~ — ~~Apple Sign-In~~ → Moved to P10-12 [DEFERRED]

**Status**: Moved to Phase 10. App currently only offers email/password auth — Apple Guideline 4.8 only applies when third-party social login is offered. Social login (Google/Apple) is a post-beta decision.

---

## P1-10 — Demo account for App Store review [MED]

**Source**: R10:M5.2
**Fix**: Apple requires a demo account with pre-populated data for review. Create seed script and test credentials.
**Effort**: 4h

---

## P1-11 — App store metadata preparation [MED]

**Source**: R06:6.4, R10:M5.3
**Fix**: Screenshots, descriptions, feature graphics, keywords, content rating, data safety/privacy labels. Required before submission.
**Effort**: 2-3d
