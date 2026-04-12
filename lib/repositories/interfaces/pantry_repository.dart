import 'package:butlery/models/pantry/pantry_item.dart';

/// Repository interface for the user's pantry ("skafferi") subcollection.
///
/// All methods are user-scoped; the [userId] parameter is explicit so that
/// callers (services, cleanup jobs, GDPR exports) can operate on arbitrary
/// users without going through auth state.
abstract class PantryRepository {
  /// Persists a new item and returns the generated document ID.
  Future<String> add(String userId, PantryItem item);

  Future<void> update(String userId, PantryItem item);

  Future<void> remove(String userId, String itemId);

  Future<List<PantryItem>> getAll(String userId);

  Stream<List<PantryItem>> watchAll(String userId);

  /// Returns the first existing item linked to [ingredientId], or null.
  /// Used to detect duplicates when adding from an ingredient.
  Future<PantryItem?> getByIngredientId(String userId, String ingredientId);

  /// Items expiring within [days] days from now (inclusive of already
  /// expired). Items without an expiry date are excluded.
  Future<List<PantryItem>> getExpiringSoon(String userId, int days);

  /// Removes every item in the user's pantry. Used by GDPR deletion.
  Future<void> deleteAll(String userId);
}
