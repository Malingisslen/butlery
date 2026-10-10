// BUT-2308: "Lägg i inköpslistan" on a recipe is one dialog and then the add
// itself. These tests drive the handler the way the button does and read what
// the user sees (snackbars, navigation) and what reaches the shopping service.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/viewmodels/recipe_detail_viewmodel.dart';
import 'package:butlery/views/recipe_detail/handlers/recipe_shopping_handler.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/mock_factory.dart';
import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/helpers/widget_test_app.dart';
import '../../../infrastructure/mocks/widget_mocks.dart';
import '../../../test_support/base_unit_test.dart';

class _MockShoppingService extends Mock implements UnifiedShoppingService {}

typedef _Entry =
    Future<void> Function(
      BuildContext context, {
      required int currentPortions,
      List<PantryItem>? pantry,
    });

void main() {
  late _MockShoppingService service;
  late MockRecipeDetailViewModel viewModel;
  late UnifiedShoppingList weekList;
  String? pushedRoute;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await BaseUnitTest.setupUnit();
  });

  setUp(() async {
    pushedRoute = null;
    await TestServiceLocator.initialize();
    service = _MockShoppingService();
    weekList = UnifiedShoppingList(
      id: 'week-1',
      name: 'Veckan',
      ownerId: 'test-user-123',
      ownerDisplayName: 'Malin',
    );
    when(() => service.isInitialized).thenReturn(true);
    when(() => service.lists).thenReturn([weekList]);
    when(() => service.activeListId).thenReturn(weekList.id);
    when(() => service.setActiveList(any())).thenAnswer((_) async => true);
    when(
      () => service.addItemsBatch(any(), source: any(named: 'source')),
    ).thenAnswer((_) async => true);
    TestServiceLocator.registerMock<UnifiedShoppingService>(service);
    production.ServiceLocator.initialize(DIContainer());

    viewModel = MockRecipeDetailViewModel()
      ..setRecipeDetailState(
        recipe: RecipeFactory.build(
          title: 'Köttbullar',
          portions: 4,
          ingredients: ['2 dl mjölk', '4 ägg', '200 g vetemjöl'],
        ),
      );
  });

  tearDown(() async {
    await TestServiceLocator.reset();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  Future<void> press(
    WidgetTester tester, {
    _Entry entry = RecipeShoppingHandler.generateShoppingListFromRecipe,
    List<PantryItem>? pantry,
  }) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        onGenerateRoute: (settings) {
          pushedRoute = settings.name;
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => const Scaffold(body: Text('shopping page')),
          );
        },
        child: ChangeNotifierProvider<RecipeDetailViewModel>.value(
          value: viewModel,
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  entry(context, currentPortions: 4, pantry: pantry),
              child: const Text('press'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('press'));
    await tester.pumpAndSettle();
  }

  Future<void> confirm(WidgetTester tester) async {
    await tester.tap(find.text('Lägg till'));
    await tester.pumpAndSettle();
  }

  List<UnifiedShoppingItem> addedItems() =>
      verify(
            () => service.addItemsBatch(captureAny(), source: 'recipe'),
          ).captured.single
          as List<UnifiedShoppingItem>;

  for (final entry in <String, _Entry>{
    'generateShoppingListFromRecipe':
        RecipeShoppingHandler.generateShoppingListFromRecipe,
    'showAddToCartConfirmation':
        RecipeShoppingHandler.showAddToCartConfirmation,
  }.entries) {
    testWidgets('${entry.key}: an existing list gets every ingredient with '
        'source recipe, a snackbar says how many, and Visa opens the list', (
      tester,
    ) async {
      await press(tester, entry: entry.value);
      await confirm(tester);

      verify(() => service.setActiveList('week-1')).called(1);
      final added = addedItems();
      expect(added, hasLength(3));
      verifyNever(() => service.createPersonalList(any()));
      expect(find.text('3 varor tillagda i "Veckan"'), findsOneWidget);
      expect(pushedRoute, isNull);

      await tester.tap(find.text('Visa'));
      await tester.pumpAndSettle();
      expect(pushedRoute, Routes.shoppingList);
    });
  }

  testWidgets('a new list is created first and the add targets its id', (
    tester,
  ) async {
    when(() => service.lists).thenReturn([]);
    when(() => service.activeListId).thenReturn(null);
    when(
      () => service.createPersonalList(any()),
    ).thenAnswer((_) async => 'created-1');

    await press(tester);
    await confirm(tester);

    verify(
      () => service.createPersonalList('Köttbullar - Ingredienser'),
    ).called(1);
    verify(() => service.setActiveList('created-1')).called(1);
    expect(addedItems(), hasLength(3));
    expect(
      find.text('3 varor tillagda i "Köttbullar - Ingredienser"'),
      findsOneWidget,
    );
  });

  testWidgets('a list that cannot be created adds nothing and says so', (
    tester,
  ) async {
    when(() => service.lists).thenReturn([]);
    when(() => service.activeListId).thenReturn(null);
    when(() => service.createPersonalList(any())).thenAnswer((_) async => null);

    await press(tester);
    await confirm(tester);

    verifyNever(
      () => service.addItemsBatch(any(), source: any(named: 'source')),
    );
    expect(
      find.textContaining('Kunde inte skapa eller välja inköpslista'),
      findsOneWidget,
    );
  });

  testWidgets('Cancel adds nothing and creates nothing', (tester) async {
    when(() => service.lists).thenReturn([]);
    when(() => service.activeListId).thenReturn(null);

    await press(tester);
    await tester.tap(find.text('Avbryt'));
    await tester.pumpAndSettle();

    verifyNever(() => service.createPersonalList(any()));
    verifyNever(() => service.setActiveList(any()));
    verifyNever(
      () => service.addItemsBatch(any(), source: any(named: 'source')),
    );
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a refused batch add shows the failure, not the success '
      'snackbar', (tester) async {
    when(
      () => service.addItemsBatch(any(), source: any(named: 'source')),
    ).thenAnswer((_) async => false);

    await press(tester);
    await confirm(tester);

    expect(
      find.textContaining('Kunde inte lägga till ingredienser'),
      findsOneWidget,
    );
    expect(find.textContaining('varor tillagda'), findsNothing);
    expect(find.text('Visa'), findsNothing);
  });

  testWidgets('a permission error thrown by the add is reported as missing '
      'permission on the shared list', (tester) async {
    when(
      () => service.addItemsBatch(any(), source: any(named: 'source')),
    ).thenThrow(PermissionDeniedException('nope'));

    await press(tester);
    await confirm(tester);

    expect(
      find.textContaining('behörighet att redigera denna delade inköpslista'),
      findsOneWidget,
    );
  });

  testWidgets('no edit permission on the target list means no add', (
    tester,
  ) async {
    // A freshly created list the permission cache does not yet grant.
    when(() => service.lists).thenReturn([]);
    when(() => service.activeListId).thenReturn(null);
    when(
      () => service.createPersonalList(any()),
    ).thenAnswer((_) async => 'created-1');
    TestServiceLocator.registerMock<PermissionService>(
      MockFactory.createPermissionService()..setPermissionState(
        currentUserId: 'test-user-123',
        permissions: {
          'created-1': {ResourcePermission.editor: false},
        },
      ),
    );

    await press(tester);
    await confirm(tester);

    verifyNever(
      () => service.addItemsBatch(any(), source: any(named: 'source')),
    );
    expect(
      find.text('Du har inte behörighet att redigera denna inköpslista'),
      findsOneWidget,
    );
  });

  testWidgets('a pantry that covers everything adds nothing and says what is '
      'at home, with no dialog', (tester) async {
    viewModel.setRecipeDetailState(
      recipe: RecipeFactory.build(portions: 4, ingredients: ['2 dl mjölk']),
    );

    await press(
      tester,
      pantry: [
        PantryItem(
          id: 'p1',
          ingredientName: 'mjölk',
          quantity: 10,
          unit: 'dl',
          location: PantryLocation.pantry,
          addedAt: DateTime(2026, 1, 1),
        ),
      ],
    );

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.textContaining('Allt finns hemma'), findsOneWidget);
    verifyNever(
      () => service.addItemsBatch(any(), source: any(named: 'source')),
    );
  });

  testWidgets('a recipe without ingredients warns and opens no dialog', (
    tester,
  ) async {
    viewModel.setRecipeDetailState(
      recipe: RecipeFactory.build(ingredients: []),
    );

    await press(tester);

    expect(find.byType(AlertDialog), findsNothing);
    expect(
      find.text('Receptet har inga ingredienser att lägga till'),
      findsOneWidget,
    );
    verifyNever(
      () => service.addItemsBatch(any(), source: any(named: 'source')),
    );
  });
}
