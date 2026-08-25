# iOS Third-Party Pod Privacy Manifest Audit

**Linear:** BUT-596
**Sprint:** Final store-submission close-out — 2026-04-26
**Companion doc:** `docs/ops/ios-privacy-manifest-audit.md` (BUT-568) — covers
first-party declarations and methodology.
**Manifest file:** `ios/Runner/PrivacyInfo.xcprivacy`

> **Restored 2026-08-25, inventory NOT re-run.** Deleted in `c79af46c5` (2026-06-24) as an
> "unreferenced ops runbook" — wrong: `STORE_SUBMISSION_CHECKLIST.md:59` names it, and
> `ios-privacy-manifest-audit.md` names it as its companion.
>
> **Every status value below is the 2026-04-25 snapshot.** It was deliberately not rewritten on
> restore: "Ships own manifest?" needs `pod install` on macOS, which this Windows workstation
> cannot run — the same constraint the original audit records. The measured `pubspec.yaml` delta
> is in "Dependency drift since this audit" at the end of this file, and it is large enough that
> **the conclusion "no pod is currently flagged as definitively MISSING" no longer holds** — see
> the amended "Gaps requiring action" section.

This document audits every third-party pod linked into the Runner target for
the presence of a bundled `PrivacyInfo.xcprivacy`. Apple's review pipeline
auto-merges per-pod manifests at archive time; gaps must either be closed by
upgrading the pod, declared at app level, or escalated upstream.

## Status legend

| Value | Meaning |
|---|---|
| **PRESENT** | Pod ships `PrivacyInfo.xcprivacy` in its podspec resource bundle. |
| **MISSING** | Pod does not ship a manifest and accesses required-reason APIs / collects data. |
| **NOT_REQUIRED** | Pod has no required-reason API usage and does not collect user data (e.g. pure-Dart wrapper, build-time only, on-device compute only). |
| **UNVERIFIED_LOCAL** | Cannot verify on this Windows workstation (no `pod install` artefacts). Action: re-run audit on the macOS CI runner — see "How to verify on CI" below. |

## Source of truth

The pod versions below are derived from `pubspec.yaml` constraints
(`^X.Y.Z` resolves to the latest `>= X.Y.Z, < (X+1).0.0`). The actual locked
version lands in `ios/Podfile.lock` at `pod install` time on macOS. This
audit must be reconciled against `Podfile.lock` once it is regenerated on
the build machine.

## Pod inventory and manifest status

Versions are the `pubspec.yaml` floor (caret-resolved to the latest
compatible release as of 2026-04-25). Upstream-manifest status is taken
from the pod's published source repository.

### Firebase iOS SDK (FirebaseCore 11.x family)

All Firebase pods ship `PrivacyInfo.xcprivacy` since Firebase iOS SDK 10.17
(October 2023) and have been continuously maintained through 11.x.

| Pod (FlutterFire) | Version | Native pod | Manifest | Action |
|---|---|---|---|---|
| firebase_core | ^4.2.1 | FirebaseCore 11.x | PRESENT | OK |
| firebase_auth | ^6.1.2 | FirebaseAuth 11.x | PRESENT | OK |
| cloud_firestore | ^6.1.0 | FirebaseFirestore 11.x | PRESENT | OK |
| firebase_database | ^12.1.3 | FirebaseDatabase 11.x | PRESENT | OK |
| firebase_storage | ^13.0.4 | FirebaseStorage 11.x | PRESENT | OK |
| firebase_analytics | ^12.0.4 | FirebaseAnalytics 11.x | PRESENT | OK |
| firebase_app_check | ^0.4.0 | FirebaseAppCheck 11.x | PRESENT | OK |
| firebase_messaging | ^16.0.4 | FirebaseMessaging 11.x | PRESENT | OK |
| firebase_performance | ^0.11.0 | FirebasePerformance 11.x | PRESENT | OK |
| firebase_crashlytics | ^5.0.4 | FirebaseCrashlytics 11.x | PRESENT | OK |
| firebase_remote_config | ^6.0.4 | FirebaseRemoteConfig 11.x | PRESENT | OK |
| cloud_functions | ^6.0.4 | FirebaseFunctions 11.x | PRESENT | OK |

### Flutter community / first-party plugins

| Pod | Version (pubspec) | Manifest | Action |
|---|---|---|---|
| shared_preferences | ^2.3.2 | PRESENT (since 2.2.x) | OK |
| path_provider | ^2.1.4 | PRESENT (declares FileTimestamp) | OK |
| image_picker | ^1.1.2 | PRESENT (declares FileTimestamp + Photos) | OK |
| url_launcher | ^6.3.1 | PRESENT | OK |
| package_info_plus | ^9.0.1 | PRESENT (since 8.x) | OK |
| connectivity_plus | ^7.1.0 | PRESENT (since 5.x) | OK |
| device_info_plus | ^12.4.0 | PRESENT (since 10.x) | OK |
| share_plus | ^12.0.2 | PRESENT (since 8.x) | OK |
| wakelock_plus | ^1.4.0 | PRESENT (since 1.2.x) | OK |
| file_picker | ^10.3.3 | PRESENT (since 8.x) | OK |
| permission_handler | ^12.0.1 | PRESENT (since 11.x) | OK |
| flutter_local_notifications | ^20.1.0 | PRESENT (since 18.x) | OK |
| flutter_secure_storage | ^10.0.0 | PRESENT (since 9.x) | OK |
| image_cropper | ^12.0.0 | PRESENT (since 8.x) | OK |

### Third-party / community pods (lower assurance)

| Pod | Version (pubspec) | Manifest | Action |
|---|---|---|---|
| freerasp | ^7.5.1 | UNVERIFIED_LOCAL — Talsec confirmed manifest in 7.4+ release notes | OK pending CI verification; app-level UserDefaults CA92.1 covers worst case |
| sqlcipher_flutter_libs | ^0.6.4 | UNVERIFIED_LOCAL — upstream `sqlite_flutter_libs` added manifest in 0.5.27 | OK pending CI verification; app-level FileTimestamp 3B52.1 covers worst case |
| cached_network_image | ^3.4.1 | NOT_REQUIRED at pod level (pure-Dart wrapping flutter_cache_manager); no native iOS code | App-level FileTimestamp 3B52.1 covers cache-eviction mtimes |
| flutter_image_compress | ^2.3.0 | UNVERIFIED_LOCAL — manifest added in 2.2.0 | OK pending CI verification; app-level FileTimestamp 3B52.1 covers worst case |
| flutter_inappwebview | ^6.1.5 | UNVERIFIED_LOCAL — manifest added in 6.1.0 | OK pending CI verification; app-level UserDefaults CA92.1 covers worst case |
| flutter_onnxruntime | ^1.6.4 | NOT_REQUIRED — on-device inference, no API usage requiring declaration | OK |
| receive_intent | ^0.2.0 | NOT_REQUIRED — Android-only plugin, no iOS native target | OK |
| algoliasearch | ^1.46.1 | NOT_REQUIRED — pure-Dart REST client | OK; data-collection (search queries) declared at app level |

### Pure-Dart packages (no iOS native target)

These have no podspec and therefore no manifest is possible or required:
`provider`, `get_it`, `drift`, `http`, `crypto`, `uuid`, `intl`,
`collection`, `rxdart`, `clock`, `path`, `html`, `html_unescape`, `csv`,
`excel`, `timeago`, `archive`, `sembast`, `sembast_web`, `sqlite3`, `web`.

## Gaps requiring action

**AMENDED 2026-08-25 — the paragraph below is scoped to the pods that were in `pubspec.yaml` on
2026-04-25. It says nothing about the fourteen pods added since, none of which has ever been
audited (see "Dependency drift"). Do not read it as "the app is clear".** Two of the new ones
are the highest-assurance-risk additions in the app's history: `record` (microphone capture) and
`whisper_ggml_plus` (bundled native inference engine). Treat the app-level coverage claim as
UNVERIFIED until the macOS pass runs.

After upstream review, no pod **from the April inventory** is currently flagged as definitively MISSING.
Five pods are `UNVERIFIED_LOCAL` (freerasp, sqlcipher_flutter_libs,
flutter_image_compress, flutter_inappwebview, plus one of the older
plus-plugins variants depending on what `pod install` resolves) and need
confirmation on the macOS CI runner. App-level coverage already exists for
the worst case of each:

| Risk | App-level mitigation in `Runner/PrivacyInfo.xcprivacy` |
|---|---|
| freerasp without manifest | UserDefaults `CA92.1` |
| flutter_inappwebview without manifest | UserDefaults `CA92.1` |
| sqlcipher_flutter_libs without manifest | FileTimestamp `3B52.1` |
| flutter_image_compress without manifest | FileTimestamp `3B52.1` |
| Firestore disk-space probing not auto-merged | DiskSpace `E174.1` |
| Performance Monitoring boot-time not auto-merged | SystemBootTime `35F9.1` |

If CI verification turns up a genuine MISSING (manifest absent AND no
app-level coverage exists), follow the escalation playbook below.

## Escalation playbook for MISSING pods

1. **Upgrade path exists** — bump the pod to the version that ships a
   manifest. Update `pubspec.yaml`, run `flutter pub get`, re-run
   `pod install`, re-verify.
2. **No upgrade path** — file an upstream issue with the following
   draft body. Replace `<POD>` and `<VERSION>` placeholders.

   ```
   Title: Add PrivacyInfo.xcprivacy to <POD> for App Store compliance

   Apple has required a per-framework PrivacyInfo.xcprivacy since
   1 May 2024 for any SDK that uses required-reason APIs or collects
   user data. <POD> v<VERSION> currently does not ship one, which
   blocks App Store submission for apps depending on it.

   Required-reason API categories observed via static analysis of
   the source tree:
     - <list categories, e.g. NSPrivacyAccessedAPICategoryUserDefaults>

   References:
     - https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
     - https://developer.apple.com/documentation/bundleresources/privacy_manifest_files/describing_use_of_required_reason_api

   Happy to submit a PR with a minimal manifest if maintainers agree
   on the wording.
   ```

3. **Maintainer unresponsive (>= 30 days)** — declare the pod's
   required-reason APIs at app level in `Runner/PrivacyInfo.xcprivacy`
   with a comment naming the pod and the upstream issue URL. Track the
   override in this document under a new "App-level overrides" section.

## How to verify on CI

After `pod install` runs on the macOS build agent, fail the build if any
linked pod is missing a manifest. Add the following step to the iOS build
job (e.g. `.github/workflows/ios-archive.yml` or its sprint successor):

```bash
# Fail if any pod in ios/Pods is missing PrivacyInfo.xcprivacy.
# Allow-list pods that genuinely don't need one (pure-Dart wrappers,
# Android-only shims) by listing their directory names.
ALLOWLIST=(
  "Flutter"
  "FlutterPluginRegistrant"
  "Pods"
)

missing=()
for pod_dir in ios/Pods/*/; do
  pod_name="$(basename "$pod_dir")"
  # Skip pods on the allowlist
  for allowed in "${ALLOWLIST[@]}"; do
    if [[ "$pod_name" == "$allowed" ]]; then continue 2; fi
  done
  if ! find "$pod_dir" -name "PrivacyInfo.xcprivacy" -print -quit | grep -q .; then
    missing+=("$pod_name")
  fi
done

if [[ ${#missing[@]} -gt 0 ]]; then
  echo "Pods missing PrivacyInfo.xcprivacy:"
  printf '  - %s\n' "${missing[@]}"
  echo "Reconcile against docs/ops/ios-third-party-privacy-manifests.md"
  echo "and either upgrade the pod, file upstream, or add app-level"
  echo "coverage in ios/Runner/PrivacyInfo.xcprivacy."
  exit 1
fi
```

If/when Apple ships `xcrun privacy-manifests aggregate` (announced at
WWDC, not yet stable as of Xcode 15.4), prefer that — its diagnostics are
richer than this shell loop.

## Dependency drift since this audit

**Measured 2026-08-25** against `pubspec.yaml`. This is the canonical drift record; the
companion doc `ios-privacy-manifest-audit.md` points here rather than keeping a second copy.
Nothing below is a manifest verdict — it is the list of what a macOS re-audit has to cover.

Of the **37 versioned rows** in the April SDK inventory: **8 unchanged**, **28 moved**,
**1 removed**.

### Removed since April

| Package | Replaced by | Why |
|---|---|---|
| `receive_intent` | `app_links` | BUT-434 — unverified publisher, single maintainer, Android-only |
| `excel` | `xml` + `archive` (own `XlsxReader`) | BUT-503 |
| `sembast` | `sembast_web` only | web-platform CacheDao backend |

### Added since April — NEVER AUDITED

Fourteen packages entered `pubspec.yaml` after this audit and appear in no table above.
Seven of them have an iOS native component and therefore a manifest question:

| Package | Why it matters on iOS | Manifest status |
|---|---|---|
| `record` | **Microphone capture.** Writes a temp WAV to app storage | UNAUDITED |
| `whisper_ggml_plus` | **Bundles whisper.cpp 1.8.3 as compilable source** — a native inference engine, not a thin bridge. Exact-pinned (1.5.2) per Security-panel condition | UNAUDITED |
| `google_mlkit_text_recognition` | Bundles ML Kit pods (Latin script model) for on-device OCR | UNAUDITED |
| `flutter_tts` | OS bridge to `AVSpeechSynthesizer` | UNAUDITED |
| `app_links` | Deep-link / share-intent handling | UNAUDITED |
| `http_certificate_pinning` | Pin enforcement; exact-pinned 3.0.1 (BUT-793) | UNAUDITED |
| `in_app_review` | StoreKit review prompt (BUT-678) | UNAUDITED |

Seven are pure-Dart or asset-only and need no podspec: `dio`, `fl_chart`, `image`, `timezone`,
`xml`, `meta`, `cupertino_icons`. (Platform classification is from each package's own pubspec
note and pub.dev platform support — **confirm at `pod install` time**, do not file from it.)

### Version drift on existing rows

All 28 changed rows need their "Ships own manifest?" answer re-derived, because a manifest can
appear *or* disappear across versions. Notable ones:

| Package | April | Now | Note |
|---|---|---|---|
| `freerasp` | 7.5.1 | **8.0.0** | Major bump; was already `UNVERIFIED_LOCAL` |
| `flutter_local_notifications` | 20.1.0 | **^21.0.0** | Major bump (BUT-435) |
| `file_picker` | 10.3.3 | **^11.0.2** | Major bump |
| `device_info_plus` | 12.4.0 | **12.3.0 (PINNED, downgrade)** | 12.4.0+ ships a speculative iOS-26 API that fails Build Validation |
| `connectivity_plus` | 7.1.0 | **7.0.0 (PINNED, downgrade)** | Same speculative iOS-26 API; re-confirmed 2026-06-24 (BUT-1367) |
| `firebase_app_check` | 0.4.0 | **0.4.5 (PINNED)** | Security primitive (BUT-793) — bump explicitly |
| All eleven `firebase_*` + `cloud_functions` | 4.2.1 / 6.x family | `firebase_core ^4.7.0` etc. | **The "FirebaseCore 11.x" assumption above is now unverified** — the FlutterFire versions moved and the native SDK family must be re-derived from `Podfile.lock`, not assumed |

`device_info_plus`, `connectivity_plus`, `firebase_app_check`, `freerasp`,
`http_certificate_pinning` and `whisper_ggml_plus` are pinned to an exact version on purpose
(`image` and `xml` carry Dart-SDK ceilings, which is a different thing). Read the reason beside
each one in `pubspec.yaml` before "fixing" any of them.

## Re-audit triggers

Re-run this audit when **any** of the following happens:

- Every 6 months on calendar cadence (next: 2026-10-25).
- After a major Firebase iOS SDK bump (10.x → 11.x → 12.x). Firebase
  occasionally adds new required-reason API usage that needs to be
  cross-checked.
- Whenever a new pod is added to `pubspec.yaml`. Add a row to the table
  before merging the dependency change.
- Whenever Apple publishes a new required-reason API category or new
  reason code (announced via Apple Developer News).
- After any App Store rejection citing privacy-manifest issues.
- When the underlying iOS deployment target is raised (currently 17.0)
  and previously-irrelevant APIs become available.

## Change log

- 2026-04-25 — initial audit (BUT-596). Cannot run `pod install` on this
  Windows workstation; UNVERIFIED_LOCAL flags must be cleared by the
  macOS CI runner. App-level coverage in `Runner/PrivacyInfo.xcprivacy`
  protects against every UNVERIFIED gap turning out to be genuine.
- 2026-08-25 — restored after an incorrect deletion in `c79af46c5`. Inventory NOT re-run
  (still needs macOS). Added the measured "Dependency drift since this audit" section — 37
  April rows: 8 unchanged, 28 moved, 1 removed, plus 14 packages added since, 7 of them with
  an iOS native component and none ever audited. Scoped the "no pod is definitively MISSING"
  conclusion to the April inventory, because it never covered the new ones.
