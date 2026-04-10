import 'package:butlery/models/cook_snap.dart';
import 'package:butlery/repositories/interfaces/repository.dart';

/// Repository interface for CookSnap CRUD operations.
abstract class CookSnapRepository extends Repository<CookSnap> {
  /// Gets cook snaps for a recipe, ordered by createdAt desc.
  Future<List<CookSnap>> getCookSnapsForRecipe(String recipeId, {int limit});

  /// Adds a new cook snap.
  Future<CookSnap> addCookSnap(CookSnap snap);

  /// Deletes a cook snap.
  Future<void> deleteCookSnap(String snapId);

  /// Watches cook snaps for a recipe in real-time.
  Stream<List<CookSnap>> watchCookSnaps(String recipeId, {int limit});

  /// Gets all cook snaps by a specific user (for GDPR export/deletion).
  Future<List<CookSnap>> getCookSnapsByUser(String userId);

  /// Deletes all cook snaps by a specific user (for account deletion).
  Future<int> deleteAllByUser(String userId);
}
