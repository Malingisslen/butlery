# SUBSYSTEM MAP: import

I have enough material now. Producing the deep structural map.

## Purpose & entry points

`lib/services/import/` implements Butlery's "import ANY recipe from ANY source" pipeline: normalize arbitrary input (URL, pasted text, photo, file, archive lookup, YouTube/TikTok/Instagram links) into a `Recipe` model, with multi-tier fallback (structured data → scraping → text heuristics → LLM → user-assisted) and cost-aware rate limiting.

- **`ImportManager`** (`lib/services/import/import_manager.dart:33`) is the single entry point used by ViewModels: `autoImport`, `autoParseOnly`, `autoParseMulti`, `batchImport`, `importWithStrategy`. It owns strategy priority order and orchestrates cache/rate-limit/tagging around each strategy.
- Five `ImportStrategy` implementations are registered in `_initializeStrategies` (`import_manager.dart:131-142`): `ArchiveImportStrategy`, `UrlImportStrategy`, `TextImportStrategy`, `FileImportStrategy`, `PhotoImportStrategy`.
- Three URL "pipelines" bypass the generic strategy list and are checked explicitly and first in `autoImport`: `YouTubeImportStrategy`, `TikTokPipeline`, `InstagramPipeline` (`import_manager.dart:222-281`) — these are platform-specific because they need caption/transcript extraction rather than HTML scraping.

## Flow (step-by-step)

`ImportManager.autoImport(input)` (`import_manager.dart:195`):
1. Rate-limit check via `ImportRateLimiter.checkLimit` (basic op) — denies before any network work (`:203-212`).
2. `_checkCacheForUrl` — if input looks like a URL (`UrlNormalizer.looksLikeUrl`), look up `GlobalRecipeCache.findByUrl`; on hit, optionally retag (`_cachedRecipeNeedsRetagging` / `_retagCachedRecipe`, 30-day TTL) and return without saving (`:690-751`, `:835-887`).
3. If YouTube URL → `YouTubeImportStrategy` (own module, not detailed here); terminal (success/assistance/screenshot) — never falls through to WebScraper (`:222-254`).
4. Else if TikTok URL → `TikTokPipeline` (`:256-266`).
5. Else if Instagram URL → `InstagramPipeline` (`:268-281`).
6. Else caller's `preferredStrategy`, then the 5 registered strategies in order, first `canHandle` match tried (`:283-315`). A `needsAssistance` result is terminal (Tier-7 recovery), not a fallback trigger.
7. `_parseWithStrategy` (`:602-671`) wraps strategy execution: propagates `needsAssistance`, converts failure/success, and — HIGH-1 — generates a Phase-1 tagging preview (`TaggingService.generatePhase1Preview`) so allergen/dietary badges show before the user saves.
8. On success, `_saveToCacheIfUrl` records rate-limit usage and (for URL-like input, not already-from-cache) writes to `GlobalRecipeCache` with `ExtractionMeta` (pipeline/tier/method) — note `tier: 0` is hardcoded with a `// Phase 4 will add proper tier tracking` comment (`:786-791`).
9. Recipe is **not saved** here — `autoImport`/`autoParseOnly` are parse-only; the caller (ViewModel) calls `saveImportedRecipe` (`:578`) after user review in the editor.

**`UrlImportStrategy.import`** (`url_import_strategy.dart:98`) — the deepest single strategy, 7 tiers per URL:
1. `HttpContentFetcher.fetchHtmlWithTimeout` (simple HTTP, SSRF-guarded) → HTML.
2. Tier 1: `RecipeParserService.parseFromUrl` (the "enhanced parser" — CRF/ML pipeline, external to this dir) on the HTTP HTML (`:114`).
3. Tier 2: `_tryStructuredExtraction` — site-specific parser (`SiteParserRegistry`) or generic schema.org JSON-LD via `extractRecipeFromHtml` → `SchemaOrgRecipeExtractor.createRecipe` (`:224-253`).
4. Tier 3: if tiers 1-2 failed, fetch via headless `WebScraper` (`HttpContentFetcher.tryWebScraperHtml`) and retry tiers 1+2 on that HTML (`:126-148`) — covers JS-rendered/HTTP-blocking sites.
5. Tier 4: `_tryWebScraperFallback` — WebScraper's own text extraction fed into `TextImportStrategy` (`:255-284`).
6. Tier 5: `_tryHtmlTextParse` — strip HTML to plain text (`HtmlSanitizer.stripToPlainText`) and feed to `TextImportStrategy`; gated on non-empty ingredients+instructions, else falls through (`:286-333`).
7. Tier 6: `LlmExtractionFallback.tryExtraction` (LLM call, only if `LlmEnhancementService.isAvailable()`) (`:169-180`).
8. Tier 7: `_createUserAssistedResult` — returns extracted plain text + a title guess + likely-ingredient lines for manual completion, never a hard failure if ≥50 chars of text exist (`:390-406`).
9. Every tier logs a `ParseEventLogger` event with domain/tier/success/timing (`:429-446`).

**`TextImportStrategy.import`** (`text_import_strategy.dart:50`) — pure regex/heuristic recipe parser, no async/LLM:
1. `normalizeText` + `TextImportNormalizer.preprocessText`.
2. `_parseTextToRecipe`: Stage 1 measurement-first ingredient extraction (regex over unit allowlist, `_extractIngredientsByMeasurement`, `:226`), Stage 2 title extraction (`_extractTitleFromText`, handles Instagram-style captions/usernames/emoji), Stage 3 line-by-line state-machine classification (ingredients/instructions sections via `RecipeSectionDetector`), Stage 4 dedup + cleanup + logging when empty.
3. Builds `Recipe` with `structuredIngredients` derived via `StructuredIngredientDeriver.deriveAll` (BUT-1232).

**`PhotoImportStrategy.import`** (`photo_import_strategy.dart:110`):
1. Extract bytes from `options['imageBytes']` or base64.
2. HEIC magic-byte detect → `HeicConverter.convertToJpegIfHeic`.
3. `OCRExtractionService.extractText` (multi-provider: OCR.space → Google Vision → Tesseract, external to this dir).
4. On OCR failure/empty text/unparseable text at each step, tries `LlmEnhancementService.extractFromImage` (vision fallback, Tier 4) before giving up (`_tryLlmFallback`, `:292-347`).
5. On OCR success, delegates parsing to `TextImportStrategy.import(ocrResult.text)` — photo import is OCR + the same text parser, not a separate parser.

**`InstagramPipeline.importV2`** (`pipelines/instagram_pipeline.dart:70`) — 4-tier: WebScraper caption extraction → `LlmEnhancementService.extractFromTranscript` → assisted-import with extracted caption (if LLM rate-limited or text too short to structure) → `ImportNeedsScreenshot` if no caption at all.

**`ArchiveImportStrategy`** — pure in-memory lookup against `butlery/data/archived_recipes.dart` by ID or `archive:name` prefix; deliberately drops the source's `tagResult` so tags regenerate fresh (`archive_import_strategy.dart:87-89`).

**`MultiRecipeSplitter.split`** (`multi_recipe_splitter.dart:45`) — deterministic, rule-based (no LLM) cookbook-page splitter used by `ImportManager.autoParseMulti`: scans for title-like lines followed by an ingredient cluster within an 8-line lookahead, only opens a new block once the current one is "complete" (has both ingredients and an instruction signal), caps at 12 blocks, falls back to `[input]` unchanged if <2 confident blocks found.

**`IndexPageDetector` / `IndexPageExpander`** — offer batch-import expansion: given a listing/collection URL, `IndexPageExpander.harvest` fetches it (SSRF-guarded) and `IndexPageDetector.extractRecipeLinks` regex-scans anchors, filtering nav/utility segments and requiring a slug-like final path segment, capped at 50 links, only "offered" if ≥5 candidates found (`defaultMinLinks`).

## Data shapes (inputs/outputs, key models, where the shape changes)

- **`ImportResult`** (`import_strategy.dart`) — per-strategy result: `success(recipe, warnings, metadata)` / `failure(message, ...)` / `assistance(extractedText, suggestedTitle, likelyIngredientLines, ...)`.
- **`ImportManagerResult`** (`import_manager_result.dart`) — manager-level wrapper adding `rateLimit(RateLimitDenied)` as a fourth outcome; `import_manager.dart` converts `ImportResult` → `ImportManagerResult` in `_parseWithStrategy`.
- **`ImportResultV2`** (`models/import_result_v2.dart`) — a richer sealed hierarchy (`ImportSuccess`/`ImportNeedsAssistance`/`ImportNeedsScreenshot`/`ImportPartial`/`ImportFailure`) used by the newer pipelines (`InstagramPipeline`, `TikTokPipeline`, `LlmEnhancementService`, `PhotoImportStrategy`'s LLM fallback) and always converted back down to legacy `ImportResult` at the pipeline boundary (`instagram_pipeline.dart:181-221`). **Two parallel result vocabularies coexist** — see Quality Observations.
- **`Recipe`/`RecipeCore`** (`models/recipe_unified.dart`) is the universal output shape all strategies converge on; `SourceArtefact` (payload + type: `url`/`textPaste`/`photoOcr`/`instagramCaption`) is attached so re-extraction can replay without re-fetching.
- **`CacheEntry`/`ExtractionMeta`** (`cache/cache_entry.dart`) — cache-layer shape: raw `recipe` JSON + pipeline/tier/method/confidence metadata + domain/sourceType/age.
- **`UsageLimits`** (`models/rate_limit_models.dart`) — Firestore-persisted counters (imports per minute/hour/day, LLM ops/cost per day/month) — shape changes at the Firestore boundary via `fromFirestore`/`toFirestore`.
- Ingredient shape changes twice: raw OCR/HTML string → `RecipeIngredient` structured form via `RecipeIngredient.fromParsed` (URL path, `url_import_strategy.dart:473-475`) or `StructuredIngredientDeriver.deriveAll` (text path, `text_import_strategy.dart:481-483`) — two different derivation code paths for the same target shape.

## Config & thresholds (magic numbers, remote config, seeds)

- Rate limits (`models/rate_limit_models.dart:293-308`): 10/min, 30/hour, 100/day basic imports; LLM: 20 enhancements/day, 10 extractions/day, 10 vision/day, 3/min & 10/hour LLM ops; cost ceilings $0.50/day, $10.00/month.
- `ImportRateLimiter._cacheDuration` = 30s in-memory usage cache (`import_rate_limiter.dart:37`).
- `ImportRateLimiter` retry: `maxRetries: 3`, `baseDelay` 1s for the usage-write transaction (`:135-138`).
- `ImportManager._batchConcurrencyLimit` = 5 parallel imports; circuit breaker aborts batch if ≥8/last-10 fail (`import_manager.dart:401-405`).
- Cache retagging TTL: 30 days (`import_manager.dart:843`).
- `HttpContentFetcher`: 10s fetch timeout, 5 MB response cap, blocked-host/DNS-rebinding SSRF guard covering RFC1918 + link-local + loopback (IPv4 and IPv6) (`fetchers/http_content_fetcher.dart:14-16, 32-79`).
- `PhotoImportStrategy` OCR confidence bands: high ≥0.85, medium ≥0.70, low ≥0.50 (`photo_import_strategy.dart:66-68`).
- `MultiRecipeSplitter`: lookahead 8 lines, min block 40 chars, max 12 blocks, min 2 ingredient lines (`multi_recipe_splitter.dart:20-30`).
- `IndexPageDetector`: max 50 links, min 5 links to treat as an index page (`index_page_detector.dart:19-25`).
- `ExtractedContentAnalyzer` scoring: ingredients +25, instructions +25, time +15, portions +10, length>500 +15 (length<200 penalized), recipe-keyword +10; quality bands excellent≥75/good≥50/fair≥25/poor (`extracted_content_analyzer.dart:26-84`).
- No remote-config values found in this subtree — all thresholds are hardcoded Dart constants (no Firebase Remote Config reads observed).

## Coupling (upstream/downstream, hidden dependencies)

**Upstream feeds:**
- `PersonalRecipeOperations` (constructor-injected into `ImportManager`) — the only way parsed recipes actually persist (`saveImportedRecipe`).
- `TaggingService` (via `ServiceLocator`) — 5-phase auto-tagging engine; `ImportManager` calls `generatePhase1Preview` for immediate display and `generateTags` for cache retagging. If unavailable, import proceeds untagged with a warning-level log (`:123-127`) — a silent product-quality degradation, not a hard failure.
- `RecipeParserService` (ServiceLocator, from `services/parsing/`) — the CRF/ML "enhanced parser" that `UrlImportStrategy` tries first; this dir doesn't own it, just calls it.
- `WebScraper`/`PlatformDetector` (`services/extraction/`) — headless browser/platform-specific fetch used by `HttpContentFetcher`, `InstagramPipeline`, `TikTokPipeline`.
- `LlmEnhancementService` (`llm/llm_enhancement_service.dart`) — shared LLM gateway used by `LlmExtractionFallback` (URL), `PhotoImportStrategy` (vision), `InstagramPipeline`/`TikTokPipeline` (caption/transcript structuring). Single choke point for LLM cost.
- `OCRExtractionService` — external OCR provider chain, only touched by `PhotoImportStrategy`.
- `SiteParserRegistry` (`services/extraction/site_parsers/`) — per-domain scrapers, consulted before generic schema.org extraction.

**Downstream consumers:**
- ViewModels (`lib/viewmodels/...import*`) call `ImportManager` exclusively — no view/VM reaches into individual strategies except `getTextImportStrategy()` (explicit escape hatch, `import_manager.dart:562-572`) and direct construction of `IndexPageExpander`/`MultiRecipeSplitter` for UI-level features (index-page banner, multi-photo combine).
- `GlobalRecipeCache` and `UrlNormalizer` (`cache/`) — shared, resolved lazily via `ServiceLocator.tryGet`, gracefully degrade to "no cache" if unavailable (every accessor in `import_manager.dart` follows this try/catch/null pattern, e.g. `:56-129`).
- `ImportRateLimiter` reads/writes `/users/{userId}/rateLimits/imports` in Firestore directly — the only Firestore write in this subsystem's control flow (rate-limit + retag are the two async side channels beyond the parse itself).

**Hidden/non-obvious dependencies:**
- `ParsedRecipeCache` (`services/parsing/cache/`) is silently populated as a side effect of `UrlImportStrategy._convertParsedRecipeToImportResult` (`:454-458`) — a cross-cutting cache write buried in a strategy, not visible from `ImportManager`.
- `AppLocale.current` is read synchronously throughout (warnings, error messages) — import strategies are locale-coupled, meaning tests must set up locale context or these fields silently degrade to fallback text.
- `clock.now()` (package:clock) is used pervasively for testability — but not universally (e.g. `ArchiveImportStrategy` also uses `clock.now()` consistently; good).

## Quality observations

1. **Two parallel result-type vocabularies** — `ImportResult` (legacy, `import_strategy.dart`) and `ImportResultV2` (`models/import_result_v2.dart`, sealed with 5 subtypes). Every V2-native pipeline (`InstagramPipeline`, presumably `TikTokPipeline`) implements a `_convertToLegacyResult` adapter (`pipelines/instagram_pipeline.dart:181-221`) purely to satisfy the `ImportStrategy.import()` contract that `ImportManager` still consumes. This is real: `ImportManager` never sees V2 results directly even though `LlmEnhancementService` and `PhotoImportStrategy`'s LLM fallback speak V2 internally (`photo_import_strategy.dart:310-339`). Two parsers exist for the same conceptual outcome ("needs assistance", "success") and a future maintainer editing one easily forgets the other. Ownership of "which one is canonical" is unclear.
2. **Error swallowing via broad `catch (e) { return null }`** is the dominant failure-handling pattern across nearly every tier method — `UrlImportStrategy._tryWebScraperFallback`, `_tryHtmlTextParse`, `LlmExtractionFallback.tryExtraction` (`fallbacks/llm_extraction_fallback.dart:87-91`), `PhotoImportStrategy._tryLlmFallback` (`:341-346`). This is a deliberate "keep trying the next tier" design, but it means a genuine bug (e.g. a null-pointer in the LLM adapter) is indistinguishable from "LLM legitimately unavailable" — nothing surfaces to monitoring except a debug/warning log line, no metric increment differentiating exception-vs-expected-miss.
3. **`ImportManager._sourceTypeFromStrategy`** (`import_manager.dart:820-833`) infers cache `sourceType` from a **substring match on the strategy's display name** (`lower.contains('url')`, `.contains('youtube')`, etc.) rather than a typed enum on the strategy itself. Renaming a `strategyName` string (e.g. `'URL Import'` → `'Web Import'`) silently reclassifies cache entries with no compile-time signal.
4. **Hardcoded placeholder metadata**: `ExtractionMeta(tier: 0, ..., confidence: 0.8, ...)` in `_saveToCacheIfUrl` (`import_manager.dart:788, 790`) — both values are explicit stand-ins ("Phase 4 will add proper tier tracking", "Default confidence for now") that have apparently never been revisited; every cached entry reports the same fake confidence regardless of which of the 7 URL tiers actually succeeded, even though `UrlImportStrategy` itself tracks real tier numbers (`'tier': 4` for LLM, `'tier': 7` for user-assisted) that are simply discarded at the cache-write boundary.
5. **`FileImportStrategy.canHandle`/`validateInput` always return `false`** (`file_import_strategy.dart:37-46`) — by design (file picker driven, not text-driven), but this means `FileImportStrategy` is registered in `ImportManager._strategies` (`:139`) yet can **never** be reached through `autoImport`'s `canHandle` loop; it's dead weight in that list, only usable via `getTextImportStrategy()`-style direct access or `importFromContent`. A reader tracing `autoImport`'s strategy loop would reasonably conclude file import is wired in when it structurally cannot fire.
6. **`FileImportStrategy` also declares an unused `name` getter and a `calculateConfidence` method both explicitly commented `// @override removed - not in parent class`** (`file_import_strategy.dart:26-27, 48-52`) — vestigial API surface from a prior interface shape, dead code that should have been deleted rather than annotated.
7. **`TextImportStrategy` is entirely private-method regex heuristics with no unit boundary for individual stages** — `_parseTextToRecipe` (~200 lines, `:296-498`) runs 4 stages inline in one method with mutable shared state (`inIngredients`/`inInstructions`/`seenIngredientSections`). Tests exercise it black-box via `import()`; this makes the state machine hard to reason about incrementally and any regex tweak risks unintended cross-stage interaction (acknowledged implicitly by the extensive inline comments explaining ordering rationale, e.g. `:356-361`).
8. **Instagram/TikTok pipelines duplicate near-identical 4-tier structure** (WebScraper caption → LLM structuring → assisted → screenshot) — `instagram_pipeline.dart` (222 lines) vs `tiktok_pipeline.dart` (519 lines, not fully read but same tier comment structure per its docstring) — no shared base class beyond `ImportStrategy`; the `_convertToLegacyResult` switch statement is very likely duplicated verbatim between the two (would need to diff to confirm exact duplication, but the same 5-arm switch pattern is visible in Instagram's file).
9. **`ImportRateLimiter.checkLimit` fails closed on Firestore error** (deny with `retryAfter: 30s`, `:86-95`) but **`recordUsage` fails open** (logs an ERROR and gives up after 3 retries, `:148-158`) — i.e. an outage can simultaneously block all imports (check-time) yet, if the outage clears mid-operation, undercounts spend (record-time). The asymmetry is intentional per the inline BUT-1415 comment but worth flagging as an accepted-but-real gap in ceiling enforcement under transient Firestore instability.
10. **`_calculateConfidence` in `ImportManager`** (`:673-688`) is a stub — only distinguishes `ArchiveImportStrategy` (0.9) and `TextImportStrategy` (0.6), everything else gets a flat 0.5 default regardless of actual strategy quality; only used by `getImportSuggestions`, which appears to be a secondary/advisory API (not the main `autoImport` path), so low severity but a real half-implemented feature.

## Test coverage observed

- Direct unit tests exist per strategy: `text_import_strategy_test.dart`, `url_import_strategy_test.dart`, `photo_import_strategy_test.dart`, `archive_import_strategy_test.dart`, `file_import_strategy_parsing_test.dart` + `file_import_strategy_structure_test.dart`, `file_import_paprika_test.dart` — these pin per-strategy parsing behavior (title/ingredient/instruction extraction correctness) and failure/warning paths.
- `import_manager_test.dart` + `import_manager_multi_test.dart` — pin orchestration: strategy selection order, cache hit/miss, rate-limit denial propagation, `needsAssistance` terminal handling, batch circuit breaker.
- `multi_recipe_splitter_test.dart` — pins the deterministic split-vs-fallback-to-single-block behavior.
- `index_page_detector_test.dart` / `index_page_expander_test.dart` — pin link harvesting, utility-segment filtering, slug heuristics, min-link threshold.
- `ssrf_protection_test.dart` + `http_content_fetcher_client_reuse_test.dart` — pin the blocked-host/DNS-rebinding guard and client lifecycle (matches BUT-1078's DNS-lookup seam).
- `import_rate_limiter_test.dart` + `rate_limit_models_test.dart` — pin window resets, fail-closed/fail-open asymmetry, cost ceilings.
- `pipelines/instagram_pipeline_test.dart` / `pipelines/tiktok_pipeline_test.dart` — pin the 4-tier fallback chain per platform.
- `content_fingerprint_test.dart`, `cache/global_recipe_cache_test.dart`, `cache/url_normalizer_test.dart`, `decompression_guard_test.dart` — cover the cache subsystem.
- `youtube/youtube_import_strategy_test.dart`, `youtube/youtube_transcript_service_test.dart` — YouTube pipeline (not detailed above, out of this pass's read-depth but present).
- Integration coverage: `test/integration/import/import_end_to_end_test.dart`, `swedish_sites_integration_test.dart` (real-shaped Swedish recipe-site HTML fixtures), `test/integration/tagging/import_tagging_integration_test.dart` (import→tag pipeline join), `test/corpus/web_import_prelabel_test.dart` (the cookbook gold-corpus harness referenced in project memory).
- Journey/widget tests (`test/views/import_recipe_journey_test.dart`, `deep_link_import_journey_test.dart`, `photo_import_allergen_banner_journey_test.dart`) exercise the ViewModel-level flow end-to-end including UI feedback (allergen banners, confidence indicators).
- No test file found for `extracted_content_analyzer` scoring bands beyond `extracted_content_analyzer_test.dart` (exists, not read in depth) and none observed for `_sourceTypeFromStrategy`'s substring-matching fragility (Quality Observation #3) — that inference logic appears untested directly (only indirectly via cache-save assertions in `import_manager_test.dart`, if any).

## Learning-loop hooks (events logged, corrections captured, anything fed back)

- **`ParseEventLogger`** (`services/parsing/parse_event_logger.dart`, called from `UrlImportStrategy._logImportEvent`, `:429-446`) — logs url/domain/success/successfulTier/parseTimeMs/usedLlm per import attempt. This is the primary structured signal for "which tier actually worked" analytics, feeding presumably into `docs/architecture` parsing-quality dashboards (admin dashboard's "Parsing-detaljer" tab per project memory) — not verified in this pass but the shape matches.
- **`AppLogger.analytics('rate_limit_denied', {...})`** (`import_rate_limiter.dart:234-238, 256-260, 278-282, 329-333, 352-356`) — every denial reason (perMinute/perHour/perDay/costDaily/costMonthly) is tagged as an analytics event, giving product visibility into how often users hit ceilings and which ceiling.
- **HIGH-2 retagging** (`import_manager.dart:835-887`) is a feedback loop of sorts: cached recipes older than 30 days or missing tags get re-run through `TaggingService.generateTags` on next cache hit, so tagging-rule improvements propagate to previously-cached imports without an explicit backfill job.
- **`CRIT-12` warnings** (`text_import_strategy.dart:450-463`) log (not analytics-tag) when a text import produces zero ingredients or zero instructions — a debugging signal, not wired to any dashboard/metric that this pass observed, i.e. it's a `AppLogger.warning` call, not `AppLogger.analytics`, so it likely only surfaces in Crashlytics-adjacent logs rather than a queryable metric.
- **No explicit "user corrected the parse" feedback loop was found in this subtree** — the assisted-import (Tier 7) and post-import edit flows exist (`test/unit/services/analytics/post_import_edit_decider_test.dart` suggests a decider elsewhere in `services/analytics/`) but that decider lives outside `lib/services/import/`, so within this scope the loop is "log tier success" and "retag on cache staleness," not "learn from user edits to improve future parses."
- **Cost tracking** (`llmCostToday`/`llmCostThisMonth` in `UsageLimits`) is itself a learning-loop input for the ceilings, and the BUT-1415 comment (`import_rate_limiter.dart:112-119`) explicitly documents the risk of that signal going stale on transient failures — i.e. the team is aware this feedback channel can silently drift.

---

# SUBSYSTEM MAP: extraction

Enough evidence gathered. Producing the structural map.

## Purpose & entry points

Two **parallel, largely disconnected** extraction paths exist in this codebase, both under `lib/services/extraction/`:

1. **Social/mobile-share path**: `ExtractionManager` (`extraction_manager.dart:46`) — invoked only via `SocialMediaExtractor.extractFromUrl` (`lib/services/social_media_extractor.dart:163`), which is itself consumed from `lib/views/receive_share_view.dart:159` (the OS share-sheet import flow: "share to Butlery" from Instagram/other apps). Registered as singleton in `content_module.dart`.
2. **URL-paste import path**: `lib/services/import/url_import_strategy.dart` — the actual "paste a recipe URL" entry point (`ImportManager` → `UrlImportStrategy.import`). This path does **not** go through `ExtractionManager`/`PlatformDetector` at all; it drives `WebScraper` directly via `HttpContentFetcher` (`url_import_strategy.dart:13,41,128`) and separately consults `SiteParserRegistry` (`url_import_strategy.dart:14,225`) for Swedish-site-specific parsing.

So `web_scraper.dart` is shared plumbing, but `extraction_manager.dart`/`platform_detector.dart` (Tier logic) and `site_parsers/*` (Tier logic) are two independent consumers of it that never call each other.

## Flow (step-by-step)

**Path A — share-sheet (Instagram etc.):**
1. `ExtractionManager.extractFromUrl(url)` (`extraction_manager.dart:95`)
2. `PlatformDetector.convertToWebUrl` (app-URL → web URL, Instagram-only) → `detectPlatform` (string-contains matching over a hardcoded domain list) → `isSupportedPlatform` gate (`platform_detector.dart:45-99`)
3. `withRetry(() => WebScraper.performExtraction(webUrl, platform), maxAttempts: 3)` (`extraction_manager.dart:114-117`)
4. `WebScraper.performExtraction` (`web_scraper.dart:54`): spins up a `HeadlessInAppWebView`, waits for `onProgressChanged` to hit 100%, waits a platform-dependent delay (Instagram gets `animationDurationSlow`, others `animationDurationMedium`), then dispatches to `_extractTextForPlatform` (`web_scraper.dart:251`) which switches on platform → `InstagramContentExtractor.extract` / `SocialPlatformContentExtractor.extractFacebook|extractTikTok|extractGeneric` / `RecipeSiteContentExtractor.extract`.
5. Each extractor runs a chain of `evaluateJavascript` DOM-scraping strategies (see below) and returns raw text; `WebScraper` wraps it into an `ExtractionResult` (defined in `social_media_extractor.dart`, not in this subsystem).
6. 15s timeout (`web_scraper.dart:25`) races the extraction; on timeout/error/no-content, `_safeCleanup()` tears down the WebView.

**Path B — URL paste (`UrlImportStrategy.import`, `url_import_strategy.dart:98`):** a 7-tier waterfall, only tiers 3/4 touch this subsystem:
- Tier 1 (`_tryEnhancedParser`, line 204): `RecipeParserService.parseFromUrl` (out of scope, ML/heuristic parser) on plain HTTP-fetched HTML.
- Tier 2 (`_tryStructuredExtraction`, line 224): `SiteParserRegistry.getParser(url)` → if a Swedish-site parser is registered, `RecipeSiteParser.parseRecipe(html)` (`recipe_site_parser.dart:28`): try `extractRecipeFromHtml` (schema.org JSON-LD, in `lib/utils/recipe_scraper.dart`, out of scope) → `enhanceRecipe` (site-specific CSS enrichment, e.g. ICA difficulty/tips/equipment) → `RecipeQualityScorer.score` gate at `meetsMinimumQuality` (80%, `recipe_quality_scorer.dart:75`) → else `extractWithCssSelectors` fallback, scored again. If no site parser registered, falls straight to generic `extractRecipeFromHtml`.
- Tier 3 (line 126): `HttpContentFetcher.tryWebScraperHtml(url)` → internally calls `WebScraper` (headless browser) to get raw HTML for JS-rendered/bot-blocked pages, then re-runs Tiers 1+2 against that HTML.
- Tier 4 (`_tryWebScraperFallback`, line 255): `HttpContentFetcher.tryWebScraper(url)` → `WebScraper.performExtraction` (the *text*-extraction path, same one Path A uses) → hands raw extracted text to `TextImportStrategy` (out of scope) for freeform parsing.
- Tiers 5–7 (HTML→plain-text parse, LLM fallback, user-assisted) are outside this subsystem's scope.

`SiteParserRegistry` itself is populated once, at DI-init time, in `content_module.dart:836-839` (`register(IcaRecipeParser())`, `ArlaRecipeParser()`, `KoketRecipeParser()`, `ReceptRecipeParser()`) — a static in-memory `Map<String,RecipeSiteParser>` (`site_parser_registry.dart:16`).

## Data shapes

- `ExtractionResult` (defined in `social_media_extractor.dart`, not this subsystem): `{success, extractedText?, error?, metadata: Map}` — the shape both `ExtractionManager` and `WebScraper` return. `metadata['reason']` is a stringly-typed enum-ish (`'unknown_platform' | 'network' | 'no_content' | 'parse_failed'`) with no shared constant — repeated as raw string literals in ~6 places in `web_scraper.dart`.
- `SourcePlatform` enum (`platform_detector.dart:28`): `instagram, facebook, tiktok, youtube, pinterest, recipesite, unknown`. Note **`youtube` and `pinterest` are detected but have no dedicated `_extractTextForPlatform` case** — they silently fall to `_socialPlatformExtractor.extractGeneric` (`web_scraper.dart:266` default branch).
- Site-parser layer works on `Map<String, dynamic>` "raw schema.org-shaped" recipe dicts (`name`, `recipeIngredient`, `recipeInstructions`, `recipeYield`, `totalTime`, `image`, plus site-specific extras like `difficulty`/`cookingTips`/`equipment`) — this is the shape-transition point: `RecipeSiteParser.parseRecipe` returns this raw map, and `url_import_strategy.dart:242` (`SchemaOrgRecipeExtractor.createRecipe(recipeData, url)`, out of scope) converts it into the app's real `Recipe`/`RecipeUnified` model.
- `InstagramExtractionResult` (`instagram_content_extractor.dart:8`) is a richer wrapper (`text, isSuccess, hasRecipeContent, thumbnailUrl, error`) produced by `extractWithResult`, but **nothing in the traced call graph calls `extractWithResult`** — `WebScraper._extractTextForPlatform` calls the plain `extract()` method instead, so this richer result type looks unused in the live pipeline (see Quality observations).

## Config & thresholds

- Extraction timeout: 15s (`web_scraper.dart:25`).
- Post-load-100% settle delay: `AppDimensions.animationDurationSlow` for Instagram vs `animationDurationMedium` for everything else (`web_scraper.dart:114-116`) — magic differentiation with no comment explaining why Instagram needs longer.
- Cleanup delays: hardcoded `500ms`/`1000ms` `Future.delayed` sprinkled through `web_scraper.dart` (lines 90, 154, 169, 221, 243, 334, 371, 392, 404, 414) — no named constants.
- CSS selector-based content-extraction quality gate: text must be `length > 300` and contain an ingredient/recipe keyword and not contain cookie/GDPR boilerplate strings (`recipe_site_content_extractor.dart:189-197`) — magic `300`.
- Instagram recipe-keyword detection: needs `>= 3` of ~20 hardcoded Swedish keywords, short-circuits at 3 (`instagram_content_extractor.dart:71-95,282-291`); `needsScreenshot` triggers when text `< 100` chars and no recipe keywords (line 264).
- `RecipeQualityScore` weights (`recipe_quality_scorer.dart:44-61`): title 20%, ingredients 30% (needs ≥3 items), instructions 30% (needs ≥2 steps), portions 10%, time 5%, image 5%. Three named thresholds: `meetsHighQuality 0.95`, `meetsAcceptableQuality 0.90`, `meetsMinimumQuality 0.80` (only `meetsMinimumQuality` is actually used, in `recipe_site_parser.dart:40,50` — the other two are dead/unused outside tests).
- **Two entirely separate site-config systems with duplicated/divergent selector data**: (a) hardcoded Dart parsers in `site_parsers/*.dart` (compiled into the app, requires a release to update) vs (b) `functions/src/admin/seed-site-configs.ts` seeding a Firestore `site_configs` collection consumed by `lib/services/parsing/tiers/site_config_tier.dart` (Tier used by `RecipeParserService`, i.e. Tier 1 of `UrlImportStrategy`, out of this subsystem's scope but directly load-bearing). The seed file's selectors for `ica.se`/`arla.se`/`koket.se` (e.g. `.recipe-header__title`, `.ingredients-list-group__card li`) are **different strings** from the ones hardcoded in `ica_recipe_parser.dart` (e.g. `h1.recipe-title`, `.ingredient-list li`) — two teams'/two eras' worth of guesses at the same sites' markup, never reconciled, both live in production simultaneously and can silently disagree on which one "wins" (Tier 1 runs before Tier 2's `SiteParserRegistry` lookup, so `site_config_tier.dart`'s Firestore-driven selectors take priority when present).
- `seed-site-configs.ts` also seeds 6 sites (`coop.se`, `tasteline.com`, `mathem.se`, `alltommat.se`, `receptfavoriter.se`, `landleyskok.se`) that have **no** corresponding hardcoded Dart parser at all — they rely entirely on the Firestore-tier/generic schema.org path.

## Coupling

**Upstream (feeds this subsystem):**
- `content_module.dart` DI: constructs `ExtractionManager()` singleton, registers the 4 site parsers into `SiteParserRegistry`.
- `UrlImportStrategy`/`HttpContentFetcher` construct/drive `WebScraper` directly, bypassing `ExtractionManager`/`PlatformDetector` (own `pd.SourcePlatform` detection is not reused — `HttpContentFetcher` uses `WebScraper`'s platform param but the platform value itself likely comes from a different detection call not traced here, worth flagging: confirm `HttpContentFetcher` passes a real platform through rather than a stub).
- `receive_share_view.dart` (share-sheet) → `SocialMediaExtractor` → `ExtractionManager`.

**Downstream (consumes this subsystem's output):**
- `ExtractionResult.extractedText` from Path A flows back into `receive_share_view.dart`'s recipe-creation flow (raw text handed to whatever import/parse UI comes next — outside scope).
- `SiteParserRegistry`/`RecipeSiteParser` raw maps flow into `SchemaOrgRecipeExtractor.createRecipe` (`lib/services/import/extractors/`, out of scope) to build the canonical `Recipe` model.
- `WebScraper.performExtraction`'s text output (Path B, Tier 4) flows into `TextImportStrategy` (out of scope) for freeform NLP parsing — i.e. the headless-browser-scraped text from Instagram/etc. and from generic recipe sites both ultimately funnel through the *same* text-heuristics parser, just via different call sites.

**Hidden coupling / cross-cutting:**
- `RecipeParserService` (Tier 1 in `UrlImportStrategy`, out of scope) internally uses `site_config_tier.dart` which reads the Firestore `site_configs` collection seeded by `seed-site-configs.ts` — this is a real dependency edge from "in scope" (`seed-site-configs.ts`) to "out of scope" (`site_config_tier.dart`) that determines whether `SiteParserRegistry` (Tier 2) is even reached for a given URL.
- `ParseEventLogger` (`lib/services/parsing/parse_event_logger.dart`, out of scope but directly invoked by `UrlImportStrategy._logImportEvent`) is the only place that records which tier succeeded (`successfulTier: 'StructuredExtraction' | 'WebScraper' | 'HtmlTextParse' | 'LLM' | 'UserAssisted'`) — Path A (`ExtractionManager`) has **no equivalent event logging at all**.

## Quality observations

1. **`InstagramExtractionResult`/`extractWithResult` appear dead in the live pipeline** (`instagram_content_extractor.dart:250-277`) — `WebScraper._extractTextForPlatform` (`web_scraper.dart:258-259`) calls the plain `extract()`, never `extractWithResult()`, so the richer `needsScreenshot`/`hasRecipeContent` signal (with its own recipe-keyword heuristic) is built but appears unreachable from production code; only tests seem to exercise it directly. Confirm before deleting, but worth a grep-wide check for any other caller.
2. **YouTube and Pinterest are "supported" per `PlatformDetector.isSupportedPlatform` but have no extraction strategy** — `web_scraper.dart:257-267`'s switch has no `youtube`/`pinterest` case, so they silently fall through to `extractGeneric` (body-text scrape), which will almost never find a recipe in a YouTube page (recipe is in the description, not the DOM body). This is a silent-degradation path, not a hard failure — user gets a low-quality generic extraction with no signal that "youtube" wasn't actually specially handled, despite `platform_detector.dart` explicitly enumerating it as first-class.
3. **Two parallel, non-communicating site-config systems** (see Config section) — the hardcoded 4 Dart parsers (`ica/arla/koket/recept`) and the Firestore-driven `site_configs` (10 domains, different selectors even for the overlapping 3 sites) can drift independently and nobody reconciles them; `seed-site-configs.ts` selectors were last "based on analysis" at some point (comment `seed-site-configs.ts:86`) with no update mechanism visible, while `ica_recipe_parser.dart` selectors are equally unverified guesses (`.recipe-title`, `.ingredient-list li` etc., generic enough to be wrong for ICA's actual current markup).
4. **Broad error swallowing throughout `web_scraper.dart`**: `_safeCleanup`'s `webViewController?.stopLoading()` (line 328-332) and `dispose()` (335-340) both catch-and-ignore with only a comment, no log; `fetchRawHtml`'s WebView-dispose catch (`web_scraper.dart:356-361`) logs via `AppLogger.debug` only. Every `evaluateJavascript` call in every extractor (`instagram_content_extractor.dart`, `recipe_site_content_extractor.dart`, `social_platform_content_extractor.dart`) wraps in `try {...} catch (_) { /* Continue */ }` with zero logging — a JS-side exception (e.g. malformed JSON-LD) is completely invisible; you cannot tell from logs whether extraction failed because a strategy legitimately found nothing vs. threw.
5. **`_extractJsonLd`'s embedded JS silently returns `null` on `JSON.parse` failure** (`recipe_site_content_extractor.dart:96-98`, `console.error` only, which isn't wired to `onConsoleMessage` — that callback is a no-op at `web_scraper.dart:225`) — so malformed JSON-LD (common on real sites with trailing commas/HTML-escaping bugs) produces the same "not found" signal as a page that genuinely has no JSON-LD, with no way to distinguish them from Dart-side logs.
6. **Ownership/duplication**: `RecipeSiteContentExtractor._extractJsonLd`/`_extractMicrodata` (JS-embedded schema.org extraction) duplicates logic that `lib/utils/recipe_scraper.dart`'s `extractRecipeFromHtml` (Dart-side HTML parsing, used by `RecipeSiteParser.parseRecipe`) already does — two independent JSON-LD/Recipe-type parsers exist, one in JS-string-in-Dart (harder to test/maintain, silent failures per #5) and one in real Dart with `html` package (has direct unit tests). The JS one is only reachable via Path A/Path-B-Tier-4 (`WebScraper`), the Dart one via Path-B-Tier-2/3 (`SiteParserRegistry`/`extractRecipeFromHtml`).
7. **`ExtractionManager._webScraper.dispose()` is only called from `onDispose()`** (`extraction_manager.dart:145-147`), which per `BaseService` lifecycle only fires on service teardown, not per-extraction — but `WebScraper.performExtraction` already does its own internal `_safeCleanup()` per call (`web_scraper.dart:154-155,169-170` etc.), so the two cleanup paths overlap; the `_pendingCleanup`/`_isDisposed` race-guard comment at `web_scraper.dart:58-63` exists specifically because of this overlapping-lifecycle risk between consecutive `performExtraction` calls on the same singleton-ish instance — fragile but apparently deliberately patched (worth confirming the comment reflects a real past bug fix, not speculative hardening).
8. **`_getUserAgent(platform)` ignores its `platform` parameter entirely** (`web_scraper.dart:315-317`) — always returns `HttpConstants.desktopUserAgent` regardless of platform; the parameter exists but is dead, suggesting either an incomplete refactor (per-platform UA was probably intended, e.g. mobile UA for Instagram) or a leftover after a decision was made and not cleaned up.
9. **`RecipeQualityScore.meetsHighQuality`/`meetsAcceptableQuality`** (`recipe_quality_scorer.dart:66,70`) are computed but never read outside their own class/tests — only `meetsMinimumQuality` gates real control flow (`recipe_site_parser.dart:40,50`). The doc comments claiming these target specific sites' "success rate" (ICA/Arla 95%, Köket 90%) describe aspirational per-site thresholds that aren't actually wired to per-domain logic anywhere.

## Test coverage observed

- `test/unit/services/extraction/extraction_manager_test.dart` (538 lines) — exercises `ExtractionManager` "using real ExtractionManager implementation for integration-style testing" (per its own comment); pins platform-detection→scrape orchestration and unsupported-platform error metadata (`reason: unknown_platform`).
- `test/unit/services/extraction/platform_detector_test.dart` (663 lines) — pins the domain-matching table exhaustively (all the `contains()` checks) plus the Instagram app-URL→web-URL regex conversion.
- `test/unit/services/extraction/web_scraper_test.dart` (731 lines) — pins timeout behavior, selector maps, dispose/cleanup sequencing (likely the source of the `_pendingCleanup` race-guard's regression coverage).
- `test/unit/services/extraction/social_media_extractor_test.dart` (541 lines) — tests the `SocialMediaExtractor` facade (outside strict scope but directly wraps `ExtractionManager`).
- `test/unit/services/extraction/site_parsers/{ica,arla,koket,recept}_recipe_parser_test.dart` (~460-510 lines each) — pin each site's `enhanceRecipe`/`extractWithCssSelectors`/formatting-cleanup behavior against fixture HTML; these are the tests that would catch a real ICA markup change if the fixtures are kept current (unverifiable here whether fixtures reflect *live* ICA markup — that's the open risk in observation #3).
- `test/unit/services/extraction/site_parsers/recipe_quality_scorer_test.dart` (184 lines), `recipe_site_parser_test.dart` (122 lines) — pin the completeness-scoring math and the base-class extraction/fallback/quality-gate sequencing.
- `test/unit/services/extraction/site_parsers/site_parser_registry_test.dart` (70 lines, added per its header comment for "BUT-1149 coverage burndown — previously zero direct coverage") — pins register/getParser exact-match, www-stripping, unregistered→null, clear/count/registeredDomains; uses a local `_FakeParser` rather than the real site parsers.
- No test file directly exercises `functions/src/admin/seed-site-configs.ts` within the Dart test tree (it's a Cloud Function; would need a `functions/src/__tests__/*` counterpart — none found by name in this scan, meaning the seed data's correctness/admin-gating is unverified by automated tests as far as this scope shows).
- `instagram_content_extractor.dart`, `recipe_site_content_extractor.dart`, `social_platform_content_extractor.dart` have no dedicated per-extractor unit test files — they're only reachable/pinned indirectly through `web_scraper_test.dart`'s orchestration tests (meaning the embedded-JS extraction strategies' *content-selection logic* is exercised only as much as `web_scraper_test.dart`'s scenarios cover, likely via a fake/mocked `InAppWebViewController` rather than real DOM evaluation).

## Learning-loop hooks

- **Path B (`UrlImportStrategy`) has a real feedback loop**: `ParseEventLogger.logEvent` (`url_import_strategy.dart:429-446`, calling into `functions/src/events/log-parse-event.ts` out of scope) logs `url, source: 'url', success, domain, successfulTier, parseTimeMs, usedLlm` for every import attempt — this is the mechanism that could in principle drive `site_configs` success/failure counters, though `seed-site-configs.ts`'s `getSiteConfigStats` (line 321) just reads `successCount`/`failureCount` off the Firestore doc without this scan finding the write side that increments them from parse events (likely lives in `functions/src/events/log-parse-event.ts` or `site_config_tier.dart`, out of scope — worth a follow-up check if you need to confirm the loop actually closes).
- **Path A (`ExtractionManager`/`WebScraper`, share-sheet flow) has no learning-loop hook at all** — no event logging, no success/failure counters, no correction capture. A recipe extracted via Instagram share never contributes to any quality/success metric visible in this subsystem.
- `RecipeQualityScorer`'s completeness score is used only as a synchronous pass/fail gate inside `RecipeSiteParser.parseRecipe` (in-process, per-call) — it is **not** persisted or fed back anywhere; it doesn't accumulate into the `site_configs.qualityScore` field that `seed-site-configs.ts` seeds (that field is a static seed value, `0.7`–`0.9`, never recomputed from live extraction quality as far as this scope shows).
- `seed-site-configs.ts`'s admin-gating (`isAdmin`, lines 37-59) is itself a config/ops surface, not a learning loop — it's a one-shot manual re-seed callable, not triggered by extraction outcomes.

**Files read in full for this map:** `lib/services/extraction/extraction_manager.dart`, `platform_detector.dart`, `web_scraper.dart`, `extractors/recipe_site_content_extractor.dart`, `extractors/instagram_content_extractor.dart`, `extractors/social_platform_content_extractor.dart`, `site_parsers/site_parser_registry.dart`, `site_parsers/recipe_site_parser.dart`, `site_parsers/recipe_quality_scorer.dart`, `site_parsers/ica_recipe_parser.dart`, `functions/src/admin/seed-site-configs.ts`, `lib/services/import/url_import_strategy.dart` (upstream caller, read for flow accuracy). Skimmed: `arla/koket/recept_recipe_parser.dart` (structurally identical to `ica_recipe_parser.dart` per grep/wc), `lib/services/import/fetchers/http_content_fetcher.dart` (partial), test file headers/sizes.

---

# SUBSYSTEM MAP: parsing-ml

I now have sufficient depth across the pipeline. Producing the final structural map.

## Purpose & entry points

The `parsing-ml` subsystem takes raw content (HTML, plain text, OCR text) from any import source and produces a structured `ParsedRecipe`, using a cascading 4-tier strategy (structured extraction → CSS selectors → Swedish rule-based/CRF → LLM), with a shared ingredient-parsing sub-pipeline (CRF → BERT NER → LLM) and a learning-loop that captures user corrections for retraining.

- **`lib/services/parsing/recipe_parser_service.dart`** (915 lines) — the facade/orchestrator. Public entry points: `parseFromUrl()` and `parseFromText()`. Both build a `ParsingContext`, run `_runTiers()`, cache, and log analytics.
- **`lib/services/parsing/ingredient_parsing_strategy.dart`** — shared ingredient-line parser used by every tier (`CRF → BERT NER → regex`).
- Downstream callers (outside scope but worth noting): recipe import strategies (`UrlImportStrategy`, `FileImportStrategy`, OCR photo import) call `RecipeParserService.parseFromUrl/parseFromText`.

## Flow (step-by-step)

1. `RecipeParserService.parseFromUrl()` (`recipe_parser_service.dart:250`) builds `ParsingContext.fromUrl()` (`tiers/parsing_context.dart:79`), which sanitizes HTML via `HtmlSanitizer.instance.check/sanitize` (`sanitizers/html_sanitizer.dart`) and computes `contentHash`/`domain`.
2. Security gate: `context.isSecure` (`parsing_context.dart:134`) — if sanitization flags critical issues, parsing fails immediately (`recipe_parser_service.dart:268`).
3. Cache check: `_checkCache()` → `LocalRecipeCache.get()` (`cache/local_recipe_cache.dart:107`), guarded by a shared `CircuitBreaker` (`recipe_parser_service.dart:160`, `745`).
4. Reliable-domain threshold boost: if `SiteConfigRepository` marks the domain reliable, `effectiveThreshold += 0.15` (capped 0.95) (`recipe_parser_service.dart:304-321`).
5. `_runTiers()` (`recipe_parser_service.dart:459`) iterates `_tiers = [SchemaOrgTier, SiteConfigTier, RuleBasedTier, LlmTier]` in order:
   - `_shouldSkipTier()` (line 442): non-URL sources skip SchemaOrg/SiteConfig outright.
   - `context.shouldContinueParsing(qualityThreshold)` (`parsing_context.dart:197`) stops the loop once the best tier so far clears the bar.
   - Before `LlmTier`, tries `_trySelectiveIngredientEnhancement()` (line 578) — re-parses only uncertain ingredient lines via `IngredientParsingStrategy.getUncertainLines()` (routes CRF→BERT NER) then a cheap LLM call (`llmService.parseIngredientLines`), patching the existing recipe instead of a full re-extraction (~500 vs ~3000 tokens). If that clears the threshold, `LlmTier` is skipped entirely.
   - Otherwise `_preparePartialForEnhancement()` (line 526) extracts good fields into `context.bestPartialRecipe` so `LlmTier` can run in `StructureMode.enhance` instead of `extract` (`tiers/llm_tier.dart:85-98`).
   - Each tier runs via `ParsingTier.parseWithTimeout()` (`tiers/parsing_tier.dart:50`), which enforces `defaultTimeout`, catches exceptions, and records a `TierResultEntry` on the context.
   - Per-tier quality discount (`_tierQualityDiscount`, SchemaOrg −0.10, SiteConfig −0.05) lets structured tiers stop early even slightly below the raw threshold (`recipe_parser_service.dart:47-50`, `504`).
6. Tier internals for ingredients:
   - `SchemaOrgTier` (`tiers/schema_org_tier.dart`) wraps `extractRecipeFromHtmlDetailed()` (JSON-LD/microdata) from `utils/recipe_scraper.dart`, caches `context.jsonLdData` for reuse by `LlmTier`.
   - `RuleBasedTier` (`tiers/rule_based_tier.dart:64`) calls `context.parseStructureCachedAsync()` (neural or isolate-offloaded rule-based line classification via `SwedishLineClassifier`/`NeuralLineClassifier`), then routes ingredient lines through `IngredientParsingStrategy.parseLines()`.
   - `IngredientParsingStrategy.parseLine/parseLines()` (`ingredient_parsing_strategy.dart:138-211`) lazily inits CRF weights (`_ensureInitialized`, line 75) from bundled asset `assets/data/crf_ingredient_weights.json`, optionally upgraded via `RemoteWeightLoader` (`crf/remote_weight_loader.dart`) in background; falls back to legacy regex `IngredientParser` if CRF unavailable.
   - CRF path: `CrfIngredientParser.parseLine()` (`crf/crf_ingredient_parser.dart:36`) tokenizes (`tokenize`), runs `CrfViterbiDecoder.decode()` (`crf/crf_viterbi_decoder.dart:143`, forward-Viterbi over `BioLabel` tag set), then `assembleFromLabels()` groups BIO spans into qty/unit/name/prep/size.
   - Uncertain lines (confidence < `NeuralIngredientParser.confidenceThreshold`) are optionally re-parsed by BERT NER (`ner/neural_ingredient_parser.dart` → `ner/onnx_ner_service.dart`, ONNX Runtime + `ner/wordpiece_tokenizer.dart`).
7. `LlmTier.parse()` (`tiers/llm_tier.dart:71`) prepares LLM input text via a 3-strategy cascade (JSON-LD reuse → DOM container extraction → keyword-anchored truncation, lines 239-370), calls `llmService.structureRecipe()` with `RetryHelper.retryWithBackoff` (retries only `unavailable`/`deadline-exceeded`, never rate-limit), then runs P0-2 injection-pattern validation (`_validateForSuspiciousPatterns`, line 379) and range validation (`_validateResponse`, line 436) before converting to `ParsedRecipe`.
8. `RecipeMerger.merge()` (`common/recipe_merger.dart:17`) combines all successful `TierResult`s field-by-field by confidence (title/portions/instructions/time) and specially for ingredients (length-ratio, avg-confidence, then per-ingredient fuzzy matching via `_ingredientsSimilar`, word-set containment).
9. Result cached (`_cacheResult` → `LocalRecipeCache.set`) and analytics fired: `_emitTierAnalytics()` (per-tier funnel events) and `_logParseEvent()` (fire-and-forget Cloud Function `logParseEvent`, region `europe-west1`, via `ParseEventLogger`).
10. On failure, `_pickUserMessage()` (line 717) picks the most actionable Swedish-facing message from accumulated `_lastTierFailures` by a fixed priority list.

**Learning-loop flow (separate from parse-time):** after a user edits an imported recipe, `RecipeDiffCalculator.calculateDiff()` (`feedback/recipe_diff_calculator.dart:19`) diffs `ParsedRecipe` vs the user-saved `Recipe` (Levenshtein-based fuzzy ingredient/instruction matching) into a `ParsingCorrection`, which `ParseCorrectionUploader.upload()`/`uploadWithSharedSalt()` (`feedback/parse_correction_uploader.dart`) fans out per-field and fires-and-forgets to the `logParseCorrection` callable (hashed user/recipe IDs, tier name mapped to server vocabulary, whitespace/case-only diffs dropped).

## Data shapes

- `ParsingContext` (`tiers/parsing_context.dart`) — per-request bag: raw/sanitized content, hashes, `jsonLdData` cache, `bestPartialRecipe`, `tierResults` accumulator. Mutable (`parsedDocument`, `jsonLdData` set by SchemaOrgTier for reuse by LlmTier — cross-tier side channel).
- `TierResult` (`models/parsing/tier_result.dart`, not read in full but used pervasively) — per-tier outcome: `success`, `quality`, `recipe`, `failureReason`, `costSek`, `promptVersion`.
- `ParsedRecipe` / `FieldResult<T>` (`models/parsing/*`) — each field individually carries a confidence tier (`ParseConfidence.high/medium/low`) and provenance string; this is the shape that survives from tier → merger → cache → UI.
- `ParsedIngredient` — `name`, `quantity`, `unit`, `size`, `preparation`, `confidence`, `originalLine`. Shape changes at: CRF assembly (`CrfIngredientParser.assembleFromLabels`), LLM conversion (`parsedIngredientFromExtracted`, referenced but defined in `ingredient_conversion.dart`), and legacy regex fallback (`_parseWithRegex`).
- `BioLabel` enum (`crf/crf_viterbi_decoder.dart:6`) — the CRF/NER label schema (`bQty/iQty/bUnit/bName/iName/bPrep/iPrep/bSize/other`), shared contract between CRF and NER assemblers.
- `ParsingCorrection` / `FieldCorrection` / `IngredientCorrection` / `InstructionCorrection` (`models/parsing/*`) — the learning-loop's diff shape, built by `RecipeDiffCalculator`, consumed by `ParseCorrectionUploader`.
- `CrfWeights` (`crf/crf_viterbi_decoder.dart:19`) — `featureWeights: Map<BioLabel, Map<String,double>>` + `transitionWeights: Map<BioLabel, Map<BioLabel,double>>`, JSON-serializable, loaded from asset or Firebase Storage.

## Config & thresholds

- `defaultQualityThreshold = 0.65` (`recipe_parser_service.dart:35`); `_reliableDomainBoost = 0.15`, `_maxEffectiveThreshold = 0.95` (lines 38-41).
- `_tierQualityDiscount`: SchemaOrg 0.10, SiteConfig 0.05 (line 47).
- `parserVersion = '2.0.0'` — cache-invalidation key; bump on any parsing behavior change (line 32).
- `IngredientParsingStrategy._uncertaintyThreshold` = `NeuralIngredientParser.confidenceThreshold` — shared constant driving the CRF→BERT cascade (`ingredient_parsing_strategy.dart:35`).
- `IngredientParsingStrategy.shouldEnhanceSelectively` — selective-enhance only fires when `uncertainCount <= totalCount/2` (line 269-275).
- `bundledWeightVersion = 1` — bumped manually when bundled CRF weights asset changes; remote weights with a higher version replace it (line 30).
- `_initRetryDelay = 5 min` for CRF init failure backoff; NER background init retry `1 hour` (`ingredient_parsing_strategy.dart:41, 222`).
- `kSwedishUnits`, `kMaxAmountByUnit`, `kMaxAmountUnitless` (`swedish_units.dart`) — single-source-of-truth unit vocabulary and hallucination ceilings, shared by `SwedishLineClassifier` and `LlmTier._validateResponse`.
- `_maxInstructionCount = 50`, `_maxTextLength = 15000` chars, `LlmTier` timeout `30s`, ingredient name length 1-100 chars, instruction length 5-2000 chars, portions 1-100, time 1-2880 min (`tiers/llm_tier.dart:32,43,435-516`).
- Model integrity: `_expected_model_hashes.dart` — fail-closed SHA-256 registry for ONNX/CRF downloads (`remote_model_loader.dart:84-127`); empty or missing-version entry refuses the load, not a silent bypass.
- `LocalRecipeCache`: `maxAgeDays=30`, `maxEntries=100` (`cache/local_recipe_cache.dart:49-50`); cache key = `sha256(userId|urlHash|contentHash|source|version)`.
- `_hashContentMaxChars = 5000` for content hashing truncation (`local_recipe_cache.dart:91`).
- `kMaxCorrectionValueChars = 500` truncation for uploaded correction values (`feedback/parse_correction_uploader.dart:15`).
- `CircuitBreaker(failureThreshold: 3, resetTime: 2 min)` shared between cache reads/writes (`recipe_parser_service.dart:160`).

## Coupling

**Upstream (feeds this subsystem):**
- Import strategies (`UrlImportStrategy`, `FileImportStrategy`, OCR/photo pipeline) call `parseFromUrl`/`parseFromText`.
- `SiteConfigRepository` (Firestore) — CSS-selector configs and per-domain reliability flag consumed by `SiteConfigTier` and the threshold-boost logic.
- `LlmService` (`services/llm/llm_service.dart`) — injected; `LlmTier` and selective-enhancement both depend on it; absent → those paths are skipped, not errored.
- `IngredientRegistryService` — enriches CRF feature extraction (`ingredient_parsing_strategy.dart:88-91`).
- Firebase Storage — remote CRF weights (`RemoteWeightLoader`) and ONNX models (NER, line classifier) via `RemoteModelLoader`.
- `OfflineService.database.cacheDao` — Drift-backed cache DAO for `LocalRecipeCache`.

**Downstream (consumes this subsystem's output):**
- `ParsedRecipe` flows into recipe-creation viewmodels (recipe import review screens), then eventually saved as a `Recipe`/`RecipeUnified` in Firestore — outside this scope but the boundary is `ParsedRecipe.toJson()`/import-review UI.
- `RecipeDiffCalculator` consumes the saved `Recipe` (post-user-edit) against the original `ParsedRecipe` to build training data — a downstream feedback path back into the pipeline (not real-time; feeds an offline retrain, not observed in this scope).
- Analytics: `ParseEventsTracker`, `AnalyticsService`, Cloud Functions `logParseEvent`/`logParseCorrection`.

**Hidden dependencies / side channels:**
- `ParsingContext.jsonLdData` is a mutable cross-tier side channel: `SchemaOrgTier` writes it even on a *failed* full extraction; `LlmTier` reads it to build higher-signal LLM input. Any tier reordering breaks this silently.
- `ParsingContext._cachedStructure`/`_structureCacheKey` is a single-entry memo keyed by exact text equality — `RuleBasedTier` and (indirectly) selective enhancement both rely on this being called with identical text to avoid redundant classification.
- `IngredientParsingStrategy` is constructed once per `RecipeParserService` and shared across all 4 tiers (`recipe_parser_service.dart:191`), so CRF/NER lazy-init state (and its 5-min/1-hour backoff clocks) is shared, not per-tier.

## Quality observations

1. **Silent tier-analytics gap by design, not bug, but fragile**: `_analyticsTierFor()` (`recipe_parser_service.dart:805`) returns `null` for unmapped tier names (e.g. `SelectiveEnhance`), silently dropping analytics for that tier — correct today but a new tier added without updating this switch silently loses telemetry with no test enforcing exhaustiveness.
2. **Error swallowing is pervasive by design** (cache: `recipe_parser_service.dart:760,783`; analytics emit: `851`; parse-event logging: `parse_event_logger.dart:66-69`; remote weight/NER background init: `ingredient_parsing_strategy.dart:128,233`) — consistent with "telemetry must never block the user," but there is no aggregated visibility into *how often* these silent catches fire beyond the one `_emitFailureMetric` hook for `ParseEventLogger`. `ParseCorrectionUploader` upload failures (line 232) have no equivalent failure-rate metric at all.
3. **`RecipeMerger._mergeIngredientLists`** (`common/recipe_merger.dart:163`) is O(n·m) per merge with a first-match-wins greedy strategy — fine at recipe-sized lists (~10-30 ingredients) but the `_ingredientsSimilar` word-set-containment check (line 224-229) can false-positive-match short/generic ingredient names (e.g. "salt" contained in "salta jordnötter" word set only if exact word match, so this is actually fairly conservative — no bug found, just worth flagging as O(n·m) if scaled up).
4. **`RecipeDiffCalculator`** (`feedback/recipe_diff_calculator.dart`) reimplements its own Levenshtein distance (`_levenshteinDistance`, line 414) and fuzzy-name matching independently of the CRF/NER pipeline's own confidence machinery — duplicated string-similarity logic that could drift from whatever similarity notion the ML side uses; no shared utility.
5. **`ParsingTier.parseWithTimeout`** catches `Exception` (line 105) but a tier is documented as "Should not throw — return TierResult.failed() instead" (line 46) — the catch-all is defensive scaffolding for tiers that don't honor the contract; no static enforcement, only convention.
6. **`_shouldSkipTier`** (`recipe_parser_service.dart:442`) hardcodes tier *type checks* (`tier is LlmTier`, `tier is SchemaOrgTier`) rather than tier capability flags — orchestration logic knows concrete tier classes, coupling the service to the tier list order/types rather than to `ParsingTier`'s abstract contract.
7. **Ownership between `LocalRecipeCache` (parsing-tier cache) and `ParsedRecipeCache`** (`cache/parsed_recipe_cache.dart`, 72 lines, not read in full) — two similarly-named cache classes both under `services/parsing/cache/`; worth confirming they're not overlapping/duplicated responsibility (not verified in this pass — flagging as unclear ownership, file not read).
8. **`IngredientParsingStrategy._remoteCheckStarted`** is commented "intentionally never reset — remote weights checked once per session" (`ingredient_parsing_strategy.dart:43`) — means a session that starts before a weight update ships stays on stale weights until app restart; acceptable tradeoff but not obviously discoverable without reading this comment.

## Test coverage observed

Coverage is broad and mostly pins production-relevant behavior, not just green-status:
- `test/unit/services/parsing/recipe_parser_service_test.dart` — orchestrator: tier cascade, threshold behavior, cache circuit breaker.
- `test/unit/services/parsing/crf/{crf_feature_extractor_test,crf_viterbi_decoder_test,remote_weight_loader_test,remote_weight_loader_integrity_test}.dart` — decoder correctness + fail-closed hash verification.
- `test/unit/services/parsing/ner/{neural_ingredient_parser_test,onnx_ner_service_test,wordpiece_tokenizer_test}.dart` — NER path.
- `test/unit/services/parsing/tiers/{llm_tier_test,schema_org_tier_test,site_config_tier_test,parsing_context_test}.dart`.
- `test/unit/services/parsing/common/recipe_merger_test.dart` — merge logic.
- `test/unit/services/parsing/feedback/{parse_correction_uploader_test,recipe_diff_calculator_test}.dart` — learning-loop.
- `test/unit/services/parsing/expected_model_hashes_test.dart` + `model_manager_integrity_test.dart` — the fail-close hash-registry contract (BUT-877/792).
- `test/unit/services/parsing/parsers/{viterbi_calibration_test.dart, viterbi_calibration_baseline.md}` — a calibration *baseline* file, suggesting decoder score drift is tracked over time, not just pass/fail.
- `test/golden/parsing_golden_dataset.json` + `parsing_golden_test.dart`, `test/golden/crf_ingredients.json`, `test/golden/llm/ner_test.dart` — golden-dataset regression tests against real recipe fixtures, the strongest signal of intent-level correctness in this subsystem.
- `test/evaluation/crf_evaluator_test.dart` — separate evaluation harness (precision/recall style, not a pure pass/fail unit test).

## Learning-loop hooks

- **Parse-time telemetry**: `_emitTierAnalytics()` fires `import_tier_succeeded`/`import_tier_failed` per tier (skips `skipped` outcomes) with duration + platform bucket (`recipe_parser_service.dart:823`). `_logParseEvent()` sends a full parse summary (tier attempts, final quality, cost, promptVersion, unknownDomain flag) to Cloud Function `logParseEvent` for server-side aggregation (`parse_event_logger.dart`).
- **Correction capture (the actual training-data hook)**: `RecipeDiffCalculator.calculateDiff()` runs when a user edits their newly-imported recipe before/after saving, producing a `ParsingCorrection`; `ParseCorrectionUploader` fans it into per-field `logParseCorrection` calls, tagged with `sourceTier` (mapped to server vocabulary), domain, and `promptVersion` (LLM only) — this is the closed loop that presumably feeds CRF/NER retraining and prompt iteration, though the retraining consumer itself is outside `lib/` (server/ML-ops side, not in scope here).
- **Remote weight/model upgrade path acts as the "deploy" half of the loop**: `RemoteWeightLoader` (CRF) and the ONNX `RemoteModelLoader` subclasses pull newer trained weights/models from Firebase Storage once a session, gated by the hash registry — i.e., the mechanism by which retrained models actually reach the client.
- **`unknownDomain` tracking** (`recipe_parser_service.dart:317-320`) flags URL-source domains with no `SiteConfig` entry, feeding a prioritization signal for which domains need hand-authored CSS selectors — a lightweight non-ML feedback loop distinct from the correction pipeline.

---

# SUBSYSTEM MAP: cloud-llm

Have enough for a complete answer.

## Purpose & entry points

The `cloud-llm` subsystem is Butlery's final-tier import fallback: turns free-form text/images/transcripts into structured recipe JSON via Google Gemini (Vertex AI), sitting behind the deterministic heuristic/CRF parsers used earlier in the pipeline.

Entry points:
- `functions/src/llm/structure-recipe.ts:80` — callable `structureRecipe` (text/HTML/transcript/ingredient-lines modes)
- `functions/src/llm/ocr-recipe-image.ts:103` — callable `ocrRecipeImage` (vision OCR + in-process retry)
- Client: `lib/services/llm/llm_service.dart:32` (`LlmService`), consumed by `lib/services/import/llm/llm_enhancement_service.dart:26` (`LlmEnhancementService`) which is the actual pipeline-facing facade (`enhance`, `extractFromImage`, `extractFromHtml`, `extractFromTranscript`).

## Flow (step-by-step)

**Text extraction (`structureRecipe`):**
1. Dart `LlmEnhancementService.enhance/extractFromHtml/extractFromTranscript` (llm_enhancement_service.dart:65,240,308) checks `ImportRateLimiter.checkLimit` client-side first.
2. Calls `LlmService.structureRecipe` (llm_service.dart:89) → builds `StructureRecipeRequest` (with UI locale, llm_service.dart:110) → `_executeLlmCall` → `scrubPayload` (llm_service.dart:355, client-side PII scrub, dart mirror of pii-scrubber.ts) → `FirebaseFunctions.httpsCallable('structureRecipe')` behind a shared `CircuitBreaker` (llm_service.dart:47-56).
3. Server `runStructureRecipe` (structure-recipe.ts:135): validates text length (20–50000 chars) → reads kill-switch `system/config` (`loadKillSwitch`, line 208) → `scrubPii`/`scrubUrlParams` server-side (defense in depth, line 238) → `getPromptsConfig()` (Firestore-backed prompt bundle, prompts-config.ts) → `resolvePromptBucket` (A/B bucket, prompt-ab-bucket.ts) → picks system/user prompt by `mode` → optional locale instruction (`buildLocaleInstruction`, line 559) → `model.generateContent` against Vertex AI (`eu` region) → `extractResponseText` → `captureLlmSample` (best-effort sample capture, BEFORE parse) → `parseIngredientLinesResponse`/`isNotRecipeResponse`/`parseRecipeResponse` → returns `StructureRecipeResponse`.
4. Every exit path calls `emitTiming` → `logger.info('structure_recipe.complete', …)` (structure-recipe.ts:155-171).

**Vision OCR (`ocrRecipeImage`):**
1. `LlmEnhancementService.extractFromImage` (line 145) → `LlmService.ocrRecipeImage` → callable.
2. `runOcrRecipeImage` (ocr-recipe-image.ts:259): validates image size/URL → `validateOcrImageUrl` (SSRF/host-allowlist gate, BUT-425) → AI kill switch (`isAiDisabled`) → `getPromptsConfig`+bucket → `performOcr` (`defaultPerformOcr`, line 190) builds multimodal `Part[]` (`buildContentParts`) → Vertex `generateContent` → `captureLlmSample` → `parseRecipeResponse`.
3. On parse failure with non-empty rawText → `runOcrRetry` (ocr-retry.ts:109): budget guard (needs ≥65s remaining of the 120s function timeout) → re-invokes `runStructureRecipe` in-process (no HTTP hop) with `mode: 'extract'` on the raw OCR text.
4. Response carries `retryCount`/`retryOutcome` for observability; `emitTiming` logs `ocr_recipe_image.complete`.

Downstream (out of scope but connective): parsed `ExtractedRecipe` → Dart `_extractedToRecipe` (llm_enhancement_service.dart:368) → `Recipe.personal(...)` → normal recipe-save/tagging pipeline.

## Data shapes

- `ExtractedRecipe`/`ExtractedIngredient` (gemini-client.ts:656-674) — canonical LLM output shape; enforced server-side via `RECIPE_SCHEMA`/`INGREDIENT_SCHEMA` (gemini-client.ts:137-231) as Vertex `responseSchema` structured output.
- `StructureRecipeRequest`/`Response` and `OcrRecipeImageRequest`/`Response` (structure-recipe.ts:34-65, ocr-recipe-image.ts:44-89) — the callable contract; Dart mirrors live in `lib/services/llm/llm_models.dart`.
- Shape change points: `parseRecipeResponse` (gemini-client.ts:680) coerces/validates raw JSON into `ExtractedRecipe` (truncates description to 300 chars, drops invalid ingredients); `parseIngredientLinesResponse` (line 601) has a **salvage path** (`extractTopLevelObjects`/`salvageIngredientObjects`) for token-truncated arrays, flagging `truncated: true`.
- `LlmSampleInput` (llm-sample-capture.ts:57) — persisted mining shape in Firestore `llm_response_samples`, capped at 50k chars/field, 30-day TTL.
- Dart-side final shape: `Recipe.personal(...)` via `_extractedToRecipe` (llm_enhancement_service.dart:368) — ingredients go through `parsedIngredientFromExtracted` to satisfy the `structuredIngredients` index-alignment invariant (BUT-1228).

## Config & thresholds

- `TEXT_MODEL = "gemini-2.5-flash-lite"`, `VERTEX_LOCATION = "eu"` (gemini-client.ts:44,815)
- `MAX_TOKENS = 2000`, `TEMPERATURE = 0.3`, `INGREDIENT_LINE_MAX_TOKENS = 1000` (gemini-client.ts:822,825,426)
- Pricing: `INPUT_COST_PER_M = 0.10`, `OUTPUT_COST_PER_M = 0.40`, `CACHED_INPUT_DISCOUNT = 0.10` (gemini-client.ts:833-844) — marked TODO(BUT-1187) to reconfirm against live Vertex pricing
- `structureRecipe` text bounds: 20–50000 chars (structure-recipe.ts:179,187); function `memory: 512MiB, timeout: 60s`
- `ocrRecipeImage`: `memory: 1GiB, timeout: 120s`; image size cap 10MB base64 (ocr-recipe-image.ts:345)
- OCR retry budget: `MIN_REMAINING_BUDGET_MS = 65_000` of `OCR_FUNCTION_TIMEOUT_MS = 120_000` (ocr-retry.ts:82,91)
- Prompts cache TTL `PROMPTS_CACHE_TTL_MS = 5min`, doc `system/prompts` (prompts-config.ts:48,51)
- A/B bucketing: SHA-256(`authUidHash:prompt_experiment`) mod bucketCount, default 2 buckets (prompt-ab-bucket.ts:35,51)
- Kill switches: `system/config.aiEnabled` (master) and `system/config.llmParserEnabled` (parser-only), both **fail open** on missing doc (structure-recipe.ts:196-227)
- Rate limits (`functions/src/middleware/rate_limiter.ts:70-79`): `structureRecipe` 10 tokens/3 refill per 60s; `ocrRecipeImage` 5 tokens/2 refill per 60s — fails **closed** on Firestore errors
- Sample capture: `RETENTION_DAYS = 30`, `MAX_FIELD_CHARS = 50_000`, toggle `system/config.llmSampleCaptureEnabled` (default on), 5-min per-instance cache (llm-sample-capture.ts:23,26,31)
- `PROMPT_VERSION = "2.1.0"` (gemini-client.ts:28), tracked in `functions/src/llm/PROMPT_CHANGELOG.md` (append-only, versioning rubric documented)

## Coupling

**Upstream feeds:** import pipeline tiers (`lib/services/parsing/tiers/llm_tier.dart`) call `LlmEnhancementService` as the last-resort tier after heuristic/CRF parsing fails or is low-confidence; social pipelines (Instagram/TikTok/YouTube) also call it directly (per test file list).

**Downstream consumers:** recipe save flow via `Recipe.personal(...)`, then the 5-phase auto-tagging engine and menu generator consume the resulting `Recipe` — but this is post-LLM, outside scope.

**Hidden/cross-cutting dependencies:**
- `hashUid` (`../shared/hash-uid`) — used as the stable per-user key for A/B bucketing and sample-capture logging (never raw UID)
- `../shared/ocr-url-validator` — SSRF gate specific to the OCR-URL path
- `ADR-001-gemini-retry-policy.md` — explicit architectural rule: **only** the Dart client retries (`RetryHelper.retryNetworkOperation`, maxRetries 2), server never retries on top (structure-recipe.ts:451-455) — except the OCR→structureRecipe in-process retry (ocr-retry.ts), which is a distinct, budget-gated retry, not a duplicate of the client retry.
- Dart/TS PII-scrubber duplication: `lib/services/llm/pii_scrubber.dart` must be kept byte-identical to `functions/src/llm/pii-scrubber.ts`, synced via a shared fixture `src/__tests__/fixtures/pii-heuristic-vectors.json` — a manual-sync liability documented in code comments (pii-scrubber.ts:12-16).
- `ConsentService` (llm_service.dart:38, `ConsentPurpose.aiProcessing`) gates all client-initiated LLM calls on GDPR Art. 5(1)(b) consent — not visible from the Cloud Functions side.
- `withRateLimit` middleware also performs authentication (`request.auth!.uid` used unchecked at structure-recipe.ts:90 and ocr-recipe-image.ts:115 — non-null assertion relies entirely on the middleware).

## Quality observations

1. **`extractTopLevelObjects`/salvage path fragility** (gemini-client.ts:487-557): character-by-character brace-balancing salvage for truncated ingredient arrays is intricate hand-rolled parsing logic with no fuzzing; a single test file (`parse-ingredient-lines.test.ts`) covers it, but it's the kind of logic that regresses silently on Gemini output-format drift.
2. **Kill switch fails open by design** (structure-recipe.ts:204-207) — documented intentional resilience choice, but worth flagging: if `system/config` doc read throws, the outer catch turns it into `internal` (fail closed for the user) while a genuinely *missing* doc/field fails open (all LLM calls proceed). The asymmetry is subtle and only explained in a code comment, not enforced by a type.
3. **`ocr-retry.ts:183-196` silently swallows `structureRecipe` retry exceptions** — `catch (error) { logger.warn(...) }`, converts any exception (network, quota, malformed) into a flat `retryOutcome: "failure"` with no error detail forwarded to the response; acceptable per BUT-559's stated intent but is genuine error-swallowing (only a log line survives).
4. **Non-null assertion on `request.auth!`** (structure-recipe.ts:90, ocr-recipe-image.ts:115) — safe only because `withRateLimit` is trusted to always populate `auth`; no defensive check in the LLM module itself. A future refactor of the middleware call order could silently NPE.
5. **Dual owner of "is this a recipe" logic** — `isNotRecipeResponse` (structure-recipe.ts:538) special-cases empty-array sentinel responses; this logic is entirely separate from `parseRecipeResponse`'s own validation (which also allows-through empty ingredient arrays before rejecting them at line 693). The ordering (`isNotRecipeResponse` checked before `parseRecipeResponse`) is load-bearing but not enforced by types — a reordering bug would silently misclassify "no recipe" as "parse failed" (wrong user-facing Swedish string).
6. **Prompt A/B experiment infrastructure is fully built but likely unused** — `promptVariants` field, `resolvePromptBucket`, `experimentBucket`/`promptVariant` threaded through every log line, yet nothing in scope shows an active experiment (`system/prompts` doc's `promptVariants` field is operator-set, no code default). Dead machinery unless an experiment is currently live — worth confirming with ops before assuming it's exercised.
7. **Two independent Vertex API cost constants files-of-truth risk**: `calculateGeminiCost` (gemini-client.ts:856) is the sole cost source, but the `TODO(BUT-1187)` at line 828 flags the pricing is unconfirmed against live rates — cost telemetry could be silently wrong.
8. **`buildContentParts` URL branch comment is stale/misleading** (ocr-recipe-image.ts:571-574): comment says "For simplicity, pass as fileData — Gemini handles HTTPS URLs" immediately after saying "we use inlineData after fetching" — the comment describes an approach not actually taken (no fetch occurs); minor doc drift.
9. **`redactionRatio` (pii-scrubber.ts:46) is exported but not observed being consumed** anywhere in the read files — appears to be an analytics/observability helper without a visible call site in this subsystem; possibly consumed by an out-of-scope caller, otherwise dead.

## Test coverage observed

TS tests in `functions/src/__tests__/`:
- `llm-kill-switch.test.ts` — pins BUT-439 dual kill-switch behavior (aiEnabled/llmParserEnabled) via `loadKillSwitch` seam
- `ocr-retry.test.ts` — pins retry decision tree (no-text/budget/success/failure outcomes) from ocr-retry.ts
- `ocr-validation.test.ts` — OCR URL SSRF/allowlist validation
- `parse-ingredient-lines.test.ts` — happy path + salvage/truncation path of `parseIngredientLinesResponse`
- `parse-recipe-response-description-length.test.ts`, `parse-recipe-response-difficulty.test.ts` — narrow pins on `parseRecipeResponse` coercion/validation edge cases (300-char clamp, difficulty enum drift logging)
- `structure-recipe-empty.test.ts` — empty-response handling
- `pii-scrubber.test.ts`, `fixtures/pii-heuristic-vectors.json` — regex-based PII scrub vectors, shared with the Dart mirror
- `prompt-ab-bucket.test.ts` — bucket assignment determinism/uniformity
- `prompt-changelog-guard.test.ts` — likely enforces PROMPT_VERSION bump ↔ changelog entry pairing (guards against silent prompt-only edits)
- `prompts-config.test.ts` — Firestore fallback/validation/cache-TTL/coalescing behavior
- `locale-instruction.test.ts` — `buildLocaleInstruction` sanitization (injection-defense on locale string)
- `gemini-cache-telemetry.test.ts` — `calculateGeminiCost` cached-token discount math
- `llm-sample-capture.test.ts` — capture enable/disable, truncation, best-effort-never-throws contract
- `app-check-enforcement.test.ts` — App Check gate on the callables

Dart-side:
- `test/unit/services/import/llm/llm_enhancement_service_test.dart` — pins `enhance`/`extractFromImage`/`extractFromHtml`/`extractFromTranscript` against a mocked `LlmService`
- `test/unit/services/llm/llm_service_circuit_breaker_test.dart` — circuit breaker trip/reset behavior
- `test/unit/services/llm/pii_scrubber_test.dart` + `pii_scrubber_heuristic_vectors_test.dart` — Dart mirror parity with the TS vectors
- `test/unit/services/parsing/tiers/llm_tier_test.dart` — pipeline-tier integration of the LLM fallback
- Pipeline tests (`instagram_pipeline_test.dart`, `tiktok_pipeline_test.dart`, `youtube_import_strategy_test.dart`) touch it as a downstream fallback, not the module's own contract

No test file was found directly covering `structure-recipe.ts`'s full `runStructureRecipe` orchestration (prompt selection by mode, A/B bucket wiring end-to-end, kill-switch → response shape integration) or `ocr-recipe-image.ts`'s `runOcrRecipeImage` orchestration as a whole — coverage is concentrated on the smaller pure-function units (`parseRecipeResponse`, `scrubPii`, bucket math, retry decision tree) rather than the top-level callable flow.

## Learning-loop hooks

- **`captureLlmSample`** (llm-sample-capture.ts) — every paid Gemini call (text and OCR) writes scrubbed input + scrubbed raw output + prompt version/bucket/variant/model/token counts to Firestore `llm_response_samples`, explicitly "so we can mine what we already pay for to improve the deterministic parser and prompts" (BUT-1451). 30-day TTL, admin-only access.
- **`structure_recipe.complete` / `ocr_recipe_image.complete`** structured Cloud Logging events (structure-recipe.ts:155, ocr-recipe-image.ts:285) — every exit path logs duration, success, mode/reason, token counts, `promptVersion`, `experimentBucket`, `promptVariant` — designed for zero-deploy Cloud Logging metric filters correlating quality/cost to prompt revisions.
- **`validateDifficulty`** (gemini-client.ts:758) emits a `logger.warn` when Gemini returns an out-of-enum difficulty value, explicitly to catch prompt/model drift (e.g. "advanced" instead of "hard").
- **`ingredient_lines_truncated` warning** (structure-recipe.ts:365-371) surfaces salvage-path usage so ops can gauge frequency and consider raising `INGREDIENT_LINE_MAX_TOKENS`.
- **`retryOutcome`/`retryCount`** fields (ocr-retry.ts, threaded through `ocr_recipe_image.complete`) let ops measure the OCR→text retry's success rate as a distinct signal.
- **`PROMPT_CHANGELOG.md`** — manual but structurally enforced (via `prompt-changelog-guard.test.ts`) discipline linking every `PROMPT_VERSION` bump to a dated changelog entry with expected-impact predictions, closing the loop from prompt edit → predicted metric movement → dashboard verification.
- No automatic feedback loop was found that *consumes* `llm_response_samples` back into prompt/parser changes within this scope — the capture exists, but the mining/analysis side (if any) lives outside `functions/src/llm/`.

---

# SUBSYSTEM MAP: tagging

I have enough load-bearing detail now. Producing the structural map.

## Purpose & entry points

The tagging subsystem auto-generates recipe tags (allergens, dietary, protein, dish-type, mood, cuisine, difficulty…) from ingredient text and recipe metadata, without any LLM — it's a deterministic rule engine over an ingredient database. Two entry points:

- `TaggingService.generateTags(Recipe)` (`lib/services/tagging/tagging_service.dart:73`) — full pipeline, called on recipe save/import.
- `TaggingService.generatePhase1Preview(Recipe)` (`tagging_service.dart:266`) — fast allergen/dietary-only preview during import UI, 5s timeout, calls `TagGenerator.generatePhase1Only` directly (bypassing the pipeline runner).

Batch entry points: `TaggingService.retagUserRecipes` (`tagging_service.dart:378`, user-triggered from settings) and `RetaggingScheduler` (`retagging_scheduler.dart`, app-startup + periodic auto-retag of failed/stale recipes). Admin-side batch trigger: `functions/src/admin/bulk-retag.ts` (`onCall` callable `bulkMarkForRetagging`, `getRetagStatus`) — marks Firestore recipe docs for client-side retag rather than tagging server-side itself.

## Flow (step-by-step)

1. `TaggingService._generateTagsCore` (`tagging_service.dart:84`) extracts `recipe.core.ingredientsNormalized ?? ingredients`; empty → `TagResult.empty()`.
2. `_generateTagsWithBudgets` (`tagging_service.dart:106`) delegates to `TaggingPipelineRunner.run` (`tagging_pipeline_runner.dart:196`).
3. Pipeline runner, each step wrapped in its own `Future.timeout` via `_runAsync` (`tagging_pipeline_runner.dart:343`):
   - Phase 0 `lookup` → `IngredientLookupService.lookupFromRaw` (budget 5s, `tagging_phase_budgets.dart:18`). Failure → **lookup floor**: safe-default `TagResult` with `timeout-warning` tag, all allergens `TriState.unknown` (`_lookupFloorResult`, `tagging_pipeline_runner.dart:408`).
   - Edge case: 0 matched / some unmatched → `TagResult.allUnknown` short-circuit (`tagging_pipeline_runner.dart:223`).
   - Phase 1 `TagPhase1Base.calculate` (budget 2s) — allergen (`Phase1AllergenCalculator`), dietary (`Phase1DietaryCalculator`), protein/carb (`Phase1NutritionCalculator`), cooking-method/dish-type (`Phase1MethodCalculator`), plus inline time tags. Failure here → **Phase-1 floor**: `TagResult.failed` (`tagging_pipeline_runner.dart:243`), no downstream phases run.
   - Phase 2 `TagPhase2Derived` (budget 5s) — dish-category/spicy-mild/few-ingredients from Phase 1 output. On failure, downstream phases get an *empty* `Phase2Result` wrapping the real Phase 1 (`tagging_pipeline_runner.dart:265`), not skipped entirely.
   - Phase 3 `TagPhase3Complex` (budget 10s, heaviest) — difficulty, high-protein, veggie/spice-rich, texture.
   - Phase 4 `TagPhase4Mood` (budget 5s) — season/occasion/mood.
   - Phase 5 `TagPhase5Cuisine` (budget 8s) — two paths: full chain (`phase5(phase4,…)`) if 2-4 all succeeded, else `phase5FromPhase1` fallback (CRIT-7) so cuisine tags survive even when 2-4 all failed.
   - `TagGenerator.assembleResult` (`tag_generator.dart:87`) unions all phase tag sets, resolves conflicts (`_resolveTagConflicts`, safety-priority pairs `stark>mild`, `avancerad>enkel`, `varm-rätt>kall-rätt`), builds final `TagResult` with `isPartial` flag if any phase was missing.
4. Back in `TaggingService`, `_statusFromPipeline` maps the phase trace to a legacy status string for the metrics dashboard (`tagging_service.dart:185`), metrics + analytics logged via `TaggingEventsTracker`.
5. Retag paths (`retagUserRecipes`, `RetaggingScheduler._retagRecipe`) call `_generateTagsCore` directly (bypassing `executeServiceOperation`'s error-swallowing) so failures propagate as actionable errors, batch in groups of 10 with 1s/5s delays.

Config load (separate from the tag-generation call graph): `TagConfigService.onInitialize` (`tag_config_service.dart:100`) fetches `FirebaseTagConfig` from Firestore `tag_configs` collection with 3x retry + 15s outer timeout, falls back to `SharedPreferences` cache, then to hardcoded static configs (`allergen_config.dart`, `dietary_config.dart`, `cuisine_config.dart`) if both fail — `TaggingService` holds a `TagGenerator` built once at construction from `tagConfigService?.configOrNull`, so a config reload after construction does **not** propagate into an existing `TagGenerator` instance (see Quality below).

Personal tags are a parallel, independent subsystem (`personal_tag_service.dart`, `personal_tag_crud_service.dart`, `personal_tag_rule_evaluator.dart`) — user-defined tags with rule conditions, merged with auto-tags only at display time by `TagResolutionService.resolve` (`tag_resolution_service.dart:22`), which itself only merges via `TagEditingService.getEffectiveTagData` (auto-tags + overrides), not via `TagGenerator`.

## Data shapes

- Input: `Recipe.core.ingredientsNormalized ?? .ingredients` (`List<String>`, raw ingredient lines).
- `IngredientLookupResult` (`lib/models/tagging/ingredient_lookup_result.dart`) — `matched: List<IngredientData>`, `unmatched: List<String>`, `coverage: double`. Produced by `IngredientLookupService.lookupFromRaw` → `IngredientParser.parseIngredient` (strip qty/unit) → `IngredientNormalizer.normalize` → dedupe → per-name `_findIngredient` (LRU cache → user ingredients → global exact → alias → fuzzy variations via `_generateLookupVariations`).
- `IngredientData` — `properties: Set<String>` (e.g. `is-spicy`, allergen trigger props), `group`, `status` (`draft` for AI-unvalidated entries, surfaces as `hasDraftIngredients` on the final `TagResult`).
- `Phase1Result` → `Phase2Result` → `Phase3Result` → `Phase4Result` → `Phase5Result`/`Phase5ResultPartial` — each phase result wraps the previous (`Phase2Result.phase1`, etc.) plus a `Set<String> tags`; shape widens phase-by-phase.
- `TagDecision` (`lib/models/tagging/tag_decision.dart`) — explains *why* an allergen/dietary status was set (reason string + triggering ingredients); attached to `TagResult.decisions`, surfaced in UI ("why is this tagged X").
- Final output: `TagResult` (`lib/models/tagging/tag_result.dart`) — `tags: Set<String>`, `allergenStatus`/`dietaryStatus: Map<String, TriState>` (`TriState` = contains/free/unknown), `coverage`, `unknownIngredients`, `isPartial`, `hasDraftIngredients`, `generatorVersion`, `decisions`.
- Firestore-facing config shape: `FirebaseTagConfig` (`lib/models/tagging/firebase_tag_config.dart`), loaded from `tag_configs/{allergens,dietary,cuisines,properties,display}` docs, uploaded via `functions/src/admin/seed-tag-configs.ts` from JSON produced by a separate `dart scripts/migrate_tag_configs.dart` (not in scope, referenced only).

## Config & thresholds

- `tagging_thresholds.dart` — central threshold catalogue (`highProteinRatio=0.40`, `veggieRichCount=3`, `spiceRichCount=3`, `easyMaxIngredients=6`, `easyMaxMinutes=30`, `advancedMinIngredients=12`, `advancedMinMinutes=60`, `mildCoverageThreshold=0.80`, `klimatsmartCoverage=0.80`, `budgetvanligCoverage=0.80`, `generationTimeout=30s` — unused now that per-phase budgets replaced the single wrapper timeout, see Quality).
- `tagging_phase_budgets.dart` — per-phase `Duration` constants: lookup 5s, phase1 2s, phase2 5s, phase3 10s, phase4 5s, phase5 8s = **35s total**, but the file's own doc comment (`tagging_phase_budgets.dart:11`) says "Total: 32s" — stale/incorrect comment.
- Phase 3/4 thresholds are duplicated in two places: hardcoded in `tagging_thresholds.dart` AND independently sourced from `FeatureFlagService` in `TagGenerator._createPhase3`/`_createPhase4` (`tag_generator.dart:126-148`, e.g. `FeatureFlags.tagEasyMaxIngredients`) — the feature-flag values are what's actually live in production; `TaggingThresholds` constants are the fallback defaults baked into the flag defs (not verified they stay in sync).
- `reserved_tags.dart` — builds a `Set<String>` of every auto-generated tag name (all 5 phases, ~120 literal tag strings hand-copied from phase code + dietary/allergen/cuisine configs) so personal-tag creation rejects name collisions. This list is **hand-maintained separately from the phase code that actually emits the tags** — any new tag added to a phase file must be manually mirrored here or a personal tag can silently shadow a system tag.
- `seed-tag-configs.ts` is a one-off CLI upload script (not a Cloud Function trigger) — admin runs it manually after `dart scripts/migrate_tag_configs.dart`; no automated CI/CD path keeps Firestore `tag_configs` in sync with code changes to `allergen_config.dart`/`dietary_config.dart` (those are the fallback statics, deliberately allowed to drift per the fallback design, but there's no drift detector).

## Coupling

**Upstream feeds:**
- `Recipe.core.ingredientsNormalized`/`.ingredients`, `.title`, `.instructions`, `.timeMinutes` (from parsing/import pipeline, out of scope here).
- `IngredientRepository`/`UserIngredientRepository` (Firestore-backed ingredient DB).
- `FeatureFlagService` (Phase 3/4 thresholds).
- `FirebaseTagConfig` via `TagConfigService` (allergen/dietary/cuisine rule config).
- `IngredientRegistryService` (`ServiceLocator.tryGet`, enriches normalization known-words list — soft dependency, silently absent if not registered).

**Downstream consumers:**
- `RecipeCore.tagResult` persisted to Firestore, read by menu generation (`MenuService`/`MenuGenerator`, per project memory: allergen filtering + tag-based scoring), allergen-mismatch banner (`AllergenMismatch`), shopping list is **not** downstream of tagging despite `ingredient_categorizer.dart` living in this directory (see Quality — it's actually shopping-list logic, unrelated to `TagResult`).
- `TagResolutionService`/`TagEditingService` merge auto-tags with user overrides for display — UI never reads raw `TagResult` directly.
- `functions/src/ratings/update-recipe-rating-stats.ts` and menu weighting (per project memory) consume `RecipeCore` fields but not `TagResult` directly.

**Hidden dependencies:**
- `TaggingService._getCurrentUserId()` (`tagging_service.dart:304`) reaches into `ServiceLocator.get<PermissionService>()` directly rather than constructor injection, silently swallowing any lookup failure to `null` — user-defined ingredient overrides silently stop applying if `PermissionService` isn't registered, with no log.
- `TagGenerator` is constructed once inside `TaggingService`'s field initializer from `tagConfigService?.configOrNull` (`tagging_service.dart:57-59`) — if `TagConfigService` finishes loading *after* `TaggingService` is constructed (plausible given async retry+cache fallback), the `TagGenerator` never sees the loaded config and stays on static fallback configs for the app's lifetime.

## Quality observations

1. **Dead code**: `TagGenerator.generate()` (`tag_generator.dart:165-341`, ~175 lines) is never called anywhere in `lib/` — `TaggingPipelineRunner` reimplements the same phase-sequencing logic independently via `runPhase1..5`/`assembleResult`, and `generatePhase1Only` is the only other public method actually used. `generate()` is a fully duplicated, unreachable implementation of the pipeline (confirmed via `grep -rn "\.generate(" lib` — zero call sites on `TagGenerator`).
2. **Duplicated logic**: The phase-skip / tag-union / conflict-resolution combination logic in `TagGenerator.generate()` (lines 300-341) is byte-for-byte duplicated in `TagGenerator.assembleResult()` (lines 98-124) and in `TaggingPipelineRunner.run` (isPartial computation, lines 322-336) — three copies of the same "what counts as partial" rule, only two of which (assembleResult + runner) are live, and they must be kept manually in sync.
3. **Misplaced file / ownership drift**: `lib/services/tagging/ingredient_categorizer.dart` has nothing to do with tag generation — it's shopping-list category bucketing (`ShoppingCategory`), explicitly noted in its own doc comment as "promoted from `ShoppingListGenerator`". It lives in the tagging directory purely by historical accident, is exempted from `BaseService` in `lib/services/CLAUDE.md` under the tagging heading, and will mislead anyone auditing "the tagging subsystem."
4. **Dead/unreachable branch inside that misplaced file**: `IngredientCategorizer.categorize` checks `'paprika'` in both the `veg` branch (`ingredient_categorizer.dart:81`) and the `spices` branch (`ingredient_categorizer.dart:117`); since veg is checked first and both use plain substring `.contains`, the spices-branch `paprika` check is unreachable dead code (though harmless since paprika-the-vegetable dominates paprika-the-spice-word usage anyway).
5. **Stale doc comment**: `tagging_phase_budgets.dart:11` claims "Total: 32s" but the six budgets sum to 35s (5+2+5+10+5+8).
6. **Error swallowing, by design but worth flagging**: `TaggingService.generateTags` routes through `executeServiceOperation` which converts exceptions to `null`; `retagUserRecipes`/`RetaggingScheduler` explicitly bypass this via `_generateTagsCore` with an inline comment explaining why — good, but it means *any other* caller of `generateTags` (e.g. import flow) gets a silent `null` on failure with no differentiation between "no ingredients" and "internal error," a design tension the code is aware of but doesn't fully resolve.
7. **Config staleness risk**: `TagGenerator` built once from `tagConfigService?.configOrNull` at `TaggingService` construction time (see Coupling) — a genuinely load-bearing bug risk since `TagConfigService.onInitialize` is async with retries/timeouts and there's no evidence anything re-creates `_tagGenerator` after config finishes loading late.
8. **Reserved-tags hand-maintenance**: `reserved_tags.dart`'s `_autoGeneratedTags` set (~120 literal strings) has no test or codegen tying it to the actual tag strings emitted by the phase files — a new tag string added to e.g. `tag_phase4_mood.dart` without a matching addition here would let a personal tag silently collide/override it.

## Test coverage observed

Extensive coverage — this is one of the better-tested subsystems in the repo:
- `test/unit/services/tagging/phases/tag_phase{1_allergen,1_base,2_derived,3_complex,4_mood,5_cuisine}_test.dart` — per-phase unit tests, pin individual tag-emission rules.
- `test/unit/services/tagging/tagging_pipeline_runner_test.dart` — pins the per-phase-budget/timeout/graceful-degradation contract described above (the injectable `TaggingPhaseCallables` seam exists specifically so tests can simulate a hang).
- `test/unit/services/tagging/timeout_handling_test.dart`, `tagging_edge_cases_test.dart`, `conflict_resolution_test.dart`, `exclusive_groups_test.dart`, `cuisine_detection_test.dart`, `hybrid_season_detection_test.dart`, `phase3_texture_detection_test.dart`, `phase4_holiday_detection_test.dart` — behavior-specific pins.
- `test/unit/services/tagging/allergen_key_consistency_test.dart`, `allergen_mismatch_test.dart` — safety-critical allergen logic, separately pinned from generic tagging tests (matches CLAUDE.md's allergen-safety-first framing).
- `test/unit/services/tagging/tag_generator_test.dart` — likely still exercises the dead `generate()` path (worth checking whether this test file is testing dead code rather than the live `TaggingPipelineRunner` path; not confirmed by reading, flagged as a probable gap since coverage numbers can look healthy while pinning an unreachable method).
- `test/golden/tagging_golden_test.dart` + `tagging_golden_dataset.json` — golden-set regression harness (ties into the `tools/corpus_eval.dart` / cookbook-gold-corpus project mentioned in memory).
- `test/corpus/tag_eval_core_test.dart`, `tag_metrics_test.dart`, `tag_scorecard_test.dart` — scorecard tests backing the `/tagcheck` skill.
- `test/performance/tagging_performance_test.dart` — perf regression guard.
- `test/integration/firebase/services/{tagging_integration,batch_tagging,recipe_tag_persistence,retagging_workflow}_test.dart`, `test/integration/tagging/import_tagging_integration_test.dart` — emulator-backed end-to-end.
- No test file found under this scope for `ingredient_categorizer.dart`'s tagging-directory placement being wrong, nor a test asserting `reserved_tags.dart` stays in sync with actual phase output — both are structural gaps rather than behavior gaps.

## Learning-loop hooks

- `TaggingEventsTracker` (`tagging_events_tracker.dart`) is the only feedback channel: logs `taggingPerformance`, `recipeTagged`, `unknownIngredients`, `personalTagCreated`, `personalTagRuleTriggered`, `dataIntegrityCheck`, `taggingCoverageAnomaly`, `taggingCacheDesync`, `taggingConfigValidationError` — all via `AnalyticsRepository.logEvent`, i.e. Firebase Analytics events, not a structured correction-capture store.
- `TagDecision` explanations (`decisions` on `TagResult`) are surfaced in the UI for user trust ("why tagged X") but there is no code path that captures a user *correcting* a wrong allergen/dietary status back into the tagging system — user overrides are stored per-recipe in `TagOverrides` (consumed only by `TagEditingService`/`TagResolutionService` for display), never fed back to retrain/adjust `AllergenConfig`/`DietaryConfig` rules or the ingredient DB. This is a one-way system: analytics events go out for dashboards, but nothing closes the loop from "user said this tag was wrong" to "the rule/ingredient data gets fixed" — that remains a manual admin task (`saveUserIngredient` lets a user teach the system a *missing* ingredient's properties, which is the one genuine learning hook: `tagging_service.dart:316`, invalidates the LRU cache immediately so the correction is live for that user on next lookup).
- `bulk-retag.ts` (`getRetagStatus`/`bulkMarkForRetagging`) is operational tooling for rolling out generator-version bumps, not a learning signal.

---

# SUBSYSTEM MAP: personalization

Enough context. Writing the final map.

## Purpose & entry points

This subsystem turns the recipe corpus (parsed + auto-tagged by the import pipeline) into a personalized weekly menu, applying three independent layers: (1) hard **filtering** (allergens/dietary/global constraints — safety), (2) soft **weighted scoring** (recency, season, rating, pantry, cuisine affinity, skill — preference), (3) **diversity enforcement** (cuisine clustering cap). Entry points:

- `MenuGenerator.generateMenuFromPrompt(prompt)` — `lib/viewmodels/menu/menu_generator.dart:314` — the UI-facing call for full menu generation.
- `MenuGenerator.regenerateMenuSection(section, currentMenu, ...)` — `menu_generator.dart:455` — single-slot re-roll (e.g. user hits "refresh" on one meal).
- `MenuGenerator.swapSingleRecipe(currentRecipe, category, currentMenu)` — `menu_generator.dart:494` — manual one-recipe swap, a *separate*, simpler scoring path (integer cuisine/category/season score, no `MenuScoringContext`).
- `MenuGenerator.getAvailableRecipesAsync()` — `menu_generator.dart:106` — the allergen/dietary-filtered pool, with three fallback tiers: present-diner union → household union → single-user prefs.

`PersonalTagService`/`PersonalTagRuleEvaluator` were named in scope but are **not actually wired into menu generation** — no reference in `menu_service.dart` or `menu_generator.dart` (verified via grep). They're a user-authored tagging/organization subsystem (auto-apply custom tags to recipes based on rules), orthogonal to menu personalization. Treated as out-of-flow for this map; flagged under Coupling below.

## Flow (step-by-step)

1. **User submits prompt** → `MenuGenerator.generateMenuFromPrompt` (`menu_generator.dart:314`).
2. `ensureRecipeServiceInitialized()` loads recipes if needed (`:301`).
3. `availableRecipes` getter (`:91`) applies **sync** single-user allergen/dietary filters (`_filterByAllergenPreferences`/`_filterByDietaryPreferences`, `:240`/`:271`) — this is the *default* pool for the sync prompt-generation path. Note: `getAvailableRecipesAsync()` (household/present-aware filtering) exists but is **not called from `generateMenuFromPrompt`** — that path only calls sync `availableRecipes`. Async household-aware filtering is used elsewhere (unclear caller; grep shows no in-repo caller of `getAvailableRecipesAsync` within this file's own methods — likely called directly by a ViewModel/View outside scope).
4. `_applyPromptKeywordFilter(prompt, pool)` (`:420`) — keyword heuristics ("favoriter"/"senaste") narrow the pool, with a `_minFilteredPoolSize = 3` fallback to full pool if too thin.
5. `_recentlyUsedRecipeIds()` (`:351`) — reads this-week + last-week `WeeklyMenuPlanService.getWeek()` plans (2 Firestore reads), builds a `Set<recipeId>` for cross-week dedup down-weighting. Swallows all errors → empty set.
6. `_buildScoringContext(pool)` (`:386`) — builds `MenuScoringContext`:
   - reads `_userService.currentUserProfile.cuisineAffinities` / `.cookingSkillLevel` (sync, in-memory).
   - calls `PantryService.getMatchingRecipes(userId, pool)` — one batched Firestore-ish call over the whole pool, memoized into `Map<recipeId, matchPercent>`. Wrapped in try/catch → empty map on failure (never blocks generation).
7. `MenuService.generateMenuFromPrompt(prompt, pool, recentlyUsedRecipeIds, scoringContext)` (`menu_service.dart:54`) → parses prompt via `MenuConstraintParser.parse` (deterministic lexicon-based NLP, not LLM) → `generateMenuFromParsedRequest` → `_generateFromParsedInternal` (`:380`).
8. Inside `_generateFromParsedInternal`:
   a. `_passesGlobals` (`:500`) — hard filter: global allergen-avoid / dietary-require / excluded-tag/ingredient constraints parsed from the prompt text itself (distinct from the profile-level filters in step 3).
   b. Day-pins resolved first (`:404`), e.g. "tacofredag" wins a fixed slot.
   c. Slot requests resolved (`:429`): sub-constraints matched via `_matchesConstraint` (`:530`, per-clause allergen/dietary/tag/cuisine/time), then `_weightedSelect` (`:183`) does cumulative-weight random draw using `_recipeWeight` (`:110`).
   d. `_enforceCuisineDiversity` (`:256`) post-processes the picks: if any cuisine has >2 in the slot, swap extras for the next-best-weighted non-duplicate via `_findDiverseReplacement` (`:321`), bounded iteration (`maxIterations = result.length * 2`).
9. Result `Map<mealType, List<Recipe>>` returned up through `MenuGenerator` to the caller/ViewModel/View unchanged.

Weight computation (`_recipeWeight`, `menu_service.dart:110`) chain, applied multiplicatively:
`daysSinceLastCooked(capped 90, floor 1)` × `seasonBoost(1.5x if seasonal tag)` × `_ratingMultiplier` (family-avg-if-present else public/personal rating, 1.0→1.4 linear) × `MenuScoringContext.multiplierFor` (pantry × cuisine × skill, from `menu_scoring.dart:81`) × `recentUseDecay (0.15x if in last-2-weeks plan)`.

## Data shapes

- **Input**: `List<Recipe>` (`lib/models/recipe_unified.dart`) — carries `core` (RecipeCore: rating, familyAverage/familyRatingCount, timeMinutes, instructions, ingredients), `tagResult` (auto-tag output: allergen/dietary TriState map + `tags` set), `mealType`, `lastCookedAt`, `isFavorite`. This is the parsed+tagged output of the import pipeline — the actual "consumption" boundary for this subsystem.
- **`MenuScoringContext`** (`menu_scoring.dart:23`) — immutable per-generation bundle: `pantryMatchByRecipeId: Map<String,double>`, `cuisineAffinities: Set<String>`, `skill: CookingSkillLevel?`. Constructed fresh each generation call in `MenuGenerator._buildScoringContext`; never persisted or cached across calls.
- **`ParsedMenuRequest`** (from `MenuConstraintParser.parse`) — day-pins + slot-requests + global constraints, shape unchanged by this diff.
- **Output**: `Map<String, List<Recipe>>` keyed by mealType string (not an enum) — same shape before/after the personalization changes (deliberately preserved for downstream weekly-plan distribution, per the doc comment at `menu_service.dart:356-359`).
- **`UserAllergenPreferences`** (`menu_generator.dart:161-197`) — ad-hoc unioned struct built in `_presentAllergenPrefs` for the present-diner-aware filtering path; distinct instance from `_userService.allergenPreferences`.

## Config & thresholds

All magic numbers are file-local constants with documented rationale, deliberately ranked so signals never cross:
- `menu_scoring.dart`: `pantryMaxBoost=1.3`, `cuisineAffinityBoost=1.25`, `beginnerSimpleBoost=1.15`, `beginnerComplexPenalty=0.85`, `advancedComplexBoost=1.1`, complexity thresholds `_simpleMaxMinutes=30`, `_complexMinMinutes=60`, `_simpleMaxSteps=5`, `_complexMinSteps=10`.
- `menu_service.dart`: `_maxRatingBoost=1.4` (documented as the ceiling all personalization boosts must stay under — enforced only by a unit test, not by code), season boost `1.5x` (hardcoded inline at `:128`, not a named constant — inconsistent with the others), `_recentUseDecay=0.15`, `maxDays=90` (local var in `_recipeWeight`, not a class constant).
- `menu_generator.dart`: `_minFilteredPoolSize=3` (`:418`).
- `_enforceCuisineDiversity`: hardcoded cluster cap of `2` per cuisine (`:291`,`:295`,`:337` — magic number `2` repeated 3x, not a named constant), `maxIterations = result.length * 2` safety bound (`:286`).
- No remote config / feature flags involved — every knob is a compile-time Dart constant. No seeds for `_random` in production (only test injects a seed via `Random?` constructor param, per the comment at `menu_service.dart:33-37`).

## Coupling

**Upstream feeds:**
- `RecipeUnified.tagResult` (auto-tagging engine output) → drives all allergen/dietary/tag/cuisine filtering and matching.
- `RecipeUnified.core.familyAverage`/`rating` (family-rating feature, separately built subsystem) → rating multiplier.
- `UserProfile.cuisineAffinities`/`cookingSkillLevel` (user-set preferences, via `UserService.currentUserProfile`) → scoring context.
- `PantryService.getMatchingRecipes` (separate pantry-matching subsystem) → pantry boost.
- `WeeklyMenuPlanService.getWeek` → recent-use dedup.
- `HouseholdRosterService`/`HouseholdRepository`/`PermissionService` (via `ServiceLocator.tryGet`, all optional) → present-aware allergen filtering.
- `MenuConstraintParser` + `LexiconProvider` (`lib/services/menu/parser/*`) → deterministic NLP parse of the prompt (not read in full here; skimmed by name only).

**Downstream consumers**: `Map<String, List<Recipe>>` flows to the weekly-plan distribution layer (`weekly_menu_plan_service.dart`, not read in depth) and the menu-generation UI/ViewModel. `SwapResult`/`swapSingleRecipe` is consumed by a separate swap-UI flow with its **own** un-unified scoring (integer point system, no `MenuScoringContext`, no allergen/rating/pantry — only cuisine+category+season, `menu_generator.dart:570-606`) — a second, parallel personalization implementation.

**Hidden dependency**: `getAvailableRecipesAsync()` (household/present-aware filtering, `:106`) is defined but not called anywhere inside `generateMenuFromPrompt`/`regenerateMenuSection` — those use only sync `availableRecipes` (single-user prefs). Household-level and present-diner allergen safety is therefore **not applied to prompt-based generation** unless some other caller (outside this file, not found in scope) invokes the async path directly before calling `_menuService`.

## Quality observations

- **`menu_generator.dart:314-344` (generateMenuFromPrompt) never calls `getAvailableRecipesAsync`** — uses sync `availableRecipes`, which only does single-user allergen/dietary filtering. So `useHouseholdAllergens` and `presentMemberIds` (both instance fields, presumably UI-toggled) are silently inert for the main generation flow; they only take effect through whatever separately calls `getAvailableRecipesAsync`. This is a real safety-relevant gap worth flagging if the family/household allergen feature is expected to gate weekly-menu generation, not just some other caller. Not filed as CONFIRMED without knowing the caller, but worth a targeted grep before assuming it's covered.
- **Season boost `1.5x` is an inline magic number** (`menu_service.dart:128`) not promoted to a named constant like every sibling boost — inconsistent style, and the doc comments at `MenuScoringContext` (`:49`) reference "season boost (1.5x)" as an external fact they must stay under, creating an implicit cross-file coupling with no compile-time enforcement (only test-asserted at `menu_personalization_test.dart:277` "every ceiling <= rating ceiling").
- **Cuisine-cluster cap `2` is a repeated literal** (`:291,295,337`) rather than a named constant — three places to update in sync if ever changed.
- **`swapSingleRecipe`'s scoring is a second, un-unified personalization path** (`menu_generator.dart:570-606`) — duplicates cuisine/season logic from `MenuService` with different weights (integer +3/+2/+1 vs multiplicative), and completely ignores rating, pantry, skill, and allergen-context personalization that the main generation path has. A user's manual swap gets a materially different (poorer) personalization surface than an auto-generated slot.
- **Error swallowing**: `_recentlyUsedRecipeIds` (`:351-374`) and `_buildScoringContext`'s pantry try/catch (`:394-405`) both swallow all exceptions to `AppLogger.warning`/`.debug`, by design (documented rationale: never block generation). This is a deliberate resilience choice, not a bug, but means a systemic PantryService or WeeklyMenuPlanService outage degrades personalization silently with no user-visible signal or telemetry counter — only a log line.
- **`_passesGlobals`** (`menu_service.dart:500`) treats `tagResult == null` as "include" (can't determine) — different failure-open policy than `MenuGenerator`'s own filters, which respect `includeUnknownInMenu` (`:253`, `:284`). Two different "unknown tag data" policies coexist in the same subsystem: profile-level filters are configurable (opt-in fail-closed), prompt-level global constraints always fail-open. Not necessarily wrong (prompt constraints are a different UX contract) but undocumented as an intentional divergence.
- Complexity bucket in `MenuScoringContext._complexityOf` (`menu_scoring.dart:119`) falls back from cook-time to step-count only when `timeMinutes == null`; if a recipe has `timeMinutes` between 30-60 it's `moderate` and gets no skill bias at all (not a bug, just means the beginner/advanced nudge only fires at the extremes — implicit design, undocumented threshold gap).

## Test coverage observed

- `test/unit/services/menu/menu_personalization_test.dart` (392 lines, new/uncommitted) — pins `_recipeWeight`/`MenuScoringContext` math directly: pantry overlap boost (full/partial/zero/absent), cuisine affinity boost, skill bias per level (beginner/advanced/intermediate) including step-count fallback, empty-context byte-for-byte parity with pre-personalization weight, ceiling ordering (`maxSkillBoost < debugMaxRatingBoost`, all personalization ceilings ≤ rating ceiling), and a statistical diversity-floor test ("no recipe exceeds 60% of 20 weeks across several seeds") guarding against any one boost stack dominating selection.
- `test/unit/viewmodels/menu/menu_generator_personalization_test.dart` (216 lines, new/untracked) — pins the plumbing in `MenuGenerator._buildScoringContext`: profile → context mapping, pantry-service-absent/failure graceful degradation, presumably asserting `MenuService.generateMenuFromPrompt` gets called with the right `scoringContext`.
- No test file found covering `swapSingleRecipe`'s separate scoring path against the personalization signals (consistent with it being an intentionally separate, simpler system — but also means its drift from the main path is untested).
- No test observed asserting `getAvailableRecipesAsync`/`presentMemberIds`/`useHouseholdAllergens` is actually invoked from the `generateMenuFromPrompt` call chain — consistent with the coupling gap noted above.

## Learning-loop hooks

- **None found in this subsystem.** No event logging of which recipes were selected/swapped/rejected for later model training, no correction capture (e.g. "user swapped this out" isn't fed back into cuisine/skill weighting), no online-learning or bandit mechanism. `AppLogger.debug`/`.warning` calls (`menu_service.dart:391`, `:445`) are diagnostic-only, not structured analytics events.
- The only feedback loop that *does* exist is indirect and downstream: user ratings (`recipe.core.rating`/`familyAverage`) feed back into `_ratingMultiplier` on the *next* generation — but that's the pre-existing rating subsystem, not something new here, and it's a simple lagging signal (whatever the rating docs say elsewhere), not an explicit "menu personalization" learning hook.
- `PantryService.getMatchingRecipes` and `WeeklyMenuPlanService.getWeek` are read-only signal sources into this subsystem; neither is written back to by menu generation (no "generation chose X, log it to pantry/plan history for future scoring" write-back beyond the plan itself being saved elsewhere, out of scope here).

---

# SUBSYSTEM MAP: learning-loop

Enough evidence gathered. Final report below.

## Purpose & entry points

The learning-loop subsystem captures **user-generated feedback signals** (parse-event telemetry, per-field corrections, tagging metrics, LLM sample capture) and feeds a subset of them back into product data (ingredient aliases, CRF retraining) or engineering dashboards. Entry points:

- **Client-side loggers** (fire-and-forget, never block the user flow):
  - `lib/services/parsing/parse_event_logger.dart` — calls CF `logParseEvent` per import attempt.
  - `lib/services/analytics/trackers/parse_events_tracker.dart` — per-tier Firebase Analytics events (`import_tier_succeeded/failed`).
  - `lib/services/parsing/feedback/parse_correction_uploader.dart` — calls CF `logParseCorrection` once per corrected field after a recipe save.
  - `lib/repositories/parsing_correction_repository.dart` — writes the aggregate-per-recipe correction doc directly to Firestore (`parsing_corrections` collection).
  - `lib/services/tagging/tagging_events_tracker.dart` — tagging pipeline health/perf events, no correction capture.
- **Server-side** (`functions/src/events/log-parse-event.ts`, `log-parse-correction.ts`) — validated callables that persist `parse_events` and `parse_corrections_v2`.
- **`functions/src/analytics/analyze-corrections.ts`** — Firestore trigger `analyzeCorrections` on `parsing_corrections/{id}` create; this is the *only* place a correction is read back automatically and turned into a product-data mutation (ingredient alias learning).
- **`functions/src/admin/export-corrections.ts`** + **`scripts/crf/retrain_with_corrections.sh`** — manual, human-triggered offline pipeline that turns corrections into a retrained CRF ingredient-parser model.
- **`functions/src/llm/llm-sample-capture.ts`** — best-effort capture of paid LLM call input/output to `llm_response_samples`, "so we can mine what we already pay for" — currently write-only, nothing reads it back (see Learning-loop hooks).
- **`tools/corpus/*` + `tools/corpus_eval.dart`** — a separate, offline gold-corpus regression harness (flea-market cookbook OCR scans vs. parser output), not wired to production Firestore telemetry at all.

## Flow (step-by-step)

**A. Parse-event telemetry (per import attempt)**
1. `RecipeParserService` / `UrlImportStrategy` finish an import attempt → call `ParseEventLogger.logEvent()` (`lib/services/parsing/parse_event_logger.dart:22`), payload built inline, `unawaited()` call to CF `logParseEvent` region-pinned to `europe-west1` (line 20; comment explains a real prior bug where default region caused silent drops).
2. Server `logParseEvent` (`functions/src/events/log-parse-event.ts:170`) requires auth, rate-limits (line 187), validates/clamps every field, then `await getDb().collection("parse_events").add(trustedFields)` (line 231) and updates `site_configs/{domain}` success/failure counters (lines 234-249) — this is a **direct feedback loop into site-config health stats** used elsewhere for domain-tier routing.
3. Additionally `recipe_parser_service.dart:838/844` calls `ParseEventsTracker.logTierSucceeded/logTierFailed` → Firebase Analytics events `import_tier_succeeded/failed` (BigQuery/Analytics, not Firestore).
4. On CF-call failure, `ParseEventLogger._emitFailureMetric` (line 74) logs `parseEventLogFailed` to Analytics so log-loss itself is observable (BUT-616).

**B. Per-field correction upload (on recipe save after edit)**
1. `RecipePersistenceManager._trackParsingCorrectionsInBackground` (`lib/viewmodels/recipe_form/recipe_persistence_manager.dart:474`) fires after a save, only if the recipe had a `sourceUrl` and an `originalParsedRecipe` snapshot exists.
2. `RecipeDiffCalculator.calculateDiff()` builds a `ParsingCorrection` aggregate (original vs corrected fields).
3. Two parallel writes, both fire-and-forget:
   - `ParsingCorrectionRepository.save(correction)` (line 498) → **aggregate doc** in `parsing_corrections/{id}` (client-direct Firestore write, rule-gated to own uid).
   - `ParseCorrectionUploader.uploadWithSharedSalt(correction)` (line 505) → fan-out into N per-field payloads via `expandFields()` (`parse_correction_uploader.dart:104`), hashes user/recipe IDs (line 201-202, reusing the BUT-421 analytics salt), truncates to 500 chars, skips whitespace/case-only diffs, then calls CF `logParseCorrection` once per field (line 218).
4. Server `logParseCorrection` (`functions/src/events/log-parse-correction.ts:188`) re-validates everything (tier/field allowlists, hash regex), re-runs `scrubPii` + drops if redaction ratio > 0.5 (defence-in-depth against PII poisoning, line 155-160), writes to `parse_corrections_v2` (line 227). This collection has no client read/write rule at all — admin-SDK only (doc comment line 30-31).
5. `analyzeCorrections` trigger fires on the **aggregate** doc (`parsing_corrections`, not `_v2`) (`analyze-corrections.ts:117`): updates `analytics/parsing/corrections/{domain}` stats (lines 137-147, `aggregateDomainStats`) and, for each `nameChanged` ingredient correction, calls `processAliasCandidate` (line 168) which looks up the corrected name against `ingredients` (exact/lowercase/alias/learnedAlias match, `findIngredientByName` lines 53-109), tracks distinct correcting users in `analytics/ingredients/learned_aliases/{docId}`, and **auto-approves + writes `learnedAliasesSv` onto the live `ingredients/{id}` doc** once 3 distinct users agree (`ALIAS_APPROVAL_THRESHOLD = 3`, lines 269-291). This is the one truly automatic "learning" mutation in the whole subsystem.

**C. Offline CRF retraining (human-triggered)**
1. `scripts/crf/retrain_with_corrections.sh` stage 1 runs `functions/src/admin/export-corrections.ts` — reads the **whole** `parsing_corrections` collection (not `_v2`), extracts `ingredientCorrections`, dedupes by `correctedLine`, writes `scripts/crf/data/corrections.json`.
2. Stage 2 `dart run scripts/crf/export_corrections.dart` converts to CoNLL.
3. Stage 3 merges with base `training.conll`.
4. Stage 4 `python scripts/crf/train_crf.py` retrains → overwrites `assets/data/crf_ingredient_weights.json`, which ships in the app bundle and is loaded by the CRF ingredient-line parser at runtime. Nothing automatically re-runs this pipeline — it is a manual dev-ops step.

**D. Ingredient master-data sync (adjacent, not a feedback loop)**
- `fetch-livsmedelsverket.ts` fetches Swedish food DB → CSV candidates for **human review**.
- `sync-ingredients.ts` applies CSV → Firestore `ingredients` (dry-run/force flags).
- `export-ingredients.ts` exports Firestore `ingredients` → JSON → `generate_known_ingredients.dart` codegens `lib/constants/known_ingredients.dart`. This chain never reads corrections; it's the ingredient-master pipeline that the alias-learning loop (B.5) mutates into.

**E. Tagging telemetry** — `TaggingEventsTracker` (`lib/services/tagging/tagging_events_tracker.dart`) logs performance/coverage/anomaly/cache-desync events to Firebase Analytics only. No Firestore correction capture, no read-back — it's pure observability, not a learning loop.

**F. LLM sample capture** — `captureLlmSample()` (`functions/src/llm/llm-sample-capture.ts:86`) writes scrubbed input+output to `llm_response_samples` with a 30-day TTL (`expireAt`, line 95-97) and a kill switch `system/config.llmSampleCaptureEnabled` (fail-open, lines 34-50). Stated purpose in the file's own docstring is "so we can mine what we already pay for to improve the deterministic parser and the prompts" — but no code path anywhere in the repo reads `llm_response_samples` back (see Quality observations).

## Data shapes

- `ParsingCorrection` (`lib/models/parsing/parsing_correction.dart`) — aggregate model: `id, recipeId, userId, timestamp, source, domain, successfulTier, originalQuality, titleCorrection, portionsCorrection, timeCorrection, ingredientCorrections[], instructionCorrections[]`. Written verbatim (raw, unhashed userId/recipeId) to `parsing_corrections`.
- `PerFieldCorrection` (`parse_correction_uploader.dart:35`) — `{correctedField, fromValue, toValue}`, one per corrected field, expanded from `ParsingCorrection`. Shape changes here: ingredient/instruction line-lists collapse into one newline-joined "before/after" string per field (not one doc per line) — deliberate to bound doc explosion (comment lines 142-146).
- Server `parse_corrections_v2` doc shape (`log-parse-correction.ts` `ValidationResult.write.doc`, line 172): `{correctedField, fromValue (scrubbed), toValue (scrubbed), sourceTier, promptVersion?, domain?, userIdHash, recipeIdHash, schemaVersion:'v2-perfield', createdAt}`. Tier vocabulary is **translated** client→server via `_dartToServerTier` (`parse_correction_uploader.dart:20-30`, e.g. `SchemaOrg`→`schema_org`) — two parallel enum spaces kept manually in sync (client map + server `VALID_TIERS` in `log-parse-event.ts:23-26` and `log-parse-correction.ts:42-53`, plus a *third* copy of tier names implicit in `export-corrections.ts` output, which uses the *client* CamelCase names since it reads `parsing_corrections`, not `_v2`).
- `parse_events` doc (`log-parse-event.ts:209-228`): `{userId, url, domain, source, success, fromCache, parseTimeMs, parserVersion, timestamp, successfulTier, finalQuality, usedLlm, totalCostSek, tierAttempts[], unknownDomain?}`.
- `analytics/ingredients/learned_aliases/{docId}` — `{originalName, correctedName, ingredientId, userIds[], count, firstSeen, lastSeen, status: pending|approved}`.
- `llm_response_samples` doc (`llm-sample-capture.ts:99-124`) — scrubbed input/output text + token counts + `expireAt` TTL field.

## Config & thresholds

- `kMaxCorrectionValueChars = 500` (client, `parse_correction_uploader.dart:15`) mirrored server-side as `MAX_VALUE_CHARS = 500` (`log-parse-correction.ts:63`) — "defence in depth", two independently maintained constants.
- `HEAVY_REDACTION_THRESHOLD = 0.5` (`log-parse-correction.ts:69`) — drop correction if PII scrub redacted >50% of either value.
- `ALIAS_APPROVAL_THRESHOLD = 3` distinct users (`analyze-corrections.ts:29`) — auto-writes to live ingredient data, no human review gate.
- `RETENTION_DAYS = 30` for `llm_response_samples` (`llm-sample-capture.ts:23`), `ENABLE_CACHE_MS = 5min` for the enable-flag cache (line 31).
- `MAX_FIELD_CHARS = 50_000` truncation bound for LLM sample storage (line 26).
- Rate limits: `logParseEvent` 30/min·10refill (`log-parse-event.ts:187` comment), `logParseCorrection` 60/min (`log-parse-correction.ts:203-205`) — configured elsewhere in `RATE_LIMIT_CONFIGS` (not read in this scope).
- `VALID_TIERS`/`VALID_SOURCES`/`VALID_FIELDS` allowlists duplicated across 3 files (client Dart map, `log-parse-event.ts`, `log-parse-correction.ts`).
- `HASH_REGEX = /^[a-f0-9]{16,128}$/i` sanity check on client-supplied hashes (`log-parse-correction.ts:66`).

## Coupling

**Upstream feeds:**
- `RecipeParserService` / `UrlImportStrategy` (3-tier import pipeline) → `ParseEventLogger`, `ParseEventsTracker`.
- `RecipeFormViewModel` → `RecipePersistenceManager` → correction diff calculator → both correction sinks.
- BUT-421 per-install analytics salt (`FirebaseAnalyticsRepository.saltPrefsKey`) is a **hard dependency** for per-field upload — if the salt hasn't loaded yet, `uploadWithSharedSalt` silently returns 0 (`parse_correction_uploader.dart:251-256`), meaning early-session corrections can be dropped entirely.
- `scrubPii`/`redactionRatio` (`functions/src/llm/pii-scrubber.ts`) shared between `log-parse-correction.ts` and `llm-sample-capture.ts`.

**Downstream consumers:**
- `analyzeCorrections` trigger → live `ingredients/{id}.learnedAliasesSv` (feeds the ingredient-lookup/tagging pipeline directly — production-mutating).
- `site_configs/{domain}` success/failure counters (written by `logParseEvent`) — consumed elsewhere by the tier-selection/site-config strategy logic (out of scope here, but this *is* a feedback loop: parse outcomes change future routing for that domain).
- `export-corrections.ts` → `scripts/crf/*` → `assets/data/crf_ingredient_weights.json`, a bundled app asset. This is a **build-time, not run-time** feedback loop — requires a human to run the shell script and ship a new build.
- Admin dashboard (per docs, `docs/security/llm-sample-retention.md`, `docs/FEATURE_INVENTORY.md`) references parse-health concepts but the memory notes ("Admin dashboard" / "Parsing-detaljer tab") indicate this reads `parse_events`/`analytics/parsing/corrections` for display — a pure telemetry consumer, not a learning loop.

**Hidden/implicit dependencies:**
- Two Firestore collections (`parsing_corrections` aggregate vs `parse_corrections_v2` per-field) exist in parallel with **different consumers** and no cross-reference — a developer reading only `log-parse-correction.ts`'s docstring (lines 10-16) would correctly infer this is intentional, but nothing enforces the two writes stay consistent; a failure in one path (e.g. `ParsingCorrectionRepository.save` throws and is swallowed) silently starves `analyzeCorrections` while `parse_corrections_v2` still gets data, or vice versa.
- `export-corrections.ts` and `analyzeCorrections`' alias-learning both parse `ingredientCorrections[].type === 'reordered'`/`nameChanged` conventions that live only in the Dart `ParsingCorrection`/`IngredientCorrection` model — schema contract enforced by convention, not shared types (TS and Dart, no codegen).

## Quality observations

1. **`llm_response_samples` is captured but never read back** — `functions/src/llm/llm-sample-capture.ts:1-3` states the purpose is "to improve the deterministic parser and the prompts," but a repo-wide grep found no reader of that collection anywhere (no export script, no admin function, no `tools/` usage). This is a write-only cost sink with a 30-day TTL — data is deleted before anyone builds the promised mining tool. (functions/src/llm/llm-sample-capture.ts:1-16)
2. **Two independently-maintained tier vocabularies (3 copies)** — `_dartToServerTier` map (`parse_correction_uploader.dart:20-30`), `VALID_TIERS` in `log-parse-event.ts:23-26`, and `VALID_TIERS` in `log-parse-correction.ts:42-53` must all stay in sync by hand; a new tier added to the Dart parser but forgotten in one of the two server allowlists will silently drop data (`log-parse-correction.ts` throws `invalid-argument`; `expandFields`/`upload` in the client silently returns 0 and logs debug only, `parse_correction_uploader.dart:190-199`).
3. **Silent-drop-on-unknown-tier** — `ParseCorrectionUploader.upload()` returns `0` and just logs debug (`parse_correction_uploader.dart:193-198`) if `correction.successfulTier` isn't in the map; the caller (`recipe_persistence_manager.dart:504`) never inspects the return value, so there is no telemetry-on-telemetry-failure here (contrast with `ParseEventLogger._emitFailureMetric`, which *does* self-report failures). Correction-upload failures are strictly invisible.
4. **Salt-not-loaded silently drops corrections** (`parse_correction_uploader.dart:251-256`) — a new/early-session user's very first corrections (arguably the most valuable signal — first-import friction) can be lost with only a debug log, no retry, no queue.
5. **Everything in this subsystem swallows errors by design** ("telemetry must never block the user") — consistent and intentional, but means there is no failure-rate visibility for the correction-upload path specifically (only for `logParseEvent`, via `_emitFailureMetric`). A systemic failure (e.g. a schema change breaking `logParseCorrection` validation) would be invisible until someone manually queries `parse_corrections_v2` volume.
6. **`export-corrections.ts` reads the aggregate `parsing_corrections` collection**, not the per-field `parse_corrections_v2` collection introduced by BUT-595 specifically to make field-level correction data queryable (docstring says so, `log-parse-correction.ts:6-9`). The CRF retraining pipeline therefore never benefits from the PII-heavy-redaction skip (`HEAVY_REDACTION_THRESHOLD`) or server-side re-scrub applied only on the `_v2` write path — the aggregate doc is scrubbed only by the client's own diff calculator (not verified in this scope, but no server-side scrub exists on the `parsing_corrections` write path since it's a direct client Firestore write, not a callable).
7. **`analyzeCorrections`' alias auto-approval has no human review gate or ability to demote** — 3 distinct users agreeing on a wrong correction (e.g. a shared typo, or coordinated bad-faith input) permanently mutates `ingredients/{id}.learnedAliasesSv` in production with no revert path visible in this scope (`analyze-corrections.ts:269-291`). `findIngredientByName` only guards that the *target* is a real ingredient, not that the *mapping* is sane.
8. **Dead/duplicated collection design risk**: the `parsing_corrections` aggregate doc and `parse_corrections_v2` per-field docs both exist to answer overlapping questions ("what did users fix"), split by an explicit "don't break the alias-learning trigger" decision (`log-parse-correction.ts:10-16`) rather than a clean redesign — acknowledged tech debt in the code comment itself, not silently accrued.
9. **No composite-index concern flagged** — `getByDomain`/`getByTier` in `parsing_correction_repository.dart` use single-equality + orderBy, which per this repo's accepted-deviations note about equality-only queries would still need a composite (orderBy + equality does need one) — worth confirming an index exists, not verified in this pass.

## Test coverage observed

- `test/unit/services/analytics/parse_events_tracker_test.dart` — pins `ParseEventsTracker` event/param shape (tier success/fail).
- `test/unit/services/parsing/feedback/parse_correction_uploader_test.dart` — exercises `expandFields`, `isWhitespaceOrCaseOnly`, `truncate`, `hashId`, and `upload()` against an injected `CallableInvoker` (per the file's own doc comment, this is the intended test seam).
- `test/unit/repositories/parsing_correction_repository_test.dart` — repository CRUD/GDPR-delete behavior.
- `test/unit/repositories/parse_events_repository_test.dart` — presumably a parallel client-side repo/tracker not covered above (not read in this pass; flagged for awareness).
- `test/unit/models/parsing/{field,ingredient,instruction,parsing}_correction_test.dart` — model-level round-trip/serialization pins.
- `functions/src/__tests__/log-parse-correction.test.ts` — server callable validation pipeline (`validateAndPreparePayload`), likely pins the whitespace/PII-heavy skip paths and hash/tier allowlists.
- `functions/src/__tests__/parse-corrections-v2-rules.test.ts` — Firestore rules test confirming `parse_corrections_v2` is admin-SDK-only (no client read/write), matching the doc comment's stated contract.
- No test file was found exercising `analyzeCorrections`' alias-approval logic, `llm-sample-capture.ts`, `export-corrections.ts`, or the CRF retrain shell pipeline — these are the least-covered parts of the loop, consistent with them being offline/admin-triggered rather than user-facing.

## Learning-loop hooks (summary)

| Signal captured | Where | Fed back into | Automatic? |
|---|---|---|---|
| Parse success/failure + tier + cost | `parse_events` (Firestore) | `site_configs/{domain}` success/failure counters (routing signal) | Yes, same CF call |
| Per-tier funnel | Firebase Analytics (`import_tier_succeeded/failed`) | BigQuery/dashboards only | N/A (observability) |
| Per-recipe field corrections (aggregate) | `parsing_corrections` | `analyzeCorrections` trigger → `analytics/parsing/corrections/{domain}` stats + ingredient alias learning → live `ingredients/{id}.learnedAliasesSv` | **Yes — the only fully automatic model/data update in scope** |
| Per-recipe field corrections (aggregate) | `parsing_corrections` | `export-corrections.ts` → CRF retraining → `assets/data/crf_ingredient_weights.json` | No — manual script run, ships in next build |
| Per-field corrections (scrubbed, granular) | `parse_corrections_v2` | Nothing found reading it back in this scope | No consumer found |
| Paid LLM call input/output | `llm_response_samples` | Nothing found reading it back; 30-day TTL deletes it first | Write-only, unused |
| Tagging coverage/perf/anomalies | Firebase Analytics events | Dashboards only | N/A (observability) |

---

# SUBSYSTEM MAP: test-inventory

Enough evidence gathered. Compiling the map.

## Purpose & entry points

The test-inventory subsystem is the automated-test coverage of the import → extraction → parsing → tagging → menu-personalization pipeline, split across three trees:

- **Dart unit tests** (`test/unit/services/{import,extraction,parsing,tagging,menu}/`, `test/unit/viewmodels/menu/`, `test/unit/models/{parsing,tagging,menu}/`) — cover Flutter-side services/viewmodels.
- **Cloud Functions tests** (`functions/src/__tests__/*.test.ts`) — cover the Gemini LLM structuring, OCR, and prompt-config path.
- **Corpus/eval harness** (`test/corpus/*`, `test/tools/corpus_*`, `tools/corpus/*.dart`) — offline OCR/parse accuracy scoring against a "gold" flea-market cookbook corpus, run manually via `dart run tools/corpus_eval.dart`.

Entry points examined in full: `test/unit/services/menu/menu_personalization_test.dart`, `test/unit/services/tagging/tagging_pipeline_runner_test.dart`, `test/unit/services/parsing/recipe_parser_service_test.dart`, `test/unit/services/tagging/phases/tag_phase1_allergen_test.dart`, `test/unit/services/import/import_manager_test.dart` (partial), `test/unit/services/extraction/site_parsers/ica_recipe_parser_test.dart` (partial), `test/corpus/corpus_multi_layout_test.dart`, `functions/src/__tests__/ocr-validation.test.ts` (partial).

## Flow (step-by-step)

1. **Import layer tests** (`test/unit/services/import/*`) drive `ImportManager.withStrategies(...)` with a real `TextImportStrategy` + a `MockImportStrategy` (mocktail) — `import_manager_test.dart:43-135`. Strategy selection (`autoImport`, `getCompatibleStrategies`, preferred-strategy fallback) is exercised against real Swedish recipe text; the downstream repository write is mocked (`MockPersonalRecipeOperations.addUnifiedRecipe`).
2. **Extraction/site-parser tests** (`test/unit/services/extraction/site_parsers/*`) feed static JSON-LD fixture strings (`fixtures/swedish_sites/ica_test_data.dart`) straight into `IcaRecipeParser.parseRecipe(html)` — no mocking at all, pure input→output on real parser code (`ica_recipe_parser_test.dart:24-120`), including a documented quality-gate rejection case (<3 ingredients).
3. **Parsing-tier tests** (`test/unit/services/parsing/recipe_parser_service_test.dart`) construct `RecipeParserService` with injected fakes (`StubLlmService`, `FakeLocalRecipeCache`, `StubParsingTier`) and drive it through `parseFromText`/`parseFromUrl` against a full Swedish pancake recipe fixture (lines 86-99) and hand-built HTML/JSON-LD. This is the most rigorous file in scope: it pins the security gate (null-byte/`data:text/html`, lines 167-229), the tier short-circuit threshold at exactly 0.65 (lines 606-656), LLM-cost gating (lines 383-442), analytics fire-and-forget swallowing (797-879), and a cache circuit-breaker trip after 3 failures (1154-1196).
4. **Tagging pipeline tests** (`test/unit/services/tagging/tagging_pipeline_runner_test.dart`) inject a `TaggingPhaseCallables` bundle of phase functions (not the phases' internals) into `TaggingPipelineRunner.forTesting`, and use `fakeAsync`/`Future.delayed` to simulate a hang in each of Phase 2/3/5/1 in turn, asserting per-phase timeout budgets (5000/10000/8000ms) and that later phases still run off the last-good phase result (lines 139-234, 238-331). The one true "generator not mocked" real-logic seam: `TagGenerator()` is real (line 55) so `assembleResult` combination logic is exercised for real.
5. **Phase-level allergen tests** (`tag_phase1_allergen_test.dart`) call `Phase1AllergenCalculator.calculate(lookup, null)` directly against hand-built `IngredientLookupResult`s, pinning the tri-state FREE/CONTAINS/UNKNOWN safety contract, including the OR-combined-allergen case (nuts) and the coverage<1.0→UNKNOWN safety floor (lines 57-76).
6. **Menu personalization tests** (`test/unit/services/menu/menu_personalization_test.dart`) call `MenuService.debugRecipeWeight(...)` (a debug-only static accessor) directly against `RecipeFactory`-built recipes and `MenuScoringContext` variants, then separately run the **real** `MenuService.generateMenuFromParsedRequest` with a seeded `Random` across 20 simulated weeks × 3 seeds to assert a diversity floor (max 60% share for any one recipe) — this is a genuine statistical/behavioral test, not a mock-driven unit test (lines 352-390).
7. **Cloud Functions tests** (`ocr-validation.test.ts`, `parse-ingredient-lines.test.ts`, `prompts-config.test.ts`, etc.) are hand-rolled (no Jest/Mocha framework detected in the sampled files) — they use a `record()`/pass-fail console harness (`ocr-validation.test.ts:30-47`) and monkey-patch `firebase-functions/logger` to capture structured log fields (lines 58-80) rather than using a spy library.
8. **Corpus tests** (`test/corpus/corpus_multi_layout_test.dart`) build temp-directory fixture trees (flat single-recipe vs nested multi-recipe-per-image layouts) and assert `CorpusPaths.recipeEntries`/`loadEntries` discover the right entry set — this tests the *harness's file-discovery logic*, not parser accuracy itself.

## Data shapes (inputs/outputs, key models, where the shape changes)

- `ParseResult` (success/failure factory pair) — `recipe_parser_service_test.dart:102-165` pins that `.failure` **never** carries a recipe (contract: UI must not render a fabricated recipe on failure).
- `TagResult` / `TagDecision` / `IngredientLookupResult` — tri-state (`TriState.free/contains/unknown`) allergen status keyed by allergen string (`gluten`, `mjölk`, `ägg`, `nötter`), each with a `decisions` list carrying `triggeringIngredients` for audit (`tag_phase1_allergen_test.dart:78-96`).
- `TaggingPipelineResult` — carries `outcomes` (per-phase `TaggingPhaseOutcome{phaseIndex, phaseName, budgetMs, result}`) plus final `tagResult.isPartial`/`errorReason`/`generatorVersion` (the `'failed'` sentinel on floor-case).
- `MenuScoringContext` — carries `pantryMatchByRecipeId`, `cuisineAffinities`, `skill` (enum `CookingSkillLevel`), with documented ceilings (`pantryMaxBoost`, `cuisineAffinityBoost`, `maxSkillBoost`) tested to stay below `MenuService.debugMaxRatingBoost` (menu_personalization_test.dart:269-292) — a **cross-cutting product invariant** pinned as a test, not just a code comment.
- Corpus gold/draft JSON shape (`_goldJson`, corpus_multi_layout_test.dart:12-15): `{verified, title, ingredients:[{name, originalLine, quantity, unit}], instructions:[...]}` — minimal, synthetic, not a real scanned-cookbook fixture in this particular test (real OCR text fixtures live elsewhere in `test/fixtures/corpus`, not read here).

## Config & thresholds (magic numbers, remote config, seeds)

- Tagging phase budgets: Phase1 (floor, no explicit ms shown but treated as failure-fatal), Phase2=5000ms, Phase3=10000ms, Phase5=8000ms (`tagging_pipeline_runner_test.dart:182,263,309`).
- Parsing tier quality threshold: `defaultQualityThreshold = 0.65`, with `>=` (not `>`) semantics deliberately pinned on both sides of the boundary (0.65 short-circuits, 0.649 does not) — `recipe_parser_service_test.dart:606-656`.
- Cache circuit breaker: `failureThreshold = 3` (recipe_parser_service.dart:152-155 per test comment) — 4th call short-circuits (lines 1154-1196).
- Menu diversity floor: `maxShare <= 0.6` across 20 simulated weeks, 3 fixed seeds (`20260701, 42, 1337`) — deliberately not a single seed, to avoid a lucky-draw false pass (lines 345-390).
- ICA quality gate: recipe rejected if <3 ingredients or no instructions (`ica_recipe_parser_test.dart:41-50`), asserted by fixture not by reading the source threshold directly.

## Coupling (what upstream feeds it, what downstream consumes it, hidden dependencies)

- Import tests depend on `RecipeFactory` (shared test factory) and `TestServiceLocator`/`BaseUnitTest` — the production DI bridge (`ServiceLocator.initialize(DIContainer())`) is spun up per suite (setUpAll/tearDown), meaning many of these tests are **integration-flavored unit tests**, not pure unit tests: they exercise real `TextImportStrategy` and real `MenuService` weighting/generation logic, with only the repository write layer mocked out.
- `recipe_parser_service_test.dart` explicitly documents what it does **not** cover: `init()`/cache paths requiring a real `OfflineService` + Drift DB are called out as out-of-unit-scope (file header, lines 22-27) — a known, acknowledged blind spot rather than a silent one.
- Cloud Functions tests hijack `firebase-functions/logger` globally by reassigning its methods (`ocr-validation.test.ts:70-80`) — this is a *shared mutable module patch*, not a proper test double; if these files run in the same process/import graph as other function tests without restoring the original methods, cross-test log-capture bleed is a latent risk (no `afterEach` restore visible in the read excerpt).
- `MenuScoringContext` ceilings are asserted to be below `MenuService.debugMaxRatingBoost` — a debug-only static, meaning this safety invariant is only checked via test-visible debug surface, not enforced by a runtime assertion in production code (if `debugRecipeWeight`/`debugMaxRatingBoost` get stripped in a refactor, this whole invariant test silently loses its anchor).
- Corpus eval harness (`tools/corpus/*.dart`) is invoked from tests but is also a manual CLI tool (`dart run tools/corpus_eval.dart`) — per project memory, wired-but-unverified pending real scan data/keys, so its "test coverage" of real-world OCR accuracy is currently more scaffold than signal.

## Quality observations

- `functions/src/__tests__/*.test.ts` use a **hand-rolled pass/fail harness** (`record()` + console.log, `ocr-validation.test.ts:30-47`) instead of a standard test runner (Jest/Mocha) — no evidence of `describe/it`/assertion library; this means these files are executed as plain scripts (`npx ts-node ...` per header comment line 13), so they likely aren't wired into a conventional `npm test` / CI test-discovery glob unless explicitly listed — a real risk of these tests silently not running in CI if the invocation list drifts. Worth verifying against `functions/package.json` test script (not read in this pass).
- `recipe_parser_service_test.dart:757-794` ("no failures → userMessage is null… state resets per call") has a weaker-than-ideal assertion: it explicitly says "userMessage may be null or point to the last failure — either is fine", which is a soft assertion rather than pinning one specific expected behavior — the test proves *consistency* across calls, not *correctness* of the value itself.
- `import_manager_test.dart` mixes a real `TextImportStrategy` with a `MockImportStrategy`, which is good (doesn't mock the subject away), but the "should auto-detect text strategy and parse" test (lines 91-109) only asserts `isSuccess`/`strategy != null` — it does not assert the parsed recipe's actual field values (title, ingredient count), so a regression that parses garbage-but-non-null output would pass.
- `ica_recipe_parser_test.dart` tests are pure fixture→output assertions with zero mocking, which is exemplary — but fixtures are synthetic ICA-shaped JSON-LD strings authored by the test suite, not captured real-world HTML snapshots, so site-format drift (ICA changing their JSON-LD schema) would not be caught until a real import fails in production.
- `tagging_pipeline_runner_test.dart` mocks the phase *callables* (functions), not the phases' internal logic — a deliberate, well-documented choice (file header lines 13-17) that keeps `TagGenerator.assembleResult` real. This is the right mocking boundary; contrast with weaker patterns elsewhere.
- `corpus_multi_layout_test.dart` tests file-discovery plumbing (`CorpusPaths`) with synthetic single-ingredient recipes — it does not validate actual OCR/parse accuracy against the "flea-market cookbook" gold corpus that's the stated purpose of the corpus harness (per project memory, this harness is "wired-but-unverified pending prelabel keys+scans"), so the corpus_eval numeric accuracy claims aren't exercised by CI at all currently.

## Test coverage observed (files touched, what they pin)

| Area | File | Pins |
|---|---|---|
| Menu personalization | `test/unit/services/menu/menu_personalization_test.dart` | pantry/cuisine/skill weight boosts, ceiling-below-rating invariant, 20-week diversity floor with real generation + seeded RNG |
| Menu generation (broader) | `test/unit/viewmodels/menu/menu_generator_test.dart` (1379 lines, not fully read) | largest menu test file — likely the widest surface, worth a deeper follow-up pass |
| Tagging pipeline resilience | `test/unit/services/tagging/tagging_pipeline_runner_test.dart` | per-phase timeout budgets, partial-result assembly, floor-case failure, structured phase-outcome logging |
| Tagging phase 1 allergens | `test/unit/services/tagging/phases/tag_phase1_allergen_test.dart` | tri-state FREE/CONTAINS/UNKNOWN safety contract incl. OR-combined allergens |
| Tagging edge cases | `test/unit/services/tagging/tagging_edge_cases_test.dart` (177 lines, skimmed only) | not deeply read this pass |
| Recipe parsing tiers | `test/unit/services/parsing/recipe_parser_service_test.dart` | security gate, tier short-circuit threshold boundary (both sides), LLM cost gating, cache hit/miss/version-invalidation/circuit-breaker, analytics swallow-on-failure |
| Site parser (ICA) | `test/unit/services/extraction/site_parsers/ica_recipe_parser_test.dart` (461 lines) | JSON-LD extraction, quality-gate rejection, Swedish-char handling, ICA-specific enhancement fields |
| Other site parsers | `arla_`, `koket_`, `recept_recipe_parser_test.dart`, `site_parser_registry_test.dart` | present but not read this pass — same fixture-driven pattern presumed |
| Import strategy orchestration | `test/unit/services/import/import_manager_test.dart` (517 lines) | strategy selection/fallback with mocked repo write, real TextImportStrategy |
| Import strategies (per-source) | `archive_`, `file_import_paprika_`, `photo_import_`, `text_import_`, `url_import_`, `youtube/youtube_import_strategy_test.dart` | present, not individually read |
| Cloud Functions LLM/OCR | `ocr-validation.test.ts`, `ocr-retry.test.ts`, `parse-ingredient-lines.test.ts`, `parse-recipe-response-{description-length,difficulty}.test.ts`, `prompts-config.test.ts`, `prompt-ab-bucket.test.ts`, `prompt-changelog-guard.test.ts`, `llm-kill-switch.test.ts`, `llm-response-samples-rules.test.ts`, `llm-sample-capture.test.ts` | SSRF/host-pinning validation for OCR image URLs, response-shape/length/difficulty guards, prompt A/B bucketing + changelog-guard (prevents undocumented prompt edits), kill-switch behavior |
| Corpus/eval harness | `test/corpus/corpus_multi_layout_test.dart`, `corpus_prelabel_test.dart`, `test/tools/corpus_eval_core_test.dart`, `corpus_metrics_test.dart` | file-discovery/layout logic and metrics-math, not real OCR accuracy (corpus data itself is pending per project memory) |

## Learning-loop hooks (events logged, corrections captured, anything fed back)

- `functions/src/__tests__/log-parse-correction.test.ts` and `log-parse-event-domain.test.ts` cover the correction/telemetry logging path that feeds `parse_events_repository` / `parsing_correction_repository` (Dart-side counterparts: `test/unit/repositories/parse_events_repository_test.dart`, `parsing_correction_repository_test.dart`).
- `test/unit/services/parsing/feedback/parse_correction_uploader_test.dart` covers uploading user corrections back to Firestore for future model/heuristic improvement — this is the client-side half of the parse-correction learning loop.
- `test/unit/services/tagging/retagging_scheduler_test.dart` covers scheduled re-tagging (presumably triggered when tagging config/rules change), which is the tagging-side equivalent of a feedback/re-processing loop.
- `functions/src/__tests__/prompt-changelog-guard.test.ts` is a distinctive learning-loop guard: it enforces that prompt-text changes are accompanied by a changelog entry, which is a governance/audit hook on the LLM-prompt side rather than a runtime data-feedback loop.
- No test in the areas sampled directly exercises a closed-loop "correction → retrain/re-tag → verify improved accuracy" cycle; the corpus eval harness (`tools/corpus/tag_eval_core.dart`, `tag_metrics.dart`) is architecturally positioned to be that measurement tool but, per the file `test/corpus/corpus_multi_layout_test.dart` and project memory, is not yet exercised against real corrections/gold data end-to-end.