# Scan — Role #27 Release / App-Store Compliance Manager

_Date: 2026-06-27 · 2 passes · scope: privacy manifest, Android target-API/permissions, age-rating alignment, release.yml, Data Safety, store-submission checklist staleness._

**Launch context (memory):** NO store submission scheduled yet. Every finding below is a real
compliance gap but **launch-gated** — file as `deferred`/`launch-gated`, not urgent. Do not
prioritize over feature build.

**Already tracked / NOT re-filed (dedup):** BUT-1384 (age-15 enforcement in code), BUT-561/646
(Play Data Safety form), BUT-590/624 (age-rating questionnaire filing), BUT-596 (third-party pod
manifests), BUT-416 (reviewer demo accounts), Apple "social media capabilities" Jul/Sep-2026
ticket (dedup row 8), the missing-`play-data-safety-runbook.md` + missing iOS-audit-docs items
(already dossier watch-items for this role, scanned 2026-06-27). Apple social-media-capability +
Data Safety baselines already in world-watch/state.json.

---

## PASS 1 — primary sweep

### NEW-1 [HIGH · launch-gated] Age-rating docs still say 13+/12+ but the enforced floor is now 15 — declaration drift
The whole store-facing age story is now inconsistent with the code. The server-authoritative gate
is **15** (`functions/src/account/verify-signup-age.ts:51` `MIN_AGE_YEARS = 15`;
`firestore.rules:128-129` `isAgeCompliant()`), and BUT-1384 closed the in-code enforcement. But the
submission docs were never reconciled and still describe the old 13+ regime:
- `docs/ops/age-rating-runbook.md:22-23` — Apple "**12+**", Play "minimum age **13**".
- `:66` and `:100` and `:288` — "App is 12+… `birthYear ≤ 2013` (user is at least 13)".
- `:124` / `:279` — target age groups still keyed off the 13 floor ("13–15, 16–17, 18+").
- `:238-243` — COPPA section still cites the "13+ age gate (`birthYear ≤ 2013`)".
- `docs/store-submission/STORE_SUBMISSION_CHECKLIST.md:23` — "App Store age rating … **12+**".

**Consequence:** if Malin fills the App Store Connect / Play IARC questionnaires by copy-pasting
these runbook answers, the store-declared minimum age (12/13) will contradict the in-app gate (15)
and the privacy-policy age language — exactly the cross-store inconsistency reviewers reject.
**Action:** reconcile age-rating-runbook.md + checklist to the 15 floor before the
age-rating questionnaires are filed (BUT-590/624). This is the downstream doc half of BUT-1384, not
covered by that ticket. Launch-gated.

### NEW-2 [MEDIUM · launch-gated] Checklist has no target-API-level / version-parity row
`build.gradle.kts:38` targets SDK 36 and `:19` compiles 36 — currently ahead of Play's mandate, so
no immediate risk. But `STORE_SUBMISSION_CHECKLIST.md` has **no row** tracking (a) the Play
target-API-level requirement (Google raises the floor annually with a hard deadline) or (b)
iOS/Android version-parity at submission (`CFBundleShortVersionString` from `FLUTTER_BUILD_NAME`
vs Android `versionName` from `flutter.versionName` — they share pubspec `version: 0.9.0+1`, so they
agree *today*, but nothing asserts it pre-submission). The role dossier already flagged the absent
version-coordination protocol; this finding is the concrete checklist-row fix. Launch-gated, low effort.

### Verified-clean in pass 1 (no finding)
- **`release.yml`** — correct: manual `workflow_dispatch` only, `cancel-in-progress: false`,
  `contents: write` scoped, dependency-free bash bump. No defect.
- **`PrivacyInfo.xcprivacy`** — Required-Reason API set (CA92.1, C617.1+3B52.1, E174.1, 35F9.1) and
  CollectedDataTypes are well-formed and match the bundled SDKs; `NSPrivacyTracking=false`. The
  *audit-doc absence* is already a dossier watch-item (not re-filed).
- **Android signing** — `build.gradle.kts:59-66` correctly throws in CI without a keystore (no
  silent debug-signed AAB). No defect.
- **Android permissions** — INTERNET, CAMERA, media-images, POST_NOTIFICATIONS, USE/SCHEDULE_EXACT_ALARM
  (BUT-1242), RECEIVE_BOOT_COMPLETED all have a declared in-app justification. EXACT_ALARM is the
  sanctioned cooking-timer use case; Play's restricted-permission declaration may be requested at
  submission but that is captured under the existing age-rating/Data-Safety launch work, not new here.

---

## PASS 2 — second sweep (what pass 1 missed)

### NEW-3 [MEDIUM · launch-gated] Data Safety README still references the 13/12 age framing indirectly via the runbook chain — fold the age-15 reconcile across BOTH docs
`docs/store-submission/play-data-safety/README.md` and `age-rating-runbook.md:329` both defer to the
not-yet-existing `play-data-safety-runbook.md` for the canonical answer set, and the age-rating doc
says its maintenance sync runs "parallel to play-data-safety-runbook.md §9". When the age-15
reconcile (NEW-1) happens, the Data Safety / target-audience answers must move in lockstep —
otherwise Play's privacy-policy-vs-Data-Safety **consistency check** fails. Capture as an explicit
acceptance criterion on the NEW-1 reconcile ticket (one age floor, propagated to: privacy policy,
age-rating runbook, Data Safety answers, checklist). Not a new content gap beyond the age drift, so
folded into NEW-1's scope rather than a standalone ticket — recorded here so it isn't lost.

### Verified-clean / already-tracked in pass 2 (no new finding)
- **Apple "social media capabilities" declaration** (age-rating questionnaire update Jul 2026,
  mandatory Sep 2026) — already a backlog ticket (dedup row 8) and a world-watch baseline. Not re-filed.
  Note for that ticket: Butlery DOES have social-media capability (UGC redistributed via friends/
  comments/ratings), so the answer is **Yes** — and Apple's Social-Media Time-Allowance class carries
  a **13+** floor, which is below Butlery's own 15 floor, so it does not lower the rating. Worth a line
  in the reconcile so the two age numbers (Apple's 13 SM floor vs Butlery's 15) aren't confused.
- **Data Safety form completion** — BUT-561/646, deferred/launch-gated, tracked. Not re-filed.
- **Reviewer demo seed-script stub** (`app-review-demo.md:104-106`, missing
  `functions/src/admin/seed-reviewer-data.ts`) — already a dossier watch-item + BUT-416 follow-up.
  Not re-filed.
- **iOS social-media capability vs `ITSAppUsesNonExemptEncryption=false`** (`Info.plist:57-58`) —
  correct; Butlery uses only exempt HTTPS/standard crypto. No defect.

---

COVERAGE: privacy manifest (xcprivacy) ✓ · Android target-API/permissions/signing ✓ · release.yml ✓ ·
age-rating alignment (code vs docs) ✓ · Data Safety chain ✓ · store-submission checklist staleness ✓.
NEW findings: **2 tickets** (NEW-1 age-15 doc reconcile [HIGH], NEW-2 checklist target-API+version-parity
row [MED]) + NEW-3 folded into NEW-1. All launch-gated. Everything else pre-tracked (dedup) or clean.
