/// Unit tests for UserCounters + UserCounterIncrements.
///
/// Pure-Dart; targets the 92 unhit lines in lib/models/user_counters.dart.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/user_counters.dart';

UserCounters _counters({
  String userId = 'u1',
  int recipes = 0,
  int menus = 0,
  int shoppingLists = 0,
  int total = 0,
  int messages = 0,
  int friendRequests = 0,
}) {
  return UserCounters(
    userId: userId,
    unreadSharedRecipes: recipes,
    unreadSharedMenus: menus,
    unreadSharedShoppingLists: shoppingLists,
    totalSharedContent: total,
    unreadMessages: messages,
    pendingFriendRequests: friendRequests,
    lastUpdated: DateTime.utc(2026, 1, 1),
  );
}

void main() {
  group('factory + serialization', () {
    test('empty() returns zero counters for given user', () {
      final c = UserCounters.empty('u1');
      expect(c.userId, 'u1');
      expect(c.unreadSharedRecipes, 0);
      expect(c.totalUnreadSharedContent, 0);
    });

    test('fromFirestore parses counters with defaults for missing fields', () {
      final c = UserCounters.fromFirestore('u1', const {
        'unreadSharedRecipes': 3,
        'unreadMessages': 7,
      });
      expect(c.userId, 'u1');
      expect(c.unreadSharedRecipes, 3);
      expect(c.unreadMessages, 7);
      expect(c.unreadSharedMenus, 0);
    });

    test('toFirestore preserves all counters + epoch lastUpdated', () {
      final c = _counters(recipes: 2, messages: 5);
      final data = c.toFirestore();
      expect(data['unreadSharedRecipes'], 2);
      expect(data['unreadMessages'], 5);
      expect(data['lastUpdated'], isA<int>());
    });
  });

  group('totalUnreadSharedContent', () {
    test('sums recipes + menus + shopping lists', () {
      final c = _counters(recipes: 3, menus: 2, shoppingLists: 1);
      expect(c.totalUnreadSharedContent, 6);
    });
  });

  group('getCounterForType', () {
    test('maps every known type', () {
      final c = _counters(
        recipes: 1,
        menus: 2,
        shoppingLists: 3,
        messages: 4,
        friendRequests: 5,
      );
      expect(c.getCounterForType('recipes'), 1);
      expect(c.getCounterForType('shared_recipes'), 1);
      expect(c.getCounterForType('menus'), 2);
      expect(c.getCounterForType('shared_menus'), 2);
      expect(c.getCounterForType('shopping_lists'), 3);
      expect(c.getCounterForType('shared_shopping_lists'), 3);
      expect(c.getCounterForType('messages'), 4);
      expect(c.getCounterForType('friend_requests'), 5);
    });

    test('returns 0 for unknown type', () {
      expect(_counters().getCounterForType('unknown'), 0);
    });
  });

  group('incrementCounter', () {
    test('increments by 1 by default', () {
      final c = _counters().incrementCounter('recipes');
      expect(c.unreadSharedRecipes, 1);
    });

    test('increments by custom amount', () {
      final c = _counters().incrementCounter('messages', by: 5);
      expect(c.unreadMessages, 5);
    });

    test('targets each type alias', () {
      expect(_counters().incrementCounter('shared_recipes').unreadSharedRecipes,
          1);
      expect(_counters().incrementCounter('shared_menus').unreadSharedMenus, 1);
      expect(
          _counters()
              .incrementCounter('shared_shopping_lists')
              .unreadSharedShoppingLists,
          1);
      expect(
          _counters().incrementCounter('friend_requests').pendingFriendRequests,
          1);
    });

    test('unknown type returns self unchanged', () {
      final original = _counters(recipes: 3);
      final result = original.incrementCounter('unknown');
      expect(result.unreadSharedRecipes, 3);
    });
  });

  group('decrementCounter', () {
    test('decrements by 1 default', () {
      final c = _counters(recipes: 5).decrementCounter('recipes');
      expect(c.unreadSharedRecipes, 4);
    });

    test('decrements by custom amount', () {
      final c = _counters(messages: 10).decrementCounter('messages', by: 3);
      expect(c.unreadMessages, 7);
    });

    test('clamps to 0 on under-decrement', () {
      final c = _counters(recipes: 2).decrementCounter('recipes', by: 5);
      expect(c.unreadSharedRecipes, 0);
    });

    test('clamps menus/shoppingLists/messages/friend_requests at 0', () {
      expect(_counters().decrementCounter('shared_menus').unreadSharedMenus, 0);
      expect(
          _counters()
              .decrementCounter('shared_shopping_lists')
              .unreadSharedShoppingLists,
          0);
      expect(_counters().decrementCounter('messages').unreadMessages, 0);
      expect(
          _counters().decrementCounter('friend_requests').pendingFriendRequests,
          0);
    });

    test('unknown type returns self unchanged', () {
      final original = _counters(recipes: 3);
      final result = original.decrementCounter('unknown');
      expect(result.unreadSharedRecipes, 3);
    });
  });

  group('copyWith', () {
    test('preserves unspecified fields', () {
      final original = _counters(recipes: 3, messages: 5);
      final copied = original.copyWith(unreadSharedRecipes: 7);
      expect(copied.unreadSharedRecipes, 7);
      expect(copied.unreadMessages, 5);
    });
  });

  group('equality + toString + hash', () {
    test('equal when userId matches (other fields ignored)', () {
      final a = _counters(userId: 'same', recipes: 0);
      final b = _counters(userId: 'same', recipes: 100);
      expect(a == b, isTrue);
      expect(a.hashCode, b.hashCode);
    });

    test('not equal when userId differs', () {
      expect(_counters(userId: 'a') == _counters(userId: 'b'), isFalse);
    });

    test('toString includes userId + totals', () {
      final s = _counters(userId: 'u1', recipes: 2, messages: 5).toString();
      expect(s, contains('u1'));
      expect(s, contains('2'));
      expect(s, contains('5'));
    });
  });

  group('UserCounterIncrements.fieldForType', () {
    test('maps each known type to its field name', () {
      expect(UserCounterIncrements.fieldForType('recipes'),
          UserCounterIncrements.unreadSharedRecipes);
      expect(UserCounterIncrements.fieldForType('shared_recipes'),
          UserCounterIncrements.unreadSharedRecipes);
      expect(UserCounterIncrements.fieldForType('menus'),
          UserCounterIncrements.unreadSharedMenus);
      expect(UserCounterIncrements.fieldForType('shared_menus'),
          UserCounterIncrements.unreadSharedMenus);
      expect(UserCounterIncrements.fieldForType('shopping_lists'),
          UserCounterIncrements.unreadSharedShoppingLists);
      expect(UserCounterIncrements.fieldForType('shared_shopping_lists'),
          UserCounterIncrements.unreadSharedShoppingLists);
      expect(UserCounterIncrements.fieldForType('messages'),
          UserCounterIncrements.unreadMessages);
      expect(UserCounterIncrements.fieldForType('friend_requests'),
          UserCounterIncrements.pendingFriendRequests);
    });

    test('throws ArgumentError on unknown type', () {
      expect(() => UserCounterIncrements.fieldForType('unknown'),
          throwsA(isA<ArgumentError>()));
    });
  });
}
