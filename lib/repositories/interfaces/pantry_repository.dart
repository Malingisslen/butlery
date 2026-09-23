import 'package:butlery/models/pantry/pantry_item.dart';

/// Repository interface for the user's pantry ("skafferi") subcollection.
///
/// All methods are user-scoped; the [userId] parameter is explicit so that
/// callers (services, cleanup jobs, GDPR exports) can operate on arbitrary
/// users without going through auth state.
abstract class PantryRepository {
  /// Persists a new item and returns the generated document ID.
  Future<String> add(String userId, PantryItem item);

  /// Writes only [changes] to the item, plus who changed it and when
  /// (`updatedBy`, `updatedAt`). Per field, the latest change wins
  /// (produktregler.md:105, :142), so a change to one field never overwrites
  /// another field changed on another device. [changes] comes from
  /// [PantryItem.changesFrom] or [PantryItem.editableFields]; an empty map
  /// writes nothing.
  Future<void> updateFields(
    String userId,
    String itemId,
    Map<String, Object> changes,
  );

  /// Changes the item's quantity by [delta], sent as a relative change
  /// ("Bocka av 2 av 6 skickas som delta: -2", produktregler.md:146), so two
  /// devices that each take 2 end with 4 less, not 2.
  Future<void> adjustQuantity(String userId, String itemId, double delta);

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

  /// Export every pantry item for [userId] for GDPR Article 20.
  /// Returns raw `{id, data}` shapes. Ownership is structural (subcollection
  /// under `users/{userId}`); the implementation must still verify the
  /// authenticated caller IS [userId].
  Future<List<Map<String, dynamic>>> exportAllByUser(
    String userId, {
    int maxDocuments = 1000,
  });
}
