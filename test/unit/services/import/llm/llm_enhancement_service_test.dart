/// Intent tests for [LlmEnhancementService].
///
/// What this file proves (one bullet per behaviour, in order of group):
/// - canEnhance gate: a partial result without enough data must NOT spend an
///   LLM call — it should fail fast with parsingFailed, no rate-limit check,
///   no LlmService invocation.
/// - Rate-limit gate: when the limiter denies, the service must short-circuit
///   to `ImportFailure.rateLimited` carrying the limiter's retryAfter and
///   swedishMessage — LlmService must NOT be called.
/// - Happy path (enhance): on a successful LlmService response, the returned
///   ImportSuccess carries the *next* tier (partial.tier + 1), the documented
///   confidence (0.85), `usedLlm = true`, `requiresReview = true`, and the
///   metadata block with originalConfidence/missingFields/llmCost.
/// - Meal-type inference: tags from the LLM are routed to the correct
///   mealType ("frukost"→breakfast, "middag"→dinner, "dessert"→dessert,
///   "mellanmål"→snack, no-match→dinner default).
/// - Default portions: when LLM returns `portions: null`, the recipe gets
///   `ParsingTier.kDefaultPortions` (4) — not 0, not null-then-crash.
/// - LlmException → ImportFailure: rate-limited LlmException maps to
///   `llmQuotaExceeded`, others to `parsingFailed`, retryAfter is preserved.
/// - Non-LlmException error path: unexpected throws are caught and surfaced
///   as `ImportErrorCode.unknown` with `technicalDetails` populated (the bug
///   class where errors silently disappear).
/// - LlmService says `success: false`: returns ImportFailure carrying the
///   server-provided error message, NOT a fabricated success with empty
///   recipe.
/// - `extractFromImage` happy path → ImportSuccess(tier=4, pipeline='photo').
/// - `extractFromImage` raw-text-only response → ImportNeedsAssistance with
///   the raw text and the original image bytes preserved.
/// - `extractFromImage` neither success nor rawText → ImportFailure with
///   ocrFailed code.
/// - `extractFromHtml` happy path → ImportSuccess with currentTier+1.
/// - `extractFromTranscript` falls back to ImportNeedsAssistance (NOT
///   ImportFailure) when LLM yields no recipe — videoTitle becomes the
///   suggested title.
/// - `isAvailable` is a pure passthrough to LlmService.isAvailable.
///
/// Mocking strategy: configurable `Fake` implementations of `LlmService` and
/// `ImportRateLimiter`. We never mock the subject. The fakes record their
/// invocations so each test can assert what was/wasn't called.
library;

import 'dart:typed_data';

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/import/llm/llm_enhancement_service.dart';
import 'package:butlery/services/import/import_rate_limiter.dart';
import 'package:butlery/services/import/models/import_result_v2.dart';
import 'package:butlery/services/import/models/rate_limit_models.dart';
import 'package:butlery/services/llm/llm_models.dart';
import 'package:butlery/services/llm/llm_service.dart';
import 'package:butlery/services/parsing/tiers/parsing_tier.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeRateLimiter extends Fake implements ImportRateLimiter {
  RateLimitResult result = const RateLimitAllowed(
    remainingInWindow: 999,
    limitType: LimitType.perMinute,
  );
  final List<ImportOperation> seenOperations = [];

  @override
  Future<RateLimitResult> checkLimit(ImportOperation operation) async {
    seenOperations.add(operation);
    return result;
  }
}

class _FakeLlmService extends Fake implements LlmService {
  // Configurable responses per method.
  StructureRecipeResponse? structureResponse;
  Object? structureThrow;
  int structureCalls = 0;
  StructureRecipeRequest? lastStructureRequest;
  // Capture per-arg detail
  String? lastStructureText;
  StructureMode? lastStructureMode;
  Map<String, dynamic>? lastStructurePartialData;
  String? lastStructureSourceUrl;

  OcrRecipeImageResponse? ocrResponse;
  Object? ocrThrow;
  int ocrCalls = 0;
  Uint8List? lastOcrBytes;
  String? lastOcrContext;

  bool isAvailableValue = true;
  int isAvailableCalls = 0;

  @override
  Future<StructureRecipeResponse> structureRecipe({
    required String text,
    StructureMode mode = StructureMode.extract,
    Map<String, dynamic>? partialData,
    String? sourceUrl,
  }) async {
    structureCalls++;
    lastStructureText = text;
    lastStructureMode = mode;
    lastStructurePartialData = partialData;
    lastStructureSourceUrl = sourceUrl;
    if (structureThrow != null) throw structureThrow!;
    return structureResponse ??
        const StructureRecipeResponse(success: false, estimatedCost: 0.0);
  }

  @override
  Future<OcrRecipeImageResponse> ocrRecipeImage({
    Uint8List? imageBytes,
    String? imageUrl,
    String? mimeType,
    String? context,
  }) async {
    ocrCalls++;
    lastOcrBytes = imageBytes;
    lastOcrContext = context;
    if (ocrThrow != null) throw ocrThrow!;
    return ocrResponse ??
        const OcrRecipeImageResponse(success: false, estimatedCost: 0.0);
  }

  @override
  Future<bool> isAvailable() async {
    isAvailableCalls++;
    return isAvailableValue;
  }
}

// ---------------------------------------------------------------------------
// Builders
// ---------------------------------------------------------------------------

ExtractedRecipe _extracted({
  String title = 'Pasta Carbonara',
  String? description = 'Klassisk italiensk',
  int? portions = 4,
  int? prepTime,
  int? cookTime,
  List<ExtractedIngredient>? ingredients,
  List<String>? instructions,
  List<String>? tags,
  String? source,
}) {
  return ExtractedRecipe(
    title: title,
    description: description,
    portions: portions,
    prepTimeMinutes: prepTime,
    cookTimeMinutes: cookTime,
    ingredients:
        ingredients ??
        const [
          ExtractedIngredient(amount: 200, unit: 'g', name: 'spaghetti'),
          ExtractedIngredient(amount: 100, unit: 'g', name: 'pancetta'),
        ],
    instructions: instructions ?? const ['Koka pasta.', 'Stek pancetta.'],
    tags: tags ?? const [],
    source: source,
  );
}

ImportPartial _partial({
  Map<String, dynamic>? partialData,
  String? extractedText = 'Pasta carbonara with eggs and pancetta',
  String? rawHtml,
  double confidence = 0.6,
  String pipeline = 'website',
  int tier = 2,
  List<String> missingFields = const ['portions', 'timeMinutes'],
}) {
  return ImportPartial(
    partialData: partialData ?? const {'title': 'Pasta carbonara'},
    extractedText: extractedText,
    rawHtml: rawHtml,
    confidence: confidence,
    pipeline: pipeline,
    tier: tier,
    missingFields: missingFields,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late _FakeLlmService llm;
  late _FakeRateLimiter limiter;
  late LlmEnhancementService service;

  setUp(() {
    llm = _FakeLlmService();
    limiter = _FakeRateLimiter();
    service = LlmEnhancementService(llmService: llm, rateLimiter: limiter);
  });

  group('enhance — canEnhance gate', () {
    /// A partial result with no extracted text AND no rawHtml fails the
    /// canEnhance contract. We must reject WITHOUT consuming a rate-limit
    /// slot or an LLM call — silently spending budget here is the exact
    /// kind of regression this test exists to catch.
    test(
      'rejects fast when partial.canEnhance is false (no text and no html)',
      () async {
        final partial = _partial(
          partialData: const {'title': 'x'},
          extractedText: null,
          rawHtml: null,
        );
        expect(
          partial.canEnhance,
          isFalse,
          reason: 'precondition: partial must not be enhanceable',
        );

        final result = await service.enhance(partial);

        expect(result, isA<ImportFailure>());
        expect(
          (result as ImportFailure).errorCode,
          ImportErrorCode.parsingFailed,
        );
        expect(result.pipeline, partial.pipeline);
        expect(result.tier, partial.tier);
        expect(
          limiter.seenOperations,
          isEmpty,
          reason: 'rate-limit slot must NOT be consumed for invalid input',
        );
        expect(
          llm.structureCalls,
          0,
          reason: 'LLM must NOT be invoked when canEnhance is false',
        );
      },
    );

    /// A partial with confidence below the canEnhance floor (0.3) is also
    /// rejected — protects against feeding garbage into the model.
    test('rejects fast when confidence below the canEnhance floor', () async {
      final partial = _partial(confidence: 0.1);
      expect(partial.canEnhance, isFalse);

      final result = await service.enhance(partial);

      expect(result, isA<ImportFailure>());
      expect(llm.structureCalls, 0);
    });
  });

  group('enhance — rate-limit gate', () {
    /// When the limiter denies, the failure must (a) carry the limiter's
    /// swedishMessage and retryAfter so the UI can show real copy, and
    /// (b) NEVER call the LLM service.
    test(
      'short-circuits to ImportFailure.rateLimited; LLM not called',
      () async {
        limiter.result = const RateLimitDenied(
          message: 'too fast',
          retryAfter: Duration(seconds: 17),
          limitType: LimitType.perMinute,
          suggestedAction: FallbackAction.retryLater,
        );

        final result = await service.enhance(_partial());

        expect(result, isA<ImportFailure>());
        final failure = result as ImportFailure;
        expect(failure.errorCode, ImportErrorCode.rateLimited);
        expect(failure.retryAfter, const Duration(seconds: 17));
        expect(
          llm.structureCalls,
          0,
          reason: 'denied limit must never spend an LLM call',
        );
      },
    );

    /// The operation handed to the limiter must mark itself as LLM with
    /// llmType=enhancement — otherwise rate-limit accounting becomes
    /// wrong and LLM-budget gates won't apply.
    test('asks the limiter with the correct LLM operation type', () async {
      await service.enhance(_partial());

      expect(limiter.seenOperations, hasLength(1));
      final op = limiter.seenOperations.single;
      expect(op.requiresLlm, isTrue);
      expect(op.llmType, LlmOperationType.enhancement);
    });
  });

  group('enhance — happy path mapping', () {
    test('success returns ImportSuccess with tier+1, confidence 0.85, '
        'usedLlm/requiresReview true, and metadata block', () async {
      llm.structureResponse = StructureRecipeResponse(
        success: true,
        recipe: _extracted(title: 'Carbonara Deluxe'),
        estimatedCost: 0.012,
      );
      final partial = _partial(
        confidence: 0.55,
        tier: 2,
        missingFields: const ['portions'],
      );

      final result = await service.enhance(partial);

      expect(result, isA<ImportSuccess>());
      final success = result as ImportSuccess;
      expect(success.recipe.title, 'Carbonara Deluxe');
      expect(success.confidence, 0.85);
      expect(
        success.tier,
        3,
        reason: 'LLM enhancement must bump tier (partial.tier + 1)',
      );
      expect(success.pipeline, partial.pipeline);
      expect(success.method, 'llm-enhancement');
      expect(success.usedLlm, isTrue);
      expect(success.requiresReview, isTrue);
      expect(success.metadata, isNotNull);
      expect(success.metadata!['originalConfidence'], 0.55);
      expect(success.metadata!['missingFields'], ['portions']);
      expect(success.metadata!['llmCost'], 0.012);
    });

    /// LlmService is invoked with mode=enhance and the partial's
    /// partialData payload — otherwise the model is given no context to
    /// merge with.
    test('invokes structureRecipe with mode=enhance and partial.partialData '
        'payload', () async {
      llm.structureResponse = StructureRecipeResponse(
        success: true,
        recipe: _extracted(),
        estimatedCost: 0,
      );
      final partial = _partial(
        partialData: const {
          'title': 'X',
          'ingredients': ['a'],
        },
        extractedText: 'TEXT-PAYLOAD',
      );

      await service.enhance(partial);

      expect(llm.lastStructureMode, StructureMode.enhance);
      expect(llm.lastStructurePartialData, {
        'title': 'X',
        'ingredients': ['a'],
      });
      expect(llm.lastStructureText, 'TEXT-PAYLOAD');
    });

    /// rawHtml is used as the text payload when extractedText is null —
    /// fallback path. Catches the "we forgot the fallback" off-by-one.
    test('falls back to rawHtml when extractedText is null', () async {
      llm.structureResponse = StructureRecipeResponse(
        success: true,
        recipe: _extracted(),
        estimatedCost: 0,
      );
      final partial = _partial(
        extractedText: null,
        rawHtml: '<html>recipe body</html>',
      );

      await service.enhance(partial);

      expect(llm.lastStructureText, '<html>recipe body</html>');
    });
  });

  group('enhance — meal-type inference', () {
    Future<String> mealTypeFromTags(List<String> tags) async {
      llm.structureResponse = StructureRecipeResponse(
        success: true,
        recipe: _extracted(tags: tags),
        estimatedCost: 0,
      );
      final result = await service.enhance(_partial()) as ImportSuccess;
      return result.recipe.mealType;
    }

    test(
      'Swedish "frukost" maps to breakfast',
      () async => expect(await mealTypeFromTags(['Frukost']), 'breakfast'),
    );

    test(
      'English "breakfast" also maps to breakfast',
      () async => expect(await mealTypeFromTags(['BREAKFAST']), 'breakfast'),
    );

    test(
      '"lunch" maps to lunch',
      () async => expect(await mealTypeFromTags(['Lunch']), 'lunch'),
    );

    test(
      'Swedish "middag" maps to dinner',
      () async => expect(await mealTypeFromTags(['middag']), 'dinner'),
    );

    test(
      '"dessert" maps to dessert',
      () async => expect(await mealTypeFromTags(['Dessert']), 'dessert'),
    );

    test(
      'Swedish "efterrätt" maps to dessert',
      () async => expect(await mealTypeFromTags(['efterrätt']), 'dessert'),
    );

    test(
      'Swedish "mellanmål" maps to snack',
      () async => expect(await mealTypeFromTags(['mellanmål']), 'snack'),
    );

    test('unknown / empty tags default to dinner (NOT empty string)', () async {
      expect(await mealTypeFromTags(const []), 'dinner');
      expect(await mealTypeFromTags(['random']), 'dinner');
    });
  });

  group('enhance — extracted→recipe defaults', () {
    /// If LLM omits portions, we must NOT propagate null or 0 (which would
    /// later divide-by-zero in shopping/scaling). We fall back to the
    /// documented ParsingTier.kDefaultPortions constant.
    test(
      'null portions from LLM falls back to ParsingTier.kDefaultPortions',
      () async {
        llm.structureResponse = StructureRecipeResponse(
          success: true,
          recipe: _extracted(portions: null),
          estimatedCost: 0,
        );

        final result = await service.enhance(_partial()) as ImportSuccess;

        expect(result.recipe.portions, ParsingTier.kDefaultPortions);
      },
    );

    /// totalTimeMinutes is prep+cook; when both are null the recipe gets
    /// 0 (not crash, not null). Guards against the "0 minutes shown
    /// because we forgot the coalesce" UX bug.
    test(
      'null prep+cook minutes maps to timeMinutes=0 without crashing',
      () async {
        llm.structureResponse = StructureRecipeResponse(
          success: true,
          recipe: _extracted(prepTime: null, cookTime: null),
          estimatedCost: 0,
        );

        final result = await service.enhance(_partial()) as ImportSuccess;

        expect(result.recipe.timeMinutes, 0);
      },
    );

    test(
      'ingredients are converted to their formatted string representation',
      () async {
        llm.structureResponse = StructureRecipeResponse(
          success: true,
          recipe: _extracted(
            ingredients: const [
              ExtractedIngredient(amount: 2, unit: 'dl', name: 'mjölk'),
              ExtractedIngredient(name: 'salt'),
            ],
          ),
          estimatedCost: 0,
        );

        final result = await service.enhance(_partial()) as ImportSuccess;

        expect(result.recipe.ingredients, ['2 dl mjölk', 'salt']);
      },
    );
  });

  group('enhance — failure mapping', () {
    /// A rate-limited LlmException must map to llmQuotaExceeded (not the
    /// generic parsingFailed) — this distinction drives UI copy and the
    /// retry-later affordance. retryAfter must round-trip.
    test(
      'LlmException(isRateLimited=true) → llmQuotaExceeded with retryAfter',
      () async {
        llm.structureThrow = const LlmException(
          'quota burned',
          isRateLimited: true,
          retryAfter: Duration(minutes: 5),
        );

        final result = await service.enhance(_partial());

        expect(result, isA<ImportFailure>());
        final failure = result as ImportFailure;
        expect(failure.errorCode, ImportErrorCode.llmQuotaExceeded);
        expect(failure.retryAfter, const Duration(minutes: 5));
        expect(failure.message, 'quota burned');
      },
    );

    test('LlmException(non-rate-limited) → parsingFailed', () async {
      llm.structureThrow = const LlmException('model said no');

      final result = await service.enhance(_partial());

      expect(
        (result as ImportFailure).errorCode,
        ImportErrorCode.parsingFailed,
      );
    });

    /// Unexpected (non-LlmException) errors must be caught — not propagated —
    /// and surfaced as unknown with technicalDetails populated. The bug
    /// class: someone removes the bare `catch` and a StateError now crashes
    /// the import flow. This assertion would fail in that world.
    test(
      'non-LlmException error caught, mapped to unknown with technicalDetails',
      () async {
        llm.structureThrow = StateError('boom from inside');

        final result = await service.enhance(_partial());

        expect(result, isA<ImportFailure>());
        final failure = result as ImportFailure;
        expect(failure.errorCode, ImportErrorCode.unknown);
        expect(failure.technicalDetails, contains('boom from inside'));
      },
    );

    /// LLM responds with success=false. We must NOT fabricate an
    /// ImportSuccess with an empty recipe — the user-visible failure
    /// message must come from the server-provided error string.
    test('LLM success=false returns ImportFailure carrying server error '
        '(no fabricated success)', () async {
      llm.structureResponse = const StructureRecipeResponse(
        success: false,
        error: 'no recipe in input',
        estimatedCost: 0,
      );

      final result = await service.enhance(_partial());

      expect(result, isA<ImportFailure>());
      final failure = result as ImportFailure;
      expect(failure.errorCode, ImportErrorCode.parsingFailed);
      expect(failure.message, 'no recipe in input');
    });

    /// success=true but recipe=null is a subtler bug — model said OK,
    /// returned no body. Must NOT crash on .recipe! null-bang and must
    /// NOT fabricate success.
    test(
      'LLM success=true but recipe=null returns ImportFailure (not crash)',
      () async {
        llm.structureResponse = const StructureRecipeResponse(
          success: true,
          recipe: null,
          error: 'empty recipe',
          estimatedCost: 0,
        );

        final result = await service.enhance(_partial());

        expect(result, isA<ImportFailure>());
      },
    );
  });

  group('extractFromImage', () {
    test('rate-limit denial short-circuits without invoking LLM', () async {
      limiter.result = const RateLimitDenied(
        message: 'nope',
        retryAfter: Duration(seconds: 5),
        limitType: LimitType.perMinute,
        suggestedAction: FallbackAction.retryLater,
      );

      final result = await service.extractFromImage(
        Uint8List.fromList([1, 2, 3]),
      );

      expect((result as ImportFailure).errorCode, ImportErrorCode.rateLimited);
      expect(llm.ocrCalls, 0);
    });

    test('asks limiter with vision operation type', () async {
      await service.extractFromImage(Uint8List.fromList([0]));
      expect(limiter.seenOperations.single.llmType, LlmOperationType.vision);
    });

    test('success returns ImportSuccess(pipeline="photo", tier=4)', () async {
      llm.ocrResponse = OcrRecipeImageResponse(
        success: true,
        recipe: _extracted(title: 'Bok Choy Bowl'),
        estimatedCost: 0.04,
      );

      final result = await service.extractFromImage(
        Uint8List.fromList([1, 2, 3]),
      );

      expect(result, isA<ImportSuccess>());
      final success = result as ImportSuccess;
      expect(success.recipe.title, 'Bok Choy Bowl');
      expect(success.pipeline, 'photo');
      expect(success.tier, 4);
      expect(success.method, 'llm-vision');
      expect(success.usedLlm, isTrue);
      expect(success.requiresReview, isTrue);
      expect(success.confidence, 0.8);
    });

    /// If the LLM couldn't structure a recipe but returned raw OCR text,
    /// we surface that as ImportNeedsAssistance so the user can fix it
    /// manually. The image bytes must be threaded through unchanged
    /// (the assistance UI shows the photo).
    test('raw-text-only response → ImportNeedsAssistance with image bytes '
        'preserved', () async {
      llm.ocrResponse = const OcrRecipeImageResponse(
        success: false,
        rawText: 'Pasta carbonara\nIngredients:\n200g spaghetti...',
        estimatedCost: 0.01,
      );
      final bytes = Uint8List.fromList([7, 8, 9, 10]);

      final result = await service.extractFromImage(bytes);

      expect(result, isA<ImportNeedsAssistance>());
      final assist = result as ImportNeedsAssistance;
      expect(assist.extractedText, contains('Pasta carbonara'));
      expect(assist.imageBytes, bytes);
    });

    test(
      'no structured recipe and no rawText → ImportFailure with ocrFailed',
      () async {
        llm.ocrResponse = const OcrRecipeImageResponse(
          success: false,
          estimatedCost: 0,
          error: 'couldnt see anything',
        );

        final result = await service.extractFromImage(
          Uint8List.fromList([1, 2]),
        );

        expect(result, isA<ImportFailure>());
        expect((result as ImportFailure).errorCode, ImportErrorCode.ocrFailed);
        expect(result.message, 'couldnt see anything');
      },
    );

    test(
      'LlmException(rate-limited) maps to llmQuotaExceeded (not ocrFailed)',
      () async {
        llm.ocrThrow = const LlmException(
          'quota',
          isRateLimited: true,
          retryAfter: Duration(seconds: 30),
        );

        final result = await service.extractFromImage(Uint8List.fromList([1]));

        expect(result, isA<ImportFailure>());
        final failure = result as ImportFailure;
        expect(failure.errorCode, ImportErrorCode.llmQuotaExceeded);
        expect(failure.retryAfter, const Duration(seconds: 30));
        expect(failure.tier, 4);
        expect(failure.pipeline, 'photo');
      },
    );

    test('passes context through to LlmService.ocrRecipeImage', () async {
      await service.extractFromImage(
        Uint8List.fromList([1]),
        context: 'menu page 3',
      );
      expect(llm.lastOcrContext, 'menu page 3');
    });
  });

  group('extractFromHtml', () {
    test('asks limiter with fullExtraction operation type', () async {
      await service.extractFromHtml('<html/>', 'https://x.test');
      expect(
        limiter.seenOperations.single.llmType,
        LlmOperationType.fullExtraction,
      );
    });

    /// currentTier is the LAST tier that failed; the success result must
    /// be tagged with currentTier+1 so analytics can attribute the
    /// extraction to the LLM tier and not the last rule-based tier.
    test('success tier is currentTier+1 (default 3 → 4)', () async {
      llm.structureResponse = StructureRecipeResponse(
        success: true,
        recipe: _extracted(),
        estimatedCost: 0,
      );

      final result = await service.extractFromHtml(
        '<html/>',
        'https://example.com/recipe',
      );

      final success = result as ImportSuccess;
      expect(success.tier, 4);
      expect(success.pipeline, 'website');
      expect(success.method, 'llm-extraction');
      expect(success.metadata!['sourceUrl'], 'https://example.com/recipe');
    });

    test('explicit currentTier=5 → success tier is 6', () async {
      llm.structureResponse = StructureRecipeResponse(
        success: true,
        recipe: _extracted(),
        estimatedCost: 0,
      );

      final result = await service.extractFromHtml(
        '<html/>',
        'u',
        currentTier: 5,
      );

      expect((result as ImportSuccess).tier, 6);
    });

    test(
      'LLM success=false returns ImportFailure with server message',
      () async {
        llm.structureResponse = const StructureRecipeResponse(
          success: false,
          error: 'no recipe in html',
          estimatedCost: 0,
        );

        final result = await service.extractFromHtml('<html/>', 'u');

        expect(result, isA<ImportFailure>());
        expect((result as ImportFailure).message, 'no recipe in html');
      },
    );

    test('passes sourceUrl through to LlmService', () async {
      await service.extractFromHtml('<html/>', 'https://src.test');
      expect(llm.lastStructureSourceUrl, 'https://src.test');
      expect(llm.lastStructureMode, StructureMode.extract);
    });
  });

  group('extractFromTranscript', () {
    /// Failure-mode test: when LLM can't structure a video transcript,
    /// we fall back to ImportNeedsAssistance (NOT ImportFailure) — the
    /// user still has the transcript text to salvage manually. The
    /// videoTitle becomes the suggestedTitle.
    test('LLM yields no recipe → ImportNeedsAssistance with transcript + '
        'videoTitle as suggested title', () async {
      llm.structureResponse = const StructureRecipeResponse(
        success: false,
        estimatedCost: 0,
      );

      final result = await service.extractFromTranscript(
        'today we are making pasta',
        'https://youtu.be/abc',
        videoTitle: 'How to make pasta',
      );

      expect(result, isA<ImportNeedsAssistance>());
      final assist = result as ImportNeedsAssistance;
      expect(assist.extractedText, 'today we are making pasta');
      expect(assist.suggestedTitle, 'How to make pasta');
    });

    test(
      'success → ImportSuccess(pipeline=video, tier=5, confidence=0.75)',
      () async {
        llm.structureResponse = StructureRecipeResponse(
          success: true,
          recipe: _extracted(),
          estimatedCost: 0.02,
        );

        final result = await service.extractFromTranscript(
          'transcript',
          'https://youtu.be/x',
          videoTitle: 'My Video',
        );

        final success = result as ImportSuccess;
        expect(success.pipeline, 'video');
        expect(success.tier, 5);
        expect(success.confidence, 0.75);
        expect(success.method, 'llm-transcript');
        expect(success.metadata!['videoTitle'], 'My Video');
      },
    );

    test('LlmException(rate-limited) → llmQuotaExceeded', () async {
      llm.structureThrow = const LlmException(
        'q',
        isRateLimited: true,
        retryAfter: Duration(seconds: 10),
      );

      final result = await service.extractFromTranscript('t', 'https://u.test');

      expect(result, isA<ImportFailure>());
      expect(
        (result as ImportFailure).errorCode,
        ImportErrorCode.llmQuotaExceeded,
      );
      expect(result.tier, 5);
      expect(result.pipeline, 'video');
    });

    test('uses StructureMode.spoken', () async {
      llm.structureResponse = StructureRecipeResponse(
        success: true,
        recipe: _extracted(),
        estimatedCost: 0,
      );
      await service.extractFromTranscript('t', 'u');
      expect(llm.lastStructureMode, StructureMode.spoken);
    });
  });

  group('structured ingredients wiring (BUT-1228)', () {
    // This conversion seam builds the Recipe for ALL LLM-based imports:
    // TikTok/Instagram captions, photo vision fallback, URL Tier-6 fallback
    // and enhance mode. The Recipe it produces must PERSIST the LLM's
    // structured form (amount/unit/name), index-aligned with the raw
    // ingredient strings — the facade silently degrades misaligned data to
    // raw-only, so these assertions check core storage AND facade output.
    const structuredInput = [
      ExtractedIngredient(amount: 2, unit: 'dl', name: 'mjölk'),
      ExtractedIngredient(name: 'salt'),
      ExtractedIngredient(
        amount: 1.5,
        unit: 'tsk',
        name: 'socker',
        preparation: 'siktat',
      ),
    ];

    void expectStructuredWired(Recipe recipe) {
      final stored = recipe.core.structuredIngredients;
      expect(
        stored,
        isNotNull,
        reason:
            'structured data must be persisted on the core, '
            'not synthesized by the facade fallback',
      );
      expect(stored!.length, recipe.ingredients.length);
      for (var i = 0; i < stored.length; i++) {
        expect(
          stored[i].raw,
          recipe.ingredients[i],
          reason: 'entry $i must be index-aligned with ingredients[$i]',
        );
      }

      // Facade serves the stored data (proves alignment validation passed).
      final facade = recipe.structuredIngredients;
      expect(facade[0].amount, 2);
      expect(facade[0].unit, 'dl');
      expect(facade[0].name, 'mjölk');
      expect(
        facade[1].isStructured,
        isFalse,
        reason: 'amount-less line stays a raw-only entry',
      );
      expect(facade[1].name, 'salt');
      expect(facade[2].amount, 1.5);
      expect(facade[2].note, 'siktat');
    }

    test('extractFromTranscript (TikTok/Instagram path) recipe carries '
        'index-aligned structuredIngredients', () async {
      llm.structureResponse = StructureRecipeResponse(
        success: true,
        recipe: _extracted(ingredients: structuredInput),
        estimatedCost: 0,
      );

      final result =
          await service.extractFromTranscript(
                'caption text',
                'https://www.tiktok.com/@chef/video/1',
              )
              as ImportSuccess;

      expectStructuredWired(result.recipe);
    });

    test('extractFromImage (photo LLM fallback) recipe carries '
        'index-aligned structuredIngredients', () async {
      llm.ocrResponse = OcrRecipeImageResponse(
        success: true,
        recipe: _extracted(ingredients: structuredInput),
        estimatedCost: 0,
      );

      final result =
          await service.extractFromImage(
                Uint8List.fromList([1, 2, 3]),
              )
              as ImportSuccess;

      expectStructuredWired(result.recipe);
    });
  });

  group('isAvailable', () {
    test('delegates to LlmService.isAvailable (true)', () async {
      llm.isAvailableValue = true;
      expect(await service.isAvailable(), isTrue);
      expect(llm.isAvailableCalls, 1);
    });

    test('delegates to LlmService.isAvailable (false)', () async {
      llm.isAvailableValue = false;
      expect(await service.isAvailable(), isFalse);
    });
  });
}
