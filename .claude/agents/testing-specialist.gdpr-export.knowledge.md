# testing-specialist — chapter: gdpr-export

- A **bundle key** added to `_buildExportBundle`, and a **cascade step** registered in
  `runAccountDeletionWithDeps` (its own registry already records prior misses). Both are
  invisible to every suite that fakes the repository or `require()`s the deleter directly. Grep
  the key / the step NAME as the FIRST step of the review. A source-derived TS drift guard does
  not close it — it proves a path is SPELLED, not that any manager calls it (BUT-1732/1957/1992,
  BUT-1800/1956). **The `_buildExportBundle` key has now shipped unpinned FOUR times, each
  round with the previous warnings visible in the same file — treat it as owed, not as a
  candidate.**
- **A WHOLE-BUNDLE WALKER test grades only the routes its own fixture SEEDS, and the routes its
  comment ENUMERATES are exactly the ones to probe one by one.** A walk that decodes the bundle,
  collects every leaf matching a shape and asserts a property over them reads as covering the
  change everywhere, and its `containsAll` anti-vacuity list makes it look audited. Probe each
  named route SEPARATELY by reverting that route alone: on BUT-2000 the generic `sanitizeForJson`
  walk — the route every whole-document section takes, and the only one with a pre-existing direct
  suite — was deletable-green over the whole account-export directory, because every fixture in
  that suite built its stamps with `DateTime.utc(...)`, for which `.toUtc()` is a no-op. **A
  UTC-only fixture corpus makes a UTC-normalising change unfalsifiable**, and the repair is one
  LOCAL fixture per branch with the expected side COMPUTED (`local.toUtc().toIso8601String()`),
  never a literal that would pin the host offset. Same round, same shape: the helper's own NEW
  function had zero `grep` hits in `test/` while reading as covered through its callers.
- **A per-FIELD normalisation list, and the fixture that seeds exactly the fields it names, is a
  closed loop that certifies itself.** A section naming `['sourceArtefact.fetchedAt']` plus a
  seed carrying that one field passes every assertion while a SIBLING field of the same document
  ships unnormalised. Grade the LIST, never the test: open the model's `toFirestore()` and check
  every nested `toJson()`/`toFirestore()` delegation — a writer that hands one child `toJson()`
  and its neighbours `toFirestore()` is the tell, because only the JSON one stringifies the
  instant. On BUT-2000 that was `tagOverrides?.toJson()` sitting one line between two
  `toFirestore()` calls, missed by two review rounds and an integration gate. The cheap
  whole-class check is a `grep -rn "toIso8601String()" lib/models/ | grep -v toUtc` census, which
  is also the guard this owes. **Close such a list by ENUMERATION, not by fixing what a gate
  found**: tabulate every nested serialiser the writer calls and mark each covered / no-stamp /
  excluded — that is what turns "the three routes we happened to find" into a claim. And when the
  list moves behind a SHARED helper taking a `prefix`/discriminator, grade the PARAMETER by
  neutering it (`p = ''`), never by deleting a call site: only that shows the two call sites are
  actually distinguished, and it reddens one section while leaving the other green (BUT-2000 P5).
- A **DETECTOR added beside a well-tested MUTATOR** reads as covered because the suite EXECUTES
  it and asserts nothing about it. A completeness signal is observable only through its FAILING
  state — grep the result flag's own name (`gdprCompliant`) rather than trusting the function ran
  (BUT-1971).

- **A FAIL-CLOSED projection (allowlist) owes its withheld-absent and kept-present assertions in
  ONE test body, because each half kills a DIFFERENT mutant and the withheld half alone is
  satisfied by the empty-return route.** Measured (BUT-2062): "always return `const {}`" kills only
  the kept half; "drop the projection" kills only the withheld half. So splitting the loops, or
  trimming one as redundant, silently retires a whole direction. A sibling case asserting only an
  absence (a planted undeclared key) needs one kept-key assertion of its own or it survives the
  empty-return mutant. Bind any hand-kept whole-document fixture to the decided set with a
  `containsAll` case — without it, a fixture that loses a key makes its absence assertion pass for
  free, and nothing else reddens.
  **Where a section distinguishes an ABSENT key ("we could not say") from a PRESENT-but-EMPTY
  one ("a true negative"), that is TWO pins and a round writes only the failure one** — a
  mutant emitting the key only when the list is non-empty then survives the whole group. Grep
  the key across `test/`; a sibling section in the same file usually already carries the "keys
  present even when empty" case to copy (BUT-2018). **The same split reaches PROSE: making a
  user-facing note CONDITIONAL creates two arms, and the round pins the failure one** — the
  healthy arm is what every real bundle carries, so an arm SWAP ships a note contradicting its
  own section with the suite green. Grep a distinctive fragment of each arm; the fix is
  `contains(<this arm>)` plus `isNot(contains(<the other>))` in each test, the second killing
  a mutant that emits BOTH. Note `isEmpty` returns false for null, so a present-and-empty
  assertion does discriminate key absence — but write `containsKey` beside it anyway, or the
  pin is invisible to the next reader (BUT-2014).
- **A fail-loud parser deriving ownership from the STORED BODY is protective on read, an Art. 17
  defect on delete** — decide erasure from the composite-id PATH, not the body. A deterministic
  composite id + body-vs-path check makes "stored==payload" checks TAUTOLOGIES.
- **A cap-decline test proves `continue`-not-`return` only if the DECLINING leg is not the LAST
  iteration** — with the over-cap direction last, both mutants leave identical state and the "the
  other direction is still swept" assertion passes on LOOP ORDER (BUT-1917).
- **A `contains('$n')` on a NUMBER is satisfied by any cap that has it as a substring** — pin the
  surrounding CLAUSE or the whole sentence. Sibling gap: deriving BOTH sides of a cap assertion from
  `getLimitForType(<type>)` cannot see the map ENTRY disappearing, and two types sharing one value
  make their type strings interchangeable — a suite that never asserts a cap ABSOLUTELY pins
  equality, never the number (BUT-2003).
- **A true/false PAIR over a new boolean pins the flag against HARDCODING and nothing else** — the
  surviving mutant derives the flag from a SIBLING field the two fixtures happen to correlate with.
  Enumerate the callee's zero-valued SUCCESS constants and add the third fixture where flag and
  sibling disagree; the diff's own new production comment usually states that case as the contract
  (BUT-1983).
### GDPR / export section contract
- **Every section needs THREE proofs**: seeded (count present, PII round-trips verbatim);
  ownership-negative (another uid's doc absent); empty-safe (`total==0` AND `containsKey('error')
  isFalse`).
- **A FOURTH: JSON-ENCODABLE** — `expect(() => json.encode(section), returnsNormally)`. A raw
  `Timestamp` anywhere means NO FILE for the subject, uncatchable per-section. Drive via the REAL
  repository over `FakeFirebaseFirestore`. Pin the EXACT key set too.
- **A new export section spans FOUR-PLUS SEAMS and the round's suite lands only on the manager one**:
  the repository's Firestore PATH (the manager suite fakes the repository, so a wrong collection
  matching zero rows is invisible — BUT-1697 dropped every shopping list that way), the manager's
  shape, the bundle WIRING in `data_export_service.dart`, and the section's `data_minimisation`
  disclosure. ONE end-to-end test in `firebase_data_export_repository_*_test.dart` — seed the real
  subcollection plus a DECOY in the neighbour, assert the bundle key — kills the first two mutants at
  once. **A written warning comment does NOT work; the mechanical grep does** (BUT-1732/1957/1992).
- **A fifth seam: a SIBLING section that DERIVES flags from the same repository read.** Grep the
  repointed repository method for EVERY manager caller, not just the section named in the ticket, and
  make the fake answer each caller's other reads (BUT-1990).
- **A new section's failure envelope is pinned only by the file's parameterised `cases` table, never
  by a hand-written `completion(isA<Map>())`** — that matcher is satisfied by the raw-leak mutant
  `return {'error': e.toString()}`, the exact defect the table exists to prevent. Adding the row is
  the whole repair, and it also grades the section PHRASE, which reaches the bundle as "Could not
  export &lt;phrase&gt;." (BUT-1760/1957).
- **A section that gains PER-LEG isolation owes three checks the diff does not show**: (1) the removed
  outer `try` was the section's only envelope guarantee — grep every throwing expression left OUTSIDE
  the per-leg `try` (the `_exports` ServiceLocator getter is the usual one, and a throw there now
  aborts the WHOLE bundle); (2) a leak fixture repointed onto the surviving seam is fine only if the
  path it LEFT is pinned one layer down; (3) a partial-vs-outright condition is unkillable by
  construction when both `if`s write the same map key — do not file that as a coverage gap
  (BUT-2003/2004).
- **The `data_minimisation` sentence IS the Art. 12(1) mitigation for whatever the section decided to
  keep, so it dies with nothing red while the kept third-party data ships on.** Every sibling section
  carrying that key has a presence pin; a section disclosing rather than promising needs the same pin,
  asserted BESIDE the passthrough test so the disclosure and the disclosed field die together. Settle
  it by grep, not probe — the key is additive. **When the withheld set lives in ONE language and the
  sentence disclosing it in ANOTHER, nothing ties them and the drift arrives at birth** — grade a
  disclosure sentence against the EXEMPT SET, and read a test named "the bundle names BOTH exempted
  collections" as a count over that set rather than a behaviour (BUT-1957/1992).
- **That pin then COUPLES the wording, so grade the DISCLOSURE against the mechanism it describes in
  the same round.** It survives TRANSLATION only by luck; re-probe per DIRECTION after translating a
  pinned sentence, and prefer the phrase that pins the CLAUSE carrying the disclosure over a word the
  rest of the sentence also satisfies. Strike an overclaiming HEADLINE clause even when it errs in the
  privacy-conservative direction — it is the sentence a later round quotes to argue a wider keep
  (BUT-1957).
- A refactor collapsing N redaction blocks into ONE loop over a literal field list moves the whole
  contract into THE LIST — a dropped name fails OPEN while the doc still claims removal (BUT-1838).
- Before crediting a redaction, check that leg's QUERY against the WRITERS — a strip on a leg
  returning zero rows is dead code AND an Art. 15 gap.
- A GDPR rationale naming a Cloud Function is a claim about another language — grep `functions/src`
  before it ships or gets copied into `ACCEPTED_DEVIATIONS.md`.
- The bundle AGGREGATOR needs its own two tests: a flag nested in a list-of-maps needs a depth-bounded
  walk; the warnings lift must key on `error` as well as `error_code`. A derived message can't be
  worded from the failure case alone — `error_code` also marks PARTIAL success.
- A field added to an existing scrub/cascade ships untested because the suite LOOKS covering — audit
  the fixture's fields, add keys + a retained-field negative.
- A cascade deleting a PARENT does NOT delete subcollections, and its residual probe usually counts
  top-level docs only — grep rules for `match /<coll>/{id}/<sub>` and every client
  `.doc(x).collection(y)`.
- Redaction paths (FCM token→prefix+`[redacted]`) outrank another happy-path test. A two-query
  union+de-dup needs FOUR fixtures: sent-only, received-only, self (both legs match), foreign.
- Truncation flags need all THREE boundary points + a positive control per leg — the highest-value
  untested case in a multi-leg section is neither leg over cap but COMBINED over. `total_count` must
  equal the SHIPPED length, not the pre-trim fetch.
- The strongest forwarding assertion is one WHOLE-MAP equality on a per-method capture, derived from
  `getLimitForType` so a typo'd `type:` is caught too. A section's wiring line is deletable-green
  unless a bundle-level test asserts `data['<section>']`.
- A section-root flag ORed over M reads while aggregating N>M record types asserts completeness for
  data never probed — count reads, not the ticket's list.
- When extracting a shared capped-read primitive, test it directly (size/trim/both
  boundaries/unknown-type/error); per-section tests then only prove wiring — grep the whole swept file
  for the old pattern.
- **Fixture note**: a LOCAL `DateTime(...)` seed is zone-safe when the expectation is the SAME
  expression production evaluates — but a "newest wins" fixture whose newest row is also the LAST row
  leaves the last-wins mutant alive; put the max in the MIDDLE of an unordered query's rows.

### Age/maturity/consent gates
- A field moved client→CF-authoritative: invert the old round-trip into an ABSENCE assertion on every
  client-write surface.
- "Infra error" vs "explicit rejection" needs a TYPED discriminator flag on BOTH branches.
- "Must NOT re-fire on resume" needs `verifyNever` AND the positive downstream effect in the SAME test.
- A "never-throws" method's contract is proven by the user-facing error field staying null on EVERY
  failure branch.

