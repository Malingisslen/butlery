import 'package:butlery/models/tagging/ingredient_data.dart';

/// Repository interface for ingredient data operations.
///
/// Provides lookup and search functionality for the tagging system.
/// The global ingredients collection is read-only for normal users.
abstract class IngredientRepository {
  /// Get ingredient by ID.
  Future<IngredientData?> getById(String id);

  /// Find ingredient by exact name match.
  ///
  /// Searches Swedish and English names.
  Future<IngredientData?> findByName(String name, {String language = 'sv'});

  /// Find ingredients by alias.
  ///
  /// Searches aliases_sv and aliases_en.
  Future<List<IngredientData>> findByAlias(String alias);

  /// Get all ingredients in a group.
  ///
  /// Example: getByGroup('protein/meat') returns all meats.
  Future<List<IngredientData>> getByGroup(String groupPath);

  /// Get all ingredients with a specific property.
  ///
  /// Example: getByProperty('contains-gluten') returns all gluten-containing.
  Future<List<IngredientData>> getByProperty(String property);

  /// Search ingredients by query text.
  ///
  /// Searches names, aliases, and search terms.
  Future<List<IngredientData>> searchIngredients(String query,
      {int limit = 20});

  /// Watch all ingredients (for cache updates).
  Stream<List<IngredientData>> watchAll();

  /// Get all ingredients (use carefully - ~2230 items).
  Future<List<IngredientData>> getAll();

  /// Check if ingredient exists by ID.
  Future<bool> exists(String id);

  /// Get ingredient count.
  Future<int> count();
}

/// Repository interface for user-defined ingredients.
///
/// Allows users to add their own ingredient definitions
/// when the global database doesn't contain what they need.
abstract class UserIngredientRepository {
  /// Get user ingredient by ID.
  Future<IngredientData?> getById(String userId, String ingredientId);

  /// Find user ingredient by name.
  Future<IngredientData?> findByName(String userId, String name);

  /// Get all user-defined ingredients.
  Future<List<IngredientData>> getAll(String userId);

  /// Create new user-defined ingredient.
  Future<IngredientData> create(String userId, IngredientData ingredient);

  /// Update user-defined ingredient.
  Future<void> update(String userId, IngredientData ingredient);

  /// Delete user-defined ingredient.
  Future<void> delete(String userId, String ingredientId);

  /// Watch user ingredients.
  Stream<List<IngredientData>> watchAll(String userId);
}
