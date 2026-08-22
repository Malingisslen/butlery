# firebase-backend-security — accumulated knowledge

Step-0 read for every security/backend task. **Principles only, edited in place** — a
finding extends the bullet it matches or earns a new one; it never appends a dated
paragraph here. The dated raw entry belongs in the append-only
`firebase-backend-security.knowledge.archive.md`. Full contract below ("How new learning
enters this file").

---

## Repository layer contract

**Every repository in `lib/repositories/` MUST use `PermissionValidationMixin`** (CLAUDE.md
rule #3, non-negotiable — missing it is Critical). But `with PermissionValidationMixin` is
the LETTER, not the substance: grep the class body for an actual
`logPermissionCheck`/`validateOwnership` call before crediting it — a read-only +
callable-write repository can carry the mixin and call nothing in it, leaving zero Art. 30
rows for a cross-user mutation (archive: BUT-1838 `FirebaseChatGroupRepository`). A
callable-backed mutator should log the callable's OUTCOME (never `granted:true` before it
answers — that forges the trail) and check whether the CF itself writes an audit row.

**Service access**: `ServiceLocator.get<T>()` (widgets/VMs) or constructor injection (DI
modules). Never `FirebaseFirestore.instance` directly — inject `FirestoreRepository`.
`FirebaseRecipeRepository` is registered as the `RecipeRepository` interface — use the
interface for `ServiceLocator.get`.

## Data-source rules (CLAUDE.md)

| Need | Use |
|---|---|
| Complete user data (settings, avatar, social) | `userService.currentUserProfile` |
| Auth/permission checks only | `permissionService.currentUserId` |

Never mix these. Two live-recurring variants: (1) `PermissionService.currentUser`
SYNTHESIZES a `UserProfile` from the Auth user (`displayName ?? 'User'`) — it looks like a
profile handle but is the auth-only side wearing the user-data type; any
`permissionService.currentUser.<profile field>` stamped onto a document another user reads
is a finding on sight. (2) A denormalized actor-name field written via `copyWith` (whose
`name ?? this.name` default keeps the PREVIOUS editor's name while the id advances)
misattributes on any multi-user doc — stamp an id/name PAIR atomically from
`UserService.profileDisplayName` (profile-first, no Auth fallback) at PERSIST time, never
`authRepository.currentUser?.displayName`, and teach the read side that empty means
"unknown" rather than defaulting to a placeholder.

## Firestore rules pairing

`firestore.rules` (~72KB) MUST match repository permissions in lockstep — a drift is either
a security hole (rule too permissive) or an app break (rule too strict). A new field on a
model with `toFirestore()` is a rules change too: `hasOnly` allowlists fail CLOSED and
SILENTLY (an unlisted field denies every write, with no signal beyond "nothing saved") — grep
`firestore.rules` for its validator in the SAME edit, and demand a rules test that day (one
allowed set, one rejected extra key).

The `firestore-rules-tester` agent owns proving rule behavior — hand off after rule changes
rather than writing rules tests yourself.

## Cost principles (CLAUDE.md)

- A read budget must count the RULE's `get()`/`exists()`/`getAfter()` calls too — each is
  billed as a document read, the per-evaluation cache only collapses repeats of the SAME
  document within ONE request, and a missing document still bills one read; a probe behind
  a rule chaining two lookups costs 3x per probe. Re-derive any "N reads worst case" claim
  by opening the rule, not just the query.
- Avoid unnecessary reads/writes. Batch (Firestore limit: 500 ops/batch; a consolidated
  update is 1 op/doc). Cache aggressively; use indexed queries; prefer deterministic logic
  over LLM calls.

## GDPR compliance baseline

Required for every user-data-touching feature (Critical finding if any is missing):

- [ ] Consent before collection
- [ ] Data minimization
- [ ] Right to access (export)
- [ ] Right to deletion (cascading through subtrees)
- [ ] Right to rectification
- [ ] Data portability
- [ ] Privacy policy linked from any consent surface

## Security best practices

- Input validation/sanitization on every write boundary.
- Grade an interpolated `$e` by its SINK and by the SHAPE OF THE READ, never by the word
  "exception." `AppLogger.warning` reaches `developer.log` only; `AppLogger.error` also
  reaches Crashlytics + analytics and runs the uid redactor, so promoting a log level is a
  privacy change. A `create_composite` index-hint URL carrying another user's uid can only
  come from a QUERY (a single-doc `get()` cannot produce that `FAILED_PRECONDITION`), and
  the error string must never reach the Art. 15 bundle — derive the export's warning from
  `error_code`, never copy `error`/`e.toString()` through verbatim.
- Audit logging for security-critical operations. No exposed keys/credentials (`.env`
  gitignored). HTTPS-only, encryption at rest.

## Performance & query optimization

- Compound queries need composite indexes (`firestore.indexes.json`). `where()`: indexed
  fields first. Always `limit()`. No whole-collection reads on user-facing paths. Use
  subcollections for scalable per-user data.

## Real-time listener hygiene

- StreamBuilder/StreamProvider, never raw `onSnapshot` in widgets. Listeners attached in
  `initState`/VM `init`, disposed in `dispose()`. Stream errors handled.
- Hydrating a page of parents with a per-parent SUBCOLLECTION (archive: BUT-1832
  `message_query_module.dart`) has four failure modes: a per-item listener under
  `switchMap` over the parent stream rebuilds the WHOLE fan on every parent emission — key
  it by the parent-ID SET (`distinct`) so it only rebuilds on membership change; a
  `.take(n)` cap applied AFTER `.reversed` keeps the wrong end — cap on the end the user
  reads from; hydration must reach EVERY reader that hands the entity out (stream, page,
  single-doc, search), grepped, not assumed from a comment; and an error handler returning
  an EMPTY collection is fail-CLOSED, not fail-open — only a null/absent value the combiner
  FILTERS OUT leaves the entity untouched.

## Severity tagging for findings

- **Critical** — security vulnerability, GDPR violation, data-loss risk, memory leak.
- **High** — missing permission check, missing index for a deployed query, performance
  issue at scale.
- **Medium** — optimization opportunity, incomplete validation.
- **Low** — code organization, documentation.

Always include specific code examples and remediation steps.

---

## How new learning enters this file

This file is a **principles document, edited in place** — never a log. Every dated,
ticket-specific narrative belongs in `firebase-backend-security.knowledge.archive.md`
instead, however recent; the test is SHAPE (a story about which ticket found what), not age.

- **Extends an existing bullet?** Edit it in place — merge aggressively; most findings are
  a new instance of a pattern already here.
- **A genuinely new durable rule** (a future run would act differently because of it): add
  one tight bullet under the right category, AND append the full dated narrative to the
  archive. It earns its place only if SHARP and FINDABLE — a principle that takes a
  paragraph to say will not be read. Malin's Art. 15/17 balancing calls are DECISIONS, not
  lessons: cite `docs/architecture/ACCEPTED_DEVIATIONS.md` rather than restating the
  reasoning, and never let a merge blur two decisions made deliberately differently.
- **A one-off verified-clean review with no new reusable rule**: archive only.
- If an edit would grow this file, sharpen or retire a principle first. A bullet that has
  accumulated several "CLOSED 2026-..." status updates inline should become ONE sentence
  describing the current rule, with the history left in the archive.

## Principles

### The one architecture fact behind the most bugs
Butlery splits a user across **two** Firestore docs with different read rules: `users/{uid}`
(private, `isOwner||isAdmin`, CF-authoritative for `birthYear`/`isMinor`) vs
`public_profiles/{uid}` (world-readable to any authenticated user, client-written via
`saveProfile`, and what search/cross-user reads and the client's OWN hydration actually use).
**A server-set flag written only to `users/{uid}` protects nothing that search, another user,
or the client's own UI reads.** For any "CF sets flag X, client/search reacts to X" design,
name which doc each end touches before approving it.

### Parallel write paths to the same collection
- A tidy `service.<feature>.op()` facade and the module chain the UI actually calls can
  diverge (one is dead code) — grep the real caller (view/VM) before crediting any fix; a
  fix on the unreached twin reviews green and changes nothing.
- TWO STORAGE SHAPES for one field (a parent-doc array AND a matching subcollection) means
  a write filling only one shape is invisible after the next read through the other — check
  which shape every writer/reader uses. Fix: put the fan-out in the SERIALIZER so every
  write inherits it by construction, gate a copy-then-delete on a SERVER-confirmed count
  (`metadata.isFromCache == false`, never a local-cache answer), and on a cross-tree copy
  strip foreign attribution (`addedBy*`/`purchasedBy*`) unless the uid is the copying
  owner's — rebuild via the model's full CONSTRUCTOR (a partial rebuild resets omitted
  fields to default) and check a nulled id doesn't flip a derived getter a live consumer
  reads.
- A "which shape is this" type-detection helper reading the OTHER collection first can bill
  a guaranteed-denied read on the happy path (probing shared for a personal-list id, which
  rules deny by construction) — pass the known type through explicitly instead.

### Firestore rules & permission patterns
- Full-doc `set()`: create pins `request.resource.data.userId==auth.uid`; update pins BOTH
  `resource.data.userId` AND `request.resource.data.userId`; delete pins
  `resource.data.userId`. Ship rule + repo-support together, or one is dead code.
- Prefer a targeted `update({changed fields})` over `set(merge:true)` from a possibly-stale
  local base (offline/queued replay) — a merge re-sends unchanged privileged fields, letting
  the one caller allowed to touch them (the owner) resurrect a removed member via a stale
  write. Shipped shape: diff the proposed doc against the stored one, emit only differing
  keys (map fields as per-key paths so deletion survives `merge:`), empty diff = skip the
  write, THROW if a privileged key differs while the base is from cache
  (`metadata.isFromCache`).
- A guard set is scoped to a method's callers; promoting it to a public INTERFACE
  invalidates that scope — review the promotion and its sibling as one change, require
  guard parity. An injected `void Function({...})` callback silently drops the `await` on a
  `Future<void>`-returning `logPermissionCheck` (Dart void-covariance) — declare it
  `Future<void> Function({...})` and await, only once the sink can't throw.
- `requireCurrentUserId()` then `logPermissionCheck(granted:true)` with no real check
  forges the trail. Run the actual `validate*Permission`, log its verdict, fix every sibling
  (create/update/mutate) in one pass, checking EVERY conjunct of the matching rule.
- An OPT-IN named-parameter guard defaults every EXISTING caller into the restricted branch
  (silent no-op) — ship a named METHOD on the interface instead, with its own exception
  type and a caller that honours the result (ADR-002).
- No `firestore.rules` match block = default-deny — grep for every new collection path. An
  admin-only collection-group rule can make "no match block" a false claim; word it "no
  rule grants a CLIENT this read." A denied read inside a shared `try` DISCARDS sibling
  reads already collected — give each probe in a multi-read section its own inner try.
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
- `allow list`/`allow get` are evaluated SEPARATELY (a `get` grant doesn't pass `list`);
  `auth.uid in resource.data.someMap` checks MAP KEYS, not values; self-only set edits need
  symmetric-difference CEL + `affectedKeys().hasOnly([...])`, and a self-leave needs
  `removeAll()` both directions.
- `rateLimitWrite(collection, seconds)` is live only PER BUCKET — grep `.doc('<bucket>')`
  under `userRateLimits` before calling any conjunct live or dead (live today: `messages`,
  `comments`, `social_requests`, `activity_events`; most others, incl. `audit_logs`, are
  inert).
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
- `documentId()` prefix-range erasure needs the upper bound at `p` + U+F8FF (invisible in
  every editor/diff) — byte-check with `grep -P "\x{F8FF}"` before filing a "degenerate
  range" as a bug.
- Overriding `create()`/`update()` does NOT cover `createBatch`/`updateBatch` — put the
  invariant in the shared `toFirestore(entity)` serializer instead, but grep for hand-built
  `.set(`/`.update(` calls bypassing the repository, and watch a `copyWith` transform
  inheriting a stray default (`updatedAt ?? now()`) that restamps every "clean" write.
  `validateRequiredFields` checks `containsKey` only — never credit it with rejecting an
  empty/blank value.
- UPDATE permission checks must load the STORED doc's ownership field, not the submitted
  entity's. A `not-in`/`in` filter silently excludes docs where the discriminator is
  absent; replacing a PREDICATE with an ENUMERATION reclassifies HISTORY — derive the list
  from `git log -S` on the writer, never today's live callers.

### GDPR: deletion, export, and the "wrong probe shape" bug class
- **Most-repeated defect**: a cascade/probe/export query targets the wrong field, shape or
  COLLECTION NAME — an owner-keyed collection probed by `userId`, an OR-owned collection
  folded into one query instead of per-field, or a constant naming a path nothing writes.
  Open the actual `.where()`/`.collection()` clause; a function with the right name proves
  nothing. Cheapest check: grep `firestore.rules` for the path — no match block means
  nothing writes there. Sibling shape, WRONG NESTING LEVEL: a class mixing
  `UserScopedFirebaseRepository` (repoints CRUD to `users/{uid}/<name>`) with hand-built
  top-level `firestore.collection(name)` calls creates two disjoint trees under one name —
  resolve `getCollectionRef()` for the exact class, and grep the LITERAL string too (a
  hard-coded Admin-SDK reader survives a rename and silently reads an empty tree).
- A rules diff adding a per-document READ conjunct breaks every UNFILTERED query on that
  collection whole (one refused doc fails the query entirely) — the Art. 15 export is
  usually the first casualty. Enumerate every reader (stream, pagination, search, export,
  cascade probes) and require each to mirror the predicate.
- "May be incomplete" convention: a row-level catch (so one bad row doesn't fail the
  section) must still set a SECTION-ROOT `error_code` with no `error` key (`error` = "could
  not export", bare `error_code` = "may be incomplete") — never a bespoke flag or raw
  `e.toString()` alone (leaks uids/paths into what the subject may forward to a regulator).
  Truncation: fetch `limit+1`, flag `truncated = fetched.length > limit`; a NESTED per-parent
  cap needs the identical flag.
- A denormalized ERASURE HANDLE (flat `array-contains` trail, needed because Firestore
  can't filter inside an array of maps) must be extended by EVERY write path (derive the
  obligation from the payload so a new path inherits it by construction), removed in the
  SAME write as the scrub and added to the residual probe, and constrained APPEND-ONLY in
  rules (`hasAll(resource.data.F)` + size bound) or any editing member can strip another
  user's uid.
- Deleting a parent doc does NOT delete its subcollections — child sweep (STRICT) before
  parent delete (best-effort), covering every legacy name variant. TTL fields need three
  things: the `gcloud --enable-ttl` policy (separate admin action), a backfill for
  pre-existing docs, and a deletion-cascade cross-check if the collection carries a raw
  `userId`.
- "Export ⊇ erasure" is a field-PAIR property — the two filters must target the identical
  field on the identical collection; check both cascades together. A membership MAP KEY is
  itself a raw identifier — clearing the name but leaving the ACL key is incomplete
  (`FieldValue.delete()` it in the same scrub). A row authored by a SYNTHETIC identity
  ("system") naming a real person in FREE TEXT is invisible to every id-keyed cascade — give
  it an erasure HANDLE field. Denormalized PII travels in FIELD GROUPS (`sharedBy*`,
  `lastActivityBy*`); the rename-propagation CF (`on-profile-updated.ts`) is the inventory —
  diff it against the deletion cascade ("propagated on rename, not scrubbed on erasure" is
  the recurring miss). A residual probe and its cascade must share the same DISCOVERY
  QUERY, or the mismatch leaves a permanently-reported, unfixable residual — every probe
  here is FIELD-keyed and blind to an identifier living only in a DOCUMENT ID, so a step
  that knowingly leaves such a doc standing must flip its own `complete`/`gdprCompliant`
  flag false.
- A nullable field where null is meaningful must not reuse null as "not provided" on a
  merge-write (sentinel + omit branch instead); a `toFirestore()` that OMITS a null field
  makes a consent-withdrawal merge silently fail to erase it — needs a full `set()`. A
  local-cache PARSER returning `defaults()` for an unusable payload destroys the caller's
  only way to say "no cache" — fail toward NULL, never a populated default that gets
  written back; grep for the LEGACY on-disk shape an older app version wrote.
- Relocating a field into a subcollection drops it from every DERIVED surface not named in
  the ticket — enumerate all four: display path, Art. 15 export (needs a collection-group
  `match`), Art. 17 cascade + probe, and the rules validator. A section's own prose
  describing its contents becomes FALSE the moment the storage shape moves under it.
- Audit retention differentiates by category (consent 730d, general 180d) via the
  `operation` STRING — every writer must set it, purge must exclude fresh consent events.
  Renaming/retiring a token: grep CONSUMERS and `git log -S` the old spelling and writer
  METHOD, since rows outlive their caller. `auditRepository` is an OPTIONAL constructor arg
  some DI modules don't pass — check DI registration, not the repository, before crediting a
  trail as live.
- A UI gate hiding a CONSENT control must key on the absence of a live consent, not only
  the precondition that made it offerable (Art. 7(3)) — read "do I have a record?" BEFORE
  the eligibility check. A one-shot backfill needs a REQUEST-LEVEL resume cursor (both
  request and response types), not a loop-local one, or every invocation restarts at the
  top. An EU single-region→multi-region move is NOT a Chapter V regression — only a move to
  `global`/outside-EEA is.

### Age gating & minors (server-authoritative — protected category)
- Swedish legal floor is **15** (Dataskyddslagen 2 kap. 4§), not 13 (GDPR Art. 8). Enforce
  in `firestore.rules` itself — a Dart-layer check alone is advisory only.
- Gate on custom claim `request.auth.token.ageCompliant==true`, never a Firestore `get()`.
  Client must `getIdToken(forceRefresh:true)` after a compliant verdict or the first UGC
  write denies on a stale token (fail-safe: deny).
- `birthYear`/`isMinor` immutability: rule compares old vs new on UPDATE (holds under
  merge) AND requires null on CREATE. An idempotent-retry branch must NOT recompute either
  from the request payload once stored, or a retry with a different birthYear can flip
  `isMinor` back to false.
- Rejection-path audit rows must never link a real identity to "is under 15" (operation/
  reason/basis/timestamp + hashed hour-bucket only); compliant-row audit stores
  `userIdHash` + coarse `birthDecade`, never raw birthYear.
- `isSearchable` for minors has ONE chokepoint (`UserProfile.toFirestore()`), backed by an
  explicit rules hard-deny on a minor setting it true server-side — a legacy `true` isn't
  force-corrected by the rule itself, only the next full save. `isMinor` must be mirrored
  via `public_profiles`/settings, never left only on `users/{uid}` (see the two-doc
  architecture fact); a save must re-read the AUTHORITATIVE server value before it can make
  a minor MORE discoverable.
- Minor-specific analytics minimisation needs EVERY writer of the gating property grepped,
  not just the primary setter. A group-safety CF removing a minor must delete every mirror
  the app's own client removal path touches (membership doc, per-user maps, participants
  subcollection).

### PII handling & logging
- Bounded enum/numeric telemetry (error codes, token counts, `schemaVersion`) is safe to
  log — the leak surface is the adjacent free-text field; bound length even for "should be
  small" fields.
- `AppLogger.error` is not device-local — it forwards the raw `e` object to Crashlytics and
  `error.toString()` to analytics, and the uid redactor applies to the MESSAGE string only.
  Never assume "stays on the device"; think before logging an exception whose text embeds a
  query built from a uid (a `memberPermissions.<uid>` index-hint URL is the realistic
  shape). A Dart-core throw (`StateError`, `Exception`) is NOT covered by the exception
  classes that mask in `toString()` — mask at the throw site.
- On WEB Crashlytics is skipped, so `WebErrorReporter` is the only sink, and a "mask the
  message, leave the STACK readable" carve-out there does not hold: a web `StackTrace`
  is the JS engine's `Error.stack`, whose HEAD line is the exception's own `toString()` —
  re-exporting every identifier the message field just masked. Mask the head up to the
  first frame; frames stay raw (the {20,28} uid rule eats class names). Mask BEFORE
  truncating: a cap applied first cuts a 28-char uid below the window (passes RAW) and
  re-hashes a `direct_` id out of parity with the same conversation elsewhere — that, and
  NOT capacity, is the reason for the order, because scrubbing can LENGTHEN
  (`[PERSONNUMMER]` is 14 chars for an 11-13 char match).
- A head/frame SPLIT covers only the line-prefixed engines — V8 `at `, Dart `#N`.
  SpiderMonkey/JSC emit `fn@url:line:col` with no header line, so those traces match no
  frame and are masked WHOLE (safe, but every frame mangled on Firefox/Safari), and a
  message line beginning `#1`/`at ` splits early, dropping its tail outside the mask.
  Probe any such regex against all three engine spellings before writing "both spellings
  the web engines emit."
- A log line's PII profile changes when its function gains a new CALLER, with no edit to
  the logging code. A composite doc id (`direct_{uidA}_{uidB}`, `{uid}_{date}`) is personal
  data wherever it lands; hash it through one chokepoint helper. `\b` treats `_` as a word
  character, so it never fires inside such an id — run the regex on the exact shape rather
  than reading it, and note a raw-uid log guard misses structured args
  (`AppLogger.x({'uid': uid})`).
- A field on a world-readable doc must be audited individually — a boolean gating SEARCH
  does not gate DIRECT-FETCH. A moderation "hide" flag is search-suppression + UI-
  placeholder only unless every direct-fetch consumer also filters it. A presence opt-out
  must freeze the source write, not just gate a boolean — a hidden dot with an advancing
  `lastActiveAt` still leaks "active N min ago."
- A rollback error message must not read a field a DIFFERENT, unrelated failure also
  writes — use a dedicated field cleared at the START of every mutation entry point, read
  through a self-clearing `consumeError()` called before `if (!mounted)`. A NEW exception
  subtype needs its own arm at the message-mapping seam in the same diff.
- An automatic/background profile mutation must be a single-field `update()`, never a
  full-profile `set()` (clobbers peer-owned denormalized fields).
- Scrubber regexes: ASCII `\b` misfires before å/ä/ö; an unbounded leading letter-class
  before a literal suffix is O(n²) regex-DoS; case-sensitive heuristics no-op on ALL-CAPS.
- Any user string interpolated into an LLM prompt must be type-checked, trimmed, stripped
  of sentence-forming punctuation, and fail-undefined when absent.

### Query cost, indexes, real-time listeners
- Every `.snapshots()` in `lib/repositories/` ends in `.limit(N)` (per-user ~100, per-group
  ~200, cross-user collection-group ~200-500; per-thread → cursor-paginate instead). Live
  pagination uses a DOC-cursor (`startAfterDocument`) — value-cursors miss/double-emit docs
  sharing one `serverTimestamp()`. `where(equality)+orderBy(different field)` needs a
  composite; a lone equality-or-range does not.
- **`.where(f, isNotEqualTo: null)` / `isEqualTo: null` builds NO CONDITION** —
  `cloud_firestore`'s builder adds each operator only if non-null, so a literal null
  compiles, reads as a filter, and leaves an UNFILTERED sweep. Use `isNull: false/true`. On
  a member-scoped collection this reads as "my data won't load" (rules refuse the unscoped
  query), not as an over-share. `fake_cloud_firestore` THROWS on the bad spelling, so a
  green Dart unit test proves the QUERY only, never the permission.
- A per-doc visibility rule needs a SPLIT query (owner branch unfiltered, friend branch
  STRICT equality) — a "field absent" looseness re-opens the leak.
- Judge "is swallowing this read safe" by whether the downstream safety verdict defaults
  permissive on missing input (permissive-default = Critical). A parser/lookup that can
  turn 1 input into N reads needs a cap at the split site.
- A write-coalescing guard ("once per day") keyed off a stored timestamp is inert for a doc
  whose PARSER defaults that field to `now()` on absence — check what an absent field
  parses to before trusting the guard.
- A pre-write EXISTENCE read filtering stale ids from a batch write: gate any "nothing
  exists any more" verdict on `snapshot.metadata.isFromCache == false` (an offline query
  resolves from cache with no error); `whereIn(FieldPath.documentId, chunk)` at 30 IDs bills
  only the submitted rows.
- `runTransaction` has NO offline path — a `set()` lands in the local cache instantly, but
  a transaction throws `unavailable` offline with no optimistic write; a write moved to a
  transaction needs an explicit fallback or an accepted-deviation entry (BUT-1683). Skip a
  true no-op write entirely, keyed on "no submitted row matched a live one" (an
  activity-stamp field defeats an object-identity check). `deadline-exceeded` is a
  client-side timeout, not proof of offline. The offline-safe repair is a field-level MERGE
  primitive (`FieldValue.arrayUnion` for an append); a change to an EXISTING row has none.
  Enforcement shape: a `toFirestore()` diff that THROWS on any differing key outside a
  narrow whitelist rather than falling back to a full write (which re-sends a stale ACL) —
  mutation-test such a guard on the WHOLE test file, never a name-scoped single test.
- Per-item analytics loops over a REPLACEMENT set double-count on regeneration — log once
  with a count. A consent check with no in-flight dedupe means N fire-and-forget events on a
  cold cache issue N concurrent reads — wrap the whole emit in one `unawaited(...)`.

### Admin-only aggregate repository bypass (6+ repos confirmed clean)
- Skip `PermissionValidationMixin` only when ALL FOUR hold: read-only; rule-gated by
  `isAdmin()`; PII-free output; errors degrade to empty/zero, never rethrown. Document the
  rationale in a class doc comment. Any one failing = mixin mandatory.
- Admin callables with a client `limit` must reject invalid values explicitly
  (`invalid-argument`) — `limit||fallback` wrongly treats `0` as "use fallback."
- A post-batch `.get()` may not reflect a `FieldValue` transform from the SAME batch — never
  use it to enforce a size cap; use a transaction.

### LLM / Vertex / prompt safety
- Kill-switches: master server gate fails CLOSED; a client-side Remote Config shortcut can
  fail open. An uninvalidated module-scope cache can serve stale config for the warm-
  instance lifetime — hours, not an optimistic "~30 min".
- Treat raw LLM output as adversarial: bounded parsers only, enum-drift logging capped, and
  verify no consumer branches a decision off a cost/telemetry field before calling it
  "telemetry-only." A locale/variant string reaching only telemetry has zero injection
  surface — confirm by grepping every actual caller.
- Model-integrity gates sit BEFORE any disk write/cache-path assignment; a cache-path LOAD
  skips re-verification only when the threat model is transit/storage substitution. A
  result's "ok" can be true while "unverified" is also true — callers must check both.

### Cloud Functions / cascade mechanics
- A deterministic doc ID + `set()` (not `add()`) is the standard idempotency primitive.
  Region pinning covers every export in a file — removing it reverts unconverted functions
  to the default region; clients must match the region option or 404 in prod.
- A scheduled drainer retrying a state machine needs a max-attempts cutoff to `failed`.
  Storage/document triggers cannot carry App Check — put it on the client-facing callable
  that produces the triggering write.
- A virtual-parent-doc subcollection tree (parent never written) is valid for owner-scoped
  logs; GDPR cascades use listCollections-on-ghost-root + conditional root delete, with the
  rule's `hasOnly([...])` matching the model's `toFirestore()` key set byte-for-byte. An
  aggregate recomputed from a deletable subcollection should use the existing
  `onDocumentWritten` trigger (fires on delete unconditionally) over an explicit cascade
  call.

### Storage / uploads
- Storage download URLs are percent-encoded — `Uri.decodeFull` before string-matching
  against unencoded segment literals. Upload/delete authorization should funnel through
  exactly ONE low-level write method so one validation gate covers every entry point. A
  negative-permission storage test asserting only `isNull` proves nothing — assert the side
  effect directly (bytes did NOT land at the foreign path), paired with a positive control.

### Third-party / infra
- Cert pinning: empty per-host pins must no-op fall through; release-safety checks must
  `throw`/`StateError` (never bare `assert`); an in-flight-request guard must key by the
  real serialization axis (per-host), not one global `Future?`; a pin-reject-then-fallback
  is safe only if the reject happens before the request hits the wire (`onRequest`, not
  `onResponse`).
- Native-only plugins have no web SDK — a `kIsWeb` branch calling one silently no-ops.
  `execFileSync(cmd, argsArray)` is immune to command injection even with
  attacker-influenced argv — the risk is shell-string interpolation, not the args.

### Testing / tooling gotchas
- `fake_cloud_firestore` enforces neither RULES nor INDEXES — a green fake test proves
  query shape only. Sharpest instance: a real `get()` on a nonexistent doc in a rules-gated
  collection returns `permission-denied` (the read rule dereferences null `resource.data`),
  while the fake returns `exists == false` — a "try shared, fall back to personal" probe
  whose `catch` RETURNS the inconclusive value instead of falling through reads as covered
  and answers "unknown" forever in production; state such a throw in the interface.
- Prefer real-repository + fake-Firestore + auth-state-fake tests over side-effect stubs
  that mock away the boundary under test. Cascade unit tests against a fake Firestore must
  bridge the production `ServiceLocator`, or it throws, gets caught, and the step lands
  silently in `failedCollections` — a green test proving nothing.
- A standalone admin script is safe to delete once: no exports; not exported from
  `index.ts`; no `package.json` entry; no dedicated test; not named in CI/deploy config.
  Reference `firestore.rules` branches by path+rule type in comments, never line number.

### Superseded
- `activity_events` and comment-image Storage orphans (both previously open follow-ups
  here) are fully closed and retired — grep the archive for the closing entries rather than
  re-filing either.

---

## When to consult the archive

- An export section returns empty or a value looks wrong, and you need to tell "denied" from
  "genuinely nothing there" — grep the archive by collection name for a prior probe-shape
  finding before re-deriving it.
- A cascade step reports success while rows are still on disk, or a residual probe stays
  red after a fix — search for the ticket/collection; the discovery-query-mismatch pattern
  has recurred multiple times and the fix is usually already recorded.
- A finding-in-progress feels familiar — search by collection name or symptom before filing
  it as new.
- You need the exact rule predicate, code excerpt, or full multi-round narrative behind a
  principle above — every principle here has its raw history in the archive.
- You're about to append a new dated entry — check first whether it should instead extend a
  bullet above.
