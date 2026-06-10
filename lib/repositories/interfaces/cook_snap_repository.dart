import 'package:butlery/models/cook_snap.dart';
import 'package:butlery/repositories/interfaces/repository.dart';

/// Repository interface for CookSnap CRUD operations.
///
/// Read queries are friends-gated at the rules layer: a `cook_snaps` doc is
/// only visible if the caller is the snap-owner or in the snap-owner's
/// friends list. [friendIds] on read queries must contain only ids the
/// caller is authorised to see, or the query will be denied wholesale by
/// Firestore. The service layer is responsible for resolving this set.
///
/// BUT-1214: snaps marked [CookSnapVisibility.onlyMe] are author-only.
/// Implementations must query the viewer's own snaps separately (no
/// visibility filter) from friends' snaps (visibility-filtered), because
/// rules deny foreign `onlyMe` docs and any such doc in a result set fails
/// the entire query.
abstract class CookSnapRepository extends Repository<CookSnap> {
  /// Gets cook snaps for a recipe: all of [viewerId]'s own snaps plus
  /// friends' snaps whose visibility is not `onlyMe`. Ordered by createdAt
  /// desc. Chunks [friendIds] across Firestore's `whereIn` cap and merges.
  Future<List<CookSnap>> getCookSnapsForRecipe(
    String recipeId, {
    required String viewerId,
    required Set<String> friendIds,
    int limit,
  });

  /// Adds a new cook snap.
  Future<CookSnap> addCookSnap(CookSnap snap);

  /// Deletes a cook snap.
  Future<void> deleteCookSnap(String snapId);

  /// Watches cook snaps for a recipe in real-time. See
  /// [getCookSnapsForRecipe] for the viewer/friends contract.
  Stream<List<CookSnap>> watchCookSnaps(
    String recipeId, {
    required String viewerId,
    required Set<String> friendIds,
    int limit,
  });

  /// Gets all cook snaps by a specific user (for GDPR export/deletion).
  /// Bypasses the friends gate — the caller must already be authorised
  /// (currently used only for owner export and account-deletion flows).
  Future<List<CookSnap>> getCookSnapsByUser(String userId);

  /// Deletes all cook snaps by a specific user (for account deletion).
  Future<int> deleteAllByUser(String userId);

  /// Export all cook snaps authored by [userId] for GDPR Article 20.
  /// Returns raw `{id, data}` shapes (NOT typed [CookSnap]) so the export
  /// pipeline can sanitize timestamps without round-tripping. Implementations
  /// MUST validate the caller owns [userId].
  Future<List<Map<String, dynamic>>> exportCookSnapsByUser(
    String userId, {
    int maxDocuments = 1000,
  });
}
