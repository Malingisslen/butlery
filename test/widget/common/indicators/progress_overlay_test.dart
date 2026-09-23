// test/widget/common/indicators/progress_overlay_test.dart
//
// ProgressOverlay: text plus the plate line on a dark scrim, never a
// spinner (produktregler.md:163, B-18).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';
import 'package:butlery/widgets/common/indicators/progress_overlay.dart';

Widget _wrap(Widget overlay, {Brightness brightness = Brightness.light}) =>
    MaterialApp(
      theme: ThemeData(
        colorScheme: brightness == Brightness.dark
            ? AppColors.darkColorScheme
            : AppColors.lightColorScheme,
      ),
      home: Scaffold(
        body: SizedBox(
          width: 96,
          height: 96,
          child: Stack(children: [overlay]),
        ),
      ),
    );

BoxDecoration _scrim(WidgetTester tester) =>
    tester
            .widget<DecoratedBox>(
              find
                  .descendant(
                    of: find.byType(ProgressOverlay),
                    matching: find.byType(DecoratedBox),
                  )
                  .first,
            )
            .decoration
        as BoxDecoration;

void main() {
  testWidgets('shows the text and the in-button plate line, no spinner', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const ProgressOverlay(text: 'Laddar upp')));
    expect(find.text('Laddar upp'), findsOneWidget);
    expect(find.byType(ButtonPlateLine), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    // The text stands above the line.
    expect(
      tester.getRect(find.text('Laddar upp')).bottom,
      lessThanOrEqualTo(tester.getRect(find.byType(ButtonPlateLine)).top),
    );
  });

  testWidgets('fills its stack', (tester) async {
    await tester.pumpWidget(_wrap(const ProgressOverlay(text: 'x')));
    final positioned = tester.widget<Positioned>(find.byType(Positioned));
    expect(positioned.left, 0);
    expect(positioned.top, 0);
    expect(positioned.right, 0);
    expect(positioned.bottom, 0);
  });

  testWidgets('avatar is a circle, rectangle is a rectangle', (tester) async {
    await tester.pumpWidget(_wrap(const ProgressOverlay.avatar(text: 'x')));
    expect(_scrim(tester).shape, BoxShape.circle);
    await tester.pumpWidget(_wrap(const ProgressOverlay.rectangle(text: 'x')));
    expect(_scrim(tester).shape, BoxShape.rectangle);
  });

  for (final brightness in Brightness.values) {
    testWidgets('scrim, text and line follow the scheme in $brightness', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const ProgressOverlay(text: 'x'), brightness: brightness),
      );
      final cs = brightness == Brightness.dark
          ? AppColors.darkColorScheme
          : AppColors.lightColorScheme;
      expect(
        _scrim(tester).color,
        cs.onSurface.withValues(alpha: AppDimensions.opacityDark),
      );
      expect(
        tester.widget<Text>(find.text('x')).style?.color,
        cs.surfaceContainerHighest,
      );
      expect(
        tester.widget<ButtonPlateLine>(find.byType(ButtonPlateLine)).color,
        cs.surfaceContainerHighest,
      );
    });
  }

  testWidgets('custom colours pass through', (tester) async {
    const bg = Color(0x80000000);
    const fg = Color(0xFFFFFFFF);
    await tester.pumpWidget(
      _wrap(
        const ProgressOverlay.rectangle(
          text: 'x',
          backgroundColor: bg,
          progressColor: fg,
          textColor: fg,
        ),
      ),
    );
    expect(_scrim(tester).color, bg);
    expect(
      tester.widget<ButtonPlateLine>(find.byType(ButtonPlateLine)).color,
      fg,
    );
  });

  testWidgets('one semantics node: the text, as a live region', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_wrap(const ProgressOverlay(text: 'Laddar upp')));
    expect(find.bySemanticsLabel('Laddar upp'), findsOneWidget);
    handle.dispose();
  });
}
