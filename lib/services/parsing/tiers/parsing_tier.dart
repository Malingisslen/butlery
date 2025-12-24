import 'dart:async';

import 'package:butlery/models/parsing/tier_result.dart';
import 'package:butlery/services/parsing/tiers/parsing_context.dart';
import 'package:butlery/core/utils/logger.dart';

/// Abstract base class for parsing tiers.
///
/// Each tier implements a different parsing strategy:
/// - Tier 1: SchemaOrg (JSON-LD extraction)
/// - Tier 2: SiteConfig (CSS selectors from Firestore)
/// - Tier 3: RuleBased (Swedish line classification)
/// - Tier 4: LLM (AI-based extraction)
///
/// Tiers are executed in order until one produces a result
/// meeting the quality threshold.
abstract class ParsingTier {
  /// Unique name for this tier.
  String get tierName;

  /// Execution priority (lower = runs first).
  int get priority;

  /// Default timeout for this tier.
  Duration get defaultTimeout;

  /// Minimum quality score this tier can produce.
  double get minQualityScore;

  /// Whether this tier should be skipped for the given context.
  bool shouldSkip(ParsingContext context);

  /// Execute the parsing logic.
  ///
  /// Returns a TierResult with the parsed recipe if successful.
  /// Should not throw - return TierResult.failed() instead.
  Future<TierResult> parse(ParsingContext context);

  /// Execute parsing with timeout protection.
  Future<TierResult> parseWithTimeout(
    ParsingContext context, {
    Duration? timeout,
  }) async {
    if (shouldSkip(context)) {
      return TierResult.skipped(tierName: tierName);
    }

    final effectiveTimeout = timeout ?? defaultTimeout;
    final stopwatch = Stopwatch()..start();

    try {
      final result = await parse(context).timeout(
        effectiveTimeout,
        onTimeout: () {
          AppLogger.warning(
            '$tierName: Timeout after ${effectiveTimeout.inSeconds}s',
          );
          return TierResult.timeout(
            tierName: tierName,
            duration: stopwatch.elapsed,
          );
        },
      );

      // Update duration if not set
      final finalResult = result.copyWith(
        duration: result.duration == Duration.zero
            ? stopwatch.elapsed
            : result.duration,
      );

      // Add to context
      context.addTierResult(TierResultEntry(
        tierName: tierName,
        success: finalResult.success,
        quality: finalResult.quality,
        duration: finalResult.duration,
        failureReason: finalResult.failureReason?.name,
      ));

      if (finalResult.success) {
        AppLogger.info(
          '$tierName: Success (quality: ${(finalResult.quality * 100).toInt()}%, '
          'time: ${stopwatch.elapsedMilliseconds}ms)',
        );
      } else {
        AppLogger.debug(
          '$tierName: Failed - ${finalResult.failureReason?.name ?? "unknown"}',
        );
      }

      return finalResult;
    } catch (e) {
      stopwatch.stop();
      AppLogger.warning('$tierName: Exception: $e');

      final result = TierResult.parseError(
        tierName: tierName,
        duration: stopwatch.elapsed,
        message: e.toString(),
      );

      context.addTierResult(TierResultEntry(
        tierName: tierName,
        success: false,
        quality: 0.0,
        duration: stopwatch.elapsed,
        failureReason: 'exception: $e',
      ));

      return result;
    }
  }
}

/// Mixin providing timeout handling utilities.
mixin TimeoutHandling {
  /// Execute a function with timeout, returning null on timeout or error.
  Future<T?> withTimeoutOrNull<T>(
    Future<T> Function() operation,
    Duration timeout,
  ) async {
    try {
      return await operation().timeout(timeout);
    } on TimeoutException {
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Execute multiple operations concurrently with individual timeouts.
  Future<List<T?>> withConcurrentTimeouts<T>(
    List<Future<T> Function()> operations,
    Duration timeout,
  ) async {
    return Future.wait(
      operations.map((op) => withTimeoutOrNull(op, timeout)),
    );
  }
}

/// Mixin for tiers that need quality scoring utilities.
mixin QualityScoring {
  /// Calculate ingredient quality score.
  double scoreIngredients(List<dynamic>? ingredients) {
    if (ingredients == null || ingredients.isEmpty) return 0.0;

    var score = 0.3; // Base score for having ingredients

    // More ingredients = more confidence
    if (ingredients.length >= 3) score += 0.2;
    if (ingredients.length >= 6) score += 0.2;

    // Check for structured data
    var structuredCount = 0;
    for (final ing in ingredients) {
      if (ing is Map && (ing['quantity'] != null || ing['unit'] != null)) {
        structuredCount++;
      } else if (ing is String && ing.contains(RegExp(r'\d'))) {
        structuredCount++;
      }
    }

    final structureRatio =
        ingredients.isEmpty ? 0.0 : structuredCount / ingredients.length;
    score += structureRatio * 0.3;

    return score.clamp(0.0, 1.0);
  }

  /// Calculate instruction quality score.
  double scoreInstructions(List<String>? instructions) {
    if (instructions == null || instructions.isEmpty) return 0.0;

    var score = 0.3; // Base score for having instructions

    // More steps = more confidence
    if (instructions.length >= 3) score += 0.2;
    if (instructions.length >= 5) score += 0.1;

    // Longer instructions = more detailed
    final avgLength =
        instructions.map((s) => s.length).reduce((a, b) => a + b) /
            instructions.length;
    if (avgLength > 50) score += 0.2;
    if (avgLength > 100) score += 0.2;

    return score.clamp(0.0, 1.0);
  }

  /// Calculate overall recipe quality.
  double calculateOverallQuality({
    String? title,
    int? portions,
    List<dynamic>? ingredients,
    List<String>? instructions,
    Duration? totalTime,
    String? imageUrl,
  }) {
    var score = 0.0;

    // Title: 15%
    if (title != null && title.length >= 3) {
      score += 0.15;
    }

    // Portions: 10%
    if (portions != null && portions > 0 && portions <= 50) {
      score += 0.10;
    }

    // Ingredients: 40%
    score += scoreIngredients(ingredients) * 0.40;

    // Instructions: 30%
    score += scoreInstructions(instructions) * 0.30;

    // Time: 5%
    if (totalTime != null && totalTime.inMinutes > 0) {
      score += 0.05;
    }

    return score.clamp(0.0, 1.0);
  }
}
