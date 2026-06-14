# Sprint Backlog

## Sprint: cooking-mode + user-repo follow-up close-out (4 tickets) — 2026-06-14 (iter-155)

Focus requested = `recipe`. **Warning: the pure `recipe` area is drained of buildable work.** Of 7 open `recipe`-labeled tickets, all are non-buildable this loop: BUT-1156 is an umbrella EPIC; BUT-445 nutrition view + BUT-643 Livsmedelsverket are explicitly post-beta per the standing nutrition decision (memory); BUT-976 per-step images is a multi-week speculative schema change the epic itself says "defer"; BUT-610 offline audit is a vague open-ended audit; BUT-907 is a speculative `idea` EPIC; BUT-1179 is manual/visual QA needing two concurrent devices (can't be loop-run). All flagged below.

The buildable cluster is the **follow-up close-out** for the just-shipped commit `22ab49ae9` (multi-timer cooking mode + user-repo split). These are concrete, gradeable, clear-mandate follow-ups to already-approved/shipped work — the cooking-mode timer surface IS the recipe surface. Clustered into two disjoint-file batches.

### Agent A: cooking-mode-timers — close the BUT-1242 acceptance gaps
- [ ] **A1. Widget test for the active-timers overview strip** `[Tier A]` — `test/widget/cooking/cooking_mode_active_timers_strip_test.dart` (new), drives `lib/views/cooking_mode_view.dart` `_ActiveTimersStrip`/`_TimerChip` + `lib/services/cooking/step_timer_service.dart`. (BUT-1283)
  - Acceptance: Test asserts the strip renders exactly one chip per running timer with ≥2 active timers · Test asserts idle/expired timer entries are hidden from the strip · Test asserts the strip renders nothing (zero chips / collapsed) when no timer is active · Test asserts tapping a chip reopens the correct step's timer sheet
- [ ] **A2. Initialize iOS local-notifications (Darwin) for timer-expiry alerts** `[Tier A]` — `lib/services/notifications/local_timer_notification_service.dart` (+ iOS `Info.plist` / `AppDelegate` if a plugin registration line is required). (BUT-1284)
  - Acceptance: `_ensurePrepared` (or init path) constructs `DarwinInitializationSettings` and calls `FlutterLocalNotificationsPlugin.initialize` before any `zonedSchedule` runs · iOS notification permission is requested via `requestPermissions` at a defined, sensible point (timer-start, not app-launch) · No `zonedSchedule` call path can execute against an un-initialized plugin on iOS (init is idempotent + awaited) · Existing Android channel/exact-alarm path is unchanged (no Android regression)

### Agent B: user-repo-followups — attribution + GDPR audit-test close-out
- [ ] **B1. Correct in-code attribution + confirm merge-write acceptance** `[Tier A]` — `lib/repositories/firebase/firebase_user_repository.dart`, `lib/models/user_profile.dart` (comment correction; verify shipped behavior). (BUT-1285)
  - Acceptance: Every in-code comment that reads "BUT-1242 follow-up" on the profile-merge fix now references BUT-1285 instead · `saveProfile`/`updatePublicProfile` use `set(merge:true)` driven by `toFirestoreEditable()` which excludes `friendsCount`/`isHidden`/`hiddenAt` · The existing merge-regression test (stale profile does not overwrite a concurrent `friendsCount`) still passes · No behavioral change to the write path beyond the already-shipped merge fix (comment-only diff in lib aside from any missing-coverage assertion)
- [ ] **B2. Test the GDPR success-path audit log on deletion** `[Tier A]` — `test/unit/repositories/firebase_user_repository_test.dart`. (BUT-1286)
  - Acceptance: A test asserts `deleteUserRootDoc` emits a `logPermissionCheck(granted: true)` entry on success (operation `delete`, resource `user_root_doc/{uid}`) · A test asserts `deletePublicProfile` emits a `logPermissionCheck(granted: true)` entry on success (operation `delete`, resource `public_profile/{uid}`) · Both tests fail if the success-path audit call is removed (they pin the side effect, not just a green run)

### Needs you (not built — flagged for your call)
- **BUT-445** (Medium, recipe) — Build nutrition display view. Explicitly tagged post-beta per the standing nutrition decision ("Nutrition = plan models post-beta, use Livsmedelsverket API"). Recommendation: **defer** until nutrition is a decided workstream — building it now contradicts a saved decision.
- **BUT-643** (Low, recipe/idea) — Livsmedelsverket nutrition DB integration. Same post-beta nutrition gate as BUT-445. Recommendation: **defer**, build alongside the nutrition view when nutrition is greenlit.
- **BUT-976** (Medium, recipe/idea) — Per-step images. The epic itself says "defer — schema change + migration + editor + viewer + import = multi-week." Speculative, no mandate. Recommendation: **defer/reframe** into a scoped phase if you want it.
- **BUT-610** (Medium, recipe/backend) — Audit + harden offline mode. Open-ended audit, no concrete defect list. Recommendation: **reframe** into specific defect tickets after a scoped offline crash audit.
- **BUT-907** (Low, recipe/idea) — Trash & Recovery EPIC (persistent undo). Speculative epic, flagged needsApproval previously. Recommendation: **your call** — product decision on whether persistent trash is wanted.

### Tier D / manual — flagged, never coded this loop
- **BUT-1179** (Medium, recipe) — Manual QA of ConflictBanner live concurrent-edit on 3 surfaces. Explicitly manual/visual-only, needs two concurrent devices/browser profiles against the emulator. No code change expected. Cannot be loop-run — needs you (or a manual QA pass).
- **BUT-1156** (High, recipe) — umbrella EPIC, not directly buildable; its children route through the tickets above.

### Obsolete (done in git, still open in Linear)
- None. BUT-604 (inline timers) already shows commit `212279228` and is not in the open set. BUT-1242/BUT-734 shipped in `22ab49ae9` and are correctly parked (1242 In Review, 734 closed); the four follow-ups above are the deliberate gap-closers, not obsolete work.

### Post-Sprint Steps
- [ ] Run `dart analyze --fatal-infos`
- [ ] Run relevant unit/widget tests (`test/widget/cooking/`, `test/unit/repositories/firebase_user_repository_test.dart`)
- [ ] Commit, push to main
- [ ] Update Linear: all four (BUT-1283/1284/1285/1286) → Done (Tier A, test/infra close-outs, fully verifiable)

---
## ARCHIVED — iter-154 (backend thin slice: BUT-734 Tier C user-repo split + BUT-1242 Tier B multi-timer cooking mode — shipped commit 22ab49ae9; spawned follow-ups BUT-1283/1284/1285/1286 — this iter's batch) · iter-153 (tagging: area drained, no batches — BUT-907 flagged needsApproval as speculative Trash & Recovery epic) · iter-152 (menu: BUT-1278/1279 Tier A, BUT-1043/930 Tier B — shipped commit 1711d297c; BUT-1179 Needs-you) · iter-151 (import: BUT-1040/931/947/903/1205 — shipped 673f80c87 + 10325a5bb; BUT-653/656/684/941 needsApproval) · iter-150 (social conflict-cleanup + activity/sharing UI: BUT-1267/1266 Tier A, BUT-1220/1000/949 Tier B; BUT-1265 obsolete-closed) · iter-149 (BUT-1265 conflictStream test — f37c9af03) · iter-148 (BUT-1263/1264 recoverLocalVersion test-gaps — d4ee51b0f) · iter-147 (BUT-1262 realtime data-loss-path) · iter-146 (BUT-1053/1247/1250) · iter-145 (BUT-1251/1246/1249 Done) · iter-144 (BUT-648/1057 In Review) · iter-143 (BUT-1245/626 Done) · äldre i git-historiken
