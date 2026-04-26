import 'package:butlery/models/cook_snap.dart';
import 'package:butlery/repositories/interfaces/repository.dart';

/// Repository interface for CookSnap CRUD operations.
///
/// Read queries are friends-gated at the rules layer: a `cook_snaps` doc is
/// only visible if the caller is the snap-owner or in the snap-owner's
/// friends list. The `allowedUserIds` parameter on read queries must contain
/// only ids the caller is authorised to see (i.e. self + friend ids), or the
/// query will be denied wholesale by Firestore. The service layer is
/// responsible for resolving and supplying this set.
abstract class CookSnapRepository extends Repository<CookSnap> {
  /// Gets cook snaps for a recipe, restricted to docs whose `userId` is in
  /// [allowedUserIds]. Ordered by createdAt desc. Chunks the set across
  /// Firestore's `whereIn` cap and merges results.
  Future<List<CookSnap>> getCookSnapsForRecipe(
    String recipeId, {
    required Set<String> allowedUserIds,
    int limit,
  });

  /// Adds a new cook snap.
  Future<CookSnap> addCookSnap(CookSnap snap);

  /// Deletes a cook snap.
  Future<void> deleteCookSnap(String snapId);

  /// Watches cook snaps for a recipe in real-time, restricted to docs whose
  /// `userId` is in [allowedUserIds]. See [getCookSnapsForRecipe] for the
  /// allowedUserIds contract.
  Stream<List<CookSnap>> watchCookSnaps(
    String recipeId, {
    required Set<String> allowedUserIds,
    int limit,
  });

  /// Gets all cook snaps by a specific user (for GDPR export/deletion).
  /// Bypasses the friends gate — the caller must already be authorised
  /// (currently used only for owner export and account-deletion flows).
  Future<List<CookSnap>> getCookSnapsByUser(String userId);

  /// Deletes all cook snaps by a specific user (for account deletion).
  Future<int> deleteAllByUser(String userId);
}
