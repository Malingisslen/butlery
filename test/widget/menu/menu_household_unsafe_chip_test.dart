// BUT-2362: the Lista view of a menu marks a dish someone in the household
// cannot eat, and says that the allergen filter follows who is home only
// while the per-meal choice is on.
//
// Drives the real MenuViewModel: the household's allergens are read
// asynchronously, so the chip appears on a later frame than the dish.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/services/tagging/tag_generator.dart'
    show kTagGeneratorVersion;
import 'package:butlery/viewmodels/menu_viewmodel.dart';
import 'package:butlery/widgets/menu/menu_content_widgets.dart';

import '../../infrastructure/factories/mock_factory.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/helpers/base_widget_test.dart';
import '../../infrastructure/helpers/widget_test_app.dart';

Recipe _dish(String id, {required TriState nuts}) {
  final base = RecipeFactory.build(id: id, title: id, mealType: 'Middag');
  return Recipe(
    core: base.core.copyWith(
      tagResult: TagResult(
        tags: const {},
        allergenStatus: {'nötter': nuts},
        dietaryStatus: const {},
        coverage: 1.0,
        generatedAt: DateTime(2026),
        generatorVersion: kTagGeneratorVersion,
      ),
    ),
    type: base.type,
  );
}

const _tracksNuts = UserAllergenPreferences(
  trackedAllergens: {'nötter'},
  trackedDietary: {},
);

void main() {
  final sv = AppLocalizationsSv();
  final nutDish = _dish('nutdish', nuts: TriState.contains);
  final freeDish = _dish('freedish', nuts: TriState.free);

  setUpAll(() async {
    await BaseWidgetTest.setupWidget();
    production.ServiceLocator.initialize(DIContainer());
  });

  tearDownAll(() async {
    await BaseWidgetTest.teardownWidget();
  });

  Future<void> pumpList(
    WidgetTester tester,
    List<Recipe> dishes, {
    bool scopeOn = false,
  }) async {
    final vm = MenuViewModel(
      recipeService: MockFactory.createUnifiedRecipeService(
        isInitialized: true,
      ),
      menuService: MockFactory.createMenuService(),
      analyticsService: MockFactory.createAnalyticsService(),
      householdAllergens: () async => _tracksNuts,
      mealAllergenScopeOn: () => scopeOn,
    );
    addTearDown(vm.dispose);
    vm.loadFromSharedMenu(
      SharedMenu.create(
        sharedByUserId: 'u1',
        sharedByDisplayName: 'Test',
        sharedToUserIds: const [],
        menuSnapshot: {'middag': dishes},
      ),
    );
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: ListenableBuilder(
          listenable: vm,
          builder: (context, _) =>
              MenuContentWidgets.buildMenuContent(context, viewModel: vm),
        ),
      ),
    );
    // The household's allergens land after the first frame.
    await tester.pump();
  }

  testWidgets('a dish the household cannot eat carries the chip', (
    tester,
  ) async {
    await pumpList(tester, [nutDish]);

    expect(find.text(sv.menuAllergenUnsafeForHousehold), findsOneWidget);
  });

  testWidgets('a dish free of the allergen carries no chip', (tester) async {
    await pumpList(tester, [freeDish]);

    // Positive control: the dish itself rendered.
    expect(find.textContaining('freedish', findRichText: true), findsWidgets);
    expect(find.text(sv.menuAllergenUnsafeForHousehold), findsNothing);
  });

  testWidgets('the chip marks only the unsafe dish of a mixed menu', (
    tester,
  ) async {
    await pumpList(tester, [freeDish, nutDish]);

    expect(find.text(sv.menuAllergenUnsafeForHousehold), findsOneWidget);
    final chip = tester.getCenter(
      find.text(sv.menuAllergenUnsafeForHousehold),
    );
    final unsafe = tester.getCenter(find.textContaining('nutdish'));
    final safe = tester.getCenter(find.textContaining('freedish'));
    expect((chip - unsafe).distance, lessThan((chip - safe).distance));
  });

  testWidgets(
    'the follows-who-is-home hint shows only while the choice is on',
    (
      tester,
    ) async {
      await pumpList(tester, [freeDish], scopeOn: true);
      expect(find.text(sv.menuMealAllergenScopeHint), findsOneWidget);

      await pumpList(tester, [freeDish]);
      expect(find.text(sv.menuMealAllergenScopeHint), findsNothing);
    },
  );

  group('reading the household allergens', () {
    MenuViewModel viewModel(Future<UserAllergenPreferences> Function() read) {
      final vm = MenuViewModel(
        recipeService: MockFactory.createUnifiedRecipeService(
          isInitialized: true,
        ),
        menuService: MockFactory.createMenuService(),
        analyticsService: MockFactory.createAnalyticsService(),
        householdAllergens: read,
      );
      addTearDown(vm.dispose);
      return vm;
    }

    test('a failed read is not repeated for every dish shown', () async {
      var reads = 0;
      final vm = viewModel(() async {
        reads++;
        throw StateError('offline');
      });

      vm.isHouseholdUnsafe(nutDish);
      await pumpEventQueue();
      vm.isHouseholdUnsafe(nutDish);
      vm.isHouseholdUnsafe(freeDish);
      await pumpEventQueue();

      expect(reads, 1);
    });

    test('a read started before a new menu is asked for is not used for '
        'it', () async {
      final answers = <Completer<UserAllergenPreferences>>[];
      final vm = viewModel(() {
        final answer = Completer<UserAllergenPreferences>();
        answers.add(answer);
        return answer.future;
      });

      vm.isHouseholdUnsafe(nutDish);
      // Rejected at once (empty prompt), after the old read is set aside.
      await vm.generateMenu('');
      vm.isHouseholdUnsafe(nutDish);
      expect(answers, hasLength(2));

      // The older read still holds an allergen the household no longer has.
      answers.first.complete(_tracksNuts);
      await pumpEventQueue();
      expect(vm.isHouseholdUnsafe(nutDish), isFalse);

      answers.last.complete(UserAllergenPreferences.none);
      await pumpEventQueue();
      expect(vm.isHouseholdUnsafe(nutDish), isFalse);
    });
  });
}
