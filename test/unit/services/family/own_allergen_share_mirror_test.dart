// DPIA R4 (BUT-2267): saving allergen settings must carry the member's own
// shares along, so a household never filters on a list its member has
// already changed.
import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/household.dart';
import 'package:butlery/models/household_allergen_share.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/repositories/interfaces/household_allergen_share_repository.dart';
import 'package:butlery/repositories/interfaces/household_repository.dart';
import 'package:butlery/services/family/own_allergen_share_mirror.dart';

class _MockHouseholds extends Mock implements HouseholdRepository {}

class _MockShares extends Mock implements HouseholdAllergenShareRepository {}

const _me = 'me';

Household _hh(String id) => Household(
  id: id,
  name: Household.defaultName,
  members: [
    HouseholdMember(
      userId: _me,
      permission: SharedListPermission.view,
      addedAt: DateTime.utc(2026, 1, 1),
    ),
  ],
  createdBy: _me,
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
);

HouseholdAllergenShare _share(String householdId) => HouseholdAllergenShare(
  householdId: householdId,
  userId: _me,
  trackedAllergens: const {'ägg'},
  trackedDietary: const {},
  includeUnknownInMenu: true,
  consentGranted: true,
  consentVersion: HouseholdAllergenShare.currentConsentVersion,
  consentGrantedAt: DateTime.utc(2026, 8, 12),
  updatedAt: DateTime.utc(2026, 8, 12),
);

const _newPrefs = UserAllergenPreferences(
  trackedAllergens: {'jordnötter'},
  trackedDietary: {'vegetarisk'},
  includeUnknownInMenu: false,
);

void main() {
  late _MockHouseholds households;
  late _MockShares shares;
  late OwnAllergenShareMirror mirror;

  setUp(() {
    households = _MockHouseholds();
    shares = _MockShares();
    mirror = OwnAllergenShareMirror(
      householdRepository: households,
      shareRepository: shares,
    );
    when(
      () => households.getForUser(_me),
    ).thenAnswer((_) async => [_hh('shared-in'), _hh('not-shared-in')]);
    when(
      () => shares.getOwn('shared-in'),
    ).thenAnswer((_) async => _share('shared-in'));
    when(() => shares.getOwn('not-shared-in')).thenAnswer((_) async => null);
  });

  test(
    'each existing share takes the new list and keeps its consent',
    () async {
      final now = DateTime.utc(2026, 10, 6, 12);
      final copies = await withClock(
        Clock.fixed(now),
        () => mirror.sharesFor(_me, _newPrefs),
      );

      expect(copies, hasLength(1));
      final copy = copies.single;
      expect(copy.id, _share('shared-in').id);
      expect(copy.trackedAllergens, {'jordnötter'});
      expect(copy.trackedDietary, {'vegetarisk'});
      expect(copy.includeUnknownInMenu, isFalse);
      expect(copy.updatedAt, now);
      // The consent is the member's earlier act; a settings save is not a new
      // one and must not restamp it.
      expect(copy.consentGrantedAt, DateTime.utc(2026, 8, 12));
      expect(copy.consentVersion, HouseholdAllergenShare.currentConsentVersion);
      expect(copy.isValidConsent, isTrue);
    },
  );

  test('a household where they never shared gets no share', () async {
    final copies = await mirror.sharesFor(_me, _newPrefs);
    expect(copies.map((s) => s.householdId), ['shared-in']);
  });

  test(
    'a corrupt own row is skipped, not a reason to block the save',
    () async {
      when(
        () => shares.getOwn('shared-in'),
      ).thenThrow(const FormatException('body disagrees with path'));

      expect(await mirror.sharesFor(_me, _newPrefs), isEmpty);
    },
  );

  test('a share that cannot be read fails the save', () async {
    // Going ahead would leave the household filtering on the old list, which
    // is the lag R4 exists to close.
    when(() => shares.getOwn('shared-in')).thenThrow(StateError('offline'));

    await expectLater(
      mirror.sharesFor(_me, _newPrefs),
      throwsA(isA<StateError>()),
    );
  });
}
