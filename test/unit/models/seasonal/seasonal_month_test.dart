/// Direct unit tests for [SeasonalMonth] (BUT-1149 coverage burndown —
/// previously zero direct coverage).
///
/// Parses one month entry from the seasonal JSON asset. The contract: validate
/// required fields (throwing FormatException so the service can degrade to "no
/// hero"), lowercase ingredient names, map vegetableType by name with a broccoli
/// fallback, and ignore unknown keys (curation data lives alongside).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/seasonal/seasonal_month.dart';
import 'package:butlery/widgets/common/illustrations/vegetable_illustration.dart';

Map<String, dynamic> validJson() => {
  'monthIndex': 4,
  'monthKey': 'april',
  'ingredients': ['Sparris', 'KÅL'],
  'vegetableType': 'carrot',
};

void main() {
  group('fromJson (valid)', () {
    test('parses fields and lowercases ingredients', () {
      final m = SeasonalMonth.fromJson(validJson());
      expect(m.monthIndex, 4);
      expect(m.monthKey, 'april');
      expect(m.ingredients, ['sparris', 'kål']);
      expect(m.vegetableType, VegetableType.carrot);
    });

    test('unknown vegetableType falls back to broccoli', () {
      final m = SeasonalMonth.fromJson(validJson()..['vegetableType'] = 'nope');
      expect(m.vegetableType, VegetableType.broccoli);
    });

    test('ignores unknown keys (e.g. gradient)', () {
      final m = SeasonalMonth.fromJson(validJson()..['gradient'] = ['#fff']);
      expect(m.monthKey, 'april');
    });
  });

  group('fromJson (invalid → FormatException)', () {
    test('monthIndex not an int / out of range', () {
      expect(
        () => SeasonalMonth.fromJson(validJson()..['monthIndex'] = 'x'),
        throwsFormatException,
      );
      expect(
        () => SeasonalMonth.fromJson(validJson()..['monthIndex'] = 0),
        throwsFormatException,
      );
      expect(
        () => SeasonalMonth.fromJson(validJson()..['monthIndex'] = 13),
        throwsFormatException,
      );
    });

    test('monthKey missing or empty', () {
      final j = validJson()..remove('monthKey');
      expect(() => SeasonalMonth.fromJson(j), throwsFormatException);
      expect(
        () => SeasonalMonth.fromJson(validJson()..['monthKey'] = ''),
        throwsFormatException,
      );
    });

    test('ingredients missing, not a list, or empty', () {
      expect(
        () => SeasonalMonth.fromJson(validJson()..['ingredients'] = 'x'),
        throwsFormatException,
      );
      expect(
        () => SeasonalMonth.fromJson(validJson()..['ingredients'] = <String>[]),
        throwsFormatException,
      );
    });

    test('vegetableType not a string', () {
      expect(
        () => SeasonalMonth.fromJson(validJson()..['vegetableType'] = 5),
        throwsFormatException,
      );
    });
  });
}
