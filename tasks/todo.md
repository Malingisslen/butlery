# Sprint Backlog

## Sprint: release polish + ops doc + Linear reconciliation — 2026-05-05 (L)

Theme: 2 small ship-able items + 1 reconciliation pass + 1 ticket rescope. After sprint K shipped 7 tickets, the picks here are deliberately light — most of the remaining backlog is in declared "own sprint" clusters (auth/security, deploy pipeline, repo discipline, Dart-SDK bump, large-file decompose, button system, A/B infra). This sprint takes the unblocked one-off polish items.

**In Progress carry-overs (NOT in this sprint, NOT shipped):**
- BUT-442 — repo migrations (own focused sprint, mid-flight)
- BUT-760 — App Check enforcement; awaiting Firebase Console flip

**Linear-state cleanup (E1–E2):** BUT-738 and BUT-724 shipped in commit `25ec5b025` but Linear still shows them as "In Progress". Move to Done.

**Step 0 verification — done:**
- **BUT-715** fits — `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml` has only background+foreground; no `<monochrome>` layer. The existing `drawable/ic_launcher_foreground.xml` is a vector with named paths (fork, knife, plate-circle, inner-plate). Generating a monochrome variant is mechanical — same paths, force `#FFFFFF`, drop the alpha variants (Android tints the monochrome layer from the wallpaper, so reducing visual richness is preferred).
- **BUT-493** fits — `docs/operations/RELEASE_POLICY.md` does not exist. Pure doc add. Cite related tickets BUT-420 (Fastlane), BUT-449 (web error tracking) as expected dependencies for the policy to become operational.
- **BUT-702 PLAN STALE** — recipe delete **already has undo wired** at `lib/views/mina_recept_view.dart:565-577` via `SnackBarUtils.showSuccessWithAction(context, recipeDeleted, actionLabel: commonUndo, onAction: undoDeleteById, duration: 5s)`. The ticket's "wire to recipe delete first" prescription is stale. Rescope the ticket body to focus on the remaining surfaces (group leave/delete, friend remove, shopping-list clear) and leave in Backlog. No code in this sprint.

### Reconciliation: Linear ticket states (no code)

- [ ] **E1. BUT-738 → Done** — shipped in commit `25ec5b025`. Comment with commit SHA, transition state to Done.
- [ ] **E2. BUT-724 → Done** — shipped in commit `25ec5b025`. Comment with commit SHA, transition state to Done.

### Agent A: Release polish — Android monochrome icon

Specialists: none required (no `.dart` change, only Android resource files).

- [ ] **A1. BUT-715 — Add adaptive icon monochrome layer for themed icons (Android 13+)**
  - **New file** `android/app/src/main/res/drawable/ic_launcher_monochrome.xml`:
    - Same vector boilerplate as `ic_launcher_foreground.xml` (108×108 viewport, centered 72dp safe zone via `<group translateX="18" translateY="18">`).
    - Same fork + knife + plate-circle + inner-plate paths.
    - Replace all `android:fillColor="#FFFFFF"` (the rule body of all four paths) with `android:fillColor="#FFFFFFFF"` (fully opaque — Android tints from wallpaper).
    - **Drop the `android:fillAlpha` attributes** on plate-circle and inner-plate. The monochrome layer is rendered as a single tinted shape; alpha gradations look muddy under wallpaper tinting. Solid silhouette reads better.
  - **Edit** `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml`:
    - Add `<monochrome android:drawable="@drawable/ic_launcher_monochrome"/>` inside `<adaptive-icon>` (after `<foreground>`).
  - **Verification**: visually inspect that monochrome XML parses (XML well-formed, vector valid). Optional `flutter build apk --debug` smoke check that the resource compiles. No analyzer step (no Dart change).
  - **Out of scope**: regenerating PNG fallbacks for older Android versions — monochrome is API-31+ only and falls back transparently to the existing foreground on older devices.
  - (BUT-715)

### Agent B: Ops documentation

- [ ] **B1. BUT-493 — Document staged rollout / phased release strategy**
  - **New dir** `docs/operations/` (does not exist; create).
  - **New file** `docs/operations/RELEASE_POLICY.md` — sections:
    1. **Purpose** — establish the staged-rollout policy and halt thresholds before BUT-420 lands the Fastlane upload pipeline (which would otherwise default to 100% rollout).
    2. **Per-platform rollout mechanics** — Android (Play Console staged rollout: 1% → 5% → 25% → 50% → 100%), iOS (App Store Connect "Phased Release" toggle: 1% → 2% → 5% → 10% → 20% → 50% → 100% over 7 days), Web (Firebase Hosting channels + manual traffic split, since Hosting has no native staged rollout).
    3. **Halt thresholds** — concrete numbers a release engineer can act on: crash-free sessions <99.5%, Sentry/Crashlytics velocity >2× 7-day baseline, retention drop >5pp at D1.
    4. **Halt + rollback procedures** — step-by-step: pause Play rollout (Play Console UI path), pause iOS phased release (ASC UI path), Web rollback (revert Firebase Hosting deploy via `firebase hosting:rollback`).
    5. **Dependencies / current gaps** — note that automated rollout halt requires BUT-420 (Fastlane integration), BUT-449 (web error tracking), and BUT-492 (Firebase + GCP cost/budget alerts as part of the same observability stack). Until those land, halt is manual via console.
    6. **Review cadence** — re-check thresholds after first 3 staged releases.
  - **Verification**: re-read the file end-to-end; confirm all referenced ticket IDs still exist (grep BUT-420, BUT-449, BUT-492 in Linear). No code; no analyzer step.
  - (BUT-493)

### Linear cleanup (no code, ticket-state only)

- [ ] **C1. BUT-702 — rescope ticket body** — update Linear description to capture that recipe delete already has undo. New body:
  ```
  ## Status update (2026-05-05)

  Recipe-delete undo already shipped — `lib/views/mina_recept_view.dart:565-577` uses `SnackBarUtils.showSuccessWithAction` with a 5-second `commonUndo` action that calls `viewModel.undoDeleteById(id)`. The "wire to recipe delete first" prescription in the original ticket is stale.

  ## Remaining destructive surfaces (none of which currently offer undo)

  - Group leave/delete (`lib/views/group/...` — verify exact path during scoping)
  - Friend remove (social/friends views)
  - Shopping-list clear (shopping-list view)
  - Calendar event delete (if applicable)

  ## Generalization decision

  Two paths:
  1. **Lift** the recipe-delete pattern into a generic `UndoableAction` helper (single SnackBar utility + per-VM `undo<Op>` method convention). Wire each surface.
  2. **Repeat the inline pattern** at each call site. Fast, but drifts.

  Path 1 needs ~30 minutes of design (where does the helper live? `lib/widgets/common/`? `lib/services/ui/`?). Path 2 ships in an afternoon.

  Effort: 4-6h for path 1 (helper + 3-4 surfaces + tests), 2-3h for path 2 (just the wiring).
  ```
  Stay in Backlog.

### Post-Sprint Steps
- [ ] No `dart analyze` needed (no Dart changes this sprint).
- [ ] No unit-test runs needed (no logic changes).
- [ ] No Tier-2 specialist gates trigger (no `*.dart` files touched).
- [ ] Commit: `feat(sprint): release polish + ops doc + Linear cleanup (BUT-715/493/738/724/702)`
- [ ] Push to main; CI watcher; reconcile Linear states (BUT-738/724 → Done; BUT-715/493 → Done; BUT-702 stays Backlog with rescoped body).

### Continued blockers (NOT in scope per memory)
- BUT-415 / BUT-714 / BUT-646 / BUT-731 — store/Play submission deferred (Apple Dev enrollment gated)
- BUT-549 — post-beta (Sign in with Apple lands when social login does)
- BUT-579 — held for button-system sprint
- BUT-444 / BUT-445 — own product-design sprints
- BUT-686 / BUT-660 / BUT-694 — feature-level brainstorming first
- BUT-674 / BUT-721 — own scoped sprints
- BUT-626 — bucket-based A/B infra; own sprint
- BUT-420 / BUT-451 / BUT-452 / BUT-486 — deploy-pipeline / staging cluster; focused infra sprint
- BUT-550 / BUT-536 / BUT-441 — ACCEPTED_LARGE_FILES drift sprint
- BUT-558 — DCM install (own sprint)
- BUT-554 — tracking ticket (blocked on drift_dev upstream)
- BUT-594 — macOS sandbox audit needs hardware-exercise step
- BUT-701 — focus traversal (2-day a11y sprint)
- BUT-479 — cursor-pagination half is non-trivial; needs design ticket
- BUT-435 + BUT-502/503/507/509 — Dart SDK 3.10 bump cluster (one focused sprint)
- BUT-472 — realtime_session_manager stream/timer migration (next perf sprint)
- BUT-455 / BUT-440 / BUT-504 — repository discipline cluster (paired with BUT-442)
- BUT-453 / BUT-454 — auth/session security (own sprint with product-design input)
- BUT-488 — pubspec auto-bump CI workflow (3h, intricate; standalone)
- BUT-704 — i18n @key ARB descriptions (2-day sweep)
- BUT-520 — VM-migration sweep (rescoped sprint I)
- BUT-431 / BUT-530 — main.dart bootstrap split + extraction (rescoped sprint J — only the doc+timeout portions shipped; remaining DI split + ButleryApp extraction live here)
- BUT-581 — `?? ''` migration (rescoped sprint K; sequenced 4-6h effort)
- BUT-610 — offline-mode hardening (multi-day audit)
- BUT-723 — tablet master-detail layouts (multi-day refactor)
- BUT-702 — undo SnackBar generalization (rescoped this sprint; recipe-delete already shipped)
- BUT-734 — split FirebaseUserRepository (per ticket: defer until file ≥700 lines; currently 610)
- BUT-710 / BUT-706 / BUT-711 / BUT-715 (Android) — platform-polish cluster (BUT-715 lands this sprint)
- All `idea`-labeled monetization scaffolding — post-beta

### What this means in plain language
- **Two reconciliation closures**: the previous sprint shipped a refactor and a web-scrollbar tweak, but Linear still has them as "in progress." We're just clicking the "done" button (with a comment linking to the commit). No code change.
- **One Android polish item**: phones running Android 13+ can show app icons that pick up the user's wallpaper colors (the "themed icons" feature). Today Butlery's icon doesn't participate in that — it just shows the colorful version. This sprint adds a stripped-down "monochrome" version that lets the OS tint it. Pure asset addition.
- **One ops document**: when the future deploy pipeline ships, releases would otherwise go to 100% of users immediately. We write a short policy now (1% → 5% → 25% → 100%, plus when to hit "halt" if crashes spike) so the future self has a checklist. No code; just a markdown file.
- **One ticket cleanup**: an "undo when deleting" ticket assumed recipe-delete had no undo, but it actually does (we wired it earlier without closing the ticket). Rescoping the ticket so the next picker sees the real remaining work (undo on group/friend/shopping-list deletes), not duplicate work.
- **Risk**: very low. No `.dart` changes. No tests to run. The Android XML can be reverted in seconds if it breaks an icon variant. The ops doc is text-only.

---

## Archived prior sprint (completed in commit 25ec5b025)

Tech-debt sweep + dep watch + web polish — 2026-05-05 (K) — shipped BUT-526/567/562/564/578/724/738 + rescoped BUT-581.

## Archived sprint before (completed in commits 245b71478 + a5288014f)

Dep hygiene + PWA polish + Linear cleanup — 2026-05-05 (J) — shipped BUT-500/519/524/718 + closed BUT-437 + rescoped BUT-431/530. Plus follow-up CI fix allowlisting `firestore_bootstrap.dart` in the architecture test.

## Archived sprint before (completed in commit 1e347b424)

Backend hygiene + auth security micro-hardening — 2026-05-04 (I) — shipped BUT-446/506/465/490 + closed BUT-716 + rescoped BUT-520. See git log for full task breakdown.

## Archived sprint before (completed in commit 44b6f4792)

GDPR cascade + rules tightening + stream lifecycle — 2026-05-04 (H) — shipped BUT-466/464/463/462/461/613/471. See git log for full task breakdown.

## Archived sprint before (completed in commit b33653c47)

Backend perf + observability hardening — 2026-05-04 (G) — shipped BUT-482/483/473/480/592/627. See git log for full task breakdown.

## Archived sprint before (completed in commit 4fc17758e + d9cb88acf)

Parsing/social tech-debt + dependency hygiene — 2026-05-04 (F) — shipped BUT-700/682/676/631/630/513/529 + BUT-698 closed as Duplicate. See git log for full task breakdown.
