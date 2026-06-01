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
  });
}
