/// Unit tests for HouseholdAllergenShare (BUT-1693).
///
/// The feature rests on one distinction: a member with NO document has not
/// shared and keeps BUT-1663's four-allergen safety floor, while a member with
/// a document and an EMPTY list has declared that they have no allergies. Every
/// test here defends one half of that, or the consent record that decides
/// whether the document counts as a declaration at all.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/household_allergen_share.dart';
import 'package:butlery/models/user_allergen_preferences.dart';

/// A stored document. A null argument means the KEY IS ABSENT, which is the
/// case each test is about — so the map is built and then stripped, rather than
/// written with conditional entries that would blur absent and null.
Map<String, dynamic> _doc({
  Object? allergens,
  Object? dietary,
  Object? consentGranted = true,
  Object? consentVersion = 'v1',
  Object? consentGrantedAt = 'seed',
}) {
  final map = <String, dynamic>{
    'householdId': 'hh',
    'userId': 'u',
    'trackedAllergens': allergens,
    'trackedDietary': dietary,
    'consentGranted': consentGranted,
    'consentVersion': consentVersion,
    'consentGrantedAt': consentGrantedAt == 'seed'
        ? Timestamp.fromDate(DateTime.utc(2026, 8, 12))
        : consentGrantedAt,
  };
  map.removeWhere((_, value) => value == null);
  return map;
}

void main() {
  group('HouseholdAllergenShare parsing', () {
    test(
      'a document with NO allergen keys parses as no allergies, never the '
      'four defaults',
      () {
        // The trap this whole model exists to avoid:
        // UserAllergenPreferences.fromFirestore returns `defaults` for an
        // absent map, so routing this through it would manufacture gluten,
        // mjölk, nötter and jordnötter for a member who declared none.
        final share = HouseholdAllergenShare.fromMap('hh_u', _doc());

        expect(share.trackedAllergens, isEmpty);
        expect(share.trackedDietary, isEmpty);
        expect(
          share.toPreferences().trackedAllergens,
          isNot(UserAllergenPreferences.defaults.trackedAllergens),
        );
      },
    );

    test('an explicitly empty list is still no allergies', () {
      final share = HouseholdAllergenShare.fromMap(
        'hh_u',
        _doc(allergens: <String>[], dietary: <String>[]),
      );

      expect(share.trackedAllergens, isEmpty);
      expect(share.isValidConsent, isTrue, reason: 'empty is a declaration');
    });

    test('legacy ASCII allergen keys are normalised to Swedish', () {
      // A raw `mjolk` would match nothing downstream, so the allergen would
      // silently disappear from the household union instead of failing loud.
      final share = HouseholdAllergenShare.fromMap(
        'hh_u',
        _doc(allergens: ['mjolk', 'agg', 'skaldjur']),
      );

      expect(share.trackedAllergens, {'mjölk', 'ägg', 'skaldjur'});
    });

    test('includeUnknownInMenu fails SAFE when the flag is missing', () {
      final share = HouseholdAllergenShare.fromMap('hh_u', _doc());

      expect(
        share.includeUnknownInMenu,
        isFalse,
        reason:
            'a missing flag must exclude unverified recipes, not admit them',
      );
    });
  });

  group('toPreferences is the seam the menu filter will consume', () {
    test('carries the three filtering fields through unchanged', () {
      // The only seam between a share and menu generation. Hardcoding
      // includeUnknownInMenu to true here would silently drop a member's
      // "exclude unverified recipes" caution — unsafe in the one direction
      // that matters — and swapping the two sets would filter on the wrong
      // vocabulary entirely.
      final prefs = HouseholdAllergenShare.fromMap(
        'hh_u',
        _doc(allergens: ['ägg'], dietary: ['vegansk'])
          ..['includeUnknownInMenu'] = false,
      ).toPreferences();

      expect(prefs.trackedAllergens, {'ägg'});
      expect(prefs.trackedDietary, {'vegansk'});
      expect(prefs.includeUnknownInMenu, isFalse);
    });

    test(
      'a shared true is carried through, not flattened to the safe default',
      () {
        // Every other assertion on this flag is `isFalse`, so a `fromMap` or
        // `toPreferences` stuck on the cautious value would go unnoticed. The
        // direction is safe — it over-filters — but it discards a member's
        // stated willingness to eat unverified recipes.
        final prefs = HouseholdAllergenShare.fromMap(
          'hh_u',
          _doc()..['includeUnknownInMenu'] = true,
        ).toPreferences();

        expect(prefs.includeUnknownInMenu, isTrue);
      },
    );
  });

  group('consent decides whether the document is a declaration', () {
    test('a missing consent flag is not consent', () {
      final share = HouseholdAllergenShare.fromMap(
        'hh_u',
        _doc(consentGranted: null),
      );

      expect(share.consentGranted, isFalse);
      expect(share.isValidConsent, isFalse);
    });

    test('consent with no readable timestamp is not a consent record', () {
      final share = HouseholdAllergenShare.fromMap(
        'hh_u',
        _doc(consentGrantedAt: null),
      );

      expect(share.consentGrantedAt, isNull);
      expect(share.isValidConsent, isFalse);
    });

    test('consent with no version is not a consent record', () {
      final share = HouseholdAllergenShare.fromMap(
        'hh_u',
        _doc(consentVersion: null),
      );

      expect(share.isValidConsent, isFalse);
    });
  });

  group('wire format', () {
    test('dates are written as Firestore Timestamps, not strings', () {
      // An ISO string cannot be type-checked or bounded against request.time
      // in firestore.rules, and the format stops being free to change once the
      // first document exists.
      final map = HouseholdAllergenShare(
        householdId: 'hh',
        userId: 'u',
        trackedAllergens: const {'ägg'},
        trackedDietary: const {},
        includeUnknownInMenu: true,
        consentGranted: true,
        consentVersion: HouseholdAllergenShare.currentConsentVersion,
        consentGrantedAt: DateTime.utc(2026, 8, 12),
        updatedAt: DateTime.utc(2026, 8, 12),
      ).toFirestore();

      expect(map['consentGrantedAt'], isA<Timestamp>());
      expect(map['updatedAt'], isA<Timestamp>());
    });

    test('a null date is omitted, not stored as null', () {
      final map = HouseholdAllergenShare(
        householdId: 'hh',
        userId: 'u',
        trackedAllergens: const {},
        trackedDietary: const {},
        includeUnknownInMenu: false,
        consentGranted: false,
        consentVersion: '',
        consentGrantedAt: null,
        updatedAt: null,
      ).toFirestore();

      expect(map.containsKey('consentGrantedAt'), isFalse);
      expect(map.containsKey('updatedAt'), isFalse);
    });

    test('toFirestore -> fromMap preserves the consent record', () {
      final original = HouseholdAllergenShare(
        householdId: 'hh',
        userId: 'u',
        trackedAllergens: const {'ägg'},
        trackedDietary: const {'vegansk'},
        includeUnknownInMenu: true,
        consentGranted: true,
        consentVersion: HouseholdAllergenShare.currentConsentVersion,
        consentGrantedAt: DateTime.utc(2026, 8, 12, 9, 30),
        updatedAt: DateTime.utc(2026, 8, 12, 9, 30),
      );

      final restored = HouseholdAllergenShare.fromMap(
        original.id,
        original.toFirestore(),
      );

      // Compared as instants: a Firestore Timestamp round-trips to a LOCAL
      // DateTime, so an equality check on the object would fail on any machine
      // that is not on UTC — and would be measuring the test's timezone, not
      // the serializer.
      expect(
        restored.consentGrantedAt!.toUtc(),
        original.consentGrantedAt!.toUtc(),
      );
      expect(restored.trackedAllergens, original.trackedAllergens);
      expect(restored.trackedDietary, original.trackedDietary);
      expect(restored.isValidConsent, isTrue);
    });

    test('the document id is derived, so one member holds one share', () {
      expect(HouseholdAllergenShare.documentId('hh', 'u'), 'hh_u');
    });
  });
}
