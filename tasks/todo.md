# Sprint Backlog

## Sprint: realtime data-loss-path sign-off — 2026-06-13 (iter-147)

7th sprint this session. FULL backlog scan (105 open: Backlog 100 + Todo 5; In Progress / Triage empty). Honest finding: the clean-buildable Tier A pool on `main` is essentially drained this iteration. Most open tickets are (a) **premise-pending** — they reference files from an uncommitted parallel sprint that have NOT landed on `main` (BUT-1259/1260/1258 cite `lib/butlery_app.dart`, `lib/bootstrap/app_initializer.dart`, and a 832-line `veckomeny_view.dart` — none of which exist here; `main.dart` is still 1395 lines, `veckomeny_view.dart` is 606), (b) **ops/secret-blocked** (BUT-840 needs an Algolia admin key in CF; BUT-819 needs prod gcloud; BUT-1011 premature until prod telemetry), or (c) **self-deferred-until-trigger** by their own bodies (BUT-1067/1176/1248/1149/610). Per the skill, a batch that's mostly needsApproval is fine and expected — not manufacturing build work to fill N.

One genuinely-clean build this sprint.

### Agent A: realtime — data-loss-prevention path sign-off `[Tier A]`
- [ ] **A1. Re-review + harden recoverLocalVersion / conflict_diff_view** `[Tier A]` — `lib/services/realtime_sync_service.dart` (recoverLocalVersion ~line 293, the ~35-line conflict-resolution + editCount-bump method) and `lib/views/realtime/conflict_diff_view.dart` (the "Behåll min version" button wired to call it). The reviewer markers were stale when BUT-1262 was filed (newer lib changes than the marker mtime), so the fixup wave never got a fresh code-review / testing-review. Read the recoverLocalVersion diff cold for correctness on the load-bearing data-loss path: editCount monotonicity, no silent overwrite of the remote winner, idempotency, dispose/listener safety. Fix any real bug inline (smallest correct diff); if clean, the existing `realtime_sync_service_test.dart` coverage stands and this is a sign-off only. (BUT-1262)
  - Acceptance: recoverLocalVersion's editCount handling is correct — it bumps strictly above the remote version so the local recovery wins the next sync (test-pinned in realtime_sync_service_test.dart, or shown already-pinned) · "Behåll min version" calls recoverLocalVersion (not a raw re-persist) and the path cannot silently drop the user's local edits · `dart analyze --fatal-infos` clean on both files · existing realtime_sync_service_test.dart + any conflict_diff_view tests stay green (no assertion weakened to pass)

### Needs you (not built — flagged for your call)
- **BUT-1259** — premise-pending: cites `lib/butlery_app.dart` (1164 lines) which does not exist on `main` yet. The BUT-530 main.dart slim-down + ButleryApp extraction was done in a parallel session that hasn't merged. Re-runnable once that lands. Recommend: hold.
- **BUT-1260** — premise-pending: cites `lib/bootstrap/app_initializer.dart` (runPhaseA/runPhaseB) which doesn't exist on `main`. Same uncommitted cold-start split. Recommend: hold until BUT-431 lands.
- **BUT-1258** — premise-pending: cites `veckomeny_view.dart` at 832 lines; it's 606 on `main` (the BUT-1043 copy-week UI that grew it hasn't merged). Recommend: hold.
- **BUT-840** — ops/secret-blocked: search is real Algolia (client-side `saveObject`); the CF `on-profile-updated.ts` has no Algolia admin SDK or admin API key. Needs a secret + SDK add. Recommend: do it, but you (or a deliberate ops pass) must provision the Algolia admin key first.
- **BUT-819** — ops-only: `gcloud firestore databases describe` against prod. Recommend: run it yourself when convenient; it's a 1-line verify.
- **BUT-1011** — self-deferred: its own body says "premature optimization; file IF telemetry shows timeouts." None reported. Recommend: drop until a real prod `deadline-exceeded` appears.
- **BUT-1176** — self-deferred: adds a `custom_lint` dependency for a refinement of a guard that has zero current leaks. Body says "pick up only if custom_lint is added for other reasons." Note: it flags one clean sub-fix — the inert `- custom_lint` plugin line at `analysis_options.yaml:37` (no package in pubspec) should be removed if the ticket is dropped. Recommend: drop the custom_lint upgrade; remove the dangling line as a tiny follow-up.
- **BUT-1248** — self-deferred: "no v2 schema exists; building the dispatcher now would be speculative dead code." Recommend: drop until the first breaking model change.
- **BUT-1149** — blocked-on-precondition: bumping the coverage floor 55→60 would red `main` because filtered coverage is ~55.5% today. Needs more tests to reach 60% first. Recommend: reframe as "write tests to 60%, THEN flip the floor" — not a one-liner.
- **BUT-610** — large open-ended audit+harden (~1 day audit + 3–5 days). Genuine value (offline is a review-rejection vector) but the scope/size is your call. Recommend: greenlight just Phase 1 (the offline-path audit) as a scoped sprint if you want it moving.

### Post-Sprint Steps
- [ ] Run `dart analyze --fatal-infos`
- [ ] Phase 2.7 outcome-grading (fresh-context verifier on BUT-1262 acceptance)
- [ ] Commit, push
- [ ] Linear: BUT-1262 → Done if review clean (Tier A); → In Review if a non-trivial fix was made

---
## ARCHIVED — iter-146 (BUT-1053/1247/1250 — 1247 confirmed Done; locale-aware LLM/OCR + 2 test-gap close-outs, commit b247fad66) · iter-145 (BUT-1251/1246/1249 Done) · iter-144 (BUT-648/1057 In Review) · iter-143 (BUT-1245/626 Done) · äldre i git-historiken
