# firebase-backend-security — accumulated knowledge

Step-0 read for every security/backend task. **Principles only** — edit the bullet a finding
extends; the dated raw entry goes to the append-only
`firebase-backend-security.knowledge.archive.md`. Full contract: "How new learning enters this
file", below.

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

### The second footgun: parallel write paths to the same collection
Several unified services expose a tidy `service.<feature>.op()` facade AND a module chain the UI
actually calls. Confirmed on collaborative shopping: `ListItemOperations` (facade, ZERO production
callers) vs `ShoppingItemManagementModule → ShoppingItemOperationsModule → updateCollaborativeList`
(what every view runs). **Any concurrency, permission or audit fix must be grepped to a real
caller before approval** — a fix on the dead twin reviews as green and changes nothing. Name the
view/VM file that reaches the edited method, or file it as unreached.

**Its twin: TWO STORAGE SHAPES for one field.** Personal shopping lists keep items BOTH as an
`items` array inside the parent doc (`toFirestore()` emits it) AND as an `items` subcollection
(what `addItem`/`addItemsBatch` write and what `readAll` reads back, overwriting the array via
`copyWith(items:)`). Any write that fills only the array is invisible after the next read:
`createPersonalList(name, items: …)` → `super.create()` writes the array only, so
convert-collaborative-to-personal copies the items, deletes the source list, and the copy reads
empty on the next load (in-memory cache hides it until restart). When reviewing a
collection with a nested child collection, ask which shape each writer and each reader uses —
and note that the GDPR export is only complete because it dumps BOTH (parent doc data + child
docs), which makes it a superset of what the app itself can read. Fixed 2026-07-27 (BUT-1723):
`create()` now fans the array out to the subcollection and the conversion only deletes the source
after a SERVER-confirmed item count. Two lessons generalise. (a) A copy-then-delete needs a
read-back that can distinguish "server has it" from "the local cache answered" —
`metadata.isFromCache`, and `null`/unconfirmed must mean KEEP BOTH. (b) **Repairing a copy path
that never actually persisted anything can ACTIVATE a dormant cross-user PII leak**: the
collaborative→personal copy carries other members' `addedBy*`/`purchasedBy*`/`lastModifiedBy*`
into `users/{me}/…/items`, a tree no OTHER user's cascade scans, so their name outlives their
erasure. Strip foreign attribution at any cross-tree copy site. **Verified STILL UNSTRIPPED
2026-07-27** now that the fan-out has landed: `ListLifecycleOperations.convertCollaborativeToPersonal`
passes `collaborativeList.items` verbatim to `createPersonalList`. No widget renders those names
today, which is the only reason it is High rather than Critical — a display accident, not a control. **CLOSED 2026-07-28**: the copy path now runs every row through
a strip helper that keeps WHAT happened (name, amount, `bought`, timestamps) and drops WHO unless the
uid equals the converting owner's — the shape to copy at any cross-tree copy site. Two things that
made it safe rather than lossy: the strip rebuilds via the full CONSTRUCTOR, so verify the
constructor's parameter list is exhaustive against the model's fields (a missing one silently resets
to its default), and a nulled `addedByUserId` flips a derived `isCollaborative` getter — check that
getter has no production consumer before nulling, or anonymize instead of nulling as the CF cascade does.
**Two costs the fan-out repair carries, both worth checking on any "write the other shape too" fix
(2026-07-28).** (a) It routes through a TYPE-ROUTING helper, and this repo's router probes the SHARED
collection first: `create()` → `addItemsBatch` → `_requireList` → `read()` → a
`sharedListsRef.doc(id).get()` that the rules DENY for every personal-list id (nonexistent doc ⇒
`resource` is null ⇒ CEL error ⇒ `permission-denied`), caught and logged as a warning. So every
personal create with items now bills a guaranteed-denied read plus a scary log line on the happy
path — pass the already-known list/type into the batch writer instead of re-reading. (b) It makes a
pre-existing orphan CERTAIN: the client's `delete()` removes the personal list document without
sweeping its `items` subcollection, so the conversion's source delete now always strands a fully
populated subcollection. Not a GDPR hole here only because the CF cascade sweeps
`unified_shopping_lists/{id}/items` and the probe uses `listDocuments()` — check both before
downgrading it.
Second lesson from the same repair: a copy-confirmation gate that compares the SERVER count of the
copy against a count read from LOCAL STATE of the source still deletes a source that had more rows
than this device knew about (personal lists have no snapshot stream). Confirm both ends server-side,
or say in the doc comment that the source count is trusted. **Still open 2026-07-28** on the
personal→collaborative leg only (the collaborative leg's source IS stream-backed).

### Firestore rules & permission patterns
- Full-doc `set()` collections: create pins `request.resource.data.userId==auth.uid`; update
  pins BOTH `resource.data.userId` AND `request.resource.data.userId`; delete pins
  `resource.data.userId`. Rule and repo-support ship together, or one is dead code.
- A full-doc `set(merge:true)` by a NON-owner member passes an `affectedKeys().hasOnly/hasAny`
  rule only because the immutable fields round-trip byte-identically through the model
  (`Timestamp.fromDate(createdAt)` etc.). Prefer a targeted `update({changed fields})` — smaller,
  cheaper, and immune to a serialization change silently turning every member write into a deny.
  The sharper failure is when the base document is STALE (offline/cached-base fallback, queued
  replay): the merge re-sends `ownerId`/`memberPermissions` as they were, so for the ONE caller
  the rule lets write those fields (the owner) a queued tick RESURRECTS a member the owner
  removed from another device. A rules-denied non-owner replay is fail-safe; the owner's is not.
  Any write whose base can be older than the server needs a targeted field update, not a merge.
  **The shipped shape to copy (BUT-1719, `ShoppingOfflineWriteModule.narrowUpdatePayload`):** diff
  `proposed.toFirestore()` against `stored.toFirestore()` with `DeepCollectionEquality`, emit only
  differing keys, emit a MAP field as per-key field paths (`memberPermissions.<uid>`, value or
  `FieldValue.delete()`) so a removal lands under `update()` or `set(merge:)` alike, return an empty
  map to mean "skip the write", and THROW when the narrowed payload touches a privileged key while
  the base came from cache (`metadata.isFromCache`). Two things this quietly fixes beyond the
  ticket: `merge:true` can never delete a map key, so member removal never stuck; and a
  `fromFirestore` that normalises an unknown enum value no longer writes the normalised value back
  over the server's. Prerequisite to verify before approving such a diff — `toFirestore()` must be
  sentinel-free (no `FieldValue.serverTimestamp()`), or every key diffs on every call.
- **A guard set is scoped to the callers a method had, and promoting it to a public
  repository INTERFACE invalidates that scope.** An internal module method may lean on "every
  caller is our own code, and our mutators only touch `items`"; the moment the same method is
  added to `lib/repositories/interfaces/*.dart` it must carry the full guard set of its
  siblings on the same collection. Review an interface addition and its implementation as ONE
  change: diff the new method's checks against the method it is replacing/paralleling and
  require parity (BUT-1665: `updateCollaborativeList` gained a privilege-escalation guard while
  `mutateCollaborativeList` — simultaneously promoted to the interface — did not).
- **A module that receives `logPermissionCheck` as an injected callback silently loses the await.**
  `PermissionValidationMixin.logPermissionCheck` returns `Future<void>`, but every shopping module
  (and the new `ShoppingListPermissionGuards`) declares the field as `void Function({...})` — Dart's
  return-type covariance to `void` accepts the assignment with no warning, so the audit write is
  fire-and-forget and a failure inside it is an unhandled async error rather than a signal. Check
  the declared callback type against the mixin's signature whenever a repository hands its audit
  hook to a helper; only the repository's own call sites (`FirebaseShoppingRepository.delete`)
  actually await it.
- A write helper that calls `requireCurrentUserId()` and then `logPermissionCheck(granted:true)`
  with NO check in between forges the audit trail. Either run the real
  `validate*Permission` and log its verdict (see `FirebaseShoppingRepository.delete`), or don't
  claim a check. Rules being the backstop makes it an audit defect, not an access hole.
  **Fix the whole sibling set in one pass, and name every unfixed sibling in the finding** —
  create/update/mutate live in the same module and a round that repairs only the one under review
  leaves the others forging grants (three consecutive passes on `ShoppingRepositoryRoutingModule`
  fixed update, then mutate, and `createCollaborativeList` is STILL unguarded — a finding that says
  "fix both" without naming the third method never reaches it). A guard added to one sibling is also
  a gap opened in the other: once `update` blocks privilege escalation, `mutate` on the same
  collection and the same public interface becomes the soft spot. **When the sibling finally gets
  its guard, check EVERY CONJUNCT of the rule, not just the identity one**: BUT-1696 added
  `_requireSelfOwnedCreate` (ownerId==uid) to `createCollaborativeList`, but the create rule is a
  triple — `ownerId==uid` AND `uid in memberPermissions` AND
  `hasRequiredFields(['ownerId','memberPermissions','items','createdAt'])` — so a create missing
  the membership key still logs `granted:true` and is still refused by the server. Half a mirror
  is still a forged grant. **CLOSED 2026-07-28**: `requireSelfOwnedCreate` now checks BOTH
  `entity.ownerId == uid` AND `entity.memberPermissions.containsKey(uid)`, with a distinct message
  and a distinct audit `details` per arm, and both arms are pinned by tests. The same round moved
  all three mirrors out of the routing module into a dedicated
  `ShoppingListPermissionGuards` (500-line pressure). **Review rule for such an extraction:** the
  guards' scope is "every write path calls them", so re-derive that from the NEW module rather than
  trusting the diff — grep the extracted method names in the caller and match them against the
  collection's full write surface (here 4/4: create, whole-list update, transactional mutate,
  cached-base offline mutate). A path that quietly kept an inlined check would read as a pure move.
  And a client check that is LOOSER
  than the matching rule
  (repo accepts any `memberPermissions` key; rule demands `edit`/`admin`) still logs
  `granted:true` for a write the server then denies — mirror the rule's predicate exactly.
- **Judging a client check that gets STRICTER: compare it to the app's own permission service,
  not just to the rule.** If `PermissionService.canEditX` already barred the case (Butlery's
  view-only shopping member), the UI never offered it and no legitimate caller regresses — the
  change only moves a guaranteed server denial earlier and gives it an audit row. Where the app
  service is LOOSER than the rule (`canManageShoppingList` grants a non-owner `admin`), the
  strictening exposes dead UI that could never have succeeded: report it as a product gap, not a
  regression. Also check what the new gate transitively requires — `_requireEditRights` inherits
  `validateUpdatePermission`'s `isCollaborative` test, so a shared doc whose `type` field is
  missing parses as `personal` (enum `orElse`) and locks out every non-owner member. Fail-closed,
  but enumerate every writer of the collection before accepting it.
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
- `documentId()` prefix-range erasure via `.startAt(p).endAt(p)` (or
  `>= p AND < p`) with **genuinely** identical bounds is a CLOSED range matching only a doc
  literally equal to the prefix — it under-matches and deletes NOTHING. Treat as Critical; test
  with a seeded-target + seeded-other-user pair. **But "identical" is a byte claim, not a visual
  one**: the correct upper bound is `p` + U+F8FF, a private-use codepoint that renders as NOTHING
  in every editor, diff viewer and Read output, so a working range looks degenerate. Before filing
  this, byte-check with `git show HEAD:<file> | grep -n <bound> | cat -A` (expect `M-oM-#M-?` =
  `EF A3 BF`) or `grep -P "\x{F8FF}"` — BUT-1690 was filed against a range that had always worked.
  Prefer the escape spelling (backslash + lowercase u + f8ff); `test/architecture/architecture_test.dart` now fails on a
  literal U+F8FF anywhere in `lib/**.dart` (`functions/src` is still outside that guard's scope).
  The `_` separator before the sentinel is what stops a uid that prefixes another uid from
  matching across owners — both halves are load-bearing and both fail SILENTLY.
- Overriding `create()`/`update()` for an invariant does NOT cover `createBatch`/`updateBatch` —
  those live on the base class and skip the override. Override the batch methods too, or hoist
  the assertion into a shared private method both call. Rules are the real backstop.
- On UPDATE, permission checks must load the STORED doc's ownership field, not the submitted
  entity's — else a caller who is a member of TWO groups can re-parent a doc between them by
  resubmitting it.
- A `not-in`/`in` filter (e.g. an audit purge sweep) silently excludes docs where the
  discriminator field is ABSENT from both buckets — every writer must set it unconditionally.

### GDPR: deletion, export, and the recurring "wrong probe shape" bug
- **Most-repeated bug class: a cascade/probe/export query targets the wrong field, shape or
  COLLECTION NAME** — seen 4+ times independently: `where('userId'==uid)` against a collection
  keyed `ownerId` (matches zero, "deletion" no-ops); an OR-owned collection
  (`senderId==uid OR targetUserId==uid`) folded into one probe instead of a per-field loop; a
  subcollection with no `userId` field probed by equality instead of existence; and **a path
  nothing writes** — Butlery has TWO constants for the same concept (`unifiedShoppingLists =
  'unified_shopping_lists'`, what the repo writes via `collectionName` + `getUserCollection`, vs
  `userShoppingLists = 'shopping_lists'`, what BOTH the deletion cascade and the Art-15 export
  read), so personal shopping lists had never been erased or exported (CLOSED 2026-07-26/BUT-1697:
  cascade, export and the residual probe all moved to `unified_shopping_lists`, legacy name still
  swept, items subcollection deleted before its parent). **Always open the actual
  `.where()`/`.collection()` clause and confirm it matches the collection the repository really
  writes — a function existing with the right name proves nothing.** Cheapest independent check:
  grep `firestore.rules` for the path. No rule block ⇒ nothing writes there (default-deny), so a
  cascade or export aimed at it is dead. Same for the `probeResidualData` canary list — a
  collection missing from it can no-op for months in silence. **The other half of the same
  shape error is the WRONG NESTING LEVEL**: `deleteUserSubcollections` sweeps
  `users/{uid}/user_shared_shopping_lists` and `.../user_shared_menus`, but the app writes both
  as TOP-LEVEL trees `user_shared_shopping_lists/{uid}/received_lists/{id}` — the only shape
  `firestore.rules` grants — so those inbox rows (carrying `sharedByUserId` +
  `sharedByDisplayName`) survive erasure, are absent from the export, and are absent from the
  canary (OPEN, filed 2026-07-26). `users/{uid}/X` vs top-level `X/{uid}/Y` read identically in a
  grep of the constant; only the `.collection(...).doc(...)` chain and the rules path settle it.
  **Grep the LITERAL as well as the constant** — the readers that survive a rename are the ones
  that hard-code the string (`functions/src/analytics/compute-feature-retention.ts` still probes
  `users/{uid}/shopping_lists`, so its `shopped` retention flag is permanently false), and a
  doc comment on the legacy constant that enumerates "the only remaining reader" is a claim to
  re-grep, not evidence — and such an enumeration is systematically blind to ADMIN-SDK readers
  (`account-deletion-cascade.ts`'s legacy sweep, `admin/reset-user-data.ts`), which hard-code the
  string, are rules-exempt, and are therefore empty rather than denied. Verified 2026-07-27: for
  `userShoppingLists` both client/CF readers the comment names are real
  (`friends_utility_operations.dart:146` root query → catch-all deny `firestore.rules:2526-2528`;
  `compute-feature-retention.ts:212`), and a denied QUERY surfaces as `permission-denied`, not empty.
- **A denormalized ERASURE HANDLE is only as good as its weakest writer and its rule.** When a
  cascade cannot query the field that actually carries the PII (Firestore cannot filter inside an
  array of maps), the repair is a flat `array-contains`-queryable trail of everyone who has written
  — Butlery's `contributorUserIds` on `unified_shared_shopping_lists` (BUT-1725), because
  membership and ownership are both things a user can STOP having while their name stays on the
  items. Three checks every time: (1) EVERY write path that stamps the attribution must extend the
  handle — Butlery unions it in the transaction and the offline replay but NOT in
  `updateCollaborativeList`, which is public interface and also writes `items`; (2) the handle must
  be removed in the SAME per-doc write as the scrub (it is the step's re-entry query handle) and
  must be added to the residual probe, keeping deleter ⊇ probe; (3) **`firestore.rules` must
  constrain it append-only** (`request.resource.data.F.hasAll(resource.data.F)` + a size bound) —
  otherwise any edit-level member can drop another user's uid and make that user's PII unreachable
  to erasure. A pre-existing corpus needs a one-shot backfill reconstructing the handle from the
  uids still visible on the doc (a documented LOWER bound), plus a stated removal condition.
  **Status 2026-07-28 (BUT-1725), re-verified after the fix round:** (2) DONE. (3) DONE —
  `keepsContributorTrail()` (append-only `hasAll` + `size() <= 200`) is now a conjunct of both create
  and update, owner included. (1) is THREE-QUARTERS done: create seeds `[uid]`, the transaction
  computes the union from the live array inline, and the offline replay queues
  `_withContributor(...arrayUnion)` — but `updateCollaborativeList` still writes `items` through the
  public interface with no union (`_withContributor` is wired to `_mutateFromCache` only). Today's
  only live caller of that leg writes attribution-free generated rows, so nothing leaks yet; the
  point is that the invariant is upheld by caller discipline rather than by construction. The cheap
  enforcement is one line at the write site: union the handle whenever the narrowed payload
  `containsKey('items')`. **Re-verified 2026-07-28, still open** — and note WHY the narrowing makes
  it structural: the payload is diffed from `entity.toFirestore()`, whose key set never includes the
  handle, so a denormalized erasure handle that lives OUTSIDE the model can never ride along on a
  model-derived payload. Whenever such a handle is introduced, enumerate the write paths that build
  their payload from `toFirestore()` and treat every one as a miss until it explicitly re-adds the
  handle. Discharging the "no live caller leaks today" claim costs a full caller trace, not a
  grep: repository `update()` → `ShoppingListManagementModule.updateList` →
  `personal_shopping_operations` (preserves existing attribution), `list_member_operations`
  (owner-only, no item attribution) and `menu_shopping_list_generator` (generated rows, no
  attribution) — name all of them or the claim is unverified. A new field written by the client is not "covered" by a rule block merely
  existing; grep the FIELD NAME in `firestore.rules`, not the collection. **And an append-only rule conjunct changes what the
  WRITE SHAPE has to prove**: the offline replay queues the handle as `FieldValue.arrayUnion`, so the
  rule passes only if `request.resource.data` reflects field transforms — assert that on the emulator
  before shipping, because the failure mode is every queued shop-aisle tick denied on replay and
  rolled back, visible only as a log line. A brand-new gating conjunct on a live collection with NO
  `*-rules.test.ts` at all is a High finding on its own; hand it to `firestore-rules-tester`.
  Do that grep as the routine check whenever a rules diff lands: a `*-rules.test.ts` merely EXISTING
  in the repo says nothing about the collection under review. **And the grep is only half the check
  — pair it with `git status --porcelain` (2026-07-28):** `shared-shopping-lists-rules.test.ts` now
  answers the grep with 528 lines including the `arrayUnion` case, but it is `??` UNTRACKED while
  the rule change itself is STAGED, and its `package.json` script + `firestore-rules.yml` path
  triggers sit unstaged in the working tree. Committing the staged set alone ships a brand-new
  gating conjunct with zero proof, and the CI new-block gate stays green because the match BLOCK is
  not new — only the function inside it. On any rules diff, list the proof file's git state, not
  just its existence.
  And the one-shot backfill needs a REQUEST-LEVEL RESUME CURSOR (`startAfter`/`nextCursor`, as
  `backfill-canonical-ratings.ts` has), not just a loop-local one: without it every invocation
  restarts at the top of the collection, so past `MAX_BATCHES × BATCH_SIZE` docs the documented
  `hasMore: false` removal gate is unreachable forever. **This RECURS on every new backfill file**
  (2026-07-28: `backfill-shared-list-contributors.ts` shipped with a loop-local `lastDocId`, no
  `startAfter` in its request type and no `nextCursor` in its response, ceiling 23×450). Make it a
  fixed check on any `functions/src/migrations/*` diff: open the request/response interfaces and
  confirm the cursor is on BOTH, before reading the loop. Note the idempotent-skip does not save it —
  skipped docs still consume the `maxLists` budget, so a re-run cannot advance.
- **Deleting a list/parent doc does NOT delete its subcollections.** `batchDeleteAll(db, docs)`
  over `users/{uid}/<lists>` leaves every `<listId>/items/*` doc alive and unreferenced. A
  cascade over any doc that owns a subcollection needs an explicit per-doc child sweep (or
  `recursiveDelete`) — child sweep STRICT, parent delete best-effort, in that order, or a
  swallowed chunk failure strands children under a deleted parent that no query can reach again.
  When the step sweeps SEVERAL name variants of the same collection (live + legacy), the child
  sweep must cover every variant; Butlery's fixed `deleteShoppingLists` sweeps
  `unified_shopping_lists/{id}/items` but still bulk-deletes legacy `shopping_lists` parents bare.
- "Export ⊇ erasure" is a field-PAIR property: export filter and deletion filter must target the
  identical field on the identical collection. Every new user-data collection needs BOTH
  cascades checked in the same review (deletion AND export) — one wired, one forgotten recurs.
- A pure `users/{uid}/*` subcollection is cheapest to get right: erase = one entry in a generic
  subcollection sweep, export = one whole-doc read of the same subcollection, nothing to
  keep in sync field-by-field. A residual probe that `count()`s the PARENT collection is blind to
  orphaned SUBCOLLECTION docs — if the child sweep half-fails, the canary reads clean.
- **A membership MAP KEY is itself a raw identifier, and a scrub that clears the neighbouring
  name/id fields but leaves the ACL key is incomplete** — it is what the rule reads as write
  authorization and what the UI derives member counts from. Fix shape (CLOSED for Butlery's shared
  shopping lists, BUT-1697): `FieldValue.delete()` on the key in the SAME per-doc `update()` as the
  scrub, so a retry either still finds the key (its own re-entry handle) or finds nothing to do; a
  sole-member owned doc is DELETED instead, since `ownerId` must stay (nulling it orphans the list
  for remaining members).
- **A cascade step that finds its docs by ONE query cannot fix a residual its probe finds by
  ANOTHER.** The shared-list step iterates `where('memberPermissions.{uid}','!=',null)` while the
  canary also counts `where('ownerId','==',uid)` sole-member docs — an owned list missing the
  owner's own key is unreachable by the fix and permanently reported, and `residual_data_detected`
  forces `success:false`/`gdprCompliant:false`. Keep the probe's query set ⊆ the cascade's. And a
  "the retry re-discovers everything" comment is only true if a retry exists: Butlery calls
  `auth.deleteUser` unconditionally after the cascade, so the account is gone and the ONLY retry is
  a human running `functions/src/admin/reset-user-data.ts` — nothing alerts on the failed run.
  Prefer strict/loud anyway, but say what the recovery actually is.
- Cross-user cascade mutations stage their audit-log entry in the SAME batch as the mutation.
- Denormalized author/sharer PII travels in FIELD GROUPS (`sharedBy*`, `authorName*`,
  `lastActivityBy*`) — tombstoning one field on deletion requires clearing every field sharing
  that prefix. **The rename-propagation CF is the inventory**: every `{queryField, updateField}`
  pair in `functions/src/social/on-profile-updated.ts` is a denormalized-name field group that
  survives account deletion unless the cascade names it too. Diff that list against
  `account-deletion-cascade.ts` — `unified_shared_shopping_lists.lastActivityBy{UserId,DisplayName}`
  and `ownerDisplayName` are propagated on rename but NOT scrubbed on erasure (open, BUT-1665 review).
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
  from transient errors (swallow best-effort) in cross-user cascade writes. Same rule for a
  QUEUED OFFLINE replay: an unawaited `set().catchError(log)` treats a rules rejection like a
  flaky link, so a member demoted while offline sees the tick land, then silently vanish when the
  cache rolls back — the only trace is a log line. Branch on the code and surface the denial.
- Pagination style must match the mutation: a DELETE loop over a filtered query needs no cursor
  (the matching set shrinks every pass); an UPDATE loop needs `startAfterDocument` (updated docs
  stay in the result set and get revisited forever without one).
- Export truncation idiom: fetch `limit+1`, `truncated = fetched.length > limit`, export only
  `take(limit)`. Keying truncation off `length>=limit` falsely flags an exactly-complete export.
  `ExportPaginationHelper.fetchCapped` + a declared `exportLimits` entry is the correct shape and
  covers the OUTER cap. **A NESTED per-parent cap has no such helper and is the gap to look for**:
  `exportPersonalShoppingLists`' `maxItemsPerList` and `exportConversationsAndMessages`'
  per-conversation cap are enforced with a bare `.limit()`, and only the latter emits a flag. A
  swallowed child-collection read is the same defect — a `catch` that logs at debug and returns
  `items: []` makes "read failed" indistinguishable from "no items", so the section must carry an
  error/truncation marker, not a log line.
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
- **A nullable actor-NAME field stamped through `copyWith` misattributes on a multi-user doc.**
  Butlery's `copyWith` is `name ?? this.name`, so writing `lastActivityByDisplayName:
  auth.currentUser?.displayName` (null for any account that never set an Auth profile name) keeps
  the PREVIOUS editor's name while `lastActivityByUserId` advances to the caller — the shared list
  then tells other household members that person X made a change person Y made (Art. 5(1)(d)
  accuracy, cross-user visible). Two rules: stamp an id/name PAIR atomically or not at all, and
  take the name from the source the rename-propagation CF writes (`userService.currentUserProfile`
  → profile displayName), never `authRepository.currentUser?.displayName` — the CLAUDE.md
  data-source footgun in denormalized form; the two diverge until the user next edits their profile.
  Butlery's fix stamps `resolveDisplayName() ?? ''` and teaches the model to read empty as
  "unknown"; note `UserService.currentDisplayName` still FALLS BACK to the Auth handle, which
  re-opens the divergence on the accounts that have one — read the profile field directly. An
  injected `resolveDisplayName` seam also means the unit test pins the seam, not the production
  resolver: assert the wiring separately or the footgun rides back in through the default.
  Shipped state (BUT-1697): the repository writer stamps `resolveDisplayName() ?? ''` wired to
  `UserService.currentDisplayName` (profile-first, Auth-fallback — good enough, not exact), and
  `activitySummary` treats empty as unknown. **Second writer CLOSED 2026-07-28 (BUT-1705)**:
  `UnifiedShoppingService.currentUserDisplayName` now reads `UserService.profileDisplayName`, a NEW
  getter that is the profile name or null with NO Auth fallback — the shape to reach for whenever a
  name is about to be PERSISTED as attribution (`currentDisplayName`, which falls back to the Auth
  handle, is display-only and now says so). Two lessons from that fix. A `?? '<placeholder>'` at a
  PERSIST site is the same defect as the Auth fallback: it stores a fact nobody asserted, so stamp
  EMPTY and teach the read side that empty means unknown — and when you do, sweep the render sites,
  because a `?? unknownUser` there only catches an ABSENT key and renders a blank line for the empty
  string (`shopping_sharing_status_dialog.dart` needed a `trim().isEmpty` arm in the same commit).
  **Third writer, same family, STILL OPEN 2026-07-28:**
  `PermissionService.currentUser` looks like a profile handle but SYNTHESIZES a
  `UserProfile` from the Auth user with `displayName ?? 'User'` — it is the auth-only side of the
  CLAUDE.md footgun wearing the user-data type. `shopping_social_share_module` /
  `social_menu_operations` stamp `sharedByDisplayName` + `sharedByAvatarUrl` from it into OTHER
  users' inbox trees, and `sharedBy*` is NOT in `on-profile-updated.ts`'s propagation pairs, so a
  recipient can see the literal `'User'` permanently — and worse, the account's REAL Google/Apple
  name plus `photoURL` whenever one exists. Treat any `permissionService.currentUser.<
  profile field>` as a finding on sight. Corollary when reviewing the OTHER writers' fix commits: a
  doc comment claiming "the Auth handle can no longer be stamped onto a document other people read"
  is a REPO-WIDE claim — grep the whole field group before accepting it, or the comment retires a
  finding the code did not fix.
- A rollback that finally "says why" must not read a SHARED error field: Butlery's
  `UnifiedShoppingService._error` carries both list-load failures and mutation failures, and the
  early-return denial paths (`!canEditActiveList`, list/item not in local state) set nothing — so
  a view that shows `viewModel.error` after a failed tick can print last hour's
  "couldn't load lists" as the reason. Clear before the call, or set a message on every `false`.
  **The shape that actually works, and the one to copy** (BUT-1696 final, verified 2026-07-26): a
  DEDICATED field the load-scoped `hasError`/state emitter never reads, set by a `_failMutation`
  that does NOT `notifyListeners()` (so report-before-rollback can no longer emit a frame carrying
  the optimistic value plus the error), read through a self-clearing `consumeMutationError()` the
  view calls BEFORE its `if (!mounted) return;` — read-once removes both the sticky full-screen
  error and every "caller forgot to clear" path. Residual, still open: nothing clears the field at
  the START of a mutation and the early-return `false`s (`!canEditActiveList`, no active list,
  list/item absent from local state) still set nothing, so an unconsumed message from an earlier
  failure can be shown as the reason for a later, different one. Clear-before-the-call is the last
  mile; a per-branch message set can never cover an early return someone adds later.
  **A NEW exception type thrown by a repository needs its own arm at that mapping seam in the same
  diff**, or it inherits a sibling's wording and asserts a cause nobody established: BUT-1697's
  row-level `ResourceNotFoundException(resourceType:'shopping_item')` maps to
  `AppLocale.shoppingListNotFound` ("Lista hittades inte") for a list that is on screen — exactly the
  lie `ShoppingItemManagementModule.toggleItemBought` documents refusing. Switch on the
  `resourceType` the exception already carries; and note the rollback behind such a message restores
  rows the server no longer has, which only a live snapshot stream corrects — personal shopping lists
  have none (they come from `readAll()`), so that stale state survives until a manual reload.
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
- **A pre-write EXISTENCE read that filters rows out** (so one stale id can't fail a whole
  `batch.update` chunk with `not-found`) is a sound repair, but judge three things. (a) It is not an
  authorization TOCTOU when the path is derived from `requireCurrentUserId()` on both the read and
  the write — nothing can re-point either at another user — only a staleness mitigation, best-effort
  by construction. (b) Offline, a *query* resolves from cache and returns a possibly-empty snapshot
  with NO error (unlike an explicit `Source.cache` doc miss, which throws `unavailable`), so an
  empty survivor set is unfalsifiable: gate any "nothing exists any more" verdict on
  `snapshot.metadata.isFromCache == false`, or a cold cache converts a write Firestore would have
  queued and replayed into an abandoned write plus a rollback. (c) Reading the WHOLE subcollection
  to validate M ids bills one read per row on the list; `whereIn(FieldPath.documentId, chunk)` at
  `kFirestoreWhereInLimit = 30` bills only the submitted ids and is never worse — don't confuse it
  with `kFirestoreBatchSafeChunkSize = 450` for the write loop. And log the WRITTEN count in the
  audit row, not the submitted one.
- **`runTransaction` has no offline path.** Persistence is on (`firestore_bootstrap.dart`), so a
  `set()` lands in the local cache instantly and syncs later; a transaction simply fails
  (`unavailable`) with no optimistic local write. Converting a user-facing write (a shopping tick
  in a store) to a transaction trades a lost-update race for a hard offline failure — require an
  explicit fallback or a written accepted-deviation. Also skip the write entirely when the mutator
  returns the base unchanged (`identical(mutated, live)`): a no-op still bills a write and, worse,
  reports success, firing downstream analytics/side-effects for an edit that never happened. An
  activity STAMP (`updatedAt`/`lastActivityBy*`) defeats that identity check, so on a bulk-replace
  path the no-op guard must be "no submitted id matched a live row", not object identity — and it
  must be on EVERY leg: `updateItemsBatch`'s personal leg throws when nothing survives its filter
  while the collaborative leg commits a stamped no-op and still reports success, contradicting its
  own doc comment (open, BUT-1697).
  Verified plugin mechanics for reviewing such a fallback (cloud_firestore 6.6.0): a custom
  `timeout:` budget expires client-side and surfaces as `FirebaseException(code:'deadline-exceeded')`
  (Android `TransactionStreamHandler` semaphore → `Code.DEADLINE_EXCEEDED`), so keying a fallback on
  `unavailable` alone leaves the commonest flaky-connection case unhandled; and an exception thrown
  by the handler propagates VERBATIM (not rewrapped), so a domain `PermissionDeniedException` raised
  inside the transaction still reaches the caller with its own type. `deadline-exceeded` is NOT proof
  of "offline" though — a slow-but-working link hits it too, so a cached-base fallback on that code
  reintroduces the lost update it was built to prevent; say so explicitly or gate on real
  connectivity. Awaiting a check between `transaction.get` and `transaction.set` is safe only if the
  check issues no reads — confirm the validator is pure in-memory before approving it. The right
  offline repair is a **field-level merge primitive, not a better base**: an APPEND queued as
  `FieldValue.arrayUnion(newRows)` (detected by comparing the serialized prefix of the array, not
  ids — a tick rewrites `bought` on an unchanged id) replays without losing a concurrent edit and
  is safe even on the `deadline-exceeded`-but-online case; only a change to an EXISTING row has no
  offline-replayable primitive and still needs the cached base (Butlery accepts that: BUT-1683,
  `ACCEPTED_DEVIATIONS.md`). Two things to check on such a narrowed payload: the whitelisted keys
  must exclude every key the rule forbids a non-owner from touching, and the whitelist is scoped
  to today's mutators — on a PUBLIC interface method a future mutator that appends a row *and*
  changes some other field loses that field silently while the method returns the full mutated
  object. Require a fallback-to-full-write assertion, not a comment: **STILL OPEN after three
  passes** — `_appendPayload`'s comment names the excluded keys correctly (Butlery's whitelist
  `items` + `updatedAt`/`lastActivityAt`/`lastActivityBy{UserId,DisplayName}` exactly complements
  the rule's forbidden `ownerId`/`memberPermissions`/`createdAt`), but nothing DETECTS a mutator
  that also moves `name`/`description`/`settings`/`categoryIds`/`autoRemoveCompleted`. The cheap
  enforcement is a serialized-doc diff (`mutated.toFirestore()` vs `live.toFirestore()`): any
  differing key outside `items` + the whitelist ⇒ return null and take the full merge write.
  `syncStatus` looks like an instance of this and is not — the model sets it in `addItem` but
  `toFirestore()` never emits it; the diff is also trivial to write because `toFirestore()` emits a
  FIXED key set. Two adjacent mechanics: a `Source.cache` MISS **throws**
  `FirebaseException('unavailable')` in real Firestore while `fake_cloud_firestore` ignores
  `GetOptions` and returns `exists == false`, so a cached-base fallback must handle both shapes or
  its not-found branch is dead in production (mock the sealed `DocumentReference` to pin it); and
  `arrayUnion` dedupes by deep equality, safe to ignore only while every appended row has a
  unique id.
- Per-item analytics loops over a REPLACEMENT set double-count on every regeneration — log once
  with a count, or diff against the previous set, or the funnel the event exists to measure lies.
  Such a loop is also a cost trap: each tracker call awaits `hasAnalyticsConsent()`, and
  `ConsentService.getUserConsent` caches only AFTER the first future resolves (no in-flight
  dedupe), so N fire-and-forget events on a cold cache issue N concurrent consent reads. A sync
  `try/catch` around un-awaited `Future`s catches nothing either — wrap the whole emit in one
  `unawaited(Future(() async {...}))` with the catch inside.

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
  fake test proves query shape only; prove rule-allowed and index-exists separately. **Sharpest
  instance: a `get()` on a doc that does NOT exist in a rules-gated collection returns
  `permission-denied`, not `exists == false`, whenever the read rule dereferences `resource.data`
  (`resource` is null ⇒ CEL error ⇒ deny) — which is every Butlery shared collection. The fake
  returns `exists == false`, so the miss branch is dead-tested.** Consequence for the common
  "try the shared collection, else the personal one" probe: the first leg's `catch` must FALL
  THROUGH to the second, never `return` the inconclusive value, or the personal case answers
  "unknown" forever in production while every fake test passes (BUT-1723,
  `shopping_repository_query_module.dart:confirmPersistedItemCount`). The same rule explains the
  pre-existing `try/catch`-and-continue around the shared probe in `read()`/`delete()`.
- Prefer real-repository + fake-Firestore + auth-state-fake tests over side-effect stubs that
  mock away the boundary under test.
- Cascade unit tests against a fake Firestore must bridge the production `ServiceLocator` or
  `ServiceLocator.get<>()` throws, gets caught, and the step lands silently in
  `failedCollections` — a green test proving nothing.
- A standalone admin script is safe to delete once: no exports; not exported from `index.ts`;
  no `package.json` entry; no dedicated test; not named in CI/deploy config.
- Reference `firestore.rules` branches by path+rule type in comments, never by line number.

### Superseded
- Both prior entries here are fully closed and retired (2026-07-26): `activity_events` rules
  block exists (open follow-ups: inert rate-limit guard, unbounded payload fields);
  comment-image Storage orphans are handled by best-effort cleanup. Grep the archive for detail.

## When to consult the archive
Grep the archive when: a principle needs its exact rule predicate/path/excerpt to copy rather
than re-derive; a diff touches a file or BUT-ticket a principle references and you want the
prior verdict; a finding-in-progress feels familiar (search by collection name/symptom before
filing it as new); you need to confirm something already cleared the admin-bypass or
export/erasure-pair checklist; or you're about to add a new dated entry and should extend a
bullet above instead.
