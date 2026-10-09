// BUT-2158: a recipe with lines the reader could not read never rides the
// batch save past the review; its row opens it in the editor instead
// (flows-roles-budget.md).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart'
    as app_provider;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/parsing/parse_metadata.dart';
import 'package:butlery/models/parsing/parsed_recipe.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/parsing/cache/parsed_recipe_cache.dart';
import 'package:butlery/services/parsing/feedback/import_correction_snapshot.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/import/batch_import_preview.dart';

import '../../infrastructure/builders/recipe_builder.dart';

void main() {
  final clean = RecipeBuilder()
      .withId('clean')
      .withTitle('Pannkakor')
      .withIngredients(['3 dl vetemjöl', '2 ägg'])
      .build();
  final unread = RecipeBuilder()
      .withId('unread')
      .withTitle('Potatisbullar')
      .withIngredients(['} dl potatismjöl', '2z dl vetemjöl', '1 ägg'])
      .build();

  Future<List<Object?>> pumpPreview(
    WidgetTester tester, {
    required List<Recipe> recipes,
    required List<Object?> popped,
    required List<Object?> editorArgs,
    List<ParsedRecipe?>? editorSnapshots,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('sv'),
        onGenerateRoute: (settings) {
          if (settings.name == Routes.manualEntry) {
            editorArgs.add(settings.arguments);
            // The editor's view model takes the snapshot out of the cache
            // when it opens, exactly once per open.
            final recipe =
                (settings.arguments! as Map)['initialRecipe'] as Recipe;
            editorSnapshots?.add(
              app_provider.ServiceLocator.tryGet<ParsedRecipeCache>()?.retrieve(
                recipe.id,
              ),
            );
            return MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('editor')),
            );
          }
          return null;
        },
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                popped.add(
                  await Navigator.of(context).push<List<Recipe>>(
                    MaterialPageRoute(
                      builder: (_) => BatchImportPreview(recipes: recipes),
                    ),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return popped;
  }

  testWidgets('the unread recipe says how many lines and is not in the batch', (
    tester,
  ) async {
    final popped = <Object?>[];
    await pumpPreview(
      tester,
      recipes: [clean, unread],
      popped: popped,
      editorArgs: [],
    );

    expect(
      find.text('2 rader kunde inte läsas. Tryck för att granska receptet.'),
      findsOneWidget,
    );
    expect(find.byType(CheckboxListTile), findsOneWidget);

    await tester.tap(find.byWidgetPredicate((w) => w is FilledButton));
    await tester.pumpAndSettle();
    expect(popped.single, [clean]);
  });

  testWidgets('a tap opens the unread recipe in the editor as an import', (
    tester,
  ) async {
    final editorArgs = <Object?>[];
    await pumpPreview(
      tester,
      recipes: [clean, unread],
      popped: [],
      editorArgs: editorArgs,
    );

    await tester.tap(find.byKey(const ValueKey('batch-import-unread-1')));
    await tester.pumpAndSettle();

    expect(find.text('editor'), findsOneWidget);
    expect(editorArgs.single, {'initialRecipe': unread, 'isTemplate': true});

    Navigator.of(tester.element(find.text('editor'))).pop();
    await tester.pumpAndSettle();
    expect(find.text('Öppnat för granskning'), findsOneWidget);
  });

  testWidgets('select all never takes the unread recipe into the batch', (
    tester,
  ) async {
    final popped = <Object?>[];
    await pumpPreview(
      tester,
      recipes: [clean, unread],
      popped: popped,
      editorArgs: [],
    );

    expect(find.text('Avmarkera alla'), findsOneWidget);
    await tester.tap(find.text('Avmarkera alla'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Markera alla'));
    await tester.pumpAndSettle();

    await tester.tap(find.byWidgetPredicate((w) => w is FilledButton));
    await tester.pumpAndSettle();
    expect(popped.single, [clean]);
  });

  testWidgets('a batch of only unread recipes has nothing to select', (
    tester,
  ) async {
    final single = RecipeBuilder()
        .withId('single')
        .withTitle('Kålpudding')
        .withIngredients(['1 vitkålshuvud', '% tsk salt'])
        .build();
    await pumpPreview(
      tester,
      recipes: [unread, single],
      popped: [],
      editorArgs: [],
    );

    expect(
      find.text('1 rad kunde inte läsas. Tryck för att granska receptet.'),
      findsOneWidget,
    );
    expect(find.text('Markera alla'), findsOneWidget);
    await tester.tap(find.text('Markera alla'));
    await tester.pumpAndSettle();
    expect(find.text('Markera alla'), findsOneWidget);

    final confirm = tester.widget<ButtonStyleButton>(
      find.byWidgetPredicate((w) => w is FilledButton),
    );
    expect(confirm.onPressed, isNull);
  });

  group('BUT-2317 the review on every open', () {
    late ParsedRecipeCache cache;

    setUp(() {
      cache = ParsedRecipeCache();
      app_provider.ServiceLocator.reset();
      app_provider.ServiceLocator.initialize(DIContainer());
      final getIt = GetIt.instance;
      if (getIt.isRegistered<ParsedRecipeCache>()) {
        getIt.unregister<ParsedRecipeCache>();
      }
      getIt.registerSingleton<ParsedRecipeCache>(cache);
    });

    tearDown(() {
      final getIt = GetIt.instance;
      if (getIt.isRegistered<ParsedRecipeCache>()) {
        getIt.unregister<ParsedRecipeCache>();
      }
      app_provider.ServiceLocator.reset();
    });

    Future<void> openAndClose(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('batch-import-unread-1')));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.text('editor'))).pop();
      await tester.pumpAndSettle();
    }

    testWidgets('a second open of the same recipe gets its review snapshot', (
      tester,
    ) async {
      ImportCorrectionSnapshot.capture(
        unread,
        source: ImportSource.photo,
        cache: cache,
      );
      final stored = cache.contains(unread.id);
      final snapshots = <ParsedRecipe?>[];
      await pumpPreview(
        tester,
        recipes: [clean, unread],
        popped: [],
        editorArgs: [],
        editorSnapshots: snapshots,
      );

      await openAndClose(tester);
      await openAndClose(tester);
      await openAndClose(tester);

      expect(stored, isTrue);
      expect(snapshots, hasLength(3));
      for (final snapshot in snapshots) {
        expect(
          snapshot?.metadata.parserVersion,
          ImportCorrectionSnapshot.reviewParserVersion,
        );
      }
      expect(identical(snapshots[0], snapshots[1]), isTrue);
    });

    testWidgets('a recipe imported without a snapshot opens without one', (
      tester,
    ) async {
      final snapshots = <ParsedRecipe?>[];
      await pumpPreview(
        tester,
        recipes: [clean, unread],
        popped: [],
        editorArgs: [],
        editorSnapshots: snapshots,
      );

      await openAndClose(tester);
      await openAndClose(tester);

      expect(snapshots, [null, null]);
    });
  });
}
