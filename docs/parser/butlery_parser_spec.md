# Butlery Recipe Parser System

## Specifikation v3.4 (KOMPLETT)

En tier-baserad receptparser för den svenska marknaden med fokus på säkerhet, kostnadskontroll och kvalitet.

---

## ÄNDRINGSLOGG

### v3.4
- Komplett specifikation med alla komponenter
- Alla 4 tiers: SchemaOrg, SiteConfig, RuleBased, LLM
- Svensk ingrediens-parser och radklassificering
- SiteConfigRepository

### v3.3 (säkerhetsfixar)
| Fix | Beskrivning |
|-----|-------------|
| **P0-1** | Cache key inkluderar content-hash även med URL (förhindrar poisoning) |
| **P0-2** | LLM strikt schema-validering med allowlist (förhindrar injection) |
| **P1-3** | Circuit breaker för asynkrona writes (backpressure) |
| **P1-4** | Server ignorerar klientens tierSummaries (förhindrar analytics poisoning) |

---

## ARKITEKTUR

### Pipeline-översikt

```
┌─────────────────────────────────────────────────────────────────┐
│  INPUT                                                          │
│  URL / Text / Instagram / TikTok / YouTube / Foto               │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  RecipeParserService.parse()                                    │
│  1. Validera input                                              │
│  2. Kolla lokal cache (Hive)                                    │
│  3. Skapa ParsingContext (DOM parsas EN gång)                   │
│  4. Kör tiers i ordning tills kvalitet >= threshold             │
│  5. Slå ihop resultat med RecipeMerger                          │
│  6. Eventuellt LLM-patch för låg kvalitet                       │
│  7. Spara cache + logga event (fire-and-forget med backpressure)│
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  TIER-ORDNING                                                   │
│  1. SchemaOrgTier    - JSON-LD / microdata (bäst kvalitet)      │
│  2. SiteConfigTier   - CSS-selectors per domän                  │
│  3. RuleBasedTier    - Svensk regelbaserad parser               │
│  4. LlmTier          - AI-fallback (dyrast)                     │
└─────────────────────────────────────────────────────────────────┘
```

### Säkerhetsmodell

```
┌─────────────────────────────────────────────────────────────────┐
│  KLIENT (Flutter-app)                                           │
│  ├─ Läser: site_configs (endast)                                │
│  ├─ Skriver: INGENTING till Firestore                           │
│  ├─ Anropar: callable functions (alla writes)                   │
│  └─ Lokal cache: Hive (per-user via userId i nyckel)            │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  BACKEND (Cloud Functions + App Check)                          │
│  ├─ logParseEvent: rate-limited, ignorerar klient-summaries     │
│  ├─ saveUserRecipeCache: validerad cache-write                  │
│  ├─ submitCorrection: validerad correction-write                │
│  ├─ getSharedCache: returnerar recept (aldrig URL)              │
│  ├─ requestSharedCache: server hämtar+parsar                    │
│  └─ requestAutoSelector: LLM med sandbox-validering             │
└─────────────────────────────────────────────────────────────────┘
```

### Trust Boundaries

| Komponent | Klient kan | Server gör |
|-----------|------------|------------|
| recipe_cache | Läsa egen (via callable) | All write + validering |
| shared_cache | Läsa recept (via callable) | Fetch + parse + write |
| parse_events | Skicka metadata | Ignorerar summaries, sätter timestamp |
| corrections | Ingenting | All write |
| site_configs | Läsa | All write |

---

## FILSTRUKTUR

```
lib/
├── config/
│   └── parser_config.dart              # ParserConfig, ClassificationWeights, QualityWeights
├── core/
│   ├── auth_state.dart                 # AuthState
│   ├── clock.dart                      # Clock, SystemClock, FakeClock
│   └── circuit_breaker.dart            # CircuitBreaker
├── models/
│   └── parsing/
│       ├── field_result.dart           # FieldResult<T>, ParseConfidence
│       ├── tier_result.dart            # TierResult, TierFailureReason
│       ├── parsed_ingredient.dart      # ParsedIngredient
│       ├── parse_metadata.dart         # ParseMetadata, ImportSource
│       ├── parsed_recipe.dart          # ParsedRecipe
│       └── site_config.dart            # SiteConfig
├── repositories/
│   └── site_config_repository.dart     # SiteConfigRepository
├── services/
│   ├── llm/
│   │   └── llm_service.dart            # LlmService (abstract), LlmResponse
│   └── parsing/
│       ├── cache/
│       │   ├── cache_key_generator.dart
│       │   └── recipe_cache.dart
│       ├── common/
│       │   ├── url_canonicalizer.dart
│       │   └── recipe_merger.dart
│       ├── events/
│       │   └── parse_event_logger.dart
│       ├── parsers/
│       │   ├── parsing_utils.dart
│       │   ├── swedish_ingredient_parser.dart
│       │   └── swedish_line_classifier.dart
│       ├── sanitizers/
│       │   └── html_sanitizer.dart
│       ├── tiers/
│       │   ├── parsing_tier.dart       # Abstract + TimeoutHandling mixin
│       │   ├── parsing_context.dart
│       │   ├── schema_org_tier.dart    # Tier 1
│       │   ├── site_config_tier.dart   # Tier 2
│       │   ├── rule_based_tier.dart    # Tier 3
│       │   └── llm_tier.dart           # Tier 4
│       └── recipe_parser_service.dart

functions/
├── src/
│   ├── utils/
│   │   ├── rate-limiter.ts
│   │   ├── fetch-with-limits.ts
│   │   └── url-canonicalizer.ts
│   ├── events/
│   │   └── log-parse-event.ts
│   ├── corrections/
│   │   └── submit-correction.ts
│   ├── cache/
│   │   └── shared-cache.ts
│   └── index.ts
└── firestore.rules
```

---

## DEPENDENCIES

```yaml
dependencies:
  collection: ^1.17.0
  crypto: ^3.0.0
  equatable: ^2.0.0
  html: ^0.15.4
  hive_flutter: ^1.1.0
  cloud_firestore: ^4.0.0
  cloud_functions: ^4.0.0
  firebase_app_check: ^0.2.0
  firebase_crashlytics: ^3.0.0
```

---

## KONFIGURATION

**lib/config/parser_config.dart**
```dart
import 'package:flutter/foundation.dart';

@immutable
class ParserConfig {
  // Timeouts
  final Duration tier1Timeout;
  final Duration tier2Timeout;
  final Duration tier3Timeout;
  final Duration tier4Timeout;
  final Duration cacheReadTimeout;
  final Duration domTraversalDeadline;
  
  // Thresholds
  final double tier1QualityThreshold;
  final double tier2QualityThreshold;
  final double llmTriggerThreshold;
  
  // Limits
  final int maxInputLength;
  final int maxHtmlNodes;
  final int maxHtmlDepth;
  final int maxCacheValueSize;
  final int maxIngredientsCount;
  final int maxInstructionsCount;
  
  // LLM
  final int llmMaxInputTokens;
  final int llmMaxOutputTokens;
  final double llmInputCostPer1kTokens;
  final double llmOutputCostPer1kTokens;
  final double sekPerUsd;
  
  // Cache TTL
  final Duration urlCacheTtl;
  final Duration socialCacheTtl;
  final Duration textCacheTtl;
  
  // Circuit breaker
  final int circuitBreakerThreshold;
  final Duration circuitBreakerResetTime;
  
  // Version
  final String parserVersion;

  const ParserConfig({
    this.tier1Timeout = const Duration(seconds: 5),
    this.tier2Timeout = const Duration(seconds: 3),
    this.tier3Timeout = const Duration(seconds: 3),
    this.tier4Timeout = const Duration(seconds: 30),
    this.cacheReadTimeout = const Duration(seconds: 2),
    this.domTraversalDeadline = const Duration(milliseconds: 500),
    this.tier1QualityThreshold = 0.95,
    this.tier2QualityThreshold = 0.80,
    this.llmTriggerThreshold = 0.80,
    this.maxInputLength = 500000,
    this.maxHtmlNodes = 10000,
    this.maxHtmlDepth = 100,
    this.maxCacheValueSize = 100000,
    this.maxIngredientsCount = 200,
    this.maxInstructionsCount = 100,
    this.llmMaxInputTokens = 4000,
    this.llmMaxOutputTokens = 2000,
    this.llmInputCostPer1kTokens = 0.00025,
    this.llmOutputCostPer1kTokens = 0.00125,
    this.sekPerUsd = 10.5,
    this.urlCacheTtl = const Duration(days: 90),
    this.socialCacheTtl = const Duration(days: 60),
    this.textCacheTtl = const Duration(days: 30),
    this.circuitBreakerThreshold = 100,
    this.circuitBreakerResetTime = const Duration(minutes: 5),
    this.parserVersion = '3.4.0',
  });

  factory ParserConfig.test() => const ParserConfig(
    tier1Timeout: Duration(milliseconds: 100),
    tier2Timeout: Duration(milliseconds: 100),
    tier3Timeout: Duration(milliseconds: 100),
    tier4Timeout: Duration(milliseconds: 500),
    cacheReadTimeout: Duration(milliseconds: 50),
    domTraversalDeadline: Duration(milliseconds: 50),
    circuitBreakerThreshold: 5,
    circuitBreakerResetTime: Duration(seconds: 10),
  );
}

@immutable
class ClassificationWeights {
  final double startsWithDigit;
  final double containsUnit;
  final double shortLine;
  final double containsFoodWord;
  final double startsWithVerb;
  final double containsVerb;
  final double containsIndicator;
  final double longLine;
  final double startsWithNumber;
  final double shortNoDigits;
  final double startsWithCapital;
  
  const ClassificationWeights({
    this.startsWithDigit = 0.4,
    this.containsUnit = 0.35,
    this.shortLine = 0.1,
    this.containsFoodWord = 0.2,
    this.startsWithVerb = 0.5,
    this.containsVerb = 0.25,
    this.containsIndicator = 0.2,
    this.longLine = 0.15,
    this.startsWithNumber = 0.3,
    this.shortNoDigits = 0.4,
    this.startsWithCapital = 0.3,
  });
}

@immutable  
class QualityWeights {
  final double ingredients;
  final double instructions;
  final double title;
  final double portions;
  final double time;
  
  const QualityWeights({
    this.ingredients = 0.40,
    this.instructions = 0.30,
    this.title = 0.15,
    this.portions = 0.10,
    this.time = 0.05,
  });
  
  double calculate({
    required double ingredientsScore,
    required double instructionsScore,
    required double titleScore,
    required double portionsScore,
    required double timeScore,
  }) {
    return ingredientsScore * ingredients +
           instructionsScore * instructions +
           titleScore * title +
           portionsScore * portions +
           timeScore * time;
  }
}
```

---

## CORE

**lib/core/auth_state.dart**
```dart
class AuthState {
  String? _currentUserId;
  
  String? get userId => _currentUserId;
  bool get isLoggedIn => _currentUserId != null;
  
  void setUser(String userId) {
    _currentUserId = userId;
  }
  
  void clearUser() {
    _currentUserId = null;
  }
}
```

**lib/core/clock.dart**
```dart
abstract class Clock {
  DateTime now();
}

class SystemClock implements Clock {
  const SystemClock();
  
  @override
  DateTime now() => DateTime.now();
}

class FakeClock implements Clock {
  DateTime _now;
  
  FakeClock([DateTime? initial]) : _now = initial ?? DateTime(2025, 1, 1);
  
  @override
  DateTime now() => _now;
  
  void advance(Duration duration) {
    _now = _now.add(duration);
  }
  
  void set(DateTime time) {
    _now = time;
  }
}
```

**lib/core/circuit_breaker.dart**
```dart
import 'clock.dart';

enum CircuitState { closed, open, halfOpen }

/// Circuit breaker för att hantera kaskadfel.
/// - closed: normalt läge, requests går igenom
/// - open: för många fel, requests blockeras
/// - halfOpen: testar om systemet återhämtat sig
class CircuitBreaker {
  final int threshold;
  final Duration resetTime;
  final Clock _clock;
  
  int _failureCount = 0;
  DateTime? _openedAt;
  CircuitState _state = CircuitState.closed;

  CircuitBreaker({
    required this.threshold,
    required this.resetTime,
    required Clock clock,
  }) : _clock = clock;

  CircuitState get state {
    if (_state == CircuitState.open) {
      final elapsed = _clock.now().difference(_openedAt!);
      if (elapsed >= resetTime) {
        _state = CircuitState.halfOpen;
      }
    }
    return _state;
  }

  bool get isOpen => state == CircuitState.open;
  bool get allowRequest => state != CircuitState.open;
  int get failureCount => _failureCount;

  void recordSuccess() {
    if (_state == CircuitState.halfOpen) {
      _reset();
    }
  }

  void recordFailure() {
    _failureCount++;
    
    if (_state == CircuitState.halfOpen) {
      _trip();
    } else if (_failureCount >= threshold) {
      _trip();
    }
  }

  void _trip() {
    _state = CircuitState.open;
    _openedAt = _clock.now();
  }

  void _reset() {
    _state = CircuitState.closed;
    _failureCount = 0;
    _openedAt = null;
  }

  /// Kör operation om circuit är stängt/half-open.
  Future<T?> execute<T>(Future<T> Function() operation) async {
    if (!allowRequest) {
      return null;
    }
    
    try {
      final result = await operation();
      recordSuccess();
      return result;
    } catch (_) {
      recordFailure();
      return null;
    }
  }
}
```

---

## DATAMODELLER

**lib/models/parsing/field_result.dart**
```dart
import 'package:equatable/equatable.dart';

enum ParseConfidence { high, medium, low, failed }

extension ParseConfidenceScore on ParseConfidence {
  double get score => switch (this) {
    ParseConfidence.high => 1.0,
    ParseConfidence.medium => 0.7,
    ParseConfidence.low => 0.3,
    ParseConfidence.failed => 0.0,
  };
}

class FieldResult<T> extends Equatable {
  final T? value;
  final ParseConfidence confidence;
  final String? failureReason;

  const FieldResult({
    this.value,
    required this.confidence,
    this.failureReason,
  });

  factory FieldResult.success(T value) => FieldResult(
    value: value,
    confidence: ParseConfidence.high,
  );

  factory FieldResult.uncertain(T value) => FieldResult(
    value: value,
    confidence: ParseConfidence.medium,
  );

  factory FieldResult.low(T value, {String? reason}) => FieldResult(
    value: value,
    confidence: ParseConfidence.low,
    failureReason: reason,
  );

  factory FieldResult.failed(String reason) => FieldResult(
    value: null,
    confidence: ParseConfidence.failed,
    failureReason: reason,
  );

  bool get hasValue => value != null;
  bool get needsReview => confidence == ParseConfidence.low || confidence == ParseConfidence.failed;
  double get confidenceScore => confidence.score;

  Map<String, dynamic> toJson([Object? Function(T)? valueConverter]) => {
    'value': value != null
        ? (valueConverter != null ? valueConverter(value as T) : value)
        : null,
    'confidence': confidence.name,
    if (failureReason != null) 'failureReason': failureReason,
  };

  factory FieldResult.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic) valueConverter,
  ) => FieldResult(
    value: json['value'] != null ? valueConverter(json['value']) : null,
    confidence: ParseConfidence.values.byName(json['confidence'] as String),
    failureReason: json['failureReason'] as String?,
  );

  @override
  List<Object?> get props => [value, confidence, failureReason];
}
```

**lib/models/parsing/tier_result.dart**
```dart
import 'package:equatable/equatable.dart';
import 'parsed_recipe.dart';

class TierResult extends Equatable {
  final String tierName;
  final ParsedRecipe? recipe;
  final bool success;
  final double quality;
  final Duration duration;
  final double? costSek;
  final TierFailureReason? failureReason;
  final int? tokensUsed;

  const TierResult({
    required this.tierName,
    required this.success,
    required this.quality,
    required this.duration,
    this.recipe,
    this.costSek,
    this.failureReason,
    this.tokensUsed,
  });

  factory TierResult.success({
    required String tierName,
    required ParsedRecipe recipe,
    required Duration duration,
    double? costSek,
    int? tokensUsed,
  }) => TierResult(
    tierName: tierName,
    recipe: recipe,
    success: true,
    quality: recipe.overallQuality,
    duration: duration,
    costSek: costSek,
    tokensUsed: tokensUsed,
  );

  factory TierResult.failure({
    required String tierName,
    required TierFailureReason reason,
    required Duration duration,
  }) => TierResult(
    tierName: tierName,
    success: false,
    quality: 0.0,
    duration: duration,
    failureReason: reason,
  );

  factory TierResult.skipped({required String tierName}) => TierResult(
    tierName: tierName,
    success: false,
    quality: 0.0,
    duration: Duration.zero,
    failureReason: TierFailureReason.skipped,
  );

  @override
  List<Object?> get props => [
    tierName, recipe, success, quality, duration, costSek, failureReason, tokensUsed
  ];
}

enum TierFailureReason {
  skipped,
  timeout,
  noData,
  parseError,
  networkError,
  rateLimited,
  invalidResponse,
  inputTooLarge,
  securityBlocked,
  deadlineExceeded,
  schemaValidationFailed,
}
```

**lib/models/parsing/parsed_ingredient.dart**
```dart
import 'package:equatable/equatable.dart';
import 'field_result.dart';

class ParsedIngredient extends Equatable {
  final String? quantity;
  final String? unit;
  final String name;
  final String? preparation;
  final String originalLine;
  final ParseConfidence confidence;
  final String? ingredientId;

  const ParsedIngredient({
    this.quantity,
    this.unit,
    required this.name,
    this.preparation,
    required this.originalLine,
    required this.confidence,
    this.ingredientId,
  });

  String get displayText {
    final parts = <String>[];
    if (quantity != null) parts.add(quantity!);
    if (unit != null) parts.add(unit!);
    parts.add(name);
    if (preparation != null) parts.add('($preparation)');
    return parts.join(' ');
  }

  bool get isMatched => ingredientId != null;

  Map<String, dynamic> toJson() => {
    'quantity': quantity,
    'unit': unit,
    'name': name,
    'preparation': preparation,
    'confidence': confidence.name,
    'ingredientId': ingredientId,
  };

  factory ParsedIngredient.fromJson(Map<String, dynamic> json) => ParsedIngredient(
    quantity: json['quantity'] as String?,
    unit: json['unit'] as String?,
    name: json['name'] as String,
    preparation: json['preparation'] as String?,
    originalLine: '',
    confidence: ParseConfidence.values.byName(json['confidence'] as String),
    ingredientId: json['ingredientId'] as String?,
  );

  ParsedIngredient copyWith({
    String? quantity,
    String? unit,
    String? name,
    String? preparation,
    String? originalLine,
    ParseConfidence? confidence,
    String? ingredientId,
  }) => ParsedIngredient(
    quantity: quantity ?? this.quantity,
    unit: unit ?? this.unit,
    name: name ?? this.name,
    preparation: preparation ?? this.preparation,
    originalLine: originalLine ?? this.originalLine,
    confidence: confidence ?? this.confidence,
    ingredientId: ingredientId ?? this.ingredientId,
  );

  @override
  List<Object?> get props => [
    quantity, unit, name, preparation, originalLine, confidence, ingredientId
  ];
}
```

**lib/models/parsing/parse_metadata.dart**
```dart
import 'package:equatable/equatable.dart';
import 'tier_result.dart';

enum ImportSource { url, text, instagram, tiktok, youtube, photo, file }

class ParseMetadata extends Equatable {
  final ImportSource source;
  final String? domain;
  final String? sourceUrl;
  final String? cacheKey;
  final List<TierResult> tierResults;
  final Duration totalParseTime;
  final String parserVersion;
  final DateTime timestamp;

  const ParseMetadata({
    required this.source,
    this.domain,
    this.sourceUrl,
    this.cacheKey,
    required this.tierResults,
    required this.totalParseTime,
    required this.parserVersion,
    required this.timestamp,
  });

  String? get successfulTier {
    for (final result in tierResults) {
      if (result.success) return result.tierName;
    }
    return null;
  }

  double get totalCost => 
      tierResults.fold(0.0, (sum, r) => sum + (r.costSek ?? 0));

  Map<String, dynamic> toJson() => {
    'source': source.name,
    'domain': domain,
    'sourceUrl': sourceUrl,
    'cacheKey': cacheKey,
    'tierResults': tierResults.map((r) => {
      'tierName': r.tierName,
      'success': r.success,
      'quality': r.quality,
      'durationMs': r.duration.inMilliseconds,
      'costSek': r.costSek,
      'failureReason': r.failureReason?.name,
    }).toList(),
    'totalParseTimeMs': totalParseTime.inMilliseconds,
    'parserVersion': parserVersion,
    'timestamp': timestamp.toIso8601String(),
  };

  factory ParseMetadata.fromJson(Map<String, dynamic> json) => ParseMetadata(
    source: ImportSource.values.byName(json['source'] as String),
    domain: json['domain'] as String?,
    sourceUrl: json['sourceUrl'] as String?,
    cacheKey: json['cacheKey'] as String?,
    tierResults: (json['tierResults'] as List).map((r) => TierResult(
      tierName: r['tierName'] as String,
      success: r['success'] as bool,
      quality: (r['quality'] as num).toDouble(),
      duration: Duration(milliseconds: r['durationMs'] as int),
      costSek: (r['costSek'] as num?)?.toDouble(),
      failureReason: r['failureReason'] != null 
          ? TierFailureReason.values.byName(r['failureReason'] as String)
          : null,
    )).toList(),
    totalParseTime: Duration(milliseconds: json['totalParseTimeMs'] as int),
    parserVersion: json['parserVersion'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
  );

  @override
  List<Object?> get props => [
    source, domain, sourceUrl, cacheKey, tierResults, 
    totalParseTime, parserVersion, timestamp
  ];
}
```

**lib/models/parsing/parsed_recipe.dart**
```dart
import 'package:equatable/equatable.dart';
import 'field_result.dart';
import 'parsed_ingredient.dart';
import 'parse_metadata.dart';
import '../../config/parser_config.dart';

class ParsedRecipe extends Equatable {
  final FieldResult<String> title;
  final FieldResult<int> portions;
  final FieldResult<List<ParsedIngredient>> ingredients;
  final FieldResult<List<String>> instructions;
  final FieldResult<Duration> totalTime;
  final ParseMetadata metadata;

  const ParsedRecipe({
    required this.title,
    required this.portions,
    required this.ingredients,
    required this.instructions,
    required this.totalTime,
    required this.metadata,
  });

  double get overallQuality => _calculateQuality(const QualityWeights());
  
  double _calculateQuality(QualityWeights weights) {
    return weights.calculate(
      ingredientsScore: ingredients.confidenceScore,
      instructionsScore: instructions.confidenceScore,
      titleScore: title.confidenceScore,
      portionsScore: portions.confidenceScore,
      timeScore: totalTime.confidenceScore,
    );
  }

  List<String> get fieldsNeedingReview {
    final fields = <String>[];
    if (title.needsReview) fields.add('title');
    if (portions.needsReview) fields.add('portions');
    if (ingredients.needsReview) fields.add('ingredients');
    if (instructions.needsReview) fields.add('instructions');
    if (totalTime.needsReview) fields.add('totalTime');
    return fields;
  }

  List<ParsedIngredient> get lowConfidenceIngredients {
    return ingredients.value
        ?.where((i) => i.confidence == ParseConfidence.low || 
                       i.confidence == ParseConfidence.failed)
        .toList() ?? [];
  }

  Map<String, dynamic> toJson() => {
    'title': title.toJson(),
    'portions': portions.toJson(),
    'ingredients': ingredients.toJson(
      (list) => list.map((i) => i.toJson()).toList(),
    ),
    'instructions': instructions.toJson((list) => list),
    'totalTime': totalTime.toJson((d) => d.inMinutes),
    'metadata': metadata.toJson(),
  };

  factory ParsedRecipe.fromJson(Map<String, dynamic> json) => ParsedRecipe(
    title: FieldResult.fromJson(
      json['title'] as Map<String, dynamic>,
      (v) => v as String,
    ),
    portions: FieldResult.fromJson(
      json['portions'] as Map<String, dynamic>,
      (v) => v as int,
    ),
    ingredients: FieldResult.fromJson(
      json['ingredients'] as Map<String, dynamic>,
      (v) => (v as List)
          .map((i) => ParsedIngredient.fromJson(i as Map<String, dynamic>))
          .toList(),
    ),
    instructions: FieldResult.fromJson(
      json['instructions'] as Map<String, dynamic>,
      (v) => (v as List).cast<String>(),
    ),
    totalTime: FieldResult.fromJson(
      json['totalTime'] as Map<String, dynamic>,
      (v) => Duration(minutes: v as int),
    ),
    metadata: ParseMetadata.fromJson(json['metadata'] as Map<String, dynamic>),
  );

  ParsedRecipe copyWith({
    FieldResult<String>? title,
    FieldResult<int>? portions,
    FieldResult<List<ParsedIngredient>>? ingredients,
    FieldResult<List<String>>? instructions,
    FieldResult<Duration>? totalTime,
    ParseMetadata? metadata,
  }) => ParsedRecipe(
    title: title ?? this.title,
    portions: portions ?? this.portions,
    ingredients: ingredients ?? this.ingredients,
    instructions: instructions ?? this.instructions,
    totalTime: totalTime ?? this.totalTime,
    metadata: metadata ?? this.metadata,
  );

  @override
  List<Object?> get props => [
    title, portions, ingredients, instructions, totalTime, metadata
  ];
}
```

**lib/models/parsing/site_config.dart**
```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class SiteConfig extends Equatable {
  final String domain;
  final String? titleSelector;
  final String? ingredientsSelector;
  final String? instructionsSelector;
  final String? portionsSelector;
  final String? timeSelector;
  final DateTime lastUpdated;
  final int successCount;
  final int failureCount;
  final bool autoGenerated;
  final bool isSupported;
  final int configVersion;

  const SiteConfig({
    required this.domain,
    this.titleSelector,
    this.ingredientsSelector,
    this.instructionsSelector,
    this.portionsSelector,
    this.timeSelector,
    required this.lastUpdated,
    this.successCount = 0,
    this.failureCount = 0,
    this.autoGenerated = false,
    this.isSupported = true,
    this.configVersion = 1,
  });

  double get successRate {
    final total = successCount + failureCount;
    if (total == 0) return 0.0;
    return successCount / total;
  }

  bool get hasSelectors =>
      titleSelector != null ||
      ingredientsSelector != null ||
      instructionsSelector != null;

  factory SiteConfig.fromJson(Map<String, dynamic> json) => SiteConfig(
    domain: json['domain'] as String,
    titleSelector: json['titleSelector'] as String?,
    ingredientsSelector: json['ingredientsSelector'] as String?,
    instructionsSelector: json['instructionsSelector'] as String?,
    portionsSelector: json['portionsSelector'] as String?,
    timeSelector: json['timeSelector'] as String?,
    lastUpdated: (json['lastUpdated'] as Timestamp).toDate(),
    successCount: json['successCount'] as int? ?? 0,
    failureCount: json['failureCount'] as int? ?? 0,
    autoGenerated: json['autoGenerated'] as bool? ?? false,
    isSupported: json['isSupported'] as bool? ?? true,
    configVersion: json['configVersion'] as int? ?? 1,
  );

  @override
  List<Object?> get props => [
    domain, titleSelector, ingredientsSelector, instructionsSelector,
    portionsSelector, timeSelector, lastUpdated, successCount, 
    failureCount, autoGenerated, isSupported, configVersion
  ];
}
```
## REPOSITORIES

**lib/repositories/site_config_repository.dart**
```dart
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/parsing/site_config.dart';

/// Repository för site configs (read-only från Firestore)
class SiteConfigRepository {
  final FirebaseFirestore _firestore;
  final Map<String, _CachedConfig> _cache = {};
  static const Duration _cacheTtl = Duration(hours: 1);

  SiteConfigRepository(this._firestore);

  Future<SiteConfig?> getConfig(String domain) async {
    final normalizedDomain = _normalizeDomain(domain);
    
    // Kolla lokal cache först
    final cached = _cache[normalizedDomain];
    if (cached != null && !cached.isExpired) {
      return cached.config;
    }
    
    try {
      final doc = await _firestore
          .collection('site_configs')
          .doc(normalizedDomain)
          .get();
      
      if (!doc.exists) {
        _cache[normalizedDomain] = _CachedConfig(null, DateTime.now());
        return null;
      }
      
      final config = SiteConfig.fromJson(doc.data()!);
      _cache[normalizedDomain] = _CachedConfig(config, DateTime.now());
      return config;
    } catch (_) {
      // Vid fel, returnera cached version om den finns
      return _cache[normalizedDomain]?.config;
    }
  }

  void clearCache() {
    _cache.clear();
  }

  String _normalizeDomain(String domain) {
    var normalized = domain.toLowerCase();
    if (normalized.startsWith('www.')) {
      normalized = normalized.substring(4);
    }
    return normalized;
  }
}

class _CachedConfig {
  final SiteConfig? config;
  final DateTime fetchedAt;
  
  _CachedConfig(this.config, this.fetchedAt);
  
  bool get isExpired => 
      DateTime.now().difference(fetchedAt) > SiteConfigRepository._cacheTtl;
}
```

---

## CACHE

**lib/services/parsing/cache/cache_key_generator.dart**

> **SÄKERHETSFIX P0-1**: Cache key inkluderar ALLTID content-hash, även när URL finns.
> Detta förhindrar cache poisoning från A/B-tester, geo-targeting, etc.

```dart
import 'dart:convert';
import 'package:crypto/crypto.dart';

import '../../../models/parsing/parse_metadata.dart';

/// Genererar cache-nycklar som är resistenta mot poisoning.
/// 
/// VIKTIGT: Även med URL-hash inkluderas content-hash för att förhindra
/// att olika HTML (A/B-test, geo-targeting, cookies) ger samma nyckel.
class CacheKeyGenerator {
  /// Genererar unik cache-nyckel.
  /// 
  /// Nyckel = SHA256(userId | keySource | source | version)
  /// där keySource = urlHash + contentHash (om URL) eller bara contentHash
  static String generate({
    required String input,
    required ImportSource source,
    required String parserVersion,
    required String userId,
    String? canonicalUrlHash,
  }) {
    // P0-1 FIX: Inkludera ALLTID content-hash, även med URL
    // Detta förhindrar cache poisoning från A/B-tests, geo-targeting, etc.
    final contentHash = _hashFullText(input);
    
    final String keySource;
    if (canonicalUrlHash != null) {
      // URL + första 16 chars av content-hash
      keySource = '$canonicalUrlHash|${contentHash.substring(0, 16)}';
    } else {
      // Bara content-hash
      keySource = contentHash;
    }
    
    final bytes = utf8.encode('$userId|$keySource|${source.name}|$parserVersion');
    return sha256.convert(bytes).toString();
  }

  /// Hashar hela input-texten normaliserad.
  static String _hashFullText(String input) {
    final normalized = input.trim().replaceAll(RegExp(r'\s+'), ' ');
    final bytes = utf8.encode(normalized);
    return sha256.convert(bytes).toString();
  }
  
  /// Genererar content-hash för extern användning (t.ex. deduplication).
  static String contentHash(String input) => _hashFullText(input);
}
```

**lib/services/parsing/cache/recipe_cache.dart**
```dart
import 'dart:convert';

import 'package:hive/hive.dart';

import '../../../models/parsing/parsed_recipe.dart';
import '../../../models/parsing/parse_metadata.dart';
import '../../../config/parser_config.dart';
import '../../../core/clock.dart';
import '../../../core/auth_state.dart';
import 'cache_key_generator.dart';

/// Lokal cache (Hive). All Firestore-write sker via callable functions.
class RecipeCache {
  final Box<String> _box;
  final ParserConfig _config;
  final Clock _clock;
  final AuthState _authState;

  RecipeCache({
    required Box<String> box,
    required ParserConfig config,
    required Clock clock,
    required AuthState authState,
  }) : _box = box,
       _config = config,
       _clock = clock,
       _authState = authState;

  Future<void> clearForLogout() async {
    await _box.clear();
  }

  Future<ParsedRecipe?> get({
    required String input,
    required ImportSource source,
    String? canonicalUrlHash,
    required String expectedVersion,
  }) async {
    final userId = _authState.userId;
    if (userId == null) return null;
    
    final key = CacheKeyGenerator.generate(
      input: input,
      source: source,
      parserVersion: expectedVersion,
      userId: userId,
      canonicalUrlHash: canonicalUrlHash,
    );
    
    try {
      final json = _box.get(key);
      if (json == null) return null;
      
      final data = jsonDecode(json) as Map<String, dynamic>;
      
      // Kolla TTL
      final expiryStr = data['expiry'] as String?;
      if (expiryStr != null) {
        final expiry = DateTime.parse(expiryStr);
        if (_clock.now().isAfter(expiry)) {
          await _box.delete(key);
          return null;
        }
      }
      
      // Kolla version
      final cachedVersion = data['parserVersion'] as String?;
      if (cachedVersion != expectedVersion) {
        await _box.delete(key);
        return null;
      }
      
      return ParsedRecipe.fromJson(data['recipe'] as Map<String, dynamic>);
    } catch (_) {
      await _box.delete(key);
      return null;
    }
  }

  Future<void> set({
    required String input,
    required ImportSource source,
    String? canonicalUrlHash,
    required ParsedRecipe recipe,
  }) async {
    final userId = _authState.userId;
    if (userId == null) return;
    
    final key = CacheKeyGenerator.generate(
      input: input,
      source: source,
      parserVersion: _config.parserVersion,
      userId: userId,
      canonicalUrlHash: canonicalUrlHash,
    );
    
    final ttl = _getTtl(source);
    final expiry = _clock.now().add(ttl);
    
    final data = {
      'recipe': recipe.toJson(),
      'expiry': expiry.toIso8601String(),
      'parserVersion': _config.parserVersion,
      'source': source.name,
      'createdAt': _clock.now().toIso8601String(),
    };
    
    final json = jsonEncode(data);
    if (json.length > _config.maxCacheValueSize) {
      return; // För stor, skippa caching
    }
    
    await _box.put(key, json);
  }

  Future<void> clear() async {
    await _box.clear();
  }

  Future<int> cleanExpired() async {
    final now = _clock.now();
    var count = 0;
    final keysToDelete = <String>[];
    
    for (final key in _box.keys) {
      try {
        final json = _box.get(key);
        if (json == null) continue;
        
        final data = jsonDecode(json) as Map<String, dynamic>;
        final expiryStr = data['expiry'] as String?;
        
        if (expiryStr != null) {
          final expiry = DateTime.parse(expiryStr);
          if (now.isAfter(expiry)) {
            keysToDelete.add(key as String);
          }
        }
      } catch (_) {
        keysToDelete.add(key as String);
      }
    }
    
    for (final key in keysToDelete) {
      await _box.delete(key);
      count++;
    }
    
    return count;
  }

  Duration _getTtl(ImportSource source) {
    return switch (source) {
      ImportSource.url => _config.urlCacheTtl,
      ImportSource.instagram || ImportSource.tiktok => _config.socialCacheTtl,
      _ => _config.textCacheTtl,
    };
  }
}
```

---

## URL UTILITIES

**lib/services/parsing/common/url_canonicalizer.dart**
```dart
import 'dart:convert';
import 'package:crypto/crypto.dart';

class UrlCanonicalizer {
  static const Set<String> _trackingParams = {
    'utm_source', 'utm_medium', 'utm_campaign', 'utm_term', 'utm_content',
    'fbclid', 'gclid', 'msclkid', 'dclid',
    'ref', 'source', 'mc_cid', 'mc_eid',
    '_ga', '_gl', 'yclid', 'zanpid',
    'affiliate', 'partner', 'clickid',
  };

  /// Canonicaliserar URL genom att ta bort tracking params och fragment.
  static String canonicalize(String url) {
    try {
      final uri = Uri.parse(url);
      
      // Ta bort tracking params
      final cleanParams = Map<String, String>.from(uri.queryParameters)
        ..removeWhere((key, _) => _trackingParams.contains(key.toLowerCase()));
      
      // Normalisera host (lowercase)
      final host = uri.host.toLowerCase();
      
      // Normalisera path (ta bort trailing slash om inte root)
      var path = uri.path;
      if (path.length > 1 && path.endsWith('/')) {
        path = path.substring(0, path.length - 1);
      }
      
      // Bygg canonical URL (utan fragment)
      final canonical = Uri(
        scheme: uri.scheme,
        host: host,
        port: uri.hasPort && uri.port != 80 && uri.port != 443 ? uri.port : null,
        path: path,
        queryParameters: cleanParams.isNotEmpty ? cleanParams : null,
      );
      
      return canonical.toString();
    } catch (_) {
      return url;
    }
  }

  /// Genererar hash av canonical URL (32 chars).
  static String hashUrl(String url) {
    final canonical = canonicalize(url);
    final bytes = utf8.encode(canonical);
    return sha256.convert(bytes).toString().substring(0, 32);
  }

  /// Extraherar domain från URL.
  static String? extractDomain(String url) {
    try {
      final uri = Uri.parse(url);
      var host = uri.host.toLowerCase();
      if (host.startsWith('www.')) {
        host = host.substring(4);
      }
      return host.isNotEmpty ? host : null;
    } catch (_) {
      return null;
    }
  }
}
```

---

## HTML SANITIZER

**lib/services/parsing/sanitizers/html_sanitizer.dart**
```dart
import 'dart:collection';

import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';

import '../../../config/parser_config.dart';
import '../../../core/clock.dart';

class HtmlSanitizer {
  static const Set<String> _blockedElements = {
    'script', 'style', 'noscript', 'iframe', 'object', 'embed',
    'form', 'input', 'button', 'select', 'textarea',
    'svg', 'math', 'canvas',
    'head', 'meta', 'link', 'base',
    'template', 'slot',
  };

  static const Set<String> _noiseElements = {
    'nav', 'header', 'footer', 'aside', 'menu', 'menuitem',
    'advertisement', 'social', 'share', 'comment', 'comments',
    'related', 'sidebar', 'widget',
  };

  static const Set<String> _dangerousAttributes = {
    'onclick', 'onload', 'onerror', 'onmouseover', 'onfocus',
    'onsubmit', 'onchange', 'onkeyup', 'onkeydown',
    'style', 'class', 'id',
  };

  static final RegExp _injectionPatterns = RegExp(
    r'(ignore|disregard|forget).{0,20}(instructions?|above|previous)|'
    r'(system|assistant|user)\s*:|'
    r'<\s*(system|prompt|instruction)',
    caseSensitive: false,
  );

  /// Extraherar text med iterativ traversal och deadline.
  static String extractText(
    String html, {
    required ParserConfig config,
    required Clock clock,
  }) {
    final deadline = clock.now().add(config.domTraversalDeadline);
    final document = html_parser.parse(html);
    
    final result = _iterativeTraversal(
      document: document,
      config: config,
      deadline: deadline,
      clock: clock,
      extractTextOnly: true,
    );
    
    if (result.deadlineExceeded) {
      throw HtmlSanitizationException('Deadline exceeded during traversal');
    }
    
    return result.text
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'\n\s*\n+'), '\n\n')
        .trim();
  }

  /// Saniterar HTML för LLM med iterativ traversal och deadline.
  static String sanitizeForLlm(
    String html, {
    required ParserConfig config,
    required Clock clock,
    int maxLength = 12000,
    bool keepStructure = true,
  }) {
    final deadline = clock.now().add(config.domTraversalDeadline);
    final document = html_parser.parse(html);
    
    final result = _iterativeTraversal(
      document: document,
      config: config,
      deadline: deadline,
      clock: clock,
      extractTextOnly: false,
    );
    
    final recipeContent = _extractRecipeRelevantContent(document);
    var output = recipeContent ?? result.html;
    
    if (output.length > maxLength) {
      output = output.substring(0, maxLength);
      final lastTagEnd = output.lastIndexOf('>');
      if (lastTagEnd > maxLength * 0.8) {
        output = output.substring(0, lastTagEnd + 1);
      }
    }
    
    return output;
  }

  /// Iterativ DOM-traversal med deadline, max nodes och max depth.
  static _TraversalResult _iterativeTraversal({
    required Document document,
    required ParserConfig config,
    required DateTime deadline,
    required Clock clock,
    required bool extractTextOnly,
  }) {
    final textBuffer = StringBuffer();
    final nodesToRemove = <Node>[];
    
    var nodeCount = 0;
    var maxDepthReached = 0;
    var deadlineExceeded = false;
    
    // Stack: (node, depth)
    final stack = Queue<(Node, int)>();
    
    // Börja med document children
    for (final child in document.nodes.reversed) {
      stack.addFirst((child, 0));
    }
    
    while (stack.isNotEmpty) {
      // Kolla deadline var 100:e nod
      if (nodeCount % 100 == 0 && clock.now().isAfter(deadline)) {
        deadlineExceeded = true;
        break;
      }
      
      final (node, depth) = stack.removeFirst();
      nodeCount++;
      
      // Max nodes
      if (nodeCount > config.maxHtmlNodes) {
        break;
      }
      
      // Max depth
      if (depth > config.maxHtmlDepth) {
        continue;
      }
      
      maxDepthReached = depth > maxDepthReached ? depth : maxDepthReached;
      
      if (node is Element) {
        final tagName = node.localName?.toLowerCase() ?? '';
        
        // Ta bort blocked elements
        if (_blockedElements.contains(tagName)) {
          nodesToRemove.add(node);
          continue;
        }
        
        // Ta bort noise elements
        if (_noiseElements.contains(tagName)) {
          nodesToRemove.add(node);
          continue;
        }
        
        // Ta bort farliga attribut
        final attributesToRemove = <String>[];
        for (final attr in node.attributes.keys) {
          final attrName = attr.toString().toLowerCase();
          if (_dangerousAttributes.contains(attrName) ||
              attrName.startsWith('on') ||
              attrName.startsWith('data-')) {
            attributesToRemove.add(attr.toString());
          }
        }
        for (final attr in attributesToRemove) {
          node.attributes.remove(attr);
        }
        
        // Lägg till children på stacken (reversed för rätt ordning)
        for (final child in node.nodes.reversed) {
          stack.addFirst((child, depth + 1));
        }
      } else if (node is Text) {
        final text = node.text;
        
        // Kolla injection patterns
        if (_injectionPatterns.hasMatch(text)) {
          node.replaceWith(Text('[content removed]'));
        } else if (extractTextOnly) {
          textBuffer.write(text);
          textBuffer.write(' ');
        }
      }
    }
    
    // Ta bort markerade noder
    for (final node in nodesToRemove) {
      node.remove();
    }
    
    return _TraversalResult(
      text: textBuffer.toString(),
      html: document.outerHtml,
      nodeCount: nodeCount,
      maxDepth: maxDepthReached,
      deadlineExceeded: deadlineExceeded,
    );
  }

  static String? _extractRecipeRelevantContent(Document document) {
    final selectors = [
      '[itemtype*="schema.org/Recipe"]',
      '[itemtype*="Recipe"]',
      '.recipe',
      '#recipe',
      '[class*="recipe"]',
      'article',
      'main',
      '.content',
      '#content',
    ];
    
    for (final selector in selectors) {
      try {
        final element = document.querySelector(selector);
        if (element != null && element.text.length > 200) {
          return element.outerHtml;
        }
      } catch (_) {
        continue;
      }
    }
    
    return null;
  }

  static bool isSafe(String html) {
    if (RegExp(r'<\s*script', caseSensitive: false).hasMatch(html)) {
      return false;
    }
    if (RegExp(r'\s+on\w+\s*=', caseSensitive: false).hasMatch(html)) {
      return false;
    }
    if (RegExp(r'javascript\s*:', caseSensitive: false).hasMatch(html)) {
      return false;
    }
    if (_injectionPatterns.hasMatch(html)) {
      return false;
    }
    return true;
  }
}

class _TraversalResult {
  final String text;
  final String html;
  final int nodeCount;
  final int maxDepth;
  final bool deadlineExceeded;
  
  _TraversalResult({
    required this.text,
    required this.html,
    required this.nodeCount,
    required this.maxDepth,
    required this.deadlineExceeded,
  });
}

class HtmlSanitizationException implements Exception {
  final String message;
  HtmlSanitizationException(this.message);
  
  @override
  String toString() => 'HtmlSanitizationException: $message';
}
```

---

## PARSING UTILITIES

**lib/services/parsing/parsers/parsing_utils.dart**
```dart
import 'dart:math' show min;

import '../../../models/parsing/field_result.dart';

class ParsingUtils {
  // === PORTIONS ===
  
  static FieldResult<int> parsePortions(String? text) {
    if (text == null || text.isEmpty) {
      return FieldResult.failed('Ingen portions-text');
    }
    
    final lowerText = text.toLowerCase().trim();
    
    final patterns = [
      RegExp(r'(\d+)\s*(?:port|pers|servings?)'),
      RegExp(r'(?:ger|för|gives?|serves?|yields?)\s*(\d+)'),
      RegExp(r'(\d+)\s*-\s*\d+\s*(?:port|pers)?'),
      RegExp(r'^(\d+)$'),
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(lowerText);
      if (match != null) {
        final value = int.tryParse(match.group(1)!);
        if (value != null && value > 0 && value <= 100) {
          return FieldResult.success(value);
        }
      }
    }
    
    return FieldResult.failed('Kunde inte parsa: $text');
  }

  // === TIME ===
  
  static final RegExp _safeCombinedTimeRegex = RegExp(
    r'(\d{1,2})\s{0,3}(?:tim|timmar|h)\s{0,5}(?:och\s{0,3})?(\d{1,3})\s{0,3}(?:min|m)',
    caseSensitive: false,
  );
  
  // Stöd för unicode-bråk i tid ("1½ timme")
  static final RegExp _halfHourRegex = RegExp(
    r'(\d*)½\s*(?:tim|timmar|timme)',
    caseSensitive: false,
  );
  
  static FieldResult<Duration> parseTime(String? text) {
    if (text == null || text.isEmpty) {
      return FieldResult.failed('Ingen tids-text');
    }
    
    // Försök ISO-duration först
    final isoDuration = parseIsoDuration(text);
    if (isoDuration != null) {
      return FieldResult.success(isoDuration);
    }
    
    final lowerText = text.toLowerCase();
    
    // Kolla "1½ timme" eller "½ timme"
    final halfMatch = _halfHourRegex.firstMatch(lowerText);
    if (halfMatch != null) {
      final wholeHours = int.tryParse(halfMatch.group(1) ?? '') ?? 0;
      final duration = Duration(hours: wholeHours, minutes: 30);
      if (duration.inMinutes > 0 && duration.inMinutes <= 1440) {
        return FieldResult.success(duration);
      }
    }
    
    // Total tid patterns
    final totalPatterns = [
      RegExp(r'(?:total\s*tid|totalt|total)\s*[:\s]\s*(\d+)\s*(?:tim|timmar|h)', caseSensitive: false),
      RegExp(r'(?:total\s*tid|totalt|total)\s*[:\s]\s*(\d+)\s*(?:min|minuter|m)', caseSensitive: false),
    ];
    
    for (final pattern in totalPatterns) {
      final match = pattern.firstMatch(lowerText);
      if (match != null) {
        final value = int.tryParse(match.group(1)!);
        if (value != null) {
          final isHours = pattern.pattern.contains('tim');
          final duration = Duration(
            hours: isHours ? value : 0,
            minutes: isHours ? 0 : value,
          );
          if (duration.inMinutes > 0 && duration.inMinutes <= 1440) {
            return FieldResult.success(duration);
          }
        }
      }
    }
    
    // Kombinerad tid (t.ex. "1 tim 30 min")
    final combinedMatch = _safeCombinedTimeRegex.firstMatch(lowerText);
    if (combinedMatch != null) {
      final hours = int.tryParse(combinedMatch.group(1) ?? '0') ?? 0;
      final minutes = int.tryParse(combinedMatch.group(2) ?? '0') ?? 0;
      final duration = Duration(hours: hours, minutes: minutes);
      if (duration.inMinutes > 0 && duration.inMinutes <= 1440) {
        return FieldResult.success(duration);
      }
    }
    
    // Bara timmar
    final hourMatch = RegExp(r'(\d+)\s*(?:tim|timmar|timme|h(?:our)?s?)\b')
        .firstMatch(lowerText);
    if (hourMatch != null) {
      final hours = int.tryParse(hourMatch.group(1)!);
      if (hours != null && hours > 0 && hours <= 24) {
        return FieldResult.success(Duration(hours: hours));
      }
    }
    
    // Bara minuter
    final minMatch = RegExp(r'(\d+)\s*(?:min|minuter|minuten|m(?:inute)?s?)\b')
        .firstMatch(lowerText);
    if (minMatch != null) {
      final minutes = int.tryParse(minMatch.group(1)!);
      if (minutes != null && minutes > 0 && minutes <= 1440) {
        return FieldResult.success(Duration(minutes: minutes));
      }
    }
    
    return FieldResult.failed('Kunde inte parsa: $text');
  }

  static Duration? parseIsoDuration(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    
    final regex = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?', caseSensitive: false);
    final match = regex.firstMatch(iso);
    
    if (match == null) return null;
    
    final hours = int.tryParse(match.group(1) ?? '') ?? 0;
    final minutes = int.tryParse(match.group(2) ?? '') ?? 0;
    final seconds = int.tryParse(match.group(3) ?? '') ?? 0;
    
    final total = Duration(hours: hours, minutes: minutes, seconds: seconds);
    return total.inMinutes > 0 ? total : null;
  }

  // === FRACTIONS ===
  
  static const Map<String, double> unicodeFractions = {
    '½': 0.5, '⅓': 0.333, '⅔': 0.667, '¼': 0.25, '¾': 0.75,
    '⅕': 0.2, '⅖': 0.4, '⅗': 0.6, '⅘': 0.8,
    '⅙': 0.167, '⅚': 0.833,
    '⅛': 0.125, '⅜': 0.375, '⅝': 0.625, '⅞': 0.875,
  };

  static String normalizeFractions(String input) {
    var result = input;
    
    // "1½" -> "1.5"
    for (final entry in unicodeFractions.entries) {
      result = result.replaceAllMapped(
        RegExp('(\\d+)${entry.key}'),
        (m) => (int.parse(m.group(1)!) + entry.value).toString(),
      );
    }
    
    // Standalone fractions
    for (final entry in unicodeFractions.entries) {
      result = result.replaceAll(entry.key, entry.value.toString());
    }
    
    // "1 1/2" -> "1.5"
    result = result.replaceAllMapped(
      RegExp(r'(\d+)\s+(\d+)/(\d+)'),
      (m) {
        final whole = int.parse(m.group(1)!);
        final num = int.parse(m.group(2)!);
        final den = int.parse(m.group(3)!);
        if (den == 0) return m.group(0)!;
        return (whole + num / den).toString();
      },
    );
    
    // "1/2" -> "0.5"
    result = result.replaceAllMapped(
      RegExp(r'(?<!\d\s*)(\d+)/(\d+)'),
      (m) {
        final num = int.parse(m.group(1)!);
        final den = int.parse(m.group(2)!);
        if (den == 0) return m.group(0)!;
        return (num / den).toString();
      },
    );
    
    return result;
  }

  // === TEXT QUANTITIES ===
  
  static const Map<String, String> swedishTextQuantities = {
    'en halv': '0.5', 'ett halvt': '0.5', 'halv': '0.5', 'halvt': '0.5',
    'en': '1', 'ett': '1',
    'två': '2', 'tre': '3', 'fyra': '4', 'fem': '5',
    'sex': '6', 'sju': '7', 'åtta': '8', 'nio': '9', 'tio': '10',
    'ett par': '2', 'några': '3', 'ett dussin': '12', 'dussin': '12',
  };

  static String normalizeTextQuantities(String input) {
    var result = input.toLowerCase();
    
    // Sortera längst först för att matcha "en halv" före "en"
    final sortedEntries = swedishTextQuantities.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));
    
    for (final entry in sortedEntries) {
      result = result.replaceAll(
        RegExp('\\b${entry.key}\\b', caseSensitive: false),
        entry.value,
      );
    }
    
    return result;
  }

  // === BULLETS ===
  
  static String removeBullets(String input) {
    return input.replaceFirst(
      RegExp(r'^[\u2022\u25CF\u25E6\u2023\u2043•\-\*]\s*'),
      '',
    );
  }

  // === VALIDATION ===
  
  static bool isValidIngredientName(String name) {
    if (name.isEmpty || name.length > 200) return false;
    if (name.length < 2) return false;
    if (RegExp(r'^\d+$').hasMatch(name)) return false;
    if (name.contains('http')) return false;
    return true;
  }

  static bool isValidInstruction(String instruction) {
    if (instruction.isEmpty || instruction.length > 2000) return false;
    if (instruction.length < 5) return false;
    return true;
  }

  // === HTML ENTITIES ===
  
  static String decodeHtmlEntities(String input) {
    var result = input;
    
    const namedEntities = {
      '&amp;': '&', '&lt;': '<', '&gt;': '>',
      '&quot;': '"', '&apos;': "'", '&nbsp;': ' ',
      '&deg;': '°', '&frac12;': '½', '&frac14;': '¼', '&frac34;': '¾',
    };
    
    for (final entry in namedEntities.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }
    
    // Numeric entities (&#123;)
    result = result.replaceAllMapped(
      RegExp(r'&#(\d+);'),
      (m) {
        final code = int.tryParse(m.group(1)!);
        if (code != null && code > 0 && code < 65536) {
          return String.fromCharCode(code);
        }
        return m.group(0)!;
      },
    );
    
    // Hex entities (&#x1F4;)
    result = result.replaceAllMapped(
      RegExp(r'&#x([0-9a-fA-F]+);'),
      (m) {
        final code = int.tryParse(m.group(1)!, radix: 16);
        if (code != null && code > 0 && code < 65536) {
          return String.fromCharCode(code);
        }
        return m.group(0)!;
      },
    );
    
    return result;
  }
}
```
## SWEDISH INGREDIENT PARSER

**lib/services/parsing/parsers/swedish_ingredient_parser.dart**
```dart
import 'dart:math' show min;

import '../../../models/parsing/parsed_ingredient.dart';
import '../../../models/parsing/field_result.dart';
import '../../../config/parser_config.dart';
import 'parsing_utils.dart';

/// Svensk ingrediensparser
class SwedishIngredientParser {
  final ParserConfig config;
  
  SwedishIngredientParser(this.config);

  static const Map<String, List<String>> unitAliases = {
    'msk': ['matsked', 'matskedar', 'msk.'],
    'tsk': ['tesked', 'teskedar', 'tsk.'],
    'krm': ['kryddmått', 'krm.'],
    'ml': ['milliliter'],
    'cl': ['centiliter'],
    'dl': ['deciliter'],
    'l': ['liter'],
    'g': ['gram'],
    'hg': ['hekto', 'hektogram'],
    'kg': ['kilo', 'kilogram'],
    'st': ['styck', 'stycken', 'st.'],
    'port': ['portion', 'portioner'],
    'förp': ['förpackning', 'förpackningar', 'paket', 'pkt'],
    'burk': ['burkar'],
    'näve': ['nävar'],
    'nypa': ['nypor'],
  };

  static const Set<String> preparationWords = {
    'hackad', 'hackade', 'hackat',
    'skivad', 'skivade', 'skivat',
    'strimlad', 'strimlade', 'strimlat',
    'riven', 'rivet', 'rivna',
    'krossad', 'krossade', 'krossat',
    'tärnad', 'tärnade', 'tärnat',
    'mosad', 'mosade', 'mosat',
    'pressad', 'pressade', 'pressat',
    'skalad', 'skalade', 'skalat',
    'delad', 'delade', 'delat',
    'halverad', 'halverade', 'halverat',
    'smält', 'smälta', 'smällt',
    'kokt', 'kokta',
    'stekt', 'stekta',
    'färsk', 'färska', 'färskt',
    'fryst', 'frysta',
    'torkad', 'torkade', 'torkat',
    'rökt', 'rökta',
    'grovhackad', 'grovhackade', 'grovhackat',
    'finhackad', 'finhackade', 'finhackat',
    'tunnskivad', 'tunnskivade',
    'grovt', 'fint',
    'ca', 'cirka', 'ungefär',
    'rumstempererad', 'rumstempererade',
  };

  ParsedIngredient parse(String line) {
    final originalLine = line;
    var input = _normalizeInput(line);
    
    // Extrahera quantity
    final quantity = _extractQuantity(input);
    final remaining1 = quantity != null 
        ? input.substring(quantity.length).trim() 
        : input;
    
    // Extrahera unit
    final unit = _extractUnit(remaining1);
    final remaining2 = unit != null 
        ? remaining1.substring(unit.length).trim() 
        : remaining1;
    
    // Extrahera preparation och name
    final preparation = _extractPreparation(remaining2);
    final name = _extractName(remaining2, preparation);
    
    final confidence = _calculateConfidence(
      hasQuantity: quantity != null,
      hasUnit: unit != null,
      hasName: name.isNotEmpty,
    );
    
    return ParsedIngredient(
      quantity: quantity,
      unit: _normalizeUnit(unit),
      name: name,
      preparation: preparation,
      originalLine: originalLine,
      confidence: confidence,
    );
  }

  List<ParsedIngredient> parseAll(List<String> lines) {
    return lines
        .map((line) => parse(line))
        .where((ing) => ParsingUtils.isValidIngredientName(ing.name))
        .take(config.maxIngredientsCount)
        .toList();
  }

  String _normalizeInput(String input) {
    var result = input.trim();
    result = ParsingUtils.removeBullets(result);
    result = ParsingUtils.normalizeFractions(result);
    result = ParsingUtils.normalizeTextQuantities(result);
    result = result.replaceAll(RegExp(r'\s+'), ' ');
    result = ParsingUtils.decodeHtmlEntities(result);
    return result;
  }

  String? _extractQuantity(String input) {
    final patterns = [
      // Range: "1-2" eller "1–2"
      RegExp(r'^(\d+(?:\.\d+)?)\s*[-–]\s*(\d+(?:\.\d+)?)'),
      // Decimal: "1.5" eller "1,5"
      RegExp(r'^(\d+[.,]\d+)'),
      // Integer: "2"
      RegExp(r'^(\d+)'),
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(input);
      if (match != null) {
        var quantity = match.group(0)!;
        quantity = quantity.replaceAll(',', '.');
        return quantity;
      }
    }
    
    return null;
  }

  String? _extractUnit(String input) {
    final lowerInput = input.toLowerCase();
    
    for (final entry in unitAliases.entries) {
      final unit = entry.key;
      final aliases = entry.value;
      
      // Kolla huvudenheten
      if (lowerInput.startsWith(unit) && 
          (lowerInput.length == unit.length || 
           !RegExp(r'\w').hasMatch(lowerInput[unit.length]))) {
        return input.substring(0, unit.length);
      }
      
      // Kolla aliases
      for (final alias in aliases) {
        if (lowerInput.startsWith(alias) &&
            (lowerInput.length == alias.length ||
             !RegExp(r'\w').hasMatch(lowerInput[alias.length]))) {
          return input.substring(0, alias.length);
        }
      }
    }
    
    return null;
  }

  String? _extractPreparation(String input) {
    final words = input.toLowerCase().split(RegExp(r'\s+'));
    final preparations = <String>[];
    
    for (final word in words) {
      final cleanWord = word.replaceAll(',', '');
      if (preparationWords.contains(cleanWord)) {
        preparations.add(cleanWord);
      }
    }
    
    if (preparations.isEmpty) return null;
    return preparations.join(', ');
  }

  String _extractName(String input, String? preparation) {
    var name = input;
    
    // Ta bort preparation-ord
    if (preparation != null) {
      for (final prep in preparation.split(', ')) {
        name = name.replaceAll(RegExp('\\b$prep\\b', caseSensitive: false), '');
      }
    }
    
    // Städa upp
    name = name
        .replaceAll(RegExp(r'\s*,\s*'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^\s*[-–]\s*'), '')
        .trim();
    
    // Ta bort parenteser
    name = name.replaceAll(RegExp(r'\([^)]*\)'), '').trim();
    
    return name;
  }

  String? _normalizeUnit(String? unit) {
    if (unit == null) return null;
    
    final lowerUnit = unit.toLowerCase();
    
    for (final entry in unitAliases.entries) {
      if (entry.key == lowerUnit || entry.value.contains(lowerUnit)) {
        return entry.key;
      }
    }
    
    return lowerUnit;
  }

  ParseConfidence _calculateConfidence({
    required bool hasQuantity,
    required bool hasUnit,
    required bool hasName,
  }) {
    if (!hasName) return ParseConfidence.failed;
    if (hasQuantity && hasUnit) return ParseConfidence.high;
    if (hasQuantity || hasUnit) return ParseConfidence.medium;
    return ParseConfidence.low;
  }
}
```

---

## SWEDISH LINE CLASSIFIER

**lib/services/parsing/parsers/swedish_line_classifier.dart**
```dart
import 'dart:math' show min;

import '../../../models/parsing/field_result.dart';
import '../../../config/parser_config.dart';

enum LineType { 
  ingredient, 
  instruction, 
  title, 
  metadata, 
  sectionHeader, 
  empty, 
  unknown 
}

class ClassifiedLine {
  final String text;
  final LineType type;
  final double confidence;
  final LineType? sectionType;
  
  ClassifiedLine(this.text, this.type, this.confidence, {this.sectionType});
}

class RecipeSection {
  final LineType type;
  final List<ClassifiedLine> lines;
  
  RecipeSection({required this.type, required this.lines});
  
  double get averageConfidence =>
      lines.isEmpty ? 0 : lines.map((l) => l.confidence).reduce((a, b) => a + b) / lines.length;
}

/// Radklassificering för svensk text
class SwedishLineClassifier {
  final ClassificationWeights weights;
  
  SwedishLineClassifier([this.weights = const ClassificationWeights()]);

  static const Map<String, LineType> _sectionHeaders = {
    'ingredienser': LineType.ingredient,
    'ingrediens': LineType.ingredient,
    'ingredients': LineType.ingredient,
    'du behöver': LineType.ingredient,
    'det här behöver du': LineType.ingredient,
    'till servering': LineType.ingredient,
    'gör så här': LineType.instruction,
    'så här gör du': LineType.instruction,
    'tillagning': LineType.instruction,
    'instruktioner': LineType.instruction,
    'instructions': LineType.instruction,
    'steg för steg': LineType.instruction,
    'metod': LineType.instruction,
    'förberedelse': LineType.instruction,
    'marinad': LineType.ingredient,
    'sås': LineType.ingredient,
    'topping': LineType.ingredient,
    'garnering': LineType.ingredient,
    'servering': LineType.instruction,
    'tips': LineType.metadata,
  };

  static const Set<String> _foodWords = {
    'kyckling', 'fläsk', 'nöt', 'nötfärs', 'lamm', 'fisk', 'lax', 'torsk', 'räkor',
    'köttfärs', 'blandfärs', 'bacon', 'korv', 'skinka', 'ägg',
    'lök', 'vitlök', 'morot', 'potatis', 'tomat', 'paprika', 'gurka',
    'sallad', 'spenat', 'broccoli', 'blomkål', 'zucchini', 'selleri',
    'mjölk', 'grädde', 'smör', 'ost', 'yoghurt', 'crème', 'fraiche', 'kvarg',
    'pasta', 'ris', 'bröd', 'mjöl', 'nudlar', 'couscous', 'bulgur', 'quinoa',
    'salt', 'peppar', 'basilika', 'oregano', 'timjan', 'rosmarin', 'persilja',
    'socker', 'honung', 'sirap', 'vanilj', 'kakao', 'choklad',
    'olja', 'olivolja', 'rapsolja', 'vinäger', 'soja', 'senap',
  };

  static const Set<String> _instructionVerbs = {
    'stek', 'steka', 'koka', 'grädda', 'baka', 'fräs', 'fritera',
    'grilla', 'rosta', 'värm', 'värma', 'smält', 'smälta',
    'sjud', 'sjuda', 'pochera', 'ångkoka', 'woka', 'halstra', 'ugnsbaka',
    'skär', 'skära', 'hacka', 'strimla', 'tärna', 'dela', 'halvera',
    'riv', 'riva', 'mosa', 'mixa', 'vispa', 'blanda', 'rör', 'röra',
    'knåda', 'kavla', 'forma', 'skala', 'ansa', 'rensa', 'filea',
    'tillsätt', 'tillsätta', 'häll', 'hälla', 'lägg', 'lägga',
    'strö', 'pensla', 'bred', 'doppa', 'vänd', 'vända',
    'låt', 'låta', 'vila', 'ställ', 'sätt', 'ta', 'dra',
    'vänta', 'kyl', 'kyla', 'täck', 'täcka',
    'servera', 'garnera', 'toppa', 'dekorera', 'anrätta',
    'börja', 'avsluta', 'upprepa', 'fortsätt',
  };

  static const Set<String> _instructionIndicators = {
    'tills', 'under', 'minuter', 'minuten', 'min',
    'timmar', 'timme', 'tim', 'sekunder',
    'sedan', 'därefter', 'slutligen', 'först', 'sist',
    'ca', 'cirka', 'ungefär', 'gradvis', 'försiktigt', 'snabbt',
    'gyllene', 'gyllenbruna', 'mjuk', 'mjuka', 'genomstekt',
    'medelvärme', 'högvärme', 'svag', 'stark',
  };

  static const Set<String> _metadataWords = {
    'portioner', 'portion', 'personer', 'pers',
    'tid', 'tillagning', 'tillagad', 'förberedelsetid', 'totaltid',
    'svårighetsgrad', 'svårighet', 'lätt', 'medel', 'avancerad',
    'kategori', 'källa', 'recept',
  };

  ClassifiedLine classify(String line) {
    final trimmed = line.trim();
    
    if (trimmed.isEmpty) {
      return ClassifiedLine(line, LineType.empty, 1.0);
    }
    
    final lowerLine = trimmed.toLowerCase();
    
    // Kolla section headers först
    final sectionType = _detectSectionHeader(lowerLine);
    if (sectionType != null) {
      return ClassifiedLine(line, LineType.sectionHeader, 0.95, sectionType: sectionType);
    }
    
    final words = lowerLine.split(RegExp(r'\s+'));
    
    double ingredientScore = 0;
    double instructionScore = 0;
    double titleScore = 0;
    double metadataScore = 0;
    
    // === INGREDIENT SIGNALS ===
    
    // Börjar med siffra
    if (RegExp(r'^\d').hasMatch(trimmed)) {
      ingredientScore += weights.startsWithDigit;
    }
    
    // Innehåller enhet
    if (RegExp(
      r'\b(msk|tsk|krm|dl|cl|ml|l|g|kg|hg|st|port|burk|pkt|matsked|tesked)\b',
      caseSensitive: false,
    ).hasMatch(lowerLine)) {
      ingredientScore += weights.containsUnit;
    }
    
    // Kort rad
    if (trimmed.length < 50) {
      ingredientScore += weights.shortLine;
    }
    
    // Matord
    final foodWordCount = words.where((w) => _foodWords.contains(w)).length;
    ingredientScore += min(weights.containsFoodWord, foodWordCount * 0.1);
    
    // === INSTRUCTION SIGNALS ===
    
    // Börjar med verb
    final firstWord = words.isNotEmpty ? words.first : '';
    if (_instructionVerbs.contains(firstWord)) {
      instructionScore += weights.startsWithVerb;
    }
    
    // Innehåller verb
    final verbCount = words.where((w) => _instructionVerbs.contains(w)).length;
    instructionScore += min(weights.containsVerb, verbCount * 0.1);
    
    // Innehåller tidsindikatorer
    final indicatorCount = words.where((w) => _instructionIndicators.contains(w)).length;
    instructionScore += min(weights.containsIndicator, indicatorCount * 0.1);
    
    // Lång rad
    if (trimmed.length > 60) {
      instructionScore += weights.longLine;
    }
    
    // Börjar med numrerat steg
    if (RegExp(r'^\d+[.)]\\s').hasMatch(trimmed)) {
      instructionScore += weights.startsWithNumber;
    }
    
    // === TITLE SIGNALS ===
    
    // Kort utan siffror
    if (trimmed.length < 40 && !RegExp(r'\d').hasMatch(trimmed) && ingredientScore < 0.3) {
      titleScore += weights.shortNoDigits;
    }
    
    // Börjar med versal (men inte verb)
    if (trimmed.isNotEmpty && 
        trimmed[0] == trimmed[0].toUpperCase() &&
        !_instructionVerbs.contains(firstWord) &&
        !RegExp(r'\b(msk|tsk|dl|g|st)\b').hasMatch(lowerLine)) {
      titleScore += weights.startsWithCapital;
    }
    
    // === METADATA SIGNALS ===
    
    final metadataCount = words.where((w) => _metadataWords.contains(w)).length;
    if (metadataCount > 0) {
      metadataScore += 0.4 + min(0.3, metadataCount * 0.15);
    }
    
    // Välj bästa typ
    final scores = {
      LineType.ingredient: ingredientScore,
      LineType.instruction: instructionScore,
      LineType.title: titleScore,
      LineType.metadata: metadataScore,
    };
    
    final maxEntry = scores.entries.reduce(
      (a, b) => a.value > b.value ? a : b,
    );
    
    if (maxEntry.value >= 0.3) {
      return ClassifiedLine(line, maxEntry.key, maxEntry.value);
    }
    
    return ClassifiedLine(line, LineType.unknown, 0.0);
  }

  LineType? _detectSectionHeader(String lowerLine) {
    final cleanLine = lowerLine.replaceAll(RegExp(r'[:\.]$'), '').trim();
    
    for (final entry in _sectionHeaders.entries) {
      if (cleanLine == entry.key || 
          (cleanLine.length < 35 && cleanLine.contains(entry.key))) {
        return entry.value;
      }
    }
    return null;
  }

  List<RecipeSection> groupIntoSections(List<ClassifiedLine> lines) {
    final sections = <RecipeSection>[];
    var currentLines = <ClassifiedLine>[];
    LineType? currentType;
    LineType? forcedType;
    
    for (final line in lines) {
      if (line.type == LineType.sectionHeader) {
        // Spara föregående sektion
        if (currentLines.isNotEmpty && currentType != null) {
          sections.add(RecipeSection(type: currentType, lines: List.from(currentLines)));
          currentLines = [];
        }
        forcedType = line.sectionType;
        currentType = null;
        continue;
      }
      
      if (line.type == LineType.empty) {
        // Tom rad kan avsluta sektion (om inte forcedType)
        if (currentLines.isNotEmpty && currentType != null && forcedType == null) {
          sections.add(RecipeSection(type: currentType, lines: List.from(currentLines)));
          currentLines = [];
          currentType = null;
        }
        continue;
      }
      
      final lineType = forcedType ?? line.type;
      
      if (currentType == null || lineType == currentType) {
        currentLines.add(line);
        currentType = lineType;
      } else {
        // Ny typ, spara föregående
        if (currentLines.isNotEmpty) {
          sections.add(RecipeSection(type: currentType, lines: List.from(currentLines)));
        }
        currentLines = [line];
        currentType = lineType;
        forcedType = null;
      }
    }
    
    // Spara sista sektionen
    if (currentLines.isNotEmpty && currentType != null) {
      sections.add(RecipeSection(type: currentType, lines: currentLines));
    }
    
    return sections;
  }

  List<RecipeSection> classifyAndGroup(String text) {
    final rawLines = text.split('\n');
    final classified = rawLines.map((l) => classify(l)).toList();
    return groupIntoSections(classified);
  }
}
```

---

## TIER ABSTRAKTION

**lib/services/parsing/tiers/parsing_tier.dart**
```dart
import 'dart:async';

import '../../../models/parsing/tier_result.dart';
import 'parsing_context.dart';

abstract class ParsingTier {
  int get priority;
  String get name;
  bool canHandle(ParsingContext context);
  Future<TierResult> parse(ParsingContext context);
}

mixin TimeoutHandling on ParsingTier {
  Duration get timeout;
  
  Future<TierResult> parseWithTimeout(
    ParsingContext context,
    Future<TierResult> Function() parseFunction,
  ) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      return await parseFunction().timeout(timeout);
    } on TimeoutException {
      return TierResult.failure(
        tierName: name,
        reason: TierFailureReason.timeout,
        duration: stopwatch.elapsed,
      );
    } catch (e) {
      return TierResult.failure(
        tierName: name,
        reason: TierFailureReason.parseError,
        duration: stopwatch.elapsed,
      );
    }
  }
}
```

**lib/services/parsing/tiers/parsing_context.dart**
```dart
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';

import '../../../models/parsing/parse_metadata.dart';
import '../../../config/parser_config.dart';
import '../../../core/clock.dart';
import '../sanitizers/html_sanitizer.dart';
import '../common/url_canonicalizer.dart';

/// Delat context för alla tiers. DOM parsas EN gång och återanvänds.
class ParsingContext {
  final String input;
  final String plainText;
  final Document? document;
  final ImportSource source;
  final String? domain;
  final String? sourceUrl;
  final String? canonicalUrlHash;
  final ParserConfig config;
  final Clock clock;

  const ParsingContext({
    required this.input,
    required this.plainText,
    this.document,
    required this.source,
    required this.config,
    required this.clock,
    this.domain,
    this.sourceUrl,
    this.canonicalUrlHash,
  });
  
  factory ParsingContext.fromInput({
    required String input,
    required ImportSource source,
    required ParserConfig config,
    required Clock clock,
    String? sourceUrl,
  }) {
    Document? document;
    String plainText;
    String? domain;
    String? canonicalUrlHash;
    
    if (source == ImportSource.url) {
      // Parse DOM en gång
      document = html_parser.parse(input);
      
      // Extrahera text med deadline
      try {
        plainText = HtmlSanitizer.extractText(
          input,
          config: config,
          clock: clock,
        );
      } catch (_) {
        plainText = document.body?.text ?? '';
      }
      
      // URL-info
      if (sourceUrl != null) {
        domain = UrlCanonicalizer.extractDomain(sourceUrl);
        canonicalUrlHash = UrlCanonicalizer.hashUrl(sourceUrl);
      }
    } else {
      // För icke-URL sources, preprocessa baserat på typ
      plainText = _preprocessBySource(input, source);
    }
    
    return ParsingContext(
      input: input,
      plainText: plainText,
      document: document,
      source: source,
      config: config,
      clock: clock,
      domain: domain,
      sourceUrl: sourceUrl,
      canonicalUrlHash: canonicalUrlHash,
    );
  }
  
  static String _preprocessBySource(String input, ImportSource source) {
    switch (source) {
      case ImportSource.instagram:
      case ImportSource.tiktok:
        return _preprocessSocial(input);
      default:
        return input;
    }
  }
  
  static String _preprocessSocial(String input) {
    final lines = input.split('\n');
    final processed = <String>[];
    
    for (final line in lines) {
      var processedLine = line;
      
      // Ta bort hashtags i slutet
      processedLine = processedLine.replaceAllMapped(
        RegExp(r'(?:^|\s)(#\w+)(?=\s*#|\s*$)'),
        (m) => ' ',
      );
      
      // Ta bort @mentions och URLs
      processedLine = processedLine.replaceAll(RegExp(r'@\w+'), '');
      processedLine = processedLine.replaceAll(RegExp(r'https?://\S+'), '');
      
      processed.add(processedLine.trim());
    }
    
    return processed.where((l) => l.isNotEmpty).join('\n');
  }
}
```

---

## TIER 1: SCHEMA.ORG

**lib/services/parsing/tiers/schema_org_tier.dart**
```dart
import 'dart:convert';

import 'package:html/dom.dart';

import '../../../models/parsing/parsed_recipe.dart';
import '../../../models/parsing/parsed_ingredient.dart';
import '../../../models/parsing/field_result.dart';
import '../../../models/parsing/parse_metadata.dart';
import '../../../models/parsing/tier_result.dart';
import '../parsers/parsing_utils.dart';
import 'parsing_tier.dart';
import 'parsing_context.dart';

class SchemaOrgTier extends ParsingTier with TimeoutHandling {
  @override
  int get priority => 1;
  
  @override
  String get name => 'SchemaOrg';
  
  @override
  Duration get timeout => const Duration(seconds: 2);

  @override
  bool canHandle(ParsingContext context) {
    return context.source == ImportSource.url && context.document != null;
  }

  @override
  Future<TierResult> parse(ParsingContext context) {
    return parseWithTimeout(context, () => _parse(context));
  }

  Future<TierResult> _parse(ParsingContext context) async {
    final stopwatch = Stopwatch()..start();
    final document = context.document!;
    
    // Försök JSON-LD först, sen microdata
    var recipe = _extractBestFromJsonLd(document);
    recipe ??= _extractFromMicrodata(document);
    
    if (recipe == null) {
      return TierResult.failure(
        tierName: name,
        reason: TierFailureReason.noData,
        duration: stopwatch.elapsed,
      );
    }
    
    final recipeWithMetadata = recipe.copyWith(
      metadata: ParseMetadata(
        source: context.source,
        domain: context.domain,
        sourceUrl: context.sourceUrl,
        cacheKey: context.canonicalUrlHash,
        tierResults: [],
        totalParseTime: stopwatch.elapsed,
        parserVersion: context.config.parserVersion,
        timestamp: context.clock.now(),
      ),
    );
    
    return TierResult.success(
      tierName: name,
      recipe: recipeWithMetadata,
      duration: stopwatch.elapsed,
    );
  }

  /// Extraherar ALLA ld+json scripts och väljer bästa Recipe.
  ParsedRecipe? _extractBestFromJsonLd(Document document) {
    final scripts = document.querySelectorAll('script[type="application/ld+json"]');
    
    final candidates = <_RecipeCandidate>[];
    
    for (final script in scripts) {
      try {
        final content = script.text.trim();
        if (content.isEmpty) continue;
        
        final json = jsonDecode(content);
        final recipes = _findAllRecipesInJson(json);
        
        for (final recipeJson in recipes) {
          final parsed = _parseSchemaRecipe(recipeJson);
          final score = _scoreRecipe(parsed);
          candidates.add(_RecipeCandidate(parsed, score));
        }
      } on FormatException {
        continue;
      }
    }
    
    if (candidates.isEmpty) return null;
    
    // Välj bästa recept baserat på score
    candidates.sort((a, b) => b.score.compareTo(a.score));
    return candidates.first.recipe;
  }

  /// Hittar ALLA Recipe-objekt rekursivt i JSON.
  List<Map<String, dynamic>> _findAllRecipesInJson(dynamic json) {
    final recipes = <Map<String, dynamic>>[];
    
    if (json is Map<String, dynamic>) {
      final type = json['@type'];
      final isRecipe = type == 'Recipe' || 
                       (type is List && type.contains('Recipe'));
      
      if (isRecipe) {
        recipes.add(json);
      }
      
      // Sök i @graph
      if (json['@graph'] is List) {
        for (final item in json['@graph'] as List) {
          recipes.addAll(_findAllRecipesInJson(item));
        }
      }
      
      // Sök i nested objects
      for (final value in json.values) {
        if (value is Map || value is List) {
          recipes.addAll(_findAllRecipesInJson(value));
        }
      }
    }
    
    if (json is List) {
      for (final item in json) {
        recipes.addAll(_findAllRecipesInJson(item));
      }
    }
    
    return recipes;
  }

  /// Poängsätter recept för att välja bäst.
  double _scoreRecipe(ParsedRecipe recipe) {
    var score = 0.0;
    
    if (recipe.title.hasValue) score += 1.0;
    
    // Ingredienser viktigast
    if (recipe.ingredients.hasValue) {
      score += 3.0;
      score += (recipe.ingredients.value!.length * 0.1).clamp(0, 2);
    }
    
    // Instruktioner näst viktigast
    if (recipe.instructions.hasValue) {
      score += 2.0;
      score += (recipe.instructions.value!.length * 0.2).clamp(0, 2);
    }
    
    if (recipe.portions.hasValue) score += 0.5;
    if (recipe.totalTime.hasValue) score += 0.5;
    
    return score;
  }

  ParsedRecipe _parseSchemaRecipe(Map<String, dynamic> recipe) {
    return ParsedRecipe(
      title: _extractTitle(recipe),
      portions: _extractPortions(recipe),
      ingredients: _extractIngredients(recipe),
      instructions: _extractInstructions(recipe),
      totalTime: _extractTime(recipe),
      metadata: ParseMetadata(
        source: ImportSource.url,
        tierResults: [],
        totalParseTime: Duration.zero,
        parserVersion: '',
        timestamp: DateTime.now(),
      ),
    );
  }

  FieldResult<String> _extractTitle(Map<String, dynamic> recipe) {
    final name = recipe['name'];
    if (name is String && name.isNotEmpty) {
      final decoded = ParsingUtils.decodeHtmlEntities(name.trim());
      return FieldResult.success(decoded);
    }
    return FieldResult.failed('Ingen titel i Schema.org');
  }

  FieldResult<int> _extractPortions(Map<String, dynamic> recipe) {
    final yield_ = recipe['recipeYield'];
    
    if (yield_ == null) {
      return FieldResult.failed('Ingen yield i Schema.org');
    }
    
    String yieldStr;
    if (yield_ is List && yield_.isNotEmpty) {
      yieldStr = yield_.first.toString();
    } else {
      yieldStr = yield_.toString();
    }
    
    return ParsingUtils.parsePortions(yieldStr);
  }

  FieldResult<List<ParsedIngredient>> _extractIngredients(Map<String, dynamic> recipe) {
    final ingredients = recipe['recipeIngredient'];
    
    if (ingredients == null || ingredients is! List || ingredients.isEmpty) {
      return FieldResult.failed('Inga ingredienser i Schema.org');
    }
    
    final parsed = <ParsedIngredient>[];
    for (final ing in ingredients) {
      if (ing is String && ing.isNotEmpty) {
        final decoded = ParsingUtils.decodeHtmlEntities(ing.trim());
        parsed.add(ParsedIngredient(
          name: decoded,
          originalLine: decoded,
          confidence: ParseConfidence.medium,
        ));
      }
    }
    
    if (parsed.isEmpty) {
      return FieldResult.failed('Inga giltiga ingredienser');
    }
    
    return FieldResult(
      value: parsed,
      confidence: ParseConfidence.medium,
    );
  }

  FieldResult<List<String>> _extractInstructions(Map<String, dynamic> recipe) {
    final instructions = recipe['recipeInstructions'];
    
    if (instructions == null) {
      return FieldResult.failed('Inga instruktioner i Schema.org');
    }
    
    final steps = <String>[];
    
    if (instructions is List) {
      for (final item in instructions) {
        if (item is String) {
          final decoded = ParsingUtils.decodeHtmlEntities(item.trim());
          if (decoded.isNotEmpty) steps.add(decoded);
        } else if (item is Map) {
          final text = item['text'] ?? item['name'];
          if (text is String && text.isNotEmpty) {
            final decoded = ParsingUtils.decodeHtmlEntities(text.trim());
            steps.add(decoded);
          }
          
          // Hantera HowToSection
          if (item['itemListElement'] is List) {
            for (final subItem in item['itemListElement'] as List) {
              if (subItem is Map) {
                final subText = subItem['text'] ?? subItem['name'];
                if (subText is String && subText.isNotEmpty) {
                  final decoded = ParsingUtils.decodeHtmlEntities(subText.trim());
                  steps.add(decoded);
                }
              }
            }
          }
        }
      }
    } else if (instructions is String) {
      final decoded = ParsingUtils.decodeHtmlEntities(instructions);
      steps.addAll(
        decoded.split(RegExp(r'\n|(?<=\.)\s{2,}')).where((s) => s.trim().isNotEmpty)
      );
    }
    
    if (steps.isEmpty) {
      return FieldResult.failed('Inga giltiga instruktioner');
    }
    
    return FieldResult.success(steps);
  }

  FieldResult<Duration> _extractTime(Map<String, dynamic> recipe) {
    final totalTime = recipe['totalTime'];
    if (totalTime != null) {
      final duration = ParsingUtils.parseIsoDuration(totalTime.toString());
      if (duration != null) {
        return FieldResult.success(duration);
      }
    }
    
    // Kombinera prep + cook time
    final prepTime = ParsingUtils.parseIsoDuration(recipe['prepTime']?.toString());
    final cookTime = ParsingUtils.parseIsoDuration(recipe['cookTime']?.toString());
    
    if (prepTime != null || cookTime != null) {
      final total = Duration(
        minutes: (prepTime?.inMinutes ?? 0) + (cookTime?.inMinutes ?? 0),
      );
      if (total.inMinutes > 0) {
        return FieldResult.success(total);
      }
    }
    
    return FieldResult.failed('Ingen tid i Schema.org');
  }

  ParsedRecipe? _extractFromMicrodata(Document document) {
    final recipeElement = document.querySelector('[itemtype*="schema.org/Recipe"]');
    if (recipeElement == null) return null;
    
    String? getItemprop(String prop) {
      final el = recipeElement.querySelector('[itemprop="$prop"]');
      if (el == null) return null;
      return ParsingUtils.decodeHtmlEntities(el.text.trim());
    }
    
    List<String> getAllItemprop(String prop) {
      return recipeElement
          .querySelectorAll('[itemprop="$prop"]')
          .map((e) => ParsingUtils.decodeHtmlEntities(e.text.trim()))
          .where((s) => s.isNotEmpty)
          .toList();
    }
    
    final name = getItemprop('name');
    final ingredients = getAllItemprop('recipeIngredient');
    
    if (name == null && ingredients.isEmpty) {
      return null;
    }
    
    return ParsedRecipe(
      title: name != null 
          ? FieldResult.success(name)
          : FieldResult.failed('Ingen titel'),
      portions: ParsingUtils.parsePortions(getItemprop('recipeYield')),
      ingredients: ingredients.isNotEmpty
          ? FieldResult(
              value: ingredients.map((i) => ParsedIngredient(
                name: i,
                originalLine: i,
                confidence: ParseConfidence.medium,
              )).toList(),
              confidence: ParseConfidence.medium,
            )
          : FieldResult.failed('Inga ingredienser'),
      instructions: getAllItemprop('recipeInstructions').isNotEmpty
          ? FieldResult.success(getAllItemprop('recipeInstructions'))
          : FieldResult.failed('Inga instruktioner'),
      totalTime: ParsingUtils.parseTime(getItemprop('totalTime')),
      metadata: ParseMetadata(
        source: ImportSource.url,
        tierResults: [],
        totalParseTime: Duration.zero,
        parserVersion: '',
        timestamp: DateTime.now(),
      ),
    );
  }
}

class _RecipeCandidate {
  final ParsedRecipe recipe;
  final double score;
  
  _RecipeCandidate(this.recipe, this.score);
}
```

---

## TIER 2: SITE CONFIG

**lib/services/parsing/tiers/site_config_tier.dart**
```dart
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';

import '../../../models/parsing/parsed_recipe.dart';
import '../../../models/parsing/parsed_ingredient.dart';
import '../../../models/parsing/field_result.dart';
import '../../../models/parsing/parse_metadata.dart';
import '../../../models/parsing/tier_result.dart';
import '../../../models/parsing/site_config.dart';
import '../../../repositories/site_config_repository.dart';
import '../parsers/parsing_utils.dart';
import 'parsing_tier.dart';
import 'parsing_context.dart';

/// Tier 2: CSS-selectors per domän (read-only från Firestore)
class SiteConfigTier extends ParsingTier with TimeoutHandling {
  final SiteConfigRepository _configRepo;
  
  SiteConfigTier(this._configRepo);
  
  @override
  int get priority => 2;
  
  @override
  String get name => 'SiteConfig';
  
  @override
  Duration get timeout => const Duration(seconds: 3);

  @override
  bool canHandle(ParsingContext context) {
    return context.source == ImportSource.url && context.domain != null;
  }

  @override
  Future<TierResult> parse(ParsingContext context) {
    return parseWithTimeout(context, () => _parse(context));
  }

  Future<TierResult> _parse(ParsingContext context) async {
    final stopwatch = Stopwatch()..start();
    
    // Hämta config för domänen
    final config = await _configRepo.getConfig(context.domain!);
    
    if (config == null || !config.hasSelectors || !config.isSupported) {
      return TierResult.failure(
        tierName: name,
        reason: TierFailureReason.noData,
        duration: stopwatch.elapsed,
      );
    }
    
    final document = context.document ?? html_parser.parse(context.input);
    final recipe = _parseWithConfig(document, config);
    
    if (recipe == null) {
      return TierResult.failure(
        tierName: name,
        reason: TierFailureReason.parseError,
        duration: stopwatch.elapsed,
      );
    }
    
    final recipeWithMetadata = recipe.copyWith(
      metadata: ParseMetadata(
        source: context.source,
        domain: context.domain,
        sourceUrl: context.sourceUrl,
        tierResults: [],
        totalParseTime: stopwatch.elapsed,
        parserVersion: context.config.parserVersion,
        timestamp: context.clock.now(),
      ),
    );
    
    return TierResult.success(
      tierName: name,
      recipe: recipeWithMetadata,
      duration: stopwatch.elapsed,
    );
  }

  ParsedRecipe? _parseWithConfig(Document document, SiteConfig config) {
    final title = _extractWithSelector(document, config.titleSelector);
    final ingredientsRaw = _extractAllWithSelector(document, config.ingredientsSelector);
    final instructionsRaw = _extractAllWithSelector(document, config.instructionsSelector);
    final portionsRaw = _extractWithSelector(document, config.portionsSelector);
    final timeRaw = _extractWithSelector(document, config.timeSelector);
    
    // Kräv minst ingredienser eller instruktioner
    if (ingredientsRaw.isEmpty && instructionsRaw.isEmpty) {
      return null;
    }
    
    return ParsedRecipe(
      title: title != null
          ? FieldResult.success(title)
          : FieldResult.failed('Ingen titel'),
      portions: ParsingUtils.parsePortions(portionsRaw),
      ingredients: ingredientsRaw.isNotEmpty
          ? FieldResult(
              value: ingredientsRaw.map((i) => ParsedIngredient(
                name: i,
                originalLine: i,
                confidence: ParseConfidence.medium,
              )).toList(),
              confidence: ParseConfidence.medium,
            )
          : FieldResult.failed('Inga ingredienser'),
      instructions: instructionsRaw.isNotEmpty
          ? FieldResult.success(instructionsRaw)
          : FieldResult.failed('Inga instruktioner'),
      totalTime: ParsingUtils.parseTime(timeRaw),
      metadata: ParseMetadata(
        source: ImportSource.url,
        tierResults: [],
        totalParseTime: Duration.zero,
        parserVersion: '',
        timestamp: DateTime.now(),
      ),
    );
  }

  String? _extractWithSelector(Document document, String? selector) {
    if (selector == null || selector.isEmpty) return null;
    
    try {
      final element = document.querySelector(selector);
      if (element == null) return null;
      
      final text = ParsingUtils.decodeHtmlEntities(element.text.trim());
      return text.isNotEmpty ? text : null;
    } catch (_) {
      return null;
    }
  }

  List<String> _extractAllWithSelector(Document document, String? selector) {
    if (selector == null || selector.isEmpty) return [];
    
    try {
      final elements = document.querySelectorAll(selector);
      return elements
          .map((e) => ParsingUtils.decodeHtmlEntities(e.text.trim()))
          .where((s) => s.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }
}
```

---

## TIER 3: RULE BASED

**lib/services/parsing/tiers/rule_based_tier.dart**
```dart
import '../../../models/parsing/parsed_recipe.dart';
import '../../../models/parsing/parsed_ingredient.dart';
import '../../../models/parsing/field_result.dart';
import '../../../models/parsing/parse_metadata.dart';
import '../../../models/parsing/tier_result.dart';
import '../parsers/swedish_ingredient_parser.dart';
import '../parsers/swedish_line_classifier.dart';
import '../parsers/parsing_utils.dart';
import 'parsing_tier.dart';
import 'parsing_context.dart';

/// Tier 3: Regelbaserad svensk parser
class RuleBasedTier extends ParsingTier with TimeoutHandling {
  final SwedishIngredientParser _ingredientParser;
  final SwedishLineClassifier _lineClassifier;
  
  RuleBasedTier(this._ingredientParser, this._lineClassifier);
  
  @override
  int get priority => 3;
  
  @override
  String get name => 'RuleBased';
  
  @override
  Duration get timeout => const Duration(seconds: 3);

  @override
  bool canHandle(ParsingContext context) => true;

  @override
  Future<TierResult> parse(ParsingContext context) {
    return parseWithTimeout(context, () => _parse(context));
  }

  Future<TierResult> _parse(ParsingContext context) async {
    final stopwatch = Stopwatch()..start();
    
    final text = context.plainText;
    
    if (text.isEmpty) {
      return TierResult.failure(
        tierName: name,
        reason: TierFailureReason.noData,
        duration: stopwatch.elapsed,
      );
    }
    
    // Klassificera och gruppera rader
    final sections = _lineClassifier.classifyAndGroup(text);
    
    // Extrahera ingredienser
    final ingredientSection = sections.where((s) => s.type == LineType.ingredient).toList();
    final ingredientLines = ingredientSection
        .expand((s) => s.lines)
        .map((l) => l.text)
        .where((t) => t.trim().isNotEmpty)
        .toList();
    
    final ingredients = _ingredientParser.parseAll(ingredientLines);
    
    // Extrahera instruktioner
    final instructionSection = sections.where((s) => s.type == LineType.instruction).toList();
    final instructions = instructionSection
        .expand((s) => s.lines)
        .map((l) => l.text.trim())
        .where((t) => t.isNotEmpty && ParsingUtils.isValidInstruction(t))
        .take(context.config.maxInstructionsCount)
        .toList();
    
    // Extrahera titel
    final titleSection = sections.where((s) => s.type == LineType.title).toList();
    final title = titleSection.isNotEmpty 
        ? titleSection.first.lines.first.text.trim()
        : null;
    
    // Extrahera metadata (portioner, tid)
    final metadataSection = sections.where((s) => s.type == LineType.metadata).toList();
    final metadataText = metadataSection
        .expand((s) => s.lines)
        .map((l) => l.text)
        .join(' ');
    
    final portions = _extractPortions(metadataText, text);
    final totalTime = _extractTime(metadataText, text);
    
    final recipe = ParsedRecipe(
      title: title != null && title.isNotEmpty
          ? FieldResult.success(title)
          : FieldResult.failed('Ingen titel hittad'),
      portions: portions,
      ingredients: ingredients.isNotEmpty
          ? _calculateIngredientsField(ingredients)
          : FieldResult.failed('Inga ingredienser hittade'),
      instructions: instructions.isNotEmpty
          ? FieldResult.success(instructions)
          : FieldResult.failed('Inga instruktioner hittade'),
      totalTime: totalTime,
      metadata: ParseMetadata(
        source: context.source,
        domain: context.domain,
        sourceUrl: context.sourceUrl,
        tierResults: [],
        totalParseTime: stopwatch.elapsed,
        parserVersion: context.config.parserVersion,
        timestamp: context.clock.now(),
      ),
    );
    
    return TierResult.success(
      tierName: name,
      recipe: recipe,
      duration: stopwatch.elapsed,
    );
  }

  FieldResult<int> _extractPortions(String metadataText, String fullText) {
    // Försök metadata först
    var result = ParsingUtils.parsePortions(metadataText);
    if (result.hasValue) return result;
    
    // Sök i hela texten
    final patterns = [
      RegExp(r'(\d+)\s*(?:port|pers|servings?)', caseSensitive: false),
      RegExp(r'(?:ger|för|gives?|yields?|serves?)\s*(\d+)', caseSensitive: false),
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(fullText);
      if (match != null) {
        final value = int.tryParse(match.group(1)!);
        if (value != null && value > 0 && value <= 100) {
          return FieldResult.success(value);
        }
      }
    }
    
    return FieldResult.failed('Inga portioner hittade');
  }

  FieldResult<Duration> _extractTime(String metadataText, String fullText) {
    var result = ParsingUtils.parseTime(metadataText);
    if (result.hasValue) return result;
    return ParsingUtils.parseTime(fullText);
  }

  FieldResult<List<ParsedIngredient>> _calculateIngredientsField(List<ParsedIngredient> ingredients) {
    final highConfidence = ingredients.where((i) => i.confidence == ParseConfidence.high).length;
    final total = ingredients.length;
    
    final ratio = total > 0 ? highConfidence / total : 0.0;
    
    final confidence = ratio >= 0.7 
        ? ParseConfidence.high
        : ratio >= 0.4 
            ? ParseConfidence.medium
            : ParseConfidence.low;
    
    return FieldResult(
      value: ingredients,
      confidence: confidence,
    );
  }
}
```
## LLM SERVICE INTERFACE

**lib/services/llm/llm_service.dart**
```dart
abstract class LlmService {
  Future<LlmResponse> complete({
    required String prompt,
    required int maxTokens,
  });
}

class LlmResponse {
  final String content;
  final int inputTokens;
  final int outputTokens;
  
  LlmResponse({
    required this.content,
    required this.inputTokens,
    required this.outputTokens,
  });
}

class LlmRateLimitException implements Exception {
  final String message;
  LlmRateLimitException(this.message);
}
```

---

## TIER 4: LLM PARSER

> **SÄKERHETSFIX P0-2**: Strikt schema-validering med allowlist.
> Förhindrar prompt injection via manipulerade LLM-svar.

**lib/services/parsing/tiers/llm_tier.dart**
```dart
import 'dart:convert';
import 'dart:math' show min;

import '../../../models/parsing/parsed_recipe.dart';
import '../../../models/parsing/parsed_ingredient.dart';
import '../../../models/parsing/field_result.dart';
import '../../../models/parsing/parse_metadata.dart';
import '../../../models/parsing/tier_result.dart';
import '../../../config/parser_config.dart';
import '../../llm/llm_service.dart';
import '../sanitizers/html_sanitizer.dart';
import 'parsing_tier.dart';
import 'parsing_context.dart';

class LlmTier extends ParsingTier with TimeoutHandling {
  final LlmService _llm;
  final ParserConfig _config;
  
  LlmTier(this._llm, this._config);
  
  @override
  int get priority => 4;
  
  @override
  String get name => 'LLM';
  
  @override
  Duration get timeout => _config.tier4Timeout;

  @override
  bool canHandle(ParsingContext context) => true;

  @override
  Future<TierResult> parse(ParsingContext context) {
    return parseWithTimeout(context, () => _fullParse(context));
  }

  Future<TierResult> _fullParse(ParsingContext context) async {
    final stopwatch = Stopwatch()..start();
    
    final sanitizedText = _sanitizeForLlm(context.plainText);
    
    if (sanitizedText.isEmpty) {
      return TierResult.failure(
        tierName: name,
        reason: TierFailureReason.noData,
        duration: stopwatch.elapsed,
      );
    }
    
    final prompt = _buildFullParsePrompt(sanitizedText, context.source);
    
    try {
      final response = await _llm.complete(
        prompt: prompt,
        maxTokens: _config.llmMaxOutputTokens,
      );
      
      final recipe = _parseResponse(response.content, context);
      
      if (recipe == null) {
        return TierResult.failure(
          tierName: name,
          reason: TierFailureReason.invalidResponse,
          duration: stopwatch.elapsed,
        );
      }
      
      final cost = _calculateCost(response.inputTokens, response.outputTokens);
      
      return TierResult.success(
        tierName: name,
        recipe: recipe,
        duration: stopwatch.elapsed,
        costSek: cost,
        tokensUsed: response.inputTokens + response.outputTokens,
      );
    } on LlmRateLimitException {
      return TierResult.failure(
        tierName: name,
        reason: TierFailureReason.rateLimited,
        duration: stopwatch.elapsed,
      );
    } catch (_) {
      return TierResult.failure(
        tierName: name,
        reason: TierFailureReason.networkError,
        duration: stopwatch.elapsed,
      );
    }
  }

  /// Patcha specifika fält med LLM (billigare än full parse)
  Future<TierResult> patchFields({
    required ParsingContext context,
    required ParsedRecipe existingRecipe,
    required List<String> fieldsToFix,
  }) async {
    final stopwatch = Stopwatch()..start();
    
    if (fieldsToFix.isEmpty) {
      return TierResult.success(
        tierName: name,
        recipe: existingRecipe,
        duration: stopwatch.elapsed,
        costSek: 0,
        tokensUsed: 0,
      );
    }
    
    final sanitizedText = _sanitizeForLlm(context.plainText);
    final prompt = _buildPatchPrompt(existingRecipe, fieldsToFix, sanitizedText);
    
    try {
      final response = await _llm.complete(
        prompt: prompt,
        maxTokens: min(1500, _config.llmMaxOutputTokens),
      );
      
      final patchedRecipe = _applyPatch(existingRecipe, response.content, fieldsToFix, context);
      final cost = _calculateCost(response.inputTokens, response.outputTokens);
      
      return TierResult.success(
        tierName: name,
        recipe: patchedRecipe ?? existingRecipe,
        duration: stopwatch.elapsed,
        costSek: cost,
        tokensUsed: response.inputTokens + response.outputTokens,
      );
    } catch (_) {
      return TierResult.failure(
        tierName: name,
        reason: TierFailureReason.networkError,
        duration: stopwatch.elapsed,
      );
    }
  }

  String _sanitizeForLlm(String text) {
    final maxLength = _config.llmMaxInputTokens * 4; // ~4 chars per token
    var sanitized = text.length > maxLength 
        ? text.substring(0, maxLength) 
        : text;
    
    // Extra sanitering om innehållet ser misstänkt ut
    if (!HtmlSanitizer.isSafe(sanitized)) {
      sanitized = sanitized
          .replaceAll(RegExp(r'<[^>]+>', caseSensitive: false), '')
          .replaceAll(RegExp(r'(ignore|disregard).{0,30}instructions?', caseSensitive: false), '[removed]')
          .replaceAll(RegExp(r'(system|assistant|user)\s*:', caseSensitive: false), '[removed]');
    }
    
    return sanitized.trim();
  }

  String _buildFullParsePrompt(String text, ImportSource source) {
    final sourceHint = switch (source) {
      ImportSource.instagram || ImportSource.tiktok => 
        'Detta är från sociala medier. Ignorera hashtags och @-mentions.',
      ImportSource.youtube => 
        'Detta är ett YouTube-transkript. Kan vara lite rörigt.',
      ImportSource.photo => 
        'Detta är OCR-text från en bild. Kan ha felläsningar.',
      _ => '',
    };
    
    return '''
Du är en expert på att extrahera receptinformation från svensk text.
$sourceHint

Svara ENDAST med JSON i detta exakta format (inga andra tecken):
{
  "title": "receptets namn",
  "portions": nummer eller null,
  "ingredients": [
    {"quantity": "mängd som sträng", "unit": "enhet", "name": "ingrediens", "preparation": "tillagning eller null"}
  ],
  "instructions": ["steg 1", "steg 2", ...],
  "totalTimeMinutes": nummer eller null
}

Regler:
- quantity ska vara sträng ("2", "1.5", "1-2")
- unit ska vara förkortning: msk, tsk, dl, ml, g, kg, st, etc.
- Om ingen mängd anges, sätt quantity och unit till null
- instructions ska vara en array av separata steg
- Gissa INTE - om du inte hittar information, använd null

Text att parsa:
---
$text
---
''';
  }

  String _buildPatchPrompt(
    ParsedRecipe existing,
    List<String> fieldsToFix,
    String rawText,
  ) {
    final existingJson = <String, dynamic>{};
    
    if (!fieldsToFix.contains('title') && existing.title.hasValue) {
      existingJson['title'] = existing.title.value;
    }
    if (!fieldsToFix.contains('portions') && existing.portions.hasValue) {
      existingJson['portions'] = existing.portions.value;
    }
    if (!fieldsToFix.contains('ingredients') && existing.ingredients.hasValue) {
      existingJson['ingredients'] = existing.ingredients.value!.map((i) => {
        'quantity': i.quantity,
        'unit': i.unit,
        'name': i.name,
        'preparation': i.preparation,
      }).toList();
    }
    if (!fieldsToFix.contains('instructions') && existing.instructions.hasValue) {
      existingJson['instructions'] = existing.instructions.value;
    }
    if (!fieldsToFix.contains('totalTime') && existing.totalTime.hasValue) {
      existingJson['totalTimeMinutes'] = existing.totalTime.value!.inMinutes;
    }
    
    return '''
Du är en expert på att extrahera receptinformation från svensk text.

Jag har redan parsad viss information men behöver hjälp med: ${fieldsToFix.join(', ')}

Befintlig data (behåll detta):
${jsonEncode(existingJson)}

Komplettera ENDAST de saknade fälten. Svara med JSON som innehåller ALLA fält.

Text att analysera:
---
$rawText
---
''';
  }

  /// P0-2 FIX: Strikt schema-validering med fail-closed.
  ParsedRecipe? _parseResponse(String response, ParsingContext context) {
    try {
      var jsonStr = response.trim();
      
      // Ta bort markdown code blocks
      if (jsonStr.startsWith('```')) {
        jsonStr = jsonStr.replaceFirst(RegExp(r'^```\w*\n?'), '');
        jsonStr = jsonStr.replaceFirst(RegExp(r'\n?```$'), '');
      }
      
      // Hitta JSON-objekt
      if (!jsonStr.startsWith('{')) {
        final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(jsonStr);
        if (jsonMatch == null) return null;
        jsonStr = jsonMatch.group(0)!;
      }
      
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      
      // P0-2: Validera schema FÖRE konvertering
      if (!_isValidRecipeSchema(json)) {
        return null;
      }
      
      return _jsonToRecipe(json, context);
    } catch (_) {
      return null;
    }
  }

  /// P0-2 FIX: Allowlist-baserad schema-validering.
  /// 
  /// Validerar att:
  /// 1. Endast tillåtna nycklar finns
  /// 2. Varje fält har rätt typ
  /// 3. Inga misstänkta värden (injection-försök)
  bool _isValidRecipeSchema(Map<String, dynamic> json) {
    // Allowlist av tillåtna top-level nycklar
    const allowedKeys = {
      'title',
      'portions', 
      'ingredients',
      'instructions',
      'totalTimeMinutes',
    };
    
    // Kolla att inga okända nycklar finns
    for (final key in json.keys) {
      if (!allowedKeys.contains(key)) {
        return false;
      }
    }
    
    // Validera title
    if (json['title'] != null) {
      if (json['title'] is! String) return false;
      if ((json['title'] as String).length > 200) return false;
      if (_containsSuspiciousContent(json['title'] as String)) return false;
    }
    
    // Validera portions
    if (json['portions'] != null) {
      if (json['portions'] is! int && json['portions'] is! double) return false;
      final portions = (json['portions'] as num).toInt();
      if (portions < 1 || portions > 100) return false;
    }
    
    // Validera totalTimeMinutes
    if (json['totalTimeMinutes'] != null) {
      if (json['totalTimeMinutes'] is! int && json['totalTimeMinutes'] is! double) return false;
      final time = (json['totalTimeMinutes'] as num).toInt();
      if (time < 1 || time > 1440) return false; // Max 24h
    }
    
    // Validera ingredients
    if (json['ingredients'] != null) {
      if (json['ingredients'] is! List) return false;
      final ingredients = json['ingredients'] as List;
      if (ingredients.length > 200) return false;
      
      for (final ing in ingredients) {
        if (ing is! Map<String, dynamic>) return false;
        if (!_isValidIngredientSchema(ing)) return false;
      }
    }
    
    // Validera instructions  
    if (json['instructions'] != null) {
      if (json['instructions'] is! List) return false;
      final instructions = json['instructions'] as List;
      if (instructions.length > 100) return false;
      
      for (final inst in instructions) {
        if (inst is! String) return false;
        if (inst.length > 2000) return false;
        if (_containsSuspiciousContent(inst)) return false;
      }
    }
    
    return true;
  }

  /// Validerar ingrediens-schema.
  bool _isValidIngredientSchema(Map<String, dynamic> ing) {
    const allowedIngKeys = {'quantity', 'unit', 'name', 'preparation'};
    
    for (final key in ing.keys) {
      if (!allowedIngKeys.contains(key)) return false;
    }
    
    // name är obligatoriskt
    if (ing['name'] == null) return false;
    if (ing['name'] is! String) return false;
    if ((ing['name'] as String).isEmpty) return false;
    if ((ing['name'] as String).length > 200) return false;
    if (_containsSuspiciousContent(ing['name'] as String)) return false;
    
    // Övriga fält är valfria men måste vara strängar eller null
    for (final key in ['quantity', 'unit', 'preparation']) {
      if (ing[key] != null && ing[key] is! String) return false;
      if (ing[key] is String && (ing[key] as String).length > 100) return false;
    }
    
    return true;
  }

  /// Letar efter misstänkta injection-mönster i text.
  bool _containsSuspiciousContent(String text) {
    final lowerText = text.toLowerCase();
    
    // Mönster som kan indikera injection-försök
    final suspiciousPatterns = [
      RegExp(r'(ignore|disregard|forget).{0,20}(instructions?|above|previous)', caseSensitive: false),
      RegExp(r'(system|assistant|user)\s*:', caseSensitive: false),
      RegExp(r'<\s*(system|prompt|instruction)', caseSensitive: false),
      RegExp(r'\bact\s+as\b', caseSensitive: false),
      RegExp(r'\byou\s+are\s+(now|a)\b', caseSensitive: false),
      RegExp(r'\bpretend\b', caseSensitive: false),
      RegExp(r'\brole\s*play\b', caseSensitive: false),
      RegExp(r'```', caseSensitive: false),
      RegExp(r'\{[\s\S]*"role"', caseSensitive: false),
    ];
    
    for (final pattern in suspiciousPatterns) {
      if (pattern.hasMatch(text)) return true;
    }
    
    // Kolla för homoglyph-attacker (unicode som ser ut som ASCII)
    final normalized = _normalizeUnicode(lowerText);
    if (normalized != lowerText) {
      // Text innehåller homoglyphs - extra suspekt om det innehåller keywords
      if (RegExp(r'ignore|system|user|assistant|instructions?').hasMatch(normalized)) {
        return true;
      }
    }
    
    return false;
  }

  /// Normaliserar unicode homoglyphs till ASCII.
  String _normalizeUnicode(String text) {
    const homoglyphs = {
      'а': 'a', 'е': 'e', 'о': 'o', 'р': 'p', 'с': 'c', 'у': 'y', 'х': 'x', // Cyrillic
      'Α': 'A', 'Β': 'B', 'Ε': 'E', 'Η': 'H', 'Ι': 'I', 'Κ': 'K', 'Μ': 'M', // Greek
      'Ν': 'N', 'Ο': 'O', 'Ρ': 'P', 'Τ': 'T', 'Υ': 'Y', 'Χ': 'X', 'Ζ': 'Z',
      'α': 'a', 'ο': 'o', 'ι': 'i', 'υ': 'u',
      '０': '0', '１': '1', '２': '2', '３': '3', '４': '4', // Fullwidth
      '５': '5', '６': '6', '７': '7', '８': '8', '９': '9',
    };
    
    final buffer = StringBuffer();
    for (final char in text.characters) {
      buffer.write(homoglyphs[char] ?? char);
    }
    return buffer.toString();
  }

  ParsedRecipe? _applyPatch(
    ParsedRecipe existing,
    String response,
    List<String> fieldsToFix,
    ParsingContext context,
  ) {
    try {
      var jsonStr = response.trim();
      if (jsonStr.startsWith('```')) {
        jsonStr = jsonStr.replaceFirst(RegExp(r'^```\w*\n?'), '');
        jsonStr = jsonStr.replaceFirst(RegExp(r'\n?```$'), '');
      }
      
      if (!jsonStr.startsWith('{')) {
        final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(jsonStr);
        if (jsonMatch == null) return null;
        jsonStr = jsonMatch.group(0)!;
      }
      
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      
      // P0-2: Validera även patch-svar
      if (!_isValidRecipeSchema(json)) {
        return null;
      }
      
      final parsed = _jsonToRecipe(json, context);
      
      if (parsed == null) return null;
      
      return existing.copyWith(
        title: fieldsToFix.contains('title') ? parsed.title : null,
        portions: fieldsToFix.contains('portions') ? parsed.portions : null,
        ingredients: fieldsToFix.contains('ingredients') ? parsed.ingredients : null,
        instructions: fieldsToFix.contains('instructions') ? parsed.instructions : null,
        totalTime: fieldsToFix.contains('totalTime') ? parsed.totalTime : null,
      );
    } catch (_) {
      return null;
    }
  }

  ParsedRecipe _jsonToRecipe(Map<String, dynamic> json, ParsingContext context) {
    final ingredientsJson = json['ingredients'] as List?;
    final ingredients = ingredientsJson?.map((i) {
      final map = i as Map<String, dynamic>;
      return ParsedIngredient(
        quantity: map['quantity']?.toString(),
        unit: map['unit']?.toString(),
        name: map['name']?.toString() ?? '',
        preparation: map['preparation']?.toString(),
        originalLine: '',
        confidence: ParseConfidence.high,
      );
    }).where((i) => i.name.isNotEmpty).toList();
    
    final instructionsJson = json['instructions'] as List?;
    final instructions = instructionsJson
        ?.map((i) => i.toString())
        .where((i) => i.isNotEmpty)
        .toList();
    
    final timeMinutes = json['totalTimeMinutes'];
    Duration? totalTime;
    if (timeMinutes is int && timeMinutes > 0) {
      totalTime = Duration(minutes: timeMinutes);
    } else if (timeMinutes is double && timeMinutes > 0) {
      totalTime = Duration(minutes: timeMinutes.round());
    }
    
    return ParsedRecipe(
      title: json['title'] != null
          ? FieldResult.success(json['title'].toString())
          : FieldResult.failed('LLM hittade ingen titel'),
      portions: json['portions'] is int
          ? FieldResult.success(json['portions'] as int)
          : FieldResult.failed('LLM hittade inga portioner'),
      ingredients: ingredients != null && ingredients.isNotEmpty
          ? FieldResult.success(ingredients)
          : FieldResult.failed('LLM hittade inga ingredienser'),
      instructions: instructions != null && instructions.isNotEmpty
          ? FieldResult.success(instructions)
          : FieldResult.failed('LLM hittade inga instruktioner'),
      totalTime: totalTime != null
          ? FieldResult.success(totalTime)
          : FieldResult.failed('LLM hittade ingen tid'),
      metadata: ParseMetadata(
        source: context.source,
        domain: context.domain,
        sourceUrl: context.sourceUrl,
        cacheKey: context.canonicalUrlHash,
        tierResults: [],
        totalParseTime: Duration.zero,
        parserVersion: context.config.parserVersion,
        timestamp: context.clock.now(),
      ),
    );
  }

  double _calculateCost(int inputTokens, int outputTokens) {
    final inputCost = inputTokens / 1000 * _config.llmInputCostPer1kTokens;
    final outputCost = outputTokens / 1000 * _config.llmOutputCostPer1kTokens;
    return (inputCost + outputCost) * _config.sekPerUsd;
  }
}
```

---

## RECIPE MERGER

**lib/services/parsing/common/recipe_merger.dart**
```dart
import '../../../models/parsing/parsed_recipe.dart';
import '../../../models/parsing/parsed_ingredient.dart';
import '../../../models/parsing/field_result.dart';

class RecipeMerger {
  /// Slår ihop två recept, väljer bästa fält från varje
  ParsedRecipe merge(ParsedRecipe? base, ParsedRecipe candidate) {
    if (base == null) return candidate;
    
    return candidate.copyWith(
      title: _bestField(base.title, candidate.title),
      portions: _bestField(base.portions, candidate.portions),
      ingredients: _bestIngredients(base.ingredients, candidate.ingredients),
      instructions: _bestField(base.instructions, candidate.instructions),
      totalTime: _bestField(base.totalTime, candidate.totalTime),
    );
  }

  FieldResult<T> _bestField<T>(FieldResult<T> a, FieldResult<T> b) {
    if (!a.hasValue && !b.hasValue) return b;
    if (!a.hasValue) return b;
    if (!b.hasValue) return a;
    return a.confidenceScore >= b.confidenceScore ? a : b;
  }

  FieldResult<List<ParsedIngredient>> _bestIngredients(
    FieldResult<List<ParsedIngredient>> a,
    FieldResult<List<ParsedIngredient>> b,
  ) {
    if (!a.hasValue && !b.hasValue) return b;
    if (!a.hasValue) return b;
    if (!b.hasValue) return a;
    
    final aList = a.value!;
    final bList = b.value!;
    
    // Räkna strukturerade ingredienser (med quantity/unit)
    final aStructured = aList.where((i) => i.quantity != null || i.unit != null).length;
    final bStructured = bList.where((i) => i.quantity != null || i.unit != null).length;
    
    final aTotal = aList.length;
    final bTotal = bList.length;
    
    final aRatio = aTotal > 0 ? aStructured / aTotal : 0.0;
    final bRatio = bTotal > 0 ? bStructured / bTotal : 0.0;
    
    // Preferera mer strukturerade ingredienser
    if ((bRatio - aRatio).abs() > 0.3) {
      return bRatio > aRatio ? b : a;
    }
    
    // Preferera fler ingredienser
    if ((aTotal - bTotal).abs() > 2) {
      return aTotal > bTotal ? a : b;
    }
    
    return a.confidenceScore >= b.confidenceScore ? a : b;
  }

  /// Returnerar fält som behöver förbättras (under threshold)
  List<String> getFieldsNeedingImprovement(ParsedRecipe recipe, {double threshold = 0.5}) {
    final fields = <String>[];
    if (recipe.title.confidenceScore < threshold) fields.add('title');
    if (recipe.portions.confidenceScore < threshold) fields.add('portions');
    if (recipe.ingredients.confidenceScore < threshold) fields.add('ingredients');
    if (recipe.instructions.confidenceScore < threshold) fields.add('instructions');
    if (recipe.totalTime.confidenceScore < threshold) fields.add('totalTime');
    return fields;
  }
}
```

---

## PARSE EVENT LOGGER

> **SÄKERHETSFIX P1-4**: Skickar INTE tierSummaries, successfulTier, llmCostSek.
> Server kan inte lita på klient-beräknade värden.

**lib/services/parsing/events/parse_event_logger.dart**
```dart
import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import '../../../models/parsing/tier_result.dart';
import '../../../models/parsing/parse_metadata.dart';
import '../../../config/parser_config.dart';
import '../../../core/circuit_breaker.dart';

enum EventFailureType {
  validation,
  network,
  rateLimit,
  circuitOpen,
  unknown,
}

class ParseEventLogger {
  final FirebaseFunctions _functions;
  final ParserConfig _config;
  final CircuitBreaker _circuitBreaker;
  
  final Map<EventFailureType, int> _failureMetrics = {
    EventFailureType.validation: 0,
    EventFailureType.network: 0,
    EventFailureType.rateLimit: 0,
    EventFailureType.circuitOpen: 0,
    EventFailureType.unknown: 0,
  };

  ParseEventLogger({
    required FirebaseFunctions functions,
    required ParserConfig config,
    required CircuitBreaker circuitBreaker,
  }) : _functions = functions,
       _config = config,
       _circuitBreaker = circuitBreaker;

  Future<void> logParseComplete({
    required ImportSource source,
    String? domain,
    String? cacheKey,
    required List<TierResult> tierResults,
    required double finalQuality,
  }) async {
    // P1-4: Skicka ENDAST metadata som server behöver
    // tierSummaries, successfulTier, llmCostSek ignoreras av server
    final data = {
      'source': source.name,
      'domain': domain,
      'cacheKey': cacheKey,
      'finalQuality': finalQuality,
      'parserVersion': _config.parserVersion,
      'tierCount': tierResults.length,
    };
    
    await _sendEvent(data, 'parse_complete');
  }

  Future<void> logCacheHit({
    required ImportSource source,
    String? domain,
  }) async {
    final data = {
      'source': source.name,
      'domain': domain,
      'parserVersion': _config.parserVersion,
    };
    
    await _sendEvent(data, 'cache_hit');
  }

  Future<void> logUserCorrection({
    required ImportSource source,
    String? domain,
    required List<String> correctedFields,
    required double originalQuality,
  }) async {
    final data = {
      'source': source.name,
      'domain': domain,
      'correctedFields': correctedFields,
      'originalQuality': originalQuality,
      'parserVersion': _config.parserVersion,
    };
    
    await _sendEvent(data, 'user_correction');
  }

  Future<void> _sendEvent(Map<String, dynamic> data, String eventType) async {
    // P1-3: Kolla circuit breaker först
    if (!_circuitBreaker.allowRequest) {
      _failureMetrics[EventFailureType.circuitOpen] = 
          (_failureMetrics[EventFailureType.circuitOpen] ?? 0) + 1;
      return;
    }
    
    // Validera storlek
    final json = jsonEncode(data);
    if (json.length > 10000) {
      _failureMetrics[EventFailureType.validation] = 
          (_failureMetrics[EventFailureType.validation] ?? 0) + 1;
      
      FirebaseCrashlytics.instance.log(
        'ParseEvent validation failed: size=${json.length} type=$eventType'
      );
      return;
    }
    
    try {
      await _functions
          .httpsCallable('logParseEvent')
          .call(data);
      
      // P1-3: Registrera success för circuit breaker
      _circuitBreaker.recordSuccess();
    } on FirebaseFunctionsException catch (e, st) {
      final failureType = _classifyError(e.code);
      _failureMetrics[failureType] = (_failureMetrics[failureType] ?? 0) + 1;
      
      // P1-3: Registrera failure för circuit breaker
      _circuitBreaker.recordFailure();
      
      FirebaseCrashlytics.instance.recordError(
        e, 
        st,
        reason: 'parse_event_failed:$eventType:${e.code}',
        fatal: false,
      );
    } catch (e, st) {
      _failureMetrics[EventFailureType.unknown] = 
          (_failureMetrics[EventFailureType.unknown] ?? 0) + 1;
      
      _circuitBreaker.recordFailure();
      
      FirebaseCrashlytics.instance.recordError(
        e, 
        st,
        reason: 'parse_event_failed:$eventType:unknown',
        fatal: false,
      );
    }
  }

  EventFailureType _classifyError(String code) {
    return switch (code) {
      'resource-exhausted' => EventFailureType.rateLimit,
      'invalid-argument' => EventFailureType.validation,
      'unavailable' || 'deadline-exceeded' => EventFailureType.network,
      _ => EventFailureType.unknown,
    };
  }

  /// Exponerar metrics för monitoring.
  Map<String, int> get failureMetrics => Map.unmodifiable(_failureMetrics);
  
  int get totalFailures => _failureMetrics.values.fold(0, (a, b) => a + b);
  
  bool get isCircuitOpen => _circuitBreaker.isOpen;
}
```

---

## RECIPE PARSER SERVICE

> **SÄKERHETSFIX P1-3**: Circuit breaker för cache writes och event logging.
> Förhindrar kaskadfel vid Firestore-outage.

**lib/services/parsing/recipe_parser_service.dart**
```dart
import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import '../../models/parsing/parsed_recipe.dart';
import '../../models/parsing/parse_metadata.dart';
import '../../models/parsing/tier_result.dart';
import '../../config/parser_config.dart';
import '../../core/clock.dart';
import '../../core/circuit_breaker.dart';
import 'tiers/parsing_tier.dart';
import 'tiers/parsing_context.dart';
import 'tiers/llm_tier.dart';
import 'common/recipe_merger.dart';
import 'common/url_canonicalizer.dart';
import 'cache/recipe_cache.dart';
import 'cache/cache_key_generator.dart';
import 'events/parse_event_logger.dart';

class RecipeParserService {
  final List<ParsingTier> _tiers;
  final RecipeMerger _merger;
  final RecipeCache _cache;
  final ParseEventLogger _eventLogger;
  final ParserConfig _config;
  final Clock _clock;
  
  // P1-3: Separata circuit breakers för cache och events
  final CircuitBreaker _cacheCircuitBreaker;
  
  // Metrics
  int _cacheWriteFailures = 0;
  int _cacheWriteSuccesses = 0;
  int _eventWriteFailures = 0;
  int _eventWriteSuccesses = 0;

  RecipeParserService({
    required List<ParsingTier> tiers,
    required RecipeMerger merger,
    required RecipeCache cache,
    required ParseEventLogger eventLogger,
    required ParserConfig config,
    required Clock clock,
    required CircuitBreaker cacheCircuitBreaker,
  }) : _tiers = List.from(tiers)..sort((a, b) => a.priority.compareTo(b.priority)),
       _merger = merger,
       _cache = cache,
       _eventLogger = eventLogger,
       _config = config,
       _clock = clock,
       _cacheCircuitBreaker = cacheCircuitBreaker;

  /// Factory för att skapa service med korrekta circuit breakers.
  factory RecipeParserService.create({
    required List<ParsingTier> tiers,
    required RecipeMerger merger,
    required RecipeCache cache,
    required ParseEventLogger eventLogger,
    required ParserConfig config,
    required Clock clock,
  }) {
    return RecipeParserService(
      tiers: tiers,
      merger: merger,
      cache: cache,
      eventLogger: eventLogger,
      config: config,
      clock: clock,
      cacheCircuitBreaker: CircuitBreaker(
        threshold: config.circuitBreakerThreshold,
        resetTime: config.circuitBreakerResetTime,
        clock: clock,
      ),
    );
  }

  /// Huvudmetod för att parsa recept
  Future<ParsedRecipe> parse({
    required String input,
    required ImportSource source,
    String? sourceUrl,
    bool skipCache = false,
  }) async {
    final totalStopwatch = Stopwatch()..start();
    
    // Validera input
    if (input.isEmpty) {
      throw ParseException('Tom input');
    }
    
    if (input.length > _config.maxInputLength) {
      throw ParseException('Input för stor: ${input.length} > ${_config.maxInputLength}');
    }
    
    // Canonicalisera URL
    String? canonicalUrlHash;
    String? domain;
    if (sourceUrl != null) {
      canonicalUrlHash = UrlCanonicalizer.hashUrl(sourceUrl);
      domain = UrlCanonicalizer.extractDomain(sourceUrl);
    }
    
    // Generera cache key (P0-1: inkluderar content-hash)
    final cacheKey = CacheKeyGenerator.generate(
      input: input,
      source: source,
      parserVersion: _config.parserVersion,
      userId: 'anonymous', // Hanteras av RecipeCache med authState
      canonicalUrlHash: canonicalUrlHash,
    );
    
    // Kolla cache
    if (!skipCache) {
      final cached = await _cache.get(
        input: input,
        source: source,
        canonicalUrlHash: canonicalUrlHash,
        expectedVersion: _config.parserVersion,
      );
      
      if (cached != null) {
        // P1-3: Logga cache hit med circuit breaker
        _logCacheHitAsync(source, domain);
        return cached;
      }
    }
    
    // Skapa context (DOM parsas en gång här)
    final context = ParsingContext.fromInput(
      input: input,
      source: source,
      config: _config,
      clock: _clock,
      sourceUrl: sourceUrl,
    );
    
    final tierResults = <TierResult>[];
    ParsedRecipe? mergedRecipe;
    
    // Kör tiers i prioritetsordning
    for (final tier in _tiers) {
      if (!tier.canHandle(context)) {
        tierResults.add(TierResult.skipped(tierName: tier.name));
        continue;
      }
      
      final result = await tier.parse(context);
      tierResults.add(result);
      
      if (result.success && result.recipe != null) {
        mergedRecipe = _merger.merge(mergedRecipe, result.recipe!);
        
        // Avbryt om kvaliteten är tillräckligt bra
        if (mergedRecipe.overallQuality >= _config.tier2QualityThreshold) {
          break;
        }
      }
    }
    
    // LLM patch om kvalitet för låg
    if (mergedRecipe != null && 
        mergedRecipe.overallQuality < _config.llmTriggerThreshold) {
      final llmTier = _tiers.whereType<LlmTier>().firstOrNull;
      
      if (llmTier != null) {
        final fieldsToFix = _merger.getFieldsNeedingImprovement(mergedRecipe);
        
        // Bara patcha om det finns några fält att fixa (men inte för många)
        if (fieldsToFix.isNotEmpty && fieldsToFix.length < 4) {
          final patchResult = await llmTier.patchFields(
            context: context,
            existingRecipe: mergedRecipe,
            fieldsToFix: fieldsToFix,
          );
          
          tierResults.add(patchResult);
          
          if (patchResult.success && patchResult.recipe != null) {
            mergedRecipe = _merger.merge(mergedRecipe, patchResult.recipe!);
          }
        }
      }
    }
    
    if (mergedRecipe == null) {
      throw ParseException('Kunde inte parsa recept');
    }
    
    // Bygg slutresultat med metadata
    final finalRecipe = mergedRecipe.copyWith(
      metadata: ParseMetadata(
        source: source,
        domain: domain,
        sourceUrl: sourceUrl,
        cacheKey: cacheKey,
        tierResults: tierResults,
        totalParseTime: totalStopwatch.elapsed,
        parserVersion: _config.parserVersion,
        timestamp: _clock.now(),
      ),
    );
    
    // P1-3: Fire-and-forget med circuit breaker
    _writeCacheAsync(input, source, canonicalUrlHash, finalRecipe);
    _logParseCompleteAsync(source, domain, cacheKey, tierResults, finalRecipe.overallQuality);
    
    return finalRecipe;
  }

  /// P1-3: Cache write med circuit breaker.
  void _writeCacheAsync(
    String input,
    ImportSource source,
    String? canonicalUrlHash,
    ParsedRecipe recipe,
  ) {
    if (!_cacheCircuitBreaker.allowRequest) {
      _cacheWriteFailures++;
      return;
    }
    
    unawaited(
      _cache.set(
        input: input,
        source: source,
        canonicalUrlHash: canonicalUrlHash,
        recipe: recipe,
      ).then((_) {
        _cacheWriteSuccesses++;
        _cacheCircuitBreaker.recordSuccess();
      }).catchError((e, st) {
        _cacheWriteFailures++;
        _cacheCircuitBreaker.recordFailure();
        FirebaseCrashlytics.instance.log(
          'Cache write failed: ${e.runtimeType}'
        );
      }),
    );
  }

  /// P1-3: Event logging (circuit breaker hanteras av ParseEventLogger).
  void _logParseCompleteAsync(
    ImportSource source,
    String? domain,
    String cacheKey,
    List<TierResult> tierResults,
    double finalQuality,
  ) {
    unawaited(
      _eventLogger.logParseComplete(
        source: source,
        domain: domain,
        cacheKey: cacheKey,
        tierResults: tierResults,
        finalQuality: finalQuality,
      ).then((_) {
        _eventWriteSuccesses++;
      }).catchError((e, st) {
        _eventWriteFailures++;
      }),
    );
  }

  /// P1-3: Cache hit logging.
  void _logCacheHitAsync(ImportSource source, String? domain) {
    unawaited(
      _eventLogger.logCacheHit(source: source, domain: domain)
        .catchError((e, st) {
          _eventWriteFailures++;
        }),
    );
  }
  
  /// Metrics för monitoring.
  ParserServiceMetrics get metrics => ParserServiceMetrics(
    cacheWriteFailures: _cacheWriteFailures,
    cacheWriteSuccesses: _cacheWriteSuccesses,
    eventWriteFailures: _eventWriteFailures,
    eventWriteSuccesses: _eventWriteSuccesses,
    cacheCircuitOpen: _cacheCircuitBreaker.isOpen,
    eventCircuitOpen: _eventLogger.isCircuitOpen,
    eventFailuresByType: _eventLogger.failureMetrics,
  );
}

class ParserServiceMetrics {
  final int cacheWriteFailures;
  final int cacheWriteSuccesses;
  final int eventWriteFailures;
  final int eventWriteSuccesses;
  final bool cacheCircuitOpen;
  final bool eventCircuitOpen;
  final Map<String, int> eventFailuresByType;
  
  ParserServiceMetrics({
    required this.cacheWriteFailures,
    required this.cacheWriteSuccesses,
    required this.eventWriteFailures,
    required this.eventWriteSuccesses,
    required this.cacheCircuitOpen,
    required this.eventCircuitOpen,
    required this.eventFailuresByType,
  });
  
  double get cacheWriteSuccessRate {
    final total = cacheWriteFailures + cacheWriteSuccesses;
    return total > 0 ? cacheWriteSuccesses / total : 1.0;
  }
  
  double get eventWriteSuccessRate {
    final total = eventWriteFailures + eventWriteSuccesses;
    return total > 0 ? eventWriteSuccesses / total : 1.0;
  }
  
  Map<String, dynamic> toJson() => {
    'cacheWriteFailures': cacheWriteFailures,
    'cacheWriteSuccesses': cacheWriteSuccesses,
    'cacheWriteSuccessRate': cacheWriteSuccessRate,
    'eventWriteFailures': eventWriteFailures,
    'eventWriteSuccesses': eventWriteSuccesses,
    'eventWriteSuccessRate': eventWriteSuccessRate,
    'cacheCircuitOpen': cacheCircuitOpen,
    'eventCircuitOpen': eventCircuitOpen,
    'eventFailuresByType': eventFailuresByType,
  };
}

class ParseException implements Exception {
  final String message;
  ParseException(this.message);
  
  @override
  String toString() => 'ParseException: $message';
}
```
## FIRESTORE SECURITY RULES

**firestore.rules**
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // === HJÄLPFUNKTIONER ===
    
    function isAuthenticated() {
      return request.auth != null;
    }
    
    function isOwner(userId) {
      return isAuthenticated() && request.auth.uid == userId;
    }
    
    function hasAppCheck() {
      return request.auth.token.firebase.app_check == true;
    }
    
    // === SITE CONFIGS (read-only för klienter) ===
    
    match /site_configs/{domain} {
      // Klienten kan läsa site configs
      allow read: if isAuthenticated();
      
      // INGEN write från klient - endast admin/backend
      allow write: if false;
    }
    
    // === USER RECIPE CACHE (via callable endast) ===
    
    match /user_recipe_cache/{cacheKey} {
      // Ingen direkt access - allt via callable functions
      allow read: if false;
      allow write: if false;
    }
    
    // === SHARED RECIPE CACHE (via callable endast) ===
    
    match /shared_recipe_cache/{cacheKey} {
      // Ingen direkt access - allt via callable functions
      // Detta förhindrar att URL:er exponeras
      allow read: if false;
      allow write: if false;
    }
    
    // === PARSE EVENTS (via callable endast) ===
    
    match /parse_events/{eventId} {
      // Ingen direkt access - server skriver via callable
      allow read: if false;
      allow write: if false;
    }
    
    // === CORRECTIONS (via callable endast) ===
    
    match /corrections/{correctionId} {
      // Ingen direkt access
      allow read: if false;
      allow write: if false;
    }
    
    // === RATE LIMITS (intern användning) ===
    
    match /rate_limits/{key} {
      // Endast backend access
      allow read: if false;
      allow write: if false;
    }
    
    // === CATCH-ALL: Neka allt annat ===
    
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

---

## BACKEND UTILITIES

### Rate Limiter

**functions/src/utils/rate-limiter.ts**
```typescript
import * as admin from 'firebase-admin';

export interface RateLimitConfig {
  maxRequests: number;
  windowMs: number;
  maxStoredTimestamps?: number;
}

export interface RateLimitResult {
  allowed: boolean;
  remaining: number;
  resetAt: Date;
}

const db = admin.firestore();

/**
 * Sliding window rate limiter med Firestore.
 * 
 * Begränsar antal requests per nyckel inom ett tidsfönster.
 * Använder transactions för att hantera concurrent requests.
 */
export async function checkRateLimit(
  key: string,
  config: RateLimitConfig
): Promise<RateLimitResult> {
  const { maxRequests, windowMs, maxStoredTimestamps = 1000 } = config;
  const now = Date.now();
  const windowStart = now - windowMs;
  
  const docRef = db.collection('rate_limits').doc(key);
  
  return db.runTransaction(async (transaction) => {
    const doc = await transaction.get(docRef);
    
    let timestamps: number[] = [];
    
    if (doc.exists) {
      const data = doc.data();
      timestamps = (data?.timestamps || []) as number[];
    }
    
    // Filtrera bort gamla timestamps
    timestamps = timestamps.filter((ts) => ts > windowStart);
    
    // Begränsa antal sparade timestamps för att undvika unbounded growth
    if (timestamps.length > maxStoredTimestamps) {
      timestamps = timestamps.slice(-maxStoredTimestamps);
    }
    
    const requestsInWindow = timestamps.length;
    const allowed = requestsInWindow < maxRequests;
    
    if (allowed) {
      timestamps.push(now);
      transaction.set(docRef, {
        timestamps,
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    
    // Beräkna när fönstret resetas
    const oldestTimestamp = timestamps.length > 0 ? timestamps[0] : now;
    const resetAt = new Date(oldestTimestamp + windowMs);
    
    return {
      allowed,
      remaining: Math.max(0, maxRequests - timestamps.length),
      resetAt,
    };
  });
}

/**
 * Rensa gamla rate limit dokument (scheduled job).
 */
export async function cleanupRateLimits(maxAgeMs: number = 24 * 60 * 60 * 1000): Promise<number> {
  const cutoff = new Date(Date.now() - maxAgeMs);
  
  const oldDocs = await db
    .collection('rate_limits')
    .where('lastUpdated', '<', cutoff)
    .limit(500)
    .get();
  
  const batch = db.batch();
  oldDocs.docs.forEach((doc) => batch.delete(doc.ref));
  await batch.commit();
  
  return oldDocs.size;
}
```

### Fetch With Limits

**functions/src/utils/fetch-with-limits.ts**
```typescript
export interface FetchConfig {
  timeoutMs: number;
  maxBytes: number;
  allowedContentTypes?: string[];
}

export interface FetchResult {
  ok: boolean;
  status?: number;
  contentType?: string;
  body?: string;
  error?: string;
  truncated?: boolean;
}

/**
 * Fetch med timeout och storleksbegränsning.
 * 
 * Skyddar mot:
 * - Slow loris (timeout)
 * - Stora responses (maxBytes)
 * - Oväntade content types
 */
export async function fetchWithLimits(
  url: string,
  config: FetchConfig
): Promise<FetchResult> {
  const { timeoutMs, maxBytes, allowedContentTypes } = config;
  
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), timeoutMs);
  
  try {
    const response = await fetch(url, {
      signal: controller.signal,
      headers: {
        'User-Agent': 'Butlery/1.0 (Recipe Parser)',
        'Accept': 'text/html,application/xhtml+xml',
      },
      redirect: 'follow',
    });
    
    clearTimeout(timeoutId);
    
    if (!response.ok) {
      return {
        ok: false,
        status: response.status,
        error: `HTTP ${response.status}`,
      };
    }
    
    const contentType = response.headers.get('content-type') || '';
    
    // Validera content type
    if (allowedContentTypes && allowedContentTypes.length > 0) {
      const isAllowed = allowedContentTypes.some((allowed) =>
        contentType.toLowerCase().includes(allowed.toLowerCase())
      );
      
      if (!isAllowed) {
        return {
          ok: false,
          contentType,
          error: `Disallowed content type: ${contentType}`,
        };
      }
    }
    
    // Läs body med storleksbegränsning
    const reader = response.body?.getReader();
    if (!reader) {
      return {
        ok: false,
        error: 'No response body',
      };
    }
    
    const chunks: Uint8Array[] = [];
    let totalBytes = 0;
    let truncated = false;
    
    while (true) {
      const { done, value } = await reader.read();
      
      if (done) break;
      
      if (totalBytes + value.length > maxBytes) {
        // Trunkera
        const remaining = maxBytes - totalBytes;
        if (remaining > 0) {
          chunks.push(value.slice(0, remaining));
        }
        truncated = true;
        reader.cancel();
        break;
      }
      
      chunks.push(value);
      totalBytes += value.length;
    }
    
    // Konvertera till string
    const decoder = new TextDecoder('utf-8', { fatal: false });
    const body = chunks.map((chunk) => decoder.decode(chunk, { stream: true })).join('');
    
    return {
      ok: true,
      status: response.status,
      contentType,
      body,
      truncated,
    };
  } catch (error: any) {
    clearTimeout(timeoutId);
    
    if (error.name === 'AbortError') {
      return {
        ok: false,
        error: 'Request timeout',
      };
    }
    
    return {
      ok: false,
      error: error.message || 'Unknown fetch error',
    };
  }
}
```

### URL Canonicalizer (TypeScript)

**functions/src/utils/url-canonicalizer.ts**
```typescript
import * as crypto from 'crypto';

const TRACKING_PARAMS = new Set([
  'utm_source', 'utm_medium', 'utm_campaign', 'utm_term', 'utm_content',
  'fbclid', 'gclid', 'msclkid', 'dclid',
  'ref', 'source', 'mc_cid', 'mc_eid',
  '_ga', '_gl', 'yclid', 'zanpid',
  'affiliate', 'partner', 'clickid',
]);

/**
 * Canonicaliserar URL genom att ta bort tracking params.
 */
export function canonicalizeUrl(url: string): string {
  try {
    const parsed = new URL(url);
    
    // Ta bort tracking params
    const params = new URLSearchParams(parsed.search);
    for (const key of Array.from(params.keys())) {
      if (TRACKING_PARAMS.has(key.toLowerCase())) {
        params.delete(key);
      }
    }
    
    // Normalisera
    parsed.search = params.toString();
    parsed.hash = ''; // Ta bort fragment
    parsed.hostname = parsed.hostname.toLowerCase();
    
    // Ta bort trailing slash (om inte root)
    if (parsed.pathname.length > 1 && parsed.pathname.endsWith('/')) {
      parsed.pathname = parsed.pathname.slice(0, -1);
    }
    
    return parsed.toString();
  } catch {
    return url;
  }
}

/**
 * Hashar canonical URL.
 */
export function hashUrl(url: string): string {
  const canonical = canonicalizeUrl(url);
  return crypto.createHash('sha256').update(canonical).digest('hex').substring(0, 32);
}

/**
 * Extraherar domain från URL.
 */
export function extractDomain(url: string): string | null {
  try {
    const parsed = new URL(url);
    let host = parsed.hostname.toLowerCase();
    if (host.startsWith('www.')) {
      host = host.substring(4);
    }
    return host || null;
  } catch {
    return null;
  }
}
```

---

## CLOUD FUNCTIONS

### Log Parse Event

> **SÄKERHETSFIX P1-4**: Server ignorerar tierSummaries, successfulTier, llmCostSek från klienten.

**functions/src/events/log-parse-event.ts**
```typescript
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { checkRateLimit } from '../utils/rate-limiter';

const db = admin.firestore();

interface ParseEventData {
  source: string;
  domain?: string;
  cacheKey?: string;
  finalQuality?: number;
  parserVersion?: string;
  tierCount?: number;
  correctedFields?: string[];
  originalQuality?: number;
}

interface ValidationResult {
  valid: boolean;
  data?: Record<string, any>;
  error?: string;
}

/**
 * P1-4 FIX: Validerar event-data och IGNORERAR opålitliga fält.
 * 
 * Klienten kan manipulera:
 * - tierSummaries (kan ljuga om vilka tiers som kördes)
 * - successfulTier (kan fejka framgång)
 * - llmCostSek (kan dölja kostnader)
 * 
 * Dessa fält accepteras INTE från klienten.
 */
function validateParseEvent(data: any): ValidationResult {
  if (!data || typeof data !== 'object') {
    return { valid: false, error: 'Invalid data' };
  }
  
  const { source, domain, cacheKey, finalQuality, parserVersion, tierCount,
          correctedFields, originalQuality } = data;
  
  // Validera source
  const validSources = ['url', 'text', 'instagram', 'tiktok', 'youtube', 'photo', 'file'];
  if (!source || !validSources.includes(source)) {
    return { valid: false, error: 'Invalid source' };
  }
  
  // Validera domain (valfritt, max 100 chars)
  if (domain !== undefined && domain !== null) {
    if (typeof domain !== 'string' || domain.length > 100) {
      return { valid: false, error: 'Invalid domain' };
    }
  }
  
  // Validera cacheKey (valfritt, max 64 chars)
  if (cacheKey !== undefined && cacheKey !== null) {
    if (typeof cacheKey !== 'string' || cacheKey.length > 64) {
      return { valid: false, error: 'Invalid cacheKey' };
    }
  }
  
  // Validera finalQuality (valfritt, 0-1)
  if (finalQuality !== undefined && finalQuality !== null) {
    if (typeof finalQuality !== 'number' || finalQuality < 0 || finalQuality > 1) {
      return { valid: false, error: 'Invalid finalQuality' };
    }
  }
  
  // Validera parserVersion (valfritt, max 20 chars)
  if (parserVersion !== undefined && parserVersion !== null) {
    if (typeof parserVersion !== 'string' || parserVersion.length > 20) {
      return { valid: false, error: 'Invalid parserVersion' };
    }
  }
  
  // Validera tierCount (valfritt)
  if (tierCount !== undefined && tierCount !== null) {
    if (typeof tierCount !== 'number' || tierCount < 0 || tierCount > 10) {
      return { valid: false, error: 'Invalid tierCount' };
    }
  }
  
  // Validera correctedFields (valfritt)
  if (correctedFields !== undefined && correctedFields !== null) {
    if (!Array.isArray(correctedFields) || correctedFields.length > 10) {
      return { valid: false, error: 'Invalid correctedFields' };
    }
    const validFields = ['title', 'portions', 'ingredients', 'instructions', 'totalTime'];
    for (const field of correctedFields) {
      if (typeof field !== 'string' || !validFields.includes(field)) {
        return { valid: false, error: 'Invalid field in correctedFields' };
      }
    }
  }
  
  // Returnera ENDAST betrodda fält
  // P1-4: tierSummaries, successfulTier, llmCostSek IGNORERAS helt
  return {
    valid: true,
    data: {
      source,
      domain: domain?.substring(0, 100),
      cacheKey: cacheKey?.substring(0, 64),
      finalQuality,
      parserVersion: parserVersion?.substring(0, 20),
      tierCount,
      correctedFields,
      originalQuality,
      // NOTERA: Följande fält från klienten ignoreras:
      // - tierSummaries (kan manipuleras)
      // - successfulTier (kan ljuga)
      // - llmCostSek (kan dölja kostnader)
    },
  };
}

export const logParseEvent = functions.https.onCall(async (data, context) => {
  // Kräv autentisering
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }
  
  // App Check (om aktiverat)
  if (context.app === undefined) {
    // App Check ej konfigurerat - logga men tillåt
    functions.logger.warn('App Check not enforced', { uid: context.auth.uid });
  }
  
  const userId = context.auth.uid;
  
  // Rate limiting: 100 requests per minut per user
  const rateLimitResult = await checkRateLimit(`parse_event:${userId}`, {
    maxRequests: 100,
    windowMs: 60 * 1000,
  });
  
  if (!rateLimitResult.allowed) {
    throw new functions.https.HttpsError(
      'resource-exhausted',
      'Rate limit exceeded',
      { resetAt: rateLimitResult.resetAt.toISOString() }
    );
  }
  
  // Validera data (P1-4: ignorerar opålitliga fält)
  const validation = validateParseEvent(data);
  
  if (!validation.valid) {
    throw new functions.https.HttpsError('invalid-argument', validation.error || 'Validation failed');
  }
  
  // Spara event
  const eventData = {
    ...validation.data,
    userId,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    clientIp: context.rawRequest?.ip || null,
  };
  
  await db.collection('parse_events').add(eventData);
  
  return { success: true };
});
```

### Submit Correction

**functions/src/corrections/submit-correction.ts**
```typescript
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { checkRateLimit } from '../utils/rate-limiter';

const db = admin.firestore();

interface CorrectionData {
  recipeId?: string;
  cacheKey?: string;
  field: string;
  originalValue: any;
  correctedValue: any;
  source?: string;
  domain?: string;
}

function validateCorrection(data: any): { valid: boolean; error?: string } {
  if (!data || typeof data !== 'object') {
    return { valid: false, error: 'Invalid data' };
  }
  
  const { field, originalValue, correctedValue } = data;
  
  // Validera field
  const validFields = ['title', 'portions', 'ingredients', 'instructions', 'totalTime'];
  if (!field || !validFields.includes(field)) {
    return { valid: false, error: 'Invalid field' };
  }
  
  // Kräv både original och corrected
  if (originalValue === undefined || correctedValue === undefined) {
    return { valid: false, error: 'Missing values' };
  }
  
  // Storleksbegränsning
  const originalJson = JSON.stringify(originalValue);
  const correctedJson = JSON.stringify(correctedValue);
  
  if (originalJson.length > 50000 || correctedJson.length > 50000) {
    return { valid: false, error: 'Values too large' };
  }
  
  return { valid: true };
}

export const submitCorrection = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }
  
  const userId = context.auth.uid;
  
  // Rate limiting: 20 corrections per timme
  const rateLimitResult = await checkRateLimit(`correction:${userId}`, {
    maxRequests: 20,
    windowMs: 60 * 60 * 1000,
  });
  
  if (!rateLimitResult.allowed) {
    throw new functions.https.HttpsError(
      'resource-exhausted',
      'Rate limit exceeded'
    );
  }
  
  const validation = validateCorrection(data);
  if (!validation.valid) {
    throw new functions.https.HttpsError('invalid-argument', validation.error || 'Validation failed');
  }
  
  const correctionData = {
    userId,
    recipeId: data.recipeId?.substring(0, 100) || null,
    cacheKey: data.cacheKey?.substring(0, 64) || null,
    field: data.field,
    originalValue: data.originalValue,
    correctedValue: data.correctedValue,
    source: data.source?.substring(0, 20) || null,
    domain: data.domain?.substring(0, 100) || null,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    status: 'pending',
  };
  
  const docRef = await db.collection('corrections').add(correctionData);
  
  return { success: true, correctionId: docRef.id };
});
```

### Shared Cache

**functions/src/cache/shared-cache.ts**
```typescript
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { checkRateLimit } from '../utils/rate-limiter';
import { fetchWithLimits } from '../utils/fetch-with-limits';
import { canonicalizeUrl, hashUrl, extractDomain } from '../utils/url-canonicalizer';

const db = admin.firestore();

interface SharedCacheEntry {
  recipe: any;
  domain: string;
  fetchedAt: admin.firestore.Timestamp;
  expiresAt: admin.firestore.Timestamp;
  parserVersion: string;
  quality: number;
}

/**
 * Hämtar cached recept.
 * 
 * VIKTIGT: Returnerar ALDRIG källans URL - endast receptdata.
 * Detta skyddar mot att användare kan se vilka URLs andra användare parsade.
 */
export const getSharedCache = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }
  
  const { cacheKey } = data;
  
  if (!cacheKey || typeof cacheKey !== 'string' || cacheKey.length > 64) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid cache key');
  }
  
  const doc = await db.collection('shared_recipe_cache').doc(cacheKey).get();
  
  if (!doc.exists) {
    return { found: false };
  }
  
  const entry = doc.data() as SharedCacheEntry;
  
  // Kolla expiry
  if (entry.expiresAt.toDate() < new Date()) {
    return { found: false };
  }
  
  // Returnera recept (UTAN URL)
  return {
    found: true,
    recipe: entry.recipe,
    quality: entry.quality,
    parserVersion: entry.parserVersion,
  };
});

/**
 * Begär att server hämtar och parsar en URL.
 * 
 * Server gör fetch och parsing - klienten får bara receptdata.
 * Detta möjliggör:
 * 1. Server-side caching utan att exponera URLs
 * 2. Server-side parsing med bättre säkerhet
 * 3. Rate limiting på server-nivå
 */
export const requestSharedCache = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }
  
  const userId = context.auth.uid;
  const { url } = data;
  
  if (!url || typeof url !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid URL');
  }
  
  // Validera URL
  let parsedUrl: URL;
  try {
    parsedUrl = new URL(url);
    if (!['http:', 'https:'].includes(parsedUrl.protocol)) {
      throw new Error('Invalid protocol');
    }
  } catch {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid URL format');
  }
  
  // Rate limiting: 30 requests per minut
  const rateLimitResult = await checkRateLimit(`shared_cache:${userId}`, {
    maxRequests: 30,
    windowMs: 60 * 1000,
  });
  
  if (!rateLimitResult.allowed) {
    throw new functions.https.HttpsError('resource-exhausted', 'Rate limit exceeded');
  }
  
  const cacheKey = hashUrl(url);
  const domain = extractDomain(url);
  
  // Kolla cache först
  const existingDoc = await db.collection('shared_recipe_cache').doc(cacheKey).get();
  
  if (existingDoc.exists) {
    const entry = existingDoc.data() as SharedCacheEntry;
    if (entry.expiresAt.toDate() > new Date()) {
      return {
        found: true,
        recipe: entry.recipe,
        quality: entry.quality,
        cached: true,
      };
    }
  }
  
  // Fetch URL
  const fetchResult = await fetchWithLimits(url, {
    timeoutMs: 15000,
    maxBytes: 2 * 1024 * 1024, // 2MB
    allowedContentTypes: ['text/html', 'application/xhtml'],
  });
  
  if (!fetchResult.ok || !fetchResult.body) {
    throw new functions.https.HttpsError('unavailable', fetchResult.error || 'Fetch failed');
  }
  
  // Parsa Schema.org på server
  const recipe = extractSchemaOrgRecipe(fetchResult.body);
  
  if (!recipe) {
    throw new functions.https.HttpsError('not-found', 'No recipe found');
  }
  
  // Beräkna kvalitet (förenklad)
  const quality = calculateQuality(recipe);
  
  // Spara i cache
  const expiresAt = new Date();
  expiresAt.setDate(expiresAt.getDate() + 90); // 90 dagar
  
  await db.collection('shared_recipe_cache').doc(cacheKey).set({
    recipe,
    domain,
    quality,
    fetchedAt: admin.firestore.FieldValue.serverTimestamp(),
    expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
    parserVersion: '3.4.0',
  });
  
  return {
    found: true,
    recipe,
    quality,
    cached: false,
  };
});

/**
 * Scheduled cleanup av expired cache entries.
 */
export const cleanExpiredSharedCache = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async () => {
    const now = admin.firestore.Timestamp.now();
    
    const expired = await db
      .collection('shared_recipe_cache')
      .where('expiresAt', '<', now)
      .limit(500)
      .get();
    
    const batch = db.batch();
    expired.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
    
    functions.logger.info(`Cleaned ${expired.size} expired cache entries`);
  });

/**
 * Extraherar Schema.org Recipe från HTML.
 */
function extractSchemaOrgRecipe(html: string): any | null {
  // Hitta JSON-LD scripts
  const jsonLdRegex = /<script[^>]*type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi;
  let match;
  
  while ((match = jsonLdRegex.exec(html)) !== null) {
    try {
      const json = JSON.parse(match[1]);
      const recipe = findRecipeInJson(json);
      if (recipe) {
        return sanitizeRecipe(recipe);
      }
    } catch {
      continue;
    }
  }
  
  return null;
}

function findRecipeInJson(json: any): any | null {
  if (!json) return null;
  
  if (typeof json === 'object') {
    const type = json['@type'];
    if (type === 'Recipe' || (Array.isArray(type) && type.includes('Recipe'))) {
      return json;
    }
    
    if (json['@graph'] && Array.isArray(json['@graph'])) {
      for (const item of json['@graph']) {
        const found = findRecipeInJson(item);
        if (found) return found;
      }
    }
    
    for (const value of Object.values(json)) {
      if (typeof value === 'object') {
        const found = findRecipeInJson(value);
        if (found) return found;
      }
    }
  }
  
  if (Array.isArray(json)) {
    for (const item of json) {
      const found = findRecipeInJson(item);
      if (found) return found;
    }
  }
  
  return null;
}

function sanitizeRecipe(recipe: any): any {
  // Ta bara med säkra fält
  return {
    name: typeof recipe.name === 'string' ? recipe.name.substring(0, 200) : null,
    recipeYield: recipe.recipeYield,
    recipeIngredient: Array.isArray(recipe.recipeIngredient) 
      ? recipe.recipeIngredient.slice(0, 200).map((i: any) => 
          typeof i === 'string' ? i.substring(0, 500) : null
        ).filter(Boolean)
      : null,
    recipeInstructions: sanitizeInstructions(recipe.recipeInstructions),
    totalTime: recipe.totalTime,
    prepTime: recipe.prepTime,
    cookTime: recipe.cookTime,
  };
}

function sanitizeInstructions(instructions: any): string[] | null {
  if (!instructions) return null;
  
  const result: string[] = [];
  
  if (typeof instructions === 'string') {
    return [instructions.substring(0, 2000)];
  }
  
  if (Array.isArray(instructions)) {
    for (const item of instructions.slice(0, 100)) {
      if (typeof item === 'string') {
        result.push(item.substring(0, 2000));
      } else if (typeof item === 'object') {
        const text = item.text || item.name;
        if (typeof text === 'string') {
          result.push(text.substring(0, 2000));
        }
      }
    }
  }
  
  return result.length > 0 ? result : null;
}

function calculateQuality(recipe: any): number {
  let score = 0;
  let maxScore = 0;
  
  if (recipe.name) { score += 1; } maxScore += 1;
  if (recipe.recipeIngredient?.length > 0) { score += 3; } maxScore += 3;
  if (recipe.recipeInstructions?.length > 0) { score += 2; } maxScore += 2;
  if (recipe.recipeYield) { score += 0.5; } maxScore += 0.5;
  if (recipe.totalTime || recipe.prepTime || recipe.cookTime) { score += 0.5; } maxScore += 0.5;
  
  return score / maxScore;
}
```

### Index

**functions/src/index.ts**
```typescript
import * as admin from 'firebase-admin';

admin.initializeApp();

// Events
export { logParseEvent } from './events/log-parse-event';

// Corrections
export { submitCorrection } from './corrections/submit-correction';

// Shared Cache
export { 
  getSharedCache, 
  requestSharedCache, 
  cleanExpiredSharedCache 
} from './cache/shared-cache';
```

---

## IMPLEMENTATION CHECKLIST

### Flutter-filer (lib/)

| Fil | Skapad | Testad |
|-----|--------|--------|
| config/parser_config.dart | ☐ | ☐ |
| core/auth_state.dart | ☐ | ☐ |
| core/clock.dart | ☐ | ☐ |
| core/circuit_breaker.dart | ☐ | ☐ |
| models/parsing/field_result.dart | ☐ | ☐ |
| models/parsing/tier_result.dart | ☐ | ☐ |
| models/parsing/parsed_ingredient.dart | ☐ | ☐ |
| models/parsing/parse_metadata.dart | ☐ | ☐ |
| models/parsing/parsed_recipe.dart | ☐ | ☐ |
| models/parsing/site_config.dart | ☐ | ☐ |
| repositories/site_config_repository.dart | ☐ | ☐ |
| services/llm/llm_service.dart | ☐ | ☐ |
| services/parsing/cache/cache_key_generator.dart | ☐ | ☐ |
| services/parsing/cache/recipe_cache.dart | ☐ | ☐ |
| services/parsing/common/url_canonicalizer.dart | ☐ | ☐ |
| services/parsing/common/recipe_merger.dart | ☐ | ☐ |
| services/parsing/events/parse_event_logger.dart | ☐ | ☐ |
| services/parsing/parsers/parsing_utils.dart | ☐ | ☐ |
| services/parsing/parsers/swedish_ingredient_parser.dart | ☐ | ☐ |
| services/parsing/parsers/swedish_line_classifier.dart | ☐ | ☐ |
| services/parsing/sanitizers/html_sanitizer.dart | ☐ | ☐ |
| services/parsing/tiers/parsing_tier.dart | ☐ | ☐ |
| services/parsing/tiers/parsing_context.dart | ☐ | ☐ |
| services/parsing/tiers/schema_org_tier.dart | ☐ | ☐ |
| services/parsing/tiers/site_config_tier.dart | ☐ | ☐ |
| services/parsing/tiers/rule_based_tier.dart | ☐ | ☐ |
| services/parsing/tiers/llm_tier.dart | ☐ | ☐ |
| services/parsing/recipe_parser_service.dart | ☐ | ☐ |

### Backend-filer (functions/)

| Fil | Skapad | Deployad |
|-----|--------|----------|
| src/utils/rate-limiter.ts | ☐ | ☐ |
| src/utils/fetch-with-limits.ts | ☐ | ☐ |
| src/utils/url-canonicalizer.ts | ☐ | ☐ |
| src/events/log-parse-event.ts | ☐ | ☐ |
| src/corrections/submit-correction.ts | ☐ | ☐ |
| src/cache/shared-cache.ts | ☐ | ☐ |
| src/index.ts | ☐ | ☐ |
| firestore.rules | ☐ | ☐ |

### Säkerhetsfixar

| Fix | Beskrivning | Implementerad | Verifierad |
|-----|-------------|---------------|------------|
| P0-1 | Cache key inkluderar content-hash | ☐ | ☐ |
| P0-2 | LLM schema-validering med allowlist | ☐ | ☐ |
| P1-3 | Circuit breaker för async writes | ☐ | ☐ |
| P1-4 | Server ignorerar klient tierSummaries | ☐ | ☐ |

---

## SLUT PÅ SPECIFIKATION v3.4
