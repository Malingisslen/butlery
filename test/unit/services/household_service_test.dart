/// BUT-1663: the household allergen union must tell four situations apart —
/// declared allergens, a genuine "I have none", data we are not permitted to
/// read, and a read that failed. Only the last of those may make the menu
/// cautious.
///
/// `aggregateAllergenPreferences` runs through the auth-gated
/// `executeServiceOperation`, and `HouseholdService` resolves its collaborators
/// from the global `ServiceLocator`, so this suite wires the production locator
/// with an authenticated `AuthRepository` and registers mocks for the friends
/// and user services.
///
/// The structural fact these tests build on — that another member's declared
/// allergens are unreadable by design — is pinned against real serialization in
/// `test/unit/repositories/firebase/firebase_user_repository_gaps_test.dart`,
/// not mocked here.
library;

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/household.dart';
import 'package:butlery/models/household_allergen_share.dart';
import 'package:butlery/models/profile_lookup.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/household_allergen_share_repository.dart';
import 'package:butlery/repositories/interfaces/household_repository.dart';
import 'package:butlery/services/feature_flags/feature_flag_service.dart';
import 'package:butlery/services/household_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/unified/operations/friend_categories_operations.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/user_service.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../test_support/base_unit_test.dart';

class _MockFriendsService extends Mock implements UnifiedFriendsService {}

class _MockCategoriesOps extends Mock implements FriendsCategoriesOperations {}

class _MockUserService extends Mock implements UserService {}

class _MockHouseholdRepository extends Mock implements HouseholdRepository {}

class _MockShareRepository extends Mock
    implements HouseholdAllergenShareRepository {}

class _MockFeatureFlags extends Mock implements FeatureFlagService {}

class _MockRemoteConfig extends Mock implements FirebaseRemoteConfig {}

class _MockPermissionService extends Mock implements PermissionService {}

HouseholdAllergenShare _share(
  String userId, {
  Set<String> allergens = const {},
  Set<String> dietary = const {},
  bool includeUnknownInMenu = true,
}) => HouseholdAllergenShare(
  householdId: 'hh-doc',
  userId: userId,
  trackedAllergens: allergens,
  trackedDietary: dietary,
  includeUnknownInMenu: includeUnknownInMenu,
  consentGranted: true,
  consentVersion: HouseholdAllergenShare.currentConsentVersion,
  consentGrantedAt: DateTime.utc(2026, 8, 12),
  updatedAt: DateTime.utc(2026, 8, 12),
);

UserProfile _profile(
  String uid, {
  UserAllergenPreferences? prefs,
  bool settingsMerged = false,
}) => UserProfile(
  uid: uid,
  displayName: uid,
  email: '$uid@example.com',
  joinedAt: DateTime(2026, 1, 1),
  lastActiveAt: DateTime(2026, 1, 1),
  allergenPreferences: prefs,
  settingsMerged: settingsMerged,
);

UserAllergenPreferences _prefs(
  Set<String> allergens, {
  Set<String> dietary = const {},
  bool includeUnknownInMenu = true,
}) => UserAllergenPreferences(
  trackedAllergens: allergens,
  trackedDietary: dietary,
  includeUnknownInMenu: includeUnknownInMenu,
);

void main() {
  late _MockFriendsService friendsService;
  late _MockCategoriesOps categoriesOps;
  late _MockUserService userService;
  late HouseholdService service;

  setUpAll(() async {
    // executeServiceOperation's auth pre-flight reads the PRODUCTION locator.
    await BaseUnitTest.setupUnitWithProductionLocator();
  });

  tearDownAll(() async {
    await TestServiceLocator.reset();
    await BaseUnitTest.teardownUnit();
  });

  /// Registers a household with the given non-owner members.
  void useHousehold(List<String> friendUserIds) {
    when(() => categoriesOps.categoriesList).thenReturn([
      FriendCategory(
        id: 'hh',
        ownerId: 'owner',
        name: 'Familjen',
        friendUserIds: friendUserIds,
        isHousehold: true,
      ),
    ]);
  }

  setUp(() {
    friendsService = _MockFriendsService();
    categoriesOps = _MockCategoriesOps();
    userService = _MockUserService();

    when(() => friendsService.categories).thenReturn(categoriesOps);
    useHousehold(const ['partner', 'kid']);
    when(() => userService.currentUserProfile).thenReturn(_profile('owner'));

    TestServiceLocator.registerSingleton<UnifiedFriendsService>(friendsService);
    TestServiceLocator.registerSingleton<UserService>(userService);
    (TestServiceLocator.get<AuthRepository>() as FakeAuthRepository)
        .setAuthState(userId: 'owner');

    service = HouseholdService();
  });

  /// BUT-1693: wires the share repository so [shares] are what the household
  /// has been told. Pass null to stage the shares being UNREADABLE, which must
  /// never look like "nobody shared".
  late _MockHouseholdRepository lastHouseholdRepository;

  void useShares(List<HouseholdAllergenShare>? shares, {bool enabled = true}) {
    final householdRepository = _MockHouseholdRepository();
    final shareRepository = _MockShareRepository();
    lastHouseholdRepository = householdRepository;

    final flags = _MockFeatureFlags();
    // The CONSTANT is stubbed last so it wins: with only a wildcard, repointing
    // the constant at a different (default-true) flag would keep every test
    // green while shipping the feature live against an absent rules block.
    when(() => flags.isEnabled(any())).thenReturn(false);
    when(
      () => flags.isEnabled(FeatureFlags.enableHouseholdAllergenSharing),
    ).thenReturn(enabled);
    // mocktail is last-registered-wins, so the ORDER above is load-bearing:
    // swapping the two `when` lines — a plausible tidy-up — would answer false
    // for the real flag and turn every test in this group into a second copy
    // of the flag-off one, silently green. A comment cannot hold that; this
    // can.
    expect(
      flags.isEnabled(FeatureFlags.enableHouseholdAllergenSharing),
      enabled,
      reason: 'the stub for the real flag must win over the wildcard',
    );
    TestServiceLocator.registerSingleton<FeatureFlagService>(flags);

    // The share read is permission-gated, so the service asks PermissionService
    // for the caller's id rather than the cached profile.
    final permissions = _MockPermissionService();
    when(() => permissions.currentUserId).thenReturn('owner');
    TestServiceLocator.registerSingleton<PermissionService>(permissions);

    when(() => householdRepository.getForUser('owner')).thenAnswer(
      (_) async => [
        Household(
          id: 'hh-doc',
          name: Household.defaultName,
          members: const [],
          createdBy: 'owner',
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
      ],
    );
    when(() => shareRepository.getByHousehold('hh-doc')).thenAnswer((_) async {
      if (shares == null) {
        throw StateError('the household roster could not be read');
      }
      return shares;
    });

    TestServiceLocator.registerSingleton<HouseholdRepository>(
      householdRepository,
    );
    TestServiceLocator.registerSingleton<HouseholdAllergenShareRepository>(
      shareRepository,
    );
  }

  void stubLookup(String uid, ProfileLookup lookup) {
    when(
      () => userService.lookupUserProfile(uid),
    ).thenAnswer((_) async => lookup);
  }

  /// The realistic shape for another account holder: their profile resolves,
  /// their allergens do not (private settings sub-doc, owner-read-only).
  void stubOtherMember(String uid) =>
      stubLookup(uid, ProfileLookup.found(_profile(uid)));

  /// Self resolves with genuinely-read settings — the only shape where an
  /// absent allergen set is a declaration.
  void stubSelf({UserAllergenPreferences? prefs}) => stubLookup(
    'owner',
    ProfileLookup.found(
      _profile('owner', prefs: prefs, settingsMerged: true),
    ),
  );

  // Nobody has shared unless a test says so. Registered per test because the
  // locator outlives a single case — without this, one test's shares would be
  // read by the next one and the pre-1693 expectations would silently change.
  setUp(() => useShares(const []));

  group('a member who shared their own list (BUT-1693)', () {
    test('the feature ships OFF by default', () {
      // Asked of the REAL service with a remote config that has no value for
      // it, which is what a device sees before any rollout — so this pins the
      // shipped default, not a stub. It must stay false until the rules block
      // lands and something writes a share.
      final remoteConfig = _MockRemoteConfig();
      when(
        () => remoteConfig.getBool(
          FeatureFlags.enableHouseholdAllergenSharing,
        ),
      ).thenThrow(Exception('no value'));

      expect(
        FeatureFlagService(remoteConfig: remoteConfig).isEnabled(
          FeatureFlags.enableHouseholdAllergenSharing,
        ),
        isFalse,
      );
    });

    test(
      'with the feature OFF nothing is read and the household behaves exactly '
      'as it did before sharing existed',
      () async {
        stubSelf();
        stubOtherMember('partner');
        stubOtherMember('kid');
        useShares([
          _share('partner', allergens: {'ägg'}),
        ], enabled: false);

        final aggregate = await service.aggregateAllergenPreferences();

        expect(
          aggregate.preferences.trackedAllergens,
          containsAll(UserAllergenPreferences.defaults.trackedAllergens),
        );
        expect(aggregate.preferences.trackedAllergens, isNot(contains('ägg')));
        expect(
          aggregate.isRosterComplete,
          isTrue,
          reason: 'a switched-off feature is knowledge, not an outage',
        );
        // The half of "nothing is read" that the preferences cannot show: no
        // denied query on a user-visible path while the rules block is absent.
        verifyNever(() => lastHouseholdRepository.getForUser(any()));
      },
    );

    test(
      'is read, not guessed at — their real allergens replace the floor and '
      'the roster stays complete',
      () async {
        stubSelf();
        stubOtherMember('partner');
        stubOtherMember('kid');
        useShares([
          _share('partner', allergens: {'ägg'}),
          _share('kid', allergens: {'skaldjur'}),
        ]);

        final aggregate = await service.aggregateAllergenPreferences();

        expect(aggregate.preferences.trackedAllergens, {'ägg', 'skaldjur'});
        expect(
          aggregate.preferences.trackedAllergens,
          isNot(contains('jordnötter')),
          reason: 'the four-allergen floor must be gone for a shared member',
        );
        expect(aggregate.isRosterComplete, isTrue);
      },
    );

    test(
      'sharing an EMPTY list means "I have no allergies", not "unknown"',
      () async {
        stubSelf();
        stubOtherMember('partner');
        stubOtherMember('kid');
        useShares([_share('partner'), _share('kid')]);

        final aggregate = await service.aggregateAllergenPreferences();

        expect(
          aggregate.preferences.trackedAllergens,
          isEmpty,
          reason: 'the whole point of the collection: absent is not empty',
        );
        expect(aggregate.isRosterComplete, isTrue);
      },
    );

    test('a shared dietary choice narrows the household menu', () async {
      stubSelf();
      stubOtherMember('partner');
      stubOtherMember('kid');
      useShares([
        _share('partner', dietary: {'vegansk'}),
        _share('kid'),
      ]);

      final aggregate = await service.aggregateAllergenPreferences();

      expect(aggregate.preferences.trackedDietary, {'vegansk'});
    });

    test('a shared caution about unverified recipes tightens the whole '
        'household', () async {
      stubSelf();
      stubOtherMember('partner');
      stubOtherMember('kid');
      useShares([
        _share('partner', includeUnknownInMenu: false),
        _share('kid'),
      ]);

      final aggregate = await service.aggregateAllergenPreferences();

      expect(aggregate.preferences.includeUnknownInMenu, isFalse);
    });

    test(
      'a member who has NOT shared keeps the floor, beside one who has',
      () async {
        stubSelf();
        stubOtherMember('partner');
        stubOtherMember('kid');
        useShares([
          _share('partner', allergens: {'ägg'}),
        ]);

        final aggregate = await service.aggregateAllergenPreferences();

        expect(aggregate.preferences.trackedAllergens, contains('ägg'));
        expect(
          aggregate.preferences.trackedAllergens,
          containsAll(UserAllergenPreferences.defaults.trackedAllergens),
          reason: 'kid never shared, so kid is still guessed at',
        );
      },
    );

    test(
      'shares that cannot be READ are not "nobody shared" — the roster reports '
      'itself INCOMPLETE so the menu says so',
      () async {
        stubSelf();
        stubOtherMember('partner');
        stubOtherMember('kid');
        useShares(null);

        final aggregate = await service.aggregateAllergenPreferences();

        expect(
          aggregate.preferences.trackedAllergens,
          containsAll(UserAllergenPreferences.defaults.trackedAllergens),
        );
        expect(
          aggregate.isRosterComplete,
          isFalse,
          reason:
              'someone may have shared a list this menu is filtering without; '
              'reporting a healthy roster would hide that',
        );
        expect(aggregate.preferences.includeUnknownInMenu, isFalse);
      },
    );

    test(
      'a member whose profile read FAILED still degrades the roster even '
      'though they shared — a share can lag behind the settings it mirrors',
      () async {
        stubSelf();
        stubLookup('partner', ProfileLookup.unavailable());
        stubOtherMember('kid');
        useShares([
          _share('partner', allergens: {'ägg'}),
        ]);

        final aggregate = await service.aggregateAllergenPreferences();

        expect(
          aggregate.preferences.trackedAllergens,
          contains('ägg'),
          reason: 'the share still contributes what it knows',
        );
        expect(aggregate.isRosterComplete, isFalse);
        expect(aggregate.unresolvedMemberIds, contains('partner'));
      },
    );

    test(
      'a flag service that cannot be READ degrades the roster — not being able '
      'to read the switch is not the same as reading it and finding it off',
      () async {
        stubSelf();
        stubOtherMember('partner');
        stubOtherMember('kid');
        useShares([
          _share('partner', allergens: {'ägg'}),
        ]);
        TestServiceLocator.unregister<FeatureFlagService>();

        final aggregate = await service.aggregateAllergenPreferences();

        expect(aggregate.isRosterComplete, isFalse);
        expect(
          aggregate.preferences.trackedAllergens,
          containsAll(UserAllergenPreferences.defaults.trackedAllergens),
        );
        expect(aggregate.preferences.includeUnknownInMenu, isFalse);
      },
    );

    test(
      'a share about the signed-in user is ignored even when their cached '
      'profile is missing — the auth handle decides who "self" is',
      () async {
        // The cached profile is the handle this must NOT depend on: with it
        // null, a uid-by-profile comparison would fail to recognise the
        // signed-in user and let a document written about them stand in for
        // the settings their own device can read.
        stubSelf(prefs: _prefs({'selleri'}));
        stubOtherMember('partner');
        stubOtherMember('kid');
        useShares([
          _share('owner', allergens: {'ägg'}),
          _share('partner'),
          _share('kid'),
        ]);
        when(() => userService.currentUserProfile).thenReturn(null);

        final aggregate = await service.aggregateAllergenPreferences();

        expect(aggregate.preferences.trackedAllergens, {'selleri'});
      },
    );

    test(
      'a household of one is not degraded by an unreadable share read — '
      'nobody else could have shared, so nothing was missed',
      () async {
        useHousehold(const []);
        stubSelf();
        useShares(null);

        final aggregate = await service.aggregateAllergenPreferences();

        expect(aggregate.isRosterComplete, isTrue);
        expect(aggregate.preferences.trackedAllergens, isEmpty);
      },
    );

    test(
      'a share left behind by a member whose profile does not EXIST does not '
      'filter the menu',
      () async {
        // BUT-1663 decided an absent person cannot be protected and must not
        // shrink the menu. A share from a deleted account is that person.
        stubSelf();
        stubLookup('partner', ProfileLookup.missing());
        stubOtherMember('kid');
        useShares([
          _share('partner', allergens: {'selleri'}),
        ]);

        final aggregate = await service.aggregateAllergenPreferences();

        expect(
          aggregate.preferences.trackedAllergens,
          isNot(contains('selleri')),
        );
        expect(aggregate.isRosterComplete, isTrue);
      },
    );

    test(
      'the signed-in user is read from their OWN settings, never from a share '
      'someone could have written about them',
      () async {
        stubSelf(prefs: _prefs({'selleri'}));
        stubOtherMember('partner');
        stubOtherMember('kid');
        useShares([
          _share('owner', allergens: {'ägg'}),
          _share('partner'),
          _share('kid'),
        ]);

        final aggregate = await service.aggregateAllergenPreferences();

        expect(aggregate.preferences.trackedAllergens, {'selleri'});
      },
    );
  });

  group('what each member contributes', () {
    test(
      'the signed-in user with no declared allergens contributes NOTHING — an '
      'untouched screen is a declaration, not missing data (BUT-1663)',
      () async {
        useHousehold(const []);
        stubSelf();

        final aggregate = await service.aggregateAllergenPreferences();

        expect(aggregate.preferences.trackedAllergens, isEmpty);
        // Emphatically NOT UserAllergenPreferences.defaults, whose dietary set
        // would restrict a solo omnivore to vegan dishes.
        expect(aggregate.preferences.trackedDietary, isEmpty);
        expect(aggregate.isRosterComplete, isTrue);
      },
    );

    test(
      'another account member keeps the common-allergen floor — their real '
      'allergens are unreadable, so silence proves nothing (BUT-1663)',
      () async {
        stubSelf(prefs: _prefs({'ägg'}));
        stubOtherMember('partner');
        stubOtherMember('kid');

        final aggregate = await service.aggregateAllergenPreferences();

        expect(
          aggregate.preferences.trackedAllergens,
          containsAll({
            'ägg',
            ...UserAllergenPreferences.defaults.trackedAllergens,
          }),
        );
        // The floor is allergens only — the dietary defaults would turn the
        // household's menu vegan, which is not a safety property.
        expect(aggregate.preferences.trackedDietary, isEmpty);
      },
    );

    test(
      'the floor is decided by PROVENANCE, not by comparing user ids — a '
      'profile whose settings were never read keeps the floor even if it is '
      'the owner (BUT-1663)',
      () async {
        // Guards the auth-race door back into the original bug: if this
        // branch compared uids instead, a moment where auth reports null
        // while the cached profile does not would let an unread self profile
        // through as "she declared none".
        useHousehold(const []);
        stubLookup(
          'owner',
          ProfileLookup.found(_profile('owner')), // settingsMerged: false
        );

        final aggregate = await service.aggregateAllergenPreferences();

        expect(
          aggregate.preferences.trackedAllergens,
          UserAllergenPreferences.defaults.trackedAllergens,
        );
      },
    );

    test('declared allergens union across members that expose them', () async {
      stubSelf(prefs: _prefs({'ägg'}, dietary: {'vegetarisk'}));
      stubLookup(
        'partner',
        ProfileLookup.found(_profile('partner', prefs: _prefs({'soja'}))),
      );
      stubOtherMember('kid');

      final aggregate = await service.aggregateAllergenPreferences();

      expect(
        aggregate.preferences.trackedAllergens,
        containsAll({'ägg', 'soja'}),
      );
      expect(aggregate.preferences.trackedDietary, {'vegetarisk'});
    });
  });

  group('no regression versus the previous behaviour', () {
    test(
      'a household where every profile resolves behaves EXACTLY as before: '
      'same floor, same UNKNOWN handling, same complete roster (BUT-1663)',
      () async {
        stubSelf(prefs: _prefs({'ägg'}));
        stubOtherMember('partner');
        stubOtherMember('kid');

        final aggregate = await service.aggregateAllergenPreferences();

        // All three fields asserted — a superset check alone would miss a
        // regression in the other two, which is how an earlier draft of this
        // change slipped an unintended tightening past review.
        expect(
          aggregate.preferences.trackedAllergens,
          containsAll(UserAllergenPreferences.defaults.trackedAllergens),
        );
        expect(aggregate.preferences.includeUnknownInMenu, isTrue);
        expect(aggregate.isRosterComplete, isTrue);
      },
    );

    test('includeUnknownInMenu stays conservative if any member excludes '
        'unknowns', () async {
      stubSelf(prefs: _prefs({'ägg'}, includeUnknownInMenu: false));
      stubOtherMember('partner');
      stubOtherMember('kid');

      final aggregate = await service.aggregateAllergenPreferences();

      expect(aggregate.preferences.includeUnknownInMenu, isFalse);
    });
  });

  group('a read that failed', () {
    test(
      'a failed profile read WIDENS with the floor and reports an incomplete '
      'roster (BUT-1663)',
      () async {
        stubSelf(prefs: _prefs({'ägg'}));
        stubOtherMember('partner');
        stubLookup('kid', const ProfileLookup.unavailable());

        final aggregate = await service.aggregateAllergenPreferences();

        // The original bug was dropping the unreadable member silently; the
        // first fix's regression was replacing the resolved union with defaults.
        expect(aggregate.preferences.trackedAllergens, contains('ägg'));
        expect(
          aggregate.preferences.trackedAllergens,
          containsAll(UserAllergenPreferences.defaults.trackedAllergens),
        );
        expect(aggregate.preferences.includeUnknownInMenu, isFalse);
        expect(aggregate.isRosterComplete, isFalse);
        expect(aggregate.unresolvedMemberIds, ['kid']);
      },
    );

    test(
      'the signed-in user whose SETTINGS read failed is treated as unknown, '
      'not as "declared nothing" (BUT-1663)',
      () async {
        useHousehold(const []);
        // Profile loaded, private settings did not — allergens are absent
        // because of a failure. The dangerous reading is "she has none".
        stubLookup(
          'owner',
          ProfileLookup.foundSettingsUnavailable(_profile('owner')),
        );

        final aggregate = await service.aggregateAllergenPreferences();

        expect(
          aggregate.preferences.trackedAllergens,
          containsAll(UserAllergenPreferences.defaults.trackedAllergens),
        );
        expect(aggregate.preferences.includeUnknownInMenu, isFalse);
        expect(aggregate.isRosterComplete, isFalse);
        expect(aggregate.unresolvedMemberIds, ['owner']);
      },
    );
  });

  group('a member who is not there', () {
    test(
      'a missing profile does NOT make the household cautious — an absent '
      'person cannot be protected, and degrading forever is unrecoverable '
      '(BUT-1663)',
      () async {
        // The deliberate safety relaxation this change introduces. Pinned so
        // it can never happen anywhere else by accident: today a deleted
        // member holds a 3-person household at includeUnknownInMenu: false
        // permanently, with no way for the user to clear it.
        stubSelf(prefs: _prefs({'ägg'}));
        stubOtherMember('partner');
        stubLookup('kid', const ProfileLookup.missing());

        final aggregate = await service.aggregateAllergenPreferences();

        expect(aggregate.isRosterComplete, isTrue);
        expect(aggregate.preferences.includeUnknownInMenu, isTrue);
        expect(aggregate.missingMemberIds, ['kid']);
        expect(aggregate.unresolvedMemberIds, isEmpty);
        // The members who ARE there still supply their protection.
        expect(aggregate.preferences.trackedAllergens, contains('ägg'));
        expect(
          aggregate.preferences.trackedAllergens,
          containsAll(UserAllergenPreferences.defaults.trackedAllergens),
        );
      },
    );

    test(
      'a degraded run KEEPS the dietary restrictions it did resolve — '
      'widening allergens must not quietly drop a vegetarian',
      () async {
        stubSelf(prefs: _prefs({'ägg'}, dietary: {'vegetarisk'}));
        stubOtherMember('partner');
        stubLookup('kid', const ProfileLookup.unavailable());

        final aggregate = await service.aggregateAllergenPreferences();

        expect(aggregate.isRosterComplete, isFalse);
        // Replacing the degraded branch's dietary passthrough with `const {}`
        // would leave every other assertion green while serving meat to a
        // vegetarian household.
        expect(aggregate.preferences.trackedDietary, {'vegetarisk'});
      },
    );

    test('a failed read still wins over a missing one', () async {
      stubSelf(prefs: _prefs({'ägg'}));
      stubLookup('partner', const ProfileLookup.missing());
      stubLookup('kid', const ProfileLookup.unavailable());

      final aggregate = await service.aggregateAllergenPreferences();

      expect(aggregate.isRosterComplete, isFalse);
      expect(aggregate.unresolvedMemberIds, ['kid']);
      expect(aggregate.missingMemberIds, ['partner']);
    });
  });

  test(
    'the owner appearing twice in the roster is resolved once (BUT-1663)',
    () async {
      // migrateOwnersAsMembers() appends ownerId INTO friendUserIds on every
      // login, and allMemberIds is [ownerId, ...friendUserIds] — so a migrated
      // household hands the owner over twice.
      useHousehold(const ['partner', 'owner']);
      stubLookup('owner', const ProfileLookup.unavailable());
      stubOtherMember('partner');

      final aggregate = await service.aggregateAllergenPreferences();

      expect(aggregate.unresolvedMemberIds, ['owner']);
      verify(() => userService.lookupUserProfile('owner')).called(1);
    },
  );

  test(
    'a roster that resolves to NO members at all is unknown, not safe '
    '(BUT-1663)',
    () async {
      // No household group, and no signed-in profile either — the startup
      // profile fetch failed or auth is mid-refresh. Removing the old
      // single-member early return exposed this path: without an explicit
      // guard it falls through to an empty union with UNKNOWN allowed, i.e.
      // every allergen filter silently off, reported as a healthy roster.
      when(() => categoriesOps.categoriesList).thenReturn([]);
      when(() => userService.currentUserProfile).thenReturn(null);

      final aggregate = await service.aggregateAllergenPreferences();

      expect(aggregate.isRosterComplete, isFalse);
      expect(
        aggregate.preferences.trackedAllergens,
        UserAllergenPreferences.defaults.trackedAllergens,
      );
      expect(aggregate.preferences.includeUnknownInMenu, isFalse);
      expect(aggregate.preferences.trackedDietary, isEmpty);
    },
  );

  test(
    'a failed aggregation falls back to the common-allergen floor with '
    'UNKNOWN closed, and reports an incomplete roster (BUT-1663)',
    () async {
      // executeServiceOperation's auth pre-flight returns the null default
      // when no user is signed in — the only seam that reaches the
      // whole-aggregation-failed branch.
      (TestServiceLocator.get<AuthRepository>() as FakeAuthRepository)
          .setAuthState(userId: null);

      final aggregate = await service.aggregateAllergenPreferences();

      expect(aggregate.isRosterComplete, isFalse);
      expect(aggregate.unresolvedMemberIds, isEmpty);
      expect(
        aggregate.preferences.trackedAllergens,
        UserAllergenPreferences.defaults.trackedAllergens,
      );
      expect(aggregate.preferences.includeUnknownInMenu, isFalse);
      expect(aggregate.preferences.trackedDietary, isEmpty);
      verifyNever(() => userService.lookupUserProfile(any()));
    },
  );
}
