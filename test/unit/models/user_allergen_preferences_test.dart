import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/user_allergen_preferences.dart';

void main() {
  group('UserAllergenPreferences.fromFirestore', () {
    test('normalizes ASCII allergen keys to Swedish characters', () {
      final data = {
        'trackedAllergens': ['gluten', 'mjolk', 'notter', 'agg'],
        'trackedDietary': ['vegetarisk'],
      };

      final prefs = UserAllergenPreferences.fromFirestore(data);

      expect(prefs.trackedAllergens, contains('mjölk'));
      expect(prefs.trackedAllergens, contains('nötter'));
      expect(prefs.trackedAllergens, contains('ägg'));
      expect(prefs.trackedAllergens, contains('gluten'));
      expect(prefs.trackedAllergens, isNot(contains('mjolk')));
      expect(prefs.trackedAllergens, isNot(contains('notter')));
      expect(prefs.trackedAllergens, isNot(contains('agg')));
    });

    test('normalizes all known ASCII keys', () {
      final data = {
        'trackedAllergens': [
          'tradnotter',
          'kraftdjur',
          'blotdjur',
          'kott',
          'flask',
          'notkott',
        ],
        'trackedDietary': <String>[],
      };

      final prefs = UserAllergenPreferences.fromFirestore(data);

      expect(prefs.trackedAllergens, contains('trädnötter'));
      expect(prefs.trackedAllergens, contains('kräftdjur'));
      expect(prefs.trackedAllergens, contains('blötdjur'));
      expect(prefs.trackedAllergens, contains('kött'));
      expect(prefs.trackedAllergens, contains('fläsk'));
      expect(prefs.trackedAllergens, contains('nötkött'));
    });

    test('preserves already-correct Swedish keys', () {
      final data = {
        'trackedAllergens': ['mjölk', 'nötter', 'ägg', 'gluten'],
        'trackedDietary': ['vegansk'],
      };

      final prefs = UserAllergenPreferences.fromFirestore(data);

      expect(prefs.trackedAllergens, {'mjölk', 'nötter', 'ägg', 'gluten'});
    });

    test('deduplicates when both ASCII and Swedish keys present', () {
      final data = {
        'trackedAllergens': ['mjolk', 'mjölk', 'agg', 'ägg'],
        'trackedDietary': <String>[],
      };

      final prefs = UserAllergenPreferences.fromFirestore(data);

      expect(prefs.trackedAllergens, {'mjölk', 'ägg'});
    });

    test('returns defaults when data is null', () {
      final prefs = UserAllergenPreferences.fromFirestore(null);

      expect(prefs.trackedAllergens,
          UserAllergenPreferences.defaults.trackedAllergens);
    });

    test('does not alter dietary keys', () {
      final data = {
        'trackedAllergens': ['gluten'],
        'trackedDietary': ['vegetarisk', 'vegansk'],
      };

      final prefs = UserAllergenPreferences.fromFirestore(data);

      expect(prefs.trackedDietary, {'vegetarisk', 'vegansk'});
    });
  });
}
