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
/// retried.
class RecipeRevisionConflictException implements Exception {
  const RecipeRevisionConflictException(this.remote);

  final Recipe remote;

  @override
  String toString() =>
      'RecipeRevisionConflictException(${remote.id} at rev ${remote.rev})';
}

/// BUT-2363: a comment was refused before it was written because the
/// account's previous comment is still in this device's offline queue. The comment
/// create rule allows one comment per 5 s (`rateLimitStamped`), and Firestore
/// sends queued writes back to back on reconnect, so a second queued comment
/// would be refused there and lost.
class CommentAwaitingSendException implements Exception {
  const CommentAwaitingSendException();

  @override
  String toString() => 'CommentAwaitingSendException';
}
