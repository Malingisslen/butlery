/// Unit tests for FirebaseHouseholdRepository.
///
/// Pure-Dart; FakeFirebaseFirestore. Focus: the household-membership
/// permission model (members read; only admins update/delete; update/delete
/// read the CURRENT doc so a caller cannot self-elevate) and the
/// getForUser/ensureForUser/isMember resolution helpers.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/household.dart';
import 'package:butlery/repositories/firebase/firebase_household_repository.dart';

import '../../../infrastructure/mocks/production_mocks.dart';

const _malin = 'user-malin';
const _johan = 'user-johan';
const _stranger = 'user-stranger';

FirebaseHouseholdRepository _repo(
  FakeFirebaseFirestore firestore, {
  String authedUserId = _malin,
}) {
  final mockAuth = FakeAuthRepository();
  mockAuth.setAuthState(
    user: FakeUser(uid: authedUserId),
    userId: authedUserId,
    isAuthenticated: true,
  );
  return FirebaseHouseholdRepository(
    firestore: firestore,
    authRepository: mockAuth,
  );
}

/// A household where Malin is admin and Johan is an editor.
Household _twoParent({String id = 'hh-1'}) {
  return Household(
    id: id,
    name: Household.defaultName,
    members: [
      HouseholdMember(
        userId: _malin,
        permission: SharedListPermission.admin,
        addedAt: DateTime.utc(2026, 1, 1),
      ),
      HouseholdMember(
        userId: _johan,
        permission: SharedListPermission.edit,
        addedAt: DateTime.utc(2026, 1, 1),
      ),
    ],
    createdBy: _malin,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );
}

Future<void> _seed(FakeFirebaseFirestore fs, Household hh) =>
    fs.collection('households').doc(hh.id).set(hh.toFirestore());

void main() {
  group('create permission', () {
    test('true when creator is a member', () async {
      final repo = _repo(FakeFirebaseFirestore());
      expect(
        await repo.validateCreatePermission(_malin, _twoParent()),
        isTrue,
      );
    });

    test('false when the actor is not a member', () async {
      final repo = _repo(FakeFirebaseFirestore());
      expect(
        await repo.validateCreatePermission(_stranger, _twoParent()),
        isFalse,
      );
    });
  });

  group('read permission', () {
    test('both members can read; an outsider cannot', () async {
      final repo = _repo(FakeFirebaseFirestore());
      final hh = _twoParent();
      expect(await repo.validateReadPermission(_malin, hh.id, hh), isTrue);
      expect(await repo.validateReadPermission(_johan, hh.id, hh), isTrue);
      expect(await repo.validateReadPermission(_stranger, hh.id, hh), isFalse);
    });

    test('delegates to rules when entity is null', () async {
      final repo = _repo(FakeFirebaseFirestore());
      expect(await repo.validateReadPermission(_malin, 'any', null), isTrue);
    });
  });

  group('update/delete permission read the CURRENT doc', () {
    test('admin can update, an editor cannot', () async {
      final fs = FakeFirebaseFirestore();
      final hh = _twoParent();
      await _seed(fs, hh);

      final repo = _repo(fs);
      expect(await repo.validateUpdatePermission(_malin, hh.id, hh), isTrue);
      expect(await repo.validateUpdatePermission(_johan, hh.id, hh), isFalse);
    });

    test('admin can delete, an editor cannot', () async {
      final fs = FakeFirebaseFirestore();
      final hh = _twoParent();
      await _seed(fs, hh);

      final repo = _repo(fs);
      expect(await repo.validateDeletePermission(_malin, hh.id), isTrue);
      expect(await repo.validateDeletePermission(_johan, hh.id), isFalse);
    });

    test(
      'self-elevation is rejected — checks stored state not the payload',
      () async {
        // Johan (an editor) submits an entity that makes HIM admin. The check
        // must read the CURRENT doc (where he is only an editor) and deny.
        final fs = FakeFirebaseFirestore();
        final stored = _twoParent();
        await _seed(fs, stored);

        final elevated = Household(
          id: stored.id,
          name: stored.name,
          members: [
            HouseholdMember(
              userId: _johan,
              permission: SharedListPermission.admin,
              addedAt: DateTime.utc(2026, 1, 1),
            ),
          ],
          createdBy: stored.createdBy,
          createdAt: stored.createdAt,
          updatedAt: DateTime.utc(2026, 2, 1),
        );

        final repo = _repo(fs);
        expect(
          await repo.validateUpdatePermission(_johan, stored.id, elevated),
          isFalse,
        );
      },
    );

    test('update/delete on a missing doc is denied', () async {
      final repo = _repo(FakeFirebaseFirestore());
      expect(
        await repo.validateUpdatePermission(_malin, 'ghost', _twoParent()),
        isFalse,
      );
      expect(await repo.validateDeletePermission(_malin, 'ghost'), isFalse);
    });
  });

  group('getForUser', () {
    test('returns the household each member belongs to', () async {
      final fs = FakeFirebaseFirestore();
      await _seed(fs, _twoParent());

      // Each call must run as that user (caller-identity guard).
      expect(
        await _repo(fs, authedUserId: _malin).getForUser(_malin),
        hasLength(1),
      );
      expect(
        await _repo(fs, authedUserId: _johan).getForUser(_johan),
        hasLength(1),
      );
      expect(
        await _repo(fs, authedUserId: _stranger).getForUser(_stranger),
        isEmpty,
      );
    });

    test('a caller cannot list another user\'s households', () async {
      // The High-severity guard: an authed user requesting someone else's id
      // gets nothing, even though that household exists.
      final fs = FakeFirebaseFirestore();
      await _seed(fs, _twoParent());
      final asMalin = _repo(fs, authedUserId: _malin);
      expect(await asMalin.getForUser(_johan), isEmpty);
    });

    test('isolates results across multiple households', () async {
      // Two distinct households with disjoint membership — each user sees only
      // their own. Catches an arrayContains field-name/filter bug.
      final fs = FakeFirebaseFirestore();
      await _seed(fs, _twoParent(id: 'hh-malin'));
      await _seed(
        fs,
        Household(
          id: 'hh-stranger',
          name: Household.defaultName,
          members: [
            HouseholdMember(
              userId: _stranger,
              permission: SharedListPermission.admin,
              addedAt: DateTime.utc(2026, 1, 1),
            ),
          ],
          createdBy: _stranger,
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
      );

      final malinHouseholds = await _repo(
        fs,
        authedUserId: _malin,
      ).getForUser(_malin);
      final strangerHouseholds = await _repo(
        fs,
        authedUserId: _stranger,
      ).getForUser(_stranger);

      expect(malinHouseholds, hasLength(1));
      expect(malinHouseholds.single.id, 'hh-malin');
      expect(strangerHouseholds, hasLength(1));
      expect(strangerHouseholds.single.id, 'hh-stranger');
    });
  });

  group('ensureForUser', () {
    test('returns the existing household when one exists', () async {
      final fs = FakeFirebaseFirestore();
      final existing = _twoParent();
      await _seed(fs, existing);
      final repo = _repo(fs);

      final result = await repo.ensureForUser(_malin);
      expect(result.id, existing.id);
    });

    test('creates a fresh single-member household when none exists', () async {
      final fs = FakeFirebaseFirestore();
      final repo = _repo(fs);

      final created = await repo.ensureForUser(_malin);
      expect(created.isMember(_malin), isTrue);
      expect(created.canAdmin(_malin), isTrue);
      expect(created.members, hasLength(1));

      // Persisted and resolvable on a second call (no duplicate).
      final again = await repo.ensureForUser(_malin);
      expect(again.id, created.id);
    });
  });

  group('isMember', () {
    test('reflects stored membership for the caller', () async {
      final fs = FakeFirebaseFirestore();
      final hh = _twoParent();
      await _seed(fs, hh);

      // Each query runs as the user it asks about (caller-only guard).
      expect(
        await _repo(fs, authedUserId: _johan).isMember(hh.id, _johan),
        isTrue,
      );
      expect(
        await _repo(fs, authedUserId: _stranger).isMember(hh.id, _stranger),
        isFalse,
      );
      expect(
        await _repo(fs, authedUserId: _malin).isMember('ghost', _malin),
        isFalse,
      );
    });

    test('refuses to answer membership about another user', () async {
      final fs = FakeFirebaseFirestore();
      final hh = _twoParent();
      await _seed(fs, hh);
      // Authed as Malin, asking about Johan → guarded to false.
      expect(
        await _repo(fs, authedUserId: _malin).isMember(hh.id, _johan),
        isFalse,
      );
    });
  });

  group('view-tier member', () {
    Household withViewer() => Household(
      id: 'hh-v',
      name: Household.defaultName,
      members: [
        HouseholdMember(
          userId: _malin,
          permission: SharedListPermission.admin,
          addedAt: DateTime.utc(2026, 1, 1),
        ),
        HouseholdMember(
          userId: _stranger,
          permission: SharedListPermission.view,
          addedAt: DateTime.utc(2026, 1, 1),
        ),
      ],
      createdBy: _malin,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );

    test('a viewer can read but cannot update or delete', () async {
      final fs = FakeFirebaseFirestore();
      final hh = withViewer();
      await _seed(fs, hh);
      final repo = _repo(fs, authedUserId: _stranger);

      expect(await repo.validateReadPermission(_stranger, hh.id, hh), isTrue);
      expect(
        await repo.validateUpdatePermission(_stranger, hh.id, hh),
        isFalse,
      );
      expect(await repo.validateDeletePermission(_stranger, hh.id), isFalse);
      expect(await repo.isMember(hh.id, _stranger), isTrue);
    });
  });
}
