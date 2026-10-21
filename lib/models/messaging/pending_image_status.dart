// lib/models/messaging/pending_image_status.dart
//
// BUT-2294: what the server holds for the placeholder message of a chat image
// that was sent without a connection.
library;

enum PendingImageState {
  /// The message is not on the server and the device holds no write for it.
  absent,

  /// The message is not on the server yet, but this device still holds the
  /// write that creates it: the placeholder is waiting in Firestore's own
  /// queue, so the image must wait too.
  writePending,

  /// The sender's placeholder, with no picture yet.
  waiting,

  /// The sender's message with a picture set, [PendingImageStatus.imageUrl].
  filled,

  /// A message that is not the caller's to fill in (another sender, or the
  /// tombstone an erased account leaves).
  notMine,
}

class PendingImageStatus {
  const PendingImageStatus(this.state, {this.imageUrl});

  final PendingImageState state;
  final String? imageUrl;
}
