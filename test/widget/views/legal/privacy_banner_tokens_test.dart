// BUT-2183 5n: the privacy policy's notice banner leaves the old opacity steps.
// It is the raised surface with no border and info-coloured glyph and text.
// Colours only: the wording and layout are unchanged. Runs in both modes and
// asserts the fill, the missing border and the glyph and text colours.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/views/legal/privacy_policy_view.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

late AppLocalizations _sv;

class _FakeOfflineService extends ChangeNotifier implements OfflineService {
  @override
  bool get isOnline => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pump(WidgetTester tester, ThemeData theme) async {
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
      home: const PrivacyPolicyView(),
    ),
  );
  // The policy is a bundled asset decoded off the fake clock, so let real
  // time pass until the banner above it is built.
  final banner = find.text(_sv.privacyGdprCompliant);
  for (var i = 0; i < 100 && banner.evaluate().isEmpty; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  setUpAll(() async {
    _sv = await AppLocalizations.delegate.load(const Locale('sv', 'SE'));
  });

  setUp(() async {
    rootBundle.clear();
    await GetIt.instance.reset();
    GetIt.instance.registerSingleton<OfflineService>(_FakeOfflineService());
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

    testWidgets(
      'the GDPR banner is the raised surface with no border and info glyph '
      'and text, $mode',
      (tester) async {
        await _pump(tester, theme);

        final text = find.text(_sv.privacyGdprCompliant);
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
        expect(box.color, cs.surfaceContainerHighest);
        expect(box.border, isNull);
        expect(tester.widget<Text>(text).style?.color, modeColors.info);
        expect(
          tester.widget<Icon>(find.byIcon(ButleryIcons.info).first).color,
          modeColors.info,
        );
      },
    );
  }
}
