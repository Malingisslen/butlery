import 'package:butlery/models/parsing/field_result.dart';
import 'package:butlery/models/parsing/parsed_ingredient.dart';
import 'package:butlery/models/parsing/parsed_recipe.dart';
import 'package:butlery/models/parsing/parse_metadata.dart';
import 'package:butlery/models/parsing/tier_result.dart';
import 'package:butlery/services/llm/llm_models.dart';
import 'package:butlery/services/llm/llm_service.dart';
import 'package:butlery/services/parsing/tiers/parsing_context.dart';
import 'package:butlery/services/parsing/tiers/parsing_tier.dart';
import 'package:butlery/core/utils/logger.dart';

/// Tier 4: LLM-based extraction with P0-2 schema validation.
///
/// This is the final fallback tier using AI to extract recipe data.
/// It's the most expensive but can handle unstructured content.
///
/// **P0-2 Security Fix**: All LLM responses are validated for
/// suspicious patterns to prevent prompt injection attacks.
class LlmTier extends ParsingTier with QualityScoring {
  /// LLM service for making extraction calls.
  final LlmService? llmService;

  LlmTier({
    this.llmService,
  });

  @override
  String get tierName => 'LLM';

  @override
  int get priority => 4;

  @override
  Duration get defaultTimeout => const Duration(seconds: 30);

  @override
  double get minQualityScore => 0.5;

  @override
  bool shouldSkip(ParsingContext context) {
    // Don't skip - LLM is the final fallback
    if (context.sanitizedContent.isEmpty) return true;

    // Skip if LLM service is not available
    if (llmService == null) return true;

    return false;
  }

  @override
  Future<TierResult> parse(ParsingContext context) async {
    final stopwatch = Stopwatch()..start();

    try {
      // Prepare text for LLM
      final text = _prepareText(context);

      if (text.isEmpty || text.length < 50) {
        return TierResult.noData(
          tierName: tierName,
          duration: stopwatch.elapsed,
        );
      }

      // Call LLM service
      final response = await llmService!.structureRecipe(
        text: text,
        mode: StructureMode.extract,
        sourceUrl: context.sourceUrl,
      );

      if (!response.success || response.recipe == null) {
        return TierResult(
          tierName: tierName,
          recipe: null,
          success: false,
          quality: 0.0,
          duration: stopwatch.elapsed,
          costSek: response.estimatedCost,
          failureReason: TierFailureReason.noData,
        );
      }

      final extractedRecipe = response.recipe!;

      // P0-2: Validate response for suspicious patterns
      if (!_validateForSuspiciousPatterns(extractedRecipe)) {
        AppLogger.warning('$tierName: P0-2 validation failed - suspicious patterns');
        return TierResult(
          tierName: tierName,
          recipe: null,
          success: false,
          quality: 0.0,
          duration: stopwatch.elapsed,
          costSek: response.estimatedCost,
          failureReason: TierFailureReason.invalidResponse,
        );
      }

      // Convert to ParsedRecipe
      final recipe = _convertToRecipe(extractedRecipe, context);

      if (recipe == null || !recipe.isComplete) {
        return TierResult.noData(
          tierName: tierName,
          duration: stopwatch.elapsed,
        );
      }

      return TierResult.success(
        tierName: tierName,
        recipe: recipe,
        duration: stopwatch.elapsed,
        costSek: response.estimatedCost,
      );
    } catch (e) {
      AppLogger.warning('$tierName: Exception during extraction: $e');
      return TierResult.parseError(
        tierName: tierName,
        duration: stopwatch.elapsed,
        message: e.toString(),
      );
    }
  }

  /// Prepare text for LLM processing.
  String _prepareText(ParsingContext context) {
    var text = context.sanitizedContent;

    // If HTML, strip tags
    if (text.contains('<')) {
      text = _stripHtml(text);
    }

    // Truncate to reasonable length
    if (text.length > 15000) {
      text = text.substring(0, 15000);
    }

    return text.trim();
  }

  /// Strip HTML tags.
  String _stripHtml(String html) {
    var text = html;

    // Remove script and style
    text = text.replaceAll(
      RegExp(r'<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>',
          caseSensitive: false),
      '',
    );
    text = text.replaceAll(
      RegExp(r'<style\b[^<]*(?:(?!<\/style>)<[^<]*)*<\/style>',
          caseSensitive: false),
      '',
    );

    // Replace block elements with newlines
    text = text.replaceAll(
      RegExp(r'<(?:br|p|div|li|tr)[^>]*>', caseSensitive: false),
      '\n',
    );

    // Remove tags
    text = text.replaceAll(RegExp(r'<[^>]+>'), '');

    return text;
  }

  // ========== P0-2: Security Validation ==========

  /// Check for suspicious patterns that might indicate injection.
  bool _validateForSuspiciousPatterns(ExtractedRecipe recipe) {
    // Check title
    if (_hasSuspiciousPatterns(recipe.title)) {
      return false;
    }

    // Check description
    if (recipe.description != null &&
        _hasSuspiciousPatterns(recipe.description!)) {
      return false;
    }

    // Check instructions
    for (final instruction in recipe.instructions) {
      if (_hasSuspiciousPatterns(instruction)) {
        return false;
      }
    }

    // Check ingredient names
    for (final ingredient in recipe.ingredients) {
      if (_hasSuspiciousPatterns(ingredient.name)) {
        return false;
      }
      if (ingredient.preparation != null &&
          _hasSuspiciousPatterns(ingredient.preparation!)) {
        return false;
      }
    }

    return true;
  }

  /// Check for suspicious patterns that might indicate injection.
  bool _hasSuspiciousPatterns(String value) {
    final patterns = [
      RegExp(r'<script', caseSensitive: false),
      RegExp(r'javascript:', caseSensitive: false),
      RegExp(r'{{.*}}'), // Template injection
      RegExp(r'\$\{.*\}'), // String interpolation
      RegExp(r'__proto__'),
      RegExp(r'constructor\s*\('),
    ];

    for (final pattern in patterns) {
      if (pattern.hasMatch(value)) {
        return true;
      }
    }

    return false;
  }

  // ========== Recipe Conversion ==========

  ParsedRecipe? _convertToRecipe(
    ExtractedRecipe extracted,
    ParsingContext context,
  ) {
    // Convert ingredients
    final ingredients = _convertIngredients(extracted.ingredients);

    // Convert instructions
    final instructions = _convertInstructions(extracted.instructions);

    // Calculate total time
    final totalTime = extracted.totalTimeMinutes != null
        ? Duration(minutes: extracted.totalTimeMinutes!)
        : null;

    // Create metadata
    final metadata = ParseMetadata(
      source: context.source,
      domain: context.domain,
      sourceUrl: context.sourceUrl,
      parserVersion: context.parserVersion,
      timestamp: DateTime.now(),
      totalParseTime: context.elapsed,
      tierResults: const [],
    );

    return ParsedRecipe(
      title: FieldResult.success(extracted.title),
      portions: extracted.portions != null
          ? FieldResult.success(extracted.portions!)
          : FieldResult.lowConfidence(4, 'Defaulting to 4'),
      ingredients: ingredients,
      instructions: instructions,
      totalTime: totalTime != null
          ? FieldResult.success(totalTime)
          : FieldResult.failed('No time from LLM'),
      metadata: metadata,
      description: extracted.description,
    );
  }

  FieldResult<List<ParsedIngredient>> _convertIngredients(
    List<ExtractedIngredient> extracted,
  ) {
    if (extracted.isEmpty) {
      return FieldResult.failed('No ingredients from LLM');
    }

    final parsed = <ParsedIngredient>[];

    for (final ing in extracted) {
      parsed.add(ParsedIngredient(
        name: ing.name,
        originalLine: ing.formatted,
        quantity: ing.amount?.toString(),
        unit: ing.unit,
        preparation: ing.preparation,
        confidence: ing.amount != null || ing.unit != null
            ? ParseConfidence.high
            : ParseConfidence.medium,
      ));
    }

    return FieldResult.success(parsed);
  }

  FieldResult<List<String>> _convertInstructions(List<String> instructions) {
    if (instructions.isEmpty) {
      return FieldResult.failed('No instructions from LLM');
    }

    return FieldResult.success(instructions);
  }
}
