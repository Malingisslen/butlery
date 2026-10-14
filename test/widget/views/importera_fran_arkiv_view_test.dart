/// Skarmar v12 'Importera från arkiv': ticking rows, "Välj alla", the "Fler"
/// sheet and the restore button's count all drive the same view model the
/// import runs from, so they are pinned against the real one.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/data/archived_recipes.dart' as archive;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/services/search_service.dart';
import 'package:butlery/services/unified/operations/personal_recipe_operations.dart';
import 'package:butlery/services/unified/types/recipe_types.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/archive_import_viewmodel.dart';
import 'package:butlery/views/importera_fran_arkiv_view.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../test_support/base_unit_test.dart';

class _MockPersonalOps extends Mock implements PersonalRecipeOperations {}

void main() {
  final total = archive.archivedRecipes.length;
  late _MockPersonalOps personalOps;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await BaseUnitTest.setupUnit();
    registerFallbackValue(archive.archivedRecipes);
  });

  setUp(() async {
    await TestServiceLocator.initialize();
    production.ServiceLocator.initialize(DIContainer());
    SharedPreferences.setMockInitialValues(<String, Object>{});
    personalOps = _MockPersonalOps();
    when(
      () => personalOps.addMultipleUnifiedRecipes(any()),
    ).thenAnswer((_) async => RecipeOperationResult.success('ok'));
    final recipes = MockUnifiedRecipeService()
      ..setRecipeState(
        error: null,
        personalOperations: personalOps,
        isInitialized: true,
      );
    TestServiceLocator.registerFactory<ArchiveImportViewModel>(
      () => ArchiveImportViewModel(
        recipeService: recipes,
        searchService: SearchService(),
      ),
    );
  });

  tearDown(() async {
    await TestServiceLocator.reset();
    production.ServiceLocator.reset();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  Future<void> pumpView(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('sv'),
        home: const ImporteraFranArkivView(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a failed restore shows the error view; Försök igen runs it '
      'again', (tester) async {
    var calls = 0;
    when(() => personalOps.addMultipleUnifiedRecipes(any())).thenAnswer((
      _,
    ) async {
      calls++;
      return calls == 1
          ? RecipeOperationResult.failure('Nätverksfel')
          : RecipeOperationResult.success('ok');
    });
    await pumpView(tester);

    await tester.tap(find.text('Återställ $total recept'));
    await tester.pumpAndSettle();

    expect(find.text('Nätverksfel'), findsOneWidget);
    expect(find.text('Försök igen'), findsOneWidget);
    expect(find.text(archive.archivedRecipes.first.title), findsNothing);

    await tester.tap(find.text('Försök igen'));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.text('Nätverksfel'), findsNothing);
  });

  testWidgets('with nothing ticked the button restores every listed recipe', (
    tester,
  ) async {
    await pumpView(tester);

    expect(find.text('Återställ $total recept'), findsOneWidget);
    expect(find.text('ARKIVERADE RECEPT · $total'), findsOneWidget);
  });

  testWidgets('ticking a row counts it in the top bar and on the button', (
    tester,
  ) async {
    await pumpView(tester);
    final first = archive.archivedRecipes.first;

    await tester.tap(find.text(first.title));
    await tester.pumpAndSettle();

    expect(find.text('1 VALD'), findsOneWidget);
    expect(find.text('Återställ 1 recept'), findsOneWidget);
  });

  testWidgets('a ticked row draws a ticked box and the others stay empty', (
    tester,
  ) async {
    await pumpView(tester);
    final recipes = archive.archivedRecipes;

    bool ticked(String title) => tester
        .widget<Checkbox>(
          find.descendant(
            of: find.ancestor(
              of: find.text(title),
              matching: find.byType(InkWell),
            ),
            matching: find.byType(Checkbox),
          ),
        )
        .value!;

    await tester.tap(find.text(recipes.first.title));
    await tester.pumpAndSettle();

    expect(ticked(recipes.first.title), isTrue);
    expect(ticked(recipes[1].title), isFalse);
  });

  testWidgets('"Välj alla" ticks every listed recipe', (tester) async {
    await pumpView(tester);

    await tester.tap(find.text('Välj alla'));
    await tester.pumpAndSettle();

    expect(find.text('$total VALDA'), findsOneWidget);
  });

  testWidgets('the restore button imports only what is ticked', (
    tester,
  ) async {
    await pumpView(tester);
    await tester.tap(find.text(archive.archivedRecipes.first.title));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Återställ 1 recept'));
    await tester.pumpAndSettle();

    final sent =
        verify(
              () => personalOps.addMultipleUnifiedRecipes(captureAny()),
            ).captured.single
            as List;
    expect(sent, hasLength(1));
  });

  testWidgets('a tag pill filters the list', (tester) async {
    await pumpView(tester);

    await tester.tap(find.text('curry'));
    await tester.pumpAndSettle();

    final inCurry = archive.archivedRecipes
        .where((r) => r.personalTagIds?.contains('curry') ?? false)
        .length;
    expect(inCurry, lessThan(total));
    expect(find.text('ARKIVERADE RECEPT · $inCurry'), findsOneWidget);
  });

  testWidgets('"Fler" opens the sheet with every tag and the time limits', (
    tester,
  ) async {
    await pumpView(tester);

    await tester.tap(find.text('Fler'));
    await tester.pumpAndSettle();

    expect(find.text('Filter'), findsOneWidget);
    expect(find.text('vegetariskt'), findsOneWidget);
    expect(find.text('Högst 30 min'), findsOneWidget);

    await tester.tap(find.text('Högst 15 min'));
    await tester.pumpAndSettle();
    final fast = archive.archivedRecipes
        .where((r) => r.timeMinutes != null && r.timeMinutes! <= 15)
        .length;
    expect(fast, lessThan(total));
    expect(find.text('ARKIVERADE RECEPT · $fast'), findsOneWidget);
  });
}
