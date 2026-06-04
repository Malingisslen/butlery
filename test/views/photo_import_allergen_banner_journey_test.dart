/// BUT-1209 journey test for the photo multi-recipe → allergen-banner wiring
/// (BUT-1200). The trigger helper `AllergenMismatch.anyUnconfigured` is
/// unit-proven; this proves the view-layer wiring the unit test can't reach:
/// after a successful multi-recipe save, `_navigateToMultiRecipePicker` shows
/// the allergen-setup banner IFF a saved recipe contains an untracked allergen,
/// and does NOT show it when the batch is clean or the save fails.
///
/// Mechanical view wiring (BUT-387 journey territory), so it pumps the real
/// view + the real BatchImportPreview picker rather than asserting internals.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/photo_import_viewmodel.dart';
import 'package:butlery/views/photo_import_view.dart';

import '../infrastructure/di/test_service_locator.dart';
import '../infrastructure/factories/recipe_factory.dart';
import '../infrastructure/mocks/production_mocks.dart' as mocks;
import '../test_support/base_unit_test.dart';

class _MockUserService extends Mock implements UserService {}

TagResult _allergenTags(Map<String, TriState> allergens) => TagResult(
      tags: const {},
      allergenStatus: allergens,
      dietaryStatus: const {},
      coverage: 1.0,
      generatedAt: DateTime(2026, 6, 4),
    );

Recipe _recipe(String title, Map<String, TriState> allergens) =>
    RecipeFactory.build(title: title)
        .copyWith(tagResult: _allergenTags(allergens));

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('sv'),
      home: child,
    );

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await BaseUnitTest.setupUnit();
    registerFallbackValue(<Recipe>[]);
  });

  /// Wires a photo VM in multi-recipe state with [recipes], a save that returns
  /// [saveOk], and a user tracking [tracked] allergens; returns nothing — the
  /// mocks are registered into the locator the view resolves from.
  void arrange({
    required List<Recipe> recipes,
    required bool saveOk,
    Set<String> tracked = const {},
  }) {
    final vm = mocks.MockPhotoImportViewModel();
    vm.setPhotoImportState(
      hasOcrResult: true,
      ocrText: 'some recipes',
      hasMultipleRecipes: true,
      parsedRecipes: recipes,
    );
    when(() => vm.saveSelectedRecipes(any())).thenAnswer((_) async => saveOk);
    when(() => vm.clearPhoto()).thenReturn(null);
    when(() => vm.dispose()).thenReturn(null);
    TestServiceLocator.registerMock<PhotoImportViewModel>(vm);

    final userService = _MockUserService();
    when(() => userService.allergenPreferences).thenReturn(
      UserAllergenPreferences.defaults.copyWith(trackedAllergens: tracked),
    );
    TestServiceLocator.registerMock<UserService>(userService);
  }

  setUp(() async {
    await TestServiceLocator.initialize();
    production.ServiceLocator.initialize(DIContainer());
  });

  tearDown(() async {
    await TestServiceLocator.reset();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  Future<void> saveBatch(WidgetTester tester) async {
    await tester.pumpWidget(_wrap(const PhotoImportView()));
    await tester.pumpAndSettle();

    final ctx = tester.element(find.byType(PhotoImportView));
    final l10n = AppLocalizations.of(ctx);

    // Open the multi-recipe picker (the button sits below the OCR card, so
    // scroll it into view before tapping).
    final multiBtn = find.text(l10n.importMultipleRecipesFound(2));
    await tester.ensureVisible(multiBtn);
    await tester.pumpAndSettle();
    await tester.tap(multiBtn);
    await tester.pumpAndSettle();

    // BatchImportPreview pre-selects everything; confirm the (2) selection.
    final confirmBtn = find.text(l10n.importConfirmButton(2));
    await tester.ensureVisible(confirmBtn);
    await tester.pumpAndSettle();
    await tester.tap(confirmBtn);
    await tester.pumpAndSettle();
  }

  testWidgets('an untracked contained allergen surfaces the setup banner',
      (tester) async {
    arrange(
      recipes: [
        _recipe('Pasta', {'gluten': TriState.contains}),
        _recipe('Sallad', const {}),
      ],
      saveOk: true,
    );

    await saveBatch(tester);

    expect(find.byType(MaterialBanner), findsOneWidget,
        reason: 'a saved recipe contains an untracked allergen → prompt shows');
  });

  testWidgets('a fully-tracked batch shows no banner', (tester) async {
    arrange(
      recipes: [
        _recipe('Pasta', {'gluten': TriState.contains}),
        _recipe('Sallad', const {}),
      ],
      saveOk: true,
      tracked: const {'gluten'},
    );

    await saveBatch(tester);

    expect(find.byType(MaterialBanner), findsNothing,
        reason: 'every contained allergen is already tracked → no prompt');
  });

  testWidgets('a failed save shows no banner', (tester) async {
    arrange(
      recipes: [
        _recipe('Pasta', {'gluten': TriState.contains}),
        _recipe('Sallad', const {}),
      ],
      saveOk: false,
    );

    await saveBatch(tester);

    expect(find.byType(MaterialBanner), findsNothing,
        reason: 'the save failed → the import did not complete → no prompt');
  });
}
