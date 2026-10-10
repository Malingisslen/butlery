// BUT-1465: Widget gate for the Settings "Filter the menu for the whole
// household" switch (household-allergen-filter opt-out).
//
// Proves: it is HIDDEN when the user has no household; it reflects the stored
// `useHouseholdAllergens` value; turning it ON persists immediately with NO
// dialog; turning it OFF opens the child-safety confirm dialog (naming the
// household's actual tracked allergens) and only persists on confirm — a
// refactor that drops the gate, skips the confirm, or stops persisting is caught.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/widgets/common/feedback/inline_warning.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/diner_profile.dart';
import 'package:butlery/models/household.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/repositories/interfaces/diner_profile_repository.dart';
import 'package:butlery/repositories/interfaces/household_repository.dart';
import 'package:butlery/services/household_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/views/settings/widgets/household_allergen_filter_tile.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

class _MockUserService extends Mock implements UserService {}

class _MockHouseholdService extends Mock implements HouseholdService {}

class _MockHouseholdRepository extends Mock implements HouseholdRepository {}

class _MockDinerProfileRepository extends Mock
    implements DinerProfileRepository {}

class _MockPermissionService extends Mock implements PermissionService {}

/// The dialog subtracts what the MENU filters by for the owner alone
/// (`HouseholdService.ownMenuPreferences`), read from the profile: declared
/// [prefs] as is, none with the settings read done = nothing, none with the
/// read failed = the common-allergen floor.
UserProfile _profile({
  required bool useHousehold,
  UserAllergenPreferences? prefs,
  bool settingsMerged = true,
}) => UserProfile(
  uid: 'u1',
  displayName: 'Test',
  email: 't@example.com',
  joinedAt: DateTime(2024, 1, 1),
  lastActiveAt: DateTime(2024, 1, 1),
  useHouseholdAllergens: useHousehold,
  allergenPreferences: prefs,
  settingsMerged: settingsMerged,
);

void main() {
  final sv = AppLocalizationsSv();

  group('HouseholdAllergenFilterTile (BUT-1465)', () {
    late _MockUserService userService;
    late _MockHouseholdService household;

    setUp(() async {
      await GetIt.instance.reset();
      ServiceLocator.reset();

      userService = _MockUserService();
      household = _MockHouseholdService();
      when(() => userService.addListener(any())).thenReturn(null);
      when(() => userService.removeListener(any())).thenReturn(null);
      when(
        () => userService.setUseHouseholdAllergens(any()),
      ).thenAnswer((_) async {});
      // The OWNER tracks nothing, so the household's gluten is genuinely
      // newly-exposed by opting out — and thus named in the warning. (The
      // warning names union MINUS owner-own; an owner-own allergen stays
      // filtered and must NOT be named.)
      when(() => userService.allergenPreferences).thenReturn(
        const UserAllergenPreferences(trackedAllergens: {}, trackedDietary: {}),
      );
      when(() => household.aggregateAllergenPreferences()).thenAnswer(
        (_) async => const HouseholdAllergenAggregate.complete(
          UserAllergenPreferences(
            trackedAllergens: {'gluten'},
            trackedDietary: {},
          ),
        ),
      );

      final container = DIContainer();
      container.container.registerSingleton<UserService>(userService);
      container.container.registerSingleton<HouseholdService>(household);
      ServiceLocator.initialize(container);
    });

    tearDown(() async {
      ServiceLocator.reset();
      await GetIt.instance.reset();
    });

    testWidgets('is hidden when the user has no household', (tester) async {
      when(() => household.hasHousehold).thenReturn(false);
      when(
        () => userService.currentUserProfile,
      ).thenReturn(_profile(useHousehold: true));

      await tester.pumpWidget(
        createLocalizedTestApp(child: const HouseholdAllergenFilterTile()),
      );
      await tester.pump();

      expect(find.byType(ButleryListRow), findsNothing);
    });

    testWidgets('reflects the stored value when a household exists', (
      tester,
    ) async {
      when(() => household.hasHousehold).thenReturn(true);
      when(
        () => userService.currentUserProfile,
      ).thenReturn(_profile(useHousehold: true));

      await tester.pumpWidget(
        createLocalizedTestApp(child: const HouseholdAllergenFilterTile()),
      );
      await tester.pump();

      expect(find.text(sv.householdAllergenFilterTitle), findsOneWidget);
      expect(
        tester.widget<ButleryListRow>(find.byType(ButleryListRow)).checked,
        isTrue,
      );
    });

    testWidgets(
      'the filter-off warning row is drawn in the warning tokens, gold icon '
      'and onWarningContainer text',
      (tester) async {
        // The gold is an icon/container colour: as small text on cream it
        // measures ~2.2:1, well under WCAG AA. This row shipped that way, so
        // the tokens are pinned rather than left to review.
        when(() => household.hasHousehold).thenReturn(true);
        when(
          () => userService.currentUserProfile,
        ).thenReturn(_profile(useHousehold: false));

        await tester.pumpWidget(
          createLocalizedTestApp(child: const HouseholdAllergenFilterTile()),
        );
        await tester.pump();

        // Scoped to the tile: the confirm dialog this suite opens elsewhere
        // carries two more warning_amber icons, and an unscoped finder would
        // crash rather than fail cleanly the day someone settles past it.
        final icon = tester.widget<Icon>(
          find.descendant(
            of: find.byType(InlineWarning),
            matching: find.byIcon(ButleryIcons.triangleAlert),
          ),
        );
        expect(icon.color, ModeColors.light.warning);
        final subtitle = tester.widget<Text>(
          find.text(sv.householdAllergenFilterSubtitleOff),
        );
        expect(
          subtitle.style?.color,
          ModeColors.light.onWarningContainer,
        );
      },
    );

    testWidgets('turning ON persists immediately with no dialog', (
      tester,
    ) async {
      when(() => household.hasHousehold).thenReturn(true);
      when(
        () => userService.currentUserProfile,
      ).thenReturn(_profile(useHousehold: false));

      await tester.pumpWidget(
        createLocalizedTestApp(child: const HouseholdAllergenFilterTile()),
      );
      await tester.pump();

      await tester.tap(find.byType(ButleryListRow));
      await tester.pumpAndSettle();

      // Re-enabling protection must NOT show a confirm dialog.
      expect(find.text(sv.householdAllergenOffTitle), findsNothing);
      verify(() => userService.setUseHouseholdAllergens(true)).called(1);
    });

    testWidgets(
      'turning OFF opens the confirm dialog naming the allergens and persists '
      'only on confirm',
      (tester) async {
        when(() => household.hasHousehold).thenReturn(true);
        when(
          () => userService.currentUserProfile,
        ).thenReturn(_profile(useHousehold: true));

        await tester.pumpWidget(
          createLocalizedTestApp(child: const HouseholdAllergenFilterTile()),
        );
        await tester.pump();

        await tester.tap(find.byType(ButleryListRow));
        await tester.pumpAndSettle();

        // The child-safety confirm dialog is up, and it names the household's
        // actual tracked allergen using its display label ("Gluten").
        expect(find.text(sv.householdAllergenOffTitle), findsOneWidget);
        expect(
          find.textContaining(
            AllergenPreferenceOptions.getAllergenLabel('gluten'),
          ),
          findsOneWidget,
        );
        verifyNever(() => userService.setUseHouseholdAllergens(any()));

        await tester.tap(find.text(sv.commonTurnOff));
        await tester.pumpAndSettle();

        verify(() => userService.setUseHouseholdAllergens(false)).called(1);
      },
    );

    testWidgets(
      'the warning names a diner profile\'s allergen (a child has no account, '
      'so the account union never saw it)',
      (tester) async {
        when(() => household.hasHousehold).thenReturn(true);
        when(
          () => userService.currentUserProfile,
        ).thenReturn(_profile(useHousehold: true));

        final householdRepo = _MockHouseholdRepository();
        final dinerRepo = _MockDinerProfileRepository();
        final permission = _MockPermissionService();
        when(() => permission.currentUserId).thenReturn('u1');
        when(() => householdRepo.getActiveForUser('u1')).thenAnswer(
          (_) async => Household(
            id: 'hh1',
            name: Household.defaultName,
            members: const [],
            createdBy: 'u1',
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        );
        when(() => dinerRepo.getByHousehold('hh1')).thenAnswer(
          (_) async => [
            DinerProfile(
              id: 'kid',
              householdId: 'hh1',
              name: 'Testbarn',
              ageBand: DinerAgeBand.child,
              allergenPreferences: const UserAllergenPreferences(
                trackedAllergens: {'fisk'},
                trackedDietary: {},
              ),
              createdBy: 'u1',
            ),
          ],
        );
        final getIt = GetIt.instance;
        getIt.registerSingleton<HouseholdRepository>(householdRepo);
        getIt.registerSingleton<DinerProfileRepository>(dinerRepo);
        getIt.registerSingleton<PermissionService>(permission);

        await tester.pumpWidget(
          createLocalizedTestApp(child: const HouseholdAllergenFilterTile()),
        );
        await tester.pump();

        await tester.tap(find.byType(ButleryListRow));
        await tester.pumpAndSettle();

        expect(find.text(sv.householdAllergenOffTitle), findsOneWidget);
        expect(
          find.textContaining(
            AllergenPreferenceOptions.getAllergenLabel('fisk'),
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            AllergenPreferenceOptions.getAllergenLabel('gluten'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'a diner profile read that FAILS names no allergen and says the list '
      'may be partial, instead of naming the safety floor as the family\'s',
      (tester) async {
        when(() => household.hasHousehold).thenReturn(true);
        when(
          () => userService.currentUserProfile,
        ).thenReturn(_profile(useHousehold: true));

        final householdRepo = _MockHouseholdRepository();
        final dinerRepo = _MockDinerProfileRepository();
        final permission = _MockPermissionService();
        when(() => permission.currentUserId).thenReturn('u1');
        when(() => householdRepo.getActiveForUser('u1')).thenAnswer(
          (_) async => Household(
            id: 'hh1',
            name: Household.defaultName,
            members: const [],
            createdBy: 'u1',
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        );
        when(
          () => dinerRepo.getByHousehold('hh1'),
        ).thenThrow(Exception('down'));
        final getIt = GetIt.instance;
        getIt.registerSingleton<HouseholdRepository>(householdRepo);
        getIt.registerSingleton<DinerProfileRepository>(dinerRepo);
        getIt.registerSingleton<PermissionService>(permission);

        await tester.pumpWidget(
          createLocalizedTestApp(child: const HouseholdAllergenFilterTile()),
        );
        await tester.pump();

        await tester.tap(find.byType(ButleryListRow));
        await tester.pumpAndSettle();

        expect(find.text(sv.householdAllergenOffTitle), findsOneWidget);
        expect(
          find.textContaining(sv.householdAllergenRosterIncomplete),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            AllergenPreferenceOptions.getAllergenLabel('gluten'),
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'an owner whose settings read FAILED is floor-protected alone, so a '
      'floor allergen is NOT named as newly exposed',
      (tester) async {
        when(() => household.hasHousehold).thenReturn(true);
        when(() => userService.currentUserProfile).thenReturn(
          _profile(useHousehold: true, settingsMerged: false),
        );
        when(
          () => userService.allergenPreferences,
        ).thenReturn(UserAllergenPreferences.defaults);

        await tester.pumpWidget(
          createLocalizedTestApp(child: const HouseholdAllergenFilterTile()),
        );
        await tester.pump();

        await tester.tap(find.byType(ButleryListRow));
        await tester.pumpAndSettle();

        expect(find.text(sv.householdAllergenOffTitle), findsOneWidget);
        expect(
          find.textContaining(
            AllergenPreferenceOptions.getAllergenLabel('gluten'),
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'an owner whose settings were read and hold nothing is NOT protected '
      'alone, so a floor allergen IS named — even though the getter would '
      'claim the owner tracks it',
      (tester) async {
        when(() => household.hasHousehold).thenReturn(true);
        // Production shape: profile read and empty, getter substituting the
        // defaults. The two sources disagree on gluten, so a dialog reading
        // the getter would wrongly subtract it and show the generic body.
        when(() => userService.currentUserProfile).thenReturn(
          _profile(useHousehold: true, settingsMerged: true),
        );
        when(
          () => userService.allergenPreferences,
        ).thenReturn(UserAllergenPreferences.defaults);

        await tester.pumpWidget(
          createLocalizedTestApp(child: const HouseholdAllergenFilterTile()),
        );
        await tester.pump();

        await tester.tap(find.byType(ButleryListRow));
        await tester.pumpAndSettle();

        expect(find.text(sv.householdAllergenOffTitle), findsOneWidget);
        expect(
          find.textContaining(
            AllergenPreferenceOptions.getAllergenLabel('gluten'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'the warning names only NEWLY-exposed allergens, not the owner\'s own',
      (tester) async {
        // Owner already tracks gluten (stays filtered after opt-out); the
        // household adds laktos. Only laktos becomes newly exposed, so the
        // warning must name laktos and NOT gluten.
        when(() => household.hasHousehold).thenReturn(true);
        const ownerGluten = UserAllergenPreferences(
          trackedAllergens: {'gluten'},
          trackedDietary: {},
        );
        when(
          () => userService.currentUserProfile,
        ).thenReturn(_profile(useHousehold: true, prefs: ownerGluten));
        when(() => userService.allergenPreferences).thenReturn(ownerGluten);
        when(() => household.aggregateAllergenPreferences()).thenAnswer(
          (_) async => const HouseholdAllergenAggregate.complete(
            UserAllergenPreferences(
              trackedAllergens: {'gluten', 'laktos'},
              trackedDietary: {},
            ),
          ),
        );

        await tester.pumpWidget(
          createLocalizedTestApp(child: const HouseholdAllergenFilterTile()),
        );
        await tester.pump();

        await tester.tap(find.byType(ButleryListRow));
        await tester.pumpAndSettle();

        expect(
          find.textContaining(
            AllergenPreferenceOptions.getAllergenLabel('laktos'),
          ),
          findsOneWidget,
          reason: 'the household-only allergen (laktos) must be named',
        );
        expect(
          find.textContaining(
            AllergenPreferenceOptions.getAllergenLabel('gluten'),
          ),
          findsNothing,
          reason:
              'the owner\'s own allergen (gluten) stays filtered and must NOT '
              'be named as newly exposed',
        );
      },
    );

    testWidgets(
      'an incomplete roster names NO allergens and says the list may be '
      'partial (BUT-1663)',
      (tester) async {
        // A household member could not be read, so the aggregate carries the
        // widened safety floor rather than the family's real allergies.
        // Naming that floor would be a false statement in a child-safety
        // dialog: it would claim laktos-free protection is being dropped for
        // a family whose actual allergy nobody could read.
        when(() => household.hasHousehold).thenReturn(true);
        when(
          () => userService.currentUserProfile,
        ).thenReturn(_profile(useHousehold: true));
        when(() => userService.allergenPreferences).thenReturn(
          const UserAllergenPreferences(
            trackedAllergens: {},
            trackedDietary: {},
          ),
        );
        when(() => household.aggregateAllergenPreferences()).thenAnswer(
          (_) async => const HouseholdAllergenAggregate.degraded(
            preferences: UserAllergenPreferences(
              trackedAllergens: {'gluten', 'mjölk', 'nötter', 'jordnötter'},
              trackedDietary: {},
              includeUnknownInMenu: false,
            ),
            unresolvedMemberIds: ['kid'],
          ),
        );

        await tester.pumpWidget(
          createLocalizedTestApp(child: const HouseholdAllergenFilterTile()),
        );
        await tester.pump();

        await tester.tap(find.byType(ButleryListRow));
        await tester.pumpAndSettle();

        expect(find.text(sv.householdAllergenOffTitle), findsOneWidget);
        expect(
          find.textContaining(sv.householdAllergenRosterIncomplete),
          findsOneWidget,
          reason: 'the user must be told the allergen list may be incomplete',
        );
        expect(
          find.textContaining(
            AllergenPreferenceOptions.getAllergenLabel('gluten'),
          ),
          findsNothing,
          reason:
              'the safety floor is not the household\'s allergen list and '
              'must never be presented as one',
        );
      },
    );

    testWidgets('turning OFF then cancelling does NOT persist', (tester) async {
      when(() => household.hasHousehold).thenReturn(true);
      when(
        () => userService.currentUserProfile,
      ).thenReturn(_profile(useHousehold: true));

      await tester.pumpWidget(
        createLocalizedTestApp(child: const HouseholdAllergenFilterTile()),
      );
      await tester.pump();

      await tester.tap(find.byType(ButleryListRow));
      await tester.pumpAndSettle();

      await tester.tap(find.text(sv.commonCancel));
      await tester.pumpAndSettle();

      verifyNever(() => userService.setUseHouseholdAllergens(any()));
    });
  });
}
