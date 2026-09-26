/// P5-U27b: suggestions to someone else's shared recipe, for 7 days.
///
/// produktregler.md:103 (the owner's version wins, the change becomes a
/// suggestion, "Se ditt förslag", 7 days) and :241 (the owner accepts or
/// dismisses it). RealtimeSyncService stores the suggestion when a
/// non-owner's edit meets the owner's; this service lists the ones still kept
/// and carries out the owner's decision.
///
/// Accepting writes the suggested content onto the recipe as the owner, on
/// top of the current version's edit counter so it wins the next comparison
/// (RealtimeSyncService.recoverLocalVersion), and keeps who the recipe is
/// shared with as it is now: a suggestion never changes access. Dismissing
/// writes nothing to the recipe.
library;

import 'package:clock/clock.dart';

import 'package:butlery/models/realtime/realtime_recipe.dart';
import 'package:butlery/models/realtime/realtime_resource.dart';
import 'package:butlery/models/recipe_suggestion.dart';
import 'package:butlery/repositories/interfaces/recipe_suggestion_repository.dart';
import 'package:butlery/services/realtime/overwritten_version_service.dart';
import 'package:butlery/services/realtime/realtime_types.dart';
import 'package:butlery/services/realtime_sync_service.dart';

/// Thrown when the recipe a suggestion is for no longer exists or is no
/// longer shared, so there is nothing to accept it into. The suggestion is
/// left as it was.
class RecipeSuggestionTargetMissing implements Exception {
  const RecipeSuggestionTargetMissing(this.recipeId);

  final String recipeId;

  @override
  String toString() => 'RecipeSuggestionTargetMissing($recipeId)';
}

class RecipeSuggestionService {
  RecipeSuggestionService({
    required RecipeSuggestionRepository repository,
    required RealtimeSyncService syncService,
  }) : _repository = repository,
       _sync = syncService;

  final RecipeSuggestionRepository _repository;
  final RealtimeSyncService _sync;

  /// The suggestions the signed-in user made to [recipeId] that are still
  /// kept, newest first. Decided ones stay listed until their 7 days end, so
  /// the suggester can see what became of them.
  Stream<List<RecipeSuggestion>> watchMine(String recipeId) =>
      _repository.watchMine(recipeId).map(stillKept);

  /// The pending suggestions others made to the signed-in user's recipe
  /// [recipeId], newest first. Only these ask the owner for a decision.
  Stream<List<RecipeSuggestion>> watchPendingToMe(String recipeId) =>
      _repository
          .watchToMe(recipeId)
          .map(
            (rows) => [
              for (final s in stillKept(rows))
                if (s.isPending) s,
            ],
          );

  /// [rows] without those whose 7 days have passed at [clock.now]. The app
  /// stops offering a suggestion at its expiry even before the TTL sweep.
  static List<RecipeSuggestion> stillKept(List<RecipeSuggestion> rows) {
    final now = clock.now();
    return [
      for (final s in rows)
        if (s.isKeptAt(now)) s,
    ];
  }

  /// What [suggestion] changes against the recipe as it is now. Throws
  /// [RecipeSuggestionTargetMissing] when the recipe is gone.
  Future<ConflictDiff> diffAgainstLive(RecipeSuggestion suggestion) async {
    final current = await _live(suggestion.recipeId);
    return ConflictDiff.fromMaps(
      suggestion.suggestion,
      current.toFirestore(),
    );
  }

  /// The owner accepts [suggestion]: its content becomes the recipe's, with
  /// the sharing the recipe has now, and the row records the decision.
  Future<void> accept(RecipeSuggestion suggestion) async {
    final current = await _live(suggestion.recipeId);
    final suggested = RealtimeRecipe.fromMap(
      suggestion.recipeId,
      suggestion.suggestion,
    );
    await _sync.recoverLocalVersion<RealtimeResource>(
      OverwrittenVersionService.withSharingOf(suggested, current),
    );
    await _repository.decide(suggestion.id, RecipeSuggestionStatus.accepted);
  }

  /// The owner dismisses [suggestion]. Nothing is written to the recipe.
  Future<void> dismiss(RecipeSuggestion suggestion) =>
      _repository.decide(suggestion.id, RecipeSuggestionStatus.dismissed);

  Future<RealtimeResource> _live(String recipeId) async {
    final current = await _sync.fetchLatestResource<RealtimeResource>(
      recipeId,
    );
    if (current == null || !current.isActive) {
      throw RecipeSuggestionTargetMissing(recipeId);
    }
    return current;
  }
}
