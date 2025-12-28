import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/tagging/config/dietary_config.dart';

void main() {
  group('DietaryConfig', () {
    group('all dietary entries', () {
      test('contains core dietary restrictions', () {
        final allKeys = DietaryConfig.all.map((d) => d.key).toSet();

        expect(allKeys, contains('vegetarisk'));
        expect(allKeys, contains('vegansk'));
        expect(allKeys, contains('pescetarian'));
        expect(allKeys, contains('halalanpassad'));
        expect(allKeys, contains('kosheranpassad'));
      });

      test('contains safety-related dietary restrictions', () {
        final allKeys = DietaryConfig.all.map((d) => d.key).toSet();

        expect(allKeys, contains('graviditetssäker'));
        expect(allKeys, contains('barnvänlig'));
      });

      test('contains meat-specific restrictions', () {
        final allKeys = DietaryConfig.all.map((d) => d.key).toSet();

        expect(allKeys, contains('nötkötsfri'));
        // Note: fläskfri is handled via halalanpassad which excludes pork
      });
    });

    group('getByKey', () {
      test('returns dietary entry for valid key', () {
        final veg = DietaryConfig.getByKey('vegetarisk');
        expect(veg, isNotNull);
        expect(veg!.key, 'vegetarisk');
      });

      test('returns null for invalid key', () {
        final result = DietaryConfig.getByKey('nonexistent');
        expect(result, isNull);
      });
    });

    group('dietary entry properties', () {
      test('vegetarisk excludes meat and seafood', () {
        final veg = DietaryConfig.getByKey('vegetarisk')!;

        expect(veg.excludedProperties, contains('meat'));
        expect(veg.excludedProperties, contains('seafood'));
      });

      test('vegansk excludes animal products', () {
        final vegan = DietaryConfig.getByKey('vegansk')!;

        // Vegan uses the umbrella property 'animal-product' which covers
        // all animal-derived ingredients (meat, dairy, egg, etc.)
        expect(vegan.excludedProperties, contains('animal-product'));
      });

      test('pescetarian requires seafood', () {
        final pesc = DietaryConfig.getByKey('pescetarian')!;

        expect(pesc.requiredProperties, isNotNull);
        expect(pesc.requiredProperties, contains('fish'));
      });

      test('pescetarian excludes meat', () {
        final pesc = DietaryConfig.getByKey('pescetarian')!;

        expect(pesc.excludedProperties, contains('meat'));
      });

      test('halalanpassad excludes pork and alcohol', () {
        final halal = DietaryConfig.getByKey('halalanpassad')!;

        expect(halal.excludedProperties, contains('pork'));
        expect(halal.excludedProperties, contains('contains-alcohol'));
      });

      test('kosheranpassad excludes pork and shellfish', () {
        final kosher = DietaryConfig.getByKey('kosheranpassad')!;

        expect(kosher.excludedProperties, contains('pork'));
        expect(kosher.excludedProperties, contains('shellfish'));
      });

      test('graviditetssäker excludes high-mercury fish and alcohol', () {
        final preg = DietaryConfig.getByKey('graviditetssäker')!;

        expect(preg.excludedProperties, contains('high-mercury'));
        expect(preg.excludedProperties, contains('contains-alcohol'));
      });

      test('barnvänlig excludes spicy and alcohol', () {
        final child = DietaryConfig.getByKey('barnvänlig')!;

        expect(child.excludedProperties, contains('is-spicy'));
        expect(child.excludedProperties, contains('contains-alcohol'));
      });
    });

    group('tagSv', () {
      test('all entries have Swedish tag names', () {
        for (final entry in DietaryConfig.all) {
          expect(entry.tagSv, isNotEmpty,
              reason: '${entry.key} should have a Swedish tag name');
        }
      });

      test('vegetarisk has correct Swedish name', () {
        final veg = DietaryConfig.getByKey('vegetarisk')!;
        expect(veg.tagSv, 'vegetarisk');
      });
    });
  });
}
