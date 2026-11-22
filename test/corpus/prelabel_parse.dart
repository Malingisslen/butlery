/// Parses stored OCR text with the app's real importer into draft recipes.
/// Shared by the prelabel and re-derive harnesses so both measure the same
/// parser path.
library;

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/services/parsing/ingredient_parsing_strategy.dart';

import '../../tools/corpus/corpus_models.dart';

/// Parse one page's OCR text into N draft recipes via the multi-recipe path.
/// Returns one draft for a single-recipe page, several for a cookbook spread,
/// or a single title-only fallback when nothing parsed.
Future<List<GoldRecipe>> parseOcrToDrafts(
  ImportManager importManager,
  IngredientParsingStrategy ingredientParser,
  String ocrText,
) async {
  List<Recipe> recipes = const [];
  try {
    final result = await importManager.autoParseMulti(ocrText);
    recipes = result.successfulRecipes;
  } catch (_) {
    // Fall through to the title-only fallback below.
  }

  if (recipes.isEmpty) {
    return [
      GoldRecipe(
        verified: false,
        title: _firstNonEmptyLine(ocrText),
        ingredients: const [],
        instructions: const [],
        sourcePages: const ['page-01.jpg'],
      ),
    ];
  }

  final drafts = <GoldRecipe>[];
  for (final recipe in recipes) {
    drafts.add(await recipeToGold(ingredientParser, recipe));
  }
  return drafts;
}

Future<GoldRecipe> recipeToGold(
  IngredientParsingStrategy ingredientParser,
  Recipe recipe,
) async {
  final ingredients = <GoldIngredient>[];
  for (final line in recipe.ingredients) {
    ingredients.add(await structureLine(ingredientParser, line));
  }
  return GoldRecipe(
    verified: false,
    title: recipe.title,
    portions: recipe.portions?.toString(),
    timeMinutes: _totalTime(recipe),
    ingredients: ingredients,
    instructions: recipe.instructions,
    sourcePages: const ['page-01.jpg'],
  );
}

Future<GoldIngredient> structureLine(
  IngredientParsingStrategy parser,
  String line,
) async {
  try {
    // ocrCorrection mirrors the production photo path (TextImportStrategy now
    // corrects too) so the corpus measures the same text the app would parse.
    final p = await parser.parseLine(line, ocrCorrection: true);
    return GoldIngredient(
      name: p.name.isEmpty ? line : p.name,
      originalLine: p.originalLine.isEmpty ? line : p.originalLine,
      quantity: p.quantity,
      unit: p.unit,
      size: p.size,
      preparation: p.preparation,
    );
  } catch (_) {
    // Structuring is best-effort; a name-only ingredient is still a usable seed.
    return GoldIngredient(name: line, originalLine: line);
  }
}

int? _totalTime(Recipe? r) {
  if (r == null) return null;
  final prep = r.prepTimeMinutes ?? 0;
  final cook = r.cookTimeMinutes ?? 0;
  final total = prep + cook;
  if (total > 0) return total;
  // The TEXT/photo path never fills the split prep/cook fields — it writes a
  // single `timeMinutes` (TextImportStrategy._extractTime). Reading only
  // prep+cook made the eval report 0.0% time accuracy for every photographed
  // page regardless of what the parser found: a broken yardstick, not a
  // measured failure. Fall back to the field that path actually populates.
  return r.timeMinutes;
}

String _firstNonEmptyLine(String text) => text
    .split('\n')
    .map((l) => l.trim())
    .firstWhere((l) => l.isNotEmpty, orElse: () => 'Namnlöst recept');
