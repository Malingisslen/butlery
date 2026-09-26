/// P5-U27b: where suggestions to someone else's shared recipe are kept for 7
/// days.
///
/// See `RecipeSuggestion` for the rule and the storage path. Every call acts
/// as the signed-in user: they can make a suggestion only as themselves, list
/// only the suggestions they made or the ones made to their own recipes, and
/// decide only the ones made to their own recipes.
library;

import 'package:butlery/models/recipe_suggestion.dart';

abstract class RecipeSuggestionRepository {
  /// Stores [suggestion] as the signed-in user's and returns it with its id.
  /// Throws when nobody is signed in, when [suggestion] is someone else's, or
  /// when it is made to the user's own recipe.
  Future<RecipeSuggestion> suggest(RecipeSuggestion suggestion);

  /// The suggestions the signed-in user made to [recipeId], newest first.
  Stream<List<RecipeSuggestion>> watchMine(String recipeId);

  /// The suggestions others made to the signed-in user's recipe [recipeId],
  /// newest first.
  Stream<List<RecipeSuggestion>> watchToMe(String recipeId);

  /// Records the owner's decision on one suggestion made to their recipe.
  /// [status] is accepted or dismissed, never pending.
  Future<void> decide(String suggestionId, RecipeSuggestionStatus status);
}
