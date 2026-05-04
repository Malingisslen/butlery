import 'package:clock/clock.dart';
import 'dart:convert';

import 'package:html/dom.dart' as dom;

import 'package:butlery/models/parsing/field_result.dart';
import 'package:butlery/models/parsing/parsed_ingredient.dart';
import 'package:butlery/models/parsing/parsed_recipe.dart';
import 'package:butlery/services/parsing/ingredient_conversion.dart';
import 'package:butlery/services/parsing/swedish_units.dart';
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
/// Cap on instruction array count. Longest real recipe in our goldens has
/// ~30 steps; 50 is generous headroom. Above this cap → log + truncate.
/// Prevents an adversarial 100-step output from blowing up UI rendering
/// and Firestore writes.
const _maxInstructionCount = 50;

class LlmTier extends ParsingTier with QualityScoring {
  /// LLM service for making extraction calls.
  final LlmService? llmService;

  LlmTier({
    this.llmService,
  });

  static const tierIdentifier = 'LLM';
  static const _maxTextLength = 15000;
  static final _horizontalWhitespace = RegExp(r'[ \t]+');
  static final _excessiveNewlines = RegExp(r'\n{3,}');

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

      final pv = response.promptVersion;

      if (!response.success || response.recipe == null) {
        return TierResult(
          tierName: tierName,
          recipe: null,
          success: false,
          quality: 0.0,
          duration: stopwatch.elapsed,
          costSek: response.estimatedCost,
          failureReason: TierFailureReason.noData,
          promptVersion: pv,
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
          promptVersion: pv,
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
            promptVersion: pv,
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
          promptVersion: pv,
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
        promptVersion: pv,
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

  /// Prepare text for LLM processing using a three-strategy cascade:
  /// 1. JSON-LD from SchemaOrg tier (highest signal, lowest noise)
  /// 2. DOM-based recipe container extraction (strips navigation/comments)
  /// 3. Keyword-anchored truncation (centers window on recipe content)
  String _prepareText(ParsingContext context) {
    // Strategy 1: Reuse JSON-LD extracted by SchemaOrg tier
    final jsonLdText = _extractFromJsonLd(context);
    if (jsonLdText != null && jsonLdText.length >= 200) {
      return jsonLdText;
    }

    // Strategy 2: Extract recipe container from parsed DOM
    final domText = _extractFromDom(context);
    if (domText != null && domText.length >= 100) {
      return _truncate(domText);
    }

    // Strategy 3: Smart keyword-anchored truncation
    var text = context.sanitizedContent;
    if (text.contains('<')) {
      text = HtmlSanitizer.stripToPlainText(text);
    }
    return _smartTruncate(text);
  }

  /// Reuse JSON-LD even when SchemaOrg couldn't build a full recipe —
  /// the raw structured data is still higher signal than plain text for the LLM.
  String? _extractFromJsonLd(ParsingContext context) {
    final jsonLd = context.jsonLdData;
    if (jsonLd == null || jsonLd.isEmpty) return null;

    try {
      return jsonEncode(jsonLd);
    } catch (_) {
      return null;
    }
  }

  String? _extractFromDom(ParsingContext context) {
    if (context.parsedDocument is! dom.Document) return null;
    final doc = context.parsedDocument as dom.Document;

    // Find the most recipe-relevant container
    const recipeSelectors = [
      '[itemtype*="schema.org/Recipe"]',
      '[itemtype*="Recipe"]',
      'article[class*="recipe"]',
      'div[class*="recipe-content"]',
      'div[class*="recipe_content"]',
      'div[id*="recipe"]',
      'main article',
      'article',
      'main',
      '[role="main"]',
    ];

    dom.Element? container;
    for (final selector in recipeSelectors) {
      try {
        container = doc.querySelector(selector);
        if (container != null) break;
      } catch (_) {
        continue;
      }
    }

    container ??= doc.body;
    if (container == null) return null;

    // Clone to avoid mutating the cached DOM
    final clone = container.clone(true);

    // Remove noise elements
    const noiseSelectors = [
      'nav',
      'footer',
      'header',
      'aside',
      '[class*="comment"]',
      '[id*="comment"]',
      '[class*="sidebar"]',
      '[class*="related"]',
      '[class*="newsletter"]',
      '[class*="social-share"]',
      '[class*="advertisement"]',
      '[class*="ad-"]',
      '[class*="cookie"]',
      '[class*="modal"]',
      'script',
      'style',
      'noscript',
    ];
    for (final sel in noiseSelectors) {
      try {
        clone.querySelectorAll(sel).forEach((e) => e.remove());
      } catch (_) {}
    }

    final text = clone.text
        .replaceAll(_horizontalWhitespace, ' ')
        .replaceAll(_excessiveNewlines, '\n\n')
        .trim();

    return text.isEmpty ? null : text;
  }

  /// Center the truncation window on recipe keyword anchors
  /// instead of always taking the first 15k chars.
  String _smartTruncate(String text) {
    if (text.length <= _maxTextLength) return text.trim();

    const anchors = [
      'ingredienser',
      'ingredients',
      'instruktioner',
      'gör så här',
      'tillagning',
    ];

    final lowerText = text.toLowerCase();
    for (final anchor in anchors) {
      final pos = lowerText.indexOf(anchor);
      if (pos >= 0) {
        // Bias toward content after the anchor (recipe body follows the header)
        final start = (pos - _maxTextLength ~/ 4).clamp(0, text.length);
        final end = (start + _maxTextLength).clamp(0, text.length);
        return text.substring(start, end).trim();
      }
    }

    return text.substring(0, _maxTextLength).trim();
  }

  /// Simple truncation helper.
  String _truncate(String text) {
    if (text.length <= _maxTextLength) return text;
    return text.substring(0, _maxTextLength);
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

  static final _suspiciousPatterns = [
    RegExp(r'<script', caseSensitive: false),
    RegExp(r'javascript:', caseSensitive: false),
    RegExp(r'{{.*}}'), // Template injection
    RegExp(r'\$\{.*\}'), // String interpolation
    RegExp(r'__proto__'),
    RegExp(r'constructor\s*\('),
  ];

  /// Check for suspicious patterns that might indicate injection.
  bool _hasSuspiciousPatterns(String value) {
    for (final pattern in _suspiciousPatterns) {
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

    // Ingredients: ≥1, each name 1-100 chars; amount within per-unit ceiling
    // or `kMaxAmountUnitless` when unit is missing. Unknown-unit rows are
    // dropped at conversion time (not rejected here) — preserving the rest
    // of the recipe is more useful than rejecting on a single bad unit.
    if (extracted.ingredients.isEmpty) {
      errors.add('no_ingredients');
    }
    for (final ing in extracted.ingredients) {
      if (ing.name.isEmpty || ing.name.length > 100) {
        errors.add('ingredient_name_length');
        break;
      }
      if (ing.amount != null) {
        if (ing.amount! < 0) {
          errors.add('ingredient_amount_range');
          break;
        }
        final unitKey = ing.unit?.toLowerCase();
        final ceiling = (unitKey != null && unitKey.isNotEmpty)
            ? (kMaxAmountByUnit[unitKey] ?? kMaxAmountUnitless)
            : kMaxAmountUnitless;
        if (ing.amount! > ceiling) {
          AppLogger.warning(
            '$tierName: Implausible amount ${ing.amount} ${ing.unit ?? "(no unit)"} '
            'for "${ing.name}" exceeds ceiling $ceiling',
          );
          errors.add('ingredient_amount_range');
          break;
        }
      }
    }

    // Instructions: ≥1, each 5-2000 chars. Total count truncated at
    // `_maxInstructionCount` in conversion — not rejected here.
    if (extracted.instructions.isEmpty) {
      errors.add('no_instructions');
    }
    for (final inst in extracted.instructions) {
      if (inst.length < 5 || inst.length > 2000) {
        errors.add('instruction_length');
        break;
      }
    }

    // Portions: 1-kMaxPortions if present
    if (extracted.portions != null &&
        (extracted.portions! < 1 ||
            extracted.portions! > ParsingTier.kMaxPortions)) {
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
          : FieldResult.lowConfidence(
              ParsingTier.kDefaultPortions,
              'Defaulting to ${ParsingTier.kDefaultPortions} portions',
            ),
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
      timestamp: clock.now(),
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
          : FieldResult.lowConfidence(
              ParsingTier.kDefaultPortions,
              'Defaulting to ${ParsingTier.kDefaultPortions} portions',
            ),
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

    // Drop unknown-unit rows so they can't corrupt downstream
    // shopping-list / scaling / unit-conversion (which silently
    // mis-interpret or ignore them). Empty/null unit is allowed — many
    // legitimate ingredients are unitless (e.g. `2 ägg`).
    final filtered = <ExtractedIngredient>[];
    var droppedUnknownUnit = 0;
    for (final ing in extracted) {
      final unitKey = ing.unit?.toLowerCase();
      final isUnitless = unitKey == null || unitKey.isEmpty;
      if (isUnitless || kSwedishUnits.contains(unitKey)) {
        filtered.add(ing);
      } else {
        droppedUnknownUnit++;
        AppLogger.warning(
          '$tierName: Dropping ingredient "${ing.name}" — unknown unit "${ing.unit}"',
        );
      }
    }

    if (filtered.isEmpty) {
      return FieldResult.failed(
        'All LLM ingredients had unknown units (dropped $droppedUnknownUnit)',
      );
    }

    final deduped = _deduplicateIngredients(filtered);
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

    // Cap instruction count. Real recipes top out at ~30 steps; an LLM
    // returning 100 steps is hallucination — truncate so it can't blow
    // up UI rendering or Firestore writes. Front-loaded steps are
    // typically the most accurate; tail steps are where drift accumulates.
    if (instructions.length > _maxInstructionCount) {
      AppLogger.warning(
        '$tierName: Truncating instructions ${instructions.length} → $_maxInstructionCount',
      );
      return FieldResult.mediumConfidence(
        instructions.take(_maxInstructionCount).toList(),
        'LLM extraction (truncated)',
      );
    }

    return FieldResult.mediumConfidence(instructions, 'LLM extraction');
  }
}
