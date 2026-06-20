import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/services/import/text_import_strategy.dart';
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
      when(() => mockPersonalOps.addUnifiedRecipe(any()))
          .thenAnswer((_) async => RecipeOperationResult.success('Added'));
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

    test('single recipe → hasMultipleRecipes false, parsedRecipe set',
        () async {
      await vm.parseOcrTextForTesting(singleRecipe);
      expect(vm.hasMultipleRecipes, isFalse);
      expect(vm.parsedRecipe, isNotNull,
          reason: 'single-recipe path still drives the existing getter');
    });

    test('three-recipe page → hasMultipleRecipes true, picker list populated',
        () async {
      await vm.parseOcrTextForTesting(threeRecipePage);
      expect(vm.hasMultipleRecipes, isTrue);
      expect(vm.parsedRecipes.length, greaterThanOrEqualTo(3));
    });

    test('saveSelectedRecipes saves each selected recipe', () async {
      final recipes = [
        RecipeFactory.build(id: 'r1', title: 'A'),
        RecipeFactory.build(id: 'r2', title: 'B'),
      ];
      final ok = await vm.saveSelectedRecipes(recipes);
      expect(ok, isTrue);
      verify(() => mockPersonalOps.addUnifiedRecipe(any())).called(2);
    });

    test('saveSelectedRecipes on empty list reports failure, saves nothing',
        () async {
      final ok = await vm.saveSelectedRecipes(const []);
      expect(ok, isFalse);
      verifyNever(() => mockPersonalOps.addUnifiedRecipe(any()));
    });

    test('saveSelectedRecipes continues past a failure and counts it',
        () async {
      // First save fails, second succeeds → partial: ok stays true (the saved
      // one is kept), failure count is 1, and BOTH were attempted.
      var call = 0;
      when(() => mockPersonalOps.addUnifiedRecipe(any())).thenAnswer((_) async {
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
    });

    test('saveSelectedRecipes reports a hard failure when every save fails',
        () async {
      when(() => mockPersonalOps.addUnifiedRecipe(any()))
          .thenAnswer((_) async => RecipeOperationResult.failure('boom'));
      final ok = await vm
          .saveSelectedRecipes([RecipeFactory.build(id: 'r1', title: 'A')]);
      expect(ok, isFalse);
    });

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

      test('removing the last remaining page clears the whole import',
          () async {
        await vm.addPageForTesting(bytes(1), 'ONLY');
        await vm.removePage(0);

        expect(vm.pageCount, 0);
        expect(vm.hasImage, isFalse);
        expect(vm.hasOcrResult, isFalse);
      });

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
      test('reorderPage handles drop-past-end index from ReorderableListView',
          () async {
        await vm.addPageForTesting(bytes(1), 'A');
        await vm.addPageForTesting(bytes(2), 'B');

        // List = [A, B]; drag A (index 0) to the end → newIndex == length (2).
        await vm.reorderPage(0, 2);

        expect(vm.ocrText, 'B\n\nA',
            reason: 'first page moved to the end becomes the last page');
        expect(vm.imageBytes, bytes(2),
            reason: 'B is now the first/cover page driving the preview');
      });

      test('reorderPage to its own slot is a no-op', () async {
        await vm.addPageForTesting(bytes(1), 'A');
        await vm.addPageForTesting(bytes(2), 'B');

        await vm.reorderPage(1, 1);

        expect(vm.ocrText, 'A\n\nB');
      });
    });
  });
}
