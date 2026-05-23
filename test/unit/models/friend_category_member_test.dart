/// Unit tests for FriendCategoryMember + CategoryMembership.
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/friend_category_member.dart';

void main() {
  group('FriendCategoryMember.create', () {
    test('stamps addedAt from clock.now()', () {
      withClock(Clock.fixed(DateTime.utc(2026, 5, 23, 12)), () {
        final m = FriendCategoryMember.create(
          friendId: 'alice',
          categoryId: 'inner_circle',
          ownerId: 'bob',
        );
        expect(m.addedAt, DateTime.utc(2026, 5, 23, 12));
      });
    });

    test('display + avatar are optional', () {
      final m = FriendCategoryMember.create(
        friendId: 'a',
        categoryId: 'c',
        ownerId: 'o',
      );
      expect(m.displayName, isNull);
      expect(m.avatarUrl, isNull);
    });

    test('preserves provided display + avatar', () {
      final m = FriendCategoryMember.create(
        friendId: 'a',
        categoryId: 'c',
        ownerId: 'o',
        displayName: 'Alice',
        avatarUrl: 'https://x',
      );
      expect(m.displayName, 'Alice');
      expect(m.avatarUrl, 'https://x');
    });
  });

  group('FriendCategoryMember serialization', () {
    test('toFirestore round-trip via fromFirestore', () {
      final original = FriendCategoryMember(
        friendId: 'alice',
        categoryId: 'inner',
        ownerId: 'bob',
        addedAt: DateTime.utc(2026, 1, 1),
        displayName: 'Alice',
        avatarUrl: 'https://x',
      );
      final data = original.toFirestore();
      final restored = FriendCategoryMember.fromFirestore('alice', data);

      expect(restored.friendId, 'alice');
      expect(restored.categoryId, original.categoryId);
      expect(restored.ownerId, original.ownerId);
      expect(restored.addedAt, original.addedAt);
      expect(restored.displayName, original.displayName);
      expect(restored.avatarUrl, original.avatarUrl);
    });

    test('toJson + fromJson round-trips via ISO 8601 string', () {
      final original = FriendCategoryMember(
        friendId: 'alice',
        categoryId: 'inner',
        ownerId: 'bob',
        addedAt: DateTime.utc(2026, 1, 1),
      );
      final json = original.toJson();
      expect(json['addedAt'], '2026-01-01T00:00:00.000Z');

      final restored = FriendCategoryMember.fromJson(json);
      expect(restored.friendId, 'alice');
      expect(restored.addedAt, DateTime.utc(2026, 1, 1));
    });

    test('fromFirestore safe defaults for missing fields', () {
      final m = FriendCategoryMember.fromFirestore('alice', {});
      expect(m.friendId, 'alice');
      expect(m.categoryId, '');
      expect(m.ownerId, '');
      expect(m.displayName, isNull);
      expect(m.avatarUrl, isNull);
    });
  });

  group('FriendCategoryMember equality', () {
    test('same (friendId, categoryId) → equal regardless of ownerId/dates', () {
      final a = FriendCategoryMember(
        friendId: 'alice',
        categoryId: 'inner',
        ownerId: 'bob',
        addedAt: DateTime.utc(2026, 1, 1),
      );
      final b = FriendCategoryMember(
        friendId: 'alice',
        categoryId: 'inner',
        ownerId: 'carol', // different owner
        addedAt: DateTime.utc(2026, 5, 1), // different date
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('different friendId or categoryId → unequal', () {
      final base = FriendCategoryMember(
        friendId: 'alice',
        categoryId: 'inner',
        ownerId: 'bob',
        addedAt: DateTime.utc(2026, 1, 1),
      );
      final diffFriend = FriendCategoryMember(
        friendId: 'carol',
        categoryId: 'inner',
        ownerId: 'bob',
        addedAt: DateTime.utc(2026, 1, 1),
      );
      final diffCat = FriendCategoryMember(
        friendId: 'alice',
        categoryId: 'outer',
        ownerId: 'bob',
        addedAt: DateTime.utc(2026, 1, 1),
      );
      expect(base, isNot(diffFriend));
      expect(base, isNot(diffCat));
    });

    test('identical short-circuit', () {
      final m = FriendCategoryMember(
        friendId: 'a',
        categoryId: 'c',
        ownerId: 'o',
        addedAt: DateTime.utc(2026, 1, 1),
      );
      expect(m == m, isTrue);
    });
  });

  test('FriendCategoryMember toString includes friendId + categoryId', () {
    final m = FriendCategoryMember(
      friendId: 'alice',
      categoryId: 'inner',
      ownerId: 'bob',
      addedAt: DateTime.utc(2026, 1, 1),
    );
    final s = m.toString();
    expect(s, contains('alice'));
    expect(s, contains('inner'));
  });

  group('CategoryMembership', () {
    test('toFirestore + fromFirestore round-trip', () {
      final original = CategoryMembership(
        categoryId: 'inner',
        ownerId: 'bob',
        categoryName: 'Inner circle',
        categoryEmoji: '⭐',
        addedAt: DateTime.utc(2026, 1, 1),
      );
      final data = original.toFirestore();
      final restored = CategoryMembership.fromFirestore('inner', data);

      expect(restored.categoryId, 'inner');
      expect(restored.ownerId, original.ownerId);
      expect(restored.categoryName, original.categoryName);
      expect(restored.categoryEmoji, original.categoryEmoji);
      expect(restored.addedAt, original.addedAt);
    });

    test('safe defaults + null emoji', () {
      final m = CategoryMembership.fromFirestore('id', {});
      expect(m.categoryId, 'id');
      expect(m.ownerId, '');
      expect(m.categoryName, '');
      expect(m.categoryEmoji, isNull);
    });

    test('equality is categoryId-only', () {
      final a = CategoryMembership(
        categoryId: 'inner',
        ownerId: 'bob',
        categoryName: 'X',
        addedAt: DateTime.utc(2026, 1, 1),
      );
      final b = CategoryMembership(
        categoryId: 'inner',
        ownerId: 'carol',
        categoryName: 'Y',
        addedAt: DateTime.utc(2026, 5, 1),
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('identical short-circuit', () {
      final m = CategoryMembership(
        categoryId: 'inner',
        ownerId: 'bob',
        categoryName: 'X',
        addedAt: DateTime.utc(2026, 1, 1),
      );
      expect(m == m, isTrue);
    });

    test('toString includes categoryId + owner', () {
      final m = CategoryMembership(
        categoryId: 'inner',
        ownerId: 'bob',
        categoryName: 'X',
        addedAt: DateTime.utc(2026, 1, 1),
      );
      final s = m.toString();
      expect(s, contains('inner'));
      expect(s, contains('bob'));
    });
  });
}
