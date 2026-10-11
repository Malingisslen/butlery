// "Portioner som standard" (Mer, omtänkt del 2): the household-size default
// is chosen in a sheet on Familj & hushåll. The stepper drives the shared
// [UserProfileViewModel], Klar saves only a real change, a failed save keeps
// the sheet open with the change, and dismissing the sheet saves nothing.
//
// The last group is carried over from the household-size page's suite,
// which this sheet replaced: the profile-edit "cooking identity" section
// keeps the skill and cuisine controls BUT-1594 moved there.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/image_picker_service.dart';
import 'package:butlery/services/upload/image_upload_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/viewmodels/user_profile_viewmodel.dart';
import 'package:butlery/views/family/household_portions_sheet.dart';
import 'package:butlery/views/social/user_profile_edit/cooking_identity_section.dart';
import 'package:butlery/widgets/styled/styled_input.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

class _FakeUserService extends Fake implements UserService {
  _FakeUserService(this._profile);
  final UserProfile _profile;

  /// Every householdSize a save sent, the sentinel included.
  final saves = <Object?>[];
  bool failSaves = false;

  @override
  UserProfile? get currentUserProfile => _profile;

  @override
  String? get error => null;

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
  }) async {
    saves.add(householdSize);
    if (failSaves) return null;
    return _profile.copyWith(householdSize: householdSize as int?);
  }

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

  // The ViewModel is registered as a singleton so the test holds the exact
  // instance the sheet resolves in initState.
  (UserProfileViewModel, _FakeUserService) register() {
    final userService = _FakeUserService(_profile());
    final container = DIContainer();
    container.container.registerSingleton<UserService>(userService);
    // Before the VM: its constructor reads the profile through the locator.
    ServiceLocator.initialize(container);
    final vm = UserProfileViewModel(
      userService,
      _FakeImagePickerService(),
      uploadService: _FakeImageUploadService(),
    );
    container.container.registerSingleton<UserProfileViewModel>(vm);
    return (vm, userService);
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => showHouseholdPortionsSheet(context),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('HouseholdPortionsSheet', () {
    testWidgets('opens on the recipe default and steps up on +', (
      tester,
    ) async {
      final (vm, _) = register();
      await openSheet(tester);

      expect(find.text(sv.householdPortionsTitle), findsOneWidget);
      expect(vm.householdSize, isNull, reason: 'precondition: unset profile');
      expect(find.text(sv.householdSizeRecipeDefault), findsOneWidget);

      final plus = find.byTooltip(sv.a11yIncreaseHouseholdSize);
      await tester.tap(plus);
      await tester.pump();
      await tester.tap(plus);
      await tester.pump();

      expect(vm.householdSize, 2);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('clears back to the recipe default', (tester) async {
      final (vm, _) = register();
      await openSheet(tester);

      await tester.tap(find.byTooltip(sv.a11yIncreaseHouseholdSize));
      await tester.pump();
      expect(vm.householdSize, 1);

      await tester.tap(find.text(sv.householdSizeUseRecipeDefault));
      await tester.pump();

      expect(vm.householdSize, isNull);
      expect(find.text(sv.householdSizeRecipeDefault), findsOneWidget);
    });

    testWidgets('Klar saves the new value and closes the sheet', (
      tester,
    ) async {
      final (_, userService) = register();
      await openSheet(tester);

      await tester.tap(find.byTooltip(sv.a11yIncreaseHouseholdSize));
      await tester.pump();
      await tester.tap(find.text(sv.commonDone));
      await tester.pumpAndSettle();

      expect(userService.saves, [1]);
      expect(find.text(sv.householdPortionsTitle), findsNothing);
      expect(find.text(sv.householdPortionsSaved), findsOneWidget);
    });

    testWidgets('Klar without a change closes the sheet and writes nothing', (
      tester,
    ) async {
      final (_, userService) = register();
      await openSheet(tester);

      await tester.tap(find.text(sv.commonDone));
      await tester.pumpAndSettle();

      expect(userService.saves, isEmpty);
      expect(find.text(sv.householdPortionsTitle), findsNothing);
    });

    testWidgets('a failed save keeps the sheet open with the change', (
      tester,
    ) async {
      final (vm, userService) = register();
      userService.failSaves = true;
      await openSheet(tester);

      await tester.tap(find.byTooltip(sv.a11yIncreaseHouseholdSize));
      await tester.pump();
      await tester.tap(find.text(sv.commonDone));
      await tester.pumpAndSettle();

      expect(userService.saves, [1]);
      expect(find.text(sv.householdPortionsTitle), findsOneWidget);
      expect(vm.householdSize, 1);
    });

    testWidgets('dismissing the sheet saves nothing', (tester) async {
      final (_, userService) = register();
      await openSheet(tester);

      await tester.tap(find.byTooltip(sv.a11yIncreaseHouseholdSize));
      await tester.pump();
      // The barrier above the sheet.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.text(sv.householdPortionsTitle), findsNothing);
      expect(userService.saves, isEmpty);
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
        final (vm, _) = register();
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
        expect(
          find.byType(StyledInput),
          findsOneWidget,
          reason: 'the bio field must remain in the profile-edit section',
        );

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
