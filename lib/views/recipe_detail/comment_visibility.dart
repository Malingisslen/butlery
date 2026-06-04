import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/models/recipe_unified.dart';

/// BUT-914: the set of OTHER users who will see a comment posted on [recipe],
/// from [currentUserId]'s perspective — the recipe owner plus its collaborative
/// members, minus the author themselves.
///
/// Returns empty for non-collaborative recipes: a personal recipe's comments
/// are author/owner-only, not a shared audience worth labelling, so the caller
/// hides the "visible to" line in that case rather than mis-stating it.
///
/// Mirrors `FirebaseRecipeOwnershipResolver._resolveSharedIds` (the canonical
/// server-side audience used to denormalize comment read-access) so the label
/// can neither over- nor under-state who can see the comment.
List<String> commentVisibilityAudience(Recipe recipe, String currentUserId) {
  if (!recipe.isCollaborative) return const <String>[];
  final social = recipe.socialData;
  final ownerId = (social?.ownerId?.isNotEmpty ?? false)
      ? social!.ownerId!
      : recipe.createdBy.orEmpty();
  final members = social?.memberPermissions?.keys ?? const <String>[];
  final ids = <String>{
    if (ownerId.isNotEmpty) ownerId,
    ...members.where((id) => id.isNotEmpty),
  }..remove(currentUserId);
  return ids.toList();
}

/// BUT-914: formats the visibility-label string from [resolvedNames] (audience
/// members whose display name is known) and [total] (the TRUE audience size,
/// including members whose name didn't resolve).
///
/// Privacy invariant — **never under-state**: the comment is shared with all
/// [total] people, so the label always discloses that total. Shows up to 3
/// names + "+N" where N is counted against [total] (so unresolved members are
/// included in the count, never silently dropped); falls back to a count-only
/// label (`countLabel(total)`) when no name resolves, rather than hiding a real
/// audience. Returns null only when [total] is 0 (caller hides the line).
String? formatCommentAudience(
  List<String> resolvedNames,
  int total, {
  required String Function(int count) countLabel,
}) {
  if (total <= 0) return null;
  final shown = resolvedNames.take(3).toList();
  if (shown.isEmpty) return countLabel(total);
  final remaining = total - shown.length;
  return remaining > 0 ? '${shown.join(', ')} +$remaining' : shown.join(', ');
}
