/// P8-U04: hosts for the key screens that are not among the 53 rows.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' show find;
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/seasonal/seasonal_month.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/services/offline/queued_change.dart';
import 'package:butlery/services/pantry/pantry_service.dart';
import 'package:butlery/services/persistence_service.dart';
import 'package:butlery/services/search_service.dart';
import 'package:butlery/services/seasonal/seasonal_hero_service.dart';
import 'package:butlery/services/tagging/personal_tag_service.dart';
import 'package:butlery/services/tagging/tag_editing_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/viewmodels/personal_tag_viewmodel.dart';
import 'package:butlery/viewmodels/recipe_list_viewmodel.dart';
import 'package:butlery/viewmodels/shared_content/shared_content_coordinator_viewmodel.dart';
import 'package:butlery/views/mina_recept_view.dart';
import 'package:butlery/views/more/more_view.dart';
import 'package:butlery/views/sync/sync_queue_view.dart';

import '../../infrastructure/builders/recipe_builder.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/mock_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/mocks/service_mocks.dart' show MockSearchService;
import '../../infrastructure/mocks/widget_mocks.dart';
import '../design_states/state_harness.dart';
import '../design_states/state_host.dart';

/// Mer, with a fixed avatar (MoreView.avatar is replaceable for this,
/// lib/views/more/more_view.dart:32-34) and two changes waiting.
final StateHost moreHost = StateHost(
  build: (ctx) async {
    ctx.env.queue.set(_changes());
    return const MoreView(avatar: SizedBox.square(dimension: 40));
  },
);

/// Väntar på synk with one change draining and one that needs the user.
final StateHost syncQueueHost = StateHost(
  build: (ctx) async {
    ctx.env.queue.set(_changes());
    return SyncQueueView(backTo: sv.moreTitle);
  },
);

/// Mina recept itself: the real [MinaReceptView] over a library of four
/// recipes, shown as a grid.
///
/// The view builds its own RecipeListViewModel, RecipeQueryViewModel and
/// HemViewModel from the locator, so the fakes sit at the service edge
/// (recipes, week plan, pantry, search, persistence) and the view models are
/// the real ones. FriendsViewModel and the shared-content coordinator are the
/// shared mocks.
///
/// No friend group is registered and there is no cooking-session module, so
/// the presence bar and "X lagar just nu" stay hidden, as for a user without
/// a household: both read live streams that a fixed picture cannot hold.
final StateHost minaReceptHost = StateHost(
  build: (ctx) async {
    final recipeService = MockUnifiedRecipeService()
      ..setRecipeState(
        recipes: _library(),
        isInitialized: true,
        currentUserId: _me,
        currentUserDisplayName: 'Malin',
      );
    when(recipeService.initialize).thenAnswer((_) async {});
    TestServiceLocator.registerMock<UnifiedRecipeService>(recipeService);

    // Order is kept as given, so the picture does not depend on a sort.
    registerFallbackValue(SortCriteria.title);
    final search = MockSearchService();
    when(
      () => search.sortRecipes(
        any(),
        any(),
        ascending: any(named: 'ascending'),
      ),
    ).thenAnswer((i) => i.positionalArguments[0] as List<Recipe>);
    TestServiceLocator.registerMock<SearchService>(search);

    // The real view model over the fakes above. A factory, because the view
    // disposes the one it takes.
    TestServiceLocator.registerFactory<RecipeListViewModel>(
      () => RecipeListViewModel(
        recipeService: recipeService,
        searchService: search,
        tagEditingService: TagEditingService(),
      ),
    );

    TestServiceLocator.registerMock<PersistenceService>(_GridPersistence());
    TestServiceLocator.registerMock<UserService>(_SignedInUser());

    TestServiceLocator.registerMock<FriendsViewModel>(MockFriendsViewModel());
    TestServiceLocator.registerMock<SharedContentCoordinatorViewModel>(
      MockFactory.createSharedContentCoordinatorViewModel(),
    );

    final tags = MockPersonalTagService();
    // Without these the view model's load fails and retries on a timer.
    when(tags.getAllTags).thenAnswer((_) async => []);
    when(tags.getAllGroups).thenAnswer((_) async => []);
    when(tags.watchTagsWithGroups).thenAnswer((_) => const Stream.empty());
    TestServiceLocator.registerMock<PersonalTagService>(tags);
    TestServiceLocator.registerMock<PersonalTagViewModel>(
      PersonalTagViewModel(service: tags),
    );

    // No curated month: the seasonal banner stays out of the column.
    TestServiceLocator.registerMock<SeasonalHeroService>(
      SeasonalHeroService()..debugInjectMonths(const <int, SeasonalMonth>{}),
    );

    // HemViewModel.fromServices reads these for tonight's dish.
    final plan = _MockWeeklyMenuPlanService();
    when(() => plan.readWeek(any())).thenAnswer(
      (_) async => WeeklyMenuPlanRead(plan: _tonight(), readFailed: false),
    );
    TestServiceLocator.registerMock<WeeklyMenuPlanService>(plan);
    final pantry = _MockPantryService();
    when(() => pantry.getAll(any())).thenAnswer((_) async => const []);
    TestServiceLocator.registerMock<PantryService>(pantry);

    return const MinaReceptView();
  },
  // The view loads its social data after 1.5 s (_safeLoadSocialData); the
  // runner's own pump is shorter, so let that timer fire inside the test.
  reach: (tester, ctx) async {
    await tester.pump(const Duration(milliseconds: 1600));
    // An asset decodes outside fake time, so a placeholder illustration no
    // earlier screen in the run has shown would draw blank.
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        await precacheImage((element.widget as Image).image, element);
      }
    });
    await tester.pump();
  },
);

const _me = 'test-user-123';

class _SignedInUser extends MockUserService {
  _SignedInUser() {
    when(() => addListener(any())).thenReturn(null);
    when(() => removeListener(any())).thenReturn(null);
  }

  @override
  UserAllergenPreferences get allergenPreferences =>
      UserAllergenPreferences.defaults;

  @override
  String? get currentUserId => _me;
}

/// The grid is the stored display preference, which the view model reads.
class _GridPersistence extends PersistenceService {
  @override
  Future<bool> getIsGridView() async => true;
}

class _MockWeeklyMenuPlanService extends Mock
    implements WeeklyMenuPlanService {}

class _MockPantryService extends Mock implements PantryService {}

WeeklyMenuPlan _tonight() =>
    WeeklyMenuPlan.empty(userId: _me, date: goldenNow).copyWith(
      entries: [
        WeeklyMenuPlanEntry.create(
          day: DayOfWeek.thu,
          slot: MealSlot.middag,
          recipeId: 'r1',
          recipeTitle: 'Krämig svamppasta med timjan',
        ),
      ],
    );

/// Dates are relative to [goldenNow], never to the real clock. Every recipe
/// was cooked within the last 60 days, so neither discovery shelf (never
/// cooked for 60 days, favourites not cooked for 90) has anything to show:
/// with a shelf in the column the library body overflows on the 360 x 800
/// surface and the grid is pushed out of sight.
List<Recipe> _library() {
  Recipe recipe(
    String id,
    String title,
    int minutes,
    double rating,
    int cookedDaysAgo, {
    bool favourite = false,
    List<String> ingredients = const ['1 gul lök'],
  }) {
    final created = goldenNow.subtract(const Duration(days: 120));
    final r =
        (RecipeBuilder()
              ..id = id
              ..title = title
              ..timeMinutes = minutes
              ..rating = rating
              ..ingredients = ingredients
              ..createdAt = created
              ..updatedAt = created
              ..lastCookedAt = goldenNow.subtract(Duration(days: cookedDaysAgo))
              ..tags = const [])
            .build();
    r.core.isFavorite = favourite;
    return r;
  }

  return [
    recipe(
      'r1',
      'Krämig svamppasta med timjan',
      45,
      4.5,
      12,
      ingredients: const ['300 g svamp', '400 g pasta'],
    ),
    recipe('r2', 'Linsgryta med kokos', 35, 4.0, 40, favourite: true),
    recipe('r3', 'Citronrisotto', 30, 4.5, 21),
    recipe('r4', 'Rårakor med lingon', 25, 3.5, 30),
  ];
}

/// A queue time fixed so the ages read the same on every run.
final goldenNow = DateTime(2026, 9, 24, 17, 30);

List<QueuedChange> _changes() => [
  QueuedChange(
    kind: QueuedChangeKind.recipe,
    id: 'q1',
    operation: QueuedOperation.update,
    queuedAt: goldenNow.subtract(const Duration(minutes: 12)),
    subject: 'Linsgryta med kokos',
  ),
  QueuedChange(
    kind: QueuedChangeKind.recipe,
    id: 'q2',
    operation: QueuedOperation.update,
    queuedAt: goldenNow.subtract(const Duration(hours: 3)),
    subject: 'Citronrisotto',
    needsUser: true,
    reason: QueuedChangeReason.permissionDenied,
  ),
];
