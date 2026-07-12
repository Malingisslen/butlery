# Store Submission Checklist

Top-level tracker for App Store + Google Play store-submission steps that
require manual action by a human with the right console access. Code-side
work happens in `docs/ops/*-runbook.md` files; this tracker links each
runbook to its filing artefact.

## How to use this file

- Each row maps a runbook (the WHAT) to its filing destination (the
  WHERE) and current state.
- Tick the box when the manual filing step is complete in the relevant
  console.
- Add a date in the "Filed" column.
- If a filing is rejected and re-submitted, log both attempts.

## Filings

| Item | Runbook | Console | Destination for proof | State | Filed |
|---|---|---|---|---|---|
| Google Play Data Safety form | `docs/ops/play-data-safety-runbook.md` | Play Console → App content → Data safety | `docs/store-submission/play-data-safety/YYYY-MM-DD-submitted.png` | Pending user action (BUT-646) | — |
| Apple App Privacy section | `docs/ops/play-data-safety-runbook.md` (cross-ref) + `ios/Runner/PrivacyInfo.xcprivacy` | App Store Connect → App Privacy | n/a (App Store Connect captures internally) | Pending user action | — |
| App Store age rating | `docs/ops/age-rating-runbook.md` §2 | App Store Connect → App Information → Age Rating | n/a (App Store Connect captures internally) | Pending user action (BUT-624) | — |
| Google Play content rating (IARC) | `docs/ops/age-rating-runbook.md` §3 + §5 | Play Console → App content → Content rating | n/a (Play Console captures internally) | Pending user action (BUT-624) | — |
| COPPA / target audience answers | `docs/ops/age-rating-runbook.md` "COPPA target audience" | Play Console → App content → Target audience and content; App Store Connect → Made for Kids | n/a (consoles capture internally) | Pending user action (BUT-720) | — |
| App review demo + reviewer notes | `docs/ops/app-review-demo.md` | App Store Connect → App Review Information; Play Console → Store listing → App access | n/a | Pending user action (BUT-416) | — |
| iOS PrivacyInfo manifest | `docs/ops/ios-privacy-manifest-audit.md` + `ios/Runner/PrivacyInfo.xcprivacy` | Bundled with iOS build (no separate filing) | n/a | Code complete; ships with binary (BUT-568/587/596/603) | n/a |
| Pre-login privacy/ToS reachability | tested in `auth_view_legal_links_test.dart` | n/a (in-app) | n/a | Code complete (BUT-563) | n/a |
| RECORD_AUDIO permission declaration (voice menu prompt) | Declare in the Play Console permissions form: microphone used for on-device speech-to-text of the user's menu request; audio never leaves the device, never stored. Must match `AndroidManifest.xml` comment + `docs/legal/privacy_policy.md` §5 word-for-word in substance. | Play Console → App content → Permissions declaration (+ update Data Safety form: NO audio collection — on-device only) | `docs/store-submission/play-data-safety/YYYY-MM-DD-record-audio.png` | Pending user action (kb-whisper plan, 2026-07-12) | — |
| Apple mic purpose string + privacy label (voice menu prompt) | `NSMicrophoneUsageDescription` ships in `ios/Runner/Info.plist` (on-device-only wording). App Privacy label: audio is NOT collected (on-device processing, never leaves device) — verify against Guideline 5.1.1 at submission. Denial fallback (typed input) is implemented + tested. | App Store Connect → App Privacy | n/a (App Store Connect captures internally) | Code complete 2026-07-12; filing pending user action | — |

## Why this file exists

Several store-submission items can't be done by agents — they require
console access (App Store Connect, Play Console) that only the founder
has. This file is the visible to-do list of "the human still has to do
this" so nothing falls through the cracks between sprints.

## Naming convention for proof artefacts

`docs/store-submission/<category>/YYYY-MM-DD-<descriptor>.png`

Examples:

- `docs/store-submission/play-data-safety/2026-04-26-submitted.png`
- `docs/store-submission/play-data-safety/2026-05-01-resubmitted.png`
  (if rejected and re-filed)

Use full ISO-8601 dates so files sort chronologically. One artefact
per submission attempt; multiple artefacts per item are expected over
the lifetime of the app.

## Related

- `docs/ops/play-data-safety-runbook.md` — Data Safety answers (BUT-561)
- `docs/ops/age-rating-runbook.md` — age rating + COPPA (BUT-624/590/720)
- `docs/ops/app-review-demo.md` — reviewer demo accounts (BUT-416)
- `docs/ops/ios-privacy-manifest-audit.md` — iOS PrivacyInfo audit (BUT-568)
- `docs/ops/ios-third-party-privacy-manifests.md` — third-party manifest audit (BUT-596)
- `docs/store-submission/play-data-safety/README.md` — Data Safety filing instructions
