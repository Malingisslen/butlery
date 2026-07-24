# firebase-backend-security — accumulated knowledge

This file is the agent's long-term memory across sessions. The agent **MUST**
read it as Step 0 of every security/backend task and **APPEND** to it when
it discovers a new pattern, settles a GDPR question, or is corrected by the
user.

## How to update this file

This file holds **principles** and is meant to be rewritten — see "How new learning enters
this file" below for the full contract. In short: edit the bullet a finding extends; the
dated raw entry goes to `firebase-backend-security.knowledge.archive.md`, which is the
append-only audit trail.

---

## Repository layer contract

**Every repository in `lib/repositories/` MUST use `PermissionValidationMixin`.**
This is non-negotiable — it's CLAUDE.md rule #3 and the foundation of the
authorization story. If you find a repository that doesn't use it, that is
a Critical-severity finding.

**Service access**: code uses `ServiceLocator.get<T>()` (in widgets/VMs) or
constructor injection (in DI modules). Never `FirebaseFirestore.instance`
directly — inject `FirestoreRepository`.

**DI registration**: `FirebaseRecipeRepository` is registered as the
`RecipeRepository` interface. Use the interface for `ServiceLocator.get`.

## Data-source rules (CLAUDE.md)

| Need | Use |
|---|---|
| Complete user data (settings, avatar, social) | `userService.currentUserProfile` |
| Auth/permission checks only | `permissionService.currentUserId` |

Never mix these — the bug pattern is "settings don't persist" because the
write went through the auth-only handle and the cache wasn't refreshed.

## Firestore rules pairing

`firestore.rules` (~72KB) MUST match repository permissions. When repository
code adds/removes a permission check, the matching rule branch must change
in lockstep. If they drift, either the rule is too permissive (security
hole) or the rule is too strict (rules-reject breaks the app).

The `firestore-rules-tester` agent owns proving rule behavior. Hand off to
it after rule changes — don't write rules tests yourself.

## Cost principles (CLAUDE.md)

- Avoid unnecessary Firebase reads/writes.
- Batch operations (Firestore batch limit: **500 ops per batch**;
  consolidated updates = 1 op per doc).
- Cache aggressively; use efficient queries with indexes.
- Prefer deterministic logic over LLM calls. LLMs only when truly needed
  (free-text, creative generation).

## GDPR compliance baseline

Required for every user-data-touching feature:

- [ ] User consent before data collection
- [ ] Data minimization (only what's needed)
- [ ] Right to access (user can retrieve their data)
- [ ] Right to deletion (cascading where the data lives in subtrees)
- [ ] Right to rectification (user can update)
- [ ] Data portability (export functionality)
- [ ] Privacy policy linked from any consent surface

Critical finding if any of these is missing for a new user-data feature.

## Security best practices

- Input validation and sanitization on every write boundary.
- Error handling must NOT leak sensitive data (no raw Firestore error
  messages to the user).
- Audit logging for security-critical operations (rule grants, role
  changes, deletions).
- No exposed API keys or credentials — `.env` is gitignored; check
  `.env.example` matches the shape but contains no secrets.
- HTTPS-only, encryption at rest where applicable.

## Performance & query optimization

- Compound queries require composite indexes — confirm in
  `firestore.indexes.json` before merging.
- `where()` clauses: indexed fields first.
- Always `limit()` results that could grow large.
- No "read entire collection" queries on user-facing paths.
- Use subcollections for scalable per-user data.

## Real-time listener hygiene

- StreamBuilder/StreamProvider patterns; never raw `onSnapshot` in widgets.
- Listeners attached in `initState`/ViewModel `init`.
- Listeners disposed in `dispose()` — leak finder catches violations.
- Stream errors handled (don't let an unhandled stream crash the UI).

## Severity tagging for findings

- **Critical** — security vulnerability, GDPR violation, data-loss risk,
  memory leak.
- **High** — missing permission check, missing index for a deployed query,
  performance issue at scale.
- **Medium** — optimization opportunity, incomplete validation.
- **Low** — code organization, documentation.

Always include specific code examples and remediation steps.

---

## How new learning enters this file (updated 2026-07-24 — knowledge-diet pass)

This file is a **principles document**, not a log — it stayed a dated append-only log through
2026-07-20 (153 entries) until it cost ~66k tokens per Step-0 read with the actual patterns
buried in narrative. That full log is preserved verbatim, in order, in
`firebase-backend-security.knowledge.archive.md`. Going forward:

- If a new finding **extends or supersedes** a bullet below, edit that bullet in place (note a
  supersession in the `### Superseded` section if the old guidance was actively wrong).
- If it's a **genuinely new durable rule**, add one dated line to the archive file (same
  `### YYYY-MM-DD — title` format as before) with the full narrative/code/ticket ID, AND add a
  short bullet for it under the right category below (or a new category). The archive entry is
  where "append-only, date every entry" still applies in full; the bullet here is the permanent
  distillation.
- If it's a **one-off verified-clean review with no new reusable rule**, it can go to the
  archive alone — don't pad the principles section with narrative that doesn't change a future
  decision.

## Principles (distilled from 153 dated incident entries, 2026-04-25 to 2026-07-20)

_Raw entries are archived verbatim in `firebase-backend-security.knowledge.archive.md` (BUT
ticket IDs, code excerpts, full narrative). Before appending a new dated entry, check whether it
extends a bullet below instead of restating one._

### The one architecture fact behind the most bugs
Butlery splits a user across **two** Firestore docs with different read rules: `users/{uid}`
(private, `isOwner||isAdmin`, CF-authoritative for `birthYear`/`isMinor`) vs
`public_profiles/{uid}` (world-readable to any authenticated user, client-written via
`saveProfile`, and what search/cross-user reads and the client's OWN hydration actually use).
**A server-set flag written only to `users/{uid}` protects nothing that search, another user, or
the client's own UI reads.** For any "CF sets flag X, client/search reacts to X" design, name
which doc each end touches before approving it.

### Firestore rules & permission patterns
- Full-doc `set()` collections: create pins `request.resource.data.userId==auth.uid`; update
  pins BOTH `resource.data.userId` AND `request.resource.data.userId`; delete pins
  `resource.data.userId`. Rule and repo-support ship together, or one is dead code.
- A collection with no rule block silently default-denies
  (`match /{document=**}{allow read,write:if false}`) — writes look implemented but are
  rejected. Grep `firestore.rules` for every new collection path in a diff first.
- `allow list` and `allow get` are evaluated separately — a `get` rule granting
  `auth.uid in resource.data.arrayField` does not make the matching `list` pass; a
  membership-gated query needs its own `list` branch + composite index.
- `request.auth.uid in resource.data.someMap` checks MAP KEYS, not values.
- Self-only set edits: symmetric-difference CEL
  (`before.toSet().difference(after).union(after.toSet().difference(before)).hasOnly([auth.uid])`)
  + `affectedKeys().hasOnly([...])`. Self-leave-a-shared-doc needs `removeAll()` both directions
  or a recipient can grief by dropping others while leaving.
- `rateLimitWrite(collection, seconds)` is only live if a write path stamps
  `users/{uid}/rate_limits/{collection}.lastWrite` — else it's a permanent no-op.
- Cross-user point-reads rely on rules alone (a client pre-check needs the same read); still
  call `logPermissionCheck` on both branches — `validateReadPermission` would be circular.
- Accepting a social/share request must verify `caller==request.toUserId` at the accept
  boundary, not rely on a downstream ownership check.
- Idempotency existence-check queries need their composite index verified in
  `firestore.indexes.json` — a missing index throws `FAILED_PRECONDITION`, usually swallowed,
  silently defeating the guard. Prefer a deterministic doc ID over an existence-check race.
- Admin-only collections need an EXPLICIT `allow read, write: if false;` even under
  default-deny (grep-auditable, immune to future wildcard widening). Keep `audit_logs/`
  (canonical trail, retention policy) distinct from `audit/` (other server-only trees).
- `documentId()` prefix-range erasure via `.startAt(p).endAt(p)` with identical bounds is a
  CLOSED range matching only a doc literally equal to the prefix — it under-matches and deletes
  NOTHING. Treat as Critical; test with a seeded-target + seeded-other-user pair.
- Overriding `create()`/`update()` for an invariant does NOT cover `createBatch`/`updateBatch` —
  those live on the base class and skip the override. Override the batch methods too, or hoist
  the assertion into a shared private method both call. Rules are the real backstop.
- On UPDATE, permission checks must load the STORED doc's ownership field, not the submitted
  entity's — else a caller who is a member of TWO groups can re-parent a doc between them by
  resubmitting it.
- A `not-in`/`in` filter (e.g. an audit purge sweep) silently excludes docs where the
  discriminator field is ABSENT from both buckets — every writer must set it unconditionally.

### GDPR: deletion, export, and the recurring "wrong probe shape" bug
- **Most-repeated bug class: a cascade/probe/export query targets the wrong field or shape for
  the collection** — seen 3+ times independently: `where('userId'==uid)` against a collection
  keyed `ownerId` (matches zero, "deletion" no-ops); an OR-owned collection
  (`senderId==uid OR targetUserId==uid`) folded into one probe instead of a per-field loop; a
  subcollection with no `userId` field probed by equality instead of existence. **Always open
  the actual `.where()` clause and confirm it matches the collection's real ownership
  field/shape — a function existing with the right name proves nothing.**
- "Export ⊇ erasure" is a field-PAIR property: export filter and deletion filter must target the
  identical field on the identical collection. Every new user-data collection needs BOTH
  cascades checked in the same review (deletion AND export) — one wired, one forgotten recurs.
- A pure `users/{uid}/*` subcollection is cheapest to get right: erase = one entry in a generic
  subcollection sweep, export = one whole-doc read of the same subcollection, nothing to
  keep in sync field-by-field.
- Cross-user cascade mutations stage their audit-log entry in the SAME batch as the mutation.
- Denormalized author/sharer PII travels in FIELD GROUPS (`sharedBy*`, `authorName*`) —
  tombstoning one field on deletion requires clearing every field sharing that prefix.
- Anonymize (don't hard-delete) a row that is also someone else's GDPR evidence.
- Prefer read-modify-write list rewrites over `FieldValue.arrayRemove()` in scrubs — test fakes
  silently no-op `arrayRemove`, hiding a broken cascade.
- A cascade-then-destructive-step must not proceed when the cascade swallowed errors and
  returned an ambiguous "0" — "0 matched" and "0 because it threw" must be distinguishable.
- `commitInChunks`: `strict:true` when a partial purge leaves live PII; best-effort only when
  idempotent/retried next run. Counts ITEMS not ops — pass `opsPerItem` when a mutate callback
  stages MORE than one `batch.*` call (multiple `FieldValue` ops inside one `batch.update()` are
  still 1 op).
- Distinguish `permission-denied` (rethrow — a rules-engine rejection is a bug worth surfacing)
  from transient errors (swallow best-effort) in cross-user cascade writes.
- Pagination style must match the mutation: a DELETE loop over a filtered query needs no cursor
  (the matching set shrinks every pass); an UPDATE loop needs `startAfterDocument` (updated docs
  stay in the result set and get revisited forever without one).
- Export truncation idiom: fetch `limit+1`, `truncated = fetched.length > limit`, export only
  `take(limit)`. Keying truncation off `length>=limit` falsely flags an exactly-complete export.
- A roster/keep-set diff that DELETES user data must refuse to run when the keep-set is empty or
  implausibly small — an empty denormalized member list must not read as "everyone left"; guard
  `if (roster.size===0) return docs;` and prefer the authoritative membership list over a
  denormalized projection built for a different query.
- An EU single-region→multi-region move (e.g. Vertex `europe-west1`→`eu`) is NOT a Chapter V
  regression — only a move to `global`/outside-EEA is; treat that as Critical.
- Audit retention differentiates by category: consent events 24mo/730d (Art 7(1)); general 6mo/
  180d (Art 5(1)(c)) — the general purge must exclude fresh consent events, and every writer
  must set the discriminator field.
- A blocked/admin-only collection's Art-15 export goes through an admin-SDK callable scoped to
  `request.auth.uid`, never a widened user-side read rule.
- TTL fields need THREE things: the `gcloud ... --enable-ttl` policy itself (separate admin
  action, not deployed with code); a backfill for pre-existing docs; a deletion-cascade
  cross-check if the collection carries raw `userId` (or a documented accepted residual).
- A nullable field where null is meaningful must not reuse null as "not provided" on a
  merge-write — use a sentinel + omit-the-key branch, or a degraded read silently clears the
  stored value. Conversely, `update()`/merge on a repo whose `toFirestore()` OMITS a field when
  null means a consent-withdrawal write that nulls it silently FAILS to erase (merge never
  touches an absent key) — that write needs a full `set()` (no merge), after the same
  permission-check chain, and only where no peer-owned field would be clobbered by the replace.

### Age gating & minors (server-authoritative — protected category)
- Swedish legal floor is **15** (Dataskyddslagen 2 kap. 4§, information-society + social
  component), **not 13** (GDPR Art. 8).
- Gate on custom claim `request.auth.token.ageCompliant==true`, never a Firestore `get()`
  (token-bound, zero extra reads/write). Client must `getIdToken(forceRefresh:true)` after a
  compliant verdict or the first UGC write denies on a stale token (fail-safe: deny).
- `birthYear`/`isMinor` immutability check: rule compares
  `request.resource.data.get('X',null)==resource.data.get('X',null)` on UPDATE (holds under
  merge — Firestore evaluates post-merge) AND `...get('X',null)==null` on CREATE. Missing either
  half leaks. Admin-SDK CF is the sole writer.
- An idempotent-retry branch must NOT recompute `isMinor`/`birthYear` from the request payload
  once a value is stored — else an authed minor can retry with an adult birthYear and overwrite
  `isMinor:false`. Ignore/reject a mismatched retry value.
- Rejection-path audit rows must never link a real identity to "is under 15" — no uid/email/
  birthYear, only `operation/reason/basis/timestamp` (+hashed hour-bucket for rate limiting).
  Compliant-row audit stores `userIdHash` + coarse `birthDecade`, never raw birthYear.
- Age-floor asymmetry is intentional: CREATE requires `birthYear` present+valid (CEL `null is
  int` is false, so `is int` rejects both null and missing); UPDATE tolerates absent/null
  (legacy escape hatch) until the signup CF is the sole writer everywhere.
- Signup-verification rate limits must be a DEDICATED config, decoupled from feature
  kill-switches (e.g. `aiEnabled`) — disabling one feature must never disable an
  age-verification control. Both must fail CLOSED on a Firestore error.
- `isSearchable` for minors has ONE chokepoint: `UserProfile.toFirestore()`:
  `'isSearchable': isMinor ? false : isSearchable`. Two OPEN gaps to keep re-checking: (a) a
  window between signup profile creation and onboarding completion where a minor is briefly
  discoverable (fix: force `isSearchable:false` the moment the CF returns `isMinor:true`, not at
  onboarding completion); (b) `isMinor` must be mirrored onto/hydrated via `public_profiles`/
  settings, never left only on `users/{uid}` (see architecture fact above) — a hydration path
  that skips the settings-merge seam silently un-suppresses search.
- `firestore.rules` now separately hard-denies a minor setting `isSearchable:true` server-side
  (`accountIsMinor(userId)`, short-circuited `get()` only when a write SETS it true) —
  supersedes any earlier "client-side-only" note. A legacy `isSearchable:true` isn't
  force-corrected by the rule itself; the client derivation fixes it on the next full save.
- Minor-searchability reassert: before a full profile save, re-read the AUTHORITATIVE server
  value (`Source.server`, never cache-first) and restore via a trusted admin callable after
  save — invariant: a save can never make a minor MORE discoverable than the server says. Known
  accepted edge: a failed pre-save read fails toward less-discoverable, silently and
  permanently — acceptable for child-safety, but a real UX gap if it resurfaces.
- Analytics minimisation for minors must gate EVERY live writer of the property (grep the
  property name), not just the primary setter.
- A group-safety CF removing a minor must delete every mirror the app's own client removal path
  touches (membership doc, per-user maps, AND any participants subcollection) — a partial
  removal leaves stale membership records even though the message-access gate itself closes
  correctly. Known data-consistency gap on this feature, not an access hole.
- Surfacing a reported user's `isMinor` to moderators is fine (more data-minimising than raw
  birthYear) — the read/cache path must default to non-minor on ANY failure, never fail toward
  a state that suppresses the mod queue.
- An age/consent gate must be enforced in `firestore.rules` itself, not only a Dart-layer
  override (see batch-bypass rule) — the client-side check is advisory only.

### PII handling & logging
- Bounded enum/numeric telemetry (error codes, token counts, model IDs, `schemaVersion`,
  variant strings) is safe to log — the leak surface is the adjacent free-text field. Bound raw
  length even for "should be small" fields.
- A field on a world-readable doc must be audited individually for exposure — a boolean gating a
  SEARCH QUERY does not gate DIRECT-FETCH visibility.
- A moderation "hide" flag is search-suppression + UI-placeholder, not a read boundary, unless
  every direct-fetch consumer also filters it.
- A presence opt-out must gate every derived surface, not just the boolean (a hidden dot with an
  advancing `lastActiveAt` still leaks "active N min ago"). Prefer freezing the source write.
- An automatic/background profile mutation must be a single-field `update()`, never a
  full-profile `set()` — full overwrite clobbers peer-owned denormalized fields
  (`friendsCount`, `isHidden`). Recurring finding, still open for `saveProfile` itself.
- Scrubber regexes: ASCII `\b` misfires before å/ä/ö; an unbounded leading letter-class before a
  literal suffix is O(n²) regex-DoS; case-sensitive heuristics no-op on ALL-CAPS OCR. A shared
  TS/Dart vector file must stay byte-identical; watch Dart's `Uri.pathSegments` auto-decoding
  percent-encoding where TS's `pathname.split("/")` does not.
- Any user string interpolated into an LLM prompt must be type-checked, trimmed, stripped of
  sentence-forming punctuation (or whitelisted to a tight charset), fail-undefined when absent —
  a length clamp alone can still smuggle punctuation-based injection.
- The raw-uid-interpolation log guard doesn't catch structured-arg leaks
  (`AppLogger.x({'uid': uid})`) — extend the regex if that shape appears.
- A field-rename on an `isAdmin()`-only collection is zero-risk unless admin tooling reads that
  exact field name by string.

### Query cost, indexes, real-time listeners
- Every `.snapshots()` in `lib/repositories/` ends in `.limit(N)` even for "small" collections —
  per-user ~100, per-group ~200, cross-user collection-group ~200-500, per-thread →
  cursor-paginate instead. Not a substitute for pagination or a permission check.
- Live pagination uses a DOC-cursor (`startAfterDocument`) — value-cursors miss/double-emit
  docs sharing one `serverTimestamp()`.
- `where(equality)+orderBy(different field)` needs a composite; a lone single-field
  equality-or-range query does NOT (accepted-deviations) — only a SECOND field triggers one.
- `where(...).limit(N)` without `orderBy` returns insertion order, not recency.
- A per-doc visibility rule needs a SPLIT query (owner unfiltered, friend branch STRICT
  equality, no "field absent" allowance) — looseness re-opens the leak. Backfill the default
  BEFORE the strict rule ships.
- Judge "is swallowing this read safe" by whether a downstream SAFETY verdict defaults
  permissive on missing input — restrictive-default (Butlery's allergen coverage gate) makes
  swallowing fail-safe; permissive-default would make it Critical.
- A parser/lookup that can turn 1 input into N reads needs a cap at the split site — same
  "bound the worst case" rule as `.snapshots()` limits.

### Admin-only aggregate repository bypass (6+ repos confirmed clean)
- Skip `PermissionValidationMixin` only when ALL FOUR hold: read-only; rule-gated by
  `isAdmin()`; PII-free output; errors degrade to empty/zero, never rethrown. Document the
  rationale in a class doc comment. Confirmed clean: `SiteConfigRepository`,
  `EngagementRepository`, `RecipeStatsRepository`, `OpsLogRepository`, `ParseEventsRepository`,
  `AnomalyRepository`, `AnalyticsRepository`, search repos. Any one failing = mixin mandatory.
- Admin callables with a client `limit` must reject invalid values explicitly
  (`invalid-argument`) — `limit||fallback` wrongly treats `0` as "use fallback".
- A post-batch `.get()` may not reflect a `FieldValue` transform in the SAME batch — never use
  it to enforce a size cap; use a transaction.

### LLM / Vertex / prompt safety
- Kill-switches: master server gate fails CLOSED (visible error, never silent bypass); a
  client-side Remote Config shortcut can fail open. An uninvalidated module-scope cache can
  serve stale config for the warm-instance lifetime — hours, not an optimistic "~30 min".
- Treat raw LLM output as adversarial: bounded parsers only, enum-drift logging capped, and
  verify no consumer branches a decision off a cost/telemetry field before calling it
  "telemetry-only".
- A locale/variant string reaching only telemetry (never a prompt/filter/branch) has zero
  injection surface — confirm by grepping every actual caller.
- Model-integrity gates sit BEFORE any disk write/cache-path assignment; a cache-path LOAD skips
  re-verification only when the threat model is transit/storage substitution. A registry entry
  ships before the remote version pointer bumps. A result's "ok" can be true while "unverified"
  is also true — callers must check both.

### Cloud Functions / cascade mechanics
- A deterministic doc ID + `set()` (not `add()`) is the standard idempotency primitive.
- Region pinning covers every export in a file — removing it silently reverts unconverted
  functions to the default region. Clients must call region-pinned callables with the matching
  region option or 404 in prod.
- A scheduled drainer retrying a state machine needs a max-attempts cutoff to `failed`.
- Storage/document triggers cannot carry App Check — put it on the client-facing callable that
  produces the triggering write.
- A virtual-parent-doc subcollection tree (parent never written) is valid for owner-scoped logs;
  GDPR cascades use listCollections-on-ghost-root + conditional root delete. The rule's
  `hasOnly([...])` and the model's `toFirestore()` key set must match byte-for-byte.
- An aggregate recomputed from a deletable subcollection should use the existing
  `onDocumentWritten` trigger (fires on delete, keys off `event.params`, never flag-gated)
  rather than an explicit cascade call.
- Extracting a scheduled/trigger handler into a testable function is safe when it stays
  network-unreachable, behavior is byte-identical, and no cascade step is removed/reordered.

### Storage / uploads
- Storage download URLs are percent-encoded — never string-match a raw URL against unencoded
  `/segment/` literals; `Uri.decodeFull` first.
- Upload/delete authorization should funnel through exactly ONE low-level write method so one
  validation gate covers every entry point.
- A negative-permission storage test asserting only `isNull` proves nothing — assert the side
  effect directly (bytes did NOT land at the foreign path), paired with a positive control.
- Best-effort cleanup triggered by a non-owner legitimately fails both the client guard and the
  Storage rule (correct fail-safe) — the orphan is swept by the eventual account-deletion wipe.

### Third-party / infra
- Cert pinning: empty per-host pins must no-op fall through; release-safety checks must
  `throw`/`StateError` (never bare `assert`); an in-flight-request guard must key by the real
  serialization axis (e.g. per-host), not one global `Future?`.
- Native-only plugins have no web SDK — a `kIsWeb` branch calling one silently no-ops.
- Storage lifecycle rules for version retention MUST include `isLive:false`; verify the
  DEPLOYED rule via `gcloud`, not just the source script.
- A pin-reject-then-fallback is safe only if the reject happens before the request hits the
  wire (`onRequest`, not `onResponse`).
- `execFileSync(cmd, argsArray)` (array form) is immune to command injection even with
  attacker-influenced argv — the risk is shell-string interpolation, not the args.

### Testing / tooling gotchas
- `fake_cloud_firestore`/`FakeFirebaseFirestore` enforce neither RULES nor INDEXES — a green
  fake test proves query shape only; prove rule-allowed and index-exists separately.
- Prefer real-repository + fake-Firestore + auth-state-fake tests over side-effect stubs that
  mock away the boundary under test.
- Cascade unit tests against a fake Firestore must bridge the production `ServiceLocator` or
  `ServiceLocator.get<>()` throws, gets caught, and the step lands silently in
  `failedCollections` — a green test proving nothing.
- A standalone admin script is safe to delete once: no exports; not exported from `index.ts`;
  no `package.json` entry; no dedicated test; not named in CI/deploy config.
- Reference `firestore.rules` branches by path+rule type in comments, never by line number.

### Superseded
- `activity_events` rules: "no block exists" was superseded same-day by confirmation the block
  now exists (two still-open follow-ups: inert rate-limit guard, unbounded payload fields).
- Comment-image Storage cleanup: "orphans on delete" was closed by best-effort cleanup
  (moderator-triggered deletes still legitimately orphan images, by design).

## When to consult the archive
Grep the archive when: a principle needs its exact rule predicate/path/excerpt to copy rather
than re-derive; a diff touches a file or BUT-ticket a principle references and you want the
prior verdict; a finding-in-progress feels familiar (search by collection name/symptom before
filing it as new); you need to confirm something already cleared the admin-bypass or
export/erasure-pair checklist; or you're about to add a new dated entry and should extend a
bullet above instead.
