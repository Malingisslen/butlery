# Butlery Import System — Updated Master Plan v2.0
## Incorporating Current Infrastructure + 2025 LLM Enhancements

**Generated:** 2025-12-05
**Based on:** Current system audit + original architecture plan + LLM capability updates

---

## Executive Summary

This document provides a **delta-based implementation plan** — showing exactly what to ADD, MODIFY, KEEP, and REMOVE from the current Butlery import system to achieve the target architecture.

### Current State (From Audit)
- ✅ 5 import strategies working
- ✅ 4 Swedish site parsers (ICA, Arla, Köket, Recept)
- ✅ JSON-LD + Microdata extraction
- ✅ Headless browser fallback
- ✅ Multi-provider OCR with circuit breakers
- ✅ Comprehensive Swedish/English ingredient parsing

### Key Gaps to Address
- ❌ No Global Recipe Cache (cross-user deduplication)
- ❌ No YouTube transcript/video extraction
- ❌ No LLM fallback for complex extractions
- ❌ No User-Assisted Import screen
- ❌ Limited TikTok/Instagram extraction

### Strategic Approach
**Build incrementally on existing infrastructure** — don't replace what works.

---

# PART 1: ARCHITECTURE CHANGES OVERVIEW

## 1.1 Change Summary Table

| Component | Current Status | Action | Priority |
|-----------|---------------|--------|----------|
| **InputClassifier** | Partial (`platform_detector.dart`) | MODIFY | P1 |
| **ImportRouter** | Exists (`import_manager.dart`) | MODIFY | P1 |
| **GlobalRecipeCache** | Does not exist | ADD | P1 |
| **UrlNormalizer** | Does not exist | ADD | P1 |
| **RateLimiter** | Does not exist | ADD | P1 |
| **ImageMatcher** | Does not exist | ADD (defer) | P4 |
| **ContentMatcher** | Does not exist | ADD | P2 |
| **Website Pipeline** | Good (3 tiers) | MODIFY (expand to 5 tiers) | P2 |
| **YouTube Pipeline** | Detection only | ADD | P2 |
| **TikTok Pipeline** | Basic scraping | ADD | P3 |
| **Instagram Pipeline** | Caption only | MODIFY | P3 |
| **Facebook Pipeline** | Basic OG | KEEP (low priority) | P4 |
| **OCR Pipeline** | Good (3 providers) | MODIFY (add LLM tier) | P2 |
| **Text Pipeline** | Comprehensive | KEEP + minor enhance | P3 |
| **LLM Enhancement Service** | Does not exist | ADD | P2 |
| **User-Assisted Import** | Does not exist | ADD | P2 |
| **JSON-LD Parser** | Exists (`recipe_scraper.dart`) | KEEP | - |
| **Site Parsers** | 4 Swedish sites | KEEP | - |
| **Ingredient Parser** | Comprehensive | KEEP | - |

## 1.2 Updated Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              USER INPUT                                      │
│                    URL  |  Image  |  Text  |  File                          │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                    INPUT CLASSIFIER (MODIFY: platform_detector.dart)         │
│   Detect: YouTube | TikTok | Instagram | Facebook | Website | Image | Text  │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                    GLOBAL RECIPE CACHE (ADD: NEW)                            │
│                                                                              │
│   URL Hash ──▶ Firestore lookup ──▶ HIT? ──▶ Return cached recipe           │
│                                                                              │
│   Content Fingerprint ──▶ Check for duplicates ──▶ HIT? ──▶ Return cached   │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼ MISS
┌─────────────────────────────────────────────────────────────────────────────┐
│                    IMPORT ROUTER (MODIFY: import_manager.dart)               │
│                Route to appropriate pipeline based on input type             │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
        ┌───────────┬───────────┬───┴───┬───────────┬───────────┐
        ▼           ▼           ▼       ▼           ▼           ▼
   ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐
   │ Website │ │ YouTube │ │ TikTok  │ │  Insta  │ │   OCR   │ │  Text   │
   │ MODIFY  │ │   ADD   │ │   ADD   │ │ MODIFY  │ │ MODIFY  │ │  KEEP   │
   │ 5 tiers │ │ 6 tiers │ │ 4 tiers │ │ 3 tiers │ │ 4 tiers │ │ 3 tiers │
   └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘
        │           │           │           │           │           │
        └───────────┴───────────┴─────┬─────┴───────────┴───────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         EXTRACTION RESULT                                    │
│                                                                              │
│   SUCCESS (≥80% confidence) ──────────────────────────▶ Save to cache       │
│                                                              │               │
│   PARTIAL (50-80% confidence) ──▶ LLM ENHANCEMENT (ADD) ───▶│               │
│                                                              │               │
│   FAILURE (<50% confidence) ──▶ LLM FULL EXTRACTION (ADD) ──┤               │
│                                          │                   │               │
│                                          ▼                   ▼               │
│                               Still failed? ──▶ USER-ASSISTED MODE (ADD)    │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                    UNIFIED OUTPUT                                            │
│              ExtractedRecipe ──▶ Recipe Model ──▶ Firestore                 │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

# PART 2: FILES TO KEEP (No Changes)

These files are working well and should not be modified:

## 2.1 Site-Specific Parsers
```
✅ KEEP: lib/services/extraction/site_parsers/ica_recipe_parser.dart
✅ KEEP: lib/services/extraction/site_parsers/arla_recipe_parser.dart
✅ KEEP: lib/services/extraction/site_parsers/koket_recipe_parser.dart
✅ KEEP: lib/services/extraction/site_parsers/recept_recipe_parser.dart
✅ KEEP: lib/services/extraction/site_parsers/recipe_site_parser.dart (base class)
✅ KEEP: lib/services/extraction/site_parsers/site_parser_registry.dart
✅ KEEP: lib/services/extraction/site_parsers/recipe_quality_scorer.dart
```

## 2.2 JSON-LD / Schema.org Parsing
```
✅ KEEP: lib/utils/recipe_scraper.dart
```
This already handles JSON-LD and Microdata extraction correctly.

## 2.3 Ingredient Parsing
```
✅ KEEP: lib/utils/text/ingredient_parser.dart
✅ KEEP: lib/utils/text/ingredient_processor.dart
✅ KEEP: lib/utils/text/ingredient_normalizer.dart
✅ KEEP: lib/utils/text/unit_converter.dart
```
Comprehensive Swedish/English support already exists.

## 2.4 Text Import Strategy
```
✅ KEEP: lib/services/import/text_import_strategy.dart
```
Well-implemented with keyword detection and structure parsing.

## 2.5 File/Archive Import
```
✅ KEEP: lib/services/import/file_import_strategy.dart
✅ KEEP: lib/services/import/archive_import_strategy.dart
```
These work and are outside scope of this update.

## 2.6 Base Infrastructure
```
✅ KEEP: lib/services/import/import_strategy.dart (interface)
✅ KEEP: lib/services/extraction/web_scraper.dart (headless browser)
```

---

# PART 3: FILES TO MODIFY

## 3.1 InputClassifier Enhancement

**File:** `lib/services/extraction/platform_detector.dart`

**Current capabilities:**
- Detects social media platforms from URL
- Returns platform type enum

**Modifications needed:**
```dart
// ADD: Input type classification (not just platform)
enum InputType {
  youtubeUrl,
  tiktokUrl,
  instagramUrl,
  facebookUrl,
  pinterestUrl,
  swedishRecipeSite,  // ICA, Arla, etc.
  genericWebsite,
  image,
  plainText,
  jsonFile,
  unknown,
}

// ADD: Method to classify any input
InputType classifyInput(dynamic input) {
  if (input is Uint8List) return InputType.image;
  if (input is String) {
    if (_looksLikeUrl(input)) {
      return _classifyUrl(input);
    }
    if (_looksLikeJson(input)) return InputType.jsonFile;
    return InputType.plainText;
  }
  return InputType.unknown;
}

// ADD: Swedish site detection
static const _swedishRecipeSites = {
  'ica.se', 'arla.se', 'koket.se', 'recepten.se',
  'tasteline.com', 'mittkok.expressen.se',
};

// ENHANCE: Better URL pattern matching
InputType _classifyUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return InputType.unknown;
  
  final host = uri.host.replaceFirst('www.', '').toLowerCase();
  
  // Check Swedish sites first (they have custom parsers)
  if (_swedishRecipeSites.any((s) => host.contains(s))) {
    return InputType.swedishRecipeSite;
  }
  
  // Then check social platforms
  if (host.contains('youtube.com') || host.contains('youtu.be')) {
    return InputType.youtubeUrl;
  }
  // ... etc
}
```

**Lines to change:** ~50-100 additions

---

## 3.2 ImportManager Enhancement

**File:** `lib/services/import/import_manager.dart`

**Current capabilities:**
- Routes to appropriate strategy
- Tries strategies in order until success

**Modifications needed:**
```dart
// ADD: Cache check before any extraction
Future<ImportResult> autoImport(String input, {Map<String, dynamic>? options}) async {
  // NEW: Check global cache first
  final cacheResult = await _globalCache.findByInput(input);
  if (cacheResult != null) {
    return ImportResult.success(
      recipe: cacheResult.recipe,
      fromCache: true,
      cacheHit: true,
    );
  }
  
  // EXISTING: Detect input type and get strategies
  final inputType = _inputClassifier.classifyInput(input);
  final strategies = _getStrategiesForInputType(inputType);
  
  // ENHANCED: Track tiers and confidence
  ExtractionAttempt? bestAttempt;
  
  for (final strategy in strategies) {
    if (strategy.canHandle(input)) {
      final result = await strategy.import(input, options: options);
      
      // NEW: Track best attempt even if not fully successful
      if (result.confidence > (bestAttempt?.confidence ?? 0)) {
        bestAttempt = ExtractionAttempt(
          result: result,
          strategy: strategy.name,
          tier: strategy.currentTier,
        );
      }
      
      if (result.isSuccess && result.confidence >= 0.8) {
        // NEW: Save to global cache
        await _globalCache.save(input, result);
        return result;
      }
    }
  }
  
  // NEW: If we have partial results, try LLM enhancement
  if (bestAttempt != null && bestAttempt.confidence >= 0.5) {
    final enhanced = await _llmEnhancer.enhance(bestAttempt);
    if (enhanced.isSuccess) {
      await _globalCache.save(input, enhanced);
      return enhanced;
    }
  }
  
  // NEW: Return NeedsAssistance for user-assisted mode
  return ImportResult.needsAssistance(
    partialData: bestAttempt?.result.partialData,
    extractedText: bestAttempt?.result.rawText,
    message: 'Kunde inte extrahera receptet automatiskt. Hjälp oss hitta ingredienserna.',
  );
}

// ADD: Dependency injection for new services
final GlobalRecipeCache _globalCache;
final InputClassifier _inputClassifier;
final LlmEnhancementService _llmEnhancer;
```

**Lines to change:** ~100-150 additions/modifications

---

## 3.3 URL Import Strategy Enhancement

**File:** `lib/services/import/url_import_strategy.dart`

**Current tiers:**
1. Static HTTP → JSON-LD/Microdata
2. Headless WebView
3. Text parsing

**New tier structure:**
```dart
// MODIFY: Expand to 5 tiers with better tracking

enum WebsiteTier {
  jsonLd,           // Tier 1: Schema.org (FREE)
  siteSpecific,     // Tier 2: Custom parsers (FREE)
  heuristicHtml,    // Tier 3: CSS selectors (FREE)
  headlessBrowser,  // Tier 4: WebView (FREE but slow)
  llmExtraction,    // Tier 5: LLM fallback (PAID)
}

class UrlImportStrategy implements ImportStrategy {
  WebsiteTier _currentTier = WebsiteTier.jsonLd;
  
  @override
  Future<ImportResult> import(String url, {Map<String, dynamic>? options}) async {
    final html = await _fetchHtml(url);
    if (html == null) return ImportResult.failure('Kunde inte hämta sidan');
    
    // Tier 1: JSON-LD (EXISTING - keep)
    _currentTier = WebsiteTier.jsonLd;
    final jsonLdResult = _recipeScraper.extractFromJsonLd(html);
    if (jsonLdResult != null && _qualityScorer.score(jsonLdResult) >= 0.8) {
      return ImportResult.success(recipe: jsonLdResult, tier: _currentTier);
    }
    
    // Tier 2: Site-specific parser (EXISTING - keep)
    _currentTier = WebsiteTier.siteSpecific;
    final parser = _parserRegistry.getParserForUrl(url);
    if (parser != null) {
      final parsed = await parser.parse(html, url);
      if (parsed != null && _qualityScorer.score(parsed) >= 0.8) {
        return ImportResult.success(recipe: parsed, tier: _currentTier);
      }
    }
    
    // Tier 3: Heuristic HTML (NEW)
    _currentTier = WebsiteTier.heuristicHtml;
    final heuristicResult = _heuristicParser.parse(html);
    if (heuristicResult != null && _qualityScorer.score(heuristicResult) >= 0.7) {
      return ImportResult.success(recipe: heuristicResult, tier: _currentTier, requiresReview: true);
    }
    
    // Tier 4: Headless browser (EXISTING - keep)
    _currentTier = WebsiteTier.headlessBrowser;
    final webViewHtml = await _webScraper.scrape(url);
    if (webViewHtml != null) {
      // Re-try tiers 1-3 on rendered HTML
      final webViewResult = await _extractFromHtml(webViewHtml, url);
      if (webViewResult != null) {
        return ImportResult.success(recipe: webViewResult, tier: _currentTier);
      }
    }
    
    // Tier 5: LLM extraction (NEW)
    _currentTier = WebsiteTier.llmExtraction;
    if (options?['allowLlm'] != false) {
      final llmResult = await _llmExtractor.extractRecipe(html, url);
      if (llmResult != null) {
        return ImportResult.success(recipe: llmResult, tier: _currentTier, usedLlm: true);
      }
    }
    
    // All tiers failed - return partial with best attempt
    return ImportResult.partial(
      rawHtml: html,
      extractedText: _stripHtml(html),
      confidence: 0.3,
    );
  }
}
```

**Lines to change:** ~150-200 additions/modifications

---

## 3.4 OCR Service Enhancement

**File:** `lib/services/ocr_extraction_service.dart`

**Current tiers:**
1. OCR.space (Engine 2)
2. Google Vision
3. Tesseract

**New tier structure:**
```dart
// MODIFY: Add LLM tier and reorder for cost optimization

enum OcrTier {
  tesseract,      // Tier 1: FREE, good for printed
  ocrSpace,       // Tier 2: FREE (25k/mo), better for Swedish
  googleVision,   // Tier 3: PAID ($1.50/1k), excellent quality
  llmVision,      // Tier 4: PAID (~$0.01), understands context (NEW)
}

class OcrExtractionService {
  // KEEP: Existing circuit breaker pattern
  // KEEP: Existing SHA256 caching
  
  Future<OcrResult> extractText(Uint8List imageBytes, {
    bool allowLlm = true,
    String? languageHint,
  }) async {
    // KEEP: Check cache first
    final cacheKey = sha256.convert(imageBytes).toString();
    final cached = _cache.get(cacheKey);
    if (cached != null) return cached;
    
    // REORDER: Tesseract first (FREE)
    final tesseractResult = await _tryTesseract(imageBytes, languageHint ?? 'swe+eng');
    if (tesseractResult.confidence >= 0.8) {
      _cache.set(cacheKey, tesseractResult);
      return tesseractResult;
    }
    
    // KEEP: OCR.space second
    final ocrSpaceResult = await _tryOcrSpace(imageBytes);
    if (ocrSpaceResult.confidence >= 0.8) {
      _cache.set(cacheKey, ocrSpaceResult);
      return ocrSpaceResult;
    }
    
    // KEEP: Google Vision third
    final visionResult = await _tryGoogleVision(imageBytes);
    if (visionResult.confidence >= 0.8) {
      _cache.set(cacheKey, visionResult);
      return visionResult;
    }
    
    // NEW: LLM Vision as final tier (understands recipes!)
    if (allowLlm) {
      final llmResult = await _tryLlmVision(imageBytes);
      if (llmResult != null) {
        _cache.set(cacheKey, llmResult);
        return llmResult;
      }
    }
    
    // Return best result even if low confidence
    return _selectBestResult([tesseractResult, ocrSpaceResult, visionResult]);
  }
  
  // NEW: LLM Vision extraction
  Future<OcrResult?> _tryLlmVision(Uint8List imageBytes) async {
    // Use Claude or GPT-4o Vision to extract recipe directly
    // This understands context - knows what a recipe looks like
    final response = await _llmService.extractRecipeFromImage(imageBytes);
    if (response != null) {
      return OcrResult(
        text: response.rawText,
        structuredRecipe: response.recipe, // Bonus: already parsed!
        confidence: 0.9,
        tier: OcrTier.llmVision,
      );
    }
    return null;
  }
}
```

**Lines to change:** ~80-100 additions

---

## 3.5 Instagram Extractor Enhancement

**File:** `lib/services/extraction/extractors/instagram_content_extractor.dart`

**Current capabilities:**
- Caption extraction only

**Modifications needed:**
```dart
// ENHANCE: Add OCR fallback for image posts

class InstagramContentExtractor {
  final OcrExtractionService _ocrService;
  
  Future<ExtractionResult> extract(String url) async {
    // KEEP: Try oEmbed first
    final oembed = await _getOembed(url);
    if (oembed != null) {
      final captionResult = _parseCaptionForRecipe(oembed.title);
      if (captionResult.hasIngredients) {
        return ExtractionResult.success(captionResult);
      }
    }
    
    // NEW: Request user screenshot if caption doesn't have recipe
    return ExtractionResult.needsScreenshot(
      platform: 'Instagram',
      thumbnailUrl: oembed?.thumbnailUrl,
      message: 'Instagram-inläggets text innehöll inget recept. '
               'Ta en skärmbild av receptet och ladda upp den.',
    );
  }
  
  // NEW: Process uploaded screenshot
  Future<ExtractionResult> processScreenshot(Uint8List imageBytes) async {
    final ocrResult = await _ocrService.extractText(imageBytes, allowLlm: true);
    
    if (ocrResult.structuredRecipe != null) {
      return ExtractionResult.success(ocrResult.structuredRecipe!);
    }
    
    if (ocrResult.text.isNotEmpty) {
      // Try text parsing on OCR result
      final parsed = _textParser.parseRecipeText(ocrResult.text);
      if (parsed.hasIngredients) {
        return ExtractionResult.success(parsed, requiresReview: true);
      }
    }
    
    return ExtractionResult.needsAssistance(
      extractedText: ocrResult.text,
      message: 'Vi kunde läsa texten men inte hitta receptet. Markera ingredienserna.',
    );
  }
}
```

**Lines to change:** ~60-80 additions

---

# PART 4: FILES TO ADD (New)

## 4.1 Global Recipe Cache

**New file:** `lib/services/import/cache/global_recipe_cache.dart`

```dart
/// Cross-user recipe cache service
/// Checks if URL/content has been imported before by ANY user
class GlobalRecipeCache {
  final FirebaseFirestore _firestore;
  final UrlNormalizer _urlNormalizer;
  final ContentFingerprint _fingerprinter;
  
  static const _collection = 'globalRecipeCache';
  static const _defaultTtlDays = 90;
  
  /// Check cache before extraction
  Future<CachedRecipe?> findByInput(dynamic input) async {
    if (input is String && _looksLikeUrl(input)) {
      return findByUrl(input);
    }
    // Image and text don't cache well (too much variation)
    return null;
  }
  
  /// Find by URL hash
  Future<CachedRecipe?> findByUrl(String url) async {
    final hash = _urlNormalizer.hash(url);
    
    final doc = await _firestore
        .collection(_collection)
        .doc(hash)
        .get();
    
    if (!doc.exists) return null;
    
    final entry = CacheEntry.fromFirestore(doc.data()!);
    
    // Check TTL
    if (_isExpired(entry)) {
      doc.reference.delete(); // Cleanup
      return null;
    }
    
    // Update access stats (fire and forget)
    _updateAccessStats(doc.reference);
    
    return entry.recipe;
  }
  
  /// Find by content fingerprint (same recipe from different sources)
  Future<CachedRecipe?> findByContent(ExtractedRecipe recipe) async {
    final fingerprint = _fingerprinter.generate(recipe);
    
    final query = await _firestore
        .collection(_collection)
        .where('contentFingerprint', isEqualTo: fingerprint)
        .limit(1)
        .get();
    
    if (query.docs.isEmpty) return null;
    
    final entry = CacheEntry.fromFirestore(query.docs.first.data());
    if (_isExpired(entry)) return null;
    
    return entry.recipe;
  }
  
  /// Save to cache after successful extraction
  Future<void> save(dynamic input, ImportResult result) async {
    if (!result.isSuccess) return;
    
    String? urlHash;
    String? domain;
    
    if (input is String && _looksLikeUrl(input)) {
      urlHash = _urlNormalizer.hash(input);
      domain = Uri.parse(input).host.replaceFirst('www.', '');
    }
    
    final contentFingerprint = _fingerprinter.generate(result.recipe!);
    
    final entry = CacheEntry(
      urlHash: urlHash,
      contentFingerprint: contentFingerprint,
      domain: domain,
      sourceType: result.sourceType,
      recipe: result.recipe!.toMap(),
      extractionMeta: ExtractMeta(
        pipeline: result.pipeline,
        tier: result.tier,
        method: result.method,
        confidence: result.confidence,
      ),
      ttlDays: _getTtlForSource(result.sourceType),
    );
    
    final docId = urlHash ?? _firestore.collection(_collection).doc().id;
    
    await _firestore
        .collection(_collection)
        .doc(docId)
        .set(entry.toFirestore());
  }
  
  int _getTtlForSource(String sourceType) {
    switch (sourceType) {
      case 'youtube': return 180;  // Rarely changes
      case 'website': return 90;
      case 'tiktok':
      case 'instagram': return 60; // More ephemeral
      default: return _defaultTtlDays;
    }
  }
  
  bool _isExpired(CacheEntry entry) {
    final age = DateTime.now().difference(entry.cachedAt);
    return age.inDays > entry.ttlDays;
  }
  
  void _updateAccessStats(DocumentReference ref) {
    ref.update({
      'accessCount': FieldValue.increment(1),
      'lastAccessedAt': FieldValue.serverTimestamp(),
    }).catchError((_) {}); // Ignore errors
  }
}
```

---

## 4.2 URL Normalizer

**New file:** `lib/services/import/cache/url_normalizer.dart`

```dart
/// Normalizes URLs for consistent cache keys
class UrlNormalizer {
  /// Tracking parameters to strip
  static const _trackingParams = {
    'utm_source', 'utm_medium', 'utm_campaign', 'utm_term', 'utm_content',
    'fbclid', 'gclid', 'ref', 'source', 'mc_cid', 'mc_eid',
  };
  
  /// Normalize URL for comparison
  String normalize(String url) {
    var uri = Uri.parse(url.toLowerCase().trim());
    
    // Remove www prefix
    var host = uri.host.replaceFirst('www.', '');
    
    // Remove tracking parameters
    final cleanParams = Map<String, String>.from(uri.queryParameters)
      ..removeWhere((key, _) => _trackingParams.contains(key.toLowerCase()));
    
    // Sort remaining parameters
    final sortedParams = Map.fromEntries(
      cleanParams.entries.toList()..sort((a, b) => a.key.compareTo(b.key))
    );
    
    // Rebuild URL
    uri = uri.replace(
      host: host,
      queryParameters: sortedParams.isEmpty ? null : sortedParams,
    );
    
    // Remove trailing slash
    var path = uri.path;
    if (path.endsWith('/') && path.length > 1) {
      path = path.substring(0, path.length - 1);
    }
    
    return uri.replace(path: path).toString();
  }
  
  /// Generate hash for cache key
  String hash(String url) {
    final normalized = normalize(url);
    return sha256.convert(utf8.encode(normalized)).toString();
  }
}
```

---

## 4.3 Content Fingerprint

**New file:** `lib/services/import/cache/content_fingerprint.dart`

```dart
/// Generates fingerprint from recipe content for deduplication
class ContentFingerprint {
  /// Generate fingerprint from recipe
  String generate(ExtractedRecipe recipe) {
    // Normalize ingredients to canonical form
    final normalizedIngredients = recipe.ingredients
        .map((i) => _normalizeIngredient(i))
        .where((i) => i.isNotEmpty)
        .toList()
      ..sort();
    
    // Create fingerprint from:
    // 1. First 3 words of title
    // 2. Sorted ingredient names (first 10)
    // 3. Instruction count
    
    final titleWords = recipe.title
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 2)
        .take(3)
        .join('_');
    
    final ingredientStr = normalizedIngredients.take(10).join('|');
    final instructionCount = recipe.instructions.length;
    
    final raw = '$titleWords:$ingredientStr:$instructionCount';
    return sha256.convert(utf8.encode(raw)).toString().substring(0, 16);
  }
  
  String _normalizeIngredient(String ingredient) {
    // Use existing ingredient normalizer if available
    return ingredient
        .toLowerCase()
        .replaceAll(RegExp(r'\d+'), '') // Remove quantities
        .replaceAll(RegExp(r'(dl|msk|tsk|g|kg|ml|st|krm)\b'), '') // Remove units
        .replaceAll(RegExp(r'[^\wåäö]'), ' ') // Keep Swedish chars
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
```

---

## 4.4 Cache Entry Model

**New file:** `lib/services/import/cache/cache_entry.dart`

```dart
class CacheEntry {
  final String? urlHash;
  final String contentFingerprint;
  final String? domain;
  final String sourceType;
  final Map<String, dynamic> recipe;
  final ExtractMeta extractionMeta;
  final DateTime cachedAt;
  final int ttlDays;
  final int accessCount;
  final DateTime? lastAccessedAt;
  
  CacheEntry({
    this.urlHash,
    required this.contentFingerprint,
    this.domain,
    required this.sourceType,
    required this.recipe,
    required this.extractionMeta,
    DateTime? cachedAt,
    this.ttlDays = 90,
    this.accessCount = 1,
    this.lastAccessedAt,
  }) : cachedAt = cachedAt ?? DateTime.now();
  
  Map<String, dynamic> toFirestore() => {
    if (urlHash != null) 'urlHash': urlHash,
    'contentFingerprint': contentFingerprint,
    if (domain != null) 'domain': domain,
    'sourceType': sourceType,
    'recipe': recipe,
    'extractionMeta': extractionMeta.toMap(),
    'cachedAt': FieldValue.serverTimestamp(),
    'ttlDays': ttlDays,
    'accessCount': accessCount,
    'lastAccessedAt': FieldValue.serverTimestamp(),
  };
  
  factory CacheEntry.fromFirestore(Map<String, dynamic> data) => CacheEntry(
    urlHash: data['urlHash'],
    contentFingerprint: data['contentFingerprint'],
    domain: data['domain'],
    sourceType: data['sourceType'],
    recipe: Map<String, dynamic>.from(data['recipe']),
    extractionMeta: ExtractMeta.fromMap(data['extractionMeta']),
    cachedAt: (data['cachedAt'] as Timestamp).toDate(),
    ttlDays: data['ttlDays'] ?? 90,
    accessCount: data['accessCount'] ?? 1,
    lastAccessedAt: data['lastAccessedAt'] != null 
        ? (data['lastAccessedAt'] as Timestamp).toDate() 
        : null,
  );
}

class ExtractMeta {
  final String pipeline;
  final int tier;
  final String method;
  final double confidence;
  
  ExtractMeta({
    required this.pipeline,
    required this.tier,
    required this.method,
    required this.confidence,
  });
  
  Map<String, dynamic> toMap() => {
    'pipeline': pipeline,
    'tier': tier,
    'method': method,
    'confidence': confidence,
  };
  
  factory ExtractMeta.fromMap(Map<String, dynamic> data) => ExtractMeta(
    pipeline: data['pipeline'],
    tier: data['tier'],
    method: data['method'],
    confidence: data['confidence'],
  );
}
```

---

## 4.5 Enhanced Import Result

**New file:** `lib/services/import/models/import_result_v2.dart`

```dart
/// Enhanced import result with tier tracking and assistance mode
sealed class ImportResultV2 {
  bool get isSuccess;
  double get confidence;
  String? get pipeline;
  int? get tier;
}

class ImportSuccess extends ImportResultV2 {
  final Recipe recipe;
  @override final double confidence;
  @override final String pipeline;
  @override final int tier;
  final String method;
  final bool fromCache;
  final bool usedLlm;
  final bool requiresReview;
  
  @override bool get isSuccess => true;
  
  ImportSuccess({
    required this.recipe,
    required this.confidence,
    required this.pipeline,
    required this.tier,
    required this.method,
    this.fromCache = false,
    this.usedLlm = false,
    this.requiresReview = false,
  });
}

class ImportPartial extends ImportResultV2 {
  final Map<String, dynamic>? partialData;
  final String? extractedText;
  final String? rawHtml;
  @override final double confidence;
  @override final String? pipeline;
  @override final int? tier;
  
  @override bool get isSuccess => false;
  
  ImportPartial({
    this.partialData,
    this.extractedText,
    this.rawHtml,
    required this.confidence,
    this.pipeline,
    this.tier,
  });
}

class ImportNeedsAssistance extends ImportResultV2 {
  final String? extractedText;
  final Map<String, dynamic>? partialData;
  final String? thumbnailUrl;
  final Uint8List? imageBytes;
  final String message;
  
  @override bool get isSuccess => false;
  @override double get confidence => 0.0;
  @override String? get pipeline => null;
  @override int? get tier => null;
  
  ImportNeedsAssistance({
    this.extractedText,
    this.partialData,
    this.thumbnailUrl,
    this.imageBytes,
    required this.message,
  });
}

class ImportNeedsScreenshot extends ImportResultV2 {
  final String platform;
  final String? url;
  final String? thumbnailUrl;
  final String message;
  
  @override bool get isSuccess => false;
  @override double get confidence => 0.0;
  @override String? get pipeline => null;
  @override int? get tier => null;
  
  ImportNeedsScreenshot({
    required this.platform,
    this.url,
    this.thumbnailUrl,
    required this.message,
  });
}

class ImportFailure extends ImportResultV2 {
  final String message;
  final String? errorCode;
  
  @override bool get isSuccess => false;
  @override double get confidence => 0.0;
  @override String? get pipeline => null;
  @override int? get tier => null;
  
  ImportFailure(this.message, {this.errorCode});
}
```

---

## 4.6 LLM Enhancement Service

**New file:** `lib/services/import/llm/llm_enhancement_service.dart`

```dart
/// Uses LLM to enhance partial extractions or extract from complex content
class LlmEnhancementService {
  final AnthropicService _anthropic; // Or OpenAI
  
  /// Enhance a partial extraction result
  Future<ImportResultV2> enhance(ExtractionAttempt attempt) async {
    if (attempt.result.extractedText == null) {
      return attempt.result as ImportResultV2;
    }
    
    final prompt = '''
Du är en expert på att extrahera recept från text. Här är text som extraherats från en webbsida, men parsern kunde inte hitta alla delar.

TEXT:
${attempt.result.extractedText}

${attempt.result.partialData != null ? '''
DELVIS EXTRAHERAT:
${jsonEncode(attempt.result.partialData)}
''' : ''}

Extrahera ett komplett recept i JSON-format med följande fält:
- title: string
- description: string (valfritt)
- portions: number (valfritt)
- timeMinutes: number (valfritt)
- ingredients: string[] (varje ingrediens som egen sträng, t.ex. "2 dl mjöl")
- instructions: string[] (varje steg som egen sträng)

Svara ENDAST med JSON, inget annat.
''';

    try {
      final response = await _anthropic.complete(prompt);
      final json = jsonDecode(response.text);
      
      final recipe = Recipe.fromJson(json);
      
      return ImportSuccess(
        recipe: recipe,
        confidence: 0.85, // LLM-enhanced has good but not perfect confidence
        pipeline: attempt.strategy,
        tier: attempt.tier,
        method: 'llm_enhanced',
        usedLlm: true,
        requiresReview: true, // Always review LLM extractions
      );
    } catch (e) {
      return attempt.result as ImportResultV2;
    }
  }
  
  /// Extract recipe directly from image using vision
  Future<ExtractedRecipe?> extractFromImage(Uint8List imageBytes) async {
    final prompt = '''
Analysera denna bild av ett recept. Extrahera receptet i JSON-format:
{
  "title": "Receptets namn",
  "ingredients": ["ingrediens 1", "ingrediens 2"],
  "instructions": ["steg 1", "steg 2"]
}

Om bilden inte innehåller ett recept, svara med: {"error": "no_recipe"}
''';

    try {
      final response = await _anthropic.completeWithImage(
        prompt: prompt,
        imageBytes: imageBytes,
      );
      
      final json = jsonDecode(response.text);
      if (json['error'] != null) return null;
      
      return ExtractedRecipe.fromJson(json);
    } catch (e) {
      return null;
    }
  }
  
  /// Extract recipe from raw HTML when parsers fail
  Future<ExtractedRecipe?> extractFromHtml(String html, String url) async {
    // Strip to reasonable length
    final cleanText = _stripHtml(html).substring(0, min(10000, html.length));
    
    final prompt = '''
Denna text kommer från $url. Hitta och extrahera receptet i JSON-format:
{
  "title": "Receptets namn",
  "description": "Kort beskrivning",
  "portions": 4,
  "timeMinutes": 30,
  "ingredients": ["2 dl mjöl", "1 msk socker"],
  "instructions": ["Steg 1", "Steg 2"]
}

TEXT:
$cleanText

Svara ENDAST med JSON.
''';

    try {
      final response = await _anthropic.complete(prompt);
      final json = jsonDecode(response.text);
      return ExtractedRecipe.fromJson(json);
    } catch (e) {
      return null;
    }
  }
}
```

---

## 4.7 YouTube Pipeline

**New file:** `lib/services/import/pipelines/youtube_pipeline.dart`

```dart
/// 6-tier YouTube extraction pipeline
class YouTubePipeline {
  final YouTubeService _youtube;
  final TextParser _textParser;
  final LlmEnhancementService _llm;
  
  Future<ImportResultV2> extract(String url) async {
    final videoId = _extractVideoId(url);
    if (videoId == null) {
      return ImportFailure('Ogiltig YouTube-länk');
    }
    
    // Get video metadata
    final metadata = await _youtube.getVideoMetadata(videoId);
    
    // Tier 1: Description parsing (FREE)
    final descResult = _parseDescription(metadata.description);
    if (descResult.hasIngredients && descResult.confidence >= 0.8) {
      return ImportSuccess(
        recipe: descResult.toRecipe(title: metadata.title, thumbnailUrl: metadata.thumbnailUrl),
        confidence: descResult.confidence,
        pipeline: 'youtube',
        tier: 1,
        method: 'description',
      );
    }
    
    // Tier 2: Chapter-based extraction (FREE)
    if (metadata.hasChapters) {
      final chapterResult = await _extractFromChapters(videoId, metadata);
      if (chapterResult != null && chapterResult.confidence >= 0.8) {
        return ImportSuccess(
          recipe: chapterResult.toRecipe(title: metadata.title),
          confidence: chapterResult.confidence,
          pipeline: 'youtube',
          tier: 2,
          method: 'chapters',
        );
      }
    }
    
    // Tier 3: Auto-caption parsing (FREE)
    final captions = await _youtube.getAutoCaptions(videoId);
    if (captions != null) {
      final captionResult = _parseCaptions(captions);
      if (captionResult.hasIngredients && captionResult.confidence >= 0.7) {
        return ImportSuccess(
          recipe: captionResult.toRecipe(title: metadata.title),
          confidence: captionResult.confidence,
          pipeline: 'youtube',
          tier: 3,
          method: 'auto_captions',
          requiresReview: true,
        );
      }
    }
    
    // Tier 4: Manual captions (FREE)
    final manualCaptions = await _youtube.getManualCaptions(videoId, language: 'sv');
    if (manualCaptions != null) {
      final manualResult = _parseCaptions(manualCaptions);
      if (manualResult.hasIngredients) {
        return ImportSuccess(
          recipe: manualResult.toRecipe(title: metadata.title),
          confidence: 0.85, // Manual captions are more reliable
          pipeline: 'youtube',
          tier: 4,
          method: 'manual_captions',
        );
      }
    }
    
    // Tier 5: Combined description + captions with LLM (PAID)
    final combinedText = _combineAvailableText(metadata, captions);
    final llmResult = await _llm.enhance(ExtractionAttempt(
      result: ImportPartial(extractedText: combinedText, confidence: 0.5),
      strategy: 'youtube',
      tier: 5,
    ));
    if (llmResult.isSuccess) {
      return llmResult;
    }
    
    // Tier 6: Request user assistance
    return ImportNeedsAssistance(
      extractedText: combinedText,
      thumbnailUrl: metadata.thumbnailUrl,
      message: 'Vi kunde inte extrahera receptet från videon. '
               'Klistra in ingredienserna manuellt.',
    );
  }
  
  String? _extractVideoId(String url) {
    // Handle youtube.com/watch?v=, youtu.be/, youtube.com/shorts/
    final patterns = [
      RegExp(r'youtube\.com/watch\?v=([a-zA-Z0-9_-]+)'),
      RegExp(r'youtu\.be/([a-zA-Z0-9_-]+)'),
      RegExp(r'youtube\.com/shorts/([a-zA-Z0-9_-]+)'),
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(url);
      if (match != null) return match.group(1);
    }
    return null;
  }
}
```

---

## 4.8 TikTok Pipeline

**New file:** `lib/services/import/pipelines/tiktok_pipeline.dart`

```dart
/// 4-tier TikTok extraction pipeline
class TikTokPipeline {
  final TikTokService _tiktok;
  final OcrExtractionService _ocr;
  final TextParser _textParser;
  final LlmEnhancementService _llm;
  
  Future<ImportResultV2> extract(String url) async {
    // Resolve short URLs (vm.tiktok.com)
    final resolvedUrl = await _tiktok.resolveShortUrl(url);
    
    // Tier 1: oEmbed metadata (FREE)
    final oembed = await _tiktok.getOembed(resolvedUrl);
    if (oembed != null) {
      final captionResult = _parseTikTokCaption(oembed.title);
      if (captionResult.hasIngredients) {
        return ImportSuccess(
          recipe: captionResult.toRecipe(),
          confidence: 0.7,
          pipeline: 'tiktok',
          tier: 1,
          method: 'oembed_caption',
          requiresReview: true,
        );
      }
    }
    
    // Tier 2: Frame OCR (TikTok videos often have on-screen text)
    // This requires user to provide screenshot or video
    // For now, request screenshot
    
    // Tier 3: LLM with available context
    if (oembed != null) {
      final llmResult = await _llm.enhance(ExtractionAttempt(
        result: ImportPartial(
          extractedText: oembed.title,
          partialData: {'author': oembed.authorName},
          confidence: 0.4,
        ),
        strategy: 'tiktok',
        tier: 3,
      ));
      if (llmResult.isSuccess) {
        return llmResult;
      }
    }
    
    // Tier 4: Request user screenshot
    return ImportNeedsScreenshot(
      platform: 'TikTok',
      url: resolvedUrl,
      thumbnailUrl: oembed?.thumbnailUrl,
      message: 'Vi kan inte extrahera recept direkt från TikTok-videos. '
               'Ta en skärmbild av receptet och ladda upp den.',
    );
  }
  
  /// Parse TikTok caption for recipe
  /// TikTok often uses emoji bullets: 🥕 carrots 🧅 onion
  RecipeParseResult _parseTikTokCaption(String caption) {
    final emojiPattern = RegExp(r'[🥕🧅🥩🧀🥛🍳🧈🌶️🧄🍋🥒🍅🥔🌽🥦•\-]\s*(.+?)(?=[🥕🧅🥩🧀🥛🍳🧈🌶️🧄🍋🥒🍅🥔🌽🥦•\-\n]|$)');
    
    final matches = emojiPattern.allMatches(caption);
    final ingredients = matches.map((m) => m.group(1)?.trim()).whereNotNull().toList();
    
    if (ingredients.length >= 2) {
      return RecipeParseResult(
        ingredients: ingredients,
        confidence: 0.7,
      );
    }
    
    // Fallback to text parser
    return _textParser.parseRecipeText(caption);
  }
}
```

---

## 4.9 User-Assisted Import View

**New file:** `lib/views/import/user_assisted_import_view.dart`

```dart
/// UI for manual recipe correction when automatic extraction fails
class UserAssistedImportView extends StatefulWidget {
  final ImportNeedsAssistance result;
  
  const UserAssistedImportView({required this.result, super.key});
  
  @override
  State<UserAssistedImportView> createState() => _UserAssistedImportViewState();
}

class _UserAssistedImportViewState extends State<UserAssistedImportView> {
  final _titleController = TextEditingController();
  final _selectedIngredients = <String>[];
  final _selectedInstructions = <String>[];
  late List<String> _textLines;
  
  @override
  void initState() {
    super.initState();
    _textLines = (widget.result.extractedText ?? '')
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    
    // Pre-select lines that look like ingredients
    for (final line in _textLines) {
      if (_looksLikeIngredient(line)) {
        _selectedIngredients.add(line);
      }
    }
  }
  
  bool _looksLikeIngredient(String line) {
    return RegExp(r'^\d+[\s,./]?\d*\s*(dl|msk|tsk|krm|g|kg|ml|l|st|cl)\b', caseSensitive: false)
        .hasMatch(line);
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hjälp oss hitta receptet'),
      ),
      body: Column(
        children: [
          // Optional thumbnail
          if (widget.result.thumbnailUrl != null)
            Image.network(
              widget.result.thumbnailUrl!,
              height: 150,
              fit: BoxFit.cover,
            ),
          
          // Message
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              widget.result.message,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          
          // Title input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Receptets namn',
                hintText: 'Ange ett namn för receptet',
              ),
            ),
          ),
          
          // Instructions
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Tryck på rader för att markera:\n'
              '🟢 Grön = Ingrediens\n'
              '🔵 Blå = Instruktion',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          
          // Selectable text lines
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _textLines.length,
              itemBuilder: (context, index) {
                final line = _textLines[index];
                final isIngredient = _selectedIngredients.contains(line);
                final isInstruction = _selectedInstructions.contains(line);
                
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: InkWell(
                    onTap: () => _toggleLine(line),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isIngredient
                            ? Colors.green.withOpacity(0.2)
                            : isInstruction
                                ? Colors.blue.withOpacity(0.2)
                                : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isIngredient
                              ? Colors.green
                              : isInstruction
                                  ? Colors.blue
                                  : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(child: Text(line)),
                          if (isIngredient)
                            const Icon(Icons.restaurant, color: Colors.green, size: 20),
                          if (isInstruction)
                            const Icon(Icons.format_list_numbered, color: Colors.blue, size: 20),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Save button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Avbryt'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _selectedIngredients.isNotEmpty ? _save : null,
                      child: const Text('Spara recept'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  void _toggleLine(String line) {
    setState(() {
      if (_selectedIngredients.contains(line)) {
        _selectedIngredients.remove(line);
        _selectedInstructions.add(line);
      } else if (_selectedInstructions.contains(line)) {
        _selectedInstructions.remove(line);
      } else {
        _selectedIngredients.add(line);
      }
    });
  }
  
  void _save() {
    final recipe = Recipe(
      title: _titleController.text.isNotEmpty
          ? _titleController.text
          : 'Importerat recept',
      ingredients: _selectedIngredients,
      instructions: _selectedInstructions,
    );
    
    Navigator.pop(context, ImportSuccess(
      recipe: recipe,
      confidence: 1.0, // User-verified
      pipeline: 'user_assisted',
      tier: 0,
      method: 'manual',
    ));
  }
}
```

---

## 4.10 User-Assisted ViewModel

**New file:** `lib/viewmodels/user_assisted_import_viewmodel.dart`

```dart
class UserAssistedImportViewModel extends ChangeNotifier {
  final ImportManager _importManager;
  
  String _title = '';
  List<String> _ingredients = [];
  List<String> _instructions = [];
  bool _isSaving = false;
  
  String get title => _title;
  List<String> get ingredients => List.unmodifiable(_ingredients);
  List<String> get instructions => List.unmodifiable(_instructions);
  bool get isSaving => _isSaving;
  bool get canSave => _ingredients.isNotEmpty;
  
  void setTitle(String title) {
    _title = title;
    notifyListeners();
  }
  
  void addIngredient(String line) {
    if (!_ingredients.contains(line)) {
      _instructions.remove(line);
      _ingredients.add(line);
      notifyListeners();
    }
  }
  
  void addInstruction(String line) {
    if (!_instructions.contains(line)) {
      _ingredients.remove(line);
      _instructions.add(line);
      notifyListeners();
    }
  }
  
  void removeLine(String line) {
    _ingredients.remove(line);
    _instructions.remove(line);
    notifyListeners();
  }
  
  Future<Recipe?> save() async {
    if (!canSave) return null;
    
    _isSaving = true;
    notifyListeners();
    
    try {
      final recipe = Recipe(
        title: _title.isNotEmpty ? _title : 'Importerat recept',
        ingredients: _ingredients,
        instructions: _instructions,
      );
      
      // Save to user's recipes
      await _importManager.saveRecipe(recipe);
      
      return recipe;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
```

---

# PART 5: FILES TO REMOVE

Based on the audit, no files need to be removed. The existing infrastructure is solid and should be enhanced rather than replaced.

However, consider **deprecating** these if they become redundant after migration:

```
⚠️ CONSIDER DEPRECATING (after migration):
- None identified - existing code integrates well with new architecture
```

---

# PART 6: FIRESTORE CHANGES

## 6.1 New Collection: globalRecipeCache

```javascript
// Collection: /globalRecipeCache/{documentId}
{
  // Lookup keys (indexed)
  urlHash: string,              // SHA256 of normalized URL
  contentFingerprint: string,   // Hash of title + ingredients
  
  // Metadata
  domain: string,               // e.g., "ica.se"
  sourceType: string,           // "website", "youtube", "tiktok", etc.
  
  // The cached recipe
  recipe: {
    title: string,
    description: string,
    ingredients: string[],
    instructions: string[],
    portions: number,
    timeMinutes: number,
    imageUrls: string[],
  },
  
  // Extraction info
  extractionMeta: {
    pipeline: string,           // "website", "youtube", etc.
    tier: number,               // Which tier succeeded
    method: string,             // "json-ld", "site-parser", etc.
    confidence: number,         // 0.0-1.0
  },
  
  // Cache management
  cachedAt: timestamp,
  ttlDays: number,
  accessCount: number,
  lastAccessedAt: timestamp,
}
```

## 6.2 Indexes

Add to `firestore.indexes.json`:

```json
{
  "indexes": [
    {
      "collectionGroup": "globalRecipeCache",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "contentFingerprint", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "globalRecipeCache",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "domain", "order": "ASCENDING" },
        { "fieldPath": "cachedAt", "order": "DESCENDING" }
      ]
    }
  ]
}
```

## 6.3 Security Rules

Add to `firestore.rules`:

```javascript
match /globalRecipeCache/{docId} {
  // Any authenticated user can read
  allow read: if request.auth != null;
  
  // Any authenticated user can create new cache entries
  allow create: if request.auth != null;
  
  // Only allow updating access stats
  allow update: if request.auth != null
    && request.resource.data.diff(resource.data).affectedKeys()
        .hasOnly(['accessCount', 'lastAccessedAt']);
  
  // No direct deletes (cleanup via Cloud Function only)
  allow delete: if false;
}
```

---

# PART 7: DEPENDENCY INJECTION

## 7.1 Update ContentModule

**File:** `lib/core/di/modules/content_module.dart`

Add these registrations:

```dart
void configure(DIContainer container) {
  // ... existing registrations ...
  
  // NEW: Cache services
  container.registerLazySingleton<UrlNormalizer>(
    () => UrlNormalizer(),
  );
  
  container.registerLazySingleton<ContentFingerprint>(
    () => ContentFingerprint(),
  );
  
  container.registerLazySingleton<GlobalRecipeCache>(
    () => GlobalRecipeCache(
      firestore: container<FirebaseFirestore>(),
      urlNormalizer: container<UrlNormalizer>(),
      fingerprinter: container<ContentFingerprint>(),
    ),
  );
  
  // NEW: LLM services
  container.registerLazySingleton<LlmEnhancementService>(
    () => LlmEnhancementService(
      anthropic: container<AnthropicService>(),
    ),
  );
  
  // NEW: Platform pipelines
  container.registerLazySingleton<YouTubePipeline>(
    () => YouTubePipeline(
      youtube: container<YouTubeService>(),
      textParser: container<TextParser>(),
      llm: container<LlmEnhancementService>(),
    ),
  );
  
  container.registerLazySingleton<TikTokPipeline>(
    () => TikTokPipeline(
      tiktok: container<TikTokService>(),
      ocr: container<OcrExtractionService>(),
      textParser: container<TextParser>(),
      llm: container<LlmEnhancementService>(),
    ),
  );
  
  // MODIFY: Update ImportManager with new dependencies
  container.registerLazySingleton<ImportManager>(
    () => ImportManager(
      globalCache: container<GlobalRecipeCache>(),
      inputClassifier: container<InputClassifier>(),
      llmEnhancer: container<LlmEnhancementService>(),
      urlStrategy: container<UrlImportStrategy>(),
      textStrategy: container<TextImportStrategy>(),
      photoStrategy: container<PhotoImportStrategy>(),
      youtubePipeline: container<YouTubePipeline>(),
      tiktokPipeline: container<TikTokPipeline>(),
      // ... other strategies ...
    ),
  );
}
```

---

# PART 8: IMPLEMENTATION PHASES

## Phase 1: Core Cache Infrastructure (Week 1)
**Goal:** Global cache working for existing URL imports

**Files to create:**
- [ ] `lib/services/import/cache/url_normalizer.dart`
- [ ] `lib/services/import/cache/content_fingerprint.dart`
- [ ] `lib/services/import/cache/cache_entry.dart`
- [ ] `lib/services/import/cache/global_recipe_cache.dart`

**Files to modify:**
- [ ] `lib/services/import/import_manager.dart` — Add cache check
- [ ] `lib/core/di/modules/content_module.dart` — Register cache services
- [ ] `firestore.indexes.json` — Add indexes
- [ ] `firestore.rules` — Add cache rules

**Test:** Import same URL twice, verify second is instant (cache hit)

---

## Phase 2: Enhanced Result Types + LLM Service + Rate Limiting (Week 2)
**Goal:** Foundation for all pipeline enhancements + cost protection

**Files to create:**
- [ ] `lib/services/import/models/import_result_v2.dart`
- [ ] `lib/services/import/models/rate_limit_models.dart`
- [ ] `lib/services/import/rate_limiter.dart`
- [ ] `lib/services/import/llm/llm_enhancement_service.dart`
- [ ] `lib/widgets/dialogs/rate_limit_dialog.dart`

**Files to modify:**
- [ ] `lib/services/import/import_manager.dart` — Use new result types + rate limit checks
- [ ] `lib/services/import/url_import_strategy.dart` — Return enhanced results

**Test:** 
- Partial extraction triggers LLM enhancement
- Rapid imports get rate limited
- LLM limits block after threshold, offer fallback

---

## Phase 3: Website Pipeline Enhancement (Week 3)
**Goal:** 5-tier website extraction with LLM fallback

**Files to modify:**
- [ ] `lib/services/import/url_import_strategy.dart` — Add tiers 3-5
- [ ] `lib/services/extraction/platform_detector.dart` — Better classification

**Files to create:**
- [ ] `lib/services/extraction/heuristic_html_parser.dart` (optional, for Tier 3)

**Test:** Complex sites that fail JSON-LD get extracted via LLM

---

## Phase 4: User-Assisted Import (Week 4)
**Goal:** Graceful fallback for failed extractions

**Files to create:**
- [ ] `lib/views/import/user_assisted_import_view.dart`
- [ ] `lib/viewmodels/user_assisted_import_viewmodel.dart`

**Files to modify:**
- [ ] `lib/services/import/import_manager.dart` — Route to user-assisted
- [ ] Navigation — Add route to user-assisted view

**Test:** Failed import shows user-assisted screen

---

## Phase 5: YouTube Pipeline (Week 5-6)
**Goal:** Extract recipes from YouTube videos

**Files to create:**
- [ ] `lib/services/import/pipelines/youtube_pipeline.dart`
- [ ] `lib/services/youtube/youtube_service.dart` (if not exists)

**Files to modify:**
- [ ] `lib/services/import/import_manager.dart` — Route YouTube URLs
- [ ] DI module — Register YouTube pipeline

**Test:** YouTube recipe video extracts ingredients from description/captions

---

## Phase 6: TikTok + Instagram Enhancement (Week 7)
**Goal:** Better social media extraction

**Files to create:**
- [ ] `lib/services/import/pipelines/tiktok_pipeline.dart`

**Files to modify:**
- [ ] `lib/services/extraction/extractors/instagram_content_extractor.dart`
- [ ] `lib/services/import/import_manager.dart` — Route social URLs

**Test:** TikTok/Instagram with recipe in caption extracts correctly

---

## Phase 7: OCR Enhancement (Week 8)
**Goal:** Add LLM vision as final OCR tier

**Files to modify:**
- [ ] `lib/services/ocr_extraction_service.dart` — Add Tier 4 LLM

**Test:** Handwritten recipe image extracts correctly

---

## Phase 8: Integration + Polish (Week 9)
**Goal:** Production-ready system

**Tasks:**
- [ ] End-to-end testing all pipelines
- [ ] Analytics events for cache hits/misses
- [ ] Error tracking for LLM failures
- [ ] Documentation
- [ ] Cache cleanup Cloud Function
- [ ] Rate limit cleanup Cloud Function (`functions/src/cleanup-rate-limits.ts`)

---

# PART 9: COST PROJECTIONS

## 9.1 Per-Import Costs

| Tier | Cost | When Used |
|------|------|-----------|
| Cache hit | ~$0.00001 (Firestore read) | ~30-50% of imports |
| Rule-based extraction | FREE | ~40-50% of imports |
| LLM enhancement | ~$0.005-0.02 | ~10-15% of imports |
| LLM full extraction | ~$0.02-0.05 | ~5% of imports |
| User-assisted | FREE | ~5% of imports |

## 9.2 Expected Monthly Costs

| Users | Monthly Imports | Estimated Cost |
|-------|-----------------|----------------|
| 100 | 1,000 | ~$5-10 |
| 1,000 | 10,000 | ~$50-100 |
| 10,000 | 100,000 | ~$500-1,000 |

**Comparison to AI-first approach:** 5-10× cheaper due to cache + rule-based tiers

---

# PART 10: RATE LIMITING & ABUSE PREVENTION

## 10.1 Strategy Overview

Rate limiting protects against:
- **Cost runaway** — LLM calls are paid
- **Abuse** — Malicious users spamming imports
- **System overload** — Too many concurrent extractions

**Philosophy:** Generous for FREE operations, restrictive for PAID (LLM) operations.

## 10.2 Rate Limit Configuration

```dart
/// Rate limits per user per time window
class ImportRateLimits {
  // ═══════════════════════════════════════════════════════════
  // FREE OPERATIONS (generous)
  // ═══════════════════════════════════════════════════════════
  
  /// Total imports per day (all types)
  static const int maxImportsPerDay = 100;
  
  /// Total imports per hour
  static const int maxImportsPerHour = 30;
  
  /// Imports per minute (burst protection)
  static const int maxImportsPerMinute = 10;
  
  // ═══════════════════════════════════════════════════════════
  // LLM OPERATIONS (restrictive)
  // ═══════════════════════════════════════════════════════════
  
  /// LLM enhancement calls per day
  static const int maxLlmEnhancementsPerDay = 20;
  
  /// LLM full extraction calls per day
  static const int maxLlmExtractionsPerDay = 10;
  
  /// LLM vision (image) calls per day
  static const int maxLlmVisionPerDay = 10;
  
  /// Total LLM calls per hour (all types)
  static const int maxLlmCallsPerHour = 10;
  
  /// LLM calls per minute (burst protection)
  static const int maxLlmCallsPerMinute = 3;
  
  // ═══════════════════════════════════════════════════════════
  // COST CAPS (hard limits)
  // ═══════════════════════════════════════════════════════════
  
  /// Max LLM spend per user per day (USD)
  static const double maxLlmSpendPerUserPerDay = 0.50;
  
  /// Max LLM spend per user per month (USD)
  static const double maxLlmSpendPerUserPerMonth = 10.00;
}
```

## 10.3 Limits Summary Table

| Operation | Per Minute | Per Hour | Per Day | Rationale |
|-----------|------------|----------|---------|-----------|
| **Any import** | 10 | 30 | 100 | Generous for normal use |
| **Cache hit** | ∞ | ∞ | ∞ | Essentially free |
| **Rule-based extraction** | 10 | 30 | 100 | Part of total imports |
| **LLM enhancement** | 3 | 10 | 20 | ~$0.20/day max |
| **LLM full extraction** | 3 | 10 | 10 | ~$0.30/day max |
| **LLM vision** | 3 | 10 | 10 | ~$0.10/day max |
| **Total LLM spend/day** | - | - | $0.50 | Hard cost cap |
| **Total LLM spend/month** | - | - | $10.00 | Monthly cap |

## 10.4 Rate Limiter Service

**New file:** `lib/services/import/rate_limiter.dart`

```dart
/// Rate limiting service for import operations
class ImportRateLimiter {
  final FirebaseFirestore _firestore;
  final String _userId;
  
  ImportRateLimiter({
    required FirebaseFirestore firestore,
    required String userId,
  }) : _firestore = firestore, _userId = userId;
  
  /// Check if operation is allowed
  Future<RateLimitResult> checkLimit(ImportOperation operation) async {
    final limits = await _getCurrentUsage();
    
    // Check burst limits first (per-minute)
    if (limits.importsThisMinute >= ImportRateLimits.maxImportsPerMinute) {
      return RateLimitResult.denied(
        reason: 'För många importer. Vänta en minut.',
        retryAfter: Duration(minutes: 1),
      );
    }
    
    // Check hourly limits
    if (limits.importsThisHour >= ImportRateLimits.maxImportsPerHour) {
      return RateLimitResult.denied(
        reason: 'Timgräns nådd (${ImportRateLimits.maxImportsPerHour}/timme). Försök igen senare.',
        retryAfter: Duration(hours: 1),
      );
    }
    
    // Check daily limits
    if (limits.importsToday >= ImportRateLimits.maxImportsPerDay) {
      return RateLimitResult.denied(
        reason: 'Daggräns nådd (${ImportRateLimits.maxImportsPerDay}/dag). Försök igen imorgon.',
        retryAfter: _timeUntilMidnight(),
      );
    }
    
    // For LLM operations, apply stricter limits
    if (operation.requiresLlm) {
      return _checkLlmLimits(limits, operation);
    }
    
    return RateLimitResult.allowed();
  }
  
  Future<RateLimitResult> _checkLlmLimits(UsageLimits limits, ImportOperation operation) async {
    // Per-minute burst protection
    if (limits.llmCallsThisMinute >= ImportRateLimits.maxLlmCallsPerMinute) {
      return RateLimitResult.denied(
        reason: 'För många AI-anrop. Vänta en minut.',
        retryAfter: Duration(minutes: 1),
      );
    }
    
    // Per-hour limit
    if (limits.llmCallsThisHour >= ImportRateLimits.maxLlmCallsPerHour) {
      return RateLimitResult.denied(
        reason: 'AI-gräns nådd för denna timme.',
        retryAfter: Duration(hours: 1),
      );
    }
    
    // Type-specific daily limits
    switch (operation.llmType) {
      case LlmOperationType.enhancement:
        if (limits.llmEnhancementsToday >= ImportRateLimits.maxLlmEnhancementsPerDay) {
          return RateLimitResult.deniedWithFallback(
            reason: 'AI-förbättringsgräns nådd för idag.',
            fallbackAction: FallbackAction.skipLlm,
          );
        }
        break;
      case LlmOperationType.fullExtraction:
        if (limits.llmExtractionsToday >= ImportRateLimits.maxLlmExtractionsPerDay) {
          return RateLimitResult.deniedWithFallback(
            reason: 'AI-extraheringsgräns nådd för idag.',
            fallbackAction: FallbackAction.useUserAssisted,
          );
        }
        break;
      case LlmOperationType.vision:
        if (limits.llmVisionToday >= ImportRateLimits.maxLlmVisionPerDay) {
          return RateLimitResult.deniedWithFallback(
            reason: 'AI-bildanalysgräns nådd för idag.',
            fallbackAction: FallbackAction.useUserAssisted,
          );
        }
        break;
      case null:
        break;
    }
    
    // Cost-based daily limit
    if (limits.llmSpendToday >= ImportRateLimits.maxLlmSpendPerUserPerDay) {
      return RateLimitResult.deniedWithFallback(
        reason: 'AI-kostnadsgräns nådd för idag.',
        fallbackAction: FallbackAction.useUserAssisted,
      );
    }
    
    // Cost-based monthly limit
    if (limits.llmSpendThisMonth >= ImportRateLimits.maxLlmSpendPerUserPerMonth) {
      return RateLimitResult.deniedWithFallback(
        reason: 'Månatlig AI-gräns nådd. Gränsen återställs nästa månad.',
        fallbackAction: FallbackAction.useUserAssisted,
      );
    }
    
    return RateLimitResult.allowed();
  }
  
  /// Record usage after operation completes
  Future<void> recordUsage(ImportOperation operation, {double? llmCost}) async {
    final now = DateTime.now();
    final minuteKey = '${now.year}${now.month}${now.day}${now.hour}${now.minute}';
    final hourKey = '${now.year}${now.month}${now.day}${now.hour}';
    final dayKey = '${now.year}${now.month}${now.day}';
    final monthKey = '${now.year}${now.month}';
    
    final docRef = _firestore
        .collection('users')
        .doc(_userId)
        .collection('rateLimits')
        .doc('imports');
    
    await docRef.set({
      'minute_$minuteKey': FieldValue.increment(1),
      'hour_$hourKey': FieldValue.increment(1),
      'day_$dayKey': FieldValue.increment(1),
      if (operation.requiresLlm) ...{
        'llm_minute_$minuteKey': FieldValue.increment(1),
        'llm_hour_$hourKey': FieldValue.increment(1),
        'llm_day_$dayKey': FieldValue.increment(1),
        if (operation.llmType != null)
          'llm_${operation.llmType!.name}_day_$dayKey': FieldValue.increment(1),
        if (llmCost != null) ...{
          'llm_spend_day_$dayKey': FieldValue.increment(llmCost),
          'llm_spend_month_$monthKey': FieldValue.increment(llmCost),
        },
      },
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
  
  Future<UsageLimits> _getCurrentUsage() async {
    final now = DateTime.now();
    final minuteKey = '${now.year}${now.month}${now.day}${now.hour}${now.minute}';
    final hourKey = '${now.year}${now.month}${now.day}${now.hour}';
    final dayKey = '${now.year}${now.month}${now.day}';
    final monthKey = '${now.year}${now.month}';
    
    final doc = await _firestore
        .collection('users')
        .doc(_userId)
        .collection('rateLimits')
        .doc('imports')
        .get();
    
    if (!doc.exists) return UsageLimits.zero();
    
    final data = doc.data()!;
    
    return UsageLimits(
      importsThisMinute: data['minute_$minuteKey'] ?? 0,
      importsThisHour: data['hour_$hourKey'] ?? 0,
      importsToday: data['day_$dayKey'] ?? 0,
      llmCallsThisMinute: data['llm_minute_$minuteKey'] ?? 0,
      llmCallsThisHour: data['llm_hour_$hourKey'] ?? 0,
      llmEnhancementsToday: data['llm_enhancement_day_$dayKey'] ?? 0,
      llmExtractionsToday: data['llm_fullExtraction_day_$dayKey'] ?? 0,
      llmVisionToday: data['llm_vision_day_$dayKey'] ?? 0,
      llmSpendToday: (data['llm_spend_day_$dayKey'] ?? 0).toDouble(),
      llmSpendThisMonth: (data['llm_spend_month_$monthKey'] ?? 0).toDouble(),
    );
  }
  
  Duration _timeUntilMidnight() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    return midnight.difference(now);
  }
}
```

## 10.5 Supporting Models

**New file:** `lib/services/import/models/rate_limit_models.dart`

```dart
/// Result of a rate limit check
sealed class RateLimitResult {
  bool get isAllowed;
}

class RateLimitAllowed extends RateLimitResult {
  @override
  bool get isAllowed => true;
  
  factory RateLimitResult.allowed() => RateLimitAllowed();
}

class RateLimitDenied extends RateLimitResult {
  @override
  bool get isAllowed => false;
  
  final String reason;
  final Duration? retryAfter;
  final FallbackAction? fallbackAction;
  
  RateLimitDenied({
    required this.reason,
    this.retryAfter,
    this.fallbackAction,
  });
  
  factory RateLimitResult.denied({
    required String reason,
    Duration? retryAfter,
  }) => RateLimitDenied(reason: reason, retryAfter: retryAfter);
  
  factory RateLimitResult.deniedWithFallback({
    required String reason,
    required FallbackAction fallbackAction,
  }) => RateLimitDenied(reason: reason, fallbackAction: fallbackAction);
}

/// What to do when rate limited
enum FallbackAction {
  /// Skip LLM tier, continue with rule-based only
  skipLlm,
  
  /// Go directly to user-assisted mode
  useUserAssisted,
  
  /// Block and retry later
  retryLater,
}

/// Type of LLM operation for tracking
enum LlmOperationType {
  enhancement,
  fullExtraction,
  vision,
}

/// Represents an import operation for rate limiting
class ImportOperation {
  final bool requiresLlm;
  final LlmOperationType? llmType;
  
  const ImportOperation({
    this.requiresLlm = false,
    this.llmType,
  });
  
  static const basic = ImportOperation();
  
  factory ImportOperation.llm(LlmOperationType type) => ImportOperation(
    requiresLlm: true,
    llmType: type,
  );
}

/// Current usage counters
class UsageLimits {
  final int importsThisMinute;
  final int importsThisHour;
  final int importsToday;
  final int llmCallsThisMinute;
  final int llmCallsThisHour;
  final int llmEnhancementsToday;
  final int llmExtractionsToday;
  final int llmVisionToday;
  final double llmSpendToday;
  final double llmSpendThisMonth;
  
  const UsageLimits({
    required this.importsThisMinute,
    required this.importsThisHour,
    required this.importsToday,
    required this.llmCallsThisMinute,
    required this.llmCallsThisHour,
    required this.llmEnhancementsToday,
    required this.llmExtractionsToday,
    required this.llmVisionToday,
    required this.llmSpendToday,
    required this.llmSpendThisMonth,
  });
  
  factory UsageLimits.zero() => const UsageLimits(
    importsThisMinute: 0,
    importsThisHour: 0,
    importsToday: 0,
    llmCallsThisMinute: 0,
    llmCallsThisHour: 0,
    llmEnhancementsToday: 0,
    llmExtractionsToday: 0,
    llmVisionToday: 0,
    llmSpendToday: 0,
    llmSpendThisMonth: 0,
  );
}
```

## 10.6 Integration with ImportManager

```dart
class ImportManager {
  final ImportRateLimiter _rateLimiter;
  
  Future<ImportResultV2> autoImport(String input, {Map<String, dynamic>? options}) async {
    // ═══════════════════════════════════════════════════════════
    // STEP 0: Check rate limits for basic import
    // ═══════════════════════════════════════════════════════════
    
    final rateLimitCheck = await _rateLimiter.checkLimit(ImportOperation.basic);
    
    if (!rateLimitCheck.isAllowed) {
      final denied = rateLimitCheck as RateLimitDenied;
      return ImportFailure(
        denied.reason,
        errorCode: 'RATE_LIMITED',
        retryAfter: denied.retryAfter,
      );
    }
    
    // Record basic import
    await _rateLimiter.recordUsage(ImportOperation.basic);
    
    // ... existing cache check and extraction logic ...
    
    // ═══════════════════════════════════════════════════════════
    // Before LLM operations: check LLM-specific limits
    // ═══════════════════════════════════════════════════════════
    
    if (needsLlmEnhancement) {
      final llmCheck = await _rateLimiter.checkLimit(
        ImportOperation.llm(LlmOperationType.enhancement),
      );
      
      if (!llmCheck.isAllowed) {
        final denied = llmCheck as RateLimitDenied;
        
        // Handle graceful degradation
        switch (denied.fallbackAction) {
          case FallbackAction.skipLlm:
            // Continue without LLM, return partial result
            return _returnPartialResult(bestAttempt);
            
          case FallbackAction.useUserAssisted:
            // Go directly to user-assisted mode
            return ImportNeedsAssistance(
              extractedText: bestAttempt?.extractedText,
              message: '${denied.reason} Du kan markera ingredienserna manuellt.',
            );
            
          case FallbackAction.retryLater:
          case null:
            return ImportFailure(denied.reason, retryAfter: denied.retryAfter);
        }
      }
      
      // LLM is allowed — proceed with enhancement
      final enhanced = await _llmEnhancer.enhance(bestAttempt);
      
      // Record LLM usage with estimated cost
      await _rateLimiter.recordUsage(
        ImportOperation.llm(LlmOperationType.enhancement),
        llmCost: 0.01, // Estimated cost per enhancement
      );
      
      if (enhanced.isSuccess) {
        await _globalCache.save(input, enhanced);
        return enhanced;
      }
    }
    
    // ... continue with other tiers ...
  }
}
```

## 10.7 User-Facing Rate Limit Dialog

When rate limited, show a helpful message:

```dart
class RateLimitDialog extends StatelessWidget {
  final RateLimitDenied denial;
  final VoidCallback? onRetry;
  final VoidCallback? onManualImport;
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.hourglass_empty, color: Colors.orange),
          SizedBox(width: 8),
          Text('Gräns nådd'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(denial.reason),
          SizedBox(height: 16),
          Text(
            'Du kan fortfarande:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text('• Importera recept via URL (fungerar oftast)'),
          Text('• Markera ingredienser manuellt'),
          if (denial.retryAfter != null) ...[
            SizedBox(height: 16),
            Text(
              'Försök igen om ${_formatDuration(denial.retryAfter!)}',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ],
      ),
      actions: [
        if (denial.fallbackAction == FallbackAction.useUserAssisted)
          TextButton(
            onPressed: onManualImport,
            child: Text('Manuell import'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Avbryt'),
        ),
        if (denial.fallbackAction == FallbackAction.skipLlm)
          ElevatedButton(
            onPressed: onRetry,
            child: Text('Försök utan AI'),
          ),
      ],
    );
  }
  
  String _formatDuration(Duration d) {
    if (d.inMinutes < 60) return '${d.inMinutes} minuter';
    if (d.inHours < 24) return '${d.inHours} timmar';
    return 'imorgon';
  }
}
```

## 10.8 Firestore Structure for Rate Limits

```javascript
// /users/{userId}/rateLimits/imports
{
  // Per-minute counters (auto-expire after 2 minutes)
  "minute_202512051430": 3,
  "minute_202512051431": 5,
  
  // Per-hour counters (auto-expire after 2 hours)  
  "hour_2025120514": 15,
  
  // Per-day counters (auto-expire after 2 days)
  "day_20251205": 47,
  
  // LLM-specific counters
  "llm_minute_202512051430": 1,
  "llm_hour_2025120514": 5,
  "llm_day_20251205": 8,
  "llm_enhancement_day_20251205": 5,
  "llm_fullExtraction_day_20251205": 2,
  "llm_vision_day_20251205": 1,
  
  // Cost tracking
  "llm_spend_day_20251205": 0.15,
  "llm_spend_month_202512": 2.50,
  
  "lastUpdated": Timestamp
}
```

## 10.9 Cleanup Cloud Function (Optional)

```typescript
// functions/src/cleanup-rate-limits.ts
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

export const cleanupRateLimits = functions.pubsub
  .schedule('every 6 hours')
  .onRun(async (context) => {
    const db = admin.firestore();
    const now = new Date();
    
    // Calculate keys to keep
    const keysToKeep = new Set<string>();
    
    // Keep last 5 minutes
    for (let i = 0; i < 5; i++) {
      const d = new Date(now.getTime() - i * 60000);
      keysToKeep.add(`minute_${formatKey(d, 'minute')}`);
    }
    
    // Keep last 3 hours
    for (let i = 0; i < 3; i++) {
      const d = new Date(now.getTime() - i * 3600000);
      keysToKeep.add(`hour_${formatKey(d, 'hour')}`);
    }
    
    // Keep last 3 days
    for (let i = 0; i < 3; i++) {
      const d = new Date(now.getTime() - i * 86400000);
      keysToKeep.add(`day_${formatKey(d, 'day')}`);
    }
    
    // Keep current and last month
    keysToKeep.add(`llm_spend_month_${formatKey(now, 'month')}`);
    const lastMonth = new Date(now.getFullYear(), now.getMonth() - 1);
    keysToKeep.add(`llm_spend_month_${formatKey(lastMonth, 'month')}`);
    
    // Clean up old keys from all users
    const usersSnapshot = await db.collection('users').get();
    
    for (const userDoc of usersSnapshot.docs) {
      const rateLimitDoc = await userDoc.ref
        .collection('rateLimits')
        .doc('imports')
        .get();
      
      if (!rateLimitDoc.exists) continue;
      
      const data = rateLimitDoc.data()!;
      const keysToDelete: string[] = [];
      
      for (const key of Object.keys(data)) {
        if (key === 'lastUpdated') continue;
        
        // Check if this is an old time-based key
        const isTimeKey = key.match(/^(minute|hour|day|llm_minute|llm_hour|llm_day|llm_\w+_day|llm_spend_day|llm_spend_month)_/);
        if (isTimeKey && !keysToKeep.has(key)) {
          keysToDelete.push(key);
        }
      }
      
      if (keysToDelete.length > 0) {
        const updates: Record<string, any> = {};
        for (const key of keysToDelete) {
          updates[key] = admin.firestore.FieldValue.delete();
        }
        await rateLimitDoc.ref.update(updates);
      }
    }
    
    console.log(`Cleaned up rate limit keys for ${usersSnapshot.size} users`);
  });

function formatKey(date: Date, granularity: 'minute' | 'hour' | 'day' | 'month'): string {
  const y = date.getFullYear();
  const m = date.getMonth() + 1;
  const d = date.getDate();
  const h = date.getHours();
  const min = date.getMinutes();
  
  switch (granularity) {
    case 'minute': return `${y}${m}${d}${h}${min}`;
    case 'hour': return `${y}${m}${d}${h}`;
    case 'day': return `${y}${m}${d}`;
    case 'month': return `${y}${m}`;
  }
}
```

## 10.10 Files to Add for Rate Limiting

| File | Description |
|------|-------------|
| `lib/services/import/rate_limiter.dart` | Core rate limiting service |
| `lib/services/import/models/rate_limit_models.dart` | RateLimitResult, FallbackAction, etc. |
| `lib/widgets/dialogs/rate_limit_dialog.dart` | User-facing rate limit UI |
| `functions/src/cleanup-rate-limits.ts` | Optional cleanup function |

## 10.11 Integration Points

| File to Modify | Change |
|----------------|--------|
| `lib/services/import/import_manager.dart` | Add rate limit checks before operations |
| `lib/core/di/modules/content_module.dart` | Register ImportRateLimiter |
| `lib/viewmodels/import_viewmodel.dart` | Handle RateLimitDenied results |

---

# PART 11: SUMMARY

## What's Preserved (Your Existing Work)
- ✅ 4 Swedish site parsers
- ✅ JSON-LD/Microdata extraction
- ✅ Headless browser fallback
- ✅ Multi-provider OCR with circuit breakers
- ✅ Comprehensive ingredient parsing
- ✅ Text import strategy

## What's Added (New Capabilities)
- 🆕 Global Recipe Cache (cross-user deduplication)
- 🆕 LLM enhancement for partial extractions
- 🆕 LLM fallback tier for complex cases
- 🆕 YouTube pipeline (6 tiers)
- 🆕 TikTok pipeline (4 tiers)
- 🆕 User-Assisted Import screen
- 🆕 Enhanced result types with tier tracking
- 🆕 Rate limiting & abuse prevention (generous for free, restrictive for paid)

## What's Modified (Enhancements)
- 🔄 ImportManager — Cache integration + LLM routing
- 🔄 URL Import Strategy — Expand to 5 tiers
- 🔄 OCR Service — Add LLM vision tier
- 🔄 Instagram Extractor — Add screenshot OCR
- 🔄 Platform Detector — Better input classification

## What's Removed
- Nothing — existing code is solid

---

*Document version: 2.1*
*Last updated: 2025-12-05*
*Changes: Added rate limiting & abuse prevention (Part 10)*