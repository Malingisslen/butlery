# firebase-backend-security — chapter: gdpr-export

### GDPR: deletion, export, and the "wrong probe shape" bug class
- **Most-repeated defect**: a cascade/probe/export query targets the wrong field, shape or
  COLLECTION NAME — an owner-keyed collection probed by `userId`, an OR-owned collection
  folded into one query instead of per-field, or a constant naming a path nothing writes.
  Open the actual `.where()`/`.collection()` clause; a function with the right name proves
  nothing. The REPAIR of such a read is where the next one hides: a section usually derives a
  metadata field beside the rows (`fcm_token_registered` + `fcm_token_updated_at`), and fixing
  the query leaves the derivation reading a field NO writer writes (`updatedAt` where the
  writers emit `lastUpdated`/`lastSeen`) — permanently null, in the half nobody re-checked. Diff
  every field name the section reads against the WRITER'S payload (and `git log -S` the
  spelling), not against the query you just fixed. The same commit also falsifies whatever
  comment elsewhere cited the dead read as live — the cascade's own `subs` list is the usual
  place — so grep the ticket id and the path across `functions/src` and strike the clause. Cheapest check: grep `firestore.rules` for the path — no match block means
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
  cap needs the identical flag. Two corollaries the cap creates in the OTHER direction. (1) A
  bundle field asserting EXISTENCE (`*_exist: false`) must never be derived from a capped,
  UNORDERED collection page — the one known document can fall outside it, and an export
  asserting absence is worse than one admitting it clipped; read that document BY ID (its own
  `get`, guarded like every sibling) and let the collection read cover only the rest. Adding
  `orderBy` is not a substitute unless the id is provably first. (2) When a section's legs are
  isolated per read, a FAILED leg emits `<key>_error` + `<key>_error_code` and NO list key — an
  empty list beside a failure marker is the stronger, possibly false claim "you have none" —
  and the section-root split is counted, never a literal (`failedLegs == attemptedLegs` ⇒
  `error`, else bare `error_code`), so a fourth leg cannot silently disable the
  outright-failure branch. Isolation is only real while every leg's product survives the
  others: a by-id read whose value is discarded by a sibling query's `catch` re-creates the
  shared-`try` defect one file over. (3) MERGING a sub-leg's payload with `addAll` DESTROYS a
  failure marker whenever both legs spell failure under the same generic `error_code` — and
  `??=` only swaps which one dies, because the bundle emits ONE warning per section from that
  key. Fix: lift the sub-leg's code OUT before the merge, give it its own `<leg>_error_code`,
  and let `??=` govern the generic key alone. The rationale sentence that then gets written is
  a quantifier trap: "whichever loses is GONE from the artefact" is FALSE for any leg that
  also records itself per-row, so state only "the loser produces no bundle-level warning."
- "No third party appears in these rows" is a claim about the WRITER'S COPY BUILDER, never
  about the field list — grep the module that composes the stored text, not the `set()`.
  A free-text field whose name promises nothing (`message`, `bodyShown`, `title`) is where
  personalised server copy interpolates someone else's display name
  (`${firstName(sharerName)} delade ett recept med dig`), so an unprojected pass-through
  justified from the schema ships a third party the schema never named. Such a KEEP is
  Malin's recorded decision, not an inference from a same-shaped call on another
  collection, and the paired `docs/security/*-retention.md` usually repeats the false
  sentence TWICE (the Art. 15 section and the DPIA note) — sweep the whole file. Once the
  KEEP ships, the bundle's own `data_minimisation` sentence is the only thing that tells the
  subject, so pin it with an assertion (nothing else stops a later edit deleting it), and
  word it from what the code PRODUCES: a `firstName()` helper splitting on whitespace
  returns the WHOLE display name for a single-token name, so "first name" in user-facing
  text underclaims. Grade the copy builder's OTHER branches too — a digest row of counts is
  clean, but "counts of activity on their own content" is a different claim from "counts of
  their own activity" (a comment they authored sits on someone else's recipe).
- A row-level DROP is a different decision from a field-level STRIP and takes the OPPOSITE
  fail direction: a strip fails CLOSED (unrecognised owner id ⇒ lose the field), a drop fails
  OPEN (unreadable owner id ⇒ KEEP the row, because under-disclosure is the worse Art. 15
  failure). Both need the section's `data_minimisation` sentence to NAME the drop and a test
  asserting that sentence, or the withholding is silent. A strip built as an ALLOWLIST is the
  right shape only while its under-disclosure direction is DECLARED IN the bundle — where the
  create rule is `hasRequiredFields` rather than `hasOnly` a client can store an undeclared
  field and the list then drops the requester's OWN content — and check what the list is keyed
  to: a Dart field list mirroring a TypeScript interface in `functions/src` is coupled by
  nothing but a comment, so grep for a test asserting the two agree before crediting the
  coupling. Check the allowlist is PINNED at all: a section test that fakes the repository
  method the projection lives in has faked away the projection itself, so replacing the
  list with `return raw;` stays green — grep the projecting METHOD's name across `test/`,
  and note the fail-closed direction is mechanical only if a writer-side key-set assertion
  reddens when a new field joins the document. A drift test derived from the DART MODEL's
  `toFirestore()` does not range over the SERVER writers of the same collection — the
  rename-propagation CF (`on-profile-updated.ts`) and the deletion cascade's anonymizer both
  write keys onto `recipe_comments`, and a one-time BACKFILL migration writes the very
  denormalised field the strip decision is argued about. So grade "its only writer is X" and
  "derived from the writers" as quantifiers over `functions/src` too, and strike the "only
  writer" clause rather than re-wording it: the argument such a sentence carries (nothing
  updates the snapshot on re-share/unshare) is usually verifiable on its own and survives
  the strike. If a key-set gate later lands in
  `firestore.rules`, the projection DEMOTES to defence in depth, and every comment calling
  it "the layer that decides what reaches the bundle" goes stale in that same commit —
  sweep the CONCEPT across repository, manager and test header, not the two files the diff
  happened to touch. Word that sentence as WHAT is
  withheld, never WHOSE data it is: a moderator's free-text note ABOUT the requester is the
  requester's own personal data by any reading, so telling them it "concerns another person"
  is an Art. 12(1) defect — and on a collection with no rows nobody can measure whose data it
  carries. The tell is the docstring beside it describing the SAME field the opposite way
  ("text written about the requester" vs "third-party data"); one of the two is false and it
  is the bundle's that the subject reads. A WITHHELD SET is a counted set: the
  moment a collection joins it, every "both"/"the five" in the bundle text, the Art. 30
  register, the exemption map's docstring and the pinning test's NAME goes stale at once —
  assert `contains(<name>)` per member, never a count. Grade an exemption's stated REASON
  apart from the decision: "same class as <sibling>" is a claim about doc-id SHAPE and writer,
  while the substantive reason is usually that the withheld rows are DERIVED from a section
  the bundle already ships (a report-cooldown stamp over `reports where reporterId == uid`) —
  open that section and check it carries the joining field before accepting it. The exemption
  map's SECTION HEADERS are themselves universals over the entries beneath them ("no live
  writer of this path — legacy sweep only"), so a new key filed under the wrong group ships a
  false reason without one line of its own text being wrong: check which group it lands in,
  and MOVE the entry rather than reword the header. Settle "is moving it risky" by MEASURING
  the consumers rather than arguing it: grep the map's symbol repo-wide and classify every
  assertion as KEY-reading (`name in exempt`, `exempt[X]`, a text-PREFIX filter like
  `why.startsWith('NO LIVE WRITER')`) or POSITION-reading. Where none reads position, a
  group move is assertion-neutral and the "a move broke a scenario once" worry is answered
  in one command. An exemption whose reason is another
  section's continued existence needs that dependency held by an assertion, not by prose —
  and when the depended-on section is DECIDED for removal, grep every artefact still calling
  that decision open (the guard test's own docstring is the one the sweep misses). Grade that sentence against the
  READER it is written for, not only for truth: an upper bound ("readable only by the
  members it was planned with") can be true and still fail to explain the exclusion it sits
  under, because the excluded reader satisfies it too — a leaver WAS planned with. Strike
  the bound rather than re-word it; the unconditional gap sentence above it carries the
  fact already. An Art. 15 KEEP resting on "the
  requester has already seen this in the app" is a measurable claim about a WIDGET, not a
  policy argument — grep the render before accepting it (a row drawing a COUNT does not
  justify shipping the uid LIST); when it is false, making the app show it is a legitimate
  close, and the code then owes a comment saying a change removing that surface reopens the
  decision. Three things a row filter does not
  reach: a denormalised COPY of the row on the parent doc (`conversations.lastMessage`), any
  overlay attached to the dropped row (the requester's own `your_poll_vote` goes with it), and
  a cap applied UPSTREAM of it — so the truncation flag must stay computed from the RAW
  pre-filter fetch. A row filter guarded by a CONTAINER type-check (`if (trail is List)`)
  fails OPEN at the container even when its per-row branch fails closed: an unexpected shape
  skips the filter and exports the field WHOLE. Check what the write rule actually permits
  before calling that unreachable — a `.get('f', []).size() <= N` cap bounds ROW COUNT, not
  TYPE, so a map with N keys satisfies it. Put the else-branch on the container too.
- A BUNDLE-WIDE claim in `export_metadata` ("all timestamps end with Z", "nothing here is
  another person's") is a universal over EVERY assembly route, and the routes that falsify it
  are the ones that never touch a raw document: a section serialising a MODEL
  (`d.toJson()`, a `toFirestore()` delegating to a nested `toJson()`) emits
  `toIso8601String()` on a LOCAL `DateTime`, which reaches the bundle through the
  sanitizer's PRIMITIVE arm untouched — the `Timestamp` arm everyone grades never runs.
  So enumerate by ROUTE, not by section: raw doc, model `toJson()`, and a service writing a
  string directly (`clock.now().toIso8601String()` into a map a redaction decision KEEPS).
  Fix at the export boundary, never in the model — its `toJson()` is also the local-cache and
  Firestore write format, so "fixing" it is a migration. The normalisation must NAME its key
  paths: a recursive rewrite of every date-shaped string also rewrites user content that
  merely looks like a stamp. The test is the half that matters and goes vacuous the easy way
  — a walker over the decoded bundle passes on a bundle holding no such stamp, so seed every
  route AS ITS REAL WRITER WRITES IT (a local ISO STRING, never a `Timestamp`, which exercises
  a branch the field never takes) and pin each path in an anti-vacuity `containsAll`. Probe
  one route at a time; a combined probe masks whichever route the fixture forgot.
- "Export ⊇ erasure" is a field-PAIR property — the two filters must target the identical
  field on the identical collection; check both cascades together. When a cascade UNIONS
  several discovery handles (roster + last-writer), the EXPORT's own discovery field must be
  one of the legs, or a document the bundle ships stays un-erasable — and the ACL MAP KEY is
  a third handle in its own right, not a mirror of the roster, wherever an admin may update
  `memberPermissions` alone (Admin SDK: `new FieldPath("memberPermissions", uid) != null`,
  which matches the client's `isNull: false` set exactly) — and every per-document
  scrub must be scoped to the handle that FOUND it: a writer-handle hit otherwise rewrites a
  roster the subject was never on, from a snapshot, losing a concurrent admin edit. Both rest on a prior
  property worth checking FIRST: every uid a write can store must satisfy the collection's
  DISCOVERY predicate by construction. A field written by a THIRD party (a poll close
  stamping the voters' uids onto a group plan) can carry someone the document's own
  membership array never names — a member who joined after the doc was seeded, or left
  before the write — and such a uid is invisible to a membership-keyed cascade, its residual
  probe AND the membership-keyed export at once: neither erasable nor exportable. Fix at the
  WRITE (intersect the stored ids with the roster) or add a flat `array-contains` erasure
  handle; a scrub cannot reach what no query returns. A membership MAP KEY is
  itself a raw identifier — clearing the name but leaving the ACL key is incomplete
  (`FieldValue.delete()` it in the same scrub) — and so is a map VALUE: a per-member
  `addedBy`/`invitedBy` map is scrubbed only for the DEPARTING subject's own key, so their uid
  survives as every other member's value, unqueryable by any probe. Same blind spot when an
  owner/creator field is RE-HOMED only while the subject is still in the membership array —
  the already-departed case is unreachable by that query, so the departure path needs the
  re-home too — and never let a residual sweep's own doc COUNT the fields it clears.
  A row authored by a SYNTHETIC identity
  ("system") naming a real person in FREE TEXT is invisible to every id-keyed cascade — give
  it an erasure HANDLE field. Denormalized PII travels in FIELD GROUPS (`sharedBy*`,
  `lastActivityBy*`); the rename-propagation CF (`on-profile-updated.ts`) is the inventory —
  diff it against the deletion cascade ("propagated on rename, not scrubbed on erasure" is
  the recurring miss). A residual probe and its cascade must share the same DISCOVERY
  QUERY, or the mismatch leaves a permanently-reported, unfixable residual — every probe
  here is FIELD-keyed and blind to an identifier living only in a DOCUMENT ID, so a step
  that knowingly leaves such a doc standing must flip its own `complete`/`gdprCompliant`
  flag false.
- Relocating a field into a subcollection drops it from every DERIVED surface not named in
  the ticket — enumerate all four: display path, Art. 15 export (needs a collection-group
  `match`), Art. 17 cascade + probe, and the rules validator. A section's own prose
  describing its contents becomes FALSE the moment the storage shape moves under it.
