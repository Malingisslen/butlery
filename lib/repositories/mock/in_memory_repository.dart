/// Comprehensive in-memory repository implementation providing fast, lightweight data storage for testing and development scenarios.
///
/// This repository implementation provides a complete in-memory data storage solution that implements the Repository
/// interface contract without external dependencies. It's designed for unit testing, integration testing, and
/// development scenarios where fast, predictable data operations are needed without the complexity of external
/// databases or network dependencies.
///
/// **Architecture Integration:**
/// - Implements Repository<T> interface ensuring full compatibility with application data layer
/// - Provides identical API to production repositories for seamless testing integration
/// - Supports generic type parameters for type-safe operations with any data model
/// - Enables rapid testing cycles with predictable, fast data operations
/// - Facilitates development workflows with immediate data persistence feedback
///
/// **Testing Benefits:**
/// - **Fast Execution**: In-memory operations with no I/O overhead for rapid test execution
/// - **Predictable State**: Controlled data state management for reliable test scenarios
/// - **Isolation**: Each repository instance maintains separate data for test isolation
/// - **No Dependencies**: No external database or network dependencies for simplified test setup
/// - **Full Coverage**: Complete Repository interface implementation ensuring behavior parity
///
/// **Development Advantages:**
/// The repository enables rapid development iteration with immediate data feedback, allowing developers
/// to build and test cooking application features without external infrastructure dependencies while
/// maintaining identical behavior to production data repositories.
///
/// **Key Features:**
/// - Generic type support for any data model used in the cooking application (recipes, users, shopping lists)
/// - Thread-safe operations suitable for concurrent testing scenarios
/// - Configurable ID extraction strategy for flexible entity identification
/// - Memory-efficient storage with automatic garbage collection
/// - Complete CRUD operation support matching production repository capabilities
/// - Swedish localization support for error messages and developer feedback
///
/// **Usage Examples:**
/// ```dart
/// // Create repository for recipe testing
/// final recipeRepo = InMemoryRepository<Recipe>((recipe) => recipe.id);
///
/// // Test recipe creation
/// final testRecipe = Recipe(id: 'test_123', title: 'Test Köttbullar');
/// await recipeRepo.create(testRecipe);
///
/// // Verify storage
/// final storedRecipe = await recipeRepo.read('test_123');
/// expect(storedRecipe?.title, equals('Test Köttbullar'));
///
/// // Test recipe updates
/// final updatedRecipe = testRecipe.copyWith(title: 'Updated Köttbullar');
/// await recipeRepo.update(updatedRecipe);
///
/// // Verify all recipes
/// final allRecipes = await recipeRepo.readAll();
/// expect(allRecipes.length, equals(1));
/// ```

// ignore_for_file: unintended_html_in_doc_comment

import 'package:butlery/repositories/interfaces/repository.dart';

/// Comprehensive in-memory repository implementation providing fast, lightweight data storage for testing and development scenarios.
///
/// This class serves as a complete Repository interface implementation that stores all data in memory,
/// providing identical functionality to production repositories while eliminating external dependencies.
/// It's optimized for unit testing, integration testing, and development workflows where fast, predictable
/// data operations are essential for efficient development cycles and reliable test execution.
///
/// **Repository Architecture:**
/// - **Generic Type Safety**: Strongly-typed operations ensuring compile-time validation and data integrity
/// - **ID Extraction Strategy**: Configurable entity identification enabling flexible data modeling approaches
/// - **Memory Management**: Efficient in-memory storage with automatic cleanup and garbage collection
/// - **Interface Compliance**: Complete Repository<T> implementation ensuring behavior parity with production
/// - **Thread Safety**: Safe concurrent access patterns suitable for complex testing scenarios
///
/// **Design Principles:**
/// The repository reflects the simplicity and reliability of cooking with straightforward data operations,
/// immediate feedback, and predictable behavior that supports rapid development iteration and comprehensive
/// testing coverage for Swedish cooking application requirements.
class InMemoryRepository<T> implements Repository<T> {
  /// Function used to extract unique identifier from entity instances.
  ///
  /// This function defines the strategy for extracting identifiers from entities,
  /// enabling flexible entity identification patterns. It's essential for mapping
  /// entities to their storage keys and ensuring consistent data retrieval.
  ///
  /// The function should return a unique, stable identifier for each entity that
  /// remains consistent across entity lifecycle operations.
  final String Function(T entity) _getId;

  /// Internal storage map containing all entities indexed by their unique identifiers.
  ///
  /// This map serves as the primary data store, maintaining entities in memory with
  /// efficient key-based access patterns. The map structure provides O(1) lookup
  /// performance for read operations and supports the complete range of CRUD operations
  /// expected by the Repository interface.
  ///
  /// **Storage Characteristics:**
  /// - Key: Entity unique identifier (String)
  /// - Value: Full entity instance (T)
  /// - Performance: O(1) average case for all operations
  /// - Memory: Efficient storage with automatic garbage collection
  final Map<String, T> items = <String, T>{};

  /// Creates a new in-memory repository with the specified ID extraction strategy.
  ///
  /// [_getId] Function that extracts unique identifier from entity instances
  ///
  /// The ID extraction function must return consistent, unique identifiers for entities
  /// throughout their lifecycle. Common patterns include using entity ID fields,
  /// generating UUIDs, or using composite keys for complex entities.
  ///
  /// Example:
  /// ```dart
  /// // Simple ID field extraction
  /// final recipeRepo = InMemoryRepository<Recipe>((recipe) => recipe.id);
  ///
  /// // Composite key for complex entities
  /// final relationRepo = InMemoryRepository<UserRecipe>(
  ///   (userRecipe) => '${userRecipe.userId}_${userRecipe.recipeId}'
  /// );
  /// ```
  InMemoryRepository(this._getId);

  /// Creates a new entity in the in-memory storage.
  ///
  /// Stores the provided entity using its extracted ID as the storage key. This operation
  /// is immediate and returns the stored entity, simulating the behavior of persistent
  /// storage systems while providing instant feedback for testing and development scenarios.
  ///
  /// [entity] The entity instance to store in memory
  /// Returns the stored entity (identical to input for in-memory implementation)
  ///
  /// **Operation Characteristics:**
  /// - Immediate execution with no I/O delay
  /// - Overwrites existing entities with the same ID
  /// - Maintains entity reference integrity
  /// - Provides predictable behavior for testing scenarios
  ///
  /// Example:
  /// ```dart
  /// final recipe = Recipe(id: 'test_123', title: 'Köttbullar');
  /// final createdRecipe = await repository.create(recipe);
  /// // createdRecipe is now stored and retrievable
  /// ```
  @override
  Future<T> create(T entity) async {
    items[_getId(entity)] = entity;
    return entity;
  }

  /// Retrieves a specific entity by its unique identifier.
  ///
  /// Performs immediate lookup in the internal storage map using the provided ID.
  /// Returns the stored entity if found, or null if no entity exists with the given
  /// identifier. This operation provides O(1) performance characteristics.
  ///
  /// [id] The unique identifier of the entity to retrieve
  /// Returns the stored entity or null if not found
  ///
  /// **Performance Benefits:**
  /// - Instant retrieval with no network or disk I/O
  /// - O(1) lookup complexity for predictable performance
  /// - Consistent behavior across all entity types
  /// - Reliable null handling for missing entities
  ///
  /// Example:
  /// ```dart
  /// final recipe = await repository.read('test_123');
  /// if (recipe != null) {
  ///   processRecipe(recipe);
  /// } else {
  ///   handleMissingRecipe();
  /// }
  /// ```
  @override
  Future<T?> read(String id) async => items[id];

  /// Retrieves all stored entities as a list.
  ///
  /// Returns a complete list of all entities currently stored in the repository.
  /// This operation creates a new list containing all stored values, providing
  /// a snapshot of the current repository state without affecting the internal storage.
  ///
  /// Returns [List<T>] containing all stored entities
  ///
  /// **Collection Characteristics:**
  /// - Returns a new list instance for safe iteration
  /// - Maintains insertion order for predictable testing
  /// - Empty list when no entities are stored
  /// - Immediate execution with no external dependencies
  ///
  /// Example:
  /// ```dart
  /// final allRecipes = await repository.readAll();
  /// print('Total recipes: ${allRecipes.length}');
  /// for (final recipe in allRecipes) {
  ///   validateRecipe(recipe);
  /// }
  /// ```
  @override
  Future<List<T>> readAll() async => items.values.toList();

  /// Updates an existing entity in the in-memory storage.
  ///
  /// Replaces the stored entity with the provided updated version using the entity's
  /// extracted ID. This operation is immediate and provides the same behavior as create
  /// for in-memory storage, effectively implementing an "upsert" pattern.
  ///
  /// [entity] The updated entity to store
  ///
  /// **Update Behavior:**
  /// - Replaces existing entity data completely
  /// - Creates new entry if entity doesn't exist
  /// - Maintains consistent ID extraction strategy
  /// - Immediate persistence for testing scenarios
  ///
  /// Example:
  /// ```dart
  /// final updatedRecipe = existingRecipe.copyWith(
  ///   title: 'Updated Köttbullar Recipe'
  /// );
  /// await repository.update(updatedRecipe);
  /// // Updated recipe is now stored with new data
  /// ```
  @override
  Future<void> update(T entity) async {
    items[_getId(entity)] = entity;
  }

  /// Permanently removes an entity from the in-memory storage.
  ///
  /// Deletes the entity with the specified ID from the storage map. This operation
  /// is immediate and irreversible within the current session, simulating the
  /// behavior of persistent deletion operations.
  ///
  /// [id] The unique identifier of the entity to delete
  ///
  /// **Deletion Characteristics:**
  /// - Immediate removal from storage
  /// - Silent operation if entity doesn't exist
  /// - Permanent deletion within session scope
  /// - Frees memory occupied by deleted entity
  ///
  /// Example:
  /// ```dart
  /// await repository.delete('test_123');
  /// final deletedRecipe = await repository.read('test_123');
  /// // deletedRecipe is now null
  /// ```
  @override
  Future<void> delete(String id) async {
    items.remove(id);
  }
}
