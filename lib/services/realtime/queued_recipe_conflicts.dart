// lib/services/realtime/queued_recipe_conflicts.dart
//
// BUT-2213: a queued edit of the user's own recipe that met a newer server
// version (TR::FLOW::08::ko::toms::konfliktbanner). The queue did not write
// it and the device took the server's recipe; this turns the two versions
// into the conflict banner, keeps the device's version behind Återställ for
// 30 days (Malin, 2026-10-08, A1), and writes the user's choice back through
// the recipe's own queue.
//
// `realtime_resources` is never written here (BUT-2151): `RealtimeRecipe` is
// only the in-memory shape the banner and the comparison view read.
library;

import 'package:clock/clock.dart';

import 'package:butlery/core/cache/lru_map.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/models/realtime/overwritten_version.dart';
import 'package:butlery/models/realtime/realtime_recipe.dart';
import 'package:butlery/models/realtime/realtime_resource.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/interfaces/overwritten_version_repository.dart';
import 'package:butlery/services/realtime/conflict_resolution_module.dart';
import 'package:butlery/services/realtime/realtime_types.dart';

/// Saves the user's own recipe the way the recipe editor does, through the
/// offline queue where there is one.
typedef OwnRecipeWriter = Future<void> Function(Recipe recipe);

class QueuedRecipeConflicts {
  QueuedRecipeConflicts({
    required ConflictResolutionModule conflicts,
    required String? Function() currentUserId,
    OverwrittenVersionRepository? overwrittenVersions,
    OwnRecipeWriter? writeOwnRecipe,
  }) : _conflicts = conflicts,
       _currentUserId = currentUserId,
       _overwrittenVersions = overwrittenVersions,
       _writeOwnRecipe = writeOwnRecipe;

  final ConflictResolutionModule _conflicts;
  final String? Function() _currentUserId;
  final OverwrittenVersionRepository? _overwrittenVersions;
  final OwnRecipeWriter? _writeOwnRecipe;

  /// The notices the user has neither chosen on nor closed, by recipe id, so
  /// a recipe screen opened after the queue emptied still shows its banner.
  static const int _pendingMaxSize = 50;
  final LruMap<String, ConflictEvent> _pending = LruMap(
    maxSize: _pendingMaxSize,
  );

  /// The device's version [local] was not written because the server had
  /// moved on to [remote]. Keeps [local] and announces the conflict.
  Future<void> announce(Recipe local, Recipe remote) async {
    final userId = _currentUserId();
    final mine = asResource(local, userId);
    final theirs = asResource(remote, userId);
    // Who the recipe is shared with is not kept: a restore takes the
    // sharing the recipe has then (OverwrittenVersionService).
    if (userId != null) {
      await _keep(userId, asResource(_withoutSharing(local), userId), theirs);
    }
    _conflicts.announceQueuedRecipe<RealtimeRecipe>(mine, theirs);
  }

  /// A queue notice the banner has shown: held until the user chooses or
  /// closes it.
  void remember(ConflictEvent event) {
    if (event.origin != ConflictOrigin.queue) return;
    _pending[event.docId] = event;
  }

  ConflictEvent? pendingFor(String recipeId) => _pending.peek(recipeId);

  void forget(String recipeId) => _pending.remove(recipeId);

  void clear() => _pending.clear();

  /// "Behåll min version": the device's version is saved again, now built on
  /// the server's revision, through the recipe's own queue.
  Future<void> keepLocal(ConflictEvent event) async {
    final write = _writeOwnRecipe;
    if (write == null) throw StateError('No recipe writer is attached');
    final local = (event.localValue as RealtimeRecipe).recipe;
    final remote = (event.remoteValue as RealtimeRecipe).recipe;
    await write(local.copyWith(rev: remote.rev));
    forget(event.docId);
  }

  /// A1 (Malin, 2026-10-08): the device's version never reached the server,
  /// so it is kept for 30 days whoever made the newer one, the user's own
  /// other device included. This differs from the realtime path, which
  /// keeps nothing when the winner is the user's own save. A failure is
  /// logged; the notice still carries the version.
  Future<void> _keep(
    String userId,
    RealtimeRecipe lost,
    RealtimeRecipe winner,
  ) async {
    final store = _overwrittenVersions;
    if (store == null) return;
    try {
      await store.keep(
        OverwrittenVersion.capture(
          ownerId: userId,
          entity: ConflictEntity.recipeOwn,
          lost: lost,
          winner: winner,
          at: clock.now(),
        ),
      );
    } catch (e) {
      AppLogger.error(
        '❌ Den köade versionen kunde inte sparas för ${lost.id}',
        e,
      );
    }
  }

  static Recipe _withoutSharing(Recipe recipe) => Recipe(
    core: recipe.core,
    type: recipe.type,
    realtimeData: recipe.realtimeData,
    offlineData: recipe.offlineData,
    rev: recipe.rev,
  );

  /// [recipe] in the shape the banner and the comparison view read, with
  /// who saved it last from its own `realtimeData`.
  static RealtimeRecipe asResource(Recipe recipe, String? fallbackOwnerId) {
    final ownerId =
        (recipe.socialData?.ownerId ?? recipe.createdBy ?? fallbackOwnerId)
            .orEmpty();
    final edit = recipe.realtimeData;
    return RealtimeRecipe(
      id: recipe.id,
      ownerId: ownerId,
      ownerDisplayName: (recipe.socialData?.ownerDisplayName).orEmpty(),
      participants: {ownerId: ResourcePermission.owner},
      createdAt: recipe.core.createdAt,
      lastEditedAt: edit?.lastEditedAt ?? recipe.core.updatedAt,
      lastEditedBy: edit?.lastEditedByUserId ?? ownerId,
      lastEditedByDisplayName: (edit?.lastEditedByDisplayName).orEmpty(),
      editCount: recipe.rev ?? 0,
      recipe: recipe,
    );
  }
}
