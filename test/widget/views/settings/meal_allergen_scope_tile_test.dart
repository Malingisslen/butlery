// BUT-2362: widget gate for the Settings "follow who is home" allergen switch.
//
// Proves: the tile is hidden without a household and while the household
// filter it narrows is off; turning it ON lowers a safety net, so it persists
// only after the confirm dialog is accepted; turning it OFF persists at once;
// and a write that fails says so instead of leaving a safety setting looking
// changed.

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/household_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/views/settings/widgets/meal_allergen_scope_tile.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

class _MockUserService extends Mock implements UserService {}

class _MockHouseholdService extends Mock implements HouseholdService {}

UserProfile _profile({
  required bool useHousehold,
  required bool mealScope,
}) => UserProfile(
  uid: 'u1',
  displayName: 'Test',
  email: 't@example.com',
  joinedAt: DateTime(2024, 1, 1),
  lastActiveAt: DateTime(2024, 1, 1),
  useHouseholdAllergens: useHousehold,
  useMealAllergenScope: mealScope,
);

void main() {
  final sv = AppLocalizationsSv();

  group('MealAllergenScopeTile (BUT-2362)', () {
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
        () => userService.setUseMealAllergenScope(any()),
      ).thenAnswer((_) async {});
      when(() => household.hasHousehold).thenReturn(true);

      final container = DIContainer();
      container.container.registerSingleton<UserService>(userService);
      container.container.registerSingleton<HouseholdService>(household);
      ServiceLocator.initialize(container);
    });

    tearDown(() async {
      ServiceLocator.reset();
      await GetIt.instance.reset();
    });

    Future<void> pumpTile(
      WidgetTester tester, {
      bool useHousehold = true,
      bool mealScope = false,
    }) async {
      when(() => userService.currentUserProfile).thenReturn(
        _profile(useHousehold: useHousehold, mealScope: mealScope),
      );
      await tester.pumpWidget(
        createLocalizedTestApp(child: const MealAllergenScopeTile()),
      );
      await tester.pump();
    }

    testWidgets('is hidden when the user has no household', (tester) async {
      when(() => household.hasHousehold).thenReturn(false);
      await pumpTile(tester);

      expect(find.byType(ButleryListRow), findsNothing);
    });

    testWidgets('is hidden while the household filter it narrows is off', (
      tester,
    ) async {
      await pumpTile(tester, useHousehold: false, mealScope: true);

      expect(find.byType(ButleryListRow), findsNothing);
    });

    testWidgets('is shown with its title when household and filter are on', (
      tester,
    ) async {
      await pumpTile(tester, mealScope: true);

      expect(find.text(sv.mealAllergenScopeTitle), findsOneWidget);
      expect(
        tester.widget<ButleryListRow>(find.byType(ButleryListRow)).checked,
        isTrue,
      );
    });

    testWidgets('turning ON asks first and persists only after confirm', (
      tester,
    ) async {
      await pumpTile(tester);

      await tester.tap(find.byType(ButleryListRow));
      await tester.pumpAndSettle();

      expect(find.text(sv.mealAllergenScopeOnTitle), findsOneWidget);
      verifyNever(() => userService.setUseMealAllergenScope(any()));

      await tester.tap(find.text(sv.mealAllergenScopeOnAction));
      await tester.pumpAndSettle();

      verify(() => userService.setUseMealAllergenScope(true)).called(1);
    });

    testWidgets('turning ON then cancelling does NOT persist', (tester) async {
      await pumpTile(tester);

      await tester.tap(find.byType(ButleryListRow));
      await tester.pumpAndSettle();
      await tester.tap(find.text(sv.commonCancel));
      await tester.pumpAndSettle();

      expect(find.text(sv.mealAllergenScopeOnTitle), findsNothing);
      verifyNever(() => userService.setUseMealAllergenScope(any()));
    });

    testWidgets('turning OFF persists at once with no dialog', (tester) async {
      await pumpTile(tester, mealScope: true);

      await tester.tap(find.byType(ButleryListRow));
      await tester.pumpAndSettle();

      expect(find.text(sv.mealAllergenScopeOnTitle), findsNothing);
      verify(() => userService.setUseMealAllergenScope(false)).called(1);
    });

    testWidgets('a save that throws says the setting was not saved', (
      tester,
    ) async {
      when(
        () => userService.setUseMealAllergenScope(any()),
      ).thenAnswer((_) => Future<void>.error(Exception('offline')));
      await pumpTile(tester, mealScope: true);

      await tester.tap(find.byType(ButleryListRow));
      await tester.pumpAndSettle();

      verify(() => userService.setUseMealAllergenScope(false)).called(1);
      expect(find.textContaining(sv.settingsSaveFailed), findsOneWidget);
    });
  });
}
