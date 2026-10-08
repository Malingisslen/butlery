// lib/services/offline/queue_retry_policy.dart
//
// P6-U08b: the offline queue's retry rules (produktregler.md:182-188, § 3.1),
// as pure functions the sync manager and the queue view share.
//
//   :185  "FIFO per entitet, parallellt mellan entiteter."
//   :186  "En post kan deklarera `dependsOn: [opId]` … Om beroendet permanent
//          misslyckas markeras hela kedjan som misslyckad — aldrig halvvägs."
//   :187  "Exponentiell backoff 2 s → 4 s → 8 s → 30 s → 2 min → 10 min, med
//          jitter. Max 24 h, därefter permanent fel. Ingen omförsöksstorm vid
//          återkommande nät."
//   :188  "4xx utom 408/429 försöks aldrig igen."
library;

import 'dart:math';

import 'package:firebase_core/firebase_core.dart' show FirebaseException;

import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/exceptions/storage_upload_exception.dart';

import 'package:butlery/services/offline/queued_change.dart';

/// The retry schedule, in order. The last step repeats until [maxRetryAge].
const List<Duration> kQueueRetrySchedule = [
  Duration(seconds: 2),
  Duration(seconds: 4),
  Duration(seconds: 8),
  Duration(seconds: 30),
  Duration(minutes: 2),
  Duration(minutes: 10),
];

/// How long the queue keeps retrying an entry after its first failed
/// attempt before it becomes a permanent failure.
const Duration kQueueMaxRetryAge = Duration(hours: 24);

/// ± this fraction of each step is jitter, so devices that come back online
/// together do not retry in step. The same ±25 % as RetryHelper
/// (retry_helper.dart), the app's other backoff.
const double kQueueRetryJitter = 0.25;

/// The delay before the next attempt, after [failures] failed attempts
/// (1 for the first failure). [random] supplies the jitter.
Duration queueRetryDelay(int failures, {Random? random}) {
  final index = (failures < 1 ? 1 : failures) - 1;
  final base = kQueueRetrySchedule[min(index, kQueueRetrySchedule.length - 1)];
  final spread = ((random ?? _random).nextDouble() * 2 - 1) * kQueueRetryJitter;
  return Duration(
    microseconds: (base.inMicroseconds * (1 + spread)).round(),
  );
}

final Random _random = Random();

/// Why a failed attempt will never succeed by being sent again, or null
/// when it may (a transient failure).
///
/// Read from the error's code, never from its message text
/// (produktregler.md:188 "4xx utom 408/429"). Firebase reports the HTTP
/// class through gRPC-style codes, shared by Firestore, Functions
/// (FirebaseFunctionsException extends FirebaseException) and Storage:
///
/// * not-found (404), object-not-found, bucket-not-found,
///   project-not-found → [QueuedChangeReason.notFound]
/// * permission-denied (403), unauthorized (Storage 403)
///   → [QueuedChangeReason.permissionDenied]
/// * invalid-argument, failed-precondition, out-of-range, already-exists
///   (400/409) → [QueuedChangeReason.unknown] ("Servern tog inte emot
///   ändringen")
/// * unauthenticated (401) is NOT permanent — the one exception to
///   "4xx utom 408/429 försöks aldrig igen" (produktregler.md:188). For the
///   signed-in user a 401 means the ID token is being refreshed, and the
///   next attempt carries the new token. It is retried like any transient
///   failure and still becomes a permanent failure when the 24 h run out
///   (produktregler.md:187, [queueRetriesExhausted]). Decided by the package
///   6 lead (track P6-W4, QUEUE-401); permission-denied (403) stays
///   permanent.
///
/// Transient: unauthenticated (401, above), unavailable, deadline-exceeded
/// (408), resource-exhausted and quota-exceeded (429), aborted, internal,
/// unknown, cancelled, and every other error that is not a FirebaseException
/// (a socket that closed, a timeout).
///
/// The recipe repository the sender writes through (BUT-2162) refuses some
/// writes itself, before Firestore sees them, with its own exceptions. Those
/// are the same answers the server would give again, so they map like their
/// codes: a recipe that is not there is [QueuedChangeReason.notFound], an
/// ownership or permission refusal is [QueuedChangeReason.permissionDenied],
/// and a refused field is [QueuedChangeReason.unknown]. A missing signed-in
/// user ([AuthenticationException]) stays transient, like a 401.
///
/// An image upload fails with a [StorageUploadException] carrying the
/// Storage code, mapped like the codes above. Its `too-large` is the app's
/// own size check (`checkStorageUploadSize`) and is
/// [QueuedChangeReason.tooLarge]. Since that check runs first, an
/// `unauthorized` is still a permission answer.
QueuedChangeReason? permanentFailureReason(Object error) {
  if (error is StorageUploadException) {
    if (error.isTooLarge) return QueuedChangeReason.tooLarge;
    return _permanentReasonForCode(error.code);
  }
  if (error is ResourceNotFoundException) return QueuedChangeReason.notFound;
  if (error is PermissionDeniedException ||
      error is SecurityViolationException) {
    return QueuedChangeReason.permissionDenied;
  }
  if (error is ValidationException) return QueuedChangeReason.unknown;
  if (error is! FirebaseException) return null;
  return _permanentReasonForCode(error.code);
}

QueuedChangeReason? _permanentReasonForCode(String code) {
  return switch (code) {
    'not-found' ||
    'object-not-found' ||
    'bucket-not-found' ||
    'project-not-found' => QueuedChangeReason.notFound,
    'permission-denied' ||
    'unauthorized' => QueuedChangeReason.permissionDenied,
    'invalid-argument' ||
    'failed-precondition' ||
    'out-of-range' ||
    'already-exists' => QueuedChangeReason.unknown,
    _ => null,
  };
}

/// A short, non-personal code for a failed attempt, kept for diagnostics
/// while the entry is still retried: the Firebase code, or the error's type.
/// Never the message, which can carry user text.
String queueErrorCode(Object error) => switch (error) {
  FirebaseException(:final code) || StorageUploadException(:final code) => code,
  _ => error.runtimeType.toString(),
};

/// One entry as [planQueuePass] sees it.
class QueueEntryState {
  const QueueEntryState({
    required this.opId,
    required this.entityKey,
    required this.dependsOn,
    this.nextAttemptAt,
  });

  /// The entry's identity (produktregler.md:185).
  final String opId;

  /// The entity it writes to; entries for one entity go in order.
  final String entityKey;

  /// The opIds it waits for (produktregler.md:187).
  final List<String> dependsOn;

  /// When it may be sent again, or null to send now.
  final DateTime? nextAttemptAt;
}

/// What one pass over the queue does with an entry.
enum QueueEntryDecision {
  /// Send it now.
  send,

  /// Its retry time has not come.
  backoff,

  /// It waits for an earlier entry: a dependency still in the queue, or an
  /// earlier entry for the same entity (FIFO per entity).
  waits,

  /// A dependency failed for good, so this entry can never be sent: mark it
  /// and everything after it as failed.
  dependencyFailed,
}

/// Decides, for one entry, what the pass does with it.
///
/// [waiting] and [failed] are the opIds still in either queue
/// (`AppDatabase.queuedOpIds`); a dependency in neither has reached the
/// server. [blockedEntities] are the entities with an earlier entry that is
/// still waiting. With [force] ("Försök synka nu") the retry time is
/// ignored, never the order or the dependencies.
QueueEntryDecision decideQueueEntry(
  QueueEntryState entry, {
  required DateTime now,
  required Set<String> waiting,
  required Set<String> failed,
  required Set<String> blockedEntities,
  bool force = false,
}) {
  if (entry.dependsOn.any(failed.contains)) {
    return QueueEntryDecision.dependencyFailed;
  }
  if (blockedEntities.contains(entry.entityKey) ||
      entry.dependsOn.any((id) => id != entry.opId && waiting.contains(id))) {
    return QueueEntryDecision.waits;
  }
  final next = entry.nextAttemptAt;
  if (!force && next != null && next.isAfter(now)) {
    return QueueEntryDecision.backoff;
  }
  return QueueEntryDecision.send;
}

/// Whether an entry whose first attempt failed at [firstFailedAt] has run
/// out of time and becomes a permanent failure (produktregler.md:188).
bool queueRetriesExhausted(DateTime firstFailedAt, DateTime now) =>
    now.difference(firstFailedAt) >= kQueueMaxRetryAge;
