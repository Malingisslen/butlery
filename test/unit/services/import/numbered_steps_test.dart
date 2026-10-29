/// A numbered step stays one step however many sentences it has (BUT-2455,
/// Malin's call 2026-10-29); an unnumbered paragraph is still split per
/// sentence.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/import/parsers/text_import_normalizer.dart';
import 'package:butlery/services/import/text_import_strategy.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../test_support/base_unit_test.dart';

void main() {
  group('TextImportNormalizer.preprocessText on numbered steps', () {
    List<String> lines(String s) =>
        TextImportNormalizer.preprocessText(s).split('\n');

    test('a numbered step keeps all its sentences on one line', () {
      expect(lines('1. Smält smöret. Häll i grädden.'), [
        '1.',
        'Smält smöret. Häll i grädden.',
      ]);
    });

    test('an unnumbered line is still split at each sentence', () {
      expect(lines('Smält smöret. Häll i grädden.'), [
        'Smält smöret.',
        'Häll i grädden.',
      ]);
    });

    test('a step marker without a space is a quantity, not a step', () {
      expect(lines('1.5 dl grädde'), ['1.5 dl grädde']);
    });

    test('a step kept whole still loses its hashtags', () {
      final out = lines('1. Rör ner grädden #middag. Koka upp.');
      expect(out, hasLength(2));
      expect(out.last, isNot(contains('#')));
      expect(out.last, isNot(contains('middag')));
    });

    test('a step kept whole gets the space OCR dropped after a period', () {
      expect(
        lines('1. Smält smöret.Häll i grädden.').last,
        'Smält smöret. Häll i grädden.',
      );
    });

    test('an icon-font glyph in the input is dropped, not read as a step', () {
      expect(
        lines('Ingredienser\n\uE150 2 dl mjölk\n1. Koka upp. Servera.'),
        ['Ingredienser', ' 2 dl mjölk', '1.', 'Koka upp. Servera.'],
      );
    });
  });

  group('TextImportStrategy on numbered multi-sentence steps', () {
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

    test('three numbered steps give exactly three instructions', () async {
      final result = await strategy.import('''
Krämig kycklinggryta
Ingredienser
500 g kycklingfilé
2 dl grädde
1 gul lök
Gör så här
1. Skär kycklingen i bitar. Hacka löken fint.
2. Stek kycklingen i smör. Tillsätt löken och fräs en minut.
3. Häll i grädden. Låt puttra i 10 minuter. Servera med ris.
''');
      expect(result.isSuccess, isTrue, reason: result.errorMessage);
      expect(result.recipe!.instructions, [
        'Skär kycklingen i bitar. Hacka löken fint.',
        'Stek kycklingen i smör. Tillsätt löken och fräs en minut.',
        'Häll i grädden. Låt puttra i 10 minuter. Servera med ris.',
      ]);
    });
  });
}
