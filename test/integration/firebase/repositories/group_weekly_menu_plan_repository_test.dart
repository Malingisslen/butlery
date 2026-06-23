/// Integration tests for [FirebaseGroupWeeklyMenuPlanRepository] (BUT-405).
///
/// Mirrors `weekly_menu_plan_repository_test.dart` (BUT-361 template): uses
/// FakeFirebaseFirestore + MockFirebaseAuth. Exercises deterministic
/// doc-ID upsert, missing-doc null, prefix-range delete with >500 docs,
/// cross-group delete isolation, and the internal permission-method
/// invariants (doc-ID prefix + participant membership).
library;

// ignore_for_file: subtype_of_sealed_class

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/utils/iso_week_utils.dart';
import 'package:butlery/models/menu/group_weekly_menu_plan.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart'
    show SharedListPermission;
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/repositories/firebase/firebase_group_weekly_menu_plan_repository.dart';

import '../../../test_support/base_unit_test.dart';
import '../../../test_support/test_data_isolator.dart';

const _collection = FirestoreCollections.groupWeeklyMenuPlans;

GroupWeeklyMenuPlan _buildPlan({
  required String groupId,
  required DateTime weekStart,
  List<GroupMenuParticipant>? participants,
  List<WeeklyMenuPlanEntry> entries = const [],
}) {
  final created = DateTime(2026, 4, 18, 12);
  return GroupWeeklyMenuPlan(
    id: IsoWeekUtils.weekIdFor(groupId, weekStart),
    groupId: groupId,
    weekStartDate: IsoWeekUtils.weekStartOf(weekStart),
    entries: entries,
    participants:
        participants ??
        [
          GroupMenuParticipant(
            userId: 'user-alpha',
            permission: SharedListPermission.admin,
            addedAt: created,
          ),
        ],
    createdAt: created,
    lastModifiedAt: created,
    lastModifiedBy: 'user-alpha',
  );
}

void main() {
  group('FirebaseGroupWeeklyMenuPlanRepository', () {
    late FakeFirebaseFirestore firestore;
    late FirebaseGroupWeeklyMenuPlanRepository repository;
    late MockFirebaseAuth mockAuth;

    const callerId = 'user-alpha';
    const groupId = 'fam-abc';
    final weekStart = IsoWeekUtils.weekStartOf(
      DateTime(2026, 4, 13),
    ); // ISO Mon

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() async {
      TestDataIsolator.initializeTest('GroupWeeklyMenuPlanRepository');
      firestore = FakeFirebaseFirestore();
      mockAuth = MockFirebaseAuth(
        mockUser: MockUser(
          uid: callerId,
          email: 'alpha@example.com',
          displayName: 'Alpha',
        ),
        signedIn: true,
      );
      repository = FirebaseGroupWeeklyMenuPlanRepository(
        firestore: firestore,
        authRepository: FirebaseAuthRepository(firebaseAuth: mockAuth),
      );
    });

    tearDown(() async {
      await TestDataIsolator.cleanupTest('GroupWeeklyMenuPlanRepository');
    });

    group('save (deterministic upsert)', () {
      test(
        'should use deterministic `{groupId}_{YYYY}-W{WW}` doc ID so '
        'saving the same (group, week) twice does not create duplicates',
        () async {
          final planA = _buildPlan(groupId: groupId, weekStart: weekStart);
          await repository.save(planA);

          final planB = planA.copyWith(
            entries: [
              WeeklyMenuPlanEntry.create(
                day: DayOfWeek.wed,
                slot: MealSlot.middag,
                recipeId: 'recipe-1',
                recipeTitle: 'Pasta',
              ),
            ],
          );
          await repository.save(planB);

          final snapshot = await firestore.collection(_collection).get();
          expect(
            snapshot.docs,
            hasLength(1),
            reason: 'upsert must overwrite, not append a second doc',
          );
          expect(
            snapshot.docs.first.id,
            IsoWeekUtils.weekIdFor(groupId, weekStart),
          );
          final entriesField = snapshot.docs.first.data()['entries'] as List;
          expect(entriesField, hasLength(1));
          expect((entriesField.first as Map)['recipeTitle'], 'Pasta');
        },
      );

      test('should refuse to persist a plan whose doc-ID prefix does not match '
          'the entity.groupId (internal self-consistency check)', () async {
        // Construct a plan whose id does NOT start with the entity's
        // groupId. save() must log-and-return rather than create the doc.
        final forged = GroupWeeklyMenuPlan(
          id: 'spoofed_2026-W15', // prefix does not match groupId below
          groupId: 'real-group',
          weekStartDate: IsoWeekUtils.weekStartOf(weekStart),
          entries: const [],
          participants: [
            GroupMenuParticipant(
              userId: callerId,
              permission: SharedListPermission.admin,
              addedAt: DateTime(2026, 4, 18, 12),
            ),
          ],
          createdAt: DateTime(2026, 4, 18, 12),
          lastModifiedAt: DateTime(2026, 4, 18, 12),
          lastModifiedBy: callerId,
        );

        await repository.save(forged);

        final snapshot = await firestore.collection(_collection).get();
        expect(
          snapshot.docs,
          isEmpty,
          reason: 'save() must block when id/groupId prefix mismatch',
        );
      });

      test(
        'should persist when userId is an editor on the plan '
        '(belt-and-braces permission check mirrors the user-plan repo)',
        () async {
          final plan = _buildPlan(
            groupId: groupId,
            weekStart: weekStart,
            participants: [
              GroupMenuParticipant(
                userId: 'admin-uid',
                permission: SharedListPermission.admin,
                addedAt: DateTime(2026, 4, 1),
              ),
              GroupMenuParticipant(
                userId: 'editor-uid',
                permission: SharedListPermission.edit,
                addedAt: DateTime(2026, 4, 1),
              ),
            ],
          );

          await repository.save(plan, userId: 'editor-uid');

          final snapshot = await firestore.collection(_collection).get();
          expect(
            snapshot.docs,
            hasLength(1),
            reason: 'editor must be allowed to save',
          );
        },
      );

      test(
        'should refuse to persist when userId lacks editor permission '
        '(view-only or non-participant) even if the doc-ID prefix is valid',
        () async {
          final plan = _buildPlan(
            groupId: groupId,
            weekStart: weekStart,
            participants: [
              GroupMenuParticipant(
                userId: 'admin-uid',
                permission: SharedListPermission.admin,
                addedAt: DateTime(2026, 4, 1),
              ),
              GroupMenuParticipant(
                userId: 'viewer-uid',
                permission: SharedListPermission.view,
                addedAt: DateTime(2026, 4, 1),
              ),
            ],
          );

          // Viewer — not an editor — must be rejected.
          await repository.save(plan, userId: 'viewer-uid');
          var snapshot = await firestore.collection(_collection).get();
          expect(
            snapshot.docs,
            isEmpty,
            reason:
                'view-only member must be blocked by save() permission check',
          );

          // Non-participant stranger — also rejected.
          await repository.save(plan, userId: 'stranger-uid');
          snapshot = await firestore.collection(_collection).get();
          expect(
            snapshot.docs,
            isEmpty,
            reason:
                'non-participant must be blocked by save() permission check',
          );
        },
      );

      test('should persist the denormalised `memberPermissions` + '
          '`participantUserIds` fields so Firestore rules can enforce '
          'per-user access', () async {
        final plan = _buildPlan(
          groupId: groupId,
          weekStart: weekStart,
          participants: [
            GroupMenuParticipant(
              userId: 'admin-uid',
              permission: SharedListPermission.admin,
              addedAt: DateTime(2026, 4, 1),
            ),
            GroupMenuParticipant(
              userId: 'editor-uid',
              permission: SharedListPermission.edit,
              addedAt: DateTime(2026, 4, 1),
            ),
            GroupMenuParticipant(
              userId: 'viewer-uid',
              permission: SharedListPermission.view,
              addedAt: DateTime(2026, 4, 1),
            ),
          ],
        );
        await repository.save(plan);

        final snapshot = await firestore
            .collection(_collection)
            .doc(plan.id)
            .get();
        final data = snapshot.data()!;
        expect(
          data['participantUserIds'],
          equals(['admin-uid', 'editor-uid', 'viewer-uid']),
        );
        expect(
          data['memberPermissions'],
          equals({
            'admin-uid': 'admin',
            'editor-uid': 'edit',
            'viewer-uid': 'view',
          }),
          reason: 'rules depend on memberPermissions map-key access',
        );
      });
    });

    group('fetchForWeek', () {
      test('should return null for a week with no saved plan', () async {
        final result = await repository.fetchForWeek(
          groupId: groupId,
          weekStart: weekStart,
        );
        expect(result, isNull);
      });

      test(
        'should round-trip a saved plan, preserving entries + participants',
        () async {
          final entry = WeeklyMenuPlanEntry.create(
            day: DayOfWeek.fri,
            slot: MealSlot.lunch,
            recipeId: 'recipe-fri-lunch',
            recipeTitle: 'Tacos',
          );
          final saved = _buildPlan(
            groupId: groupId,
            weekStart: weekStart,
            entries: [entry],
          );
          await repository.save(saved);

          final fetched = await repository.fetchForWeek(
            groupId: groupId,
            weekStart: weekStart,
          );

          expect(fetched, isNotNull);
          expect(fetched!.id, IsoWeekUtils.weekIdFor(groupId, weekStart));
          expect(fetched.groupId, groupId);
          expect(fetched.entries, hasLength(1));
          expect(fetched.entries.first.recipeTitle, 'Tacos');
          expect(fetched.participants, hasLength(1));
          expect(fetched.participants.single.userId, 'user-alpha');
        },
      );
    });

    group('deleteAllByGroup — group-prefix range delete', () {
      test('should delete only the target group\'s plans when multiple groups '
          'have docs in the same collection', () async {
        const groupIds = ['group-alpha', 'group-beta', 'group-gamma'];
        final weeks = [
          DateTime(2026, 4, 6),
          DateTime(2026, 4, 13),
          DateTime(2026, 4, 20),
        ];
        for (final gid in groupIds) {
          for (final w in weeks) {
            final docId = IsoWeekUtils.weekIdFor(gid, w);
            await firestore.collection(_collection).doc(docId).set({
              'groupId': gid,
              'weekStartDate': Timestamp.fromDate(IsoWeekUtils.weekStartOf(w)),
              'entries': <Map<String, dynamic>>[],
              'participants': <Map<String, dynamic>>[],
              'participantUserIds': <String>[],
              'memberPermissions': <String, String>{},
              'createdAt': Timestamp.now(),
              'lastModifiedAt': Timestamp.now(),
            });
          }
        }

        final before = await firestore.collection(_collection).get();
        expect(before.docs, hasLength(9));

        final deleted = await repository.deleteAllByGroup('group-alpha');

        expect(deleted, 3);
        final after = await firestore.collection(_collection).get();
        expect(after.docs, hasLength(6));
        final remainingGroups = after.docs
            .map((d) => d.data()['groupId'])
            .toSet();
        expect(remainingGroups, {
          'group-beta',
          'group-gamma',
        }, reason: 'only the target group should have been erased');
      });

      test('should return 0 when the group has no plans', () async {
        final deleted = await repository.deleteAllByGroup('nonexistent');
        expect(deleted, 0);
      });

      test('should chunk deletes through batchDeleteDocs when the result set '
          'exceeds the 500-op Firestore batch limit', () async {
        const targetGroup = 'bulk-group';
        for (var i = 0; i < 600; i++) {
          final docId =
              '${targetGroup}_${2010 + (i ~/ 53)}'
              '-W${((i % 53) + 1).toString().padLeft(2, '0')}';
          await firestore.collection(_collection).doc(docId).set({
            'groupId': targetGroup,
            'weekStartDate': Timestamp.now(),
            'entries': <Map<String, dynamic>>[],
            'participants': <Map<String, dynamic>>[],
            'participantUserIds': <String>[],
            'memberPermissions': <String, String>{},
            'createdAt': Timestamp.now(),
            'lastModifiedAt': Timestamp.now(),
          });
        }

        // Seed an unrelated group so we can prove the prefix scope holds.
        await firestore.collection(_collection).doc('other-group_2026-W15').set(
          {
            'groupId': 'other-group',
            'weekStartDate': Timestamp.now(),
            'entries': <Map<String, dynamic>>[],
            'participants': <Map<String, dynamic>>[],
            'participantUserIds': <String>[],
            'memberPermissions': <String, String>{},
            'createdAt': Timestamp.now(),
            'lastModifiedAt': Timestamp.now(),
          },
        );

        final deleted = await repository.deleteAllByGroup(targetGroup);

        expect(
          deleted,
          600,
          reason: 'batch chunking must not drop docs past the 500 boundary',
        );
        final after = await firestore.collection(_collection).get();
        expect(after.docs, hasLength(1));
        expect(after.docs.single.data()['groupId'], 'other-group');
      });
    });

    group('permission filter (doc-ID prefix + participant membership)', () {
      test(
        'validateUpdatePermission should reject when the actor is not an '
        'editor/admin on the plan (participant permission enforcement)',
        () async {
          final plan = _buildPlan(
            groupId: groupId,
            weekStart: weekStart,
            participants: [
              GroupMenuParticipant(
                userId: 'admin-uid',
                permission: SharedListPermission.admin,
                addedAt: DateTime(2026, 4, 1),
              ),
              GroupMenuParticipant(
                userId: 'viewer-uid',
                permission: SharedListPermission.view,
                addedAt: DateTime(2026, 4, 1),
              ),
            ],
          );

          expect(
            await repository.validateUpdatePermission(
              'admin-uid',
              plan.id,
              plan,
            ),
            isTrue,
          );
          expect(
            await repository.validateUpdatePermission(
              'viewer-uid',
              plan.id,
              plan,
            ),
            isFalse,
            reason: 'view-only members cannot write',
          );
          expect(
            await repository.validateUpdatePermission(
              'stranger-uid',
              plan.id,
              plan,
            ),
            isFalse,
            reason: 'non-participants cannot write',
          );
        },
      );

      test('validateCreatePermission should require the doc-ID prefix match '
          'AND the creator to be a participant', () async {
        final validPlan = _buildPlan(groupId: groupId, weekStart: weekStart);
        expect(
          await repository.validateCreatePermission(callerId, validPlan),
          isTrue,
        );

        // Creator not in participants — should be rejected.
        final unlistedPlan = _buildPlan(
          groupId: groupId,
          weekStart: weekStart,
          participants: [
            GroupMenuParticipant(
              userId: 'someone-else',
              permission: SharedListPermission.admin,
              addedAt: DateTime(2026, 4, 1),
            ),
          ],
        );
        expect(
          await repository.validateCreatePermission(callerId, unlistedPlan),
          isFalse,
        );
      });

      test('validateReadPermission should accept only participants when an '
          'entity snapshot is available (rules also enforce; this is the '
          'application-layer check)', () async {
        final plan = _buildPlan(groupId: groupId, weekStart: weekStart);
        expect(
          await repository.validateReadPermission(callerId, plan.id, plan),
          isTrue,
        );
        expect(
          await repository.validateReadPermission('stranger', plan.id, plan),
          isFalse,
        );
      });
    });
  });
}
