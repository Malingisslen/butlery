// UnifiedBadge draws the two badges Komponentark v1 has: the status pill
// (§08: an outline pill, never a fill in a status colour) and the counter
// (v1:741: ink as the norm, saffron only when it asks for action, "99+").
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/badges/unified_badge.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

Widget _wrap(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme ?? AppTheme.lightTheme,
  home: Scaffold(body: Center(child: child)),
);

BoxDecoration _decoration(WidgetTester tester) =>
    tester
            .widget<DecoratedBox>(
              find.descendant(
                of: find.byType(UnifiedBadge),
                matching: find.byType(DecoratedBox),
              ),
            )
            .decoration
        as BoxDecoration;

Color? _textColor(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style?.color;

void main() {
  for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
    final cs = theme.colorScheme;
    final mode = ModeColors.of(cs.brightness);
    group('status pill, ${cs.brightness.name}', () {
      testWidgets('is an outline pill in border-subtle with no fill', (
        tester,
      ) async {
        await tester.pumpWidget(
          _wrap(const UnifiedBadge.status(label: 'Granskas'), theme: theme),
        );
        final d = _decoration(tester);
        expect(d.color, isNull);
        expect((d.border! as Border).top.color, cs.outlineVariant);
        expect(
          d.borderRadius,
          BorderRadius.circular(AppDimensions.radiusPill),
        );
        expect(find.text('GRANSKAS'), findsOneWidget);
      });

      testWidgets('colours only the word and the glyph by tone', (
        tester,
      ) async {
        final expected = {
          BadgeTone.neutral: cs.onSurfaceVariant,
          BadgeTone.success: mode.success,
          BadgeTone.warning: AppModeColors.textWarning(cs.brightness),
          BadgeTone.danger: cs.error,
        };
        for (final MapEntry(key: tone, value: color) in expected.entries) {
          await tester.pumpWidget(
            _wrap(
              UnifiedBadge.status(
                label: 'Givet',
                tone: tone,
                icon: ButleryIcons.check,
              ),
              theme: theme,
            ),
          );
          expect(_textColor(tester, 'GIVET'), color, reason: '$tone');
          expect(
            tester.widget<ButleryIcon>(find.byType(ButleryIcon)).color,
            color,
            reason: '$tone',
          );
          expect(_decoration(tester).color, isNull, reason: '$tone');
        }
      });
    });

    group('counter, ${cs.brightness.name}', () {
      testWidgets('is ink with paper digits by default', (tester) async {
        await tester.pumpWidget(
          _wrap(const UnifiedBadge.count(count: 3), theme: theme),
        );
        expect(_decoration(tester).color, cs.primary);
        expect(_textColor(tester, '3'), cs.onPrimary);
      });

      testWidgets('is saffron when it asks for action', (tester) async {
        await tester.pumpWidget(
          _wrap(
            const UnifiedBadge.count(
              count: 3,
              emphasis: CountEmphasis.action,
            ),
            theme: theme,
          ),
        );
        expect(_decoration(tester).color, cs.secondary);
        expect(_textColor(tester, '3'), cs.onSecondary);
      });
    });
  }

  testWidgets('a counter above 99 reads 99+', (tester) async {
    await tester.pumpWidget(_wrap(const UnifiedBadge.count(count: 99)));
    expect(find.text('99'), findsOneWidget);
    await tester.pumpWidget(_wrap(const UnifiedBadge.count(count: 100)));
    expect(find.text('99+'), findsOneWidget);
  });

  testWidgets('a status pill without an icon draws no glyph', (tester) async {
    await tester.pumpWidget(_wrap(const UnifiedBadge.status(label: 'Stängd')));
    expect(find.byType(ButleryIcon), findsNothing);
  });

  testWidgets('a status pill is announced as written, not in capitals', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _wrap(const UnifiedBadge.status(label: 'Granskas')),
    );
    expect(find.bySemanticsLabel('Granskas'), findsOneWidget);
    expect(find.bySemanticsLabel('GRANSKAS'), findsNothing);
    handle.dispose();
  });
}
