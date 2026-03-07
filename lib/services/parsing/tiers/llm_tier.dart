import 'package:butlery/models/parsing/field_result.dart';
import 'package:butlery/models/parsing/parsed_ingredient.dart';
import 'package:butlery/models/parsing/parsed_recipe.dart';
import 'package:butlery/services/parsing/ingredient_conversion.dart';
import 'package:butlery/models/parsing/parse_metadata.dart';
import 'package:butlery/models/parsing/tier_result.dart';
import 'package:butlery/services/llm/llm_models.dart';
import 'package:butlery/services/llm/llm_service.dart';
import 'package:butlery/services/parsing/sanitizers/html_sanitizer.dart';
import 'package:butlery/services/parsing/tiers/parsing_context.dart';
import 'package:butlery/services/parsing/tiers/parsing_tier.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/retry_helper.dart';

/// Tier 4: LLM-based extraction with P0-2 schema validation.
///
/// This is the final fallback tier using AI to extract recipe data.
/// It's the most expensive but can handle unstructured content.
///
/// **P0-2 Security Fix**: All LLM responses are validated for
/// suspicious patterns to prevent prompt injection attacks.
/// Known Swedish measurement units for validation.
const _knownSwedishUnits = <String>{
  'dl',
  'cl',
  'ml',
  'l',
  'msk',
  'tsk',
  'krm',
  'g',
  'kg',
  'st',
  'nypa',
  'knippe',
  'klyfta',
  'skiva',
  'port',
  'bit',
  'burk',
  'paket',
  'pkt',
  'förp',
  'näve',
  'klick',
  'droppe',
};

class LlmTier extends ParsingTier with QualityScoring {
  /// LLM service for making extraction calls.
  final LlmService? llmService;

  LlmTier({
    this.llmService,
  });

  static const tierIdentifier = 'LLM';

  @override
  String get tierName => tierIdentifier;

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

      // Use enhance mode when earlier tiers produced a partial result
      // with only 1-2 weak fields — reduces LLM token usage by ~60-70%.
      final partial = context.bestPartialRecipe;
      final useEnhance = partial != null && partial.shouldEnhance;

      final mode = useEnhance ? StructureMode.enhance : StructureMode.extract;
      final partialData = useEnhance ? partial.goodFields : null;

      if (useEnhance) {
        AppLogger.info(
          '$tierName: Using enhance mode for fields: '
          '${partial.weakFields.join(", ")}',
        );
      }

      // Call LLM service with retry logic
      final response = await RetryHelper.retryNetworkOperation(
        () => llmService!.structureRecipe(
          text: text,
          mode: mode,
          partialData: partialData,
          sourceUrl: context.sourceUrl,
        ),
        maxRetries: 2,
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
        AppLogger.warning(
            '$tierName: P0-2 validation failed - suspicious patterns');
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

      // LLM can hallucinate unreasonable values — catch before conversion
      final validationErrors = _validateResponse(extractedRecipe);

      if (validationErrors.isNotEmpty) {
        AppLogger.debug(
          '$tierName: Validation issues: ${validationErrors.join(", ")}',
        );

        // Try partial result if title or ingredients are valid
        final recipe = _convertToPartialRecipe(
          extractedRecipe,
          context,
          validationErrors,
        );

        if (recipe != null) {
          return TierResult.success(
            tierName: tierName,
            recipe: recipe,
            duration: stopwatch.elapsed,
            costSek: response.estimatedCost,
          );
        }

        return TierResult(
          tierName: tierName,
          recipe: null,
          success: false,
          quality: 0.0,
          duration: stopwatch.elapsed,
          costSek: response.estimatedCost,
          failureReason: TierFailureReason.schemaValidationFailed,
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
    } on LlmException catch (e) {
      if (e.isRateLimited) {
        AppLogger.warning('$tierName: Rate limited - ${e.message}');
        return TierResult(
          tierName: tierName,
          recipe: null,
          success: false,
          quality: 0.0,
          duration: stopwatch.elapsed,
          failureReason: TierFailureReason.rateLimited,
        );
      }
      AppLogger.warning('$tierName: LLM exception: $e');
      return TierResult.parseError(
        tierName: tierName,
        duration: stopwatch.elapsed,
        message: e.toString(),
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
      text = HtmlSanitizer.stripToPlainText(text);
    }

    // Truncate to reasonable length
    if (text.length > 15000) {
      text = text.substring(0, 15000);
    }

    return text.trim();
  }

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

  /// Validate extracted recipe fields for reasonable ranges and formats.
  /// Returns a list of validation error descriptions (empty = valid).
  List<String> _validateResponse(ExtractedRecipe extracted) {
    final errors = <String>[];

    // Title: 2-200 chars, no URLs
    if (extracted.title.length < 2 || extracted.title.length > 200) {
      errors.add('title_length');
    }
    if (RegExp(r'https?://').hasMatch(extracted.title)) {
      errors.add('title_contains_url');
    }

    // Description: max 500 chars
    if (extracted.description != null && extracted.description!.length > 500) {
      errors.add('description_length');
    }

    // Ingredients: ≥1, each name 1-100 chars, amount 0-10000
    if (extracted.ingredients.isEmpty) {
      errors.add('no_ingredients');
    }
    for (final ing in extracted.ingredients) {
      if (ing.name.isEmpty || ing.name.length > 100) {
        errors.add('ingredient_name_length');
        break;
      }
      if (ing.amount != null && (ing.amount! < 0 || ing.amount! > 10000)) {
        errors.add('ingredient_amount_range');
        break;
      }
      // Flag unknown units (non-blocking — lower confidence logged)
      if (ing.unit != null &&
          ing.unit!.isNotEmpty &&
          !_knownSwedishUnits.contains(ing.unit!.toLowerCase())) {
        AppLogger.debug(
            '$tierName: Unknown unit "${ing.unit}" for "${ing.name}"');
      }
    }

    // Instructions: ≥1, each 5-2000 chars
    if (extracted.instructions.isEmpty) {
      errors.add('no_instructions');
    }
    for (final inst in extracted.instructions) {
      if (inst.length < 5 || inst.length > 2000) {
        errors.add('instruction_length');
        break;
      }
    }

    // Portions: 1-100 if present
    if (extracted.portions != null &&
        (extracted.portions! < 1 || extracted.portions! > 100)) {
      errors.add('portions_range');
    }

    // Time: 1-2880 min if present
    final time = extracted.totalTimeMinutes;
    if (time != null && (time < 1 || time > 2880)) {
      errors.add('time_range');
    }

    // Difficulty: must be easy/medium/hard or null
    if (extracted.difficulty != null &&
        !{'easy', 'medium', 'hard'}.contains(extracted.difficulty)) {
      errors.add('invalid_difficulty');
    }

    return errors;
  }

  /// Build a partial recipe from valid fields when validation partially fails.
  ParsedRecipe? _convertToPartialRecipe(
    ExtractedRecipe extracted,
    ParsingContext context,
    List<String> validationErrors,
  ) {
    final hasValidTitle = !validationErrors.contains('title_length') &&
        !validationErrors.contains('title_contains_url');
    final hasValidIngredients = !validationErrors.contains('no_ingredients') &&
        !validationErrors.contains('ingredient_name_length') &&
        !validationErrors.contains('ingredient_amount_range');

    // Need at least title or ingredients for a useful partial result
    if (!hasValidTitle && !hasValidIngredients) return null;

    final hasValidInstructions =
        !validationErrors.contains('no_instructions') &&
            !validationErrors.contains('instruction_length');
    final hasValidPortions = !validationErrors.contains('portions_range');
    final hasValidTime = !validationErrors.contains('time_range');

    final metadata = _buildMetadata(context);

    return ParsedRecipe(
      title: hasValidTitle
          ? FieldResult.mediumConfidence(extracted.title, 'LLM extraction')
          : FieldResult.failed('Invalid title from LLM'),
      portions: hasValidPortions && extracted.portions != null
          ? FieldResult.mediumConfidence(extracted.portions!, 'LLM extraction')
          : FieldResult.lowConfidence(4, 'Defaulting to 4'),
      ingredients: hasValidIngredients
          ? _convertIngredients(extracted.ingredients)
          : FieldResult.failed('Invalid ingredients from LLM'),
      instructions: hasValidInstructions
          ? _convertInstructions(extracted.instructions)
          : FieldResult.failed('Invalid instructions from LLM'),
      totalTime: hasValidTime && extracted.totalTimeMinutes != null
          ? FieldResult.mediumConfidence(
              Duration(minutes: extracted.totalTimeMinutes!),
              'LLM extraction',
            )
          : FieldResult.failed('No valid time from LLM'),
      metadata: metadata,
      description: extracted.description,
    );
  }

  ParseMetadata _buildMetadata(ParsingContext context) {
    return ParseMetadata(
      source: context.source,
      domain: context.domain,
      sourceUrl: context.sourceUrl,
      parserVersion: context.parserVersion,
      timestamp: DateTime.now(),
      totalParseTime: context.elapsed,
      tierResults: const [],
    );
  }

  ParsedRecipe? _convertToRecipe(
    ExtractedRecipe extracted,
    ParsingContext context,
  ) {
    final ingredients = _convertIngredients(extracted.ingredients);
    final instructions = _convertInstructions(extracted.instructions);

    final totalTime = extracted.totalTimeMinutes != null
        ? Duration(minutes: extracted.totalTimeMinutes!)
        : null;

    final metadata = _buildMetadata(context);

    return ParsedRecipe(
      title: FieldResult.mediumConfidence(extracted.title, 'LLM extraction'),
      portions: extracted.portions != null
          ? FieldResult.mediumConfidence(extracted.portions!, 'LLM extraction')
          : FieldResult.lowConfidence(4, 'Defaulting to 4'),
      ingredients: ingredients,
      instructions: instructions,
      totalTime: totalTime != null
          ? FieldResult.mediumConfidence(totalTime, 'LLM extraction')
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

    final deduped = _deduplicateIngredients(extracted);
    final parsed = <ParsedIngredient>[];

    for (final ing in deduped) {
      parsed.add(parsedIngredientFromExtracted(ing));
    }

    return FieldResult.mediumConfidence(parsed, 'LLM extraction');
  }

  /// Deduplicate ingredients by normalized name.
  /// Same name + same unit → sum amounts.
  /// Same name + different units → keep first occurrence.
  List<ExtractedIngredient> _deduplicateIngredients(
    List<ExtractedIngredient> ingredients,
  ) {
    final seen = <String, ExtractedIngredient>{};

    for (final ing in ingredients) {
      final key = ing.name.toLowerCase().trim();
      final existing = seen[key];

      if (existing == null) {
        seen[key] = ing;
      } else if (existing.unit?.toLowerCase() == ing.unit?.toLowerCase() &&
          existing.amount != null &&
          ing.amount != null) {
        // Same unit — sum amounts
        seen[key] = ExtractedIngredient(
          amount: existing.amount! + ing.amount!,
          unit: existing.unit,
          name: existing.name,
          preparation: existing.preparation ?? ing.preparation,
        );
      }
      // Different units — keep first occurrence (skip duplicate)
    }

    return seen.values.toList();
  }

  FieldResult<List<String>> _convertInstructions(List<String> instructions) {
    if (instructions.isEmpty) {
      return FieldResult.failed('No instructions from LLM');
    }

    return FieldResult.mediumConfidence(instructions, 'LLM extraction');
  }
}
