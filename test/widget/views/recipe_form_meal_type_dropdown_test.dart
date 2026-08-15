// BUT-1845: the meal-type dropdown must render whatever value the recipe
// actually carries, instead of asserting on it.
//
// `DropdownButtonFormField` asserts in its CONSTRUCTOR — re-checked on every
// build — that exactly one item matches its value. Both recipe-form views USED
// TO bind `items:` to the six Swedish `RecipeFormState.mealTypes` while
// `initialValue:` held the recipe's stored `mealType`, so any other stored
// value threw on build in debug and rendered a blank control in release. They
// now go through `RecipeFormViewModel.mealTypeOptions`, which is what these
// cases pin.
//
// This is the app's own default path, not a legacy-data edge case. The assisted
// import writes ENGLISH values (`assisted_import_viewmodel.dart:77` defaults to
// 'dinner', written at :352) and then pushes this very screen with that recipe
// (`import_result_handler.dart:237` -> `app_router.dart:200`), whose form loads
// the value verbatim (`recipe_form_state.dart`, `_mealType = recipe.mealType`
// in `_loadRecipeData` — cited by name, not by line, precisely because this
// change's own additions moved it). Text import contributes
// 'Huvudrätt' (`text_import_strategy.dart:990`), which is in no list at all.
//
// Every case below is RED before the fix. They are the proof the bug is real,
// and they double as the mutation probes for it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/social_recipe_service.dart';
import 'package:butlery/services/tagging/personal_tag_service.dart';
import 'package:butlery/services/upload/image_upload_service.dart';
import 'package:butlery/viewmodels/collaborative_status_viewmodel.dart';
import 'package:butlery/viewmodels/personal_tag_viewmodel.dart';
import 'package:butlery/viewmodels/recipe_form/recipe_form_state.dart';
import 'package:butlery/viewmodels/recipe_form_viewmodel.dart';
import 'package:butlery/views/edit_recipe_view.dart';
import 'package:butlery/views/skriv_sjalv_recept_view.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/mock_factory.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/helpers/widget_test_app.dart';
import '../../infrastructure/mocks/production_mocks.dart' as mocks;
import '../../test_support/base_unit_test.dart';

void main() {
  group('meal-type dropdown tolerates the value the recipe carries', () {
    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      production.ServiceLocator.initialize(DIContainer());
    });

    setUp(() async {
      await TestServiceLocator.initialize();
      // Both views build a real RecipeFormViewModel; EditRecipeView also
      // resolves CollaborativeStatusViewModel in initState. Same seam the
      // BUT-1309 tab-order suite uses (focus_traversal_group_test.dart).
      TestServiceLocator.registerMock<AuthService>(
        MockFactory.createAuthService(
          isAuthenticated: true,
          userId: 'test-user-123',
        ),
      );
      TestServiceLocator.registerMock<PermissionService>(
        MockFactory.createPermissionService(currentUserId: 'test-user-123'),
      );
      TestServiceLocator.registerMock<SocialRecipeService>(
        MockFactory.createSocialRecipeService(),
      );
      TestServiceLocator.registerFactory<CollaborativeStatusViewModel>(
        () => CollaborativeStatusViewModel(),
      );
      TestServiceLocator.registerMock<ImageUploadService>(ImageUploadService());
      final mockTagService = mocks.MockPersonalTagService();
      TestServiceLocator.registerMock<PersonalTagService>(mockTagService);
      TestServiceLocator.registerMock<OfflineService>(
        OfflineService(
          firestoreRepository: TestServiceLocator.get<FirestoreRepository>(),
          authRepository: TestServiceLocator.get<AuthRepository>(),
        ),
      );
      TestServiceLocator.registerFactory<PersonalTagViewModel>(
        () => PersonalTagViewModel(service: mockTagService),
      );
    });

    tearDown(() async {
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    Recipe recipeWithMealType(String mealType) => RecipeFactory.build(
      id: 'recipe-but-1845',
      title: 'Testrecept',
      description: 'Beskrivning',
      ingredients: const ['Mjöl', 'Socker'],
      instructions: const ['Blanda', 'Grädda'],
      mealType: mealType,
    );

    Future<void> pumpSkrivSjalv(WidgetTester tester, String mealType) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: SkrivSjalvReceptView(
            initialRecipe: recipeWithMealType(mealType),
          ),
          // The view ships its own Scaffold.
          wrapInScaffold: false,
        ),
      );
      await tester.pumpAndSettle();
    }

    /// The dropdown as the framework sees it. Asserting on the widget rather
    /// than on rendered text matters: a dropdown builds EVERY item into an
    /// IndexedStack, so `find.text('Lunch')` matches whether or not that row is
    /// the selected one.
    DropdownButtonFormField<String> mealTypeDropdown(WidgetTester tester) =>
        tester.widget<DropdownButtonFormField<String>>(
          find.byType(DropdownButtonFormField<String>),
        );

    /// The offered values, read off the INNER `DropdownButton` — the form field
    /// does not expose `items`, and this is the widget whose own assert also
    /// has to match. There is only ever one of it: the open menu route builds
    /// item BUTTONS, not a second DropdownButton. It is the item LABELS that
    /// get duplicated, which is why the tap case below needs `hitTestable()`.
    List<String?> offeredValues(WidgetTester tester) => tester
        .widget<DropdownButton<String>>(find.byType(DropdownButton<String>))
        .items!
        .map((item) => item.value)
        .toList();

    // The assisted import's untouched default. Nothing about this recipe is
    // unusual — this is what one ordinary import produces.
    testWidgets('an English value from assisted import renders', (
      tester,
    ) async {
      await pumpSkrivSjalv(tester, 'dinner');

      // Defensive, not the discriminator: a build-time assert already fails
      // the test. This states the intent for the next reader.
      expect(tester.takeException(), isNull);
      expect(mealTypeDropdown(tester).initialValue, 'dinner');
    });

    // From `_guessMealType`, and in NO list anywhere in the app — not the six
    // Swedish ones, not the five English ones.
    testWidgets('a Swedish value outside the offered list renders', (
      tester,
    ) async {
      await pumpSkrivSjalv(tester, 'Huvudrätt');

      expect(tester.takeException(), isNull);
      expect(mealTypeDropdown(tester).initialValue, 'Huvudrätt');

      // The value rendering is not enough on its own. The prepend could be
      // right while the vocabulary behind it is SWAPPED — a real candidate is
      // `lib/models/recipe/recipe_factory.dart`'s `getDefaultMealTypes()`
      // (note: the production class, not the test factory imported above),
      // seven Swedish words carrying 'Efterrätt'/'Dryck'/'Bakning' where
      // `mealTypes` has 'Dessert'/'Fika'. `initialValue` would still match,
      // both asserts would hold, and the user would be offered the wrong
      // words. Anchored on RecipeFormState.mealTypes rather than on
      // mealTypeOptions — routing both sides through the seam under test would
      // be a tautology.
      final items = offeredValues(tester);
      expect(items.first, 'Huvudrätt');
      expect(items.sublist(1), RecipeFormState.mealTypes);

      // The LOAD half of "must not change what the screen writes": merely
      // opening the form must leave the stored value alone. This reads the
      // source of truth DIRECTLY rather than through the view's binding.
      // Not independently discriminating today — a rewrite in `_loadRecipeData`
      // also reddens the `initialValue` assertion above, because that value is
      // derived from the same field in the same build. It survives a change
      // that widens at the VIEW instead of at the state.
      expect(
        tester
            .element(find.byType(DropdownButtonFormField<String>))
            .read<RecipeFormViewModel>()
            .mealType,
        'Huvudrätt',
      );
    });

    // The doc comment says the two halves must come from ONE read per build.
    // Nothing ABOVE pins it; below, only the narrowing assertion in "picking an
    // offered value" does, and only in the shrinking direction. Memoising the
    // read (a `late final`, or hoisting it into initState) would leave the list
    // frozen — silent wrong data, where after an external write the control
    // shows the old meal type while the viewmodel and the save hold the new one.
    //
    // This case drives the WIDENING direction, which a user pick can never
    // produce: a picked value is by construction already in the CURRENT
    // `values`, whose only member outside `mealTypes` is the stored value
    // itself — so recomputing can only drop that row (picking an offered one)
    // or reproduce it (picking the injected one). Only a write from OUTSIDE the
    // control can introduce a value the list does not hold — in production that
    // is draft recovery — `RecipeDraftRecoveryHandler` -> `loadFromDraft`
    // -> `recipe_form_state.dart`'s `_mealType = draftData['mealType'] ?? 'Middag'`,
    // which can restore a widened value into a mounted form. This case is not
    // hypothetical; do not delete it as such.
    testWidgets('an external write after first build re-widens the list', (
      tester,
    ) async {
      await pumpSkrivSjalv(tester, 'Middag');
      expect(offeredValues(tester), hasLength(6));

      tester
          .element(find.byType(DropdownButtonFormField<String>))
          .read<RecipeFormViewModel>()
          .setMealType('Huvudrätt');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(mealTypeDropdown(tester).initialValue, 'Huvudrätt');
      expect(
        offeredValues(tester),
        hasLength(7),
        reason:
            'The list must widen on the rebuild. If it does not, the read was '
            'memoised and the control now disagrees with what will be saved.',
      );
    });

    // `SerializationUtils.safeString` defaults only on null, so a stored empty
    // string survives `Recipe.fromJson` and reaches the form intact.
    testWidgets('an empty stored value renders as an unselected control', (
      tester,
    ) async {
      await pumpSkrivSjalv(tester, '');

      expect(tester.takeException(), isNull);
      expect(
        mealTypeDropdown(tester).initialValue,
        isNull,
        reason:
            'An empty value matches no item, so the control must be unselected '
            'rather than asserting. What the user then sees is the view hint, '
            'or blank where none is declared — deliberate, and better than a '
            'crash either way.',
      );
    });

    // The invariant the whole change rests on: it must not alter what the
    // screen WRITES. Displaying the value correctly and then saving the wrong
    // one would pass every assertion above.
    testWidgets('picking an offered value still writes that value', (
      tester,
    ) async {
      await pumpSkrivSjalv(tester, 'Huvudrätt');

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      // The open menu renders a second copy of each label on top of the
      // IndexedStack one. hitTestable() picks the copy the user can actually
      // tap, without depending on traversal order.
      await tester.tap(find.text('Lunch').hitTestable());
      await tester.pumpAndSettle();

      // The view is a StatelessWidget wrapping a ChangeNotifierProvider, so
      // read the viewmodel from a context BELOW the provider — the dropdown's
      // own element. That is the source of truth the save path reads.
      final viewModel = tester
          .element(find.byType(DropdownButtonFormField<String>))
          .read<RecipeFormViewModel>();
      expect(tester.takeException(), isNull);
      expect(
        viewModel.mealType,
        'Lunch',
        reason:
            'Selecting an offered row must persist it — displaying the value '
            'correctly and then saving a different one would satisfy every '
            'other case here.',
      );
      // The narrowing direction: the injected row is gone once it is no longer
      // the stored value. This does reach `didUpdateWidget` — the parent
      // rebuilds with a changed `initialValue` — but idempotently, since
      // `didChange` already set the same value. Only the external-write case
      // above exercises it with a value the list does not yet contain.
      expect(offeredValues(tester), hasLength(6));
    });

    // EditRecipeView edits the same field through the same seam, so it needs
    // its own case — otherwise its line is unguarded and the mutation probe
    // that swaps initialValue back can only be satisfied on one of the two.
    testWidgets('the edit screen renders an out-of-list value too', (
      tester,
    ) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: EditRecipeView(recipe: recipeWithMealType('Huvudrätt')),
          // The view ships its own Scaffold.
          wrapInScaffold: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(mealTypeDropdown(tester).initialValue, 'Huvudrätt');
    });
  });
}
