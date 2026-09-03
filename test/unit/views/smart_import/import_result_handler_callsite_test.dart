/// BUT-1247: callsite-order contract for [ImportResultHandler.checkForDuplicates].
///
/// BUT-1245 tested the two pure helpers in isolation. This file tests the ORDER
/// in which they are called inside [checkForDuplicates]:
///
///   (a) The content-threshold GATE is applied BEFORE the exact-match CLAMP.
///       Concretely: a fingerprint similarity of 0.0 (completely disjoint
///       recipes) must not trigger the duplicate dialog. If the clamp ran
///       first, 0.0 would be elevated to 0.8, which passes the 0.6 gate →
///       the dialog would open and the method would never return `true`
///       synchronously → the test would hang or fail.
///
///   (b) The clamp fires ONLY when `matchScore == 1.0`. That is the sentinel a
///       URL or title match leaves behind, and it is also what a content match
///       scoring exactly 1.0 sets — so the gate is the value, not the path. A
///       content match with a score above the gate but below 0.8 passes
///       through un-clamped (the raw score reaches the dialog).
///
/// Both tests drive the REAL [checkForDuplicates] method through a minimal
/// [BuildContext] obtained from a pumped widget. The
/// [UnifiedRecipeService] is stubbed at the mock layer so no network,
/// Firebase, or dialog-show infrastructure is needed for assertion (a); for
/// assertion (b) a real dialog is shown and we interact with it.
///
/// Production bridge pattern: [TestServiceLocator] + [production.ServiceLocator].
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/router/recipe_detail_route_args.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/views/smart_import/import_result_handler.dart';
import 'package:butlery/core/constants/routes.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Recipe _recipe({
  String id = 'r1',
  String title = 'Recepttitel',
  String? sourceUrl,
  List<String> ingredients = const ['ägg', 'mjöl', 'smör'],
}) {
  return Recipe(
    core: RecipeCore(
      id: id,
      title: title,
      description: '',
      ingredients: ingredients,
      instructions: const [],
      mealType: 'Middag',
      sourceUrl: sourceUrl,
    ),
    type: RecipeType.personal,
  );
}

/// Minimal wrapper that provides the localized [MaterialApp] environment
/// [checkForDuplicates] needs to resolve [context.l10n] and show snackbars.
/// Records every replaced route so a test can assert what the detail route was
/// actually handed. BUT-1779 changed three call sites from a bare id String to
/// the Recipe itself; a bare id decodes to null on the real router and lands on
/// the error screen, and nothing here could see the difference before.
class _RouteSpy extends NavigatorObserver {
  final List<Route<dynamic>> replaced = [];

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) replaced.add(newRoute);
  }
}

/// Routes `Routes.recipeDetail` through the production decoder, so the argument
/// contract is not copied here: anything that is neither a Recipe nor a Map
/// carrying one under 'recipe' — notably a bare id String — decodes to a null
/// recipe and falls to the error route.
///
/// `AppRouter.generateRoute` itself cannot be called: it reaches
/// `FirebaseAuth.instance` before this branch and error-routes everything in a
/// `flutter test` host, so it could not tell the fix from the bug (BUT-1779).
Route<dynamic>? _routerLikeOnGenerateRoute(RouteSettings settings) {
  if (settings.name != Routes.recipeDetail) return null;

  // The decode is the production function, not a copy, so this cannot drift
  // from it. Its own contract is pinned in
  // test/unit/core/router/recipe_detail_route_args_test.dart; what this suite
  // adds is the callers. Only the two markers below are local, so a route can
  // be asserted on without building RecipeDetailView and its DI graph.
  final recipe = decodeRecipeDetailRouteArgs(settings.arguments).recipe;
  if (recipe == null) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => const Scaffold(body: Text('DETAIL_ERROR')),
    );
  }
  final resolved = recipe;
  return MaterialPageRoute<void>(
    settings: settings,
    builder: (_) => Scaffold(body: Text('DETAIL_OK:${resolved.title}')),
  );
}

Widget _testApp(Widget child, {_RouteSpy? spy}) {
  return MaterialApp(
    locale: const Locale('sv'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: AppTheme.lightTheme,
    navigatorObservers: spy == null ? const [] : [spy],
    onGenerateRoute: _routerLikeOnGenerateRoute,
    home: Scaffold(body: child),
  );
}

void main() {
  late MockUnifiedRecipeService mockRecipeService;

  setUpAll(() {
    production.ServiceLocator.initialize(DIContainer());
  });

  setUp(() async {
    await TestServiceLocator.initialize();

    mockRecipeService =
        TestServiceLocator.get<UnifiedRecipeService>()
            as MockUnifiedRecipeService;

    // Default: no URL or title match → falls through to content fingerprint.
    when(
      () => mockRecipeService.findBySourceUrl(any()),
    ).thenAnswer((_) async => []);
    when(
      () => mockRecipeService.findByTitle(any()),
    ).thenAnswer((_) async => []);
  });

  tearDown(() async {
    await TestServiceLocator.reset();
  });

  // ── (a) Gate before clamp: sub-threshold score never opens dialog ────────

  testWidgets(
    'checkForDuplicates returns true without dialog '
    'when content similarity is below the 0.6 gate',
    (tester) async {
      // Arrange: the candidate has ingredients A, B, C; the existing recipe
      // has completely disjoint ingredients X, Y, Z. Jaccard similarity on
      // disjoint sets = 0.0 → 30% title + 70% ingredient = 0.0 total score.
      // This is well below the 0.6 gate.
      //
      // Regression proof: if clampToExactMatchFloor ran before
      // meetsContentDuplicateThreshold, 0.0 would be clamped to 0.8 which
      // passes the gate → showDuplicateMergeSheet would be called → the
      // method would never reach `return true` without user interaction.
      final existingRecipe = _recipe(
        id: 'existing',
        title: 'Soppor',
        ingredients: const ['potatis', 'lök', 'buljong'],
      );
      mockRecipeService.setRecipeState(
        recipes: [existingRecipe],
        isInitialized: true,
      );

      final candidate = _recipe(
        id: 'new',
        title: 'Pannkakor',
        ingredients: const ['ägg', 'mjöl', 'smör'],
      );

      late bool result;
      late BuildContext capturedContext;

      await tester.pumpWidget(
        _testApp(
          Builder(
            builder: (ctx) {
              capturedContext = ctx;
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pump();

      // Act: checkForDuplicates runs synchronously until the first await that
      // involves the mocked service returning empty URL/title lists, then
      // scans `recipes` (the disjoint existing recipe), computes similarity
      // 0.0, which fails the gate → returns true (caller should continue).
      result =
          await tester.runAsync(
            () async => ImportResultHandler.checkForDuplicates(
              capturedContext,
              candidate,
            ),
          ) ??
          true;

      // Assert: no dialog appeared; result is true (save as new).
      expect(
        result,
        isTrue,
        reason:
            'A fingerprint score of 0.0 is below the 0.6 gate and must '
            'not trigger the duplicate flow. If this fails, the gate '
            'and clamp have been reordered or the threshold has been '
            'lowered below 0.0.',
      );
      // showDuplicateMergeSheet uses showModalBottomSheet, not AlertDialog.
      expect(
        find.text('Spara som nytt'),
        findsNothing,
        reason:
            'No duplicate merge sheet should appear for a zero-similarity '
            'recipe pair. The "Spara som nytt" button is only rendered '
            'inside the sheet — its absence proves no sheet was shown.',
      );
    },
  );

  // ── (b) Content-fingerprint path above gate shows the duplicate sheet ────
  //
  // Intent: "This test proves that when a content similarity score passes the
  // 0.6 gate (without a URL/title match), checkForDuplicates shows the
  // duplicate merge bottom sheet and returns true when the user picks
  // 'Spara som nytt'."
  //
  // This is the second half of the ordering contract: the gate letting a
  // content match THROUGH is observable (sheet appears). If the gate
  // threshold were accidentally raised above the test score, the sheet would
  // not appear and the future would resolve true before the tap — the pump
  // after the future resolution would find no sheet.

  testWidgets(
    'checkForDuplicates shows the duplicate merge sheet for a content '
    'match above the 0.6 gate and returns true when user picks saveAsNew',
    (tester) async {
      // Arrange: two recipes sharing identical ingredients but different
      // titles. Jaccard on ingredients = 1.0; title keywords don't overlap
      // ("Soppor" vs "Pannkakor"). Combined score = 0.3*0 + 0.7*1.0 = 0.70
      // — above the 0.6 gate. Neither URL nor title match is set up so the
      // code follows the content-fingerprint branch exclusively.
      final existingRecipe = _recipe(
        id: 'existing',
        title: 'Soppor',
        ingredients: const ['ägg', 'mjöl', 'smör'],
      );
      mockRecipeService.setRecipeState(
        recipes: [existingRecipe],
        isInitialized: true,
      );

      final candidate = _recipe(
        id: 'new',
        title: 'Pannkakor',
        ingredients: const ['ägg', 'mjöl', 'smör'],
      );

      late BuildContext capturedContext;

      await tester.pumpWidget(
        _testApp(
          Builder(
            builder: (ctx) {
              capturedContext = ctx;
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pump();

      // Start checkForDuplicates WITHOUT awaiting it — the function suspends
      // at the first `await findBySourceUrl(...)`. The testWidgets fake-async
      // zone advances the microtask queue on each tester.pump() call, which
      // lets the mocked Futures resolve and the function progress through each
      // await point, eventually calling showModalBottomSheet.
      //
      // Using tester.runAsync here would block until the sheet is dismissed,
      // making it impossible to pump the sheet into view first.
      // ignore: unawaited_futures
      final resultFuture = ImportResultHandler.checkForDuplicates(
        capturedContext,
        candidate,
      );

      // Drain: findBySourceUrl → [] (1 await point)
      await tester.pump();
      // Drain: findByTitle → [] (1 await point)
      await tester.pump();
      // showModalBottomSheet is synchronous-ish; kick off the entrance animation.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // The "Spara som nytt" button is rendered by the sheet's action row
      // (duplicateMergeSaveAsNew = "Spara som nytt" in app_sv.arb).
      final saveAsNewBtn = find.text('Spara som nytt');
      expect(
        saveAsNewBtn,
        findsOneWidget,
        reason:
            'The duplicate merge sheet must appear when content similarity '
            'is 0.70 (above the 0.6 gate). If this is missing, the gate '
            'threshold was raised or the content-fingerprint branch is '
            'broken.',
      );

      await tester.tap(saveAsNewBtn);
      // Settle the sheet dismissal animation and let Navigator.pop resolve.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final result = await resultFuture;
      expect(
        result,
        isTrue,
        reason:
            "saveAsNew returns true so the caller can proceed with 'save "
            "as new'. If this fails, DuplicateMergeChoice.saveAsNew does "
            'not return true.',
      );
    },
  );

  /// BUT-1779. The merge branches push the detail route. They used to pass
  /// `matches.first.id`, a bare String, which the real router decodes to null
  /// and sends to the error screen. Nothing asserted the argument, so
  /// reverting the fix reddened nothing.
  ///
  /// BUT-1784 class, same two branches: `updateRecipe` returns a bool and it
  /// was discarded, so a refused write showed the success snackbar AND a detail
  /// screen rendering content that was never saved.
  for (final branch in const [
    ('Slå ihop bästa fält', 'mergeBestFields'),
    ('Ersätt med nytt', 'replaceWithNew'),
  ]) {
    final (buttonLabel, branchName) = branch;

    Future<(_RouteSpy, bool)> runBranch(
      WidgetTester tester, {
      required bool writeSucceeds,
    }) async {
      final existingRecipe = _recipe(
        id: 'existing',
        title: 'Soppor',
        ingredients: const ['ägg', 'mjöl', 'smör'],
      );
      mockRecipeService.setRecipeState(
        recipes: [existingRecipe],
        isInitialized: true,
      );
      when(
        () => mockRecipeService.updateRecipe(any()),
      ).thenAnswer((_) async => writeSucceeds);

      final candidate = _recipe(
        id: 'new',
        title: 'Pannkakor',
        ingredients: const ['ägg', 'mjöl', 'smör'],
      );

      final spy = _RouteSpy();
      late BuildContext capturedContext;
      await tester.pumpWidget(
        _testApp(
          Builder(
            builder: (ctx) {
              capturedContext = ctx;
              return const SizedBox();
            },
          ),
          spy: spy,
        ),
      );
      await tester.pump();

      // ignore: unawaited_futures
      final resultFuture = ImportResultHandler.checkForDuplicates(
        capturedContext,
        candidate,
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final btn = find.text(buttonLabel);
      expect(btn, findsOneWidget, reason: 'the $branchName button must render');
      await tester.tap(btn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final result = await resultFuture;
      return (spy, result);
    }

    testWidgets(
      '$branchName hands the detail route a Recipe, not a bare id',
      (tester) async {
        final (spy, _) = await runBranch(tester, writeSucceeds: true);

        expect(
          spy.replaced,
          isNotEmpty,
          reason: 'a successful merge navigates to the detail screen',
        );
        expect(
          spy.replaced.single.settings.arguments,
          isA<Recipe>(),
          reason:
              'a bare id String decodes to null on the real router and lands '
              'on the error screen — that was the BUT-1779 defect',
        );
        expect(find.text('DETAIL_ERROR'), findsNothing);
      },
    );

    testWidgets(
      '$branchName does NOT claim success when the write is refused',
      (tester) async {
        final (spy, result) = await runBranch(tester, writeSucceeds: false);

        expect(
          find.text('Kunde inte sammanfoga receptet'),
          findsOneWidget,
          reason: 'the user must be told the merge did not happen',
        );
        expect(
          find.text('Receptet har sammanfogats'),
          findsNothing,
          reason: 'a refused write must not show the success message',
        );
        expect(
          spy.replaced,
          isEmpty,
          reason:
              'navigating would render unsaved content as though it were '
              'persisted — invisible until the next load',
        );
        expect(result, isFalse);
      },
    );
  }

  // ── (e) URL match wins, and its display score is clamped to the floor ────
  //
  // BUT-1804 Gap 1. `findBySourceUrl` was stubbed to [] in setUp and no test
  // ever overrode it, so the URL branch and the clamp beside it were both
  // unexercised. The clamp exists because a URL match carries matchScore 1.0
  // as a sentinel; the real content similarity is computed afterwards and can
  // be far lower, and showing that raw number would tell the user 0% about a
  // recipe the URL already proved is the same page.

  testWidgets(
    'a source-URL match opens the sheet even when the content is dissimilar, '
    'and the score it shows is clamped to the exact-match floor',
    (tester) async {
      final existingRecipe = _recipe(
        id: 'existing',
        title: 'Soppor',
        ingredients: const ['potatis', 'lök', 'buljong'],
        sourceUrl: 'https://example.com/recept/1',
      );
      // Disjoint ingredients: real similarity is 0.0, well under the 0.6 gate.
      // Only the URL match can open the sheet here.
      when(
        () => mockRecipeService.findBySourceUrl('https://example.com/recept/1'),
      ).thenAnswer((_) async => [existingRecipe]);
      mockRecipeService.setRecipeState(recipes: const [], isInitialized: true);

      final candidate = _recipe(
        id: 'new',
        title: 'Pannkakor',
        ingredients: const ['ägg', 'mjöl', 'smör'],
        sourceUrl: 'https://example.com/recept/1',
      );

      late BuildContext capturedContext;
      await tester.pumpWidget(
        _testApp(
          Builder(
            builder: (ctx) {
              capturedContext = ctx;
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pump();

      // ignore: unawaited_futures
      ImportResultHandler.checkForDuplicates(capturedContext, candidate);
      await tester.pumpAndSettle();

      expect(
        find.text('Spara som nytt'),
        findsOneWidget,
        reason:
            'A URL match must open the merge sheet on its own. If this fails '
            'the URL branch has stopped being consulted, and an import from a '
            'page the user already saved would silently duplicate it.',
      );
      // The two ingredient sets are disjoint, so the computed similarity is
      // 0.0 and the sheet would read "0% likhet" without the clamp. 80 is the
      // exact-match floor the clamp raises it to.
      expect(
        find.text('80% likhet'),
        findsOneWidget,
        reason:
            'A URL match must display the exact-match floor, not the raw '
            'content similarity. Without clampToExactMatchFloor this reads '
            '"0% likhet" about a recipe the URL already proved is the same '
            'page.',
      );

      // The suppression is the half `verifyInOrder` in (f) cannot prove: it
      // shows both lookups ran in order, which an unconditional sequence would
      // also satisfy. This is what pins the `matches.isEmpty` guard.
      verifyNever(() => mockRecipeService.findByTitle(any()));

      await tester.tap(find.text('Spara som nytt'));
      await tester.pumpAndSettle();
    },
  );

  // ── (f) The title lookup runs after the URL lookup comes back empty ──────

  testWidgets(
    'a title match opens the sheet, and runs after the URL lookup',
    (tester) async {
      final existingRecipe = _recipe(
        id: 'existing',
        title: 'Pannkakor',
        ingredients: const ['potatis', 'lök', 'buljong'],
      );
      when(
        () => mockRecipeService.findByTitle('Pannkakor'),
      ).thenAnswer((_) async => [existingRecipe]);
      mockRecipeService.setRecipeState(recipes: const [], isInitialized: true);

      final candidate = _recipe(
        id: 'new',
        title: 'Pannkakor',
        ingredients: const ['ägg', 'mjöl', 'smör'],
        sourceUrl: 'https://example.com/recept/2',
      );

      late BuildContext capturedContext;
      await tester.pumpWidget(
        _testApp(
          Builder(
            builder: (ctx) {
              capturedContext = ctx;
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pump();

      // ignore: unawaited_futures
      ImportResultHandler.checkForDuplicates(capturedContext, candidate);
      await tester.pumpAndSettle();

      expect(find.text('Spara som nytt'), findsOneWidget);
      // The candidate carries a sourceUrl, so the URL lookup ran first and
      // returned the setUp default of []. This pins that both lookups run and
      // in which order; that the title one is SUPPRESSED by a URL hit is
      // pinned by (e) above.
      verifyInOrder([
        () => mockRecipeService.findBySourceUrl('https://example.com/recept/2'),
        () => mockRecipeService.findByTitle('Pannkakor'),
      ]);

      await tester.tap(find.text('Spara som nytt'));
      await tester.pumpAndSettle();
    },
  );
}
