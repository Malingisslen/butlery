/// Unit tests for BaseMetadataRepository contract.
///
/// Exercised through SharedShoppingViewRepository (concrete subclass) and
/// SharedShoppingDismissalRepository (covers the dismissal-only methods).
/// Builds on top of base_shared_content_repository_test.dart, which already
/// covers `addMetadata` / `hasMetadata` via markAsViewed / hasViewed; this
/// file targets the still-uncovered base methods:
///
/// - `removeMetadata` (success + permission-denied via missing parent)
/// - `getMetadata` (success + null + permission-denied)
/// - `getMetadataForResource` (list, including empty + permission-denied)
/// - `getMetadataCount`
/// - `addMetadataBatch` via `markMultipleAsViewed` (success + propagation)
///
/// The `userId != currentUserId` self-annotation branches in addMetadata/
/// removeMetadata (lines 75-79, 123-127 of SUT) are unreachable through the
/// public concrete API (every wrapper threads the current user) and would
/// require `@visibleForTesting` exposure to cover. Documented gap.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/repositories/firebase/shared_content/shared_shopping_dismissal_repository.dart';
import 'package:butlery/repositories/firebase/shared_content/shared_shopping_view_repository.dart';

import '../../../infrastructure/mocks/production_mocks.dart';

const _alice = 'user-alice';
const _bob = 'user-bob';
const _resource = 'list-1';

SharedShoppingViewRepository _viewRepo(
  FakeFirebaseFirestore firestore, {
  String authedUserId = _alice,
}) {
  final mockAuth = FakeAuthRepository();
  mockAuth.setAuthState(
    user: FakeUser(uid: authedUserId),
    userId: authedUserId,
    isAuthenticated: true,
  );
  return SharedShoppingViewRepository(
    firestore: firestore,
    authRepository: mockAuth,
  );
}

SharedShoppingDismissalRepository _dismissRepo(
  FakeFirebaseFirestore firestore, {
  String authedUserId = _alice,
}) {
  final mockAuth = FakeAuthRepository();
  mockAuth.setAuthState(
    user: FakeUser(uid: authedUserId),
    userId: authedUserId,
    isAuthenticated: true,
  );
  return SharedShoppingDismissalRepository(
    firestore: firestore,
    authRepository: mockAuth,
  );
}

Future<void> _seedParent(
  FakeFirebaseFirestore firestore, {
  String resourceId = _resource,
}) async {
  // The validateMetadataAccess override in SharedShoppingViewRepository
  // checks doc existence on shared_content/{id}.
  await firestore
      .collection('shared_content')
      .doc(resourceId)
      .set({'contentType': 'shopping_list'});
}

void main() {
  group('addMetadata / removeMetadata via concrete wrappers', () {
    test('removeMetadata (via undismiss) removes own dismissal', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _dismissRepo(firestore);
      await _seedParent(firestore);
      await repo.dismiss(_resource, reason: 'not interested');
      expect(await repo.isDismissed(_resource), isTrue);

      await repo.undismiss(_resource);

      expect(await repo.isDismissed(_resource), isFalse);
    });

    test('removeMetadata throws PermissionDenied when parent missing',
        () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _dismissRepo(firestore);
      // Pre-seed a dismissal doc but NO parent shared_content doc; that
      // makes validateMetadataAccess return false on the next remove call.
      await firestore
          .collection('shared_content')
          .doc(_resource)
          .collection('dismissals')
          .doc(_alice)
          .set({'userId': _alice});

      await expectLater(
        () => repo.undismiss(_resource),
        throwsA(isA<PermissionDeniedException>()),
      );
    });
  });

  group('getMetadata (single)', () {
    test('returns null when not annotated', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _viewRepo(firestore);
      await _seedParent(firestore);

      // getUserView wraps getMetadata; null when no annotation present.
      expect(await repo.getUserView(_resource), isNull);
    });

    test('returns parsed metadata when present', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _viewRepo(firestore);
      await _seedParent(firestore);
      await repo.markAsViewed(_resource);

      final got = await repo.getUserView(_resource);
      expect(got, isNotNull);
      expect(got!.userId, _alice);
    });

    test('throws PermissionDenied when parent missing', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _viewRepo(firestore);
      // No parent seeded → validateMetadataAccess returns false.
      await expectLater(
        () => repo.getUserView(_resource),
        throwsA(isA<PermissionDeniedException>()),
      );
    });
  });

  group('getMetadataForResource (list)', () {
    test('returns all annotations for resource', () async {
      final firestore = FakeFirebaseFirestore();
      final aliceRepo = _viewRepo(firestore);
      final bobRepo = _viewRepo(firestore, authedUserId: _bob);
      await _seedParent(firestore);

      await aliceRepo.markAsViewed(_resource);
      await bobRepo.markAsViewed(_resource);

      final viewers = await aliceRepo.getViewers(_resource);
      expect(viewers.map((v) => v.userId).toSet(), {_alice, _bob});
    });

    test('returns empty list when no annotations', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _viewRepo(firestore);
      await _seedParent(firestore);

      final viewers = await repo.getViewers(_resource);
      expect(viewers, isEmpty);
    });

    test('throws PermissionDenied when parent missing', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _viewRepo(firestore);

      await expectLater(
        () => repo.getViewers(_resource),
        throwsA(isA<PermissionDeniedException>()),
      );
    });
  });

  group('getMetadataCount', () {
    test('returns number of annotations', () async {
      final firestore = FakeFirebaseFirestore();
      final aliceRepo = _viewRepo(firestore);
      final bobRepo = _viewRepo(firestore, authedUserId: _bob);
      await _seedParent(firestore);

      expect(await aliceRepo.getViewCount(_resource), 0);
      await aliceRepo.markAsViewed(_resource);
      expect(await aliceRepo.getViewCount(_resource), 1);
      await bobRepo.markAsViewed(_resource);
      expect(await aliceRepo.getViewCount(_resource), 2);
    });

    test('throws PermissionDenied when parent missing', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _viewRepo(firestore);

      await expectLater(
        () => repo.getViewCount(_resource),
        throwsA(isA<PermissionDeniedException>()),
      );
    });
  });

  group('addMetadataBatch / removeMetadataBatch', () {
    test('markMultipleAsViewed annotates each resource', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _viewRepo(firestore);
      await _seedParent(firestore, resourceId: 'l1');
      await _seedParent(firestore, resourceId: 'l2');
      await _seedParent(firestore, resourceId: 'l3');

      await repo.markMultipleAsViewed(['l1', 'l2', 'l3']);

      expect(await repo.hasViewed('l1'), isTrue);
      expect(await repo.hasViewed('l2'), isTrue);
      expect(await repo.hasViewed('l3'), isTrue);
    });

    test('markMultipleAsViewed propagates permission error from a member',
        () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _viewRepo(firestore);
      // Only seed two of the three parents.
      await _seedParent(firestore, resourceId: 'l1');
      await _seedParent(firestore, resourceId: 'l2');

      // l3 parent missing → validateMetadataAccess fails → throws.
      await expectLater(
        () => repo.markMultipleAsViewed(['l1', 'l2', 'l3']),
        throwsA(isA<PermissionDeniedException>()),
      );
    });
  });

  group('engagement / dismissal getters delegate correctly', () {
    test('getDismissals returns dismissals for resource', () async {
      final firestore = FakeFirebaseFirestore();
      final aliceRepo = _dismissRepo(firestore);
      final bobRepo = _dismissRepo(firestore, authedUserId: _bob);
      await _seedParent(firestore);

      await aliceRepo.dismiss(_resource, reason: 'not interested');
      await bobRepo.dismiss(_resource);

      final dismissals = await aliceRepo.getDismissals(_resource);
      expect(dismissals.length, 2);
    });

    test('getDismissalCount returns count', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _dismissRepo(firestore);
      await _seedParent(firestore);
      await repo.dismiss(_resource);

      expect(await repo.getDismissalCount(_resource), 1);
    });

    test('getUserDismissal returns parsed metadata with reason', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _dismissRepo(firestore);
      await _seedParent(firestore);
      await repo.dismiss(_resource, reason: 'already_have');

      final got = await repo.getUserDismissal(_resource);
      expect(got, isNotNull);
      expect(got!.reason, 'already_have');
    });
  });
}
