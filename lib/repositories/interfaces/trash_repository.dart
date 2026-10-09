/// BUT-907: the signed-in user's trash, `users/{uid}/trash`.
///
/// See `TrashItem` for the rule and the storage path. Every call acts on the
/// signed-in user's own trash only.
library;

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/trash_item.dart';

/// Thrown by a restore of an item whose 30 days have passed. Nothing is
/// written.
class TrashItemExpiredException implements Exception {
  const TrashItemExpiredException(this.itemId);

  final String itemId;

  @override
  String toString() => 'TrashItemExpiredException($itemId)';
}

/// Thrown by a restore that finds the item gone from the trash (restored or
/// deleted elsewhere) or its recipe already back. Nothing is written.
class TrashItemGoneException implements Exception {
  const TrashItemGoneException(this.itemId);

  final String itemId;

  @override
  String toString() => 'TrashItemGoneException($itemId)';
}

abstract class TrashRepository {
  /// The most items one listing returns.
  static const int listLimit = 200;

  /// The signed-in user's trash, newest first, at most [listLimit] rows.
  /// Rows that cannot be restored are left out. Expiry is the caller's
  /// filter, so a stream open across the 30-day line can drop the row then.
  Stream<List<TrashItem>> watchTrash();

  /// One read of what [watchTrash] streams.
  Future<List<TrashItem>> listTrash();

  /// Moves the signed-in user's own [recipe] to the trash: the copy is
  /// written and the recipe deleted in one atomic write. Throws
  /// `PermissionDeniedException` when it is not the user's.
  Future<void> moveRecipeToTrash(Recipe recipe);

  /// Puts [item]'s recipe back and removes it from the trash, in one atomic
  /// write, with its revision raised by one. [tagResult], when given,
  /// replaces the stored tags. Returns the recipe as it was written.
  ///
  /// Throws [TrashItemExpiredException] past its 30 days and
  /// [TrashItemGoneException] when it is no longer in the trash or the
  /// recipe already exists.
  Future<Recipe> restoreRecipe(TrashItem item, {TagResult? tagResult});

  /// Deletes the signed-in user's items [ids] now.
  Future<void> deleteForever(List<String> ids);

  /// Deletes everything in the signed-in user's trash and returns how many
  /// rows were deleted.
  Future<int> emptyTrash();
}
