// BUT-1594: Settings > "Hushållsstorlek".
//
// Intent: prove the screen now surfaces ONLY the household-size stepper (its
// intro copy + stepper), that the cuisine/skill tuning controls have LEFT this
// screen (they moved off the menu in BUT-1594), that the stepper drives the
// shared [UserProfileViewModel], and that the Settings-hub row navigates to the
// renamed route. A final regression group proves the profile-edit "cooking
// identity" section still carries the cuisine/skill controls.

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
import 'package:butlery/views/settings/household_size_view.dart';
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

  // Lets saveProfile() succeed in the exit-dialog-Save test — a household-only
  // edit skips the display-name availability check, so this is the only service
  // call the save makes. Echoes the profile back so the VM syncs its baseline.
  @override
  Future<UserProfile?> createOrUpdateProfile({
    required String displayName,
    String? avatarUrl,
    bool? isSearchable,
    bool? allowEmailSearch,
    CookingSkillLevel? cookingSkillLevel,
    List<String>? cuisineAffinities,
    String? bio,
    bool? showOnlineStatus,
    bool? shareActivityToFeed,
    Map<String, bool>? activityFeedEventTypes,
    Object? householdSize = UserService.householdSizeUntouched,
  }) async => _profile;

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

  group('HouseholdSizeView (BUT-1594)', () {
    testWidgets('renders the intro line and the household stepper only', (
      tester,
    ) async {
      registerVm();

      await tester.pumpWidget(
        createLocalizedTestApp(
          wrapInScaffold: false,
          child: const HouseholdSizeView(),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(sv.householdSettingsIntro),
        findsOneWidget,
        reason: 'the point-of-use intro must render',
      );
      // The household stepper is present (its null-state label).
      expect(
        find.text(sv.householdSizeRecipeDefault),
        findsOneWidget,
        reason: 'the household-size stepper must render',
      );
      // Regression: the cuisine/skill tuning controls must NOT be on this
      // screen anymore — they left the menu in BUT-1594.
      expect(
        find.byType(SegmentedButton<CookingSkillLevel>),
        findsNothing,
        reason: 'the cooking-skill selector must be gone from the menu screen',
      );
      expect(
        find.widgetWithText(FilterChip, 'italiensk'),
        findsNothing,
        reason: 'the cuisine-affinity chips must be gone from the menu screen',
      );
    });

    // Guards the point-of-use contract: a freshly-loaded profile has nothing to
    // save, so the button is inert; a real household change must arm it. A
    // regression that dropped the `hasUnsavedChanges` gate would either leave
    // the button permanently dead (change lost) or let an empty save fire.
    testWidgets('Save button is disabled until the household size changes', (
      tester,
    ) async {
      registerVm();

      await tester.pumpWidget(
        createLocalizedTestApp(
          wrapInScaffold: false,
          child: const HouseholdSizeView(),
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

      final plus = find.byTooltip(sv.a11yIncreaseHouseholdSize);
      await tester.ensureVisible(plus);
      await tester.pumpAndSettle();
      await tester.tap(plus);
      await tester.pump();

      expect(
        tester.widget<ElevatedButton>(saveButton).onPressed,
        isNotNull,
        reason: 'a household-size change must arm the Save button',
      );
    });

    // BUT-1594 review (finding 3): the unsaved-changes exit dialog's "Spara"
    // must both persist AND leave the screen — like the profile-edit guard it
    // mirrors — not save then strand the user on the screen (a second back
    // press). Pushes the view onto a navigator so a successful save can pop it.
    testWidgets('exit-dialog Save persists and leaves the screen', (
      tester,
    ) async {
      registerVm();

      await tester.pumpWidget(
        createLocalizedTestApp(
          wrapInScaffold: false,
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const HouseholdSizeView(),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(HouseholdSizeView), findsOneWidget);

      // Make an unsaved change, then request back (system back → PopScope).
      final plus = find.byTooltip(sv.a11yIncreaseHouseholdSize);
      await tester.ensureVisible(plus);
      await tester.pumpAndSettle();
      await tester.tap(plus);
      await tester.pump();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      // The unsaved-changes dialog is up; tap Save.
      expect(find.text(sv.profileUnsavedChanges), findsOneWidget);
      await tester.tap(find.widgetWithText(ElevatedButton, sv.commonSave).last);
      await tester.pumpAndSettle();

      // The screen has left (successful save) — the caller is back on 'open'.
      expect(
        find.byType(HouseholdSizeView),
        findsNothing,
        reason: 'a successful exit-dialog Save must pop the screen',
      );
      expect(find.text('open'), findsOneWidget);
    });
  });

  group('Household size control (BUT-1322)', () {
    testWidgets('renders the null state and steps up on +', (tester) async {
      final vm = registerVm();

      await tester.pumpWidget(
        createLocalizedTestApp(
          wrapInScaffold: false,
          child: const HouseholdSizeView(),
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
          child: const HouseholdSizeView(),
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

  group('SettingsHub row → Household-size route (BUT-1594)', () {
    testWidgets('the "Hushållsstorlek" tile navigates to the new route', (
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

      await tester.tap(find.text(sv.settingsHouseholdSizeTitle));
      await tester.pump();

      expect(
        pushedRoute,
        Routes.settingsHousehold,
        reason: 'the hub row must push the household-size route',
      );
    });
  });

  // Refactor guard: the skill + cuisine controls live in the shared
  // CookingPreferenceControls, used by the profile-edit "cooking identity"
  // section. BUT-1594 removed them from the Settings/menu screen but they MUST
  // stay on profile-edit (social bio data). This proves the profile-edit entry
  // point still renders the shared controls AND its own bio field, and that the
  // shared control stays wired to the same ViewModel — a toggle must reach
  // cuisineAffinities.
  group('CookingIdentitySection keeps skill + cuisine (BUT-1594)', () {
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

        // Shared control still present on profile-edit.
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
        // Profile-only bit that must NOT have been dropped.
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
