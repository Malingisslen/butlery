import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/services/tagging/config/allergen_config.dart';

void main() {
  final canonicalKeys = AllergenConfig.allKeys.toSet();

  group('Allergen key consistency', () {
    test(
        'should have AllergenPreferenceOptions keys as subset of AllergenConfig',
        () {
      final optionKeys = AllergenPreferenceOptions.allergens.keys.toSet();
      final missing = optionKeys.difference(canonicalKeys);

      expect(missing, isEmpty,
          reason: 'AllergenPreferenceOptions contains keys not in '
              'AllergenConfig.all: $missing');
    });

    test(
        'should have AllergenConfig keys covered by AllergenPreferenceOptions or a UI group',
        () {
      final optionKeys = AllergenPreferenceOptions.allergens.keys.toSet();
      final groupedKeys = AllergenConfig.all
          .where((a) => a.uiGroup != null)
          .map((a) => a.key)
          .toSet();

      // Keys must appear in options directly OR belong to a UI group
      // (grouped keys like kräftdjur/blötdjur are exposed via skaldjur)
      final uncovered =
          canonicalKeys.difference(optionKeys).difference(groupedKeys);

      expect(uncovered, isEmpty,
          reason: 'AllergenConfig.all contains keys not in '
              'AllergenPreferenceOptions and not covered by a UI group: $uncovered');
    });

    test(
        'should have UserAllergenPreferences defaults as subset of AllergenConfig',
        () {
      final defaultKeys = UserAllergenPreferences.defaults.trackedAllergens;
      final missing = defaultKeys.difference(canonicalKeys);

      expect(missing, isEmpty,
          reason: 'UserAllergenPreferences.defaults contains keys not in '
              'AllergenConfig.all: $missing');
    });

    // OnboardingAllergenPage._allergenIcons is private; hardcode known keys
    // so drift is caught. Update this list if the onboarding page changes.
    test(
        'should have onboarding allergen page keys as subset of AllergenConfig',
        () {
      const onboardingKeys = {
        'gluten',
        'mjölk',
        'nötter',
        'ägg',
        'soja',
        'fisk',
        'skaldjur',
        'sesam',
      };
      final missing = onboardingKeys.difference(canonicalKeys);

      expect(missing, isEmpty,
          reason: 'OnboardingAllergenPage._allergenIcons contains keys not in '
              'AllergenConfig.all: $missing. '
              'Verify lib/views/onboarding/onboarding_allergen_page.dart');
    });

    // CompactAllergenRow._defaultAllergens is private; hardcode known keys.
    test('should have CompactAllergenRow defaults as subset of AllergenConfig',
        () {
      const compactRowDefaults = {
        'gluten',
        'mjölk',
        'nötter',
        'ägg',
      };
      final missing = compactRowDefaults.difference(canonicalKeys);

      expect(missing, isEmpty,
          reason: 'CompactAllergenRow._defaultAllergens contains keys not in '
              'AllergenConfig.all: $missing. '
              'Verify lib/widgets/tagging/tag_result_display.dart');
    });

    test('should have no duplicate keys in AllergenConfig', () {
      final keys = AllergenConfig.allKeys;
      final duplicates = keys.toList()
        ..removeWhere((k) => keys.where((k2) => k2 == k).length == 1);

      expect(duplicates, isEmpty,
          reason: 'AllergenConfig.all has duplicate keys: $duplicates');
    });
  });
}
