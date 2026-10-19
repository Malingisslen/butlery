# cloud-functions-specialist — chapter: data-pipelines


### TS↔Dart parity twins (canonical-pool-key.ts et al.)
- Case-insensitive triggers need per-letter classes, not `/i`. Module-scope
  `/g` regexes are stateful with `.test()`/`.exec()` in long-lived isolates.
  Shared word lists and cross-port VECTORS: compiled-in consts or one shared
  JSON fixture, pinned on BOTH sides, never a runtime load.

### Telemetry callables (events/)
- **A counter a callable bumps from a client event is only as true as the set of events
  the client sends.** When a client change widens WHICH outcomes reach the callable
  (cache hits, assisted results, new channels, social pipelines), re-check every aggregate
  the handler writes against the new population, even if the CF lines are untouched.
  `site_configs.successCount`/`failureCount` feed `SiteConfig.isReliable` → the parser's
  quality bar, so only a live site parse may move them: gate in an exported pure predicate
  (`countsForSite`) and derive `success` from the validated `outcome`, never a second
  client flag.
- A Dart test pins `VALID_*` lists by regex `export const NAME\s*=\s*\[([^\]]*)\]` — no type
  annotation before `=`, no `]` inside the list.

### LLM quota wrappers (llm/guest-import-quota.ts)
- **A refunding quota wrapper keys the refund on SPEND, never on success.** Giving back
  a per-uid slot while keeping a SHARED counter turns every refusal inside the wrapper
  into a free burn of that shared counter; refunding everything on `success:false`
  turns a paid model call into a free one. `withGuestImportQuota`: a throw refunds the
  call, `success:false` refunds the call only at `estimatedCost == 0`. A daily refund
  checks the charge's own `dayKey`.
- **A refund that releases a SHARED-KEY resource is decided per KEY, never per call.**
  Concurrent calls on one client id share the slot and the shared count the opener
  charged, so the opener's refund must not release them while a sibling holds the id.
  `guest_quotas/{uid}.imports[id] = {open, day, spent}`: charge bumps `open`, refund
  drops it, success never does; the slot comes back only at `open == 0`, and the daily
  count only if no call on that id ever had `spent`. A re-add-on-success repair
  (`arrayUnion` back) is the wrong shape: it skips `GUEST_IMPORT_LIMIT` and never
  re-charges the shared count. Stage BOTH orderings with deferred handler gates.
- **A client string used as a MAP KEY is a field name**: the backend (emulator included)
  refuses `^__.*__$` with INVALID_ARGUMENT "field name '…' is reserved"; the Node SDK
  does not check it. An id regex that admits `_` must exclude that shape, or the write
  fails as an `internal` callable error.
- The shared `_fake-firestore.ts` records WRITES only. To assert what a transaction
  READ (e.g. a hot shared doc touched only on a new id), wrap the store in a `Proxy`
  whose `runTransaction` passes a `tx` with a recording `get`.

### LLM prompts & prompts-config
- Compiled-in prompt edits are INERT while a Firestore `system/prompts`
  override doc is live — ship a matching prod-doc update. A new prompt field
  must be OPTIONAL with per-field fallback (a required-keys set reverts every
  live override), and mirroring a config field means grepping every test
  fixture, or a stale one flips to fallback and passes vacuously.

### Ingredient sync, allergen data & admin exports/ETL (admin/ family)
- `admin/` scripts run `main()` at import — extract pure cores to test.
- **A hand-run script's delete/keep OVERLAP guard no-ops the WHOLE script in
  silence** (`reset-user-data.ts`); repairing it removes the header's only
  enforcement, so the durable barrier is a HUMAN step nothing can pre-satisfy: a
  typed `CONFIRMATION_PHRASE`, `!dryRun`-scoped, above the first `runPhases(`
  (`admin-init.ts` hardcodes prod). Its Auth-wipe phase fires
  `onUserDeleted`, which writes into collections Phase 2 is concurrently deleting.
- **A run-time REPORT of "what no list decides" reads EVERY register the deleters
  use** (one erased by its OWN tier step — `pantry` — is in no list and fires on
  every account), never steers the run, and never says
  what an appearing name MEANS: trigger-owned rows come from ordinary app use.
- **Moving a collection to `COLLECTIONS_TO_KEEP` only half-decides it.** Its
  SUBCOLLECTIONS need a fail-closed allowlist, and a subcollection-level prune
  leaves PARENT-DOCUMENT FIELDS behind — measure them in the verification pass
  rather than promising them in a comment. A kept-collection existence probe
  (`.limit(1).get()`) reports "empty" for a collection whose parents hold only
  subcollections; `listDocuments()` answers, and bills one read per document. A
  `dryRun` flag on a helper that DELEGATES deletion is inert unless the helper
  reads it — delete it.
- **A source pin owes**: a grep-UNIQUE anchor; the guard's EFFECT, not its position
  (`process.exit(0|1)` INSIDE the gate); `//`-stripping, which stops NEITHER
  `&& false` NOR a `/* */` wrap; and the INVOKER, its literal DERIVED from the
  declaration, anchored `/^const NAME = "([^"]+)"/m` (`String.match` takes the
  FIRST hit — an unstripped `/** */` quoting it wins).
- **A "wipes all" claim needs TWO sources, never a number**: `firestore.rules`
  top-level `match` blocks (blind to server-only) UNION a `functions/src` scan
  resolving `Collections.X`, `(export )?const N = "…"` PER FILE (an IMPORTED name
  must stay unresolved), `collectionGroup(…)`, and doc paths in BOTH quote and
  backtick form. ONE anchor per branch, on a name only THAT branch finds and
  something writes; the mutant must COMPILE (TS6133 is not a red test).
  That scan collapses a `users/{uid}` subcollection only when `.collection("users").doc(…)`
  sits in the SAME chain: `userRef.collection("consent")` off a variable reads as a TOP-LEVEL
  collection and reddens `every collection this repo knows about is decided` — write such
  refs as one inline chain. The reset prune's `dailyDocRef` scan likewise needs a string
  LITERAL group; a named const is reported unresolved.
- **A skip register's reason is a MEASURED claim about EVERY writer** — it authorises
  retention, and rules are not evidence (the Admin SDK bypasses them): `system_events`
  read clean in two writers while a third wrote raw uids in a doc id and a field.
- Normalization parity must hold across every matching surface (sync stamp,
  server hold-gate, Dart client); list-split regexes stay in lockstep.
- Export/mining: verify FIELD PARITY against the writer. Best test is a
  PRIVACY WHITELIST — seed adversarial PII-shaped fields, assert the exported
  key set is EXACTLY allow-listed.
