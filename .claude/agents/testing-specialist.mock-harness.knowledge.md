# testing-specialist — chapter: mock-harness

- **"Duplicate test" is measurable**: mutate the guarded expression; a duplicate deletes only a
  strict subset of the kill set THROUGH THE SAME SEAM. Exceptions: reaches the sole fail-closed
  lookup via a different seam, or is another test's CONTROL. Grade two suites for one class by
  what only ONE holds. Never retire by path convention alone.
  **The same override also makes the overridden member's own CONTRACT unpinnable from the
  consuming suite**: a spy subclass recording `logPermissionCheck` means no test in the
  consumer's file can observe that production SWALLOWS its failures, so a docblock reading
  "fire-and-forget by contract" is unpinned while the suite reads as thorough — measured, a
  `rethrow` mutant left both suites green. That pin belongs in the OWNER's suite, driven by a
  failing sink, and a `completes` case whose write SUCCEEDS never enters the catch (BUT-1773).
  **The failing sink may fail at the NEAREST member rather than at the write** — a `Fake`
  throwing from `collection()` avoids implementing the sealed `Query` and still kills the
  `rethrow` mutant, because the getter is dereferenced inside the same `try` statement. What it
  cannot discriminate is a DROPPED `await`: a synchronous throw is caught either way, while a
  real rejection would escape unhandled. Settle that analytically; a green probe proves nothing.
- **A guard a REVIEWER asked for is exactly as unproven as any other line, and probing it is the
  reviewer's job to demand** — a one-line re-check I recommended shipped GREEN (deletable with
  every case passing) until the probe said so. Staging an INTERLEAVING to kill it needs a
  subclass double that delegates (`super.read()`) and then schedules the side effect: that is
  not the override trap above, because production's method still runs and only the timing is
  staged. Expect the fix to falsify the rationale comment on the guard it now subsumes — and a
  check made redundant by a later one is a behaviour-preserving fast path that owes no pin
  (BUT-2046 follow-up, 2026-09-13).
- **A green probe over the SUITE YOU WROTE cannot support a "no other witness" claim** — that
  needs the suites found by `grep -rl '<mutated symbol>' test/`, a different set from the files
  you edited. "Raising this constant leaves every suite green" shipped false because the probe
  ran one file (BUT-1971).
- **Dart's lcov mis-attributes lines around an `await`** — an `await service.save(...)` line can
  carry no `DA:` record at all while a hit lands two lines past it, which reads as the opposite
  of the truth. The decisive probe is TEST-side and needs no `lib/` write: copy the suite to a
  scratch `_zz_probe_test.dart`, insert `verify(() => mock.<seam>(any())).called(greaterThan(0))`
  in every case, run with `--plain-name`, delete (BUT-1962).
### Project-specific test infrastructure (full detail in `testing-specialist.md`)
- Production ServiceLocator bridge: `production.ServiceLocator.initialize(DIContainer())` in
  `setUpAll`; both ServiceLocator classes share one `GetIt.instance`.
  `BaseUnitTest.setupUnitWithProductionLocator()` does both and works inside a GROUP-scoped
  `setUp` in a widget suite that otherwise never touches DI — pair it with
  `TestServiceLocator.reset()` + `prod.ServiceLocator.reset()` in that group's `tearDown`. It is
  what makes household/presence surfaces reachable from a widget test; note a VM can resolve a
  repository in its CONSTRUCTOR on a path that never calls it, and
  `test_service_locator.dart` may not register one (BUT-1982).
- **`TestTimestampProvider` reads `clock.now()`, so under `withClock` its value equals every
  clock-derived value in the same write** — a "lastWrite comes from the provider" pin using it
  alone cannot tell the provider from a direct `clock.now()`. Add a provider returning an
  instant the clock never produces. Same shape wherever two uid sources collapse in a fixture:
  assert the premise that they DIFFER before asserting which one a path uses (rate-limit stamp
  tests, 2026-09-14).
- `MockUnifiedRecipeService.setRecipeState()` defaults `isInitialized: false` — pass it.
- Debounced VM: `fakeAsync` + `async.elapse(300ms)`; `executeDebounced` fires 3 notifications.
  `test/views/` is journey-test territory (owned by `e2e-test-specialist`).
- **A `setUpAll(registerFallbackValue(...))` added with "the suite had none" is a MEASURED claim
  about the whole file** — grep `registerFallbackValue` and the mocked method across the WHOLE
  file, and delete-and-rerun as the cheapest check (BUT-1962).
- **A TAUTOLOGICAL assertion is not automatically a coverage hole — grade the whole test
  ARITHMETICALLY before repairing it.** `hasLength(<the constant>)` compares a bound to itself,
  but a sibling `first.entryId == 'e5'` may be `e(N − cap)` and already redden on every cap
  change. Substituting the mutant value into the fixture's own arithmetic settles this in seconds
  and OUTRANKS a mutation probe. A cross-language DRIFT guard pins EQUALITY between two copies,
  never the VALUE — and the moment one lands, every "nothing ties these two copies" comment on
  the other side goes false (BUT-1971).
  **A DECLARED CONSTANT equal to the fallback it replaces is unprovable end-to-end, and one that
  DIFFERS is the cheapest real pin available** — an export cap of 500 beside `defaultBatchSize`
  500 leaves the section's type literal untestable (a typo falls back to the same number and
  reads identically), so it owes a MAP-level assertion; a cap of 50 binds the wiring, and a
  cap+1-row fixture then kills a mistyped literal AND a deleted map entry in one case. Ask
  whether the constant differs from the fallback before grading such a test as covered
  (BUT-1693 vs BUT-2028).
- **A stub must reproduce the production return's IDENTITY, not just its VALUE, whenever the code
  under test branches on `identical(...)`** — a stub calling `copyWith` unconditionally hands
  back a fresh object, the short-circuit never fires, and a test written for that branch passes
  on the UNFIXED code. Read the production method's early-return line before writing any stub of
  it. A stub that correctly mirrors the identity return still silently drops the method's THROW
  arm: grade a hand-written stub against the callee's GUARD CLAUSES as well as its early returns,
  and check the gate with a scratch `_zz_probe_test.dart` rather than a `lib/` mutant (BUT-1971).
  **The FAILURE MODE is the same question and the commoner miss: a `thenThrow` models a branch
  production cannot enter whenever the real collaborator CATCHES its own error and returns a
  neutral value** (`UserService.getUserProfiles` swallows the repository failure and returns `[]`
  or a PARTIAL list). Such a test is green, reads as a retry pin, and the real failure falls
  through to whatever the neutral value renders — here an empty state asserting a fact about the
  group. Read the callee's `catch` before choosing HOW the stub fails, and where the neutral value
  is ambiguous, pin the two states apart with `verifyNever` on the seam the genuinely-empty case
  must not reach (BUT-1951).
- **A mocktail matcher goes vacuous only when a named arg's value stops equalling its DEFAULT** —
  `verifyNever` is the dangerous direction: a non-default named param can never match the
  omitted-param form, so the guard is UNFAILABLE. Spell every named param.
  **Unfailable only where the escaping call is otherwise STUBBED, so measure BOTH shapes
  rather than filing from the signature.** When the `setUp` stub is spelled just as narrowly
  as the `verifyNever`, the escaping shape misses the stub too and dies on the unstubbed-call
  throw — red, but as `type 'Null' is not a subtype of Future<T>`, which reads as a broken
  fixture rather than a caught regression. Consequence for an INVERTED pin over removed
  behaviour: the "unused" stub for a call no production path can make is load-bearing for the
  pin's DIAGNOSABILITY, and a later tidy deleting it as dead downgrades a MATCHING re-wire's
  failure message while nothing reddens (BUT-2016).
- A **telemetry constant** added in the same commit as the behaviour it measures (the sibling
  SUCCESS event is pinned, its FAILURE twin is not, emitted from the very `catch` the change made
  reachable) (BUT-1962).
- **A cross-language literal contract is usually pinned consumer-side only, and pinned on BOTH
  sides is still not pinned ACROSS** — a one-sided rename reddens only its own side and hands the
  author the new spelling, so the other language degrades silently. Check whether the emitting
  test IMPORTS the constant or RE-TYPES it (re-typing is the stronger pin) and state the residual
  as DIRECTIONAL. The enforcing pattern exists and is cheap: a Dart test that
  `File(...).readAsStringSync()` the `.ts` and regex-extracts the literal
  (`tag_phase1_seafood_safety_test.dart`). Until it is built, the mirroring test's NAME must state
  only what it asserts (`'the cap constant is 100'`), never the mirror (BUT-1929/1960).
- Notification `when(...)` stubs are not coverage (the wrapper swallows everything incl.
  `MissingStubError`) — only `verify(...).called(n)` + `verifyNever` on the retained member.
- A test passing an OPTIONAL override bypasses the changed default branch — grep every call site.
  Worst case: a remote KILL SWITCH override present in every test by construction. **The MIRROR is
  the useful half when grading a new defaulted flag: the DEFAULT is pinned only by a NEGATIVE
  assertion on a caller that OMITS it.** The explicit caller's positive assertion is byte-identical
  under a flipped default and under an unconditional body, so a `findsNothing` on the omitting path
  is a discriminator, not a control — settle it analytically (substitute the mutant into each
  caller) rather than by the shared inversion mutant, which reddens both sides and attributes to
  neither. Such a negative needs a POSITIVE anchor in the same fixture at the same pump, or it
  passes for the wrong reason (BUT-1951 follow-up).
- A defensive bound on an injected collaborator is mutation-dead when every fake answers
  immediately — `grep 'fakeAsync\|Completer\|TimeoutException'` zero hits IS the finding. A new
  conjunct beside an existing gate is born mutation-dead without a fixture passing the OLD gate and
  failing ONLY the new one. **A cache invalidated from a stream's LIFECYCLE has one limb per
  callback and they need opposite fixtures**: `onError` an OPEN controller you `addError` to,
  `onDone` one you CLOSE and then read through; `const Stream.empty()` proves neither (BUT-1909).
- The CONDITIONAL-IMPORT SEAM: `flutter test` compiles the native branch into every unit test, the
  web stub into none — the shipping impl runs in zero tests if every test injects a fake through the
  `_testX` seam. Same for `Platform.isX`.
- A "no unit test can see this" comment is a claim — split the untestable PREMISE (rules denial)
  from the testable BEHAVIOUR (the catch is not).
- The client-side twin: an injected `Future<bool> Function(T)` stubbed true can't show what
  PRODUCTION binds actually reject — resolve the argument to its terminal implementation, owed once
  per SPRINT.
### Conscious-skip taxonomy
- Static-method orchestrator: skip only when ALL hold — ≤3 calls, no injection seam, each in its own
  try/catch, no branching beyond the catches.
- Compiler-enforced sync contract (a renamed l10n/analytics constant fails gen-l10n/analyze first);
  pure-nav affordance (route constant is compile-checked).
- Nth surface adopting an already-proven predicate: prove via `git diff --staged --name-only` — no
  new surface if the pure-logic file is absent.
- **A mask-at-the-throw fix owes NO test when nothing observes the message** — the string is handed to
  `AppLogger.error` as the ERROR OBJECT (only the MESSAGE arg is sanitized) and the user-visible text
  is a generic fallback, so `isNot(contains(id))` on it is type-description vacuity. The durable pin
  is a source lint in `test/architecture/`. **The skip INVERTS once the throwing class's own
  `toString()` interpolates the message** — `recordError` sends `exception.toString()`, so a fixture
  IS owed. Read that `toString()` before citing this bullet (BUT-1897/1915).
- **A "sole guard"/KNOWN-GAPS comment is a CLAIM until a test enters that exact branch** — verify
  against the model's SERIALIZER; never read a rules subcollection match or a cascade's defensive
  sweep as evidence the client writes it.
- A pure removal of dead code owes no test when a repo-walking structural lint holds the invariant —
  verify the lint is byte-identical to HEAD and the pre-fix set had exactly ONE element.
- A behaviour-neutral respelling owes no test — earn that by MUTATION-COUNTING the existing suite,
  then fix the comment the respelling falsified. Before writing "the suite had nothing to say", grep
  `test/architecture/architecture_test.dart`: style bans ARE tests there. **Run
  `tools/check_staged_arch_guards.sh` FIRST when reviewing a recovered or never-reviewed patch** —
  ~1s, and it grades the axis vacuity analysis structurally cannot see. Gates grade CLAIMS; lints
  grade CONVENTIONS; neither covers the other (BUT-1912).

- A Fake with two branches answering the same success value, driven by one UI flag, eats a routing
  test whole — test the FAILURE arm. An enum-driven `defaults()` owes a KEY-SET-COMPLETENESS test.
  **A Fake whose ENUM getter can emit only TWO of the enum's N members makes `!= A` and `== B`
  polarity-equivalent, so the guard's polarity has no witness and the real-world state is
  unreachable** — grade an enum guard by which members the FAKE can produce, never by how many
  cases the suite has (BUT-1951: a two-valued `getFriendshipStatus` left "hide Blockera unless
  already blocked" indistinguishable from "show it only to strangers", which hides it from every
  friend — on the friend profile screen).
- Negative-scope claims need a negative assertion against `toMap().keys`, not a render check.
- mocktail is LAST-REGISTERED-WINS — wildcard-then-specific `when` is a genuine repoint discriminator;
  reversing the lines silently duplicates the other test.
- When production adds a call to a NEW repository method, an existing `extends Fake` suite silently
  grades that leg's CATCH branch (noSuchMethod throws, swallowed) — grep the new method name across
  `test/`; zero overrides while production calls it IS the finding.
- A `-1` sentinel default on a Fake means two things and only one is self-proving — pick the arm.
- Lazy `tryGet` fields cache on construction — register fakes BEFORE constructing the SUT.
- `verify(f(captureAny()))` marks calls VERIFIED, so a later `verifyInOrder` over the same method
  fails "not found" — capture THROUGH `verifyInOrder`. Fire-and-forget writes to
  `FakeFirebaseFirestore` need microtask draining, not a real-time wait. (A row written through the
  mixin's `unawaited(...)` IS visible to the very next `.get()` with zero intervening awaits, so a
  negative `expect(rows, isEmpty)` does discriminate — measured, BUT-1981.)
- **The GetIt→DIContainer bridge gotcha (recurring: analytics, tag-overrides, correction-snapshot,
  import chokepoints)**: many singletons resolve via PRODUCTION `ServiceLocator`, not
  `TestServiceLocator` — a mock there is invisible. Fix:
  `prod.ServiceLocator.initialize(DIContainer())`, register into `GetIt.instance` after; tearDown
  unregisters + resets.
- A new fire-and-forget telemetry call at a chokepoint ships with ZERO tests by default — add
  fires-once and fires-nothing; "no seam" is usually false. The test that matters passes NO injected
  seam. **The test written to close that gap is the one that goes green without reaching the failure
  it names**: the event sits in a `catch` wrapping a whole block, so ANY throw emits it — and the
  throw that fires is usually an unstubbed collaborator EARLIER in the block (mocktail's
  `MissingStubError`, caught by the same `catch`). Never grade such a test by reading it; a
  `verify(() => mock.<seam>())` in a scratch probe names the only call that happened. The repair is to
  stub the earlier seams and KEEP the `verify` in the committed test (BUT-1962).
- A defaulted `String source='manual'` param is worse than silence — grep the CALLERS of the
  newly-tagged method, not the ticket's named path.
- A safety-critical method covered ONLY via a caller's `verify()` proves WIRING, never the CONTRACT.
  Mirror: an opt-in param's tests can prove the contract while zero production callers pass it.
- A REQUIRED param moves the job from "is it wired" to "is the DECLARED value right" — test the UI's
  CHOICE of value and its rebase after a self-triggered change.
- **A REFUSAL+CONTROL pair whose non-vacuity needs no probe**: when both cases pump ONE fixture
  builder and differ only in a stub, the control's green proves the path reaches the observable, and
  the refusal case's green then proves the stubbed seam WAS called. Grade such a pair by reading the
  two `when(...)` lines (BUT-1962).

### Extraction seams & duplicated-logic-across-surfaces
- Pure decisions locked in a DI-heavy widget → extract `@visibleForTesting static`, not a DI bridge.
  When the SAME behaviour is re-implemented in 2+ classes, demand a test PER COPY.
- An OPT-IN parameter gating a SECURITY behaviour is OFF everywhere until a `lib/` caller passes it —
  grep the name in `lib/` and `test/` separately; "test-only hits" IS the finding.
- READ THE MUTATED LINE BACK before believing a red count — a shell heredoc can mangle backslashes
  silently. Write probes with the Write tool, raw Dart strings, never a bash heredoc. Never pipe a
  mutation driver into `head` (SIGPIPE kills its own cleanup).
- A probe file lives in scratch, not `test/` — a `// delete after` header is not a deletion. Close
  every round with `git status --porcelain`.
