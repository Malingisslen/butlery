/// Generic repository interface defining standard CRUD operations for data persistence.
///
/// This abstract interface establishes the foundational contract for all repository
/// implementations in the Butlery application. It provides a consistent API for
/// data access operations across different storage backends and entity types,
/// promoting code reusability and testability through dependency injection.
///
/// **Repository Pattern Benefits:**
/// - **Abstraction**: Decouples business logic from data access implementation
/// - **Testability**: Enables easy mocking and unit testing of data operations
/// - **Consistency**: Standardizes CRUD operations across all entity types
/// - **Flexibility**: Allows switching between different storage backends
/// - **Separation of Concerns**: Isolates data access logic from business rules
///
/// **Architecture Integration:**
/// Repository implementations serve as the data access layer in the MVVM pattern,
/// bridging the gap between ViewModels/Services and actual data storage. They
/// handle Firebase Firestore operations, local caching, and data transformation.
///
/// **Generic Type Parameter:**
/// The type parameter [T] represents the entity model that this repository manages.
/// This enables type safety and allows the IDE to provide proper code completion
/// and compile-time error checking for repository operations.
///
/// **Usage Examples:**
/// ```dart
/// // Define a specific repository implementation
/// class UserRepository implements Repository<UserProfile> {
///   @override
///   Future<UserProfile> create(UserProfile user) async {
///     // Store user in Firestore and return created entity
///     final docRef = await _firestore.collection('users').add(user.toFirestore());
///     return user.copyWith(id: docRef.id);
///   }
///   
///   @override
///   Future<UserProfile?> read(String id) async {
///     // Fetch user by ID with error handling
///     final doc = await _firestore.collection('users').doc(id).get();
///     return doc.exists ? UserProfile.fromFirestore(doc.data()!, id) : null;
///   }
/// }
/// 
/// // Usage in services or ViewModels
/// final userRepo = ServiceLocator.get<Repository<UserProfile>>();
/// final user = await userRepo.read('user123');
/// if (user != null) {
///   final updatedUser = user.copyWith(name: 'Updated Name');
///   await userRepo.update(updatedUser);
/// }
/// ```
///
/// **Implementation Guidelines:**
/// - Handle null safety appropriately in read operations
/// - Implement proper error handling and logging
/// - Consider caching strategies for performance optimization
/// - Validate input parameters and entity data integrity
/// - Use transactions for operations affecting multiple documents
abstract class Repository<T> {
  /// Creates a new entity in the data store.
  ///
  /// Persists the provided [entity] to the underlying storage system and returns
  /// the created entity, potentially with updated fields like generated IDs or
  /// timestamps. The implementation should handle ID generation and any required
  /// data validation.
  ///
  /// [entity] The entity instance to create and persist
  ///
  /// Returns the created entity with any server-generated fields populated
  ///
  /// Throws [ValidationException] if the entity data is invalid
  /// Throws [StorageException] if the storage operation fails
  ///
  /// Example:
  /// ```dart
  /// final newUser = UserProfile(name: 'John Doe', email: 'john@example.com');
  /// final createdUser = await repository.create(newUser);
  /// print('Created user with ID: ${createdUser.id}');
  /// ```
  Future<T> create(T entity);

  /// Retrieves a single entity by its unique identifier.
  ///
  /// Fetches the entity with the specified [id] from the data store. Returns
  /// null if no entity with the given ID exists. This operation should be
  /// optimized for single-record retrieval and may utilize caching.
  ///
  /// [id] The unique identifier of the entity to retrieve
  ///
  /// Returns the entity if found, null if no entity exists with the given ID
  ///
  /// Throws [StorageException] if the retrieval operation fails
  ///
  /// Example:
  /// ```dart
  /// final user = await repository.read('user123');
  /// if (user != null) {
  ///   print('Found user: ${user.name}');
  /// } else {
  ///   print('User not found');
  /// }
  /// ```
  Future<T?> read(String id);

  /// Retrieves all entities of this type from the data store.
  ///
  /// Fetches and returns a list containing all entities managed by this
  /// repository. For large datasets, consider implementing pagination or
  /// filtering in specialized repository methods to avoid performance issues.
  ///
  /// Returns a list of all entities, empty list if no entities exist
  ///
  /// Throws [StorageException] if the retrieval operation fails
  ///
  /// **Performance Note:**
  /// This method loads all entities into memory and should be used cautiously
  /// with large datasets. Consider implementing filtered read methods for
  /// production use cases.
  ///
  /// Example:
  /// ```dart
  /// final allUsers = await repository.readAll();
  /// print('Total users: ${allUsers.length}');
  /// for (final user in allUsers) {
  ///   print('User: ${user.name}');
  /// }
  /// ```
  Future<List<T>> readAll();

  /// Updates an existing entity in the data store.
  ///
  /// Modifies the entity with the same ID as the provided [entity] in the
  /// storage system. The implementation should validate that the entity exists
  /// before updating and handle partial updates appropriately.
  ///
  /// [entity] The entity with updated data to persist
  ///
  /// Throws [EntityNotFoundException] if no entity exists with the given ID
  /// Throws [ValidationException] if the updated entity data is invalid
  /// Throws [StorageException] if the update operation fails
  ///
  /// Example:
  /// ```dart
  /// final existingUser = await repository.read('user123');
  /// if (existingUser != null) {
  ///   final updatedUser = existingUser.copyWith(name: 'Updated Name');
  ///   await repository.update(updatedUser);
  ///   print('User updated successfully');
  /// }
  /// ```
  Future<void> update(T entity);

  /// Permanently removes an entity from the data store.
  ///
  /// Deletes the entity with the specified [id] from the storage system.
  /// This operation is irreversible and should be used with caution. The
  /// implementation should handle cascade deletions if the entity has
  /// dependent relationships.
  ///
  /// [id] The unique identifier of the entity to delete
  ///
  /// Throws [EntityNotFoundException] if no entity exists with the given ID
  /// Throws [StorageException] if the deletion operation fails
  ///
  /// **Important:**
  /// This operation permanently removes data and cannot be undone. Consider
  /// implementing soft deletion patterns for entities that should be recoverable.
  ///
  /// Example:
  /// ```dart
  /// await repository.delete('user123');
  /// print('User deleted successfully');
  /// 
  /// // Verify deletion
  /// final deletedUser = await repository.read('user123');
  /// assert(deletedUser == null);
  /// ```
  Future<void> delete(String id);
}
