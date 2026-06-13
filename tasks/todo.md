# Sprint Backlog

## Sprint: recoverLocalVersion test-gap hardening — 2026-06-14 (iter-148)

8th sprint this session. FULL backlog scan (100 most-recently-updated of ~105 open; Todo 5, In Progress / Triage empty). Honest finding repeated from iter-147: the clean-buildable Tier A pool on `main` is still essentially drained. Verified against `main`:

- **Premise-pending (still not merged):** BUT-1259/1260/1258 reference the parallel-session cold-start split — `lib/butlery_app.dart`, `lib/bootstrap/app_initializer.dart`, slimmed `main.dart`, grown `veckomeny_view.dart`. None landed: `main.dart` is still 1395 lines, `butlery_app.dart`/`app_initializer.dart` don't exist, `veckomeny_view.dart` is at `lib/views/veckomeny_view.dart` (not the path they cite). BUT-1259's ACCEPTED_LARGE_FILES.md entry doesn't even exist on main. → hold.
- **Ops/secret-blocked:** BUT-840 (Algolia admin key), BUT-819 (prod gcloud), BUT-1229/814/492/451/486/etc. → not worked.
- **Self-deferred-until-trigger:** BUT-1011, BUT-1176, BUT-1248, BUT-1149, BUT-610. → hold.

The one clean, verified-on-main build slice this iteration: two test-gap follow-ups to last sprint's BUT-1262 conflict-recovery work. Both reference `recoverLocalVersion` (real, at `realtime_sync_service.dart:300`) and the existing tests at `realtime_sync_service_test.dart:434`. I read the method + tests: both gaps are real (existing tests assert only `editCount`; the `lastEditedAt`/`lastEditedBy` bump and the `remote.editCount <= local.editCount` branch are genuinely unasserted). Single batch — both touch only the one test file.

### Agent A: realtime — recoverLocalVersion test-gap hardening `[Tier A]`
- [ ] **A1. Assert timestamp + author bump in recoverLocalVersion recovery** `[Tier A]` — `test/unit/services/realtime_sync_service_test.dart`: add a test under the existing `recoverLocalVersion` group that, under a fixed clock, asserts the persisted doc's `lastEditedBy == currentUserId` and `lastEditedAt == clock.now()` (not just editCount). (BUT-1263)
  - Acceptance: a new test in the `recoverLocalVersion` group asserts the persisted doc's `lastEditedBy` equals the current user id · the same (or a sibling) test asserts `lastEditedAt` equals the fixed `clock.now()` value · neither of the two pre-existing recoverLocalVersion tests has any assertion weakened or removed · `flutter test test/unit/services/realtime_sync_service_test.dart` passes green
- [ ] **A2. Cover the remote.editCount <= local.editCount branch** `[Tier A]` — `test/unit/services/realtime_sync_service_test.dart`: add a case where the remote exists but `remote.editCount <= local.editCount`, asserting the persisted bump is `local.editCount + 1` (the guard is false → local's own count is used). (BUT-1264)
  - Acceptance: a new test seeds a remote whose `editCount` is <= the local snapshot's `editCount` · it asserts the persisted `editCount` equals `local.editCount + 1` (proving the false-guard branch uses local's count, not remote's) · the test is distinct from the existing remote>local and no-remote cases · file stays green under `flutter test`

### Needs you (not built — flagged for your call)
- **BUT-1259 / BUT-1260 / BUT-1258** — premise-pending: all cite the parallel cold-start split (`butlery_app.dart`, `app_initializer.dart`, slimmed main.dart, 832-line veckomeny_view) that has NOT merged to `main`. Re-runnable once that branch lands. Recommend: hold.
- **BUT-1261** — Tier B design-decision: conflict diff view per-resource-type rendering + semantic ingredient diffing, OR narrow BUT-1163's acceptance. Its own body asks to "confirm with Malin." Recommend: your call — option (b) narrow-the-acceptance is cheaper if the generic diff reads fine to you.
- **BUT-840** — ops/secret-blocked (Algolia admin key in CF). Recommend: provision the key first.
- **BUT-819** — ops-only (`gcloud firestore databases describe` against prod). Recommend: 1-line verify you run when convenient.
- **BUT-1011 / BUT-1248** — self-deferred dead-code-until-trigger. Recommend: drop until a real trigger.
- **BUT-1176** — self-deferred custom_lint upgrade. Note: the inert `- custom_lint` plugin line at `analysis_options.yaml:37` (no package in pubspec) is a real dangling-config nit and could be removed as a tiny standalone fix. Recommend: drop the upgrade; greenlight just the line-removal if you want it gone.
- **BUT-1149** — blocked-on-precondition: floor 55→60 would red main (coverage ~55.5%). Recommend: reframe as "write tests to 60% THEN flip."
- **BUT-610** — large open-ended offline audit+harden (~1 day + 3–5 days). Recommend: greenlight just Phase 1 if you want it moving.

### Post-Sprint Steps
- [ ] Run `dart analyze --fatal-infos`
- [ ] Run `flutter test test/unit/services/realtime_sync_service_test.dart`
- [ ] Phase 2.7 outcome-grading (fresh-context verifier on BUT-1263/1264 acceptance)
- [ ] Commit, push
- [ ] Linear: BUT-1263, BUT-1264 → Done (Tier A) if tests green and acceptance met

---
## ARCHIVED — iter-147 (BUT-1262 realtime data-loss-path sign-off, 1 clean build; rest premise-pending/ops-blocked/self-deferred) · iter-146 (BUT-1053/1247/1250 — 1247 Done; locale-aware LLM/OCR + 2 test-gap close-outs, commit b247fad66) · iter-145 (BUT-1251/1246/1249 Done) · iter-144 (BUT-648/1057 In Review) · iter-143 (BUT-1245/626 Done) · äldre i git-historiken
