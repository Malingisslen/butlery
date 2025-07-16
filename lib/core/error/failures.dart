// lib/core/error/failures.dart

/// Abstrakt klass för alla typer av fel i appen
abstract class Failure {
  final String message;
  final String? code;
  final dynamic originalError;

  const Failure({required this.message, this.code, this.originalError});

  @override
  String toString() => message;
}

/// Nätverksrelaterade fel
class NetworkFailure extends Failure {
  const NetworkFailure({
    required super.message,
    super.code,
    super.originalError,
  });
}

/// Valideringsfel för formulär och input
class ValidationFailure extends Failure {
  final Map<String, String>? fieldErrors;

  const ValidationFailure({
    required super.message,
    this.fieldErrors,
    super.code,
  });
}

/// Cache-relaterade fel
class CacheFailure extends Failure {
  const CacheFailure({required super.message, super.code, super.originalError});
}

/// Timeout fel
class TimeoutFailure extends Failure {
  const TimeoutFailure({
    required super.message,
    super.code = 'timeout',
    super.originalError, // ✅ LÄGG TILL DENNA RAD
  });
}

/// Okänt fel
class UnknownFailure extends Failure {
  const UnknownFailure({
    super.message = 'Ett oväntat fel uppstod',
    super.originalError,
  });
}
