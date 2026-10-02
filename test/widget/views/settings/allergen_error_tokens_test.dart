// BUT-2183 5n: the allergen settings' save error leaves the old opacity steps.
// Colours only: the box is the mode's danger surface tint with no border, and
// the glyph and message are onErrorContainer. Runs in both
// modes and asserts the fill, the missing border and the glyph and text
// colours.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/views/settings/allergen_preferences_view.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

late AppLocalizations _sv;

class _MockUserService extends Mock implements UserService {}

Future<void> _pumpWithSaveError(WidgetTester tester, ThemeData theme) async {
  tester.view.physicalSize = const Size(420, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  // The test font is wider than the production one, so rows overflow the
  // viewport; these tests read colours, not layout.
  final originalHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('overflowed')) return;
    originalHandler?.call(details);
  };
  addTearDown(() => FlutterError.onError = originalHandler);

  final service = _MockUserService();
  when(
    () => service.allergenPreferences,
  ).thenReturn(UserAllergenPreferences.defaults);
  when(() => service.updateAllergenPreferences(any())).thenAnswer(
    (_) async => false,
  );
  GetIt.instance.registerSingleton<UserService>(service);
  prod.ServiceLocator.initialize(DIContainer());

  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      locale: const Locale('sv', 'SE'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const AllergenPreferencesView(),
    ),
  );
  await tester.pump();

  // A change makes the save action appear; the refused save raises the error.
  await tester.tap(
    find.text(AllergenPreferenceOptions.allergens.values.first).first,
  );
  await tester.pump();
  await tester.tap(find.text(_sv.commonSave));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  setUpAll(() async {
    _sv = await AppLocalizations.delegate.load(const Locale('sv', 'SE'));
  });

  setUp(() async {
    await GetIt.instance.reset();
    registerFallbackValue(UserAllergenPreferences.defaults);
  });

  tearDown(() async {
    prod.ServiceLocator.reset();
    await GetIt.instance.reset();
  });

  for (final (mode, theme) in [
    ('light', AppTheme.lightTheme),
    ('dark', AppTheme.darkTheme),
  ]) {
    final cs = theme.colorScheme;
    final modeColors = ModeColors.of(theme.brightness);

    testWidgets(
      'the save error is the danger tint with no border and onErrorContainer '
      'glyph and text, $mode',
      (tester) async {
        await _pumpWithSaveError(tester, theme);

        final text = find.textContaining(
          _sv.errorCouldNotUpdateAllergenSettings,
        );
        expect(text, findsOneWidget);
        final box =
            tester
                    .widget<Container>(
                      find
                          .ancestor(
                            of: text,
                            matching: find.byWidgetPredicate(
                              (w) =>
                                  w is Container &&
                                  w.decoration is BoxDecoration,
                            ),
                          )
                          .first,
                    )
                    .decoration!
                as BoxDecoration;
        expect(box.color, modeColors.surfaceTintDanger);
        expect(box.border, isNull);
        expect(tester.widget<Text>(text).style?.color, cs.onErrorContainer);
        expect(
          tester
              .widget<Icon>(find.byIcon(ButleryIcons.triangleAlert).first)
              .color,
          cs.onErrorContainer,
        );
      },
    );
  }
}
