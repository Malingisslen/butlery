// The heading that opens a group of rows: it shows whether the group is open,
// folds it only when given something to do, and says so to a screen reader.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/list/section_band.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

void main() {
  Future<void> pump(WidgetTester tester, SectionBand band) async {
    await tester.pumpWidget(createLocalizedTestApp(child: band));
    await tester.pump();
  }

  testWidgets('expanded shows the up chevron and folded the down chevron', (
    tester,
  ) async {
    await pump(tester, const SectionBand(title: 'Kyl', expanded: true));
    expect(find.byIcon(ButleryIcons.chevronUp), findsOneWidget);
    expect(find.byIcon(ButleryIcons.chevronDown), findsNothing);

    await pump(tester, const SectionBand(title: 'Kyl', expanded: false));
    expect(find.byIcon(ButleryIcons.chevronDown), findsOneWidget);
    expect(find.byIcon(ButleryIcons.chevronUp), findsNothing);
  });

  testWidgets('a band that does not fold draws no chevron', (tester) async {
    await pump(tester, const SectionBand(title: 'Kyl', count: '3'));

    // Positive control: the band itself is drawn.
    expect(find.text('3'), findsOneWidget);
    expect(find.byIcon(ButleryIcons.chevronUp), findsNothing);
    expect(find.byIcon(ButleryIcons.chevronDown), findsNothing);
  });

  testWidgets('tapping a band calls onTap once', (tester) async {
    var taps = 0;
    await pump(
      tester,
      SectionBand(title: 'Kyl', expanded: false, onTap: () => taps++),
    );

    await tester.tap(find.byType(SectionBand));
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets('with onTap the band is a toggle button named by its label; '
      'without it, a plain heading', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(
      tester,
      SectionBand(
        title: 'Kyl',
        expanded: true,
        semanticLabel: 'Kyl',
        onTap: () {},
      ),
    );
    final folding = tester
        .getSemantics(find.byType(SectionBand))
        .getSemanticsData();
    expect(folding.flagsCollection.isButton, isTrue);
    expect(folding.flagsCollection.isToggled, ui.Tristate.isTrue);

    await pump(tester, const SectionBand(title: 'Kyl', count: '3'));
    // Positive control: the heading is still in the tree.
    expect(find.text('3'), findsOneWidget);
    final plain = tester
        .getSemantics(find.byType(SectionBand))
        .getSemanticsData();
    expect(plain.flagsCollection.isButton, isFalse);
    expect(plain.hasAction(ui.SemanticsAction.tap), isFalse);
    handle.dispose();
  });

  for (final dark in [false, true]) {
    testWidgets('the bar is ink-toned for a standard band and saffron for a '
        'warning band in ${dark ? 'dark' : 'light'} mode', (tester) async {
      final brightness = dark ? Brightness.dark : Brightness.light;
      Color barOf(WidgetTester tester) {
        final box = tester
            .widgetList<Container>(find.byType(Container))
            .map((c) => c.decoration)
            .whereType<BoxDecoration>()
            .firstWhere(
              (d) =>
                  d.border is Border && (d.border! as Border).left.width == 3,
            );
        return (box.border! as Border).left.color;
      }

      Widget app(SectionBandTone tone) => MaterialApp(
        theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
        home: Scaffold(
          body: SectionBand(title: 'Utgår snart', tone: tone),
        ),
      );

      await tester.pumpWidget(app(SectionBandTone.standard));
      final scheme = Theme.of(
        tester.element(find.byType(SectionBand)),
      ).colorScheme;
      final standard = barOf(tester);
      expect(standard, scheme.onSurface);

      await tester.pumpWidget(app(SectionBandTone.warning));
      final warning = barOf(tester);
      expect(warning, AppModeColors.actionPrimary(brightness));
      expect(warning, isNot(standard));
    });
  }
}
