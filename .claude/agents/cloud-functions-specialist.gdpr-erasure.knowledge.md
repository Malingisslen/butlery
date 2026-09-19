# cloud-functions-specialist — chapter: gdpr-erasure

### PII scrubbing + GDPR cascade design
- **A server write leaving a doc unable to satisfy its own UPDATE limb BRICKS a
  DETERMINISTIC doc id** (`{groupId}_{ISO week}`). Two forms: emptying
  `memberPermissions` (a client `set()` is an UPDATE and every limb gates on
  that map), and — since the Admin SDK bypasses rules — `arrayUnion`ing past a
  rules cap (`contributorUserIds` 200), which freezes the doc
  for every client. Delete the doc, or prune/skip at the cap; before revoking
  the last holder, name what re-creates the id.
- `runStep` CATCHES a throw → `failedCollections` + `gdprCompliant:false`, no
  auto-retry. A step that DECIDES something read later (a hold, a `retained`
  record) RETURNS false with the decision intact, never throws — a throw skips
  the caller's assignment. A `retained` record derived from rows the step itself
  anonymizes vanishes on a user's RE-RUN (its query handle was nulled) — persist
  it uid-keyed (`erasure_holds`) or the retry's Art. 12(4) notice omits it.
- **`batch.update()` on a concurrently-deleted doc fails the WHOLE chunk with
  NOT_FOUND** under `strict:false`; and `commitInChunks` calls `mutate` OUTSIDE
  that try, so a SYNCHRONOUS validation throw from the callback (`undefined` in
  an array, bad FieldValue) escapes `strict:false` and aborts the step —
  piggyback the existence probe on the SAME `getAll` as the idempotency gate;
  skip (never `set(merge)`) when absent. `strict` DEFAULTS to false. A step that
  DELETES and UPDATES one collection: await the deletes, then RE-QUERY — the
  re-query is what removes the NOT_FOUND, so a doc-id dedupe across the two
  halves is dead defence, and rule 10's fake shows neither.
- A step that early-`return false`s on its own cap skips every leg below it —
  put independent legs first.
- **A scenario that calls two steps in sequence pins that they COMPOSE, never
  the orchestrator's ORDER** — moving the runStep into (or above) a parallel
  tier stays green. Pin order in `request-account-deletion.test.ts` via
  `state.queries` indices (a tier step's `where` after an `await` records
  AFTER a sibling's synchronous one). A `batchFailures` fixture for "a failed
  chunk fails the step" uses 13/14, not 5: grpc 5 is the "already gone" code.
- **Cross-check the identity FIELD and COLLECTION NAME across every leg**
  (deleter, export, probe, rules, Dart constant) — a wrong or pre-rename name
  deletes NOTHING silently, and the VALUE searched for must match what the
  PRODUCER writes. A DEAD SPELLING has no writer, so no source scan and no TTL
  reach it (a policy keys an EXACT id) — sweep BOTH names, only a prod dry run
  finds one, and the legacy inherits the live Art. 15 exemption by CITATION.
  One field can have TWO stores — erase BOTH. A NEW uid
  ARRAY on an already-swept doc owes no cascade leg ONLY while every writer
  keeps it a strict SUBSET of the swept field (`categorySeatedUserIds` ⊆
  `memberIds`) — prove it per writer, else add deleter AND probe.
- **A parent deleted by plain `doc(id).delete()` leaves subcollection orphans
  no PARENT-KEYED read can reach** — `listDocuments()` is the only Admin-SDK call
  returning refs for MISSING docs with live children (a `count()` reports ZERO);
  use it on sweep AND probe, and `strict:true` for a doomed parent's children.
  The CHILDREN stay reachable: a `collectionGroup` query on the row's OWN field,
  path-scoped via `ref.parent.parent`, returns them whatever happened to the
  parent — so "orphaned = unerasable forever" is FALSE for such a leg, however
  true it is for every CLIENT. Never write it without naming which reader.
  So a step destroys its parent/shared HANDLE LAST, after every child commit —
  including a QUERY HANDLE cleared in the same write as the scrub, ahead of a
  dependent mirror.
- **A server-written PROJECTION of a client collection (`block_mirror` of
  `blocks`) owes**: an existence check on the SUBJECT the constrained user cannot
  forge — `users/{uid}` is owner-DELETABLE, so ask `admin.auth().getUser`, OUTSIDE
  the transaction (Auth is not transactional), answering `auth/user-not-found` and
  `auth/invalid-uid` as "gone", rethrowing every other code; a DELETE of an
  orphan (a late rebuild re-creates the erased uid's doc post-probe; Auth
  deletion is the cascade's LAST step); a cross-user sweep that STAMPS the
  revision guard (`arrayRemove` leaves it untouched, so an older in-flight
  rebuild wins); a run AFTER the source tier; and a CAP flag unread by the
  consuming gate under-enforces on input OTHERS choose (`.limit(cap+1)` with no
  `orderBy` keeps the lowest doc ids, so sockpuppets sort a real entry off the
  end). Trigger + reconcile NARROWS the window, never closes it;
  a task LAST in `WEEKLY_REPORT_TASKS` is what `runTaskChain` SKIPS first, and a
  TIMEOUT aborts the chain at ANY index — so a safety sweep needs its own
  wall-clock budget, not just a row cap.
- **A compare-before-repair reconciliation resolves EXISTENCE once per uid ABOVE
  every branch, and counts a DELETE as drift on every branch.** `stored == expected`
  never settles orphanhood (an EMPTY orphan matches an empty expectation), and the
  existence seam must not be reached THROUGH the repair call.
- A "shared" collection also holds SOLO-owner docs to DELETE, not scrub. A scrub
  enumerates every uid in the MODEL's `toFirestore`: array elements, per-uid map
  keys, AND attribution scalars (`lastModifiedBy`, `lastEditedBy`).
  **DISCOVER those rows by collectionGroup query PER UID FIELD, never by current
  MEMBERSHIP** — `removeMember` drops `members/{uid}` AND `arrayRemove`s the
  roster in one call, so a departed member is invisible to both handles while the
  name stays. Check `firestore.indexes.json` first: the COLLECTION_GROUP
  overrides may already exist for a rename propagator. PATH-scope each row
  (`parent.id === X && parent.parent === null`, BOTH limbs) where a sibling path
  shares the group id, and scope BEFORE counting against a cap.
- A rules hard-deny plus an Admin-SDK escape hatch has TWO guards: the callable
  exempts only the first; the model's `toFirestore` coercion is the second.
  Enumerate the SERIALIZER's call sites, not just the rules' writes.
- **Any write derived from an EARLIER read is a lost update** — a query-time
  snapshot via plain `.update()`, or a serial `ref.update()` loop over an embedded
  array, where NOT_FOUND also aborts the remaining iterations. Per-doc
  `runTransaction` + re-read fixes only the lost update: skip on `!fresh.exists`,
  try/catch each, throw once, filter failed ids out of any UNCONDITIONAL write the
  abort protected. Fan-out helpers take a `CollectionReference`, never a NAME.

### GDPR account-deletion cascade
- **A probe leg whose ONLY deleter lives in `onUserDeleted` is broader by TIMING.**
  `probeResidualData` runs BEFORE `auth.deleteUser` (the cascade's last step) and
  `success = authDeleted && !failedCollections.length`, so such a leg returns
  `success:false` + `gdprCompliant:false` on every affected account while the row
  IS erased seconds later. `TRIGGER_OWNED_SUBCOLLECTIONS` is that exclusion;
  `social_requests` is deliberately unprobed. Probe only what a CASCADE step
  erases — cross-user is no reason to leave the deleter in the trigger
  (`deleteBlocks` erases rows other users authored, from tier 1).
- **`probeResidualData` must not be BROADER than the deleter, and the deleter
  must not be NARROWER than the EXPORT's predicate** — Art. 15 must never reach
  a document Art. 17 cannot (`memberPermissions.<uid> != null` = Dart
  `isNull:false`). Union the probe's queries into the deleter's scoping, dedup
  by `doc.ref.path`. A LAWFUL-HOLD exception narrows the deleter on purpose:
  every field it then KEEPS must be spread out of the probe by the SAME flag —
  one decision in two lists, keyed on the retained record's `resourceType`, never
  on `retained.length` — or each held erasure reports `gdprCompliant:false`
  forever with no path able to clear it. A leg on an
  ATTRIBUTION SCALAR (`lastModifiedBy`, `ownerId`) is broader unless
  `firestore.rules` PINS that field to the roster the deleter discovers by —
  read the write limb, never the app's own writer; unpinned, any editor plants
  a stranger's uid and that user's deletions report `gdprCompliant:false`
  forever.
  GATE any empty-roster DELETE on the uid having been ON that roster AND on EVERY
  denormalised roster being empty, EACH READ RAW (a DERIVED witness or `.select()`
  projection collapses it); witnesses are ROSTERS (readers) only, never a discovery
  handle (`contributorUserIds`). Binds EVERY server writer that can empty a roster;
  its NON-delete branch rewrites projections PER KEY and drops the whole-field key.
  A leg with no DIRTY fixture is mutation-invisible and `strict:false` swallows
  a failed chunk, so the probe is the ONLY contradiction to `return true` — leg
  and scenario ship in one edit, and DELETING the leg must redden BOTH the
  targeted fixture and "no failed collections". A probe ERROR ADDS to residual (a sentinel,
  never a count), never aborts; one try/catch per leg.
- **An ENUMERATING probe (`rootRef.listCollections()`) is BROADER than the
  deleter by construction** — any user subcollection no step erases reports
  `gdprCompliant:false` forever.
  Ship it only with a DERIVED drift test: regex every
  `.collection(users).doc(..).collection("X")` writer across `functions/src` +
  `lib`, spelling the users token `\w*[Uu]sers\w*` (`[A-Za-z_]\w*` misses the bare
  `FirestoreCollections.users` every Dart repo writes);
  `db.doc("users/${uid}/X/y")` strings are still missed. Bucket each name into the
  EXPORTED `USER_SUBCOLLECTIONS` or `TRIGGER_OWNED_SUBCOLLECTIONS` — IMPORT them,
  never parse the cascade as text — or into a map whose every entry is EXERCISED
  (seed, run the named deleter, assert gone). A deleter removing ONE DOC BY ID is NOT a deleter for the
  COLLECTION the probe counts. Every fake doc-ref then needs `listCollections()`
  derived from stored deeper paths, never `[]` — absent, the outer catch fails
  CLOSED and every CLEAN fixture reddens.
- **EXPORT ⊇ DELETION is the cascade's other drift guard**: every source-parsed
  `subs` name is either read by an export chain or in a reasoned exemption map
  kept in PRODUCTION source, not the test. That map is PERMANENT — re-check each "no live writer"
  exemption against the writer scan; one reasoned from another export SECTION dies
  with it, so re-argue it in the removing commit and supersede every
  decision-record sentence it falsifies. Name each withheld collection in a
  `data_minimisation` line, verifying WHICH line, or the gap is undisclosed
  (Art. 12(1)).
- **A SCHEDULED JOB writing uid-keyed rows under a non-`users/{uid}` path is
  invisible to both of the cascade's structural loops** (e.g.
  `analytics/notifications/effectiveness`) — give each its own probe leg; a
  colliding subcollection name arms a `fieldOverrides` TTL (COLLECTION-GROUP
  scoped) over the wrong docs. Such a job can flush IN-MEMORY pages back AFTER
  the sweep, so pin the leg with a RESURRECTION scenario, never by mirroring
  the deleter.

### Pooled ratings + rating aggregation (ratings/ family)
- Unbounded collection-group folds use `.aggregate({count, average})`, never
  `.get()`; ANY filtered `collectionGroup` query — equality or
  `array-contains` — needs a `fieldOverrides` entry with
  `queryScope:"COLLECTION_GROUP"` in `firestore.indexes.json`, staged in the
  SAME commit (precedent: `participants/participantId`) — missing, a cascade leg
  throws FAILED_PRECONDITION on every real erasure while the fake stays green.
  COLLECTION-scoped equality needs none unless `fieldOverrides` EXEMPTS the
  field — check exemptions, not `indexes`.

### Verify-signup-age, account callables & minor-safety triggers
- **A cleanup helper writing an ATTRIBUTION row takes the ACTOR as an argument,
  and a no-tombstone rule binds every CONSTANT it writes.** Deriving the actor
  from the SUBJECT misnames an eviction; a SENTINEL marks that eviction as well
  as a tombstone would, correlated with the uid removed in the same write. For a
  TRIGGER caller the answer is a NULLABLE actor and NO row, never a nicer
  sentinel — a non-uid also sticks permanently in any append-only uid array the
  client derives from that row. Pin the CALL SITE: testing the shared function
  leaves deleting the call green.
- **A callable that READS a doc before checking caller membership is an ORACLE,
  and its idempotent no-op branch is the leak** — collapse `!exists` +
  non-member into ONE uniform response.
- **A client-chosen document id is not unique across accounts.** A
  server-side pointer to one (`friend_categories/{uuid}`) must be keyed on
  OWNER + id, or an ex-member re-creating that id under their own uid is
  handed the victim's object. Do not then exempt that owner from the
  membership check — an owner who left could otherwise empty its roster.
- A roster/keep-set diff that DELETES user data must refuse to run when the keep-set is empty or
  implausibly small — an empty denormalized member list must not read as "everyone left"; guard
  `if (roster.size===0) return docs;` and prefer the authoritative membership list over a
  denormalized projection built for a different query.
