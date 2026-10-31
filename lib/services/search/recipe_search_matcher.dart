import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/services/tagging/config/allergen_config.dart';
import 'package:butlery/services/tagging/config/dietary_config.dart';
import 'package:butlery/services/tagging/tag_display_utils.dart';
import 'package:butlery/utils/text/swedish_character_normalizer.dart';

/// The one rule every recipe search box in the app uses, so a recipe found in
/// the recipe list is also found when adding to the weekly menu.
///
/// Every word of the query must appear somewhere in the recipe, but the words
/// may land in different places: "kyckling ugn" finds a recipe whose
/// ingredient is chicken and whose auto tag is "ugnsbakad".
class RecipeSearchMatcher {
  RecipeSearchMatcher._();

  static List<Recipe> filter(List<Recipe> recipes, String query) {
    final words = queryWords(query);
    // A copy either way: callers sort the result in place.
    if (words.isEmpty) return List.of(recipes);
    return recipes.where((r) => _matchesWords(r, words)).toList();
  }

  static bool matches(Recipe recipe, String query) {
    final words = queryWords(query);
    return words.isEmpty || _matchesWords(recipe, words);
  }

  static List<String> queryWords(String query) => fold(
    query,
  ).split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

  /// Search-only folding. [SwedishCharacterNormalizer] is a contract shared
  /// with the server and must not change, so the extra accents live here.
  static String fold(String input) {
    final swedish = SwedishCharacterNormalizer.normalize(input);
    if (swedish.codeUnits.every((unit) => unit < 128)) return swedish;
    final buffer = StringBuffer();
    for (final rune in swedish.runes) {
      final char = String.fromCharCode(rune);
      buffer.write(_accentFolds[char] ?? char);
    }
    return buffer.toString();
  }

  static const Map<String, String> _accentFolds = {
    'á': 'a',
    'à': 'a',
    'â': 'a',
    'ã': 'a',
    'æ': 'ae',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'í': 'i',
    'ì': 'i',
    'î': 'i',
    'ï': 'i',
    'ó': 'o',
    'ò': 'o',
    'ô': 'o',
    'õ': 'o',
    'ø': 'o',
    'ú': 'u',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ç': 'c',
    'ñ': 'n',
    'ß': 'ss',
  };

  /// Folds the recipe's text only as far as needed: runs on every keystroke
  /// over the whole library, and most recipes miss on an early field.
  static bool _matchesWords(Recipe recipe, List<String> words) {
    final folded = <String>[];
    final source = searchableText(recipe).iterator;
    bool contains(String word) {
      if (folded.any((text) => text.contains(word))) return true;
      while (source.moveNext()) {
        final text = fold(source.current);
        folded.add(text);
        if (text.contains(word)) return true;
      }
      return false;
    }

    return words.every(
      (word) => contains(word) || _matchesNumber(recipe, word),
    );
  }

  /// Everything a person can see on the recipe and might type to find it.
  static Iterable<String> searchableText(Recipe recipe) sync* {
    yield recipe.title;
    yield recipe.description;
    yield recipe.mealType;
    yield* recipe.ingredients;
    yield* recipe.instructions;
    final cuisine = recipe.cuisine;
    if (cuisine != null) yield cuisine;
    final author = recipe.sourceAuthor;
    if (author != null) yield author;
    // Personal tags and cookbooks: a cookbook is a personal tag, and a rename
    // is written through to every recipe that carries it.
    for (final tag in recipe.core.personalTags ?? const []) {
      yield tag.name;
    }
    yield* _autoTagText(recipe);
  }

  /// The auto tags the recipe page shows, after the person's own edits, both
  /// as the stored word ("pasta-dish") and as shown ("Pasta").
  static Iterable<String> _autoTagText(Recipe recipe) sync* {
    final result = recipe.tagResult;
    final overrides = recipe.tagOverrides;
    final autoTags = result?.tags ?? const <String>{};
    final tags =
        overrides?.getEffectiveTags(autoTags.toSet()) ?? autoTags.toSet();
    for (final tag in tags) {
      yield tag;
      yield TagDisplayUtils.getDisplayName(tag);
    }
    if (result == null) return;

    for (final diet in DietaryConfig.all) {
      final status =
          overrides?.dietaryOverrides[diet.key] ??
          result.dietaryStatus[diet.key];
      if (status == TriState.free) yield diet.tagSv;
    }
    for (final allergen in AllergenConfig.all) {
      final freeTag = allergen.freeTag;
      if (freeTag == null) continue;
      final status =
          overrides?.allergenOverrides[allergen.key] ??
          result.allergenStatus[allergen.key];
      if (status == TriState.free) yield freeTag;
    }
  }

  static bool _matchesNumber(Recipe recipe, String word) {
    if (double.tryParse(word) == null) return false;
    return [
      recipe.portions,
      recipe.timeMinutes,
      recipe.rating,
    ].any((value) => value != null && value.toString().contains(word));
  }
}
