---
paths:
  - "test/**"
  - "functions/src/__tests__/**"
---

# Lessons Digest — testing

Lessons that only bind while writing or running tests. Counted by the same drift tripwire
as the core digest (`knowledge.digestFiles`), so these are as in-force as any other lesson —
they simply do not load in sessions that never open a test file.

- Eval input must match PRODUCTION input, not the cheapest-to-label input.
- Red CI on an unrelated test = suspect a pre-existing flake; fix the flake at root (seed the RNG) — never rerun-until-green.
- Chronic-red CI disarms safety-gate tests silently — triage any always-red job to zero promptly, and after moving a definition, grep tests for hardcoded paths/regexes aimed at the old site.
- `architecture_test.dart` guards are NOT in `dart analyze` — analyze-clean ≠ CI-green for `lib/widgets/`.
- Adding a named param to a mocked service silently un-matches every old mocktail stub — update the stubs.
- cloud_firestore's FieldValue caches the platform factory statically — fake batches can throw subtype errors.
- Lexicon-dependent tests: assert the premise, and watch NFC vs NFD normalization on å/ä/ö.
- real-time-guard matches the literal `DateTime.now()` even inside comments.
- After changing a class's constructor, run its EXISTING test suites — not just the new test you wrote.
- A DI cap/gate seam defaulting to a real-Firestore resolver fails CLOSED in ts-node CF unit tests (no Firebase app) and silently diverts control flow on every path that reaches it — inject it to `async () => true` in those tests (mirror `makeOcrSeams`); if a sibling suite is red, STASH your diff first to check it wasn't already red on main, then fix at root.
- A golden/corpus suite is TWO files — the corpus JSON and the runner's `_expectedPassing` id snapshot; extend both in one edit. A green golden run proves only the LISTED ids behave, so grep the corpus for the literal string an acceptance criterion names before claiming it's covered (BUT-1666 went 17/17 green with all three named collision strings absent and still misclassified).
- `FakeFirebaseFirestore.runTransaction` is a NO-OP passthrough (handler called once, writes immediate, `SetOptions`/`timeout`/`maxAttempts` dropped, no isolation/abort/retry) — a two-writer test there LOSES one edit, i.e. it contradicts production rather than under-proving it; `merge:true` is dropped and `GetOptions(source:cache)` is ignored (real Firestore THROWS `unavailable` on a cache miss). Never let a fake-backed test's name or comment claim atomicity; put that on the emulator lane, and verify the lane actually runs in CI before counting it (BUT-1665/BUT-1695). The fake also DROPS a `FieldValue` sentinel inside a transactional merge-set (an `arrayUnion` comes back as just the new value) — compute the union explicitly from the snapshot the transaction already holds. And the emulator lane cannot simply be switched on: `--dart-define=USE_EMULATOR=true` under plain `flutter test` makes `Firebase.initializeApp` throw a channel `PlatformException` (no plugin channels in the Dart-only host) — it needs an `integration_test` host or a pure-Dart client (BUT-1730).
- Auditing a mature test suite means auditing DISCOVERY, not adding test types — every runner that decides what to run from a HAND-TYPED list (npm `test:*` script names, a workflow `paths:` filter) is a silent-drift hole; prove orphan counts by script, then guard the list. Rank by blast radius of the check going dark.
- A test written to pin a fix is a HYPOTHESIS until you revert the fix and watch YOUR test redden (then restore, md5-verified). Three ways one passes vacuously, all hit in one sprint: a tautology over the implementation (assert key ABSENCE, not value non-nullness, when the builder filters keys); a fixture answered by an EARLIER branch (a digit reaches `RegExp(r'\d')` first; a factory that stamps every field makes an "unstamped" case impossible — check the branches ABOVE, not only beside); and a premise the fake cannot stage (`fake_cloud_firestore.update()` DEEP-MERGES nested maps, and `GetOptions(source:)` is ignored, so cache-vs-server divergence must come from the mutator, never the stored doc).

- Two Firestore deny tests cannot be told apart by their `PERMISSION_DENIED` text — the evaluation error fingerprints the RULE LINE, not the actor, so SSL22 and SSL40 print byte-identical verdicts. Prove non-vacuity with a FAIL-CLOSED control (same doc/id/actor/payload but the actor seated → must ALLOW) plus a DISCRIMINATING MUTATION (the suspected duplicate's branch grants → the new test flips, its neighbour stays denied), and send the REAL production payload at least once.

- Rerouting a call through a shared helper inherits the helper's DEPENDENCIES, and a test double written for the old ones is now incomplete, not merely old — `LinkifiedText` routed through `openExternalLink` gained a `canLaunchUrl` call the recording fake did not implement, and ordinary comment links stopped opening. It survived six review passes because every test run named the folders I had EDITED and the broken test lived elsewhere. Before calling a reroute "defence in depth, behaviour unchanged", diff the helper's calls against the old line, then run the suites found by grepping the DEPENDENCY's name across `test/`. And when a test only passes once you EXTEND a double, ask whether the new dependency belongs there at all before extending it — here it did not (`canLaunchUrl` answers a permission question, and iOS declares no `LSApplicationQueriesSchemes`), so dropping it left the double byte-identical to HEAD. Adding a `catch` in the same commit can convert the new failure into silence — add it after the suite is green, or run once without it (BUT-1819, 2026-08-10).

- A rules branch keyed on `parentDoc() == null` treats DESTROYED as NOT-YET-CREATED — the two states are indistinguishable to Firestore rules, so a permissive bootstrap branch silently re-opens for every conversation anyone deletes. Before shipping one, enumerate EVERY deleter of the parent (the client `allow delete` AND each CF), because the fix can only live in code: here the eviction CF deletes the conversation when the group collapses, which is the same CF whose missing roster cleanup the branch was written to contain. Pin the deleted-parent state as its own fixture, and seed the subcollection the production writer really seeds — a cleanup assertion over an empty collection passes for free (2026-08-12).

