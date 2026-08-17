# testing-specialist — accumulated knowledge

Read as Step 0 of every testing task; update when you discover a pattern, find a helper, or
are corrected. `testing-specialist.md` holds the durable DO-WRITE/DO-NOT-WRITE rules, the
production→test path map, and Mock-vs-Fake. This file holds **principles only, edited in
place — never a log, and NOT append-only about itself.**

## How to update this file

- **PRINCIPLES only, 1-4 lines.** Earns its place only if a future run would act
  DIFFERENTLY because of it. Merge into the matching section; never append to the end.
- **The raw, dated record lives ONLY in `testing-specialist.knowledge.archive.md`** —
  append-only, one `### <date> — <title>` entry per incident, verbatim.
- **This file has drifted back three times (35K→432K 2026-07-24; 262K→112K 2026-08-09;
  162K→here 2026-08-17) the same way: not dated entries (never used here) but individual
  principles absorbing worked-example detail instead of citing the ticket and archiving the
  detail.** When adding an example, ask if the sentence stands without it; if yes, archive
  the example and cite the ticket.
- **Budget ~25,000 chars** — a smell, not the control; the rule above is. Every principle
  the pre-2026-08-17 file carried survives here, merged, or verbatim in the archive's
  2026-08-17 snapshot entry.
- **The real trigger is the Read tool, not char count** — past ~250,000 chars Step 0
  silently degrades to grepping. Next time this approaches that, SPLIT `Vacuity patterns`
  out rather than compress again; it's been the largest section twice running.

## When to consult the archive

Grep it when a principle here is too terse to act on and you need the worked example (test
code, failure output); an unfamiliar mocktail/Firestore-fake discrepancy not named below; an
emulator-lane setup failure (full runbooks live there); a ticket's or area's full review
history (grep the BUT-#### or area name); a principle citing "verified non-vacuous by X" and
you want the revert-probe that proved it; or this file itself reads too compressed — the
2026-08-17 entry holds the prior version of this whole file, byte-for-byte.

---

## Principles

### Re-review economics (re-reviewing "after automated fixes")
- **Confirm bytes actually MOVED before re-reviewing** — hash + `wc -l` per file, both ends
  of the round; mtime lies. `git diff <path>` empty ≠ unmoved (staged shows only in `git
  diff HEAD`/`git show :<path>`). Hash a suite's runtime INPUT files too (a source-text
  guard reading `firestore.rules`), not just changed ones.
- **The brief is pinned to a hash and expires with it** — a `sed -n` printing different
  content at the same lines means re-Read and rebuild the mutant list; skip re-running
  mutants already measured on an unchanged hash.
- **The motion check is the map: moved PRODUCTION ∩ unmoved SUITES = unasserted by
  construction** — `git show :<path>` on such a file is a free pre-fix mutant.
- **Fix loop consumes Critical/High only** — an all-Low/Medium re-review never changes.
  Apply zero-risk test-only fixes yourself; never edit production in a review pass.
- **"Duplicate test" is measurable**: mutate the guarded expression, delete only a strict
  subset kill set THROUGH THE SAME SEAM. Exceptions: reaches the sole fail-closed lookup via
  a different seam, or is another test's CONTROL. Grade two suites for one class by what
  only ONE holds — the tidy mirror suite is often the sweep; the "stale duplicate" can carry
  the security/a11y groups nobody rewrote. Never retire by path convention alone.
- **A live parallel session poisons a battery both ways**: their edits are FALSE KILLS in
  your run (attribute by test name vs mutant blast radius, re-hash before verdict); an
  identical md5 + fresh mtime is THEIR mutate-and-restore, and your `finally` can clobber
  their in-flight write — prefer a production-free `test/`-side probe beside a live session.
- **The tree moves DURING your round** — re-read before filing (a stale stack-trace line
  number is the cheapest tell); back up/restore your own probes in ONE Bash call.
- **"Only `dart format`" is provable, not assumed**: walk `git cat-file --batch-all-objects`,
  compare whitespace-stripped bytes blob-to-blob (not blob-to-disk — CRLF differs by one
  byte/line). The formatter can insert a trailing comma, so fall back to raw `diff` if a
  token-signature match misses a genuine format-only file.
- **"Staging — resolved" isn't resolved until `git show :<path>` diff is empty** — an index
  can sit behind graded bytes across rounds; close every round naming unstaged hunks.
- **An analyze finding contradicting the source you just read, or a suite passing against
  code analyze says can't compile, means re-md5sum BOTH files** — a timestamp-preserving
  restore can leave stale bytes running.
- **"Would the RULES allow this?" — just run it**: a throwaway `_zz_probe_*.ts` under `npx
  firebase emulators:exec --only firestore --project demo-test` names the rule line in ~90s;
  add a control arm.
- When a parallel session lands a test for the same guard, delete yours with a pointer
  comment. A measured claim in a comment is one command to verify — agreement across files
  often just means one was copied.

### Project-specific test infrastructure (full detail in `testing-specialist.md`)
- Production ServiceLocator bridge: `production.ServiceLocator.initialize(DIContainer())`
  in `setUpAll`; both ServiceLocator classes share one `GetIt.instance`.
- `MockUnifiedRecipeService.setRecipeState()` defaults `isInitialized: false` — pass it.
- Debounced VM: `fakeAsync` + `async.elapse(300ms)`; `executeDebounced` fires 3
  notifications. `test/views/` is journey-test territory (owned by `e2e-test-specialist`).
- **A repoint to `collectionGroup(...)` is HALF a fix** — needs a `fieldOverride` with
  `queryScope: COLLECTION_GROUP` or FAILED_PRECONDITIONs; `deploy --force` prunes anything
  absent from `firestore.indexes.json`. Suite needs three arms (override exists at group
  scope, exact set survives delete+add, source still spells the field). Register the npm
  `test:*` script in the same edit.
- Source-text assertion suites must strip comments first, or a bare `includes` stays green
  after the setting is deleted; probe non-vacuity with a STRING mutant, never a file mutant.
- **A mocktail matcher goes vacuous only when a named arg's value stops equalling its
  DEFAULT** — `verifyNever` is the dangerous direction: a non-default named param can never
  match the omitted-param form, so the guard is UNFAILABLE. Spell every named param.
- A poll-until-condition loop discriminates only if the assertion sits AFTER it, polling the
  LAST observable step. `retry:true` owes a reachability read of `isCascadeEventExpired` as
  the handler's FIRST statement, or a deref above it escapes the bound.

### Coverage decisions
Codecov: 60% project / 70% new patches / 2% drop tolerance — floors, decided 55% project
(2026-07-11); don't file generic "raise coverage" tickets.
- **Open a review by grepping each NEW TOKEN into a token→files table** (~30s). Zero files
  IS the finding; hits only in an extracted class's own suite means the composing line in
  the CALLER's suite is still unproven (BUT-1838: a `copyWith` carry, a DTO write asymmetry,
  a query filter — three sibling suites untouched).
- When a fix SPLITS one write/event across destinations, or teaches a method a new
  side-field, grep every WRITER/reader's OWN SUITE (not `lib/`) — the list grows mid-round.
- **A collection's DOCUMENT-ID SCHEME change (deterministic→auto-id) breaks every reader
  that addresses/dedupes by it, invisibly** — grade writers keyed on `doc(x)`, mergers doing
  `byId[doc.id]=doc` (silent double-render), and field-keyed cascades (can lose their
  address if spellings never matched).
- A cross-language literal contract (a CF-written marker Dart matches) is usually pinned
  consumer-side only — a doc comment claiming sync is not a test; grep for the enforcing one.
- **"X was REPOINTED" — run X's PRE-EXISTING suite even if the ticket omits it.** It's
  written against the retired behaviour and usually passes VACUOUSLY (seam uncalled, fixture
  unseeded) rather than failing. Rewrite with a fixture where old/new DISAGREE, seed the
  new, assert the retired seam unreached (BUT-1838: 6/6 red after, 0 before).
- A capped/OR'd flag over N sources needs its recall control rebuilt when a source is
  added/removed (BUT-1801 43/43 survived; BUT-1832 9/9) — grade any capped section by the
  below/at/over trio.
- A fan-out loop + accumulator is one untested input whenever every fixture is a singleton
  — close at the outer layer with 2-cut+1-retained via a capture recorder, never
  `verifyNever` beside a positive. Dead work (unread map, unused helper) reads as coverage —
  file a deletion ticket.
- Two branches sharing one guarded block need separate inputs; one variable at N call sites
  needs proof PER SITE (`any(named:)` survives mutants on the other sites). A comment naming
  two shapes one guard catches is two claims — the second is often unreachable-but-true;
  reachability is a producer question.
- **Fixture-shape family**: the fixture's own shape answers for the code. An accumulator off
  `.first` hides its loop unless the first item is interior on every axis; enumerate every
  field production READS, override each independently.
- A repository suite where every fixture lives in ONE scope can't see its scoping `where` —
  and habitually leaves inherited CRUD (`read`, `readAll`, `watchAll`) untested though it
  skips every filter the finders apply.
- A defensive DECODE helper's null branch needs the ABSENCE mutated, not the value, plus a
  wrong-TYPE row. A deterministic composite id + body-vs-path check makes "stored==payload"
  checks TAUTOLOGIES — isolate the one conjunct that can still decide.
- **A fail-loud parser deriving ownership from the STORED BODY is protective on read, an
  Art. 17 defect on delete** — the forged row becomes the one doc its owner can't erase;
  decide erasure from the composite-id PATH, not the body.
- **Guard-chain subsumption, three directions**: BACKWARD (an earlier guard pinned by
  nothing because a later one refuses everything it does), FORWARD (fixture must clear
  every downstream refusal WITH SLACK, never at an exact tie), SIDEWAYS (a new guard can
  unpin an older filter downstream). Total subsumption = comment, never a test. Run "which
  mutants killed nothing" and its mirror once per file.
- A guard inside a loop has a POSITION (before/after the accumulator update); one above a
  pre-existing early-return is blind to every fixture that falls through — usually the
  worst leak (raw content unfiltered).
- **A dropdown widened to keep an off-vocabulary value needs FOUR fixtures**: off-list-
  untouched; pick-something-then-pick-back (only killer of keying the list off current vs
  stored selection); empty-stored; literal vocabulary pin (BUT-1858).
- A flag selecting between two values is pinned by both arms over one fixture with
  observably different values — no production mutant needed. A nullable override deriving
  its default from a nullable payload owes a third arm: the EMPTY (non-null) payload.
- "Declines/falls back" needs `equals([input])`, not `hasLength` — catches truncation. A
  test named after an input must assert that input's VALUE.
- "X does NOT happen" needs proof the code reached where X could — "no write" can mean
  skipped OR identical values; count writes, positive control same test.
- A guard skipping a per-parent subcollection probe is unfailable when the probed doc
  doesn't exist — repair with a TRAP row at a path production never writes, spelled with
  production CONSTANTS (a literal drifts dead on a rename).
- **A write the RULES refuse is 100% green under mocks, and its TWINS stay refused — grep
  the file, not the ticket.** Every field the write touches: grep `firestore.rules` for a
  deny; each surviving twin owes a comment naming the rule LINE.
- A source-text guard pinning `keys().hasOnly([...])` has five vacuity seams: widest
  payload; complete writer set (forever); anchor sentinel checked against the NEXT match,
  not global uniqueness; blind to the `hasAll` mirror; can't see a SWAP (delete+add, count
  unchanged). Prove by neutralising the call and watching the WRONG-LIST message (BUT-1830).
- The client-side twin: an injected `Future<bool> Function(T)` stubbed true can't show what
  PRODUCTION binds actually rejects — resolve the argument to its terminal implementation,
  owed once per SPRINT (a feature can ship end-to-end while every write stays refused).
- A CF split into pure core + DI'd orchestrator ships the orchestrator untested — a `noop`
  verdict can't see "writes no second message"; the missing fixture is always the
  outsider-vs-member split the gate eats first.
- A guard replicated across sibling fields is tested on one field only — enumerate fields,
  one fixture per field per branch. `hasRequiredFields` checks presence+non-null ONLY, never
  TYPE — every shape check needs a companion `is! Map`/`is! List` row.
- The in-memory version DELETES data instead of failing to write it (a model field + N
  field-by-field rebuilds) — `copyWith` is the durable fix, it can't forget what it never
  enumerates; assert an UNTOUCHED member survives.
- Notification `when(...)` stubs are not coverage (the wrapper swallows everything incl.
  `MissingStubError`) — only `verify(...).called(n)` + `verifyNever` on the retained member.
- A test passing an OPTIONAL override bypasses the changed default branch — grep every call
  site. Worst case: a remote KILL SWITCH override present in every test by construction, so
  neither the real lookup nor the defaults entry runs anywhere.
- A defensive bound on an injected collaborator is mutation-dead when every fake answers
  immediately — `grep 'fakeAsync\|Completer\|TimeoutException'` zero hits IS the finding. A
  new conjunct beside an existing gate is born mutation-dead without a fixture passing the
  OLD gate and failing ONLY the new one.
- The CONDITIONAL-IMPORT SEAM: `flutter test` compiles the native branch into every unit
  test, web stub into none — the shipping impl runs in zero tests if every test injects a
  fake through the `_testX` seam. Same for `Platform.isX`: guard and no-guard agree on every
  observable that doesn't count calls.
- A "no unit test can see this" comment is a claim — split the untestable PREMISE (rules
  denial) from the testable BEHAVIOUR (the catch is not).
- A COPY test stopping at the confirmation dialog pins the words, not the branch — the
  decision usually lives on a surface it never renders (both snackbars, title, body).
- `MaterialApp(routes:{...})` never reads `settings.arguments` — nav tests on it pin the
  SHAPE vacuously; push through `onGenerateRoute` mirroring the real decode.
- Two l10n keys with the SAME string make `find.text` unfalsifiable — grep the ARB.
- "Returns null on X" needs a positive control in the same fixture — where every layer
  swallows to null, null is the NORMAL shape of denied/offline/deleted, so grep the suite
  for `async => null` on the loader; zero hits IS the finding.
- Last-wins/precedence tests need the LOSER asserted absent, with inputs where the wrong
  answer genuinely differs. A partition/drift-guard test from the SAME curated list the impl
  was written from cannot fail — probe with a real sibling name.
- Coalescing-across-calls: a fixture whose injected reader returns a CONSTANT can't see it —
  model the read, drive N calls on an advancing clock. A parameterised loop over failure
  codes proves one leg N times if the fixture starts EMPTY — need a fixture failing the fast
  path's own predicate.
- A predicate's SCOPE guard (suffix-not-substring) ships untested when the illustrating
  fixture sits outside its vocabulary — need the positive half PLUS the guarded shape.
- Round-trips must drive the REAL serializer, never `copyWith`; a DateTime sentinel needs
  zone normalisation checked via round trip.
- A two-sided guard (å/ä/ö boundaries) needs a discriminator PER SIDE and a recall control on
  tightening — classify by which side the diacritic sits. Boundary shape is decided by the
  CONSUMER, not tidiness — never harmonise two deliberately different guards in this repo.
- A hand-built narrow write payload needs BOTH the carried and omitted keys pinned — for the
  omission, drive a mutator that moves the excluded key as its OWNER.
- Firestore whole-number aggregates store as `int` — `as double?` throws and silently drops
  the row. A guard spanning TWO user-facing shapes ships pinned on one — the diff's own
  "accepted consequence" sentence usually names the unpinned shape.

### Helpers that exist (grep before writing a new one)
| Helper | Path |
|---|---|
| `setupUnit()`, `teardownUnit()`, `setupUnitWithProductionLocator()` | `test/test_support/base_unit_test.dart` |
| `TestTimestampProvider`, matchers | `test/test_support/timestamp_test_helper.dart` |
| `useEmulatorLane`, `firestoreForLane()`, `clearLane()`, `emulatorOnlySkip` | `test/test_support/emulator_lane.dart` |
| `butleryGolden(...)` | `test/widget/golden/golden_helper.dart` |
| `createLocalizedTestApp(...)` | `test/infrastructure/helpers/widget_test_app.dart` |
| All production mocks | `test/infrastructure/mocks/production_mocks.dart` |
| Typed mock factory | `test/infrastructure/factories/mock_factory.dart` |
| `MockMenuService` (NOT in production_mocks.dart) | `test/infrastructure/mocks/service_mocks.dart` |

### FakeFirebaseFirestore vs emulator decision tree
| Behaviour under test | Use |
|---|---|
| Plain reads/writes/queries, `collectionGroup`+equality, `orderBy` on a present field | `FakeFirebaseFirestore()` in `setUp` |
| `FieldValue.increment`, `serverTimestamp` (usually), transactional writes, security rules | Emulator lane, or `firestore-rules-tester` |
| `GetOptions.source` | NOT testable — fake ignores `source`; real Firestore THROWS `unavailable` on a cache MISS instead of `exists:false`, so `if (!cached.exists) throw NotFound` is DEAD in production. Assert the outcome contract only. |
| `snapshot.metadata.isFromCache` | NOT reachable — fake answers every read `false`. `grep isFromCache <suite>` zero hits IS the finding. Stage via sealed-class mock on snapshot+metadata. |
| Read of a doc that may NOT EXIST, rules-guarded collection | NOT testable, and the fake's answer is the OPPOSITE of production's — a rule dereferencing `resource.data` denies a `get` on a missing doc. Test a "probe A, fall to B" helper with a ref whose `.get()` throws. |
| Service that wraps Firestore | Mock at the repository interface |
| Dotted-path `update({'core.x': v})`, `update()` on a MISSING doc | **Faithful.** Dotted keys write nested with siblings preserved; `FieldValue.delete()` on an absent key is a silent no-op, so seed the field first. `update()` on a missing doc throws and creates nothing — `expect(oldPathDoc.exists, isFalse)` is a PERMANENT PASS: documentation, not coverage. |
| A NULL-VALUED KEY via `set(..., merge: true)` (incl. `batch`) | **Faithful, `containsKey` is real coverage.** Key present, value null, siblings preserved; null OVERWRITES a stored map. So "writer must emit key even when null" is testable at module level (verified 2026-08-13). |
| Query PREDICATE SHAPE, incl. `where('<map>.<uid>', isNull: false)` | **Exact.** Build the REAL repository over the fake; dotted keys, `isNull`, `arrayContains` all work. `isNotEqualTo: null` adds NO condition in the real SDK and makes the fake THROW — never accept a comment claiming map-path keys unsupported. |
| A negative "gets nothing" test | Mutation value only when the SUT doesn't swallow errors — behind a catch-all `return []` it's a recall control, and the positive test is the whole guard. |
| A per-ROW transactional write (doc id == uid) | Transaction wrapper is deletable-green by construction — the suite really pins the DOC-ID DERIVATION. Keep the two-actor test as CONTROL; put the permission half in the rules lane. |
| `FakeFirebaseFirestore.runTransaction` | NO-OP PASSTHROUGH, never proves atomicity — handler runs once, `SetOptions` dropped, `timeout`/`maxAttempts` ignored. Use a bare read-modify-write; a truly interleaved test fails on the fake, passes in production. |
| `test/integration` | Nothing in CI passes `--dart-define=USE_EMULATOR=true` over it — every lane test skips everywhere, never coverage. `flutter test` is plugin-less; the lane needs an `integration_test` project. Ticket it, don't "just add the flag." |
| `serverTimestamp()` in `batch.set(..., merge:true)` | Trips the fake on some shapes — never a valid `skip:`. Fix: `FieldValueFactoryPlatform.instance = MockFieldValueFactoryPlatform();` in `setUp`. |
| `permission-denied` | Fake can't fire it — skip only when the branch is a bare `if (e.code=='permission-denied') return null;` above a rethrow, no side effects. |
| `orderBy` field | Seeded fixture must include every field the `orderBy` reads — the fake silently drops docs missing it. |
| `collectionGroup` | Safe on the fake for index-free `.limit(N).get()` with no `where()`, and (^4.1.0+1) for plain equality. |

### Conscious-skip taxonomy
- Static-method orchestrator: skip only when ALL hold — ≤3 calls, no injection seam, each in
  its own try/catch, no branching beyond the catches.
- Compiler-enforced sync contract (renamed l10n/analytics constant fails gen-l10n/analyze
  first); pure-nav affordance (route constant is compile-checked).
- Nth surface adopting an already-proven predicate: prove via `git diff --staged
  --name-only` — no new surface if the pure-logic file is absent.
- `SemanticsService.announce` in a fire-and-forget handler is skippable UNTIL the view gains
  a DI seam — dated, not permanent. A comment-only diff owes no test IF the claim is already
  pinned by a fail-loud spy — verify, don't trust.
- **A "sole guard"/KNOWN-GAPS comment is a CLAIM until a test enters that exact branch** —
  verify against the model's SERIALIZER, never read a rules subcollection match or a
  cascade's defensive sweep as evidence the client writes it. A rationale citing a backend
  propagator/cascade is two greps (collection constant, then the query field) and both
  usually fail.
- A pure removal of dead code owes no test when a repo-walking structural lint holds the
  invariant — verify the lint is byte-identical to HEAD and the pre-fix set had exactly ONE
  element.
- A behaviour-neutral respelling owes no test — earn that by MUTATION-COUNTING the existing
  suite, then fix the comment/header claim the respelling falsified.

### Vacuity patterns — the recurring ways a "passing" test proves nothing
The single most repeated finding across two months of review.
- **MASTER RULE: name every OTHER mechanism that could satisfy the assertion, then build the
  fixture where they DISAGREE. Every pattern below is an instance.**
- Circular determinism (calling the same pure function twice, or deriving expected from the
  const under test) — pin the literal OUTPUT.
- Sibling-OR-branch short-circuit: for `if(A) return true; if(B) return true;`, check no
  fixture satisfies a branch other than the named one.
- Fake-default-same-as-expected: use a sentinel no real caller would pass.
- **DESERIALIZER-DEFAULT vacuity**: a save-retrieve test asserting the parser's own
  `defaultValue` is unfailable — missing doc, dropped write, empty map all answer the same.
  Tell: a "returns defaults" sibling test with a byte-identical assertion list.
- **Production twin**: a "must not OVERWRITE" fixture holding the value the code would write
  anyway. Widest instance: an untouched-save test over `copyWith(f: _selection)` — only
  picked≠stored can see a dropped `f:` argument (BUT-1858 test 7).
- A NULLABILITY WIDENING (`T x=d`→`T? x=d`) trades a compile guarantee for a test — trace the
  `??` chain to what the mutant does downstream (a dropped initialiser can store a SILENTLY
  DERIVED value, not "no value").
- A collection-SHAPE assertion instead of the skipped element's VALUE (a Map can't hold a
  dup key, so "appears once" can't distinguish skip-vs-overwrite).
- A Fake with two branches answering the same success value, driven by one UI flag, eats a
  routing test whole — test the FAILURE arm. An enum-driven `defaults()` owes a
  KEY-SET-COMPLETENESS test — a forgotten member is DEAD, not "off by default."
- Negative-scope claims need a negative assertion against `toMap().keys`, not a render check.
- **"No write was issued" is the commonest untestable claim** — before/after can't tell
  skipped from identical-value. Count writes, positive control same test.
- `findsNothing` needs a co-asserted positive render. A widget whose only access control is
  an early-return is untested if every pump uses the same actor constant.
- **An ORDERING fix (resolve A before B) is mutation-dead whenever the suite INJECTS A** —
  the testable constructor param resolves A synchronously, hiding a reverted fire-and-forget
  order (BUT-1838: 11/14 files, revert left all 45 green).
- Inherited-authorization-discarded: no test sees it while the permission fake defaults
  true. Tell: tests changing `currentUserId` on one double, not the permission double.
- A flag-lifting aggregator owes an EXACT-SET assertion + absence control, not `contains`. A
  two-layer fix (N emitters + chokepoint) is tested only at the chokepoint — a control, not
  coverage; each emitter owes its own suite's test.
- Boundary tests must straddle the EXACT flip point (`==N` vs `N+1`); a calendar-day guard
  flips at MIDNIGHT, not a duration. `DateTime.utc(...)` fixtures can't assert zone
  normalisation — feed `Timestamp.fromDate(x).toDate()`.
- Any normalizer/sanitizer is the IDENTITY on an already-normal fixture, and realistic
  fixtures usually are — enumerate what the helper changes, plant one instance each.
- A measurement harness's failure mode is a confident number from a broken rig — demand a
  positive control that the engine produced anything at all.
- A hand-rolled double MODELLING a write's effect (not applying its payload) is blind to
  field NAMES, and a migration IS a field name — union under `Object.keys(op.data)[0]`.
- "Returns null on permission denial" needs a positive control same fixture — where every
  layer swallows to null, it's the NORMAL shape; grep for `async => null` on the loader.
- A `??` wiring needs a fixture where the arms DISAGREE. "Does less work now" needs a
  discriminator (something only the naive path pulls in), not a convergence test.
- A guard classifying OLD vs NEW mutation is untested when every fixture base is EMPTY or
  same LENGTH — need the MIXED case. Same for a re-found index after `await` (identical to
  stale when the collection has one element) and a field-exclusion decision (byte-identical
  round-trips hide it).
- A SCOPE guard (suffix-not-substring) needs a fixture inside the vocabulary that fails ONLY
  on the guarded shape.
- A two-sided guard needs a discriminator PER SIDE and a tightening needs a recall control —
  print each candidate pattern over all three fixture histories (old-matched, new-matched,
  never-matched) before writing rationale.
- A hand-built narrow payload needs both carried and omitted keys pinned. A `continue`-style
  skip-list disagrees with its absence only when a skipped token shares a LINE with a
  matched one — if that's also where the real answer is lost, it's a design finding.
- A PLACEMENT claim un-pinnable when wrong-placement is benign — say so, don't force a test.
  A signature-only narrowing opens no gap by construction — the question is whether the
  DISPATCHER calls the narrowed overload (2-arm replica, 10s).

### Fake/Mock idioms + the ServiceLocator/GetIt bridge
- `class X implements Y` with concrete bodies is a legitimate Fake; the mocktail ban is
  specifically a concrete `@override` on `extends Mock`. `extends <ConcreteClass>` with an
  override is a legitimate subclass SPY, not the banned pattern.
- **`verifyNever(() => mock.f(any()))` is UNFAILABLE against non-default NAMED args** —
  noSuchMethod fills omitted params with declared defaults, so `unit:null` never matches
  production's `unit:'st'`. Spell every named param as `any(named:'x')` (BUT-1858; positive
  `verify` unaffected).
- mocktail is LAST-REGISTERED-WINS — wildcard-then-specific `when` is a genuine repoint
  discriminator; reversing the lines silently duplicates the other test.
- When production adds a call to a NEW repository method, an existing `extends Fake` suite
  silently grades that leg's CATCH branch (noSuchMethod throws, swallowed) — grep the new
  method name across `test/`; zero overrides while production calls it IS the finding.
- A `-1` sentinel default on a Fake means two things and only one is self-proving — pick the
  arm, write the expectation, or it's just a recorder nobody reads.
- Lazy `tryGet` fields cache on construction — register fakes BEFORE constructing the SUT.
- `verify(f(captureAny()))` marks calls VERIFIED, so a later `verifyInOrder` over the same
  method fails "not found" over an all-verified list — capture THROUGH `verifyInOrder`
  instead. Fire-and-forget writes to `FakeFirebaseFirestore` need microtask draining, not a
  real-time wait.
- **The GetIt→DIContainer bridge gotcha (recurring: analytics, tag-overrides, correction-
  snapshot, import chokepoints)**: many singletons resolve via PRODUCTION `ServiceLocator`,
  not `TestServiceLocator` — a mock there is invisible. Fix:
  `prod.ServiceLocator.initialize(DIContainer())`, register into `GetIt.instance` after;
  tearDown unregisters+resets.
- A hand-rolled CF query double must be IMMUTABLE once `.where()` is called twice — a
  mutable `q` aliases both legs. A double keyed on flat `"col/id"` paths CANNOT represent a
  subcollection; give it a real `ref.collection()`.
- A new fire-and-forget telemetry call at a chokepoint ships with ZERO tests by default —
  add fires-once (happy) and fires-nothing (negative); trace the resolution chain, "no seam"
  is usually false. The test that matters passes NO injected seam.
- A funnel-attribution fix has two directions — an idempotent regenerate re-counts unchanged
  lines on rerun; assert the second run logs only the DELTA.
- A defaulted `String source='manual'` param is worse than silence — grep the CALLERS of the
  newly-tagged method, not the ticket's named path.
- A safety-critical method covered ONLY via a caller's `verify()` proves WIRING, never the
  CONTRACT — grep the method name at its own layer. Mirror: an opt-in param's tests can
  prove the contract while zero production callers pass it — demand a named entry point.
- A REQUIRED param moves the job from "is it wired" to "is the DECLARED value right" — test
  the UI's CHOICE of value and its rebase after a self-triggered change.

### Disposal & lifecycle guard idioms (BaseViewModel family)
- `BaseViewModel` already guards disposal twice — only test a subclass's OWN guard when it
  protects an observable effect no base guard blocks.
- Two quadrants: delegate disposed BY this VM → `returnsNormally`+`notified==0`; delegate is
  a SHARED SERVICE outliving the VM → `returnsNormally` is VACUOUS, assert the service's
  error SURVIVES disposal.
- A class with both local `_isDisposed` and inherited `isDisposed` must use the SAME flag
  its own callbacks use. `executeAsync` RETHROWS on failure — prove via a caller retrying
  only on THROW.
- `dispose()` clearing DATA (not just controllers) opens a use-after-dispose window for a
  still-running op — dispose mid-operation, assert the write still carries user data.
- A "disposes its children" test asserting only `returnsNormally` is vacuous — materialize
  the child, assert it's dead after (`addListener`→`throwsFlutterError`).
- A suite whose every stubbed stream is already COMPLETING pins no cancellation — use a
  `StreamController`, assert `hasListener` true-before/false-after.
- A throw-on-disposed guard inside a shared builder is safe only at callers that catch —
  `notifyListeners()` post-dispose is DEBUG-ONLY, so never conclude "unreachable" from a
  debug-mode trace.
- A `manager.dispose()` fix's wiring half ships untested — delete the OWNER's `dispose()`
  line as a probe; if the suite stays green, the fix is deletable. The flip is the returned
  future THROWING instead of resolving null.
- A `Completer` whose `.future` is never awaited is dead plumbing — grep for `.future`. A
  polling loop returning a cached `_lastResult` drops the second caller's work.
- Any concurrency fix needs the second caller actually LAUNCHED (warm-up, gate on a
  `Completer`, launch B, settle) — assert `same(inFlight, queued)`, `queued==null`
  post-dispose, and exactly ONE persisted id from the overlapping pair.

### Contract pinning: selectors, ordering, equality, revert
- Every `field==expected` selector needs THREE pins: matched-key reused, unmarked-collision
  untouched, marked-for-different-key untouched+new created.
- `==`/`hashCode` need an equal pair AND a deliberately-unequal instance — watch `hashCode`
  hashing a collection by IDENTITY while `==` compares CONTENT.
- A numeric tuning constant is pinnable only in the direction that DELETES content — never
  manufacture a fixture just to satisfy a mutant.
- A colour pin is legitimate only when the row's semantics ARE the colour, and must name the
  theme TOKEN, not a raw hex — grep the hex across the theme's own fields too.
- `tester.widget<T>(find.byIcon(...))` throws StateError on "more than one," not a clean red
  — scope it. Ordering needs `verifyInOrder`, not call-count. Revert-to-start: mutate, THEN
  revert, then assert.
- A `void Function`→`Future<void> Function` fix is pinned PER CALL SITE — Dart drops the
  future behind a `void` param silently, so one dropped `await` is invisible unless the
  injected sink is made to FAIL.

### Import & correction-capture pipeline
- SSRF host-filtering and decompression-bomb caps are running invariants across every
  import surface. A CTA/UI test proves the LABEL, not the ACTION — assert wire-level
  dispatch separately.
- Correction-snapshot/parse-cache keys sharing a placeholder across unrelated imports
  silently collide — test two same-kind imports in sequence.
- A wizard rebuilding an editable buffer from a prior step loses edits on back-then-forward.
- **`\b` fixes are per-REGEX, not per-file** — the lefthook `swedish-boundary-guard` can't
  find `RegExp(r'\b'+unit+r'\b')` or an ASCII-token alternation wrapped in a literal `\b`;
  grep the raw escape yourself. Check for a diacritic FOLD first — folded text has no å/ä/ö
  left to open a boundary.
- A safety carve-out via `return null` grows a second, untested public entry point once one
  caller lacks the fallback. A "keep the row" carve-out needs the re-inserted string run
  through the CONSUMER's normalizer, asserting the resolved KEY, not list membership.
- A boundary repair inside a shared predicate changes behaviour at EVERY call site — some
  decide the OPPOSITE of the predicate's name; grep for compensating workarounds whose
  comments now assert the fixed bug as live.
- Rate-limit metering: enumerate ALL call sites of the limited op. A circuit-breaker over a
  parallel `Future.wait` must not discard already-materialized results mid-batch.
- A cross-copy "single source of truth" test must READ every copy — an unexported duplicate
  still drifts. Windows: `/c/tools/flutter/bin/flutter test <forward-slash-path>` via Bash
  works directly.

### GDPR / export section contract
- **Every section needs THREE proofs**: seeded (count present, PII round-trips verbatim);
  ownership-negative (another uid's doc absent); empty-safe (`total==0` AND
  `containsKey('error') isFalse`).
- **A FOURTH: JSON-ENCODABLE** — `expect(() => json.encode(section), returnsNormally)`. A
  raw `Timestamp` anywhere means NO FILE for the subject, uncatchable per-section. Drive via
  the REAL repository over `FakeFirebaseFirestore`. Pin the EXACT key set too.
- A refactor collapsing N redaction blocks into ONE loop over a literal field list moves the
  whole contract into THE LIST — a dropped name fails OPEN while the doc still claims
  removal (BUT-1838: `memberSince` had zero coverage).
- Before crediting a redaction, check that leg's QUERY against the WRITERS — a strip on a
  leg returning zero rows is dead code AND an Art. 15 gap.
- A GDPR rationale naming a Cloud Function is a claim about another language — grep
  `functions/src` before it ships or gets copied into `ACCEPTED_DEVIATIONS.md`.
- The bundle AGGREGATOR needs its own two tests: a flag nested in a list-of-maps needs a
  depth-bounded walk; the warnings lift must key on `error` as well as `error_code`.
- A derived message can't be worded from the failure case alone — `error_code` also marks
  PARTIAL success.
- A field added to an existing scrub/cascade ships untested because the suite LOOKS
  covering — audit the fixture's fields, add keys + a retained-field negative.
- A cascade deleting a PARENT does NOT delete subcollections, and its residual probe usually
  counts top-level docs only — grep rules for `match /<coll>/{id}/<sub>` and every client
  `.doc(x).collection(y)`.
- Redaction paths (FCM token→prefix+`[redacted]`) outrank another happy-path test. A
  two-query union+de-dup needs FOUR fixtures: sent-only, received-only, self (both legs
  match), foreign.
- Truncation flags need all THREE boundary points + a positive control per leg — the
  highest-value untested case in a multi-leg section is neither leg over cap but COMBINED
  over. `total_count` must equal the SHIPPED length, not the pre-trim fetch.
- The strongest forwarding assertion is one WHOLE-MAP equality on a per-method capture,
  derived from `getLimitForType` so a typo'd `type:` is caught too. A section's wiring line
  is deletable green unless a bundle-level test asserts `data['<section>']`.
- A section-root flag ORed over M reads while aggregating N>M record types asserts
  completeness for data never probed — count reads, not the ticket's list.
- When extracting a shared capped-read primitive, test it directly (size/trim/both
  boundaries/unknown-type/error); per-section tests then only prove wiring — grep the whole
  swept file for the old pattern (silent clipping in un-swept siblings is worse than the bug).

### Settings-hydration & sentinel-parameter template (recurring: BUT-1220, 674, 1322, 1610)
Any field persisted via a private settings sub-doc needs: hydration seeding the sub-doc
directly; a corrupt-value test ALSO asserting a sibling merged field survives (one
`copyWith` in one try/catch can abort the whole merge); a save-path test asserting the
settings doc has it and the public doc does NOT, plus a round trip; one test per
serialization surface. Sentinel params (`Object? field=_unset`) need both quadrants:
omit→preserved, explicit-null→cleared. Capture the forwarded ARGUMENT IDENTITY, not a
downstream no-op.

### Age/maturity/consent gates
- A field moved client→CF-authoritative: invert the old round-trip into an ABSENCE
  assertion on every client-write surface.
- "Infra error" vs "explicit rejection" needs a TYPED discriminator flag on BOTH branches.
- "Must NOT re-fire on resume" needs `verifyNever` AND the positive downstream effect in the
  SAME test.
- A "never-throws" method's contract is proven by the user-facing error field staying null
  on EVERY failure branch.

### Menu & tagging domain
- Weighted-random selectors: assert WEIGHT MATH via a `@visibleForTesting debug*` hook,
  never the sampled outcome; unrated == 1★ value; ceilings via `closeTo` at extremes.
- Any feature persisting entity ids later intersected with a live collection needs a
  ZERO-INTERSECTION test — stale ids usually fail OPEN, dangerous for allergen safety.
- A "conservative fallback" is only conservative if the shared `defaults` const is a
  SUPERSET of the happy path — open it and check.
- A widen-not-replace fallback needs its PASSTHROUGH half asserted too, not just the added
  floor — a preserved field can be silently swapped for empty.
- Anchor/cursor guards need a fixture landing the two code paths on DIFFERENT days, or a
  single-recipe fixture hides the off-by-one.
- Feature-flag OFF paths are a systemic blind spot (`tryGet<T>() ?? true`) unless a fake
  flag service is explicitly registered false.
- Denormalized-projection tests: capture via `.captured.last`; cover NULL-CLAMP (last vote
  removed → null, not 0); prove EQUAL-WEIGHTING with ASYMMETRIC inputs.

### Firestore cost, index & cascade patterns
- A declared composite index needs its own assertion (fakes can't catch a missing one) —
  assert `queryScope` alongside field order.
- A merged/idempotent cascade `update()`ing a doc it assumes exists can throw NOT_FOUND and
  fail the whole batch — test the gating doc exists but the target does not.
- A dotted-path transactional `update` needs an UNRELATED sibling field asserted SURVIVING.
- A CF trusting a doc field for a security decision is only as strong as the Firestore RULE
  validating it on create.

### CF/TS-specific
- A new emulator-integration test needs wiring on THREE fronts: the granular
  `test:integration:*` script, the composite CI chain, and the workflow's `paths:` trigger —
  unit runners auto-discover `test:*` but EXCLUDE those prefixes.
- Order the existence assert BEFORE the first dereference of a possibly-missing doc.
- A fix swapping a hand-rolled throw for a shared enforcer ships deletable-green whenever
  the suite injects that enforcer as a seam, and the AUDIT ROW is unassertable if the logger
  bypasses the module's own test seam (`admin.firestore()` direct vs `__setFirestoreForTest`).
- A relational CONFIG pin stays green when both numbers move together — anchor one literal.
- A ts-node mutant removing the LAST use of an import doesn't compile (`TS6133`) and prints
  ZERO test lines, which reads as "the whole suite died" — keep the symbol used.
- A retired-collection RE-POINT is proven by seeding the RETIRED path as a trap in the SAME
  run, never by asserting the live path alone.

### Multi-select / bulk-action wiring
- VM tests + card tests can pass while the GLUE (snapshot/order/callback) is untested at
  widget level. Selection-guard tests need the owner's OWN tile, not all-strangers.
- Clear-on-cancel: assert the count returns to the ORIGINAL, not zero. Copy-paste id-field
  mismatches are invisible unless a fixture makes the fields DIFFER.
- Async error stubs: `thenAnswer((_) => Future<int>.error(...))` — never `thenThrow`.

### Extraction seams & duplicated-logic-across-surfaces
- Pure decisions locked in a DI-heavy widget → extract `@visibleForTesting static`, not a DI
  bridge. When the SAME behaviour is re-implemented in 2+ classes, demand a test PER COPY —
  copies WILL diverge silently.
- An OPT-IN parameter gating a SECURITY behaviour is OFF everywhere until a `lib/` caller
  passes it — grep the name in `lib/` and `test/` separately; "test-only hits" IS the finding.
- **LIVE-PATH CHECK, before writing any test for a bug fix**: grep the call chain from the
  view down to the write, confirm the fixed method is ON it — a fix on a parallel facade
  with no `lib/` callers ships nothing. A tested caller + a tested callee ≠ a tested seam.
- An optional nullable callback seam ("stays constructible in tests") is invisible when every
  harness omits it — grep the seam's name across `test/`; zero hits IS the finding.
- A new error/message seam is only as good as its READERS — a caller that awaits then shows
  success unconditionally means the message is never shown or cleared.
- Enumerate optimistic-rollback siblings by SHAPE (catch blocks restoring local state,
  `return false`), not the ticket's wording — a fix on the two named leaves the rest live.
- When a data-loss ticket ships root cause + safety gate, the gate gets tests and the root
  cause gets none — grep the root-cause CLASS across `test/`. The third untested layer is
  usually the VIEW's outcome→message branch: assert the INVARIANT, be CHANNEL-AGNOSTIC.
- A "reads live state, not the cache" contract is only tested if the fixture makes the two
  DIFFER — cached vs stored needs a tick PLUS an item the cache never saw.
- An atomicity fix is tested at the layer OWNING atomicity, unreachable on the fake — a
  transaction-runner typedef seam is legitimate for platform codes but seams out the
  RUNNER, not the transaction; pair with an emulator-lane test.
- A permission guard on ONE method of a pair must be checked on its sibling — a
  callback-based API is the EASIER bypass. An attribution-field fix's sweep must include
  MODEL FACTORIES (a factory copying a display name means the FIRST stamp differs in source).
- Converting a per-item write to a per-item TRANSACTION makes existing `Future.wait` fan-outs
  over the SAME document pathological — grep callers first.
- A shared cache reused by a STRICTER new reader launders the weakest writer's output —
  enumerate every writer into the cache.
- A `didChangeDependencies` retry on a widget that renders `SizedBox.shrink()` on failure is
  DEAD — the early return happens before any `Theme.of`, so only a REMOUNT recovers.

### One-off gotchas, Windows/runner notes, and the revert-probe technique
- An overflow probe MUST mount `AppTheme.lightTheme` — the bare `MaterialApp`'s smaller
  default typography can hide a real overflow. Pin with SYNTHETIC tall content, never real
  ARB copy (dies with the flag).
- A page-size guard is only testable on a TALL surface (`tester.view.physicalSize =
  Size(800,14000)`, dpr 1.0) — a short surface auto-scrolls and hides item 0.
- `Semantics(label:)` on a tooltip'd button MERGES into one node — match with `RegExp`,
  bracket with `ensureSemantics()`/`handle.dispose()`.
- Real `.xlsx` stores text via shared-strings (`t="s"`), not `inlineStr`. A
  `TimeoutException` with 0 tests run is compile-bound (~12 min shared compile), not hung —
  split invocation per file.
- **THE PROBE LADDER, cheapest first**: (1) analytic — make the two sources DIFFERENT
  literals so a revert can't coincide with expected; (2) SCRATCHPAD replica via `dart.bat
  --packages=<repo>/.dart_tool/package_config.json` (no repo writes, immune to parallel
  sessions); (3) `test/`-side replica; (4) mutate the INJECTION, not `lib/`; (5) only then a
  real `lib/` revert.
- **Writing a mutant into `lib/`/`functions/src` is REFUSED by the auto-mode classifier
  (content-, not command-sensitive)** — the Edit applies silently and the NEXT run is
  refused. On a dirty file: `cp -p` first, restore via reverse Edit, `cmp`/md5 verify. On a
  clean file: Edit-mutate, restore with `git checkout --`, verify via `git status`/`diff
  --stat` (not md5 — CRLF on checkout differs).
- **Revert-probe mechanics**: copy to scratch, string-replace the fix OUT, confirm EXACTLY
  the expected tests go red, restore + `cmp`. Assert the search text occurs EXACTLY ONCE
  before writing — doubles as a tree-motion detector. Do the cycle in ONE Bash call, script
  reading OLD/NEW text from FILES; on Windows read/replace/WRITE IN BINARY.
- A WHOLE-CLASS replica scales this: copy class + suite to the SESSION SCRATCHPAD (not
  `test/`), rename, repoint the import — the only route when the `lib/` file is STAGED or
  edits are forbidden. Run the unmutated copy as control first.
- READ THE MUTATED LINE BACK before believing a red count — a shell heredoc can mangle
  backslashes silently. Write probes with the Write tool, raw Dart strings, never a bash
  heredoc. Never pipe a mutation driver into `head` (SIGPIPE kills its own cleanup).
- A probe file lives in scratch, not `test/` — a `// delete after` header is not a deletion
  (two outlived their round in 2026-08-12). Close every round with `git status --porcelain`.
- When the test reads a FILE PATH (registry lints, declared-index asserts), the mutant is a
  GIT REVISION — `git show HEAD:<path> > scratch/`, run the walk against both. The only
  probe available when the "fix" is a deletion.
- A deletion mutant inside a fluent chain doesn't compile — substitute an always-true
  equivalent (`.where('name', isNull:false)`).
- A generated file in a diff is verified by re-running its generator, byte-compared, with
  the output's mtime moving while inputs don't (a byte match proves nothing if the generator
  silently skipped files).
- A one-character change inside a string literal can't be reviewed from `git diff` — `od -c`
  or `git show HEAD:` it. Byte-form grep false-negatives under UTF-8: use the codepoint form
  `grep -nP '\x{F8FF}'`, a Python sweep, or `cat -A`.
- A new grep guard in `lefthook.yml` needs one path-handling probe — it renders
  `{staged_files}` REPO-RELATIVE, so an anchor past a `path:line:` prefix false-fails on a
  Windows absolute path (`C:/…` splits at the drive colon); anchor the LAST `:<digits>:`. A
  guard wired only pre-commit is bypassed by `LEFTHOOK_EXCLUDE` or a merge.

### Firestore-rules `.ts` suites (emulator-gated)
- Every `&&` clause in an `allow` rule gets a failing test; every `cannotModify`/
  `hasRequiredFields` list needs a test PER FIELD.
- A failure-only update suite can be silently over-restrictive — pair denials with an
  `assertSucceeds` on a mutable field.
- The emulator persists docs ACROSS invocations — suffix create-test ids with a per-run
  `Date.now().toString(36)`, or a fixed-id create silently becomes an update.
- Hand-rolled `npx ts-node` runners against `127.0.0.1:8080` time out without the emulator
  running first; `npx tsc --noEmit` DOES typecheck `src/__tests__` — a free non-emulator
  check on a rules suite you can't run.
- **A client-side filter test on the fake says NOTHING about whether the SERVER accepts that
  query** — rules refuse a whole QUERY when any candidate doc fails the read rule. A
  membership-filtered read owes THREE assertions: filtered-ALLOW (SDK's own spelling, with a
  non-empty premise check); unfiltered-DENY (delta is only the missing `where()`); and
  filtered-ALLOW-but-empty for a member of nothing.
