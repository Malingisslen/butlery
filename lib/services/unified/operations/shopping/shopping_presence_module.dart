// lib/services/unified/operations/shopping/shopping_presence_module.dart
//
// Collaborative shopping presence tracking (BUT-238).
// Mirrors [PresenceTrackingModule] (recipe presence) but scoped to shopping lists.
// Per-list, 30s TTL heartbeat, atomic `set(merge: true)` writes.

import 'dart:async';

import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/repositories/firebase/firebase_shopping_presence_repository.dart';
import 'package:butlery/services/permission_service.dart';

/// Public contract for shopping presence — used for DI registration so tests
/// can swap in a fake without reaching into Firestore.
abstract class ShoppingPresenceModule {
  /// Announce user is actively viewing the collaborative list.
  Future<bool> showPresence(String listId);

  /// Announce user has left (or backgrounded) the list.
  Future<bool> hidePresence(String listId);

  /// Periodic lastSeen refresh — called by automatic tracker below.
  Future<bool> updatePresenceHeartbeat(String listId);

  /// Stream of active shoppers for header indicator.
  /// Emits the full list of active user presence maps on every change.
  Stream<List<Map<String, dynamic>>> watchListPresence(String listId);

  /// Start the 30s heartbeat for a list. Returns a subscription the caller
  /// is responsible for cancelling (wired to view lifecycle).
  StreamSubscription<void> startAutomaticPresenceTracking(
    String listId, {
    Duration heartbeatInterval = const Duration(seconds: 30),
  });

  /// Stop the heartbeat for a list. Safe to call multiple times.
  void stopAutomaticPresenceTracking(String listId);

  /// Clear all presence + release streams. Called on logout / dispose.
  Future<void> dispose();
}

/// Firestore-backed implementation.
///
/// Write model: per-list doc at `shoppingPresence/{listId}/activeUsers/{userId}`.
/// Heartbeat default: 30s (BUT-238 spec). Atomic writes via `set(merge: true)`.
class FirebaseShoppingPresenceModule implements ShoppingPresenceModule {
  /// Default heartbeat cadence (BUT-238 spec: 30s).
  static const Duration defaultHeartbeat = Duration(seconds: 30);

  /// TTL window — if lastSeen is older than this, drop from presence.
  /// Set to 2×heartbeat so a missed tick does not flicker the indicator.
  static const Duration ttl = Duration(seconds: 60);

  final FirebaseShoppingPresenceRepository _repository;
  final PermissionService? _permissionServiceOverride;

  final Map<String, StreamSubscription<void>> _heartbeatSubscriptions = {};

  FirebaseShoppingPresenceModule({
    required FirebaseShoppingPresenceRepository repository,
    PermissionService? permissionService,
  })  : _repository = repository,
        _permissionServiceOverride = permissionService;

  PermissionService get _permissionService =>
      _permissionServiceOverride ?? ServiceLocator.get<PermissionService>();

  @override
  Future<bool> showPresence(String listId) async {
    try {
      if (!_permissionService.isAuthenticated) return false;
      final currentUser = _permissionService.currentUser;
      if (currentUser == null) return false;

      await _repository.setUserPresence(
        listId: listId,
        userId: currentUser.uid,
        displayName: currentUser.displayName,
        avatarUrl: currentUser.avatarUrl,
      );
      AppLogger.info(
          'Shopping presence: ${currentUser.displayName} entered list $listId');
      return true;
    } catch (e) {
      AppLogger.error('showPresence failed', e);
      return false;
    }
  }

  @override
  Future<bool> hidePresence(String listId) async {
    try {
      if (!_permissionService.isAuthenticated) return false;
      final currentUser = _permissionService.currentUser;
      if (currentUser == null) return false;

      await _repository.markUserInactive(
        listId: listId,
        userId: currentUser.uid,
      );
      return true;
    } catch (e) {
      AppLogger.error('hidePresence failed', e);
      return false;
    }
  }

  @override
  Future<bool> updatePresenceHeartbeat(String listId) async {
    try {
      if (!_permissionService.isAuthenticated) return false;
      final userId = _permissionService.currentUserId;
      if (userId == null) return false;

      await _repository.updatePresenceHeartbeat(
        listId: listId,
        userId: userId,
      );
      return true;
    } catch (e) {
      AppLogger.error('updatePresenceHeartbeat failed', e);
      return false;
    }
  }

  @override
  Stream<List<Map<String, dynamic>>> watchListPresence(String listId) {
    return _repository.watchActiveUsers(listId).map((rows) {
      // Recompute cutoff on each tick so stale rows drop as time advances.
      final cutoff = DateTime.now().subtract(ttl);
      // Client-side TTL filter — Firestore rule allows stale rows until
      // heartbeat GC catches up. We drop anything older than 2×heartbeat.
      return rows.where((row) {
        final lastSeen = row['lastSeen'];
        if (lastSeen == null) return true; // optimistically include
        if (lastSeen is DateTime) return lastSeen.isAfter(cutoff);
        // Firestore Timestamp → DateTime
        try {
          final dt = (lastSeen as dynamic).toDate();
          return dt is DateTime && dt.isAfter(cutoff);
        } catch (_) {
          return true;
        }
      }).toList(growable: false);
    });
  }

  @override
  StreamSubscription<void> startAutomaticPresenceTracking(
    String listId, {
    Duration heartbeatInterval = defaultHeartbeat,
  }) {
    _heartbeatSubscriptions[listId]?.cancel();
    final subscription = Stream<void>.periodic(heartbeatInterval, (_) {})
        .listen((_) => updatePresenceHeartbeat(listId));
    _heartbeatSubscriptions[listId] = subscription;
    return subscription;
  }

  @override
  void stopAutomaticPresenceTracking(String listId) {
    _heartbeatSubscriptions[listId]?.cancel();
    _heartbeatSubscriptions.remove(listId);
  }

  @override
  Future<void> dispose() async {
    for (final sub in _heartbeatSubscriptions.values) {
      await sub.cancel();
    }
    _heartbeatSubscriptions.clear();
  }
}
