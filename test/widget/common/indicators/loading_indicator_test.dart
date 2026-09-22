/// Widget tests for LoadingIndicator.
///
/// The body is the plate line (decision B-18, beslutslogg.md:25: no spinner),
/// centred in the same size × size box the spinner used to fill, so row height
/// and bounded width at every call site stay as they were.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_colors_dark.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/indicators/loading_indicator.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';

Widget _wrap(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme,
  home: Scaffold(body: child),
);

/// The outer SizedBox is the first SizedBox descendant of LoadingIndicator.
/// PlateLine also contains a SizedBox for its width, so we cannot use
/// `.single`.
SizedBox _sizedBoxFor(WidgetTester tester) {
  return tester.widget<SizedBox>(
    find
        .descendant(
          of: find.byType(LoadingIndicator),
          matching: find.byType(SizedBox),
        )
        .first,
  );
}

PlateLine _lineOf(WidgetTester tester) =>
    tester.widget<PlateLine>(find.byType(PlateLine));

ColoredBox _trackOf(WidgetTester tester) =>
    tester.widget<ColoredBox>(find.byKey(PlateLine.trackKey));

Color? _segmentOf(WidgetTester tester) =>
    (tester.widget<DecoratedBox>(find.byKey(PlateLine.segmentKey)).decoration
            as BoxDecoration)
        .color;

void main() {
  group('LoadingIndicator — default', () {
    testWidgets('renders a plate line centred in a size × size SizedBox', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const LoadingIndicator()));
      expect(find.byType(PlateLine), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(_sizedBoxFor(tester).width, AppDimensions.iconSizeM);
      expect(_sizedBoxFor(tester).height, AppDimensions.iconSizeM);
      expect(_lineOf(tester).width, AppDimensions.iconSizeM);
      expect(
        find.descendant(
          of: find.byType(LoadingIndicator),
          matching: find.byType(Center),
        ),
        findsOneWidget,
      );
    });

    testWidgets('default has no Padding wrapper (padding is null)', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const LoadingIndicator()));
      expect(
        find.descendant(
          of: find.byType(LoadingIndicator),
          matching: find.byType(Padding),
        ),
        findsNothing,
      );
    });

    testWidgets('a bare LoadingIndicator in a Row with an Expanded sibling '
        'lays out (bounded width, as in base_dialog)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const Row(
            children: [
              LoadingIndicator(),
              SizedBox(width: AppDimensions.spacingM),
              Expanded(child: Text('Hämtar …')),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(LoadingIndicator)),
        const Size(AppDimensions.iconSizeM, AppDimensions.iconSizeM),
      );
    });
  });

  group('LoadingIndicator — explicit props', () {
    testWidgets('explicit size sets the box and the line width', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const LoadingIndicator(size: 80)));
      expect(_sizedBoxFor(tester).width, 80);
      expect(_sizedBoxFor(tester).height, 80);
      expect(_lineOf(tester).width, 80);
    });

    testWidgets('strokeWidth does not change the line: thickness is fixed', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const LoadingIndicator(strokeWidth: 6)));
      expect(
        tester.getSize(find.byKey(PlateLine.trackKey)).height,
        PlateLine.thickness,
      );
    });

    testWidgets('colours come from the tokens per mode, never from color', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const LoadingIndicator(
            color: Colors.deepOrange,
            backgroundColor: Colors.black,
          ),
          theme: ThemeData(colorScheme: AppColors.lightColorScheme),
        ),
      );
      expect(_trackOf(tester).color, AppColors.progressTrack);
      expect(_segmentOf(tester), AppColors.surfaceDisabled);

      await tester.pumpWidget(
        _wrap(
          const LoadingIndicator(color: Colors.deepOrange),
          theme: ThemeData(colorScheme: AppColors.darkColorScheme),
        ),
      );
      // MaterialApp animates between themes; let the change land.
      await tester.pump(const Duration(seconds: 1));
      expect(_trackOf(tester).color, AppColorsDark.progressTrack);
      expect(_segmentOf(tester), AppColorsDark.surfaceDisabled);
    });

    testWidgets('explicit padding wraps the SizedBox in a Padding', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const LoadingIndicator(
            padding: EdgeInsets.all(24),
          ),
        ),
      );
      final padding = tester.widget<Padding>(
        find.descendant(
          of: find.byType(LoadingIndicator),
          matching: find.byType(Padding),
        ),
      );
      expect(padding.padding, const EdgeInsets.all(24));
    });
  });

  group('LoadingIndicator.small', () {
    testWidgets('uses iconSizeS dimensions', (tester) async {
      await tester.pumpWidget(_wrap(const LoadingIndicator.small()));
      expect(_sizedBoxFor(tester).width, AppDimensions.iconSizeS);
      expect(_sizedBoxFor(tester).height, AppDimensions.iconSizeS);
      expect(_lineOf(tester).width, AppDimensions.iconSizeS);
    });

    testWidgets('wraps content in Padding(all: spacingL)', (tester) async {
      await tester.pumpWidget(_wrap(const LoadingIndicator.small()));
      final padding = tester.widget<Padding>(
        find.descendant(
          of: find.byType(LoadingIndicator),
          matching: find.byType(Padding),
        ),
      );
      expect(
        padding.padding,
        const EdgeInsets.all(AppDimensions.spacingL),
      );
    });
  });
}
