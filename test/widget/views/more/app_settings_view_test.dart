// Appinställningar under Mer: language and theme are picked in a bottom
// sheet, saved at once and confirmed in a snackbar; the notification row
// leads to Notisinställningar.

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
import 'package:butlery/services/theme_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/views/more/app_settings_view.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

class _MockUserService extends Mock implements UserService {}

void main() {
  final sv = AppLocalizationsSv();
  late LocaleProvider locale;
  late ThemeService theme;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await GetIt.instance.reset();
    ServiceLocator.reset();

    final users = _MockUserService();
    when(() => users.currentUserProfile).thenReturn(null);
    when(() => users.addListener(any())).thenReturn(null);
    when(() => users.removeListener(any())).thenReturn(null);

    locale = LocaleProvider();
    theme = ThemeService();
    final container = DIContainer();
    container.container.registerSingleton<UserService>(users);
    container.container.registerSingleton<LocaleProvider>(locale);
    container.container.registerSingleton<ThemeService>(theme);
    ServiceLocator.initialize(container);
  });

  tearDown(() async {
    ServiceLocator.reset();
    await GetIt.instance.reset();
  });

  Future<List<String?>> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final pushed = <String?>[];
    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScaffold: false,
        child: const AppSettingsView(),
        onGenerateRoute: (settings) {
          pushed.add(settings.name);
          return MaterialPageRoute<void>(
            builder: (_) => const SizedBox.shrink(),
            settings: settings,
          );
        },
      ),
    );
    await tester.pumpAndSettle();
    return pushed;
  }

  Finder rowValue(String label, String value) => find.descendant(
    of: find.ancestor(of: find.text(label), matching: find.byType(InkWell)),
    matching: find.text(value),
  );

  group('language', () {
    testWidgets('the row shows the current language and the sheet offers '
        'every supported one', (tester) async {
      await pump(tester);

      expect(rowValue(sv.settingsLanguageTitle, 'Svenska'), findsOneWidget);

      await tester.tap(find.text(sv.settingsLanguageTitle));
      await tester.pumpAndSettle();

      for (final code in LocaleProvider.supportedLocales) {
        expect(
          find.descendant(
            of: find.byType(BottomSheet),
            matching: find.text(LocaleProvider.getLocaleName(code)),
          ),
          findsOneWidget,
        );
      }
    });

    testWidgets('picking another language saves it, updates the row and '
        'says so', (tester) async {
      await pump(tester);

      await tester.tap(find.text(sv.settingsLanguageTitle));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('English'),
        ),
      );
      await tester.pumpAndSettle();

      expect(locale.locale.languageCode, 'en');
      expect(rowValue(sv.settingsLanguageTitle, 'English'), findsOneWidget);
      expect(find.text(sv.profileLanguageChangedTo('English')), findsOneWidget);
    });

    testWidgets('picking the current language changes nothing and says '
        'nothing', (tester) async {
      await pump(tester);

      await tester.tap(find.text(sv.settingsLanguageTitle));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('Svenska'),
        ),
      );
      await tester.pumpAndSettle();

      expect(locale.locale.languageCode, 'sv');
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('theme', () {
    testWidgets('the row shows the current theme and picking dark saves '
        'it, updates the row and says so', (tester) async {
      await pump(tester);
      expect(rowValue(sv.profileTheme, sv.profileThemeSystem), findsOneWidget);

      await tester.tap(find.text(sv.profileTheme));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text(sv.profileThemeDark),
        ),
      );
      await tester.pumpAndSettle();

      expect(theme.themeMode, ThemeMode.dark);
      expect(rowValue(sv.profileTheme, sv.profileThemeDark), findsOneWidget);
      expect(
        find.text(sv.profileThemeChangedTo(sv.profileThemeDark)),
        findsOneWidget,
      );
    });

    testWidgets('dismissing the sheet leaves the theme alone', (tester) async {
      await pump(tester);

      await tester.tap(find.text(sv.profileTheme));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(400, 20));
      await tester.pumpAndSettle();

      expect(theme.themeMode, ThemeMode.system);
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  testWidgets('the notification row opens Notisinställningar', (tester) async {
    final pushed = await pump(tester);

    await tester.tap(find.text(sv.settingsNotificationSettings));
    await tester.pumpAndSettle();

    expect(pushed, [Routes.settingsNotifications]);
  });

  testWidgets('carries the pantry switch', (tester) async {
    await pump(tester);

    expect(find.text(sv.settingsAutoAddPantryTitle), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);
  });
}
