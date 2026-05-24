# Sprint Backlog

## Sprint: iter-64 — BUT-1059 AppLogger async error handling — 2026-05-25 (Mon)

Theme: Bug fix — `AppLogger._logToCrashlytics` wraps `FirebaseCrashlytics.instance.log(...)` and `.recordError(...)` (both `Future`-returning) in a SYNC `try/catch`. Async exceptions escape the catch as unhandled. P3 backend.

### Step 0 — premise verification

- Ticket body matches `lib/core/utils/logger.dart:212-235` exactly. Sync try wraps two async calls.
- `kIsWeb` short-circuit on line 218 stays unchanged (Crashlytics not supported on web).
- The sync catch DOES catch errors from constructing `FirebaseCrashlytics.instance` (e.g. uninitialized Firebase throws synchronously), so we keep the outer try/catch + add per-future `.catchError`.
- Classification: **fits** — implement as written.

### Design choices

- **Chain `.catchError((_) {})` on each Future** — minimal change, both async exceptions absorbed. Doesn't introduce `dart:async` import (uses Future method).
- **Keep the outer sync try/catch** — handles the synchronous "Firebase not initialized → instance throws" path.
- **No `unawaited(...)` wrap** — the discarded-future analyzer lint is not enabled in this project (verified by no existing `discarded_futures` overrides in `analysis_options.yaml`). If it does fire, add `// ignore_for_file: discarded_futures` rather than restructure.
- **No tests to flip.** This fix is invisible to existing tests (those that mock the Crashlytics channel still work; those that don't were failing — they're not in the current suite per the discovered-by note).

### Ship this sprint

- [ ] **A1. Fix AppLogger._logToCrashlytics** — `lib/core/utils/logger.dart:220-234`: chain `.catchError((_) {})` on both `log()` and `recordError()` futures so async errors are absorbed. (BUT-1059)

### Acceptance

- [ ] `flutter analyze` clean.
- [ ] `flutter test` for files that touch AppLogger.error from non-Crashlytics-mocked contexts no longer fails with MissingPluginException escape.
- [ ] Outer sync try/catch retained for the "Firebase not initialized" path.

### Post-Sprint Steps

- [ ] Commit + push
- [ ] Close BUT-1059 with commit hash

---

## Archived iter-63 (commit `6eb6c4455`) — 2026-05-25 (Mon)

BUT-1069 P3 fix — `RealtimeSyncService.watchResource` now propagates errors to BOTH main stream + errorStream side-channel via `StreamTransformer.fromHandlers`. +67 / −56. 25/25 tests pass. BUT-1082 filed for wrapper-channel verification.
