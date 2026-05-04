# Code Quality & Architecture — Phase 1 Findings

**Analyst:** Claude (Opus 4.7, 1M context)
**Run:** 2026-05-claude — Prompt 01 of 12
**Date:** 2026-05-02
**Phase:** Investigation only — no code changes

---

## Executive Summary

```
BUTLERY CODE QUALITY & ARCHITECTURE ANALYSIS — PHASE 1 FINDINGS
================================================================
Codebase: 1,252 hand-written .dart files / 327,280 lines (excludes generated)
Reality vs orchestrator claim ("~850+ files / ~150k lines"): +47% files / +118% lines

OVERALL SCORE: 71/100   (Acceptable — prioritized remediation in next 2 sprints)

  Architecture Compliance:        15/20
  File Size & Complexity:          8/15   (single largest drag — 4× the documented count)
  Deduplication & Infrastructure: 12/15
  Error Handling & Resilience:    11/15
  Documentation Health:            7/10   (doc-vs-reality drift owned by prompt 12)
  Code Readability:                8/10
  Production Readiness:            7/10
  Deprecated API & Tech Debt:      3/5

CRITICAL: 2     HIGH: 8     MEDIUM: 11     LOW: 7
```

**Headline finding:** the codebase is structurally healthier than its documentation suggests on most axes (zero `print()` in production, zero `withOpacity()`, no `setState()` in ViewModels, healthy mixin adoption), but has accumulated **3.7× the documented "intentionally large" file count** (132 over the 500-line line vs 33 documented) and ships with a **compile-error-class issue** in flutter analyze that needs to either be reproduced, root-caused, or marked stale.

---

## Pre-Analysis Reuse Notes

- `flutter analyze` was captured at 2026-05-02 19:48; `notification_service.dart` was modified at 19:51. The captured error may already be resolved on disk. I did not re-run analyze (per instructions). Treat the captured "1 issue found" as last known state — see **C-1** for what to verify.
- Test infrastructure hang: confirmed on file `test/views/helpers/infrastructure_integration_test.dart` (4 widget tests). Root cause investigated below — see **C-2**.

---

## Codebase Scale (verified vs documentation)

| Metric | Doc claim | Reality | Drift |
|---|---|---|---|
| Hand-written `.dart` files | ~850+ | 1,252 | +47% |
| Hand-written LOC | ~150k+ | 327,280 | +118% |
| Files >500 lines | 33 ("intentional") | 132 | +99 (4×) |
| Files >1,000 lines | 4 | 4 (`recipe_image_manager`, `recipe_unified`, `main`, `known_ingredients`) | aligned |
| Service files | ~70 | 88 | +18 |
| Direct Firebase instance usage | 17 files | 29 files | +12 |
| BaseFirebaseRepository extenders | 35/45 (~78%) | 32 direct extenders + 3 transitive = 35 | aligned with reconciled denominator |
| BaseService extenders | ~67/~70 (96%) | 72 of 88 (~82%) | -14% (denominator drift) |
| `print()` in production | n/a | 0 hand-written calls | clean |
| `.withOpacity(` | n/a | 0 | fully migrated |
| `setState(` in ViewModels | 2 | 0 (the 2 known are `resetState()`, false positive) | resolved |
| TODO/FIXME/HACK comments | ~14 | 23 across 9 files (mostly `BUT-427-ops` cert-pin placeholders) | low absolute count, well-tracked |

**Implication:** the orchestrator's "Confirmed Violations" block in `01_CODE_QUALITY_AND_ARCHITECTURE.md` lines 821-832 is now stale on multiple counts — flagged for prompt 12.

---

## Dimension 1 — Architecture Compliance (15/20)

### CRITICAL

**C-1. `flutter analyze` reports compile error in `notification_service.dart`**
- Evidence: `docs/analysis/runs/2026-05-codex/_pre-analysis/flutter-analyze.txt:3` —
  `error - Undefined name 'ConsentPurpose' - lib\services\notifications\notification_service.dart:648:9`
- Current source state (read live): `notification_service.dart:16` imports `package:butlery/models/account/user_consent.dart`, and that file declares `enum ConsentPurpose` at `lib/models/account/user_consent.dart:90`. The import chain *should* resolve.
- Mtime mismatch: analyze captured 19:48, file modified 19:51 (3 minutes later). The error may be from a transient pre-edit state.
- Risk: if reproducible, this is a build-breaking error — app won't compile, no tests run. If stale, the captured pre-analysis is wrong and prompt 12 needs to know.
- **Remediation:** re-run `flutter analyze` once (out of scope here). If reproduces, the bug is real (likely an unrelated import was unintentionally removed, or there's a circular dependency unwinding the export). If clean, mark the pre-analysis as stale.
- Severity: **Critical** if real, **Low** if stale. Cannot determine without re-running.

### HIGH

**H-1. View layer reaches into Firebase Auth directly**
- `lib/views/onboarding/onboarding_age_gate_blocked_view.dart:22` — `FirebaseAuth.instance.currentUser?.delete()`
- Why it matters: views must go through ViewModel → Service → Repository. Direct `FirebaseAuth.instance` calls in a view layer break the testability/repository abstraction; a `MockAuthRepository` cannot intercept this path. Comment on lines 18-21 acknowledges this is a "best-effort" cleanup but the right place is `AccountDeletionService` which already exists.
- Remediation: move under-15 cleanup into `AccountDeletionService.deleteUnderageAccount()`; view calls service. ~1h.
- Severity: **High** (testability + GDPR Art 8 path correctness)

**H-2. ViewModel imports `cloud_firestore` directly**
- `lib/viewmodels/menu/menu_storage.dart:3` — `import 'package:cloud_firestore/cloud_firestore.dart';`
- Class `MenuStorage` does inject `FirestoreRepository` (line 26-31), but the file still pulls in the SDK type — likely uses `Timestamp` or `FieldValue` types directly in method bodies. ViewModels (and ViewModel-tier modules) should not transitively import the SDK; conversion to/from Firestore primitives belongs in the repository layer.
- Remediation: audit usages in this file, replace SDK types with domain types or repository-returned shapes. ~1-2h.
- Severity: **High** (layering)

**H-3. 29 files use `FirebaseFirestore.instance` / `FirebaseAuth.instance` directly**
- Up from documented 17. Most are in `lib/repositories/` (correct — that *is* the repository layer) and `lib/core/di/` (correct — DI registration).
- Wrong locations:
  - `lib/main.dart:172, 182, 194-196` — bootstrap configuration of `FirebaseFirestore.instance.settings`. Acceptable as bootstrap, but should be wrapped behind `FirestoreSettingsConfigurator` for testability.
  - `lib/views/onboarding/onboarding_age_gate_blocked_view.dart:22` — see H-1.
  - `lib/services/notifications/fcm_service.dart` and `lib/services/notifications/notification_service.dart` — services calling Firebase SDK directly bypassing repositories. The notification-history operations should go through `NotificationHistoryRepository` (which already exists per imports).
  - `lib/services/analytics/winback_attribution_service.dart` — analytics service with direct Firestore.
- Remediation effort: ~1-2 days to migrate the 5-6 service-layer offenders to use existing repository interfaces.
- Severity: **High** (testability + the orchestrator claim is now 70% understated)

### MEDIUM

**M-1. Notification subsystem has 6 sibling "manager" classes — high coupling**
- `lib/services/notifications/modules/`: `notification_content_manager`, `notification_preference_manager`, `notification_offline_manager`, `notification_batch_manager`, `fcm_token_manager`, `notification_analytics_manager` (notification_service.dart:18-23 imports all 6).
- This is a facade pattern *applied correctly* (the file is 657 lines with 6 delegated managers), but the modules are tightly co-coupled — any consent change ripples into 6 collaborators. Worth a design review for whether `notification_service` should be split by user-facing capability (push/local/in-app) instead of by technical layer (content/preference/offline/batch/token/analytics).
- Severity: **Medium** (not broken, just complex)

**M-2. View files import services directly (62 occurrences across 30 files)**
- This is conventionally fine in MVVM-with-services (e.g. for one-shot service calls like `ImagePickerService.pick()`), but at this volume it suggests viewmodels are too thin. Spot-checked offenders:
  - `lib/views/recipe_detail_view.dart` imports 5 services
  - `lib/views/personal_tags/personal_tag_dialogs.dart` imports 5 services
  - `lib/views/mina_recept_view.dart` imports 5 services
- A view importing 5 services is a smell that the corresponding ViewModel is missing facade methods.
- Severity: **Medium** (architectural drift, not violation)

**M-3. Two views import repositories directly (skipping ViewModel layer)**
- `lib/views/social/friends_list/feed_tab.dart:14` — `import 'package:butlery/repositories/interfaces/recipe_repository.dart';`
- `lib/views/social/shared_with_me/shared_content_actions.dart` — same pattern (per grep)
- The interface-only imports are the lesser sin (it's the *interface*, not the concrete repo), but views should still go through ViewModels.
- Severity: **Medium**

### LOW

**L-1. 33 documented "intentionally large" files vs 132 actual** — see Dimension 2 below. Architectural impact is layering: each unaccounted >500-line file represents either a missed facade opportunity or undocumented growth.

---

## Dimension 2 — File Size & Complexity (8/15)

This dimension takes the largest hit. **132 files exceed 500 lines; only 33 are documented in `docs/architecture/ACCEPTED_LARGE_FILES.md` as intentional.** The accepted list was last updated 2026-04-25, only 7 days before this audit, and already claims "133 files currently >500 lines... documented below." But the table only enumerates ~120 entries and the doc footer says "133 files" — there's an internal counting drift even in the accepted-files doc itself.

### HIGH

**H-4. ACCEPTED_LARGE_FILES.md is internally inconsistent**
- `docs/architecture/ACCEPTED_LARGE_FILES.md:11` claims "133 files currently >500 lines"
- Pre-analysis count: 132 hand-written files >500 lines (`docs/analysis/runs/2026-05-codex/_pre-analysis/files-over-500-lines.txt`)
- `CLAUDE.md` Code Style section claims **33 files** (the rule that triggers all reviewer guidance)
- Three different numbers in three places — the rule is no longer enforceable as written.
- Defer deep audit to **prompt 12**.
- Remediation here: nothing — flag for prompt 12.
- Severity: **High** (norm erosion)

**H-5. Files near or over the 1,000-line limit**
- `lib/models/recipe_unified.dart` — **1,424 lines** (accepted at 1,257 in ACCEPTED list — has grown +167)
- `lib/main.dart` — **1,250 lines** (accepted at 954 — has grown +296, +31%)
- `lib/viewmodels/recipe_form/recipe_image_manager.dart` — **1,246 lines** (accepted at 1,343 — has shrunk, OK)
- `lib/repositories/firebase/firebase_recipe_repository.dart` — **1,092 lines** (accepted at 931 — has grown +161)
- `lib/services/unified/modules/personal_recipe_module.dart` — **1,023 lines** (accepted at 1,023 — stable)
- `lib/services/unified/unified_recipe_service.dart` — **995 lines** (accepted at 966 — close to 1k)
- Severity: **High** for `main.dart` (entry point, 31% bloat), **Medium** for the rest.

### MEDIUM

**M-4. Top size growers vs ACCEPTED_LARGE_FILES.md baselines**
| File | Accepted | Actual | Δ |
|---|---|---|---|
| `lib/main.dart` | 954 | 1,250 | +296 |
| `lib/models/recipe_unified.dart` | 1,257 | 1,424 | +167 |
| `lib/repositories/firebase/firebase_recipe_repository.dart` | 931 | 1,092 | +161 |
| `lib/views/mina_recept_view.dart` | 687 | 996 | +309 (+45%) |
| `lib/views/skriv_sjalv_recept_view.dart` | 816 | 873 | +57 |
| `lib/views/recipe_detail_view.dart` | 777 | 835 | +58 |
| `lib/widgets/menu/calendar_weekly_menu_widget.dart` | not in accepted | 760 | undocumented |
| `lib/widgets/recipe/recipe_card.dart` | 674 | 754 | +80 |

`mina_recept_view.dart` (+45%) is the worst offender; the doc says "Main recipe list screen" with no decomposition note. **Remediation:** schedule recipe-list-view decomposition (likely 2-3 days). Add a CI gate to fail any commit that grows an accepted file by >10% without updating the doc.

### LOW

**L-2. ~99 files >500 lines that aren't in the accepted list**
- These need an audit pass: either add to ACCEPTED_LARGE_FILES.md with a documented reason, or flag for refactoring. The pre-analysis raw file (`files-over-500-lines.txt`) lists every one.
- Effort: 1-2 days for the audit + facade-pattern refactors for clear duplications.

---

## Dimension 3 — Deduplication & Infrastructure (12/15)

### HIGH

**H-6. BaseService adoption denominator is wrong in CLAUDE.md context**
- Documented: 96% of ~70 services
- Reality: 72 `extends BaseService` occurrences across 88 service files = **82%**
- 16 services don't extend BaseService. Spot-check: e.g. `lib/services/auth_service.dart` — needs verification but file pattern suggests AuthService directly extends framework class.
- Remediation: audit the 16 holdouts; some are legitimate (interfaces, NoOp adapters) but the count needs to match reality. **Defer denominator reconciliation to prompt 12** (doc drift).
- Severity: **High** (the rule "BaseService is mandatory" doesn't match 18% of services)

### MEDIUM

**M-5. Test infrastructure has hardcoded `Future.delayed` "garbage collection" pauses**
- `test/infrastructure/di/test_service_locator.dart:153` — `await Future.delayed(Duration(milliseconds: 5));` "Small delay for garbage collection"
- `test/infrastructure/mocks/firestore_singleton.dart:264` — `await Future.delayed(Duration(milliseconds: 10));` "Small delay to allow garbage collection"
- These are smell-tier — Dart GC can't be flushed by `Future.delayed`. They paper over a real synchronization gap. See **C-2** below.
- Remediation: replace with explicit lifecycle hooks (e.g. await stream cancellation, await disposal completers).
- Severity: **Medium**

**M-6. `FakeFirebaseFirestore` singleton has hardcoded operation cap that triggers unannounced resets**
- `test/infrastructure/mocks/firestore_singleton.dart:18-19` — `_maxOperationsBeforeReset = 100`
- Lines 38-44: every 100 reads/writes the singleton silently destroys and recreates itself, including in the middle of a test. Any test holding a reference to the previous instance gets a stale handle. This pattern is at minimum confusing; at worst it's a non-deterministic test failure source.
- Severity: **Medium** (test flakiness vector)

**M-7. Notification batch handling — sibling `_consentHandlerInProgress` re-entry guard**
- `lib/services/notifications/notification_service.dart:641` — boolean guard for re-entry
- This is a manually-implemented mutex. The codebase has `RetryPolicy`/`CircuitBreaker` infrastructure; consider using a `Lock` from `package:synchronized` (likely already a transitive dep) or a `Completer`-based queue.
- Severity: **Low-Medium**

### LOW

**L-3. Empty catch blocks: 11 across 7 files**
- Acceptable in some cleanup paths (stream cancellation, retry secondary errors).
- Notable: `lib/viewmodels/cooking_mode_viewmodel.dart` (2), `lib/viewmodels/recipe_list_viewmodel.dart` (2), `lib/services/cook_snap_service.dart` (1), `lib/services/parsing/tiers/llm_tier.dart` (1).
- Each should have a one-line comment explaining the intentional swallow.
- Severity: **Low**

---

## Dimension 4 — Error Handling & Resilience (11/15)

### CRITICAL

**C-2. Test infrastructure hangs ~10 minutes per test in `infrastructure_integration_test.dart`**
- File: `test/views/helpers/infrastructure_integration_test.dart` (4 testWidgets)
- Root cause analysis (read-only investigation):
  - Each test calls `setupViewTestEnvironment()` and `teardownViewTestEnvironment()` (`view_test_helpers.dart:73, 98`)
  - Setup chain: `BaseUnitTest.setupUnit()` → `TestServiceLocator.initialize()` → registers ~50 mocks via `_registerRepositories/_registerServices/_registerViewModels/_registerUtilities` (`test_service_locator.dart:103-106`)
  - Teardown: `TestServiceLocator.reset()` → `ServiceLocator._getIt.reset(dispose: true)` → `Future.delayed(5ms)` → `FirestoreSingleton.hardReset()` → `_cancelAllStreams()` → `_forceRecreate()` → `Future.delayed(10ms)` (`test_service_locator.dart:138-170`, `firestore_singleton.dart:244-267`)
  - **The hang is most likely in `_getIt.reset(dispose: true)`**: `dispose: true` calls `dispose()` on every singleton, including services that never finish disposing if their stream subscriptions weren't cancelled first. With 50+ registered mocks (some of which subscribe to fakes that hold timers), one un-cancelled subscription can stall the dispose pipeline indefinitely.
  - The 10-minute timeout is the Flutter test timeout (default), not an internal one — i.e. the dispose chain is genuinely never completing.
- Why this is critical: the file is in CI's coverage path. Per the prompt context: "the full coverage run [is] aborted." This means test/coverage validation is currently broken end-to-end.
- Remediation: 4h to triage. Either (a) skip the file pending a real fix, (b) replace `dispose: true` with explicit per-service cleanup, or (c) audit the registered mocks to find the one that hangs on dispose.
- Severity: **Critical** (CI is broken)

### HIGH

**H-7. 1,617 try-catch blocks across 361 files vs 23 TODO/FIXME**
- Ratio is healthy (good error-handling discipline)
- But the *quality* of these catch blocks is uneven — empty catches (L-3) and "log-only" catches need a sweep. The orchestrator delegated to AsyncOperationMixin/ErrorHandlingMixin but adoption metrics aren't tracked.
- Defer detailed audit to prompt 03 if it covers test/error coverage strategy; otherwise file separately.
- Severity: **High** (it's hard to know where the 1,617 blocks fall on the actionable→silent spectrum)

### MEDIUM

**M-8. `notification_service._handleConsentChange` swallows all errors silently into `AppLogger.error`**
- `lib/services/notifications/notification_service.dart:643-663` — outer `try/catch (e)` only logs.
- If consent revocation fails to clear the SecureStorage token (BUT-754 cleanup), the user remains subscribed despite revoked consent. Should propagate or retry, not just log.
- Severity: **Medium** (privacy/GDPR edge case — defer impact to prompt 02/09)

---

## Dimension 5 — Documentation Health (7/10)

Most points lost here are owned by **prompt 12**, but flagging for completeness:

### HIGH (defer detail to prompt 12)

**H-8. CLAUDE.md "33 files >500 lines" rule is broken**
- See Dimension 2. This is the single most impactful doc-vs-code drift in the repo.
- Severity: **High** (the rule no longer governs behavior)

### MEDIUM

**M-9. TODOs are well-tracked but cluster in security pinning**
- 9 of 23 TODOs are `BUT-427-ops` cert-pin fingerprint placeholders in `lib/services/security/cert_pin_config.dart:39-69`
- These are blocking real cert pinning in production — i.e. SSL pinning is currently disabled by design until rotation is set up.
- Defer detail to prompt 02 (security).
- Severity: **Medium**

### LOW

**L-4. CLAUDE.md sub-files (`lib/services/CLAUDE.md`, `lib/views/CLAUDE.md`, `lib/viewmodels/CLAUDE.md`) are well-maintained**
- Read during this audit (system reminders). They give clear, current rules. This is a *strength* — note for the synthesis report.

**L-5. Doc comment count not measured**
- Out of scope without DCM running. Defer.

---

## Dimension 6 — Code Readability (8/10)

Strong overall. Specific positives:

- **Zero `print()` calls** in production code (the 25 grep hits are all in `///` doc comments)
- **Zero `.withOpacity(`** — fully migrated to `.withValues(alpha:)`
- Naming convention adherence is strong (no single-letter vars in spot-checks)
- Service/ViewModel/View naming pattern is consistent

### MEDIUM

**M-10. Two services named like *modules* in the View layer (`feed_tab.dart` extension)**
- `lib/views/social/friends_list/feed_tab.dart:18` — `class FeedTab` with only `static Widget build(...)`. This is a "namespace function" disguised as a class. Should be a top-level function `Widget buildFeedTab(...)`, or a proper StatelessWidget.
- Pattern recurs in a few view helpers — minor smell.
- Severity: **Medium**

### LOW

**L-6. One `debugPrint(` in production code**
- `lib/utils/recipe_scraper.dart:1` (per grep — likely a leftover from import-debugging)
- Should be `AppLogger.debug(...)` per the project's logger convention.
- Severity: **Low** (1 call, but the rule is "no `print`/`debugPrint` outside `kDebugMode`")

---

## Dimension 7 — Production Readiness (7/10)

### HIGH

**H-9. Cert pinning configured but not active in production** — see M-9 (defer to prompt 02 detail).

### MEDIUM

**M-11. `main.dart` directly invokes `FirebaseFirestore.instance.terminate()` and `clearPersistence()` in bootstrap**
- `lib/main.dart:194-196` — bootstrap fallback path. Acceptable for an entry point but the lack of abstraction means tests can't mock the bootstrap path without booting Firebase.
- Severity: **Medium**

### LOW

**L-7. `kDebugMode`-gated `debugPrint` in test infrastructure**
- `test/infrastructure/di/test_service_locator.dart:111-114` — the production `kDebugMode` gate is fine in tests; it's just noise during test runs. Optional cleanup.
- Severity: **Low**

---

## Dimension 8 — Deprecated API & Tech Debt (3/5)

Strong on this dimension overall:

- **0** `.withOpacity(` occurrences (fully migrated)
- **0** `setState()` in ViewModels (the 2 known-bad references in the orchestrator are `resetState()`, false positives)
- TODO count is low (23) and well-attributed (BUT-ticket prefixes)

Points lost: see C-1 (potential compile error), and the file-size accumulation in Dimension 2.

---

## Top 10 Issues (Priority-Ranked)

| # | Severity | Title | Location | Effort | Category |
|---|---|---|---|---|---|
| 1 | CRITICAL | `flutter analyze` reports `ConsentPurpose` undefined | `lib/services/notifications/notification_service.dart:648` | 0.5h verify, 2h if real | Build/Compile |
| 2 | CRITICAL | Test infrastructure hangs CI for ~10min, full coverage run aborted | `test/views/helpers/infrastructure_integration_test.dart` (root cause in `test_service_locator.dart:149` `dispose: true`) | 4h | CI/Testing |
| 3 | HIGH | `FirebaseAuth.instance` called in view layer | `lib/views/onboarding/onboarding_age_gate_blocked_view.dart:22` | 1h | Architecture |
| 4 | HIGH | ViewModel imports `cloud_firestore` SDK directly | `lib/viewmodels/menu/menu_storage.dart:3` | 1-2h | Architecture |
| 5 | HIGH | 29 files use direct Firebase instances (doc claims 17) — 5-6 service-tier offenders | `lib/services/notifications/*`, `lib/services/analytics/winback_attribution_service.dart`, `lib/main.dart` | 1-2 days | Architecture |
| 6 | HIGH | ACCEPTED_LARGE_FILES.md is internally inconsistent (33 vs 132 vs 133) | `docs/architecture/ACCEPTED_LARGE_FILES.md` + `CLAUDE.md` | defer to prompt 12 | Documentation |
| 7 | HIGH | `main.dart` grew from 954 → 1,250 lines (+31%) | `lib/main.dart` | 1 day decomposition | File Size |
| 8 | HIGH | BaseService adoption is 82% (72/88), not 96% as documented | service files in `lib/services/` | defer to prompt 12 | Infrastructure |
| 9 | MEDIUM | View layer imports services directly at high volume (62 occurrences/30 files) | `lib/views/recipe_detail_view.dart`, `lib/views/mina_recept_view.dart`, etc. | 2-3 days facade-fattening | Architecture |
| 10 | MEDIUM | `mina_recept_view.dart` grew 687 → 996 lines (+45%) without doc update | `lib/views/mina_recept_view.dart` | 1-2 days decomposition | File Size |

---

## Metrics Snapshot

| Metric | Current | Gold standard |
|---|---|---|
| Files >500 lines (non-generated) | 132 | 33 (per CLAUDE.md) |
| Files >1000 lines (non-generated) | 4 | as low as practical |
| Direct Firebase instance usage outside `lib/repositories` and `lib/core/di` | ~6 | 0 |
| `setState()` in ViewModels | 0 | 0 |
| `.withOpacity(` | 0 | 0 |
| `print()` in `lib/` | 0 | 0 |
| `debugPrint(` in `lib/` | 1 | 0 |
| Empty catch blocks | 11 | 0 (or all commented) |
| TODO/FIXME comments | 23 | low + ticketed (current is good) |
| Compile errors from `flutter analyze` | 1 (status uncertain) | 0 |
| BaseService adoption (services/) | 72/88 = 82% | ~95%+ |
| BaseFirebaseRepository adoption | 35/45 = 78% | reconciled, accepted |

---

## Phase 2 Preparation

**Group 1 — must verify before any other work (0.5–4h):**
- C-1 (re-run `flutter analyze`)
- C-2 (root-cause the test infra hang)

**Group 2 — Architecture cleanup (3-5 days):**
- H-1, H-2, H-3 — pull direct Firebase calls out of the view + viewmodel + non-repository service layers

**Group 3 — File size discipline (4-6 days):**
- H-4 (reconcile docs — defer to prompt 12)
- H-5, H-7, M-4, L-2 (decompose `main.dart`, `mina_recept_view.dart`; audit the 99 undocumented >500-line files)

**Group 4 — Infrastructure adoption (2-3 days):**
- H-8 (BaseService denominator audit — coordinate with prompt 12)
- M-5, M-6 (test infra cleanup)

**Group 5 — Polish (1-2 days):**
- L-3 (empty catch blocks — comment or replace)
- L-6 (one `debugPrint`)
- M-8 (notification consent error propagation — coordinate with prompt 02)

**Total estimated remediation effort:** ~12-18 days for everything CRITICAL+HIGH+MEDIUM. CRITICAL alone is 0.5-4h.

---

## What this means in plain language

- Two things are urgent: (1) check whether the app currently *compiles* (one tool report says no, but the file was edited 3 minutes after the report — easy to verify), and (2) one test file hangs CI for 10 minutes per case, which is why test coverage runs are aborted right now.
- Beyond those two: the app is in better shape than its own documentation suggests on most quality axes — but the file-size discipline rule that says "we have 33 large files" is now off by a factor of four (132 actual). The rule no longer reflects reality, so people stopped enforcing it.
- A small handful of files (5-6 services, 1 view, 1 viewmodel) call Firebase directly when they should go through the repository layer. Each of these makes the app slightly harder to test.
- Risk of the proposed fixes is low — most are boilerplate-level extractions and the changes are well-isolated. Nothing here will break user-visible behavior.
