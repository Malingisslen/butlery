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

      expect(
        prefs.trackedAllergens,
        UserAllergenPreferences.defaults.trackedAllergens,
      );
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

  group(
    'includeUnknownInMenu default (Malin 2026-10-05: OFF with an allergy)',
    () {
      const withAllergy = UserAllergenPreferences(
        trackedAllergens: {'nötter'},
        trackedDietary: {},
      );
      const dietOnly = UserAllergenPreferences(
        trackedAllergens: {},
        trackedDietary: {'vegansk'},
      );
      const nothing = UserAllergenPreferences(
        trackedAllergens: {},
        trackedDietary: {},
      );

      test('undecided and tracking an allergen reads false', () {
        expect(withAllergy.includeUnknownInMenu, isFalse);
        expect(withAllergy.includeUnknownInMenuChoice, isNull);
      });

      test('undecided with only a diet, or nothing at all, reads true', () {
        expect(dietOnly.includeUnknownInMenu, isTrue);
        expect(nothing.includeUnknownInMenu, isTrue);
      });

      test('an explicit answer wins over the derived default, both ways', () {
        expect(
          withAllergy.copyWith(includeUnknownInMenu: true).includeUnknownInMenu,
          isTrue,
        );
        expect(
          nothing.copyWith(includeUnknownInMenu: false).includeUnknownInMenu,
          isFalse,
        );
      });

      test('ticking the first allergen flips an undecided switch off, and '
          'unticking the last flips it back on', () {
        final ticked = nothing.trackAllergen('gluten');
        expect(ticked.includeUnknownInMenuChoice, isNull);
        expect(ticked.includeUnknownInMenu, isFalse);
        expect(ticked.untrackAllergen('gluten').includeUnknownInMenu, isTrue);
      });

      test('defaults suggest four allergens and therefore read false', () {
        expect(
          UserAllergenPreferences.defaults.includeUnknownInMenuChoice,
          isNull,
        );
        expect(UserAllergenPreferences.defaults.includeUnknownInMenu, isFalse);
      });

      test('fromFirestore keeps a stored bool and treats anything else as '
          'undecided', () {
        Map<String, dynamic> doc(Object? value) => {
          'trackedAllergens': ['gluten'],
          'trackedDietary': <String>[],
          if (value != 'ABSENT') 'includeUnknownInMenu': value,
        };

        expect(
          UserAllergenPreferences.fromFirestore(doc(true)).includeUnknownInMenu,
          isTrue,
        );
        expect(
          UserAllergenPreferences.fromFirestore(
            doc(false),
          ).includeUnknownInMenuChoice,
          isFalse,
        );
        expect(
          UserAllergenPreferences.fromFirestore(
            doc(null),
          ).includeUnknownInMenuChoice,
          isNull,
        );
        expect(
          UserAllergenPreferences.fromFirestore(
            doc('true'),
          ).includeUnknownInMenuChoice,
          isNull,
        );
        expect(
          UserAllergenPreferences.fromFirestore(
            doc('ABSENT'),
          ).includeUnknownInMenu,
          isFalse,
        );
      });

      test('toFirestore writes the raw answer, null included, so a merge write '
          'clears an earlier explicit one', () {
        expect(withAllergy.toFirestore()['includeUnknownInMenu'], isNull);
        expect(
          withAllergy.toFirestore().containsKey('includeUnknownInMenu'),
          isTrue,
        );
        expect(
          withAllergy
              .copyWith(includeUnknownInMenu: true)
              .toFirestore()['includeUnknownInMenu'],
          isTrue,
        );
      });

      test('equality distinguishes undecided from an explicit answer', () {
        expect(
          withAllergy,
          isNot(withAllergy.copyWith(includeUnknownInMenu: false)),
        );
        expect(
          withAllergy,
          const UserAllergenPreferences(
            trackedAllergens: {'nötter'},
            trackedDietary: {},
          ),
        );
      });
    },
  );
}
