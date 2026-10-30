/// Unit tests for UnitDefinitions.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/parsing/swedish_units.dart';
import 'package:butlery/utils/text/unit_definitions.dart';

void main() {
  group('isKnownUnit', () {
    test('Swedish weight units', () {
      for (final u in ['g', 'kg', 'hg', 'dag', 'mg']) {
        expect(UnitDefinitions.isKnownUnit(u), isTrue, reason: u);
      }
    });

    test('Swedish volume units', () {
      for (final u in ['dl', 'l', 'ml', 'cl']) {
        expect(UnitDefinitions.isKnownUnit(u), isTrue, reason: u);
      }
    });

    test('Swedish cooking units', () {
      for (final u in ['msk', 'tsk', 'krm']) {
        expect(UnitDefinitions.isKnownUnit(u), isTrue, reason: u);
      }
    });

    test('Swedish packaging units', () {
      for (final u in ['burk', 'pkt', 'förpackning', 'påse', 'ask', 'flaska']) {
        expect(UnitDefinitions.isKnownUnit(u), isTrue, reason: u);
      }
    });

    test('Swedish full-word forms', () {
      for (final u in ['matsked', 'tesked', 'gram', 'kilo', 'liter']) {
        expect(UnitDefinitions.isKnownUnit(u), isTrue, reason: u);
      }
    });

    test('American units', () {
      for (final u in ['cup', 'tbsp', 'tsp', 'oz', 'lb', 'pound', 'ounce']) {
        expect(UnitDefinitions.isKnownUnit(u), isTrue, reason: u);
      }
    });

    test('plural American forms', () {
      for (final u in ['cups', 'lbs', 'pounds', 'ounces', 'tablespoons']) {
        expect(UnitDefinitions.isKnownUnit(u), isTrue, reason: u);
      }
    });

    test('Informal Swedish measures', () {
      for (final u in ['näve', 'gnutta', 'klick', 'droppe']) {
        expect(UnitDefinitions.isKnownUnit(u), isTrue, reason: u);
      }
    });

    test('case-insensitive lookup', () {
      expect(UnitDefinitions.isKnownUnit('KG'), isTrue);
      expect(UnitDefinitions.isKnownUnit('Msk'), isTrue);
      expect(UnitDefinitions.isKnownUnit('TBSP'), isTrue);
    });

    test('rejects unknown words', () {
      expect(UnitDefinitions.isKnownUnit('foo'), isFalse);
      expect(UnitDefinitions.isKnownUnit(''), isFalse);
      expect(UnitDefinitions.isKnownUnit('mjölk'), isFalse);
    });
  });

  test('standaloneUnits set is non-empty and contains expected anchors', () {
    expect(UnitDefinitions.standaloneUnits, contains('g'));
    expect(UnitDefinitions.standaloneUnits, contains('msk'));
    expect(UnitDefinitions.standaloneUnits, contains('cup'));
    expect(UnitDefinitions.standaloneUnits.length, greaterThan(40));
  });

  test('potted and bunched herbs are units ("1 kruka koriander")', () {
    for (final unit in [
      'kruka',
      'krukor',
      'bunt',
      'buntar',
      'knippe',
      'knippen',
    ]) {
      expect(UnitDefinitions.isKnownUnit(unit), isTrue, reason: unit);
    }
  });

  group('canonical (kärnflöde steg 3, p09)', () {
    test('every spelling of a unit becomes its short form', () {
      for (final MapEntry(key: written, value: short) in {
        'Matsked': 'msk',
        'matskedar': 'msk',
        'MSK': 'msk',
        'teskedar': 'tsk',
        'kryddmått': 'krm',
        'styck': 'st',
        'stycken': 'st',
        'deciliter': 'dl',
        'gram': 'g',
        'kilo': 'kg',
        'klyftor': 'klyfta',
        'förpackning': 'förp',
        ' dl ': 'dl',
      }.entries) {
        expect(UnitDefinitions.canonical(written), short, reason: written);
      }
    });

    test('a count noun keeps its plural for the list to show', () {
      expect(UnitDefinitions.canonical('skivor'), 'skivor');
      expect(UnitDefinitions.canonical('kvistar'), 'kvistar');
    });

    test('an unknown unit comes back lowercased, unchanged', () {
      expect(UnitDefinitions.canonical('Näve2'), 'näve2');
      expect(UnitDefinitions.canonical(''), '');
    });

    test('every short form is itself a known unit', () {
      for (final written in UnitDefinitions.standaloneUnits) {
        final short = UnitDefinitions.canonical(written);
        expect(UnitDefinitions.isKnownUnit(short), isTrue, reason: written);
        expect(UnitDefinitions.canonical(short), short, reason: written);
      }
    });

    test("the parsing pipeline's unit list is known here too", () {
      for (final unit in kSwedishUnits) {
        expect(UnitDefinitions.isKnownUnit(unit), isTrue, reason: unit);
      }
    });

    test('every spelling of a spoon converts the same', () {
      expect(UnitDefinitions.baseFactor('matsked'), (15.0, 'ml'));
      expect(UnitDefinitions.baseFactor('msk'), (15.0, 'ml'));
      expect(UnitDefinitions.baseFactor('Deciliter'), (100.0, 'ml'));
      expect(UnitDefinitions.baseFactor('kilo'), (1000.0, 'g'));
      expect(UnitDefinitions.baseFactor('st'), isNull);
    });
  });
}
