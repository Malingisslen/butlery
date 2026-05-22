/// Unit tests for FirebaseGroupWeeklyMenuPlanRepository.
///
/// Pure-Dart; FakeFirebaseFirestore. Targets ~61 unhit lines.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/menu/group_weekly_menu_plan.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/repositories/firebase/firebase_group_weekly_menu_plan_repository.dart';

import '../../../infrastructure/mocks/production_mocks.dart';

const _alice = 'user-alice';
const _bob = 'user-bob';
const _group = 'group-1';

FirebaseGroupWeeklyMenuPlanRepository _repo(
  FakeFirebaseFirestore firestore, {
  String authedUserId = _alice,
}) {
  final mockAuth = MockAuthRepository();
  mockAuth.setAuthState(
    user: FakeUser(uid: authedUserId),
    userId: authedUserId,
    isAuthenticated: true,
  );
  return FirebaseGroupWeeklyMenuPlanRepository(
    firestore: firestore,
    authRepository: mockAuth,
  );
}

GroupWeeklyMenuPlan _plan({
  String groupId = _group,
  String creatorId = _alice,
  DateTime? date,
  List<GroupMenuParticipant>? participants,
}) {
  return GroupWeeklyMenuPlan.empty(
    groupId: groupId,
    creatorId: creatorId,
    date: date ?? DateTime.utc(2026, 1, 15),
    initialParticipants: participants,
  );
}

void main() {
  group('permission validators', () {
    test('validateCreatePermission true when id prefix + participant match',
        () async {
      final repo = _repo(FakeFirebaseFirestore());
      final plan = _plan();

      expect(await repo.validateCreatePermission(_alice, plan), isTrue);
    });

    test('validateCreatePermission false when user not a participant',
        () async {
      final repo = _repo(FakeFirebaseFirestore());
      final plan = _plan();

      expect(await repo.validateCreatePermission(_bob, plan), isFalse);
    });

    test('validateReadPermission true for participant', () async {
      final repo = _repo(FakeFirebaseFirestore());
      final plan = _plan();

      expect(await repo.validateReadPermission(_alice, plan.id, plan), isTrue);
    });

    test('validateReadPermission false for non-participant', () async {
      final repo = _repo(FakeFirebaseFirestore());
      final plan = _plan();

      expect(await repo.validateReadPermission(_bob, plan.id, plan), isFalse);
    });

    test('validateReadPermission delegates to rules when entity null',
        () async {
      final repo = _repo(FakeFirebaseFirestore());
      expect(await repo.validateReadPermission(_alice, 'any', null), isTrue);
    });

    test('validateUpdatePermission true for editor/admin participant',
        () async {
      final repo = _repo(FakeFirebaseFirestore());
      final plan = _plan();

      expect(
          await repo.validateUpdatePermission(_alice, plan.id, plan), isTrue);
    });

    test('validateUpdatePermission false for view-only participant', () async {
      final repo = _repo(FakeFirebaseFirestore());
      final plan = _plan(participants: [
        GroupMenuParticipant(
          userId: _alice,
          permission: SharedListPermission.view,
          addedAt: DateTime.utc(2026, 1, 1),
        ),
      ]);

      expect(
          await repo.validateUpdatePermission(_alice, plan.id, plan), isFalse);
    });

    test('validateDeletePermission always true (rules enforce)', () async {
      final repo = _repo(FakeFirebaseFirestore());
      expect(await repo.validateDeletePermission(_alice, 'any'), isTrue);
    });
  });

  group('fetchForWeek', () {
    test('returns null when doc missing', () async {
      final repo = _repo(FakeFirebaseFirestore());
      final result = await repo.fetchForWeek(
          groupId: _group, weekStart: DateTime.utc(2026, 1, 15));
      expect(result, isNull);
    });

    test('returns parsed plan when doc exists', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      final plan = _plan();

      await firestore
          .collection('group_weekly_menu_plans')
          .doc(plan.id)
          .set(plan.toFirestore());

      final fetched = await repo.fetchForWeek(
          groupId: _group, weekStart: DateTime.utc(2026, 1, 15));
      expect(fetched, isNotNull);
      expect(fetched!.id, plan.id);
      expect(fetched.groupId, _group);
    });
  });

  group('save', () {
    test('persists plan when user has edit permission', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      final plan = _plan();

      await repo.save(plan, userId: _alice);

      final doc = await firestore
          .collection('group_weekly_menu_plans')
          .doc(plan.id)
          .get();
      expect(doc.exists, isTrue);
    });

    test('persists plan when userId not provided (no permission check)',
        () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      final plan = _plan();

      await repo.save(plan);

      final doc = await firestore
          .collection('group_weekly_menu_plans')
          .doc(plan.id)
          .get();
      expect(doc.exists, isTrue);
    });

    test('rejects save when id/groupId mismatch (returns silently)', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      // Manually construct a plan with mismatched id.
      final plan = GroupWeeklyMenuPlan(
        id: 'wrong-prefix_2026-W03',
        groupId: _group,
        weekStartDate: DateTime.utc(2026, 1, 15),
        entries: const [],
        participants: [
          GroupMenuParticipant(
            userId: _alice,
            permission: SharedListPermission.admin,
            addedAt: DateTime.utc(2026, 1, 1),
          ),
        ],
        createdAt: DateTime.utc(2026, 1, 1),
        lastModifiedAt: DateTime.utc(2026, 1, 1),
      );

      await repo.save(plan);

      final doc = await firestore
          .collection('group_weekly_menu_plans')
          .doc(plan.id)
          .get();
      expect(doc.exists, isFalse);
    });

    test('rejects save when user lacks edit permission', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      final plan = _plan(participants: [
        GroupMenuParticipant(
          userId: _alice,
          permission: SharedListPermission.view, // not editor/admin
          addedAt: DateTime.utc(2026, 1, 1),
        ),
      ]);

      await repo.save(plan, userId: _alice);

      // Should be silently blocked.
      final doc = await firestore
          .collection('group_weekly_menu_plans')
          .doc(plan.id)
          .get();
      expect(doc.exists, isFalse);
    });

    test('overwrites on resave (deterministic id)', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      final plan = _plan();

      await repo.save(plan);
      // Second save with same id — should overwrite, not collide.
      await repo.save(plan);
    });
  });

  group('watchForWeek', () {
    test('emits null when doc missing', () async {
      final repo = _repo(FakeFirebaseFirestore());
      final first = await repo
          .watchForWeek(groupId: _group, date: DateTime.utc(2026, 1, 15))
          .first;
      expect(first, isNull);
    });

    test('emits plan when present', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      final plan = _plan();

      await firestore
          .collection('group_weekly_menu_plans')
          .doc(plan.id)
          .set(plan.toFirestore());

      final first = await repo
          .watchForWeek(groupId: _group, date: DateTime.utc(2026, 1, 15))
          .first;
      expect(first, isNotNull);
      expect(first!.id, plan.id);
    });
  });
}
