/// Repository-specific exceptions for error handling.
class RepositoryException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  const RepositoryException(
    this.message, {
    this.code,
    this.originalError,
  });

  @override
  String toString() => 'RepositoryException: $message';
}