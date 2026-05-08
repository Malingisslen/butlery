# Sprint Backlog

## Sprint: test-gap closure + tech-debt sweeps — 2026-05-08 (F)

Theme: close 5 follow-up tickets filed by the 2026-05-06/07 sprints (BUT-815/816/827/831/832/836/837) — most are small, targeted scopes that would otherwise rot in the backlog. No store-submission, no ops-only work.

### Step 0 results (filled per ticket during execution)

- **BUT-832** — pending Step 0 read.
- **BUT-827** — pending Step 0 read.
- **BUT-815** — Dart-only carve-out: 3 unit tests in scope, 2 CF integration tests deferred (emulator-bound).
- **BUT-816** — pending Step 0 read.
- **BUT-836** — pending Step 0 read (will run grep against current `lib/models/`).
- **BUT-837** — analysis-only ticket (output is updated Linear body, not code).
- **BUT-831** — pending Step 0 read (5 surfaces listed in ticket body).

### Agent A: testing-specialist — test-gap closure
- [ ] **A1. BUT-832** — `test/unit/repositories/firebase_analytics_repository_test.dart:455`: `equals('false')` → `equals(false)`. Verify pass.
- [ ] **A2. BUT-827** — new `test/unit/services/expected_model_hashes_test.dart`: assert each map value matches `^[0-9a-f]{64}$`. Empty maps pass vacuously.
- [ ] **A3. BUT-815** — 3 Dart unit tests: report-repo batch+throttle, compliance-export pagination+cap, FriendsStateManager listener-cleanup. CF integration tests filed as follow-up.

### Agent B: cloud-functions-specialist + dart-tech-debt — refactor + targeted sweep
- [ ] **B1. BUT-816** — `functions/src/shared/batch-update.ts`: add `commitInChunks(database, refs, mutate, label, {strict})`. Refactor 3 sites in `on-user-deleted.ts`. Preserve best-effort/strict semantics.
- [ ] **B2. BUT-836** — Phase 1 only: grep raw `as DateTime|as Timestamp|as int|as double` in `lib/models/`, find unguarded sites lacking upstream coercion, migrate to `SerializationUtils.safeXxx`. Add arch-test guard.

### Agent C: analysis-only — re-audit
- [ ] **C1. BUT-837** — re-grep `lib/repositories/` + `functions/src/` for `displayName`/`avatarUrl` writes. Update Linear ticket body with file:line table distinguishing legit denorm vs bypass. Code-side sweep stays a separate ticket once scope is concrete.

### Agent D: flutter-developer — UI keyboard padding
- [ ] **D1. BUT-831** — apply `MediaQuery.viewInsetsOf(context).bottom` (or `resizeToAvoidBottomInset`) to: login/signup forms, comment composer, recipe form (`skriv_sjalv_recept_view`, `edit_recipe_view`), chat input, group dialogs. Manual smoke note in commit body.

### Tier-2 agent reviews (run before commit)
- [ ] code-reviewer — full Dart diff
- [ ] testing-specialist — staged `lib/**/*.dart`
- [ ] firebase-backend-security — only if `lib/repositories/` or `functions/src/` (excl tests) staged
- [ ] firestore-rules-tester — skip unless `firestore.rules` touched

### Post-Sprint Steps
- [ ] `dart analyze --fatal-infos`
- [ ] Relevant unit tests pass
- [ ] Commit (inline), push
- [ ] Linear close: BUT-832, BUT-827, BUT-815, BUT-816, BUT-836, BUT-837, BUT-831
- [ ] File any deferred follow-ups (BUT-815 CF integration tests; BUT-836 Phase 2 if warranted)

---

## Archived prior sprint (completed in commit fd9c8ea17 + bed18c4cd + aef8968c7)

analytics caller-wiring + backend correctness sweeps — 2026-05-07 (Th) — BUT-833/834/830/824/826 done; BUT-787/783 deferred → BUT-836/837 filed; CI fix BUT-835 + mocks refactor BUT-838 follow-up.
