/// Unit tests for InvitationTarget.
///
/// Pure-Dart model — no Flutter widgets, no Firebase. Targets the 166 unhit
/// lines in lib/models/invitations/invitation_target.dart.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/invitations/invitation_target.dart';
import 'package:butlery/models/user_profile.dart';

UserProfile _user({
  String uid = 'u1',
  String displayName = 'Anna',
  String email = 'anna@example.com',
  bool isSearchable = true,
  int friendsCount = 0,
}) {
  return UserProfile(
    uid: uid,
    displayName: displayName,
    email: email,
    isSearchable: isSearchable,
    friendsCount: friendsCount,
    joinedAt: DateTime.utc(2026, 1, 1),
    lastActiveAt: DateTime.utc(2026, 1, 1),
  );
}

FriendCategory _category({
  String id = 'g1',
  String ownerId = 'u1',
  String name = 'Familj',
  String? description,
  String? emoji,
  List<String> friendUserIds = const [],
}) {
  return FriendCategory(
    id: id,
    ownerId: ownerId,
    name: name,
    description: description,
    emoji: emoji,
    friendUserIds: friendUserIds,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );
}

void main() {
  group('factory constructors', () {
    test('individual extracts uid/displayName + metadata', () {
      final user = _user(
        uid: 'u-anna',
        displayName: 'Anna',
        isSearchable: false,
        friendsCount: 7,
      );

      final t = InvitationTarget.individual(user);
      expect(t.type, InvitationTargetType.individual);
      expect(t.targetId, 'u-anna');
      expect(t.displayName, 'Anna');
      expect(t.metadata?['isSearchable'], false);
      expect(t.metadata?['friendsCount'], 7);
      expect(t.metadata?['memberSince'], isNotNull);
      expect(t.memberCount, isNull);
      expect(t.memberIds, isNull);
    });

    test('group expands members + extracts metadata', () {
      final group = _category(
        id: 'g-fam',
        ownerId: 'u1',
        description: 'Familj',
        emoji: '🏠',
      );
      final members = [
        _user(uid: 'u1', displayName: 'Anna'),
        _user(uid: 'u2', displayName: 'Bob'),
      ];

      final t = InvitationTarget.group(group, members);
      expect(t.type, InvitationTargetType.group);
      expect(t.targetId, 'g-fam');
      expect(t.imageOrEmoji, '🏠');
      expect(t.memberCount, 2);
      expect(t.memberIds, ['u1', 'u2']);
      expect(t.metadata?['description'], 'Familj');
      expect(t.metadata?['ownerId'], 'u1');
    });

    test('group with no emoji falls back to default emoji', () {
      final t = InvitationTarget.group(_category(), const []);
      expect(t.imageOrEmoji, '👥');
    });
  });

  group('type predicates + display getters', () {
    test('isIndividual / isGroup discriminate correctly', () {
      final i = InvitationTarget.individual(_user());
      final g = InvitationTarget.group(_category(), const []);

      expect(i.isIndividual, isTrue);
      expect(i.isGroup, isFalse);
      expect(g.isIndividual, isFalse);
      expect(g.isGroup, isTrue);
    });

    test('displayEmoji default for individual', () {
      expect(InvitationTarget.individual(_user()).displayEmoji, '👤');
    });

    test('displayEmoji custom for group', () {
      final t = InvitationTarget.group(_category(emoji: '🎉'), const []);
      expect(t.displayEmoji, '🎉');
    });

    test('description: singular vs plural for group; empty for individual', () {
      final solo = InvitationTarget.group(_category(), [_user()]);
      expect(solo.description, '1 medlem');

      final many = InvitationTarget.group(_category(), [
        _user(),
        _user(uid: 'u2'),
      ]);
      expect(many.description, '2 medlemmar');

      expect(InvitationTarget.individual(_user()).description, '');
    });

    test(
      'subtitle: group uses description, individual uses ButleryUser label',
      () {
        final i = InvitationTarget.individual(_user());
        final g = InvitationTarget.group(_category(), [_user()]);

        expect(g.subtitle, '1 medlem');
        expect(i.subtitle, isNotEmpty);
      },
    );
  });

  group('validation', () {
    test('isValid true for properly formed individual', () {
      expect(InvitationTarget.individual(_user()).isValid, isTrue);
    });

    test('isValid false when targetId empty', () {
      const t = InvitationTarget(
        type: InvitationTargetType.individual,
        targetId: '',
        displayName: 'X',
      );
      expect(t.isValid, isFalse);
    });

    test('isValid false when displayName empty', () {
      const t = InvitationTarget(
        type: InvitationTargetType.individual,
        targetId: 'u1',
        displayName: '',
      );
      expect(t.isValid, isFalse);
    });

    test('isValid false for group without members', () {
      final t = InvitationTarget.group(_category(), const []);
      expect(t.isValid, isFalse);
    });

    test('isValid true for group with members', () {
      final t = InvitationTarget.group(_category(), [_user()]);
      expect(t.isValid, isTrue);
    });
  });

  group('user-id helpers', () {
    test('allUserIds returns single-item list for individual', () {
      expect(InvitationTarget.individual(_user(uid: 'u-anna')).allUserIds, [
        'u-anna',
      ]);
    });

    test('allUserIds returns memberIds for group', () {
      final t = InvitationTarget.group(_category(), [
        _user(uid: 'u1'),
        _user(uid: 'u2'),
      ]);
      expect(t.allUserIds, ['u1', 'u2']);
    });

    test('allUserIds returns empty for group with null memberIds', () {
      const t = InvitationTarget(
        type: InvitationTargetType.group,
        targetId: 'g1',
        displayName: 'Empty',
        memberIds: null,
      );
      expect(t.allUserIds, isEmpty);
    });
  });

  group('metadata getters', () {
    test('createdAt parses ISO string from metadata', () {
      final t = InvitationTarget.group(_category(), [_user()]);
      expect(t.createdAt, isNotNull);
      expect(t.createdAt!.year, 2026);
    });

    test('createdAt returns null when missing', () {
      expect(InvitationTarget.individual(_user()).createdAt, isNull);
    });

    test('createdAt returns null when invalid string', () {
      const t = InvitationTarget(
        type: InvitationTargetType.group,
        targetId: 'g1',
        displayName: 'X',
        metadata: {'createdAt': 'not-a-date'},
      );
      expect(t.createdAt, isNull);
    });

    test('ownerId extracts metadata field', () {
      final t = InvitationTarget.group(_category(ownerId: 'owner-99'), [
        _user(),
      ]);
      expect(t.ownerId, 'owner-99');
    });

    test('friendsCount defaults to 0 when missing', () {
      const t = InvitationTarget(
        type: InvitationTargetType.individual,
        targetId: 'u1',
        displayName: 'X',
      );
      expect(t.friendsCount, 0);
    });

    test('friendsCount reads metadata field', () {
      final t = InvitationTarget.individual(_user(friendsCount: 12));
      expect(t.friendsCount, 12);
    });

    test('isSearchable defaults to true when missing', () {
      const t = InvitationTarget(
        type: InvitationTargetType.individual,
        targetId: 'u1',
        displayName: 'X',
      );
      expect(t.isSearchable, isTrue);
    });

    test('isSearchable reads metadata field', () {
      final t = InvitationTarget.individual(_user(isSearchable: false));
      expect(t.isSearchable, isFalse);
    });
  });

  group('serialization', () {
    test('toFirestore + fromFirestore round-trip individual', () {
      final original = InvitationTarget.individual(_user(uid: 'u-anna'));
      final data = original.toFirestore();
      final restored = InvitationTarget.fromFirestore(data);

      expect(restored.type, original.type);
      expect(restored.targetId, original.targetId);
      expect(restored.displayName, original.displayName);
    });

    test('toFirestore + fromFirestore round-trip group', () {
      final original = InvitationTarget.group(_category(id: 'g1'), [
        _user(uid: 'u1'),
        _user(uid: 'u2'),
      ]);
      final data = original.toFirestore();
      final restored = InvitationTarget.fromFirestore(data);

      expect(restored.type, InvitationTargetType.group);
      expect(restored.memberCount, 2);
      expect(restored.memberIds, ['u1', 'u2']);
    });

    test('toJson + fromJson round-trip', () {
      final original = InvitationTarget.individual(_user(uid: 'u-anna'));
      final json = original.toJson();
      final restored = InvitationTarget.fromJson(json);

      expect(restored.type, original.type);
      expect(restored.targetId, original.targetId);
    });

    test('fromFirestore falls back to individual on unknown type', () {
      final t = InvitationTarget.fromFirestore({
        'type': 'unknown',
        'targetId': 'u1',
        'displayName': 'X',
      });
      expect(t.type, InvitationTargetType.individual);
    });
  });

  group('copyWith / withMetadata / withoutMetadata', () {
    test('copyWith preserves unspecified fields', () {
      final original = InvitationTarget.individual(_user(uid: 'u1'));
      final copied = original.copyWith(displayName: 'New Name');

      expect(copied.targetId, 'u1');
      expect(copied.displayName, 'New Name');
      expect(copied.type, original.type);
    });

    test('withMetadata merges new keys without losing existing', () {
      final original = InvitationTarget.individual(_user(friendsCount: 5));
      final updated = original.withMetadata({'extraKey': 'extraValue'});

      expect(updated.metadata?['friendsCount'], 5);
      expect(updated.metadata?['extraKey'], 'extraValue');
    });

    test('withoutMetadata removes specified key', () {
      final original = InvitationTarget.individual(_user(friendsCount: 5));
      final updated = original.withoutMetadata('friendsCount');

      expect(updated.metadata?.containsKey('friendsCount'), isFalse);
      expect(updated.metadata?.containsKey('isSearchable'), isTrue);
    });

    test('withoutMetadata is a no-op when key missing', () {
      final original = InvitationTarget.individual(_user());
      final updated = original.withoutMetadata('does-not-exist');

      expect(updated.metadata, original.metadata);
    });

    test('withoutMetadata is a no-op when metadata is null', () {
      const t = InvitationTarget(
        type: InvitationTargetType.individual,
        targetId: 'u1',
        displayName: 'X',
      );
      final updated = t.withoutMetadata('anything');
      expect(updated.metadata, isNull);
    });
  });

  group('equality + hashCode + toString', () {
    test('equal when type + targetId match (other fields ignored)', () {
      final a = InvitationTarget.individual(_user(uid: 'u1'));
      final b = InvitationTarget(
        type: InvitationTargetType.individual,
        targetId: 'u1',
        displayName: 'Different Name',
      );
      expect(a == b, isTrue);
      expect(a.hashCode, b.hashCode);
    });

    test('not equal when type differs', () {
      final a = InvitationTarget(
        type: InvitationTargetType.individual,
        targetId: 'x',
        displayName: 'X',
      );
      final b = InvitationTarget(
        type: InvitationTargetType.group,
        targetId: 'x',
        displayName: 'X',
      );
      expect(a == b, isFalse);
    });

    test('toString includes essential fields', () {
      final t = InvitationTarget.individual(_user(uid: 'u-99'));
      expect(t.toString(), contains('u-99'));
      expect(t.toString(), contains('Anna'));
    });
  });

  group('compareTo sort order', () {
    test('groups come before individuals', () {
      final i = InvitationTarget.individual(_user());
      final g = InvitationTarget.group(_category(), [_user()]);
      expect(g.compareTo(i), lessThan(0));
      expect(i.compareTo(g), greaterThan(0));
    });

    test('same type sorts alphabetically by displayName', () {
      final a = InvitationTarget.individual(_user(displayName: 'Anna'));
      final b = InvitationTarget.individual(_user(displayName: 'Bob'));
      expect(a.compareTo(b), lessThan(0));
      expect(b.compareTo(a), greaterThan(0));
    });
  });

  group('static utilities', () {
    test('fromUsers / fromGroups produce parallel lists', () {
      final users = [_user(uid: 'u1'), _user(uid: 'u2')];
      final groups = [_category(id: 'g1', name: 'Familj')];
      final members = {
        'g1': [_user(uid: 'u3')],
      };

      final us = InvitationTarget.fromUsers(users);
      final gs = InvitationTarget.fromGroups(groups, members);

      expect(us.length, 2);
      expect(us.every((t) => t.isIndividual), isTrue);
      expect(gs.length, 1);
      expect(gs.first.memberIds, ['u3']);
    });

    test('extractAllUserIds deduplicates across mixed targets', () {
      final shared = _user(uid: 'shared');
      final individual = InvitationTarget.individual(shared);
      final group = InvitationTarget.group(_category(), [
        shared,
        _user(uid: 'unique'),
      ]);

      final ids = InvitationTarget.extractAllUserIds([individual, group]);
      expect(ids, {'shared', 'unique'});
    });

    test('groupByType splits into individual + group buckets', () {
      final targets = [
        InvitationTarget.individual(_user(uid: 'u1')),
        InvitationTarget.individual(_user(uid: 'u2')),
        InvitationTarget.group(_category(id: 'g1'), [_user(uid: 'u3')]),
      ];

      final grouped = InvitationTarget.groupByType(targets);
      expect(grouped[InvitationTargetType.individual]?.length, 2);
      expect(grouped[InvitationTargetType.group]?.length, 1);
    });

    test('sortForUI returns new list with groups first', () {
      final i = InvitationTarget.individual(_user(displayName: 'Anna'));
      final g = InvitationTarget.group(_category(name: 'Zebra'), [_user()]);

      final sorted = InvitationTarget.sortForUI([i, g]);
      expect(sorted.first.isGroup, isTrue);
    });

    test(
      'filterBySearch matches displayName + description + group metadata',
      () {
        final i = InvitationTarget.individual(_user(displayName: 'Anna'));
        final g = InvitationTarget.group(
          _category(name: 'Familj', description: 'Närmaste'),
          [_user()],
        );

        expect(InvitationTarget.filterBySearch([i, g], '').length, 2);
        expect(InvitationTarget.filterBySearch([i, g], 'anna').length, 1);
        expect(InvitationTarget.filterBySearch([i, g], 'fam').length, 1);
        // Search inside group description metadata.
        expect(InvitationTarget.filterBySearch([i, g], 'närmaste').length, 1);
        expect(InvitationTarget.filterBySearch([i, g], 'nope'), isEmpty);
      },
    );

    test('filterByType / individualsOnly / groupsOnly partition correctly', () {
      final i = InvitationTarget.individual(_user());
      final g = InvitationTarget.group(_category(), [_user()]);

      expect(
        InvitationTarget.filterByType([i, g], InvitationTargetType.group),
        [g],
      );
      expect(InvitationTarget.individualsOnly([i, g]), [i]);
      expect(InvitationTarget.groupsOnly([i, g]), [g]);
    });

    test('getTotalUserCount returns unique-id count', () {
      final shared = _user(uid: 'shared');
      final i = InvitationTarget.individual(shared);
      final g = InvitationTarget.group(_category(), [shared, _user(uid: 'u2')]);

      expect(InvitationTarget.getTotalUserCount([i, g]), 2);
    });

    test('containsUser reflects extractAllUserIds', () {
      final i = InvitationTarget.individual(_user(uid: 'anna'));
      expect(InvitationTarget.containsUser([i], 'anna'), isTrue);
      expect(InvitationTarget.containsUser([i], 'other'), isFalse);
    });
  });
}
