# Sprint Backlog

## Sprint: iter-110 — Tier A quality cluster (test-quality + error-surfacing) — 2026-06-01 (Mon)

Fresh-context iteration. Clean Tier-A backend backlog is largely drained (iter-103→109), so this
batch is the genuinely-clean remainder: two test-quality follow-ups + one small service-layer
error-surfacing fix. All three are contained, test-proven → close to **Done**.

### Agent A — test quality (test-gap follow-ups)
- [x] **A1. BUT-1172: edge-case tests for AutoPersonalTagDisplay instanceReady re-bind** `[Tier A]`
  - Step 0: FITS. Rebind test exists (`auto_personal_tag_display_rebind_test.dart`). Add 2 flagged edge cases:
    (1) re-bind when NO card mounted at login then card mounts after; (2) last-subscriber teardown of
    `_instanceReadySubscription` — instanceReady event after last unmount must not throw/resurrect binding.
  - File: `test/widget/widgets/tagging/auto_personal_tag_display_rebind_test.dart` (+ read `personal_tag_selector.dart`).
- [x] **A2. BUT-1171: rewrite 3 leaky photo-import VM tests** `[Tier A]`
  - Step 0: REVISED. Ran the suite — actual failures were NOT the ticket's named tests (480/689/757) but the
    3 `saveImportedRecipe` tests (657/717/737). Root cause: the production `ServiceLocator` (application_provider)
    was never bridged, so `saveImportedRecipe`'s `ServiceLocator.get<HeirloomBridge>()` threw → `executeAsyncVoid`
    (no errorPrefix) swallowed it into the generic 'Ett oväntat fel uppstod' → save returned false. Fix:
    (1) bridge `app_provider.ServiceLocator.initialize(DIContainer())` in setUp (DIContainer reads GetIt.instance
    where setUp already registers HeirloomBridge); (2) eliminate the shadow-field seam — added `@visibleForTesting`
    `setOcrTextForTesting`/`setImageBytesForTesting` on the VM so the double drives the REAL `_ocrText`/`_imageBytes`
    the pipeline reads, dropping the getter overrides. Suite green 31/31, no assertions weakened.
  - Files: `test/unit/viewmodels/photo_import_viewmodel_test.dart`, `lib/viewmodels/photo_import_viewmodel.dart`.

### Agent B — sharing error-surfacing
- [x] **B1. BUT-1056: surface RecipeSharingManager.shareRecipe cap-rejection to UI** `[Tier A]`
  - Step 0: FITS. Cap-guard at `recipe_sharing_manager.dart:131-138` returns bare `null`. Implement option 3
    (recommended): optional `void Function(String)? onError` callback in constructor, invoked with the localized
    `errorShareCapReached` on cap-rejection. Mirror `SocialRecipeSharingService` pattern. Wire through the caller.
  - Files: `lib/services/unified/operations/modules/recipe_sharing_manager.dart` + caller in unified ops + test
    `recipe_sharing_manager_test.dart`.

### Needs you (Tier D — flagged, not worked)
- (none this sprint)

### Post-Sprint Steps
- [ ] `dart analyze --fatal-infos` clean on changed files
- [ ] Relevant unit/widget tests green
- [ ] code-reviewer + testing-specialist (+ firebase-backend-security for B1) markers
- [ ] Commit, push to main
- [ ] Linear: all three → Done (Tier A, test-proven)

---

## Sprint: iter-109 — Tier A bounded wave (CPI→LoadingIndicator) — 2026-05-30 (Sat)

Bounded mechanical wave (context large from iter-107/108; picked a safe guarded sweep).

### Agent A — CPI→LoadingIndicator migration (BUT-1168 wave)

- [x] **A1. BUT-1168 wave: migrate the social cluster (5 files)** `[Tier A]`
  - Step 0: FITS. Mechanical CPI→LoadingIndicator migration, guarded by the arch-test in
    `test/architecture/architecture_test.dart`. Migrated 5 fully-indeterminate files + removed
    them from the allowlist: `social_components/{social_avatar_components, social_builder_components,
    social_group_components}.dart`, `social/{invitation_target_states, social_builders}.dart`.
  - `social_builders.dart`: passed `size: AppDimensions.iconSizeS` so the wrapper's default 24px
    doesn't overflow the existing fixed 16px SizedBox (behavior-preserving).
  - **Skipped `invitation_states.dart`** — it has DETERMINATE progress bars (`CPI(value: progress)`)
    that LoadingIndicator (indeterminate) can't express. Stays allowlisted → filed **BUT-1173** (LOW)
    for a determinate variant. Updated the allowlist comment to say why it stays.
  - Verify: analyze clean on all 5 + arch test; arch CPI guard GREEN with the 5 de-allowlisted
    (proves they're actually clean). BUT-1168 stays In Progress (long-tail, ~24 files remain).

### Post-Sprint Steps
- [x] analyze clean + arch CPI guard green
- [x] code-reviewer + testing-specialist — both CLEAN (no test breaks)
- [x] Commit `0181823fa` (specific files), pushed to main
- [x] BUT-1168 progress comment (5 more migrated, stays In Progress); BUT-1173 filed

### Carried high-value (fresh-context iterations)
- **BUT-1155** (High, Bug) — broken CI views shard (200+ failures + hang). Whole-sprint Tier C.
- **BUT-1044** (tooling) — custom_lint for un-disposed StreamSubscription.

---

## Prior sprints (shipped)
iter-104 `b80aac380` (BUT-1055+1066), iter-105 closed BUT-969 premise-gone, iter-106 `c03789f69`
(BUT-975 Tier B → In Review), autonomy-tier policy `a3c49bd67`, iter-107 `d881cbf27` (BUT-1154 1/4),
iter-108 `9159fbce9` (BUT-1170 + BUT-1172 follow-up filed), iter-109 `0181823fa` (BUT-1168 wave,
BUT-1173 filed). Durable record: Linear + git.

> Tree hygiene: `docs/cleanup/deletable-files-report.md` is an untracked parallel-session/hook artifact —
> not mine, leave it. `stash@{0}` (sprint3-salvageable) must stay preserved. Do NOT `git add -A` blindly.
