/// BUT-956 + BUT-1234: menu→shopping-list GENERATION orchestration contract.
///
/// The pure aggregation math is pinned in `menu_shopping_aggregator_test.dart`
/// — this file pins what the GENERATOR adds on top: one list per ISO week
/// identified by the `generatedForWeek` marker (BUT-1234 — lookup by name was
/// the BUT-956 V1 contract and was deliberately replaced), idempotent
/// regeneration into the marked list even after a user rename, hands-off
/// treatment of identically named UNMARKED user lists, bought-status survival
/// across regeneration (keyed by the SAME Swedish normalization as the
/// aggregation), honest degradation when plan recipes can't be resolved, and
/// the `nothingToGenerate` sentinel for an empty week (null is reserved for
/// FAILURE — the view shows different copy for each).
///
/// Scaffolding note: the generator resolves all three services via
/// `ServiceLocator.get` at call time, and `executeServiceOperation`'s
/// auth pre-flight reads `AuthRepository.currentUserId` directly — the
/// default test registration is UNAUTHENTICATED, which silently returns
/// null (knowledge entry 2026-06-10). Every non-null assertion below carries
/// a loud `reason:` so that trap fails honestly — doubly load-bearing now
/// that null is the documented failure signal.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/core/utils/iso_week_utils.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe/recipe_ingredient.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/services/shopping/menu_shopping_list_generator.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/mock_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

class _MockWeeklyMenuPlanService extends Mock
    implements WeeklyMenuPlanService {}

const _testUserId = 'test-user-123';

/// 2026-06-10 is a Wednesday in ISO week 24 — the expected list name and
/// week marker are asserted as LITERALS so this suite independently pins the
/// name format, the marker format, and the week computation (no tautological
/// re-derivation via IsoWeekUtils in the assertions). The name comes from
/// `AppLocale.current`, which defaults to Swedish in unit tests.
final _date = DateTime(2026, 6, 10);
const _expectedListName = 'Inköpslista v.24';
const _expectedWeekKey = '2026-W24';

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

WeeklyMenuPlan _plan(List<String> recipeIds) => WeeklyMenuPlan(
      id: 'plan-1',
      userId: _testUserId,
      weekStartDate: IsoWeekUtils.weekStartOf(_date),
      entries: [
        for (final (i, recipeId) in recipeIds.indexed)
          WeeklyMenuPlanEntry(
            id: 'entry-$i',
            day: DayOfWeek.values[i % 7],
            slot: MealSlot.middag,
            recipeId: recipeId,
            recipeTitle: recipeId,
          ),
      ],
      createdAt: DateTime(2026, 6, 8),
      updatedAt: DateTime(2026, 6, 8),
    );

UnifiedShoppingList _list(
  String id,
  String name, {
  List<UnifiedShoppingItem> items = const [],
  String? generatedForWeek,
}) =>
    UnifiedShoppingList(
      id: id,
      name: name,
      ownerId: _testUserId,
      ownerDisplayName: 'Test',
      items: items,
      generatedForWeek: generatedForWeek,
    );

void main() {
  late _MockWeeklyMenuPlanService menuService;
  late MockUnifiedRecipeService recipeService;
  late MockUnifiedShoppingService shoppingService;
  late MenuShoppingListGenerator generator;

  setUpAll(() {
    production.ServiceLocator.initialize(DIContainer());
    registerFallbackValue(
      UnifiedShoppingList(
          name: 'fallback', ownerId: 'x', ownerDisplayName: 'x'),
    );
  });

  setUp(() async {
    await BaseUnitTest.setupUnit();
    await TestServiceLocator.initialize();

    // executeServiceOperation's auth pre-flight — default registry is
    // unauthenticated and would silently return null (the false-"never ran"
    // trap).
    TestServiceLocator.registerMock<AuthRepository>(
      MockFactory.createAuthRepository(
          isAuthenticated: true, userId: _testUserId),
    );

    menuService = _MockWeeklyMenuPlanService();
    recipeService = MockUnifiedRecipeService();
    shoppingService = MockUnifiedShoppingService();
    TestServiceLocator.registerMock<WeeklyMenuPlanService>(menuService);
    TestServiceLocator.registerMock<UnifiedRecipeService>(recipeService);
    TestServiceLocator.registerMock<UnifiedShoppingService>(shoppingService);

    generator = MenuShoppingListGenerator();
  });

  tearDown(() async {
    BaseUnitTest.resetMocks();
    await TestServiceLocator.reset();
  });

  // Two recipes sharing mjöl (dl) so the generated items prove the RESOLVED
  // recipes reached the aggregator (3 dl summed), plus ägg as a second line.
  void seedTwoRecipePlan() {
    when(() => menuService.getWeek(any()))
        .thenAnswer((_) async => _plan(['r1', 'r2']));
    recipeService.setRecipeState(
      recipes: [
        _recipe('r1', const [
          RecipeIngredient(
              amount: 2, unit: 'dl', name: 'mjöl', raw: '2 dl mjöl'),
        ]),
        _recipe('r2', const [
          RecipeIngredient(
              amount: 1, unit: 'dl', name: 'mjöl', raw: '1 dl mjöl'),
          RecipeIngredient(amount: 3, unit: 'st', name: 'ägg', raw: '3 ägg'),
        ]),
      ],
      isInitialized: true,
    );
    when(() => shoppingService.updateList(any())).thenAnswer((_) async => true);
  }

  UnifiedShoppingList capturedUpdate() =>
      verify(() => shoppingService.updateList(captureAny())).captured.single
          as UnifiedShoppingList;

  group('MenuShoppingListGenerator (BUT-956)', () {
    test(
        'absent week list: creates "Inköpslista v.NN" and writes the '
        'aggregated items into it', () async {
      // Proves: first generation of a week creates the named list and the
      // items the user sees are the cross-recipe aggregation.
      seedTwoRecipePlan();
      shoppingService.setShoppingState(lists: [], personalLists: []);
      when(() => shoppingService.createPersonalList(any(),
          items: any(named: 'items'))).thenAnswer((_) async {
        // Mirror production: after creation the service's list cache holds
        // the new (empty) list, which the generator re-reads to update.
        shoppingService.setShoppingState(
          lists: [_list('new-list-1', _expectedListName)],
          personalLists: [_list('new-list-1', _expectedListName)],
        );
        return 'new-list-1';
      });

      final result = await generator.generateForWeek(_date);

      expect(result, isNotNull,
          reason: 'generation must run — a null here usually means the '
              'auth pre-flight silently short-circuited');
      expect(result!.listId, 'new-list-1');
      expect(result.listName, _expectedListName);
      expect(result.recipeCount, 2);
      expect(result.unresolvedRecipes, 0);

      verify(() => shoppingService.createPersonalList(_expectedListName,
          items: any(named: 'items'))).called(1);

      final written = capturedUpdate();
      expect(written.id, 'new-list-1');
      expect(written.generatedForWeek, _expectedWeekKey,
          reason: 'BUT-1234: a freshly created week list must carry the '
              'generatedForWeek marker so the next regeneration finds it '
              'even if the user renames it');
      final byName = {for (final i in written.items) i.name: i};
      expect(byName.keys, containsAll(['mjöl', 'ägg']));
      expect(byName['mjöl']!.amount, 3,
          reason: '2 dl + 1 dl across the two plan recipes must arrive summed');
      expect(byName['mjöl']!.unit, 'dl');
      expect(byName['ägg']!.amount, 3);
      expect(result.itemCount, written.items.length);
    });

    test(
        'idempotent regeneration: existing week list is updated in place, '
        'never duplicated, and its content is replaced', () async {
      // Proves: re-running "Generera inköpslista" for the same week targets
      // the existing MARKED list (no "Inköpslista v.24 (2)" pile-up) and the
      // generator OWNS the content — stale/manual lines do not survive.
      seedTwoRecipePlan();
      final existing = _list(
        'existing-1',
        _expectedListName,
        generatedForWeek: _expectedWeekKey,
        items: [
          UnifiedShoppingItem(name: 'gammal vara', amount: 1, unit: 'st'),
        ],
      );
      shoppingService.setShoppingState(
        lists: [existing],
        personalLists: [existing],
      );

      final result = await generator.generateForWeek(_date);

      expect(result, isNotNull,
          reason: 'regeneration must run against the existing list');
      expect(result!.listId, 'existing-1');
      verifyNever(() => shoppingService.createPersonalList(any(),
          items: any(named: 'items')));

      final written = capturedUpdate();
      expect(written.id, 'existing-1');
      expect(written.items.map((i) => i.name), isNot(contains('gammal vara')),
          reason: 'documented V1 contract: the generated list is owned by '
              'the generator — regeneration replaces its content');
      expect(written.items.map((i) => i.name), containsAll(['mjöl', 'ägg']));
    });

    test(
        'BUT-1234: a RENAMED generated list is still found via its '
        'generatedForWeek marker and regenerated in place', () async {
      // Proves: lookup is by marker, not name. The user renaming
      // "Inköpslista v.24" to "veckans mat" must not cause a duplicate
      // marker-less "Inköpslista v.24" to spawn next regeneration.
      seedTwoRecipePlan();
      final renamed = _list(
        'renamed-1',
        'veckans mat', // user renamed it — nothing like the generated name
        generatedForWeek: _expectedWeekKey,
      );
      shoppingService.setShoppingState(
        lists: [renamed],
        personalLists: [renamed],
      );

      final result = await generator.generateForWeek(_date);

      expect(result, isNotNull,
          reason: 'regeneration must run against the renamed marked list');
      expect(result!.listId, 'renamed-1');
      expect(result.listName, 'veckans mat',
          reason: 'the snackbar must echo the name the user actually sees, '
              'not the default generated name');
      verifyNever(() => shoppingService.createPersonalList(any(),
          items: any(named: 'items')));
      expect(capturedUpdate().id, 'renamed-1');
    });

    test(
        'BUT-1234: a user list coincidentally named "Inköpslista v.NN" but '
        'WITHOUT the marker is never touched — a new marked list is created '
        'alongside it', () async {
      // Proves: name collision alone does not make a list the generator's
      // target. The user's own list (and its items) must survive untouched;
      // the duplicate name is the documented acceptable cost.
      seedTwoRecipePlan();
      final userList = _list(
        'user-list-1',
        _expectedListName, // same name, no generatedForWeek marker
        items: [
          UnifiedShoppingItem(name: 'användarens vara', amount: 1, unit: 'st'),
        ],
      );
      shoppingService.setShoppingState(
        lists: [userList],
        personalLists: [userList],
      );
      when(() => shoppingService.createPersonalList(any(),
          items: any(named: 'items'))).thenAnswer((_) async {
        shoppingService.setShoppingState(
          lists: [userList, _list('new-list-1', _expectedListName)],
          personalLists: [userList, _list('new-list-1', _expectedListName)],
        );
        return 'new-list-1';
      });

      final result = await generator.generateForWeek(_date);

      expect(result, isNotNull,
          reason: 'an unmarked name-collision must not abort generation');
      expect(result!.listId, 'new-list-1',
          reason: 'generation must target a NEW list, not the user\'s');
      verify(() => shoppingService.createPersonalList(_expectedListName,
          items: any(named: 'items'))).called(1);

      final written = capturedUpdate();
      expect(written.id, 'new-list-1',
          reason: 'the only write must hit the new list — the user\'s '
              'identically named list stays untouched');
      expect(written.generatedForWeek, _expectedWeekKey);
    });

    test(
        'BUT-1234: a list marked for a DIFFERENT week is never hijacked — '
        'generating a new week creates a new list', () async {
      // Proves: lookup matches the marker VALUE, not mere marker presence.
      // A regression to "find any generated list" would overwrite last
      // week's list every time a new week is generated.
      seedTwoRecipePlan();
      final lastWeek = _list(
        'last-week-1',
        'Inköpslista v.23',
        generatedForWeek: '2026-W23',
        items: [
          UnifiedShoppingItem(
              name: 'förra veckans vara', amount: 1, unit: 'st'),
        ],
      );
      shoppingService.setShoppingState(
        lists: [lastWeek],
        personalLists: [lastWeek],
      );
      when(() => shoppingService.createPersonalList(any(),
          items: any(named: 'items'))).thenAnswer((_) async {
        shoppingService.setShoppingState(
          lists: [lastWeek, _list('new-list-1', _expectedListName)],
          personalLists: [lastWeek, _list('new-list-1', _expectedListName)],
        );
        return 'new-list-1';
      });

      final result = await generator.generateForWeek(_date);

      expect(result, isNotNull);
      expect(result!.listId, 'new-list-1',
          reason: 'a marker for another week must not make a list the '
              'generation target');
      verify(() => shoppingService.createPersonalList(_expectedListName,
          items: any(named: 'items'))).called(1);

      final written = capturedUpdate();
      expect(written.id, 'new-list-1',
          reason: 'the only write must hit the new list — last week\'s '
              'list must receive no write');
      expect(written.generatedForWeek, _expectedWeekKey);
    });

    test(
        'bought-status survives regeneration by name+unit; new lines '
        'default to not bought', () async {
      // Proves: ticking off "mjöl" in the store, then regenerating the week,
      // does not resurrect it as unbought — while genuinely new lines start
      // unbought.
      seedTwoRecipePlan();
      final existing = _list(
        'existing-1',
        _expectedListName,
        generatedForWeek: _expectedWeekKey,
        items: [
          UnifiedShoppingItem(
              name: 'mjöl', amount: 2, unit: 'dl', bought: true),
        ],
      );
      shoppingService.setShoppingState(
        lists: [existing],
        personalLists: [existing],
      );

      final result = await generator.generateForWeek(_date);

      expect(result, isNotNull,
          reason: 'regeneration must reach the updateList write');
      final written = capturedUpdate();
      final byName = {for (final i in written.items) i.name: i};
      expect(byName['mjöl']!.bought, isTrue,
          reason: 'matching name+unit must carry the bought flag across '
              'regeneration');
      expect(byName['ägg']!.bought, isFalse,
          reason: 'a line absent from the previous list starts unbought');
    });

    test(
        'bought-status survives a display-casing/diacritic flip between '
        'runs (normalized key, not toLowerCase)', () async {
      // Proves: the bought key uses the SAME SwedishCharacterNormalizer as
      // the aggregation key. Display names keep first-seen casing, so last
      // week's list can say "Mjöl" while this week's recipes spell it
      // "mjol" — a plain toLowerCase key ('mjöl|dl' vs 'mjol|dl') would
      // silently reset bought-status in exactly the regeneration scenario
      // the preservation exists for.
      when(() => menuService.getWeek(any()))
          .thenAnswer((_) async => _plan(['r1']));
      recipeService.setRecipeState(
        recipes: [
          _recipe('r1', const [
            RecipeIngredient(
                amount: 2, unit: 'dl', name: 'mjol', raw: '2 dl mjol'),
          ]),
        ],
        isInitialized: true,
      );
      final existing = _list(
        'existing-1',
        _expectedListName,
        generatedForWeek: _expectedWeekKey,
        items: [
          UnifiedShoppingItem(
              name: 'Mjöl', amount: 2, unit: 'dl', bought: true),
        ],
      );
      shoppingService.setShoppingState(
        lists: [existing],
        personalLists: [existing],
      );
      when(() => shoppingService.updateList(any()))
          .thenAnswer((_) async => true);

      final result = await generator.generateForWeek(_date);

      expect(result, isNotNull,
          reason: 'regeneration must reach the updateList write');
      final written = capturedUpdate();
      expect(written.items.single.name, 'mjol',
          reason: 'sanity: this run\'s first-seen display casing wins');
      expect(written.items.single.bought, isTrue,
          reason: '"Mjöl" ticked off last run must stay ticked when the '
              'fresh aggregation spells it "mjol"');
    });

    test(
        'unresolved plan recipe: counted in the result, list still '
        'generated from the rest', () async {
      // Proves: a deleted/uncached recipe on the plan degrades honestly —
      // the list is built from what resolved, and the gap is surfaced so the
      // snackbar can tell the truth.
      when(() => menuService.getWeek(any()))
          .thenAnswer((_) async => _plan(['r1', 'r-deleted']));
      recipeService.setRecipeState(
        recipes: [
          _recipe('r1', const [
            RecipeIngredient(
                amount: 2, unit: 'dl', name: 'mjöl', raw: '2 dl mjöl'),
          ]),
        ],
        isInitialized: true,
      );
      shoppingService.setShoppingState(lists: [], personalLists: []);
      when(() => shoppingService.createPersonalList(any(),
          items: any(named: 'items'))).thenAnswer((_) async {
        shoppingService.setShoppingState(
          lists: [_list('new-list-1', _expectedListName)],
          personalLists: [_list('new-list-1', _expectedListName)],
        );
        return 'new-list-1';
      });
      when(() => shoppingService.updateList(any()))
          .thenAnswer((_) async => true);

      final result = await generator.generateForWeek(_date);

      expect(result, isNotNull,
          reason: 'one unresolved recipe must not abort generation');
      expect(result!.unresolvedRecipes, 1);
      expect(result.recipeCount, 1);

      final written = capturedUpdate();
      expect(written.items.map((i) => i.name), ['mjöl'],
          reason: 'list is generated from the recipes that DID resolve');
    });

    test(
        'empty plan: returns the nothingToGenerate sentinel and '
        'creates/writes nothing', () async {
      // Proves: an unplanned week is a quiet no-op — no empty "Inköpslista
      // v.NN" husk appears in the user's list collection — and the view can
      // tell "nothing planned" (sentinel) apart from "generation failed"
      // (null), which carry different user-facing messages.
      when(() => menuService.getWeek(any())).thenAnswer(
          (_) async => WeeklyMenuPlan.empty(userId: _testUserId, date: _date));
      shoppingService.setShoppingState(lists: [], personalLists: []);

      final result = await generator.generateForWeek(_date);

      expect(result, isNotNull,
          reason: 'an empty plan is NOT a failure — null is reserved for '
              'the error path');
      expect(result!.isEmptyPlan, isTrue);
      verifyNever(() => shoppingService.createPersonalList(any(),
          items: any(named: 'items')));
      verifyNever(() => shoppingService.updateList(any()));
    });

    test(
        'plan whose every recipe is unresolvable degrades to '
        'nothingToGenerate without touching any list', () async {
      // Proves: the second sentinel branch — entries exist but none resolve
      // (all deleted/uncached). Generating an empty husk list here would be
      // worse than doing nothing; failing (null) would show the wrong copy.
      when(() => menuService.getWeek(any()))
          .thenAnswer((_) async => _plan(['r-gone-1', 'r-gone-2']));
      recipeService.setRecipeState(recipes: [], isInitialized: true);
      shoppingService.setShoppingState(lists: [], personalLists: []);

      final result = await generator.generateForWeek(_date);

      expect(result, isNotNull,
          reason: 'unresolvable plan recipes must degrade, not fail');
      expect(result!.isEmptyPlan, isTrue);
      verifyNever(() => shoppingService.createPersonalList(any(),
          items: any(named: 'items')));
      verifyNever(() => shoppingService.updateList(any()));
    });

    test(
        'amount-less aggregated lines land with the manual-add default of 1, '
        'not a misleading 0', () async {
      // Proves the generator-owned mapping rule (`a.amount ?? 1`): a raw-only
      // line like "en nypa salt" must render like a manually added item
      // (amount 1), never "0 salt". This lives in the GENERATOR, not the
      // aggregator — the aggregator hands over amount == null.
      when(() => menuService.getWeek(any()))
          .thenAnswer((_) async => _plan(['r1']));
      recipeService.setRecipeState(
        recipes: [
          _recipe('r1', [RecipeIngredient.rawOnly('en nypa salt')]),
        ],
        isInitialized: true,
      );
      shoppingService.setShoppingState(lists: [], personalLists: []);
      when(() => shoppingService.createPersonalList(any(),
          items: any(named: 'items'))).thenAnswer((_) async {
        shoppingService.setShoppingState(
          lists: [_list('new-list-1', _expectedListName)],
          personalLists: [_list('new-list-1', _expectedListName)],
        );
        return 'new-list-1';
      });
      when(() => shoppingService.updateList(any()))
          .thenAnswer((_) async => true);

      final result = await generator.generateForWeek(_date);

      expect(result, isNotNull,
          reason: 'raw-only-ingredient weeks must still generate');
      final written = capturedUpdate();
      expect(written.items.single.amount, 1);
    });
  });
}
