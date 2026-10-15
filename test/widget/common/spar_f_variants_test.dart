import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/buttons/butlery_text_button.dart';
import 'package:butlery/widgets/common/list/butlery_item_row.dart';
import 'package:butlery/widgets/common/menus/butlery_menu.dart';
import 'package:butlery/widgets/styled/styled_input.dart';
import '../../test_support/base_unit_test.dart';

/// Noll-spår F: the danger button, the square (onboarding) variants and the
/// unread row, which replaced raw Material widgets in the views.
void main() {
  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  tearDown(() async {
    BaseUnitTest.resetMocks();
  });

  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: SizedBox(width: 400, child: child)),
    ),
  );

  group('ActionButtons', () {
    testWidgets('dangerButton is an outlined button in the error colour', (
      tester,
    ) async {
      late ColorScheme cs;
      await pump(
        tester,
        Builder(
          builder: (context) {
            cs = Theme.of(context).colorScheme;
            return ActionButtons.dangerButton(
              context,
              label: 'Radera',
              onPressed: () {},
              isExpanded: true,
            );
          },
        ),
      );
      final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      expect(button.style!.foregroundColor!.resolve({}), cs.error);
    });

    testWidgets('square draws square corners and an ink edge when outlined', (
      tester,
    ) async {
      late ColorScheme cs;
      await pump(
        tester,
        Builder(
          builder: (context) {
            cs = Theme.of(context).colorScheme;
            return ActionButtons.outlinedButton(
              context,
              label: 'Tillbaka',
              onPressed: () {},
              isExpanded: true,
              square: true,
            );
          },
        ),
      );
      final style = tester
          .widget<OutlinedButton>(find.byType(OutlinedButton))
          .style!;
      expect(
        style.shape!.resolve({}),
        const RoundedRectangleBorder(),
      );
      expect(style.side!.resolve({})!.color, cs.onSurface);
      expect(
        tester.getSize(find.byType(OutlinedButton)).height,
        greaterThanOrEqualTo(AppDimensions.buttonHeight),
      );
    });

    testWidgets('a square primary button is square and filled', (tester) async {
      await pump(
        tester,
        Builder(
          builder: (context) => ActionButtons.primaryButton(
            context,
            label: 'Nästa',
            onPressed: () {},
            isExpanded: true,
            square: true,
          ),
        ),
      );
      final style = tester
          .widget<ElevatedButton>(find.byType(ElevatedButton))
          .style!;
      expect(style.shape!.resolve({}), const RoundedRectangleBorder());
    });
  });

  group('StyledInput', () {
    testWidgets('square removes the corner radius from every edge', (
      tester,
    ) async {
      await pump(tester, const StyledInput(hint: 'Länk', square: true));
      final decoration = tester
          .widget<InputDecorator>(find.byType(InputDecorator))
          .decoration;
      for (final border in [
        decoration.border,
        decoration.enabledBorder,
        decoration.focusedBorder,
        decoration.errorBorder,
        decoration.disabledBorder,
      ]) {
        expect((border! as dynamic).borderRadius, BorderRadius.zero);
      }
    });

    testWidgets('a round field keeps its radius', (tester) async {
      await pump(tester, const StyledInput(hint: 'Namn'));
      final decoration = tester
          .widget<InputDecorator>(find.byType(InputDecorator))
          .decoration;
      expect(
        (decoration.enabledBorder! as dynamic).borderRadius,
        isNot(BorderRadius.zero),
      );
    });

    testWidgets('suffixText and counterText reach the decoration', (
      tester,
    ) async {
      await pump(
        tester,
        const StyledInput(
          hint: 'Tid',
          suffixText: 'min',
          maxLength: 10,
          counterText: '3 / 10',
        ),
      );
      expect(find.text('min'), findsOneWidget);
      expect(find.text('3 / 10'), findsOneWidget);
    });
  });

  group('StyledInput initialValue', () {
    testWidgets('starts with the given text when it has no controller', (
      tester,
    ) async {
      await pump(
        tester,
        const StyledInput(label: 'Källa', initialValue: 'https://a.se'),
      );
      expect(find.text('https://a.se'), findsOneWidget);
    });
  });

  group('ButleryTextButton', () {
    testWidgets('expanded fills the width it is given and fires', (
      tester,
    ) async {
      var pressed = 0;
      Widget button({required bool expanded}) => Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: ButleryTextButton(
            label: 'Hoppa över',
            expanded: expanded,
            tone: ButleryTextButtonTone.muted,
            onPressed: () => pressed++,
          ),
        ),
      );

      await pump(tester, button(expanded: false));
      final hugging = tester.getSize(find.byType(TextButton)).width;
      await pump(tester, button(expanded: true));

      expect(tester.getSize(find.byType(TextButton)).width, 300);
      expect(hugging, lessThan(300));
      await tester.tap(find.text('Hoppa över'));
      expect(pressed, 1);
    });
  });

  group('ButleryDropdown', () {
    testWidgets('square uses a cornerless edge', (tester) async {
      await pump(
        tester,
        ButleryDropdown<int>(
          square: true,
          semanticLabel: 'År',
          hint: 'Välj',
          value: null,
          options: const [ButleryDropdownOption(value: 1, label: 'Ett')],
          onChanged: (_) {},
        ),
      );
      final decoration = tester
          .widget<InputDecorator>(find.byType(InputDecorator))
          .decoration;
      expect(
        (decoration.enabledBorder! as dynamic).borderRadius,
        BorderRadius.zero,
      );
    });

    testWidgets('a header cannot be picked and an error option reads red', (
      tester,
    ) async {
      String? picked;
      await pump(
        tester,
        ButleryDropdown<String>(
          semanticLabel: 'Egenskap',
          value: 'gamla',
          options: const [
            ButleryDropdownOption(
              value: '#h',
              label: 'Allergener',
              header: true,
            ),
            ButleryDropdownOption(
              value: 'gluten',
              label: 'gluten',
              indented: true,
            ),
            ButleryDropdownOption(value: 'gamla', label: 'gamla', error: true),
          ],
          onChanged: (v) => picked = v,
        ),
      );
      final closed = tester.widget<Text>(find.text('gamla'));
      expect(closed.style?.color, AppTheme.lightTheme.colorScheme.error);

      await tester.tap(find.byType(ButleryDropdown<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Allergener').last);
      await tester.pumpAndSettle();
      expect(picked, isNull);

      await tester.tap(find.text('gluten').last);
      await tester.pumpAndSettle();
      expect(picked, 'gluten');
    });
  });

  group('ButleryItemRow', () {
    testWidgets('emphasised bolds the title', (
      tester,
    ) async {
      await pump(
        tester,
        Column(
          children: const [
            ButleryItemRow(title: 'Oläst', emphasised: true),
            ButleryItemRow(title: 'Läst'),
          ],
        ),
      );
      final unread = tester.widget<Text>(find.text('Oläst')).style!.fontWeight;
      final read = tester.widget<Text>(find.text('Läst')).style!.fontWeight;
      expect(unread!.value, greaterThan(read!.value));
    });
  });
}
