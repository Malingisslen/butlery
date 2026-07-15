import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/diner_profile.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'helpers/model_test_base.dart';

void main() {
  ModelTestBase.testModelGroup('DinerProfile', () {
    GuardianConsent consentWithAllergens() => GuardianConsent(
      byUid: 'parent_1',
      at: DateTime(2026, 6, 28, 19, 30),
      consentVersion: DinerProfile.currentConsentVersion,
      includesAllergenConsent: true,
    );

    group('DinerAgeBand', () {
      test('minor bands are minors, adult is not', () {
        // Intent: the consent gate keys off isMinor, so this mapping is the
        // contract that decides whether guardian consent is required.
        expect(DinerAgeBand.toddler.isMinor, isTrue);
        expect(DinerAgeBand.child.isMinor, isTrue);
        expect(DinerAgeBand.teen.isMinor, isTrue);
        expect(DinerAgeBand.adult.isMinor, isFalse);
      });

      test('fromName falls back to child for unknown/null', () {
        expect(DinerAgeBand.fromName('teen'), DinerAgeBand.teen);
        expect(DinerAgeBand.fromName('nonsense'), DinerAgeBand.child);
        expect(DinerAgeBand.fromName(null), DinerAgeBand.child);
      });
    });

    group('Construction', () {
      test('create() generates an id and stamps timestamps', () {
        final profile = DinerProfile.create(
          householdId: 'hh_1',
          name: 'Liam',
          ageBand: DinerAgeBand.child,
          createdBy: 'parent_1',
        );

        expect(profile.id, isNotEmpty);
        expect(profile.householdId, 'hh_1');
        expect(profile.name, 'Liam');
        expect(profile.ageBand, DinerAgeBand.child);
        expect(profile.createdBy, 'parent_1');
        expect(profile.createdAt, isNotNull);
        expect(profile.updatedAt, isNotNull);
        expect(profile.schemaVersion, 1);
      });
    });

    group('Consent invariants', () {
      test('isMinor reflects the age band', () {
        final kid = DinerProfile.create(
          householdId: 'hh_1',
          name: 'Liam',
          ageBand: DinerAgeBand.child,
          createdBy: 'parent_1',
        );
        final guest = DinerProfile.create(
          householdId: 'hh_1',
          name: 'Mormor',
          ageBand: DinerAgeBand.adult,
          createdBy: 'parent_1',
        );
        expect(kid.isMinor, isTrue);
        expect(guest.isMinor, isFalse);
      });

      test('hasAllergenConsent is false without explicit allergen consent', () {
        // Intent: allergen data (GDPR Art. 9) must only be stored when the
        // unbundled allergen consent is on record — base consent is not enough.
        final baseConsentOnly = DinerProfile.create(
          householdId: 'hh_1',
          name: 'Liam',
          ageBand: DinerAgeBand.child,
          createdBy: 'parent_1',
          guardianConsent: GuardianConsent(
            byUid: 'parent_1',
            at: DateTime(2026, 6, 28),
            consentVersion: 'v1',
          ),
        );
        expect(baseConsentOnly.hasAllergenConsent, isFalse);
      });

      test('hasAllergenConsent is true when allergen consent given', () {
        final withAllergens = DinerProfile.create(
          householdId: 'hh_1',
          name: 'Liam',
          ageBand: DinerAgeBand.child,
          createdBy: 'parent_1',
          guardianConsent: consentWithAllergens(),
        );
        expect(withAllergens.hasAllergenConsent, isTrue);
      });

      test('no consent at all reads as no allergen consent', () {
        final guest = DinerProfile.create(
          householdId: 'hh_1',
          name: 'Mormor',
          ageBand: DinerAgeBand.adult,
          createdBy: 'parent_1',
        );
        expect(guest.hasAllergenConsent, isFalse);
      });

      test('revoking allergen consent and clearing allergen data', () {
        // Intent: GDPR Art. 9 — withdrawing consent must actually drop the
        // allergen data, and copyWith must be able to CLEAR the nullable field
        // (not just overwrite it). This is the one-tap-withdrawal boundary.
        final consented = DinerProfile.create(
          householdId: 'hh_1',
          name: 'Liam',
          ageBand: DinerAgeBand.child,
          createdBy: 'parent_1',
          allergenPreferences: const UserAllergenPreferences(
            trackedAllergens: {'nötter'},
            trackedDietary: {},
          ),
          guardianConsent: consentWithAllergens(),
        );
        expect(consented.hasAllergenConsent, isTrue);
        expect(consented.allergenPreferences, isNotNull);

        final revoked = consented.copyWith(
          allergenPreferences: null,
          guardianConsent: consented.guardianConsent!.copyWith(
            includesAllergenConsent: false,
          ),
        );

        expect(revoked.hasAllergenConsent, isFalse);
        expect(revoked.allergenPreferences, isNull);
        // Base profile consent record is retained (only the allergen limb drops).
        expect(revoked.guardianConsent, isNotNull);
      });

      test('copyWith with no args preserves nullable fields', () {
        // Guards the sentinel: omitting an arg must NOT clear the field.
        final profile = DinerProfile.create(
          householdId: 'hh_1',
          name: 'Liam',
          ageBand: DinerAgeBand.child,
          createdBy: 'parent_1',
          allergenPreferences: const UserAllergenPreferences(
            trackedAllergens: {'mjölk'},
            trackedDietary: {},
          ),
          guardianConsent: consentWithAllergens(),
        );
        final renamed = profile.copyWith(name: 'Liam B');
        expect(renamed.name, 'Liam B');
        expect(renamed.allergenPreferences, isNotNull);
        expect(renamed.hasAllergenConsent, isTrue);
      });
    });

    group('Disliked ingredients', () {
      // Intent: dislikes are edited via copyWith on the VM's update path
      // (existing.copyWith(dislikedIngredients: ...)). These pin the two
      // behaviours that path depends on: an update replaces the set, and an
      // omitted arg leaves the stored dislikes untouched. Dislikes are ordinary
      // personal data, so none of this is gated behind consent.
      test('copyWith replaces disliked ingredients when provided', () {
        final profile = DinerProfile.create(
          householdId: 'hh_1',
          name: 'Liam',
          ageBand: DinerAgeBand.child,
          createdBy: 'parent_1',
          dislikedIngredients: const {'svamp'},
        );

        final updated = profile.copyWith(
          dislikedIngredients: {'lök', 'oliver'},
        );
        expect(updated.dislikedIngredients, {'lök', 'oliver'});

        // Passing an explicit empty set clears them (the deselect-all path).
        final cleared = profile.copyWith(dislikedIngredients: const {});
        expect(cleared.dislikedIngredients, isEmpty);
      });

      test('copyWith without the arg preserves disliked ingredients', () {
        final profile = DinerProfile.create(
          householdId: 'hh_1',
          name: 'Liam',
          ageBand: DinerAgeBand.child,
          createdBy: 'parent_1',
          dislikedIngredients: const {'svamp', 'lök'},
        );

        final renamed = profile.copyWith(name: 'Liam B');
        expect(renamed.dislikedIngredients, {'svamp', 'lök'});
      });
    });

    group('Firestore round-trip', () {
      test('preserves allergens and consent', () {
        final original = DinerProfile(
          id: 'diner_1',
          householdId: 'hh_1',
          name: 'Liam',
          ageBand: DinerAgeBand.teen,
          avatarColor: '#B5532A',
          allergenPreferences: const UserAllergenPreferences(
            trackedAllergens: {'nötter', 'mjölk'},
            trackedDietary: {'vegetarisk'},
          ),
          guardianConsent: consentWithAllergens(),
          createdBy: 'parent_1',
          createdAt: DateTime(2026, 6, 1),
          updatedAt: DateTime(2026, 6, 28),
        );

        final restored = DinerProfile.fromMap(
          original.id,
          original.toFirestore(),
        );

        expect(restored.id, 'diner_1');
        expect(restored.name, 'Liam');
        expect(restored.ageBand, DinerAgeBand.teen);
        expect(restored.avatarColor, '#B5532A');
        expect(
          restored.allergenPreferences!.trackedAllergens,
          containsAll(<String>['nötter', 'mjölk']),
        );
        expect(restored.guardianConsent!.byUid, 'parent_1');
        expect(restored.guardianConsent!.includesAllergenConsent, isTrue);
        expect(restored.hasAllergenConsent, isTrue);
        expect(restored.createdAt, DateTime(2026, 6, 1));
      });

      test('omits optional fields when absent', () {
        final minimal = DinerProfile.create(
          householdId: 'hh_1',
          name: 'Gäst',
          ageBand: DinerAgeBand.adult,
          createdBy: 'parent_1',
        );

        final map = minimal.toFirestore();
        expect(map.containsKey('allergenPreferences'), isFalse);
        expect(map.containsKey('guardianConsent'), isFalse);
        expect(map.containsKey('avatarColor'), isFalse);
        // Dislikes default to empty and are omitted, keeping the doc minimal.
        expect(map.containsKey('dislikedIngredients'), isFalse);

        final restored = DinerProfile.fromMap('gäst_1', map);
        expect(restored.allergenPreferences, isNull);
        expect(restored.guardianConsent, isNull);
        expect(restored.dislikedIngredients, isEmpty);
      });

      test('preserves disliked ingredients without any consent', () {
        // Intent: dislikes are a soft preference (ordinary personal data), so
        // an adult guest with no consent record still round-trips them — the
        // field is NOT gated behind allergen (Art. 9) consent.
        final original = DinerProfile.create(
          householdId: 'hh_1',
          name: 'Mormor',
          ageBand: DinerAgeBand.adult,
          createdBy: 'parent_1',
          dislikedIngredients: const {'svamp', 'oliver'},
        );

        final map = original.toFirestore();
        expect(
          map['dislikedIngredients'],
          containsAll(<String>['svamp', 'oliver']),
        );
        expect(map.containsKey('guardianConsent'), isFalse);

        final restored = DinerProfile.fromMap('mormor_1', map);
        expect(
          restored.dislikedIngredients,
          containsAll(<String>['svamp', 'oliver']),
        );
        expect(restored.guardianConsent, isNull);
      });
    });

    group('JSON cache round-trip', () {
      test('preserves all fields', () {
        final original = DinerProfile(
          id: 'diner_1',
          householdId: 'hh_1',
          name: 'Emma',
          ageBand: DinerAgeBand.teen,
          guardianConsent: consentWithAllergens(),
          createdBy: 'parent_1',
        );

        final restored = DinerProfile.fromJson(original.toJson());
        expect(restored.id, original.id);
        expect(restored.name, 'Emma');
        expect(restored.ageBand, DinerAgeBand.teen);
        expect(restored.guardianConsent!.includesAllergenConsent, isTrue);
      });

      test('preserves disliked ingredients through the cache', () {
        // Intent: the JSON cache path (toJson/fromJson) is separate from the
        // Firestore path and — unlike toFirestore — always emits the field.
        // A regression in _parseStringSet(json['dislikedIngredients']) would
        // silently drop dislikes from a cached profile.
        final original = DinerProfile.create(
          householdId: 'hh_1',
          name: 'Emma',
          ageBand: DinerAgeBand.teen,
          createdBy: 'parent_1',
          dislikedIngredients: const {'koriander', 'oliver'},
        );

        final restored = DinerProfile.fromJson(original.toJson());
        expect(
          restored.dislikedIngredients,
          containsAll(<String>['koriander', 'oliver']),
        );
      });
    });

    group('Equality', () {
      test('two profiles are equal iff same id', () {
        final a = DinerProfile.create(
          householdId: 'hh_1',
          name: 'Liam',
          ageBand: DinerAgeBand.child,
          createdBy: 'parent_1',
        );
        final aRenamed = a.copyWith(name: 'Liam B');
        final b = DinerProfile.create(
          householdId: 'hh_1',
          name: 'Liam',
          ageBand: DinerAgeBand.child,
          createdBy: 'parent_1',
        );

        expect(a, equals(aRenamed));
        expect(a.hashCode, aRenamed.hashCode);
        expect(a, isNot(equals(b)));
      });
    });
  });
}
