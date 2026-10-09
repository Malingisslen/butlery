/// BUT-2221: the "show my name on my dishes" switch in [PrivacySettingsSection].
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
  Future<bool> setShowNameOnSharedDishes(bool enabled) async {
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

UserProfile _profile({bool isMinor = false}) => UserProfile(
  uid: 'me',
  displayName: 'Malin',
  email: 'me@example.com',
  joinedAt: DateTime(2025, 1, 1),
  lastActiveAt: DateTime(2025, 1, 1),
  isMinor: isMinor,
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

  SwitchListTile tileFor(WidgetTester tester, String title) {
    final finder = find.ancestor(
      of: find.text(title),
      matching: find.byType(SwitchListTile),
    );
    expect(finder, findsOneWidget);
    return tester.widget<SwitchListTile>(finder);
  }

  testWidgets(
    'an adult sees it off and toggling writes through the view model',
    (
      tester,
    ) async {
      final (vm, service, l10n) = await _pump(tester, _profile());
      final title = l10n.privacyShowNameOnDishesTitle;

      expect(tileFor(tester, title).value, isFalse);
      expect(find.text(l10n.privacyShowNameOnDishesSubtitle), findsOneWidget);
      expect(find.text(l10n.privacyShowNameOnDishesMinor), findsNothing);

      await tester.tap(find.text(title));
      await tester.pump();

      expect(service.writes, [true]);
      expect(vm.showNameOnSharedDishes, isTrue);
      expect(tileFor(tester, title).value, isTrue);
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
    final title = l10n.privacyShowNameOnDishesTitle;

    await tester.tap(find.text(title));
    await tester.pump();

    expect(service.writes, [true], reason: 'the attempt reached the service');
    expect(
      find.textContaining(l10n.errorCouldNotSaveDishCredit),
      findsOneWidget,
    );
    expect(vm.showNameOnSharedDishes, isFalse);
    expect(tileFor(tester, title).value, isFalse);
  });

  testWidgets(
    'a minor sees the switch disabled with the reason, and no write',
    (
      tester,
    ) async {
      final (_, service, l10n) = await _pump(tester, _profile(isMinor: true));
      final title = l10n.privacyShowNameOnDishesTitle;

      expect(tileFor(tester, title).onChanged, isNull);
      expect(find.text(l10n.privacyShowNameOnDishesMinor), findsOneWidget);
      expect(find.text(l10n.privacyShowNameOnDishesSubtitle), findsNothing);

      await tester.tap(find.text(title), warnIfMissed: false);
      await tester.pump();

      expect(service.writes, isEmpty);
    },
  );
}
