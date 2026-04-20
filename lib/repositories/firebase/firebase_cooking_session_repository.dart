// lib/repositories/firebase/firebase_cooking_session_repository.dart
//
// BUT-408: RTDB-backed repository for live cooking session presence.
// Mirrors the shape of [FirebaseShoppingPresenceRepository] but uses
// Firebase Realtime Database (not Firestore) because we need
// `onDisconnect().remove()` for server-side cleanup when the device drops.
//
// RTDB path: `cooking_sessions/{groupId}/{userId}`.
//
// GDPR: sessions are ephemeral. They are removed by (a) explicit endSession()
// on cooking mode exit, or (b) RTDB `onDisconnect()` when the device drops.
// There is no account-deletion cascade — stale rows self-clear within seconds
// of the user going offline.

import 'package:firebase_database/firebase_database.dart';

import 'package:butlery/core/utils/log_sanitizer.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/cooking/cooking_session.dart';

/// RTDB repository for live cooking session presence (BUT-408).
///
/// Writes are **best-effort**: offline or permission-denied errors are
/// swallowed and logged — a missed broadcast must never interrupt the cook.
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
