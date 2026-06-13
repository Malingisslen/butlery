# Sprint Backlog

## Sprint: conflictStream end-to-end delivery test — 2026-06-14 (iter-149)

9th sprint this session. FULL backlog scan: 100 most-recently-updated Backlog + 5 Todo (Triage/In Progress empty). Honest finding (repeats iter-147/148): the clean, verified-on-main Tier A pool is essentially drained. Verified against `main`:

- **BUT-1263/1264 already landed** — HEAD `d4ee51b0f` (`test(realtime-sync): close recoverLocalVersion coverage gaps`) already contains them; the iter-148 scratch describing them as "not yet committed" was stale.
- **Premise-pending (still not merged):** BUT-530/1258/1259/1260 cite the parallel-session cold-start split (`butlery_app.dart`, `app_initializer.dart`, slimmed main.dart, 832-line veckomeny_view). Re-verified: `main.dart` is still 1395 lines, `butlery_app.dart`/`app_initializer.dart` don't exist, `veckomeny_view.dart` is 606 lines at `lib/views/veckomeny_view.dart`, and `ACCEPTED_LARGE_FILES.md` has no such entry. → hold.
- **Ops/secret-blocked:** BUT-1169 (drop legacy shopping constants needs prod backfill first — would break rendering on old docs), BUT-840/819/1229/889/814/492/451/486/etc. → not worked.
- **Self-deferred-until-trigger:** BUT-1067 (ARB descriptions — sleep until translation work), BUT-1011, BUT-1176, BUT-1248, BUT-1149, BUT-610. → hold.

The one clean, verified-on-main build slice this iteration: BUT-1265 — the end-to-end test that a real conflict reaches `conflictStream` subscribers. Verified the premise: the emission path is real (`realtime_sync_service.dart:93-94` adds to `_conflictController` via the `onConflict` callback, driven through `resolveConflict` at line 260), the existing test file (`realtime_sync_service_test.dart`) already uses a real `FakeFirebaseFirestore` + real `FirestoreRepository` + real `ConflictResolutionModule`, and no existing test subscribes to `conflictStream` and drives a genuine conflict (the module test feeds an injected sink; the `ConflictBanner` widget test stubs the stream). Single batch — touches only the one test file.

### Agent A: realtime — conflictStream end-to-end delivery test `[Tier A]`
- [ ] **A1. End-to-end test: a real losing-local conflict emits exactly one ConflictEvent to a live conflictStream subscriber** `[Tier A]` — `test/unit/services/realtime_sync_service_test.dart`: add a test (new `conflictStream` group) that subscribes to `service.conflictStream` BEFORE calling `updateResource` with a local value that loses to a higher-editCount seeded remote, exercising the real `resolveConflict` path (no injected sink, no pre-seeded controller). (BUT-1265)
  - Acceptance: the test subscribes to `service.conflictStream` BEFORE the `updateResource` call that triggers the conflict · driving a real losing-local conflict through `updateResource`/`resolveConflict` causes exactly ONE `ConflictEvent` to reach the live subscriber (count asserted == 1, not >= 1) · the emitted event's `chosenStrategy == remoteWon` for the losing-local case · the test does NOT inject a sink or pre-seed `_conflictController` — it drives the real resolution path through `updateResource` · `flutter test test/unit/services/realtime_sync_service_test.dart` passes green with no existing test weakened or removed

### Needs you (not built — flagged for your call)
- **BUT-530 / BUT-1258 / BUT-1259 / BUT-1260** — premise-pending: all four assume the cold-start split branch (`butlery_app.dart`, `app_initializer.dart`, slimmed main.dart, 832-line veckomeny_view) that has NOT merged to `main`. Re-verified absent. Recommend: hold until that branch lands (or close 1259 — its premise file/entry doesn't exist).
- **BUT-1169** — ops-blocked: dropping the legacy `meat_fish`/`fruit_veg` shopping constants while old Firestore docs still carry those strings would break rendering; needs a prod backfill + telemetry first (the ticket says so). Recommend: provision the backfill before the code cleanup.
- **BUT-1067** — self-deferred: ARB `description` backfill for ~3000 keys; pure translator-context value, no UX/code change. Recommend: sleep until a third locale or external translator is committed.
- **BUT-1240** — needs a device-capable CI runner for the NER real-signal lane. Recommend: hold until that runner exists.
- **BUT-1011 / BUT-1248 / BUT-1176** — self-deferred dead-code-until-trigger. Recommend: drop until a real trigger.
- **BUT-1149** — blocked-on-precondition: floor 55→60 would red main (coverage ~55.5%). Recommend: reframe as "write tests to 60% THEN flip the floor."
- **BUT-610** — large open-ended offline audit+harden (~1 day + 3–5 days). Recommend: greenlight just Phase 1 if you want it moving.
- **Ops/secret-blocked (unchanged):** BUT-840, BUT-819, BUT-1229, BUT-889, BUT-814, BUT-492, BUT-451, BUT-486 — need prod/console/secret access this loop can't reach.

### Post-Sprint Steps
- [ ] Run `dart analyze --fatal-infos`
- [ ] Run `flutter test test/unit/services/realtime_sync_service_test.dart`
- [ ] Phase 2.7 outcome-grading (fresh-context verifier on BUT-1265 acceptance)
- [ ] Commit, push
- [ ] Linear: BUT-1265 → Done (Tier A) if tests green and acceptance met

---
## ARCHIVED — iter-148 (BUT-1263/1264 recoverLocalVersion test-gaps — landed in HEAD d4ee51b0f) · iter-147 (BUT-1262 realtime data-loss-path sign-off) · iter-146 (BUT-1053/1247/1250 — 1247 Done; locale-aware LLM/OCR + 2 test-gap close-outs, b247fad66) · iter-145 (BUT-1251/1246/1249 Done) · iter-144 (BUT-648/1057 In Review) · iter-143 (BUT-1245/626 Done) · äldre i git-historiken
