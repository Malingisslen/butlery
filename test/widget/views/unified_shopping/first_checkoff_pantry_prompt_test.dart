// BUT-2257: the tick that opens "Lägg till i skafferiet automatiskt?" must
// itself reach the pantry on "Ja". These tests drive the real
// UnifiedShoppingView over the real view model, so the dialog's answer is
// followed all the way to the pantry seam.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/repositories/interfaces/category_preferences_repository.dart';
import 'package:butlery/services/shopping/shopping_checkoff_pantry_service.dart';
import 'package:butlery/services/unified/modules/shopping_category_preferences_module.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';
import 'package:butlery/views/unified_shopping_view.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/shopping_list_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../views/design_states/state_harness.dart';

class _MockCategoryPreferences extends Mock
    implements CategoryPreferencesRepository {}

class _MockUserService extends Mock implements UserService {}

class _MockCheckoffPantryService extends Mock
    implements ShoppingCheckoffPantryService {}

final _sv = AppLocalizationsSv();

const _listId = 'list-vecka';
const _ownerId = 'test-user-123';

UserProfile _profile() => UserProfile(
  uid: _ownerId,
  displayName: 'Test User',
  email: 't@example.com',
  joinedAt: DateTime(2024, 1, 1),
  lastActiveAt: DateTime(2024, 1, 1),
  autoAddBoughtToPantry: false,
  pantryAutoAddPrompted: false,
);

void _seed(MockUnifiedShoppingService service, {required bool bought}) {
  service.setShoppingState(
    lists: [
      ShoppingListFactory.build(
        id: _listId,
        name: 'Veckans inköp',
        ownerId: _ownerId,
        items: [
          ShoppingListFactory.buildItem(
            id: 'i1',
            name: 'Gul lök',
            category: 'Frukt & grönt',
            bought: bought,
          ),
        ],
      ),
    ],
    activeListId: _listId,
  );
}

void main() {
  late StateEnvironment environment;
  late MockUnifiedShoppingService service;
  late _MockUserService userService;
  late _MockCheckoffPantryService checkoff;

  setUpAll(() {
    registerFallbackValue(ShoppingListFactory.buildItem());
  });

  setUp(() async {
    environment = await StateEnvironment.setUp(online: true);

    service = MockUnifiedShoppingService();
    _seed(service, bought: false);
    when(service.loadLists).thenAnswer((_) async {});
    when(service.initialize).thenAnswer((_) async {});
    // The tick lands in the service's state, as the real one does, so the
    // view model sees the row as bought once the dialog answers.
    when(() => service.toggleItemBought(any())).thenAnswer((_) async {
      _seed(service, bought: true);
      return true;
    });
    final repository = _MockCategoryPreferences();
    when(repository.getPreferences).thenAnswer((_) async => null);
    when(
      () => service.categoryPreferences,
    ).thenReturn(ShoppingCategoryPreferencesModule(repository: repository));

    userService = _MockUserService();
    when(() => userService.currentUserProfile).thenReturn(_profile());
    when(() => userService.setAutoAddToPantry(any())).thenAnswer((_) async {});
    when(userService.markPantryAutoAddPrompted).thenAnswer((_) async {});

    checkoff = _MockCheckoffPantryService();
    when(
      () => checkoff.onItemCheckedOff(
        any(),
        any(),
        wasBought: any(named: 'wasBought'),
      ),
    ).thenAnswer((_) async {});

    TestServiceLocator.registerMock<UnifiedShoppingService>(service);
    TestServiceLocator.registerMock<UserService>(userService);
    TestServiceLocator.registerMock<ShoppingCheckoffPantryService>(checkoff);
    TestServiceLocator.registerMock<UnifiedShoppingViewModel>(
      UnifiedShoppingViewModel(),
    );
  });

  tearDown(() async {
    await environment.tearDown();
  });

  Future<void> tickAndAnswer(WidgetTester tester, String answer) async {
    setStateSurface(tester);
    await tester.pumpWidget(
      stateApp(mode: Brightness.light, home: const UnifiedShoppingView()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.textContaining('Gul lök'));
    await tester.pumpAndSettle();
    expect(find.text(_sv.pantryAutoAddPromptTitle), findsOneWidget);

    await tester.tap(find.text(answer));
    await tester.pumpAndSettle();
  }

  testWidgets('"Ja" puts the row whose tick opened the prompt in the pantry', (
    tester,
  ) async {
    await tickAndAnswer(tester, _sv.pantryAutoAddPromptEnable);

    verify(() => userService.setAutoAddToPantry(true)).called(1);
    // The tick itself ran the pantry step once with the preference still
    // off; "Ja" runs it once more, now for real, for the same row.
    verify(
      () => checkoff.onItemCheckedOff(
        any(),
        any(
          that: isA<UnifiedShoppingItem>().having((i) => i.id, 'id', 'i1'),
        ),
        wasBought: false,
      ),
    ).called(2);
  });

  testWidgets('"Inte nu" records the prompt and adds nothing more', (
    tester,
  ) async {
    await tickAndAnswer(tester, _sv.pantryAutoAddPromptDecline);

    verify(userService.markPantryAutoAddPrompted).called(1);
    verifyNever(() => userService.setAutoAddToPantry(any()));
    verify(
      () => checkoff.onItemCheckedOff(
        any(),
        any(),
        wasBought: any(named: 'wasBought'),
      ),
    ).called(1);
  });
}
