// BUT-2369: one section heading. Capitals, its own header node, the overline
// role, and a colour per tone that follows the mode.

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/section_heading.dart';

void main() {
  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    final theme = dark ? AppTheme.darkTheme : AppTheme.lightTheme;
    final cs = theme.colorScheme;

    Future<Text> pump(WidgetTester tester, SectionHeading heading) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(body: heading),
        ),
      );
      return tester.widget<Text>(find.byType(Text));
    }

    testWidgets('$mode: drawn in capitals in the overline role', (
      tester,
    ) async {
      final text = await pump(tester, const SectionHeading('Medlemmar · 3'));
      expect(text.data, 'MEDLEMMAR · 3');
      final overline = AppTextStyles.overline;
      expect(text.style!.fontSize, overline.fontSize);
      expect(text.style!.fontWeight, overline.fontWeight);
      expect(text.style!.letterSpacing, overline.letterSpacing);
    });

    for (final (tone, expected) in [
      (SectionHeadingTone.standard, cs.onSurfaceVariant),
      (SectionHeadingTone.strong, cs.onSurface),
      (SectionHeadingTone.emphasis, cs.tertiary),
      (SectionHeadingTone.attention, cs.error),
    ]) {
      testWidgets('$mode: ${tone.name} takes its colour from the scheme', (
        tester,
      ) async {
        final text = await pump(tester, SectionHeading('Kyl', tone: tone));
        expect(text.style!.color, expected);
      });
    }
  }

  testWidgets('is its own header node, apart from what follows', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: Column(children: [SectionHeading('Väntar'), Text('Mjölk')]),
        ),
      ),
    );
    expect(
      find.semantics.byFlag(SemanticsFlag.isHeader),
      findsOne,
    );
    expect(tester.getSemantics(find.text('VÄNTAR')).label, 'VÄNTAR');
    expect(tester.getSemantics(find.text('Mjölk')).label, 'Mjölk');
    handle.dispose();
  });
}
