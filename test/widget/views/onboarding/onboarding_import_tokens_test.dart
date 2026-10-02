// BUT-2183 5n: the onboarding import page leaves the old opacity steps. The
// imported-recipe notice is the mode's success surface tint with no border and
// an onSuccessContainer glyph; the glyph tile of the photo-import option sits
// on the raised card, so it is the base surface. Each test runs in both modes
// and asserts fills, borders and glyph colours.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/views/onboarding/onboarding_import_page.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

import '../../../infrastructure/factories/recipe_factory.dart';

class _MockImportManager extends Mock implements ImportManager {}

Future<void> _pump(WidgetTester tester, ThemeData theme) async {
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

  // The clipboard answers empty, so the page proposes no link.
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'Clipboard.getData') {
      return <String, dynamic>{'text': ''};
    }
    return null;
  });
  addTearDown(
    () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
  );

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
      // A success pushes the recipe editor; an empty page stands in for it.
      onGenerateRoute: (_) =>
          MaterialPageRoute<void>(builder: (_) => const SizedBox()),
      home: const Scaffold(body: OnboardingImportPage()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

BoxDecoration _boxAbove(WidgetTester tester, Finder of) =>
    tester
            .widget<Container>(
              find
                  .ancestor(
                    of: of,
                    matching: find.byWidgetPredicate(
                      (w) =>
                          w is Container &&
                          w.decoration is BoxDecoration &&
                          (w.decoration! as BoxDecoration).color != null,
                      skipOffstage: false,
                    ),
                  )
                  .first,
            )
            .decoration!
        as BoxDecoration;

Color? _glyphColor(WidgetTester tester, IconData icon) =>
    tester.widget<Icon>(find.byIcon(icon, skipOffstage: false).first).color;

void main() {
  late _MockImportManager manager;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await GetIt.instance.reset();
    manager = _MockImportManager();
    GetIt.instance.registerSingleton<ImportManager>(manager);
    prod.ServiceLocator.initialize(DIContainer());
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

    group('onboarding import page, $mode', () {
      testWidgets(
        'the imported-recipe notice is the success tint with no border and an '
        'onSuccessContainer glyph',
        (tester) async {
          when(
            () => manager.autoImport(
              any(),
              preferredStrategy: any(named: 'preferredStrategy'),
              options: any(named: 'options'),
              onProgress: any(named: 'onProgress'),
            ),
          ).thenAnswer(
            (_) async => ImportManagerResult.success(
              RecipeFactory.build(title: 'Köttbullar'),
            ),
          );
          await _pump(tester, theme);

          await tester.enterText(
            find.byType(TextField),
            'https://example.com/kottbullar',
          );
          await tester.pump();
          await tester.tap(find.byWidgetPredicate((w) => w is FilledButton));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));
          final title = find.text('Köttbullar', skipOffstage: false);
          expect(title, findsOneWidget);
          final box = _boxAbove(tester, title);
          expect(box.color, modeColors.surfaceTintSuccess);
          expect(box.border, isNull);
          expect(
            _glyphColor(tester, ButleryIcons.circleCheck),
            modeColors.onSuccessContainer,
          );
        },
      );

      testWidgets(
        'the photo-import option has a base-surface glyph tile on the raised '
        'card',
        (tester) async {
          await _pump(tester, theme);

          final glyph = find.byIcon(ButleryIcons.camera);
          expect(glyph, findsOneWidget);
          final tile = _boxAbove(tester, glyph);
          expect(tile.color, cs.surface);
          expect(_glyphColor(tester, ButleryIcons.camera), cs.onSurface);
        },
      );
    });
  }
}
