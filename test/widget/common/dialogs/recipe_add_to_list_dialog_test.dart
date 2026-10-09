// BUT-2308: ingredients and list choice share one dialog; the list used last
// is preselected and no re-read of the lists happens on open.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/shopping/recipe_pantry_check.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/widgets/common/dialogs/recipe_add_to_list_dialog.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/mock_factory.dart';
import '../../../infrastructure/helpers/widget_test_app.dart';
import '../../../test_support/base_unit_test.dart';

class _MockShoppingService extends Mock implements UnifiedShoppingService {}

UnifiedShoppingList _list(String name, DateTime updatedAt, {String? id}) =>
    UnifiedShoppingList(
      id: id,
      name: name,
      ownerId: 'test-user-123',
      ownerDisplayName: 'Malin',
      updatedAt: updatedAt,
    );

void main() {
  late _MockShoppingService service;
  RecipeListChoice? result;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await BaseUnitTest.setupUnit();
  });

  setUp(() async {
    result = null;
    await TestServiceLocator.initialize();
    service = _MockShoppingService();
    when(() => service.isInitialized).thenReturn(true);
    TestServiceLocator.registerMock<UnifiedShoppingService>(service);
    production.ServiceLocator.initialize(DIContainer());
  });

  tearDown(() async {
    await TestServiceLocator.reset();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  Future<void> open(
    WidgetTester tester, {
    RecipePantryResult? pantryCheck,
    List<UnifiedShoppingItem>? items,
  }) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showDialog<RecipeListChoice>(
                context: context,
                builder: (_) => RecipeAddToListDialog(
                  recipeTitle: 'Köttbullar',
                  items:
                      items ??
                      [
                        UnifiedShoppingItem(
                          name: 'Mjölk',
                          amount: 1,
                          unit: 'l',
                        ),
                      ],
                  pantryCheck: pantryCheck,
                  shoppingService: service,
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows ingredients and lists together, active list preselected, '
      'without re-reading lists', (tester) async {
    final old = _list('Gammal', DateTime(2026, 1, 1));
    final active = _list('Veckan', DateTime(2025, 1, 1));
    when(() => service.lists).thenReturn([old, active]);
    when(() => service.activeListId).thenReturn(active.id);

    await open(tester);

    expect(find.textContaining('Mjölk'), findsOneWidget);
    expect(find.text('Veckan'), findsOneWidget);
    expect(find.text('Gammal'), findsOneWidget);
    verifyNever(() => service.loadLists());
    verifyNever(() => service.initialize());

    await tester.tap(find.text('Lägg till'));
    await tester.pumpAndSettle();
    expect(result?.listId, active.id);
    expect(result?.listName, 'Veckan');
  });

  testWidgets('without an active list the most recently updated one is '
      'preselected', (tester) async {
    final old = _list('Gammal', DateTime(2025, 1, 1));
    final recent = _list('Nyast', DateTime(2026, 5, 1));
    when(() => service.lists).thenReturn([old, recent]);
    when(() => service.activeListId).thenReturn(null);

    await open(tester);
    await tester.tap(find.text('Lägg till'));
    await tester.pumpAndSettle();
    expect(result?.listId, recent.id);
  });

  testWidgets('with no lists it offers a new list named after the recipe', (
    tester,
  ) async {
    when(() => service.lists).thenReturn([]);
    when(() => service.activeListId).thenReturn(null);

    await open(tester);
    await tester.tap(find.text('Lägg till'));
    await tester.pumpAndSettle();
    expect(result?.newListName, isNotNull);
    expect(result?.newListName, contains('Köttbullar'));
  });

  testWidgets('a service nobody has loaded is initialised and its lists '
      'appear afterwards', (tester) async {
    final late = _list('Sen', DateTime(2026, 1, 1));
    var loaded = false;
    when(() => service.isInitialized).thenReturn(false);
    when(() => service.initialize()).thenAnswer((_) async => loaded = true);
    when(() => service.lists).thenAnswer((_) => loaded ? [late] : []);
    when(() => service.activeListId).thenReturn(null);

    await open(tester);

    verify(() => service.initialize()).called(1);
    expect(find.text('Sen'), findsOneWidget);
    await tester.tap(find.text('Lägg till'));
    await tester.pumpAndSettle();
    expect(result?.listId, late.id);
  });

  testWidgets('a failing initialisation still leaves a usable dialog that '
      'offers a new list', (tester) async {
    when(() => service.isInitialized).thenReturn(false);
    when(() => service.initialize()).thenThrow(Exception('offline'));
    when(() => service.lists).thenReturn([]);
    when(() => service.activeListId).thenReturn(null);

    await open(tester);

    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Lägg till'));
    await tester.pumpAndSettle();
    expect(result?.newListName, contains('Köttbullar'));
  });

  testWidgets('choosing another existing list returns that list', (
    tester,
  ) async {
    final active = _list('Veckan', DateTime(2026, 1, 1));
    final other = _list('Fest', DateTime(2025, 1, 1));
    when(() => service.lists).thenReturn([active, other]);
    when(() => service.activeListId).thenReturn(active.id);

    await open(tester);
    await tester.tap(find.byKey(ValueKey('recipeListChoice_${other.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lägg till'));
    await tester.pumpAndSettle();

    expect(result?.listId, other.id);
    expect(result?.listName, 'Fest');
  });

  testWidgets('a new list with lists present needs a name of two characters '
      'and keeps the dialog open until it has one', (tester) async {
    final active = _list('Veckan', DateTime(2026, 1, 1));
    when(() => service.lists).thenReturn([active]);
    when(() => service.activeListId).thenReturn(active.id);

    await open(tester);
    await tester.tap(find.byKey(const ValueKey('recipeListChoice_new')));
    await tester.pumpAndSettle();
    // Prefilled from the recipe title.
    expect(find.text('Köttbullar - Ingredienser'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'a');
    await tester.tap(find.text('Lägg till'));
    await tester.pumpAndSettle();
    expect(find.text('Namnet måste vara minst 2 tecken'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(result, isNull);

    await tester.enterText(find.byType(TextFormField), '  ');
    await tester.tap(find.text('Lägg till'));
    await tester.pumpAndSettle();
    expect(find.text('Ange ett namn för listan'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), ' Fest ');
    await tester.tap(find.text('Lägg till'));
    await tester.pumpAndSettle();
    expect(result?.newListName, 'Fest');
    expect(result?.listId, isNull);
  });

  testWidgets('pantry marks on rows and the covered and lessened notes show '
      'what the pantry took', (tester) async {
    when(() => service.lists).thenReturn([]);
    when(() => service.activeListId).thenReturn(null);

    await open(
      tester,
      items: [
        UnifiedShoppingItem(
          name: 'Smör',
          amount: 1,
          unit: 'st',
          note: 'Kanske hemma',
        ),
      ],
      pantryCheck: const RecipePantryResult(
        toBuy: [],
        coveredAtHome: ['Ägg', 'Salt'],
        lessened: ['Mjölk'],
      ),
    );

    expect(find.textContaining('Kanske hemma'), findsOneWidget);
    expect(
      find.text('Finns hemma i tillräcklig mängd: Ägg, Salt'),
      findsOneWidget,
    );
    expect(
      find.text('Mindre än i receptet, eftersom en del finns hemma: Mjölk'),
      findsOneWidget,
    );
  });

  testWidgets('without a pantry check no pantry note is shown', (tester) async {
    when(() => service.lists).thenReturn([]);
    when(() => service.activeListId).thenReturn(null);

    await open(tester);

    expect(find.byKey(const ValueKey('recipePantryCovered')), findsNothing);
    expect(find.byKey(const ValueKey('recipePantryLessened')), findsNothing);
  });

  testWidgets('lists the user cannot edit are not offered', (tester) async {
    final editable = _list('Min', DateTime(2026, 1, 1), id: 'mine');
    final readOnly = _list('Någon annans', DateTime(2026, 6, 1), id: 'theirs');
    final permissions = MockFactory.createPermissionService()
      ..setPermissionState(
        currentUserId: 'test-user-123',
        permissions: {
          'theirs': {ResourcePermission.editor: false},
        },
      );
    TestServiceLocator.registerMock<PermissionService>(permissions);
    when(() => service.lists).thenReturn([readOnly, editable]);
    when(() => service.activeListId).thenReturn(readOnly.id);

    await open(tester);

    expect(find.text('Min'), findsOneWidget);
    expect(find.text('Någon annans'), findsNothing);
    // The active list is not editable, so it must not be preselected: the
    // editable one is.
    await tester.tap(find.text('Lägg till'));
    await tester.pumpAndSettle();
    expect(result?.listId, 'mine');
  });

  testWidgets('Cancel closes the dialog with no choice', (tester) async {
    final active = _list('Veckan', DateTime(2026, 1, 1));
    when(() => service.lists).thenReturn([active]);
    when(() => service.activeListId).thenReturn(active.id);

    await open(tester);
    await tester.tap(find.text('Avbryt'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(result, isNull);
  });
}
