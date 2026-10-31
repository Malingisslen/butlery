import 'package:clock/clock.dart';

import 'package:butlery/models/recipe/source_artefact.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/import/import_strategy.dart';
import 'package:butlery/services/import/text_import_strategy.dart';

/// Reads the text under a post, or a video's transcript, with the rule-based
/// text parser before any AI is asked, the same order a photo gets.
///
/// The text parser can report success with no ingredients and no steps, so
/// its success alone never counts as having found a recipe: [holdsRecipe] is
/// the bar every caller holds a rules read to.
class CaptionRulesReader {
  CaptionRulesReader({TextImportStrategy? text}) : _text = text;

  final TextImportStrategy? _text;

  static const _minIngredients = 2;
  static const _maxTitleLength = 100;

  /// Whether a rules read holds a recipe worth keeping without AI.
  static bool foundRecipe(ImportResult result) =>
      result.isSuccess && holdsRecipe(result.recipe);

  /// The bar itself, for a caller that holds the recipe without its result.
  static bool holdsRecipe(Recipe? recipe) {
    if (recipe == null) return false;
    final ingredients = recipe.ingredients.where((i) => i.trim().isNotEmpty);
    final steps = recipe.instructions.where((s) => s.trim().isNotEmpty);
    return ingredients.length >= _minIngredients && steps.isNotEmpty;
  }

  /// The recipe the rules find in [text], or null when they find none.
  ///
  /// The recipe keeps the RAW [text] as its [artefactType] artefact, so a
  /// later re-read starts from what was fetched, and links back to
  /// [sourceUrl]. [fallbackTitle] replaces a title the rules left empty or
  /// made from a hashtag line or a whole paragraph.
  Future<Recipe?> read(
    String text, {
    required SourceArtefactType artefactType,
    required String sourceUrl,
    String? fallbackTitle,
  }) async {
    final result = await (_text ?? TextImportStrategy()).import(text);
    if (!foundRecipe(result)) return null;
    final recipe = result.recipe!;
    return recipe.copyWith(
      title: _usableTitle(recipe.title) ?? fallbackTitle ?? recipe.title,
      sourceUrl: sourceUrl,
      sourceArtefact: SourceArtefact(
        type: artefactType,
        payload: text,
        fetchedAt: clock.now(),
      ),
    );
  }

  static String? _usableTitle(String title) {
    final t = title.trim();
    if (t.isEmpty || t.length >= _maxTitleLength || t.contains('#')) {
      return null;
    }
    return t;
  }
}
