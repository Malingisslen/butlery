import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import '../../../test_support/base_unit_test.dart';

/// BUT-2367: an inline ActionButtons button hugs its label while an expanded
/// one fills its parent, and the two on-ink variants draw paper on ink.
void main() {
  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  tearDown(() async {
    BaseUnitTest.resetMocks();
  });

  Future<ColorScheme> pump(
    WidgetTester tester,
    ThemeData theme,
    Widget Function(BuildContext) build,
  ) async {
    late ColorScheme cs;
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 400,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Builder(
                    builder: (context) {
                      cs = Theme.of(context).colorScheme;
                      return build(context);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return cs;
  }

  group('width', () {
    testWidgets('an inline button hugs a short label', (tester) async {
      await pump(
        tester,
        AppTheme.lightTheme,
        (context) => ActionButtons.primaryButton(
          context,
          label: 'Ok',
          onPressed: () {},
        ),
      );

      final size = tester.getSize(find.byType(ElevatedButton));
      expect(size.width, lessThan(200));
      expect(size.height, greaterThanOrEqualTo(AppDimensions.minTouchTarget));
    });

    testWidgets('an inline outlined button hugs a short label', (
      tester,
    ) async {
      await pump(
        tester,
        AppTheme.lightTheme,
        (context) => ActionButtons.outlinedButton(
          context,
          label: 'Ok',
          onPressed: () {},
        ),
      );

      expect(tester.getSize(find.byType(OutlinedButton)).width, lessThan(200));
    });

    testWidgets('an expanded button fills its parent', (tester) async {
      await pump(
        tester,
        AppTheme.lightTheme,
        (context) => ActionButtons.primaryButton(
          context,
          label: 'Ok',
          onPressed: () {},
          isExpanded: true,
        ),
      );

      expect(tester.getSize(find.byType(ElevatedButton)).width, 400);
    });
  });

  for (final (mode, theme) in [
    ('light', AppTheme.lightTheme),
    ('dark', AppTheme.darkTheme),
  ]) {
    group('on ink ($mode)', () {
      testWidgets('onInk is a paper fill with ink text', (tester) async {
        final cs = await pump(
          tester,
          theme,
          (context) => ActionButtons.actionButton(
            context,
            label: 'Fortsätt',
            onPressed: () {},
            style: ActionButtonStyle.onInk,
          ),
        );

        final style = tester
            .widget<ElevatedButton>(find.byType(ElevatedButton))
            .style!;
        expect(style.backgroundColor!.resolve({}), cs.onPrimary);
        expect(style.foregroundColor!.resolve({}), cs.primary);
      });

      testWidgets('outlinedOnInk is paper text inside a paper outline', (
        tester,
      ) async {
        final cs = await pump(
          tester,
          theme,
          (context) => ActionButtons.actionButton(
            context,
            label: 'Byt rätt',
            onPressed: () {},
            style: ActionButtonStyle.outlinedOnInk,
          ),
        );

        final style = tester
            .widget<OutlinedButton>(find.byType(OutlinedButton))
            .style!;
        expect(style.foregroundColor!.resolve({}), cs.onPrimary);
        expect(
          style.side!.resolve({})!.color,
          cs.onPrimary.withValues(alpha: 0.35),
        );
      });
    });
  }
}
