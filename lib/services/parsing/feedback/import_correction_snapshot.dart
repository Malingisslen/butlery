import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/parsing/field_result.dart';
import 'package:butlery/models/parsing/parse_metadata.dart';
import 'package:butlery/models/parsing/parsed_ingredient.dart';
import 'package:butlery/models/parsing/parsed_recipe.dart';
import 'package:butlery/models/recipe_unified.dart';
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
/// The snapshot carries no genuine per-field confidence — it exists only to
/// anchor the edit diff — so it is stamped with [snapshotParserVersion]. The
/// form uses that sentinel to keep the per-ingredient confidence UI and the
/// import-source analytics limited to real parses (URL today).
class ImportCorrectionSnapshot {
  ImportCorrectionSnapshot._();

  /// Parser-version sentinel marking a snapshot built from an already-produced
  /// recipe rather than a genuine multi-tier parse. Lets the form distinguish
  /// "anchor for correction diffing" from "real per-field confidence".
  static const String snapshotParserVersion = 'import-snapshot-v1';

  /// Build a snapshot for [recipe] and store it in the shared cache keyed by
  /// recipe id. Best-effort: a missing cache (e.g. tests without DI) or any
  /// failure is swallowed so capture never disturbs the import path.
  static void capture(
    Recipe recipe, {
    required ImportSource source,
    String? domain,
    ParsedRecipeCache? cache,
  }) {
    if (recipe.id.isEmpty) return;
    try {
      final target = cache ?? ServiceLocator.tryGet<ParsedRecipeCache>();
      if (target == null) return;
      target.store(recipe.id, build(recipe, source: source, domain: domain));
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
  }) {
    final ingredients = [
      for (final line in recipe.ingredients)
        if (line.trim().isNotEmpty) _toParsedIngredient(line),
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
        parserVersion: snapshotParserVersion,
        timestamp: clock.now(),
      ),
    );
  }

  /// Structure one ingredient line the same way the diff calculator structures
  /// the corrected side, so an untouched line compares equal on both sides.
  static ParsedIngredient _toParsedIngredient(String line) {
    final parsed = IngredientParser.parseIngredient(line);
    return ParsedIngredient(
      name: parsed.name,
      originalLine: line,
      quantity: parsed.quantity.toString(),
      unit: parsed.unit.isEmpty ? null : parsed.unit,
      confidence: ParseConfidence.medium,
    );
  }
}
