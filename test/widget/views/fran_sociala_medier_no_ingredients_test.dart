/// BUT-2285: a text import that parsed no ingredient lines tells the recipe
/// form so, and the form explains the empty list instead of only greying out
/// save. The flag is computed here, at the hand-off, so it is pinned here.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/core/router/manual_entry_route.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/text_import_viewmodel.dart';
import 'package:butlery/views/fran_sociala_medier_view.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../test_support/base_unit_test.dart';

class _MockTextImportViewModel extends Mock implements TextImportViewModel {}

class _MockUserService extends Mock implements UserService {}

const _pasted = '2 dl mjölk\n3 ägg\nVispa ihop.';

Recipe _recipe(List<String> ingredients) => Recipe(
  core: RecipeCore(
    id: '',
    title: 'Pannkakor',
    description: '',
    ingredients: ingredients,
    instructions: const ['Vispa ihop.'],
    mealType: 'Middag',
  ),
  type: RecipeType.personal,
);

void main() {
  late _MockTextImportViewModel vm;
  late List<RouteSettings> pushed;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await BaseUnitTest.setupUnit();
  });

  setUp(() async {
    await TestServiceLocator.initialize();
    production.ServiceLocator.initialize(DIContainer());
    SharedPreferences.setMockInitialValues(<String, Object>{});

    vm = _MockTextImportViewModel();
    when(() => vm.canParse).thenReturn(true);
    when(() => vm.error).thenReturn(null);
    when(() => vm.hasError).thenReturn(false);
    when(() => vm.inputText).thenReturn(_pasted);
    when(() => vm.isParsing).thenReturn(false);
    when(() => vm.hasMultipleParsedRecipes).thenReturn(false);
    when(() => vm.sourceUrl).thenReturn(null);
    when(() => vm.updateInputText(any())).thenReturn(null);
    when(() => vm.setSourceUrl(any())).thenReturn(null);
    when(() => vm.parseText()).thenAnswer((_) async => true);
    TestServiceLocator.registerMock<TextImportViewModel>(vm);

    final userService = _MockUserService();
    when(
      () => userService.allergenPreferences,
    ).thenReturn(UserAllergenPreferences.defaults);
    TestServiceLocator.registerMock<UserService>(userService);
    pushed = [];
  });

  tearDown(() async {
    await TestServiceLocator.reset();
    production.ServiceLocator.reset();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  Future<Map<String, Object?>> previewAndEdit(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('sv'),
        home: const FranSocialaMedierView(initialText: _pasted),
        onGenerateRoute: (settings) {
          pushed.add(settings);
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const Scaffold(body: Text('editor')),
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    final button = find.text('Förhandsgranska och redigera');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();

    final editor = pushed.single;
    expect(editor.name, Routes.manualEntry);
    return editor.arguments! as Map<String, Object?>;
  }

  testWidgets('a parse with only blank ingredient lines flags the editor', (
    tester,
  ) async {
    when(() => vm.parsedRecipe).thenReturn(_recipe(const ['  ']));

    final args = await previewAndEdit(tester);

    expect(args[ManualEntryRoute.importedWithoutIngredientsKey], isTrue);
  });

  testWidgets('a parse with an ingredient does not flag the editor', (
    tester,
  ) async {
    when(() => vm.parsedRecipe).thenReturn(_recipe(const ['6 dl mjölk']));

    final args = await previewAndEdit(tester);

    expect(args[ManualEntryRoute.importedWithoutIngredientsKey], isFalse);
  });
}
