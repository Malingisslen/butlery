import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/pantry/pantry_service.dart';
import 'package:butlery/services/shopping/shopping_checkoff_pantry_service.dart';
import 'package:butlery/services/user_service.dart';

class MockPantryService extends Mock implements PantryService {}

class MockUserService extends Mock implements UserService {}

UserProfile _profile({required bool autoAdd}) => UserProfile(
  uid: 'u1',
  displayName: 'Test',
  email: 't@example.com',
  joinedAt: DateTime(2024, 1, 1),
  lastActiveAt: DateTime(2024, 1, 1),
  autoAddBoughtToPantry: autoAdd,
);

PantryItem _pantryItem({
  required String name,
  required double qty,
  String unit = 'st',
}) => PantryItem(
  id: 'p_$name',
  ingredientName: name,
  quantity: qty,
  unit: unit,
  location: PantryLocation.pantry,
  addedAt: DateTime(2024, 1, 1),
);

UnifiedShoppingItem _shoppingItem({
  required String name,
  double amount = 1,
  String unit = 'st',
  bool bought = true,
}) =>
    UnifiedShoppingItem(name: name, amount: amount, unit: unit, bought: bought);

void main() {
  late MockPantryService pantry;
  late MockUserService users;
  late ShoppingCheckoffPantryService service;

  setUpAll(() {
    registerFallbackValue(_pantryItem(name: 'fallback', qty: 1));
    registerFallbackValue(_shoppingItem(name: 'fallback'));
  });

  setUp(() {
    pantry = MockPantryService();
    users = MockUserService();
    service = ShoppingCheckoffPantryService(
      pantryService: pantry,
      userService: users,
    );
    when(() => pantry.updateItem(any(), any())).thenAnswer((_) async {});
    when(
      () => pantry.addFromShoppingItem(any(), any()),
    ).thenAnswer((_) async => _pantryItem(name: 'added', qty: 1));
  });

  group('ShoppingCheckoffPantryService.onItemCheckedOff (BUT-1050)', () {
    test('aggregates quantity into a matching pantry item instead of adding a '
        'duplicate (dedup)', () async {
      // Intent: checking off an item already in the pantry (same name + unit)
      // must NOT create a second entry — it grows the existing one's quantity.
      when(() => users.currentUserProfile).thenReturn(_profile(autoAdd: true));
      when(() => pantry.getAll('u1')).thenAnswer(
        (_) async => [_pantryItem(name: 'Mjölk', qty: 2, unit: 'l')],
      );

      await service.onItemCheckedOff(
        'u1',
        // Different case + a bought amount of 3 — must match 'Mjölk'/'l'.
        _shoppingItem(name: 'mjölk', amount: 3, unit: 'l'),
        wasBought: false,
      );

      final captured =
          verify(() => pantry.updateItem('u1', captureAny())).captured.single
              as PantryItem;
      expect(captured.quantity, 5); // 2 existing + 3 bought
      verifyNever(() => pantry.addFromShoppingItem(any(), any()));
    });

    test('adds a new pantry item when no matching entry exists', () async {
      when(() => users.currentUserProfile).thenReturn(_profile(autoAdd: true));
      when(() => pantry.getAll('u1')).thenAnswer((_) async => []);

      final item = _shoppingItem(name: 'Bröd', amount: 1);
      await service.onItemCheckedOff('u1', item, wasBought: false);

      verify(() => pantry.addFromShoppingItem('u1', item)).called(1);
      verifyNever(() => pantry.updateItem(any(), any()));
    });

    test('does nothing when the auto-add preference is OFF', () async {
      when(() => users.currentUserProfile).thenReturn(_profile(autoAdd: false));

      await service.onItemCheckedOff(
        'u1',
        _shoppingItem(name: 'Bröd'),
        wasBought: false,
      );

      // Gated off before any pantry I/O — proves the toggle actually gates.
      verifyNever(() => pantry.getAll(any()));
      verifyNever(() => pantry.addFromShoppingItem(any(), any()));
      verifyNever(() => pantry.updateItem(any(), any()));
    });

    test(
      'does nothing when re-toggling an already-bought item (wasBought=true)',
      () async {
        when(
          () => users.currentUserProfile,
        ).thenReturn(_profile(autoAdd: true));

        await service.onItemCheckedOff(
          'u1',
          _shoppingItem(name: 'Bröd', bought: true),
          wasBought: true,
        );

        // Only a genuine false→true checkoff may fire — a re-toggle is a no-op.
        verifyNever(() => pantry.getAll(any()));
        verifyNever(() => pantry.addFromShoppingItem(any(), any()));
      },
    );

    test('adds a new item when name matches but unit differs — unit mismatch '
        'must NOT aggregate', () async {
      // Intent: the dedup predicate requires BOTH name (case-insensitive) AND
      // unit to match. A unit mismatch (e.g. pantry has "Mjölk l", we bought
      // "Mjölk dl") must route to addFromShoppingItem, not updateItem.
      // Dropping the unit check from the predicate would make this fail.
      when(() => users.currentUserProfile).thenReturn(_profile(autoAdd: true));
      when(() => pantry.getAll('u1')).thenAnswer(
        (_) async => [_pantryItem(name: 'Mjölk', qty: 2, unit: 'l')],
      );

      final item = _shoppingItem(name: 'Mjölk', amount: 1, unit: 'dl');
      await service.onItemCheckedOff('u1', item, wasBought: false);

      verify(() => pantry.addFromShoppingItem('u1', item)).called(1);
      verifyNever(() => pantry.updateItem(any(), any()));
    });

    test('does nothing when user profile is null (not yet loaded)', () async {
      // Intent: the null-profile guard must fire before any pantry I/O, just
      // like the preference-OFF guard. Ensures the service doesn't crash or
      // write when called before the profile stream has arrived.
      when(() => users.currentUserProfile).thenReturn(null);

      await service.onItemCheckedOff(
        'u1',
        _shoppingItem(name: 'Bröd'),
        wasBought: false,
      );

      verifyNever(() => pantry.getAll(any()));
      verifyNever(() => pantry.addFromShoppingItem(any(), any()));
      verifyNever(() => pantry.updateItem(any(), any()));
    });
  });
}
