// lib/services/offline/queued_recipe_writer.dart
//
// BUT-2162: what the offline queue's sender calls to put a recipe write on
// the server.
library;

import 'package:butlery/models/recipe_unified.dart';

/// Told of a queued edit the server did not take because its recipe had
/// moved on (BUT-2213): [local] is the device's version, [remote] the
/// server's.
typedef RecipeConflictCallback = void Function(Recipe local, Recipe remote);

/// Writes one queued recipe change to the server.
///
/// Every method throws when the write did not reach the server, so the queue
/// can tell a failure it retries from one that waits for the user
/// (`permanentFailureReason`). The production writer goes through
/// `FirebaseRecipeRepository`, which sanitizes, normalizes and caps sharing
/// for every write to the collection (BUT-1819, BUT-955).
abstract interface class QueuedRecipeWriter {
  /// Writes [recipe] as a new document. Sending it twice gives the same
  /// document: the write replaces the whole recipe on its own id.
  Future<void> create(Recipe recipe);

  /// Writes [recipe] over the server's copy while the server is still at
  /// the revision [recipe] was built on ([Recipe.rev]; null is not
  /// compared), and returns the server's revision after the write. Throws
  /// `RecipeRevisionConflictException` when the server has moved on
  /// (BUT-2213).
  Future<int> update(Recipe recipe);

  /// Deletes the recipe and what hangs off it (images, comments, ratings).
  Future<void> delete(String recipeId);
}

/// Forwards each write to the writer [_resolve] returns at that moment, for
/// an owner that replaces its writer (a sign-out drops the recipe service's
/// adapter, and the next sign-in builds a new one).
class LazyQueuedRecipeWriter implements QueuedRecipeWriter {
  LazyQueuedRecipeWriter(this._resolve);

  final QueuedRecipeWriter Function() _resolve;

  @override
  Future<void> create(Recipe recipe) => _resolve().create(recipe);

  @override
  Future<int> update(Recipe recipe) => _resolve().update(recipe);

  @override
  Future<void> delete(String recipeId) => _resolve().delete(recipeId);
}
