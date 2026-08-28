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
import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/account/user_consent.dart';
import 'package:butlery/repositories/interfaces/analytics_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/services/account/consent_service.dart';
import 'package:butlery/services/analytics/trackers/shopping_events_tracker.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/services/pantry/pantry_service.dart';
import 'package:butlery/services/shopping/menu_shopping_list_generator.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/mock_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

class _MockWeeklyMenuPlanService extends Mock
    implements WeeklyMenuPlanService {}

class _MockPantryService extends Mock implements PantryService {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

class _MockAnalyticsRepository extends Mock implements AnalyticsRepository {}

class _MockConsentService extends Mock implements ConsentService {}

const _testUserId = 'test-user-123';

PantryItem _stapleItem(String name) => PantryItem(
  id: 'staple-$name',
  ingredientName: name,
  quantity: 1,
  unit: 'st',
  location: PantryLocation.pantry,
  addedAt: DateTime(2026, 6, 8),
  isStaple: true,
);

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

// BUT-1613: explicit-entry plan builder so tests can place the SAME recipe at
// two (day, slot) cells and attach per-slot presence — the two things the
// presence-scaling contract turns on.
WeeklyMenuPlanEntry _entry(String recipeId, DayOfWeek day, MealSlot slot) =>
    WeeklyMenuPlanEntry(
      id: 'e-${day.name}-${slot.name}-$recipeId',
      day: day,
      slot: slot,
      recipeId: recipeId,
      recipeTitle: recipeId,
    );

WeeklyMenuPlan _planWith(
  List<WeeklyMenuPlanEntry> entries, {
  Map<DayOfWeek, Map<MealSlot, List<String>>> presenceBySlot = const {},
}) => WeeklyMenuPlan(
  id: 'plan-1',
  userId: _testUserId,
  weekStartDate: IsoWeekUtils.weekStartOf(_date),
  entries: entries,
  createdAt: DateTime(2026, 6, 8),
  updatedAt: DateTime(2026, 6, 8),
  presenceBySlot: presenceBySlot,
);

// BUT-1613: recipe carrying an authored serving count, the denominator of the
// presence factor. `portions: null` models a recipe that can't form a ratio.
Recipe _recipeWithPortions(
  String id,
  int? portions,
  List<RecipeIngredient> entries,
) => Recipe(
  core: RecipeCore(
    id: id,
    title: id,
    description: '',
    ingredients: entries.map((e) => e.raw).toList(),
    structuredIngredients: entries,
    instructions: const ['x'],
    mealType: 'Middag',
    portions: portions,
  ),
  type: RecipeType.personal,
);

UnifiedShoppingList _list(
  String id,
  String name, {
  List<UnifiedShoppingItem> items = const [],
  String? generatedForWeek,
}) => UnifiedShoppingList(
  id: id,
  name: name,
  ownerId: _testUserId,
  ownerDisplayName: 'Test',
  items: items,
  generatedForWeek: generatedForWeek,
);

WeeklyMenuPlanRead _read(WeeklyMenuPlan plan) =>
    WeeklyMenuPlanRead(plan: plan, readFailed: false);

void main() {
  late _MockWeeklyMenuPlanService menuService;
  late MockUnifiedRecipeService recipeService;
  late MockUnifiedShoppingService shoppingService;
  late _MockPantryService pantryService;
  late MenuShoppingListGenerator generator;

  /// BUT-1681: every analytics event the generation emitted, as
  /// (name, parameters). The count is as load-bearing as the content — the
  /// reverted first attempt fired one per generated line.
  late List<(String, Map<String, Object>?)> loggedEvents;

  setUpAll(() {
    production.ServiceLocator.initialize(DIContainer());
    registerFallbackValue(ConsentPurpose.analytics);
    registerFallbackValue(
      UnifiedShoppingList(
        name: 'fallback',
        ownerId: 'x',
        ownerDisplayName: 'x',
      ),
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
        isAuthenticated: true,
        userId: _testUserId,
      ),
    );

    menuService = _MockWeeklyMenuPlanService();
    recipeService = MockUnifiedRecipeService();
    shoppingService = MockUnifiedShoppingService();
    pantryService = _MockPantryService();
    // BUT-1279: default to no staples so the existing generation contracts are
    // unaffected; the staple-exclusion test overrides this.
    when(() => pantryService.getAll(any())).thenAnswer((_) async => const []);
    TestServiceLocator.registerMock<WeeklyMenuPlanService>(menuService);
    TestServiceLocator.registerMock<UnifiedRecipeService>(recipeService);
    TestServiceLocator.registerMock<UnifiedShoppingService>(shoppingService);
    TestServiceLocator.registerMock<PantryService>(pantryService);

    // BUT-1681: a real ShoppingEventsTracker over a mock repository, so the
    // assertions read the parameters production would actually send. Consent
    // must be granted explicitly — BaseTracker fails closed without it.
    loggedEvents = [];
    final analyticsRepo = _MockAnalyticsRepository();
    when(
      () => analyticsRepo.logEvent(
        name: any(named: 'name'),
        parameters: any(named: 'parameters'),
      ),
    ).thenAnswer((invocation) async {
      loggedEvents.add((
        invocation.namedArguments[#name] as String,
        invocation.namedArguments[#parameters] as Map<String, Object>?,
      ));
    });
    final consent = _MockConsentService();
    when(() => consent.hasConsent(any())).thenAnswer((_) async => true);
    final tracker = ShoppingEventsTracker(repository: analyticsRepo)
      ..setConsentService(consent);
    final analytics = _MockAnalyticsService();
    when(() => analytics.shopping).thenReturn(tracker);
    TestServiceLocator.registerMock<AnalyticsService>(analytics);

    generator = MenuShoppingListGenerator();
  });

  tearDown(() async {
    BaseUnitTest.resetMocks();
    await TestServiceLocator.reset();
  });

  // Two recipes sharing mjöl (dl) so the generated items prove the RESOLVED
  // recipes reached the aggregator (3 dl summed), plus ägg as a second line.
  void seedTwoRecipePlan() {
    when(
      () => menuService.readWeek(any()),
    ).thenAnswer((_) async => _read(_plan(['r1', 'r2'])));
    recipeService.setRecipeState(
      recipes: [
        _recipe('r1', const [
          RecipeIngredient(
            amount: 2,
            unit: 'dl',
            name: 'mjöl',
            raw: '2 dl mjöl',
          ),
        ]),
        _recipe('r2', const [
          RecipeIngredient(
            amount: 1,
            unit: 'dl',
            name: 'mjöl',
            raw: '1 dl mjöl',
          ),
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

  // BUT-1613 harness: empty list collection → create → update, so a fresh
  // week generates into "new-list-1". Presence-scaling tests only care about
  // the WRITTEN items, so this hides the create/update plumbing.
  void seedFreshListCreation() {
    shoppingService.setShoppingState(lists: [], personalLists: []);
    when(
      () => shoppingService.createPersonalList(
        any(),
        items: any(named: 'items'),
      ),
    ).thenAnswer((_) async {
      shoppingService.setShoppingState(
        lists: [_list('new-list-1', _expectedListName)],
        personalLists: [_list('new-list-1', _expectedListName)],
      );
      return 'new-list-1';
    });
    when(() => shoppingService.updateList(any())).thenAnswer((_) async => true);
  }

  Map<String, UnifiedShoppingItem> writtenByName() => {
    for (final i in capturedUpdate().items) i.name: i,
  };

  group('MenuShoppingListGenerator (BUT-956)', () {
    test('absent week list: creates "Inköpslista v.NN" and writes the '
        'aggregated items into it', () async {
      // Proves: first generation of a week creates the named list and the
      // items the user sees are the cross-recipe aggregation.
      seedTwoRecipePlan();
      shoppingService.setShoppingState(lists: [], personalLists: []);
      when(
        () => shoppingService.createPersonalList(
          any(),
          items: any(named: 'items'),
        ),
      ).thenAnswer((_) async {
        // Mirror production: after creation the service's list cache holds
        // the new (empty) list, which the generator re-reads to update.
        shoppingService.setShoppingState(
          lists: [_list('new-list-1', _expectedListName)],
          personalLists: [_list('new-list-1', _expectedListName)],
        );
        return 'new-list-1';
      });

      final result = await generator.generateForWeek(_date);

      expect(
        result,
        isNotNull,
        reason:
            'generation must run — a null here usually means the '
            'auth pre-flight silently short-circuited',
      );
      expect(result!.listId, 'new-list-1');
      expect(result.listName, _expectedListName);
      expect(result.recipeCount, 2);
      expect(result.unresolvedRecipes, 0);

      verify(
        () => shoppingService.createPersonalList(
          _expectedListName,
          items: any(named: 'items'),
        ),
      ).called(1);

      final written = capturedUpdate();
      expect(written.id, 'new-list-1');
      expect(
        written.generatedForWeek,
        _expectedWeekKey,
        reason:
            'BUT-1234: a freshly created week list must carry the '
            'generatedForWeek marker so the next regeneration finds it '
            'even if the user renames it',
      );
      final byName = {for (final i in written.items) i.name: i};
      expect(byName.keys, containsAll(['mjöl', 'ägg']));
      expect(
        byName['mjöl']!.amount,
        3,
        reason: '2 dl + 1 dl across the two plan recipes must arrive summed',
      );
      expect(byName['mjöl']!.unit, 'dl');
      expect(byName['ägg']!.amount, 3);
      expect(result.itemCount, written.items.length);
    });

    test('idempotent regeneration: existing week list is updated in place, '
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

      expect(
        result,
        isNotNull,
        reason: 'regeneration must run against the existing list',
      );
      expect(result!.listId, 'existing-1');
      verifyNever(
        () => shoppingService.createPersonalList(
          any(),
          items: any(named: 'items'),
        ),
      );

      final written = capturedUpdate();
      expect(written.id, 'existing-1');
      expect(
        written.items.map((i) => i.name),
        isNot(contains('gammal vara')),
        reason:
            'documented V1 contract: the generated list is owned by '
            'the generator — regeneration replaces its content',
      );
      expect(written.items.map((i) => i.name), containsAll(['mjöl', 'ägg']));
    });

    test('BUT-1234: a RENAMED generated list is still found via its '
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

      expect(
        result,
        isNotNull,
        reason: 'regeneration must run against the renamed marked list',
      );
      expect(result!.listId, 'renamed-1');
      expect(
        result.listName,
        'veckans mat',
        reason:
            'the snackbar must echo the name the user actually sees, '
            'not the default generated name',
      );
      verifyNever(
        () => shoppingService.createPersonalList(
          any(),
          items: any(named: 'items'),
        ),
      );
      expect(capturedUpdate().id, 'renamed-1');
    });

    test('BUT-1234: a user list coincidentally named "Inköpslista v.NN" but '
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
      when(
        () => shoppingService.createPersonalList(
          any(),
          items: any(named: 'items'),
        ),
      ).thenAnswer((_) async {
        shoppingService.setShoppingState(
          lists: [userList, _list('new-list-1', _expectedListName)],
          personalLists: [userList, _list('new-list-1', _expectedListName)],
        );
        return 'new-list-1';
      });

      final result = await generator.generateForWeek(_date);

      expect(
        result,
        isNotNull,
        reason: 'an unmarked name-collision must not abort generation',
      );
      expect(
        result!.listId,
        'new-list-1',
        reason: 'generation must target a NEW list, not the user\'s',
      );
      verify(
        () => shoppingService.createPersonalList(
          _expectedListName,
          items: any(named: 'items'),
        ),
      ).called(1);

      final written = capturedUpdate();
      expect(
        written.id,
        'new-list-1',
        reason:
            'the only write must hit the new list — the user\'s '
            'identically named list stays untouched',
      );
      expect(written.generatedForWeek, _expectedWeekKey);
    });

    test('BUT-1234: a list marked for a DIFFERENT week is never hijacked — '
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
            name: 'förra veckans vara',
            amount: 1,
            unit: 'st',
          ),
        ],
      );
      shoppingService.setShoppingState(
        lists: [lastWeek],
        personalLists: [lastWeek],
      );
      when(
        () => shoppingService.createPersonalList(
          any(),
          items: any(named: 'items'),
        ),
      ).thenAnswer((_) async {
        shoppingService.setShoppingState(
          lists: [lastWeek, _list('new-list-1', _expectedListName)],
          personalLists: [lastWeek, _list('new-list-1', _expectedListName)],
        );
        return 'new-list-1';
      });

      final result = await generator.generateForWeek(_date);

      expect(result, isNotNull);
      expect(
        result!.listId,
        'new-list-1',
        reason:
            'a marker for another week must not make a list the '
            'generation target',
      );
      verify(
        () => shoppingService.createPersonalList(
          _expectedListName,
          items: any(named: 'items'),
        ),
      ).called(1);

      final written = capturedUpdate();
      expect(
        written.id,
        'new-list-1',
        reason:
            'the only write must hit the new list — last week\'s '
            'list must receive no write',
      );
      expect(written.generatedForWeek, _expectedWeekKey);
    });

    test('bought-status survives regeneration by name+unit; new lines '
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
            name: 'mjöl',
            amount: 2,
            unit: 'dl',
            bought: true,
          ),
        ],
      );
      shoppingService.setShoppingState(
        lists: [existing],
        personalLists: [existing],
      );

      final result = await generator.generateForWeek(_date);

      expect(
        result,
        isNotNull,
        reason: 'regeneration must reach the updateList write',
      );
      final written = capturedUpdate();
      final byName = {for (final i in written.items) i.name: i};
      expect(
        byName['mjöl']!.bought,
        isTrue,
        reason:
            'matching name+unit must carry the bought flag across '
            'regeneration',
      );
      expect(
        byName['ägg']!.bought,
        isFalse,
        reason: 'a line absent from the previous list starts unbought',
      );
    });

    test('bought-status survives a display-casing/diacritic flip between '
        'runs (normalized key, not toLowerCase)', () async {
      // Proves: the bought key uses the SAME SwedishCharacterNormalizer as
      // the aggregation key. Display names keep first-seen casing, so last
      // week's list can say "Mjöl" while this week's recipes spell it
      // "mjol" — a plain toLowerCase key ('mjöl|dl' vs 'mjol|dl') would
      // silently reset bought-status in exactly the regeneration scenario
      // the preservation exists for.
      when(
        () => menuService.readWeek(any()),
      ).thenAnswer((_) async => _read(_plan(['r1'])));
      recipeService.setRecipeState(
        recipes: [
          _recipe('r1', const [
            RecipeIngredient(
              amount: 2,
              unit: 'dl',
              name: 'mjol',
              raw: '2 dl mjol',
            ),
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
            name: 'Mjöl',
            amount: 2,
            unit: 'dl',
            bought: true,
          ),
        ],
      );
      shoppingService.setShoppingState(
        lists: [existing],
        personalLists: [existing],
      );
      when(
        () => shoppingService.updateList(any()),
      ).thenAnswer((_) async => true);

      final result = await generator.generateForWeek(_date);

      expect(
        result,
        isNotNull,
        reason: 'regeneration must reach the updateList write',
      );
      final written = capturedUpdate();
      expect(
        written.items.single.name,
        'mjol',
        reason: 'sanity: this run\'s first-seen display casing wins',
      );
      expect(
        written.items.single.bought,
        isTrue,
        reason:
            '"Mjöl" ticked off last run must stay ticked when the '
            'fresh aggregation spells it "mjol"',
      );
    });

    test('unresolved plan recipe: counted in the result, list still '
        'generated from the rest', () async {
      // Proves: a deleted/uncached recipe on the plan degrades honestly —
      // the list is built from what resolved, and the gap is surfaced so the
      // snackbar can tell the truth.
      when(
        () => menuService.readWeek(any()),
      ).thenAnswer((_) async => _read(_plan(['r1', 'r-deleted'])));
      recipeService.setRecipeState(
        recipes: [
          _recipe('r1', const [
            RecipeIngredient(
              amount: 2,
              unit: 'dl',
              name: 'mjöl',
              raw: '2 dl mjöl',
            ),
          ]),
        ],
        isInitialized: true,
      );
      shoppingService.setShoppingState(lists: [], personalLists: []);
      when(
        () => shoppingService.createPersonalList(
          any(),
          items: any(named: 'items'),
        ),
      ).thenAnswer((_) async {
        shoppingService.setShoppingState(
          lists: [_list('new-list-1', _expectedListName)],
          personalLists: [_list('new-list-1', _expectedListName)],
        );
        return 'new-list-1';
      });
      when(
        () => shoppingService.updateList(any()),
      ).thenAnswer((_) async => true);

      final result = await generator.generateForWeek(_date);

      expect(
        result,
        isNotNull,
        reason: 'one unresolved recipe must not abort generation',
      );
      expect(result!.unresolvedRecipes, 1);
      expect(result.recipeCount, 1);

      final written = capturedUpdate();
      expect(
        written.items.map((i) => i.name),
        ['mjöl'],
        reason: 'list is generated from the recipes that DID resolve',
      );
    });

    test('empty plan: returns the nothingToGenerate sentinel and '
        'creates/writes nothing', () async {
      // Proves: an unplanned week is a quiet no-op — no empty "Inköpslista
      // v.NN" husk appears in the user's list collection — and the view can
      // tell "nothing planned" (sentinel) apart from "generation failed"
      // (null), which carry different user-facing messages.
      when(() => menuService.readWeek(any())).thenAnswer(
        (_) async =>
            _read(WeeklyMenuPlan.empty(userId: _testUserId, date: _date)),
      );
      shoppingService.setShoppingState(lists: [], personalLists: []);

      final result = await generator.generateForWeek(_date);

      expect(
        result,
        isNotNull,
        reason:
            'an empty plan is NOT a failure — null is reserved for '
            'the error path',
      );
      expect(result!.isEmptyPlan, isTrue);
      verifyNever(
        () => shoppingService.createPersonalList(
          any(),
          items: any(named: 'items'),
        ),
      );
      verifyNever(() => shoppingService.updateList(any()));
    });

    test('FAILED read: returns null, never the nothingToGenerate sentinel '
        '(BUT-1962)', () async {
      // The pair that matters is this test and the one directly above it: same
      // stubs, same empty-looking week, and the ONLY difference is whether the
      // read answered. Before BUT-1962 both landed on the sentinel, so a week
      // the app never managed to read was reported to the user as "you have
      // nothing planned".
      when(() => menuService.readWeek(any())).thenAnswer(
        (_) async => WeeklyMenuPlanRead(
          plan: WeeklyMenuPlan.empty(userId: _testUserId, date: _date),
          readFailed: true,
        ),
      );
      shoppingService.setShoppingState(lists: [], personalLists: []);

      final result = await generator.generateForWeek(_date);

      expect(
        result,
        isNull,
        reason:
            'null is the failure channel the view renders as '
            '"Kunde inte skapa inköpslistan"',
      );
      verifyNever(
        () => shoppingService.createPersonalList(
          any(),
          items: any(named: 'items'),
        ),
      );
      verifyNever(() => shoppingService.updateList(any()));
    });

    test('plan whose every recipe is unresolvable degrades to '
        'nothingToGenerate without touching any list', () async {
      // Proves: the second sentinel branch — entries exist but none resolve
      // (all deleted/uncached). Generating an empty husk list here would be
      // worse than doing nothing; failing (null) would show the wrong copy.
      when(
        () => menuService.readWeek(any()),
      ).thenAnswer((_) async => _read(_plan(['r-gone-1', 'r-gone-2'])));
      recipeService.setRecipeState(recipes: [], isInitialized: true);
      shoppingService.setShoppingState(lists: [], personalLists: []);

      final result = await generator.generateForWeek(_date);

      expect(
        result,
        isNotNull,
        reason: 'unresolvable plan recipes must degrade, not fail',
      );
      expect(result!.isEmptyPlan, isTrue);
      verifyNever(
        () => shoppingService.createPersonalList(
          any(),
          items: any(named: 'items'),
        ),
      );
      verifyNever(() => shoppingService.updateList(any()));
    });

    test('amount-less aggregated lines land with the manual-add default of 1, '
        'not a misleading 0', () async {
      // Proves the generator-owned mapping rule (`a.amount ?? 1`): a raw-only
      // line like "en nypa salt" must render like a manually added item
      // (amount 1), never "0 salt". This lives in the GENERATOR, not the
      // aggregator — the aggregator hands over amount == null.
      when(
        () => menuService.readWeek(any()),
      ).thenAnswer((_) async => _read(_plan(['r1'])));
      recipeService.setRecipeState(
        recipes: [
          _recipe('r1', [RecipeIngredient.rawOnly('en nypa salt')]),
        ],
        isInitialized: true,
      );
      shoppingService.setShoppingState(lists: [], personalLists: []);
      when(
        () => shoppingService.createPersonalList(
          any(),
          items: any(named: 'items'),
        ),
      ).thenAnswer((_) async {
        shoppingService.setShoppingState(
          lists: [_list('new-list-1', _expectedListName)],
          personalLists: [_list('new-list-1', _expectedListName)],
        );
        return 'new-list-1';
      });
      when(
        () => shoppingService.updateList(any()),
      ).thenAnswer((_) async => true);

      final result = await generator.generateForWeek(_date);

      expect(
        result,
        isNotNull,
        reason: 'raw-only-ingredient weeks must still generate',
      );
      final written = capturedUpdate();
      expect(written.items.single.amount, 1);
    });

    test('BUT-1279: pantry staples are dropped from the generated list and '
        'counted in excludedStaples', () async {
      // Proves: an ingredient the user marked as a pantry staple (salt) never
      // lands on the generated shopping list, while non-staples (mjöl) do —
      // and the omission is reported so the UI can explain it.
      when(
        () => menuService.readWeek(any()),
      ).thenAnswer((_) async => _read(_plan(['r1'])));
      recipeService.setRecipeState(
        recipes: [
          _recipe('r1', const [
            RecipeIngredient(amount: 1, unit: 'tsk', name: 'salt', raw: 'salt'),
            RecipeIngredient(
              amount: 2,
              unit: 'dl',
              name: 'mjöl',
              raw: '2 dl mjöl',
            ),
          ]),
        ],
        isInitialized: true,
      );
      when(
        () => pantryService.getAll(_testUserId),
      ).thenAnswer((_) async => [_stapleItem('Salt')]);
      shoppingService.setShoppingState(lists: [], personalLists: []);
      when(
        () => shoppingService.createPersonalList(
          any(),
          items: any(named: 'items'),
        ),
      ).thenAnswer((_) async {
        shoppingService.setShoppingState(
          lists: [_list('new-list-1', _expectedListName)],
          personalLists: [_list('new-list-1', _expectedListName)],
        );
        return 'new-list-1';
      });
      when(
        () => shoppingService.updateList(any()),
      ).thenAnswer((_) async => true);

      final result = await generator.generateForWeek(_date);

      expect(
        result,
        isNotNull,
        reason: 'staple exclusion must not abort generation',
      );
      expect(
        result!.excludedStaples,
        1,
        reason: 'one staple line (salt) was kept off the list',
      );

      // BUT-1296: the staples must be read for THIS user, not some default or
      // empty id. An explicit-arg verify (not any()) catches a regression that
      // reads the wrong user's pantry — which would either leak another user's
      // staples or silently exclude nothing.
      verify(() => pantryService.getAll(_testUserId)).called(1);

      final written = capturedUpdate();
      expect(
        written.items.map((i) => i.name),
        ['mjöl'],
        reason: 'salt is a staple and must be excluded; mjöl remains',
      );
    });

    test('BUT-1279: a failing/absent pantry never blocks generation — list is '
        'built with no exclusions', () async {
      // Proves the defensive degrade: if the pantry read throws, the list is
      // still generated (every ingredient present, nothing excluded).
      when(
        () => menuService.readWeek(any()),
      ).thenAnswer((_) async => _read(_plan(['r1'])));
      recipeService.setRecipeState(
        recipes: [
          _recipe('r1', const [
            RecipeIngredient(amount: 1, unit: 'tsk', name: 'salt', raw: 'salt'),
          ]),
        ],
        isInitialized: true,
      );
      when(
        () => pantryService.getAll(any()),
      ).thenThrow(StateError('pantry unavailable'));
      shoppingService.setShoppingState(lists: [], personalLists: []);
      when(
        () => shoppingService.createPersonalList(
          any(),
          items: any(named: 'items'),
        ),
      ).thenAnswer((_) async {
        shoppingService.setShoppingState(
          lists: [_list('new-list-1', _expectedListName)],
          personalLists: [_list('new-list-1', _expectedListName)],
        );
        return 'new-list-1';
      });
      when(
        () => shoppingService.updateList(any()),
      ).thenAnswer((_) async => true);

      final result = await generator.generateForWeek(_date);

      expect(
        result,
        isNotNull,
        reason: 'a pantry read failure must not fail generation',
      );
      expect(result!.excludedStaples, 0);
      expect(
        capturedUpdate().items.map((i) => i.name),
        ['salt'],
        reason: 'with no staple data, every ingredient is kept',
      );
    });
  });

  group('MenuShoppingListGenerator presence scaling (BUT-1613)', () {
    test('the SAME recipe planned at TWO placements contributes its '
        'ingredients for BOTH (no week-level dedup)', () async {
      // Regression pin for the removal of the old `.toSet()` dedup: r1 sits at
      // Monday AND Tuesday middag. With portions null (no scaling — factor 1.0
      // both times) each placement adds its 2 dl mjöl, so the list must show
      // 4 dl — roughly double the single-placement 2 dl. A dedup regression
      // would collapse the two back to one line (2 dl) and under-buy.
      when(() => menuService.readWeek(any())).thenAnswer(
        (_) async => _read(
          _planWith([
            _entry('r1', DayOfWeek.mon, MealSlot.middag),
            _entry('r1', DayOfWeek.tue, MealSlot.middag),
          ]),
        ),
      );
      recipeService.setRecipeState(
        recipes: [
          _recipeWithPortions('r1', null, const [
            RecipeIngredient(
              amount: 2,
              unit: 'dl',
              name: 'mjöl',
              raw: '2 dl mjöl',
            ),
          ]),
        ],
        isInitialized: true,
      );
      seedFreshListCreation();

      final result = await generator.generateForWeek(_date);

      expect(
        result,
        isNotNull,
        reason: 'a repeated recipe must still generate',
      );
      expect(
        writtenByName()['mjöl']!.amount,
        4,
        reason: 'two Monday+Tuesday placements of 2 dl mjöl must buy 4 dl',
      );
      expect(
        result!.recipeCount,
        1,
        reason: 'recipeCount is DISTINCT recipes — r1 twice counts once',
      );
      expect(
        result.scaledMeals,
        0,
        reason: 'portions null → factor 1.0 both placements, nothing scaled',
      );
    });

    test('a meal with 3 members present scales a recipe authored for 6 down '
        'to half (factor 3/6)', () async {
      // Presence set for Monday middag = 3 diners; the recipe cooks for 6, so
      // the shopping amount is halved: 6 dl mjölk → 3 dl.
      when(() => menuService.readWeek(any())).thenAnswer(
        (_) async => _read(
          _planWith(
            [_entry('r1', DayOfWeek.mon, MealSlot.middag)],
            presenceBySlot: {
              DayOfWeek.mon: {
                MealSlot.middag: ['anna', 'björn', 'cecilia'],
              },
            },
          ),
        ),
      );
      recipeService.setRecipeState(
        recipes: [
          _recipeWithPortions('r1', 6, const [
            RecipeIngredient(
              amount: 6,
              unit: 'dl',
              name: 'mjölk',
              raw: '6 dl mjölk',
            ),
          ]),
        ],
        isInitialized: true,
      );
      seedFreshListCreation();

      final result = await generator.generateForWeek(_date);

      expect(result, isNotNull);
      expect(
        writtenByName()['mjölk']!.amount,
        3,
        reason: '3 present / 6 authored = 0.5 factor → 6 dl becomes 3 dl',
      );
      expect(
        result!.scaledMeals,
        1,
        reason: 'exactly one meal had a present-count ≠ its serving count',
      );
    });

    test('övrigt is EXEMPT from scaling even when presence-like data exists — '
        'snacks/baking stay whole-household', () async {
      // The BUT-1611→BUT-1625 exemption applied to quantities: an övrigt-slot
      // recipe is bought for the whole household regardless of who's home for
      // the day's meals. Even with a 2-person selection stored against övrigt,
      // the 6-portion recipe's 6 dl mjöl is NOT scaled to 2.
      when(() => menuService.readWeek(any())).thenAnswer(
        (_) async => _read(
          _planWith(
            [_entry('r1', DayOfWeek.mon, MealSlot.ovrigt)],
            presenceBySlot: {
              DayOfWeek.mon: {
                MealSlot.ovrigt: ['anna', 'björn'],
              },
            },
          ),
        ),
      );
      recipeService.setRecipeState(
        recipes: [
          _recipeWithPortions('r1', 6, const [
            RecipeIngredient(
              amount: 6,
              unit: 'dl',
              name: 'mjöl',
              raw: '6 dl mjöl',
            ),
          ]),
        ],
        isInitialized: true,
      );
      seedFreshListCreation();

      final result = await generator.generateForWeek(_date);

      expect(result, isNotNull);
      expect(
        writtenByName()['mjöl']!.amount,
        6,
        reason: 'övrigt is whole-household — 6 dl must stay 6 dl',
      );
      expect(
        result!.scaledMeals,
        0,
        reason: 'övrigt never scales, so no meal counts as scaled',
      );
    });

    test('null presence (no selection) and empty presence (nobody home) both '
        'buy the FULL authored amount — never scaled down', () async {
      // Both "everyone" (unset) and an explicitly-emptied slot fall back to the
      // recipe portions so the shopper never under-buys. Two runs, one plan
      // each, both must keep the authored 6 dl.
      Future<UnifiedShoppingList> runWith(
        Map<DayOfWeek, Map<MealSlot, List<String>>> presence,
      ) async {
        when(() => menuService.readWeek(any())).thenAnswer(
          (_) async => _read(
            _planWith(
              [_entry('r1', DayOfWeek.mon, MealSlot.middag)],
              presenceBySlot: presence,
            ),
          ),
        );
        recipeService.setRecipeState(
          recipes: [
            _recipeWithPortions('r1', 6, const [
              RecipeIngredient(
                amount: 6,
                unit: 'dl',
                name: 'mjölk',
                raw: '6 dl mjölk',
              ),
            ]),
          ],
          isInitialized: true,
        );
        seedFreshListCreation();
        final result = await generator.generateForWeek(_date);
        expect(result, isNotNull);
        expect(result!.scaledMeals, 0, reason: 'fallback keeps factor 1.0');
        return capturedUpdate();
      }

      // Null: no presenceBySlot at all.
      final nullPresence = await runWith(const {});
      expect(
        {for (final i in nullPresence.items) i.name: i}['mjölk']!.amount,
        6,
        reason: 'no selection = everyone → full 6 dl',
      );

      // Empty: slot explicitly emptied.
      BaseUnitTest.resetMocks();
      when(() => pantryService.getAll(any())).thenAnswer((_) async => const []);
      final emptyPresence = await runWith({
        DayOfWeek.mon: {MealSlot.middag: const []},
      });
      expect(
        {for (final i in emptyPresence.items) i.name: i}['mjölk']!.amount,
        6,
        reason: 'explicitly empty (nobody home) still buys the full 6 dl',
      );
    });

    test('a recipe with portions == null is left unscaled regardless of '
        'presence', () async {
      // Without an authored serving count there is no ratio to form, so the
      // meal is never scaled even with a 2-person present selection.
      when(() => menuService.readWeek(any())).thenAnswer(
        (_) async => _read(
          _planWith(
            [_entry('r1', DayOfWeek.mon, MealSlot.middag)],
            presenceBySlot: {
              DayOfWeek.mon: {
                MealSlot.middag: ['anna', 'björn'],
              },
            },
          ),
        ),
      );
      recipeService.setRecipeState(
        recipes: [
          _recipeWithPortions('r1', null, const [
            RecipeIngredient(
              amount: 4,
              unit: 'dl',
              name: 'mjölk',
              raw: '4 dl mjölk',
            ),
          ]),
        ],
        isInitialized: true,
      );
      seedFreshListCreation();

      final result = await generator.generateForWeek(_date);

      expect(result, isNotNull);
      expect(
        writtenByName()['mjölk']!.amount,
        4,
        reason: 'no authored portions → no ratio → unscaled 4 dl',
      );
      expect(result!.scaledMeals, 0);
    });

    test('recipeCount stays DISTINCT while scaledMeals counts only the '
        'placements whose factor ≠ 1.0', () async {
      // r1 sits at two placements: Monday middag is scaled (3 present / 6
      // authored = 0.5) while Tuesday middag has no presence (factor 1.0). r2
      // is a second distinct recipe, unscaled. So: 2 distinct recipes, exactly
      // 1 scaled meal — proving recipeCount and scaledMeals count different
      // things (recipes vs placements).
      when(() => menuService.readWeek(any())).thenAnswer(
        (_) async => _read(
          _planWith(
            [
              _entry('r1', DayOfWeek.mon, MealSlot.middag),
              _entry('r1', DayOfWeek.tue, MealSlot.middag),
              _entry('r2', DayOfWeek.wed, MealSlot.middag),
            ],
            presenceBySlot: {
              DayOfWeek.mon: {
                MealSlot.middag: ['anna', 'björn', 'cecilia'],
              },
            },
          ),
        ),
      );
      recipeService.setRecipeState(
        recipes: [
          _recipeWithPortions('r1', 6, const [
            RecipeIngredient(
              amount: 6,
              unit: 'dl',
              name: 'mjöl',
              raw: '6 dl mjöl',
            ),
          ]),
          _recipeWithPortions('r2', 4, const [
            RecipeIngredient(amount: 2, unit: 'st', name: 'ägg', raw: '2 ägg'),
          ]),
        ],
        isInitialized: true,
      );
      seedFreshListCreation();

      final result = await generator.generateForWeek(_date);

      expect(result, isNotNull);
      expect(
        result!.recipeCount,
        2,
        reason: 'r1 (×2 placements) + r2 = 2 DISTINCT recipes',
      );
      expect(
        result.scaledMeals,
        1,
        reason:
            'only Monday r1 has factor ≠ 1.0; Tuesday r1 and r2 are unscaled',
      );
      // r1 mjöl: Monday 6 dl × 0.5 = 3 dl + Tuesday 6 dl × 1.0 = 6 dl → 9 dl.
      expect(
        writtenByName()['mjöl']!.amount,
        9,
        reason: 'per-placement scale then sum: 3 dl + 6 dl = 9 dl',
      );
    });
  });

  // BUT-1681: the generated path was analytically silent (its first
  // implementation was reverted for firing one event per line). It now emits
  // exactly ONE event per genuine creation, tagged so a generated list is
  // distinguishable from a hand-made one.
  group('generation analytics (BUT-1681)', () {
    test(
      'a fresh week logs exactly one menu_generated creation event',
      () async {
        seedTwoRecipePlan();
        seedFreshListCreation();

        final result = await generator.generateForWeek(_date);
        // Analytics is fire-and-forget (it must never delay the user's list),
        // so let the consent check + logEvent chain settle before asserting.
        await Future<void>.delayed(Duration.zero);

        expect(result, isNotNull, reason: 'generation must run');
        expect(
          loggedEvents,
          hasLength(1),
          reason:
              'one summary event per generation — per-line events cost 30-40x '
              'as much and inflate the funnel they exist to measure',
        );
        final (name, params) = loggedEvents.single;
        expect(name, 'shopping_list_created');
        expect(params!['source'], 'menu_generated');
        expect(params['list_type'], 'personal');
        expect(
          params['initial_item_count'],
          2,
          reason: 'the row count is what the per-line events used to carry',
        );
      },
    );

    test('regenerating an existing week logs nothing', () async {
      seedTwoRecipePlan();
      // The week already has its marked list, so nothing is created.
      final existing = _list(
        'week-list',
        _expectedListName,
        generatedForWeek: _expectedWeekKey,
      );
      shoppingService.setShoppingState(
        lists: [existing],
        personalLists: [existing],
      );

      final result = await generator.generateForWeek(_date);
      await Future<void>.delayed(Duration.zero);

      expect(result, isNotNull, reason: 'regeneration must run');
      expect(
        loggedEvents,
        isEmpty,
        reason:
            'weekly regeneration is not a new list — counting it would '
            'inflate list-creation week over week',
      );
    });
  });
}
