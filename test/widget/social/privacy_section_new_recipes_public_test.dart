/// The "new recipes are public" switch in [PrivacySettingsSection].
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/image_picker_service.dart';
import 'package:butlery/services/upload/image_upload_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/viewmodels/user_profile_viewmodel.dart';
import 'package:butlery/views/social/user_profile_edit/privacy_section.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';

class _RecordingUserService extends Fake implements UserService {
  _RecordingUserService(this._profile, {this.writeSucceeds = true});
  final UserProfile _profile;
  final bool writeSucceeds;
  final List<bool> writes = [];

  @override
  UserProfile? get currentUserProfile => _profile;

  @override
  String? get error => null;

  @override
  Future<bool> setNewRecipesShowOnProfile(bool enabled) async {
    writes.add(enabled);
    return writeSucceeds;
  }

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

class _FakeImagePickerService extends Fake implements ImagePickerService {}

class _FakeImageUploadService extends Fake implements ImageUploadService {}

UserProfile _profile({
  bool isMinor = false,
  bool newRecipesShowOnProfile = false,
}) => UserProfile(
  uid: 'me',
  displayName: 'Malin',
  email: 'me@example.com',
  joinedAt: DateTime(2025, 1, 1),
  lastActiveAt: DateTime(2025, 1, 1),
  isMinor: isMinor,
  newRecipesShowOnProfile: newRecipesShowOnProfile,
);

Future<(UserProfileViewModel, _RecordingUserService, AppLocalizations)> _pump(
  WidgetTester tester,
  UserProfile profile, {
  bool writeSucceeds = true,
}) async {
  final service = _RecordingUserService(
    profile,
    writeSucceeds: writeSucceeds,
  );
  GetIt.instance.registerSingleton<UserService>(service);
  production.ServiceLocator.initialize(DIContainer());
  final vm = UserProfileViewModel(
    service,
    _FakeImagePickerService(),
    uploadService: _FakeImageUploadService(),
  );
  addTearDown(vm.dispose);
  late AppLocalizations l10n;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('sv'),
      home: Scaffold(
        body: SingleChildScrollView(
          child: Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context);
              return ListenableBuilder(
                listenable: vm,
                builder: (_, __) => PrivacySettingsSection(viewModel: vm),
              );
            },
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return (vm, service, l10n);
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

  ButleryListRow tileFor(WidgetTester tester, String title) {
    final finder = find.ancestor(
      of: find.text(title),
      matching: find.byType(ButleryListRow),
    );
    expect(finder, findsOneWidget);
    return tester.widget<ButleryListRow>(finder);
  }

  testWidgets(
    'an adult sees it off and toggling writes through the view model',
    (
      tester,
    ) async {
      final (vm, service, l10n) = await _pump(tester, _profile());
      final title = l10n.privacyNewRecipesPublicTitle;

      expect(tileFor(tester, title).checked, isFalse);
      expect(find.text(l10n.privacyNewRecipesPublicSubtitle), findsOneWidget);
      expect(find.text(l10n.privacyPublicRecipesMinor), findsNothing);

      await tester.tap(find.text(title));
      await tester.pump();

      expect(service.writes, [true]);
      expect(vm.newRecipesShowOnProfile, isTrue);
      expect(tileFor(tester, title).checked, isTrue);
    },
  );

  testWidgets('a refused write tells the user and leaves the switch off', (
    tester,
  ) async {
    final (vm, service, l10n) = await _pump(
      tester,
      _profile(),
      writeSucceeds: false,
    );
    final title = l10n.privacyNewRecipesPublicTitle;

    await tester.tap(find.text(title));
    await tester.pump();

    expect(service.writes, [true], reason: 'the attempt reached the service');
    expect(
      find.textContaining(l10n.errorCouldNotSaveNewRecipesPublic),
      findsOneWidget,
    );
    expect(vm.newRecipesShowOnProfile, isFalse);
    expect(tileFor(tester, title).checked, isFalse);
  });

  testWidgets(
    'a minor sees the switch off and disabled with the reason, and no write',
    (
      tester,
    ) async {
      final (_, service, l10n) = await _pump(tester, _profile(isMinor: true));
      final title = l10n.privacyNewRecipesPublicTitle;

      expect(tileFor(tester, title).enabled, isFalse);
      expect(tileFor(tester, title).checked, isFalse);
      expect(find.text(l10n.privacyPublicRecipesMinor), findsOneWidget);
      expect(find.text(l10n.privacyNewRecipesPublicSubtitle), findsNothing);

      await tester.tap(find.text(title), warnIfMissed: false);
      await tester.pump();

      expect(service.writes, isEmpty);
    },
  );

  testWidgets(
    'a minor whose stored setting is on still sees the switch off and disabled',
    (tester) async {
      final (_, service, l10n) = await _pump(
        tester,
        _profile(isMinor: true, newRecipesShowOnProfile: true),
      );
      final title = l10n.privacyNewRecipesPublicTitle;

      expect(tileFor(tester, title).checked, isFalse);
      expect(tileFor(tester, title).enabled, isFalse);

      await tester.tap(find.text(title), warnIfMissed: false);
      await tester.pump();

      expect(service.writes, isEmpty);
    },
  );
}
