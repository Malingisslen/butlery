/// BUT-1693: the settings row that shares your own allergen list.
///
/// The row is a consent surface, so the tests are about what it REFUSES to do:
/// it never appears when there is nothing to share into, it never writes a
/// share without the member confirming the Art. 9 copy, and turning it off
/// asks nothing (Art. 7(3)). Direction A of the design preview, chosen by
/// Malin 2026-08-12 — title says the action, subtitle says what the household
/// sees right now.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/models/household.dart';
import 'package:butlery/models/household_allergen_share.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/models/profile_lookup.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/repositories/interfaces/household_allergen_share_repository.dart';
import 'package:butlery/repositories/interfaces/household_repository.dart';
import 'package:butlery/services/feature_flags/feature_flag_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/views/settings/widgets/household_allergen_sharing_tile.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

class _MockHouseholdRepository extends Mock implements HouseholdRepository {}

class _MockShareRepository extends Mock
    implements HouseholdAllergenShareRepository {}

class _MockFeatureFlags extends Mock implements FeatureFlagService {}

class _MockPermissionService extends Mock implements PermissionService {}

class _MockUserService extends Mock implements UserService {}

const _userId = 'user-malin';
const _householdId = 'hh-1';

final sv = AppLocalizationsSv();

/// A member who HAS opened the allergen screen and entered one allergen.
/// `settingsMerged` is the provenance flag: true means this device really read
/// their own settings, so an absent list would be a declaration rather than a
/// gap.
/// [includeUnknownInMenu] is deliberately FALSE, against the class default of
/// true: it is the only fixture value that can tell a member's own choice from
/// the fallback the null-prefs member gets, and this is the direction that
/// tightens — the household AND-folds the flag, so one shared false drops every
/// unverified recipe from everyone's menu.
UserProfile _defaultProfile() => _profile(
  prefs: const UserAllergenPreferences(
    trackedAllergens: {'ägg'},
    trackedDietary: {},
    includeUnknownInMenu: false,
  ),
  settingsMerged: true,
);

/// Never opened the allergen screen: nothing entered, but the settings WERE
/// read — so this is "I have no allergies", not "we do not know".
UserProfile _emptyProfile() => _profile(settingsMerged: true);

/// The settings sub-document could not be read at all.
UserProfile _unreadProfile() => _profile();

UserProfile _profile({
  UserAllergenPreferences? prefs,
  bool settingsMerged = false,
}) => UserProfile(
  uid: _userId,
  displayName: 'Malin',
  email: 'malin@example.com',
  joinedAt: DateTime.utc(2026, 1, 1),
  lastActiveAt: DateTime.utc(2026, 1, 1),
  allergenPreferences: prefs,
  settingsMerged: settingsMerged,
);

/// A household with somebody else in it. The roster is load-bearing, not
/// decoration: a solo household is somebody living alone, and the row hides
/// rather than claim the household is guessing for them.
Household _household({int memberCount = 2}) => Household(
  id: _householdId,
  name: Household.defaultName,
  members: [
    for (var i = 0; i < memberCount; i++)
      HouseholdMember(
        userId: i == 0 ? _userId : 'member-$i',
        permission: SharedListPermission.edit,
        addedAt: DateTime.utc(2026, 1, 1),
      ),
  ],
  createdBy: _userId,
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
);

HouseholdAllergenShare _share() => HouseholdAllergenShare(
  householdId: _householdId,
  userId: _userId,
  trackedAllergens: const {'ägg'},
  trackedDietary: const {},
  includeUnknownInMenu: true,
  consentGranted: true,
  consentVersion: HouseholdAllergenShare.currentConsentVersion,
  consentGrantedAt: DateTime.utc(2026, 8, 12),
  updatedAt: DateTime.utc(2026, 8, 12),
);

void main() {
  late _MockHouseholdRepository households;
  late _MockShareRepository shares;
  late _MockFeatureFlags flags;

  setUpAll(() {
    registerFallbackValue(_share());
  });

  tearDown(() async {
    ServiceLocator.reset();
    await GetIt.instance.reset();
  });

  /// Wires the tile's collaborators. [household] null stages "no household to
  /// share into"; [existingShare] null stages "has not shared".
  void wire({
    bool enabled = true,
    Household? household,
    HouseholdAllergenShare? existingShare,
    UserProfile? profile,
    ProfileLookup? refetch,
    Completer<ProfileLookup>? refetchGate,
  }) {
    households = _MockHouseholdRepository();
    shares = _MockShareRepository();
    flags = _MockFeatureFlags();
    final permissions = _MockPermissionService();
    final userService = _MockUserService();

    when(() => flags.isEnabled(any())).thenReturn(false);
    when(
      () => flags.isEnabled(FeatureFlags.enableHouseholdAllergenSharing),
    ).thenReturn(enabled);
    when(() => permissions.currentUserId).thenReturn(_userId);
    when(
      () => userService.currentUserProfile,
    ).thenReturn(profile ?? _defaultProfile());
    // The grant path re-reads the profile when the cached one carries no
    // settings — `settingsMerged` is only ever written by a fetch, so the
    // cached copy can never clear itself. Default: the re-read finds the same
    // thing, which is the pessimistic case.
    when(() => userService.lookupUserProfile(_userId)).thenAnswer(
      (_) =>
          refetchGate?.future ??
          Future.value(
            refetch ?? ProfileLookup.foundSettingsUnavailable(_unreadProfile()),
          ),
    );
    when(
      () => households.getForUser(_userId),
    ).thenAnswer((_) async => household == null ? [] : [household]);
    when(
      () => shares.getOwn(_householdId),
    ).thenAnswer((_) async => existingShare);
    when(() => shares.create(any())).thenAnswer((_) async => _share());
    when(() => shares.revoke(_householdId)).thenAnswer((_) async {});

    // The tile reads its collaborators through the PRODUCTION ServiceLocator,
    // so the mocks have to be in that container — registering them anywhere
    // else leaves every `tryGet` null and the row hidden, which would make
    // every hidden-row test below pass for the wrong reason.
    final container = DIContainer();
    container.container.registerSingleton<HouseholdRepository>(households);
    container.container.registerSingleton<HouseholdAllergenShareRepository>(
      shares,
    );
    container.container.registerSingleton<FeatureFlagService>(flags);
    container.container.registerSingleton<PermissionService>(permissions);
    container.container.registerSingleton<UserService>(userService);
    ServiceLocator.initialize(container);
  }

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      createLocalizedTestApp(child: const HouseholdAllergenSharingTile()),
    );
    await tester.pumpAndSettle();
  }

  group('when the row is not shown at all', () {
    testWidgets('with the feature switched off', (tester) async {
      wire(enabled: false, household: _household());

      await pump(tester);

      expect(find.byType(SwitchListTile), findsNothing);
      // And it did not even look: an off switch must not spend a read on a
      // collection the rules still deny.
      verifyNever(() => households.getForUser(any()));
    });

    testWidgets('with no household to share into', (tester) async {
      // Malin's call: hidden entirely, not disabled with an explanation.
      wire(household: null);

      await pump(tester);

      expect(find.byType(SwitchListTile), findsNothing);
    });

    testWidgets('with a household of ONE — nobody to share with', (
      tester,
    ) async {
      // A solo `households/{id}` exists for anyone who has opened Min familj,
      // the family rating or who's-eating. The row's subtitle would tell that
      // person the household is guessing for them, which is untrue.
      wire(household: _household(memberCount: 1));

      await pump(tester);

      expect(find.byType(SwitchListTile), findsNothing);
      expect(find.text(sv.householdAllergenShareSubtitleOff), findsNothing);
    });

    testWidgets(
      'but a solo household that HAS shared still gets its off switch',
      (tester) async {
        // This row is the only revoke path in the app. Hiding it from someone
        // who already consented would make withdrawal impossible, which is
        // what Art. 7(3) forbids — and a roster can shrink under a live share
        // when the deletion cascade removes the other member.
        wire(household: _household(memberCount: 1), existingShare: _share());

        await pump(tester);

        expect(
          tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
          isTrue,
        );

        await tester.tap(find.byType(SwitchListTile));
        await tester.pumpAndSettle();

        verify(() => shares.revoke(_householdId)).called(1);
      },
    );

    testWidgets('when the current state could not be read', (tester) async {
      // Drawing the switch in a guessed position would tell the member
      // something false about their own health data.
      wire(household: _household());
      when(
        () => shares.getOwn(_householdId),
      ).thenThrow(StateError('unreadable'));

      await pump(tester);

      expect(find.byType(SwitchListTile), findsNothing);
    });
  });

  group('what the row says', () {
    testWidgets(
      'the mocks really are reachable — the row DOES appear when everything '
      'is in place',
      (tester) async {
        // The control for the hidden-row tests above: without it they would
        // all pass if the collaborators simply never resolved.
        wire(household: _household());

        await pump(tester);

        expect(find.byType(SwitchListTile), findsOneWidget);
        // The state is resolved once in initState and never re-read: a second
        // pair here would mean duplicated reads of a collection the rules
        // still gate.
        verify(() => households.getForUser(_userId)).called(1);
      },
    );

    testWidgets('off: the household is guessing for you', (tester) async {
      wire(household: _household());

      await pump(tester);

      expect(find.text(sv.householdAllergenShareTitle), findsOneWidget);
      expect(find.text(sv.householdAllergenShareSubtitleOff), findsOneWidget);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse,
      );
    });

    testWidgets('on: the menu accounts for your allergies', (tester) async {
      wire(household: _household(), existingShare: _share());

      await pump(tester);

      expect(find.text(sv.householdAllergenShareSubtitleOn), findsOneWidget);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue,
      );
    });
  });

  group('consent', () {
    testWidgets('turning it ON asks first, and writes nothing if you '
        'cancel', (tester) async {
      wire(household: _household());
      await pump(tester);

      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      expect(
        find.text(sv.householdAllergenShareConfirmTitle),
        findsOneWidget,
        reason: 'the Art. 9 copy must be shown before anything is stored',
      );
      expect(
        find.text(sv.householdAllergenShareConfirmBody),
        findsOneWidget,
        reason:
            'the stored record asserts consentVersion v1, i.e. that THIS '
            'wording was on screen — pinning only the title would let the '
            'body be swapped for anything with every test still green',
      );
      await tester.tap(find.text(sv.commonCancel));
      await tester.pumpAndSettle();

      expect(
        find.text(sv.householdAllergenShareConfirmTitle),
        findsNothing,
        reason:
            'without this the test cannot tell a refusal from a Cancel button '
            'that does nothing — both leave the write unmade',
      );
      verifyNever(() => shares.create(any()));
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse,
        reason: 'the switch must not move on a refused consent',
      );
    });

    testWidgets('confirming writes the share with the consent record', (
      tester,
    ) async {
      wire(household: _household());
      await pump(tester);

      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.text(sv.householdAllergenShareConfirmAction));
      await tester.pumpAndSettle();

      final written =
          verify(() => shares.create(captureAny())).captured.single
              as HouseholdAllergenShare;
      expect(written.userId, _userId);
      expect(
        written.householdId,
        _householdId,
        reason: 'this field decides WHO may read the Art. 9 data',
      );
      expect(written.trackedAllergens, {'ägg'});
      expect(
        written.includeUnknownInMenu,
        isFalse,
        reason:
            "the member's own caution is carried, not the fallback the "
            'null-prefs member gets',
      );
      expect(written.consentGranted, isTrue);
      expect(
        written.consentVersion,
        HouseholdAllergenShare.currentConsentVersion,
        reason: 'the record must name the wording the member was shown',
      );
      expect(written.isValidConsent, isTrue);
    });

    testWidgets(
      'a member who entered nothing shares an EMPTY list — never the defaults',
      (tester) async {
        // UserService.allergenPreferences falls back to
        // UserAllergenPreferences.defaults, which is four allergens AND
        // {vegetarisk, vegansk}. Sharing that would store a declaration this
        // member never made — and a tracked diet is a HARD menu requirement,
        // so it would plan the whole household's menu vegan.
        wire(household: _household(), profile: _emptyProfile());
        await pump(tester);

        await tester.tap(find.byType(SwitchListTile));
        await tester.pumpAndSettle();
        await tester.tap(find.text(sv.householdAllergenShareConfirmAction));
        await tester.pumpAndSettle();

        final written =
            verify(() => shares.create(captureAny())).captured.single
                as HouseholdAllergenShare;
        expect(written.trackedAllergens, isEmpty);
        expect(
          written.trackedDietary,
          isEmpty,
          reason: 'the default diets would empty an omnivore household menu',
        );
        expect(
          written.includeUnknownInMenu,
          isTrue,
          reason:
              'their own app admits unverified recipes, so sharing false '
              'would impose a caution they never chose on the whole household',
        );
      },
    );

    testWidgets(
      'a member whose own settings could not be READ cannot share at all',
      (tester) async {
        // Not a declaration of anything: an empty share would read downstream
        // as "I have no allergies" and remove the floor they have today.
        wire(household: _household(), profile: _unreadProfile());
        await pump(tester);

        await tester.tap(find.byType(SwitchListTile));
        await tester.pumpAndSettle();
        await tester.tap(find.text(sv.householdAllergenShareConfirmAction));
        await tester.pumpAndSettle();

        verifyNever(() => shares.create(any()));
        // The settings-specific message, not the generic write failure — the
        // two mean different things to the member. What keeps the re-read
        // failing here is the STUB (`refetch` defaults to still-unreadable);
        // the code path itself recovers, which the next test proves.
        expect(
          find.text(sv.householdAllergenShareSettingsUnread),
          findsOneWidget,
        );
        expect(find.text(sv.householdAllergenShareFailed), findsNothing);
      },
    );

    testWidgets(
      'a share whose consent record is unusable is REPLACED, not left as a '
      'dead end',
      (tester) async {
        // getOwn refused it, so the switch drew OFF while the member's
        // allergens sat in a household-readable collection — and granting
        // could never succeed. The member is consenting right now, so the
        // record is replaced. If the replacement write then fails, the old
        // document is already gone and the switch reads OFF: the household
        // falls back to the BUT-1663 floor, which is the safe direction.
        wire(household: _household());
        var attempt = 0;
        when(() => shares.create(any())).thenAnswer((_) async {
          if (attempt++ == 0) throw ValidationException('already exists');
          return _share();
        });
        await pump(tester);

        await tester.tap(find.byType(SwitchListTile));
        await tester.pumpAndSettle();
        await tester.tap(find.text(sv.householdAllergenShareConfirmAction));
        await tester.pumpAndSettle();

        // Order is the safety of this path: revoking AFTER the replacement was
        // written would delete the record that had just been made. Captured
        // through verifyInOrder because a plain `verify` marks the calls
        // verified and the ordering check then finds nothing left to match.
        final calls = verifyInOrder([
          () => shares.create(captureAny()),
          () => shares.revoke(_householdId),
          () => shares.create(captureAny()),
        ]);
        // The retry path re-invokes the shared builder; these assertions pin
        // that the replacement is a full consent record, not a stripped copy.
        final replacement = calls[2].captured.single as HouseholdAllergenShare;
        expect(replacement.consentGranted, isTrue);
        expect(
          replacement.consentVersion,
          HouseholdAllergenShare.currentConsentVersion,
        );
        expect(replacement.isValidConsent, isTrue);
        expect(replacement.trackedAllergens, {'ägg'});
        expect(replacement.includeUnknownInMenu, isFalse);
        expect(
          tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
          isTrue,
        );
      },
    );

    testWidgets(
      'a profile belonging to a DIFFERENT account is refused, even though it '
      'carries settings',
      (tester) async {
        // The account-switch window. Nothing downstream catches it: the
        // document id and the repository's own self-check both read LIVE auth,
        // so they agree with each other while the allergens come from a
        // profile the previous account left behind. Without the uid conjunct
        // this writes one person's Art. 9 list as another person's
        // declaration.
        wire(
          household: _household(),
          profile: _unreadProfile(),
          refetch: ProfileLookup.found(
            UserProfile(
              uid: 'someone-else',
              displayName: 'Anders',
              email: 'anders@example.com',
              joinedAt: DateTime.utc(2026, 1, 1),
              lastActiveAt: DateTime.utc(2026, 1, 1),
              allergenPreferences: const UserAllergenPreferences(
                trackedAllergens: {'skaldjur'},
                trackedDietary: {},
              ),
              settingsMerged: true,
            ),
          ),
        );
        await pump(tester);

        await tester.tap(find.byType(SwitchListTile));
        await tester.pumpAndSettle();
        await tester.tap(find.text(sv.householdAllergenShareConfirmAction));
        await tester.pumpAndSettle();

        verifyNever(() => shares.create(any()));
        expect(
          find.text(sv.householdAllergenShareSettingsUnread),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'the switch is dead while the profile re-read is in flight',
      (tester) async {
        // The re-read is an await BEFORE the write, so without the busy latch
        // a second tap would re-open the consent dialog and race a second
        // create — whose ValidationException routes into the replace branch,
        // which revokes a live allergen share for a moment.
        final gate = Completer<ProfileLookup>();
        wire(
          household: _household(),
          profile: _unreadProfile(),
          refetchGate: gate,
        );
        await pump(tester);

        await tester.tap(find.byType(SwitchListTile));
        await tester.pumpAndSettle();
        await tester.tap(find.text(sv.householdAllergenShareConfirmAction));
        await tester.pump();

        expect(
          tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
          isNull,
          reason: 'a second tap must not reach the consent dialog',
        );

        gate.complete(ProfileLookup.found(_defaultProfile()));
        await tester.pumpAndSettle();

        verify(() => shares.create(any())).called(1);
        expect(
          tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
          isNotNull,
          reason: 'the latch must clear once the grant finishes',
        );
      },
    );

    testWidgets(
      'a member whose settings were unreadable at login CAN share once the '
      're-read succeeds',
      (tester) async {
        // The refusal copy says "try again", and this is what makes that true:
        // nothing on any settings screen rewrites `settingsMerged`, so without
        // the re-read the member would be locked out until the app restarts.
        wire(
          household: _household(),
          profile: _unreadProfile(),
          refetch: ProfileLookup.found(_defaultProfile()),
        );
        await pump(tester);

        await tester.tap(find.byType(SwitchListTile));
        await tester.pumpAndSettle();
        await tester.tap(find.text(sv.householdAllergenShareConfirmAction));
        await tester.pumpAndSettle();

        final written =
            verify(() => shares.create(captureAny())).captured.single
                as HouseholdAllergenShare;
        expect(written.trackedAllergens, {'ägg'});
        expect(
          find.text(sv.householdAllergenShareSettingsUnread),
          findsNothing,
        );
      },
    );

    testWidgets('a failed withdrawal leaves the switch ON', (tester) async {
      wire(household: _household(), existingShare: _share());
      when(() => shares.revoke(_householdId)).thenThrow(StateError('denied'));
      await pump(tester);

      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      expect(find.text(sv.householdAllergenShareFailed), findsOneWidget);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue,
        reason: 'the member must not be told they stopped when they did not',
      );
    });

    testWidgets('turning it OFF asks nothing — withdrawal is one tap', (
      tester,
    ) async {
      // Art. 7(3): withdrawing consent must never be harder than giving it.
      wire(household: _household(), existingShare: _share());
      await pump(tester);

      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      verify(() => shares.revoke(_householdId)).called(1);
      expect(find.text(sv.householdAllergenShareStopped), findsOneWidget);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse,
      );
    });

    testWidgets('a failed write says so and leaves the switch alone', (
      tester,
    ) async {
      wire(household: _household());
      when(() => shares.create(any())).thenThrow(StateError('denied'));
      await pump(tester);

      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.text(sv.householdAllergenShareConfirmAction));
      await tester.pumpAndSettle();

      expect(find.text(sv.householdAllergenShareFailed), findsOneWidget);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse,
        reason: 'the member must never be told they shared when they did not',
      );
    });
  });
}
