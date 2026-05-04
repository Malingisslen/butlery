/// Group-scoped ping primitive.
///
/// Rate limit: 5/hour/user — enforced client-side via a count-aggregate query,
/// plus a 60s burst guard in Firestore rules. A Cloud Function sweeper for the
/// strict hourly cap is a tracked follow-up.
library;

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';

import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/social/ping.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/repositories/mixins/permission_validation_mixin.dart';
import 'package:butlery/services/notifications/notification_service.dart';
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';

class PingRateLimitedException implements Exception {
  final String message;
  PingRateLimitedException(this.message);

  @override
  String toString() => 'PingRateLimitedException: $message';
}

const int kPingMaxPerHour = 5;
const Duration kPingRateWindow = Duration(hours: 1);

class PingService extends BaseService with PermissionValidationMixin {
  final FirestoreRepository _firestoreRepository;
  final PermissionService? _permissionServiceOverride;
  final UnifiedFriendsService? _friendsServiceOverride;
  final NotificationService? _notificationServiceOverride;

  PingService({
    required FirestoreRepository firestoreRepository,
    PermissionService? permissionService,
    UnifiedFriendsService? friendsService,
    NotificationService? notificationService,
  })  : _firestoreRepository = firestoreRepository,
        _permissionServiceOverride = permissionService,
        _friendsServiceOverride = friendsService,
        _notificationServiceOverride = notificationService;

  @override
  String get serviceName => 'PingService';

  PermissionService get _permissionService =>
      _permissionServiceOverride ?? ServiceLocator.get<PermissionService>();

  UnifiedFriendsService get _friendsService =>
      _friendsServiceOverride ?? ServiceLocator.get<UnifiedFriendsService>();

  // Optional: tests and offline-first flows can skip the FCM leg entirely by
  // not registering a NotificationService.
  NotificationService? get _notificationService {
    if (_notificationServiceOverride != null) {
      return _notificationServiceOverride;
    }
    try {
      return ServiceLocator.get<NotificationService>();
    } catch (_) {
      return null;
    }
  }

  CollectionReference<Map<String, dynamic>> _pingsCollection(String groupId) {
    return _firestoreRepository
        .collection(FirestoreCollections.pings)
        .doc(groupId)
        .collection(FirestoreCollections.pings);
  }

  /// Send a ping to [toUserId] (or broadcast if null) within [groupId].
  ///
  /// Throws:
  ///   - [PermissionDeniedException] if the sender is not a member of the
  ///     group or is unauthenticated.
  ///   - [PingRateLimitedException] if the sender is at the hourly cap.
  Future<Ping> sendPing({
    required String groupId,
    String? toUserId,
    required PingType type,
    String? message,
  }) async {
    final userId = _permissionService.currentUserId;
    if (userId == null) {
      throw PermissionDeniedException(
        'Must be authenticated to send pings',
        resource: 'pings',
        operation: 'create',
      );
    }

    // Group membership is the gating check — a user must be in the
    // FriendCategory to ping its members. Mirrors the server rule.
    await _assertGroupMember(userId: userId, groupId: groupId);
    await _assertUnderRateLimit(userId: userId, groupId: groupId);

    final ping = Ping.create(
      groupId: groupId,
      fromUserId: userId,
      toUserId: toUserId,
      type: type,
      message: message,
    );

    await _pingsCollection(groupId).doc(ping.id).set(ping.toMap());

    // Fire-and-forget — push failures must not block the write; the in-app
    // stream still delivers.
    unawaited(_sendPush(ping));

    AppLogger.info(
      'Ping sent: group=$groupId type=${type.name} '
      'from=$userId to=${toUserId ?? "broadcast"}',
    );
    return ping;
  }

  Stream<List<Ping>> watchGroup(String groupId) {
    final now = clock.now();
    return _pingsCollection(groupId)
        .where('expiresAt', isGreaterThan: Timestamp.fromDate(now))
        .orderBy('expiresAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Ping.fromMap(d.id, d.data()))
            // Long-lived streams outlive the query-time `now` boundary.
            .where((p) => !p.isExpired)
            .toList(growable: false));
  }

  Future<void> acknowledge({
    required String groupId,
    required String pingId,
  }) async {
    final userId = _permissionService.currentUserId;
    if (userId == null) {
      throw PermissionDeniedException(
        'Must be authenticated to acknowledge pings',
        resource: 'pings',
        operation: 'update',
      );
    }

    try {
      await _pingsCollection(groupId).doc(pingId).update({
        'acknowledged': true,
      });
    } on FirebaseException catch (e) {
      if (e.code == 'not-found') {
        AppLogger.debug('Ping $pingId already gone — ack is a no-op');
        return;
      }
      rethrow;
    }
  }

  Future<void> _assertGroupMember({
    required String userId,
    required String groupId,
  }) async {
    final isMember = _friendsService.categoriesList.any(
      (c) =>
          c.id == groupId &&
          (c.ownerId == userId || c.friendUserIds.contains(userId)),
    );
    if (!isMember) {
      AppLogger.warning(
        'Ping rejected: user $userId not a member of group $groupId',
      );
      throw PermissionDeniedException(
        'User is not a member of this group',
        resource: 'pings/$groupId',
        operation: 'create',
        userId: userId,
      );
    }
  }

  Future<void> _assertUnderRateLimit({
    required String userId,
    required String groupId,
  }) async {
    final cutoff = clock.now().subtract(kPingRateWindow);
    final snap = await _pingsCollection(groupId)
        .where('fromUserId', isEqualTo: userId)
        .where('createdAt', isGreaterThan: Timestamp.fromDate(cutoff))
        .count()
        .get();
    final count = snap.count ?? 0;

    if (count >= kPingMaxPerHour) {
      AppLogger.warning(
        'Ping rate-limit hit: user=$userId group=$groupId count=$count',
      );
      throw PingRateLimitedException(
        'Too many pings in the last hour (limit: $kPingMaxPerHour)',
      );
    }
  }

  // Routes each ping type to a dedicated strategy and resolves the
  // sender's display name from the friends service so the recipient sees
  // "Knuff från Anna" instead of a UID. UID fallback only when the sender
  // isn't in the recipient's friends list (cross-group, removed friend).
  Future<void> _sendPush(Ping ping) async {
    final svc = _notificationService;
    if (svc == null) return;

    final targets = <String>[];
    if (ping.toUserId != null) {
      targets.add(ping.toUserId!);
    } else {
      final group = _friendsService.categoriesList
          .firstWhereOrNull((c) => c.id == ping.groupId);
      if (group != null) {
        final recipients = group.allMemberIds.toSet()..remove(ping.fromUserId);
        targets.addAll(recipients);
      }
    }

    if (targets.isEmpty) return;

    final senderName = _resolveSenderDisplayName(ping.fromUserId);
    final strategy = _strategyFor(ping.type);

    try {
      await svc.sendImmediateNotification(
        targetUserIds: targets,
        strategy: strategy,
        variables: {
          'senderName': senderName,
          'pingType': ping.type.name,
          'message': ping.message ?? '',
        },
        additionalData: {
          'type': NotificationPayloadType.ping,
          'pingId': ping.id,
          'groupId': ping.groupId,
          'pingType': ping.type.name,
        },
      );
    } catch (e) {
      AppLogger.warning('Ping FCM push failed (non-blocking): $e');
    }
  }

  String _resolveSenderDisplayName(String uid) {
    final profile = _friendsService.friends.firstWhereOrNull(
      (f) => f.uid == uid,
    );
    final name = profile?.displayName.trim() ?? '';
    // Fall back to the UID when the sender isn't a known friend — better
    // than a blank name. The recipient will at least see SOMETHING.
    return name.isEmpty ? uid : name;
  }

  NotificationStrategy _strategyFor(PingType type) {
    return switch (type) {
      PingType.nudge => NotificationStrategy.pingNudge,
      PingType.timerAlert => NotificationStrategy.pingTimerAlert,
      PingType.helpMe => NotificationStrategy.pingHelpMe,
      // Newer client wrote a type we don't understand — render the
      // generic nudge copy rather than silently misattributing semantics.
      PingType.unknown => NotificationStrategy.pingNudge,
    };
  }
}
