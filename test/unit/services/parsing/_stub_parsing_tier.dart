/// Controllable stub implementation of [ParsingTier] for orchestration tests
/// (BUT-1064 tiers: seam).
///
/// Allows tests to drive [_runTiers] without involving any real parsing logic:
/// - [result] determines what the tier returns
/// - [callCount] records how many times [parse] was invoked
/// - [skipPredicate] lets tests control [shouldSkip] behaviour
library;

import 'package:butlery/models/parsing/parse_metadata.dart';
import 'package:butlery/models/parsing/field_result.dart';
import 'package:butlery/models/parsing/parsed_recipe.dart';
import 'package:butlery/models/parsing/tier_result.dart';
import 'package:butlery/services/parsing/tiers/parsing_context.dart';
import 'package:butlery/services/parsing/tiers/parsing_tier.dart';

/// Builds a minimal, well-formed [ParsedRecipe] for tier-orchestration tests.
///
/// IMPORTANT: this does NOT produce a recipe whose [overallQuality] equals an
/// arbitrary score. [FieldResult.confidenceScore] is quantized to the
/// confidence bucket (high=1.0, medium=0.7, low=0.3, failed=0.0), and since all
/// fields here share a single bucket the weighted-sum [overallQuality] collapses
/// to exactly that bucket's score. [confidenceBucket] therefore SELECTS a
/// bucket, it is not a free-form target:
///   * ≥ 0.85 → high   (overallQuality == 1.0)
///   * ≥ 0.5  → medium (overallQuality == 0.7)
///   * else   → low    (overallQuality == 0.3)
///
/// Orchestration tests that need a tier whose `TierResult.quality` is an exact
/// value (e.g. on-threshold boundary at 0.65) must use [successTierAtExactQuality]
/// instead, which sets `TierResult.quality` directly rather than deriving it.
ParsedRecipe buildRecipeAtConfidenceBucket(double confidenceBucket) {
  final conf = confidenceBucket >= 0.85
      ? ParseConfidence.high
      : (confidenceBucket >= 0.5
          ? ParseConfidence.medium
          : ParseConfidence.low);

  return ParsedRecipe(
    title: FieldResult(value: 'Test Recipe', confidence: conf),
    portions: FieldResult(value: 4, confidence: conf),
    ingredients: FieldResult(
      value: const [],
      confidence: conf,
    ),
    instructions: FieldResult(
      value: const ['Step 1'],
      confidence: conf,
    ),
    totalTime: FieldResult(
      value: const Duration(minutes: 30),
      confidence: conf,
    ),
    metadata: ParseMetadata(
      source: ImportSource.text,
      parserVersion: '2.0.0',
      timestamp: DateTime(2026, 1, 1),
      totalParseTime: Duration.zero,
      tierResults: const [],
    ),
  );
}

/// A controllable stub tier for unit tests.
class StubParsingTier extends ParsingTier {
  final String _name;
  final TierResult Function(ParsingContext)? _resultFactory;
  final bool Function(ParsingContext)? _skipPredicate;

  int callCount = 0;

  /// [name] becomes [tierName]. [result] is the fixed result to return if no
  /// [resultFactory] is supplied. [skipPredicate] defaults to never-skip.
  StubParsingTier({
    required String name,
    TierResult? result,
    TierResult Function(ParsingContext)? resultFactory,
    bool Function(ParsingContext)? skipPredicate,
  })  : _name = name,
        _resultFactory =
            resultFactory ?? (result != null ? (_) => result : null),
        _skipPredicate = skipPredicate;

  @override
  String get tierName => _name;

  @override
  int get priority => 1;

  @override
  Duration get defaultTimeout => const Duration(seconds: 5);

  @override
  double get minQualityScore => 0.0;

  @override
  bool shouldSkip(ParsingContext context) =>
      _skipPredicate?.call(context) ?? false;

  @override
  Future<TierResult> parse(ParsingContext context) async {
    callCount++;
    if (_resultFactory != null) return _resultFactory(context);
    return TierResult.noData(tierName: _name, duration: Duration.zero);
  }
}

/// A stub tier that always succeeds with `TierResult.quality` set to EXACTLY
/// [quality].
///
/// `_runTiers` short-circuits on `TierResult.quality`, so this sets that field
/// directly via the general [TierResult] constructor rather than deriving it
/// from the quantized bucket (which [TierResult.success] would do). That makes
/// the [quality] argument truthful for boundary tests — `successTierAtExactQuality(_, 0.65)`
/// really produces quality 0.65, not the medium bucket's 0.7. The attached
/// recipe is built at the nearest confidence bucket purely so merge has a
/// well-formed recipe to work with.
StubParsingTier successTierAtExactQuality(String name, double quality) =>
    StubParsingTier(
      name: name,
      result: TierResult(
        tierName: name,
        success: true,
        quality: quality,
        recipe: buildRecipeAtConfidenceBucket(quality),
        duration: const Duration(milliseconds: 10),
      ),
    );

/// Convenience alias kept for readability at call sites that don't care about
/// exactness (values comfortably inside a single bucket, e.g. 0.90 / 0.30).
/// Identical semantics to [successTierAtExactQuality].
StubParsingTier successTierAt(String name, double quality) =>
    successTierAtExactQuality(name, quality);

/// A stub tier that always fails with noData.
StubParsingTier failingTier(String name, {TierFailureReason? reason}) =>
    StubParsingTier(
      name: name,
      result: TierResult(
        tierName: name,
        success: false,
        quality: 0.0,
        duration: const Duration(milliseconds: 5),
        failureReason: reason ?? TierFailureReason.noData,
      ),
    );
