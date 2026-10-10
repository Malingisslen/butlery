/// P6-U02: flow 02, the week menu to the shopping list through the merge
/// sheet (Skarmar v12 del 2 #inkopmerge, #inkopmergeoppen;
/// flows-roles-budget.md:44-51).
///
/// Pins what the sheet shows before anything is written (the preview), and
/// what "Lägg till N varor", "Ersätt listan" and Ångra write:
/// - produktbeslut PQ-10 = A: your own rows are always kept, and the rows
///   land in the week's generated list, created when missing.
/// - produktbeslut PQ-11 = A: the pantry subtracts amounts (§ 4.2).
/// - produktregler.md:131 (§ 2.4): Ångra takes back exactly the add, or the
///   replace.
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

PantryItem _pantry(String name, double? quantity, String unit) => PantryItem(
  id: 'p-$name',
  ingredientName: name,
  quantity: quantity,
  unit: unit,
  location: PantryLocation.pantry,
  addedAt: DateTime(2026, 6, 1),
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
      expect(receipt.replaced, isFalse);
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
      expect(mjol.note, '+ 4,5 dl · 3 recept');
      final ost = items.singleWhere(
        (i) => i.name.toLowerCase() == 'parmesanost',
      );
      expect(ost.note, '+ 100 g · 2 recept');
    });
  });

  group('TR::FLOW::02::merge-ark::ersätt-listan-på', () {
    test('replaces only the rows that came from recipes, keeps your own, '
        'and Ångra puts the old recipe rows back', () async {
      final own = UnifiedShoppingItem(id: 'own', name: 'kaffe', amount: 1);
      final old = UnifiedShoppingItem(
        id: 'old',
        name: 'gul lök',
        amount: 1,
        unit: 'st',
        bought: true,
      );
      final list = _weekList(items: [own, old], menuItemIds: ['old']);
      shopping.setShoppingState(lists: [list], personalLists: [list]);

      final receipt = await generator.apply(
        MenuShoppingListGenerator.preview(
          _source(),
          const MenuShoppingPantry.read([]),
          const MenuShoppingMergeOptions(replaceList: true),
        ),
      );

      final written = writes.single;
      expect(written.items.map((i) => i.id), contains('own'));
      expect(written.items.map((i) => i.id), isNot(contains('old')));
      expect(written.items, hasLength(4));
      expect(written.menuItemIds, receipt!.addedItemIds);
      expect(
        written.items.firstWhere((i) => i.name == 'gul lök').bought,
        isTrue,
        reason: 'bought status survives a replace by name and unit (§ 8.7)',
      );

      await generator.undo(receipt);

      final back = writes.last;
      expect(back.items.map((i) => i.id), unorderedEquals(['own', 'old']));
      expect(back.menuItemIds, ['old']);
    });

    test('a list written before menuItemIds existed cannot be replaced: '
        'Ersätt adds, keeps every row and its bought status, and the receipt '
        'says it added', () async {
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
      expect(generator.canReplaceWeekList(_date), isFalse);

      final merge = MenuShoppingListGenerator.preview(
        _source(),
        const MenuShoppingPantry.read([]),
        const MenuShoppingMergeOptions(replaceList: true),
      );
      final receipt = await generator.apply(merge);

      final written = writes.single;
      expect(receipt, isNotNull);
      expect(receipt!.replaced, isFalse, reason: 'nothing was replaced');
      expect(receipt.removedItems, isEmpty);
      expect(written.items, hasLength(2 + merge.itemCount));
      final legacy = written.items.where((i) => i.id.startsWith('legacy'));
      expect(legacy.map((i) => (i.id, i.bought)), [
        ('legacy-bought', true),
        ('legacy-open', false),
      ]);
      // From now on the list knows its recipe rows, so the next Ersätt works.
      expect(written.menuItemIds, receipt.addedItemIds);
      expect(generator.canReplaceWeekList(_date), isTrue);
    });

    test('a tracked list and a missing list can be replaced', () {
      expect(generator.canReplaceWeekList(_date), isTrue);
      final list = _weekList(menuItemIds: const []);
      shopping.setShoppingState(lists: [list], personalLists: [list]);
      expect(generator.canReplaceWeekList(_date), isTrue);
    });
  });

  group(
    'TR::FLOW::02::lägga-till::listan-ändrad-av-annan-person-samtidigt',
    () {
      test('a change made on another device reaches the receipt, which takes '
          'its removed rows from the server for Ångra', () async {
        final list = _weekList(menuItemIds: const []);
        shopping.setShoppingState(lists: [list], personalLists: [list]);
        final merge = MenuShoppingListGenerator.preview(
          _source(),
          const MenuShoppingPantry.read([]),
          const MenuShoppingMergeOptions(replaceList: true),
        );
        // The server's list, with a row another device ticked and one it
        // added. The generator writes per operation and never sends a list.
        final ticked = UnifiedShoppingItem(
          id: 'ticked',
          name: 'gul lök',
          amount: 1,
          unit: 'st',
          bought: true,
        );
        final theirs = UnifiedShoppingItem(
          id: 'theirs',
          name: 'bröd',
          amount: 1,
        );
        late List<UnifiedShoppingItem> written;
        when(() => shopping.applyPersonalMerge(any(), any())).thenAnswer((
          invocation,
        ) async {
          final request =
              invocation.positionalArguments[1] as PersonalMergeRequest;
          written = request.rows([ticked]);
          return PersonalMergeResult(
            list: _weekList(items: [theirs, ...written]),
            added: written,
            removed: [ticked],
            concurrentChange: true,
          );
        });

        final receipt = await generator.apply(merge);

        expect(receipt!.concurrentChange, isTrue);
        expect(receipt.removedItems, [ticked]);
        expect(receipt.addedItemIds, [for (final i in written) i.id]);
        expect(
          written.firstWhere((i) => i.name == 'gul lök').bought,
          isTrue,
          reason: 'the tick read from the server carries over (§ 8.7)',
        );
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
