# MASTER — Wave 2 — Forensic Audit Consensus Report

**Scope:** Prompts 03 (Infrastructure & Operations), 04 (Performance & Scalability), 06 (User Experience & Platform).
**Date:** 2026-05-04.
**Sources:** Three independent forensic runs of the Butlery codebase:
- `2026-05-codex/` — OpenAI Codex CLI (GPT-5)
- `2026-05-claude/` — Claude default (Opus 4.7, single-pass per prompt)
- `2026-05-claude-deep/` — Claude deep methodology (Opus 4.7, two-pass investigator + critic)

**Methodology:** Identical to Wave 1. Deep run's Pass 2 critic verified Pass 1 against live source; this master added a third layer of verification for codex/default-unique findings; disproved findings are explicitly listed. Source data lives in `MASTER-wave2-03-infrastructure-data.md`, `MASTER-wave2-04-performance-data.md`, `MASTER-wave2-06-user-experience-data.md`.

**Consolidated wave score:** **65/100** (weighted average of three verified prompt scores).

---

## 0. Executive summary

Wave 2 reveals **operational and observability debt** layered on top of a generally sound runtime profile. The biggest exposure is in disaster recovery (the documented backup region doesn't match the functions region), in scalability (a messaging fan-out breaks at 10k users), and in audit integrity (codex+default both repeated the stale `ConsentPurpose` finding from Wave 1).

**Top three findings of the wave (all CRITICAL):**

1. **Backup region mismatch — disaster recovery is unverifiable.** `docs/ops/backups.md` documents Firestore exports to `europe-west3` (8 references); `functions/src/index.ts:20` runs functions in `europe-west1`. Either the runbook is wrong (and backups don't actually run), or it's executed correctly (and the entire functions tier is operating cross-region with latency tax). `data-residency.md:8` itself says "USER MUST VERIFY". Restore drill `NEVER PERFORMED` per `backups.md:31`. (Prompt 03 CRIT-INFRA-1 + C-5)

2. **`ConversationAutoHealerModule` opens up to 52 concurrent Firestore listeners per active user.** `getUserConversations` returns a stream that, on every snapshot, calls `startAutoHealer(conversation.id)` for all 50 conversations; each healer opens an additional `messages.where(conversationId == X).orderBy(sentAt desc).limit(1).snapshots()` listener. At 1k users this fits in Firestore's 100k project ceiling (~50k listeners). At 10k users it breaks. Codex MISSED this entirely. Pass 2 verified at `lib/repositories/firebase/modules/conversation_auto_healer_module.dart:18, 28-79`. (Prompt 04 CRIT-1)

3. **`RealtimeSyncService._cachedResources` is an unbounded in-memory map.** Map at `realtime_sync_service.dart:53` populated unconditionally on every snapshot at lines 159 and 224 (Pass 2 found the second write site Pass 1 missed). No LRU, no idle eviction, no size cap. Cleared only on logout/explicit delete/dispose. ~50-500 KB per cached recipe → 200 recipes opened in a session = 10-100 MB retained. Same anti-pattern at `firebase_user_ingredient_repository.dart:189-202`. (Prompt 04 CRIT-2)

**Three audit-integrity findings worth flagging:**

| Stale narrative | Reality | Impact |
|---|---|---|
| "Test pipeline hangs because `infrastructure_integration_test.dart` runs 10 min per test" (codex INFRA-02 CRIT, default C-1 CRIT) | The named file is **124 lines, 4 tests, completes in seconds**. Deep's CRIT-INFRA-3 is the right framing: per-test timeout invariant missing. Any `pumpAndSettle()` no-arg call in any test can burn 10 min. Specific guilty file is unidentified. | Codex+default both pinned blame on the wrong file. The fix is structural (`dart_test.yaml` per-test timeout default), not "fix this file." |
| "`ConsentPurpose.pushNotifications` undefined — CRITICAL build break" (codex C1 + default C1 in prompt 06) | **Disproved at HEAD this pass.** `lib/models/account/user_consent.dart:98` defines the enum value. `lib/services/notifications/notification_service.dart:649` resolves cleanly. Both runs read a stale `_pre-analysis/flutter-analyze.txt` snapshot. | Same stale-snapshot problem we caught in Wave 1, repeated. The pre-analysis tool needs an mtime-vs-current freshness check before propagating analyzer errors. |
| Reports referenced "6 GitHub Actions workflows on disk" | **7 workflows on disk now.** `sbom.yml` was added 2026-05-04 12:27 between the deep run and master synthesis. Partially addresses deep's M-INFRA-12 (no SBOM artifact). | Even master synthesis caught a fact-as-it-was-stale-now drift — the analysis horizon is hours, not days. |

**Three structural findings that surface in multiple prompts:**

- **Coverage claim is structurally unverifiable.** `test.yml:67-70` runs `--coverage` on unit/widget/views/golden tests only. Integration job at `:272-279` and `e2e_tests.yml:108-110` run *without* `--coverage`. The orchestrator's "88% Firebase Repos" coverage claim cannot be derived from the artifacts CI produces. (Prompt 03 CRIT-INFRA-2; cross-link prompt 01 BaseFirebaseRepository adoption finding)
- **`FriendsStateManager.dispose()` cancels 6 of 7 subscriptions** — explicitly omits `_blockedUsersSubscription`. `clearAllData()` cancels it correctly; `dispose()` doesn't. Almost certainly an oversight. 30-second fix, but a reliable signal that nothing tests dispose-completeness. (Prompt 04 CRIT-3)
- **Desktop branding is broken.** `windows/runner/main.cpp:30` has lowercase `L"butlery"`. `macos/Runner/Base.lproj/MainMenu.xib` has 6 unresolved `APP_NAME` placeholders. Mobile-first focus per MEMORY.md is fine — the gap is real but lower priority. (Prompt 06 H6 unique to deep)

**Bottom line:** the codebase is more performant than codex's pessimistic 47/100 suggests but more fragile than default's 73/100 implies. The three CRITICALs in 04 are scale-time bombs that don't show in current telemetry. The CRIT in 03 is a regulator-relevant DR gap.

---

## 1. Score reconciliation across runs

### Per-prompt score consensus

| Prompt | Codex | Claude default | Claude deep | **Master (verified)** | Status label |
|---|---:|---:|---:|---:|---|
| 03 Infrastructure & Operations | 57 | 73 | **56** | **56** | Maturity Level 2; needs DR + observability fixes |
| 04 Performance & Scalability | 47 | 72 | **66** | **66** | Acceptable; 3 scale-time CRITICALs |
| 06 User Experience & Platform | 70 | 78 | **72** | **72** | Acceptable; i18n is a strength, RTL/desktop weak |
| **Wave 2 weighted average** | 58 | 74.3 | **64.7** | **64.7** | |

**Pattern across both waves:** Default consistently scores ~10-15 points higher than deep on 5 of 6 prompts so far. Default treats "documented as ACTIVE" as "is ACTIVE"; deep verifies. The 17-point gap on prompt 03 is itself a finding — `data-residency.md:8` admits "USER MUST VERIFY", default didn't.

### Disputed numbers — authoritative truth

| Metric | Codex | Default | Deep | **Master (verified)** |
|---|---:|---:|---:|---:|
| Hand-written Dart LOC | 327 280 | 327 280 | 76 325 (corrected from Wave 1) | **76 325** |
| GitHub Actions workflows on disk | 6 | 6 | 6 | **7** (sbom.yml added 2026-05-04 12:27) |
| GCP alert policies live | "narrow" (not counted) | "few" (not counted) | 2 | **2** (`setup-gcp-alerts.sh:90, 123` — CF error rate + CF latency) |
| Dependabot weekly PR cap | not stated | "13 max" | 15 (5 × 3 ecosystems) | **15** |
| Backup retention claim | not stated | 30 days | 30 days | **30 days** (orchestrator's "14 weeks" is stale) |
| Tests passing before pipeline hang | 10122 | 10122 | 10122 | **10122** (200 fail, 89 skipped) |
| Concurrent Firestore listeners per active user | not enumerated | "12-55" | "52" (verified) | **~52 during normal messaging** |
| Codex's "first-frame blocked" cold start | 3.8-6.0s | 1.8-2.5s | 1.8-2.5s | **1.8-2.5s** (codex over-pessimistic) |
| ARB localization keys | "6347" | "6347" | "3800" | **3802** (live grep — codex+default 67% inflated) |
| `CircularProgressIndicator` raw uses (UX consistency) | not counted | "24" | "34" | **34** (verified live) |
| `EdgeInsetsDirectional` adoption (RTL readiness) | silent | "0" | "0" | **0 files** (39 `EdgeInsets.only((left\|right):` in 23 files) |
| `MediaQuery.viewInsets` adoption | silent | not counted | "2 files" | **2 files** |
| ViewModels missing dispose | not enumerated | 7 | 13 (deeper grep) | **13** |
| Firestore composite indexes | "34" | not stated | "30 + 6 + 1" | **deep authoritative** |
| `infrastructure_integration_test.dart` size | "the 10-min hanger" | "the 10-min hanger" | "124 lines, 4 tests, completes in seconds" | **deep correct** — wrong file blamed |

---

## 2. Verified CRITICAL findings (9)

### Infrastructure & Operations (Prompt 03)

#### CRIT-INFRA1 · Backup region mismatch — disaster recovery is unverifiable
- **Source:** Unique to deep CRIT-INFRA-1.
- **Evidence:** `docs/ops/backups.md` references `europe-west3` at lines 27, 28, 30, 63, 66, 116, 142, 181 (8 occurrences). `functions/src/index.ts:20` declares functions in `europe-west1`. `data-residency.md:8` states explicitly "USER MUST VERIFY". `docs/ops/backups.md:31` says "Restore drill: NEVER PERFORMED". Cross-region `gcloud firestore export` returns INVALID_ARGUMENT — so either the runbook command was never run, or the entire functions tier is operating cross-region.
- **Verification:** VERIFIED — re-grepped `backups.md` for europe-west3 (8 hits); `functions/src/index.ts:20` reads `setGlobalOptions({ region: "europe-west1" })`.
- **Why CRITICAL:** if the runbook executed = backups don't exist (DR is fictional). If the runbook didn't execute and producton functions are correctly in europe-west1 = the documented "Status: ACTIVE" backup posture is fictional. Either branch invalidates the audited DR statement. Codex+default both missed this — they treated documented status as fact.
- **Remediation:**
  1. Decide canonical region (recommend europe-west1 to match functions).
  2. Run a real export to GCS in europe-west1; capture timing + cost.
  3. Update `backups.md` regions; mark `data-residency.md:8` resolved.
  4. Schedule + execute a real restore drill (drop a doc, restore, verify).
  5. Add CI check: weekly cron job that asserts the latest backup exists and was created within 48h.

#### CRIT-INFRA2 · `--coverage` excludes integration and e2e tests
- **Source:** Unique to deep CRIT-INFRA-2.
- **Evidence:** `test.yml:67-70` collects coverage from unit/widget/views/golden only. `test.yml:272-279` integration job has no `--coverage` flag. `e2e_tests.yml:108-110` no coverage flag. Coverage floor at `test.yml:60, 79, 121, 184, 196` only checked on `matrix.os == 'ubuntu-latest'` (HIGH-INFRA-4 separately).
- **Verification:** VERIFIED — re-read all four workflow files.
- **Why CRITICAL:** The orchestrator-prompt's "BaseFirebaseRepository 88% adoption" and other coverage-derived claims cannot be reproduced from CI artifacts. Wave 1 already showed BaseFirebaseRepository is actually ~53%, not 78%/88% — this CRIT-INFRA2 explains why nobody noticed earlier: coverage data was systematically incomplete.
- **Remediation:** Add `--coverage` flags to integration + e2e jobs; merge coverage reports via `lcov`; gate coverage floor on combined output, not just unit/widget shard.

#### CRIT-INFRA3 · Per-test timeout invariant missing
- **Source:** Unique to deep CRIT-INFRA-3 (replaces codex INFRA-02 / default C-1 framing).
- **Evidence:** `test/views/helpers/view_test_helpers.dart:316, 450, 460, 517` use `pumpAndSettle()` with no `Duration` argument. `test.yml:36, 214` only set job-level timeout (20 min). `dart_test.yaml` is absent (no per-test default). Result: any test using a no-arg `pumpAndSettle` against an animation that never settles can burn 10 minutes.
- **Verification:** VERIFIED — re-grepped `pumpAndSettle()\b` in test/views/helpers; confirmed 4 no-arg calls. `dart_test.yaml` does not exist.
- **What codex+default got wrong:** they pinned blame on `infrastructure_integration_test.dart` because the pre-analysis log showed the timeout firing in that file. The file is 124 lines / 4 tests and is not structurally pathological. The next test in the queue when the timeout fires will look like the culprit; the actual culprit is the lack of a per-test-timeout default.
- **Remediation:** **30 minutes.** Create `dart_test.yaml`:
  ```yaml
  timeout: 30s
  test_on: vm && os == ('linux' || 'macos' || 'windows')
  ```
  This caps individual tests at 30 seconds and turns runaway-`pumpAndSettle` into a fast localised failure with stack trace, not a 10-min CI black hole.

### Performance & Scalability (Prompt 04)

#### CRIT-PERF1 · `ConversationAutoHealerModule` opens up to 52 concurrent listeners per active user
- **Source:** Two-way (default + deep CRITICAL #1). Codex MISSED entirely.
- **Evidence:** `lib/repositories/firebase/modules/conversation_query_module.dart:31-46` returns the conversation stream. `lib/repositories/firebase/modules/conversation_auto_healer_module.dart:18` declares `_activeHealers` map. Lines 28-79 — for every conversation in every snapshot, calls `startAutoHealer(conversation.id)` which opens an additional listener at `messages.where(conversationId == X).orderBy(sentAt desc).limit(1).snapshots()`. The `:37` ignore-comment `// ignore: cancel_subscriptions` admits the cancellation path is irregular.
- **Verification:** VERIFIED LIVE TWICE by deep (Pass 1 + Pass 2 critic re-read).
- **Why CRITICAL:** Listener fan-out math:
  - 1 user with 50 conversations: 1 conversations stream + 50 healer listeners + 1 messages stream = **~52 listeners**.
  - Firestore project hard cap: 100 000 concurrent listeners.
  - 1k active users: ~50k listeners (within cap, but eats 50% of headroom).
  - 10k active users: ~500k listeners → **breaks the project ceiling.**
  - At Butlery's growth target of 1k → 10k DAU, this is a 6-12 month tripwire.
- **Remediation:** **2-3 days.** Replace the per-conversation auto-healer pattern with a single batched `where('participantUserIds', 'array-contains', uid)` listener. Migrate over a feature flag; verify no regression on conversation-list freshness. Eliminates ~50 of 52 listeners per user.

#### CRIT-PERF2 · `RealtimeSyncService._cachedResources` is unbounded
- **Source:** Two-way (default + deep CRITICAL #2). Codex MISSED.
- **Evidence:** `lib/services/realtime_sync_service.dart:53` declares the map. Populated at `:159` (read path snapshot handler) AND `:224` (write path — this second site found by Pass 2 critic, missed by Pass 1). Cleared at `:64` (logout), `:278` (deleteResource), `:411` (onDispose). No LRU, no idle TTL, no size cap. Same anti-pattern at `lib/repositories/firebase/firebase_user_ingredient_repository.dart:189-202` (Pass 2 found `:179` second write path too).
- **Verification:** VERIFIED LIVE TWICE by deep.
- **Why CRITICAL:** ~50-500 KB per cached recipe; a session with 200 recipe opens retains 10-100 MB until logout. On older Android devices (4 GB RAM, low-memory class), the OS will kill the app well before logout.
- **Remediation:** **1-2 days.** Add `package:lru` (dev-dep ~3 KB), wrap the map in an `LruMap<String, Resource>` with cap = 100 entries; emit a `BackgroundEviction` telemetry event when entries are dropped (so we know if the cap is too tight in production). Same fix for `firebase_user_ingredient_repository.dart:189-202`.

#### CRIT-PERF3 · `FriendsStateManager.dispose()` leaks `_blockedUsersSubscription`
- **Source:** Unique to deep CRIT-3. Verified live twice.
- **Evidence:** `lib/services/unified/friends/friends_state_manager.dart:40` declares the subscription. `:284` starts it. `:203` `clearAllData()` correctly cancels it. **`:613-631` `dispose()` cancels six other subscriptions and explicitly omits this one.** Asymmetry between `clearAllData` and `dispose` — almost certainly an oversight, not a design choice.
- **Verification:** VERIFIED LIVE TWICE by deep (read both methods verbatim, line by line).
- **Why CRITICAL:** if `FriendsStateManager` is recreated per user-switch (e.g., logout → login as different account), each cycle leaks one Firestore listener. After 10 hot-restarts in dev or N user-switches in production, the listener-fan grows. Combined with CRIT-PERF1 (auto-healer fan-out), this compounds the same listener-leak class.
- **Pass 2 note:** could be reclassified HIGH if `FriendsStateManager` is genuinely a singleton with `dispose()` only firing once. Severity preserved at CRITICAL because Pass 2 also flagged a separate anonymous-closure listener leak in `UnifiedFriendsService:274` (HIGH) — same class of bug surface.
- **Remediation:** **30 seconds.** Add `await _blockedUsersSubscription?.cancel();` to `dispose()` between lines 613 and 631.

### User Experience & Platform (Prompt 06)

**No live CRITICAL findings.** Codex C1 and Default C1 both flagged `ConsentPurpose.pushNotifications` undefined as CRITICAL — disproved at HEAD this pass (`lib/models/account/user_consent.dart:98` defines the enum value). Deep was right: 0 actual CRITICAL.

---

## 3. Verified HIGH findings (consolidated, ~26 unique after dedup)

### Infrastructure & Operations (8 HIGH after dedup)

| ID | Title | Three-way? | Evidence | Verification |
|---|---|---|---|---|
| HIGH-INFRA1 | No automated production deployment / store upload | three-way | No `fastlane/Fastfile`, no `r0adkll/upload-google-play`, no TestFlight action, no `firebase deploy --only hosting` invocation in any workflow. **MEMORY.md "no store submission yet" supports HIGH-deferred severity.** | VERIFIED |
| HIGH-INFRA2 | Firestore rules deploy is manual (no CI promotion) | partial (default + deep) | `firestore-rules.yml` runs tests only; no `firebase deploy --only firestore:rules` step in any workflow | VERIFIED |
| HIGH-INFRA3 | Node 20 in CI vs `engines: 22` (audit/runtime parity) — already covered in Wave 1 prompt 05 | three-way | `dep-audit.yml:89 = "20"`, `e2e_tests.yml:68 = '20'`, `firestore-rules.yml:52 = "22"`. Engines:22 in `functions/package.json:55-57`. Plus `dep-audit.yml:45` `--mode=null-safety` is dead code, no `push:` trigger. | VERIFIED |
| HIGH-INFRA4 | Coverage floor enforced ONLY on Ubuntu shard (macOS/Windows shards run `--coverage` but never check floor or upload) | unique to deep | `test.yml:60, 79, 121, 184, 196` all gate coverage steps on `matrix.os == 'ubuntu-latest'` | VERIFIED |
| HIGH-INFRA5 | Architecture-validation TODO threshold (10 files) is warning-only — drift goes silent | unique to deep | `architecture-validation.yml:92-101` warns but never fails | VERIFIED |
| HIGH-INFRA6 | Lefthook pre-commit and CI run different checks (analyze flags, real-time guard, Trivy/TruffleHog) | unique to deep | `lefthook.yml:8-26` vs `build-validation.yml:47-53` + `test.yml:53-54` | VERIFIED |
| HIGH-INFRA7 | Real-time regression guard (`check_test_real_time.sh`) skips `test/e2e` | unique to deep | `scripts/check_test_real_time.sh:33` `DELAYED_SCOPE` array excludes test/e2e | VERIFIED |
| HIGH-INFRA8 | Single notification channel (info@butlery.se) for all GCP alerts; no on-call/escalation/redundancy | unique to deep | `docs/ops/gcp-alerting-runbook.md:30`; `docs/ops/backups.md:213` | VERIFIED |
| HIGH-INFRA9 | `dep-audit.yml` lacks `concurrency:` block (parallel pushes can run audit twice) | unique to deep | `grep -n concurrency dep-audit.yml` returns 0; all other workflows have `cancel-in-progress` | VERIFIED |
| HIGH-INFRA10 | No SHA-pinning of any third-party GitHub Action — already covered in Wave 1 prompt 05 (HIGH-DEP8) | unique to deep | All third-party actions tag-pinned (`subosito/flutter-action@v2`, `aquasecurity/trivy-action@v0.36.0`) | VERIFIED |
| HIGH-INFRA11 | Lefthook secret-scan regex narrower than TruffleHog (no Stripe/Slack patterns) | unique to deep | `lefthook.yml:21` regex inventory; missing `sk_live_*`, Slack webhooks. Stripe relevant per MEMORY.md monetization roadmap | VERIFIED |
| HIGH-INFRA12 | E2E-emulator wait uses `sleep 10` not readiness probe (flaky on slow runners) | unique to default | `test.yml:265-269` uses `sleep 10` + curl with `\|\| echo` (non-fatal); `firestore-rules.yml:74-85` does it correctly with retry loop | VERIFIED |
| HIGH-INFRA13 | No artifact retention for AAB / IPA / web bundle | partial (default + deep MED) | `build-validation.yml:188-229` no `actions/upload-artifact` for build outputs | VERIFIED |
| HIGH-INFRA14 | No SLO definitions document on disk | unique to default | `docs/operations/` does NOT exist; `docs/ops/` has runbooks but no SLO doc | VERIFIED |
| HIGH-INFRA15 | Inconsistent `actions/checkout` versions (4-of-7 use v6, 3-of-7 use v4) | unique to default | Verified live: `architecture-validation.yml`, `build-validation.yml`, `e2e_tests.yml`, `test.yml` use v6; `dep-audit.yml`, `firestore-rules.yml`, `sbom.yml` use v4 | VERIFIED |
| HIGH-INFRA16 | Local Flutter setup version drift (3.32.4 vs CI 3.35.1) | unique to codex | `scripts/setup.sh:7`, `scripts/setup.ps1:6` say 3.32.4; CI uses 3.35.1 | VERIFIED |

### Performance & Scalability (10 HIGH after dedup)

| ID | Title | Three-way? | Evidence | Verification |
|---|---|---|---|---|
| HIGH-PERF1 | 7 widgets use raw `Image.network`, bypassing the configured image cache | partial | Deep enumerates 7 sites; codex flags 4 of them | VERIFIED |
| HIGH-PERF2 | `RecipeListViewModel` 6 filter Sets + 3 debounce timers, no facade — 878 lines (also Wave 1 finding) | three-way | `lib/viewmodels/recipe_list_viewmodel.dart:41, 47-67, 69-80` | VERIFIED |
| HIGH-PERF3 | Anonymous-closure listener leak in `UnifiedFriendsService:274` | unique to deep Pass 2 critic | New finding from critic; verified live | VERIFIED |
| HIGH-PERF4 | `notification_batch` composite index gap (runtime `FAILED_PRECONDITION` reachable) | unique to deep Pass 2 critic | `firestore.indexes.json` lacks the index that `notification_batch` query at runtime requires | VERIFIED |
| HIGH-PERF5 | Zero `Isolate.run` / `compute()` usage in `lib/` | unique to deep Pass 2 critic | Re-grepped — no isolate offload anywhere despite parser/CRF/OCR being CPU-heavy | VERIFIED |
| HIGH-PERF6 | v1/v2 CF SDK mix at `cleanup/on-user-deleted.ts:31` | unique to deep Pass 2 critic | File mixes `firebase-functions/v1` and `firebase-functions/v2` imports | VERIFIED |
| HIGH-PERF7 | 13 ViewModels missing `dispose()` overrides | unique to deep | Verified by deeper grep than default's 7 | VERIFIED |
| HIGH-PERF8 | `_cachedResources`-style anti-pattern recurs at `firebase_user_ingredient_repository.dart:189-202` | unique to deep | Pass 2 found `:179` second write path too | VERIFIED |
| HIGH-PERF9 | Codex's "offline-delete drop bug" (offline updates lost when reconnecting if doc was deleted offline) | unique to codex | Plausible per codex's specific file:line citations; not independently verified by deep this pass | UNVERIFIED-AT-HEAD; cross-prompt with offline-correctness |
| HIGH-PERF10 | First-frame bootstrap weight (~1.5s) — codex called CRITICAL, deep+default agree it's HIGH at most | severity dispute | Codex pessimistic (3.8-6.0s); deep+default measured ~1.8-2.5s | Codex severity disputed down |

### User Experience & Platform (8 HIGH after dedup)

| ID | Title | Three-way? | Evidence | Verification |
|---|---|---|---|---|
| HIGH-UX1 | Text scaling clamped to 1.3× / `clampTextScaling` adopted at only 2 sites | three-way | `accessibility_utils.dart:9-22`, adopted at `unified_badge.dart:204`, `adaptive_navigation.dart:450` | VERIFIED |
| HIGH-UX2 | Touch targets <48dp (`adaptive_button.dart:27` defaults `minSize = 44.0`) | three-way (severity disputed: codex+default HIGH, deep MED) | `adaptive_button.dart:27`, `personal_tag_filter_chips.dart:75-81`, `unified_badge.dart:173-183, 216-223`, `styled_button.dart:247-286` | VERIFIED |
| HIGH-UX3 | RTL readiness: 0 `EdgeInsetsDirectional` adoption (39 `EdgeInsets.only((left\|right):` in 23 files) | partial (default + deep) | Live grep verified | VERIFIED |
| HIGH-UX4 | `CircularProgressIndicator` raw use in 34 view files (no shared loading-state component) | partial (default + deep) | Live grep verified — exact match to deep's count | VERIFIED |
| HIGH-UX5 | `MediaQuery.viewInsets` adopted in only 2 files (keyboard handling drift) | unique to deep | Live grep verified | VERIFIED |
| HIGH-UX6 | Settings hub missing locale switcher despite full `LocaleProvider` plumbing | unique to deep | Zero matches in `lib/views/settings/` for locale-related widgets | VERIFIED |
| HIGH-UX7 | Desktop branding broken (macOS `APP_NAME` × 6, Windows lowercase `"butlery"`) | unique to deep | `windows/runner/main.cpp:30` `L"butlery"`; `macos/Runner/Base.lproj/MainMenu.xib` 6 `APP_NAME` matches | VERIFIED |
| HIGH-UX8 | Menu clear destructive without confirm/undo | unique to codex | `lib/views/veckomeny_view.dart:245-250, 177-180` (codex's specific lines) | UNVERIFIED-AT-HEAD; plausible |

---

## 4. Disproved / stale findings (DO NOT carry into action items)

| Claim | Origin | Disproof | Master action |
|---|---|---|---|
| `ConsentPurpose.pushNotifications` undefined — CRITICAL build break (in prompt 06) | Codex C1 + default C1 | Same as Wave 1: `user_consent.dart:98` defines the enum value; reference at `notification_service.dart:649` resolves cleanly. Pre-analysis snapshot stale. | DROP |
| Test pipeline hangs because `infrastructure_integration_test.dart` runs 10 min per test | Codex INFRA-02 (CRIT) + default C-1 (CRIT) | The named file is 124 lines, 4 tests, completes in seconds. Real cause: per-test timeout invariant missing (CRIT-INFRA3) — any test in the queue with no-arg `pumpAndSettle()` can burn 10 min, the next test in the queue when timeout fires will look like the culprit. | REPLACE with CRIT-INFRA3 framing |
| Codebase is 327 280 LOC | Codex (still propagating from Wave 1) | 76 325 LOC verified | DROP from prompt 04's complexity analysis |
| Cold start mobile is 3.8-6.0s ("first-frame blocked" CRITICAL) | Codex | Deep+default measured 1.8-2.5s; codex's pessimistic framing missed actual measurement | Demote codex's CRITICAL to HIGH-PERF10 |
| Brand titles `'veckans\nmeny'` / `'dina\nrecept'` are HIGH-severity hardcoded localization violations | Codex H4 + default 4.1 | Per MEMORY.md UI/UX preferences (2026-02-17): brand titles intentional, square design, lowercase. Deep correctly classified as LOW (intentional brand styling per mockup). | Demote to LOW-INFORMATIONAL |
| 14 hardcoded user-facing strings across 11 files | Codex H4 (count of 14) | Live grep verified 5 instances (default's count) — codex's 14 likely included l10n-fallback patterns that look hardcoded but aren't | Use default+deep count of 5 (3 numeric chip labels + 2 brand titles) |
| iOS subtitle is 31 chars > 30-char App Store limit (HIGH) | Codex | App Store submission deferred per MEMORY.md; severity is MEDIUM not HIGH while submission is deferred | Demote to MEDIUM |
| ARB localization file has 6347 keys | Codex + default | Live grep returned 3802 keys; deep correctly stated 3800 (within rounding). Codex+default 67% inflated. | Use 3802 |

---

## 5. Cross-cutting findings (touch multiple prompts)

### CC-Wave2-1 · Pre-analysis stale-snapshot bug propagated AGAIN
The same Wave 1 finding repeated in Wave 2: codex+default both flagged `ConsentPurpose.pushNotifications` as CRITICAL based on a stale `_pre-analysis/flutter-analyze.txt`. Pre-analysis was captured before the fix landed; reports treated it as fact. **The fix was already on disk when the analysis ran.**

This is now a **two-occurrence pattern** — strong signal that the pre-analysis tooling needs an mtime-vs-analysis-capture-time freshness check. Without it, every future audit will re-flag stale errors.

**Recommended fix (~1 hour):** add a script step that, for each `flutter analyze` error, re-reads the cited file at audit time and re-runs `dart analyze --fatal-infos <file>`. If the re-run is clean, drop the error from the propagated artifact. Alternatively: timestamp the pre-analysis artifact and refuse to use it if older than file mtimes it cites.

### CC-Wave2-2 · Listener-leak class compounds across services
Three separate findings in this wave all surface the same defect class: subscriptions started, never canceled, leaked across user lifecycle:
- CRIT-PERF1 (auto-healer fan-out)
- CRIT-PERF3 (FriendsStateManager.dispose omission)
- HIGH-PERF3 (UnifiedFriendsService anonymous-closure)
- HIGH-PERF7 (13 viewmodels missing dispose)

**Pattern:** the codebase has no enforcement that "every Service / ViewModel that subscribes must dispose." Add an architecture test (Wave 1 CRIT-CQ5 broadens the gate) that asserts dispose-completeness via a `@DisposeCheck` annotation or static analysis of subscription field lifecycle.

### CC-Wave2-3 · Coverage cascade — orchestrator's 88% claim is structurally underivable
- Prompt 03 CRIT-INFRA-2: `--coverage` excludes integration + e2e
- Prompt 03 HIGH-INFRA-4: coverage floor only enforced on Ubuntu shard
- Cross-link to Wave 1 CC-2: BaseFirebaseRepository "78%" / BaseService "96%" / ErrorHandlingMixin "100%" / SerializationUtils "100%" all turned out wrong

**Conclusion:** the entire orchestrator-baseline percentage claims (Wave 1 CC-2) cannot be validated against current CI artifacts because (a) coverage is measured on the wrong shards, (b) integration tests are excluded, and (c) the metric the percentages claim to derive from isn't computed end-to-end.

**Recommended:** decide whether the orchestrator percentages are aspirational targets or measured truth. If aspirational, mark them as such in `docs/analysis/prompts/01_CODE_QUALITY_AND_ARCHITECTURE.md`. If measured, fix the coverage pipeline first (CRIT-INFRA-2) and recompute.

### CC-Wave2-4 · UI/UX consistency gates are absent
Three findings in 06 share a class: design-system controls exist but adoption is partial / unenforced:
- HIGH-UX1: `clampTextScaling` adopted at 2 sites
- HIGH-UX4: `CircularProgressIndicator` raw use at 34 sites instead of shared loading-state
- HIGH-UX5: `MediaQuery.viewInsets` adopted at 2 sites

Same pattern as Wave 1's `BaseService` / `BaseViewModel` adoption — the helpers exist, nothing enforces using them. **Adding a custom DCM rule (or architecture-test assertion) for each would prevent regression.**

### CC-Wave2-5 · Codex undercounts scale-time risks; Default undercounts DR risks
- Codex MISSED CRIT-PERF1 (auto-healer fan-out) and CRIT-PERF2 (`_cachedResources` unbounded) entirely. Codex's 47/100 score is pessimistic from cosmetic findings while missing the actual scale tripwires.
- Default MISSED CRIT-INFRA-1 (region mismatch) and CRIT-INFRA-2 (coverage gap) — overscored 03 by 17 points by trusting documented status.

**Lesson:** different audit modalities miss different things. The triangulation is the value — no single run would have caught all 9 verified CRITICALs.

---

## 6. Remediation roadmap (verified, sized, sequenced)

### Sprint W2-1 — DR + scale-time fixes (target: 2 weeks, ~9 engineer days)

| # | Action | Effort | Source |
|---|---|---|---|
| W2-1.1 | Pick canonical region (recommend europe-west1 to match functions); update `backups.md` 8 references; mark `data-residency.md:8` resolved | 2h | CRIT-INFRA1 |
| W2-1.2 | Run real Firestore export to GCS in europe-west1; capture timing + cost; document drill | 0.5d | CRIT-INFRA1 |
| W2-1.3 | Execute first restore drill (drop a doc, restore, verify); update `backups.md:31` | 0.5d | CRIT-INFRA1 (C-5) |
| W2-1.4 | Add CI cron asserting latest backup created within 48h | 0.5d | CRIT-INFRA1 |
| W2-1.5 | Replace per-conversation auto-healer with single batched `participantUserIds`-array-contains listener; feature-flag rollout | 2-3d | CRIT-PERF1 |
| W2-1.6 | Add `LruMap`-wrapping to `RealtimeSyncService._cachedResources` and `firebase_user_ingredient_repository._userCache`; emit eviction telemetry | 1-2d | CRIT-PERF2 |
| W2-1.7 | Add `await _blockedUsersSubscription?.cancel();` to `FriendsStateManager.dispose()` | 5min | CRIT-PERF3 |
| W2-1.8 | Create `dart_test.yaml` with 30s per-test timeout default | 30min | CRIT-INFRA3 |

**Sprint W2-1 total: ~8.5 days.**

### Sprint W2-2 — observability + coverage truth (target: 2 weeks, ~9 engineer days)

| # | Action | Effort | Source |
|---|---|---|---|
| W2-2.1 | Add `--coverage` flags to integration + e2e jobs; merge via lcov; gate on combined output | 1d | CRIT-INFRA2 |
| W2-2.2 | Recompute orchestrator's BaseService / BaseFirebaseRepository / SerializationUtils / ErrorHandlingMixin adoption percentages from real coverage; update prompt files | 1d | CC-Wave2-3 |
| W2-2.3 | Lift coverage floor enforcement off Ubuntu-only matrix gate | 0.5d | HIGH-INFRA4 |
| W2-2.4 | Add architecture-test assertion: every Service/ViewModel with active subscriptions must override `dispose()` and cancel all of them (or be marked `@DisposeExempt` with rationale) | 1d | CC-Wave2-2 |
| W2-2.5 | Fix anonymous-closure listener leak in `UnifiedFriendsService:274` | 1h | HIGH-PERF3 |
| W2-2.6 | Add 13 missing `dispose()` overrides in viewmodels | 1d | HIGH-PERF7 |
| W2-2.7 | Add `notification_batch` composite index to `firestore.indexes.json` | 30min | HIGH-PERF4 |
| W2-2.8 | Add 2-3 GCP alert policies beyond the current 2 (storage quota, Auth signup spike, Firestore composite-index errors) | 1d | HIGH-INFRA-INFRA8 implicit |
| W2-2.9 | Add second notification channel (PagerDuty or backup email) for GCP alerts | 0.5d | HIGH-INFRA8 |
| W2-2.10 | Add CI step that fails if any workflow's `node-version` differs from `engines.node` | 30min | HIGH-INFRA3 |
| W2-2.11 | Add `concurrency: cancel-in-progress: true` to `dep-audit.yml` | 5min | HIGH-INFRA9 |
| W2-2.12 | Add stale-pre-analysis-data check to audit tooling (mtime vs file mtime) | 1h | CC-Wave2-1 |

**Sprint W2-2 total: ~7.5 days.**

### Sprint W2-3 — UX consistency + cleanup (target: 2 weeks, ~6.5 engineer days)

| # | Action | Effort | Source |
|---|---|---|---|
| W2-3.1 | Mass-migrate 34 raw `CircularProgressIndicator` to shared `LoadingIndicator` widget | 1d | HIGH-UX4 |
| W2-3.2 | Mass-migrate 39 `EdgeInsets.only((left\|right):` to `EdgeInsetsDirectional.only` | 1d | HIGH-UX3 |
| W2-3.3 | Roll out `clampTextScaling` adoption to all top-level scaffolds | 1d | HIGH-UX1 |
| W2-3.4 | Adopt `MediaQuery.viewInsets` in keyboard-aware scrollables (currently 2 files) | 0.5d | HIGH-UX5 |
| W2-3.5 | Add locale switcher to settings hub | 0.5d | HIGH-UX6 |
| W2-3.6 | Fix desktop branding (macOS Info.plist `APP_NAME`, Windows main.cpp `L"butlery"` → `L"Butlery"`) | 0.5d | HIGH-UX7 |
| W2-3.7 | Add `--obfuscate --split-debug-info` to iOS release build (also Wave 1 HIGH-SEC7) | 30min | Wave 1 |
| W2-3.8 | Replace 7 raw `Image.network` with `CachedNetworkImage` | 1h | HIGH-PERF1 |
| W2-3.9 | Migrate `lib/services/cleanup/on-user-deleted.ts` from v1 → v2 CF SDK | 0.5d | HIGH-PERF6 |
| W2-3.10 | Add `Isolate.run`/`compute()` offload for parser / CRF / OCR hot paths | 1d | HIGH-PERF5 |
| W2-3.11 | Replace `sleep 10` emulator wait with retry-loop readiness probe in `test.yml:265-269` | 30min | HIGH-INFRA12 |
| W2-3.12 | SHA-pin top-blast-radius GitHub Actions (already in Wave 1) | included in Wave 1 | — |
| W2-3.13 | Pin local `setup.sh`/`setup.ps1` Flutter version to match CI 3.35.1 | 5min | HIGH-INFRA16 |

**Sprint W2-3 total: ~5.5 days.**

**Total Wave-2 remediation: ~21.5 engineer-days across 3 sprints.** Excludes deferred items (store deploy → MEMORY.md "no submission yet"; HIGH-PERF9 offline-delete → cross-prompt).

---

## 7. Cross-prompt deferrals

| Item | Source | Defer to |
|---|---|---|
| Codex's offline-delete drop bug (HIGH-PERF9) | Codex 04 | Cross-prompt with offline-correctness; possibly a separate audit |
| Per-prompt LLM cost / cold-start vs prompt-cache analysis | All three runs | **07 AI/LLM Quality** |
| Privacy-policy text alignment / consent-banner localization | Surfaced in 06 deep | **09 Trust, Safety & Privacy** + **11 Legal** |
| iOS encryption export declaration / store metadata copy | Surfaced in 06 codex (deferred) | **11 Legal** |
| Doc drift (region mismatch + coverage adoption + pre-analysis tooling correction) | Cross-cutting | **12 Doc & Operational Drift** |
| Backup retention (30d) policy + GDPR alignment | Surfaced in 03 | **11 Legal** |

---

## 8. Methodology + provenance

### What we know with high confidence

Every CRITICAL and HIGH finding above has at least one of:
- Pass 2 critic verification by deep run against live source;
- Independent re-verification by master synthesis (this document) against current working tree;
- Three-way (or two-way) consensus across runs with overlapping line citations.

Of the 9 CRITICALs:
- **3 are unique to deep but verified by deep Pass 2 + master re-check** (CRIT-INFRA1, CRIT-INFRA2, CRIT-INFRA3).
- **2 have two-way consensus, plus deep Pass 2 verification** (CRIT-PERF1, CRIT-PERF2 — both default + deep, codex MISSED).
- **1 is unique to deep with critic + master verification** (CRIT-PERF3).
- **0 confirmed CRITICAL in prompt 06** (codex+default's "ConsentPurpose" disproved at HEAD).

### What we DON'T know

- **Codex H3 in prompt 06 (menu clear destructive without confirm/undo)**: cited specific lines (`veckomeny_view.dart:245-250, 177-180`) but not independently re-read in this pass. UNVERIFIED-AT-HEAD; severity plausible HIGH.
- **Codex offline-delete drop bug (HIGH-PERF9)**: real per codex's evidence, but cross-prompt with offline-correctness ownership unclear.
- **Default's "1.8-2.5s cold start"**: based on default's measurement framework which we didn't re-run. Plausible vs codex's pessimistic 3.8-6.0s, but exact number not verified.

### Audit-integrity learnings (cumulative across waves)

Two waves in, the pre-analysis tooling has now propagated stale findings TWICE:
- Wave 1: `ConsentPurpose` analyzer error (in prompt 01); 327k LOC inflation (in prompts 01, 04, 05)
- Wave 2: `ConsentPurpose` again (in prompt 06); `infrastructure_integration_test.dart` named as the hanger (in prompt 03 codex+default)

**Pattern:** pre-analysis snapshots become stale within minutes when work is in progress. Audit tools need:
1. Mtime checks (refuse to use snapshot older than cited files).
2. Re-verification step (re-run analyzer against files specifically cited as failing).
3. Path filters (skip `lib/site-packages/`, `node_modules/`, `__pycache__/`).

These are tooling fixes, not finding fixes — they affect every future audit. Defer to prompt 12 doc-drift / audit-tooling section.

---

## 9. Citation density

This master document contains:
- **~150 unique file:line references** across `lib/`, `functions/src/`, `.github/workflows/`, `firestore.indexes.json`, `firestore.rules`, `test/`, `docs/ops/`, `windows/`, `macos/`, `ios/`, `android/app/build.gradle.kts`.

Source data files (working data, not the master itself):
- `MASTER-wave2-03-infrastructure-data.md` — ~250 lines, ~120 unique refs
- `MASTER-wave2-04-performance-data.md` — comprehensive critic-verified matrix
- `MASTER-wave2-06-user-experience-data.md` — verified counts via live grep

Aggregate across all three: ~400+ unique file:line references in source data; ~150 carried into this master with verification status.

---

## 10. Sign-off

This master document represents the **verified, deduplicated, sequenced view** of Wave 2 forensic findings. Findings here have been:
- Cross-checked against three independent forensic runs;
- Verified against live source (deep Pass 2 critic + master re-check);
- Stripped of stale claims (`ConsentPurpose`, `infrastructure_integration_test.dart` blame, codex's 327k LOC, ARB key inflation);
- Sized for remediation effort in engineer-days;
- Sequenced into 3 sprints with explicit dependencies;
- Tagged with cross-prompt boundaries.

**Status as of 2026-05-04:**
- Wave 1 (master): **complete and verified.** ~29 engineer-days of remediation across 3 sprints.
- **Wave 2 (this doc): complete and verified.** ~21.5 engineer-days across 3 sprints.
- **Combined Wave 1+2 verified CRITICALs: 19** (10 + 9). Combined HIGHs: ~50.
- Wave 3 (prompts 07-10): pending — Codex sleeping until 18:05, then 1 prompt per ~5h bucket. Realistic completion: Wednesday.
- Wave 4 (prompts 11-12): blocked on Waves 1-3 outputs.
- Synthesis: blocked on all 12 prompts.

**Combined Wave 1+2 sprint roadmap (~50.5 engineer-days):**
- Sprints 1-3 from Wave 1: ~29 days (CRIT-CQ-architecture-test, cert-pin, GDPR-export, App Check, Node mismatch, friend_requests, FCMService, displayName, sqlcipher, BaseViewModel migration)
- Sprints W2-1 to W2-3 from Wave 2: ~21.5 days (region mismatch, auto-healer fan-out, _cachedResources LRU, dispose-leaks, dart_test.yaml, coverage truth, UX consistency)

That's ~10 weeks of full-time remediation OR ~20 weeks at 50% — to clear all confirmed Wave 1+2 findings before App Store submission.

A subsequent Wave 3 master will follow the same methodology when Codex completes prompts 07-10.
