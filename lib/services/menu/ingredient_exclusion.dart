import 'package:butlery/models/menu/dislike_vocabulary.dart';
import 'package:butlery/models/recipe_unified.dart';

/// Decides whether a recipe contains an ingredient the prompt excluded with
/// "utan X", by the same token rule as a disliked ingredient, so "utan lök"
/// and "ogillar lök" give one answer. A substring test made "utan lök" drop
/// every vitlök recipe and missed inflected forms.
class IngredientExclusion {
  const IngredientExclusion._();

  /// A word the dislike vocabulary knows is matched by its table
  /// ([DislikeVocabulary.recipeContainsAny]). Any other word is free text
  /// from the prompt and has no table entry, so a token hits when it starts
  /// with the word, as a dislike prefix does. That over-excludes ("ost" also
  /// drops ostron), which is the safe direction for an explicit "utan".
  static bool recipeContainsWord(Recipe recipe, String word) {
    final w = word.toLowerCase();
    if (DislikeVocabulary.keys.contains(w)) {
      return DislikeVocabulary.recipeContainsAny(recipe, {w});
    }
    for (final line in recipe.ingredients) {
      for (final token in _tokens(line)) {
        if (token.startsWith(w)) return true;
      }
    }
    return false;
  }

  // Same letter set as DislikeVocabulary, so a token means one thing in both.
  static final RegExp _nonLetter = RegExp(r'[^a-zåäöéèüñ]+');

  static List<String> _tokens(String line) =>
      line.toLowerCase().split(_nonLetter).where((t) => t.isNotEmpty).toList();
}
