/// Widget tests for PlateLine, the app's single loading indicator.
///
/// Komponentark v1:303-309 draws two free-standing forms: determinate fills
/// left to right in saffron, indeterminate is a still segment that pulses in
/// opacity in place and stands still under reduced motion.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_colors_dark.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';

Widget _wrap(
  Widget child, {
  Brightness brightness = Brightness.light,
  bool disableAnimations = false,
}) => MaterialApp(
  theme: ThemeData(
    colorScheme: brightness == Brightness.dark
        ? AppColors.darkColorScheme
        : AppColors.lightColorScheme,
  ),
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: Scaffold(
      body: Center(child: SizedBox(width: 200, child: child)),
    ),
  ),
);

/// The nearest FadeTransition above the segment is the pulse; the route's
/// own transitions sit further up.
double _opacity(WidgetTester tester) => tester
    .widget<FadeTransition>(
      find
          .ancestor(
            of: find.byKey(PlateLine.segmentKey),
            matching: find.byType(FadeTransition),
          )
          .first,
    )
    .opacity
    .value;

Color? _segmentColor(WidgetTester tester) =>
    (tester.widget<DecoratedBox>(find.byKey(PlateLine.segmentKey)).decoration
            as BoxDecoration)
        .color;

void main() {
  group('PlateLine — indeterminate', () {
    testWidgets('is a segment on the track, not a sliding progress bar', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const PlateLine()));
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.byKey(PlateLine.segmentKey), findsOneWidget);
      expect(
        tester.getSize(find.byKey(PlateLine.trackKey)),
        const Size(200, PlateLine.thickness),
      );
    });

    testWidgets('sits at 22 % and spans 34 % of the line (v1:306)', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const PlateLine()));
      final track = tester.getRect(find.byKey(PlateLine.trackKey));
      final seg = tester.getRect(find.byKey(PlateLine.segmentKey));
      expect(seg.left - track.left, closeTo(200 * 0.22, 0.01));
      expect(seg.width, closeTo(200 * 0.34, 0.01));
      expect(seg.height, PlateLine.thickness);
    });

    testWidgets('pulses in opacity and never moves sideways', (tester) async {
      await tester.pumpWidget(_wrap(const PlateLine()));
      final start = tester.getRect(find.byKey(PlateLine.segmentKey));
      expect(_opacity(tester), 1.0);

      await tester.pump(PlateLine.pulseHalfCycle);
      expect(
        _opacity(tester),
        closeTo(PlateLine.pulseMinOpacity, 0.001),
      );
      expect(tester.getRect(find.byKey(PlateLine.segmentKey)), start);

      await tester.pump(PlateLine.pulseHalfCycle);
      expect(_opacity(tester), closeTo(1.0, 0.001));
      expect(tester.getRect(find.byKey(PlateLine.segmentKey)), start);
    });

    testWidgets('stands still at full opacity under reduced motion', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const PlateLine(), disableAnimations: true),
      );
      expect(_opacity(tester), 1.0);
      await tester.pump(PlateLine.pulseHalfCycle);
      expect(_opacity(tester), 1.0);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('segment and track take their token per mode', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const PlateLine()));
      expect(_segmentColor(tester), AppColors.surfaceDisabled);
      expect(
        tester.widget<ColoredBox>(find.byKey(PlateLine.trackKey)).color,
        AppColors.progressTrack,
      );

      await tester.pumpWidget(
        _wrap(const PlateLine(), brightness: Brightness.dark),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(_segmentColor(tester), AppColorsDark.surfaceDisabled);
      expect(
        tester.widget<ColoredBox>(find.byKey(PlateLine.trackKey)).color,
        AppColorsDark.progressTrack,
      );
    });
  });

  group('PlateLine — determinate', () {
    testWidgets('fills in saffron on the track, per mode', (tester) async {
      await tester.pumpWidget(_wrap(const PlateLine(value: 0.5)));
      var bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, 0.5);
      expect(bar.minHeight, PlateLine.thickness);
      expect(
        (bar.valueColor! as AlwaysStoppedAnimation<Color?>).value,
        AppColors.progressIndicator,
      );
      expect(bar.backgroundColor, AppColors.progressTrack);
      expect(find.byKey(PlateLine.segmentKey), findsNothing);
      expect(tester.hasRunningAnimations, isFalse);

      await tester.pumpWidget(
        _wrap(const PlateLine(value: 0.5), brightness: Brightness.dark),
      );
      await tester.pump(const Duration(seconds: 1));
      bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(
        (bar.valueColor! as AlwaysStoppedAnimation<Color?>).value,
        AppColorsDark.progressIndicator,
      );
      expect(bar.backgroundColor, AppColorsDark.progressTrack);
    });

    testWidgets('switching to a value stops the pulse', (tester) async {
      await tester.pumpWidget(_wrap(const PlateLine()));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpWidget(_wrap(const PlateLine(value: 0.3)));
      await tester.pump();
      expect(find.byKey(PlateLine.segmentKey), findsNothing);
    });
  });

  group('PlateLineMessage — plate line plus text (produktregler.md:163)', () {
    testWidgets('lays out inside an AlertDialog, which measures intrinsics', (
      tester,
    ) async {
      // A dialog asks its content for its intrinsic width; the line must be
      // able to answer (it used to throw from a LayoutBuilder).
      await tester.pumpWidget(
        _wrap(
          const AlertDialog(
            content: PlateLineMessage(message: 'Hämtar recept …'),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(PlateLine), findsOneWidget);
      expect(find.text('Hämtar recept …'), findsOneWidget);
    });

    testWidgets('the text stands above the line and is read once', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(const PlateLineMessage(message: 'Hämtar recept …')),
      );
      expect(
        tester.getRect(find.text('Hämtar recept …')).bottom,
        lessThanOrEqualTo(tester.getRect(find.byType(PlateLine)).top),
      );
      expect(find.bySemanticsLabel('Hämtar recept …'), findsOneWidget);
      handle.dispose();
    });
  });
}
