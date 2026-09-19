# firebase-backend-security — chapter: reads-cache-offline

- Hydrating a page of parents with a per-parent SUBCOLLECTION (archive: BUT-1832
  `message_query_module.dart`) has four failure modes: a per-item listener under
  `switchMap` over the parent stream rebuilds the WHOLE fan on every parent emission — key
  it by the parent-ID SET (`distinct`) so it only rebuilds on membership change; a
  `.take(n)` cap applied AFTER `.reversed` keeps the wrong end — cap on the end the user
  reads from; hydration must reach EVERY reader that hands the entity out (stream, page,
  single-doc, search), grepped, not assumed from a comment; and an error handler returning
  an EMPTY collection is fail-CLOSED, not fail-open — only a null/absent value the combiner
  FILTERS OUT leaves the entity untouched.

- Judge "is swallowing this read safe" by whether the downstream safety verdict defaults
  permissive on missing input (permissive-default = Critical). A collaborator whose own
  `catch` returns a NEUTRAL value (`{}`, empty list) has no error channel, so every
  caller's `catch → refuse` branch is DEAD CODE that reviews and unit-tests green against
  a throwing mock while production fails OPEN — read the helper's body, not the call site,
  and give the safety caller a variant that propagates (latching an `_initialized` flag
  before the `try` also makes the neutral answer stick for the whole session). Review the
  propagating variant as a CACHE, not just a throw: moving the latch after the `await`
  needs single-flight, or concurrent first callers each fetch AND each overwrite the
  subscription field, leaking every listener but the last past `dispose()`; and the
  refresh stream's `onError` must clear the latch, or a dead watch makes the propagating
  variant report a frozen cache as authoritative — the same fail-open, one layer over.
  That invalidation has three follow-ons: clear the IN-FLIGHT future too (a fetch
  completing after `dispose()` re-latches and re-subscribes, and GetIt's `dispose:` fires
  on scope pop); the retained value is then DEAD state, so a comment calling it a
  best-effort answer for the display path is false (that path re-reads and degrades to
  empty); and with no cool-down every later read re-queries — one read per snapshot on a
  per-emission path, and never to be repaired by serving the stale set. Clearing the
  in-flight future does NOT stop a future already RUNNING: add a generation counter bumped
  by `dispose()` and re-checked after EVERY await (the fetch AND the subscribe, cancelling
  the just-opened subscription on the second arm), set the latch and the cached value ONLY
  after the LAST check with no await between them (an earlier latch leaves the previous
  user's set readable until dispose's trailing reset), and make each arm THROW — a guard that
  returns the neutral value re-creates, inside the fix, the exact fail-open it closes. Put
  the throw ONLY on the propagating variant and let the swallowing one convert it, then
  grep that no display caller reaches the throwing method. Fetch and watch usually resolve
  the signed-in user INDEPENDENTLY, so a sign-out between them swaps the watch for a
  signed-out fallback stream that overwrites the cache before completing. A
  `catch → return null` collapses FAILED into ABSENT, and the caller then "repairs" a
  document that exists;
  rethrowing and reserving null for `!exists` is the fix, but a `!exists` answer resolved
  from CACHE is still not proof of absence, so any comment claiming null means absent "and
  nothing else" overclaims unless it checks `metadata.isFromCache` — the same cache path is
  why a "refuse when unreadable" gate never covers "readable but STALE". The TRIGGER to apply
  this, stated so it fires without the ADR being open: any read on a DECISION path whose
  absent/zero answer is the INNOCENT one (has this user been reported, does a block stand, is
  a hold in force) must be `Source.server`, because a plain `get()` under
  `persistenceEnabled: true` answers a never-cached document as `exists == false` with no
  error — so a three-state design that separates FAILED from ABSENT is defeated by the cache
  in the only state anyone built it for, and no timeout or `catch` sees it. A doc comment
  saying "null means the read failed, zero means never" is then a contract the code does not
  keep; fix the read, never the sentence. Closing THAT is a
  SERVER-SOURCED sibling read (`GetOptions(source: Source.server)`, which throws `unavailable`
  offline) on the PROPAGATING variant only, and that variant must neither read nor write the
  shared latch — a display path that latched a cache-served set offline otherwise answers the
  decision with no I/O at all. Two residuals to state rather than fix: a local write not yet
  server-acked is invisible to a server-source read (the cache-backed read saw it), and the
  split stays unpinned unless a test drives the REPOSITORY, because every service-level suite
  mocks the method NAME and passes whether or not the option is still passed. A flag that TRUSTS a
  cached absence (`acceptCachedAbsence`) must be opt-in per call and stay `@protected` — but
  its real cost is that it converts a refusal into an EMPTY answer, so the read-failed flag
  never fires and the write path built on that empty answer runs unguarded: trace it, and
  check whether the collection's update rule (`cannotModify(['createdAt'])` vs a full `set()`
  carrying a client `clock.now()`) refuses the resulting overwrite — it does, because
  `diff().affectedKeys().hasAny` sees the fresh client stamp, so the loss is the user's own
  local edit, not server data. ORDER is the whole control: the cached absence may be
  substituted only inside the server read's `catch`, never before, or a stale
  "missing" becomes authoritative ONLINE too. Do NOT write that as "the server is asked on
  every call" — a cache-first helper returns a cache HIT with no server read at all, so that
  sentence is false in the docs and inverts the helper's cost story; the true claim is
  "asked before any cached absence is used". Keep that `catch` narrow — a bare `catch (_)`
  converts `permission-denied` OR a client-side timeout into "empty", so the safety claim
  must read "a caller whose server read SUCCEEDED", never "an online caller" — and that
  narrowing reappears in the DERIVED artefacts (onboarding/workflow map, feature docs) after
  the ADR itself is worded correctly, so review a diff's docs against the ADR in the same
  pass: a doc sentence saying the relaxation applies "offline, and only there" is refuted by
  the ADR paragraph beside it. And never write that a stale absence merely
  "degrades to the cautious floor": `null` and `throw` from a profile read reach OPPOSITE
  verdicts (`ProfileLookup.missing` SKIPS the member from the allergen union; `unavailable`
  applies the BUT-1663 floor), so absence is the LESS safe of the two. Negative entries persist
  as long as the app configures persistence (here 100MB LRU on every platform, web included),
  so "stale until LRU or a server read" is the honest wording. Offline, the read half is only
  half the feature: an awaited `set()` never completes until the server acks. A parser/lookup that can
  turn 1 input into N reads needs a cap at the split site.
- A read-failed FLAG is only half the repair: the same object's public SCOPE getter
  (`currentWeekStart`, the id/date a sibling VM is handed to write against) usually falls
  back to a DEFAULT — today's week, the current user — the moment its loaded entity is null,
  so a refused write path still exports a plausible WRONG TARGET to whoever asks. Keep the
  requested scope in its own field, set BEFORE the read, and order the getter
  loaded ?? requested ?? default. Check it cannot disagree with the screen: it must be
  consulted only while the loaded entity is null, and that is exactly the state the
  error branch renders (error-first precedence, no header) — verify the branch, don't assume.
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
  client-side timeout, not proof of offline — so a network-code SET reused to pick USER COPY
  (one set feeding both a message mapper and an `isNetworkError` decision) turns a timeout on
  a connected device into a sentence asserting the app is offline. Tolerable where both
  branches refuse identically and only the advice differs; grade the SENTENCE, not the branch.
  Its repair is a SUBSET split — a narrow `_offlineCodes` const set spread into the wide one,
  the copy mapper still reading the WIDE set (behaviour-neutral, pin each code) and only the
  DECISION reading the narrow one. Two things to check after it: the wide predicate is
  usually left with ZERO callers while its doc still promises "one place so callers cannot
  drift", and a sibling module may hold a PRIVATE set of the same name with different
  contents (`shopping_repository_routing_module` keeps `deadline-exceeded` in its offline
  fallback, BUT-1683) — "the offline codes" is not one fact in this repo.
  The offline-safe repair for a WRITE is a field-level MERGE
  primitive (`FieldValue.arrayUnion` for an append); a change to an EXISTING row has none.
  Enforcement shape: a `toFirestore()` diff that THROWS on any differing key outside a
  narrow whitelist rather than falling back to a full write (which re-sends a stale ACL) —
  mutation-test such a guard on the WHOLE test file, never a name-scoped single test.
- Per-item analytics loops over a REPLACEMENT set double-count on regeneration — log once
  with a count. A consent check with no in-flight dedupe means N fire-and-forget events on a
  cold cache issue N concurrent reads — wrap the whole emit in one `unawaited(...)`.

