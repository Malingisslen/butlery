// ButleryPasswordField: the validated mark stands in the box before the
// show/hide button, and gives way rather than overflow on a narrow phone at
// large text.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/styled/butlery_password_field.dart';

Widget _app(Widget child, {double scale = 1}) => MaterialApp(
  theme: AppTheme.lightTheme,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('sv'),
  home: MediaQuery(
    data: MediaQueryData(
      size: const Size(320, 640),
      textScaler: TextScaler.linear(scale),
    ),
    child: Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: child,
      ),
    ),
  ),
);

void main() {
  final controller = TextEditingController(text: 'nyttLosen123');
  tearDownAll(controller.dispose);

  testWidgets('the mark stands inside the box, before the show button', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        ButleryPasswordField(
          label: 'Upprepa lösenordet',
          controller: controller,
          validText: 'Lösenorden matchar',
        ),
      ),
    );
    final box = tester.getRect(find.byType(InputDecorator));
    final word = tester.getRect(find.text('Lösenorden matchar'));
    final eye = tester.getRect(find.byIcon(ButleryIcons.eye));
    expect(box.contains(word.center), isTrue);
    expect(word.right, lessThanOrEqualTo(eye.left));
  });

  testWidgets('hides the password until shown, and hides it again', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(ButleryPasswordField(label: 'Lösenord', controller: controller)),
    );
    bool obscured() =>
        tester.widget<EditableText>(find.byType(EditableText)).obscureText;

    expect(obscured(), isTrue);
    await tester.tap(find.byTooltip('Visa lösenord'));
    await tester.pump();
    expect(obscured(), isFalse);
    await tester.tap(find.byTooltip('Dölj lösenord'));
    await tester.pump();
    expect(obscured(), isTrue);
  });

  test('an empty pair is not a match; only an equal repeat is', () {
    expect(ButleryPasswordField.matches('', ''), isFalse);
    expect(ButleryPasswordField.matches('abc', ''), isFalse);
    expect(ButleryPasswordField.matches('abc', 'ab'), isFalse);
    expect(ButleryPasswordField.matches('abc', 'abc'), isTrue);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('fits 320 dp at ${scale}x text without overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          ButleryPasswordField(
            label: 'Upprepa lösenordet',
            controller: controller,
            validText: 'Lösenorden matchar',
          ),
          scale: scale,
        ),
      );
      expect(tester.takeException(), isNull);
      // The typed text keeps room to be read.
      expect(
        tester.getSize(find.byType(EditableText)).width,
        greaterThanOrEqualTo(48),
      );
    });
  }
}
