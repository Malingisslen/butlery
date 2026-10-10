// BUT-1306: the "Add bought items to pantry" switch under Appinställningar.
//
// The row reflects the user's `autoAddBoughtToPantry` opt-in, persists a flip
// via UserService.setAutoAddToPantry, and rebuilds when UserService notifies
// (so the one-time first-checkoff prompt enabling it elsewhere is mirrored
// here without a re-enter).

import 'dart:ui' show Tristate;

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
import 'package:butlery/views/more/app_settings_view.dart';

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
  final sv = AppLocalizationsSv();
  late _MockUserService userService;

  setUp(() async {
    await GetIt.instance.reset();
    ServiceLocator.reset();

    userService = _MockUserService();
    when(() => userService.setAutoAddToPantry(any())).thenAnswer((_) async {});
    when(() => userService.addListener(any())).thenReturn(null);
    when(() => userService.removeListener(any())).thenReturn(null);

    final container = DIContainer();
    container.container.registerSingleton<UserService>(userService);
    ServiceLocator.initialize(container);
  });

  tearDown(() async {
    ServiceLocator.reset();
    await GetIt.instance.reset();
  });

  Tristate toggled(WidgetTester tester) => tester
      .getSemantics(
        find.bySemanticsLabel(RegExp('^${sv.settingsAutoAddPantryTitle}')),
      )
      .getSemanticsData()
      .flagsCollection
      .isToggled;

  testWidgets('reflects the stored opt-in value, off and on', (tester) async {
    final handle = tester.ensureSemantics();
    when(
      () => userService.currentUserProfile,
    ).thenReturn(_profile(autoAdd: false));
    await tester.pumpWidget(
      createLocalizedTestApp(child: const AutoAddPantryRow()),
    );
    await tester.pump();
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    expect(toggled(tester), Tristate.isFalse);

    when(
      () => userService.currentUserProfile,
    ).thenReturn(_profile(autoAdd: true));
    await tester.pumpWidget(
      createLocalizedTestApp(child: const AutoAddPantryRow(key: Key('again'))),
    );
    await tester.pump();
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    expect(toggled(tester), Tristate.isTrue);
    handle.dispose();
  });

  testWidgets('tapping the row persists the flip through UserService', (
    tester,
  ) async {
    when(
      () => userService.currentUserProfile,
    ).thenReturn(_profile(autoAdd: false));
    await tester.pumpWidget(
      createLocalizedTestApp(child: const AutoAddPantryRow()),
    );
    await tester.pump();

    // The subtitle, not the switch: the whole row is the control.
    await tester.tap(find.text(sv.settingsAutoAddPantrySubtitle));
    await tester.pump();

    verify(() => userService.setAutoAddToPantry(true)).called(1);
  });

  testWidgets('rebuilds when UserService notifies (mirrors an external '
      'enable)', (tester) async {
    var enabled = false;
    when(
      () => userService.currentUserProfile,
    ).thenAnswer((_) => _profile(autoAdd: enabled));

    await tester.pumpWidget(
      createLocalizedTestApp(child: const AutoAddPantryRow()),
    );
    await tester.pump();
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);

    final captured = verify(
      () => userService.addListener(captureAny()),
    ).captured;
    enabled = true;
    for (final l in captured) {
      (l as VoidCallback)();
    }
    await tester.pump();

    expect(
      tester.widget<Switch>(find.byType(Switch)).value,
      isTrue,
      reason: 'The row must rebuild from a UserService notification.',
    );
  });

  testWidgets('localises the title (sv + en)', (tester) async {
    when(
      () => userService.currentUserProfile,
    ).thenReturn(_profile(autoAdd: false));
    final en = AppLocalizationsEn();

    await tester.pumpWidget(
      createLocalizedTestApp(child: const AutoAddPantryRow()),
    );
    await tester.pump();
    expect(find.text(sv.settingsAutoAddPantryTitle), findsOneWidget);

    await tester.pumpWidget(
      createLocalizedTestApp(
        locale: const Locale('en'),
        child: const AutoAddPantryRow(),
      ),
    );
    await tester.pump();
    expect(find.text(en.settingsAutoAddPantryTitle), findsOneWidget);
  });
}
