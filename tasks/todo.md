# Sprint Backlog

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

## Sprint: iter-108 — Tier A bug fix (subscription lifecycle) — 2026-05-30 (Sat)

Focused single-ticket sprint (context already large from iter-107; quality over count).

### Agent A — tagging subscription lifecycle

- [x] **A1. BUT-1170: AutoPersonalTagDisplay static subscription goes stale across logout/login** `[Tier A]`
  - **Step 0:** FITS. Confirmed the bug by reading the code. `_AutoPersonalTagDisplayState._mutationSubscription`
    (static) binds to the CURRENT `PersonalTagService`/`PersonalTagCrudService` `tagsMutated` controller.
    On logout, `PersonalTagCrudService` is fully disposed (DI `dispose: (s) => s.dispose()` → `onDispose` →
    `_tagsMutatedController.close()`), so the static sub gets `onDone` (currently unhandled). On login,
    `pushUserScope` → `_initializeUserScopedServices()` → fresh `PersonalTagService.onInitialize()`. New
    mutations fire on the new controller → nothing listens → chips stop updating until all cards unmount.
  - **Files touched:**
    - `lib/services/tagging/personal_tag_service.dart` — add static `instanceReady` broadcast signal
      (survives the GetIt instance-swap; instance streams die with the old controller), fire it in
      `onInitialize()`.
    - `lib/widgets/tagging/personal_tag_selector.dart` — handle `onDone` (drop stale sub on logout) +
      subscribe to `PersonalTagService.instanceReady` (re-bind to fresh instance on login, refetch, notify).
      Refactor binding into a static helper shared by `_subscribe()` and the re-bind path.
    - `test/widget/widgets/tagging/auto_personal_tag_display_rebind_test.dart` — new test proving the
      logout→login re-bind without unmount.
  - **Blast radius:** widget shown on every tagged recipe card + the shared PersonalTagService facade.
    Change is additive (new static signal) + a self-contained widget lifecycle fix. No public API removed.
    The `instanceReady` static controller is app-lifetime (never closed) — legitimate global lifecycle
    signal, same pattern as the existing static `_mutationSubscription`.
  - **Rollback:** revert the two lib edits; the static signal is unused if the widget doesn't subscribe.
  - **Optional acceptance bullet 3** (PersonalTagService DI → full `dispose()` instead of `resetForLogout()`):
    deferring — PersonalTagService holds no controller of its own (crud does, already fully disposed), so
    full-dispose vs resetForLogout is near-identical. Skipping keeps the diff focused; noted in commit.

### Post-Sprint Steps
- [x] `dart analyze` clean on all 3 changed files
- [x] New widget test green (logout→login re-bind + post-login mutation + privacy clear) + 38 existing service tests green
- [x] code-reviewer + testing-specialist — both CLEAN; applied 2 nits (dart:async import order, explicit privacy assert); filed BUT-1172 (LOW) for 2 edge-case test gaps
- [x] Commit `9159fbce9` (specific files staged), pushed to main
- [x] BUT-1170 → Done (Tier A, test-proven). Follow-up BUT-1172 (LOW) filed.

### Carried high-value (next fresh-context iterations — NOT this sprint)
- **BUT-1155** (High, Bug) — CI views shard broken: 200+ failures + 10min hang. Whole-sprint Tier C job;
  deserves fresh context for the failure triage + hang root-cause + matrix restore.
- **BUT-1044** (tooling) — custom_lint for un-disposed StreamSubscription. Real analyzer-plugin setup work.

---

## Prior sprints (shipped)
iter-104 `b80aac380` (BUT-1055+1066), iter-105 closed BUT-969 premise-gone, iter-106 `c03789f69`
(BUT-975 Tier B → In Review), autonomy-tier policy `a3c49bd67`, iter-107 `d881cbf27` (BUT-1154 1/4 —
photo_import VM heirloom mixin extraction, +5 tests, BUT-1171 follow-up filed). Durable record: Linear + git.

> Tree hygiene: `docs/cleanup/deletable-files-report.md` is an untracked parallel-session/hook artifact —
> not mine, leave it. `stash@{0}` (sprint3-salvageable) must stay preserved. Do NOT `git add -A` blindly.
