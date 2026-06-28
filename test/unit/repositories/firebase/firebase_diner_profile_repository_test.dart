/// Unit tests for FirebaseDinerProfileRepository.
///
/// Pure-Dart; FakeFirebaseFirestore with a REAL FirebaseHouseholdRepository
/// wired to the same store so membership checks run end-to-end. Focus:
/// (1) the GDPR consent data-boundary guard (minor needs guardian consent;
/// allergen data needs explicit allergen consent), and (2) household-membership
/// access control.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/models/diner_profile.dart';
import 'package:butlery/models/household.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/repositories/firebase/firebase_diner_profile_repository.dart';
import 'package:butlery/repositories/firebase/firebase_household_repository.dart';

import '../../../infrastructure/mocks/production_mocks.dart';

const _malin = 'user-malin';
const _johan = 'user-johan';
const _stranger = 'user-stranger';
const _householdId = 'hh-1';

FirebaseDinerProfileRepository _repo(
  FakeFirebaseFirestore fs, {
  String authedUserId = _malin,
}) {
  final mockAuth = FakeAuthRepository();
  mockAuth.setAuthState(
    user: FakeUser(uid: authedUserId),
    userId: authedUserId,
    isAuthenticated: true,
  );
  final householdRepo = FirebaseHouseholdRepository(
    firestore: fs,
    authRepository: mockAuth,
  );
  return FirebaseDinerProfileRepository(
    firestore: fs,
    authRepository: mockAuth,
    householdRepository: householdRepo,
  );
}

/// Seeds a household with Malin + Johan as members.
Future<void> _seedHousehold(FakeFirebaseFirestore fs) {
  final hh = Household(
    id: _householdId,
    name: Household.defaultName,
    members: [
      HouseholdMember(
        userId: _malin,
        permission: SharedListPermission.admin,
        addedAt: DateTime.utc(2026, 1, 1),
      ),
      HouseholdMember(
        userId: _johan,
        permission: SharedListPermission.edit,
        addedAt: DateTime.utc(2026, 1, 1),
      ),
    ],
    createdBy: _malin,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );
  return fs.collection('households').doc(hh.id).set(hh.toFirestore());
}

GuardianConsent _consent({bool allergens = false}) => GuardianConsent(
  byUid: _malin,
  at: DateTime.utc(2026, 6, 28),
  consentVersion: DinerProfile.currentConsentVersion,
  includesAllergenConsent: allergens,
);

DinerProfile _kid({
  GuardianConsent? consent,
  UserAllergenPreferences? allergens,
  DinerAgeBand ageBand = DinerAgeBand.child,
}) => DinerProfile.create(
  householdId: _householdId,
  name: 'Liam',
  ageBand: ageBand,
  createdBy: _malin,
  allergenPreferences: allergens,
  guardianConsent: consent,
);

/// Seeds a second household (hh-2) where Malin is also a member.
Future<void> _seedHousehold2(FakeFirebaseFirestore fs) {
  final hh = Household(
    id: 'hh-2',
    name: Household.defaultName,
    members: [
      HouseholdMember(
        userId: _malin,
        permission: SharedListPermission.admin,
        addedAt: DateTime.utc(2026, 1, 1),
      ),
    ],
    createdBy: _malin,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );
  return fs.collection('households').doc(hh.id).set(hh.toFirestore());
}

void main() {
  group('GDPR consent data-boundary guard', () {
    test('a minor without guardian consent cannot be created', () async {
      final fs = FakeFirebaseFirestore();
      await _seedHousehold(fs);
      final repo = _repo(fs);

      expect(
        () => repo.create(_kid(consent: null)),
        throwsA(isA<SecurityViolationException>()),
      );
    });

    test('a minor WITH guardian consent (no allergens) is created', () async {
      final fs = FakeFirebaseFirestore();
      await _seedHousehold(fs);
      final repo = _repo(fs);

      final created = await repo.create(_kid(consent: _consent()));
      expect(created.name, 'Liam');
      expect(created.isMinor, isTrue);
    });

    test('allergen data without allergen consent is refused', () async {
      final fs = FakeFirebaseFirestore();
      await _seedHousehold(fs);
      final repo = _repo(fs);

      final profile = _kid(
        consent: _consent(allergens: false), // base consent only
        allergens: const UserAllergenPreferences(
          trackedAllergens: {'nötter'},
          trackedDietary: {},
        ),
      );

      expect(
        () => repo.create(profile),
        throwsA(isA<SecurityViolationException>()),
      );
    });

    test('allergen data WITH explicit allergen consent is allowed', () async {
      final fs = FakeFirebaseFirestore();
      await _seedHousehold(fs);
      final repo = _repo(fs);

      final profile = _kid(
        consent: _consent(allergens: true),
        allergens: const UserAllergenPreferences(
          trackedAllergens: {'nötter'},
          trackedDietary: {},
        ),
      );

      final created = await repo.create(profile);
      expect(created.hasAllergenConsent, isTrue);
    });

    test('an adult guest needs no guardian consent', () async {
      final fs = FakeFirebaseFirestore();
      await _seedHousehold(fs);
      final repo = _repo(fs);

      final guest = _kid(consent: null, ageBand: DinerAgeBand.adult);
      final created = await repo.create(guest);
      expect(created.isMinor, isFalse);
    });

    test('update also enforces the consent guard', () async {
      final fs = FakeFirebaseFirestore();
      await _seedHousehold(fs);
      final repo = _repo(fs);

      final created = await repo.create(_kid(consent: _consent()));
      // Try to add allergen data without upgrading consent.
      final tampered = created.copyWith(
        allergenPreferences: const UserAllergenPreferences(
          trackedAllergens: {'mjölk'},
          trackedDietary: {},
        ),
      );
      expect(
        () => repo.update(tampered),
        throwsA(isA<SecurityViolationException>()),
      );
    });

    test('createBatch cannot bypass the consent guard', () async {
      // The inherited base createBatch writes directly — the override must
      // re-apply the guard so a bulk path can't smuggle in a consentless minor.
      final fs = FakeFirebaseFirestore();
      await _seedHousehold(fs);
      final repo = _repo(fs);

      expect(
        () => repo.createBatch([_kid(consent: null)]),
        throwsA(isA<SecurityViolationException>()),
      );
    });

    test('empty allergen prefs need no allergen consent', () async {
      // Characterisation: the guard fires on hasAnyPreferences, so an empty
      // prefs object with base-only consent is allowed.
      final fs = FakeFirebaseFirestore();
      await _seedHousehold(fs);
      final repo = _repo(fs);

      final created = await repo.create(
        _kid(
          consent: _consent(allergens: false),
          allergens: const UserAllergenPreferences(
            trackedAllergens: {},
            trackedDietary: {},
          ),
        ),
      );
      expect(created.hasAllergenConsent, isFalse);
    });
  });

  group('household-membership access', () {
    test('a member can create; a non-member cannot', () async {
      final fs = FakeFirebaseFirestore();
      await _seedHousehold(fs);

      expect(
        await _repo(fs, authedUserId: _malin).validateCreatePermission(
          _malin,
          _kid(consent: _consent()),
        ),
        isTrue,
      );
      expect(
        await _repo(fs, authedUserId: _stranger).validateCreatePermission(
          _stranger,
          _kid(consent: _consent()),
        ),
        isFalse,
      );
    });

    test('read: members yes, outsider no, null delegates to rules', () async {
      final fs = FakeFirebaseFirestore();
      await _seedHousehold(fs);
      final profile = _kid(consent: _consent());

      expect(
        await _repo(
          fs,
          authedUserId: _johan,
        ).validateReadPermission(_johan, profile.id, profile),
        isTrue,
      );
      expect(
        await _repo(
          fs,
          authedUserId: _stranger,
        ).validateReadPermission(_stranger, profile.id, profile),
        isFalse,
      );
      expect(
        await _repo(fs).validateReadPermission(_malin, 'any', null),
        isTrue,
      );
    });

    test('delete loads the profile and checks household membership', () async {
      final fs = FakeFirebaseFirestore();
      await _seedHousehold(fs);
      final created = await _repo(fs).create(_kid(consent: _consent()));

      expect(
        await _repo(
          fs,
          authedUserId: _johan,
        ).validateDeletePermission(_johan, created.id),
        isTrue,
      );
      expect(
        await _repo(
          fs,
          authedUserId: _stranger,
        ).validateDeletePermission(_stranger, created.id),
        isFalse,
      );
      expect(
        await _repo(fs).validateDeletePermission(_malin, 'ghost'),
        isFalse,
      );
    });

    test('a member cannot create a profile into another household', () async {
      // Malin is a member of hh-1 only; a profile claiming hh-2 is denied.
      final fs = FakeFirebaseFirestore();
      await _seedHousehold(fs);
      final repo = _repo(fs, authedUserId: _malin);

      final foreign = DinerProfile.create(
        householdId: 'hh-2',
        name: 'Liam',
        ageBand: DinerAgeBand.child,
        createdBy: _malin,
        guardianConsent: _consent(),
      );
      expect(
        () => repo.create(foreign),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test('a non-member update (valid consent) is denied via update()', () async {
      final fs = FakeFirebaseFirestore();
      await _seedHousehold(fs);
      final created = await _repo(fs).create(_kid(consent: _consent()));

      // Stranger submits a same-household, consent-valid update → permission denied.
      final asStranger = _repo(fs, authedUserId: _stranger);
      expect(
        () => asStranger.update(created.copyWith(name: 'Hijack')),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test('a valid member update is persisted', () async {
      final fs = FakeFirebaseFirestore();
      await _seedHousehold(fs);
      final repo = _repo(fs, authedUserId: _malin);
      final created = await repo.create(_kid(consent: _consent()));

      await repo.update(created.copyWith(name: 'Liam B'));
      final reread = await repo.read(created.id);
      expect(reread!.name, 'Liam B');
    });

    test('update cannot re-parent a profile to another household', () async {
      final fs = FakeFirebaseFirestore();
      await _seedHousehold(fs);
      await _seedHousehold2(fs); // Malin is a member of both
      final repo = _repo(fs, authedUserId: _malin);
      final created = await repo.create(_kid(consent: _consent()));

      // Even though Malin belongs to hh-2, re-tagging the stored hh-1 profile
      // is rejected (householdId is checked against the STORED doc).
      final reparented = created.copyWith(householdId: 'hh-2');
      expect(
        await repo.validateUpdatePermission(
          _malin,
          created.id,
          reparented,
        ),
        isFalse,
      );
    });
  });

  group('getByHousehold', () {
    test('returns profiles for a member, empty for an outsider', () async {
      final fs = FakeFirebaseFirestore();
      await _seedHousehold(fs);
      await _repo(fs).create(_kid(consent: _consent()));

      expect(
        await _repo(fs, authedUserId: _johan).getByHousehold(_householdId),
        hasLength(1),
      );
      expect(
        await _repo(fs, authedUserId: _stranger).getByHousehold(_householdId),
        isEmpty,
      );
    });

    test('isolates results to the requested household', () async {
      // Two households (Malin is in both), one profile in each. The query must
      // return ONLY the requested household's profile, not all profiles.
      final fs = FakeFirebaseFirestore();
      await _seedHousehold(fs);
      await _seedHousehold2(fs);
      final repo = _repo(fs, authedUserId: _malin);

      final inOne = await repo.create(_kid(consent: _consent()));
      await repo.create(
        DinerProfile.create(
          householdId: 'hh-2',
          name: 'Guest',
          ageBand: DinerAgeBand.adult,
          createdBy: _malin,
        ),
      );

      final hh1Profiles = await repo.getByHousehold(_householdId);
      expect(hh1Profiles, hasLength(1));
      expect(hh1Profiles.single.id, inOne.id);
    });
  });
}
