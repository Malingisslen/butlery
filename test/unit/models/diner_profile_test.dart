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

        final restored = DinerProfile.fromMap('gäst_1', map);
        expect(restored.allergenPreferences, isNull);
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
