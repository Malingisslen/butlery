// BUT-2183 5o: three small residues leave the old opacity steps. Secondary
// text is onSurfaceVariant, an inline timer chip fills with the raised surface
// of the page it stands on, and a clear glyph is onSurfaceVariant at full
// strength. Each test runs in both modes.
//
// Expected colours come from the generated schemes, not from the widget's own
// Theme lookup, so a widget that reads the wrong slot cannot agree with
// itself.

library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/branding/app_logo.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/cooking/inline_timer_text.dart';
import 'package:butlery/widgets/menu/menu_content_widgets.dart';

Widget _app(ThemeData theme, Widget child) => MaterialApp(
  theme: theme,
  locale: const Locale('sv'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  for (final (mode, theme, cs) in [
    ('light', AppTheme.lightTheme, AppColors.lightColorScheme),
    ('dark', AppTheme.darkTheme, AppColors.darkColorScheme),
  ]) {
    group('5o residue tokens ($mode)', () {
      testWidgets('the branding tagline is onSurfaceVariant, not translucent '
          'ink', (tester) async {
        await tester.pumpWidget(
          _app(theme, const AppBranding.auth(tagline: 'Din tagline')),
        );

        final color = tester
            .widget<Text>(find.text('Din tagline'))
            .style!
            .color;
        expect(color, cs.onSurfaceVariant);
        expect(color!.a, 1.0);
      });

      testWidgets('the prompt clear glyph is onSurfaceVariant at full '
          'strength', (tester) async {
        final controller = TextEditingController(text: 'pasta');
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          _app(
            theme,
            Builder(
              builder: (context) => MenuContentWidgets.buildPromptInput(
                context,
                controller: controller,
                isGenerating: false,
                onClear: () {},
                onChanged: () {},
              ),
            ),
          ),
        );

        final glyph = tester.widget<ButleryIcon>(
          find.byWidgetPredicate(
            (w) => w is ButleryIcon && w.icon == ButleryIcons.x,
          ),
        );
        expect(glyph.color, cs.onSurfaceVariant);
        expect(glyph.color!.a, 1.0);
      });

      testWidgets('the timer chip fills with the raised surface by default '
          'and takes the fill it is handed on ink', (tester) async {
        Color? chipFill() {
          final box = tester.widget<Container>(
            find
                .ancestor(
                  of: find.text('25 min'),
                  matching: find.byType(Container),
                )
                .first,
          );
          return (box.decoration! as BoxDecoration).color;
        }

        await tester.pumpWidget(
          _app(
            theme,
            InlineTimerText(text: 'Grädda i 25 min', onTimerTap: (_) {}),
          ),
        );
        expect(chipFill(), cs.surfaceContainerHighest);

        await tester.pumpWidget(
          _app(
            theme,
            InlineTimerText(
              text: 'Grädda i 25 min',
              onTimerTap: (_) {},
              chipFill: AppModeColors.surfaceRaisedOnInk(),
            ),
          ),
        );
        expect(chipFill(), AppModeColors.surfaceRaisedOnInk());
      });
    });
  }
}
