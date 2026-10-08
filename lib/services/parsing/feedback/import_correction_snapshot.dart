import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/parsing/field_result.dart';
import 'package:butlery/models/parsing/parse_metadata.dart';
import 'package:butlery/models/parsing/parsed_ingredient.dart';
import 'package:butlery/models/parsing/parsed_recipe.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/import/parsers/unread_line_detector.dart';
import 'package:butlery/services/parsing/cache/parsed_recipe_cache.dart';
import 'package:butlery/utils/text/ingredient_parser.dart';

/// Captures a pre-edit [ParsedRecipe] snapshot for import paths that produce a
/// [Recipe] directly instead of a rich parser [ParsedRecipe] (BUT-1469).
///
/// Before this, only Tier-1 URL imports fed the parser feedback loop: the URL
/// strategy stored its real [ParsedRecipe] in [ParsedRecipeCache], the recipe
/// form retrieved it, and [RecipeDiffCalculator] diffed it against the saved
/// recipe on edit. Every other import modality (text, photo, voice, archive)
/// produced a [Recipe] with no cached snapshot, so a user's corrections were
/// never captured as training data.
///
/// This builds a snapshot FROM the produced recipe, keyed by recipe id and
/// tagged with its [ImportSource], and stores it in the same cache the form
/// already reads. The ingredient side is parsed with the SAME
/// [IngredientParser] the diff calculator uses on the corrected side, so an
/// unedited save diffs to zero corrections (no spurious training rows).
///
/// A snapshot without per-line confidence exists only to anchor the edit diff
/// and is stamped with [snapshotParserVersion]. One whose lines carry the
/// reader's confidence is stamped [reviewParserVersion], and the form shows
/// those lines in the import review (BUT-2158).
class ImportCorrectionSnapshot {
  ImportCorrectionSnapshot._();

  /// Parser-version sentinel marking a snapshot built from an already-produced
  /// recipe rather than a genuine multi-tier parse. Lets the form distinguish
  /// "anchor for correction diffing" from "real per-field confidence".
  static const String snapshotParserVersion = 'import-snapshot-v1';

  /// Parser-version stamp for a snapshot whose ingredient lines carry the
  /// reader's per-line confidence, so the form can review them.
  static const String reviewParserVersion = 'import-snapshot-v2';

  /// Build a snapshot for [recipe] and store it in the shared cache keyed by
  /// recipe id. Best-effort: a missing cache (e.g. tests without DI) or any
  /// failure is swallowed so capture never disturbs the import path.
  ///
  /// [confidences] is one entry per line of `recipe.ingredients`. Without it,
  /// a snapshot already cached for the same recipe and lines keeps its
  /// confidences: photo and voice re-tag the text strategy's snapshot, and
  /// the re-tag must not erase what the text strategy measured. Failing that,
  /// a line [UnreadLineDetector] calls unread is still marked.
  static void capture(
    Recipe recipe, {
    required ImportSource source,
    String? domain,
    ParsedRecipeCache? cache,
    List<ParseConfidence>? confidences,
  }) {
    if (recipe.id.isEmpty) return;
    try {
      final target = cache ?? ServiceLocator.tryGet<ParsedRecipeCache>();
      if (target == null) return;
      final previous = confidences == null ? target.retrieve(recipe.id) : null;
      target.store(
        recipe.id,
        build(
          recipe,
          source: source,
          domain: domain,
          confidences:
              confidences ??
              _keptConfidences(previous, recipe) ??
              _unreadConfidences(recipe),
        ),
      );
    } catch (e) {
      AppLogger.debug('ImportCorrectionSnapshot: capture skipped: $e');
    }
  }

  /// Build a [ParsedRecipe] anchor from a produced [Recipe]. Public for tests.
  @visibleForTesting
  static ParsedRecipe build(
    Recipe recipe, {
    required ImportSource source,
    String? domain,
    List<ParseConfidence>? confidences,
  }) {
    final lines = recipe.ingredients;
    final reviewed =
        confidences != null && confidences.length == lines.length;
    final ingredients = [
      for (var i = 0; i < lines.length; i++)
        if (lines[i].trim().isNotEmpty)
          _toParsedIngredient(
            lines[i],
            reviewed ? confidences[i] : ParseConfidence.medium,
          ),
    ];

    return ParsedRecipe(
      title: recipe.title.trim().isNotEmpty
          ? FieldResult.success(recipe.title)
          : FieldResult.failed('No title'),
      portions: recipe.portions != null
          ? FieldResult.success(recipe.portions!)
          : FieldResult.failed('No portions'),
      ingredients: ingredients.isNotEmpty
          ? FieldResult.success(ingredients)
          : FieldResult.failed('No ingredients'),
      instructions: recipe.instructions.isNotEmpty
          ? FieldResult.success(recipe.instructions)
          : FieldResult.failed('No instructions'),
      totalTime: recipe.timeMinutes != null
          ? FieldResult.success(Duration(minutes: recipe.timeMinutes!))
          : FieldResult.failed('No time'),
      description: recipe.description.trim().isEmpty
          ? null
          : recipe.description,
      metadata: ParseMetadata(
        source: source,
        domain: domain,
        tierResults: const [],
        totalParseTime: Duration.zero,
        parserVersion: reviewed ? reviewParserVersion : snapshotParserVersion,
        timestamp: clock.now(),
      ),
    );
  }

  /// Structure one ingredient line the same way the diff calculator structures
  /// the corrected side, so an untouched line compares equal on both sides.
  static ParsedIngredient _toParsedIngredient(
    String line,
    ParseConfidence confidence,
  ) {
    final parsed = IngredientParser.parseIngredient(line);
    return ParsedIngredient(
      name: parsed.name,
      originalLine: line,
      quantity: parsed.quantity.toString(),
      unit: parsed.unit.isEmpty ? null : parsed.unit,
      confidence: confidence,
    );
  }

  static List<ParseConfidence>? _keptConfidences(
    ParsedRecipe? previous,
    Recipe recipe,
  ) {
    if (previous == null ||
        previous.metadata.parserVersion != reviewParserVersion) {
      return null;
    }
    final rows = previous.ingredients.value;
    final lines = recipe.ingredients;
    if (rows == null || lines.any((l) => l.trim().isEmpty)) return null;
    if (rows.length != lines.length) return null;
    for (var i = 0; i < lines.length; i++) {
      if (rows[i].originalLine != lines[i]) return null;
    }
    return [for (final row in rows) row.confidence];
  }

  static List<ParseConfidence>? _unreadConfidences(Recipe recipe) {
    final unread = [
      for (final line in recipe.ingredients) UnreadLineDetector.isUnread(line),
    ];
    if (!unread.contains(true)) return null;
    return [
      for (final u in unread) u ? ParseConfidence.failed : ParseConfidence.medium,
    ];
  }
}
