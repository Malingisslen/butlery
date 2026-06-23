import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/services/import/text_import_strategy.dart';
import 'package:butlery/services/unified/types/recipe_types.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/di/test_service_locator.dart';

void main() {
  group('ImportManager.autoParseMulti', () {
    late ImportManager importManager;
    late MockPersonalRecipeOperations mockPersonalOps;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(RecipeFactory.build());
    });

    setUp(() {
      mockPersonalOps = MockPersonalRecipeOperations();
      when(
        () => mockPersonalOps.addUnifiedRecipe(any()),
      ).thenAnswer((_) async => RecipeOperationResult.success('Added'));
      importManager = ImportManager.withStrategies(
        mockPersonalOps,
        [TextImportStrategy()],
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

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

    const singleRecipe = '''
Pannkakor
Ingredienser:
3 dl vetemjöl
2 ägg
Gör så här:
Vispa ihop smeten och stek i smör.''';

    test(
      'returns exactly one recipe for a single-recipe blob (identity)',
      () async {
        final result = await importManager.autoParseMulti(singleRecipe);
        expect(result.successfulRecipes, hasLength(1));
      },
    );

    test('returns three recipes for a three-recipe page', () async {
      final result = await importManager.autoParseMulti(threeRecipePage);
      expect(
        result.successfulRecipes.length,
        greaterThanOrEqualTo(3),
        reason: 'each title→ingredients→instructions block parses',
      );
    });

    test('is parse-only — never saves to PersonalRecipeOperations', () async {
      await importManager.autoParseMulti(threeRecipePage);
      verifyNever(() => mockPersonalOps.addUnifiedRecipe(any()));
    });
  });
}
