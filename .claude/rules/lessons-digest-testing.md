---
paths:
  - "test/**"
  - "functions/src/__tests__/**"
---

# Lessons Digest — testing

Lessons that only bind while writing or running tests. Counted by the same drift tripwire
as the core digest (`knowledge.digestFiles`), so these are as in-force as any other lesson —
they simply do not load in sessions that never open a test file.

- Red CI on an unrelated test = suspect a pre-existing flake; fix the flake at root (seed the RNG) — never rerun-until-green.
- Chronic-red CI disarms safety-gate tests silently — triage any always-red job to zero promptly, and after moving a definition, grep tests for hardcoded paths/regexes aimed at the old site.
- `architecture_test.dart` guards are NOT in `dart analyze` — analyze-clean ≠ CI-green for `lib/widgets/`.
- Adding a named param to a mocked service silently un-matches every old mocktail stub — update the stubs.
- cloud_firestore's FieldValue caches the platform factory statically — fake batches can throw subtype errors.
- Lexicon-dependent tests: assert the premise, and watch NFC vs NFD normalization on å/ä/ö.
- real-time-guard matches the literal `DateTime.now()` even inside comments.
- After changing a class's constructor, run its EXISTING test suites — not just the new test you wrote.
- A DI cap/gate seam defaulting to a real-Firestore resolver fails CLOSED in ts-node CF unit tests (no Firebase app) and silently diverts control flow on every path that reaches it — inject it to `async () => true` in those tests (mirror `makeOcrSeams`); if a sibling suite is red, STASH your diff first to check it wasn't already red on main, then fix at root.
- Auditing a mature test suite means auditing DISCOVERY, not adding test types — every runner that decides what to run from a HAND-TYPED list (npm `test:*` script names, a workflow `paths:` filter) is a silent-drift hole; prove orphan counts by script, then guard the list. Rank by blast radius of the check going dark.
