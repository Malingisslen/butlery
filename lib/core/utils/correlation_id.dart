import 'dart:math';

/// Correlation ID utility for cross-layer operation tracking.
/// Generates unique IDs that can be included in all log entries
/// for a single user operation, enabling end-to-end debugging.
///
/// Usage:
/// ```dart
/// // At operation start (e.g., in ViewModel)
/// CorrelationId.generate();
///
/// // All subsequent AppLogger calls will include the ID
/// AppLogger.info('Starting operation'); // [CORR:1703539200000-1234] Starting operation
///
/// // At operation end
/// CorrelationId.clear();
/// ```
class CorrelationId {
  CorrelationId._(); // Private constructor - utility class

  static final Random _random = Random.secure();
  static String? _current;

  /// Generate a new correlation ID and set it as current.
  /// Format: `{timestamp}-{random}` e.g., `1703539200000-1234`
  static String generate() {
    _current =
        '${DateTime.now().millisecondsSinceEpoch}-${_random.nextInt(10000).toString().padLeft(4, '0')}';
    return _current!;
  }

  /// Get the current correlation ID, or null if not set.
  static String? get current => _current;

  /// Set a specific correlation ID (for propagation from external sources).
  static void set(String id) => _current = id;

  /// Clear the current correlation ID (call at operation end).
  static void clear() => _current = null;

  /// Execute a function with a correlation ID scope.
  /// Automatically generates ID before and clears after.
  static Future<T> scope<T>(Future<T> Function() action) async {
    generate();
    try {
      return await action();
    } finally {
      clear();
    }
  }

  /// Synchronous version of scope.
  static T scopeSync<T>(T Function() action) {
    generate();
    try {
      return action();
    } finally {
      clear();
    }
  }
}
