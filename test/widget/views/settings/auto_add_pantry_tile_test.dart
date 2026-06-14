// BUT-1306: Widget gate for the Settings "Add bought items to pantry" switch.
//
// The tile reflects the user's `autoAddBoughtToPantry` opt-in, persists a flip
// via UserService.setAutoAddToPantry, and rebuilds when UserService notifies
// (so the one-time first-checkoff prompt enabling it elsewhere is mirrored in
// Settings without a re-enter). These tests prove that live wiring + the
// localised label in both locales — a refactor that drops the listener, wires
// the wrong l10n key, or stops persisting is caught.
//
// AutoAddPantryTile was made public specifically so it can be rendered in
// isolation here without the full SettingsHubView dependency graph.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/l10n/app_localizations_en.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/views/settings/settings_hub_view.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

class _MockUserService extends Mock implements UserService {}

UserProfile _profile({required bool autoAdd}) => UserProfile(
      uid: 'u1',
      displayName: 'Test',
      email: 't@example.com',
      joinedAt: DateTime(2024, 1, 1),
      lastActiveAt: DateTime(2024, 1, 1),
      autoAddBoughtToPantry: autoAdd,
    );

void main() {
  group('AutoAddPantryTile (BUT-1306)', () {
    late _MockUserService userService;

    setUp(() async {
      await GetIt.instance.reset();
      ServiceLocator.reset();

      userService = _MockUserService();
      when(() => userService.setAutoAddToPantry(any()))
          .thenAnswer((_) async {});

      final container = DIContainer();
      container.container.registerSingleton<UserService>(userService);
      ServiceLocator.initialize(container);
    });

    tearDown(() async {
      ServiceLocator.reset();
      await GetIt.instance.reset();
    });

    testWidgets('reflects the stored opt-in value (off)', (tester) async {
      when(() => userService.currentUserProfile)
          .thenReturn(_profile(autoAdd: false));

      await tester.pumpWidget(
        createLocalizedTestApp(child: const AutoAddPantryTile()),
      );
      await tester.pump();

      expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
          isFalse);
    });

    testWidgets('reflects the stored opt-in value (on)', (tester) async {
      when(() => userService.currentUserProfile)
          .thenReturn(_profile(autoAdd: true));

      await tester.pumpWidget(
        createLocalizedTestApp(child: const AutoAddPantryTile()),
      );
      await tester.pump();

      expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
          isTrue);
    });

    testWidgets('toggling the switch persists via UserService', (tester) async {
      when(() => userService.currentUserProfile)
          .thenReturn(_profile(autoAdd: false));

      await tester.pumpWidget(
        createLocalizedTestApp(child: const AutoAddPantryTile()),
      );
      await tester.pump();

      await tester.tap(find.byType(SwitchListTile));
      await tester.pump();

      verify(() => userService.setAutoAddToPantry(true)).called(1);
    });

    testWidgets('rebuilds when UserService notifies (mirrors external enable)',
        (tester) async {
      // Starts off; a real listener registration must drive a rebuild when the
      // profile flips elsewhere (e.g. the first-checkoff prompt enables it).
      var enabled = false;
      when(() => userService.currentUserProfile)
          .thenAnswer((_) => _profile(autoAdd: enabled));

      // The tile registers a real addListener in initState; emit by calling
      // the registered listeners through notifyListeners on the mock.
      when(() => userService.addListener(any())).thenReturn(null);
      when(() => userService.removeListener(any())).thenReturn(null);

      await tester.pumpWidget(
        createLocalizedTestApp(child: const AutoAddPantryTile()),
      );
      await tester.pump();
      expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
          isFalse);

      // Capture the listener the tile registered, flip the profile, fire it.
      final captured =
          verify(() => userService.addListener(captureAny())).captured;
      enabled = true;
      for (final l in captured) {
        (l as VoidCallback)();
      }
      await tester.pump();

      expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
          isTrue,
          reason: 'The tile must rebuild from a UserService notification.');
    });

    testWidgets('localises the title (sv + en)', (tester) async {
      when(() => userService.currentUserProfile)
          .thenReturn(_profile(autoAdd: false));
      final sv = AppLocalizationsSv();
      final en = AppLocalizationsEn();

      await tester.pumpWidget(
        createLocalizedTestApp(child: const AutoAddPantryTile()),
      );
      await tester.pump();
      expect(find.text(sv.settingsAutoAddPantryTitle), findsOneWidget);

      await tester.pumpWidget(
        createLocalizedTestApp(
          locale: const Locale('en'),
          child: const AutoAddPantryTile(),
        ),
      );
      await tester.pump();
      expect(find.text(en.settingsAutoAddPantryTitle), findsOneWidget,
          reason: 'English table must carry the new key — guards against a key '
              'added to one locale table but not the other.');
    });
  });
}
