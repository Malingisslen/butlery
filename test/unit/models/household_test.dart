import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/household.dart';
import 'helpers/model_test_base.dart';

void main() {
  ModelTestBase.testModelGroup('Household', () {
    group('Construction', () {
      test('create() makes the creator an admin member', () {
        // Intent: the household creator must be able to manage members and
        // delete the household — they are seeded as admin.
        final hh = Household.create(creatorId: 'malin');
        expect(hh.id, isNotEmpty);
        expect(hh.name, Household.defaultName);
        expect(hh.members, hasLength(1));
        expect(hh.isMember('malin'), isTrue);
        expect(hh.canAdmin('malin'), isTrue);
        expect(hh.createdBy, 'malin');
        expect(hh.schemaVersion, 1);
      });

      test('create() accepts a custom name and initial members', () {
        final hh = Household.create(
          creatorId: 'malin',
          name: 'Familjen Gisslen',
          initialMembers: [
            HouseholdMember(
              userId: 'malin',
              permission: SharedListPermission.admin,
              addedAt: DateTime(2026, 6, 1),
            ),
            HouseholdMember(
              userId: 'johan',
              permission: SharedListPermission.edit,
              addedAt: DateTime(2026, 6, 1),
            ),
          ],
        );
        expect(hh.name, 'Familjen Gisslen');
        expect(hh.members, hasLength(2));
      });

      test('create() seeds timestamps from the injectable clock', () {
        // Intent: pins the clock.now() contract so a future switch to
        // non-injected wall-clock time (which breaks deterministic tests)
        // fails loudly.
        final fixed = DateTime(2026, 6, 28, 12);
        final hh = withClock(
          Clock.fixed(fixed),
          () => Household.create(creatorId: 'malin'),
        );
        expect(hh.createdAt, fixed);
        expect(hh.updatedAt, fixed);
        expect(hh.members.single.addedAt, fixed);
      });
    });

    group('Membership semantics', () {
      final hh = Household(
        id: 'hh_1',
        name: 'Vårt hushåll',
        members: [
          HouseholdMember(
            userId: 'malin',
            permission: SharedListPermission.admin,
            addedAt: DateTime(2026, 1, 1),
          ),
          HouseholdMember(
            userId: 'johan',
            permission: SharedListPermission.edit,
            addedAt: DateTime(2026, 1, 1),
          ),
          HouseholdMember(
            userId: 'farmor',
            permission: SharedListPermission.view,
            addedAt: DateTime(2026, 1, 1),
          ),
        ],
        createdBy: 'malin',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      test(
        'both parents can edit; a viewer cannot; an outsider has no access',
        () {
          // Intent: this is the symmetric-sharing contract — both Malin AND
          // Johan can write the household's diner profiles, unlike the old
          // owner-only FriendCategory model.
          expect(hh.canEdit('malin'), isTrue);
          expect(hh.canEdit('johan'), isTrue);
          expect(hh.canEdit('farmor'), isFalse);
          expect(hh.isMember('farmor'), isTrue);
          expect(hh.isMember('stranger'), isFalse);
          expect(hh.canEdit('stranger'), isFalse);
        },
      );

      test('only admins can manage/delete', () {
        expect(hh.canAdmin('malin'), isTrue);
        expect(hh.canAdmin('johan'), isFalse);
      });

      test(
        'memberUserIds and memberPermissions mirror the structured list',
        () {
          // Intent: these denormalised projections are what Firestore rules and
          // membership queries read, so they must stay faithful to `members`.
          // unorderedEquals (not containsAll) so a duplicate id fails —
          // Firestore arrayContains misbehaves with duplicates.
          expect(
            hh.memberUserIds,
            unorderedEquals(<String>['malin', 'johan', 'farmor']),
          );
          expect(hh.memberUserIds.length, hh.members.length);
          expect(hh.memberPermissions['malin'], 'admin');
          expect(hh.memberPermissions['johan'], 'edit');
          expect(hh.memberPermissions['farmor'], 'view');
        },
      );

      test(
        'unknown/corrupt permission string falls back to view (least priv)',
        () {
          // Intent: a corrupt or future-schema permission must NOT grant write.
          final member = HouseholdMember.fromMap({
            'userId': 'x',
            'permission': 'superadmin',
            'addedAt': DateTime(2026, 1, 1).toIso8601String(),
          });
          expect(member.permission, SharedListPermission.view);
          expect(member.canEdit, isFalse);
        },
      );
    });

    group('Mutation', () {
      test('addMember appends an editor and updates the rule projections', () {
        final base = Household.create(creatorId: 'malin');
        final withJohan = base.addMember('johan');
        expect(withJohan.isMember('johan'), isTrue);
        expect(withJohan.canEdit('johan'), isTrue);
        // Projections (what Firestore rules read) must reflect the mutation.
        expect(withJohan.memberUserIds, contains('johan'));
        expect(withJohan.memberPermissions['johan'], 'edit');
      });

      test('addMember is idempotent in both the list and the projections', () {
        final withJohan = Household.create(
          creatorId: 'malin',
        ).addMember('johan');
        final again = withJohan.addMember('johan');
        expect(again.members.where((m) => m.userId == 'johan'), hasLength(1));
        expect(
          again.memberPermissions.keys.where((k) => k == 'johan'),
          hasLength(1),
        );
        expect(again.memberUserIds.length, again.members.length);
      });

      test('removeMember drops the member', () {
        final base = Household.create(creatorId: 'malin').addMember('johan');
        final removed = base.removeMember('johan');
        expect(removed.isMember('johan'), isFalse);
        expect(removed.isMember('malin'), isTrue);
        expect(removed.memberUserIds, isNot(contains('johan')));
      });

      test('removeMember is a no-op for a non-member', () {
        final base = Household.create(creatorId: 'malin');
        expect(base.removeMember('stranger'), same(base));
      });
    });

    group('Round-trips', () {
      final hh = Household.create(
        creatorId: 'malin',
        name: 'Familjen',
      ).addMember('johan');

      test('Firestore round-trip preserves members and projections', () {
        final restored = Household.fromMap(hh.id, hh.toFirestore());
        expect(restored.id, hh.id);
        expect(restored.name, 'Familjen');
        expect(restored.members, hasLength(2));
        expect(restored.canAdmin('malin'), isTrue);
        expect(restored.canEdit('johan'), isTrue);
      });

      test('Firestore map carries the denormalised rule projections', () {
        final map = hh.toFirestore();
        expect(map['memberUserIds'], containsAll(<String>['malin', 'johan']));
        expect((map['memberPermissions'] as Map)['malin'], 'admin');
      });

      test('JSON round-trip preserves membership', () {
        final restored = Household.fromJson(hh.toJson());
        expect(restored.members, hasLength(2));
        expect(restored.canEdit('johan'), isTrue);
      });
    });

    group('Equality', () {
      test('equal iff same id', () {
        final a = Household.create(creatorId: 'malin');
        final renamed = a.copyWith(name: 'Nytt namn');
        final b = Household.create(creatorId: 'malin');
        expect(a, equals(renamed));
        expect(a, isNot(equals(b)));
      });
    });
  });
}
