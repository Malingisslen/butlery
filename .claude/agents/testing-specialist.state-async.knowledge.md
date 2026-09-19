# testing-specialist — chapter: state-async

- **A CLEAR-ON-ENTRY call (`_beginMutation`, "reset the parked reason") pinned by a count on the
  SUCCESS path is graded against DELETION only, never against being MOVED below the early
  returns — and moving it is the historical defect, not deleting it.** Both mutants are
  identical from a happy-path fixture. The pin has to sit on a branch that `return false`s
  before reaching the collaborator; a sibling method in the same suite usually already has that
  case to copy. Same shape as the guard-POSITION rule above, wearing an error-reporting costume
  (BUT-1718).
- **A test asserting that a value SURVIVES a rebuild cannot tell "carried through" from "never
  rebuilt"** — the fixture REACHING the branch is a separate fact from the assertion
  DISCRIMINATING it. Pin the rebuild itself beside the carry (BUT-1971).
- **A disposal guard's RATIONALE COMMENT names a reaching path, and that is a measured claim about
  WHOSE continuation resumes — trace it, because one comment text pasted into sibling leaves is
  right in some and wrong in others.** "The owning ViewModel resumes after an `await` and touches
  this object" holds where the VM awaits a SERVICE and then touches the leaf; it is FALSE where the
  VM merely delegates (`return await _manager.foo(...)`, nothing after the await) — there the
  leaf's OWN async body is what resumes, typically in its `finally`. Same grep settles the method
  ENUMERATION such a comment carries: a method that reaches no `notifyListeners` on any path cannot
  reach the guard, so listing it is over-claiming. Strike both, never reword (BUT-1641).
- **A synchronous post-dispose call is an ADEQUATE pin for `if (_isDisposed) return` and pins
  nothing about REACHABILITY.** The guard has no await and `dispose()` sets the flag before
  `super.dispose()`, so no interleaving exists for an async test to expose — settle it
  analytically, not with a probe. What is still owed is one Completer test per leaf that OWNS the
  await, driving the real async method disposed mid-flight: it is the only thing that pins which
  method actually reaches the guard, and it is what catches an over-enumerated comment (BUT-1641).
- **An optimistic-publish ROLLBACK is pinned only for the field the refusal test reads.** Every
  OTHER restored field is deletable-green whenever the fixture's collateral collection is EMPTY.
  Grade FIELD BY FIELD, seed each collateral collection NON-EMPTY and DIFFERENT from what the
  operation would leave, and check the RETRY-after-failure path — a lost re-armed snapshot is
  permanent data loss the failure test cannot see. A `finally` release is pinned only
  incidentally (BUT-1975/1965).
- **An OPTIMISTIC publish is pinned only where a test observes state while the write is still
  PENDING — count the `Completer`s, one per COPY of the publish, not one per method.**
  `grep -n "Completer\|unawaited"` on the suite is the whole check. Ask FIRST whether the publish
  is optimistic at all.
- **A cleanup that DELETES a pair of unsafe delegates and deliberately KEEPS one twin leaves the
  KEPT twin unpinned** — the survivor gets a rationale sentence instead of a test. Close it with
  a PAIR (failure fallback + persisted passthrough); the fallback assertion alone is satisfied by
  an "always empty" mutant (BUT-1948).
- **The silent-return→throw rewrite seen from the other end**: putting `await expectLater(call,
  throwsA(...))` ABOVE a surviving "nothing was written" assertion makes that assertion
  UNREACHABLE when the throw is missing, so it no longer carries the missing-guard mutant. What it
  still kills is the ORDERING mutant (write, THEN throw) — the only sentence a comment may claim.
  Grade matcher discrimination from the TYPE LATTICE (`PermissionDeniedException implements
  Exception` vs `StateError` an `Error`), and attribute a denial to ONE conjunct (BUT-1962).
- **Grade a read-side guard against EVERY WRITER in the file — and the sentence "every save site
  guards on null" IS the finding.** The unguarded site is reliably the one that DERIVES its
  payload instead of mutating the loaded one, and a null fallback there can retarget the write to
  the WRONG week. **Refuse the aggregate probe the fix round offers back**: "neutralising every
  guard reddens exactly N" ranges over the SET and cannot see a per-site gap — mutate one site at a
  time (BUT-1939).
**Structural vacuity:**
- **An auth-gated `executeServiceOperation` wrapper hollows a raw-mock suite in BOTH directions.**
  `_isAuthenticated()` calls `ServiceLocator.get<AuthRepository>()`, which THROWS in a file with no
  DI harness, so the method returns `defaultValue` having never touched the repository, and
  `safeExecute` catches EVERYTHING so no `throwsA` test can pass while the wrapper is there.
  REMOVING it is a free analytic non-vacuity proof for any fail-loud fix. **The remedy is a HARNESS,
  not a redesign** — `setupUnitWithProductionLocator()` + a `FakeAuthRepository` auth state; the
  proof it worked is any arm asserting the SUCCESS value (BUT-1928).
- **The same swallow falsifies ORDERING-SAFETY comments two files away** — "do A before B, so if A
  fails B never runs" is FALSE whenever A wraps its write in `executeServiceOperation`. Grade every
  "if X fails, Y stays unwritten" sentence by opening X's method and asking whether anything can
  propagate out of it; usually only a guard that throws ABOVE the wrapper does (BUT-1928).
- **An ORDERING fix (resolve A before B) is mutation-dead whenever the suite INJECTS A** — the
  testable constructor param resolves A synchronously, hiding a reverted fire-and-forget order
  (BUT-1838).
### Disposal & lifecycle guard idioms (BaseViewModel family)
- `BaseViewModel` already guards disposal twice — only test a subclass's OWN guard when it protects an
  observable effect no base guard blocks.
- Two quadrants: delegate disposed BY this VM → `returnsNormally`+`notified==0`; delegate is a SHARED
  SERVICE outliving the VM → `returnsNormally` is VACUOUS, assert the service's error SURVIVES
  disposal.
- A class with both local `_isDisposed` and inherited `isDisposed` must use the SAME flag its own
  callbacks use. `executeAsync` RETHROWS on failure — prove via a caller retrying only on THROW.
- `dispose()` clearing DATA (not just controllers) opens a use-after-dispose window — dispose
  mid-operation, assert the write still carries user data.
- A "disposes its children" test asserting only `returnsNormally` is vacuous — materialize the child,
  assert it's dead after (`addListener`→`throwsFlutterError`).
- A suite whose every stubbed stream is already COMPLETING pins no cancellation — use a
  `StreamController`, assert `hasListener` true-before/false-after.
- A throw-on-disposed guard inside a shared builder is safe only at callers that catch —
  `notifyListeners()` post-dispose is DEBUG-ONLY, so never conclude "unreachable" from a debug-mode
  trace. **The MIRROR is the commoner comment defect: only the WRITE side asserts.**
  `TextEditingController.text` resolves to `ValueNotifier.value`, a bare field read with no
  `debugAssertNotDisposed`, so "reads the controller on a disposed State → an assertion in debug" is
  false — the read is silent and the real harm is the work that follows. Grade a disposal comment by
  which MEMBER it names (BUT-1831).
- A `manager.dispose()` fix's wiring half ships untested — delete the OWNER's `dispose()` line as a
  probe. The flip is the returned future THROWING instead of resolving null.
- A `Completer` whose `.future` is never awaited is dead plumbing — grep for `.future`. A polling loop
  returning a cached `_lastResult` drops the second caller's work.
- Any concurrency fix needs the second caller actually LAUNCHED (warm-up, gate on a `Completer`,
  launch B, settle) — assert `same(inFlight, queued)`, `queued==null` post-dispose, and exactly ONE
  persisted id from the overlapping pair. **The concurrency VACUITY carrier is LAST-WRITER-WINS**: two
  in-flight edits whose trailing arms both write one field resolve in CREATION order, so a test
  asserting the final value is answered by the ordering and not by the guard it names. The
  discriminating shape lets the NEWER edit finish first (BUT-1971).

- A new error/message seam is only as good as its READERS — a caller that awaits then shows success
  unconditionally means the message is never shown or cleared.
- Enumerate optimistic-rollback siblings by SHAPE (catch blocks restoring local state, `return
  false`), not the ticket's wording.
- When a data-loss ticket ships root cause + safety gate, the gate gets tests and the root cause gets
  none — grep the root-cause CLASS across `test/`. The third untested layer is usually the VIEW's
  outcome→message branch: assert the INVARIANT, be CHANNEL-AGNOSTIC.
- A "reads live state, not the cache" contract is only tested if the fixture makes the two DIFFER.
