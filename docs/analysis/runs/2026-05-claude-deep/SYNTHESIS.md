# Butlery Forensic Audit — Final Synthesis (DEEP run)

**Run:** `2026-05-claude-deep` (12-prompt audit, Waves 1–4, Pass 1 + Pass 2 critic on every prompt)
**Date:** 2026-05-04
**Synthesist:** Claude (Opus 4.7, 1M context)
**Phase:** Phase 1 — investigation only; zero code changes across all 12 reports
**Sister runs:** `2026-05-claude` (default Claude, single-pass), `2026-05-codex` (partial — 01, 02, 05 only)

---

## Executive Summary

### Overall Score: **64 / 100** — Acceptable (lower bound)

Weighted across 12 dimensions per the orchestrator formula:

```
Overall = (01*0.13) + (02*0.13) + (03*0.12) + (04*0.12)
        + (05*0.07) + (06*0.09) + (07*0.09) + (08*0.04)
        + (09*0.06) + (10*0.03) + (11*0.06) + (12*0.06)
        = 63.69 → 64 / 100
```

| Action band (per orchestrator): **60-74 = Acceptable, prioritized remediation within 2 sprints.** |
|---|

**The headline this run wants you to take away:**

> The deep, two-pass critic methodology systematically downgraded every Pass 1 score by 3-11 points. Across the run, **Pass 2 found broader scope on every Pass 1 finding it re-verified, plus net new HIGH/CRIT findings missed by every shallower analyst.** The single most valuable insight is meta: the audit *process itself* is producing materially over-optimistic scores when run shallow. This run's 64/100 is a more honest baseline than the sister `2026-05-claude` run's 74/100 against the same codebase on the same day. Nothing about the codebase regressed — the methodology got sharper.

The codebase is structurally sound. The findings cluster around **adoption discipline** (built infrastructure that nothing forces you to use) and **doc-vs-code drift** (the rules say X, the code does !X, no CI gate enforces either). Both are sprint-scale problems, not architectural rewrites. Nothing is on fire today; several things are quietly mis-aligned in ways that will surface during App Store submission, GDPR audit, or a 10× user-growth scaling event.

---

## Per-Prompt Score Table (Pass 2 final scores)

| #  | Dimension                                | Pass 1 | Pass 2 | Δ | Weight | Contribution |
|----|------------------------------------------|------:|-------:|---:|-------:|-------------:|
| 01 | Code Quality & Architecture              | 62 | **56** | -6 | 0.13 | 7.28 |
| 02 | Security & Compliance                    | 71 | **62** | -9 | 0.13 | 8.06 |
| 03 | Infrastructure & Operations              | 61 | **56** | -5 | 0.12 | 6.72 |
| 04 | Performance & Scalability                | 70 | **66** | -4 | 0.12 | 7.92 |
| 05 | Dependencies & Supply Chain              | 64 | **62** | -2 | 0.07 | 4.34 |
| 06 | User Experience & Platform               | 74 | **72** | -2 | 0.09 | 6.48 |
| 07 | AI / LLM Quality & Reliability           | 74 | **71** | -3 | 0.09 | 6.39 |
| 08 | Product Analytics & Growth               | 75 | **71** | -4 | 0.04 | 2.84 |
| 09 | Trust, Safety & Advanced Privacy         | 71 | **60** | -11 | 0.06 | 3.60 |
| 10 | Monetization & Competitive Positioning   | 68 | **65.5** | -2.5 | 0.03 | 1.97 |
| 11 | Legal Review                             | — | **71** | — | 0.06 | 4.26 |
| 12 | Documentation & Operational Drift        | — | **64** | — | 0.06 | 3.84 |
|    | **Weighted Total**                       |       |        |       | **1.00** | **63.69** |

11 and 12 ran as combined Pass 1+2 (Wave 4 methodology — both passes fold into a single canonical doc). Both produced final scores rather than a Pass 1 → Pass 2 delta.

**Δ pattern**: every single dimension lost points under critic review. The largest drops (09 -11, 02 -9) are both privacy-and-rules-side dimensions where Pass 1 missed structural blind spots (image moderation gap; cert-pin posture; rule-side `ContentType` enum). The smallest drops (10 -2.5, 06 -2, 05 -2) are dimensions where Pass 1 was already cautious or strategic.

---

## All CRITICAL Findings — Consolidated, Deduplicated, Sorted

13 distinct CRITICAL items across the 12 reports. Sort: severity → effort → cross-prompt convergence. Pre-known facts (cert-pin, ConsentPurpose) cross-checked: ConsentPurpose is **resolved on disk** (Pass 2 verified via 01); cert-pin remains live across 01/02/11.

### Tier A — Hard Blockers / Active Regressions (fix this sprint)

| # | Finding | Owning prompt(s) | File:line evidence | Effort |
|---|---|---|---|---|
| **A1** | **TLS cert pinning is wired-but-empty for all 8 third-party HTTPS hosts** (`pinned_http_client.dart` falls through to platform trust on `pins.isEmpty`). Sister `2026-05-claude` Pass 2 missed this entirely; deep Pass 2 caught it twice (01 CRIT-1, 02 HIGH-1). Bridge-attack to A2 (binary-extractable OCR keys). | 01 CRIT-1, 02 HIGH-1, 11 cited | `cert_pin_config.dart:34-71`, `pinned_http_client.dart:87-93` | 5-9 h once fingerprints captured |
| **A2** | **15 of 18 callable Cloud Functions lack `enforceAppCheck`** (~83% unprotected). Highest-risk: `recordNotificationOpened` (CTR-poisoning), `logParseEvent` (parser-confidence-degradation Sybil attack), `sendNotification`/`sendNotificationBatch` (combine with A4 friend-fallback bug). | 02 CRIT-3 | `functions/src/notifications/send-notification.ts:74,469`; `events/log-parse-event.ts:144`; `notifications/record-notification-opened.ts:125` (full table in 02) | 1-2 h (one-line per function) |
| **A3** | **`realtime_menus/{menuId}/votes/{voteId}` has NO firestore.rules block.** Feature is live (widget + viewmodel + service + DI + push deep-link route), but every client write fails default-deny. Push notification → user opens screen → votes → silent permission-denied → vote never persists. Same failure-mode class as cook_snaps gap closed in BUT-728. | 02 CRIT-1 | `firebase_menu_voting_repository.dart:24-25,75,90,103,120`; rules grep `votes` returns 0 | 30 min rules + tests |
| **A4** | **`compliance_export_manager.exportAuditLogs` permission-denies on every non-admin call; catch swallows it.** GDPR Article 15 export is silently missing the audit-log category for every non-admin user. Code admits the path is broken in its own docstring. | 02 CRIT-2 | `compliance_export_manager.dart:42-91` (line 84-90 swallow, line 11-20 docstring) | 2-3 h (build callable CF) |
| **A5** | **Cloud Function `sendNotification` queries non-existent `friend_requests` collection** (renamed to `social_requests` long ago; 6 stale references across functions). Pending-friend-request notification flow is silently broken in production. | 02 HIGH-2 (deep) / multi-prompt resonance | `send-notification.ts:125,130,539,544`; `cleanup-expired-friend-requests.ts:32`; `admin/reset-user-data.ts:74` | 1-2 h |
| **A6** | **`backups.md` claims weekly exports to `europe-west3` (Frankfurt) but all Cloud Functions/Vertex AI run in `europe-west1` (Belgium).** `gcloud firestore export --location=europe-west3` against europe-west1 DB returns INVALID_ARGUMENT. Doc says "Status: ACTIVE"; the steps in it cannot have completed. **DR is theoretical until exercised.** Restore drill: never performed. | 03 CRIT-INFRA-1 | `docs/ops/backups.md:27-30,63,66,116,181`; `functions/src/index.ts:20`; `data-residency.md:8` "USER MUST VERIFY" | 5 min DB region check; 1 hour rebuild + alert if mismatched |
| **A7** | **`reports` collection is a brigade-amplifier surface.** No rate limit, no description size cap, no `contentType` enum validation, no self-report block on rules. 10 sock-puppet accounts × 100 reports/sec = moderator queue weaponised against any target user in seconds; combined with knowledge-file BUT-645 auto-suppression, the *victim* gets auto-suspended. | 09 CRIT-1.1 | `firestore.rules:1596-1599`; `report_service.dart:108` (no `.limit()`) | 2 h rules + 6 h brigade-detector CF |
| **A8** | **No image moderation on user uploads** (`cook_snaps`, `shared/recipes`, `feedback`). Zero NSFW / copyright / CSAM scanning. Apple Guideline 1.2 hit; one viral CSAM-injection event = app pulled. Sister run missed this; deep Pass 2 (09) elevated to NEW CRITICAL. | 09 Pass-2 NEW CRITICAL | `storage.rules:62-69`; `firebase_storage_repository.dart:259` (client-side MIME only) | 1-2 sprints (Cloud Vision SafeSearch wiring) |

### Tier B — Latent submission/legal blockers (fix before any app-store filing)

| # | Finding | Owning prompt(s) | Evidence | Effort |
|---|---|---|---|---|
| **B1** | **iOS `ITSAppUsesNonExemptEncryption=false` is materially incorrect.** SQLCipher AES-256 IS non-exempt under EAR §740.17. Apple takes the developer's word but a false declaration carries liability under 50 U.S.C. § 1705. Both the privacy policy AND the orchestrator-cited security claim contradict the plist. | 11 CRIT-LEGAL-2 | `ios/Runner/Info.plist:57-58`; `pubspec.yaml:44`; `privacy_policy_en.md:277` | 30 min plist + 2 h regulatory paperwork (one-time ENC notification) |
| **B2** | **Subprocessor list omits reCAPTCHA Enterprise** (App Check provider on web). Privacy policy 1.2.0 line 169 says verbatim *"We do not engage any other data processors."* — and reCAPTCHA fires on every web session before any consent gate. Explicit closed-list claim makes this an Art. 13 misstatement (worse than mere omission). | 11 CRIT-LEGAL-1 | `assets/legal/privacy_policy_en.md:163-167,169`; `lib/main.dart:213-216` | 30 min doc-only |
| **B3** | **`sqlcipher_flutter_libs` is confirmed End-of-Life** (pub.dev v0.7.0+eol "Not used anymore"). Encrypted-database substrate on a formally-retired binary distribution. Cascade: drift 2.29 → 2.32, build_runner 2.7 → 2.15, sqlite3 2.x → 3.x — all gated on the same SDK floor bump. | 05 CRIT-1 | `pubspec.yaml:44`; `lib/core/storage/drift/app_database.dart` (single import); pub.dev live fetch | 2-3 days migration + key-derivation re-test |

### Tier C — Architecture-debt CRITICALs (compounding, not blocking)

| # | Finding | Owning prompt(s) | Evidence | Effort |
|---|---|---|---|---|
| **C1** | **`FCMService` is an all-static singleton** with 11 mutable static fields and a private constructor used solely to expose mixin methods to a static call site. Untestable; consent-revocation listener leaks every hot-reload. Most-divergent-from-rules service in the codebase. | 01 CRIT-2 | `lib/services/notifications/fcm_service.dart:75-130, 171-175` | 1.5 days incl. test rewrites |
| **C2** | **`BaseViewModel` is the documented standard but only ~18% of viewmodels extend it** (14 vs 62 raw ChangeNotifier). Every new VM copy-pasted from a ChangeNotifier template multiplies the divergence. Architectural debt that compounds. | 01 CRIT-3 | 14 files extend BaseVM, 62 extend ChangeNotifier directly (full lists in 01) | 2-3 sprints incremental |
| **C3** | **`displayName`/`avatarUrl` denormalization at 24+ sites** reads from Firebase-Auth profile, not UserService. Exact data-source bug `CLAUDE.md` "Critical Conventions" forbids. Stale name "burned" into every old comment when user changes display name. ~14 of 24 sites WRITE to Firestore (the dangerous half). | 01 CRIT-6 | 24 sites enumerated in 01 evidence | 1-2 sprints (write-path priority) |
| **C4** | **`architecture_test.dart` is structurally too narrow** — single highest-leverage finding in 01. It does NOT cover `FirebaseMessaging.instance`, mutable static fields outside `core/constants/`, BaseService extension requirement, or BaseViewModel extension. Every other architecture finding in this report is regression-vulnerable until the test broadens. | 01 CRIT-5 | `test/architecture_test.dart` (full file read) | 1 day (broaden tests) |
| **C5** | **`ConversationAutoHealerModule` opens 52 concurrent listeners per active user.** At 10K active users → 200-500K listeners, **breaks Firestore's ~100K project soft cap.** Architectural change required (CF `onMessageCreate` trigger + delete client auto-healer). | 04 CRIT-1 | `conversation_auto_healer_module.dart:38-78`; `conversation_query_module.dart:31-46` | 1-2 sprints |
| **C6** | **`RealtimeSyncService._cachedResources` grows without bound.** Power-user opening 200 recipes retains 10-100 MB session heap until logout. No LRU/idle/size cap. Project already has the eviction pattern (`IntelligentCacheManager`). | 04 CRIT-2 | `lib/services/realtime_sync_service.dart:53,159` | 1 day |
| **C7** | **No closed-loop quality measurement on AI parsing.** Per-field correction events captured but nothing runs them as regression tests. No golden-set, no scheduled CF, no alert on correction-rate spikes. The infra for a feedback loop is half-built (capture only); the action half is empty. | 07 CRIT-D3 | No `golden*` files in test tree; `firebase.json` has no alertPolicy | 3-5 days |
| **C8** | **`gemini-2.0-flash` is a floating model alias.** Google retargets aliases without notice; quality moves silently and `PROMPT_VERSION` correlation key won't change. No `modelId` field in any analytics event or `parse_corrections_v2` row — model-swap regression indistinguishable from prompt regression. | 07 CRIT-D4 | `gemini-client.ts:721,25`; `parse_corrections_v2` schema | 1 h (pin model + add field) |
| **C9** | **CI dependency-audit Node-version mismatch.** `dep-audit.yml` runs Node 20; functions engines:22. The audit step is therefore not auditing what ships. Textbook supply-chain blind spot. | 05 CRIT-2, 03 cited | `dep-audit.yml:89` vs `functions/package.json:55-57` | 5 min |
| **C10** | **Test workflow `--coverage` collects ZERO data from `test/integration` and `test/e2e`.** "88% Firebase Repos coverage" claim is structurally unverifiable; CI floor at 70% gates on a measurement that excludes the integration tests against the actual emulator. | 03 CRIT-INFRA-2 | `test.yml:67-70,272-279`; `e2e_tests.yml:108-115` | 30 min lcov merge + re-baseline |
| **C11** | **`infrastructure_integration_test.dart` claim from Wave 1 was misattribution but the underlying invariant gap is real.** `view_test_helpers.dart:316,450,460,517` calls `pumpAndSettle()` with no Duration → 10-min default. A single new test using bare `pumpAndSettle()` can consume half the CI test budget. No `defaultTestTimeout` set anywhere. | 03 CRIT-INFRA-3 | `view_test_helpers.dart:316,450,460,517`; `bootstrap_diagnostic_test.dart:63` | 1 h base-class fix + 30 min CI gate |
| **C12** | **`lib/site-packages/` ships 29 MB of Python pip-install on every developer's disk.** Audit-integrity issue (inflated all sister-run LOC counts by 4×) plus supply-chain side door (any analyzer/lint run walks Pillow + pip). | 01 CRIT-4 | Glob `lib/site-packages/*` | 30 seconds (`rm -rf`) + .gitignore + CI guard |
| **C13** | **Doc-drift CRITICALs (4):** `code-style.md` claims 33 large files (reality 136); `ACCEPTED_LARGE_FILES.md` self-contradicts with 3 different counts; audit-log retention triple-drift (90/180/365/730 days across 4 sources); orchestrator block claims Mistral but reality is Vertex AI. Each individually 5-30 min; collectively the **systemic** finding is C13. | 12 CRIT D1.1 / D4.1 / D5.1 / D8.6 | 12-doc-drift.md exhaustive | ~2 hours total |

---

## Top 5 Risks

Ranked by impact × likelihood × cross-prompt convergence:

1. **Cert-pin posture is wired-but-empty AND was missed by the shallower sister run.**
   The single most-load-bearing finding *of the audit-process improvement.* `pinned_http_client.dart` looks active; BUT-427 is treated as done; the docs say "infrastructure wired"; reality is every outbound call to Algolia / OCR.space / Vision / 4 recipe-scrape sites falls through to platform trust on `pins.isEmpty`. Combined with binary-extractable OCR keys (02 HIGH-3), an attacker has TWO paths to the same secret. Cross-prompt convergence: 01 / 02 / 11. **Sister run scored M3 as Pass.** Methodology lesson: "wired-but-inactive" is strictly worse than "no pinning" because it disables the alarm.

2. **15-of-18 Cloud Functions missing `enforceAppCheck` + brigade surface on `reports` collection.**
   Two-axis abuse vector. App Check absence enables unbounded non-app callers (cost-burn, CTR-poisoning, parser-confidence-degradation Sybil). Brigade surface enables one bad actor to weaponise the moderator queue against any user. The two combine: an unauthenticated attacker can spam-create reports through the rules-allow path while the App Check absence on `recordNotificationOpened` makes detection harder. Cross-prompt: 02 / 09. Both 1-day fixes; both not done.

3. **DR is documented as ACTIVE but cannot have run since region claim is broken.**
   `backups.md` says europe-west3, all functions europe-west1, restore drill never performed. The runbook tells you to do `gcloud firestore export --location=europe-west3` against a europe-west1 DB, which returns INVALID_ARGUMENT. Either no backups exist (no execution) OR backups exist in wrong jurisdiction (Chapter V exposure) OR DB is actually europe-west3 contradicting all function claims. **You can't find out DR is broken until you need it.** Cross-prompt: 03 / 11 / 12.

4. **Doc-vs-code drift propagates through every analysis prompt.**
   This is the meta-risk. `CLAUDE.md` / `.claude/rules/` / agent knowledge files / runbooks / orchestrator block all carry stale numerical claims (33 vs 136 large files; 1465 vs 1813 firestore.rules lines; 850 vs 1257 dart files; 5 vs 6 workflows; "Mistral" vs Vertex; ConsentPurpose error stale; cert-pin "BUT-427 done" but empty). Every audit starts from a slightly-false picture, and AI assistants making file-size or service-extension decisions get biased by the wrong numbers. The remediation is a single weekly auto-regen script. Cross-prompt: 12 owns the meta-fix; 01-11 all carry instances. *(Treated separately in "About the audit process itself" section below.)*

5. **No closed-loop quality measurement + floating model alias = AI quality regressions are invisible.**
   `gemini-2.0-flash` is unpinned (Google retargets it without notice); `parse_corrections_v2` doesn't carry `modelId`; no scheduled regression CF runs corrections as tests; no alert fires on correction-rate spikes. A model swap or prompt regression is detected only by aggregated correction-rate trends in Looker — lag is hours-to-days. The infra for the feedback loop is half-built (capture exists, action layer empty). Cross-prompt: 07 owns; 08 reinforces (no `modelId` in any analytics event); 12 documents the missing alertPolicy.

**Honourable mentions:** SQLCipher EOL substrate (05); `displayName` denormalization at 24+ sites (01 CRIT-6); `ConversationAutoHealerModule` listener fan-out hits Firestore project ceiling at 10K users (04); image moderation gap (09 Pass 2 new CRIT); audit-log retention triple-drift creating GDPR storage-limitation contradiction (02/11/12); test infrastructure has no per-test timeout invariant (01/03).

---

## Top 5 Strengths

1. **Repository / GDPR foundation is genuinely solid.** `BaseFirebaseRepository` → `PermissionValidationMixin` is correct in shape; GDPR Articles 7/15/17/30 have real implementations; multi-tier deletion cascade with admin SDK on the irreversible leg; consent purpose granularity covers analytics/marketing/social/AI/push; consent-revocation propagates through SDK side-effects (BUT-754 FCM token revoke). The CRITICALs on this surface are gap-shaped, not foundation-shaped. (02, 09, 11)

2. **Internationalization is exemplary.** 6,347 ARB keys × 2 locales (sv/en) at perfect parity. Zero hardcoded user-facing English strings in `lib/views/`. 1,769 `context.l10n` callsites. 130 a11y-prefixed keys. 256 `Semantics(` callsites for ~157 raw tap targets. The locale switcher (`LocaleProvider` with `supportedLocales = ['sv','en']` + `getLocaleName()`) is **fully built but hidden** — one missing settings tile away from shipping. (06)

3. **AI cost discipline is best-in-class for an indie shop.** Multi-tier import (SchemaOrg → SiteConfig → RuleBased → LLM-fallback) means Gemini is the *fallback*, not the default. `ImportRateLimiter` does per-window cost tracking (per-minute / per-hour / per-day / monthly $) with Firestore-transactional updates — the most expensive piece of any freemium stack already exists. Vertex AI pinned to europe-west1, ADC-authenticated, structured-output schema-enforced. Prompt versioning via `PROMPT_VERSION` + Firestore overlay (BUT-621) with fail-open + capped-warn-rate. PII scrubber (email, phone, personnummer) runs both client and server with documented sync. Truncation salvage (BUT-577) walks brace-counted JSON to recover partial output. (07, 10)

4. **Operational runbooks are the strongest doc cluster.** `presence-ttl-runbook.md`, `llm-kill-switch-runbook.md`, `audit-logs-retention.md`, `freerasp-runbook.md`, `moderation-runbook.md` are dated, internally consistent, accurate to the code they describe, and cross-validate with each other (e.g. presence-TTL gcloud command appears in both runbook AND `cloud-functions-specialist.knowledge.md` — converged). The bad apple is `backups.md` (CRIT-INFRA-1). (12 D3.* mostly PASS)

5. **The pre-commit review hook is rigorously enforced and the `firebase-backend-security` knowledge file is genuinely append-only.** Hook script (`require-review-before-commit.sh`) + 4 markers (`code-review`, `testing-review`, `firebase-security`, `rules-tester`) match CLAUDE.md spec exactly. `firebase-backend-security.knowledge.md` is 120 KB, mtime 2026-05-02, with append-only growth pattern visible across ls -la samples. **The places where the rules ARE enforced, they hold.** (12 D1.5, D2.6 PASS)

---

## Cross-Cutting Themes

These are patterns that appear across **multiple** reports — they're more important than any individual finding because the fix is upstream:

### Theme 1 — "Wired but inactive" is the dominant Butlery anti-pattern
- Cert pinning: wired, empty (01/02/11)
- BaseViewModel: built, ~18% adopted (01)
- BaseService: built, ~75% adopted (01)
- SerializationUtils / FirestoreCollections / LogSanitizer / CircuitBreaker / RetryPolicy: all built, all bypassed at scale (01)
- `LocaleProvider`: complete, no settings tile (06)
- `ConsentManagementView` / `data_export_view`: built, not linked from settings (06)
- `subscription_tier` analytics property: wired, hardcoded 'free' forever (10)
- `marketing` consent purpose: present in model + policy promises newsletter, **no MarketingService anywhere** (11)
- Per-field correction capture: collected, never run as regression tests (07)

**Underlying cause:** infrastructure-first development without the second sweep that wires it in. The fix is a single CI gate per pattern (architecture test, settings-hub registry, etc.) that fails the build when a "built but unused" piece grows stale.

### Theme 2 — Doc-vs-code drift propagates through every AI analysis
The orchestrator's pre-known-facts block carries 7+ stale claims (Mistral/Vertex; 850/1257 dart files; 5/6 workflows; 33/136 large files; 1465/1813 firestore.rules; 14-week vs 30-day backup retention; ConsentPurpose error stale). Three sister Pass-1 reports inflated the LOC count to 327k by walking `lib/site-packages/`. **Every audit starts from a slightly-false picture.** Owned by 12, but every other prompt carries instances. The **single most leveraged fix in the entire run** is the `_pre-analysis/` artifact-pinning + weekly auto-regen script that 12 M-3 proposes — it eliminates roughly half the drift forever and makes the next audit start from ground truth.

### Theme 3 — Knowledge files are reliable as hypothesis but treacherous as authority
Pass 1 of the deep run trusted `cloud-functions-specialist.knowledge.md` BUT-728 entry's "matrix closed" claim. Pass 2 verified live: `_resolveContentRef` covers 5 of 8 contentTypes, switch silently no-ops the rest. Knowledge file's table at lines 17-22 is now misleading because newer entries don't update the top-of-file summary (it's append-only, not refactor-allowed). The contract works for hypothesis-generation but fails for authority-of-current-state. Owned: 12 D2.1; resonates in 09 (silent moderation no-op), 07 (`ocr_usage_tracker.dart` "dead code" claim WRONG — verified live, the legacy 3-provider OCR path IS still used).

### Theme 4 — Consent racing SDK init shows up in 02, 09, 11 simultaneously
- Crashlytics native error handlers register at `main.dart:228-238` BEFORE consent gate at line 295 (02 MEDIUM-3).
- Onboarding wizard (`OnboardingAgeGate → Welcome → Allergen → Dietary → Import`) ships ZERO consent UI — user reaches home without granting any consent (09 HIGH-1, 11 HIGH-LEGAL-x).
- reCAPTCHA Enterprise (`main.dart:213-216`) fires on every web session BEFORE consent gate (09 + 11 CRIT-LEGAL-1).
- AI consent (`aiProcessing`) is enforced client-side; OCR-retry server-to-server path bypasses it (07 CRIT + 11 HIGH-LEGAL-3).
- Privacy policy promises consent is required for AI; code admits the leg is unprotected.

The unifying fix is a **server-side consent assertion** (Firestore lookup or signed claim in the request) on every server-to-server LLM/OCR retry path, plus an `OnboardingConsentPage` between Welcome and Allergen.

### Theme 5 — App Check absence + rule gaps + brigade surface = cost & abuse asymmetry
- 15 of 18 callables miss App Check (02 CRIT-3): cost-burn unbounded, analytics-poisoning silent.
- `reports`, `feedback`, `category_overrides`, `activity_events` collections all lack rate limits or rule blocks (02/09).
- `realtime_menus/votes` has NO rule block at all (02 CRIT-1).
- Image moderation absent on user uploads (09 NEW CRIT).

The pattern: **the perimeter is intentionally permissive** (necessary for legitimate use) **but the inner gates are missing** (rate limits, App Check, content scanning). One fix per layer is small (~30 min each); none are done.

### Theme 6 — Pass 2 critic methodology found 4-11 points per dimension that Pass 1 missed
Aggregate downgrade across 10 prompts that ran Pass 1+2: -42 raw score points. Mean: **-4.2 points per dimension.** The 10-point swings (09 -11, 02 -9, 01 -6) are at structural-find dimensions where one missing CRITICAL changes the whole picture. The 2-point swings (10 -2.5, 06 -2) are at strategic dimensions where Pass 1 was already cautious.

**Implication for the audit cadence:** if you only ever run Pass 1, your scores will be ~5 points optimistic. The sister `2026-05-claude` run scored 74; this deep run scores 64; the codebase is the same. Either future audits all use the deep methodology or budget mentally for the +5pt fudge in Pass-1-only runs.

---

## Items Requiring IMMEDIATE Attention (block any feature work until done)

These are the items that *should* preempt new feature work in the next sprint. Drawn from Tier A only.

1. **A6 — Verify Firestore region & rebuild backup if mismatched.** 5 min check, 1 hour rebuild. **Run this today.** Not knowing your DR works = doesn't work. (CRIT-INFRA-1)
2. **A1 — Populate cert pins OR rename `PinnedHttpClient` → `OptionallyPinnedHttpClient` and add release-mode assertion.** 5-9 hours once fingerprints captured. Don't ship to App Store with this open.
3. **A2 — Add `enforceAppCheck: true` to the 15 unprotected callables.** 1-2 hours. One-line per function.
4. **A3 — Add the missing `votes` rule block.** 30 min + tests. Feature is shipping broken right now.
5. **A4 — Build `exportAuditLogs` callable Cloud Function.** 2-3 hours. GDPR Article 15 is currently broken for every active user.
6. **A5 — Rename `friend_requests` → `social_requests` in 6 stale references.** 1-2 hours. Pending-friend-request notifications are silently broken in production.
7. **A7 — Add rate limit + size cap + contentType enum + self-report block on `reports` collection.** 2 hours rules + 6 hours brigade-detector. 24-h moderation SLA is voidable until done.
8. **C12 — Delete `lib/site-packages/`.** 30 seconds. Frees 29 MB and stops inflating audit numbers 4×.
9. **C13 — Update `code-style.md` "33 files" → "136 files" + auto-regen `ACCEPTED_LARGE_FILES.md`.** 35 min. Stops biasing every refactor decision.
10. **B1 + B2 — Flip `ITSAppUsesNonExemptEncryption` to true; add reCAPTCHA to subprocessor list.** 30 min plist + 30 min doc. **Both are mandatory before any App Store filing.**

A8 (image moderation) is also blocking but is 1-2 sprints — schedule it but don't gate the sprint on it.

---

## Unified Remediation Roadmap

### Sprint 1 (this sprint — ~3-4 dev-days)
**Goal: zero CRITICALs in security/rules/legal/DR.**
- A1, A2, A3, A4, A5, A6, A7 (Tier A — except A8 image moderation)
- B1, B2 (legal blockers)
- C9 (CI Node version), C10 (lcov merge), C11 (test timeout), C12 (delete site-packages), C13 (doc-style numbers)
- HIGH-VALUE quick win: **wrap `MaterialApp.builder` in `AccessibilityUtils.clampTextScaling(maxScaleFactor: 1.5)`** (06 HIGH-3, 1-line fix in main.dart, app-wide WCAG 2.1 AA SC 1.4.4 protection)
- HIGH-VALUE quick win: **add language switcher + Privacy/Data section to settings hub** (06 HIGH-5, 90 min, unblocks GDPR-easy-access claim)

Estimated total: ~25 dev-hours. Output: zero shipped CRITICALs.

### Sprint 2 (next — ~5-7 dev-days)
**Goal: close the knowledge-loop on AI quality + plug the brigade/abuse surface end-to-end.**
- C7 (golden-set regression CF + alertPolicy)
- C8 (pin Gemini model + add `modelId` field)
- A8 (image moderation Cloud Vision SafeSearch)
- C4 (broaden `architecture_test.dart` — UNLOCKS the architecture-debt CRITs by gating regression)
- 02 HIGH-1 cert-pin populate + ops calendar entry
- 02 HIGH-3 OCR/Vision API key migration to Cloud Functions
- 11 HIGH-LEGAL-3 server-side `aiProcessing` consent assertion on retry path
- 09 HIGH-1 onboarding consent page
- 12 D8.6 etc — orchestrator block auto-regen script

Estimated total: ~35 dev-hours.

### Sprint 3 (next + 1 — ~5-7 dev-days)
**Goal: close the architecture-debt CRITs + the listener fan-out.**
- C5 (`onMessageCreate` CF + delete auto-healer)
- C6 (bind `_cachedResources` to `IntelligentCacheManager`)
- C2 (BaseViewModel migration — sweep, not big-bang)
- C3 (displayName/avatarUrl write-path migration — read-path can wait)
- C1 (FCMService refactor to instance + DI — gated by C4 architecture-test broadening)
- 03 HIGH-INFRA-1 firebase deploy --only hosting in CI
- 04 HIGH findings (raw `Image.network`, FriendsStateManager listener leak)

Estimated total: ~40 dev-hours.

### Backlog (LOW + nice-to-haves)
- 12 doc-drift MEDIUMs (~2-3 hours total, batch later)
- SQLCipher → sqlite3 v3 migration (B3) — schedule after SDK-floor bump unlocks
- Voice / hands-free cooking (10 — strategic differentiation, post-monetization)
- Vertex prompt-prefix caching for ~30% cost reduction (07 HIGH)

---

## About the Audit Process Itself (meta-section)

The orchestrator's pre-known-facts block ships with 7+ stale claims. The deep run identified them via Pass 2 critic, but Pass 1 of every prompt initially trusted them. The pattern matters because:

- **Three independent Pass 1 reports inflated LOC to 327,280** by walking `lib/site-packages/` (Python pip-install accidentally inside `lib/`). Real number is 53k-77k depending on what counts as "hand-written." This is a 4-6× inflation.
- **`flutter_ci.yml.disabled` doesn't exist on disk**; the orchestrator's reference is stale (03).
- **`ConsentPurpose` undefined error is resolved on disk** (verified by 01 Pass 2), but sister run treated it as still-live.
- **"Mistral AI" appears in orchestrator and code comments**; actual SDK is `@google-cloud/vertexai 1.12.0` (05/07/12).
- **"5 workflows" in orchestrator**; actual = 6 (03/12).
- **"33 files >500 lines" in `code-style.md`**; actual = 136 (12 CRIT D1.1).
- **"BaseService 96% adopted"**; actual = ~75% (01 / 12).

Recommendations for the next audit run:
1. Pre-flight script that re-derives every numerical claim in the orchestrator block and writes them to `_pre-analysis/orchestrator-facts.md`. Fail the run if any claim differs by >5%.
2. Pre-flight script that runs `flutter analyze` once and pins the output before any prompt reads it (the staleness-vs-disk problem in claim #3 above).
3. Always run Pass 2 critic. The +4pt average fudge in Pass-1-only is too large to ignore for any decision-grade audit.
4. Pin the canonical LOC counter (`find lib -name "*.dart" -not -path "*/site-packages/*" -not -name "*.g.dart" -not -name "*.freezed.dart" -not -path "*/l10n/*" -exec wc -l {} +`) and emit `_pre-analysis/loc-baseline.txt` so future runs verify against it.
5. The deep-run methodology found things the shallower runs missed; the inverse is also true at the margin (sister run might have caught one or two LOWs deep run skipped). For decision-grade output, both methodologies should converge on key CRITs — and on this run, they DID for items A2/A4/B1/B2/B3 but DIVERGED on A1 (cert-pin) and A8 (image moderation), which is the strongest empirical case for keeping the deep methodology going forward.

---

## What this means in plain language

(Per `workflow-discipline.md` — max 8 bullets, zero jargon, written for the founder.)

- The codebase is in **decent shape but not as good as a quick-look audit suggests.** A more thorough check found 5-10 important things the quick check missed. Score: **64/100** (acceptable; needs a focused 2-3 sprint cleanup).
- **Three security locks that look installed are actually open:** the cert-pinning safety net is wired up but never had its passwords typed in (it lets through every connection); 15 of 18 backend functions don't check whether the request really came from your app (a script kid with curl can spam them); and one new feature (menu voting) was shipped without giving users *permission to use it* in the rules — every vote silently fails. All three are 1-2 hour fixes once you start.
- **Your backup story is a fiction.** The doc says "backups run weekly to Frankfurt." All your services run in Belgium. The command in the doc would error out. Either no backups exist or they're in the wrong country (legal problem). **Spend 5 minutes today running one command in the Firebase console to find out which.**
- **The onboarding flow asks for zero consent.** New users walk through Age → Welcome → Allergens → Dietary → Import and never see a "I agree to the privacy policy / I want analytics on/off" page. The page exists, just buried in Settings. EU regulator audit answer "it's reachable somewhere" is not strong enough.
- **You have 29 MB of accidental Python files inside your `lib/` folder.** Doesn't ship to users but inflated three sister-audit reports' LOC numbers by 4×. `rm -rf lib/site-packages/` — 30 seconds.
- **A bunch of helper tools have been built but nobody uses them.** Architecture rules say "use this base class" — only ~18% of the code does. Locale switcher is fully built — no UI tile. Consent management view is fully built — not linked from Settings. Marketing newsletter consent is in the privacy policy — there is no newsletter system. **Most of "fix this" is "wire up what already exists" not "build something new."**
- **Two iOS submission blockers will bite the moment you file:** a checkbox claiming "no encryption" (you have AES-256 SQLCipher — that's a federal regulation issue, not just an Apple one) and the Swedish App Store subtitle is 31 characters when Apple's max is 30. Both 30-minute fixes.
- **Easiest valuable change in the whole run:** delete the Python folder, fix one number in `code-style.md` (says "33 large files" — reality is 136), and pin the Gemini AI model version. ~1 hour total. Stops misleading every future analysis and stops Google silently swapping your AI model under you.

---

*End of synthesis. Source reports in `docs/analysis/runs/2026-05-claude-deep/01-12.md` retain full file:line evidence; this document does not duplicate it. Cross-validation against `2026-05-claude/SYNTHESIS.md` (sister single-pass) confirms convergence on Tier A items A2/A4 and divergence on Tier A items A1 and A8 — the latter two are the strongest empirical case for the deep methodology.*
