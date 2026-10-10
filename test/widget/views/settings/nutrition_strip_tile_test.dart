// BUT-643: widget gate for the Settings "show nutrition strip" switch.
//
// Proves: the tile reflects the stored value (default off), a tap persists the
// new value at once with no dialog, and a write that fails says so.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/views/settings/widgets/nutrition_strip_tile.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

class _MockUserService extends Mock implements UserService {}

UserProfile _profile({required bool strip}) => UserProfile(
  uid: 'u1',
  displayName: 'Test',
  email: 't@example.com',
  joinedAt: DateTime(2024, 1, 1),
  lastActiveAt: DateTime(2024, 1, 1),
  showNutritionStrip: strip,
);

void main() {
  final sv = AppLocalizationsSv();

  group('NutritionStripTile (BUT-643)', () {
    late _MockUserService userService;

    setUp(() async {
      await GetIt.instance.reset();
      ServiceLocator.reset();

      userService = _MockUserService();
      when(() => userService.addListener(any())).thenReturn(null);
      when(() => userService.removeListener(any())).thenReturn(null);
      when(
        () => userService.setShowNutritionStrip(any()),
      ).thenAnswer((_) async {});

      final container = DIContainer();
      container.container.registerSingleton<UserService>(userService);
      ServiceLocator.initialize(container);
    });

    tearDown(() async {
      ServiceLocator.reset();
      await GetIt.instance.reset();
    });

    Future<void> pumpTile(WidgetTester tester, {bool strip = false}) async {
      when(
        () => userService.currentUserProfile,
      ).thenReturn(_profile(strip: strip));
      await tester.pumpWidget(
        createLocalizedTestApp(child: const NutritionStripTile()),
      );
      await tester.pump();
    }

    testWidgets('is shown off by default with its title', (tester) async {
      await pumpTile(tester);

      expect(find.text(sv.settingsNutritionStripTitle), findsOneWidget);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse,
      );
    });

    testWidgets('reflects a stored ON value', (tester) async {
      await pumpTile(tester, strip: true);

      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue,
      );
    });

    testWidgets('turning ON persists at once with no dialog', (tester) async {
      await pumpTile(tester);

      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      verify(() => userService.setShowNutritionStrip(true)).called(1);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('turning OFF persists at once', (tester) async {
      await pumpTile(tester, strip: true);

      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      verify(() => userService.setShowNutritionStrip(false)).called(1);
    });

    testWidgets('a save that throws says the setting was not saved', (
      tester,
    ) async {
      when(
        () => userService.setShowNutritionStrip(any()),
      ).thenAnswer((_) => Future<void>.error(Exception('offline')));
      await pumpTile(tester);

      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      expect(find.textContaining(sv.settingsSaveFailed), findsOneWidget);
    });
  });
}
