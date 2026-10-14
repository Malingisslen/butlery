/// Intent: the upload card lists the required and optional columns without
/// overflowing a 360 px phone.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;

import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:mocktail/mocktail.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import 'package:butlery/views/file_import_view.dart';

import '../../infrastructure/helpers/widget_test_app.dart';
import '../../infrastructure/mocks/production_mocks.dart';

void main() {
  late MockImportManager importManager;
  late MockUnifiedRecipeService recipeService;
  final sv = AppLocalizationsSv();

  setUp(() async {
    await GetIt.instance.reset();
    production.ServiceLocator.reset();
    importManager = MockImportManager();
    recipeService = MockUnifiedRecipeService();
    GetIt.instance.registerSingleton<ImportManager>(importManager);
    GetIt.instance.registerSingleton<UnifiedRecipeService>(recipeService);
    production.ServiceLocator.initialize(DIContainer());
  });

  tearDown(() async {
    await GetIt.instance.reset();
    production.ServiceLocator.reset();
  });

  testWidgets('the column list fits a 360 px phone with no overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      createLocalizedTestApp(
        child: const FileImportView(),
        wrapInScaffold: false,
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  group('closing after a clean import', () {
    Future<void> importOneRecipe(WidgetTester tester) async {
      registerFallbackValue(RecipeFactory.build());
      when(() => importManager.importFile()).thenAnswer(
        (_) async => FileImportResult([RecipeFactory.build(id: 'f1')]),
      );
      when(
        () => recipeService.createRecipeFrom(any()),
      ).thenAnswer((_) async => 'f1');

      await tester.pumpWidget(
        createLocalizedTestApp(
          wrapInScaffold: false,
          child: Builder(
            builder: (ctx) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push<void>(
                  ctx,
                  MaterialPageRoute(builder: (_) => const FileImportView()),
                ),
                child: const Text('open-import'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open-import'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(sv.importSelectFileAndImport));
      await tester.pumpAndSettle();
      await tester.tap(find.text(sv.importConfirmButton(1)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets('pops the page after the delay when it is still current', (
      tester,
    ) async {
      await importOneRecipe(tester);
      expect(find.byType(FileImportView), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(find.byType(FileImportView), findsNothing);
    });

    testWidgets('does not pop a page the user opened during the delay', (
      tester,
    ) async {
      await importOneRecipe(tester);

      Navigator.of(tester.element(find.byType(FileImportView))).push<void>(
        MaterialPageRoute(builder: (_) => const Scaffold(body: Text('annan'))),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(find.text('annan'), findsOneWidget);
      expect(find.byType(FileImportView, skipOffstage: false), findsOneWidget);
    });
  });
}
