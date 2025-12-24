# Butlery Recipe Parser Architecture

> Comprehensive technical documentation for the multi-tier recipe parsing system.

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Architecture Overview](#2-architecture-overview)
3. [Tier-Based Parsing System](#3-tier-based-parsing-system)
4. [Quality-Based Progression](#4-quality-based-progression)
5. [Data Models](#5-data-models)
6. [Recipe Merging](#6-recipe-merging)
7. [Caching System](#7-caching-system)
8. [Parser Feedback Loop](#8-parser-feedback-loop)
9. [Security Features](#9-security-features)
10. [Infrastructure Components](#10-infrastructure-components)
11. [Cloud Functions](#11-cloud-functions)
12. [Integration Points](#12-integration-points)
13. [Supported Sites](#13-supported-sites)
14. [File Organization](#14-file-organization)
15. [Usage Examples](#15-usage-examples)
16. [Troubleshooting](#16-troubleshooting)

---

## 1. Executive Summary

### What the Parser Does

The Butlery Recipe Parser is a sophisticated multi-tier extraction system that converts recipe content from various sources into structured data. It handles:

- **Web URLs** - Recipe sites, blogs, news articles
- **Social Media** - Instagram, TikTok, YouTube descriptions
- **Plain Text** - Copy-pasted recipes, scanned text
- **Photos** - OCR-extracted recipe text

### Key Features

| Feature | Description |
|---------|-------------|
| **4-Tier Architecture** | Progressive fallback from fast structured data to AI extraction |
| **Confidence Tracking** | Per-field confidence scores enable smart merging and user review |
| **Quality Threshold** | Stops parsing when quality exceeds 70% (configurable) |
| **Security Protections** | Cache poisoning prevention, injection blocking, DoS protection |
| **Swedish Optimization** | Native support for Swedish recipe patterns, fractions, units, vocabulary |
| **Social Media Support** | Bullet stripping, unstructured text classification (Instagram, TikTok) |
| **Dynamic Configuration** | Firestore-stored CSS selectors (no app releases needed) |
| **Feedback Loop** | User corrections captured as training data for parser improvement |

### When to Use

```
Standard Import Flow (existing):
  URL → RecipeScraper → Site Parser → Text Parser → LLM

Enhanced Parser (new):
  URL → SchemaOrg → SiteConfig → RuleBased → LLM
        ↓ quality check at each tier
        ↓ merge results from multiple tiers
        ↓ confidence-weighted field selection
```

Use the enhanced parser when you need:
- Per-field confidence tracking
- Intelligent result merging from multiple extraction methods
- Swedish text classification (Instagram/TikTok)
- Security-hardened caching

---

## 2. Architecture Overview

### High-Level Data Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                        USER INPUT                                    │
│                    (URL, Text, Photo)                               │
└─────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    URL IMPORT STRATEGY                               │
│              lib/services/import/url_import_strategy.dart           │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  options['useEnhancedParser'] == true?                      │   │
│  │      YES → RecipeParserService                              │   │
│  │      NO  → Existing multi-tier flow                         │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                   RECIPE PARSER SERVICE                              │
│            lib/services/parsing/recipe_parser_service.dart          │
│                                                                      │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐          │
│  │ LocalCache   │    │ ParsingContext│   │ CircuitBreaker│          │
│  │ (Hive+P0-1)  │    │ (Security)    │   │ (P1-3)       │          │
│  └──────────────┘    └──────────────┘    └──────────────┘          │
│                                                                      │
│  ┌─────────────────── TIER EXECUTION ───────────────────┐          │
│  │                                                       │          │
│  │  Tier 1: SchemaOrg ──► quality >= 0.7? ──► STOP     │          │
│  │       │                      │                        │          │
│  │       ▼ (continue)           │                        │          │
│  │  Tier 2: SiteConfig ─► quality >= 0.7? ──► STOP     │          │
│  │       │                      │                        │          │
│  │       ▼ (continue)           │                        │          │
│  │  Tier 3: RuleBased ──► quality >= 0.7? ──► STOP     │          │
│  │       │                      │                        │          │
│  │       ▼ (continue)           │                        │          │
│  │  Tier 4: LLM ────────────────┘                        │          │
│  │                                                       │          │
│  └───────────────────────────────────────────────────────┘          │
│                                │                                     │
│                                ▼                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                    RECIPE MERGER                             │   │
│  │    Combines results using confidence-weighted selection      │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                       PARSED RECIPE                                  │
│   - Per-field confidence scores                                     │
│   - Metadata (tier results, timing, cost)                           │
│   - Ready for Recipe model conversion                               │
└─────────────────────────────────────────────────────────────────────┘
```

### Component Relationships

```
┌─────────────────────────────────────────────────────────────────┐
│                     DEPENDENCY GRAPH                             │
└─────────────────────────────────────────────────────────────────┘

RecipeParserService
    ├── LocalRecipeCache (Hive storage)
    │       └── CircuitBreaker (failure protection)
    ├── SiteConfigRepository (Firestore configs)
    │       └── SiteConfig model
    ├── HtmlSanitizer (security validation)
    ├── ParsingContext (shared state)
    │
    └── Parsing Tiers:
            ├── SchemaOrgTier
            │       └── RecipeScraper (existing utility)
            ├── SiteConfigTier
            │       └── SiteConfigRepository
            ├── RuleBasedTier
            │       └── SwedishLineClassifier
            └── LlmTier
                    └── LlmService (Cloud Function)

RecipeMerger
    └── Quality scoring mixins
```

---

## 3. Tier-Based Parsing System

The parser uses a progressive tier system where each tier attempts extraction with increasing complexity and cost. Parsing stops when quality exceeds the threshold (default: 0.7).

### Tier Comparison

| Tier | Name | Timeout | Quality | Cost | Best For |
|------|------|---------|---------|------|----------|
| 1 | SchemaOrg | 5s | High (90%+) | Free | Recipe sites with JSON-LD |
| 2 | SiteConfig | 10s | Medium (70-85%) | Free | Swedish sites with CSS selectors |
| 3 | RuleBased | 15s | Medium (60-75%) | Free | Instagram, TikTok, unstructured text |
| 4 | LLM | 30s | Variable | Paid | Last resort, complex extraction |

---

### Tier 1: SchemaOrgTier

**File:** `lib/services/parsing/tiers/schema_org_tier.dart`

Extracts recipe data from JSON-LD and schema.org structured data embedded in HTML.

```dart
// Example JSON-LD that SchemaOrgTier extracts:
<script type="application/ld+json">
{
  "@type": "Recipe",
  "name": "Pannkakor",
  "recipeYield": "4 servings",
  "recipeIngredient": ["3 dl mjöl", "6 dl mjölk", "3 ägg"],
  "recipeInstructions": [
    {"@type": "HowToStep", "text": "Vispa ihop mjöl och mjölk"}
  ],
  "totalTime": "PT30M"
}
</script>
```

**Quality Scoring Weights:**
- Title: 15%
- Portions: 10%
- Ingredients: 40% (more items = higher score)
- Instructions: 30% (more steps = higher score)
- Time: 5%

**Confidence Assignment:**
```dart
// High confidence: 70%+ ingredients are structured
if (structuredRatio >= 0.7) confidence = ParseConfidence.high;

// Medium confidence: 30-70% structured
else if (structuredRatio >= 0.3) confidence = ParseConfidence.medium;

// Low confidence: <30% structured
else confidence = ParseConfidence.low;
```

---

### Tier 2: SiteConfigTier

**File:** `lib/services/parsing/tiers/site_config_tier.dart`

Uses domain-specific CSS selectors stored in Firestore to extract recipe fields.

```dart
// Example SiteConfig for ica.se:
SiteConfig(
  domain: 'ica.se',
  titleSelector: 'h1.recipe-header__title',
  ingredientsSelector: '.ingredients-list-group__card li',
  instructionsSelector: '.cooking-steps-main__step',
  portionsSelector: '.recipe-header__servings',
  timeSelector: '.recipe-header__time',
  imageSelector: '.recipe-header__image img',
  qualityScore: 0.9,
)
```

**Extraction Process:**
1. Load config from `SiteConfigRepository` (cached 1 hour)
2. Parse HTML document (cached in ParsingContext)
3. Query each selector
4. Clean and normalize extracted text
5. Report success/failure to repository for quality tracking

**Advantages:**
- No app release needed to add/update sites
- Quality metrics tracked per domain
- Multiple selector fallbacks for images (src, data-src, data-lazy-src)

---

### Tier 3: RuleBasedTier

**File:** `lib/services/parsing/tiers/rule_based_tier.dart`

Classifies unstructured Swedish text line-by-line using pattern matching.

**Target Sources:** Instagram captions, TikTok descriptions, YouTube descriptions, pasted text

```dart
// SwedishLineClassifier detects:
// Section Headers:
"Ingredienser:"        → sectionHeader (ingredients)
"Gör så här:"          → sectionHeader (instructions)
"Du behöver:"          → sectionHeader (ingredients)

// Ingredients (quantity + unit + item):
"3 dl mjölk"           → ingredient (high confidence)
"1 msk socker"         → ingredient (high confidence)
"salt"                 → ingredient (low confidence, no quantity)

// Instructions (action verbs):
"Vispa ihop alla..."   → instruction
"Stek i smör..."       → instruction
"Låt svalna..."        → instruction

// Metadata:
"4 portioner"          → metadata (portions)
"30 minuter"           → metadata (time)
```

**Confidence Assignment:**
```dart
// Ingredient confidence based on structure:
if (hasQuantity && hasUnit) confidence = ParseConfidence.high;
else if (hasQuantity || hasUnit) confidence = ParseConfidence.medium;
else confidence = ParseConfidence.low;

// Overall quality based on structured ratio:
if (structuredIngredientRatio >= 0.5) quality = 0.7;
else quality = 0.5;
```

---

### Swedish Ingredient Processing Pipeline

The parser includes a comprehensive 3-stage pipeline for Swedish ingredients, integrated into Tier 3 (RuleBased):

```
Raw Text → IngredientPreprocessor → IngredientParser → IngredientNormalizer
              (Stage 1)               (Stage 2)           (Stage 3)
```

#### Stage 1: IngredientPreprocessor

**File:** `lib/utils/text/ingredient_preprocessor.dart`

Cleans raw recipe strings before parsing. Handles real-world Swedish recipe edge cases.

```dart
// What preprocessing does (in order):
// Step 0: Remove bullets    "• 2 dl mjölk"      → "2 dl mjölk"
// Step 1: Remove approx     "ca 300 g"          → "300 g"
// Step 2: Normalize ranges  "3-5 dl"            → "5 dl" (MAX value)
// Step 3: Remove optional   "ev majsstärkelse"  → "majsstärkelse"
// Step 4: Remove "till"     "smör till formen"  → "smör"
// Step 5: Remove parens     "lime (saften)"     → "lime"
// Step 6: Normalize space   Multiple → single

// Bullet patterns handled (social media formats):
final bulletPattern = RegExp(
  r'^[\u2022\u25CF\u25CB\u25E6\u25BA\u25AA\u25B8\-\*]\s*|'  // • ● ○ ◦ ► ▪ ▸ - *
  r'^\d+[.)]\s*',  // Numbered lists: 1. 2) etc.
);

// Examples:
preprocess("• 2 dl mjölk")        // → "2 dl mjölk"
preprocess("1. 3 ägg")            // → "3 ägg"
preprocess("ca 300 g nachochips") // → "300 g nachochips"
preprocess("3 - 5 st hallon")     // → "5 st hallon" (MAX!)
```

#### Stage 2: IngredientParser (v2.0)

**File:** `lib/services/parsing/parsers/ingredient_parser.dart`

World-class Swedish ingredient parser with comprehensive support:

| Feature | Status | Implementation |
|---------|--------|----------------|
| **Unicode fractions** (½, ¼, ¾) | ✅ Working | `_unicodeFractionPattern` |
| **ASCII fractions** (1/2, 1 1/2) | ✅ Working | `_parseAsciiFraction()` |
| **Mixed fractions** (1½ dl) | ✅ Working | `_parseAsciiFraction()` lines 200-231 |
| **Swedish decimal comma** (1,5) | ✅ Working | `trimmed.replaceAll(',', '.')` line 308 |
| **50+ Swedish units** | ✅ Working | dl, msk, tsk, krm, kg, g, st, etc. |
| **American units** | ✅ Working | cup, tbsp, tsp, oz, lb, etc. |

```dart
// Swedish-specific parsing examples:
parseIngredient("1½ dl mjölk")    // → ParsedIngredient(1.5, "dl", "mjölk")
parseIngredient("1,5 dl grädde")  // → ParsedIngredient(1.5, "dl", "grädde")
parseIngredient("2 1/2 msk socker") // → ParsedIngredient(2.5, "msk", "socker")
parseIngredient("3 st ägg")       // → ParsedIngredient(3.0, "st", "ägg")
```

#### Stage 3: IngredientNormalizer

**File:** `lib/services/parsing/parsers/ingredient_normalizer.dart`

Normalizes ingredient names for consistency and shopping list aggregation.

```dart
// Normalization examples:
normalize("hackad persilja")  // → "persilja"
normalize("färsk basilika")   // → "basilika"
normalize("vitlöksklyftor")   // → "vitlök"
```

#### SwedishLineClassifier

**File:** `lib/services/parsing/parsers/swedish_line_classifier.dart`

Classifies unstructured Swedish text line-by-line:

| Pattern | Regex | Status |
|---------|-------|--------|
| **Section headers** | `ingredienser:`, `gör så här:` | ✅ Working |
| **Portions** | `(\d+)\s*(port(ion(er)?)?|pers(on(er)?)?|st)` | ✅ Working |
| **Time** | `(\d+)\s*(min(ut(er)?)?|tim(m(e|ar))?)` | ✅ Working |
| **Swedish food words** | 155+ words | ✅ Working |
| **Cooking verbs** | 40+ verbs | ✅ Working |

```dart
// Classification examples:
classifyLine("4 portioner")     // → metadata (portions: 4)
classifyLine("30 minuter")      // → metadata (time: 30)
classifyLine("4 st ägg")        // → ingredient (NOT portions - correctly handled)
classifyLine("Ingredienser:")   // → sectionHeader (ingredients)
classifyLine("Vispa ihop...")   // → instruction
```

---

### Tier 4: LlmTier

**File:** `lib/services/parsing/tiers/llm_tier.dart`

Uses AI (Cloud Function) to extract recipes when other methods fail.

**P0-2 Security Validation:**
```dart
// All LLM responses checked for injection patterns:
final _suspiciousPatterns = [
  '<script',           // XSS
  'javascript:',       // Protocol injection
  '{{',                // Template injection
  r'${',               // String interpolation
  '__proto__',         // Prototype pollution
  'constructor(',      // Code injection
];

bool _containsSuspiciousPatterns(String text) {
  final lower = text.toLowerCase();
  return _suspiciousPatterns.any((p) => lower.contains(p));
}
```

**Input Limits:**
- Minimum: 50 characters (prevents noise processing)
- Maximum: 15,000 characters (cost optimization)

**Cost Tracking:**
```dart
TierResult.success(
  tierName: 'LLM',
  recipe: parsedRecipe,
  quality: 0.75,
  costSek: 0.05,      // Tracked per request
  tokensUsed: 1250,   // For analytics
)
```

---

## 4. Quality-Based Progression

### Quality Threshold System

```dart
// Default threshold: 70%
const defaultQualityThreshold = 0.7;

// In RecipeParserService:
Future<ParseResult> parseFromUrl({
  required String url,
  required String htmlContent,
  double qualityThreshold = defaultQualityThreshold,  // Configurable
  bool useLlm = true,
}) async {
  for (final tier in _tiers) {
    final result = await tier.parse(context);

    if (result.success && result.quality >= qualityThreshold) {
      // Quality threshold met - stop here
      return _buildResult(result);
    }

    // Continue to next tier...
  }
}
```

### Quality Scoring Formula

```
Overall Quality = Weighted Average of Field Qualities

Field Weights:
┌────────────────┬────────┬─────────────────────────────────────┐
│ Field          │ Weight │ Scoring Criteria                    │
├────────────────┼────────┼─────────────────────────────────────┤
│ Ingredients    │ 40%    │ Count + structure ratio             │
│ Instructions   │ 30%    │ Count + average length              │
│ Title          │ 15%    │ Non-empty, >= 3 characters          │
│ Portions       │ 10%    │ 1-50 valid range                    │
│ Time           │ 5%     │ > 0 minutes                         │
└────────────────┴────────┴─────────────────────────────────────┘

Ingredient Quality (0.0-1.0):
  Base: 0.3 (having any)
  + 0.2 (if >= 3 ingredients)
  + 0.2 (if >= 6 ingredients)
  + 0.3 * structuredRatio (quantity/unit present)

Instruction Quality (0.0-1.0):
  Base: 0.3 (having any)
  + 0.2 (if >= 3 steps)
  + 0.1 (if >= 5 steps)
  + 0.2 (if avg length > 50 chars)
  + 0.2 (if avg length > 100 chars)
```

### Progression Decision Flow

```
                    ┌─────────────┐
                    │ Start Tier  │
                    └──────┬──────┘
                           │
                           ▼
                    ┌─────────────┐
                    │ Execute     │
                    │ Parse()     │
                    └──────┬──────┘
                           │
              ┌────────────┴────────────┐
              │                         │
              ▼                         ▼
       ┌─────────────┐          ┌─────────────┐
       │ Success     │          │ Failure     │
       │ result?     │          │ (timeout,   │
       └──────┬──────┘          │  error)     │
              │                 └──────┬──────┘
              ▼                        │
       ┌─────────────┐                 │
       │ Quality     │                 │
       │ >= 0.7?     │                 │
       └──────┬──────┘                 │
              │                        │
     ┌────────┴────────┐               │
     │                 │               │
     ▼                 ▼               │
┌─────────┐     ┌─────────────┐        │
│ YES:    │     │ NO:         │        │
│ STOP    │     │ Store result│        │
│ Use this│     │ Continue to │◄───────┘
│ result  │     │ next tier   │
└─────────┘     └─────────────┘
```

---

## 5. Data Models

### FieldResult<T>

**File:** `lib/models/parsing/field_result.dart`

Wraps every extracted value with confidence tracking.

```dart
class FieldResult<T> {
  final T? value;
  final ParseConfidence confidence;
  final String? failureReason;

  // Convenience factories:
  factory FieldResult.success(T value);           // High confidence
  factory FieldResult.mediumConfidence(T value);  // Medium confidence
  factory FieldResult.lowConfidence(T value);     // Low confidence
  factory FieldResult.failed(String reason);      // No value

  // Computed properties:
  bool get hasValue => value != null;
  bool get needsReview => confidence == ParseConfidence.low ||
                          confidence == ParseConfidence.failed;
  double get confidenceScore => confidence.score;  // 0.0-1.0
}
```

### ParseConfidence Enum

```dart
enum ParseConfidence {
  high,    // 1.0 - From structured data (JSON-LD)
  medium,  // 0.7 - CSS selectors, LLM with structure
  low,     // 0.3 - Unstructured text, guesses
  failed,  // 0.0 - Could not extract
}

extension ParseConfidenceScore on ParseConfidence {
  double get score {
    switch (this) {
      case ParseConfidence.high: return 1.0;
      case ParseConfidence.medium: return 0.7;
      case ParseConfidence.low: return 0.3;
      case ParseConfidence.failed: return 0.0;
    }
  }
}
```

### TierResult

**File:** `lib/models/parsing/tier_result.dart`

Result from a single tier execution.

```dart
class TierResult {
  final String tierName;
  final ParsedRecipe? recipe;
  final bool success;
  final double quality;           // 0.0-1.0
  final Duration duration;
  final double? costSek;          // LLM cost tracking
  final int? tokensUsed;          // LLM token tracking
  final TierFailureReason? failureReason;

  // Factories for common patterns:
  factory TierResult.success(...);
  factory TierResult.failure(TierFailureReason reason, ...);
  factory TierResult.skipped(String tierName);
  factory TierResult.timeout(String tierName);
  factory TierResult.noData(String tierName);
}

enum TierFailureReason {
  skipped,              // Not applicable for input
  timeout,              // Exceeded time limit
  noData,               // No extractable content
  parseError,           // Exception during parsing
  networkError,         // Fetch failed
  rateLimited,          // API rate limit
  invalidResponse,      // Bad external service response
  inputTooLarge,        // Content too large
  securityBlocked,      // Failed security check
  deadlineExceeded,     // DOM traversal timeout
  schemaValidationFailed, // LLM response invalid
}
```

### ParsedRecipe

**File:** `lib/models/parsing/parsed_recipe.dart`

Complete recipe output with per-field confidence.

```dart
class ParsedRecipe {
  final FieldResult<String> title;
  final FieldResult<int> portions;
  final FieldResult<List<ParsedIngredient>> ingredients;
  final FieldResult<List<String>> instructions;
  final FieldResult<Duration> totalTime;
  final ParseMetadata metadata;
  final String? imageUrl;
  final String? description;

  // Computed properties:
  double get overallQuality;           // Weighted average
  bool get isComplete;                 // Has essential fields
  bool get needsReview;                // Any low-confidence fields
  List<String> get fieldsNeedingImprovement;  // Score < 0.5
  double get ingredientStructureRatio; // Structured/total
}
```

### ParsedIngredient

**File:** `lib/models/parsing/parsed_ingredient.dart`

Structured ingredient data.

```dart
class ParsedIngredient {
  final String name;              // "mjölk"
  final String originalLine;      // "3 dl mjölk, rumstempererad"
  final ParseConfidence confidence;
  final String? quantity;         // "3"
  final String? unit;             // "dl"
  final String? preparation;      // "rumstempererad"
  final String? notes;            // Parsing notes

  bool get hasQuantity => quantity != null;
  bool get hasUnit => unit != null;
  bool get isStructured => hasQuantity || hasUnit;

  String get displayString;       // "3 dl mjölk (rumstempererad)"
}
```

### ParseMetadata

**File:** `lib/models/parsing/parse_metadata.dart`

Tracks the complete parsing journey.

```dart
class ParseMetadata {
  final ImportSource source;      // url, text, instagram, etc.
  final String? domain;
  final String? sourceUrl;
  final String? cacheKey;
  final List<TierResult> tierResults;
  final Duration totalParseTime;
  final String parserVersion;
  final DateTime timestamp;
  final double? totalCostSek;
  final int? totalTokensUsed;

  String? get successfulTier;     // Name of tier that succeeded
  bool get usedLlm;               // Whether LLM was used
  double get finalQuality;        // Quality from successful tier
}

enum ImportSource {
  url,        // Web URL (cache: 90 days)
  text,       // Plain text (cache: 30 days)
  instagram,  // Instagram (cache: 60 days)
  tiktok,     // TikTok (cache: 60 days)
  youtube,    // YouTube (cache: 180 days)
  photo,      // OCR (cache: 30 days)
  file,       // CSV/Excel (cache: 90 days)
  archive,    // Recipe archive
  unknown,
}
```

### SiteConfig

**File:** `lib/models/parsing/site_config.dart`

Firestore-stored CSS selectors for specific websites.

```dart
class SiteConfig {
  final String domain;
  final bool isSupported;

  // CSS Selectors:
  final String? titleSelector;
  final String? ingredientsSelector;
  final String? instructionsSelector;
  final String? portionsSelector;
  final String? timeSelector;
  final String? imageSelector;
  final String? descriptionSelector;

  // Quality metrics:
  final double qualityScore;      // 0.0-1.0
  final int successCount;
  final int failureCount;
  final DateTime? lastUpdated;
  final String? notes;

  bool get hasSelectors;          // Has any usable selector
  bool get isReliable;            // Supported + quality >= 0.7
  double get successRate;         // success / (success + failure)
}
```

---

## 6. Recipe Merging

**File:** `lib/services/parsing/common/recipe_merger.dart`

### Merging Algorithm

```
┌─────────────────────────────────────────────────────────────────┐
│                    RECIPE MERGER ALGORITHM                       │
└─────────────────────────────────────────────────────────────────┘

Input: List<TierResult> from all executed tiers

Step 1: Filter
    ┌────────────────────────────────────────┐
    │ Keep only successful results (success = true)
    └────────────────────────────────────────┘

Step 2: Sort
    ┌────────────────────────────────────────┐
    │ Order by quality score (highest first)
    └────────────────────────────────────────┘

Step 3: Initialize
    ┌────────────────────────────────────────┐
    │ Take best result as primary
    └────────────────────────────────────────┘

Step 4: Iterate & Merge
    ┌────────────────────────────────────────┐
    │ For each remaining result:              │
    │   For each field in recipe:             │
    │     If secondary.confidence >           │
    │        primary.confidence + 0.1:        │
    │       Replace field with secondary      │
    └────────────────────────────────────────┘

Step 5: Special Ingredient Merge
    ┌────────────────────────────────────────┐
    │ Compare ingredient lists:               │
    │   - Match by name similarity            │
    │   - Prefer more structured versions     │
    │   - Deduplicate by name                 │
    │   - Take larger list if 50%+ bigger     │
    └────────────────────────────────────────┘

Output: Merged ParsedRecipe with best fields from all tiers
```

### Field Merge Logic

```dart
FieldResult<T> _mergeField<T>(
  FieldResult<T> primary,
  FieldResult<T> secondary,
) {
  // Threshold: 0.1 confidence improvement required
  if (secondary.confidenceScore > primary.confidenceScore + 0.1) {
    return secondary;
  }
  return primary;
}
```

### Ingredient List Merging

```dart
List<ParsedIngredient> _mergeIngredients(
  List<ParsedIngredient> primary,
  List<ParsedIngredient> secondary,
) {
  // If secondary is significantly larger, prefer it
  if (secondary.length > primary.length * 1.5) {
    return secondary;
  }

  // Match ingredients by name similarity
  final merged = <ParsedIngredient>[];
  final used = <int>{};

  for (final p in primary) {
    final match = _findMatch(p, secondary, used);
    if (match != null && match.isStructured && !p.isStructured) {
      merged.add(match);  // Prefer structured version
    } else {
      merged.add(p);
    }
  }

  // Add unmatched secondary ingredients
  for (var i = 0; i < secondary.length; i++) {
    if (!used.contains(i)) {
      merged.add(secondary[i]);
    }
  }

  return _deduplicate(merged);
}
```

---

## 7. Caching System

**File:** `lib/services/parsing/cache/local_recipe_cache.dart`

### Cache Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      LOCAL RECIPE CACHE                          │
│                    (Hive Encrypted Storage)                      │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Cache Key     │     │   Hive Box      │     │  Circuit Breaker│
│   Generator     │────▶│ local_recipe_   │◀────│  (Failure       │
│   (P0-1)        │     │ cache_<userId>  │     │   Protection)   │
└─────────────────┘     └─────────────────┘     └─────────────────┘

Cache Key = SHA256(
    userId       │  // Per-user isolation
    urlHash      │  // URL identity
    contentHash  │  // P0-1: Content uniqueness
    source       │  // Import source type
    version         // Parser version (invalidation)
)
```

### P0-1 Security: Content-Hash Protection

Prevents cache poisoning attacks where the same URL returns different content:

```dart
// Attack scenario without content hash:
// 1. Attacker's device requests ica.se/recipe/123
// 2. ICA returns A/B test variant with malicious content
// 3. Malicious content cached by URL alone
// 4. Victim's device gets poisoned cache entry

// Protection with content hash:
String _generateCacheKey({
  required String userId,
  required String urlHash,
  required String contentHash,  // ← P0-1: Content uniqueness
  required ImportSource source,
  required String parserVersion,
}) {
  final combined = '$userId|$urlHash|$contentHash|${source.name}|$parserVersion';
  return sha256.convert(utf8.encode(combined)).toString().substring(0, 32);
}

// Content hash from first 5000 chars (balance uniqueness vs performance)
String _computeContentHash(String content) {
  final sample = content.length > 5000 ? content.substring(0, 5000) : content;
  return sha256.convert(utf8.encode(sample)).toString().substring(0, 16);
}
```

### Cache Configuration

```dart
// Cache limits:
static const _maxEntries = 100;        // Per user
static const _maxAgeDays = 30;         // TTL
static const _parserVersion = '2.0.0'; // For invalidation

// Cache entry structure:
{
  'recipe': { ... },                   // ParsedRecipe JSON
  'cachedAt': '2024-01-15T10:30:00Z', // Timestamp
  'parserVersion': '2.0.0',           // Version check
  'source': 'url',                     // Import source
}
```

### Cache Operations

```dart
class LocalRecipeCache {
  final CircuitBreaker _circuitBreaker;  // P1-3 protection

  Future<ParsedRecipe?> get(String key) async {
    return _circuitBreaker.executeWithFallback(
      () async {
        final entry = _box.get(key);
        if (entry == null) return null;

        // Version check
        if (entry['parserVersion'] != _parserVersion) {
          await _box.delete(key);
          return null;
        }

        // Age check
        final cachedAt = DateTime.parse(entry['cachedAt']);
        if (DateTime.now().difference(cachedAt).inDays > _maxAgeDays) {
          await _box.delete(key);
          return null;
        }

        return ParsedRecipe.fromJson(entry['recipe']);
      },
      null,  // Fallback: return null on circuit breaker open
    );
  }
}
```

---

## 8. Parser Feedback Loop

The parser includes a feedback loop system that captures user corrections to parsed recipes as training data for improving parser accuracy over time.

### Overview

When a user imports a recipe and makes corrections before saving, the system:
1. Calculates the diff between the original parsed data and the user's corrected version
2. Saves correction records to Firestore for later analysis
3. Enables parser improvement without re-deploying the app

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    FEEDBACK LOOP DATA FLOW                       │
└─────────────────────────────────────────────────────────────────┘

Import Flow:

UrlImportStrategy._convertParsedRecipeToImportResult()
        │
        ├──► Recipe created (for user)
        │
        └──► ParsedRecipe stored in ParsedRecipeCache  ← NEW
                    │
                    │ (keyed by sourceUrl)
                    ▼

Edit Flow:

RecipeFormViewModel (init with imported recipe)
        │
        └──► Retrieve ParsedRecipe from cache
                    │
                    └──► _state.setOriginalParsedRecipe(parsed)

Save Flow:

RecipePersistenceManager.saveRecipe()
        │
        ├──► Recipe saved to Firestore (existing)
        │
        └──► _trackParsingCorrectionsInBackground()
                    │
                    ├──► RecipeDiffCalculator.calculateDiff()
                    │           │
                    │           └──► Compare: ParsedRecipe vs Recipe
                    │
                    └──► ParsingCorrectionRepository.save()
                                │
                                └──► Firestore: parsing_corrections
```

### Correction Types

The diff calculator detects multiple types of corrections:

| Type | Description | Example |
|------|-------------|---------|
| **Title** | Title was changed | "Pannkakor" → "Fluffiga pannkakor" |
| **Portions** | Servings corrected | 4 → 6 |
| **Time** | Cook time fixed | 30 min → 45 min |
| **Ingredient Added** | User added missing ingredient | (new) "salt" |
| **Ingredient Removed** | Parser extracted garbage | "advertisement text" removed |
| **Ingredient Modified** | Quantity/unit/name fixed | "2 dl" → "3 dl" |
| **Instruction Added** | Missing step added | (new) "Let rest 10 minutes" |
| **Instruction Removed** | Wrong step removed | "Click here to subscribe" removed |
| **Instruction Modified** | Text corrected | Fixed typo or clarified |
| **Reordered** | Order changed | Low priority for training |

### Data Models

#### ParsingCorrection

**File:** `lib/models/parsing/parsing_correction.dart`

```dart
class ParsingCorrection {
  final String id;
  final String recipeId;
  final String userId;          // For GDPR deletion
  final DateTime timestamp;

  // Context
  final ImportSource source;    // url, instagram, tiktok, etc.
  final String? domain;         // "ica.se", "koket.se"
  final String? successfulTier; // Which tier produced result
  final double originalQuality; // Parser's quality score

  // Corrections
  final FieldCorrection? titleCorrection;
  final FieldCorrection? portionsCorrection;
  final FieldCorrection? timeCorrection;
  final List<IngredientCorrection> ingredientCorrections;
  final List<InstructionCorrection> instructionCorrections;

  // Summary
  final int totalCorrections;
}
```

#### IngredientCorrection

**File:** `lib/models/parsing/ingredient_correction.dart`

```dart
enum IngredientCorrectionType {
  added,           // User added new ingredient
  removed,         // User removed parsed ingredient
  quantityFixed,   // Quantity was wrong
  unitFixed,       // Unit was wrong
  nameFixed,       // Name was wrong
  multipleFixed,   // Multiple fields changed
  reordered,       // Only position changed
}

class IngredientCorrection {
  final IngredientCorrectionType type;
  final int? originalIndex;
  final int? correctedIndex;

  // Original parsed data
  final String? originalLine;      // "2 dl mjölk"
  final String? originalQuantity;  // "2"
  final String? originalUnit;      // "dl"
  final String? originalName;      // "mjölk"

  // Corrected data
  final String? correctedLine;     // "3 dl mjölk"

  // Which fields changed
  final bool quantityChanged;
  final bool unitChanged;
  final bool nameChanged;
}
```

### Diff Algorithm

**File:** `lib/services/parsing/feedback/recipe_diff_calculator.dart`

The diff calculator uses fuzzy matching to correlate ingredients:

```dart
class RecipeDiffCalculator {
  /// Calculate diff between parsed and corrected recipe.
  /// Returns null if no meaningful corrections were made.
  ParsingCorrection? calculateDiff({
    required ParsedRecipe original,
    required Recipe corrected,
    required String userId,
  }) {
    // Field diffs
    final titleDiff = FieldCorrection.create(
      original: original.title.value,
      corrected: corrected.title,
    );

    // Ingredient matching strategy:
    // 1. Exact name match (threshold: 0.9)
    // 2. Fuzzy name match (threshold: 0.5)
    // 3. Unmatched original = removed
    // 4. Unmatched corrected = added

    final ingredientDiffs = _diffIngredients(
      original.ingredients.value ?? [],
      corrected.ingredients,  // Simple strings
    );

    // Similar for instructions...
  }

  // Levenshtein-based similarity for name matching
  double _calculateSimilarity(String a, String b) {
    final distance = _levenshteinDistance(a, b);
    final maxLength = max(a.length, b.length);
    return 1.0 - (distance / maxLength);
  }
}
```

### Caching Bridge: ParsedRecipeCache

**File:** `lib/services/parsing/cache/parsed_recipe_cache.dart`

Since `ParsedRecipe` is created in `UrlImportStrategy` but needed in `RecipeFormState`, a temporary cache bridges the gap:

```dart
class ParsedRecipeCache {
  final _cache = <String, _CacheEntry>{};
  static const _maxAge = Duration(minutes: 30);

  /// Store ParsedRecipe keyed by sourceUrl
  void store(String sourceUrl, ParsedRecipe parsed);

  /// Retrieve and remove ParsedRecipe by sourceUrl
  /// Returns null if not found or expired
  ParsedRecipe? retrieve(String sourceUrl);
}
```

**Usage:**

```dart
// In UrlImportStrategy:
ImportResult _convertParsedRecipeToImportResult(ParseResult parseResult, String url) {
  final parsed = parseResult.recipe!;

  // Store for later diff calculation
  final cache = ServiceLocator.tryGet<ParsedRecipeCache>();
  cache?.store(url, parsed);

  // ... convert to Recipe ...
}

// In RecipeFormViewModel:
if (initialRecipe?.sourceUrl != null && isTemplate) {
  final cache = ServiceLocator.tryGet<ParsedRecipeCache>();
  final parsed = cache?.retrieve(initialRecipe!.sourceUrl!);
  if (parsed != null) {
    _state.setOriginalParsedRecipe(parsed);
  }
}
```

### Firestore Structure

```
parsing_corrections/{correctionId}
├── id: string
├── recipeId: string
├── userId: string
├── timestamp: timestamp
├── source: string (ImportSource name)
├── domain: string?
├── successfulTier: string?
├── originalQuality: number
├── totalCorrections: number
├── titleCorrection: { original, corrected }?
├── portionsCorrection: { original, corrected }?
├── timeCorrection: { original, corrected }?
├── ingredientCorrections: [
│     { type, originalIndex, correctedIndex, originalLine, correctedLine, ... }
│   ]
└── instructionCorrections: [
      { type, originalIndex, correctedIndex, originalText, correctedText }
    ]
```

**Required Index:**
- Collection: `parsing_corrections`
- Fields: `domain` ASC, `timestamp` DESC

### Analysis Queries

```dart
final repo = ServiceLocator.get<ParsingCorrectionRepository>();

// Get corrections for a specific domain
final icaCorrections = await repo.getByDomain('ica.se', limit: 100);

// Get corrections by tier
final llmCorrections = await repo.getByTier('LLM', limit: 50);

// Get domain statistics
final stats = await repo.getDomainStats('koket.se');
// Returns: { totalCorrections, titleFixes, portionFixes, ... }
```

### GDPR Compliance

User corrections can be deleted:

```dart
// Delete all corrections for a user
await repo.deleteUserCorrections(userId);
```

### Fire-and-Forget Pattern

Correction tracking never blocks the save operation:

```dart
void _trackParsingCorrectionsInBackground(Recipe savedRecipe) {
  if (savedRecipe.sourceUrl == null) return;

  final originalParsed = _state.originalParsedRecipe;
  if (originalParsed == null) return;

  // Fire-and-forget - never throws
  Future(() async {
    try {
      final correction = diffCalculator.calculateDiff(...);
      if (correction != null) {
        await correctionRepo.save(correction);
      }
    } catch (e) {
      AppLogger.warning('Failed to track corrections: $e');
    }
  });

  // Clear to prevent duplicate tracking
  _state.setOriginalParsedRecipe(null);
}
```

---

## 9. Security Features

### Security Fixes Summary

| ID | Component | File | Protection |
|----|-----------|------|------------|
| P0-1 | LocalRecipeCache | `local_recipe_cache.dart` | Content-hash prevents cache poisoning |
| P0-2 | LlmTier | `llm_tier.dart` | Schema validation prevents injection |
| P1-3 | CircuitBreaker | `circuit_breaker.dart` | Prevents cascading failures |
| P1-4 | Cloud Function | `log-parse-event.ts` | Server ignores client tierSummaries |

### HtmlSanitizer

**File:** `lib/services/parsing/sanitizers/html_sanitizer.dart`

#### Script Injection Detection

```dart
// 6 injection pattern categories:
final _scriptPatterns = [
  RegExp(r'<script', caseSensitive: false),           // XSS
  RegExp(r'javascript:', caseSensitive: false),       // Protocol
  RegExp(r'on\w+\s*=', caseSensitive: false),         // Event handlers
  RegExp(r'data:text/html', caseSensitive: false),    // Data URLs
  RegExp(r'expression\s*\(', caseSensitive: false),   // CSS expression
  RegExp(r'vbscript:', caseSensitive: false),         // VBScript
];
```

#### Homoglyph Attack Detection

```dart
// Cyrillic characters that look like Latin:
final _homoglyphMap = {
  'а': 'a',  // Cyrillic а (U+0430)
  'е': 'e',  // Cyrillic е (U+0435)
  'о': 'o',  // Cyrillic о (U+043E)
  'р': 'p',  // Cyrillic р (U+0440)
  'с': 'c',  // Cyrillic с (U+0441)
  'х': 'x',  // Cyrillic х (U+0445)
  // ... 18 total mappings
};

// Detects: "ісa.se" (Cyrillic і) vs "ica.se" (Latin i)
bool _containsHomoglyphs(String text) {
  return _homoglyphMap.keys.any((h) => text.contains(h));
}
```

#### Content Validation

```dart
SanitizationResult check(String content) {
  final issues = <SecurityIssue>[];

  // DoS protection
  if (content.length > 5 * 1024 * 1024) {
    issues.add(SecurityIssue.contentTooLarge);
  }

  // Null byte detection
  if (content.contains('\x00')) {
    issues.add(SecurityIssue.nullBytes);
  }

  // Script injection
  for (final pattern in _scriptPatterns) {
    if (pattern.hasMatch(content)) {
      issues.add(SecurityIssue.scriptInjection);
      break;
    }
  }

  // Homoglyphs
  if (_containsHomoglyphs(content)) {
    issues.add(SecurityIssue.homoglyphAttack);
  }

  // Error page detection
  if (_looksLikeErrorPage(content)) {
    issues.add(SecurityIssue.errorPage);
  }

  return SanitizationResult(
    isClean: issues.isEmpty,
    issues: issues,
    hasCriticalIssues: issues.any((i) => i.isCritical),
  );
}
```

### Security Validation Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                  SECURITY VALIDATION FLOW                        │
└─────────────────────────────────────────────────────────────────┘

Input: Raw HTML content
           │
           ▼
    ┌─────────────┐
    │ Size Check  │──── > 5MB ────▶ REJECT (DoS protection)
    │ (DoS)       │
    └──────┬──────┘
           │ OK
           ▼
    ┌─────────────┐
    │ Null Byte   │──── Found ────▶ REJECT (Binary injection)
    │ Detection   │
    └──────┬──────┘
           │ OK
           ▼
    ┌─────────────┐
    │ Script      │──── Found ────▶ SANITIZE (Remove scripts)
    │ Detection   │
    └──────┬──────┘
           │ OK
           ▼
    ┌─────────────┐
    │ Homoglyph   │──── Found ────▶ WARN (Normalize + continue)
    │ Detection   │
    └──────┬──────┘
           │ OK
           ▼
    ┌─────────────┐
    │ Error Page  │──── Found ────▶ REJECT (No recipe content)
    │ Detection   │
    └──────┬──────┘
           │ OK
           ▼
    ┌─────────────┐
    │ Recipe      │──── No ───────▶ WARN (May not be recipe)
    │ Content?    │
    └──────┬──────┘
           │ YES
           ▼
       PROCEED TO PARSING
```

---

## 9. Infrastructure Components

### CircuitBreaker

**File:** `lib/core/circuit_breaker.dart`

Prevents cascading failures when external services are down.

```
┌─────────────────────────────────────────────────────────────────┐
│                   CIRCUIT BREAKER STATES                         │
└─────────────────────────────────────────────────────────────────┘

     ┌──────────────────────────────────────────────────────┐
     │                                                      │
     │    ┌────────┐    failures >= 3    ┌────────┐        │
     │    │ CLOSED │ ──────────────────▶ │  OPEN  │        │
     │    │(normal)│                     │(reject)│        │
     │    └────┬───┘                     └────┬───┘        │
     │         │                              │            │
     │         │ success                      │ 2 min      │
     │         │                              │ timeout    │
     │         │                              ▼            │
     │         │                        ┌──────────┐       │
     │         │                        │HALF-OPEN │       │
     │         │                        │ (test)   │       │
     │         │                        └────┬─────┘       │
     │         │                              │            │
     │         │       success                │ failure    │
     │         ◀──────────────────────────────┴────────────┘
     │
     └──────────────────────────────────────────────────────
```

**Configuration:**
```dart
// Cache circuit breaker settings:
final _cacheCircuitBreaker = CircuitBreaker(
  failureThreshold: 3,           // Open after 3 failures
  resetTimeout: Duration(minutes: 2),
);

// Usage:
Future<void> saveToCache(String key, ParsedRecipe recipe) async {
  await _cacheCircuitBreaker.execute(() async {
    await _hiveBox.put(key, recipe.toJson());
  });
}

// With fallback:
Future<ParsedRecipe?> getFromCache(String key) async {
  return _cacheCircuitBreaker.executeWithFallback(
    () async => _hiveBox.get(key),
    null,  // Return null if circuit is open
  );
}
```

### SiteConfigRepository

**File:** `lib/repositories/site_config_repository.dart`

Manages Firestore-stored site configurations.

```dart
class SiteConfigRepository {
  final FirebaseFirestore _firestore;
  final Map<String, _CachedConfig> _cache = {};
  static const _cacheDuration = Duration(hours: 1);

  // Load config (with caching)
  Future<SiteConfig> getConfig(String domain) async {
    final normalized = _normalizeDomain(domain);

    // Check cache
    final cached = _cache[normalized];
    if (cached != null && !cached.isExpired) {
      return cached.config;
    }

    // Load from Firestore
    final doc = await _firestore
        .collection('site_configs')
        .doc(normalized)
        .get();

    if (doc.exists) {
      final config = SiteConfig.fromFirestore(doc.data()!);
      _cache[normalized] = _CachedConfig(config);
      return config;
    }

    return SiteConfig.defaultFor(normalized);
  }

  // Seed configs on first run (non-blocking)
  Future<void> seedConfigsIfEmpty() async {
    try {
      final snapshot = await _firestore
          .collection('site_configs')
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        await FirebaseFunctions.instance
            .httpsCallable('seedSiteConfigs')
            .call({});
      }
    } catch (e) {
      // Non-blocking - parsing works without configs
      AppLogger.warning('Failed to seed configs: $e');
    }
  }

  // Track success/failure for quality metrics
  Future<void> reportSuccess(String domain) async {
    await _firestore.collection('site_configs')
        .doc(_normalizeDomain(domain))
        .set({
          'successCount': FieldValue.increment(1),
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }
}
```

---

## 10. Cloud Functions

### logParseEvent (P1-4 Security)

**File:** `functions/src/events/log-parse-event.ts`

Server-side analytics with client data validation.

```typescript
// P1-4: Server ignores client tierSummaries
export const logParseEvent = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
  }

  // TRUSTED: Server-validated fields only
  const trustedFields = {
    userId: context.auth.uid,           // From auth context
    url: sanitizeUrl(data.url),         // Sensitive params removed
    domain: extractDomain(data.url),    // Computed server-side
    source: validateSource(data.source),// Enum validated
    success: Boolean(data.success),     // Coerced boolean
    fromCache: Boolean(data.fromCache),
    parseTimeMs: clamp(data.parseTimeMs, 0, 60000),  // Bounded
    parserVersion: data.parserVersion,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    // NOTE: tierSummaries from client are IGNORED (P1-4)
  };

  await getDb().collection('parse_events').add(trustedFields);
  return { success: true };
});

// URL sanitization removes sensitive params:
function sanitizeUrl(url: string): string | null {
  const sensitiveParams = [
    'token', 'session', 'auth', 'key', 'password',
    'secret', 'api_key', 'access_token', 'refresh_token'
  ];
  // ... remove params from URL
}
```

### seedSiteConfigs

**File:** `functions/src/admin/seed-site-configs.ts`

Populates site_configs collection with Swedish recipe sites.

```typescript
export const seedSiteConfigs = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
  }

  const SITE_CONFIGS = [
    {
      domain: 'ica.se',
      titleSelector: 'h1.recipe-header__title',
      ingredientsSelector: '.ingredients-list-group__card li',
      instructionsSelector: '.cooking-steps-main__step',
      portionsSelector: '.recipe-header__servings',
      timeSelector: '.recipe-header__time',
      imageSelector: '.recipe-header__image img',
      isSupported: true,
      qualityScore: 0.9,
    },
    // ... 7 more sites
  ];

  const batch = getDb().batch();
  for (const config of SITE_CONFIGS) {
    const ref = getDb().collection('site_configs').doc(config.domain);
    batch.set(ref, {
      ...config,
      successCount: 0,
      failureCount: 0,
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
  }

  await batch.commit();
  return { success: true, count: SITE_CONFIGS.length };
});
```

### getSiteConfigStats

**File:** `functions/src/admin/seed-site-configs.ts`

View success/failure rates for all sites.

```typescript
export const getSiteConfigStats = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
  }

  const snapshot = await getDb().collection('site_configs').get();

  const stats = snapshot.docs.map(doc => {
    const data = doc.data();
    const total = (data.successCount || 0) + (data.failureCount || 0);
    return {
      domain: doc.id,
      successCount: data.successCount || 0,
      failureCount: data.failureCount || 0,
      successRate: total > 0 ? data.successCount / total : 0,
      qualityScore: data.qualityScore || 0,
      isSupported: data.isSupported || false,
    };
  });

  return { stats, count: stats.length };
});
```

---

## 11. Integration Points

### UrlImportStrategy Integration

**File:** `lib/services/import/url_import_strategy.dart`

```dart
class UrlImportStrategy extends ImportStrategy {
  RecipeParserService? _parserService;

  // Lazy loading with graceful fallback
  RecipeParserService? get _recipeParser {
    if (_parserService != null) return _parserService;
    try {
      _parserService = ServiceLocator.get<RecipeParserService>();
      return _parserService;
    } catch (e) {
      return null;  // Service not available
    }
  }

  @override
  Future<ImportResult> import(String input, {Map<String, dynamic>? options}) async {
    final url = input.trim();

    // Use enhanced parser if available and enabled
    final parser = _recipeParser;
    if (parser != null && options?['useEnhancedParser'] == true) {
      final htmlContent = await _fetchHtmlWithTimeout(url);
      if (htmlContent != null) {
        final parseResult = await parser.parseFromUrl(
          url: url,
          htmlContent: htmlContent,
        );
        if (parseResult.success && parseResult.recipe != null) {
          return _convertParsedRecipeToImportResult(parseResult, url);
        }
      }
      // Fall through to existing logic if enhanced parser fails
    }

    // Existing multi-tier flow...
  }
}
```

### DI Registration

**File:** `lib/core/di/modules/content_module.dart`

```dart
class ContentModule implements DIModule {
  @override
  Future<void> configure(GetIt container) async {
    // ... other registrations ...

    // Site config repository
    container.registerLazySingleton<SiteConfigRepository>(
      () => SiteConfigRepository(),
    );

    // Recipe parser service
    container.registerLazySingleton<RecipeParserService>(
      () {
        final authRepo = container<AuthRepository>();
        final userId = (authRepo as FirebaseAuthRepository)
            .currentUser?.uid ?? 'anonymous';
        return RecipeParserService(
          userId: userId,
          siteConfigRepository: container<SiteConfigRepository>(),
          llmService: container<LlmService>(),
        );
      },
    );
  }

  @override
  Future<void> initialize() async {
    // ... other initializations ...

    // Initialize parser (cache + site config seeding)
    final recipeParserService = container<RecipeParserService>();
    await recipeParserService.init();
  }
}
```

### Initialization Flow

```
App Start
    │
    ▼
ContentModule.configure()
    │ Register SiteConfigRepository
    │ Register RecipeParserService
    │
    ▼
ContentModule.initialize()
    │
    ▼
RecipeParserService.init()
    ├── LocalRecipeCache.init()
    │       └── Open Hive box
    │
    └── SiteConfigRepository.seedConfigsIfEmpty()
            │
            ▼ (fire-and-forget)
        Cloud Function: seedSiteConfigs
            │
            ▼
        Firestore: site_configs collection populated
```

---

## 12. Supported Sites

Sites seeded by `seedSiteConfigs` Cloud Function:

| Domain | Quality | CSS Selectors | Notes |
|--------|---------|---------------|-------|
| **ica.se** | 0.9 | Full set | Sweden's largest grocery chain |
| **arla.se** | 0.85 | Full set | Dairy company recipes |
| **koket.se** | 0.85 | Full set | Popular Swedish recipe site |
| **recept.se** | 0.8 | Full set | Recipe aggregator |
| **coop.se** | 0.8 | Full set | Grocery cooperative |
| **tasteline.com** | 0.75 | Partial | Recipe community |
| **mathem.se** | 0.75 | Partial | Online grocery recipes |
| **alltommat.se** | 0.8 | Full set | Food magazine |

### Adding New Sites

1. Identify CSS selectors using browser dev tools
2. Add to `SITE_CONFIGS` array in `seed-site-configs.ts`
3. Deploy: `firebase deploy --only functions`
4. Call: `seedSiteConfigs` Cloud Function
5. Monitor success/failure rates in Firestore

---

## 14. File Organization

```
lib/
├── core/
│   └── circuit_breaker.dart           # P1-3 reliability
│
├── models/parsing/
│   ├── field_result.dart              # Confidence tracking
│   ├── tier_result.dart               # Per-tier results
│   ├── parsed_recipe.dart             # Final output
│   ├── parsed_ingredient.dart         # Ingredient structure
│   ├── parse_metadata.dart            # Journey tracking
│   ├── site_config.dart               # Firestore config
│   ├── parsing_correction.dart        # Feedback loop: correction aggregate
│   ├── field_correction.dart          # Feedback loop: simple field diff
│   ├── ingredient_correction.dart     # Feedback loop: ingredient diff
│   └── instruction_correction.dart    # Feedback loop: instruction diff
│
├── repositories/
│   ├── site_config_repository.dart    # Firestore integration
│   └── parsing_correction_repository.dart  # Feedback loop: correction storage
│
├── utils/text/
│   └── ingredient_preprocessor.dart   # Stage 1: Bullet/range/approx cleaning
│
└── services/
    ├── import/
    │   └── url_import_strategy.dart   # Entry point
    │
    └── parsing/
        ├── recipe_parser_service.dart # Main orchestrator
        │
        ├── tiers/
        │   ├── parsing_tier.dart      # Abstract base
        │   ├── parsing_context.dart   # Shared state
        │   ├── schema_org_tier.dart   # Tier 1
        │   ├── site_config_tier.dart  # Tier 2
        │   ├── rule_based_tier.dart   # Tier 3
        │   └── llm_tier.dart          # Tier 4
        │
        ├── cache/
        │   ├── local_recipe_cache.dart    # P0-1 cache
        │   └── parsed_recipe_cache.dart   # Feedback loop: bridge cache
        │
        ├── common/
        │   └── recipe_merger.dart      # Result merging
        │
        ├── feedback/
        │   └── recipe_diff_calculator.dart  # Feedback loop: diff algorithm
        │
        ├── parsers/
        │   ├── ingredient_parser.dart       # Stage 2: Swedish quantity/unit parsing
        │   ├── ingredient_normalizer.dart   # Stage 3: Name normalization
        │   └── swedish_line_classifier.dart # Swedish text classification
        │
        └── sanitizers/
            └── html_sanitizer.dart     # Security

functions/src/
├── events/
│   └── log-parse-event.ts             # P1-4 analytics
│
└── admin/
    └── seed-site-configs.ts           # Site seeding
```

---

## 15. Usage Examples

### Basic URL Import (Enhanced Parser)

```dart
// Enable enhanced parser in import options
final result = await importManager.importRecipe(
  'https://www.ica.se/recept/pannkakor-123',
  options: {
    'useEnhancedParser': true,  // Use tier-based parsing
  },
);

if (result.isSuccess) {
  final recipe = result.recipe!;
  print('Title: ${recipe.title}');
  print('Quality: ${result.metadata['quality']}');
  print('Tier used: ${result.metadata['successfulTier']}');
}
```

### Direct RecipeParserService Usage

```dart
final parserService = ServiceLocator.get<RecipeParserService>();

// Parse from URL
final htmlContent = await fetchHtml('https://www.koket.se/recept/...');
final result = await parserService.parseFromUrl(
  url: 'https://www.koket.se/recept/...',
  htmlContent: htmlContent,
  qualityThreshold: 0.8,  // Higher threshold
  useLlm: false,          // Disable LLM fallback
);

if (result.success) {
  final recipe = result.recipe!;

  // Check per-field confidence
  if (recipe.title.needsReview) {
    print('Title needs review: ${recipe.title.value}');
  }

  // Check ingredients structure
  print('Structured: ${recipe.ingredientStructureRatio * 100}%');

  // See tier breakdown
  for (final tier in recipe.metadata.tierResults) {
    print('${tier.tierName}: ${tier.success ? tier.quality : tier.failureReason}');
  }
}
```

### Text Import (Instagram/TikTok)

```dart
// Parse unstructured Swedish text with social media formatting
final result = await parserService.parseFromText(
  text: '''
    Pannkakor 🥞

    Ingredienser:
    • 3 dl vetemjöl
    • 6 dl mjölk
    • 3 ägg
    • 1 nypa salt

    Gör så här:
    1. Vispa ihop mjöl och hälften av mjölken
    2. Tillsätt resten av mjölken och äggen
    3. Stek i smör på medelvärme

    4 portioner • 30 min
  ''',
  source: ImportSource.instagram,
);

// Processing pipeline:
// 1. IngredientPreprocessor strips bullets:
//    "• 3 dl vetemjöl" → "3 dl vetemjöl"
//    "• 6 dl mjölk" → "6 dl mjölk"
//
// 2. RuleBasedTier + SwedishLineClassifier:
//    "Pannkakor 🥞" → title
//    "Ingredienser:" → sectionHeader
//    "3 dl vetemjöl" → ingredient (high confidence)
//    "Gör så här:" → sectionHeader
//    "1. Vispa ihop..." → instruction
//    "4 portioner" → metadata (portions: 4)
//
// 3. IngredientParser parses quantities:
//    "3 dl vetemjöl" → ParsedIngredient(3.0, "dl", "vetemjöl")
```

### Checking Cache Status

```dart
final parserService = ServiceLocator.get<RecipeParserService>();

// Get cache stats
final stats = await parserService.getCacheStats();
print('Entries: ${stats['entries']}');
print('Max entries: ${stats['maxEntries']}');
print('Parser version: ${stats['parserVersion']}');

// Clear cache if needed
await parserService.clearCache();
```

---

## 16. Troubleshooting

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| Parser service not found | DI not initialized | Ensure `ContentModule.initialize()` called |
| Site configs empty | Seeding failed | Check auth, call `seedSiteConfigs` manually |
| Low quality results | Missing schema.org | Check if site has JSON-LD markup |
| Cache not working | Circuit breaker open | Wait 2 minutes for reset |
| LLM not working | Service not configured | Check `LlmService` registration |

### Debug Logging

```dart
// Enable verbose logging
AppLogger.setLevel(LogLevel.debug);

// Parser logs at these points:
// - Tier start/end with duration
// - Cache hits/misses
// - Quality scores
// - Security validation results
// - Merge decisions
```

### Cache Troubleshooting

```dart
// Check if cache is initialized
final cache = ServiceLocator.get<LocalRecipeCache>();
final isInit = cache.isInitialized;

// Get cache key for debugging
final key = cache.generateCacheKey(
  userId: 'user123',
  url: 'https://ica.se/recept/...',
  content: htmlContent,
  source: ImportSource.url,
);
print('Cache key: $key');

// Check if entry exists
final entry = await cache.get(key);
print('Cached: ${entry != null}');
```

### Site Config Troubleshooting

```dart
// Check if config exists
final repo = ServiceLocator.get<SiteConfigRepository>();
final config = await repo.getConfigIfExists('ica.se');

if (config == null) {
  print('No config for ica.se');
} else {
  print('Quality: ${config.qualityScore}');
  print('Success rate: ${config.successRate}');
  print('Has selectors: ${config.hasSelectors}');
}

// Force seed configs
await repo.seedConfigsIfEmpty();
```

### Security Issue Investigation

```dart
// Check HTML for security issues
final sanitizer = HtmlSanitizer();
final result = sanitizer.check(htmlContent);

if (!result.isClean) {
  print('Security issues found:');
  for (final issue in result.issues) {
    print('  - $issue');
  }

  if (result.hasCriticalIssues) {
    print('CRITICAL: Content blocked');
  }
}

// Get sanitized version
final clean = sanitizer.sanitize(htmlContent);
```

---

## Appendix: Version History

| Version | Changes |
|---------|---------|
| 2.0.0 | Initial tier-based architecture |
| 2.0.1 | Added P0-1 content-hash protection |
| 2.0.2 | Added P0-2 LLM schema validation |
| 2.0.3 | Added P1-3 circuit breaker |
| 2.0.4 | Added P1-4 server-side analytics |
| 2.0.5 | Added bullet character stripping for social media imports |
| 2.1.0 | Added parser feedback loop for training data collection |

### Swedish Parsing Capabilities Summary

All critical Swedish parsing features are **working**:

| Feature | Claimed Issue | Actual Status |
|---------|---------------|---------------|
| Mixed fractions (1½ dl) | "Critical - Broken" | ✅ **WORKING** since v2.0.0 |
| Swedish decimal comma (1,5) | "Critical - Broken" | ✅ **WORKING** since v2.0.0 |
| Portions regex (4 st ägg) | "Critical - Too general" | ✅ **WORKING** since v2.0.0 |
| Bullet handling (• 2 dl) | "Critical - Missing" | ✅ **FIXED** in v2.0.5 |
| Feedback loop | N/A | ✅ **NEW** in v2.1.0 |

---

*Last updated: December 2024*
*Parser version: 2.1.0*
