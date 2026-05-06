# Sprint Backlog

## Sprint: BUT-702 closure + dep tracking-ticket refresh — 2026-05-06 (N)

Theme: small process sprint. Sprint M shipped CI duration telemetry yesterday. The remaining tractable backlog clusters into "needs own sprint" (auth/security, deploy pipeline, large-file decompose, SDK 3.10 bump, A/B infra) or "blocked on external" (App Check console flip, Apple Dev enrollment, drift_dev upstream). Honest sprint scope: close one stale ticket with a thorough analysis, and refresh one tracking ticket.

**In Progress carry-overs (NOT in this sprint, NOT shipped):**
- BUT-442 — repo migrations (own focused sprint, mid-flight).
- BUT-760 — App Check enforcement; awaiting Firebase Console flip.

**Step 0 verification — done:**
- **BUT-702** rescoped sprint L claimed 4 remaining destructive surfaces (group leave, group delete, friend remove, shopping-list clear). Code-read in this sprint shows:
  - **Recipe delete** — undo wired (sprint L, `mina_recept_view.dart:565-577`).
  - **Shopping-list item delete** — undo wired (`unified_shopping_view.dart:227-256`); the undo re-adds the item with all fields. Item-by-item, not whole-list-clear.
  - **Group leave** (`group_detail_view.dart:343-414`) — confirmation dialog → `_viewModel.leaveGroup()` → success SnackBar (no undo) → navigate away. Asymmetric: re-joining requires invitation acceptance, not click-to-restore.
  - **Friend remove** (`friend_profile_view.dart:333-350`) — confirmation dialog → `removeFriend(uid)` → success SnackBar (no undo) → navigate back. Asymmetric: re-friending requires friend request flow.
  - **Group delete / member remove** (`group_detail_actions.dart:55-235`) — same asymmetry.
  - All asymmetric flows have **confirmation dialogs already** as the safety net — this is the right UX.
  - **Conclusion**: BUT-702 is effectively done. The ticket should close, not stay Backlog. The "wire to all surfaces" rescope was based on an incomplete read of which destructive operations are *symmetric*. Documenting the analysis in the closing comment so a future picker doesn't re-open this thread.
- **BUT-554** is a tracking ticket. Pubspec verification: `drift_dev: ^2.29.0` pinned in lockstep with `build_runner: 2.7.1`. `flutter pub deps` confirms `build_runner_core: 9.3.1` and `build_resolvers: 3.0.3` are *still* transitively pulled — both still discontinued upstream. No drift_dev major release since the ticket was filed. Stays Backlog with refreshed status comment + next-check date.

### Process: Linear ticket-state hygiene (no code)

- [ ] **A1. BUT-702 → Done** with comprehensive asymmetry analysis comment.
- [ ] **A2. BUT-554 → status comment** noting drift_dev still at 2.29.0, build_runner_core/build_resolvers still discontinued + still pulled, next check 2026-08-06 (3 months out).

### Post-Sprint Steps
- [ ] No `dart analyze` needed (no Dart changes).
- [ ] No unit-test runs needed.
- [ ] No Tier-2 specialist gates (no `*.dart` files touched).
- [ ] Commit: `chore(sprint): BUT-702 closure + BUT-554 dep tracking refresh`.
- [ ] Push to main.

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
- BUT-594 — macOS sandbox audit needs hardware-exercise step
- BUT-701 — focus traversal (2-day a11y sprint)
- BUT-479 — cursor-pagination half is non-trivial; needs design ticket
- BUT-435 + BUT-502/503/507/509 — Dart SDK 3.10 bump cluster (one focused sprint)
- BUT-472 — realtime_session_manager stream/timer migration (next perf sprint)
- BUT-455 / BUT-440 / BUT-504 — repository discipline cluster (paired with BUT-442)
- BUT-453 / BUT-454 — auth/session security (own sprint with product-design input)
- BUT-704 — i18n @key ARB descriptions (2-day sweep; ARB files are 9585 lines each)
- BUT-520 — VM-migration sweep (rescoped sprint I; 30 VMs, 6-10 sprints of work)
- BUT-431 / BUT-530 — main.dart bootstrap split + extraction (rescoped sprint J)
- BUT-581 — `?? ''` migration (rescoped sprint K)
- BUT-610 — offline-mode hardening (multi-day audit)
- BUT-723 — tablet master-detail layouts (multi-day refactor)
- BUT-734 — split FirebaseUserRepository (defer until file ≥700 lines)
- BUT-710 / BUT-706 / BUT-711 — platform-polish cluster (BUT-715 shipped sprint L)
- BUT-492 — cost/budget alerts (Console action; doc-only piece needs the alerts to actually be wired)
- BUT-494 — coverage floor 55→85 (same blocker as BUT-397)
- BUT-488 — pubspec auto-bump CI (rescoped sprint M; Low priority)
- BUT-397 — coverage-floor tightening (deferred sprint M; needs ≥5 successful CI baseline runs)
- All `idea`-labeled monetization scaffolding — post-beta

### What this means in plain language
- **One ticket gets a proper closure**: a "make destructive actions undoable" ticket has been open for a while, but reading the code carefully today shows the parts that *can* be undone (recipe deletes, shopping-item deletes) already have undo, and the parts that can't (leaving a group, removing a friend) shouldn't have undo because re-joining/re-friending isn't a click-to-restore action — it's a separate invitation flow. Documenting why and closing the ticket so it doesn't keep coming up in future sprints.
- **One tracking ticket gets a date refresh**: a "watch for drift_dev to release a fix" ticket was filed in April. We re-check today — still no fix. Adding a comment with today's findings + the next re-check date so this ticket doesn't get forgotten.
- **Risk**: zero. No code changes. Two Linear comments + one state transition.

---

## Archived prior sprint (completed in commit 5b480e01f)

CI duration telemetry + ML runtime memo + Linear hygiene — 2026-05-05 (M) — shipped BUT-495/571 + rescoped BUT-488 + deferred BUT-397.

## Archived sprint before (completed in commit 6af9efc88)

Release polish + ops doc + Linear cleanup — 2026-05-05 (L) — shipped BUT-715/493 + reconciled BUT-738/724 + rescoped BUT-702.

## Archived sprint before (completed in commit 25ec5b025)

Tech-debt sweep + dep watch + web polish — 2026-05-05 (K) — shipped BUT-526/567/562/564/578/724/738 + rescoped BUT-581.

## Archived sprint before (completed in commits 245b71478 + a5288014f)

Dep hygiene + PWA polish + Linear cleanup — 2026-05-05 (J) — shipped BUT-500/519/524/718 + closed BUT-437 + rescoped BUT-431/530.

## Archived sprint before (completed in commit 1e347b424)

Backend hygiene + auth security micro-hardening — 2026-05-04 (I) — shipped BUT-446/506/465/490 + closed BUT-716 + rescoped BUT-520.
