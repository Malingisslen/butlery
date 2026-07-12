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

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/household_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/views/settings/widgets/household_allergen_filter_tile.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

class _MockUserService extends Mock implements UserService {}

class _MockHouseholdService extends Mock implements HouseholdService {}

UserProfile _profile({required bool useHousehold}) => UserProfile(
  uid: 'u1',
  displayName: 'Test',
  email: 't@example.com',
  joinedAt: DateTime(2024, 1, 1),
  lastActiveAt: DateTime(2024, 1, 1),
  useHouseholdAllergens: useHousehold,
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
      when(() => household.getAggregatedAllergenPreferences()).thenAnswer(
        (_) async => const UserAllergenPreferences(
          trackedAllergens: {'gluten'},
          trackedDietary: {},
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

      expect(find.byType(SwitchListTile), findsNothing);
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
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue,
      );
    });

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

      await tester.tap(find.byType(SwitchListTile));
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

        await tester.tap(find.byType(SwitchListTile));
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
      'the warning names only NEWLY-exposed allergens, not the owner\'s own',
      (tester) async {
        // Owner already tracks gluten (stays filtered after opt-out); the
        // household adds laktos. Only laktos becomes newly exposed, so the
        // warning must name laktos and NOT gluten.
        when(() => household.hasHousehold).thenReturn(true);
        when(
          () => userService.currentUserProfile,
        ).thenReturn(_profile(useHousehold: true));
        when(() => userService.allergenPreferences).thenReturn(
          const UserAllergenPreferences(
            trackedAllergens: {'gluten'},
            trackedDietary: {},
          ),
        );
        when(() => household.getAggregatedAllergenPreferences()).thenAnswer(
          (_) async => const UserAllergenPreferences(
            trackedAllergens: {'gluten', 'laktos'},
            trackedDietary: {},
          ),
        );

        await tester.pumpWidget(
          createLocalizedTestApp(child: const HouseholdAllergenFilterTile()),
        );
        await tester.pump();

        await tester.tap(find.byType(SwitchListTile));
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

    testWidgets('turning OFF then cancelling does NOT persist', (tester) async {
      when(() => household.hasHousehold).thenReturn(true);
      when(
        () => userService.currentUserProfile,
      ).thenReturn(_profile(useHousehold: true));

      await tester.pumpWidget(
        createLocalizedTestApp(child: const HouseholdAllergenFilterTile()),
      );
      await tester.pump();

      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      await tester.tap(find.text(sv.commonCancel));
      await tester.pumpAndSettle();

      verifyNever(() => userService.setUseHouseholdAllergens(any()));
    });
  });
}
