// BUT-2494: the personal shopping list view wraps its rows in a
// ShoppingDietaryHintsScope fed from the view model's items. These tests mount
// the real UnifiedShoppingView with a household that is lactose-free and
// follow a seeded row all the way to the reminder box on screen, so the
// scope's wiring (not only the row widgets) is what is under test.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/models/tagging/ingredient_lookup_result.dart';
import 'package:butlery/models/tagging/ingredient_line.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/repositories/interfaces/category_preferences_repository.dart';
import 'package:butlery/services/tagging/ingredient_lookup_service.dart';
import 'package:butlery/services/unified/modules/shopping_category_preferences_module.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/services/user_service/user_service_roles.dart';
import 'package:butlery/viewmodels/shopping/household_shopping_choices.dart';
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';
import 'package:butlery/views/unified_shopping_view.dart';
import 'package:butlery/widgets/shopping/shopping_dietary_hint_box.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/shopping_list_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../views/design_states/state_harness.dart';

class _MockCategoryPreferences extends Mock
    implements CategoryPreferencesRepository {}

class _MockOwnProfile extends Mock implements OwnProfileReader {}

class _MockIngredientLookup extends Mock implements IngredientLookupService {}

const _listId = 'list-vecka';
const _ownerId = 'test-user-123';
const _reminder = 'Laktos i hushållet, välj laktosfri';

final _butter = IngredientData(
  id: 'butter',
  swedish: 'Smör',
  english: 'Butter',
  group: 'dairy',
  properties: const {'contains-lactose', 'dairy'},
);

void main() {
  late StateEnvironment environment;
  late MockUnifiedShoppingService service;

  setUp(() async {
    environment = await StateEnvironment.setUp(online: true);
    HouseholdShoppingChoices.forget();

    service = MockUnifiedShoppingService();
    when(service.loadLists).thenAnswer((_) async {});
    when(service.initialize).thenAnswer((_) async {});
    final repository = _MockCategoryPreferences();
    when(repository.getPreferences).thenAnswer((_) async => null);
    when(
      () => service.categoryPreferences,
    ).thenReturn(ShoppingCategoryPreferencesModule(repository: repository));

    // What ShoppingDietaryHintsController.fromLocator() reads: the viewer's own
    // allergen choices and the global ingredient data.
    final profile = _MockOwnProfile();
    when(() => profile.currentUserProfile).thenReturn(
      UserProfile(
        uid: _ownerId,
        displayName: 'Test User',
        email: 't@example.com',
        joinedAt: DateTime(2024, 1, 1),
        lastActiveAt: DateTime(2024, 1, 1),
        settingsMerged: true,
        allergenPreferences: const UserAllergenPreferences(
          trackedAllergens: {'laktos'},
          trackedDietary: {},
        ),
      ),
    );
    final lookup = _MockIngredientLookup();
    when(() => lookup.lookupFromRaw(any())).thenAnswer((call) async {
      final names = call.positionalArguments.first as List<String>;
      return IngredientLookupResult(
        matched: const [],
        unmatched: const [],
        coverage: 1,
        lines: [
          for (final name in names)
            IngredientLine(names: [name], ingredients: [_butter], known: true),
        ],
      );
    });

    TestServiceLocator.registerMock<UnifiedShoppingService>(service);
    TestServiceLocator.registerMock<OwnProfileReader>(profile);
    TestServiceLocator.registerMock<IngredientLookupService>(lookup);
    TestServiceLocator.registerMock<UnifiedShoppingViewModel>(
      UnifiedShoppingViewModel(),
    );
  });

  tearDown(() async {
    HouseholdShoppingChoices.forget();
    await environment.tearDown();
  });

  Future<void> mount(WidgetTester tester) async {
    setStateSurface(tester);
    await tester.pumpWidget(
      stateApp(mode: Brightness.light, home: const UnifiedShoppingView()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  testWidgets('an open row of the active list shows the reminder, a bought '
      'row does not', (tester) async {
    service.setShoppingState(
      lists: [
        ShoppingListFactory.build(
          id: _listId,
          name: 'Veckans inköp',
          ownerId: _ownerId,
          items: [
            ShoppingListFactory.buildItem(
              id: 'open',
              name: 'Smör',
              category: 'Mejeri',
            ),
            ShoppingListFactory.buildItem(
              id: 'done',
              name: 'Gräddfil',
              category: 'Mejeri',
              bought: true,
            ),
          ],
        ),
      ],
      activeListId: _listId,
    );

    await mount(tester);

    // Positive control: both rows are on screen.
    expect(find.textContaining('Smör'), findsOneWidget);
    expect(find.textContaining('Gräddfil'), findsOneWidget);
    expect(find.text(_reminder), findsOneWidget);
    expect(find.byType(ShoppingDietaryHintBox), findsOneWidget);
    expect(
      find.text('Påminnelser kan saknas. Läs alltid innehållet.'),
      findsOneWidget,
    );
  });
}
