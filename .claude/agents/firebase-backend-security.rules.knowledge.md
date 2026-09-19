# firebase-backend-security — chapter: rules

A gate written as `!('f' in request.resource.data) || check(...)` is DEAD until a writer
stamps `f` — grep the repository's hand-built map (not the model's `toFirestore()`, which a
merge-writing method may bypass) before calling such a rule a control, and grade the rules
test the same way: a fixture builder that unconditionally stamps `f` proves a payload
production never sends, and goes green for years. Two corollaries. A client writing with
`set(merge: true)` evaluates the UPDATE limb on the second write, so a gate on CREATE alone
is bypassed by everyone who already has a row — repeat the conjunct or the control only
covers first-timers. And the field cannot then be pinned by `cannotModify`: on a legacy row
it goes absent -> present, which `affectedKeys()` reports, so pinning it refuses every
existing row's update. That leaves the field forgeable, which is a residual to name, not a
gap to paper over — closing it needs the rule to `get()` the parent document.
Such a field has THREE states, not two, and the two non-absent ones behave oppositely: an
EMPTY STRING satisfies `in`, makes the `exists()` path match no document, and skips the gate
SILENTLY (presence without enforcement), while an explicit NULL makes the helper's string
concat an evaluation ERROR, i.e. a hard deny. So normalise unresolvable-to-ABSENT inside the
shared writer (never at one call site), and do not write a comment treating null and empty
as one case — the claim about null is a rules-semantics assertion that needs the emulator.
When the writer derives the value from an object the caller ALREADY holds (the recipe behind
a rating), the stamp costs zero extra reads and a repository-side lookup is usually
impossible anyway — a user-scoped parent path needs the very uid being resolved.

- A read budget must count the RULE's `get()`/`exists()`/`getAfter()` calls too — each is
  billed as a document read, the per-evaluation cache only collapses repeats of the SAME
  document within ONE request, and a missing document still bills one read; a probe behind
  a rule chaining two lookups costs 3x per probe. Re-derive any "N reads worst case" claim
  by opening the rule, not just the query. ARM ORDER inside an OR'd read limb is therefore a
  billing decision, invisible in any behaviour test: a membership arm that `get()`s a parent
  (`isHouseholdMember(resource.data.householdId)`) placed BEFORE a free self-field arm
  (`resource.data.userId == request.auth.uid`) short-circuits the wrong way and bills one
  parent read per ROW of every list query the self arm exists to authorise — the Art. 15
  export is the usual victim, at cap+1 rows. Put the field-only arm first; the limb is
  logically identical.
### Firestore rules & permission patterns
- Full-doc `set()`: create pins `request.resource.data.userId==auth.uid`; update pins BOTH
  `resource.data.userId` AND `request.resource.data.userId`; delete pins
  `resource.data.userId`. Ship rule + repo-support together, or one is dead code.
  Corollary that refutes most "a full `set()` destroyed the doc" claims: an update rule
  carrying `cannotModify([... 'createdAt'])` DENIES any full `set()` built from a
  freshly-synthesized entity, because a client-side `createdAt` (`clock.now()`) always lands
  in `diff().affectedKeys()`. Before writing "an overwrite erased X", open the update limb —
  the overwrite usually fails closed at the server, and the real harm is a lost local edit
  plus a rolled-back optimistic write, not server-side destruction. That corollary is now
  PINNED for both weekly-plan collections (`weekly-menu-plans-rules.test.ts`, W2 personal /
  G1 group) — cite the test rather than re-deriving it, and note the protection is a side
  effect of `*.empty()` stamping `clock.now()` while `copyWith` preserves it. Each factory
  carries its own clock-pinned model test; a "symmetry" cleanup is caught there, not by the
  rules suite, which builds its bodies from literals.
- A DETERMINISTIC COMPOSITE DOC ID (`{parentId}_{uid}`) is an identity claim only if
  something binds body to path (models parse identity from the body; the cheap rule pins
  only the path). Require both: the rule concatenates the id, and the repository's
  `fromFirestore` (not `fromMap`) refuses a doc whose derived id disagrees, identity fields
  non-empty; a list read SKIPS an unusable row rather than blanking the whole read. Keep
  that check OUT of the DELETE decision when the path already encodes the owner — deciding
  from the path keeps a forged row erasable; deciding from the body makes an Art. 9 doc
  permanently un-erasable.
- A co-located consent record must be immutable on UPDATE (rule pins `consentGrantedAt`,
  requires a real Timestamp/bool) and CREATE must refuse an existing id / require
  `consentVersion == currentConsentVersion` (a re-grant is a `create()`, so without that it
  can re-date a stale record). Read the stored doc directly, never `exists()` (swallows a
  failed read as false).
- ANY arm that dereferences `resource.data` DENIES a document that does not exist —
  `resource` is null, the deref errors, and an error is a deny. Do not read this as being
  about the ONLY arm: the live shape is a SAFE arm (`isOwner(userId)`) that later gains a
  field-ABSENCE conjunct (`!('legacyField' in resource.data)`) to fence off an un-migrated
  document, which then denies the empty state too — i.e. every user the collection has no
  row for, usually the overwhelming majority. On an Art. 15 path that is not a quiet
  degrade: `_readDoc` throws, the section returns its failure envelope, and the bundle
  announces itself incomplete for nearly everyone. Repair is `(resource == null || ...)`;
  the test set for such a conjunct is FOUR cases, and the absent one is the one that gets
  written last — absent, legacy-shaped, clean, stranger. `fake_cloud_firestore` enforces no
  rules, so the Dart suite asserting "a user with no row gets null" passes either way. The
  absent case is also where a shared-emulator suite goes VACUOUS: nothing clears documents
  between tests, so "absent" must be a DELETE in the test body, not an omitted seed.
  Prefer `resource.data.keys().hasOnly([...])` over a deny-list naming the one legacy field
  — it denies the next undecided field the day it is written instead of waiting for a human
  to notice (`hasOnly` still permits a SUBSET, so a partially-written document reads fine).
  Its price, which belongs in the deviation entry rather than only in the rule: the read
  gate is now coupled to EVERY writer of that document, and the day a legitimate field is
  added the whole document goes unreadable, so an Art. 15 section fails closed and loud for
  every subject until rules and projection are updated together. That kills the empty
  state and every read-before-create flow (`readOrBuild*`), and it looks like "you are not a
  member" to real members. Path-gated rules (`planId.matches('^'+uid+'_')`) are immune. The
  `(resource == null || <membership>)` repair's residual runs the OPPOSITE way to how it is
  usually written up: absent now ALLOWS, present-non-member still DENIES, so the bit that
  becomes newly readable is PRESENCE, not absence — state it that way, and grade it by how
  guessable the doc id is. SUPERSEDED 2026-08-29: the worked example that stood here — a
  `{conversationId}_{week}` id whose DM form `direct_<uidA>_<uidB>` two uids reconstruct — was
  WRONG, and wrong for the reason this bullet's own advice prevents: nobody grepped the
  writers. A DM is `isGroup: false`, and `closePoll` routes those to the PERSONAL collection,
  so no group-plan document is ever keyed on a DM id and that probe always ALLOWs. The
  example survived three review rounds as reviewer precedent.
  Grade guessability by the SECRET INSIDE the id, never by "derived vs random" — a
  sha256-derived group id is unguessable because its input is a v4 UUID, and "the other ids
  are random" is a falsifiable claim about a generator you have not opened. The disclosure
  itself is PRESENCE; any "so a deny means X happened" clause beside it is a claim about the
  collection's WRITER SET, so grep every creator before letting it stand in a sign-off.
  It cannot widen a LIST/query (query results contain only existing docs), so an Art. 15
  export or cascade filtering on the same field is untouched — but verify the export's
  `.where()` names the SAME field the read rule gates on.
- A rules gate that reads a SERVER-WRITTEN MIRROR and fails OPEN on its absence is only as
  strong as the mirror's DELETERS — enumerate them before accepting "absence means the
  benign case". The recurring one: the writer skips (and deletes) when the owner's
  `users/{uid}` doc is missing, while rules let any user delete their OWN profile doc and
  stay signed in — so a doc-existence owner check reads a self-deleted profile as an erased
  account and the target disarms the control on themselves, permanently, since the weekly
  reconciliation runs the same check. Ask Auth, not Firestore, when the question is "is this
  account gone". Any "never deleted afterwards" clause justifying such a fail-open is a
  measured claim about every deleter, cascade sweep included — strike it rather than reword.
  Count the budget the same way: the mirror buys a participant-count-INDEPENDENT gate, so
  state unique docs AND literal call sites against BOTH caps (10 single-write, 20 in a
  transaction — check whether the live writer is `runTransaction`, which adds the read
  limb's own accesses).
- `allow list`/`allow get` are evaluated SEPARATELY (a `get` grant doesn't pass `list`);
  `auth.uid in resource.data.someMap` checks MAP KEYS, not values; self-only set edits need
  symmetric-difference CEL + `affectedKeys().hasOnly([...])`, and a self-leave needs
  `removeAll()` both directions.
- Burst guards come in two shapes; grade them differently. The legacy
  `rateLimitWrite(collection, seconds)` is `!exists(limitsPath) || ...` over an owner-writable
  bucket: it FAILS OPEN, so a client that never stamps is unlimited. It is a throttle on our
  own repository, never a control. `rateLimitStamped(collection, seconds, key)` (ADR-0020)
  requires the SAME request to stamp `rate_limits/{type}` with `lastWrite == request.time` and
  `lastDocId == key`. Omitting the stamp denies, so every writer of a guarded path must batch
  `stampRateLimit`. Grep each guarded collection's writers for it, or the rule denies every
  write. When reviewing a stamp writer, check three things. (1) The stamp uid must be the
  AUTH uid: the rule builds the path from `request.auth.uid`. (2) Read-then-batch
  "first write only" logic: the batch is atomic, so a misclassified race denies the whole
  batch rather than orphaning a stamp. Check what the update limb already refuses (e.g. a
  `createdAt` in the merge). (3) `lastDocId` copies the DOCUMENT ID into an Art. 15-exempt
  bucket. A composite id (`<from>_<to>_...`, `direct_<a>_<b>`) therefore stores a third
  party's raw uid where their erasure never reaches. The exemption's "one timestamp per
  action" premise does not describe that content. Row COUNT still needs a callable or a
  server counter: a new account starts with a fresh window. A RETENTION promise resting on a
  client-written `expireAt` is a bound only if the rule caps it from ABOVE: a lower bound alone
  (`>= request.time + 1d`) lets any device clock set any lifetime, and shortening the writer's
  offset toward that floor shrinks the clock-skew tolerance of every guarded write. Also grade
  a description of `rate_limits` as a universal over its DOC IDS: non-stamp documents
  (`imports`, `friendSearchMigrated`) share the collection. A CLIENT-clock `expireAt` checked
  against a rules floor (`>= request.time + N`) denies whenever the device is slow by more
  than (lifetime - N), so shortening the lifetime shrinks that margin: re-check the floor and
  the rules-test fixtures (which usually still carry the old lifetime).
- A `hasOnly` allowlist derived from the collection's `hasRequiredFields` list is NARROWER
  than the declared type, and the gap is exactly the OPTIONAL content fields — which deny
  silently and fail-closed the day a client writer sends one (the `configRevision` outage
  shape). Diff the allowlist against the TS interface / model, not against the required
  list beside it. `.size()` is polymorphic (string, list and map alike), so such a bound
  buys COUNT and never type, and never element length.
- Any rules diff adding a `keys().hasOnly` must run the DART guard
  `test/unit/security/rules_allowlist_drift_test.dart`, not only the emulator suite: its
  census counts every `hasOnly(` in the file and reddens on the new one until it is either
  compared against a writer or registered in `_knowinglyUncovered` with an anchor. A
  TypeScript-only verification run ships it red, and this file's own docstring records that
  chronic red is what disarmed the guard last time.
- Moving a denied client write into a CALLABLE puts the doc behind an Admin-SDK read, so
  every distinguishable response is an oracle for a doc the caller can't read — collapse
  not-found/not-a-member/already-done into one reply, but first prove the doc EXISTS on the
  path the callable actually reads, or the merge turns "wrong path" into a false success. A
  repository method returning `Future<void>` can't surface a `removed` flag regardless of
  the CF. A CF deriving authorization from a document FIELD is only as trustworthy as that
  field's UPDATE rule.
- Cross-user point-reads rely on rules alone; log both branches. Accepting a share request
  must verify `caller==request.toUserId` at the accept boundary itself. Idempotency
  existence-checks need their composite index verified — prefer a deterministic doc ID over
  the race. Admin-only collections need an EXPLICIT deny rule even under default-deny.
