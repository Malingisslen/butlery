# firebase-backend-security — chapter: gdpr-erasure

- A denormalized ERASURE HANDLE (flat `array-contains` trail, needed because Firestore
  can't filter inside an array of maps) must be extended by EVERY write path (derive the
  obligation from the payload so a new path inherits it by construction), removed in the
  SAME write as the scrub and added to the residual probe, and constrained APPEND-ONLY in
  rules (`hasAll(resource.data.F)` + size bound) or any editing member can strip another
  user's uid. It is also a NEW THIRD-PARTY DISCLOSURE the day it ships: an Art. 15 section
  that exports the document whole now ships an array of uids including people who have
  LEFT, which no screen renders — so it needs its own recorded decision (keep or strip) and
  its own `data_minimisation` clause, and a same-named field decided on a DIFFERENT
  collection is not authority for it.
- A capped sweep that DECLINES above its bound usually names a RECOVERY in its docstring
  ("a human runs `admin/reset-user-data.ts`"), and that is a checkable claim about a
  hand-typed list in another file, not a policy sentence — open the list and confirm it names
  the collection, because such a sentence is normally copied from the sibling cap where it
  happens to hold. Close it by adding the collection AND binding it with an assertion keyed on
  the shared CONSTANT (`Collections.x`), never on the literal; prose is what let the claim be
  inherited in the first place. Membership is NECESSARY, never SUFFICIENT — also check the
  script RUNS (this one `process.exit(1)`'d on a delete/keep overlap from 2026-03-19
  until BUT-2010 repaired it 2026-09-05; a temporary BUT-2028 refusal on top of that
  was lifted 2026-09-06, and the live-run barrier is now the typed
  `CONFIRMATION_PHRASE`) and that it is per-USER at all; a clean-slate script that deletes every auth user
  is no remedy for one erasure. A residual whose named recovery cannot run stays ACCEPTABLE
  while the decline is loud (`failedCollections` -> `gdprCompliant:false` + an uncapped probe)
  and the surviving rows disclose nothing to anyone who could not already read them — file the
  ticket, do not redesign the frozen decline. Then grep the SIBLING caps: the stale recovery
  sentence is the neighbour you did not stage.
- Deleting a parent doc does NOT delete its subcollections — child sweep (STRICT) before
  parent delete (best-effort), covering every legacy name variant. TTL fields need three
  things: the `gcloud --enable-ttl` policy (separate admin action), a backfill for
  pre-existing docs, and a deletion-cascade cross-check if the collection carries a raw
  `userId`. A RENAMED collection is the sharpest legacy-variant case and no source scan can
  find it (a dead spelling has no writer, so writer-scanning guards are blind by
  construction — only a dry run against real data finds it): the old spelling keeps rows an
  ENUMERATING probe counts and a list-driven deleter cannot clear, i.e. a permanent
  unclearable `gdprCompliant:false`, and the TTL does not rescue it because a TTL policy is
  keyed to an EXACT collection id. Such a name can legitimately
  inherit another entry's Art. 15 export decision rather than getting a new one — but
  prove "same data, two names" on the commit that changes the CONSTANT's value — which is
  usually not the commit touching the writer — never by name similarity, and keep the inherited entry to the citation: re-describing the
  content in your own words re-asserts a characterisation the ADR made about the LIVE rows
  (`rate_limits` "one timestamp per gated action" does not describe the same collection's
  `imports` doc, which holds counters and LLM cost totals). The tool that CAN find the next
  one is a dry run reporting what the database holds that no list decides — grade it by what
  it SILENCES: suppressing a subcollection name because a top-level collection shares it
  re-creates the exact name-collision the export exemptions warn about (`fcm_tokens`,
  `user_shared_menus` — same word, different data), so the suppression must be stated as a
  blind spot in the report's own scope line, never asserted as "accounted for". And when a
  residual is argued from ANY hand-run script — the reset, or a one-time MIGRATION — the
  premise is a LIVE run: a dry run deletes and moves nothing, so "cleared on the next run",
  or an export exemption reasoning "the row IS moved, so the bundle carries it", is false
  until a person runs it, and nothing in the repo records that they did. Grade the two
  halves by WHEN each takes effect: adding the dead spelling to the cascade's `subs` makes
  the DELETER live on the next erasure while exportability waits on that run, so the
  exemption must not claim the subject already receives it. Put the pending run in the ops
  runbook, not only in the script's own header. Silencing such a report by adding a name to
  a list is a BEHAVIOUR question first: open the consumer and check whether that list only
  documents or also DRIVES the sweep (`CollectionTarget.subcollections` is a reader's aid;
  `.name` is what the walk iterates), because the same edit that quiets a report can widen a
  destructive run — and the sentence JUSTIFYING the old contents sits ABOVE the literal, so
  it ships in the diff as unchanged CONTEXT, where the author's edit and the reviewer's eye
  both stop ("`daily` is deliberately ABSENT" survived the commit adding `daily`): read the
  context lines above every changed list literal, and grade a register's SECTION HEADERS as
  universals over the entries beneath them (a `COLLECTIONS_DELIBERATELY_UNTOUCHED` key filed
  under "anti-abuse state a reset must NOT clear" ships a false reason with no line of its
  own text wrong; consumers there read KEYS only, so MOVE it rather than reword the header).
  MIGRATING rows from a dead spelling to the live one changes THREE reachabilities, not the
  one the ticket is about: export, erasure, AND CLIENT READ — the live name usually carries a
  `firestore.rules` block the dead one lacks, often a collection-group read granting the
  document's own member array, so the move re-grants third parties a read and re-activates a
  dormant feature. Argue all three, never only the Art. 15 half; and grade the copy-forward's
  CONFLICT branch (live doc already exists) as destructive — deleting the legacy row there
  discards divergent content with no dump, on a branch the measurement that authorised the
  run usually proves unreachable and therefore never exercises.
  When a founder's answer turns out to rest on a mechanism that is false,
  supersede the MECHANISM in place and leave the DECISION standing — quote the withdrawn
  sentence verbatim so a grep finds both, and say the answer was re-put to her.
- Replacing a guard's SOURCE-TEXT parse with a real import of the production constant is the
  right fix (a `/"([A-Za-z_]+)"/` scan is blind to a digit-carrying name and reads a quoted
  name inside a block comment as an entry) — but it owes three things: strike the guard's
  docstring clause saying the value is "parsed out of" the module, since that commit
  falsifies it; re-check that the removed parser self-checks were not the only pin on the
  list being NON-EMPTY (an emptied list makes an "every entry is exported or exempt" loop
  pass vacuously); and freeze what you export, because a mutable array/`Set` reachable by any
  importer now decides what a live erasure deletes and what the residual probe skips.
- A nullable field where null is meaningful must not reuse null as "not provided" on a
  merge-write (sentinel + omit branch instead); a `toFirestore()` that OMITS a null field
  makes a consent-withdrawal merge silently fail to erase it — needs a full `set()`. A
  local-cache PARSER returning `defaults()` for an unusable payload destroys the caller's
  only way to say "no cache" — fail toward NULL, never a populated default that gets
  written back; grep for the LEGACY on-disk shape an older app version wrote.
- A UI gate hiding a CONSENT control must key on the absence of a live consent, not only
  the precondition that made it offerable (Art. 7(3)) — read "do I have a record?" BEFORE
  the eligibility check. A one-shot backfill needs a REQUEST-LEVEL resume cursor (both
  request and response types), not a loop-local one, or every invocation restarts at the
  top. An EU single-region→multi-region move is NOT a Chapter V regression — only a move to
  `global`/outside-EEA is.

### Cloud Functions / cascade mechanics
- A deterministic doc ID + `set()` (not `add()`) is the standard idempotency primitive.
  Region pinning covers every export in a file — removing it reverts unconverted functions
  to the default region; clients must match the region option or 404 in prod.
- A client-written FIELD that becomes a PATH SEGMENT is an availability weapon, and its
  guard belongs at EVERY entry point that reaches the same `.doc()` — a trigger that
  validates `"."`/`".."`/`"/"`/`__x__`/>1500 bytes and a reconciliation pass over the same
  collection that does not are one guard and one hole. Grep every caller of the ref
  builder, not the one the guard sits in.
- A repair/reconciliation loop over N users needs PER-ITEM isolation (`try` inside the
  loop, count failures, log at ERROR) exactly like a probe's per-leg `try`: without it one
  poisoned or contending row aborts the whole pass for everyone behind it, every run,
  forever. Judge the blast radius by what the pass IS — the safety net for a control whose
  failure is silent has no second net.

- A scheduled drainer retrying a state machine needs a max-attempts cutoff to `failed`.
  Storage/document triggers cannot carry App Check — put it on the client-facing callable
  that produces the triggering write.
- A virtual-parent-doc subcollection tree (parent never written) is valid for owner-scoped
  logs; GDPR cascades use listCollections-on-ghost-root + conditional root delete, with the
  rule's `hasOnly([...])` matching the model's `toFirestore()` key set byte-for-byte. An
  aggregate recomputed from a deletable subcollection should use the existing
  `onDocumentWritten` trigger (fires on delete unconditionally) over an explicit cascade
  call.

- A standalone admin script is safe to delete once: no exports; not exported from
  `index.ts`; no `package.json` entry; no dedicated test; not named in CI/deploy config.
  Reference `firestore.rules` branches by path+rule type in comments, never line number.
- A roster/keep-set diff that DELETES user data must refuse to run when the keep-set is empty or
  implausibly small — an empty denormalized member list must not read as "everyone left"; guard
  `if (roster.size===0) return docs;` and prefer the authoritative membership list over a
  denormalized projection built for a different query.
