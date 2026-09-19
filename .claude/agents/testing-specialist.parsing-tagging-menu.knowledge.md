# testing-specialist — chapter: parsing-tagging-menu

- **A green probe on a "nothing changes" test is usually GUARD-CHAIN SUBSUMPTION, not a live
  mutant** — an earlier early-return fires and the guard under test is never reached. The repair is
  a fixture that falls THROUGH the early return (the PARTIAL state, not the complete one), and it
  usually pins a real recovery invariant nobody had written down. **Subsumption runs DOWNSTREAM
  too, and that direction is invisible to a review that only reads the mutated line: a SECOND
  guard further along the pipeline coerces to the SAME fallback value, so the first guard's own
  test passes by the other route** (BUT-2067: pass 1's finite-coercion mutant survived because
  pass 2's re-coerced 1.0 round-tripped to the identical asserted number). When one ticket adds
  N guards over one value, each owes a fixture on the branch where the OTHER N−1 cannot run —
  here a unit with no conversion family, which skips pass 2 entirely. **The rival producer
  of the constant need not be another guard** — a method-wide `catch` that builds a fallback
  row with the same `amount: 1.0` makes `expect(amount, 1.0)` unable to say WHICH route ran,
  so pair it with an observable only the guarded route yields (the parsed `unit`, not `'st'`).
- **When a green result is the claim you want, prefer an ANALYTIC argument to a probe**:
  substitute the mutant value into the fixture's own arithmetic, or read that two expressions
  evaluate to the same fixture literal. Analysis outranks a green probe; a green probe outranks
  nothing. **A BEHAVIOUR-PRESERVING FAST PATH owes no pin and cannot be given one** — an early
  return that only skips work the slow path would reach the same answer on (`if
  (!tag.contains('type')) return false;` before a parse, sound because attribute NAMES are never
  entity-decoded) is unkillable by deletion; only its WRONG versions are killable, and existing
  fixtures usually already do that. Say so analytically instead of writing a reflex test.
- **A SHARED FIXTURE CONST iterated by two consumers is the right shape for two halves of one
  predicate, and it is graded by mutating EACH consumer's SEAM separately** — one list, both
  kills, or the halves can be handed different sets and drift where nothing reddens. Check each
  half has controls in BOTH directions (always-true and always-false mutants), and name the
  entries that are the SOLE discriminator of a hazard: with one such entry the whole invariant
  dies to a fixture tidy (BUT-2034/2037).
- **Grading a LOOP-HALT (`break`): deleting it is the WRONG mutant, and a fixture holding exactly
  cap+1 items cannot grade it at all.** Where the guard block's body also FALLS THROUGH to the
  normal path, deleting `break` makes the capped item emit BOTH observables and reddens a count
  assertion for a reason unrelated to halting — which reads as "the halt is pinned". `break` →
  `continue` is the mutant that grades the halt, and it stays green until the fixture holds cap+2.
  The halt's COST is a separate measurement, never the ticket's: the work SKIPPED past the cap is
  usually the expensive part, so the halt itself bought ~21 ms of a claimed ~1 s (BUT-2066).
  **Raising a fixture to catch a new mutant can trade away the kill it already had — re-run the
  OLD mutant against the NEW fixture in the same round.**
- **A REACHABILITY refutation ("that input can't get past the size guard") is decided by the
  FLOOR of the input range, not by one hand-chosen spelling.** A gate costed a "minimal" script
  tag WITH an attribute (24 B) and declared the 266k case unreachable; the real minimum is
  `<script></script>` (17 B), and the counter only needs OPENING tags (8 B) — measured reachable
  three ways. Ask what the quantifier ranges over before letting such a finding strike anything,
  and when a refutation takes one mention of a fact and leaves an equivalent one standing
  elsewhere in the file, the SURVIVOR is the tell that the premise is wrong (BUT-2066).
- **A LENIENT token in a locating regex (`>?`, an optional delimiter) usually exists to make two
  consumers agree on MALFORMED input, and no suite has a malformed fixture by default** — every
  hand-written one is well-formed. Grep the suites for the malformed shape; zero hits IS the
  finding, and the one-character deletion that breaks the stated agreement stays green.

- A predicate's SCOPE guard (suffix-not-substring) ships untested when the illustrating fixture sits
  outside its vocabulary — need the positive half PLUS the guarded shape.
- A two-sided guard (å/ä/ö boundaries) needs a discriminator PER SIDE and a recall control on
  tightening. Boundary shape is decided by the CONSUMER, not tidiness — never harmonise two
  deliberately different guards in this repo.
- **Boundary tests must straddle the EXACT flip point** (`==N` vs `N+1`); a calendar-day guard flips
  at MIDNIGHT, not a duration. **An "these two spellings agree" assertion (`f(nfd) == f(nfc)`, two
  casings, two separators) is the same rule wearing a disguise** — vacuous unless the fixture
  straddles the threshold `f` actually tests. Measure both spellings against the BOUND before writing
  the fixture, never against plausibility (BUT-1904).
- **Any normalizer/sanitizer is the IDENTITY on an already-normal fixture, and realistic fixtures
  usually are** — enumerate what the helper changes, plant one instance each. MIRROR: a "the masker
  LEFT X alone" assertion is vacuous unless X sits inside the domain the masker would otherwise
  change. Compute the fixture against the guard's BOUNDS (BUT-1897).
- **A round-trip over a `double` is bound by its fixture LIST, and Dart's own notation switches inside
  the domain** — `toString()` goes EXPONENTIAL below 1e-6 and `round()` SATURATES at int64 rather than
  throwing, while `infinity` DOES throw `toInt`. Friendly fixtures prove none of it (BUT-1891).
  **A "round trip" over a UI value is TWO seams and the doc always blames the wrong one**:
  format→parse and format→FIELD→parse. Resolve which by grepping the CALLERS — if no production line
  pairs the two functions directly, the direct round trip is the path that does not exist. **The
  field seam's TRIGGER is a KEYSTROKE, not opening the dialog**: `inputFormatters` never run on a
  programmatically seeded controller, so a `typed()` helper models RETYPING, not seeding (BUT-1912).
- **An entry added to a NEGATIVE-fixture list (decoys, deny cases, "must be stripped") inherits that
  list's NAME as an assertion about what the input IS** — so before adding one to pin a deliberate
  non-match, check what the OTHER reader of the same fact does with it. `<script
  type="application/ld&plus;json">` was added to a decoy list titled "these decoy attributes do NOT
  exempt a script"; it is non-vacuous (it is the only entry the raw pattern refuses inside its
  ALTERNATION rather than at a bound), but `html`'s named-reference table resolves `&plus;` to `+`
  (`html-0.15.5/lib/src/constants.dart:2247`), so the DOM-reading twin accepts it and the entry
  actually pins a live import-loss as if it were an attack. A knowingly-wrong behaviour belongs in a
  DEFECT test carrying its own delete-me instruction, which the same file already had. The check is
  one grep of the sibling reader, and it is the difference between a security pin and a silently
  blessed data loss (BUT-2034, 2026-09-06).

### Import & correction-capture pipeline
- SSRF host-filtering and decompression-bomb caps are running invariants across every import surface.
  A CTA/UI test proves the LABEL, not the ACTION — assert wire-level dispatch separately.
- Correction-snapshot/parse-cache keys sharing a placeholder across unrelated imports silently
  collide — test two same-kind imports in sequence.
- A wizard rebuilding an editable buffer from a prior step loses edits on back-then-forward.
- **`\b` fixes are per-REGEX, not per-file** — the lefthook `swedish-boundary-guard` can't find
  `RegExp(r'\b'+unit+r'\b')` or an ASCII-token alternation wrapped in a literal `\b`; grep the raw
  escape yourself. Check for a diacritic FOLD first.
- A safety carve-out via `return null` grows a second, untested public entry point once one caller
  lacks the fallback. A "keep the row" carve-out needs the re-inserted string run through the
  CONSUMER's normalizer, asserting the resolved KEY, not list membership.
- A boundary repair inside a shared predicate changes behaviour at EVERY call site — some decide the
  OPPOSITE of the predicate's name; grep for compensating workarounds whose comments now assert the
  fixed bug as live.
- Rate-limit metering: enumerate ALL call sites of the limited op. A circuit-breaker over a parallel
  `Future.wait` must not discard already-materialized results mid-batch.
- A cross-copy "single source of truth" test must READ every copy — an unexported duplicate still
  drifts. Windows: `/c/tools/flutter/bin/flutter test <forward-slash-path>` via Bash works directly.

### Menu & tagging domain
- Weighted-random selectors: assert WEIGHT MATH via a `@visibleForTesting debug*` hook, never the
  sampled outcome; unrated == 1★ value; ceilings via `closeTo` at extremes.
- Any feature persisting entity ids later intersected with a live collection needs a ZERO-INTERSECTION
  test — stale ids usually fail OPEN, dangerous for allergen safety.
- A "conservative fallback" is only conservative if the shared `defaults` const is a SUPERSET of the
  happy path — open it and check.
- A widen-not-replace fallback needs its PASSTHROUGH half asserted too, not just the added floor.
- Anchor/cursor guards need a fixture landing the two code paths on DIFFERENT days.
- Feature-flag OFF paths are a systemic blind spot (`tryGet<T>() ?? true`) unless a fake flag service
  is explicitly registered false.
- Denormalized-projection tests: capture via `.captured.last`; cover NULL-CLAMP (last vote removed →
  null, not 0); prove EQUAL-WEIGHTING with ASYMMETRIC inputs.

