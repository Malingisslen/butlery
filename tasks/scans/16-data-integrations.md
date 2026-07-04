# Data / Integrations Engineer — scan findings

Lens: ROLE_RESPONSIBILITY_MAP §16 (external-call resilience — circuit breakers,
timeouts, retries; Algolia error handling; LLM/extraction/import pipelines; PII
scrubbing before LLM; cost protection). Owned paths only.

Reviewed: lib/core/circuit_breaker.dart, lib/repositories/algolia/algolia_search_repository.dart,
lib/services/extraction/extraction_manager.dart, lib/services/import/import_rate_limiter.dart
+ models/rate_limit_models.dart, lib/services/llm/llm_service.dart + pii_scrubber.dart,
lib/services/parsing/tiers/llm_tier.dart. Cross-read: lib/core/utils/retry_helper.dart,
lib/utils/retry_policy.dart, lib/services/llm/llm_models.dart, lib/services/extraction/web_scraper.dart.

Dedup checked against tasks/_scan_dedup_titles.txt, .claude/linear-tracker.json
(noted overlaps: BUT-566 "Document retry policy for Gemini 5xx", BUT-589 circuit
breaker, BUT-580 Algolia EU, BUT-963 "Differentiate LLM extraction error types",
BUT-534 URL-fragment scrub), accepted-deviations.md, and §16 dossier watch-items
(OCR cost-tracking race, LlmTier missing rate-limit precheck, Algolia EU-only-at-
construction, SocialMediaExtractor not rate-limited). None of the findings below
restate those.

---

### LlmTier wraps structureRecipe in a retry that re-fires on rate-limit / invalid-argument errors (retry storm + cost/Firestore waste)
- type: bug  area: backend
- pass: 1
- finding / why / fix:
  `LlmTier.parse()` wraps `llmService.structureRecipe(...)` in
  `RetryHelper.retryNetworkOperation(..., maxRetries: 2)`
  (llm_tier.dart:101-109). That predicate (retry_helper.dart:194-209) classifies
  retryability by substring-matching `error.toString()` against English Firebase
  codes (`unavailable`, `deadline-exceeded`, `unauthenticated`,
  `permission-denied`, `invalid-argument`) and **defaults to `return true` for
  anything unmatched**. But by the time the error reaches LlmTier it is already an
  `LlmException`, and `LlmException.toString()` returns only
  `'LlmException: <localized Swedish message>'` (llm_models.dart:374-375) — the
  English code was consumed inside `LlmException.fromFirebase`
  (llm_models.dart:378-420), which maps `resource-exhausted`/`unavailable`/etc.
  into Swedish copy (e.g. `llmServiceOverloaded`, `llmTemporarilyUnavailable`,
  `llmInvalidArgument`). So none of the predicate's English substrings match, the
  `true` default fires, and **every** LlmException is retried — including
  rate-limit denials (`isRateLimited: true`) and `invalid-argument` (a permanent
  caller error). Each retry re-enters `structureRecipe`, paying another
  consent check + a Firestore rate-limit read (import_rate_limiter.dart:104) and,
  if the breaker is closed, another callable attempt. The exact opposite of the
  intent: a denied/overloaded backend gets hammered 3×. This also defeats the
  BUT-589 circuit breaker's "short-circuit before paying I/O" goal for the
  retry path.
  Fix: pass an explicit `shouldRetry` to the retry that inspects the typed
  exception, not its string — e.g. retry only when `e is LlmException &&
  e.code == 'unavailable' || e.code == 'deadline-exceeded'` and NEVER when
  `e.isRateLimited` or `e.code == 'invalid-argument'`. Better: switch this
  call site to the typed `withRetry` in lib/utils/retry_policy.dart with a
  bespoke predicate (that helper at least rethrows on non-match rather than
  defaulting to retry). Distinct from BUT-566 (which is a *documentation*
  ticket); this is a concrete behavioral bug.

### recordUsage runs inside the rate-limit-check exception's fail-closed path is fine, but recordUsage itself swallows transaction failure with no retry → silent cost-tracking gap on the success path
- type: bug  area: backend
- pass: 1
- finding / why / fix:
  `_executeLlmCall` records a SUCCESSFUL, already-billed Gemini call by awaiting
  `_rateLimiter.recordUsage(operation, llmCost: cost)` (llm_service.dart:363).
  `recordUsage` wraps the counter increment in a Firestore transaction and, on
  any failure, only logs and returns (import_rate_limiter.dart:104-126) — no
  retry, no compensating write, no surfaced error. So when the callable succeeds
  (cost already incurred at Google) but the transaction fails (transient
  `unavailable`/`aborted`, offline, contention), the spend is permanently
  untracked: the daily/monthly budget counters under-count and the
  `llmCostPerDay`/`llmCostPerMonth` ceilings (rate_limit_models.dart:303-304) can
  be overrun. The §16 dossier flags this for the OCR path specifically; it is
  actually the shared `_executeLlmCall` path, so it affects extraction, vision,
  AND ingredient-line calls — and the right scope is "wrap recordUsage's
  transaction in a bounded retry on aborted/unavailable", not a per-call-site
  fix. Firestore transactions auto-retry on contention but not on the catch here
  swallowing a thrown `unavailable`.
  Fix: give `recordUsage`'s `runTransaction` a small bounded retry on transient
  codes (or use `FieldValue.increment` with a merge-set so a single failed write
  can be replayed idempotently), and emit an analytics/`AppLogger.error` signal
  when cost recording ultimately fails so leakage is observable rather than
  silent.

### Algolia recipe/user SEARCH swallows all errors and returns empty results — indistinguishable from "0 hits" (no fallback signal to caller)
- type: bug  area: backend
- pass: 1
- finding / why / fix:
  `searchRecipes` and `searchUsers` catch every exception and return an empty
  `SearchResult` with `totalHits: 0` (algolia_search_repository.dart:211-220,
  259-268). The caller cannot tell "Algolia is down / DNS failed / pin mismatch"
  from "the query legitimately matched nothing", so the UI shows a neutral empty
  state instead of an error/offline state and — critically — there is no signal
  to fall back to the Firestore client-side search the repo's own header docstring
  says is the fallback ("DI module can catch and fall back to Firestore search",
  lines 121-122; that catch only covers the *construction* `ArgumentError`, not
  per-query failure). On a pin mismatch the `PinningDioInterceptor` rejects the
  request (line 147-149) and the user silently sees zero recipes. `indexRecipe`/
  `removeRecipe`/`batch`/`indexUser` correctly `rethrow` (lines 290-293, 304-307,
  378-381) — only the read paths swallow, so the asymmetry is deliberate per
  BUT-1130 but leaves the read side with no observability or degraded-mode hook.
  Fix: distinguish failure from empty — either return a result that carries a
  `degraded`/`error` flag (so the ViewModel can show an offline banner and/or
  trigger Firestore fallback) or log an analytics `algolia_search_failed` event
  in the catch. At minimum surface the failure so the silent-empty UX is
  intentional and measurable. (Not BUT-580, which is the EU/anonymize concern.)

### Three competing retry helpers with divergent semantics across the integration layer
- type: tech-debt  area: backend
- pass: 1
- finding / why / fix:
  The owned integration code reaches for three different retry utilities with
  materially different safety properties:
  (1) `lib/utils/retry_policy.dart#withRetry` — typed predicate, **rethrows on
  non-match**, jitter, used by ExtractionManager (extraction_manager.dart:114);
  (2) `lib/core/utils/retry_helper.dart#retryNetworkOperation` — string-match
  predicate, **defaults to retry on unknown**, no jitter, used by LlmTier
  (llm_tier.dart:101); (3) `CircuitBreaker.execute` (circuit_breaker.dart:103).
  The string-matching variant (2) is the one that produces the retry-storm bug
  above and has no jitter (thundering-herd risk on a shared Gemini outage where
  many clients retry in lockstep). Having two general retry helpers with opposite
  defaults (rethrow-on-unknown vs retry-on-unknown) is a footgun: a future caller
  picking (2) inherits the unsafe default silently.
  Fix: standardize integration retries on the jittered, rethrow-on-unknown
  `retry_policy.dart#withRetry` and deprecate `retry_helper.dart`'s
  string-matching network/Firebase variants (or at minimum flip their default to
  `false` and document them as legacy). Lower priority than the two bugs above
  but they share a root cause.

---

### scrubPayload does not scrub Map/List values nested under an `imageBase64`-style opaque key, and only `imageBase64` is treated as opaque
- type: bug  area: security
- pass: 2
- finding / why / fix:
  `scrubPayload` skips scrubbing for keys in `_opaqueKeys = {'imageBase64'}`
  (pii_scrubber.dart:218, 231). That set is a single hard-coded key. The OCR
  request builders can carry image data under other shapes, and any future
  payload field holding a base64 blob under a differently-named key (e.g.
  `image`, `bytes`, `photo`, `attachment`) would be run through the PII regexes —
  wasted CPU on large blobs and, per the code's own comment (lines 215-217), a
  small corruption risk if the base64 alphabet coincidentally forms an
  `@`-neighborhood the email regex mangles. Conversely, a genuine PII field
  nested *inside* a value whose key merely contains `url` only gets `scrubPii`,
  not recursion — but a Map value under a URL-ish key isn't recursed at all
  because the `key.contains('url')` branch (line 235) only handles `String`
  values; a `Map`/`List` under such a key falls through to the generic Map/List
  recursion, which is correct — so that part is fine. The real gap is the
  single-element opaque-key allowlist being brittle and unsynced with the actual
  request models.
  Fix: derive `_opaqueKeys` from the real LLM request field names (or detect
  base64-blob-shaped values by length + alphabet heuristic rather than by key
  name), and add a parity case to pii_scrubber_test.dart / pii-scrubber.test.ts
  so the Dart and TS opaque-key sets can't drift.

### List-valued payload fields skip URL scrubbing — a list of source URLs reaches Cloud Logging with query params/opaque tokens intact
- type: bug  area: security
- pass: 2
- finding / why / fix:
  `_scrubValue`'s List branch (pii_scrubber.dart:243-249) applies only
  `scrubPii(v)` to string list elements — it does NOT apply `scrubUrlParams`,
  unlike the scalar-string branch which checks `key.contains('url')` and runs
  `scrubPii(scrubUrlParams(value))` (lines 235-237). So a payload field that is a
  *list* of URLs (e.g. multiple source links, image URLs threaded into an LLM
  prompt) keeps its query strings, path-embedded session tokens, and opaque
  fragments — exactly the leakage BUT-692/BUT-765/BUT-534 closed for scalar URL
  fields. The defence-in-depth promise (scrub before Cloud Logging ingests the
  raw callable payload, pii_scrubber.dart:3-6) is therefore unmet for list URLs.
  Fix: in the List branch, detect URL-shaped strings (or pass the parent key
  down) and run `scrubUrlParams` on them too, mirroring the scalar path. Add a
  vector to the shared parity fixture so TS stays aligned.

### scrubPii heuristics (street address, relation+name) never run on URL-derived strings, and personnummer/phone scrubbing isn't applied to the path segments scrubUrlParams keeps
- type: bug  area: security
- pass: 2
- finding / why / fix:
  For URL fields the order is `scrubPii(scrubUrlParams(value))`
  (pii_scrubber.dart:236): `scrubUrlParams` only redacts *opaque* path segments
  (`_looksOpaquePathSegment` requires length ≥20 + url-safe alphabet + UUID/long-
  run, lines 208-213) and strips the query entirely. A human-readable path
  segment like `/recept/anna-andersson-pannkakor/` or
  `/u/070-123-45-67/` survives `scrubUrlParams` (it's a readable slug, not
  opaque), and then `scrubPii` runs on the whole resulting URL string — but the
  RULE-A street and RULE-B relation/name heuristics depend on space-separated
  tokens (`\s+` between street name and house number, between trigger and name;
  pii_scrubber.dart:92, 111). URL path segments are hyphen/slash-joined, so
  `storgatan-14` and `mormor-anna` never match the address/name regexes even
  though the equivalent free text would be scrubbed. Net: PII embedded in
  readable URL slugs (a real shape for share/import source URLs) leaks to Cloud
  Logging despite both scrubbers running.
  Fix: either (a) tokenize URL path/slug segments on `-`/`_`/`/` before applying
  the street/name heuristics, or (b) accept the gap explicitly and record it in
  accepted-deviations.md so it stops reading as an oversight (the docstring
  already calls the URL scrubber "heuristic, not exhaustive" at lines 137-141 —
  but the PII-in-slug case specifically is not called out and is higher-stakes
  than tracker tokens). Verify which against a real import URL corpus first.

### CircuitBreaker.allowRequest mutates state from a getter; concurrent in-flight calls can all pass the half-open gate (no single-probe guarantee)
- type: bug  area: backend
- pass: 2
- finding / why / fix:
  The breaker's contract (circuit_breaker.dart:9-11) promises half-open =
  "one request allowed to test recovery". But `allowRequest` is a getter that
  sets `_isHalfOpen = true` and returns `true` (lines 42-55) without any
  in-flight counter. In Dart's single-isolate model two awaiting callers can both
  evaluate `allowRequest` before either records success/failure, so on the
  recovery boundary **N queued LLM calls all pass simultaneously** and hit the
  recovering Gemini backend at once — defeating the "single probe" intent and
  re-creating the pile-up BUT-589 was meant to prevent, precisely at the moment
  the backend is most fragile. The breaker is shared across all LLM ops
  (llm_service.dart:49) so the queue can be deep. Also a side-effecting getter is
  a maintenance trap (reads look pure but flip state).
  Fix: add a half-open in-flight guard — once a probe is dispatched, return
  `false` from `allowRequest` until that probe resolves (recordSuccess/Failure).
  Convert `allowRequest` to a method to make the state mutation explicit. Add a
  unit test for "two concurrent calls at the reset boundary → only one probes".

### ExtractionManager retries the full headless-browser scrape 3× on transient errors — up to ~45s and 3 webview spin-ups, no per-attempt cost/UX signal
- type: tech-debt  area: import
- pass: 2
- finding / why / fix:
  `extractFromUrl` wraps `_webScraper.performExtraction` in
  `withRetry(maxAttempts: 3)` (extraction_manager.dart:114-117). Each
  `performExtraction` instantiates a `HeadlessInAppWebView` with a 15s internal
  timeout (web_scraper.dart:25, 78-80). On a throwing transient (SocketException
  etc.) the retry re-runs the whole headless scrape, so worst case is ~45s of
  user wait plus three browser instantiations/teardowns — expensive on mobile and
  with no progress signal to the user mid-retry. A timeout that *returns* an
  unsuccessful result (not throws) is correctly not retried, so the blast radius
  is bounded to genuinely-thrown network errors, which is why this is tech-debt
  not a bug. Worth noting alongside the §16 dossier item that this path is also
  not rate-limited (so a user can trigger many of these back-to-back).
  Fix: drop `maxAttempts` to 2 for the headless path, or short-circuit the retry
  when the failure is the 15s timeout (already handled internally) so only true
  connection failures retry; surface a "still trying…" signal if a retry is in
  flight.

---

COVERAGE: 2 passes complete. Owned paths fully read. 9 NEW findings (4 pass-1,
5 pass-2): the LlmTier string-match retry storm (highest priority — concrete
cost+I/O bug), silent cost-tracking gap in recordUsage, Algolia search
swallow-to-empty, retry-helper proliferation; plus PII scrubber gaps (opaque-key
brittleness, list-URL scrub miss, PII-in-slug leak), the half-open concurrent-probe
breaker race, and the headless-scrape retry cost. No overlap with BUT-566/580/589/
963/534, accepted-deviations.md, or the four §16 dossier watch-items.
