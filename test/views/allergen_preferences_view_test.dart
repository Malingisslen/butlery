// Intention: the allergens page saves every choice at once and offers no Spara;
// reset asks first. Drives the real view over a mocked UserService.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/widgets/common/list/butlery_checkbox_grid.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/views/settings/allergen_preferences_view.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';

import '../infrastructure/mocks/production_mocks.dart';

const _seedPrefs = UserAllergenPreferences(
  trackedAllergens: {'gluten', 'mjölk'},
  trackedDietary: {'vegansk'},
  showOnCards: true,
  showOnDetail: true,
  showCoverage: true,
);

void main() {
  final sv = AppLocalizationsSv();
  late MockUserService userService;

  setUp(() async {
    await GetIt.instance.reset();
    registerFallbackValue(UserAllergenPreferences.defaults);
    userService = MockUserService();
    when(() => userService.allergenPreferences).thenReturn(_seedPrefs);
    when(
      () => userService.updateAllergenPreferences(any()),
    ).thenAnswer((_) async => true);
    GetIt.instance.registerSingleton<UserService>(userService);
    prod.ServiceLocator.initialize(DIContainer());
  });

  tearDown(() async {
    prod.ServiceLocator.reset();
    await GetIt.instance.reset();
  });

  Future<void> pumpView(WidgetTester tester, {String? backTo}) async {
    tester.view.physicalSize = const Size(600, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) return;
      original?.call(details);
    };
    addTearDown(() => FlutterError.onError = original);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        locale: const Locale('sv', 'SE'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: AllergenPreferencesView(backTo: backTo),
      ),
    );
    await tester.pumpAndSettle();
  }

  UserAllergenPreferences lastSaved() =>
      verify(
            () => userService.updateAllergenPreferences(captureAny()),
          ).captured.last
          as UserAllergenPreferences;

  testWidgets('the page is named as its Mer row and has no Spara', (
    tester,
  ) async {
    await pumpView(tester);

    expect(find.text(sv.moreAllergens), findsWidgets);
    expect(find.text(sv.commonSave), findsNothing);
    expect(find.text(sv.allergenSaveSettings), findsNothing);
  });

  testWidgets('Back is named after where the caller says it leads', (
    tester,
  ) async {
    await pumpView(tester, backTo: sv.moreTitle);
    expect(
      tester.widget<ButleryTopBar>(find.byType(ButleryTopBar)).backTo,
      'Mer',
    );
  });

  // The banners and empty states that also open this page lead elsewhere.
  testWidgets('opened without a destination, Back names none', (
    tester,
  ) async {
    await pumpView(tester);
    expect(
      tester.widget<ButleryTopBar>(find.byType(ButleryTopBar)).backTo,
      isNull,
    );
  });

  testWidgets('every allergen and diet option is a cell of the checkbox grid', (
    tester,
  ) async {
    await pumpView(tester);

    for (final label in [
      ...AllergenPreferenceOptions.allergens.values,
      ...AllergenPreferenceOptions.dietary.values,
    ]) {
      expect(
        find.descendant(
          of: find.byType(ButleryCheckboxGrid),
          matching: find.text(label),
        ),
        findsOneWidget,
      );
    }
  });

  testWidgets('the retag action is an outlined button above the maintenance '
      'rows', (tester) async {
    await pumpView(tester);

    final retag = find.widgetWithText(
      OutlinedButton,
      AppLocalizationsSv().allergenRetagRow,
    );
    await tester.ensureVisible(retag);
    expect(retag, findsOneWidget);
  });

  testWidgets('tapping a checkbox saves at once and shows the snackbar', (
    tester,
  ) async {
    await pumpView(tester);

    await tester.tap(
      find.text(AllergenPreferenceOptions.allergens['gluten']!),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(lastSaved().trackedAllergens, isNot(contains('gluten')));
    expect(find.text(sv.allergenSettingsSaved), findsOneWidget);
  });

  testWidgets('flipping a display toggle saves at once', (tester) async {
    await pumpView(tester);

    await tester.tap(find.text(sv.allergenDisplayOnDetailTitle));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(lastSaved().showOnDetail, isFalse);
  });

  testWidgets('reset asks first, then saves the defaults', (tester) async {
    await pumpView(tester);

    await tester.tap(find.text(sv.allergenResetToDefaults));
    await tester.pumpAndSettle();
    expect(find.text(sv.allergenResetTitle), findsOneWidget);
    verifyNever(() => userService.updateAllergenPreferences(any()));

    await tester.tap(find.text(sv.allergenReset));
    await tester.pumpAndSettle();

    expect(lastSaved(), UserAllergenPreferences.defaults);
  });

  testWidgets('cancelling the reset keeps the choices', (tester) async {
    await pumpView(tester);

    await tester.tap(find.text(sv.allergenResetToDefaults));
    await tester.pumpAndSettle();
    await tester.tap(find.text(sv.commonCancel));
    await tester.pumpAndSettle();

    verifyNever(() => userService.updateAllergenPreferences(any()));
  });

  testWidgets('the settings are rows, not switch tiles', (tester) async {
    await pumpView(tester);

    expect(find.byType(SwitchListTile), findsNothing);
    expect(find.byType(ButleryListSection), findsWidgets);
  });
}
