import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/views/recipe_detail/comment_visibility.dart';

/// BUT-901: a cook snap inherits the visibility of its parent recipe — there is
/// no per-snap visibility field, so whoever can see the recipe can see the snap.
/// This classifies that audience so the capture flow can warn the user *before*
/// uploading (the worst case being a public recipe silently making a kitchen
/// photo public).
enum CookSnapVisibilityScope {
  /// Parent recipe is public → the snap is visible to everyone.
  public,

  /// Parent recipe is collaborative → visible to its owner + members.
  shared,

  /// Personal recipe → the snap is author-only; no warning needed.
  private,
}

/// BUT-901: resolves who will see a cook snap posted on [recipe], from
/// [currentUserId]'s perspective. [friendNames] maps uid → display name for any
/// names the caller could resolve (typically the current user's friends list).
///
/// [resolvedNames]/[total] are populated only for [CookSnapVisibilityScope.shared];
/// [total] is the TRUE audience size (including members whose name didn't
/// resolve) so the disclosure can never under-state who sees the snap — the same
/// privacy invariant BUT-914 uses for comment visibility, whose audience set this
/// reuses.
///
/// A collaborative recipe whose only member is the current user resolves to
/// [private] (no one else sees the snap → no warning).
({CookSnapVisibilityScope scope, List<String> resolvedNames, int total})
cookSnapAudience(
  Recipe recipe,
  String currentUserId,
  Map<String, String> friendNames,
) {
  if (recipe.isPublic) {
    return (
      scope: CookSnapVisibilityScope.public,
      resolvedNames: const <String>[],
      total: 0,
    );
  }
  if (!recipe.isCollaborative) {
    return (
      scope: CookSnapVisibilityScope.private,
      resolvedNames: const <String>[],
      total: 0,
    );
  }

  final ids = commentVisibilityAudience(recipe, currentUserId);
  if (ids.isEmpty) {
    // Collaborative on paper, but no other members → effectively self-only.
    return (
      scope: CookSnapVisibilityScope.private,
      resolvedNames: const <String>[],
      total: 0,
    );
  }

  final resolved = resolveCommentAudienceNames(
    ids,
    friendNames,
    ownerId: recipe.socialData?.ownerId,
    ownerName: recipe.socialData?.ownerDisplayName,
  );
  return (
    scope: CookSnapVisibilityScope.shared,
    resolvedNames: resolved.resolved,
    total: resolved.total,
  );
}
