import 'package:butlery/core/utils/logger.dart';

/// How long a write waits for the server before it is left in Firestore's
/// offline queue.
const Duration queuedWritePatience = Duration(seconds: 2);

/// Waits for [write] to reach the server, but no longer than [patience].
///
/// Firestore applies a write to the device's cache at once and keeps it queued
/// until the connection is back, yet the write's future settles only when the
/// server answers. Awaited as-is, a save made without a connection leaves the
/// screen spinning until the user is back online (BUT-2287, BUT-2288).
///
/// A failure inside [patience] is rethrown, so an online refusal still reaches
/// the caller. After that the write stays in Firestore's queue and a later
/// refusal goes to [onLateRefusal], which logs it by default.
Future<void> awaitOrLeaveQueued(
  Future<void> write, {
  required String what,
  Duration patience = queuedWritePatience,
  void Function(Object error, StackTrace stack)? onLateRefusal,
}) {
  var callerWaiting = true;
  final settled = write.then<void>(
    (_) {},
    onError: (Object e, StackTrace stack) {
      if (callerWaiting) Error.throwWithStackTrace(e, stack);
      (onLateRefusal ?? (e, stack) => _logLateRefusal(what, e, stack))(
        e,
        stack,
      );
    },
  );
  return settled.timeout(
    patience,
    // Flipped in the timer callback itself: a refusal landing after it can
    // only reach the log, since the caller has already been answered.
    onTimeout: () {
      callerWaiting = false;
      AppLogger.info('No answer yet, left in the offline queue: $what');
    },
  );
}

void _logLateRefusal(String what, Object error, StackTrace stack) {
  AppLogger.error(
    'Queued write refused when sent: $what',
    error,
    'QueuedWrite',
    stack,
  );
}
