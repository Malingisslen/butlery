import '../interfaces/repository.dart';

/// Simple in-memory implementation of [Repository] used for unit tests.
class InMemoryRepository<T> implements Repository<T> {
  /// Function used to extract an id from an entity.
  final String Function(T entity) _getId;

  /// Stored entities indexed by id.
  final Map<String, T> items = <String, T>{};

  InMemoryRepository(this._getId);

  @override
  Future<T> create(T entity) async {
    items[_getId(entity)] = entity;
    return entity;
  }

  @override
  Future<T?> read(String id) async => items[id];

  @override
  Future<List<T>> readAll() async => items.values.toList();

  @override
  Future<void> update(T entity) async {
    items[_getId(entity)] = entity;
  }

  @override
  Future<void> delete(String id) async {
    items.remove(id);
  }
}
