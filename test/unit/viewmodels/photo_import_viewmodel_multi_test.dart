import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/services/import/text_import_strategy.dart';
import 'package:butlery/services/ocr/text_layout.dart';
import 'package:butlery/services/unified/types/recipe_types.dart';
import 'package:butlery/viewmodels/photo_import_viewmodel.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/di/test_service_locator.dart';

void main() {
  group('PhotoImportViewModel — multi-recipe', () {
    late PhotoImportViewModel vm;
    late MockPersonalRecipeOperations mockPersonalOps;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      // The VM constructor fires OCR-service init, which reads SharedPreferences
      // via OCRUsageTracker — mock it so the fire-and-forget init doesn't throw.
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      await BaseUnitTest.setupUnit();
      registerFallbackValue(RecipeFactory.build());
    });

    setUp(() {
      mockPersonalOps = MockPersonalRecipeOperations();
      when(
        () => mockPersonalOps.addUnifiedRecipe(any()),
      ).thenAnswer((_) async => RecipeOperationResult.success('Added'));
      // Real ImportManager (single TextImportStrategy) so autoParseMulti
      // exercises the actual splitter + parser, not a DI mock.
      vm = PhotoImportViewModel(
        importManager: ImportManager.withStrategies(
          mockPersonalOps,
          [TextImportStrategy()],
        ),
      );
    });

    tearDown(() async {
      vm.dispose();
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    const singleRecipe = '''
Pannkakor
Ingredienser:
3 dl vetemjöl
2 ägg
Gör så här:
Vispa ihop smeten och stek i smör.''';

    const threeRecipePage = '''
Pannkakor
Ingredienser:
3 dl vetemjöl
2 ägg
Gör så här:
Vispa ihop smeten och stek i smör.

Våfflor
Ingredienser:
4 dl vetemjöl
3 dl grädde
Gör så här:
Grädda i våffeljärn tills gyllene.

Plättar
Ingredienser:
2 dl vetemjöl
2 dl mjölk
Gör så här:
Stek små plättar i plättlagg.''';

    test(
      'single recipe → hasMultipleRecipes false, parsedRecipe set',
      () async {
        await vm.parseOcrTextForTesting(singleRecipe);
        expect(vm.hasMultipleRecipes, isFalse);
        expect(
          vm.parsedRecipe,
          isNotNull,
          reason: 'single-recipe path still drives the existing getter',
        );
      },
    );

    test(
      'three-recipe page → hasMultipleRecipes true, picker list populated',
      () async {
        await vm.parseOcrTextForTesting(threeRecipePage);
        expect(vm.hasMultipleRecipes, isTrue);
        expect(vm.parsedRecipes.length, greaterThanOrEqualTo(3));
      },
    );

    test('saveSelectedRecipes saves each selected recipe', () async {
      final recipes = [
        RecipeFactory.build(id: 'r1', title: 'A'),
        RecipeFactory.build(id: 'r2', title: 'B'),
      ];
      final ok = await vm.saveSelectedRecipes(recipes);
      expect(ok, isTrue);
      verify(() => mockPersonalOps.addUnifiedRecipe(any())).called(2);
    });

    test(
      'saveSelectedRecipes on empty list reports failure, saves nothing',
      () async {
        final ok = await vm.saveSelectedRecipes(const []);
        expect(ok, isFalse);
        verifyNever(() => mockPersonalOps.addUnifiedRecipe(any()));
      },
    );

    test(
      'saveSelectedRecipes continues past a failure and counts it',
      () async {
        // First save fails, second succeeds → partial: ok stays true (the saved
        // one is kept), failure count is 1, and BOTH were attempted.
        var call = 0;
        when(() => mockPersonalOps.addUnifiedRecipe(any())).thenAnswer((
          _,
        ) async {
          call++;
          return call == 1
              ? RecipeOperationResult.failure('boom')
              : RecipeOperationResult.success('Added');
        });
        final ok = await vm.saveSelectedRecipes([
          RecipeFactory.build(id: 'bad', title: 'Bad'),
          RecipeFactory.build(id: 'good', title: 'Good'),
        ]);
        expect(ok, isTrue);
        expect(vm.lastSaveFailureCount, 1);
        verify(() => mockPersonalOps.addUnifiedRecipe(any())).called(2);
      },
    );

    test(
      'saveSelectedRecipes reports a hard failure when every save fails',
      () async {
        when(
          () => mockPersonalOps.addUnifiedRecipe(any()),
        ).thenAnswer((_) async => RecipeOperationResult.failure('boom'));
        final ok = await vm.saveSelectedRecipes([
          RecipeFactory.build(id: 'r1', title: 'A'),
        ]);
        expect(ok, isFalse);
      },
    );

    // BUT-903 multi-page: collect ordered photos, OCR each, concatenate in
    // order before one parse.
    group('multi-page combine (BUT-903)', () {
      Uint8List bytes(int n) => Uint8List.fromList([n]);

      test('two pages concatenate OCR text in capture order', () async {
        await vm.addPageForTesting(bytes(1), 'PAGE-ONE');
        await vm.addPageForTesting(bytes(2), 'PAGE-TWO');

        expect(vm.pageCount, 2);
        expect(vm.hasMultiplePages, isTrue);
        // Combined text is the per-page text joined in order — this is the
        // single document the one parse sees.
        expect(vm.ocrText, 'PAGE-ONE\n\nPAGE-TWO');
        // First page drives the live preview image.
        expect(vm.imageBytes, bytes(1));
      });

      test('page cap blocks the sixth page', () async {
        for (var i = 1; i <= PhotoImportViewModel.maxPages; i++) {
          await vm.addPageForTesting(bytes(i), 'P$i');
        }
        expect(vm.pageCount, PhotoImportViewModel.maxPages);
        expect(vm.canAddPage, isFalse);

        // Beyond the cap the seam is a no-op — count stays at the max.
        await vm.addPageForTesting(bytes(99), 'OVERFLOW');
        expect(vm.pageCount, PhotoImportViewModel.maxPages);
        expect(vm.ocrText.contains('OVERFLOW'), isFalse);
      });

      test('removePage drops the page and recombines remaining text', () async {
        await vm.addPageForTesting(bytes(1), 'ONE');
        await vm.addPageForTesting(bytes(2), 'TWO');
        await vm.addPageForTesting(bytes(3), 'THREE');

        await vm.removePage(1); // drop "TWO"

        expect(vm.pageCount, 2);
        expect(vm.ocrText, 'ONE\n\nTHREE');
      });

      test(
        'removing the last remaining page clears the whole import',
        () async {
          await vm.addPageForTesting(bytes(1), 'ONLY');
          await vm.removePage(0);

          expect(vm.pageCount, 0);
          expect(vm.hasImage, isFalse);
          expect(vm.hasOcrResult, isFalse);
        },
      );

      test('reorderPage changes the concatenation order', () async {
        await vm.addPageForTesting(bytes(1), 'FIRST');
        await vm.addPageForTesting(bytes(2), 'SECOND');

        // Move the second page in front of the first.
        await vm.reorderPage(1, 0);

        expect(vm.ocrText, 'SECOND\n\nFIRST');
        expect(vm.imageBytes, bytes(2));
      });

      // ReorderableListView reports newIndex == length when an item is dropped
      // past the last slot. The VM must decrement that index by one (the item
      // being moved still occupies its old slot at drop time) so "drag the
      // first page to the end" actually lands it last instead of throwing or
      // no-op'ing. This is the off-by-one branch the production comment flags.
      test(
        'reorderPage handles drop-past-end index from ReorderableListView',
        () async {
          await vm.addPageForTesting(bytes(1), 'A');
          await vm.addPageForTesting(bytes(2), 'B');

          // List = [A, B]; drag A (index 0) to the end → newIndex == length (2).
          await vm.reorderPage(0, 2);

          expect(
            vm.ocrText,
            'B\n\nA',
            reason: 'first page moved to the end becomes the last page',
          );
          expect(
            vm.imageBytes,
            bytes(2),
            reason: 'B is now the first/cover page driving the preview',
          );
        },
      );

      test('reorderPage to its own slot is a no-op', () async {
        await vm.addPageForTesting(bytes(1), 'A');
        await vm.addPageForTesting(bytes(2), 'B');

        await vm.reorderPage(1, 1);

        expect(vm.ocrText, 'A\n\nB');
      });
    });

    group('the geometry reaches the splitter', () {
      Uint8List bytes(int n) => Uint8List.fromList([n]);

      /// One line the way a reader hands it over: a box per word, so
      /// `OcrLine.typeHeight` is a real measurement rather than the line box.
      OcrLine row(String text, double height) => OcrLine(
        text: text,
        box: LayoutBox(
          left: 0,
          top: 0,
          width: text.length * 18,
          height: height,
        ),
        words: [
          for (final w in text.split(' '))
            OcrWord(
              text: w,
              box: LayoutBox(left: 0, top: 0, width: 40, height: height),
            ),
        ],
      );

      /// Prose with no ingredient list and no quantities anywhere — the shape
      /// the whole layout path exists for. Long enough to clear the splitter's
      /// 200-char block minimum and carrying a cooking verb, which a
      /// layout-derived block must have.
      List<OcrLine> body(String dish) => [
        row('Lagg kokta skalade agg i en ratatouille och servera', 70),
        row('med brod till eller med raris och en fransk gronsaksrora', 70),
        row('Vispa ihop smeten och grada den i ugnen tills $dish ar klar', 70),
        row('Koka upp och lat sjuda under lock i ungefar tjugo minuter', 70),
      ];

      /// Both titles at ONE height on purpose: a real spread sets its dish
      /// names in one type, and `OcrWord.typeHeight` divides out the glyphs, so
      /// the height argument is the only thing that varies.
      PageLayout spread() => PageLayout(
        lines: [
          row('Italiensk frittata', 167),
          ...body('ratten'),
          row('Fransk omelett', 167),
          ...body('omeletten'),
        ],
      );

      test('a photographed prose spread becomes TWO recipes', () async {
        // The viewmodel half of the chain, with the pages INJECTED:
        // _PhotoPage -> DocumentLayout -> autoParseMulti -> split, all real.
        //
        // The recogniser and the OCR service are NOT in this test.
        // `addPageForTesting` hands the layout straight to `_PhotoPage`, so the
        // two hops before that — including the line that reads the geometry off
        // `OCRResult` — are absent, not exercised. `photo_import_layout_thread_
        // test` owns that half and is the only suite that can see it.
        final page = spread();

        // The control first, and it is the point: the SAME text with no
        // geometry stays one blob.
        //
        // Two separate facts make that meaningful, and both were measured
        // (2026-08-07) rather than reasoned. What DECLINES on the control arm
        // is the text path's ingredient-cluster gate — this page carries no
        // quantity anywhere, and adding two quantity rows under each title
        // splits the identical string with no layout at all. What SPLITS on
        // the layout arm is the type size — flattening both titles from 167 to
        // the body's 70 makes the detector find no headings and this arm return
        // 1 as well. The control alone would also hold on a page that had no
        // headings to find, which is why the second half is worth stating.
        await vm.addPageForTesting(bytes(1), page.text);
        expect(
          vm.parsedRecipes.length,
          1,
          reason: 'control — without geometry the text rules merge this page',
        );

        vm.clearPhoto();
        await vm.addPageForTesting(bytes(1), page.text, layout: page);

        expect(vm.parsedRecipes.length, 2);
      });

      test(
        'ONE page without geometry drops the whole import to text',
        () async {
          // Fail-closed across pages, and it has to be the whole DOCUMENT: a
          // photo import re-parses on every added page, so a second photo that
          // happened to reach a paid tier would otherwise collapse the picker
          // from two recipes to one mid-flow. Mixed provenance also means mixed
          // engines, whose type sizes are not comparable at all.
          //
          // Scope, measured 2026-08-07 — this is a SCENARIO record, not a
          // discriminating test, and the next reader should not spend it as
          // coverage. Every plausible mutant of the viewmodel's document build
          // survives it, but NOT all for the same reason, and the difference is
          // the part worth carrying (re-measured 2026-08-07 against these exact
          // fixtures). Dropping the null pages, and keeping only the first, are
          // both refused one layer down by `matchesLineCountOf`, on row count.
          // Substituting an EMPTY page for a missing one PASSES that gate — and
          // only by accident of this fixture, because the page that lost its
          // geometry holds exactly ONE row, which contributes no newline of its
          // own; give it two rows and the row count separates them again. What
          // actually refuses it is `HeadingDetector.headingLinesForDocument`
          // returning null: a page with no lines has no measurable baseline, so
          // the detector declines to judge the whole document. Nothing in this
          // file would catch that mutant if the detector ever learned to judge a
          // line-less page.
          //
          // The rule the test NAMES is pinned in `text_layout_test`'s
          // 'DocumentLayout.isComplete fails closed' — that is where weakening
          // the getter reddens directly. It reddens here too, but NOT in the
          // sibling test above this one, whose pages are all measured. The order
          // test below is the one that catches a document built wrongly from
          // these same pages.
          final measured = spread();
          final unmeasured = PageLayout(lines: [row('Efterratt', 167)]);

          await vm.addPageForTesting(bytes(1), measured.text, layout: measured);
          expect(
            vm.parsedRecipes.length,
            2,
            reason: 'premise: page one alone does split',
          );

          // Page two carries text but NO layout — a paid tier, the handwriting
          // path, or a restored draft.
          await vm.addPageForTesting(bytes(2), unmeasured.text);

          expect(vm.parsedRecipes.length, 1);
        },
      );

      test('the geometry follows its page when the pages are reordered', () async {
        // The one failure the fail-closed rules CANNOT catch: a document whose
        // pages are in a different order from the text they describe. The
        // pages are the same pages, so the row count matches and
        // `matchesLineCountOf` says yes; every heading index then converts
        // confidently to the wrong text row and the split lands mid-prose.
        //
        // It needs pages of DIFFERENT lengths to be visible at all. With two
        // equally long pages a reversed document maps every heading to exactly
        // the same row, so the whole hazard is invisible — which is why the
        // single-page fixtures above cannot see it. Measured 2026-08-07 with
        // this test in place: reversing the viewmodel's page list leaves the
        // OTHER 34 tests across this suite, the layout-thread suite and
        // `multi_recipe_splitter_layout_test` green and reddens only this one,
        // while turning the second block's first line into body prose. (An
        // earlier version of this sentence said all 34 stayed green — true of
        // the measurement taken BEFORE this test existed, and it read as
        // saying the mutant survives here too, which is the one thing the test
        // is for.)
        //
        // Titles, not a count: a wrongly ordered document still yields two
        // blocks. Only WHERE they start moves.
        final pA = PageLayout(
          lines: [row('Italiensk frittata', 167), ...body('ratten')],
        );
        final pB = PageLayout(
          lines: [
            row('Fransk omelett', 167),
            ...body('omeletten'),
            row('Servera genast med en skiva nybakat brod bredvid', 70),
            row('Stro over hackad persilja och mal svartpeppar over', 70),
          ],
        );

        await vm.addPageForTesting(bytes(1), pA.text, layout: pA);
        await vm.addPageForTesting(bytes(2), pB.text, layout: pB);

        expect(
          vm.parsedRecipes.map((r) => r.title),
          orderedEquals(['Italiensk frittata', 'Fransk omelett']),
        );

        // Reordering is a real user action (drag the page strip), and it moves
        // the text — so the geometry has to move with it or the two disagree
        // from the next parse on.
        await vm.reorderPage(1, 0);

        expect(
          vm.parsedRecipes.map((r) => r.title),
          orderedEquals(['Fransk omelett', 'Italiensk frittata']),
        );
      });
    });
  });
}
