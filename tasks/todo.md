# Sprint Backlog

## Sprint: post-BUT-1193 CI reconciliation + contained refactors — 2026-06-04

First sprint back on main after the other session merged BUT-1193 (#179, commit 4978e9b20).
Scope = small/contained, no product/UX call (per `feedback_autonomy_tiers.md` 2026-06-03).
Backlog: 100 issues, all Backlog, none Urgent. Launch-gated (7) + EPICs (6) + Features/ideas
+ Tier-D ops all excluded.

### Agent A: ci-reconciliation — reconcile CI tickets against the merged BUT-1193 matrix
- [x] **A1. Reconcile BUT-1182** `[Tier A]` — premise-gone (#179 shards unit 3× w/o coverage).
      Closed **Done**, linked `4978e9b20`/#179. (BUT-1182)
- [x] **A2. Reconcile BUT-1192** `[Tier A]` — plan-stale (flake → nightly `cross-os`, no longer
      commit-blocking). Re-scoped Linear body + downgraded P3→P4, kept open. (BUT-1192)
- [x] **A3. Reconcile BUT-1149** `[Tier A]` — still valid; floor unchanged at 55% (only re-timed).
      Left **open** — raising to 60% now would fail the gate (coverage ~55%). Commented. (BUT-1149)
- [x] **A4. Reconcile BUT-397** `[Tier A]` — duplicate of BUT-1149. Closed as **Duplicate**. (BUT-397)

### Agent B: contained-refactors — behavior-preserving cleanups
- [~] **B1. BUT-520** `[de-scoped]` — Step-0 caught: body self-identifies as an **EPIC** (62 VMs on
      raw ChangeNotifier, ~1 day/VM, touches core-UX loading/error behavior). Out of loop scope
      (needs Malin). De-selected, commented on ticket, left in Backlog. (BUT-520)
- [x] **B2. BUT-1190** `[Tier A]` — `firebase_comments_repository.dart` (546 lines). Facade-extracted
      the 4 like-ops into `comments/comment_likes_operations.dart` mixin → repo now **464 lines**,
      analyze clean, 52 repo tests pass (incl. Like System). (BUT-1190)

### Needs you (Tier D — flagged, not worked)
- BUT-1187 — deployed & live, but runtime-unverified: needs ONE real recipe import from your
  phone (web build can't reach the function). Imports clean → close Done; 404s → flip model + redeploy.
- onRecipeDeleted 1st→2nd-gen deploy blocker — needs a ticket filed (owed from last session).

### Post-Sprint Steps
- [ ] Run `dart analyze --fatal-infos`
- [ ] Run relevant unit tests
- [ ] Commit, push
- [ ] Update Linear ticket states (Done for Tier A reconciled/refactored)

---

## ARCHIVED — BUT-581 sprint (complete, shipped a9bb611d7)

`?? '' → .orEmpty()` migration: chunks 1–8 swept + architecture-test guard added. BUT-581 Done.
Deploys that were awaiting Malin: BUT-1187 deployed (verification pending phone test); BUT-1049
rules deploy still pending. Shipped that session: tagging cluster (1042/1185/1186/1188),
comment-images (1049/1189), GDPR coverage (1009/1191), BUT-1187 model fix, de-flaked menu_service.
