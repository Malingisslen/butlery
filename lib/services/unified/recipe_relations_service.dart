/// BUT-1048: symmetric link/unlink between two recipes via
/// [Recipe.relatedRecipeIds]. Extracted from [UnifiedRecipeService] so
/// the link/unlink contract can be unit-tested without the
/// implements-Mock noSuchMethod problem the BUT-989 attempt hit
/// (concrete methods on a mock-of-interface return null typed as
/// `Future<bool>` → crash on await).
///
/// The service takes the two narrow capabilities it needs (lookup +
/// update) as callbacks, so tests can stub them with plain functions.
library;

import 'package:butlery/models/recipe_unified.dart';

class RecipeRelationsService {
  final Recipe? Function(String id) _getRecipe;
  final Future<bool> Function(Recipe recipe) _updateRecipe;

  RecipeRelationsService({
    required Recipe? Function(String id) getRecipe,
    required Future<bool> Function(Recipe recipe) updateRecipe,
  }) : _getRecipe = getRecipe,
       _updateRecipe = updateRecipe;

  /// Symmetric link: adds [bId] to A's `relatedRecipeIds` and vice versa.
  /// Idempotent — re-linking an already-symmetric pair returns true
  /// without writes. Self-links are rejected.
  ///
  /// Not truly atomic: two sequential writes. If the second fails, A
  /// points at B but B doesn't point back — next link/unlink on either
  /// side normalises the asymmetry. For banking-grade atomicity, promote
  /// to a Cloud Function.
  Future<bool> link(String aId, String bId) async {
    if (aId == bId) return false;
    final a = _getRecipe(aId);
    final b = _getRecipe(bId);
    if (a == null || b == null) return false;

    final aRelated = a.core.relatedRecipeIds ?? const <String>[];
    final bRelated = b.core.relatedRecipeIds ?? const <String>[];

    final aAlready = aRelated.contains(bId);
    final bAlready = bRelated.contains(aId);
    if (aAlready && bAlready) return true;

    if (!aAlready) {
      final ok = await _updateRecipe(
        a.copyWith(relatedRecipeIds: [...aRelated, bId]),
      );
      if (!ok) return false;
    }
    if (!bAlready) {
      final ok = await _updateRecipe(
        b.copyWith(relatedRecipeIds: [...bRelated, aId]),
      );
      if (!ok) return false;
    }
    return true;
  }

  /// Symmetric unlink: removes the back-references on both sides.
  /// Idempotent — unlinking an already-unlinked pair returns true.
  /// Self-unlinks are rejected. Same partial-failure caveat as [link].
  Future<bool> unlink(String aId, String bId) async {
    if (aId == bId) return false;
    final a = _getRecipe(aId);
    final b = _getRecipe(bId);
    if (a == null || b == null) return false;

    final aRelated = a.core.relatedRecipeIds ?? const <String>[];
    final bRelated = b.core.relatedRecipeIds ?? const <String>[];

    final aLinks = aRelated.contains(bId);
    final bLinks = bRelated.contains(aId);
    if (!aLinks && !bLinks) return true;

    if (aLinks) {
      final ok = await _updateRecipe(
        a.copyWith(
          relatedRecipeIds: aRelated.where((id) => id != bId).toList(),
        ),
      );
      if (!ok) return false;
    }
    if (bLinks) {
      final ok = await _updateRecipe(
        b.copyWith(
          relatedRecipeIds: bRelated.where((id) => id != aId).toList(),
        ),
      );
      if (!ok) return false;
    }
    return true;
  }
}
