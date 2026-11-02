library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/tagging/ingredient_allergen_impact.dart';
import 'package:butlery/models/tagging/ingredient_column.dart';
import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/services/tagging/ingredient_change_validator.dart';

IngredientData _row({Set<String> properties = const {'dairy'}}) =>
    IngredientData(
      id: 'milk',
      swedish: 'mjölk',
      english: 'milk',
      group: 'protein/dairy',
      properties: properties,
    );

Set<IngredientIssueCode> _codes(
  IngredientColumn column,
  Object? value, {
  IngredientData? row,
}) => {
  for (final i
      in validateIngredientChanges(row ?? _row(), {
            column: value,
          }).issues[column] ??
          const <IngredientFieldIssue>[])
    i.code,
};

void main() {
  group('text rules', () {
    test('swedish may not be empty, but a name passes', () {
      expect(_codes(IngredientColumn.swedish, '  '), {
        IngredientIssueCode.empty,
      });
      expect(_codes(IngredientColumn.swedish, 'mjölk'), isEmpty);
    });

    test('length limit is 300', () {
      expect(_codes(IngredientColumn.notesSv, 'a' * 300), isEmpty);
      expect(_codes(IngredientColumn.notesSv, 'a' * 301), {
        IngredientIssueCode.tooLong,
      });
    });

    test('line breaks and control characters are refused', () {
      expect(_codes(IngredientColumn.english, 'a\nb'), {
        IngredientIssueCode.controlCharacter,
      });
      expect(_codes(IngredientColumn.english, 'a\u0007'), {
        IngredientIssueCode.controlCharacter,
      });
      expect(_codes(IngredientColumn.english, 'a b'), isEmpty);
    });

    test('group needs a known prefix as a path segment', () {
      expect(_codes(IngredientColumn.group, 'fruit/berry'), isEmpty);
      expect(_codes(IngredientColumn.group, 'spice'), isEmpty);
      expect(_codes(IngredientColumn.group, 'pantry/flour'), {
        IngredientIssueCode.invalidGroup,
      });
      expect(_codes(IngredientColumn.group, 'proteinx'), {
        IngredientIssueCode.invalidGroup,
      });
      expect(_codes(IngredientColumn.group, ''), {
        IngredientIssueCode.invalidGroup,
      });
    });

    test('status, price class and climate use their vocabularies', () {
      for (final s in kProposableStatuses) {
        expect(_codes(IngredientColumn.status, s), isEmpty);
      }
      expect(_codes(IngredientColumn.status, 'deleted'), {
        IngredientIssueCode.invalidStatus,
      });
      expect(_codes(IngredientColumn.status, ''), {
        IngredientIssueCode.invalidStatus,
      });
      expect(_codes(IngredientColumn.priceCategory, 'premium'), isEmpty);
      expect(_codes(IngredientColumn.priceCategory, ''), isEmpty);
      expect(_codes(IngredientColumn.priceCategory, 'low'), {
        IngredientIssueCode.invalidPriceCategory,
      });
      expect(_codes(IngredientColumn.carbonFootprintCategory, 'high'), isEmpty);
      expect(_codes(IngredientColumn.carbonFootprintCategory, ''), isEmpty);
      expect(_codes(IngredientColumn.carbonFootprintCategory, 'huge'), {
        IngredientIssueCode.invalidCarbonCategory,
      });
    });
  });

  group('list rules', () {
    test('separators in an element are refused, one per kind', () {
      for (final bad in ['a;b', 'a|b', 'a,b']) {
        expect(_codes(IngredientColumn.aliasesSv, [bad]), {
          IngredientIssueCode.separatorInElement,
        });
      }
      expect(_codes(IngredientColumn.aliasesSv, ['a', 'b c']), isEmpty);
      // The sync does not split on a comma before a digit.
      expect(_codes(IngredientColumn.aliasesSv, ['lättmjölk 0,5%']), isEmpty);
    });

    test('at most 30 elements', () {
      expect(
        _codes(IngredientColumn.searchTerms, [
          for (var i = 0; i < 30; i++) 'x$i',
        ]),
        isEmpty,
      );
      expect(
        _codes(IngredientColumn.searchTerms, [
          for (var i = 0; i < 31; i++) 'x$i',
        ]),
        {IngredientIssueCode.tooManyElements},
      );
    });

    test('element length, control characters and empties', () {
      expect(_codes(IngredientColumn.aliasesEn, ['a' * 301]), {
        IngredientIssueCode.tooLong,
      });
      expect(_codes(IngredientColumn.aliasesEn, ['a\tb']), {
        IngredientIssueCode.controlCharacter,
      });
      expect(_codes(IngredientColumn.aliasesEn, ['a', ' ']), {
        IngredientIssueCode.empty,
      });
    });

    test('properties must be in the sync vocabulary', () {
      expect(
        _codes(IngredientColumn.properties, ['dairy', 'processed']),
        isEmpty,
      );
      expect(_codes(IngredientColumn.properties, ['dairy', 'wheat']), {
        IngredientIssueCode.unknownProperty,
      });
      // Known to the app registry, rejected by the sync.
      expect(_codes(IngredientColumn.properties, ['raw-safe']), {
        IngredientIssueCode.unknownProperty,
      });
    });
  });

  group('price', () {
    test('null and non-negative finite numbers pass', () {
      expect(_codes(IngredientColumn.avgPriceSek, null), isEmpty);
      expect(_codes(IngredientColumn.avgPriceSek, 0.0), isEmpty);
      expect(_codes(IngredientColumn.avgPriceSek, 12.5), isEmpty);
    });

    test('negative, NaN and infinity are refused', () {
      for (final bad in [-1.0, double.nan, double.infinity]) {
        expect(_codes(IngredientColumn.avgPriceSek, bad), {
          IngredientIssueCode.invalidPrice,
        });
      }
    });
  });

  group('allergen impact', () {
    bool affects(Set<String> before, List<String> after) =>
        validateIngredientChanges(_row(properties: before), {
          IngredientColumn.properties: after,
        }).affectsAllergens;

    test(
      'removing an allergen property flags, removing a neutral one does not',
      () {
        expect(
          affects({'dairy', 'animal-product'}, ['animal-product']),
          isTrue,
        );
        expect(affects({'dairy', 'needs-cooking'}, ['dairy']), isFalse);
      },
    );

    test('adding a property that is not a vegan claim does not flag', () {
      expect(affects({'dairy'}, ['dairy', 'needs-cooking']), isFalse);
    });

    test('vegan claim on an animal or allergen row flags', () {
      expect(affects({'meat'}, ['meat', 'vegan-friendly']), isTrue);
      expect(affects({'dairy'}, ['dairy', 'plant-based']), isTrue);
      expect(
        affects({'animal-product'}, ['animal-product', 'vegan-friendly']),
        isTrue,
      );
      expect(affects({'peanut'}, ['peanut', 'vegan-friendly']), isTrue);
    });

    test(
      'vegan claim on a row without animal or allergen property does not flag',
      () {
        expect(
          affects({'needs-cooking'}, ['needs-cooking', 'vegan-friendly']),
          isFalse,
        );
      },
    );

    test('no properties change means no flag', () {
      expect(
        validateIngredientChanges(_row(), {
          IngredientColumn.english: 'Milk',
        }).affectsAllergens,
        isFalse,
      );
    });

    test('the allergen set carries the tagger triggers and both umbrellas', () {
      expect(
        kAllergenRelevantProperties,
        containsAll([
          'contains-gluten',
          'dairy',
          'seafood',
          'shellfish',
          'pork',
        ]),
      );
    });
  });

  test('a clean proposal is valid', () {
    final v = validateIngredientChanges(_row(), {
      IngredientColumn.english: 'Milk',
      IngredientColumn.status: 'verified',
    });
    expect(v.isValid, isTrue);
  });
}
