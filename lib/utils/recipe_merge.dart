import 'package:butlery/models/recipe/recipe_ingredient.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/utils/text/structured_ingredient_deriver.dart';

/// Joins import blocks that the splitter wrongly cut out of one recipe
/// (BUT-1817), so the picker can undo a false split before anything is saved.
class RecipeMerge {
  RecipeMerge._();

  /// Merges [parts] in order into the first part.
  ///
  /// The first part keeps its identity, title, description, photos and
  /// source. Ingredients and instructions are concatenated. A later part's
  /// title becomes the section of its unsectioned ingredient rows, so the
  /// title the false split produced still shows as a sub-heading.
  ///
  /// Preview tags and normalized ingredients are cleared: they describe the
  /// first part's ingredients only, and save re-derives both from the full
  /// list. Keeping them would let the first block's allergen verdict stand
  /// for ingredients it never saw.
  static Recipe merge(List<Recipe> parts) {
    if (parts.isEmpty) {
      throw ArgumentError.value(parts, 'parts', 'must not be empty');
    }
    if (parts.length == 1) return parts.single;

    final first = parts.first;
    final ingredients = <String>[];
    final structured = <RecipeIngredient>[];
    final instructions = <String>[];
    for (final (i, part) in parts.indexed) {
      final entries = StructuredIngredientDeriver.deriveAll(
        part.ingredients,
        reuse: part.core.structuredIngredients,
      );
      ingredients.addAll(part.ingredients);
      structured.addAll(
        i == 0
            ? entries
            : [
                for (final e in entries)
                  e.section == null ? e.copyWithSection(part.title) : e,
              ],
      );
      instructions.addAll(part.instructions);
    }

    return first.copyWith(
      ingredients: ingredients,
      structuredIngredients: structured,
      instructions: instructions,
      portions: _firstNonNull(parts.map((p) => p.portions)),
      timeMinutes: _firstNonNull(parts.map((p) => p.timeMinutes)),
      tagResult: null,
      ingredientsNormalized: null,
    );
  }

  static int? _firstNonNull(Iterable<int?> values) {
    for (final v in values) {
      if (v != null) return v;
    }
    return null;
  }
}
