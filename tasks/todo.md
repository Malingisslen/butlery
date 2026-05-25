# Sprint Backlog

## Sprint: iter-74 — BUT-1083 logger_test.dart — 2026-05-25 (Mon)

Theme: Pin AppLogger's two untested contracts: async-error absorption (proved BUT-1059 fix) + `_sanitizeForCrashlytics` PII redaction. P3 backend/test-gap.

### Step 0 — premise verification

- `lib/core/utils/logger.dart` has zero direct test coverage.
- `_sanitizeForCrashlytics` is private. To test cleanly without setting up a Crashlytics MethodChannel mock, add a tiny `@visibleForTesting` public wrapper (`sanitizeForCrashlyticsForTesting`) that just calls the private method. Minimal prod surface change.
- Async-absorption test uses `runZonedGuarded` + `AppLogger.error(...)` directly — no Firebase init needed (BUT-1059 fix means the sync+async catches in `_safeCrashlytics` swallow the instance-getter-throws + Future-rejects).
- Classification: **fits**.

### Design choices

- **2 new files**:
  - `lib/core/utils/logger.dart`: add `@visibleForTesting static String sanitizeForCrashlyticsForTesting(String message) => _sanitizeForCrashlytics(message);` — 3-line addition, no other changes.
  - `test/unit/core/utils/logger_test.dart`: ~6 tests covering both contracts.
- **Tests planned**:
  1. `AppLogger.error()` in `runZonedGuarded` zone with no Firebase init does not surface unhandled async error.
  2. Sanitize: 20-char UID redacted to first-4 + `***`.
  3. Sanitize: 28-char UID redacted similarly.
  4. Sanitize: 19-char and 29-char tokens NOT redacted (boundary).
  5. Sanitize: multiple UIDs in one message all redacted.
  6. Sanitize: short message with no UID passes through unchanged.

### Ship this sprint

- [ ] **A1. Add `@visibleForTesting` sanitize helper** — `lib/core/utils/logger.dart`. (BUT-1083)
- [ ] **A2. Create logger_test.dart** with 6 tests covering both contracts. (BUT-1083)

### Acceptance

- [ ] `flutter analyze` clean.
- [ ] `flutter test test/unit/core/utils/logger_test.dart` — 6/6 pass.
- [ ] No Crashlytics scaffolding needed.

### Post-Sprint Steps

- [ ] Commit + push
- [ ] Close BUT-1083

---

## Archived iter-73 (commits `96146b05f` → `8ebb36be5` → `c37732afc`) — 2026-05-25 (Mon)

BUT-1084 P4 — appended sanitizer-warning entry to testing-specialist.knowledge.md. Self-caught Edit-then-commit footgun mid-iter, added lessons.md entry for it.
