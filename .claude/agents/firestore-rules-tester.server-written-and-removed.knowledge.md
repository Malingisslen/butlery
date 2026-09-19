# firestore-rules-tester — chapter: server-written-and-removed

- **A collection with NO write limb still owes a CREATE-limb deny of its own.** The three
  verbs sent at a SEEDED document are an update and a delete — `set()` on an existing doc is
  an update — so the plausible future grant, `allow create: if isOwner(userId)` ("let the
  client initialise its own record"), is pinned by nothing. Measured on `user_moderation`
  (BUT-2046): the create mutant passes 18/18 against the suite without a delete-then-`set()`
  case and kills that one test alone with it. Exploitable, not theoretical — the CF read
  `totalReports ?? 0` then `increment(1)`, so a client-created record holding a large
  negative count never reaches the alert threshold, and it satisfies the read gate's key set
  so nothing else notices. Delete the document inside the write test, then `set()`.
- **A REMOVED match block** (the path falls through to the terminal `match /{document=**}`):
  the coverage universe is the verbs the DELETED block granted, not the verbs a reviewer
  finds natural. Pin one deny PER GRANTED VERB, sent by the actor the old block would have
  ADMITTED (owner/seated member), plus a fail-closed control on the PARENT document —
  without it a wrong path, an unseated fixture or a ruleset that failed to load passes every
  deny for free. Measured on `shared_content/{id}/items` (BUT-1716): a read/create/delete
  triple survives the likeliest partial restoration, an `allow update` limb alone, because no
  case sends an update. Attribute each deny by the trace's LINE — every verb must name the
  catch-all's line, and a deny at any other line means an outer or collection-group rule still
  reaches the path. Check `collectionGroup(<name>)` too: a `{path=**}/<name>` rule elsewhere
  would keep the rows reachable after the specific block is gone.
- **A write deny prints its trace in the emulator's `GrpcConnection` log; a READ deny does
  NOT** — the `false for 'get' @ L<n>` string is only on the thrown error, which `assertFails`
  swallows, so a suite run can attribute the writes and say nothing about the reads. Capture
  it with a throwaway probe that catches and prints `err.message`, and do not filter the
  output on `^false for` — the trace sits on the line AFTER the message's leading `\n`.
- **Deny-all server-only collection** (`allow read, write: if false`): matrix
  {read,create,update,delete} × {unauth, non-admin, admin} — admin-still-denied is the
  load-bearing case — plus one Admin-SDK-bypass write that succeeds.
- **Owner-read / server-write collection** (`allow read: if uid == userId; allow write: if
  false`, the shape a new Art. 15 export section needs): the load-bearing allow is the
  PRODUCTION READ SHAPE, which for an export is an ordered LIST query
  (`.orderBy(f,'desc').limit(n)`), not a `get()` — rules are not filters, so a single-doc
  proof says nothing about the query the app issues. Read the repository method and copy its
  ordering and limit. Non-vacuity has two distinct sources here: the read denies pair with
  the SAME query run by the same stranger against their OWN path (one variable: the
  ownership match), and the write denies pair with the identical payload+doc-id succeeding
  under `withSecurityRulesDisabled` — `if false` has no conjunct to delete, so its only
  discriminating mutant is OPENING the rule to the owner, which must redden the owner-write
  denies and leave the stranger/unauth ones green (measured on
  `users/{uid}/notifications`, BUT-1957: the read mutant kills exactly the two stranger-read
  denies, the write mutant exactly the three owner-write denies, and neither touches the
  other's cluster). A specific-path block also authorizes NO collection-group query — the
  OWNER is refused one over their own rows — so pin that too where an export could plausibly
  be refactored to `collectionGroup(<name>)`. Before calling `allow write: if false` safe, grep `lib/` for
  the collection CONSTANT — an existing client writer would make it an outage, not a
  hardening.
  **A grant reads STORED documents; "the document holds only X" is a claim about the WRITER
  and is refuted by any un-run MIGRATION.** Rules cannot scope a read by field, so a legacy
  field a hand-run script has not yet cleared ships to whoever the new limb admits — measured
  on `user_moderation` (BUT-2046): the parent still carried the pre-migration `reportHistory`
  array of maps, each naming a REPORTER, so the new owner-read handed the reported person the
  uids of the people who reported them, i.e. the exact disclosure the design withholds. Before
  passing such a sentence, `git log -S` the field to date when the writer stopped writing it
  and look for the migration's LIVE-run evidence (a hand-run script defaults to a dry run, and
  a script existing is not a run — BUT-2010/BUT-2040). The suite cannot see it either: every
  fixture is built from the CURRENT writer's key set, so seed the LEGACY shape as its own case
  and pin what it does today. "A rules tightening never cleans stored documents" met from the
  loosening side, and this is the more dangerous direction.
- **Owner-scoped subcollection under a `{path=**}/<name>/{id}` collection-group
  catch-all**: a single-doc deny test is not proof — the engine can't show every matched
  doc satisfies an owner predicate for an unconstrained collection-group query, so the
  load-bearing test is a non-owner `collectionGroup(name).get()` denial.
- **A header disclaiming "the missing `hasOnly`/rate limit is NOT asserted here as
  contract" is a claim about the ALLOW FIXTURES' key set, and only a mutant settles it.**
  Every required key the builder must send is a key a future hardening can forbid: on
  `ingredient_suggestions`, `status` is in `hasRequiredFields`, so `validBody` carries it
  and a `!('status' in request.resource.data)` mutant reddens both create-allows (measured,
  BUT-2028) while a `hasOnly` over the same five keys reddens nothing. Probe the disclaimed
  hardening itself before passing the sentence, and scope it to the fields no fixture sends.
- A collection-group read rule UNIONS with the specific match it overlays, all-or-nothing
  per doc — an admin-only collection-group grant also grants a direct `get()` on any
  single scoped doc; there is no way to express "query but not direct-get" in this shape.

