/// Unit tests for FirebaseGroupWeeklyMenuPlanRepository.
///
/// Pure-Dart; FakeFirebaseFirestore.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/models/menu/group_weekly_menu_plan.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/repositories/firebase/firebase_audit_repository.dart';
import 'package:butlery/repositories/firebase/firebase_group_weekly_menu_plan_repository.dart';

import '../../../infrastructure/mocks/production_mocks.dart';

const _alice = 'user-alice';
const _bob = 'user-bob';
const _group = 'group-1';

FirebaseGroupWeeklyMenuPlanRepository _repo(
  FakeFirebaseFirestore firestore, {
  String authedUserId = _alice,
  bool withAudit = false,
}) {
  final mockAuth = FakeAuthRepository();
  mockAuth.setAuthState(
    user: FakeUser(uid: authedUserId),
    userId: authedUserId,
    isAuthenticated: true,
  );
  return FirebaseGroupWeeklyMenuPlanRepository(
    firestore: firestore,
    authRepository: mockAuth,
    auditRepository: withAudit ? FirebaseAuditRepository(firestore) : null,
  );
}

/// A repository whose auth repository reports nobody signed in.
FirebaseGroupWeeklyMenuPlanRepository _signedOutRepo(
  FakeFirebaseFirestore firestore,
) {
  final mockAuth = FakeAuthRepository();
  mockAuth.setAuthState(user: null, userId: null, isAuthenticated: false);
  return FirebaseGroupWeeklyMenuPlanRepository(
    firestore: firestore,
    authRepository: mockAuth,
    auditRepository: FirebaseAuditRepository(firestore),
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
    test(
      'validateCreatePermission true when id prefix + participant match',
      () async {
        final repo = _repo(FakeFirebaseFirestore());
        final plan = _plan();

        expect(await repo.validateCreatePermission(_alice, plan), isTrue);
      },
    );

    test(
      'validateCreatePermission false when user not a participant',
      () async {
        final repo = _repo(FakeFirebaseFirestore());
        final plan = _plan();

        expect(await repo.validateCreatePermission(_bob, plan), isFalse);
      },
    );

    // The prefix conjunct had no negative arm: both cases above carry a
    // matching prefix, so deleting `entity.id.startsWith(...)` from
    // `validateCreatePermission` left the whole suite green.
    test(
      'validateCreatePermission false when the id prefix does not match',
      () async {
        final repo = _repo(FakeFirebaseFirestore());
        final base = _plan();
        final mismatched = GroupWeeklyMenuPlan(
          id: 'wrong-prefix_2026-W03',
          groupId: _group,
          weekStartDate: base.weekStartDate,
          entries: base.entries,
          participants: base.participants,
          createdAt: base.createdAt,
          lastModifiedAt: base.lastModifiedAt,
        );

        // Alice IS a participant, so only the prefix can decide.
        expect(
          await repo.validateCreatePermission(_alice, mismatched),
          isFalse,
        );
      },
    );

    test('validateReadPermission true for participant', () async {
      final repo = _repo(FakeFirebaseFirestore());
      final plan = _plan();

      expect(await repo.validateReadPermission(_alice, plan.id, plan), isTrue);
    });

    test('validateReadPermission false when the doc id belongs to ANOTHER '
        'group (BUT-1974)', () async {
      // Without the prefix conjunct a document keyed to a different group
      // passed on membership alone.
      final repo = _repo(FakeFirebaseFirestore());
      final plan = _plan();

      expect(
        await repo.validateReadPermission(_alice, 'other-group_2026-W03', plan),
        isFalse,
        reason: 'membership alone must not carry another group id',
      );
    });

    test('validateReadPermission false for non-participant', () async {
      final repo = _repo(FakeFirebaseFirestore());
      final plan = _plan();

      expect(await repo.validateReadPermission(_bob, plan.id, plan), isFalse);
    });

    test(
      'validateReadPermission delegates to rules when entity null',
      () async {
        final repo = _repo(FakeFirebaseFirestore());
        expect(await repo.validateReadPermission(_alice, 'any', null), isTrue);
      },
    );

    test(
      'validateUpdatePermission true for editor/admin participant',
      () async {
        final repo = _repo(FakeFirebaseFirestore());
        final plan = _plan();

        expect(
          await repo.validateUpdatePermission(_alice, plan.id, plan),
          isTrue,
        );
      },
    );

    test('validateUpdatePermission false for view-only participant', () async {
      final repo = _repo(FakeFirebaseFirestore());
      final plan = _plan(
        participants: [
          GroupMenuParticipant(
            userId: _alice,
            permission: SharedListPermission.view,
            addedAt: DateTime.utc(2026, 1, 1),
          ),
        ],
      );

      expect(
        await repo.validateUpdatePermission(_alice, plan.id, plan),
        isFalse,
      );
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
        groupId: _group,
        weekStart: DateTime.utc(2026, 1, 15),
      );
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
        groupId: _group,
        weekStart: DateTime.utc(2026, 1, 15),
      );
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

    test(
      'persists plan when userId not provided (no permission check)',
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
      },
    );

    test(
      'rejects save when id/groupId mismatch — and the caller is told',
      () async {
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

        // BUT-1962: this used to assert a silent return, which is what let a
        // refused write look identical to a completed one.
        await expectLater(repo.save(plan), throwsA(isA<StateError>()));

        final doc = await firestore
            .collection('group_weekly_menu_plans')
            .doc(plan.id)
            .get();
        expect(doc.exists, isFalse);
      },
    );

    test('rejects save when user lacks edit permission', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore);
      final plan = _plan(
        participants: [
          GroupMenuParticipant(
            userId: _alice,
            permission: SharedListPermission.view, // not editor/admin
            addedAt: DateTime.utc(2026, 1, 1),
          ),
        ],
      );

      await expectLater(
        repo.save(plan, userId: _alice),
        throwsA(isA<PermissionDeniedException>()),
      );

      // Blocked, and the refusal reached the caller (BUT-1962).
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

  /// GDPR Article 15/20 — the participation probe, which had zero coverage.
  ///
  /// It was spelled `.where('memberPermissions.$userId', isNotEqualTo: null)`.
  /// The cloud_firestore SDK adds a condition only when the argument is
  /// non-null (`query.dart:659`), so a literal `null` added NO condition at all
  /// and this became an unfiltered read of EVERY group's menu plans instead of
  /// the requester's participation. The `group_weekly_menu_plans` read rule is
  /// scoped to participants, so the server refuses that query outright — the
  /// user-visible symptom is not an over-share but "my shared data mysteriously
  /// will not load", with a whole export section collapsing into an error.
  /// `isNull: false` is the supported spelling of the same intent, and it is
  /// the identical fix the three BUT-1732 shared-shopping-list probes carry.
  ///
  /// Both halves are asserted — own participation returned, another group's
  /// plan absent — because a conditionless query satisfies the first alone.
  /// `FakeFirebaseFirestore` throws `Unsupported` on `isNotEqualTo: null`
  /// rather than silently degrading, so reverting the spelling reddens loudly.
  group('exportPlansForParticipant (BUT-1732)', () {
    Future<FakeFirebaseFirestore> seeded() async {
      final firestore = FakeFirebaseFirestore();
      final plans = firestore.collection('group_weekly_menu_plans');
      await plans.doc('group-1_2026-01-15').set(<String, dynamic>{
        'groupId': 'group-1',
        'memberPermissions': <String, dynamic>{_alice: 'edit'},
      });
      await plans.doc('group-2_2026-01-15').set(<String, dynamic>{
        'groupId': 'group-2',
        'memberPermissions': <String, dynamic>{_bob: 'admin'},
      });
      return firestore;
    }

    test('returns only the plans naming the requester', () async {
      final repo = _repo(await seeded());

      final result = await repo.exportPlansForParticipant(_alice);

      expect(result.map((row) => row['id']), <String>['group-1_2026-01-15']);
      expect(
        result.map((row) => row['id']),
        isNot(contains('group-2_2026-01-15')),
        reason:
            "another group's plan names a different uid under "
            'memberPermissions, so only a per-uid key filter excludes it',
      );
      expect(
        (result.single['data'] as Map)['groupId'],
        'group-1',
        reason: 'Art. 15 requires the document, not just its id',
      );
    });

    test('a user who participates in nothing gets an empty list', () async {
      final firestore = await seeded();
      final repo = _repo(firestore, authedUserId: 'user-nobody');

      expect(await repo.exportPlansForParticipant('user-nobody'), isEmpty);
    });

    test('respects maxDocuments', () async {
      final firestore = await seeded();
      for (var i = 0; i < 3; i++) {
        await firestore
            .collection('group_weekly_menu_plans')
            .doc('group-extra-$i')
            .set(<String, dynamic>{
              'groupId': 'group-extra-$i',
              'memberPermissions': <String, dynamic>{_alice: 'edit'},
            });
      }

      final result = await _repo(
        firestore,
      ).exportPlansForParticipant(_alice, maxDocuments: 2);

      expect(result, hasLength(2));
    });

    /// Defence-in-depth: the ownership guard still refuses somebody else's
    /// participation record even though the predicate is now correct.
    test('refuses to export another user id', () async {
      final repo = _repo(await seeded());

      await expectLater(
        repo.exportPlansForParticipant(_bob),
        throwsA(isA<PermissionDeniedException>()),
      );
    });
  });

  group('save audits refusals only (BUT-1981)', () {
    // The group half of the same change, which nothing pinned: both group
    // suites were green against the pre-change bytes, because neither passed
    // an `auditRepository` at all.
    //
    // It matters more here than on the per-user repo. That gate compares the
    // plan to itself and can only fail on a mis-keyed id; this one takes the
    // actor as a separate argument, so its refusal branch is reached by a real
    // permission decision — and dropping the granted row costs edit history on
    // a document more than one person can write.
    test('a GRANTED save writes no audit row', () async {
      final firestore = FakeFirebaseFirestore();
      final repo = _repo(firestore, withAudit: true);
      final plan = _plan(
        participants: [
          GroupMenuParticipant(
            userId: _alice,
            permission: SharedListPermission.admin,
            addedAt: DateTime.utc(2026, 1, 1),
          ),
        ],
      );

      await repo.save(plan, userId: _alice);

      final rows = await firestore
          .collection(FirestoreCollections.auditLogs)
          .get();
      expect(rows.docs, isEmpty);
      // The save itself must have happened, or an empty audit collection is
      // also satisfied by a write that never ran.
      final saved = await firestore
          .collection(FirestoreCollections.groupWeeklyMenuPlans)
          .doc(plan.id)
          .get();
      expect(saved.exists, isTrue);
    });

    test(
      'a save with nobody signed in throws before writing anything',
      () async {
        // Pins the hoist on THIS repository too. Without it, every fixture here
        // is signed in and alice is admin, so `canWrite` is true, the refusal
        // branch is skipped, and pushing `requireCurrentUserId()` back into it
        // leaves both group suites green while the write goes through.
        final firestore = FakeFirebaseFirestore();
        final repo = _signedOutRepo(firestore);
        final plan = _plan(
          participants: [
            GroupMenuParticipant(
              userId: _alice,
              permission: SharedListPermission.admin,
              addedAt: DateTime.utc(2026, 1, 1),
            ),
          ],
        );

        await expectLater(
          repo.save(plan, userId: _alice),
          throwsA(isA<AuthenticationException>()),
        );

        final saved = await firestore
            .collection(FirestoreCollections.groupWeeklyMenuPlans)
            .doc(plan.id)
            .get();
        expect(saved.exists, isFalse);
        final rows = await firestore
            .collection(FirestoreCollections.auditLogs)
            .get();
        expect(rows.docs, isEmpty);
      },
    );

    test(
      'a REFUSED save writes one audit row naming the AUTHENTICATED actor',
      () async {
        final firestore = FakeFirebaseFirestore();
        // Signed in as bob; the permission decision is made about alice, who is
        // view-only. The two uids diverge on purpose: the row must name bob,
        // because the rules refuse an `audit_logs` create whose uid is not the
        // caller's.
        final repo = _repo(firestore, authedUserId: _bob, withAudit: true);
        final plan = _plan(
          participants: [
            GroupMenuParticipant(
              userId: _alice,
              permission: SharedListPermission.view,
              addedAt: DateTime.utc(2026, 1, 1),
            ),
          ],
        );

        await expectLater(
          repo.save(plan, userId: _alice),
          throwsA(isA<PermissionDeniedException>()),
        );

        final rows = await firestore
            .collection(FirestoreCollections.auditLogs)
            .get();
        expect(rows.docs, hasLength(1));
        expect(rows.docs.single.data()['granted'], isFalse);
        expect(rows.docs.single.data()['userId'], _bob);

        final saved = await firestore
            .collection(FirestoreCollections.groupWeeklyMenuPlans)
            .doc(plan.id)
            .get();
        expect(saved.exists, isFalse);
      },
    );
  });
}
