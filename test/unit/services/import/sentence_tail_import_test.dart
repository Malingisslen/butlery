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

  test('the end of a method sentence cut loose by a column break is a step, '
      'not an ingredient row', () async {
    final result = await TextImportStrategy().import(
      'Potatisgratäng\n'
      '800 g potatis\n'
      '2 dl grädde\n'
      '1 vitlöksklyfta\n'
      'med lite salt och svartpeppar.\n'
      'Grädda i 45 minuter.',
    );
    expect(result.isSuccess, isTrue, reason: result.errorMessage);
    final recipe = result.recipe!;
    expect(
      recipe.ingredients.any((i) => i.contains('svartpeppar')),
      isFalse,
      reason: recipe.ingredients.toString(),
    );
    expect(recipe.ingredients, hasLength(3));
  });

  test('a bare row without a full stop stays an ingredient', () async {
    final result = await TextImportStrategy().import(
      'Potatisgratäng\n'
      '800 g potatis\n'
      '2 dl grädde\n'
      'salt och svartpeppar\n'
      'Gör så här: Skiva potatisen och grädda i 45 minuter.',
    );
    expect(
      result.recipe!.ingredients.any((i) => i.contains('svartpeppar')),
      isTrue,
    );
  });

  test('a row that opens on its ingredient keeps its allergen tag even with a '
      'full stop', () async {
    final result = await TextImportStrategy().import(
      'Potatisgratäng\n'
      '800 g potatis\n'
      '2 dl grädde\n'
      'smör till stekning.\n'
      'Grädda i 45 minuter.',
    );
    expect(
      result.recipe!.ingredients.any((i) => i.contains('smör')),
      isTrue,
      reason: result.recipe!.ingredients.toString(),
    );
  });
}
