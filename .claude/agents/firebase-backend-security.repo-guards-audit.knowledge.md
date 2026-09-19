# firebase-backend-security — chapter: repo-guards-audit

- Prefer a targeted `update({changed fields})` over `set(merge:true)` from a possibly-stale
  local base (offline/queued replay) — a merge re-sends unchanged privileged fields, letting
  the one caller allowed to touch them (the owner) resurrect a removed member via a stale
  write. Shipped shape: diff the proposed doc against the stored one, emit only differing
  keys (map fields as per-key paths so deletion survives `merge:`), empty diff = skip the
  write, THROW if a privileged key differs while the base is from cache
  (`metadata.isFromCache`). The CLIENT MIRROR of a doc-level `hasOnly` rule has the matching
  failure, and it is an AVAILABILITY bug rather than a drift: a guard comparing the caller's
  WHOLE entity against a fresh server read refuses whenever that entity is stale in ANY
  serialized field (a tick, an activity stamp), even though the intent — leave, un-share,
  withdraw — is fully determined by (actor, `stored`). Client and server agree, so nothing
  reddens; the operation just fails with a message naming the caller's write as the cause.
  Where the write is fully determined, BUILD the proposed entity from `stored` in the
  repository instead of trusting the caller's copy. That derivation owes three checks.
  `copyWith` must carry every other field — one stray `?? clock.now()` makes the derived
  entity trip the allowlist for EVERY caller, so read the body, not the parameter list. The
  caller's copy usually still reaches a SIBLING gate (a declared-base drift check, a cached-base
  refusal) that can refuse the write, and its `id` still SELECTS the document read and written,
  so any "the client's copy contributes nothing / only X" clause is an overclaim — strike it,
  then grep the INTERFACE doc, because that is where it comes back in different words once the
  implementation's copy is gone. Grade a POINTER clause ("as its own doc says it should") on the
  target's PREDICATE, not its topic — a doc that describes routing does not say a module should
  stay a FACADE, and checking only the topic is how a reviewer signs one off as resolved. And
  a sentence whose HEAD you edit RE-EMITS its tail as your commit's bytes: the line shows as
  changed, the eye grades the change, and an inherited false clause ships as new. `git show
  HEAD:<file>` on the sentence is the only thing that separates the two; a diff cannot. And the mirror's now-tautological conjuncts STAY when the guard is
  PUBLIC: they are then a method contract, not dead code. Grade the probe that proved them
  tautological with care — neutralising a conjunct (forcing it true) reddens nothing whether it
  is always-TRUE or always-FALSE, so the green baseline, not the mutation, is the half carrying
  that claim.
- A guard set is scoped to a method's callers; promoting it to a public INTERFACE
  invalidates that scope — review the promotion and its sibling as one change, require
  guard parity. An injected `void Function({...})` callback silently drops the `await` on a
  `Future<void>`-returning `logPermissionCheck` (Dart void-covariance) — declare it
  `Future<void> Function({...})` and await, only once the sink can't throw.
- `requireCurrentUserId()` then `logPermissionCheck(granted:true)` with no real check
  forges the trail. A guard logging `granted:true` BEFORE the write forges it a second way:
  where every SIBLING guard in the file is refusal-only and the METHOD logs the grant after
  the write, a new guard emitting its own grant yields TWO rows per operation and an ORPHAN
  grant whenever the write then fails (a rules deny, a stale-base refusal, an offline
  refusal) — so grade a new guard against the file's existing grant/refusal convention, not
  against "does it log". Keep guards refusal-only; emit a decision-specific grant AFTER the
  write returns. Run the actual `validate*Permission`, log its verdict, fix every sibling
  (create/update/mutate) in one pass, checking EVERY conjunct of the matching rule. Its
  `userId:` must be the AUTHENTICATED caller, never the entity's CLAIMED owner — the
  `audit_logs` create rule pins `request.auth.uid == request.resource.data.userId`, so
  naming the claim loses the row in exactly the denial it exists for (put the claimed owner
  in `resource`). Do NOT write that as "the authenticated actor, like every sibling" — the
  audit `userId` is NOT uniform across `lib/repositories`: the storage repositories pass the
  literals `'anonymous'` and `currentUserId ?? 'system'`, which the same create rule refuses,
  so the universal is false and points at rows that never land. State the rule (the create
  rule pins `auth.uid`), never a survey of the siblings. The call MASKS NOTHING: the raw uid goes to a device-local `developer.log`
  (`AppLogger.info`/`warning`, no Crashlytics, no redactor) and raw into the audit document
  by design — so any comment saying a sanitizer covers it is false; name the SINK. It also
  cannot fail an operation (`unawaited` + `catchError` + an outer try), which is what makes
  it safe to run BEFORE the deny branch on every write. Moving it INTO the deny branch
  (refusal-only auditing, permitted by `lib/repositories/CLAUDE.md`) costs per-operation
  HISTORY: the document is last-write-wins while audit rows are immutable and per-operation
  (`allow update, delete: if false`), so every earlier operation is unrecoverable and the
  last one only as a timestamp — the per-user plan document records no actor at all, and the
  group document only the caller-supplied `lastModifiedBy`, never the authenticated uid the
  row names. Say that out loud rather than calling the row redundant. Do not accept "the row
  is derivable from the document" as the criterion; ask instead what the row records that the
  document cannot — the authenticated uid, the refusal itself, and every earlier operation. Demand two things back: the unconditional
  `requireCurrentUserId()` is usually the method's ONLY client-side auth assertion, and
  calling it inside the deny branch THROWS before the refusal row is written, losing exactly
  the row the design keeps — hoist it to the top of the method. A volume argument resting on
  "the only live caller is <one server trigger>" is a claim about the CALLER SET that a UI
  batch in the same sprint falsifies: when a new INTERACTIVE writer reaches such a method,
  re-open the trade rather than only striking the quantifier, and split the verdict per
  REPOSITORY — on a tautological-gate, single-writer document the granted row still records
  nothing, while on a multi-writer document whose only actor field is a last-write-wins
  `lastModifiedBy` the lost history grows from thin to real. Also grade the rule file's
  own "live exceptions:" list as a measured ENUMERATION (strike, don't extend): a
  guard-shaped module whose success path is a bare `return` already logs refusals only.
- A client gate invoked as `validate*Permission(entity.ownerField, entity.id, entity)`
  compares the entity to ITSELF — the ownership conjunct is a tautology whoever is signed
  in, so it can only catch MIS-KEYING, never a cross-user write. Never credit such a refusal
  row as an attacker signal, and never let its existence stand in for the real control (the
  conjuncts in `firestore.rules`). Check the ARGUMENTS at the call site, not the
  method body.
- A destructive repository method with ZERO callers is closed by REMOVAL, not by bolting on
  a permission check and an audit row — a guard on an uncalled method protects nothing and
  reads as coverage. Before deleting, discharge three things: the obligation it was written
  for now lives somewhere that actually runs (a Cloud Function cannot call a Dart
  repository, so a server-side replacement means this method could never become that
  caller); Art. 17 for the same collection is covered by the deletion cascade; and the
  deleted-symbol sweep reaches the TEST FILE'S OWN HEADER DOCSTRING and any plan/rules
  comment naming it — those survive the compiler and become false coverage claims. Prove
  "zero callers" with `git log -S` on the writer, not just today's grep.
- An OPT-IN named-parameter guard defaults every EXISTING caller into the restricted branch
  (silent no-op) — ship a named METHOD on the interface instead, with its own exception
  type and a caller that honours the result (ADR-002).
- SWALLOWING `permission-denied` as "already done" turns a rules refusal into a claim that a
  protection is IN FORCE, so grade it on three axes. (1) ENUMERATE every reason the rule can
  deny that write, not just the intended one — an immutable-row `set()` is denied as an
  UPDATE, but the same code masks an unauthenticated caller and every FUTURE narrowing of
  `allow create`; safe only while the confirming read is denied in those cases too, which is
  a claim about the READ limb. (2) The confirming read must be `Source.server`: a plain
  `get()` answers from cache without error, so a row the server no longer holds still reports
  "you are protected" — this is a decision path, not a display path, and the SAFE direction is
  the read THROWING (catch ⇒ false ⇒ rethrow). (3) A body check re-testing what the composite
  id + create rule already pin (`blockId == blockerId + '_' + blockedId`, `blockerId ==
  auth.uid`) is redundant belt-and-braces, harmless because it only makes the code rethrow —
  but do NOT justify it by a case the READ rule makes unreachable ("a doc whose blockerId is
  somebody else"): such a doc is unreadable, so the read's denial decides it. The two guards
  are REDUNDANT WITH EACH OTHER, which is what makes every justification sentence here false
  in one direction or the other — "safe only because of the body check" and "safe only while
  the read limb denies foreign rows" are both false necessity claims, and a create-NARROWING
  cannot be swallowed unsafely at all (no row ⇒ rethrow; the caller's own row ⇒ genuinely
  idempotent). Do not offer a replacement clause as a reviewer: recommend the DELETION, and
  say only what the code does.
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

- Audit retention differentiates by category (consent 730d, general 180d) via the
  `operation` STRING — every writer must set it, purge must exclude fresh consent events.
  Renaming/retiring a token: grep CONSUMERS and `git log -S` the old spelling and writer
  METHOD, since rows outlive their caller. `auditRepository` is an OPTIONAL constructor arg
  some DI modules don't pass — check DI registration, not the repository, before crediting a
  trail as live. Grade the INVERSE the same way: a stated VOLUME COST of wiring one in
  ("~30 near-identical rows per export") is a claim that the class REACHES
  `logPermissionCheck`, and a read-only gateway usually does not — `validateOwnership` never
  calls it (it emits `AppLogger.warning` and throws), and `BaseFirebaseRepository` consumes
  `_auditRepository` only inside the four CRUD methods such a gateway overrides to throw. So
  the cost can be a counterfactual the class cannot produce, and the rows it would add are
  tautological anyway wherever the guard's call site derives both uids from one session
  (BUT-1981's accepted trade). Striking such a clause leaves its NUMBER standing with no
  argument to serve — re-measure it or strike it too. A GDPR ARTICLE cited in a comment is a measured claim about that article's
  TEXT: Art. 30 is a register of processing categories and purposes and mandates no
  per-operation access log, so "Art. 30 requires this row" turned a house rule into a legal
  one across the repo (BUT-1981, swept 2026-09-16). Retracting such a claim is keyed on the
  CLAIM, not the PHRASE: the heaviest carriers spelled it `Art.30` with NO SPACE, so a sweep
  grepping `Art. 30` came back clean for three gates at once, and the two strongest asserted
  that an auditor could RETRIEVE such a record — an obligation the article does not create.
  Grep the paired `docs/security/*-retention.md`, which is the actual Art. 30 register and
  may derive the rows' LAWFUL BASIS (Art. 6(1)(c) "legal obligation") and the Art. 17(3)(b)
  erasure exemption from the same retracted premise — but do NOT sweep it: a register ABOUT
  a collection is not the same as the collection BEING the register, and that distinction is
  what keeps a comment sweep out of the legal documents. Strike the false clause rather than
  re-point it at a doc whose own basis is now in doubt, and file the register's correction as
  its own ticket. Expect two second-order failures. The retraction's own decision record
  usually carries a "the sweep is NOT done, X still asserts it" sentence that the DISCHARGING
  commit falsifies — supersede it in that same commit. And the prose written AS the correction
  is where the next false claim lands: a provenance clause crediting the commit with files it
  never touched, and unmeasured numerals, one of them inside the supersession block itself.
- A rollback error message must not read a field a DIFFERENT, unrelated failure also
  writes — use a dedicated field cleared at the START of every mutation entry point, read
  through a self-clearing `consumeError()` called before `if (!mounted)`. A NEW exception
  subtype needs its own arm at the message-mapping seam in the same diff.
### Admin-only aggregate repository bypass (6+ repos confirmed clean)
- Skip `PermissionValidationMixin` only when ALL FOUR hold: read-only; rule-gated by
  `isAdmin()`; PII-free output; errors degrade to empty/zero, never rethrown. Document the
  rationale in a class doc comment. Any one failing = mixin mandatory.
- Admin callables with a client `limit` must reject invalid values explicitly
  (`invalid-argument`) — `limit||fallback` wrongly treats `0` as "use fallback."
- A post-batch `.get()` may not reflect a `FieldValue` transform from the SAME batch — never
  use it to enforce a size cap; use a transaction.

