# freeRASP runbook (BUT-426)

This runbook covers how to retrieve, configure, and verify the freeRASP
credentials needed for a production release build of Butlery. Without
these the iOS bundle/team check and the Android signing-cert check both
short-circuit, so the rest of RASP runs with no integrity binding to
the real release artifact.

## TL;DR

The **Android cert hash is committed** to source as the default for the
current `upload-keystore.jks` — `flutter build apk --release` works
today without any extra dart-defines.

The **iOS teamId is a placeholder** until Apple Developer Program
enrollment. iOS release builds **crash at startup** until either:
- the real teamId is committed as the default, OR
- the build pipeline passes `--dart-define=FREE_RASP_TEAM_ID=<real>`.

Both values are also overridable at build time via `--dart-define`:

```bash
# Android (works today; dart-define only needed if rotating the keystore)
flutter build apk --release

# Or with overrides
flutter build apk --release \
  --dart-define=FREE_RASP_ANDROID_CERT_HASH="<new-base64-sha256>"

# iOS (after Apple Developer Program enrollment)
flutter build ios --release \
  --dart-define=FREE_RASP_TEAM_ID="<real-team-id>"
```

Debug builds (`flutter run`, `flutter test`) work without any defines.

## Where to get the values

### `FREE_RASP_TEAM_ID`

The Talsec team id assigned when the freeRASP licence was issued.

1. Sign in to <https://docs.talsec.app>.
2. Account → Team — copy the team id (alphanumeric, ~10 chars).
3. Save it to the secrets store (1Password / GCP Secret Manager) under
   `freerasp/team-id`.

This is **not** the same as your Apple Developer Team ID. Talsec uses
its own team identifier; the iOS Apple Team ID is set elsewhere
(`ios/Runner.xcodeproj`).

### `FREE_RASP_ANDROID_CERT_HASH`

The base64-encoded SHA-256 fingerprint of the keystore signing the
release APK / AAB. Different signing certificates → different hashes,
so the value rotates whenever the upload keystore rotates.

```bash
keytool -list -v \
  -keystore android/app/upload-keystore.jks \
  -alias upload \
  | grep "SHA256:" \
  | awk '{print $2}' \
  | xxd -r -p \
  | base64
```

The output is the base64 string to pass via the dart-define. Save it to
secrets under `freerasp/android-cert-hash`.

If you ever rotate the upload keystore, the value here MUST be
re-generated and re-set in CI before the next release. Otherwise
release builds crash at startup.

## CI integration

The release pipeline must inject both dart-defines from the secrets
store at build time. Example (GitHub Actions):

```yaml
- name: Build release APK
  run: |
    flutter build apk --release \
      --dart-define=FREE_RASP_TEAM_ID=${{ secrets.FREE_RASP_TEAM_ID }} \
      --dart-define=FREE_RASP_ANDROID_CERT_HASH=${{ secrets.FREE_RASP_ANDROID_CERT_HASH }}
```

Both secrets must be configured at repo or org level under the same
names. CI runs without them will fail at app startup with a clear
`StateError` referencing this runbook.

## Verification

1. Build a release APK with the dart-defines set.
2. Install on a rooted Android emulator (or a jailbroken iOS device).
3. Open the app — `AppLogger.warning('Device integrity: root/jailbreak
   detected')` should appear in the device log within a few seconds of
   startup.
4. Without the dart-defines, `flutter build apk --release` produces an
   APK that crashes at first launch with a `StateError` mentioning
   `BUT-426`. That is the correct behaviour — confirms the guard.

## Why this is a hard fail (not a warning)

Earlier versions of the service logged a warning and continued. The
warning was buried in Crashlytics noise and the app shipped twice with
the placeholder still active. The crash makes it impossible to ship
without the real values:

- Internal testing / TestFlight: app fails to launch → caught
  immediately.
- App Store / Play Store review: the reviewer's launch fails → the
  release is rejected before it goes live.
- Production users: never see a broken-RASP build.

Trade-off accepted: a missing CI secret stops a release. That is
preferable to a silent security regression.

## Cross-references

- `lib/services/device_integrity_service.dart` — the service + the
  `assertReleaseConfig` guard.
- `test/unit/services/device_integrity_service_test.dart` — pins the
  guard's behaviour.
- BUT-79 — release keystore generation (prerequisite for the cert hash).
