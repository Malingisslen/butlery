/// A generic repository interface with basic CRUD operations.
///
/// Implement this class to provide persistence for your entities. For example:
/// ```dart
/// class UserRepository implements Repository<User> {
///   @override
///   Future<User> create(User user) => // store the user
///   @override
///   Future<User?> read(String id) => // fetch a user by id
///   @override
///   Future<List<User>> readAll() => // return all users
///   @override
///   Future<void> update(User user) => // update the user
///   @override
///   Future<void> delete(String id) => // remove the user
/// }
/// ```
abstract class Repository<T> {
  Future<T> create(T entity);
  Future<T?> read(String id);
  Future<List<T>> readAll();
  Future<void> update(T entity);
  Future<void> delete(String id);
}
