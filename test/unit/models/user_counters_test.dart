/// Unit tests for UserCounterIncrements.
///
/// Pure-Dart.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/user_counters.dart';

void main() {
  group('UserCounterIncrements.fieldForType', () {
    test('maps each known type to its field name', () {
      expect(
        UserCounterIncrements.fieldForType('recipes'),
        UserCounterIncrements.unreadSharedRecipes,
      );
      expect(
        UserCounterIncrements.fieldForType('shared_recipes'),
        UserCounterIncrements.unreadSharedRecipes,
      );
      expect(
        UserCounterIncrements.fieldForType('menus'),
        UserCounterIncrements.unreadSharedMenus,
      );
      expect(
        UserCounterIncrements.fieldForType('shared_menus'),
        UserCounterIncrements.unreadSharedMenus,
      );
      expect(
        UserCounterIncrements.fieldForType('shopping_lists'),
        UserCounterIncrements.unreadSharedShoppingLists,
      );
      expect(
        UserCounterIncrements.fieldForType('shared_shopping_lists'),
        UserCounterIncrements.unreadSharedShoppingLists,
      );
    });

    // BUT-1824: the counters allowlist in firestore.rules has no field for
    // these, so a type mapping to one would lock the document for good.
    test('has no field for messages or friend requests', () {
      for (final type in const ['messages', 'friend_requests']) {
        expect(
          () => UserCounterIncrements.fieldForType(type),
          throwsA(isA<ArgumentError>()),
        );
      }
    });

    test('throws ArgumentError on unknown type', () {
      expect(
        () => UserCounterIncrements.fieldForType('unknown'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
