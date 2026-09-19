# testing-specialist — chapter: firestore-data

- **"Would the RULES allow this?" — just run it**: a throwaway `_zz_probe_*.ts` under `npx
  firebase emulators:exec --only firestore --project demo-test` names the rule line in ~90s; add
  a control arm.
- **`fake_cloud_firestore` CREATES the key on an explicit null, so `expect(data.containsKey(k),
  isFalse)` is a real pin on a null-aware `'k': ?v` write — measured, not argued** (BUT-2057:
  changing `?recipeOwnerId` to `recipeOwnerId` reddens exactly that one case). Worth writing
  wherever a Firestore rule keys on a field's PRESENCE, since there absent and null differ.
- **The FieldValue wall is CLOSED at the bootstrap, and a `skip:` naming it is now always
  stale. Do not compress this.** `FieldValue.serverTimestamp()` and every other sentinel resolve
  through `FieldValueFactoryPlatform.instance`, a PROCESS-WIDE SINGLETON that freezes on first
  use; if the real `MethodChannelFieldValueFactory` wins the race, a write through a fake database
  throws `MethodChannelFieldValue is not a subtype of MockFieldValuePlatform` deep inside the fake,
  where best-effort denormalization code catches broadly, swallows it, and lands ZERO documents —
  **the suite does not fail; it silently asserts nothing.** `BaseTest.setup()` now calls
  `installFakeFieldValuePlatform()` as its FIRST statement, so every suite reaching it through
  `setupUnit()`/`setupUnitWithProductionLocator()` wins by construction. A suite standing up
  cloud_firestore WITHOUT that bootstrap must call the helper itself, first. 26 skips died to
  this (BUT-1806); BUT-838 was the same wall.
- **An ordering contract that only a comment enforces WILL be got wrong — move it into the shared
  bootstrap instead of documenting it harder.** The `setUp`-ordering version of the rule above had
  two callers repo-wide and 26 tests switched off around it. When a rule reads "call X before Y",
  ask whether Y can just call X.
- **Un-skipping reveals a SECOND wall as often as none: an `update()`/`batch.update()` on a
  document the fixture never seeded.** `[FakeFirestore/not-found]` there is a real FIXTURE gap, not
  a fake limitation — real Firestore refuses `update` on a missing document too. The missing doc is
  reliably the DENORMALIZED COUNTER the write increments (`public_profiles.friendsCount`, the parent
  comment's `replyCount`), which is also the assertion the skip was hiding. Seed it, then assert it.
- **A test re-enabled from a `skip:` is the likeliest place in the repo to find a body with NO
  `expect` at all** — the skip string was doing the explaining, so nobody wrote the assertion.
  Grep every un-skipped body for `expect` before running anything (BUT-1806 found several, one
  ending literally at `// Assert - FieldValue.increment conflicts...`; the archive lists them).
- **A repoint to `collectionGroup(...)` is HALF a fix** — needs a `fieldOverride` with
  `queryScope: COLLECTION_GROUP` or FAILED_PRECONDITIONs; `deploy --force` prunes anything absent
  from `firestore.indexes.json`. Suite needs three arms (override exists at group scope, exact
  set survives delete+add, source still spells the field). Register the npm `test:*` script in
  the same edit.
- A poll-until-condition loop discriminates only if the assertion sits AFTER it, polling the LAST
  observable step. `retry:true` owes a reachability read of `isCascadeEventExpired` as the
  handler's FIRST statement.

- **A `firestore.rules` edit owes a run of `test/unit/security/rules_allowlist_drift_test.dart`
  AND `rules_numeric_bound_drift_test.dart` before any verdict** — the census pins the file's
  comment-stripped `hasOnly(` population by NUMBER, so ANY new allowlist reddens it, a READ gate
  included, which the guard's name does not suggest. **Twice now the change ran its own new
  suites green and shipped this red** (BUT-2046 follow-up, BUT-1718): the tell is a rules diff
  whose author reports a clean run over the feature's own files, because the census lives in a
  directory the feature never touches. Settle it in one command before grading anything else —
  `git show HEAD:firestore.rules | sed 's://.*::' | grep -c 'hasOnly('` vs the same on the index
  both attributes the delta and proves it is yours. The census demands a classification; bumping
  the number is the repair it names as forbidden.
- A call added to satisfy a **REPO RULE** rather than a feature (`logPermissionCheck`). Unpinned
  twice over: no repository suite injects an `auditRepository`, so the mixin's null branch never
  runs; and the `requireCurrentUserId()`-vs-caller-supplied-`userId` choice collapses to one
  observable whenever the fixture's authed uid IS the passed one. The killer fixture DIVERGES the
  two uids. Grade that choice PER CALL SITE, never per method. Template:
  `firebase_activity_event_repository_test.dart` (BUT-1962/1981/1971).
- A **write moved INTO a `WriteBatch`**: a mocked-batch capture of `batch.set` pins STAGING, not
  the write — dropping `commit()` stays green unless the test verifies it; and
  `fake_cloud_firestore`'s `MockWriteBatch` replays sets one by one at commit, so batch
  MEMBERSHIP is unobservable there (a direct `.set()` beside the batch stays green). An emulator
  rules test commented "the shape <Dart writer> writes" is a coverage pointer: diff its body's
  KEYS against the writer's map before believing it (ADR-0020: `listId` in the test,
  `sharedListId` in the app, `hasRequiredFields` requires `listId`).
- **A CONTROL arm is graded by WHICH DISJUNCT grants it, never by what its comment claims it
  proves.** A "the seated member can still read the PARENT" control is granted by a different
  limb (`uid in sharedToUserIds`) than the fixture it is said to certify (`members/{uid}`), so
  deleting the seat leaves it green and the seat is pinned by nothing — and in a REMOVED-block
  suite every deny passes seat-or-no-seat, so nothing else can see it either. Read the granting
  rule's disjuncts and pin the fixture through the one that NEEDS it (the member's own
  `members/{uid}` read); a control whose comment claims to prove a fixture is the commonest
  place that claim is false (BUT-1716).
- **When ONE change edits TWIN repositories/methods, the test lands on the twin whose refusal
  branch is a TAUTOLOGY** and the untested twin is the one with a real actor gate. Grade a paired
  diff PER FILE and run the HEAD-bytes probe on the file the round wrote no test for (BUT-1981).
- **A collection's DOCUMENT-ID SCHEME change (deterministic→auto-id) breaks every reader that
  addresses/dedupes by it, invisibly** — grade writers keyed on `doc(x)`, mergers doing
  `byId[doc.id]=doc` (silent double-render), and field-keyed cascades. **When the change exists
  for a PRIVACY property (the id stops carrying a uid, because the id is copied into a stamp or
  log), the only witness is a test that constructs the REAL id-minting class** — grep the
  method across `test/`; all-mock hits means a revert to the composite id is green everywhere.
  Pin uid-ABSENCE for both parties on the captured id, never a UUID regex (BUT — ADR-0020).
- **A repository's ONE-SHOT reader and its LIVE-STREAM twin** carry byte-identical branches and the
  suite pins the one-shot half because it is the easier `await`; the stream is what the open screen
  renders from. `lcov DA=0` on the stream's branch is the whole probe (BUT-1908).
- The in-memory version DELETES data instead of failing to write it — `copyWith` is the durable fix;
  assert an UNTOUCHED member survives.
- Round-trips must drive the REAL serializer, never `copyWith`; a DateTime sentinel needs zone
  normalisation checked via round trip.
- A hand-built narrow write payload needs BOTH the carried and omitted keys pinned — for the
  omission, drive a mutator that moves the excluded key as its OWNER.
- Firestore whole-number aggregates store as `int` — `as double?` throws and silently drops the row.
  A guard spanning TWO user-facing shapes ships pinned on one; the diff's own "accepted consequence"
  sentence usually names the unpinned shape.
- A source-text guard pinning `keys().hasOnly([...])` has five vacuity seams: widest payload;
  complete writer set (forever); anchor sentinel checked against the NEXT match, not global
  uniqueness; blind to the `hasAll` mirror; can't see a SWAP (delete+add, count unchanged). Prove by
  neutralising the call and watching the WRONG-LIST message (BUT-1830). **A HAND-TYPED writer
  set in that guard pins the RULES side only** — a key the writer ADDS reddens nothing there; the
  writer's own suite owes a subset check over the keys a real write STORED against the list read
  out of `firestore.rules` (BUT-2079, `rateRecipe`).
- **A write the RULES refuse is 100% green under mocks, and its TWINS stay refused — grep the file,
  not the ticket.** Every field the write touches: grep `firestore.rules` for a deny; each surviving
  twin owes a comment naming the rule LINE. A comment quoting a deny-list beside a round-trip
  assertion names TWO populations that legitimately differ (the RULE's key list, the SERIALIZER's
  emitted set) (BUT-1831).
- A guard skipping a per-parent subcollection probe is unfailable when the probed doc doesn't exist —
  repair with a TRAP row at a path production never writes, spelled with production CONSTANTS.
- A repository suite where every fixture lives in ONE scope can't see its scoping `where`, and
  habitually leaves inherited CRUD (`read`, `readAll`, `watchAll`) untested.
- **`FakeFirebaseFirestore` honours `.orderBy(f, descending: true)` on a SUBCOLLECTION but RETURNS
  documents that lack `f`**, even as the only document; real Firestore drops them. So an ordered read
  is testable for ROUTING and ORDER on this lane, and its missing-field hazard belongs on the
  emulator lane or in a note beside the seed (measured 2026-09-02).

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
| A NULL-VALUED KEY via `set(..., merge: true)` (incl. `batch`) | **Faithful, `containsKey` is real coverage.** Key present, value null, siblings preserved; null OVERWRITES a stored map. |
| Query PREDICATE SHAPE, incl. `where('<map>.<uid>', isNull: false)` | **Exact.** Build the REAL repository over the fake; dotted keys, `isNull`, `arrayContains` all work. `isNotEqualTo: null` adds NO condition in the real SDK and makes the fake THROW — never accept a comment claiming map-path keys unsupported. |
| A negative "gets nothing" test | Mutation value only when the SUT doesn't swallow errors — behind a catch-all `return []` it's a recall control, and the positive test is the whole guard. |
| A per-ROW transactional write (doc id == uid) | Transaction wrapper is deletable-green by construction — the suite really pins the DOC-ID DERIVATION. Keep the two-actor test as CONTROL; put the permission half in the rules lane. |
| `FakeFirebaseFirestore.runTransaction` | NO-OP PASSTHROUGH, never proves atomicity — handler runs once, `SetOptions` dropped, `timeout`/`maxAttempts` ignored. Use a bare read-modify-write; a truly interleaved test fails on the fake, passes in production. |
| `test/integration` | Nothing in CI passes `--dart-define=USE_EMULATOR=true` over it — every lane test skips everywhere, never coverage. `flutter test` is plugin-less; the lane needs an `integration_test` project. Ticket it, don't "just add the flag." |
| `serverTimestamp()` in `batch.set(..., merge:true)` | Trips the fake on some shapes — never a valid `skip:`. Fix: `installFakeFieldValuePlatform()` as the FIRST line of `setUp` (see the ordering rule in test infrastructure). |
| `permission-denied` | Fake can't fire it — skip only when the branch is a bare `if (e.code=='permission-denied') return null;` above a rethrow, no side effects. |
| `orderBy` field | Seeded fixture must include every field the `orderBy` reads on a top-level collection; on a SUBCOLLECTION the fake keeps docs missing the field (real Firestore drops them). |
| `collectionGroup` | Safe on the fake for index-free `.limit(N).get()` with no `where()`, and (^4.1.0+1) for plain equality. |

- **A tautological PERMISSION gate**: `save(plan)` passing `plan.userId` into
  `validateUpdatePermission(userId, id, entity)` makes `entity.userId == userId` a tautology, so the
  doc-ID prefix is the sole determinant. Attribute a denial to ONE conjunct before writing about it
  (BUT-1962/1981).
- **DESERIALIZER-DEFAULT vacuity**: a save-retrieve test asserting the parser's own `defaultValue` is
  unfailable — missing doc, dropped write and empty map all answer the same. Tell: a "returns
  defaults" sibling test with a byte-identical assertion list.
- **A per-case seam derived from the case's own fake cannot leak — so grade the SENTENCE beside
  it, not the seam.** An in-memory Firestore double is FLAT PATH-KEYED, so seeding a PARENT
  (`users/{uid}`) is inert when the SUT reads only `users/{uid}/<sub>/<doc>`: the fixture line is
  unread and its "because other cases read it" justification is false. Same round, the case
  staging that parent as ABSENT explained its own outcome by the parent rather than by the seam —
  the refuted premise re-planted as a fixture comment (BUT-1917).
### Settings-hydration & sentinel-parameter template (recurring: BUT-1220, 674, 1322, 1610)
Any field persisted via a private settings sub-doc needs: hydration seeding the sub-doc directly; a
corrupt-value test ALSO asserting a sibling merged field survives (one `copyWith` in one try/catch can
abort the whole merge); a save-path test asserting the settings doc has it and the public doc does
NOT, plus a round trip; one test per serialization surface. Sentinel params (`Object? field=_unset`)
need both quadrants: omit→preserved, explicit-null→cleared. Capture the forwarded ARGUMENT IDENTITY,
not a downstream no-op. An EMPTY-STRING sentinel (`''`=cleared, `null`=leave alone) is a contract
between TWO files: a widget test pinning what LEAVES the emitter is green forever if a consumer later
re-collapses `''` to "unchanged" — pin the consumer's own `x ?? current` line in ITS suite, same edit
(BUT-1874).

### Firestore cost, index & cascade patterns
- A declared composite index needs its own assertion (fakes can't catch a missing one) — assert
  `queryScope` alongside field order.
- A merged/idempotent cascade `update()`ing a doc it assumes exists can throw NOT_FOUND and fail the
  whole batch — test the gating doc exists but the target does not.
- A dotted-path transactional `update` needs an UNRELATED sibling field asserted SURVIVING.
- A CF trusting a doc field for a security decision is only as strong as the Firestore RULE validating
  it on create.

- An atomicity fix is tested at the layer OWNING atomicity, unreachable on the fake — a
  transaction-runner typedef seam is legitimate for platform codes but seams out the RUNNER, not the
  transaction; pair with an emulator-lane test.
- A permission guard on ONE method of a pair must be checked on its sibling — a callback-based API is
  the EASIER bypass. An attribution-field fix's sweep must include MODEL FACTORIES.
- Converting a per-item write to a per-item TRANSACTION makes existing `Future.wait` fan-outs over the
  SAME document pathological — grep callers first.
- A shared cache reused by a STRICTER new reader launders the weakest writer's output — enumerate
  every writer into the cache.
### Firestore-rules `.ts` suites (emulator-gated)
- Every `&&` clause in an `allow` rule gets a failing test; every `cannotModify`/`hasRequiredFields`
  list needs a test PER FIELD.
- A failure-only update suite can be silently over-restrictive — pair denials with an `assertSucceeds`
  on a mutable field.
- The emulator persists docs ACROSS invocations — suffix create-test ids with a per-run
  `Date.now().toString(36)`, or a fixed-id create silently becomes an update.
- Hand-rolled `npx ts-node` runners against `127.0.0.1:8080` time out without the emulator running
  first; `npx tsc --noEmit` DOES typecheck `src/__tests__` — a free non-emulator check on a rules suite
  you can't run.
- **An emulator deny printed as `evaluation error at L<n>:<col>` names the LIMB's own position, not
  the conjunct that refused, and it says nothing about that limb throwing** — pre-existing deny cases
  that refuse via a plain-false `cannotModify` print the byte-identical string, and one write can
  report an error AND a false for the same line. So it cannot be read as "the new conjunct is never
  reached" or as "the rule errors". The only settling probe is deleting the conjunct from
  `firestore.rules` and re-running: the reds are its kill set, the greens are its controls
  (BUT-2057: 2 of 9, the two new denies, with all three controls green).
- **A client-side filter test on the fake says NOTHING about whether the SERVER accepts that query** —
  rules refuse a whole QUERY when any candidate doc fails the read rule. A membership-filtered read
  owes THREE assertions: filtered-ALLOW (SDK's own spelling, with a non-empty premise check);
  unfiltered-DENY (delta is only the missing `where()`); and filtered-ALLOW-but-empty for a member of
  nothing.
