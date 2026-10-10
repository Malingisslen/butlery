// BUT-1817: a page the app wrongly split in two can be put back together in
// the picker, before anything is saved.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/observers/snackbar_route_observer.dart';
import 'package:butlery/core/providers/application_provider.dart'
    as app_provider;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/services/tagging/tagging_service.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/import/batch_import_preview.dart';

import '../../infrastructure/builders/recipe_builder.dart';

class _MockTaggingService extends Mock implements TaggingService {}

void main() {
  setUpAll(() => registerFallbackValue(RecipeBuilder().build()));

  final cake = RecipeBuilder()
      .withId('cake')
      .withTitle('Kladdkaka')
      .withIngredients(['2 ägg', '3 dl socker'])
      .withInstructions(['Vispa.'])
      .build();
  final frosting = RecipeBuilder()
      .withId('frosting')
      .withTitle('Glasyr')
      .withIngredients(['100 g smör'])
      .withInstructions(['Rör ihop.'])
      .build();
  final buns = RecipeBuilder()
      .withId('buns')
      .withTitle('Bullar')
      .withIngredients(['5 dl mjöl'])
      .withInstructions(['Baka.'])
      .build();

  Future<void> pumpPreview(
    WidgetTester tester,
    List<Recipe> recipes,
    List<Object?> popped,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('sv'),
        // The app's observer is what clears snackbars when the picker pops.
        navigatorObservers: [SnackbarRouteObserver()],
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
  }

  Future<void> confirm(WidgetTester tester) async {
    await tester.tap(find.byWidgetPredicate((w) => w is FilledButton));
    await tester.pumpAndSettle();
  }

  testWidgets('merging two ticked recipes saves one with both halves', (
    tester,
  ) async {
    final popped = <Object?>[];
    await pumpPreview(tester, [cake, frosting, buns], popped);

    // Untick the buns, so only the two halves are merged.
    await tester.tap(find.text('Bullar'));
    await tester.pump();
    await tester.tap(find.text('Slå ihop valda (2)'));
    await tester.pump();

    expect(find.text('2 recept slogs ihop till ett'), findsOneWidget);
    expect(find.text('Glasyr'), findsNothing);
    expect(find.byType(CheckboxListTile), findsNWidgets(2));

    await confirm(tester);
    // The undo goes with the picker instead of lingering over the save result.
    expect(find.byType(SnackBar), findsNothing);
    final saved = popped.single! as List<Recipe>;
    expect(saved, hasLength(1));
    expect(saved.single.id, 'cake');
    expect(saved.single.ingredients, ['2 ägg', '3 dl socker', '100 g smör']);
    expect(saved.single.instructions, ['Vispa.', 'Rör ihop.']);
  });

  testWidgets('the merge button needs two ticked recipes', (tester) async {
    await pumpPreview(tester, [cake, frosting], []);

    expect(find.text('Slå ihop valda (2)'), findsOneWidget);

    await tester.tap(find.text('Glasyr'));
    await tester.pump();

    expect(find.textContaining('Slå ihop valda'), findsNothing);
  });

  testWidgets('undo brings back the recipes as they were', (tester) async {
    final popped = <Object?>[];
    await pumpPreview(tester, [cake, frosting], popped);

    await tester.tap(find.text('Slå ihop valda (2)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ångra'));
    await tester.pumpAndSettle();

    expect(find.text('Glasyr'), findsOneWidget);
    await confirm(tester);
    expect(popped.single, [cake, frosting]);
  });

  testWidgets('the merged row takes the place of its first part', (
    tester,
  ) async {
    final popped = <Object?>[];
    await pumpPreview(tester, [cake, frosting, buns], popped);

    await tester.tap(find.text('Bullar'));
    await tester.pump();
    await tester.tap(find.text('Slå ihop valda (2)'));
    await tester.pump();
    await tester.tap(find.text('Bullar'));
    await tester.pump();

    await confirm(tester);
    final saved = popped.single! as List<Recipe>;
    expect(saved.map((r) => r.id), ['cake', 'buns']);
  });

  testWidgets('a second merge replaces the first merge\'s undo', (
    tester,
  ) async {
    await pumpPreview(tester, [cake, frosting, buns], []);

    await tester.tap(find.text('Bullar'));
    await tester.pump();
    await tester.tap(find.text('Slå ihop valda (2)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bullar'));
    await tester.pump();
    await tester.tap(find.text('Slå ihop valda (2)'));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    await tester.tap(find.text('Ångra'));
    await tester.pumpAndSettle();

    // Only the second merge is undone: the first one's pair stays merged.
    expect(find.text('Bullar'), findsOneWidget);
    expect(find.text('Glasyr'), findsNothing);
  });

  group('with preview tagging available', () {
    late _MockTaggingService tagging;

    setUp(() {
      app_provider.ServiceLocator.reset();
      app_provider.ServiceLocator.initialize(DIContainer());
      tagging = _MockTaggingService();
      final getIt = GetIt.instance;
      if (getIt.isRegistered<TaggingService>()) {
        getIt.unregister<TaggingService>();
      }
      getIt.registerSingleton<TaggingService>(tagging);
    });

    tearDown(() {
      final getIt = GetIt.instance;
      if (getIt.isRegistered<TaggingService>()) {
        getIt.unregister<TaggingService>();
      }
      app_provider.ServiceLocator.reset();
    });

    // The allergen-setup prompt after saving reads the preview tags.
    testWidgets('the merged recipe is preview-tagged over all its rows', (
      tester,
    ) async {
      final tags = TagResult.empty();
      when(
        () => tagging.generatePhase1Preview(any()),
      ).thenAnswer((_) async => tags);
      final popped = <Object?>[];
      await pumpPreview(tester, [cake, frosting], popped);

      await tester.tap(find.text('Slå ihop valda (2)'));
      await tester.pumpAndSettle();
      await confirm(tester);

      final tagged =
          verify(
                () => tagging.generatePhase1Preview(captureAny()),
              ).captured.single
              as Recipe;
      expect(tagged.ingredients, ['2 ägg', '3 dl socker', '100 g smör']);
      expect((popped.single! as List<Recipe>).single.tagResult, same(tags));
    });
  });
}
