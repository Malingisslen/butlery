/// Unit tests for UnitDefinitions.
library;

import 'package:flutter_test/flutter_test.dart';

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
}
