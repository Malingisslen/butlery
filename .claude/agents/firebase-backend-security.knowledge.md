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
a Critical-severity finding. **But `with PermissionValidationMixin` in the
declaration is the LETTER, not the substance** — grep the class body for an actual
`logPermissionCheck`/`validateOwnership` call before crediting it. A read-only +
callable-write repository (BUT-1838's `FirebaseChatGroupRepository`) can carry the
mixin and call nothing in it, leaving zero Art. 30 rows for cross-user membership
changes; and when its doc comment cites a precedent ("same shape as
`BaseMetadataRepository`"), open the precedent — that one logs on BOTH branches of
every operation, so the citation was false. Correct shape for a callable-backed
mutator: log the callable's OUTCOME (never `granted:true` before it answers, which
forges the trail), and check whether the CF writes an audit row either — for BUT-1838
neither side did.

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

- **A read budget must count the RULE's `get()`s, not just the client's read.**
  `get()`/`exists()`/`getAfter()` in `firestore.rules` are billed as document reads, and the
  per-evaluation cache only collapses repeats of the SAME document inside ONE request — so a
  per-document probe behind a rule that chains two lookups costs 3×, re-billed on every probe.
  Butlery's poll-vote export leg (2026-08-17): `inPollConversation()` fetches the message then
  its conversation, so `maxConversations × cap × 3` = 100 × 200 × 3 ≈ 60 000, against the 50 000
  the comment claimed the cap avoided. A missing document still bills one read, so a probe that
  fires unconditionally charges the user who has nothing there. Re-derive any "N reads worst
  case" sentence by opening the rule the read passes through.
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
  messages to the user). **Grade an interpolated `$e` by its SINK and by the SHAPE OF THE READ,
  never by the word "exception."** In Butlery, `AppLogger.warning` reaches `developer.log` only,
  while `AppLogger.error` also reaches Crashlytics + analytics and runs the uid redactor — so
  promoting a log level is a privacy change. And the `create_composite` URL that carries another
  user's uid (BUT-1721/BUT-1732) can only come from a QUERY: a single-document `get()` cannot
  produce a `FAILED_PRECONDITION` index hint. Check separately that the string never reaches the
  Art. 15 bundle — `DataExportService` derives its warning from `error_code` and never copies
  `error` through, which is the shape to keep.
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
- **HYDRATING a page of parents with a per-parent SUBCOLLECTION has three failure modes, and
  only the first is about leaks (BUT-1832, `message_query_module.dart`).** (a) `switchMap` over
  the parent stream tears down and rebuilds EVERY inner listener on every parent emission — no
  leak, but a fresh billed query plus the rule's own `get()` reads each time, and a chat's
  parents re-emit constantly (status flips, delivery + read receipts). Key the inner set by the
  parent-ID SET (`distinct`) so it only rebuilds when that set changes. (b) A `.take(n)` cap
  applied AFTER the list has been `.reversed` to oldest-first keeps the WRONG END — the rows the
  user is looking at are the ones left unhydrated. Cap on the same end the user reads from.
  (c) The hydration must reach EVERY reader that hands the entity out — stream, page, single-doc
  AND search. A comment in the file saying "anything that hands one out must hydrate" is not a
  control; grep the class's own public methods and check each. Also verify what the UNHYDRATED
  value actually causes before writing it down: here the comment claimed a failed tally makes
  `closePoll` pick the first option, but `_resolveWinner` returns null at `voteCount == 0`, so
  the real outcome is a silent no-resolution. **Status 2026-08-17: (b) and (c) are FIXED; (a) is
  still open — `getConversationMessages` still `switchMap`s straight off the message stream with
  no `distinct` on the poll-ID set.** (d) A fourth mode, and the subtlest: **an error handler that
  returns an EMPTY collection is fail-CLOSED, not fail-open.** `onErrorReturnWith((e,_) => {})`
  put a PRESENT empty tally in the map, so the merge ran and blanked every option's stored
  `voterIds`; only a null/absent marker that the combiner FILTERS OUT leaves the entity untouched,
  which is what the sibling one-shot `catch` achieves by never adding the key. Read what the
  fallback value does DOWNSTREAM in the merge, not what the comment beside it claims.

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
erasure. Strip foreign attribution at any cross-tree copy site. **CLOSED 2026-07-28** (raw record in
the archive): the copy path runs every row through a strip helper that keeps WHAT happened (name,
amount, `bought`, timestamps) and drops WHO unless the uid is the converting owner's — the shape to
copy at any cross-tree copy site. Two things that made it safe rather than lossy: the strip rebuilds
via the full CONSTRUCTOR, so verify its parameter list is exhaustive against the model's fields (a
missing one silently resets to its default), and a nulled `addedByUserId` flips a derived
`isCollaborative` getter — check such a getter has no production consumer before nulling, or
anonymize instead.
**Three costs the fan-out repair carries, all worth checking on any "write the other shape too" fix
(2026-07-28).** (a) The TYPE-ROUTING helper probes the SHARED collection first (`create()` →
`addItemsBatch` → `_requireList` → `read()` → `sharedListsRef.doc(id).get()`), which the rules DENY
for every personal-list id (nonexistent doc ⇒ null `resource` ⇒ CEL error ⇒ `permission-denied`),
caught and logged — so every personal create with items bills a guaranteed-denied read on the happy
path; pass the known list/type into the batch writer instead of re-reading. (b) It makes a
pre-existing orphan CERTAIN: client `delete()` never sweeps the `items` subcollection, so the
conversion's source delete always strands one. Not a GDPR hole only because the CF cascade sweeps
`unified_shopping_lists/{id}/items` via `listDocuments()` — check both before downgrading it. (c) A
copy-confirmation gate comparing the SERVER count of the copy against a LOCAL-STATE count of the
source still deletes a source with more rows than this device knew (personal lists have no snapshot
stream) — confirm both ends server-side or say the source count is trusted. **(c) still open** on the
personal→collaborative leg only.

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
  `PermissionValidationMixin.logPermissionCheck` returns `Future<void>`, but a field declared
  `void Function({...})` still ACCEPTS it — Dart's return-type covariance to `void` — so the audit
  write is fire-and-forget and a failure inside it is an unhandled async error rather than a signal.
  Check the declared callback type against the mixin's signature whenever a repository hands its
  audit hook to a helper. **CLOSED for shopping 2026-07-30 (BUT-1741)**: all four seams
  (`ShoppingRepositoryRoutingModule`, `ShoppingOfflineWriteModule`, `ShoppingItemOperationsModule`,
  `ShoppingListPermissionGuards`) now declare `Future<void> Function({...})` and await every call,
  and the mixin's own fire-and-forget persist is spelled `unawaited(...)`. Two review rules the fix
  generalises. (a) Promoting a fire-and-forget hook to `await` puts the SINK on the operation's
  failure path — a throwing sink now aborts a write that already landed — so it is only safe once
  you have re-read the sink and confirmed it cannot throw (here: console log, then the persist
  wrapped in `unawaited(...).catchError` inside a `try`). Say which of those two facts you checked.
  (b) Fix the whole family in one pass: the covariance opt-out is PER CALL SITE, so a module that
  keeps one un-awaited call still drops that row, and the tests must therefore be per write path
  (create / whole-list update / transactional mutate / guard denial), not one sample.
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
  and a distinct audit `details` per arm, and both arms are pinned by tests. **All four conjuncts
  mirrored 2026-07-30 (BUT-1706)**: `validateRequiredFields` gained `items` + `createdAt` and the
  `contributorUserIds.size() <= 200` bound is unreachable (the client seats exactly `[uid]`). One
  caveat that generalises to every `hasRequiredFields` mirror — ask whether the payload builder can
  even OMIT the key before crediting the mirror: `UnifiedShoppingList.toFirestore()` emits a FIXED
  key set, so the new client requirement can never fire and the WHY-comment's "a create lacking
  either was refused by the SERVER" describes a path that does not exist. Harmless and correct as
  documentation of the rule; not a closed hole. The same round moved
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
- **A guard delivered as an OPT-IN named parameter defaults every existing caller into the
  restricted branch.** BUT-1726 added `updateCollaborativeList({UnifiedShoppingList?
  accessControlBase})` and made the no-declaration path STRIP `ownerId`/`memberPermissions`/
  `createdAt`; zero production callers pass it, so add/remove/demote-member, join-a-shared-list
  and leave-a-list all silently no-op while the UI is told they worked. Fixed check on any diff that
  adds a parameter or flag a write path now depends on: `git grep <paramName> -- lib/` — hits only in
  `test/` means the guarded capability is dead, not protected, because the method-level tests pass
  precisely BECAUSE they hand-pass the new argument. Trace the real chain instead
  (dialog/coordinator → `ListMemberOperations` → `UnifiedShoppingService.updateList` →
  `ShoppingListManagementModule` → `repository.update`), and note a silent STRIP must not report
  success (one op logged `granted:false` "dropped memberPermissions" then `granted:true` "Updated
  list"). **CLOSED 2026-07-30; shipped shape + rationale in
  `docs/architecture/ADR-002-collaborative-list-membership-guard.md`** (BUT-1752) — read it before
  accepting any diff that folds `updateCollaborativeListMembership` back into an optional parameter.
  Demands on any "declare your intent" guard: a NAMED method on the INTERFACE (never an optional
  argument), a distinct exception subtype whose `switch` arm PRECEDES the parent's, a caller that
  honours the returned bool, and a test driving the ENTRY POINT. Name the METHOD in the review
  marker — one that exists and is never called looks identical to a working one at file level.
  **Residual, still open:** the strip
  sits AFTER `requireNoPrivilegeEscalation`, so it only helps the owner — a non-owner's plain
  content edit carrying a stale member map still throws before reaching it, a false denial of a
  write the rule would have allowed. The real fix is to run the escalation guard against the
  payload that will actually be WRITTEN, not against the raw entity. Related product gap this
  strictening EXPOSED rather than caused: `canManageShoppingList` grants a non-owner `admin`
  member management and `leaveList` is offered to every member, but the update rule lets NO
  non-owner touch `memberPermissions` — so that UI is dead and now says so out loud.
- A collection with no rule block silently default-denies
  (`match /{document=**}{allow read,write:if false}`) — writes look implemented but are
  rejected. Grep `firestore.rules` for every new collection path in a diff first.
  **A denied READ is worse than dead code when it shares a `try` with siblings: it DISCARDS
  what they already collected.** BUT-1801 — `ContentExportManager.exportRecipes` read
  `users/{uid}/recipes`, then probed a top-level `recipes` collection no rule grants;
  `ExportPaginationHelper.fetchCapped` does not catch, so the `permission-denied` unwound past
  the personal rows into the one section-level catch and every Art. 15 bundle returned
  `recipes-export-failed` with zero recipes. So on any multi-probe section, check EACH read in
  the try against the rules and ask what the other reads lose when it throws; the shipped
  correct shape is `shared_shopping_list_export.dart`, whose refusable third probe carries its
  own inner try. Note the ADMIN-ONLY collection-group rule (`match /{path=**}/recipes/{id}
  { allow read: if isAdmin(); }`) is the trap: it makes "no match block at all" a false
  sentence while changing nothing for a real user, so word the finding as "no rule grants a
  client this read" and cite the line. And a `FakeFirebaseFirestore` test is evidence about the
  QUERY, never about the PERMISSION — five green tests covered that probe for its whole life.
- **A DETERMINISTIC COMPOSITE DOC ID (`{parentId}_{uid}`) is an identity claim only if
  something BINDS the body to the path.** Butlery's models parse identity from the body
  (`fromMap(String id, data)` routinely ignores its `id` parameter) while the rule that is
  cheapest to write pins the PATH — so the two halves can disagree and every reader believes
  the body. On a roster-scoped collection that is an ATTRIBUTION forgery: a legitimate member
  writes their own doc carrying a peer's `userId`, and any aggregate keyed on the body field
  attributes it to the peer (BUT-1693: it would retire that peer's BUT-1663 allergen floor).
  Demand both halves: the rule concatenates
  (`shareId == request.resource.data.householdId + '_' + request.auth.uid`), and the model
  refuses a doc whose derived id != its own id, with the identity fields required NON-EMPTY
  (`safeString` defaults to `''`, so a missing `userId` parses as a valid-looking share
  belonging to nobody). Same review question wherever a doc id encodes a fact the body repeats.
  **CLOSED 2026-08-12, and the closure shape is the reusable part.** Put the check in the
  REPOSITORY's `fromFirestore` (the only path a stored doc takes into the app), not in `fromMap`,
  which models legitimately call with hand-built maps; then make the LIST read parse per document
  and SKIP an unusable row, so one forged row cannot return "nobody shared" and look like a healthy
  empty collection. Two things to verify before copying it. (a) The catch is exhaustive only if
  every serializer the model uses is TOTAL — `SerializationUtils`' `safe*` helpers are (garbage
  parses to a default), `requiredString`/`requiredDateTime` are not, so `on FormatException` would
  silently become the whole model's error channel. (b) **A skip fails safe PER FIELD, not per
  collection**: dropping a row removes its contribution to a UNION (safe — the reader's floor
  covers it) *and* to an AND-FOLD (a shared `false` disappears and the aggregate loosens), so name
  the fields and say which way each one moves. The consumer must iterate the ROSTER, not the
  returned list, or "skipped" reads as "declared nothing". Same for the roster the filter itself
  uses: degrading an absent household doc to an empty member set discards every row silently —
  a roster used to FILTER user data must refuse to run when it is empty or absent.
  **Keep that identity check OUT of the DELETE decision, though (2026-08-12).** A
  `validateDeletePermission` that parses the BODY to answer "is this yours" makes a corrupt or
  forged row at the user's OWN path un-erasable: the parse throws before the ownership test runs,
  so `revoke()` cannot delete the Art. 9 document it exists to remove. Where the path encodes the
  owner, decide the delete from the PATH (the same fact the rule uses) and let the body check
  govern reads only — a fail-loud read is protective, a fail-loud erasure is an Art. 17 defect.
  Such a DELIBERATE ASYMMETRY (delete gated on ownership only while create/update also demand
  membership) survives only if a test fails when it is "harmonised": demand one that erases as a
  REMOVED member, and prove it by mutation — add the membership conjunct and require exactly that
  test to redden (verified 2026-08-12, BUT-1693: 1 of 27 red, restore md5-checked). A code comment
  saying "do not harmonise this" is not a control.
  **That asymmetry has to survive the UI layer, and the ORDER of the reads is what decides it
  (2026-08-13).** A settings row that resolves "may I offer this?" before "does a record already
  exist?" hides the only withdrawal control from anyone whose eligibility has since lapsed —
  Butlery's tile hid the switch for a household that shrank to one under a live share
  (`deleteFamilyData` removes a departing uid and leaves the household standing), i.e. Art. 7(3)
  denied by widget ordering, with the repository's path-only delete working perfectly underneath.
  Fixed by reading `getOwn` FIRST and gating the eligibility check on `own == null`. Two rules
  generalise: an eligibility guard on a consent surface may hide the OFFER only, never the
  WITHDRAWAL, so enumerate the states where a record outlives eligibility; and a read that FAILS
  LOUD by design (`fromFirestore`'s identity check) must not be allowed to veto the erasure — a
  `catch` that hides the row re-imposes one layer up exactly the defect the path-decided delete
  avoids. Where the delete needs no body, the UI's error branch should render the control ON.
  **Then review the CONSUMER as its own change (2026-08-12, BUT-1693 service slice), because a
  repository's fail-safe tri-state dies at the call site.** `HouseholdService._sharedListsByMember`
  returns `null` for "unreadable" and `{}` for "nobody shared", but the consumer spells
  `sharedLists?[uid]`, so both collapse to the same per-member fallback AND the aggregate still
  reports `isRosterComplete: true` — the distinction its own doc comment calls the point of the
  design never reaches an output, and the test named for it asserted only the values. Read the
  CONSUMING EXPRESSION before crediting any null-vs-empty design, and require the difference to
  land on the aggregate's reported HEALTH (the field the UI warns from), not just its values. Two
  siblings from the same read: a consumer acting on Art. 9 data should re-assert the model's own
  stated precondition (`isValidConsent` is enforced only in `getByHousehold`, while the interface
  the service holds also exposes `read`/`getOwn`); and enumerate the OTHER consumers of the same
  fact — `MenuGenerator._presentAllergenPrefs` takes PRIORITY over the household aggregate, sources
  member allergens from `public_profiles` (where the rules deny `allergenPreferences`, so it is
  structurally null for everyone including self), and is assigned only under `test/`: a dormant
  twin that inherits neither the BUT-1663 floor nor the shares, and whose empty union would leave
  the pool UNFILTERED (`!hasTrackedAllergens` → return everything) the day someone wires it.
  **CLOSED 2026-08-12 (same slice); the KILL SWITCH in front of it is where the reusable shape
  is.** The fix lands the distinction on the health field (`sharesUnavailable` → `degraded`
  before the `unresolved.isEmpty` branch), and a default-OFF flag pays for the over-warning —
  off is KNOWLEDGE (`return const {}`), an unreadable switch is IGNORANCE (`return null`, like
  the sibling null-repository branches). Spelling those two alike is invisible while the flag's
  code default is false and becomes a silent "nobody shared, roster healthy" the day it flips,
  so a flag over a fail-safe tri-state is a FOURTH state that must be written out, with two
  proofs: a test that UNREGISTERS the service (else that branch is unreachable in the suite),
  and a stub that pins the flag CONSTANT rather than only `isEnabled(any())` (else repointing
  the constant keeps every test green). Two more rules from the same closure. (a) **An unknown
  degrades only where knowledge could have existed** — a household of ONE has no peer who could
  have shared, so an unreadable share read there must not raise the floor and the menu warning;
  scope the degradation by whether anyone other than the caller was on the roster, not by the
  read's outcome alone. (b) **Read the identity that decides "self" from the SAME handle as the
  gated read** (`PermissionService.currentUserId`, not `userService.currentUserProfile?.uid`):
  coupled that way, the two nulls cannot disagree, so a null cached profile can never let a
  document written ABOUT the signed-in user stand in for the settings their own device reads.
  Third sibling, still open: the health bit must reach a surface that OUTLIVES the run —
  Butlery's warning hangs off `MenuGenerator.lastPoolStats`, which is in-memory, so a menu
  redisplayed after restart shows a degraded pool with no warning.
  **VERIFIED CLOSED 2026-08-12, and it took three more rules to get there.** (a) A fail-safe
  degrade must be gated on whether anything COULD have been missed, not on the read failing:
  `sharesUnavailable && othersOnRoster` — a household of one has no peer share to lose, so
  degrading it is a permanent four-allergen floor and a permanent menu warning charged to a
  population with nothing to tell you. Spell the gate so a NULL identity counts everyone as
  "other" (`memberIds.any((id) => id != selfId)`), i.e. it fails toward degrading. (b) An
  AUXILIARY data source layered onto a tri-state lookup must be applied at the SWITCH'S CALL
  SITES, never before it — the share was applied above the `switch (lookup.status)`, so a share
  left by a DELETED account (`missing`) kept filtering the menu, re-enabling exactly the crouch
  BUT-1663 declined, while the roster still reported complete. (c) **Do not review a fileset
  another session is still writing.** These four files changed FOUR times mid-read; the handoff's
  "28 green" was false against the bytes in front of me (25/3) and true three minutes later. Run
  the suite the handoff cites YOURSELF, md5 the fileset before and after every `Read`, and on any
  change re-read rather than re-reason — two of the three failures were fixes that had not landed
  yet, and reporting them would have been a review of a file that no longer existed. **The
  cheapest detector needs no baseline (2026-08-13): the text `git diff HEAD` prints IS the current
  worktree, so any wording it shows that your `Read` did not proves a write landed mid-review** —
  a re-worded comment block caught exactly that here, confirmed in one call by mtime plus an empty
  `git diff` (index == worktree). A verdict is scoped to BYTES, so re-`Read` the changed file and
  re-checksum at the END, or the gate pins content the reviewer never saw. Final state
  pinned: index == tree for all four, 28/28 and 86/86 across the four household suites, analyze
  clean.
  **Gate-pass 2026-08-12 (same slice): the DARKNESS is what makes the GDPR gap non-blocking, so
  COUNT the gates and name them.** `household_allergen_shares` has no `firestore.rules` match
  block, the flag's CODE default is false, and the only caller in `lib/` is a READ (grep the
  INTERFACE name: DI registration plus one read site, zero writers) — three independent gates,
  and any one of them failing turns the missing Art. 17 cascade step, Art. 15 export section and
  `probeResidualData` canary entry from a launch gate into a live violation of Art. 9 data.
  Enumerate all three the moment the COLLECTION CONSTANT is introduced, not the day the rules
  open, and state which you checked — a reviewer who opens only the rules file grades the same
  gap Critical or clean depending on which gate they happened to look at. Corollary from the one
  line that changed in this pass: a comment citing another FILE by LINE NUMBER drifts inside its
  own commit (`household_service.dart:89` → `HouseholdService.getHousehold`) — cite the SYMBOL.
  **The gate count is per COMMIT, and one gate flipped from three to two on 2026-08-12 without
  the rules or the flag moving:** the consent UI shipped, so `lib/` now holds WRITERS (create /
  revoke, `household_allergen_sharing_tile.dart`), and only the flag and the absent rules block
  still hold. Re-derive the caller list every pass by grepping the INTERFACE name, and check the
  UI's own gate is unconditional (flag read once in `initState`, `build` returns
  `SizedBox.shrink`, each handler re-guards on the state the gated resolve sets). **When a
  comment names a REMAINING gate, verify its SINK too:** the missing `consent_granted` /
  `consent_withdrawn` pair (DPIA R5) purges at the wrong horizon unless
  `functions/src/audit_logs/purge-expired.ts` gains `consent_withdrawn` in `CONSENT_OPERATIONS`
  — that `in`/`not-in` list is exhaustive-by-enumeration, so an unlisted `consent_*` op silently
  falls to the 180-day general bucket, i.e. the Art. 7(1) trail is deleted at six months. Today
  the only survivor of a withdrawal is the base class's `operation:'delete'` permission row
  (audit repository IS injected in `social_module.dart` — check that before crediting even
  that), which carries no `consentVersion` and is 180-day. And a DPIA/ADR that describes such a
  mitigation in the PRESENT tense (R5: "the grant and withdrawal events are recorded … and
  appear in the member's own data export") is an assertion about code with no expiry date —
  when the code comment and the legal doc disagree, the code wins and the doc is the defect.
  **GATES ARE NOT OF EQUAL STRENGTH, and the enumeration itself becomes the launch checklist
  (2026-08-12, tile pass).** A feature FLAG is flippable from Remote Config with no code change
  (`isEnabled` reads `_remoteConfig.getBool` and falls back to `_defaults` only in its catch),
  so a code default of false gates a deploy, not an operator; the ABSENT rules block is the only
  gate immune to a remote flip, because the catch-all `match /{document=**}` denies the write
  whatever the client believes. Count them separately and say which one is load-bearing. Then
  read any comment that lists "what is still missing before this may be flipped" as the
  checklist someone will flip from: BUT-1693's names the rules block, the atomic settings+share
  write and the consent audit pair, and OMITS the Art. 17 cascade step, the Art. 15 export
  section and the `probeResidualData` entry (`grep household_allergen functions/src` → zero) —
  the same three the DPIA's R7 asserts in the present tense. An incomplete gate list is worse
  than none, and it is a Medium finding on a comment-only diff, not a nit. **FIXED 2026-08-12
  (same slice) — and the fix exposes the next rule: a checklist's CITED EVIDENCE must reach every
  item it justifies.** The list now names all four and cites `grep household_allergen
  functions/src` → empty, which can only prove three of them: erasure lives in `functions/src`,
  but Butlery's Art. 15 export is CLIENT-side (`lib/services/account/export/*`, the allergen
  share's natural home being `family_export_manager.dart`, which today exports only diner
  profiles + family ratings). A GDPR checklist spanning both halves must name BOTH greps, or a
  reader re-runs the one command and credits a claim it structurally cannot reach. The same
  wording has already propagated into the DPIA's R7 status line — check where a cited grep was
  copied to, not only where it was written. Related same-day verification, cheap and worth
  repeating: `CONSENT_OPERATIONS` in `purge-expired.ts` already carries BOTH `consent_granted`
  and `consent_revoked`, so a doc prescribing a `consent_withdrawn` token would have minted a
  second spelling for one act and dropped it into the 180-day bucket — read the enumerated list
  before naming an audit operation in a comment, a DPIA or a ticket.
  **Grade a "redundant" identity check by which HANDLE each layer reads, never by whether a
  similar-looking check exists downstream (2026-08-12, tile re-read — a correction of my own
  earlier verdict).** I graded `profile.uid != userId` in
  `HouseholdAllergenSharingTile._grant` as "defence in depth; the repository's `create`
  independently asserts self-declaration". It is not: the entity's `userId`, the deterministic
  doc id, `validateCreatePermission` and `_assertSelfDeclaredWithConsent(requireCurrentUserId())`
  all resolve to the SAME live `AuthRepository.currentUserId`, so they agree tautologically —
  while the ALLERGENS come from `UserService._currentUserProfile`, a cached snapshot cleared
  only on a NULL auth event and refilled asynchronously. In an A→B switch with no null tick,
  that conjunct is the only comparison of two DIFFERENT handles, i.e. the only layer between one
  person's Art. 9 list and another's declaration; rules cannot help, since `auth.uid` and the
  path are both live too. General rule: when a guard compares a CACHED value's identity against
  a LIVE one, no downstream layer that reads only the live one can replace it, and calling such
  a guard "defence in depth" is itself a defect — that sentence is what licenses deleting it.
  The stale `_householdId` beside it IS closed downstream (the membership conjunct of
  `validateCreatePermission`), which is why the handle must be traced PER FIELD rather than per
  call site.
- **A CONSENT RECORD stored in the same document as the data it authorizes must be immutable
  on update, at both layers.** A model can make it un-`copyWith`-able and still lose it: a
  public `update(entity)` that full-`set()`s a caller-built entity re-dates `consentGrantedAt`
  and re-writes `consentVersion` on every ordinary edit, so the Art. 7(1) evidence drifts to
  the last preference change and a version bump can be silently undone. The repository usually
  already holds the stored doc (its update-permission check read it) — carry the stored consent
  triple forward — and the rule pins
  `request.resource.data.consentGrantedAt == resource.data.consentGrantedAt`. That rule is only
  writable if the field is a TIMESTAMP: a client-set `toIso8601String()` string cannot be
  type-checked, cannot be pinned to `request.time`, and `safeBool` accepts the STRING `'true'`
  as a granted flag, so `is bool` belongs in the rule too.
  **CLOSED for `update()` 2026-08-12 (BUT-1693) — and closing it moves the problem to `create()`.**
  The shipped shape is `entity.withStoredConsent(stored)`: the repository already read the stored
  doc for its permission check, so the consent triple is carried forward and the payload's is
  discarded. Check the class's DECLARATION line for `BatchOperationsFirebaseRepository` before
  filing the usual batch-bypass finding — without that mixin `updateBatch` does not exist, and
  `createBatch` (which lives on the base class) is the only sibling to cover. Then follow the
  RE-GRANT path, which is the door the fix leaves open: it is a `create()`, i.e. an unconditional
  `set()`, so a stale client can re-date the record and write an OLDER `consentVersion`.
  **CLOSED the same day (BUT-1693), and the shape generalises:** make `create()` REFUSE an
  existing id and require `consentVersion == currentConsentVersion`, so a re-grant is always a
  create on an ABSENT document (withdrawal deletes). That kills the stale re-date AND settles the
  rules question — Firestore evaluates a `set()` over an existing doc as an UPDATE, so pinning
  `consentGrantedAt == resource.data.consentGrantedAt` would otherwise make a withdrawal
  irreversible; with no re-grant ever reaching `update`, the pin is free. Two details or the guard
  is decorative: read the doc DIRECTLY, never the base `exists()` (it SWALLOWS a failed read and
  answers false, so one offline blip waves the overwrite through), and re-apply both guards in
  `createBatch`, whose `batch.set` runs past the `create()` override.
- `allow list` and `allow get` are evaluated separately — a `get` rule granting
  `auth.uid in resource.data.arrayField` does not make the matching `list` pass; a
  membership-gated query needs its own `list` branch + composite index.
- `request.auth.uid in resource.data.someMap` checks MAP KEYS, not values.
- Self-only set edits: symmetric-difference CEL
  (`before.toSet().difference(after).union(after.toSet().difference(before)).hasOnly([auth.uid])`)
  + `affectedKeys().hasOnly([...])`. Self-leave-a-shared-doc needs `removeAll()` both directions
  or a recipient can grief by dropping others while leaving.
- `rateLimitWrite(collection, seconds)` is only live if a write path stamps
  `users/{uid}/rate_limits/{collection}.lastWrite` — else it's a permanent no-op, and liveness is
  **PER BUCKET, never per repo**. **CORRECTION 2026-08-14 (BUT-1838 gate pass): the 2026-07-30
  "NOTHING in the repo writes that path" is FALSE as a blanket claim** — six Dart writers stamp
  `FirestoreCollections.userRateLimits` (= `'rate_limits'`) with a per-bucket doc id, so four rules
  buckets ARE live: `messages` (`message_mutation_module.dart`, batched beside every send),
  `comments`, `social_requests`, `activity_events` (plus `imports` and `friendSearchMigrated`, which
  no rule reads). Every OTHER bucket is inert for want of a writer — including `audit_logs`, so
  BUT-1773's conclusion below survives, and including any bucket a NEW rule invents
  (`chat_group_rename`, BUT-1838: decorative on arrival). Grep `.doc('<bucket>')` under
  `userRateLimits` before calling a specific conjunct live or dead; a bare grep of the CONSTANT
  answers neither question, which is how the blanket claim got written. Never let a design comment
  cite one as a live constraint — BUT-1773's
  one-audit-row-per-export decision is argued in three places from "rows 3..30 would be rejected by
  `rateLimitWrite('audit_logs', 2)`", which is false. The Art. 30 argument (the processing activity
  is the REQUEST, not each read) stands on its own; the rules claim must go.
- **Moving a denied client write into a callable moves the whole document behind an Admin-SDK
  read, so every distinguishable RESPONSE becomes an oracle for a doc the caller cannot read.**
  A callable is not covered by `firestore.rules`: `not-found` vs a business refusal vs an
  idempotent success each disclose something. `leaveGroupConversation` (BUT-1788) judges
  "target == caller" BEFORE any membership test — correct for idempotency, but it means a
  non-member self-leave returns `{removed:false, remainingParticipants:N}`, i.e. existence AND
  size of any conversation whose id you can guess; direct-conversation ids are deterministic
  (`direct_{sortedUidA}_{sortedUidB}`) and uids come from profile search, so "do A and B have a
  DM" becomes a query. Rule for any client-write→callable migration: enumerate the response set
  (each `HttpsError` code + each success shape) and ask what a caller who is NOT a participant
  learns; disclose no counts on the no-op branch, and prefer collapsing "not a member" into the
  same error as "does not exist". **CLOSED 2026-08-01**: one gate placed before ANY
  shape-revealing branch (`if (!snap.exists || !participantIds.includes(callerUid)) return
  {removed:false, remaining:0}`) collapses missing / not-a-member / already-left into one reply,
  and it needs a PAIRED positive test (a real member still gets the true count) or it passes on a
  function that always returns 0. **THE PRICE OF THAT GATE (2026-08-01): it also swallows "the
  callable is reading the wrong path" as a SUCCESS.** `!snap.exists` now means the same as
  "already left", so a callable pointed at a doc the client writes elsewhere returns
  `success:true` and the caller reports a completed leave (Butlery's `ConversationsViewModel.
  leaveGroup` even fires `logGroupLeft`) while nothing was written — a loud failure traded for an
  invisible one. Whenever a no-oracle gate merges a not-found branch into success, prove the doc
  EXISTS on the path the callable reads by tracing the real writer (not the ticket's premise), and
  make the no-op branch still perform whatever cleanup is the CALLER'S OWN data (their membership
  mirrors), which discloses nothing and is the only part a wrong-path call can still get right.
  **The CLIENT half is the one that actually ships the lie, and it is a separate review item
  (verified 2026-08-01, BUT-1781 fileset).** A migration diff that keeps the repository signature
  `Future<void>` cannot honour `removed` no matter how correct the CF is: Butlery's
  `ConversationMutationModule.removeParticipant` `await`s the callable, discards
  `{success, removed, remainingParticipants}` and logs `'✅ Removed participant …'`, so every merged
  branch — doc absent because `createGroupConversation` wrote `users/{uid}/conversations` via the
  `UserScoped` `createFn` while the CF reads top-level, caller not a member, already left — reaches
  the user as a completed leave. Fixed check on any client-write→callable migration: read the
  RETURN TYPE at every layer of the caller chain (module → repository → service → VM) and require
  the no-op to be distinguishable; `Future<void>` at any layer means the response contract is
  unreachable and the guard is decorative.
- **The SECOND half of that migration: a field the CREATE rule binds is not bound at CALL time.**
  A callable that reads an admin identity off the document (`metadata.creatorId`) inherits only
  the constraint the UPDATE rule still enforces. Butlery's `conversations` update rule
  (`firestore.rules:1532-1535`) forbids exactly `participantIds` + `createdAt`, so any
  participant may rewrite `metadata` — and `leaveGroupConversation`'s "only the group admin may
  remove others" becomes "any member who first writes one field". A create-time binding is only
  trustworthy to a create-TIME reader (`enforceGroupMinorMembership`, an onDocumentCreated
  trigger, is fine). Fixed check whenever a CF derives authorization from document data: open
  the collection's UPDATE rule and confirm that exact field path is immutable
  (`request.resource.data.metadata.get('creatorId',null) == resource.data.metadata.get(...)`),
  or resolve the identity from a path the client cannot write at all.
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
  **The cheapest correct shape is the SERIALIZER override**: `BaseFirebaseRepository` funnels all
  four write paths through `toFirestore(entity)` (`:118`, `:228`, `:292`, `:464`), so putting the
  transform there covers create/update/createBatch/updateBatch by construction (BUT-1819). Two
  things to check before accepting one. (a) It only covers writers that go through the base class —
  grep the collection CONSTANT for hand-built `.set(`/`.update(` refs (`OfflineSyncManager` writes
  `users/{uid}/recipes` via `FirestoreRepository.setDocument` and never touches the repository).
  (b) A transform implemented with `copyWith` inherits every DEFAULT in that `copyWith`: Butlery's
  `RecipeCore.copyWith` is `updatedAt ?? clock.now()`, so "cleaning" a document silently restamps
  it — fatal on an offline replay whose `updatedAt` is the last-write-wins key. Passing the field
  through explicitly fixes that AND silently changes the online path that used to rely on the
  restamp; enumerate the callers that build the entity by CONSTRUCTOR rather than `copyWith`
  (membership writers, re-share) — those are the ones whose timestamp now stops advancing.
- **`validateRequiredFields` checks `containsKey` only** (`permission_validation_mixin.dart:290`),
  and Butlery's `toFirestore()` serializers emit a FIXED key set — so it can never reject an empty,
  blank or whitespace value, and reordering a sanitizer to run BEFORE it changes no verdict at all.
  Any comment or ticket claiming "validate the sanitized copy so an empty title is rejected" is
  false until a length/emptiness check is actually added; read the validator body before crediting
  a validation-ordering fix with a security effect (BUT-1819).
- On UPDATE, permission checks must load the STORED doc's ownership field, not the submitted
  entity's — else a caller who is a member of TWO groups can re-parent a doc between them by
  resubmitting it.
- A `not-in`/`in` filter (e.g. an audit purge sweep) silently excludes docs where the
  discriminator field is ABSENT from both buckets — every writer must set it unconditionally.
  **Replacing a PREDICATE with an ENUMERATION reclassifies history, not just new writes.**
  BUT-1404 swapped `op.startsWith('consent_')` for `where('operation','in',CONSENT_OPERATIONS)`
  and dropped `consent_deleted` — a token with no live caller since BUT-788 but with real rows
  in `audit_logs` — so every one of them fell to the 180-day bucket and would have been erased
  ~2026-10-24, six months into a 730-day Art. 7(1) trail. Derive such a list from HISTORY
  (`git log -S "<token>"` / `git log -S` on the writer method), never from today's writers, and
  keep a retired token listed with the date it becomes droppable (last row + retention). Two
  companions: retiring a token is a RENAME in one file and a retention change in another, so
  pin the new spelling with a test that captures the logged `operation` argument; and an
  "exhaustiveness" test comparing a hand-typed list against the hand-typed constant is vacuous
  by construction — it cannot see a token added in the OTHER language, which is exactly how
  this one hid. Derive the expectation from the source files at test time.
  **The EXPOSURE WINDOW is bounded by the token's CALLER window and by the purge's own birth,
  never by the token's birth (verified 2026-08-13).** `consent_deleted` existed in Dart from
  2025-10-30, but `git log -S` on the CALL site shows it was only ever reachable between
  BUT-498 (2026-04-27) and BUT-788 (2026-05-22) — and the purge function itself was created
  2026-05-01 classifying by `startsWith`, so the rows were correctly bucketed until the
  2026-06-28 enumeration swap. That makes the exposure 46 days on rows all still short of the
  180-day cutoff: listing the legacy token SAVES them rather than recovering a loss, and the
  distinction decides whether the finding is "data already destroyed" or "close it now". Run
  three greps before dating such a claim — `git log -S "<token>"`, `git log -S` on the calling
  METHOD, and `git log --diff-filter=A` on the purge file — and check the intervening call
  sites really used the repository (a direct-Firestore sibling like the pre-BUT-498
  `deleteConsentRecords` writes no audit row at all, so its years do not count).

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
  shape error is the WRONG NESTING LEVEL**: the sharpest in-repo generator of it is
  `UserScopedFirebaseRepository`, which silently repoints `create`/`read`/`update` at
  `users/{uid}/<collectionName>` while every hand-written `firestore.collection(collectionName)`
  call and every query in the SAME module hits the TOP-LEVEL collection of the same name.
  `FirebaseMessagingRepository` mixes it in with `collectionName == 'conversations'`, so
  `createGroupConversation`/`addParticipants`/`updateConversation` (which go through `createFn`/
  `readFn`/`updateFn`) write and read the creator's private subtree, while
  `createDirectConversation`, `deleteConversation`, `updateConversationUserSettings`, the
  `arrayContains` stream and the new `leaveGroupConversation` CF all use top-level
  `conversations/{id}` — so a doc created by one half is `not-found` to the other. Whenever a
  module mixes hand-built refs with base-class CRUD, resolve `getCollectionRef()` for that class
  before believing any path claim, and re-check any CF written to "fix" such a path.
  **Traced end-to-end 2026-08-01 (BUT-1788 re-review), and the trace is the reusable move:** a
  top-level GROUP conversation doc is born only in `MessageMutationModule.sendMessage`, whose
  `batch.set(conversations/{id}, ConversationDto.toFirestore(...), merge:true)` copies the
  creator's private subtree copy up — and `createGroupConversation` never gets there because the
  `Message.system` it sends (`senderId:'system'`) fails its own `isParticipant` check and throws.
  So the doc the `leaveGroupConversation` CF reads does not exist until the CREATOR sends a chat
  message. Lesson: when a ticket's premise is "the RULE denies this write", confirm the write even
  REACHES the collection the rule guards — here the client write lands in the private subtree
  where the owner is allowed, so both the ticket's diagnosis and the CF's target were derived from
  a path the operation never touched. Follow the writer chain to a `.set(`/`.update(`, never to a
  constant. **MOVING that creation to the Admin SDK removes the private copy the client's fallback
  depended on, and the fallback is deny-shaped (BUT-1838):** `read()` returns null for every group,
  so `MessageMutationModule.sendMessage` fabricates a `participantIds:[sender]` + `createdAt: now`
  conversation and the merge-set it batches beside the message trips the update rule's deny-list on
  BOTH keys — killing the message with it. The rules suite cannot see this: its fixture seeds the
  SAME participantIds and createdAt the payload sends, so `affectedKeys()` is empty and the test
  passes. When a create path moves server-side, grep every client read of that doc that still
  resolves through a user-scoped `getCollectionRef()`. **Do that grep as a SET, and count the
  seams — fixing two of three is the failure mode (BUT-1838 re-review, 2026-08-13).** A repository
  facade hands the same `read` to several modules, so one collection has several read seams:
  `ConversationQueryModule.getConversation` and `MessageMutationModule.readConversation` were
  repointed to the top level and `ConversationMutationModule`'s `readFn: read` was not — which is
  the whole of `updateGroupTitle`, so renaming a group throws `ResourceNotFoundException` for every
  admin on every group. Enumerate the CONSTRUCTOR ARGUMENTS at the wiring site, not the methods you
  happened to open. Two traps in the obvious fix, both worth stating in the finding rather than
  patching: the WRITE half of such a seam is separately user-scoped (`markConversationAsRead` reads
  top-level now and still writes through `update`, i.e. a `.update()` on a doc that does not exist),
  and a top-level full-doc `update(dto.toFirestore(e))` re-sends every deny-listed field, so it
  survives only while the values round-trip byte-identically. Where the server has since taken
  ownership of the fact (here `chat_groups.name`, with its own admin-only `hasOnly(['name',
  'updatedAt'])` rule that NO client code calls and no trigger syncs back to `conversations.title`),
  the right answer is a target change, not a path change.
  Second half of the same shape error: `deleteUserSubcollections` sweeps
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
  string, are rules-exempt, and are therefore empty rather than denied. **Fourth variant of the
  same shape, found 2026-07-30: an in-memory FILTER predicate keyed on a field the model never
  persists.** `social_export_manager.exportMessages` keeps a message when
  `senderId == uid || messageData['recipientIds'].contains(uid)`, but `Message` has no
  `recipientIds` (the rules' create requires only `senderId`/`conversationId`/`content`/`sentAt`),
  so the OR-arm is dead and the filter silently degrades to "sent only" — every RECEIVED message
  dropped from the Art. 15 bundle with no truncation or error flag. Masked today only because the
  query reads a phantom subcollection (BUT-1767); repointing that query lands the gap invisibly.
  **Correct the failure mode before repeating it (2026-07-30): a phantom path with no rule block does
  not read EMPTY, it reads `permission-denied`** — `conversations/{id}/messages` has no branch
  (`firestore.rules:1494-1546`), so the catch-all `if false` (`:2548-2550`) denies the query, the
  `.get()` has no local catch, and the manager's outer catch drops the WHOLE section into
  `messages-export-failed`. So the requester loses their own conversation metadata too, not just the
  messages, and any redaction added inside that section is unreachable in production until the path is
  fixed. Whenever a ticket or deviation entry says a section "ships empty", check the rules for the
  path before believing it.
  Whenever an export/cascade filter, redaction map or probe NAMES a field, grep the MODEL's
  `toFirestore()` for it — the same derived-key discipline the BUT-1732 redaction test uses, owed
  to filter predicates too, and a dead OR-arm fails toward under-export where a dead AND-arm would
  fail toward over-export. Verified 2026-07-27: for
  `userShoppingLists` both client/CF readers the comment names are real
  (`friends_utility_operations.dart:146` root query → catch-all deny `firestore.rules:2526-2528`;
  `compute-feature-retention.ts:212`), and a denied QUERY surfaces as `permission-denied`, not empty.
- **A new PER-DOCUMENT conjunct in a READ rule silently breaks every UNFILTERED query on
  that collection — the GDPR export's first, because nobody runs it.** Rules are not
  filters and a query returning even ONE refused document fails ENTIRELY, so BUT-1838's
  `messages` read gate (`sentAt >= memberSince[uid]` where the conversation carries a
  `groupId`) turned `exportConversationsAndMessages`' unfiltered per-conversation message
  query into a guaranteed `permission-denied` for anyone added to a group with prior
  history — and since that read has no per-conversation catch, the WHOLE `messages`
  section (every conversation, every message, not just the group) lands as
  `messages-export-failed`. Whenever a rules diff adds such a conjunct, enumerate every
  reader of the collection (chat stream, pagination, SEARCH, export, cascade probes) and
  require each to mirror the predicate; the UI path usually gets it and `searchMessages`
  usually does not. Second half, same ticket: **an export leg that hand-builds a
  projection must run its values through `sanitizeForJson` at the leg** — the bundle is
  `JsonEncoder.convert`ed once at the end, `Timestamp` has no `toJson`, so a single raw
  Firestore value thrown into a projection map fails the ENTIRE Art. 15 export (the
  section's own try/catch is around the READ and cannot see an encode that happens later).
  A projection also needs the same three things a whole-doc leg gets: an N+1 truncation
  probe, an `error_code` (a bespoke nested `<x>_export_failed` flag is invisible to
  `DataExportService`'s lift, which keys on `error`/`error_code` at SECTION top level and
  on `truncated`/`*_truncated` in the walk), and a line in `data_minimisation` naming what
  the projection drops.
  **Third half, and it is the trap that DEGRADING a section's failure mode opens (BUT-1838,
  closed 2026-08-14): moving a read's try/catch from the SECTION to the ROW buys resilience
  by spending the alarm.** A per-conversation catch stops one unreadable conversation
  failing the whole `messages` section — but the row it substitutes (`messages: []`,
  `message_count: 0`) is byte-identical to a conversation that genuinely holds no messages,
  so the bundle silently understates itself. The shipped shape, and the one to demand
  whenever a catch is narrowed: the repository stamps a row-level `error_code`, the manager
  copies it onto the row AND sets a SECTION-ROOT `error_code` **with no `error` key** —
  because `DataExportService` reads `error` as "could not be exported" and a bare
  `error_code` as "may be incomplete", and the second is the true claim when the other rows
  did export. Never let the row marker be the only one; the aggregator's nested walk looks
  for `truncated`, not for arbitrary keys. One residual worth knowing when several legs
  `addAll` into one section map (`ChatGroupExport` into `exportMessages`): the last leg's
  `error_code` overwrites the earlier one, so the section keeps ONE token — harmless while
  both mean "incomplete", wrong the day a leg adds an `error` key too, which would relabel
  a partially successful section as failed outright.
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
  handle. **CLOSED 2026-07-30 (BUT-1733), and the fix shape is the generalisable part:** rather
  than adding the union at the fourth call site, ONE helper (`_withContributorTrail`) now decides
  the obligation from the payload itself — `if (!payload.containsKey('items')) return payload;` —
  so a fifth write path inherits it by construction, and a rename correctly stamps nothing (the
  trail records who touched the ROWS that carry names, and the rule caps it at 200 entries). Two
  details to check when copying it: the helper must offer BOTH spellings, `FieldValue.arrayUnion`
  for ordinary writes (what makes an offline replay merge) and an explicitly-computed union for a
  transaction (which already holds the live array, and where a merge-set will not honour the
  sentinel); and the "does this payload persist the field" test only works because
  `toFirestore()` emits a FIXED key set — verify that before keying an invariant off
  `containsKey`. Discharging the "no live caller leaks today" claim costs a full caller trace, not a
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
  just its existence. **Generalised 2026-07-30: `git diff --cached` is not the tree.** Run
  `git status --porcelain` over the WHOLE commit fileset and diff the unstaged half of every `MM`
  / `AM` file — a mutation-test mutant survives a review that only reads the index, is what
  `flutter analyze` and every test run actually executes, and ships the moment anyone runs
  `git add -A`. One was live during this review: `social_export_manager.dart`'s `_failed()`
  replaced by `'error': 'MUTANT raw exception: PERMISSION_DENIED blocks/<foreign uid>'` with
  `error_code` deleted. **The INVERSE is the re-review shape (2026-08-12, BUT-1693): the FIX is
  the unstaged half and the INDEX still holds the defect the last round asked to fix** — the
  staged `validateDeletePermission` was the body-reading version whose parse throws before the
  ownership test (un-erasable Art. 9 doc), while the tree carried the path-only repair. So on any
  re-review, md5 the index (`git show :<path> | md5sum`) against the tree, scope the verdict to the
  bytes reviewed by naming that md5, and state the re-stage as a precondition — a clean verdict on
  tree bytes silently blesses whatever the index happens to hold. Same pass: verify the conditions
  a handoff says were "carried into the plan" are literally IN it (grep the symbol) — two of that
  round's were not, and an unrecorded carry is a finding that expires with the session.
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
  **Same defect in the realtime tier, open 2026-07-30:** `deleteRealtimeRecipes` /
  `deleteRealtimeMenus` (BUT-1768) `batchDeleteAll` the parent and never touch
  `realtime_recipes/{id}/presence/{uid}` — a doc keyed BY uid carrying `displayName`
  (`realtime_editor_tracker.dart:28-32` → `collaborative_recipe_repository.setPresence`) — or
  `/votes/{uid}`. Both have `firestore.rules` blocks, so both paths are live. And on a doc the user
  does NOT own, `scrubLastEditor` anonymizes the `lastEditedBy*` pair but leaves their
  `presence/{uid}` doc, their `participants` MAP KEY and their `participantIds` entry. Whenever a
  step adds a scrub for one denormalized pair, enumerate that collection's subcollections from
  `firestore.rules` in the same pass — a rule block is the cheapest proof a child path is written.
- "Export ⊇ erasure" is a field-PAIR property: export filter and deletion filter must target the
  identical field on the identical collection. Every new user-data collection needs BOTH
  cascades checked in the same review (deletion AND export) — one wired, one forgotten recurs.
  **And a fix that makes an ANALYTICS PROBE start returning true is a GDPR change even when its
  own diff only touches a private owner-scoped field** (BUT-1762: a per-day `updatedAt` stamp so
  the nightly `shopped` probe stops reading structurally false). The probe's SINK is the new
  personal-data surface — `analytics/feature_retention/users/{uid}_{yyyy-mm-dd}` carries a RAW uid
  in both the doc id and a `userId` field plus five behavioural booleans, one doc per user per day,
  and as of 2026-07-31 it is in NO cascade step, NO `probeResidualData` entry, NO TTL job and NO
  deviation entry (OPEN). Whenever a diff flips a metric from structurally-zero to real signal,
  grep the sink collection in `account-deletion-cascade.ts` before passing it.
  **Two more shapes of the same pair failure, both found 2026-08-01 on `shared_content`.**
  (a) **A COMPATIBILITY DUPLICATE of a membership array is a new PII copy and a new erasure
  surface.** Butlery writes recipient uids under two spellings in one collection —
  `sharedToUserIds` (what `firestore.rules`' `allow list` grants on, what the cascade's
  `removeFromSharedContent` `arrayRemove`s, what the export now reads) and `sharedWithUserIds`
  (the three direct writers). Teaching the writers to emit BOTH fixes the read grant and the
  export in one move and silently doubles the residual: nothing scrubs the second spelling, and
  the scrub that does exist DISCOVERS its docs via `collectionGroup('members').where('userId')`,
  a subcollection the direct writers never create — so neither copy is erasable on those docs.
  When a diff adds a second spelling of an existing field, extend the scrub's FIELD LIST and its
  DISCOVERY QUERY and the residual probe in the same change, or the duplicate is pure liability.
  (b) **A shared multi-type collection needs the export to enumerate every discriminator value.**
  Repointing the recipe and menu legs at `shared_content` left `contentType == 'shopping_list'`
  (written by `shopping_social_share_module`, carrying a whole `listData` snapshot plus the
  sharer's avatar URL) read by no export leg at all — and the sibling `SharedShoppingListExport`
  looks like coverage but reads a DIFFERENT collection (`unified_shared_shopping_lists`). Whenever
  an export query filters on a type discriminator, list the discriminator's full value set from
  the writers and account for each one.
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
- **Every residual probe in this repo is FIELD-keyed, so it is structurally blind to an
  identifier that lives in a DOCUMENT ID — and a step that knowingly leaves such a document
  standing must report itself INCOMPLETE, because nothing else can.** BUT-1822's fallback (roster
  unclearable ⇒ keep the parent so `parentDoc() == null` never opens the bootstrap branch) strips
  the erased uid from every FIELD, which is exactly what makes the `participantIds
  array-contains` probe leg read zero — while the surviving document is still literally named
  `direct_<erasedUid>_<survivorUid>`. Fix shape: the branch flips a `complete` flag, the sweep
  returns a bool, the step returns `complete && swept`, so `failedCollections` carries it and the
  audit row says `gdprCompliant: false`. Ask it of any "least-bad outcome" branch: name what
  survives, then name which probe leg would see it — "none" means the step owns the alarm.
  Companion: a cap that DECLINES rather than truncates is only defensible once you have checked
  whether truncating would also be loud (here both are, via an uncapped `count()` probe), so
  write the real reason down — a false justification is what a future editor deletes the control
  on.
- **A row authored by a SYNTHETIC identity ("system", "bot") that names a real person in FREE TEXT
  is invisible to every cascade, because every cascade is keyed on an id field.** `deleteMessages`
  anonymizes `messages where senderId == uid` and tombstones `lastMessage` only when
  `lastMessage.senderId == uid`; a departure/join notice written by a CF as
  `{senderId:"system", content:"<Name> har lämnat gruppen"}` matches neither, so the name outlives
  erasure in the message row AND in the `conversations.lastMessage` copy that
  `syncConversationLastMessage` makes of it (BUT-1788). Note the trap that hides this class: the
  same rows attempted CLIENT-side were always denied (`messages` create demands
  `auth.uid == senderId`), so moving an operation to the Admin SDK can make a long-dead PII write
  start landing. Any CF-authored row that embeds a display name needs an erasure HANDLE at write
  time — an id field the cascade can query (`metadata.subjectUserId`) plus a cascade step and a
  probe entry — or must not embed the name at all.
- Cross-user cascade mutations stage their audit-log entry in the SAME batch as the mutation.
- Denormalized author/sharer PII travels in FIELD GROUPS (`sharedBy*`, `authorName*`,
  `lastActivityBy*`) — tombstoning one field on deletion requires clearing every field sharing
  that prefix. **The rename-propagation CF is the inventory**: every `{queryField, updateField}`
  pair in `functions/src/social/on-profile-updated.ts` is a denormalized-name field group that
  survives account deletion unless the cascade names it too. Diff that list against
  `account-deletion-cascade.ts` — `unified_shared_shopping_lists.lastActivityBy{UserId,DisplayName}`
  and `ownerDisplayName` are propagated on rename but NOT scrubbed on erasure (open, BUT-1665 review).
  **Second live instance, found 2026-07-30 (BUT-1766 review):** `on-profile-updated.ts:96-97`
  propagates `conversations.participantDisplayNames.<uid>` + `participantAvatarUrls.<uid>`, and
  `deleteMessages`' group branch removes ONLY the `participantIds` array entry — so a deleted
  user's name and avatar URL stay on every group conversation the remaining members read, along
  with `lastReadTimestamps.<uid>`, `perUserSettings.<uid>` and the embedded `lastMessage` copy
  (name + avatar + content) that anonymizing the top-level `messages` row does not touch. The
  correct removal shape already exists in the same repo —
  `functions/src/messaging/enforce-group-minor-membership.ts:247-252` deletes all three dot-paths in
  one `update()`. **General rule: when a cascade leg's ONLY action is `arrayRemove` on a membership
  array, treat it as incomplete until you have grepped the propagation CF for `<map>.${userId}`
  keys on the same collection**, and add `participantIds array-contains uid` to the residual probe
  (a membership array is the one map-shaped residual Firestore CAN query).
  **The diff runs BOTH ways, and the rename side is the one that under-enumerates (2026-07-30,
  BUT-1770).** The cascade scrubs FOUR item-level pairs on `UnifiedShoppingItem`
  (`assignedTo*`, `purchasedBy*`, `addedBy*`, `lastModifiedBy*`); the rename CF added only
  `addedBy*` + `lastModifiedBy*` while its own doc comment claimed cascade parity. Two checks
  whenever a propagation leg is added: (a) enumerate the group from the MODEL's `toFirestore()`
  and from the cascade's scrub block, never from the ticket; (b) ask which member of the group a
  VIEW actually renders — here the two propagated fields have zero UI readers and the missed
  `assignedToDisplayName` is the one on screen (`collaborative_shopping_items.dart:136,509`), so
  the fix shipped without touching the symptom it was written for. Cost/index corollary that WAS
  done right: a `collectionGroup("items")` equality sweep needs an explicit COLLECTION_GROUP
  single-field override in `firestore.indexes.json` (automatic ones are collection-scoped), and a
  fake-Firestore CF test cannot see that — assert the declared override from the JSON in the same
  suite.
- **An export that REDACTS a field group must enumerate the group from the model's
  `toFirestore()`, not from memory.** BUT-1732's `SharedShoppingListExport.nameKeysByOwnerIdKey`
  lists four name/id pairs; `UnifiedShoppingItem.toFirestore()` persists six —
  `purchasedByDisplayName` and `lastModifiedByDisplayName` (stamped on EVERY tick via
  `markAsBought`) ship other members' names raw, while the bundle's own `data_minimisation` string
  and the matching `ACCEPTED_DEVIATIONS.md` entry claim they are dropped. A false self-description
  in an Art. 15 bundle is its own defect, and an under-enumerated group is NOT covered by the
  deviation that decided the redaction. Open the serializer, diff its key set against the redaction
  map, and check the new test fixture actually contains the missing keys (this one did not).
  **CLOSED 2026-07-30, and the closure is the reusable part**: the map is no longer trusted to be
  exhaustive — a test derives the key set from the MODELS (`{...List.toFirestore().keys,
  ...Item.toFirestore().keys}`), filters `endsWith('DisplayName')`, and asserts the difference
  against the map is empty, plus that every paired `*UserId` is itself persisted (otherwise the
  "keep it when it is yours" branch silently becomes "drop it always"). Demand that derived-key
  test on ANY hand-enumerated field group; it only works because `toFirestore()` emits nulls rather
  than omitting keys, so check that first. The matching `ACCEPTED_DEVIATIONS.md` entry must state
  the count and the reason, since the bundle's own `data_minimisation` string is a claim the export
  makes about itself. **And the DTO is not the document (2026-07-30, BUT-1772):** a whole-doc export's
  third-party surface must be enumerated from EVERY WRITER, because a field written by dot-path
  `set(mergeFields:)`/`update()` never appears in `toFirestore()` and so is invisible to the derived-key
  test — `conversations.perUserSettings.<uid>.{isMuted,isPinned,isArchived,pinnedAt,archivedAt}`
  (`conversation_mutation_module.dart:416-441`; the DTO reads back only the CURRENT user's sub-map)
  ships every other participant's mute/archive behaviour, which the client never renders, so a
  "they've already seen it on screen" justification cannot cover it. Prefer "everything else is kept
  as stored" over a positive enumeration in the `data_minimisation` sentence: an incomplete KEEP list
  is the same self-description defect as an incomplete DROP list.
  **The INVERSE bites too, and it over-reports (2026-08-05, BUT-1797): a CONSTRUCTOR ARGUMENT is not
  the document.** `SharedRecipe.create(recipeSnapshot: recipe)` reads like the whole recipe
  (`socialData` included) lands in `shared_content`, and a deviation entry was filed on exactly that
  premise — but `SharedRecipe.toFirestore()` emits only the V2 denormalized fields and never
  `recipeSnapshot`, and the sibling writer builds its payload key-by-key. Before ruling on ANY "field
  X rides into collection Y" claim, open the serializer that the repository's `toFirestore` delegates
  to and confirm the key is emitted; an in-memory field held by a model is not a disclosure.
- **A DESCRIPTIVE provenance/attribution field is still a disclosure decision, decided by the
  document's READ rule, because Firestore has no field-level read control.** BUT-1797's
  `socialData.grants` (uid -> `['direct','group:<id>']`) changes no rule — `users/{uid}/recipes` reads
  `isOwner || uid in socialData.memberPermissions` and never `grants` — yet it sits in the doc every
  member may read, so the sharer's private grouping of their friends becomes visible to all members.
  Judge such a field on the DELTA over what the same doc already shows (co-member uids were already
  there) and on whether the new value is DEREFERENCEABLE: an opaque `categoryId` is only resolvable
  by someone already in `friendUserIds` (`firestore.rules` collection-group `friend_categories`), so
  no name leaks. That ruling expires the moment anyone denormalizes the NAME onto the doc for the
  panel — make the "stays opaque" condition explicit when clearing one.
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
  error/truncation marker, not a log line. **And the marker only counts if it is spelled
  `error_code`**: `DataExportService` rolls a section into `export_metadata.warnings` on
  `value['error_code'] != null` alone (message = `error` ?? `note` ?? 'Unknown error'), and only for
  TOP-LEVEL sections — a nested map is scanned for `messages_truncated` and nothing else. A bespoke
  per-section flag (`contributor_probe_failed`, a lone `note`) therefore admits incompleteness
  inside the section while the bundle's own metadata still reads complete — the exact defect the
  convention exists to close. Pair every new "this section may be incomplete" flag with an
  `error_code`, and never return `e.toString()` from a section catch: raw Firestore text carries
  uids and doc paths into an artifact the data subject may forward to a supervisory authority
  (BUT-1732). **Half-closed 2026-07-30 (BUT-1721), and the unclosed half is the reviewable lesson.**
  `DataExportService` now (a) lifts a section on `error` OR `error_code`, deriving
  `'<section>-export-failed'` when the manager set none, so a new manager cannot go silent at bundle
  level, and (b) replaces the one-level `messages_truncated` special case with ONE depth-bounded
  walk flagging `truncated` or any `*_truncated` — the old walk iterated `value.values` and required
  each to be a Map, so a flag inside a LIST of conversation maps was structurally invisible. Both
  lifts are mutation-proven. BUT the same change AMPLIFIES the raw-text defect: the warning's
  `message` is `value['error']`, so every site still returning `e.toString()` (10+ across
  `social_export_manager`, `activity_export_manager`, `preferences_export_manager`) now promotes
  that string from a buried section field to `export_metadata.warnings[].message` at the bundle
  root. **Review rule: a change that widens which sections get LIFTED must be paired with sanitising
  what gets lifted** — either a stable sentence per site (the shipped convention in
  `family_export_manager.dart`, `shared_shopping_list_export.dart`, and since 2026-07-30
  `social_export_manager.dart`/`activity_export_manager.dart`: `'error': '<Section> could not be
  exported.'` + a stable `error_code`) or a chokepoint that never copies `value['error']` verbatim.
  Adding `error_code` to a site while keeping `e.toString()` is half the fix and makes the exposure
  worse. **CLOSED AT THE ROOT 2026-07-30, and the chokepoint shape is the reusable answer:** the
  aggregator now DERIVES `message` (`'The "<section>" section could not be exported (error_code:
  …).'`) instead of copying the section's field — a chokepoint cannot tell an authored sentence from
  an exception string, so it must not gamble on one, and per-site sanitising then becomes
  defence-in-depth rather than the only control. Residual (Medium, pre-existing): 21 sites in
  `content_export_manager.dart` + `preferences_export_manager.dart` still put `e.toString()` in the
  section BODY, which the data subject downloads. The bundle-level walk/lift is also mutation-proven
  both ways — a fully-wired happy path asserts NO `warnings` key, which is what keeps the widened
  `error != null` lift from crying wolf.
- A roster/keep-set diff that DELETES user data must refuse to run when the keep-set is empty or
  implausibly small — an empty denormalized member list must not read as "everyone left"; guard
  `if (roster.size===0) return docs;` and prefer the authoritative membership list over a
  denormalized projection built for a different query.
- An EU single-region→multi-region move (e.g. Vertex `europe-west1`→`eu`) is NOT a Chapter V
  regression — only a move to `global`/outside-EEA is; treat that as Critical.
- Audit retention differentiates by category: consent events 24mo/730d (Art 7(1)); general 6mo/
  180d (Art 5(1)(c)) — the general purge must exclude fresh consent events, and every writer
  must set the discriminator field. **In Butlery the discriminator is the `operation` string
  itself** (`purgeExpiredAuditLogs` keeps `consent_*` for 730d, everything else 180d;
  `audit_log.dart` is the single source of truth), so a `logPermissionCheck` row spelled
  `create`/`update`/`delete` is NOT a consent record however consent-shaped the operation was —
  it is purged at 180 days. Two traps when a DPIA/doc-comment claims "the grant and withdrawal
  events are in the audit log": the `operation` spelling above, and the fact that
  `auditRepository` is an OPTIONAL constructor arg that several DI modules simply do not pass
  (`SocialModule` passes none), which makes every `logPermissionCheck` in those repositories
  console-only. Check the DI registration, not the repository, before crediting an audit trail.
  **Third trap, found 2026-08-12: the trail SPLITS on the resource string's first segment.**
  `logPermissionCheck` derives `resourceType` from `resource.split('/').first`, and
  `BaseFirebaseRepository` spells that `'${T.toString()}/$docId'` (the Dart type name) — so a
  subclass that hand-rolls a call as `'$collectionName/$id'` files its rows under a different
  `resourceType` than the create/read/delete rows for the same document, and a query
  reconstructing one document's history finds half of it. Copy the base class's spelling verbatim
  in any hand-rolled call.
  **Fourth trap (2026-08-13): the enumerated list is only as strong as the test that claims it is
  exhaustive, and the correct repair is REUSING a listed token, never minting a fifth.**
  `purge-audit-logs.test.ts`'s "exhaustiveness" test compares `CONSENT_OPERATIONS` against a
  HAND-MAINTAINED array of known values — it never reads the Dart writers — which is how
  `consent_deleted` (`deleteConsent`, written 2025-10-30) sat unlisted for 46 days (2026-06-28, when BUT-1404 replaced a prefix match with the enumeration, to 2026-08-13) in the
  180-day bucket while the test stayed green. Derive such a test from the writers
  (`grep "operation: 'consent_" lib/`) or it proves only that someone edited two lists together.
  Reuse also beats a new token on two mechanics: `not-in` caps at 10 values, and the operation
  STRING is the whole discriminator (there is no `retentionTier` field), so every spelling is a
  new silent-misclassification surface. Two checks when renaming an audit token: grep the token's
  CONSUMERS (here only the purge + its test read operation values, so no consumer conflates
  revoke-vs-delete) and `git log -S'<oldToken>'` / `-S'<method>('` — **rows outlive their caller**,
  and this one had a real one (`ProfileDeletionOperations.deleteConsentRecords`, BUT-498 2026-04-27 →
  BUT-788 2026-05-22, with `auditRepository` injected in `core_module.dart`), so "no production
  caller" is a statement about TODAY, never about the corpus. On the retention DIRECTION: 730 days
  for a withdrawal row is right and does not fight Art. 17 — `docs/security/audit-logs-retention.md`
  records the Art. 17(3)(b)/(e) position that audit rows are NOT erased at account close, the row
  is uid + operation + timestamp, and classifying the grant at 730 while the withdrawal expires at
  180 would leave a window where the controller can evidence the grant but not its end. What such
  a row must carry to be worth keeping is `consentVersion`: Butlery's delete path logs a bare
  timestamp, and since the consent DOC is deleted, nothing then records which wording was withdrawn.
- A blocked/admin-only collection's Art-15 export goes through an admin-SDK callable scoped to
  `request.auth.uid`, never a widened user-side read rule.
- **A UI gate that hides a CONSENT control must key on the absence of a live consent, not only on
  the precondition that made the control offerable** — Art. 7(3) demands withdrawal be as easy as
  granting, and a hidden switch is no withdrawal path at all. BUT-1693's sharing tile correctly
  hides when the household has fewer than two members (`ensureForUser` seeds a solo household for
  anyone who opened Min familj / family rating / who's-eating, so the row was telling people living
  alone that the household was guessing for them); it can only ever hide, since `_householdId` stays
  null and both write handlers bail on it. The residual to close before such a feature ships is the
  SHRINK: `deleteFamilyData` removes a departing uid from `memberUserIds` and keeps the household,
  so a 2→1 shrink strands a live share with the row hidden. Correct end state is
  `members < 2 && getOwn() == null` — check the count AFTER the share read; today the reverse order
  is the cost-right call (no `lib/` path grows a household past its creator, so every user is solo
  and the check saves a doc read). Corollary for a dark feature's gate list: a UI-level precondition
  that no production data satisfies is a FOURTH gate, and it belongs in the flag's checklist beside
  the flag, the missing rules block and the missing cascade/export steps.
- TTL fields need THREE things: the `gcloud ... --enable-ttl` policy itself (separate admin
  action, not deployed with code); a backfill for pre-existing docs; a deletion-cascade
  cross-check if the collection carries raw `userId` (or a documented accepted residual).
- A nullable field where null is meaningful must not reuse null as "not provided" on a
  merge-write — use a sentinel + omit-the-key branch, or a degraded read silently clears the
  stored value. Conversely, `update()`/merge on a repo whose `toFirestore()` OMITS a field when
  null means a consent-withdrawal write that nulls it silently FAILS to erase (merge never
  touches an absent key) — that write needs a full `set()` (no merge), after the same
  permission-check chain, and only where no peer-owned field would be clobbered by the replace.
- **A local-cache PARSER that returns `defaults()` for an unusable payload destroys the caller's
  only way to say "no cache".** The pattern the fix needs is fail-toward-NULL: Butlery's
  BUT-1782/BUT-1799 repair correctly stopped `getPreferences()` from seeding + PERSISTING defaults
  on a read error, but `NotificationPreferences.fromJson` maps a legacy `'{}'` (which the previous
  stub `toJson()` wrote for every user, so it is in everyone's `SharedPreferences` today) to
  `defaults()`, and `_loadPreferencesLocally` hands that back as a non-null cache hit. The fallback
  then serves and CACHES factory settings, and the settings view writes the whole object back on
  the next toggle — the server reset the ticket set out to prevent, one tap further away. Two
  checks on any "never invent state from a network blip" fix: follow the fallback's own loader to
  the parser and require an unusable payload to be indistinguishable from an absent one (null,
  not a populated default), and grep for the LEGACY on-disk shape the previous version wrote.
- **RELOCATING a field out of a document into a subcollection silently drops it from every
  DERIVED surface, and the erasure ticket is the one that gets written.** BUT-1832 moved poll
  votes from `messages/{id}.metadata.poll.options[].voterIds` into
  `messages/{id}/poll_votes/{voterUid}` and shipped a rules block, a `COLLECTION_GROUP`
  fieldOverride and an Art. 17 sweep (BUT-1835) — but the Art. 15 export reads raw message
  documents, so the requester's own votes left the bundle, and the section's own
  `data_minimisation` prose still named poll `voterIds` as kept. Rule: when a write path moves
  data, enumerate FOUR consumers and say what each one now reads — display/read path, Art. 15
  export, Art. 17 cascade + `probeResidualData`, and the rules validator — never just the two the
  ticket names. Two traps in the export half specifically: a client-side export CANNOT reach the
  new rows by `collectionGroup` unless a collection-group `match` exists (Butlery deliberately
  omitted one, so the export must hydrate per parent document, which the participant read rule
  allows); and a bundle that describes its own contents in prose becomes FALSE the moment the
  storage shape moves under it, which is the same "a comment is an untested assertion" failure
  with legal weight. BUT-1832/BUT-1835, 2026-08-16
- **A per-item live fan-out placed under `switchMap` re-subscribes the WHOLE fan on every
  upstream emission.** `MessageQueryModule` opens one `poll_votes` listener per visible poll and
  rebuilds all of them each time any message document changes (a send, the `status:sent` flip
  100 ms later, every read receipt) — each rebuild re-reads every visible poll's subcollection,
  billed. `CombineLatestStream.list` also withholds the FIRST emission until every inner stream
  has answered, so the message list itself is gated on the overlay's reads. Key inner listeners
  by id and reuse them across emissions, and give the overlay a `startWith` so the payload
  renders without it. Same review question for any "hydrate a list from N subcollections" design:
  which stream operator owns the subscription lifetime, and does the cap select the items the
  user is actually looking at (a `.take(N)` after a `.reversed` picks the OLDEST N). 2026-08-16

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
- **`AppLogger.error(msg, e)` is not device-local, and only the MESSAGE is redacted.** It forwards
  the raw `e` object to `FirebaseCrashlytics.recordError` and to the analytics callback as
  `error.toString()`; `_sanitizeForCrashlytics` (the 20–28-char alnum uid masker) is applied to the
  message string only. Consent-gated (`setCrashlyticsCollectionEnabled(hasConsent && !kDebugMode)`,
  `main.dart`), so it is acceptable for bounded Firestore error text — but never justify logging an
  exception on "it stays on the device", and think before logging an error whose text embeds a
  query the app built from a uid (a `memberPermissions.<uid>` FAILED_PRECONDITION index URL is the
  realistic shape).
- **A log line's PII profile changes when its function gains a CALLER, with no edit to the
  logging code.** `tryClearRoster` logged a bare `conversationId` safely for months because its
  only caller was a group-only trigger (UUIDv4 ids); BUT-1822 gave it a second caller, the
  account-deletion cascade's ≤2-participant branch, whose ids are `direct_<uidA>_<uidB>` — two
  raw uids, one of them the subject being erased, in a sink that outlives the account. So on any
  diff that adds a caller to an existing helper, re-derive what each logged ARGUMENT can now
  contain, not whether the helper changed. Same question for a STRUCTURED identifier anywhere:
  a composite doc id (`direct_{uid}_{uid}`, `${uid}_${op}`, `{uid}_{date}`) is personal data
  wherever it lands. Shipped shape (2026-08-13): a `logSafeConversationId` chokepoint hashing
  only the composite form through the repo's existing `hashUid` (12 hex, sync) so operators keep
  a correlatable handle, applied at EVERY call site in one pass.
  **The CLIENT half is unshipped, and the message redactor structurally cannot cover it
  (2026-08-14).** `_sanitizeForCrashlytics` is `RegExp(r'\b[a-zA-Z0-9]{20,28}\b')`; Dart follows
  ECMAScript, where `_` is a word character, so there is NO `\b` between `direct_` and the uid that
  follows it — a bare uid in a log line is masked, and the one id shape carrying TWO uids passes
  through whole. Verified by running the regex, not by reading it. So `AppLogger.error('Failed to
  get conversation $conversationId')` (several such lines across the messaging modules) ships both
  uids to Crashlytics. Two rules: never credit a redactor for a COMPOSITE identifier without
  running it on that exact shape, and remember an anchor-class bug in a redactor fails toward
  disclosure silently — the sanitized-looking output is the tell only if you look at it. The fix is
  a lookaround pair in `logger.dart`, not per-call-site masking (BUT-1838 gate pass filed it; the
  log lines themselves are pre-existing on main).
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
  `activitySummary` treats empty as unknown. **Second writer CLOSED 2026-07-28 (BUT-1705)** via
  `UserService.profileDisplayName` — profile name or null, NO Auth fallback, the shape to reach for
  whenever a name is PERSISTED as attribution. Its two lessons: a `?? '<placeholder>'` at a PERSIST
  site is the same defect as the Auth fallback (stamp EMPTY, teach the read side), and when you do,
  sweep the render sites — a `?? unknownUser` there only catches an ABSENT key and renders a blank
  line for the empty string.
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
  error and every "caller forgot to clear" path. **Last mile CLOSED (verified in code 2026-07-30):**
  `_beginMutation()` now nulls the field at the START of every mutation entry point, which is the
  only shape that also covers an early-return `false` someone adds later — a per-branch message set
  never could.
  **The same slot pattern one layer up (VM/manager) gets it wrong in a way worth naming
  (2026-07-30, BUT-1722).** `ShoppingItemOperationsManager` captures the service's sentence but
  (a) never clears `_error` at the start of an op, and (b) returns `false` from
  `if (!canEdit)` / `item == null` WITHOUT setting one — so the new
  `consumeItemOperationError()` reader shows nothing for exactly the case its doc comment names
  (a view-only member). Two review rules: a read-once consume slot is only as good as the set
  side, so walk EVERY `return false` in the method and require a message on each; and check that
  the CONTROL's enabled-ness matches the guard the mutation uses — the checkbox is gated on
  `canView` while the mutation is gated on `canEdit`, which is what manufactures a tappable
  control that can only ever fail. "Self-clearing on read cannot strand a stale reason" is false
  when the read is behind `if (!mounted) return;`; only a clear-at-entry makes that claim true.
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
- **`.where(f, isNotEqualTo: null)` / `isEqualTo: null` builds NO CONDITION** — the
  cloud_firestore builder adds each operator only `if (arg != null)` (`query.dart:659`), so a
  literal null compiles, reads as a filter, and leaves an UNFILTERED sweep of the collection.
  `isNull: false` / `isNull: true` are the spellings that build it (`query.dart:676-682`). On a
  member-scoped collection the symptom is NOT an over-share but "my data will not load": rules are
  not filters, so the server refuses the whole unscoped query (emulator-proven, SSL37/SSL38 —
  and a `!=`-on-`memberPermissions.<uid>` filter IS accepted for a rule gated on `uid in
  resource.data.memberPermissions`). Four sites shipped (BUT-1719/1732: shared-list read + stream,
  group-weekly participation probe, GDPR export gateway) before `tools/check_null_filter.sh` made
  it a lefthook grep guard — staged-file scoped, comment lines skipped (the fixed sites document
  the banned spelling), and like `check_swedish_boundary.sh` it is NOT in any CI workflow, so its
  documented whole-repo mode has no caller. `fake_cloud_firestore` THROWS `Unsupported` on the bad
  spelling, so a Dart unit test proves the filter shape and nothing about the rule (BUT-1746).
- A per-doc visibility rule needs a SPLIT query (owner unfiltered, friend branch STRICT
  equality, no "field absent" allowance) — looseness re-opens the leak. Backfill the default
  BEFORE the strict rule ships.
- Judge "is swallowing this read safe" by whether a downstream SAFETY verdict defaults
  permissive on missing input — restrictive-default (Butlery's allergen coverage gate) makes
  swallowing fail-safe; permissive-default would make it Critical.
- A parser/lookup that can turn 1 input into N reads needs a cap at the split site — same
  "bound the worst case" rule as `.snapshots()` limits.
- **A write-coalescing guard ("stamp at most once per day") keyed off a MODEL field is inert for
  every doc whose parser DEFAULTS that field to now.** Butlery's `safeRequiredDateTime(data,
  'updatedAt')` falls back to `clock.now()` (no sentinel, unlike `createdAt`'s
  `unknownCreatedAt` — BUT-1755), so a parent doc missing `updatedAt` reads as "touched today"
  and `_touchPersonalListDay` skips it forever, silently, on the exact docs the fix targets.
  Whenever a guard compares a stored timestamp to `now`, open the parser and ask what ABSENT
  parses to; a coalescing guard must fail toward one extra write, never toward never writing.
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
  object. Require an enforcement assertion, not a comment: **CLOSED 2026-07-30 (BUT-1706)** by
  `ShoppingOfflineWriteModule.requireOfflineWritableMutation` — a `toFirestore()` diff that THROWS
  on any differing key outside `items` + the activity whitelist
  (`updatedAt`/`lastActivityAt`/`lastActivityBy{UserId,DisplayName}`, exactly complementing the
  rule's forbidden `ownerId`/`memberPermissions`/`createdAt`). Three demands when copying it. (a)
  REFUSE, not fall-back-to-full-write: the full write is what re-sends a stale ACL, so
  `privilegedKeys` sit deliberately OUTSIDE the refusal (dropping those is the design) — say which
  of the two you checked. (b) It belongs on the OFFLINE leg only; the online transaction merge-sets
  the whole document and drops nothing. (c) It is unreachable by today's mutators (one shared
  stamping helper touches items + activity only), so verify the caller trace, not the guard body.
  **Mutation-test such a guard by running the WHOLE test file, never a `--plain-name`-scoped run**:
  scoping the new refusal test alone reported GREEN with the guard commented out, while the same
  test inside the full file reddened correctly — a single-test scoped run can silently lie about a
  Dart async-throw assertion.
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
  **One level up, it invalidates the INTERFACE's contract (2026-08-12, BUT-1693):** a method that
  branches on a bool derived from such a read (`if (!await isMember(hid, uid)) return [];`) has a
  fake-only branch — in production the non-member's underlying `get()` is DENIED and throws, so the
  empty-return path is dead and so is any "unavailable" branch below it that keys on
  `exists == false`. A doc comment promising "returns empty when the caller is not a member" then
  misleads the consumer that has to handle the throw. State the throw in the interface, or map the
  denial to one typed unavailability signal the caller can catch; either way say which branch the
  fake proves and which needs the emulator lane.
- Prefer real-repository + fake-Firestore + auth-state-fake tests over side-effect stubs that
  mock away the boundary under test.
- **Widening a bundle/aggregate "this failed" lift exposes FIXTURE defects, and the fix is the
  fixture, not the contract.** `MockUser` stubs `uid`/`email`/`displayName` only and mocktail throws
  on any other non-nullable getter, so `currentUser?.metadata.creationTime` had been failing the
  `profile` section of EVERY export test — invisible while the lift keyed on `error_code` alone
  (2026-07-30). Same round: two suites had to stop asserting `warnings` has LENGTH 1 and filter by
  `section` instead, because a partially-wired fixture legitimately fails a dozen sections. When a
  new guard THROWS from a repository, also name where the throw LANDS: a bare `ArgumentError` from
  `requireOfflineWritableMutation` is absorbed by `UnifiedShoppingService.mutateSharedList`'s generic
  `catch` → `false` + a mutation-error message, not a crash — check that before shipping the guard.
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
