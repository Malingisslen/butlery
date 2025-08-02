/// Generic repository interface for CRUD operations.
abstract class Repository<T> {
  /// Create entity and return with generated fields (ID, timestamps).
  Future<T> create(T entity);

  /// Read entity by ID. Returns null if not found.
  Future<T?> read(String id);

  /// Read all entities. Use with caution on large datasets.
  Future<List<T>> readAll();

  /// Update existing entity.
  Future<void> update(T entity);

  /// Delete entity permanently.
  Future<void> delete(String id);
}
