/// P5-U27b: suggestions to someone else's shared recipe, for 7 days.
///
/// produktregler.md:103 (the owner's version wins, the change becomes a
/// suggestion, "Se ditt förslag", 7 days) and :241 (the owner accepts or
/// dismisses it). RealtimeSyncService stores the suggestion when a
/// non-owner's edit meets the owner's; this service lists the ones still kept
/// and carries out the owner's decision.
///
/// Q6-08 = A (produktbeslut 2026-09-27; produktregler.md:241, :246): a member
/// never writes someone else's recipe. Every edit a member saves in the
/// recipe editor becomes a suggestion here ([suggestEdit]), not only the one
/// that meets the owner's save. Q6-07 = B: a member has at most one pending
/// suggestion per recipe; while it waits, no second one is made.
///
/// Which recipe a suggestion is taken into: the owner's own recipe in their
/// library (users/{owner}/recipes/{id}, the one recipe detail shows and the
/// only one firestore.rules lets the owner alone write) when the owner has
/// it, otherwise the recipe's realtime resource, where P5-U27b's conflict
/// path made it.
///
/// Accepting writes the suggested content onto the recipe as the owner. Into
/// the library recipe it takes the text content only (title, description,
/// ingredients, steps, portions, time and meal type) and keeps everything
/// else, sharing included. Into the realtime resource it goes on top of the
/// current version's edit counter so it wins the next comparison
/// (RealtimeSyncService.recoverLocalVersion), and keeps who the recipe is
/// shared with as it is now: a suggestion never changes access. Dismissing
/// writes nothing to the recipe.
library;

import 'package:clock/clock.dart';

import 'package:butlery/core/providers/application_provider.dart';

import 'package:butlery/models/realtime/realtime_recipe.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/realtime/realtime_resource.dart';
import 'package:butlery/models/recipe_suggestion.dart';
import 'package:butlery/repositories/interfaces/recipe_suggestion_repository.dart';
import 'package:butlery/services/realtime/overwritten_version_service.dart';
import 'package:butlery/services/realtime/realtime_types.dart';
import 'package:butlery/services/realtime_sync_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';

/// Thrown when the recipe a suggestion is for no longer exists or is no
/// longer shared, so there is nothing to accept it into. The suggestion is
/// left as it was.
class RecipeSuggestionTargetMissing implements Exception {
  const RecipeSuggestionTargetMissing(this.recipeId);

  final String recipeId;

  @override
  String toString() => 'RecipeSuggestionTargetMissing($recipeId)';
}

/// Q6-07 = B: the member already has a suggestion to this recipe that waits
/// for the owner, so no second one is made. Nothing is stored; the edit is
/// still the member's to keep.
class RecipeSuggestionAlreadyWaiting implements Exception {
  const RecipeSuggestionAlreadyWaiting(this.waiting);

  final RecipeSuggestion waiting;

  @override
  String toString() => 'RecipeSuggestionAlreadyWaiting(${waiting.id})';
}

/// Reads the signed-in owner's own recipe [recipeId] from their library, or
/// null when they do not have it.
typedef OwnRecipeReader = Future<Recipe?> Function(String recipeId);

/// Writes the signed-in owner's own recipe, the way their own editor does.
/// Throws when the write did not go through.
typedef OwnRecipeWriter = Future<void> Function(Recipe recipe);

class RecipeSuggestionService {
  RecipeSuggestionService({
    required RecipeSuggestionRepository repository,
    required RealtimeSyncService syncService,
    OwnRecipeReader? readOwnRecipe,
    OwnRecipeWriter? writeOwnRecipe,
  }) : _repository = repository,
       _sync = syncService,
       _readOwn = readOwnRecipe,
       _writeOwn = writeOwnRecipe;

  final RecipeSuggestionRepository _repository;
  final RealtimeSyncService _sync;
  final OwnRecipeReader? _readOwn;
  final OwnRecipeWriter? _writeOwn;

  /// The fields a suggestion carries into the owner's library recipe, and
  /// the ones the suggestion view compares, in the order it shows them.
  /// Identity, sharing, images, tags, ratings and cook counts stay the
  /// owner's.
  static const List<String> contentFields = [
    'title',
    'description',
    'ingredients',
    'instructions',
    'portions',
    'timeMinutes',
    'mealType',
  ];

  static Map<String, Object?> _content(Recipe r) => {
    'title': r.title,
    'description': r.description,
    'ingredients': r.ingredients,
    'instructions': r.instructions,
    'portions': r.portions,
    'timeMinutes': r.timeMinutes,
    'mealType': r.mealType,
  };

  /// Q6-08 = A: [suggesterId]'s edit of [ownerId]'s recipe, saved from the
  /// recipe editor, becomes a pending suggestion; nothing is written to the
  /// recipe. Throws [RecipeSuggestionAlreadyWaiting] when the member already
  /// has one waiting for this recipe (Q6-07 = B), and whatever the store
  /// throws when it cannot be kept.
  Future<RecipeSuggestion> suggestEdit({
    required Recipe edited,
    required String ownerId,
    required String suggesterId,
  }) async {
    final waiting = RecipeSuggestion.waitingAmong(
      await _repository.watchMine(edited.id).first,
      clock.now(),
    );
    if (waiting != null) throw RecipeSuggestionAlreadyWaiting(waiting);
    final shaped = RealtimeRecipe.fromRecipe(
      recipe: edited,
      ownerId: ownerId,
      ownerDisplayName: '',
    ).copyWithMetadata(lastEditedBy: suggesterId);
    return _repository.suggest(
      RecipeSuggestion.create(
        recipeId: edited.id,
        ownerId: ownerId,
        suggesterId: suggesterId,
        suggestion: shaped.toFirestore(),
        at: clock.now(),
      ),
    );
  }

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

  /// The name to show for who made [suggestion], or empty when it is not
  /// known. Resolved from [RecipeSuggestion.suggesterId], which
  /// firestore.rules pins to the writer's own account, through the signed-in
  /// user's friends (the people a recipe is shared with); never from text the
  /// suggester stored, so a member cannot pose as someone else.
  static String suggesterNameOf(RecipeSuggestion suggestion) {
    final friends = ServiceLocator.tryGet<UnifiedFriendsService>();
    if (friends == null) return '';
    for (final f in friends.friendsList) {
      if (f.uid == suggestion.suggesterId) return f.displayName.trim();
    }
    return '';
  }

  /// [rows] without those whose 7 days have passed at [clock.now]. The app
  /// stops offering a suggestion at its expiry even before the TTL sweep.
  static List<RecipeSuggestion> stillKept(List<RecipeSuggestion> rows) {
    final now = clock.now();
    return [
      for (final s in rows)
        if (s.isKeptAt(now)) s,
    ];
  }

  /// What [suggestion] changes against the recipe as it is now, field by
  /// field over [contentFields]. Throws [RecipeSuggestionTargetMissing] when
  /// the recipe is gone.
  Future<ConflictDiff> diffAgainstLive(RecipeSuggestion suggestion) async {
    final target = await _target(suggestion.recipeId);
    final current = target.own ?? _recipeOf(target.live!);
    if (current == null) {
      return ConflictDiff.fromMaps(
        suggestion.suggestion,
        target.live!.toFirestore(),
      );
    }
    return ConflictDiff.fromMaps(
      _content(_suggested(suggestion)),
      _content(current),
    );
  }

  /// The owner accepts [suggestion]: its content becomes the recipe's, with
  /// the sharing the recipe has now, and the row records the decision.
  Future<void> accept(RecipeSuggestion suggestion) async {
    final target = await _target(suggestion.recipeId);
    final own = target.own;
    if (own != null) {
      final s = _suggested(suggestion);
      await _writeOwn!(
        own.copyWith(
          title: s.title,
          description: s.description,
          ingredients: s.ingredients,
          instructions: s.instructions,
          portions: s.portions,
          timeMinutes: s.timeMinutes,
          mealType: s.mealType,
        ),
      );
    } else {
      final suggested = RealtimeRecipe.fromMap(
        suggestion.recipeId,
        suggestion.suggestion,
      );
      await _sync.recoverLocalVersion<RealtimeResource>(
        OverwrittenVersionService.withSharingOf(suggested, target.live!),
      );
    }
    await _repository.decide(suggestion.id, RecipeSuggestionStatus.accepted);
  }

  /// The owner dismisses [suggestion]. Nothing is written to the recipe.
  Future<void> dismiss(RecipeSuggestion suggestion) =>
      _repository.decide(suggestion.id, RecipeSuggestionStatus.dismissed);

  static Recipe _suggested(RecipeSuggestion suggestion) =>
      RealtimeRecipe.fromMap(suggestion.recipeId, suggestion.suggestion).recipe;

  static Recipe? _recipeOf(RealtimeResource live) =>
      live is RealtimeRecipe ? live.recipe : null;

  /// The owner's library recipe when they have it and it can be written,
  /// otherwise the active realtime resource.
  Future<({Recipe? own, RealtimeResource? live})> _target(
    String recipeId,
  ) async {
    final readOwn = _readOwn;
    if (readOwn != null && _writeOwn != null) {
      final own = await readOwn(recipeId);
      if (own != null) return (own: own, live: null);
    }
    final current = await _sync.fetchLatestResource<RealtimeResource>(
      recipeId,
    );
    if (current == null || !current.isActive) {
      throw RecipeSuggestionTargetMissing(recipeId);
    }
    return (own: null, live: current);
  }
}
