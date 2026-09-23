/// P5-U22: the shared partial-outcome surface (I-29).
///
/// produktregler.md:905-909: "Formen är `surface.raised` med varningskant";
/// it names what went, what did not and why. Drawn in Skarmar v12 etapp 9
/// globala tillstand och flerval.dc.html:390-393.
///
/// Pins, in light AND dark: the surface is surface.raised (#E6EAD9 / #2F4437,
/// tokens.json), the edge is 3 px #CE7C1E on the leading side only, and the
/// text is text.primary. Also the public API P5-T4 reads: items keyed by id,
/// reasons shown, actions rendered, the title a live region.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/feedback/partial_outcome.dart';

Widget _app(ThemeData theme, Widget child) => MaterialApp(
  theme: theme,
  locale: const Locale('sv'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: Scaffold(
    body: Padding(padding: const EdgeInsets.all(16), child: child),
  ),
);

PartialOutcome _outcome({VoidCallback? onRetry, VoidCallback? onDone}) =>
    PartialOutcome(
      title: 'Vi hämtade 7 av 9 länkar',
      message: 'Vi kunde inte hämta länkarna nedan.',
      items: [
        PartialOutcomeItem(
          id: 'u-4',
          label: 'https://example.com/trasig',
          reason: 'Sidan svarade inte',
          action: TextButton(
            onPressed: onRetry,
            child: const Text('Försök igen'),
          ),
        ),
        const PartialOutcomeItem(
          id: 'u-8',
          label: 'https://example.com/tom',
          reason: 'Inget recept på sidan',
        ),
      ],
      actions: [
        OutlinedButton(onPressed: onDone, child: const Text('Klart')),
      ],
    );

void main() {
  for (final (mode, theme, raised, text) in [
    (
      'light',
      AppTheme.lightTheme,
      const Color(0xFFE6EAD9),
      const Color(0xFF24382C),
    ),
    (
      'dark',
      AppTheme.darkTheme,
      const Color(0xFF2F4437),
      const Color(0xFFF5F4ED),
    ),
  ]) {
    testWidgets('surface.raised with a 3 px #CE7C1E leading edge ($mode)', (
      tester,
    ) async {
      await tester.pumpWidget(_app(theme, _outcome()));

      final box = tester.widget<DecoratedBox>(
        find.byKey(PartialOutcome.surfaceKey),
      );
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.color, raised);
      final border = decoration.border! as Border;
      expect(border.left.color, const Color(0xFFCE7C1E));
      expect(border.left.width, PartialOutcome.edgeWidth);
      expect(border.top, BorderSide.none);
      expect(border.right, BorderSide.none);
      expect(border.bottom, BorderSide.none);

      final title = tester.widget<Text>(find.text('Vi hämtade 7 av 9 länkar'));
      expect(title.style?.color, text);
      final reason = tester.widget<Text>(find.text('Sidan svarade inte'));
      expect(reason.style?.color, text);
    });
  }

  testWidgets('each item is keyed by its id and names its reason', (
    tester,
  ) async {
    await tester.pumpWidget(_app(AppTheme.lightTheme, _outcome()));

    final first = find.byKey(PartialOutcome.itemKey('u-4'));
    final second = find.byKey(PartialOutcome.itemKey('u-8'));
    expect(first, findsOneWidget);
    expect(second, findsOneWidget);
    expect(
      find.descendant(of: first, matching: find.text('Sidan svarade inte')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: second, matching: find.text('Inget recept på sidan')),
      findsOneWidget,
    );
    expect(find.text('Vi kunde inte hämta länkarna nedan.'), findsOneWidget);
  });

  testWidgets('item actions and outcome actions work', (tester) async {
    var retried = 0;
    var done = 0;
    await tester.pumpWidget(
      _app(
        AppTheme.lightTheme,
        _outcome(onRetry: () => retried++, onDone: () => done++),
      ),
    );

    await tester.tap(find.text('Försök igen'));
    await tester.tap(find.text('Klart'));

    expect(retried, 1);
    expect(done, 1);
  });

  testWidgets('the title is announced as a live region', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(AppTheme.lightTheme, _outcome()));

    expect(
      tester.getSemantics(find.text('Vi hämtade 7 av 9 länkar')),
      containsSemantics(isLiveRegion: true, isHeader: true),
    );
    handle.dispose();
  });

  testWidgets('it fits a 320 dp phone without overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(AppTheme.lightTheme, _outcome()));

    expect(tester.takeException(), isNull);
  });
}
