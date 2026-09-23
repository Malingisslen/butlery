// A failed ingredient search says so in the app language, says what was
// kept, and offers Sök igen (P5-U13). While it runs, the plate line says
// "Söker ingredienser …" (P5-U21).
//
// Sources: content-style-guide.md:89-94 (what happened, what was kept, what
// you can do), produktregler.md:163 (plate line + text).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/ingredient_repository.dart';
import 'package:butlery/services/ingredient_match_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/viewmodels/ingredient_search_viewmodel.dart';
import 'package:butlery/views/ingredient_search/ingredient_search_view.dart';
import 'package:butlery/widgets/common/state_widget.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

class _MockMatchService extends Mock implements IngredientMatchService {}

class _MockIngredientRepository extends Mock implements IngredientRepository {}

class _MockRecipeService extends Mock implements UnifiedRecipeService {}

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  final sv = AppLocalizationsSv();
  late _MockMatchService match;
  late IngredientSearchViewModel vm;
  late Completer<List<IngredientMatchResult>> pending;

  setUp(() async {
    await GetIt.instance.reset();
    match = _MockMatchService();
    final recipes = _MockRecipeService();
    final auth = _MockAuthRepository();
    when(() => auth.currentUserId).thenReturn(null);
    when(() => recipes.recipes).thenReturn(const <Recipe>[]);
    GetIt.instance.registerSingleton<AuthRepository>(auth);
    vm = IngredientSearchViewModel(
      matchService: match,
      ingredientRepository: _MockIngredientRepository(),
      recipeService: recipes,
    );
    GetIt.instance.registerSingleton<IngredientSearchViewModel>(vm);
    prod.ServiceLocator.initialize(DIContainer());
  });

  tearDown(() async {
    prod.ServiceLocator.reset();
    await GetIt.instance.reset();
  });

  testWidgets('searching shows the plate line with text; a failure shows '
      'what happened, that the ingredients stay, and Sök igen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    // Created inside the test body so it completes on the test's clock.
    pending = Completer<List<IngredientMatchResult>>();
    when(
      () => match.matchRecipesWithNormalization(
        selectedIngredientIds: any(named: 'selectedIngredientIds'),
        recipes: any(named: 'recipes'),
      ),
    ).thenAnswer((_) => pending.future);

    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScaffold: false,
        child: const IngredientSearchView(),
      ),
    );
    vm.addIngredient(
      const IngredientData(
        id: 'chicken',
        swedish: 'kyckling',
        english: 'chicken',
        group: 'other',
        properties: {},
      ),
    );
    unawaited(vm.performSearch());
    await tester.pump();

    final loading = tester.widget<StateWidget>(find.byType(StateWidget));
    expect(loading.type, StateType.loading);
    expect(loading.message, sv.loadingIngredientSearch);

    pending.completeError(StateError('boom'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    final error = tester.widget<StateWidget>(find.byType(StateWidget));
    expect(error.type, StateType.error);
    expect(find.text(sv.ingredientSearchError), findsOneWidget);
    expect(find.text(sv.ingredientSearchSelectionKept), findsOneWidget);
    expect(find.text(sv.ingredientSearchAgain), findsOneWidget);
    expect(find.textContaining('boom'), findsNothing);

    // Sök igen runs the search again with the kept ingredients.
    when(
      () => match.matchRecipesWithNormalization(
        selectedIngredientIds: any(named: 'selectedIngredientIds'),
        recipes: any(named: 'recipes'),
      ),
    ).thenAnswer((_) async => const <IngredientMatchResult>[]);
    await tester.tap(find.text(sv.ingredientSearchAgain));
    await tester.pump();
    await tester.pump();
    verify(
      () => match.matchRecipesWithNormalization(
        selectedIngredientIds: {'chicken'},
        recipes: any(named: 'recipes'),
      ),
    ).called(2);
  });
}
