# firebase-backend-security — chapter: pii-logging-platform

- An EXEMPTION inside a sanitizer (the one branch that KEEPS hostile markup) is graded by
  what it matches, not by what it names. A regex over a raw opening tag is an
  attribute-VALUE substring match unless BOTH ends are anchored: `\b` does not bound an
  attribute NAME (`-`, `:` and `x-` are non-word, so `\btype=` fires on `data-type=`), and
  an unterminated value matches any suffix (`application/ld+jsonx`). Anchor with
  `(?<=[\s/])` and a value terminator `(?=["'\s;>]|$)`, measured against a decoy table —
  and pick the STRONGEST decoy for the test, because the plausible one (`data-type=`)
  passes while the implausible one (`data-note=`) is the one usually pinned. Any comment
  saying "only a real `type=` attribute exempts it", or that a raw-source regex is "the
  same decision as" a parsed-attribute equality helper, is a measured claim: run it.
- Grade an interpolated `$e` by its SINK and by the SHAPE OF THE READ, never by the word
  "exception." `AppLogger.warning` reaches `developer.log` only; `AppLogger.error` also
  reaches Crashlytics + analytics and runs the uid redactor, so promoting a log level is a
  privacy change. A `create_composite` index-hint URL carrying another user's uid can only
  come from a QUERY (a single-doc `get()` cannot produce that `FAILED_PRECONDITION`), and
  the error string must never reach the Art. 15 bundle — derive the export's warning from
  `error_code`, never copy `error`/`e.toString()` through verbatim.
### Age gating & minors (server-authoritative — protected category)
- Swedish legal floor is **15** (Dataskyddslagen 2 kap. 4§), not 13 (GDPR Art. 8). Enforce
  in `firestore.rules` itself — a Dart-layer check alone is advisory only.
- Gate on custom claim `request.auth.token.ageCompliant==true`, never a Firestore `get()`.
  Client must `getIdToken(forceRefresh:true)` after a compliant verdict or the first UGC
  write denies on a stale token (fail-safe: deny).
- `birthYear`/`isMinor` immutability: rule compares old vs new on UPDATE (holds under
  merge) AND requires null on CREATE. An idempotent-retry branch must NOT recompute either
  from the request payload once stored, or a retry with a different birthYear can flip
  `isMinor` back to false.
- Rejection-path audit rows must never link a real identity to "is under 15" (operation/
  reason/basis/timestamp + hashed hour-bucket only); compliant-row audit stores
  `userIdHash` + coarse `birthDecade`, never raw birthYear.
- `isSearchable` for minors has ONE chokepoint (`UserProfile.toFirestore()`), backed by an
  explicit rules hard-deny on a minor setting it true server-side — a legacy `true` isn't
  force-corrected by the rule itself, only the next full save. `isMinor` must be mirrored
  via `public_profiles`/settings, never left only on `users/{uid}` (see the two-doc
  architecture fact); a save must re-read the AUTHORITATIVE server value before it can make
  a minor MORE discoverable.
- Minor-specific analytics minimisation needs EVERY writer of the gating property grepped,
  not just the primary setter. A group-safety CF removing a minor must delete every mirror
  the app's own client removal path touches (membership doc, per-user maps, participants
  subcollection).

### PII handling & logging
- Bounded enum/numeric telemetry (error codes, token counts, `schemaVersion`) is safe to
  log — the leak surface is the adjacent free-text field; bound length even for "should be
  small" fields.
- `AppLogger.error` is not device-local — it forwards the raw `e` object to Crashlytics and
  `error.toString()` to analytics, and the uid redactor applies to the MESSAGE string only.
  Never assume "stays on the device"; think before logging an exception whose text embeds a
  query built from a uid (a `memberPermissions.<uid>` index-hint URL is the realistic
  shape). A Dart-core throw (`StateError`, `Exception`) is NOT covered by the exception
  classes that mask in `toString()` — mask at the throw site.
- On WEB Crashlytics is skipped, so `WebErrorReporter` is the only sink, and a "mask the
  message, leave the STACK readable" carve-out there does not hold: a web `StackTrace`
  is the JS engine's `Error.stack`, whose HEAD line is the exception's own `toString()` —
  re-exporting every identifier the message field just masked. Mask the head up to the
  first frame; frames stay raw (the {20,28} uid rule eats class names). Mask BEFORE
  truncating: a cap applied first cuts a 28-char uid below the window (passes RAW) and
  re-hashes a `direct_` id out of parity with the same conversation elsewhere — that, and
  NOT capacity, is the reason for the order, because scrubbing can LENGTHEN
  (`[PERSONNUMMER]` is 14 chars for an 11-13 char match).
- A head/frame SPLIT covers only the line-prefixed engines — V8 `at `, Dart `#N`.
  SpiderMonkey/JSC emit `fn@url:line:col` with no header line, so those traces match no
  frame and are masked WHOLE (safe, but every frame mangled on Firefox/Safari), and a
  message line beginning `#1`/`at ` splits early, dropping its tail outside the mask.
  Probe any such regex against all three engine spellings before writing "both spellings
  the web engines emit."
- A log line's PII profile changes when its function gains a new CALLER, with no edit to
  the logging code. A composite doc id (`direct_{uidA}_{uidB}`, `{uid}_{date}`) is personal
  data wherever it lands; hash it through one chokepoint helper. `\b` treats `_` as a word
  character, so it never fires inside such an id — run the regex on the exact shape rather
  than reading it, and note a raw-uid log guard misses structured args
  (`AppLogger.x({'uid': uid})`). A mask helper NAMED FOR ONE ID SHAPE
  (`maskConversationId`, `direct_` only) is the IDENTITY function on every other shape, so a
  comment saying "masked" is a claim about which shapes can REACH that call — measure the
  reachable value class, and reach for `maskIdentifiers` when a uid can arrive. The INVERSE
  wording ("it redacts nothing here, this branch only ever holds <shape>") is the same
  caller-invariant-as-fact claim, and on a GUARD branch it is worse: that branch is entered
  exactly when the invariant is violated, so its value class is the one nothing constrains
  (here a doc-body field the model parses from stored data, defaulting to `''` — for which
  the helper returns `[empty]`, not identity). Strike such a clause; do not reword it. The
  mask at the THROW SITE is nonetheless the only one an exception OBJECT gets —
  `AppLogger.error` sanitizes the message string only and hands `error` to `recordError`
  untouched — so keeping the call while striking the sentence is right.
- A field on a world-readable doc must be audited individually — a boolean gating SEARCH
  does not gate DIRECT-FETCH. A moderation "hide" flag is search-suppression + UI-
  placeholder only unless every direct-fetch consumer also filters it. A presence opt-out
  must freeze the source write, not just gate a boolean — a hidden dot with an advancing
  `lastActiveAt` still leaks "active N min ago."
- Scrubber regexes: ASCII `\b` misfires before å/ä/ö; an unbounded leading letter-class
  before a literal suffix is O(n²) regex-DoS; case-sensitive heuristics no-op on ALL-CAPS.
- Any user string interpolated into an LLM prompt must be type-checked, trimmed, stripped
  of sentence-forming punctuation, and fail-undefined when absent.

### LLM / Vertex / prompt safety
- Kill-switches: master server gate fails CLOSED; a client-side Remote Config shortcut can
  fail open. An uninvalidated module-scope cache can serve stale config for the warm-
  instance lifetime — hours, not an optimistic "~30 min".
- Treat raw LLM output as adversarial: bounded parsers only, enum-drift logging capped, and
  verify no consumer branches a decision off a cost/telemetry field before calling it
  "telemetry-only." A locale/variant string reaching only telemetry has zero injection
  surface — confirm by grepping every actual caller.
- Model-integrity gates sit BEFORE any disk write/cache-path assignment; a cache-path LOAD
  skips re-verification only when the threat model is transit/storage substitution. A
  result's "ok" can be true while "unverified" is also true — callers must check both.

### Storage / uploads
- Storage download URLs are percent-encoded — `Uri.decodeFull` before string-matching
  against unencoded segment literals. Upload/delete authorization should funnel through
  exactly ONE low-level write method so one validation gate covers every entry point. A
  negative-permission storage test asserting only `isNull` proves nothing — assert the side
  effect directly (bytes did NOT land at the foreign path), paired with a positive control.

