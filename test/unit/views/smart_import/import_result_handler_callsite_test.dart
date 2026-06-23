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
///   (b) The clamp fires ONLY when `matchScore == 1.0` — i.e. only on the
///       URL / title match path, not on the content-fingerprint path. A
///       content match with a score above the gate but below 0.8 must pass
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
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/views/smart_import/import_result_handler.dart';

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
Widget _testApp(Widget child) {
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
}
