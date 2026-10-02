// BUT-2184: disabled input text is text.disabled, not Material's onSurface
// at 38 %; enabled text keeps its colour, and the field's text and hint keep
// their size.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/theme/field_text_style.dart';

void main() {
  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    final theme = dark ? AppTheme.darkTheme : AppTheme.lightTheme;

    Future<void> pump(
      WidgetTester tester, {
      required bool enabled,
      TextStyle? base,
      bool withStyle = true,
      String text = 'Linsgryta',
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextField(
                controller: TextEditingController(text: text),
                enabled: enabled,
                decoration: const InputDecoration(hintText: 'Sök'),
                style: withStyle
                    ? fieldTextStyle(context, enabled: enabled, base: base)
                    : base,
              ),
            ),
          ),
        ),
      );
    }

    TextStyle typed(WidgetTester tester) =>
        tester.widget<EditableText>(find.byType(EditableText)).style;

    testWidgets('$mode: disabled text is text.disabled', (tester) async {
      await pump(tester, enabled: false);
      expect(
        typed(tester).color,
        AppModeColors.textDisabled(theme.colorScheme.brightness),
      );
    });

    testWidgets('$mode: disabled text is text.disabled even with a base '
        'colour', (tester) async {
      await pump(
        tester,
        enabled: false,
        base: TextStyle(color: theme.colorScheme.primary),
      );
      expect(
        typed(tester).color,
        AppModeColors.textDisabled(theme.colorScheme.brightness),
      );
    });

    testWidgets('$mode: enabled text is onSurface', (tester) async {
      await pump(tester, enabled: true);
      expect(typed(tester).color, theme.colorScheme.onSurface);
    });

    testWidgets('$mode: a base colour is kept while enabled', (tester) async {
      await pump(
        tester,
        enabled: true,
        base: TextStyle(color: theme.colorScheme.primary),
      );
      expect(typed(tester).color, theme.colorScheme.primary);
    });

    testWidgets('$mode: the field keeps its own text size', (tester) async {
      await pump(tester, enabled: true, withStyle: false);
      final plain = typed(tester).fontSize;
      await pump(tester, enabled: true);
      expect(typed(tester).fontSize, plain);
    });

    testWidgets('$mode: the hint keeps the base size, enabled and disabled', (
      tester,
    ) async {
      for (final enabled in [true, false]) {
        await pump(
          tester,
          enabled: enabled,
          withStyle: false,
          text: '',
          base: AppTextStyles.bodyMedium,
        );
        final hintBefore = tester
            .renderObject<RenderParagraph>(find.text('Sök'))
            .text
            .style
            ?.fontSize;
        await pump(
          tester,
          enabled: enabled,
          text: '',
          base: AppTextStyles.bodyMedium,
        );
        final hintAfter = tester
            .renderObject<RenderParagraph>(find.text('Sök'))
            .text
            .style
            ?.fontSize;
        expect(hintAfter, hintBefore, reason: 'enabled: $enabled');
        expect(hintAfter, AppTextStyles.bodyMedium.fontSize);
      }
    });
  }
}
