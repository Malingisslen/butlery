// BUT-2307: onboarding and Settings read one allergen list, and the diets
// "glutenfri"/"laktosfri" that old onboarding stored become allergens.

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/household_allergen_share.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/services/tagging/config/allergen_config.dart';
import 'package:butlery/services/tagging/config/dietary_config.dart';

void main() {
  group('one allergen list', () {
    test('every key is a tagging allergen, nothing is a diet', () {
      final tagging = AllergenConfig.allKeys.toSet();
      final dietKeys = DietaryConfig.all.map((d) => d.key).toSet();
      for (final key in AllergenPreferenceOptions.allergens.keys) {
        expect(tagging, contains(key));
        expect(dietKeys, isNot(contains(key)));
      }
    });

    test('Settings offers kräftdjur and blötdjur and the meat keys', () {
      expect(
        AllergenPreferenceOptions.allergens.keys,
        containsAll([
          'kräftdjur',
          'blötdjur',
          'kött',
          'fläsk',
          'nötkött',
          'alkohol',
        ]),
      );
    });

    test('onboarding "visa alla" equals the Settings list', () {
      final all = [
        ...AllergenPreferenceOptions.primaryAllergenKeys,
        ...AllergenPreferenceOptions.extendedAllergenKeys,
      ];
      expect(all.toSet(), AllergenPreferenceOptions.allergens.keys.toSet());
      expect(all.length, all.toSet().length);
    });
  });

  group('legacy diets', () {
    test('glutenfri and laktosfri move to gluten and laktos on load', () {
      final prefs = UserAllergenPreferences.fromFirestore({
        'trackedAllergens': ['ägg'],
        'trackedDietary': ['vegetarisk', 'glutenfri', 'laktosfri'],
      });
      expect(prefs.trackedAllergens, {'ägg', 'gluten', 'laktos'});
      expect(prefs.trackedDietary, {'vegetarisk'});
    });

    test('untouched preferences stay as they are', () {
      final prefs = UserAllergenPreferences.fromFirestore({
        'trackedAllergens': ['mjölk'],
        'trackedDietary': ['vegansk'],
      });
      expect(prefs.trackedAllergens, {'mjölk'});
      expect(prefs.trackedDietary, {'vegansk'});
    });

    test('a household share is mapped the same way', () {
      final share = HouseholdAllergenShare.fromMap('x', {
        'trackedAllergens': <String>[],
        'trackedDietary': ['glutenfri'],
      });
      expect(share.trackedAllergens, {'gluten'});
      expect(share.trackedDietary, isEmpty);
    });
  });
}
