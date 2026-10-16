/// Megagenomgången, spår A: what a screen reader, a keyboard and a dark
/// screen get from the shared components.
library;

import 'dart:ui' show SemanticsAction, SemanticsRole, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/butlery_segment_switch.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/input/portion_scaler.dart';
import 'package:butlery/widgets/common/layout/page_rule.dart';
import 'package:butlery/widgets/common/list/butlery_checkbox_grid.dart';
import 'package:butlery/widgets/common/navigation/underline_tabs.dart';
import 'package:butlery/widgets/common/star_rating_row.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

Widget _themed(ThemeData theme, Widget child) => MaterialApp(
  theme: theme,
  locale: const Locale('sv'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  group('the secondary button', () {
    testWidgets('is not drawn as the primary button', (tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (context) => Column(
              children: [
                ActionButtons.primaryButton(
                  context,
                  label: 'Spara',
                  onPressed: () {},
                  isExpanded: true,
                ),
                ActionButtons.secondaryButton(
                  context,
                  label: 'Avbryt',
                  onPressed: () {},
                  isExpanded: true,
                ),
              ],
            ),
          ),
        ),
      );

      final buttons = tester
          .widgetList<ElevatedButton>(find.byType(ElevatedButton))
          .toList();
      final theme = Theme.of(tester.element(find.text('Spara')));
      final primaryFill =
          (buttons[0].style?.backgroundColor ??
                  theme.elevatedButtonTheme.style!.backgroundColor)!
              .resolve({});
      final secondaryStyle = buttons[1].style;

      expect(
        secondaryStyle?.backgroundColor?.resolve({}),
        isNot(primaryFill),
        reason: 'Avbryt must not carry the fill of Spara',
      );
      expect(secondaryStyle?.side?.resolve({}), isNotNull);
    });
  });

  group('dark mode', () {
    final dark = AppTheme.darkTheme;

    testWidgets('a live primary button reads as a fill, without an edge', (
      tester,
    ) async {
      await tester.pumpWidget(
        _themed(
          dark,
          Builder(
            builder: (context) => Column(
              children: [
                ActionButtons.primaryButton(
                  context,
                  label: 'Live',
                  onPressed: () {},
                ),
                ActionButtons.primaryButton(context, label: 'Dead'),
              ],
            ),
          ),
        ),
      );

      final style = dark.elevatedButtonTheme.style!;
      expect(style.side?.resolve(<WidgetState>{}), isNull);
      final fill = style.backgroundColor!.resolve(<WidgetState>{})!;
      expect(
        _contrast(fill, dark.colorScheme.surface),
        greaterThanOrEqualTo(3.0),
        reason: 'the fill is the non-text boundary: 3:1 against the page',
      );
      expect(
        _contrast(fill, dark.colorScheme.surfaceContainerHighest),
        greaterThanOrEqualTo(3.0),
      );
    });

    test('a page rule and a layer can be seen against the dark page', () {
      final cs = dark.colorScheme;
      expect(
        _contrast(
          Color.alphaBlend(ruleInk(cs), cs.surface),
          cs.surface,
        ),
        greaterThanOrEqualTo(3.0),
      );
      expect(
        ruleInk(AppTheme.lightTheme.colorScheme),
        AppTheme.lightTheme.colorScheme.primary,
      );
    });

    test('dialogs and sheets stand one step above the page, behind a scrim '
        'that can be seen', () {
      final cs = dark.colorScheme;
      expect(dark.dialogTheme.backgroundColor, cs.surfaceContainerHighest);
      expect(
        dark.bottomSheetTheme.modalBackgroundColor,
        cs.surfaceContainerHighest,
      );
      expect(dark.dialogTheme.barrierColor, cs.scrim);
      expect(dark.bottomSheetTheme.modalBarrierColor, cs.scrim);
      final edge = (dark.dialogTheme.shape! as RoundedRectangleBorder).side;
      expect(edge.color, cs.outline);
      expect(dark.dialogTheme.elevation, 0);
      // A scrim in the page's own colour darkens nothing.
      final dimmed = Color.alphaBlend(cs.scrim, cs.surface);
      expect(
        dimmed.computeLuminance(),
        lessThan(cs.surface.computeLuminance()),
      );
    });
  });

  group('semantics', () {
    testWidgets('UnderlineTabs is a tab list of tabs, one selected', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: UnderlineTabs<String>(
            values: const ['a', 'b', 'c'],
            labelOf: (v) => 'Flik $v',
            selected: 'b',
            onChanged: (_) {},
          ),
        ),
      );

      final list = tester
          .getSemantics(find.byType(UnderlineTabs<String>))
          .getSemanticsData();
      expect(list.role, SemanticsRole.tabBar);

      final chosen = tester
          .getSemantics(find.text('Flik b'))
          .getSemanticsData();
      final other = tester.getSemantics(find.text('Flik a')).getSemanticsData();
      expect(chosen.role, SemanticsRole.tab);
      expect(chosen.flagsCollection.isSelected, Tristate.isTrue);
      expect(other.role, SemanticsRole.tab);
      expect(other.flagsCollection.isSelected, Tristate.isFalse);
      handle.dispose();
    });

    testWidgets('ButlerySegmentSwitch is a radio group', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: ButlerySegmentSwitch<String>(
            choices: const [('a', 'Alla'), ('b', 'Några')],
            selected: 'a',
            onChanged: (_) {},
          ),
        ),
      );

      expect(
        tester
            .getSemantics(find.byType(ButlerySegmentSwitch<String>))
            .getSemanticsData()
            .role,
        SemanticsRole.radioGroup,
      );
      handle.dispose();
    });

    testWidgets('the portion picker has a value a screen reader can step', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final changes = <int>[];
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: PortionScaler(
            originalPortions: 4,
            originalIngredients: const ['2 dl mjölk'],
            onPortionChanged: (n, _) => changes.add(n),
          ),
        ),
      );

      final stepper = find.semantics.byAction(SemanticsAction.increase);
      final data = stepper.evaluate().single.getSemanticsData();
      expect(data.value, '4');
      expect(data.increasedValue, '5');
      expect(data.decreasedValue, '3');

      tester.semantics.increase(stepper);
      await tester.pump();
      expect(changes, [5]);
      handle.dispose();
    });

    testWidgets('a star can be picked with the keyboard, and the chosen one '
        'is selected', (tester) async {
      final handle = tester.ensureSemantics();
      final picked = <double>[];
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: StarRatingRow(
            rating: 3,
            onRatingChanged: picked.add,
            semanticsLabel: (s) => 'Stjärna $s',
          ),
        ),
      );

      final three = tester
          .getSemantics(find.bySemanticsLabel('Stjärna 3'))
          .getSemanticsData();
      final four = tester
          .getSemantics(find.bySemanticsLabel('Stjärna 4'))
          .getSemanticsData();
      expect(three.flagsCollection.isSelected, Tristate.isTrue);
      expect(four.flagsCollection.isSelected, Tristate.isFalse);

      // Tab to the fourth star and press Enter.
      for (var i = 0; i < 4; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(picked, [4.0]);
      handle.dispose();
    });

    testWidgets('the allergen grid answers a screen reader tap', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final toggled = <String>[];
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: ButleryCheckboxGrid(
            options: const {'gluten': 'Gluten', 'mjolk': 'Mjölk'},
            isSelected: (_) => false,
            onToggle: toggled.add,
          ),
        ),
      );

      tester.semantics.tap(find.semantics.byLabel('Mjölk'));
      await tester.pump();
      expect(toggled, ['mjolk']);
      handle.dispose();
    });

    testWidgets('the allergen grid keeps one column when a long word cannot '
        'fit in two', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: ButleryCheckboxGrid(
            options: const {
              'a': 'Svaveldioxid och sulfiter',
              'b': 'Selleri',
              'c': 'Lupin',
              'd': 'Mjölk',
            },
            isSelected: (_) => false,
            onToggle: (_) {},
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getTopLeft(find.text('Selleri')).dx,
        tester.getTopLeft(find.text('Svaveldioxid och sulfiter')).dx,
        reason: 'one column: every word starts at the same x',
      );
    });

    testWidgets(
      'the allergen grid keeps two columns when the words are short',
      (
        tester,
      ) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: ButleryCheckboxGrid(
              options: const {'a': 'Gluten', 'b': 'Mjölk'},
              isSelected: (_) => false,
              onToggle: (_) {},
            ),
          ),
        );
        expect(
          tester.getTopLeft(find.text('Mjölk')).dx,
          greaterThan(tester.getTopLeft(find.text('Gluten')).dx),
        );
      },
    );

    testWidgets('the portion picker follows an edited recipe', (tester) async {
      Widget scaler(List<String> lines) => createLocalizedTestApp(
        child: PortionScaler(
          originalPortions: 4,
          originalIngredients: lines,
          onPortionChanged: (_, _) {},
        ),
      );
      await tester.pumpWidget(scaler(const ['2 dl mjölk']));
      expect(find.text('Konvertera amerikanska enheter'), findsNothing);
      await tester.pumpWidget(scaler(const ['2 cups milk']));
      await tester.pump();
      expect(find.text('Konvertera amerikanska enheter'), findsOneWidget);
    });
  });
}
