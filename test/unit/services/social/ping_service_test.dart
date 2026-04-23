/// Unit tests for [PingService] (BUT-407).
///
/// Focus: the behavioural contract of the ping primitive — rate limiting,
/// cross-group blocking, acknowledge round-trip, expiresAt filtering, and
/// the quiet-hours suppression path. All FCM calls are routed through a
/// fake [NotificationService] so the tests never touch real FCM.
library;

import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/social/ping.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/services/notifications/notification_service.dart';
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/social/ping_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';

class _FakeFirestoreRepository extends Fake implements FirestoreRepository {
  final FakeFirebaseFirestore _fake;
  _FakeFirestoreRepository(this._fake);

  @override
  FirebaseFirestore get firestore => _fake;

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _fake.collection(path);

  @override
  DocumentReference<Map<String, dynamic>> doc(String path) => _fake.doc(path);
}

class _FakePermissionService extends Fake implements PermissionService {
  String? _uid;
  _FakePermissionService(this._uid);

  void setUserId(String? uid) => _uid = uid;

  @override
  String? get currentUserId => _uid;

  @override
  bool get isAuthenticated => _uid != null;
}

class _FakeFriendsService extends Fake implements UnifiedFriendsService {
  List<FriendCategory> _categories = const [];

  void setCategories(List<FriendCategory> cats) => _categories = cats;

  @override
  List<FriendCategory> get categoriesList => List.unmodifiable(_categories);
}

/// Records FCM calls without actually sending — lets us assert push
/// suppression during quiet hours.
class _RecordingNotificationService extends Mock
    implements NotificationService {
  final List<List<String>> calls = [];
  bool suppressAll = false;

  @override
  Future<void> sendImmediateNotification({
    required List<String> targetUserIds,
    required NotificationStrategy strategy,
    required Map<String, String> variables,
    Map<String, dynamic>? additionalData,
    String? imageUrl,
    List<NotificationAction>? actions,
  }) async {
    if (suppressAll) return;
    calls.add(List<String>.from(targetUserIds));
  }
}

void main() {
  late FakeFirebaseFirestore firestore;
  late _FakeFirestoreRepository repo;
  late _FakePermissionService perm;
  late _FakeFriendsService friends;
  late _RecordingNotificationService notifications;
  late PingService service;

  const groupId = 'group-1';
  const ownerId = 'alice';
  const memberId = 'bob';
  const outsiderId = 'carol';

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repo = _FakeFirestoreRepository(firestore);
    perm = _FakePermissionService(ownerId);
    friends = _FakeFriendsService();
    friends.setCategories([
      FriendCategory(
        id: groupId,
        ownerId: ownerId,
        name: 'Familjen',
        friendUserIds: const [memberId],
      ),
    ]);
    notifications = _RecordingNotificationService();
    service = PingService(
      firestoreRepository: repo,
      permissionService: perm,
      friendsService: friends,
      notificationService: notifications,
    );
  });

  group('sendPing', () {
    test('writes ping doc + triggers FCM to directed target', () async {
      final ping = await service.sendPing(
        groupId: groupId,
        toUserId: memberId,
        type: PingType.nudge,
        message: 'börja laga?',
      );

      final snap =
          await firestore.collection('pings/$groupId/pings').doc(ping.id).get();
      expect(snap.exists, isTrue, reason: 'doc written to Firestore');
      expect(snap.data()?['fromUserId'], equals(ownerId));
      expect(snap.data()?['toUserId'], equals(memberId));
      expect(snap.data()?['type'], equals('nudge'));
      expect(snap.data()?['acknowledged'], isFalse);

      // Give the unawaited push a microtask to record.
      await Future<void>.delayed(Duration.zero);
      expect(notifications.calls, hasLength(1));
      expect(notifications.calls.single, equals([memberId]));
    });

    test('cross-group write is rejected (user not in group)', () async {
      // Outsider attempts to ping into a group they're not a member of.
      perm.setUserId(outsiderId);

      expect(
        () => service.sendPing(
          groupId: groupId,
          toUserId: memberId,
          type: PingType.helpMe,
        ),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test('rate-limit trips at 6th ping within an hour', () async {
      // withClock locks time so all 5 pings share the same "now" — the
      // count-query uses > cutoff, so the 6th exceeds kPingMaxPerHour.
      final t0 = DateTime(2026, 4, 21, 10, 0);
      await withClock(Clock.fixed(t0), () async {
        for (var i = 0; i < 5; i++) {
          await service.sendPing(groupId: groupId, type: PingType.nudge);
        }

        expect(
          () => service.sendPing(groupId: groupId, type: PingType.nudge),
          throwsA(isA<PingRateLimitedException>()),
        );
      });
    });

    test('rate-limit window slides — 5 pings > 1h ago do not count', () async {
      // Seed 5 already-expired-window pings directly to Firestore with
      // createdAt 2h ago. We bypass the service so `Ping.create`'s internal
      // `DateTime.now()` doesn't override our backdated timestamps.
      final twoHoursAgo = DateTime.now().subtract(const Duration(hours: 2));
      for (var i = 0; i < 5; i++) {
        final old = Ping(
          id: 'old-$i',
          groupId: groupId,
          fromUserId: ownerId,
          type: PingType.nudge,
          createdAt: twoHoursAgo,
          expiresAt: twoHoursAgo.add(const Duration(minutes: 10)),
        );
        await firestore
            .collection('pings/$groupId/pings')
            .doc(old.id)
            .set(old.toMap());
      }

      // Those 5 fall OUTSIDE the 1h rate-limit window — a fresh ping lands.
      final ok = await service.sendPing(
        groupId: groupId,
        type: PingType.nudge,
      );
      expect(ok.id, isNotEmpty);
    });
  });

  group('watchGroup', () {
    test('expired pings are filtered from the stream', () async {
      // Seed one fresh + one stale ping directly to Firestore.
      final now = DateTime.now();
      final fresh = Ping(
        id: 'fresh',
        groupId: groupId,
        fromUserId: ownerId,
        type: PingType.nudge,
        createdAt: now,
        expiresAt: now.add(const Duration(minutes: 5)),
      );
      final stale = Ping(
        id: 'stale',
        groupId: groupId,
        fromUserId: ownerId,
        type: PingType.nudge,
        createdAt: now.subtract(const Duration(hours: 1)),
        expiresAt: now.subtract(const Duration(minutes: 10)),
      );

      await firestore
          .collection('pings/$groupId/pings')
          .doc(fresh.id)
          .set(fresh.toMap());
      await firestore
          .collection('pings/$groupId/pings')
          .doc(stale.id)
          .set(stale.toMap());

      final pings = await service.watchGroup(groupId).first;
      final ids = pings.map((p) => p.id).toList();
      expect(ids, contains('fresh'));
      expect(ids, isNot(contains('stale')),
          reason: 'expired ping filtered by expiresAt > now');
    });
  });

  group('acknowledge', () {
    test('flips acknowledged flag to true', () async {
      final ping = await service.sendPing(
        groupId: groupId,
        toUserId: memberId,
        type: PingType.nudge,
      );

      // Recipient acknowledges.
      perm.setUserId(memberId);
      await service.acknowledge(groupId: groupId, pingId: ping.id);

      final doc =
          await firestore.collection('pings/$groupId/pings').doc(ping.id).get();
      expect(doc.data()?['acknowledged'], isTrue);
    });

    test('acknowledge on missing ping is a no-op (not-found swallowed)',
        () async {
      // Missing doc — should complete without throwing.
      await service.acknowledge(
        groupId: groupId,
        pingId: 'never-existed',
      );
      expect(true, isTrue); // reached here = no throw
    });
  });

  group('quiet hours / FCM suppression', () {
    test('stream still delivers when FCM is suppressed', () async {
      // Simulate the recipient being in quiet hours — the service-level
      // API we have access to is the notification service's internal
      // filter, but from PingService's perspective we just need to prove
      // that the in-app stream delivers even if FCM is a no-op.
      notifications.suppressAll = true;

      final ping = await service.sendPing(
        groupId: groupId,
        toUserId: memberId,
        type: PingType.nudge,
      );

      await Future<void>.delayed(Duration.zero);
      expect(notifications.calls, isEmpty,
          reason: 'FCM suppressed during quiet hours');

      // In-app stream still sees it.
      final pings = await service.watchGroup(groupId).first;
      expect(pings.map((p) => p.id), contains(ping.id));
    });
  });

  group('broadcast pings', () {
    test('broadcast fans out to all group members except sender', () async {
      // Sender is owner; broadcast should reach memberId but not ownerId.
      await service.sendPing(groupId: groupId, type: PingType.timerAlert);

      await Future<void>.delayed(Duration.zero);
      expect(notifications.calls, hasLength(1));
      final targets = notifications.calls.single;
      expect(targets, contains(memberId));
      expect(targets, isNot(contains(ownerId)),
          reason: 'sender excluded from broadcast recipients');
    });
  });

  group('authentication gate', () {
    test('unauthenticated sendPing throws PermissionDeniedException', () async {
      perm.setUserId(null);
      expect(
        () => service.sendPing(groupId: groupId, type: PingType.nudge),
        throwsA(isA<PermissionDeniedException>()),
      );
    });
  });
}
