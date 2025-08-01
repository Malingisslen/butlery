/// Comprehensive base Hive repository providing unified local data storage operations for the Butlery cooking application.
///
/// This abstract base class implements a sophisticated local storage solution using Hive database for offline
/// data persistence and caching. It provides generic CRUD operations with user-scoped data isolation,
/// enabling efficient local data management for recipes, shopping lists, and other cooking-related data
/// that needs to be available offline or requires fast local access for Swedish users.
///
/// **Architecture Integration:**
/// - Implements local data persistence layer in the Repository pattern architecture
/// - Provides offline-first data access with seamless user switching capabilities
/// - Integrates with Firebase repositories for hybrid online/offline data synchronization
/// - Supports user-scoped data isolation for multi-user device scenarios
/// - Enables efficient caching strategies for improved cooking application performance
///
/// **Storage Features:**
/// - **User-Scoped Storage**: Separate Hive boxes for different user accounts with automatic isolation
/// - **Generic CRUD Operations**: Type-safe create, read, update, delete operations for any data model
/// - **Box Lifecycle Management**: Automatic box initialization, management, and proper disposal
/// - **User Switching**: Seamless transition between different user data contexts
/// - **Cache Management**: Efficient cache clearing and data reset capabilities
/// - **Performance Optimization**: Fast local I/O operations optimized for cooking workflow scenarios
///
/// **Offline Capabilities:**
/// The repository enables robust offline functionality essential for cooking applications where users
/// may not have reliable internet connectivity in kitchen environments. It provides immediate data
/// access for recipes, shopping lists, and cooking instructions without network dependencies.
///
/// **Key Features:**
/// - Type-safe generic implementation supporting any serializable cooking data model
/// - User-specific data isolation preventing data cross-contamination between accounts
/// - Automatic box lifecycle management with proper initialization and cleanup
/// - Swedish localization support with appropriate error messaging and user feedback
/// - Performance optimization for cooking workflow scenarios requiring fast data access
/// - Seamless integration with online data synchronization patterns
///
/// **Usage Examples:**
/// ```dart
/// // Implement concrete repository
/// class RecipeHiveRepository extends BaseHiveRepository<Recipe> {
///   RecipeHiveRepository() : super('recipes');
/// 
///   Future<void> saveRecipe(Recipe recipe) async {
///     await put(recipe.id, recipe);
///   }
/// 
///   List<Recipe> getUserRecipes() {
///     return getAll();
///   }
/// }
/// 
/// // Usage in application
/// final recipeRepo = RecipeHiveRepository();
/// await recipeRepo.init(userId: currentUserId);
/// await recipeRepo.saveRecipe(newRecipe);
/// final recipes = recipeRepo.getUserRecipes();
/// 
/// // User switching scenario
/// await recipeRepo.switchUser(newUserId);
/// final newUserRecipes = recipeRepo.getUserRecipes();
/// ```

import 'package:hive_flutter/hive_flutter.dart';

/// Comprehensive base Hive repository implementing unified local data storage operations for cooking-focused user interface design.
///
/// This abstract class serves as the foundation for all local data storage repositories throughout the
/// Butlery application, providing type-safe CRUD operations, user-scoped data isolation, and efficient
/// offline data management. It enables robust cooking application functionality with seamless user
/// switching, cache management, and performance optimization for kitchen environment usage scenarios.
///
/// **Storage Architecture:**
/// - **Generic Type Safety**: Strongly-typed operations ensuring data integrity and compile-time validation
/// - **User Isolation**: Separate storage contexts for different users preventing data cross-contamination
/// - **Box Lifecycle**: Automatic initialization, management, and cleanup of Hive storage boxes
/// - **Performance Focus**: Optimized for fast local I/O operations essential in cooking workflows
/// - **Offline Priority**: Local-first approach enabling full functionality without network connectivity
///
/// **Design Principles:**
/// The repository reflects the reliability and precision of cooking with consistent data access patterns,
/// robust offline capabilities, and user-focused data isolation that supports complex multi-user
/// cooking scenarios while maintaining optimal performance for Swedish cooking application requirements.
abstract class BaseHiveRepository<T> {
  /// The base name for the Hive box used for data storage.
  ///
  /// This name serves as the foundation for user-scoped box naming, where actual box names
  /// are constructed by appending user IDs to create isolated storage contexts for different
  /// users. This enables multi-user support on shared devices while maintaining data privacy.
  final String boxName;

  /// The currently opened Hive box instance for type-safe data operations.
  ///
  /// This box provides direct access to the underlying Hive storage for the current user context.
  /// It remains null until [init] is called and becomes the primary interface for all CRUD operations.
  /// The box is automatically managed through the repository lifecycle and properly disposed when needed.
  Box<T>? _box;

  /// Creates a new base Hive repository with the specified box name.
  ///
  /// [boxName] The base name used for creating user-scoped storage boxes
  ///
  /// The constructor initializes the repository with the provided box name but does not open
  /// the actual Hive box. Call [init] with a user ID to open the box for data operations.
  BaseHiveRepository(this.boxName);

  /// Initializes the Hive box with user-specific naming for data isolation.
  ///
  /// Opens or creates a Hive box with user-scoped naming to ensure data separation between
  /// different user accounts. This is essential for multi-user device scenarios where multiple
  /// family members or users might access the cooking application on the same device.
  ///
  /// [userId] Optional user identifier for box naming. If null, uses base box name
  ///
  /// **Box Naming Strategy:**
  /// - With userId: `{boxName}_{userId}` for user-specific data isolation
  /// - Without userId: `{boxName}` for shared or anonymous data access
  ///
  /// **Usage Note:**
  /// This method must be called before any data operations. It's idempotent and safe to call
  /// multiple times with the same userId - the box will only be opened once.
  ///
  /// Example:
  /// ```dart
  /// await repository.init(userId: 'user123');
  /// // Box name becomes: 'recipes_user123'
  /// ```
  Future<void> init({String? userId}) async {
    final userSpecificBoxName = userId != null ? '${boxName}_$userId' : boxName;
    _box ??= await Hive.openBox<T>(userSpecificBoxName);
  }

  /// Provides safe access to the initialized Hive box for data operations.
  ///
  /// Returns the currently opened box instance, ensuring it has been properly initialized
  /// before use. This getter serves as the primary access point for all CRUD operations
  /// and includes built-in validation to prevent operations on uninitialized storage.
  ///
  /// Returns the opened [Box<T>] instance for type-safe data operations
  ///
  /// Throws [StateError] if the box has not been initialized via [init] method
  ///
  /// **Safety Features:**
  /// - Validates box initialization before providing access
  /// - Prevents data corruption from operations on null boxes
  /// - Provides clear error messaging for debugging initialization issues
  ///
  /// Example:
  /// ```dart
  /// await repository.init(userId: currentUserId);
  /// final box = repository.box; // Safe access after initialization
  /// final data = box.get('key');
  /// ```
  Box<T> get box {
    if (_box == null) {
      throw StateError('Hive-box $boxName är inte initialiserad. Anropa init() först.');
    }
    return _box!;
  }

  /// Retrieves all stored objects from the current user's box.
  ///
  /// Returns a complete list of all values stored in the current box context, providing
  /// immediate access to the user's locally cached data without network dependencies.
  /// This operation is optimized for cooking applications where users need quick access
  /// to all their recipes, shopping lists, or other cooking-related data.
  ///
  /// Returns [List<T>] containing all stored objects in the box
  ///
  /// **Performance Note:**
  /// This operation loads all data into memory simultaneously, which is efficient for
  /// typical cooking application data sizes but should be monitored for very large datasets.
  ///
  /// Example:
  /// ```dart
  /// final allRecipes = repository.getAll();
  /// for (final recipe in allRecipes) {
  ///   displayRecipe(recipe);
  /// }
  /// ```
  List<T> getAll() => box.values.toList();

  /// Retrieves a specific object by its key from the storage box.
  ///
  /// Fetches a single stored object using its unique identifier, providing immediate
  /// local access without network latency. This is essential for cooking applications
  /// where users need instant access to specific recipes or shopping list items.
  ///
  /// [key] The unique identifier for the object to retrieve
  /// Returns the stored object or null if no object exists with the given key
  ///
  /// **Key Strategy:**
  /// Keys should be consistent and meaningful (e.g., recipe IDs, shopping list names)
  /// to enable efficient retrieval and data organization within the cooking application.
  ///
  /// Example:
  /// ```dart
  /// final recipe = repository.get('recipe_123');
  /// if (recipe != null) {
  ///   displayRecipeDetails(recipe);
  /// } else {
  ///   showRecipeNotFound();
  /// }
  /// ```
  T? get(dynamic key) => box.get(key);

  /// Stores or updates an object in the local storage box.
  ///
  /// Persists an object with the specified key, either creating a new entry or updating
  /// an existing one. This operation provides immediate local storage for cooking data
  /// that users need to access quickly, even when offline in kitchen environments.
  ///
  /// [key] The unique identifier under which to store the object
  /// [value] The object to store in the local database
  ///
  /// **Storage Strategy:**
  /// Objects are stored immediately and persistently, ensuring data survival across
  /// app restarts and providing reliable offline access to cooking information.
  ///
  /// Example:
  /// ```dart
  /// await repository.put(recipe.id, recipe);
  /// // Recipe is now available offline
  /// final savedRecipe = repository.get(recipe.id);
  /// ```
  Future<void> put(dynamic key, T value) async => box.put(key, value);

  /// Removes a specific object from the storage box.
  ///
  /// Permanently deletes the object associated with the given key from local storage.
  /// This operation is immediate and irreversible, suitable for removing outdated
  /// recipes, completed shopping lists, or other cooking data that's no longer needed.
  ///
  /// [key] The unique identifier of the object to remove
  ///
  /// **Data Integrity:**
  /// Deletion is permanent and cannot be undone. Consider implementing soft deletion
  /// patterns for critical cooking data that users might want to recover.
  ///
  /// Example:
  /// ```dart
  /// await repository.delete('recipe_123');
  /// final deletedRecipe = repository.get('recipe_123'); // Returns null
  /// ```
  Future<void> delete(dynamic key) async => box.delete(key);

  /// Clears all data from the current user's storage box.
  ///
  /// Removes all stored objects from the box, effectively resetting the user's local
  /// data cache. This is useful for data refresh scenarios, user logout cleanup, or
  /// when implementing data synchronization patterns that require a clean slate.
  ///
  /// **Warning:**
  /// This operation permanently removes all local data and cannot be undone. Ensure
  /// proper user confirmation and consider data backup strategies before clearing.
  ///
  /// Example:
  /// ```dart
  /// await repository.clear();
  /// final allData = repository.getAll(); // Returns empty list
  /// ```
  Future<void> clear() async => box.clear();

  /// Properly closes the Hive box and releases system resources.
  ///
  /// Closes the current box connection and frees associated memory and file handles.
  /// This method should be called when the repository is no longer needed to ensure
  /// proper resource cleanup and prevent memory leaks in the cooking application.
  ///
  /// **Lifecycle Management:**
  /// Call this method during app shutdown, user logout, or when switching to different
  /// repository instances to maintain optimal system performance.
  ///
  /// Example:
  /// ```dart
  /// await repository.dispose();
  /// // Repository is now closed and should not be used
  /// ```
  Future<void> dispose() async => _box?.close();

  /// Switches to a different user's data context with seamless box management.
  ///
  /// Closes the current user's box and opens a new box for the specified user, enabling
  /// smooth transitions between different user accounts on shared devices. This is essential
  /// for family cooking scenarios where multiple users share the same device but need
  /// separate recipe collections and shopping lists.
  ///
  /// [newUserId] The user identifier for the new user context, or null for anonymous access
  ///
  /// **User Isolation Benefits:**
  /// - Maintains complete data separation between different users
  /// - Prevents accidental data mixing in multi-user households
  /// - Enables personalized cooking experiences for each family member
  /// - Supports seamless switching without data loss or corruption
  ///
  /// **Transition Process:**
  /// 1. Safely closes the current user's box with proper resource cleanup
  /// 2. Resets internal state to prepare for new user context
  /// 3. Initializes new user's box with isolated data storage
  ///
  /// Example:
  /// ```dart
  /// // Switch from parent to child account
  /// await repository.switchUser('child_user_123');
  /// final childRecipes = repository.getAll(); // Only child's recipes
  /// 
  /// // Switch back to parent account
  /// await repository.switchUser('parent_user_456');
  /// final parentRecipes = repository.getAll(); // Only parent's recipes
  /// ```
  Future<void> switchUser(String? newUserId) async {
    // Safely close current user's box
    await _box?.close();
    _box = null;
    
    // Initialize new user's isolated storage context
    await init(userId: newUserId);
  }

  /// Clears all cached data for the current user while preserving box structure.
  ///
  /// Removes all stored data from the current user's box without closing the box itself,
  /// providing a fast way to refresh local cache while maintaining the active storage
  /// connection. This is useful for data synchronization scenarios or when implementing
  /// cache refresh functionality in the cooking application.
  ///
  /// **Use Cases:**
  /// - Refreshing local data cache after online synchronization
  /// - Clearing outdated cached recipes or shopping lists
  /// - Implementing manual cache refresh functionality
  /// - Preparing for bulk data import operations
  ///
  /// **Safety Note:**
  /// This operation only affects the current user's data and maintains box initialization,
  /// allowing immediate continued use of the repository without reinitialization.
  ///
  /// Example:
  /// ```dart
  /// // Clear cache before fresh data sync
  /// await repository.clearUserCache();
  /// final freshData = await syncFromServer();
  /// for (final item in freshData) {
  ///   await repository.put(item.id, item);
  /// }
  /// ```
  Future<void> clearUserCache() async {
    if (_box != null) {
      await _box!.clear();
    }
  }
}

