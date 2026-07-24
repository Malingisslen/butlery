---
paths:
  - "test/**"
  - "functions/src/__tests__/**"
---

# Testing Philosophy

Tests verify **intended behavior**, not green status.

1. **Intention first** — articulate what behavior a test proves. One sentence, or it's
   unfocused.
2. **A failing test might be right** — ask "is the test correct?" before "how do I make it
   pass?" Never weaken an assertion just to go green.
3. **Mock dependencies, not the subject** — a test that mocks away the behavior it claims
   to verify proves nothing.
4. **Test the contract** — inputs → outputs and side effects, not implementation details.
   One meaningful behavioral test beats ten getter checks.

Run a single suite with `flutter test test/unit/<file>_test.dart`. Always use forward
slashes in test paths on this machine.

Accumulated testing gotchas: `.claude/rules/lessons-digest-testing.md` (loaded alongside
this file). The `testing-specialist` agent owns unit and widget tests; `e2e-test-specialist`
owns journey tests under `test/views/` and `test/e2e/`.
