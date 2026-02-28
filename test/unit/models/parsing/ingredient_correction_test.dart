import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/parsing/ingredient_correction.dart';

void main() {
  group('IngredientCorrection', () {
    group('correctedName in toJson()', () {
      test('included when set', () {
        const correction = IngredientCorrection(
          type: IngredientCorrectionType.nameFixed,
          originalIndex: 0,
          correctedIndex: 0,
          originalName: 'potatsi',
          correctedName: 'potatis',
          nameChanged: true,
        );

        final json = correction.toJson();
        expect(json['correctedName'], 'potatis');
      });

      test('omitted when null', () {
        const correction = IngredientCorrection(
          type: IngredientCorrectionType.quantityFixed,
          originalIndex: 0,
          correctedIndex: 0,
          quantityChanged: true,
        );

        final json = correction.toJson();
        expect(json.containsKey('correctedName'), isFalse);
      });
    });

    group('correctedName in fromJson()', () {
      test('parses when present', () {
        final json = {
          'type': 'nameFixed',
          'originalIndex': 0,
          'correctedIndex': 0,
          'originalName': 'potatsi',
          'correctedName': 'potatis',
          'nameChanged': true,
        };

        final correction = IngredientCorrection.fromJson(json);
        expect(correction.correctedName, 'potatis');
      });

      test('handles missing field (backward compat)', () {
        final json = {
          'type': 'nameFixed',
          'originalIndex': 0,
          'correctedIndex': 0,
          'originalName': 'potatsi',
          'nameChanged': true,
        };

        final correction = IngredientCorrection.fromJson(json);
        expect(correction.correctedName, isNull);
      });
    });

    group('factories', () {
      test('modified() passes correctedName through', () {
        final correction = IngredientCorrection.modified(
          originalIndex: 0,
          correctedIndex: 0,
          originalLine: '3 dl potatsi',
          correctedLine: '3 dl potatis',
          originalName: 'potatsi',
          correctedName: 'potatis',
          quantityChanged: false,
          unitChanged: false,
          nameChanged: true,
        );

        expect(correction.correctedName, 'potatis');
        expect(correction.type, IngredientCorrectionType.nameFixed);
      });

      test('added() has correctedName as null', () {
        final correction = IngredientCorrection.added(
          correctedIndex: 0,
          correctedLine: '2 dl mjöl',
        );

        expect(correction.correctedName, isNull);
      });

      test('removed() has correctedName as null', () {
        final correction = IngredientCorrection.removed(
          originalIndex: 0,
          originalLine: '1 st ägg',
          originalName: 'ägg',
        );

        expect(correction.correctedName, isNull);
      });
    });

    group('roundtrip', () {
      test('toJson/fromJson preserves correctedName', () {
        final original = IngredientCorrection.modified(
          originalIndex: 2,
          correctedIndex: 2,
          originalLine: '500g kycklign',
          correctedLine: '500g kyckling',
          originalName: 'kycklign',
          correctedName: 'kyckling',
          quantityChanged: false,
          unitChanged: false,
          nameChanged: true,
        );

        final json = original.toJson();
        final restored = IngredientCorrection.fromJson(json);

        expect(restored.correctedName, original.correctedName);
        expect(restored.originalName, original.originalName);
        expect(restored.nameChanged, original.nameChanged);
        expect(restored.type, original.type);
      });
    });
  });
}
