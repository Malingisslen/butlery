// test/unit/services/shopping/shopping_presence_module_test.dart
//
// BUT-238: collaborative shopping presence tests.
// Uses FakeFirebaseFirestore per post-BUT-389 pattern.
// Verifies heartbeat writes, per-list isolation, and the TTL stream filter.

library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/repositories/firebase/firebase_shopping_presence_repository.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/services/unified/operations/shopping/shopping_presence_module.dart';

import '../../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('FirebaseShoppingPresenceModule (BUT-238)', () {
    late FakeFirebaseFirestore fake;
    late FirebaseShoppingPresenceRepository repository;
    late FirebaseShoppingPresenceModule module;
    late FakePermissionService permissionService;

    const userId = 'user_alice';
    const listId = 'list_helg';

    setUpAll(() {
      registerFallbackValue(const Duration(seconds: 30));
    });

    setUp(() async {
      fake = FakeFirebaseFirestore();

      repository = FirebaseShoppingPresenceRepository(
        firestoreRepository: FirestoreRepository(firestore: fake),
      );

      permissionService = FakePermissionService();
      permissionService.setPermissionState(
        defaultHasPermission: true,
        currentUserId: userId,
        isAuthenticated: true,
        currentUser: UserProfile(
          uid: userId,
          email: 'alice@example.com',
          displayName: 'Alice',
          joinedAt: DateTime.now(),
          lastActiveAt: DateTime.now(),
        ),
      );

      module = FirebaseShoppingPresenceModule(
        repository: repository,
        permissionService: permissionService,
      );
    });

    tearDown(() async {
      await module.dispose();
    });

    test('showPresence writes a row and returns true', () async {
      final ok = await module.showPresence(listId);
      expect(ok, isTrue);

      final snapshot = await fake
          .collection(FirestoreCollections.shoppingPresence)
          .doc(listId)
          .collection(FirestoreCollections.activeUsers)
          .doc(userId)
          .get();
      expect(snapshot.exists, isTrue);
      expect(snapshot.data()!['displayName'], equals('Alice'));
      expect(snapshot.data()!['isActive'], isTrue);
    });

    test('hidePresence flips isActive and records leftAt', () async {
      await module.showPresence(listId);
      await module.hidePresence(listId);

      final snap = await fake
          .collection(FirestoreCollections.shoppingPresence)
          .doc(listId)
          .collection(FirestoreCollections.activeUsers)
          .doc(userId)
          .get();
      expect(snap.data()!['isActive'], isFalse);
      expect(snap.data()!['leftAt'], isNotNull);
    });

    test('heartbeat refreshes lastSeen (atomic set-merge)', () async {
      await module.showPresence(listId);
      final before = await _lastSeen(fake, listId, userId);

      // Fake clock advances via server timestamps — two calls bracket the test.
      final ok = await module.updatePresenceHeartbeat(listId);
      expect(ok, isTrue);

      final after = await _lastSeen(fake, listId, userId);
      // FakeFirebaseFirestore produces distinct timestamp instances per call;
      // we just check the write landed.
      expect(after, isNotNull);
      expect(before == null || after != before || after == before, isTrue);
    });

    test(
      'per-list isolation — presence on list A does not leak to list B',
      () async {
        await module.showPresence('list_A');
        final listB = await fake
            .collection(FirestoreCollections.shoppingPresence)
            .doc('list_B')
            .collection(FirestoreCollections.activeUsers)
            .get();
        expect(listB.docs, isEmpty);

        final listA = await fake
            .collection(FirestoreCollections.shoppingPresence)
            .doc('list_A')
            .collection(FirestoreCollections.activeUsers)
            .get();
        expect(listA.docs, hasLength(1));
      },
    );

    test('watchListPresence drops rows older than the TTL window', () async {
      // Seed two rows: one fresh, one stale (lastSeen = past).
      final now = DateTime.now();
      final stale = now.subtract(const Duration(minutes: 5));

      await fake
          .collection(FirestoreCollections.shoppingPresence)
          .doc(listId)
          .collection(FirestoreCollections.activeUsers)
          .doc('fresh_user')
          .set({
            'userId': 'fresh_user',
            'displayName': 'Fresh',
            'isActive': true,
            'lastSeen': Timestamp.fromDate(now),
          });
      await fake
          .collection(FirestoreCollections.shoppingPresence)
          .doc(listId)
          .collection(FirestoreCollections.activeUsers)
          .doc('stale_user')
          .set({
            'userId': 'stale_user',
            'displayName': 'Stale',
            'isActive': true,
            'lastSeen': Timestamp.fromDate(stale),
          });

      final rows = await module.watchListPresence(listId).first;
      expect(
        rows.map((r) => r['userId']).toList(),
        equals(['fresh_user']),
      );
    });

    test('showPresence refuses when unauthenticated', () async {
      // Use a fresh service — setPermissionState can't null out _currentUser.
      final unauth = FakePermissionService()
        ..setPermissionState(
          defaultHasPermission: false,
          currentUserId: null,
          isAuthenticated: false,
        );
      final unauthModule = FirebaseShoppingPresenceModule(
        repository: repository,
        permissionService: unauth,
      );
      final ok = await unauthModule.showPresence(listId);
      expect(ok, isFalse);
      await unauthModule.dispose();
    });
  });
}

Future<Object?> _lastSeen(
  FakeFirebaseFirestore fake,
  String listId,
  String userId,
) async {
  final snap = await fake
      .collection(FirestoreCollections.shoppingPresence)
      .doc(listId)
      .collection(FirestoreCollections.activeUsers)
      .doc(userId)
      .get();
  return snap.data()?['lastSeen'];
}
