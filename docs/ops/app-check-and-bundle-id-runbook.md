# App Check enforcement + iOS bundle ID rectification — runbook

Covers BUT-759 (Firebase iOS app bundle ID mismatch) and BUT-760 (App Check
enforcement on Android + iOS). The two are intentionally bundled — App Check
on iOS can't be registered until the iOS Firebase app is registered with the
correct bundle ID.

**Pre-existing in-repo state (already done — do NOT redo):**

- `firebase_app_check: ^0.4.0` is in `pubspec.yaml`.
- `lib/main.dart:213` already calls `FirebaseAppCheck.instance.activate(...)`
  with `AndroidPlayIntegrityProvider` (release) + `AppleDebugProvider`
  (debug). After 2026-05-03 the iOS release path is
  `AppleAppAttestWithDeviceCheckFallbackProvider` (was `AppleDeviceCheckProvider`).
- Web already activates `ReCaptchaV3Provider` and the web/windows apps are
  already enforced in Console.

**What's left = console-side registrations + enforcement flip.** No more
Flutter code needs to change unless something below surfaces a surprise.

---

## Phase 1 — BUT-759: Fix the iOS Firebase app bundle ID

### Why

`lib/firebase_options.dart` has `iosBundleId: 'com.example.butlery'`
(default from `flutter create`); the actual Xcode project ships
`PRODUCT_BUNDLE_IDENTIFIER = se.butlery.app`. Until this matches:

- iOS calls to Firebase APIs send `X-Ios-Bundle-Identifier: se.butlery.app`
  but Firebase's iOS app registration is `com.example.butlery` → mismatch.
- App Check on iOS (Phase 2) cannot be registered against the placeholder
  app — App Attest needs the real bundle ID.
- Two orphan `com.example.butlery` apps still appear in App Check → Apps.

### Steps (USER does these — code can't)

1. **Sign in to Firebase Console with the project-owner account.**
   - URL: <https://console.firebase.google.com/project/butlery-app-1>
   - The current Chrome session is signed in to a Google account that
     doesn't list `butlery-app-1` — switch to the project-owner account.

2. **Add a new iOS app for `se.butlery.app`.**
   - Project Settings → Your apps → Add app → iOS
   - iOS bundle ID: `se.butlery.app`
   - App nickname: `Butlery iOS`
   - App Store ID: leave blank (no submission yet)
   - Download `GoogleService-Info.plist` when prompted

3. **Replace `ios/Runner/GoogleService-Info.plist`** with the downloaded file.

4. **Regenerate `lib/firebase_options.dart`** locally:

   ```bash
   cd C:/Butlery/butlery
   flutterfire configure --project=butlery-app-1
   ```

   Select the existing apps for Web/Android/Windows and the new
   `se.butlery.app` iOS app. Confirm `firebase_options.dart` updates so
   the `ios` and `macos` blocks have:
   - `iosBundleId: 'se.butlery.app'`
   - a new `appId` matching the new Firebase iOS app registration

5. **Delete the two orphan `com.example.butlery` iOS apps.**
   - Project Settings → Your apps → for each `com.example.butlery` entry:
     ⋮ menu → Remove app
   - Confirm with `App ID` text input
   - Also clear them from App Check → Apps if they appear there

6. **Smoke-test on a real iPhone or simulator:**
   - `flutter run -d <iOS device>`
   - Sign in with a test account → confirm Auth + Firestore round-trip work
   - Look for `[firebase_core] App initialized` in logs (no bundle-mismatch warnings)

### Acceptance for BUT-759

- [ ] Project Settings → Apps shows exactly one iOS app, bundle `se.butlery.app`
- [ ] `lib/firebase_options.dart` `ios` and `macos` blocks have `iosBundleId: 'se.butlery.app'`
- [ ] Two `com.example.butlery` apps removed
- [ ] iOS build authenticates against Firebase

---

## Phase 2 — BUT-760: Register attestation providers + enforce App Check

**Blocked by Phase 1.** App Attest registration needs the iOS Firebase app
to exist with the correct bundle ID first.

### 2A — Register Play Integrity for Android

1. **Link Play Console to Firebase project.**
   - Project Settings → Integrations → Google Play → Link
   - Select the `se.butlery.app` Play Console listing (or create one if not yet)

2. **Enable Play Integrity API in GCP.**
   - <https://console.cloud.google.com/apis/api/playintegrity.googleapis.com/overview?project=butlery-app-1>
   - If not enabled: ENABLE button, takes ~30s

3. **Register the Android app with the Play Integrity provider.**
   - <https://console.firebase.google.com/project/butlery-app-1/appcheck/apps>
   - Click the Android app `Butlery (Android) se.butlery.app`
   - Play Integrity → Register
   - Token TTL: keep default (1 hour)

### 2B — Register App Attest for iOS (after Phase 1 lands)

1. **Apple Developer Team ID.**
   - The Linear ticket notes this requires Apple Developer Program enrollment
     for the Team ID. Free Apple IDs don't give one.
   - If enrolled: confirm the Team ID matches what's in
     `ios/Runner/Runner.xcodeproj/project.pbxproj` (`DEVELOPMENT_TEAM`).
   - If not enrolled yet: skip 2B and 2C until enrollment lands. Android-only
     enforcement is still useful and can ship now.

2. **Enable App Attest capability in Xcode.**
   - Open `ios/Runner.xcworkspace` in Xcode
   - Runner target → Signing & Capabilities → + Capability → App Attest
   - This adds `com.apple.developer.devicecheck.appattest-environment` to the
     entitlements file. Set value to `production` for App Store builds,
     `development` for TestFlight/Xcode builds.

3. **Register the iOS app with the App Attest provider.**
   - <https://console.firebase.google.com/project/butlery-app-1/appcheck/apps>
   - Click the iOS app `Butlery iOS se.butlery.app`
   - App Attest → Register
   - Token TTL: keep default (1 hour)

### 2C — Switch products from Unenforced → Enforce

**Console UX changed (2026):** the explicit "Monitor" toggle was dropped
from new product flows — it's now binary `Unenforced ↔ Enforce`. The
Enforce confirmation modal explicitly lists Registered vs Unregistered
apps and warns that unregistered apps will be denied. Cloud Firestore
is still in legacy Monitoring mode (configured before the UX change)
and continues to log iOS verification rates without blocking — leave
it there as a free dashboard.

**Hard prerequisite:** every platform that sends real traffic to a
product must be registered before that product is enforced. Today
that means iOS App Attest (Phase 2B) must land first. Flipping
Storage / Auth / Firestore / Functions to Enforce while iOS App Check
is unregistered locks every iOS user out of that product instantly.

For each Firebase product (Storage, Authentication, Firestore,
Functions, Realtime Database):

1. **Confirm registered apps in the Enforce modal.**
   - <https://console.firebase.google.com/project/butlery-app-1/appcheck>
   - Click the product row → scroll to bottom of the expanded panel →
     click the blue `Enforce` button
   - The modal shows two columns: Registered apps (verified requests
     allowed) and Unregistered apps (all requests denied). All
     platforms in production traffic must appear under Registered
     before clicking the bottom-right `Enforce` button.

2. **Stage the rollout — easiest first.**
   - Suggested order: Storage → Authentication → Firestore →
     Functions → Realtime Database. Storage has the smallest blast
     radius (file uploads only); Firestore is the highest-traffic
     and highest-risk to flip last.
   - After each enforce, watch the per-product dashboard for 24h
     before flipping the next.

3. **If a flip causes lockouts, revert in seconds.**
   - Same path → click the same button (now reads `Don't enforce`
     or similar) → Confirm. Console-side flips are reversible without
     code changes.

### Acceptance for BUT-760

- [x] Android (`se.butlery.app`) registered with Play Integrity (2026-05-03)
- [ ] iOS (`se.butlery.app`) registered with App Attest + DeviceCheck
      fallback — **BLOCKED on Apple Developer Program enrollment**
      (same blocker as BUT-426 freerasp iOS Team ID)
- [x] Two `com.example.butlery` orphan apps removed from App Check
      (30-day pending-delete; auto-purges)
- [x] Flutter activation code matches above (`main.dart:213` —
      AppleAppAttestWithDeviceCheckFallbackProvider already wired)
- [ ] All applicable products in Enforce mode — **blocked on iOS
      registration** (Cloud Firestore in legacy Monitoring; Storage
      and Auth still Unenforced)
- [ ] Then flipped to Enforce per product

---

## Rollback

Both phases are reversible without code changes:

- BUT-759: re-add the old `com.example.butlery` Firebase iOS app (Console)
  and run `flutterfire configure` again to revert `firebase_options.dart`.
- BUT-760: flip Enforce → Monitor → Unenforced per product (Console). The
  Flutter activation code stays — `FirebaseAppCheck.activate` is harmless
  when the providers aren't registered.

If iOS users report sudden lockouts after Enforce: flip back to Monitor
within seconds. The App Check dashboard shows which app/version is failing,
which is enough to triage before re-enforcing.

## Cross-references

- BUT-759 Linear: <https://linear.app/butlery/issue/BUT-759>
- BUT-760 Linear: <https://linear.app/butlery/issue/BUT-760>
- Firebase docs:
  - <https://firebase.google.com/docs/app-check>
  - <https://firebase.google.com/docs/app-check/android/play-integrity-provider>
  - <https://firebase.google.com/docs/app-check/ios/app-attest-provider>
- In-repo activation: `lib/main.dart:213-223`
- Related: `docs/ops/freerasp-runbook.md` (BUT-426 — same Apple Dev Program
  enrollment dependency for iOS)
