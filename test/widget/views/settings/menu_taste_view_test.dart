// BUT-1320 (UI half): Settings > "Meny och smak".
//
// Intent: prove the weekly-menu tuning controls (cooking skill + cuisine
// affinities) are surfaced in Settings with copy that names their effect on the
// menu, and that they drive the SAME shared [UserProfileViewModel] the
// profile-edit section uses — so tuning here reaches the menu scorer.
//
// Three behaviours are pinned:
//   1. The view renders both controls plus the explanatory intro line.
//   2. Selecting a skill segment persists onto the shared ViewModel (proving
//      the control is wired, not decorative).
//   3. The Settings-hub row navigates to the menu-taste route.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/providers/locale_provider.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/image_picker_service.dart';
import 'package:butlery/services/moderation/report_service.dart';
import 'package:butlery/services/upload/image_upload_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/viewmodels/user_profile_viewmodel.dart';
import 'package:butlery/views/settings/menu_taste_view.dart';
import 'package:butlery/views/settings/settings_hub_view.dart';
import 'package:butlery/views/social/user_profile_edit/cooking_identity_section.dart';
import 'package:butlery/widgets/styled/styled_input.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

class _MockReportService extends Mock implements ReportService {}

class _FakeUserService extends Fake implements UserService {
  _FakeUserService(this._profile);
  final UserProfile _profile;

  @override
  UserProfile? get currentUserProfile => _profile;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

class _FakeImagePickerService extends Fake implements ImagePickerService {}

class _FakeImageUploadService extends Fake implements ImageUploadService {}

UserProfile _profile() => UserProfile(
  uid: 'me',
  displayName: 'Malin',
  email: 'me@example.com',
  joinedAt: DateTime(2025, 1, 1),
  lastActiveAt: DateTime(2025, 1, 1),
);

void main() {
  final sv = AppLocalizationsSv();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await GetIt.instance.reset();
    ServiceLocator.reset();
  });

  tearDown(() async {
    ServiceLocator.reset();
    await GetIt.instance.reset();
  });

  // Registers the shared ViewModel as a singleton so the test can hold the exact
  // instance the view resolves via ServiceLocator.get in initState.
  UserProfileViewModel registerVm() {
    final userService = _FakeUserService(_profile());
    final container = DIContainer();
    container.container.registerSingleton<UserService>(userService);
    // Initialize before constructing the VM — its constructor reads
    // currentProfile via ServiceLocator.get<UserService>().
    ServiceLocator.initialize(container);
    final vm = UserProfileViewModel(
      userService,
      _FakeImagePickerService(),
      uploadService: _FakeImageUploadService(),
    );
    container.container.registerSingleton<UserProfileViewModel>(vm);
    return vm;
  }

  group('MenuTasteView (BUT-1320)', () {
    testWidgets('renders the intro line and both tuning controls', (
      tester,
    ) async {
      registerVm();

      await tester.pumpWidget(
        createLocalizedTestApp(
          wrapInScaffold: false,
          child: const MenuTasteView(),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(sv.menuTasteIntro),
        findsOneWidget,
        reason: 'the point-of-use copy naming the menu effect must render',
      );
      expect(
        find.byType(SegmentedButton<CookingSkillLevel>),
        findsOneWidget,
        reason: 'the cooking-skill selector must render',
      );
      // A representative cuisine chip proves the affinity picker rendered.
      expect(
        find.widgetWithText(FilterChip, 'italiensk'),
        findsOneWidget,
        reason: 'the cuisine-affinity chips must render',
      );
    });

    testWidgets('selecting a skill segment persists on the shared ViewModel', (
      tester,
    ) async {
      final vm = registerVm();

      await tester.pumpWidget(
        createLocalizedTestApp(
          wrapInScaffold: false,
          child: const MenuTasteView(),
        ),
      );
      await tester.pumpAndSettle();

      expect(vm.cookingSkillLevel, isNull, reason: 'precondition: unset');

      await tester.tap(find.text(sv.profileCookingSkillAdvanced));
      await tester.pump();

      expect(
        vm.cookingSkillLevel,
        CookingSkillLevel.advanced,
        reason: 'tapping a segment must update the shared ViewModel',
      );
    });

    // Guards the point-of-use contract: a freshly-loaded profile has nothing to
    // save, so the button is inert; a real tuning change must arm it. A
    // regression that dropped the `hasUnsavedChanges` gate would either leave
    // the button permanently dead (change lost) or let an empty save fire.
    testWidgets('Save button is disabled until a control changes', (
      tester,
    ) async {
      registerVm();

      await tester.pumpWidget(
        createLocalizedTestApp(
          wrapInScaffold: false,
          child: const MenuTasteView(),
        ),
      );
      await tester.pumpAndSettle();

      final saveButton = find.widgetWithText(ElevatedButton, sv.commonSave);
      expect(saveButton, findsOneWidget);

      expect(
        tester.widget<ElevatedButton>(saveButton).onPressed,
        isNull,
        reason: 'no unsaved changes yet → Save must be disabled',
      );

      await tester.tap(find.text(sv.profileCookingSkillAdvanced));
      await tester.pump();

      expect(
        tester.widget<ElevatedButton>(saveButton).onPressed,
        isNotNull,
        reason: 'a tuning change must arm the Save button',
      );
    });
  });

  group('Household size control (BUT-1322)', () {
    testWidgets('renders the null state and steps up on +', (tester) async {
      final vm = registerVm();

      await tester.pumpWidget(
        createLocalizedTestApp(
          wrapInScaffold: false,
          child: const MenuTasteView(),
        ),
      );
      await tester.pumpAndSettle();

      expect(vm.householdSize, isNull, reason: 'precondition: unset profile');
      expect(
        find.text(sv.householdSizeRecipeDefault),
        findsOneWidget,
        reason: 'null state must read as "recipe default", not a number',
      );

      final plus = find.byTooltip(sv.a11yIncreaseHouseholdSize);
      await tester.ensureVisible(plus);
      await tester.pumpAndSettle();
      await tester.tap(plus);
      await tester.pump();
      await tester.tap(plus);
      await tester.pump();

      expect(
        vm.householdSize,
        2,
        reason: 'two + taps from unset must land on 2 on the shared VM',
      );
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('clears back to recipe default', (tester) async {
      final vm = registerVm();

      await tester.pumpWidget(
        createLocalizedTestApp(
          wrapInScaffold: false,
          child: const MenuTasteView(),
        ),
      );
      await tester.pumpAndSettle();

      final plus = find.byTooltip(sv.a11yIncreaseHouseholdSize);
      await tester.ensureVisible(plus);
      await tester.pumpAndSettle();
      await tester.tap(plus);
      await tester.pump();
      expect(vm.householdSize, 1);

      final clear = find.text(sv.householdSizeUseRecipeDefault);
      await tester.ensureVisible(clear);
      await tester.pumpAndSettle();
      await tester.tap(clear);
      await tester.pump();

      expect(
        vm.householdSize,
        isNull,
        reason: 'the clear affordance must return the setting to null',
      );
      expect(find.text(sv.householdSizeRecipeDefault), findsOneWidget);
    });
  });

  group('SettingsHub row → MenuTaste route (BUT-1320)', () {
    testWidgets('the "Meny och smak" tile navigates to the menu-taste route', (
      tester,
    ) async {
      // SettingsHubView's own dependency graph (admin stream + embedded tiles).
      final reportService = _MockReportService();
      when(
        () => reportService.watchIsAdmin(),
      ).thenAnswer((_) => Stream<bool>.value(false));
      final container = DIContainer();
      container.container.registerSingleton<ReportService>(reportService);
      container.container.registerSingleton<LocaleProvider>(LocaleProvider());
      container.container.registerSingleton<UserService>(
        _FakeUserService(_profile()),
      );
      ServiceLocator.initialize(container);

      String? pushedRoute;
      await tester.pumpWidget(
        createLocalizedTestApp(
          wrapInScaffold: false,
          child: const SettingsHubView(),
          onGenerateRoute: (settings) {
            pushedRoute = settings.name;
            return MaterialPageRoute<void>(
              builder: (_) => const SizedBox.shrink(),
              settings: settings,
            );
          },
        ),
      );
      await tester.pump();

      await tester.tap(find.text(sv.settingsMenuTasteTitle));
      await tester.pump();

      expect(
        pushedRoute,
        Routes.settingsMenuTaste,
        reason: 'the hub row must push the menu-taste route',
      );
    });
  });

  // Refactor guard: BUT-1320 pulled the skill + cuisine controls OUT of the
  // profile-edit "cooking identity" section into the shared
  // CookingPreferenceControls. This proves the profile-edit entry point still
  // renders BOTH the shared controls AND its own bio field (extraction didn't
  // drop the profile-only bits), and that the shared control stays wired to the
  // same ViewModel here — a toggle must reach cuisineAffinities. Without this,
  // the extraction could have silently broken the profile side while the
  // Settings side stayed green.
  group('CookingIdentitySection after extraction (BUT-1320 regression)', () {
    testWidgets(
      'keeps skill + cuisine controls and the bio field, wired to VM',
      (tester) async {
        final vm = registerVm();
        final bioController = TextEditingController();
        addTearDown(bioController.dispose);

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: CookingIdentitySection(
              bioController: bioController,
              viewModel: vm,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Shared control survived the extraction.
        expect(
          find.byType(SegmentedButton<CookingSkillLevel>),
          findsOneWidget,
          reason:
              'skill selector must still render in the profile-edit section',
        );
        expect(
          find.widgetWithText(FilterChip, 'italiensk'),
          findsOneWidget,
          reason: 'cuisine chips must still render in the profile-edit section',
        );
        // Profile-only bit that must NOT have been dropped by the extraction.
        expect(
          find.byType(StyledInput),
          findsOneWidget,
          reason: 'the bio field must remain in the profile-edit section',
        );

        // The shared control is still wired to the same ViewModel here.
        expect(vm.cuisineAffinities, isEmpty, reason: 'precondition');
        await tester.tap(find.widgetWithText(FilterChip, 'italiensk'));
        await tester.pump();
        expect(
          vm.cuisineAffinities,
          contains('italiensk'),
          reason: 'toggling a chip in the profile section must reach the VM',
        );
      },
    );
  });
}
