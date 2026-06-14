/// Widget tests for the BUT-1220 per-event-type activity-feed privacy toggles
/// inside [PrivacySettingsSection].
///
/// Intent: prove the two behaviours that the privacy contract depends on —
/// (1) an event type with NO stored entry defaults to ON (so a user who never
/// touched the per-type list still broadcasts everything), and (2) toggling a
/// type OFF persists through the real ViewModel (the next read reflects the new
/// value, not the absent-default). Also prove the per-type rows are disabled
/// while the master "share activity" switch is off, since they have no effect
/// then.
///
/// Step-0 note (BUT-1270): the ticket text also asked for a "one-time hint
/// banner". No such banner exists in privacy_section.dart, the ViewModel, or
/// the ARB strings — the feature was never built, so there is nothing to test.
/// Per the sprint Step-0 rule (current code wins over ticket text) this test is
/// scoped to the toggle list that actually ships; the banner is recorded as
/// not-yet-implemented on the Linear ticket.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/social/activity_event.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/image_picker_service.dart';
import 'package:butlery/services/upload/image_upload_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/viewmodels/user_profile_viewmodel.dart';
import 'package:butlery/views/social/user_profile_edit/privacy_section.dart';

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

UserProfile _profile({Map<String, bool> activityFeedEventTypes = const {}}) =>
    UserProfile(
      uid: 'me',
      displayName: 'Malin',
      email: 'me@example.com',
      joinedAt: DateTime(2025, 1, 1),
      lastActiveAt: DateTime(2025, 1, 1),
      shareActivityToFeed: true,
      activityFeedEventTypes: activityFeedEventTypes,
    );

Widget _wrap(UserProfileViewModel vm) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('sv'),
      home: Scaffold(
        // The real profile-edit view rebuilds this section on VM changes; mirror
        // that with a ListenableBuilder so notifyListeners() repaints the rows.
        body: SingleChildScrollView(
          child: ListenableBuilder(
            listenable: vm,
            builder: (_, __) => PrivacySettingsSection(viewModel: vm),
          ),
        ),
      ),
    );

UserProfileViewModel _buildVm(UserProfile profile) {
  GetIt.instance.registerSingleton<UserService>(_FakeUserService(profile));
  production.ServiceLocator.initialize(DIContainer());
  return UserProfileViewModel(
    _FakeUserService(profile),
    _FakeImagePickerService(),
    uploadService: _FakeImageUploadService(),
  );
}

/// Finds the [SwitchListTile] whose title renders [text].
SwitchListTile _switchByTitle(WidgetTester tester, String text) {
  final tile = find.ancestor(
    of: find.text(text),
    matching: find.byType(SwitchListTile),
  );
  expect(tile, findsOneWidget, reason: 'expected a toggle titled "$text"');
  return tester.widget<SwitchListTile>(tile);
}

void main() {
  setUp(() async {
    await GetIt.instance.reset();
    production.ServiceLocator.reset();
  });

  tearDown(() async {
    await GetIt.instance.reset();
    production.ServiceLocator.reset();
  });

  group('PrivacySettingsSection — activity-type toggles (BUT-1220)', () {
    testWidgets('a type with no stored entry defaults to ON (absent = enabled)',
        (tester) async {
      // Empty map → every per-type toggle must read as on.
      final vm = _buildVm(_profile(activityFeedEventTypes: const {}));
      await tester.pumpWidget(_wrap(vm));
      await tester.pump();

      final cooked = _switchByTitle(tester, 'När jag lagar ett recept');
      expect(cooked.value, isTrue,
          reason: 'an unset event type must default to ON');
      // Master switch is on, so the row is interactive.
      expect(cooked.onChanged, isNotNull,
          reason: 'rows are enabled while broadcasting is on');
    });

    testWidgets('a stored false renders the row OFF', (tester) async {
      final vm = _buildVm(_profile(
        activityFeedEventTypes: {ActivityEventType.cooked.name: false},
      ));
      await tester.pumpWidget(_wrap(vm));
      await tester.pump();

      final cooked = _switchByTitle(tester, 'När jag lagar ett recept');
      expect(cooked.value, isFalse,
          reason: 'an explicitly-disabled type must render OFF');
      // Sibling rows that were never set still default ON.
      final shared = _switchByTitle(tester, 'När jag delar ett recept');
      expect(shared.value, isTrue,
          reason: 'disabling one type must not affect untouched siblings');
    });

    testWidgets('toggling a type OFF persists through the ViewModel',
        (tester) async {
      final vm = _buildVm(_profile(activityFeedEventTypes: const {}));
      await tester.pumpWidget(_wrap(vm));
      await tester.pump();

      // Precondition: the type is on by default.
      expect(vm.isActivityEventTypeEnabled(ActivityEventType.cooked), isTrue);

      // Tap the row's SwitchListTile (tapping anywhere on the tile toggles it).
      final tile = find.ancestor(
        of: find.text('När jag lagar ett recept'),
        matching: find.byType(SwitchListTile),
      );
      await tester.tap(tile);
      await tester.pump();

      // The toggle persisted on the ViewModel...
      expect(vm.isActivityEventTypeEnabled(ActivityEventType.cooked), isFalse,
          reason: 'tapping the row must persist the new value');
      // ...and the rebuilt switch reflects it.
      final cooked = _switchByTitle(tester, 'När jag lagar ett recept');
      expect(cooked.value, isFalse);
    });

    testWidgets('per-type rows are disabled while the master switch is off',
        (tester) async {
      final vm = _buildVm(_profile(activityFeedEventTypes: const {}));
      await tester.pumpWidget(_wrap(vm));
      await tester.pump();

      // Turn the master "share activity" switch off.
      vm.updateShareActivityToFeed(false);
      await tester.pump();

      final cooked = _switchByTitle(tester, 'När jag lagar ett recept');
      expect(cooked.onChanged, isNull,
          reason: 'per-type rows are non-interactive when broadcasting is off');
      expect(cooked.value, isFalse,
          reason: 'rows read OFF while the master toggle is off');
    });
  });
}
