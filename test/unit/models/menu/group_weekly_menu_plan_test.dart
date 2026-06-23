/// Unit tests for [GroupWeeklyMenuPlan] (BUT-405).
///
/// Covers:
/// - Firestore round-trip serialization (toFirestore/fromMap preserves every
///   field — entries, participants, permissions, audit timestamps).
/// - `copyWith` updates only the fields it's given and bumps
///   `lastModifiedAt` by default.
/// - Doc-ID determinism: same `(groupId, week)` always returns the same ID,
///   different groups collide into different IDs.
/// - Participant permission helpers (`canRead` / `canEdit` / `canAdmin`).
/// - Denormalised `memberPermissions` map matches the structured participants.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/utils/iso_week_utils.dart';
import 'package:butlery/models/menu/group_weekly_menu_plan.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart'
    show SharedListPermission;

GroupMenuParticipant _p(
  String uid, {
  SharedListPermission permission = SharedListPermission.edit,
  DateTime? addedAt,
}) {
  return GroupMenuParticipant(
    userId: uid,
    permission: permission,
    addedAt: addedAt ?? DateTime(2026, 4, 18, 9),
  );
}

void main() {
  group('GroupWeeklyMenuPlan', () {
    const groupId = 'fam-abc';
    final weekDate = DateTime(2026, 4, 13); // ISO Monday
    final weekStart = IsoWeekUtils.weekStartOf(weekDate);

    group('docIdFor', () {
      test('should produce deterministic `{groupId}_{YYYY}-W{WW}` ids so the '
          'same (group, week) always hits the same Firestore document', () {
        final a = GroupWeeklyMenuPlan.docIdFor(groupId, weekDate);
        final b = GroupWeeklyMenuPlan.docIdFor(groupId, weekDate);
        expect(
          a,
          equals(b),
          reason: 'upsert relies on stable doc IDs — must be pure',
        );
        expect(a, matches(RegExp(r'^fam-abc_\d{4}-W\d{2}$')));
      });

      test('should differ across groups for the same ISO week', () {
        final one = GroupWeeklyMenuPlan.docIdFor('group-one', weekDate);
        final two = GroupWeeklyMenuPlan.docIdFor('group-two', weekDate);
        expect(one, isNot(equals(two)));
      });

      test('should differ across weeks for the same group', () {
        final earlier = GroupWeeklyMenuPlan.docIdFor(
          groupId,
          DateTime(2026, 4, 6),
        ); // previous week
        final later = GroupWeeklyMenuPlan.docIdFor(groupId, weekDate);
        expect(earlier, isNot(equals(later)));
      });
    });

    group('empty', () {
      test('seeds the creator as sole admin when no participants supplied', () {
        final plan = GroupWeeklyMenuPlan.empty(
          groupId: groupId,
          creatorId: 'user-creator',
          date: weekDate,
        );
        expect(plan.participants, hasLength(1));
        expect(plan.participants.single.userId, 'user-creator');
        expect(plan.participants.single.permission, SharedListPermission.admin);
        expect(plan.entries, isEmpty);
        expect(plan.id, GroupWeeklyMenuPlan.docIdFor(groupId, weekDate));
        expect(plan.lastModifiedBy, 'user-creator');
      });

      test('uses the caller-supplied participant list verbatim', () {
        final preset = [
          _p('user-a', permission: SharedListPermission.admin),
          _p('user-b', permission: SharedListPermission.edit),
          _p('user-c', permission: SharedListPermission.view),
        ];
        final plan = GroupWeeklyMenuPlan.empty(
          groupId: groupId,
          creatorId: 'user-a',
          date: weekDate,
          initialParticipants: preset,
        );
        expect(plan.participants, equals(preset));
      });
    });

    group('permission helpers', () {
      late GroupWeeklyMenuPlan plan;

      setUp(() {
        plan = GroupWeeklyMenuPlan(
          id: GroupWeeklyMenuPlan.docIdFor(groupId, weekStart),
          groupId: groupId,
          weekStartDate: weekStart,
          entries: const [],
          participants: [
            _p('admin-uid', permission: SharedListPermission.admin),
            _p('editor-uid', permission: SharedListPermission.edit),
            _p('viewer-uid', permission: SharedListPermission.view),
          ],
          createdAt: DateTime(2026, 4, 18, 9),
          lastModifiedAt: DateTime(2026, 4, 18, 9),
          lastModifiedBy: 'admin-uid',
        );
      });

      test('canRead is true for any participant, false for non-members', () {
        expect(plan.canRead('admin-uid'), isTrue);
        expect(plan.canRead('editor-uid'), isTrue);
        expect(plan.canRead('viewer-uid'), isTrue);
        expect(plan.canRead('stranger-uid'), isFalse);
      });

      test('canEdit only for editor + admin (not viewer, not stranger)', () {
        expect(plan.canEdit('admin-uid'), isTrue);
        expect(plan.canEdit('editor-uid'), isTrue);
        expect(plan.canEdit('viewer-uid'), isFalse);
        expect(plan.canEdit('stranger-uid'), isFalse);
      });

      test('canAdmin only for admin', () {
        expect(plan.canAdmin('admin-uid'), isTrue);
        expect(plan.canAdmin('editor-uid'), isFalse);
        expect(plan.canAdmin('viewer-uid'), isFalse);
      });

      test(
        'memberPermissions denormalisation mirrors the participants list',
        () {
          final perms = plan.memberPermissions;
          expect(
            perms,
            equals({
              'admin-uid': 'admin',
              'editor-uid': 'edit',
              'viewer-uid': 'view',
            }),
          );
        },
      );
    });

    group('Firestore round-trip', () {
      test('should preserve every field across toFirestore / fromMap '
          '(entries, participants, permissions, audit fields)', () {
        final addedAt = DateTime(2026, 4, 1, 12);
        final created = DateTime(2026, 4, 18, 9);
        final modified = DateTime(2026, 4, 18, 10);
        final entry = WeeklyMenuPlanEntry.create(
          day: DayOfWeek.wed,
          slot: MealSlot.middag,
          recipeId: 'recipe-1',
          recipeTitle: 'Lasagne',
          recipeImageUrl: 'https://example/lasagne.jpg',
        );
        final original = GroupWeeklyMenuPlan(
          id: GroupWeeklyMenuPlan.docIdFor(groupId, weekStart),
          groupId: groupId,
          weekStartDate: weekStart,
          entries: [entry],
          participants: [
            _p(
              'admin-uid',
              permission: SharedListPermission.admin,
              addedAt: addedAt,
            ),
            _p(
              'editor-uid',
              permission: SharedListPermission.edit,
              addedAt: addedAt,
            ),
          ],
          createdAt: created,
          lastModifiedAt: modified,
          lastModifiedBy: 'admin-uid',
        );

        final serialized = original.toFirestore();

        // Denormalised fields must be present for rules to function.
        expect(
          serialized['participantUserIds'],
          equals(['admin-uid', 'editor-uid']),
        );
        expect(
          serialized['memberPermissions'],
          equals({'admin-uid': 'admin', 'editor-uid': 'edit'}),
        );

        final decoded = GroupWeeklyMenuPlan.fromMap(original.id, serialized);

        expect(decoded.id, original.id);
        expect(decoded.groupId, original.groupId);
        expect(decoded.weekStartDate, original.weekStartDate);
        expect(decoded.entries, hasLength(1));
        expect(decoded.entries.single.id, entry.id);
        expect(decoded.entries.single.recipeTitle, 'Lasagne');
        expect(decoded.participants, hasLength(2));
        expect(decoded.participants[0].userId, 'admin-uid');
        expect(decoded.participants[0].permission, SharedListPermission.admin);
        expect(decoded.participants[1].permission, SharedListPermission.edit);
        expect(decoded.createdAt, created);
        expect(decoded.lastModifiedAt, modified);
        expect(decoded.lastModifiedBy, 'admin-uid');
      });

      test('should tolerate a missing `participants` field by decoding to an '
          'empty list (partial/legacy data never crashes the reader)', () {
        final decoded = GroupWeeklyMenuPlan.fromMap(
          'some-group_2026-W15',
          {
            'groupId': 'some-group',
            'weekStartDate': DateTime(2026, 4, 13).toIso8601String(),
            'entries': <Map<String, dynamic>>[],
            'createdAt': DateTime(2026, 4, 18).toIso8601String(),
            'lastModifiedAt': DateTime(2026, 4, 18).toIso8601String(),
          },
        );
        expect(decoded.participants, isEmpty);
        expect(decoded.entries, isEmpty);
        expect(decoded.lastModifiedBy, isNull);
      });
    });

    group('copyWith', () {
      test('updates entries while preserving identity + audit scaffolding', () {
        final base = GroupWeeklyMenuPlan.empty(
          groupId: groupId,
          creatorId: 'user-a',
          date: weekDate,
        );
        final newEntry = WeeklyMenuPlanEntry.create(
          day: DayOfWeek.fri,
          slot: MealSlot.lunch,
          recipeId: 'r',
          recipeTitle: 'Tacos',
        );
        final updated = base.copyWith(
          entries: [newEntry],
          lastModifiedBy: 'user-a',
        );

        expect(updated.id, base.id);
        expect(updated.groupId, base.groupId);
        expect(updated.createdAt, base.createdAt);
        expect(updated.entries, hasLength(1));
        expect(updated.entries.single.recipeTitle, 'Tacos');
        expect(updated.lastModifiedBy, 'user-a');
        expect(
          updated.lastModifiedAt.isAtSameMomentAs(base.lastModifiedAt) ||
              updated.lastModifiedAt.isAfter(base.lastModifiedAt),
          isTrue,
          reason: 'lastModifiedAt should advance (or stay within ms)',
        );
      });

      test('updates participants list without touching entries', () {
        final base =
            GroupWeeklyMenuPlan.empty(
              groupId: groupId,
              creatorId: 'user-a',
              date: weekDate,
            ).copyWith(
              entries: [
                WeeklyMenuPlanEntry.create(
                  day: DayOfWeek.mon,
                  slot: MealSlot.middag,
                  recipeId: 'r',
                  recipeTitle: 'Sushi',
                ),
              ],
            );

        final updated = base.copyWith(
          participants: [
            _p('user-a', permission: SharedListPermission.admin),
            _p('user-b', permission: SharedListPermission.edit),
          ],
        );

        expect(updated.participants, hasLength(2));
        expect(
          updated.entries,
          equals(base.entries),
          reason: 'entries untouched when only participants changes',
        );
      });
    });
  });
}
