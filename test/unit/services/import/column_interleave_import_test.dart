/// A cookbook photo with the ingredients in a narrow column beside the method
/// is read line by line across both. Each line then has to sort itself:
/// rows into the ingredient list, sentences into the method, and the pieces a
/// reader cut loose out of the way.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/import/text_import_strategy.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../test_support/base_unit_test.dart';

void main() {
  late TextImportStrategy strategy;

  setUp(() async {
    await BaseUnitTest.setupUnit();
    await TestServiceLocator.initialize();
    strategy = TextImportStrategy();
  });

  tearDown(() async {
    await TestServiceLocator.reset();
    BaseUnitTest.resetMocks();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  Future<Recipe> parse(String text) async {
    final result = await strategy.import(text);
    expect(result.isSuccess, isTrue, reason: result.errorMessage);
    return result.recipe!;
  }

  const kokostarta =
      'Kokostårta med hallon\n'
      'Mördeg:\n'
      '125 g margarin eller smör\n'
      '1/2 dl strösocker\n'
      'Låt krämen svalna, rör då och då i den, och smaka av med vanillin-\n'
      '1 äggula\n'
      'socker och ev rom, konjak eller\n'
      '3 dl vetemjöl\n'
      'Fyll mördegsskalet med den kalla\n'
      'Kokoskräm:\n'
      '1 3/4 dl strösocker\n'
      '1 nypa salt\n'
      'krämen och garnera med hallon.\n'
      '3/4 dl vetemjöl\n'
      'Smörj botten på en form, ca 24 cm\n'
      'i diameter och helst löstagbar.\n';

  test('sentences among the rows are steps, not ingredients', () async {
    final r = await parse(kokostarta);
    expect(r.ingredients, containsAll(['125 g margarin eller smör']));
    expect(
      r.ingredients.any((i) => i.toLowerCase().contains('smörj botten')),
      isFalse,
    );
    expect(
      r.ingredients.any((i) => i.toLowerCase().contains('krämen och')),
      isFalse,
    );
  });

  test(
    'the same ingredient with another amount in one list is its own row',
    () async {
      final r = await parse(
        'Pannkakor\n\n'
        '2 dl vetemjöl\n'
        '4 dl mjölk\n'
        '4 dl vetemjöl\n'
        '2 ägg\n\n'
        'Vispa ihop mjöl och mjölk. Stek i smör.',
      );
      final flour = r.ingredients.where((i) => i.contains('vetemjöl')).toList();
      expect(flour, hasLength(2), reason: '$flour');
    },
  );

  test('a bare allergen carrier with no amount is kept', () async {
    final r = await parse(
      'Wok\n\n2 dl ris\n1 gul lök\n3 msk soja\ntofu\ngärna nötter\n\n'
      'Stek löken i olja. Blanda allt.',
    );
    expect(r.ingredients, contains('tofu'));
    expect(r.ingredients.any((i) => i.contains('nötter')), isTrue);
  });

  test('a digit the reader took for a letter still makes a row', () async {
    final r = await parse(
      'Svampburgare\n\n'
      '4 burgare\n'
      '1 gul lök\n'
      'i tsk hackad färsk timjan\n'
      '400 g kokta kikärtor, sköljda\n'
      '½ dl potatismjöl\n\n'
      'Koka riset och låt det kallna. Skala och finhacka lök och vitlök.',
    );
    expect(
      r.ingredients.any((i) => i.contains('timjan')),
      isTrue,
      reason: '${r.ingredients}',
    );
  });

  test('a bare word cut loose from a sentence is not a row', () async {
    final r = await parse(
      'Pannkakor\n\n'
      '3 dl vetemjöl\n'
      '6 dl mjölk\n'
      '3 ägg\n'
      'csas\n'
      'smält smöret och rör ner det i smeten.\n'
      'Vispa ihop allt och stek i smör.',
    );
    expect(r.ingredients.any((i) => i.contains('csas')), isFalse);
    expect(r.ingredients.any((i) => i.contains('rör ner')), isFalse);
  });
}
