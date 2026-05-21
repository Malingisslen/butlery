# Sprint Backlog

## Sprint: wave-5 follow-ups + cooking-mode analytics + ops runbooks — 2026-05-21 (Th) wave 6

Theme: 4 tickets after Step 0 (1 obsolete close + 1 test fix + 2 scope-split implementations).

### Agent A: testing-specialist — wave-5 test fix (1)
- [x] **A1. BUT-876** — `test/unit/services/parsing/model_manager_integrity_test.dart` "latest version absent from hash registry" tests (NerModelManager + LineClassifierModelManager) assert that unregistered versions abort without disk write, but production `RemoteModelLoader.verifyModelDownload` (line 107-114) returns `true` for unregistered versions per documented **transitional rollout** behavior in `_expected_model_hashes.dart:23-27`. Rewrite both tests (one per manager group) to assert the documented soft-allow contract: `ensureModelAvailable()` returns non-null + disk has committed files + a fail-loud log signal fires. File a Linear follow-up for fail-close hardening once registries are complete.

### Agent B: flutter-developer — cooking-mode analytics (1)
- [x] **B1. BUT-802 (HIGH-PA4 only)** — wire 4 cooking-mode analytics events into `lib/viewmodels/cooking_mode_viewmodel.dart`. Lifecycle map:
  - `onEnter()` → `cooking_session_started { recipe_id, session_id, started_at }`
  - `nextStep()` / `previousStep()` / `goToStep()` → `cooking_step_advanced { recipe_id, from_step, to_step, session_id }`
  - `onExit()` when `_currentStepIndex == totalSteps - 1` → `cooking_session_completed { recipe_id, session_id, duration_sec, steps_viewed }`
  - `onExit()` when not at last step → `cooking_session_abandoned { recipe_id, session_id, last_step, duration_sec }`
  - Add `sessionId` (Uuid.v4) generated on first `onEnter()`, retained in VM state.
  - Add 4 constants to `lib/services/analytics/analytics_events.dart` under a new `--- Cooking mode ---` section.
  - Resolve tracker via `ServiceLocator.tryGet<SocialEventsTracker>()`'s sibling (likely `SystemEventsTracker` or a new method). If no tracker has cooking events, add 4 methods to a relevant existing tracker (avoid creating a new class — `RecipeEventsTracker` is the closest fit).
  - File a Linear follow-up for **HIGH-PA10** (9 social-graph methods + DM tracking) — that scope is bounded but separate.

### Agent C: ops-docs — runbooks (1)
- [x] **C1. BUT-452 (first 3 docs only)** — create:
  - `docs/operations/DISASTER_RECOVERY.md` — PITR restore steps (gcloud commands), scheduled-backup restore, Auth user export/import flow. Mark `Restore drill: NOT YET PERFORMED` with date placeholder.
  - `docs/operations/DEPLOY_ROLLBACK.md` — checklist procedures for functions / rules / hosting rollback (`firebase functions:rollback`, `firebase deploy --only firestore:rules` against a prior commit, hosting channel promotion).
  - `docs/operations/INCIDENTS.md` — triage checklist (severity buckets, first-15min decisions) + post-mortem template.
  - File follow-ups: SLO_DEFINITIONS.md (HIGH-INFRA14), region drill execution (CRIT-INFRA1), retention/residency reconciliation (HIGH-DOC1/8/9/12) — each can ship independently.

### Step 0 — obsolete tickets to close (1)
- [~] **BUT-874** — premise gone. `dart analyze --fatal-infos` now reports clean ("No issues found!"). The l10n keys `ocrImageRejected` and `ocrImageResolutionTooLow` are present in `lib/l10n/app_localizations.dart`, `app_localizations_en.dart`, and `app_localizations_sv.dart` (verified via grep). The wave-5 commit `b66f5892f` shipped with regenerated files. Close as resolved by wave-5.

### Post-Sprint Steps
- [ ] `dart analyze --fatal-infos` clean
- [ ] Tier-2 agent reviews — code-reviewer (.dart), testing-specialist (lib/*.dart) — markers written before commit
- [ ] File follow-ups in Linear (mandatory before commit): BUT-802 HIGH-PA10 split, BUT-452 sub-tasks (SLO doc, region drill, retention reconciliation), BUT-876 fail-close hardening
- [ ] Commit (inline) + push direct to main
- [ ] Close Linear tickets BUT-876/802/452 (done) + BUT-874 (obsolete)
- [ ] CI watcher

---

## Archived prior sprint (commit b66f5892f)

wave-5 — image-quality OCR gate + test-gap closures + adoption metric — 2026-05-19 (Tu) wave 5 — BUT-660/872/865/866/873 shipped. BUT-479/843/858 closed as premise-gone. BUT-840 deferred.

## Archived two-sprints-ago (commit 90d88cfca / b115d7519)

wave-3 follow-ups + UI consolidation continuation — BUT-868/869/870/871/867/776/864.

## Archived three-sprints-ago (commit 8e54f68f2)

UI consolidation + CI + model integrity tests — BUT-861/579/801/841/825/823.
