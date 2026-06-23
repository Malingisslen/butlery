// RTDB (not Firestore) — we need `onDisconnect().remove()` for server-side
// cleanup when the device drops. Path: cooking_sessions/{groupId}/{userId}.
//
// GDPR: rows are ephemeral; no account-deletion cascade needed — stale rows
// self-clear within seconds of the user going offline.

import 'package:firebase_database/firebase_database.dart';

import 'package:butlery/core/utils/log_sanitizer.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/cooking/cooking_session.dart';

// Writes are best-effort — offline or permission-denied errors are swallowed
// so a missed broadcast never interrupts the cook.
class FirebaseCookingSessionRepository {
  final FirebaseDatabase _database;

  FirebaseCookingSessionRepository({required FirebaseDatabase database})
    : _database = database;

  /// Root node for all cooking session presence data.
  static const String _rootPath = 'cooking_sessions';

  /// Per-group path where each member's live session may appear.
  DatabaseReference _groupRef(String groupId) =>
      _database.ref('$_rootPath/$groupId');

  /// Per-user leaf within a group — one node per cook per group.
  DatabaseReference _userRef(String groupId, String userId) =>
      _database.ref('$_rootPath/$groupId/$userId');

  /// Announce that [session.userId] has entered cooking mode for [session]
  /// within [groupId]. Registers an `onDisconnect().remove()` handler so
  /// the entry self-clears if the device drops before [endSession] fires.
  Future<void> startSession({
    required String groupId,
    required CookingSession session,
  }) async {
    try {
      final ref = _userRef(groupId, session.userId);
      // Register the disconnect handler BEFORE the set so a crash between
      // the two leaves behind nothing (mirrors PresenceService ordering).
      await ref.onDisconnect().remove();
      await ref.set(session.toMap());
      AppLogger.debug(
        'Cooking session started: ${session.userId.maskedUserId} '
        'in group $groupId',
      );
    } catch (e) {
      // Best-effort — never surface broadcast failures to the cooking UI.
      AppLogger.warning('Failed to start cooking session presence: $e');
    }
  }

  /// Patch just `currentStep` + `totalSteps` on an existing session row.
  /// Uses RTDB [DatabaseReference.update] so we write only the two fields —
  /// the rest of the node is untouched. Best-effort: errors are swallowed.
  ///
  /// If no session row exists at the path, RTDB creates an orphan node with
  /// only the two fields set. The module gates this call behind an
  /// active-session check, so in practice the node always exists already.
  Future<void> updateStep({
    required String groupId,
    required String userId,
    required int currentStep,
    required int totalSteps,
  }) async {
    try {
      final ref = _userRef(groupId, userId);
      await ref.update({
        'currentStep': currentStep,
        'totalSteps': totalSteps,
      });
    } catch (e) {
      AppLogger.warning('Failed to update cooking session step: $e');
    }
  }

  /// Explicitly clear the session for [userId] in [groupId]. Also cancels
  /// the `onDisconnect` handler so we don't race against ourselves.
  Future<void> endSession({
    required String groupId,
    required String userId,
  }) async {
    try {
      final ref = _userRef(groupId, userId);
      await ref.onDisconnect().cancel();
      await ref.remove();
      AppLogger.debug(
        'Cooking session ended: ${userId.maskedUserId} in group $groupId',
      );
    } catch (e) {
      AppLogger.warning('Failed to end cooking session presence: $e');
    }
  }

  /// Stream of all live sessions within [groupId]. Emits an empty list when
  /// no members are cooking. Entries are parsed leniently — a malformed row
  /// is skipped rather than crashing the stream.
  Stream<List<CookingSession>> watchSessions(String groupId) {
    return _groupRef(groupId).onValue.map((event) {
      final raw = event.snapshot.value;
      if (raw == null) return const <CookingSession>[];
      if (raw is! Map) return const <CookingSession>[];

      final sessions = <CookingSession>[];
      raw.forEach((_, value) {
        if (value is Map) {
          try {
            sessions.add(CookingSession.fromMap(value));
          } catch (e) {
            AppLogger.warning('Malformed cooking session row dropped: $e');
          }
        }
      });
      // Stable ordering so merged UIs (e.g. "Erik & Sara") don't flicker.
      sessions.sort((a, b) => a.startedAt.compareTo(b.startedAt));
      return sessions;
    });
  }
}
