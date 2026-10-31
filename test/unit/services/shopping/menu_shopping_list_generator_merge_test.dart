/// Pins what the sheet shows before anything is written (the preview), and
/// what "Lägg till N varor", "Uppdatera listan" and Ångra write:
/// - produktbeslut PQ-10 = A: your own rows are always kept, and the rows
///   land in the week's generated list, created when missing.
/// - produktbeslut PQ-11 = A: the pantry subtracts amounts.
/// - Ångra takes back exactly the add, or the sync.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/models/recipe/recipe_ingredient.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/shopping_repository.dart';
import 'package:butlery/services/pantry/pantry_service.dart';
import 'package:butlery/services/shopping/menu_shopping_list_generator.dart';
import 'package:butlery/services/shopping/week_list_reconciler.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/mock_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';
import 'personal_merge_stub.dart';

class _MockPantryService extends Mock implements PantryService {}

const _userId = 'merge-user';
const _weekKey = '2026-W24';
final _date = DateTime(2026, 6, 10);

Recipe _recipe(String id, List<RecipeIngredient> entries) => Recipe(
  core: RecipeCore(
    id: id,
    title: id,
    description: '',
    ingredients: entries.map((e) => e.raw).toList(),
    structuredIngredients: entries,
    instructions: const ['x'],
    mealType: 'Middag',
  ),
  type: RecipeType.personal,
);

RecipeIngredient _ing(double amount, String unit, String name) =>
    RecipeIngredient(
      amount: amount,
      unit: unit,
      name: name,
      raw: '$amount $unit $name',
    );

/// Three dishes, 6 ingredient lines: lök three times (merged), mjölk in dl
/// and ml (converted), and pasta once.
MenuShoppingSource _source() => MenuShoppingListGenerator.sourceForMenu({
  'Middag': [
    _recipe('r1', [_ing(1, 'st', 'gul lök'), _ing(2, 'dl', 'mjölk')]),
    _recipe('r2', [_ing(1, 'st', 'gul lök'), _ing(100, 'ml', 'mjölk')]),
    _recipe('r3', [_ing(1, 'st', 'gul lök'), _ing(500, 'g', 'pasta')]),
  ],
}, _date);

PantryItem _pantry(
  String name,
  double? quantity,
  String unit, {
  String? ingredientId,
}) => PantryItem(
  id: 'p-$name',
  ingredientName: name,
  quantity: quantity,
  unit: unit,
  location: PantryLocation.pantry,
  addedAt: DateTime(2026, 6, 1),
  ingredientId: ingredientId,
);

UnifiedShoppingList _weekList({
  List<UnifiedShoppingItem> items = const [],
  List<String>? menuItemIds,
}) => UnifiedShoppingList(
  id: 'week-list',
  name: 'Inköpslista v.24',
  ownerId: _userId,
  ownerDisplayName: 'Test',
  items: items,
  generatedForWeek: _weekKey,
  menuItemIds: menuItemIds,
);

void main() {
  late MockUnifiedShoppingService shopping;
  late MenuShoppingListGenerator generator;
  late List<UnifiedShoppingList> writes;

  setUpAll(() {
    production.ServiceLocator.initialize(DIContainer());
    registerFallbackValue(
      UnifiedShoppingList(name: 'x', ownerId: 'x', ownerDisplayName: 'x'),
    );
    registerPersonalMergeFallbacks();
  });

  setUp(() async {
    await BaseUnitTest.setupUnit();
    await TestServiceLocator.initialize();
    TestServiceLocator.registerMock<AuthRepository>(
      MockFactory.createAuthRepository(isAuthenticated: true, userId: _userId),
    );
    shopping = MockUnifiedShoppingService();
    TestServiceLocator.registerMock<UnifiedShoppingService>(shopping);
    writes = [];
    stubPersonalMerge(shopping, writes);
    when(() => shopping.setActiveList(any())).thenAnswer((_) async => true);
    when(() => shopping.deleteList(any())).thenAnswer((_) async => true);
    generator = MenuShoppingListGenerator();
  });

  tearDown(() async {
    BaseUnitTest.resetMocks();
    await TestServiceLocator.reset();
  });

  group('the preview (#inkopmerge summary)', () {
    test('counts dishes, rows before merging, merged, converted', () {
      final merge = MenuShoppingListGenerator.preview(
        _source(),
        const MenuShoppingPantry.read([]),
        const MenuShoppingMergeOptions(),
      );

      expect(merge.recipeCount, 3);
      expect(merge.rawRowCount, 6, reason: '"3 rätter ger 6 rader"');
      expect(merge.itemCount, 3, reason: 'lök, mjölk, pasta');
      expect(merge.mergedCount, 3, reason: '6 rows became 3');
      expect(
        merge.convertedCount,
        1,
        reason: '"2 dl + 100 ml blir 3 dl": the ml row is converted',
      );
      final mjolk = merge.lines.firstWhere((l) => l.name == 'mjölk');
      expect(mjolk.amount, closeTo(3, 1e-9));
      expect(mjolk.unit, 'dl');
      final lok = merge.lines.firstWhere((l) => l.name == 'gul lök');
      expect(lok.amount, 3);
      expect(lok.sourceCount, 3);
    });

    test('Slå samman dubbletter off keeps every line as written', () {
      final merge = MenuShoppingListGenerator.preview(
        _source(),
        const MenuShoppingPantry.read([]),
        const MenuShoppingMergeOptions(mergeDuplicates: false),
      );
      expect(merge.itemCount, 6);
      expect(merge.mergedCount, 0);
      expect(merge.convertedCount, 0);
    });

    test('Konvertera enheter off keeps dl and ml as separate amounts on one '
        'row', () {
      final merge = MenuShoppingListGenerator.preview(
        _source(),
        const MenuShoppingPantry.read([]),
        const MenuShoppingMergeOptions(convertUnits: false),
      );
      expect(merge.itemCount, 3, reason: 'BUT-2304: one row per ingredient');
      expect(merge.convertedCount, 0);
      final mjolk = merge.lines.singleWhere((l) => l.name == 'mjölk');
      expect(mjolk.amount, 2);
      expect(mjolk.unit, 'dl');
      expect(mjolk.extraAmounts, [(amount: 100.0, unit: 'ml')]);
    });

    test('BUT-2304: a pantry match on a folded row is Kanske hemma, with no '
        'deduction', () {
      final source = MenuShoppingListGenerator.sourceForMenu({
        'Middag': [
          _recipe('r1', [_ing(350, 'g', 'vetemjöl')]),
          _recipe('r2', [_ing(3, 'dl', 'vetemjöl')]),
        ],
      }, _date);
      final merge = MenuShoppingListGenerator.preview(
        source,
        MenuShoppingPantry.read([_pantry('vetemjöl', 1, 'kg')]),
        const MenuShoppingMergeOptions(),
      );
      final line = merge.lines.single;
      expect(line.mark, MenuShoppingPantryMark.maybeAtHome);
      expect(line.amount, 350);
    });

    test('a row without an amount is covered by stock in date, and marked '
        'Kolla datum when the stock is past it (Malin 2026-10-31)', () {
      final source = MenuShoppingListGenerator.sourceForMenu({
        'Middag': [
          _recipe('r1', [
            const RecipeIngredient(name: 'salt', raw: 'salt'),
          ]),
        ],
      }, _date);

      final merge = MenuShoppingListGenerator.preview(
        source,
        MenuShoppingPantry.read([_pantry('salt', null, 'st')]),
        const MenuShoppingMergeOptions(),
      );
      expect(merge.lines, isEmpty);
      expect(merge.coveredAtHome, ['salt']);
      expect(merge.atHomeCount, 1);

      final expired = MenuShoppingListGenerator.preview(
        source,
        MenuShoppingPantry.read([
          PantryItem(
            id: 'p-salt',
            ingredientName: 'salt',
            quantity: 1,
            unit: 'st',
            location: PantryLocation.pantry,
            addedAt: DateTime(2026, 1, 1),
            expiryDate: DateTime(2020, 1, 1),
          ),
        ]),
        const MenuShoppingMergeOptions(),
      );
      expect(expired.lines.single.mark, MenuShoppingPantryMark.checkDate);
      expect(expired.coveredAtHome, isEmpty);
    });

    test('a prepared pantry row covers the plain ingredient', () {
      final source = MenuShoppingListGenerator.sourceForMenu({
        'Middag': [
          _recipe('r1', [_ing(1, 'st', 'lök')]),
        ],
      }, _date);
      final merge = MenuShoppingListGenerator.preview(
        source,
        MenuShoppingPantry.read([_pantry('hackad lök', 2, 'st')]),
        const MenuShoppingMergeOptions(),
      );
      expect(merge.lines, isEmpty);
      expect(merge.coveredAtHome, ['lök']);
    });

    group('pantry match by registry id', () {
      // "rödlök" and "lök" have different name keys (rodlok / lok), so only
      // a shared id can make the pantry cover the row.
      MenuShoppingSource sourceFor(String? recipeLineId) =>
          MenuShoppingListGenerator.sourceForMenu({
            'Middag': [
              _recipe('r1', [
                RecipeIngredient(
                  amount: 1,
                  unit: 'st',
                  name: 'rödlök',
                  raw: '1 st rödlök',
                  ingredientId: recipeLineId,
                ),
              ]),
            ],
          }, _date);

      MenuShoppingMergePreview previewWith(
        String? recipeLineId,
        String? pantryId,
      ) => MenuShoppingListGenerator.preview(
        sourceFor(recipeLineId),
        MenuShoppingPantry.read([
          _pantry('lök', 2, 'st', ingredientId: pantryId),
        ]),
        const MenuShoppingMergeOptions(),
      );

      test('the same id covers the row although the names differ', () {
        final merge = previewWith('onion', 'onion');
        expect(merge.lines, isEmpty);
        expect(merge.coveredAtHome, ['rödlök']);
      });

      test('without ids the differing names do not match', () {
        final merge = previewWith(null, null);
        expect(merge.lines.single.name, 'rödlök');
        expect(merge.atHomeCount, 0);
      });

      test('an id on only one side does not match', () {
        expect(previewWith('onion', null).atHomeCount, 0);
        expect(previewWith(null, 'onion').atHomeCount, 0);
      });

      test('different ids with different names do not match', () {
        expect(previewWith('onion', 'leek').atHomeCount, 0);
      });

      test('the merge line carries the id for the list row', () {
        expect(previewWith('onion', null).lines.single.ingredientId, 'onion');
      });
    });

    test('Dra bort skafferivaror subtracts: 2 dl at home, 3 dl needed, '
        '1 dl on the list (PQ-11 = A)', () {
      final merge = MenuShoppingListGenerator.preview(
        _source(),
        MenuShoppingPantry.read([
          _pantry('mjölk', 2, 'dl'),
          _pantry('pasta', 1, 'kg'),
        ]),
        const MenuShoppingMergeOptions(),
      );
      expect(merge.atHomeCount, 2);
      expect(
        merge.lines.firstWhere((l) => l.name == 'mjölk').amount,
        closeTo(1, 1e-9),
      );
      expect(
        merge.lines.map((l) => l.name),
        isNot(contains('pasta')),
        reason: '1 kg at home covers 500 g',
      );
      expect(merge.coveredAtHome, ['pasta'], reason: 'the deduction is named');
    });

    test('with the switch off nothing is subtracted', () {
      final merge = MenuShoppingListGenerator.preview(
        _source(),
        MenuShoppingPantry.read([_pantry('pasta', 1, 'kg')]),
        const MenuShoppingMergeOptions(subtractPantry: false),
      );
      expect(merge.atHomeCount, 0);
      expect(merge.lines.map((l) => l.name), contains('pasta'));
    });

    test('an unreadable pantry subtracts nothing and says so', () {
      final merge = MenuShoppingListGenerator.preview(
        _source(),
        const MenuShoppingPantry.unavailable(),
        const MenuShoppingMergeOptions(),
      );
      expect(merge.pantryUnavailable, isTrue);
      expect(merge.atHomeCount, 0);
      expect(merge.itemCount, 3);
    });
  });

  group('TR::FLOW::02::merge-ark::lägg-till-n-varor', () {
    test('adds the rows next to every row already on the week list, and '
        'Ångra takes back exactly those rows', () async {
      final own = UnifiedShoppingItem(id: 'own', name: 'kaffe', amount: 1);
      final earlier = UnifiedShoppingItem(
        id: 'earlier',
        name: 'ris',
        amount: 1,
      );
      final list = _weekList(items: [own, earlier], menuItemIds: ['earlier']);
      shopping.setShoppingState(lists: [list], personalLists: [list]);

      final merge = MenuShoppingListGenerator.preview(
        _source(),
        const MenuShoppingPantry.read([]),
        const MenuShoppingMergeOptions(),
      );
      final receipt = await generator.apply(merge);

      expect(receipt, isNotNull);
      expect(receipt!.itemCount, 3);
      final written = writes.single;
      expect(written.items.map((i) => i.id), containsAll(['own', 'earlier']));
      expect(written.items, hasLength(5));
      expect(
        written.menuItemIds,
        containsAll(['earlier', ...receipt.addedItemIds]),
      );
      final lok = written.items.firstWhere((i) => i.name == 'gul lök');
      expect(lok.note, '3 recept', reason: 'Raden visar "3 recept"');
      verify(() => shopping.setActiveList('week-list')).called(1);

      final undone = await generator.undo(receipt);

      expect(undone, isTrue);
      final back = writes.last;
      expect(back.items.map((i) => i.id), ['own', 'earlier']);
      expect(back.menuItemIds, ['earlier']);
    });

    test('a written row carries the registry id of its recipe lines, and a '
        'row whose lines disagree carries none', () async {
      const lok = RecipeIngredient(
        amount: 1,
        unit: 'st',
        name: 'gul lök',
        raw: '1 st gul lök',
        ingredientId: 'onion',
      );
      RecipeIngredient bringa(String id) => RecipeIngredient(
        amount: 500,
        unit: 'g',
        name: 'bringa',
        raw: '500 g bringa',
        ingredientId: id,
      );
      shopping.setShoppingState(
        lists: [_weekList()],
        personalLists: [_weekList()],
      );
      final source = MenuShoppingListGenerator.sourceForMenu({
        'Middag': [
          _recipe('r1', [lok, bringa('beef-brisket')]),
          _recipe('r2', [lok, bringa('lamb-brisket')]),
        ],
      }, _date);

      await generator.apply(
        MenuShoppingListGenerator.preview(
          source,
          const MenuShoppingPantry.read([]),
          const MenuShoppingMergeOptions(),
        ),
      );

      final written = writes.single.items;
      expect(
        written.singleWhere((i) => i.name == 'gul lök').ingredientId,
        'onion',
      );
      expect(
        written.singleWhere((i) => i.name == 'bringa').ingredientId,
        isNull,
      );
    });

    test(
      'a missing week list is created, and Ångra removes it again',
      () async {
        shopping.setShoppingState(lists: [], personalLists: []);
        when(
          () => shopping.createPersonalList(any(), items: any(named: 'items')),
        ).thenAnswer((_) async {
          final created = _weekList();
          shopping.setShoppingState(lists: [created], personalLists: [created]);
          return 'week-list';
        });

        final receipt = await generator.apply(
          MenuShoppingListGenerator.preview(
            _source(),
            const MenuShoppingPantry.read([]),
            const MenuShoppingMergeOptions(),
          ),
        );

        expect(receipt!.createdList, isTrue);
        expect(writes.single.generatedForWeek, _weekKey);
        await generator.undo(receipt);
        verify(() => shopping.deleteList('week-list')).called(1);
      },
    );
  });

  group('BUT-2304: the note of a folded row', () {
    test('lists the extra amounts before the recipe count', () async {
      final list = _weekList(menuItemIds: const []);
      shopping.setShoppingState(lists: [list], personalLists: [list]);
      final source = MenuShoppingListGenerator.sourceForMenu({
        'Middag': [
          _recipe('r1', [
            _ing(350, 'g', 'vetemjöl'),
            _ing(1, '', 'Parmesanost'),
          ]),
          _recipe('r2', [
            _ing(3, 'dl', 'vetemjöl'),
            _ing(100, 'g', 'parmesanost'),
            _ing(1.5, 'dl', 'vetemjöl'),
          ]),
        ],
      }, _date);
      final merge = MenuShoppingListGenerator.preview(
        source,
        const MenuShoppingPantry.read([]),
        const MenuShoppingMergeOptions(),
      );
      await generator.apply(merge);

      final items = writes.single.items;
      expect(items, hasLength(2));
      final mjol = items.singleWhere((i) => i.name == 'vetemjöl');
      expect(mjol.amount, 350);
      expect(mjol.unit, 'g');
      // r2 names vetemjöl on two lines but is one recipe.
      expect(mjol.note, '+ 4,5 dl · 2 recept');
      final ost = items.singleWhere(
        (i) => i.name.toLowerCase() == 'parmesanost',
      );
      expect(ost.note, '+ 100 g · 2 recept');
    });
  });

  group('TR::FLOW::02::merge-ark::listan-följer-menyn', () {
    MenuShoppingMergePreview previewOf(List<Recipe> recipes) =>
        MenuShoppingListGenerator.preview(
          MenuShoppingListGenerator.sourceForMenu({'Middag': recipes}, _date),
          const MenuShoppingPantry.read([]),
          const MenuShoppingMergeOptions(),
        );

    final onion = _recipe('r1', [_ing(1, 'st', 'gul lök')]);
    final milk = _recipe('r2', [_ing(2, 'dl', 'mjölk')]);
    final pasta = _recipe('r3', [_ing(500, 'g', 'pasta')]);
    final bigMilk = _recipe('r4', [_ing(5, 'dl', 'mjölk')]);

    UnifiedShoppingItem rowNamed(UnifiedShoppingList list, String name) =>
        list.items.firstWhere((i) => i.name == name);

    void seedEmptyWeekList({List<UnifiedShoppingItem> items = const []}) {
      final list = _weekList(items: items, menuItemIds: const []);
      shopping.setShoppingState(lists: [list], personalLists: [list]);
    }

    test('a second sync updates the rows the first wrote instead of doubling '
        'them, leaves a ticked row and a row of yours alone, takes off a '
        'dish\'s untouched row, and Ångra puts every old value back', () async {
      seedEmptyWeekList(
        items: [UnifiedShoppingItem(id: 'own', name: 'kaffe', amount: 1)],
      );
      final first = await generator.apply(previewOf([onion, milk, pasta]));
      final afterFirst = writes.last;
      final milkId = rowNamed(afterFirst, 'mjölk').id;
      final milkBefore = rowNamed(afterFirst, 'mjölk').amount;
      // The user ticks the onion in the shop.
      final ticked = [
        for (final i in afterFirst.items)
          i.name == 'gul lök' ? i.copyWith(bought: true) : i,
      ];
      shopping.setShoppingState(
        lists: [afterFirst.copyWith(items: ticked)],
        personalLists: [afterFirst.copyWith(items: ticked)],
      );

      // The week now has more milk, no pasta, and a second onion dish.
      final second = await generator.apply(
        previewOf([onion, onion, bigMilk]),
      );

      final written = writes.last;
      expect(second, isNotNull);
      expect(first!.itemCount, 3);
      expect(second!.addedItemIds, isEmpty, reason: 'no row is doubled');
      expect(
        written.items.where((i) => i.name == 'mjölk'),
        hasLength(1),
        reason: 'the milk row is updated in place',
      );
      expect(rowNamed(written, 'mjölk').id, milkId);
      expect(rowNamed(written, 'mjölk').amount, greaterThan(milkBefore));
      expect(
        rowNamed(written, 'gul lök').amount,
        1,
        reason: 'a ticked row is never updated',
      );
      expect(rowNamed(written, 'gul lök').bought, isTrue);
      expect(written.items.map((i) => i.name), isNot(contains('pasta')));
      expect(written.items.map((i) => i.name), contains('kaffe'));
      expect(second.updatedList, isTrue);
      expect(second.removedItems.map((i) => i.name), ['pasta']);
      expect(second.changedItems.single.amount, milkBefore);

      await generator.undo(second);

      final back = writes.last;
      expect(rowNamed(back, 'mjölk').amount, milkBefore);
      expect(back.items.map((i) => i.name), contains('pasta'));
      expect(back.items.map((i) => i.name), contains('kaffe'));
    });

    test(
      'pressing the same merge twice writes nothing the second time',
      () async {
        seedEmptyWeekList();
        await generator.apply(previewOf([onion, milk, pasta]));
        final afterFirst = writes.last;

        final second = await generator.apply(previewOf([onion, milk, pasta]));

        expect(second!.itemCount, 0);
        expect(second.updatedList, isFalse);
        expect(
          writes.last.items.map((i) => i.id),
          unorderedEquals(afterFirst.items.map((i) => i.id)),
        );
        expect(writes.last.items, hasLength(afterFirst.items.length));
      },
    );

    test('a row you changed is kept as you left it', () async {
      seedEmptyWeekList();
      await generator.apply(previewOf([onion, milk]));
      final afterFirst = writes.last;
      final edited = [
        for (final i in afterFirst.items)
          i.name == 'mjölk' ? i.copyWith(amount: 99) : i,
      ];
      shopping.setShoppingState(
        lists: [afterFirst.copyWith(items: edited)],
        personalLists: [afterFirst.copyWith(items: edited)],
      );

      final second = await generator.apply(previewOf([onion, bigMilk]));

      expect(rowNamed(writes.last, 'mjölk').amount, 99);
      expect(second!.updatedList, isFalse);
      expect(writes.last.items.where((i) => i.name == 'mjölk'), hasLength(1));
    });

    test('a list written before rows carried their origin: a row with the '
        'same amount is taken over, one you changed is left, and neither is '
        'doubled', () async {
      final same = UnifiedShoppingItem(
        id: 'same',
        name: 'gul lök',
        unit: 'st',
        amount: 1,
        bought: true,
      );
      final changed = UnifiedShoppingItem(
        id: 'changed',
        name: 'pasta',
        unit: 'g',
        amount: 123,
      );
      final list = _weekList(
        items: [same, changed],
        menuItemIds: ['same', 'changed'],
      );
      shopping.setShoppingState(lists: [list], personalLists: [list]);

      final receipt = await generator.apply(previewOf([onion, pasta]));

      final written = writes.single;
      expect(receipt!.addedItemIds, isEmpty);
      expect(written.items, hasLength(2));
      expect(rowNamed(written, 'gul lök').generatedFrom, 'menu');
      expect(rowNamed(written, 'gul lök').bought, isTrue);
      expect(rowNamed(written, 'pasta').amount, 123);
    });

    test('a list written before menuItemIds existed: the rows are added, '
        'every old row and its tick is kept, and the list then knows its '
        'rows', () async {
      final legacyBought = UnifiedShoppingItem(
        id: 'legacy-bought',
        name: 'gul lök',
        unit: 'st',
        amount: 3,
        bought: true,
      );
      final legacyOpen = UnifiedShoppingItem(
        id: 'legacy-open',
        name: 'mjöl',
        amount: 2,
      );
      final list = _weekList(items: [legacyBought, legacyOpen]);
      shopping.setShoppingState(lists: [list], personalLists: [list]);
      expect(
        generator.weekListHasRowsFrom(_date, ShoppingRowOrigin.menu),
        isFalse,
      );

      final merge = MenuShoppingListGenerator.preview(
        _source(),
        const MenuShoppingPantry.read([]),
        const MenuShoppingMergeOptions(),
      );
      final receipt = await generator.apply(merge);

      final written = writes.single;
      expect(receipt, isNotNull);
      expect(receipt!.removedItems, isEmpty);
      expect(written.items, hasLength(2 + merge.itemCount));
      final legacy = written.items.where((i) => i.id.startsWith('legacy'));
      expect(legacy.map((i) => (i.id, i.bought)), [
        ('legacy-bought', true),
        ('legacy-open', false),
      ]);
      expect(written.menuItemIds, receipt.addedItemIds);
      expect(
        generator.weekListHasRowsFrom(_date, ShoppingRowOrigin.menu),
        isTrue,
      );
    });

    test('weekListHasRowsFrom: false for a missing list, your own rows and '
        'the other source\'s rows, true for this source\'s', () async {
      expect(
        generator.weekListHasRowsFrom(_date, ShoppingRowOrigin.menu),
        isFalse,
      );
      seedEmptyWeekList(
        items: [UnifiedShoppingItem(id: 'own', name: 'kaffe', amount: 1)],
      );
      expect(
        generator.weekListHasRowsFrom(_date, ShoppingRowOrigin.menu),
        isFalse,
      );

      await generator.apply(previewOf([onion]));

      expect(
        generator.weekListHasRowsFrom(_date, ShoppingRowOrigin.menu),
        isTrue,
      );
      expect(
        generator.weekListHasRowsFrom(_date, ShoppingRowOrigin.plan),
        isFalse,
      );
    });

    test(
      'activate false writes the list without making it the active one',
      () async {
        seedEmptyWeekList();

        await generator.apply(previewOf([onion]), activate: false);

        expect(writes, hasLength(1));
        verifyNever(() => shopping.setActiveList(any()));
      },
    );
  });

  group(
    'TR::FLOW::02::lägga-till::listan-ändrad-av-annan-person-samtidigt',
    () {
      test('a change made on another device reaches the receipt, which takes '
          'its removed and changed rows from the server for Ångra, and the '
          'sync decides on the server\'s rows', () async {
        final list = _weekList(menuItemIds: const []);
        shopping.setShoppingState(lists: [list], personalLists: [list]);
        final merge = MenuShoppingListGenerator.preview(
          _source(),
          const MenuShoppingPantry.read([]),
          const MenuShoppingMergeOptions(),
        );
        // The server's list, with a week row another device ticked and one it
        // added. The generator writes per operation and never sends a list.
        final ticked = WeekListReconciler.stamp([
          UnifiedShoppingItem(
            id: 'ticked',
            name: 'gul lök',
            amount: 1,
            unit: 'st',
            bought: true,
          ),
        ], ShoppingRowOrigin.menu).single;
        final theirs = UnifiedShoppingItem(
          id: 'theirs',
          name: 'bröd',
          amount: 1,
        );
        final gone = UnifiedShoppingItem(id: 'gone', name: 'ris', amount: 1);
        final was = UnifiedShoppingItem(id: 'was', name: 'te', amount: 1);
        late PersonalMergeWrite write;
        when(() => shopping.applyPersonalMerge(any(), any())).thenAnswer((
          invocation,
        ) async {
          final request =
              invocation.positionalArguments[1] as PersonalMergeRequest;
          write = request.sync([ticked]);
          return PersonalMergeResult(
            list: _weekList(items: [theirs, ticked, ...write.add]),
            added: write.add,
            removed: [gone],
            changedFrom: [was],
            concurrentChange: true,
          );
        });

        final receipt = await generator.apply(merge);

        expect(receipt!.concurrentChange, isTrue);
        expect(receipt.removedItems, [gone]);
        expect(receipt.changedItems, [was]);
        expect(receipt.addedItemIds, [for (final i in write.add) i.id]);
        expect(
          write.add.map((i) => i.name),
          isNot(contains('gul lök')),
          reason: 'the tick read from the server keeps its row, no copy',
        );
        expect(write.remove, isEmpty);
        expect(write.update, isEmpty);
        verifyNever(() => shopping.updateList(any()));
      });
    },
  );

  group('readPantry', () {
    test('a failed read is unavailable, never an empty pantry', () async {
      final pantry = _MockPantryService();
      when(
        () => pantry.watchAll(_userId),
      ).thenAnswer((_) => Stream.error(StateError('offline')));
      TestServiceLocator.registerMock<PantryService>(pantry);

      final result = await generator.readPantry();

      expect(result.unavailable, isTrue);
    });

    test('a read pantry carries its rows', () async {
      final pantry = _MockPantryService();
      when(() => pantry.watchAll(_userId)).thenAnswer(
        (_) => Stream.value([_pantry('mjölk', 2, 'dl')]),
      );
      TestServiceLocator.registerMock<PantryService>(pantry);

      final result = await generator.readPantry();

      expect(result.unavailable, isFalse);
      expect(result.items.single.ingredientName, 'mjölk');
    });
  });
}
