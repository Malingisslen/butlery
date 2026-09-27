/// P5-U27b: where suggestions to someone else's shared recipe are kept for 7
/// days.
///
/// See `RecipeSuggestion` for the rule and the storage path. Every call acts
/// as the signed-in user: they can make a suggestion only as themselves, list
/// only the suggestions they made or the ones made to their own recipes, and
/// decide only the ones made to their own recipes.
library;

import 'package:clock/clock.dart';

import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/models/recipe_suggestion.dart';

abstract class RecipeSuggestionRepository {
  /// Stores [suggestion] as the signed-in user's and returns it with its id.
  /// Throws when nobody is signed in, when [suggestion] is someone else's, or
  /// when it is made to the user's own recipe.
  Future<RecipeSuggestion> suggest(RecipeSuggestion suggestion);

  /// Q6-12 = B: the signed-in user replaces their own pending suggestion with
  /// [replacement] (made by RecipeSuggestion.replacedWith), under the same
  /// id. Throws when it is someone else's or no longer pending.
  Future<RecipeSuggestion> replace(RecipeSuggestion replacement);

  /// The suggestions the signed-in user made to [recipeId], newest first.
  Stream<List<RecipeSuggestion>> watchMine(String recipeId);

  /// The suggestions others made to the signed-in user's recipe [recipeId],
  /// newest first.
  Stream<List<RecipeSuggestion>> watchToMe(String recipeId);

  /// Records the owner's decision on one suggestion made to their recipe.
  /// [status] is accepted or dismissed, never pending.
  Future<void> decide(String suggestionId, RecipeSuggestionStatus status);
}

/// Q6-12 = B: how a member's edit is kept, over any store.
extension RecipeSuggestionKeeping on RecipeSuggestionRepository {
  /// One pending suggestion per member and recipe (Q6-07 = B), and a new
  /// one replaces the waiting one (Q6-12 = B): [suggestion] replaces the
  /// suggester's pending suggestion to [recipeId] when there is one, and is
  /// stored as a new suggestion otherwise. The editor
  /// (RecipeSuggestionService.suggestEdit) and the conflict path
  /// (RealtimeSyncService._keepAsSuggestion) both keep a suggestion here.
  ///
  /// When the waiting one was decided in the meantime, the replacement is
  /// refused and the edit is stored as a new suggestion instead, so the edit
  /// is never lost to that race.
  Future<RecipeSuggestion> keepOrReplace({
    required String recipeId,
    required String ownerId,
    required String suggesterId,
    required Map<String, dynamic> suggestion,
  }) async {
    final now = clock.now();
    final waiting = RecipeSuggestion.waitingAmong(
      await watchMine(recipeId).first,
      now,
    );
    if (waiting != null) {
      try {
        return await replace(
          waiting.replacedWith(suggestion, at: now),
        );
      } on PermissionDeniedException {
        // Decided or gone since it was read: fall through to a new one.
      }
    }
    return suggest(
      RecipeSuggestion.create(
        recipeId: recipeId,
        ownerId: ownerId,
        suggesterId: suggesterId,
        suggestion: suggestion,
        at: now,
      ),
    );
  }
}
