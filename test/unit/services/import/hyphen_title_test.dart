import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/import/text_import_strategy.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../test_support/base_unit_test.dart';

void main() {
  setUp(() async {
    await BaseUnitTest.setupUnit();
    await TestServiceLocator.initialize();
  });

  tearDown(() async {
    await TestServiceLocator.reset();
    BaseUnitTest.resetMocks();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  test(
    'a title broken at a hyphen is the title, not an ingredient row',
    () async {
      final result = await TextImportStrategy().import(
        'Roquefort-\npotatis\nTill 4 portioner behövs:\n'
        '800 g små färska potatisar • 100 g bacon i\n'
        'tunna skivor • 60 g roquefortost\n'
        'Gör så här: Koka potatisen med skal. • Stek baconet.',
      );
      expect(result.isSuccess, isTrue, reason: result.errorMessage);
      final recipe = result.recipe!;
      expect(recipe.title, 'Roquefortpotatis');
      expect(
        recipe.ingredients.any(
          (i) => i.toLowerCase().contains('roquefortpotatis'),
        ),
        isFalse,
      );
      expect(recipe.ingredients.any((i) => i.toLowerCase() == 'till'), isFalse);
    },
  );
}
