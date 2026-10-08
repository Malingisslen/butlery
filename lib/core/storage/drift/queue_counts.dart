/// The offline queue's counts, shared by the native database and the web stub.
library;

import 'package:flutter/foundation.dart' show immutable;

/// How many of the user's changes are not yet saved, across both queues
/// (the sync queue and the upload queue).
///
/// The queue view shows "antal poster" (produktregler.md:191), and the
/// offline banner "N ändringar väntar" (Komponentark v1:753-754), so the
/// app needs one number for both queues, not one per table.
///
/// PQ-04 = B (decided 2026-09-23): a surface shows nothing while the queue
/// drains by itself, and a saffron counter only when something needs the
/// user. [needsUser] is that second number.
@immutable
class QueueCounts {
  const QueueCounts({required this.draining, required this.needsUser});

  /// Nothing waiting.
  static const QueueCounts empty = QueueCounts(draining: 0, needsUser: 0);

  /// Entries not marked permanently failed (queued, uploading, or failed).
  /// A failed upload stays here until something marks it permanently
  /// failed, even when its retries have run out.
  final int draining;

  /// Permanent failures that wait for the user ("Väntar på dig",
  /// produktregler.md:189).
  final int needsUser;

  /// Every change that has not reached the server.
  int get waiting => draining + needsUser;

  @override
  bool operator ==(Object other) =>
      other is QueueCounts &&
      other.draining == draining &&
      other.needsUser == needsUser;

  @override
  int get hashCode => Object.hash(draining, needsUser);

  @override
  String toString() =>
      'QueueCounts(draining: $draining, needsUser: $needsUser)';
}
