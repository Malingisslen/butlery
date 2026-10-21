// lib/models/avatar_write_outcome.dart
//
// BUT-2294: what became of a profile picture that waited on the device.
library;

enum AvatarWriteOutcome {
  /// The picture was set; the profile held the one the user was looking at.
  set,

  /// The profile already holds this picture (a send repeated after its answer
  /// was lost).
  alreadySet,

  /// The profile holds a different picture than the one the user was looking
  /// at: someone changed it since, and that newer picture is left alone.
  superseded,

  /// The profile no longer exists, so there is nothing to put a picture on.
  accountGone,
}
