library;

import 'package:butlery/models/recipe_unified.dart';

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

/// BUT-2213: a queued recipe write was built on revision `expectedRev`, and
/// the server's recipe has moved on since, with other content. Nothing was
/// written. [remote] is the server's recipe as it is now.
///
/// Deliberately neither a `FirebaseException` nor a `PermissionDeniedException`:
/// the offline queue must not read a conflict as a failure
/// (`permanentFailureReason`), since a conflict is shown to the user, not
/// retried (produktregler.md:189).
class RecipeRevisionConflictException implements Exception {
  const RecipeRevisionConflictException(this.remote);

  final Recipe remote;

  @override
  String toString() =>
      'RecipeRevisionConflictException(${remote.id} at rev ${remote.rev})';
}
