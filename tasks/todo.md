# Sprint Backlog

## Sprint: iter-63 — BUT-1069 watchResource error propagation — 2026-05-25 (Mon)

Theme: Bug fix — `RealtimeSyncService.watchResource` swallows downstream errors via `.handleError` terminator. UI's `StreamBuilder` never sees `documentNotFound` or `firestoreError` → stale data forever. P3 backend.

### Step 0 — premise verification

- Ticket body matches `lib/services/realtime_sync_service.dart:186-193` exactly. `.handleError` records to side-channel `_errorController` (errorStream) but swallows from main stream.
- Two pin'd-bug tests in `test/unit/services/realtime_sync_service_test.dart`:
  - line 175-199 "missing document is routed through errorStream, not propagated"
  - line 211-... "malformed payload surfaces as firestoreError via errorStream"
- Both tests assert the BUG behavior with explicit "intentionally swallows the propagation" docstring.
- Classification: **fits** — implement as written, with the dual-fire approach (side-channel + propagate).

### Design choices

- **Replace `.handleError` with `StreamTransformer.fromHandlers`** so we can both:
  1. Record on `_errorController` (preserve existing side-channel for callers that watch errorStream)
  2. Re-emit via `sink.addError(error, stackTrace)` to the main stream
- **Don't wrap as a new SyncError** in propagation path — the upstream `.map` already wrapped parse failures + missing-doc as typed `SyncError`. Re-wrapping would double-shell. Pass through as-is.
- **Test updates**: flip both pin'd tests to assert error ALSO reaches the main stream subscriber (not just the side-channel). Remove the "not propagated" / "intentionally swallows" docstrings.
- **No callers to update.** Existing callers using `StreamBuilder.builder` with `snapshot.hasError` will start working correctly. Callers using `errorStream.listen` continue to work (additive change).

### Ship this sprint

- [ ] **A1. Fix watchResource error propagation** — `lib/services/realtime_sync_service.dart:186-193`: swap `.handleError` for `.transform(StreamTransformer.fromHandlers(handleError: ...))` that records side-channel + re-emits via `sink.addError`. (BUT-1069)
- [ ] **A2. Flip 2 pin'd-bug tests** — `test/unit/services/realtime_sync_service_test.dart` lines 165-199 + 201-...: update to assert error propagates to main stream AND surfaces on errorStream. (BUT-1069)

### Acceptance

- [ ] `flutter analyze` clean.
- [ ] `flutter test test/unit/services/realtime_sync_service_test.dart` passes (flipped tests now assert correct behavior).
- [ ] errorStream still receives the error (side-channel preserved).

### Post-Sprint Steps

- [ ] Commit + push
- [ ] Close BUT-1069 with commit hash

---

## Archived iter-62 (commit `538bef887`) — 2026-05-25 (Mon)

BUT-1068 P2 fix — three shared-content VMs (recipe/menu/shopping) dismiss/restore closures forward coordinator bool instead of always-true. 5 closures, +36 / −45. BUT-1081 filed for sibling test gap.
