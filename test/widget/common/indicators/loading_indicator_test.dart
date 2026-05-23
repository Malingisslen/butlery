/// Widget tests for LoadingIndicator.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/indicators/adaptive_activity_indicator.dart';
import 'package:butlery/widgets/common/indicators/loading_indicator.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

/// The outer SizedBox is the first SizedBox descendant of LoadingIndicator
/// (its direct child). On non-iOS hosts AdaptiveActivityIndicator also
/// contains a SizedBox internally, so we cannot use `.single`.
SizedBox _sizedBoxFor(WidgetTester tester) {
  return tester.widget<SizedBox>(find
      .descendant(
        of: find.byType(LoadingIndicator),
        matching: find.byType(SizedBox),
      )
      .first);
}

AdaptiveActivityIndicator _adaptiveOf(WidgetTester tester) {
  return tester.widget<AdaptiveActivityIndicator>(
    find.byType(AdaptiveActivityIndicator),
  );
}

void main() {
  group('LoadingIndicator — default', () {
    testWidgets('renders an AdaptiveActivityIndicator inside a SizedBox',
        (tester) async {
      await tester.pumpWidget(_wrap(const LoadingIndicator()));
      expect(find.byType(AdaptiveActivityIndicator), findsOneWidget);
      expect(_sizedBoxFor(tester).width, AppDimensions.iconSizeM);
      expect(_sizedBoxFor(tester).height, AppDimensions.iconSizeM);
    });

    testWidgets('default has no Padding wrapper (padding is null)',
        (tester) async {
      await tester.pumpWidget(_wrap(const LoadingIndicator()));
      // The widget tree under LoadingIndicator should be SizedBox directly
      // — no Padding descendant of LoadingIndicator.
      expect(
        find.descendant(
          of: find.byType(LoadingIndicator),
          matching: find.byType(Padding),
        ),
        findsNothing,
      );
    });

    testWidgets('passes default strokeWidth=3 to inner indicator',
        (tester) async {
      await tester.pumpWidget(_wrap(const LoadingIndicator()));
      expect(_adaptiveOf(tester).strokeWidth, 3);
    });

    testWidgets('passes radius = size/2 to inner indicator', (tester) async {
      await tester.pumpWidget(_wrap(const LoadingIndicator()));
      expect(
        _adaptiveOf(tester).radius,
        AppDimensions.iconSizeM / 2,
      );
    });
  });

  group('LoadingIndicator — explicit props', () {
    testWidgets('explicit size sets SizedBox dimensions + radius',
        (tester) async {
      await tester.pumpWidget(_wrap(const LoadingIndicator(size: 80)));
      expect(_sizedBoxFor(tester).width, 80);
      expect(_sizedBoxFor(tester).height, 80);
      expect(_adaptiveOf(tester).radius, 40);
    });

    testWidgets('explicit strokeWidth forwards to AdaptiveActivityIndicator',
        (tester) async {
      await tester.pumpWidget(_wrap(const LoadingIndicator(strokeWidth: 6)));
      expect(_adaptiveOf(tester).strokeWidth, 6);
    });

    testWidgets('explicit color forwards to AdaptiveActivityIndicator',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const LoadingIndicator(color: Colors.deepOrange),
      ));
      expect(_adaptiveOf(tester).color, Colors.deepOrange);
    });

    testWidgets('explicit padding wraps the SizedBox in a Padding',
        (tester) async {
      await tester.pumpWidget(_wrap(const LoadingIndicator(
        padding: EdgeInsets.all(24),
      )));
      final padding = tester.widget<Padding>(find.descendant(
        of: find.byType(LoadingIndicator),
        matching: find.byType(Padding),
      ));
      expect(padding.padding, const EdgeInsets.all(24));
    });
  });

  group('LoadingIndicator.small', () {
    testWidgets('uses iconSizeS dimensions', (tester) async {
      await tester.pumpWidget(_wrap(const LoadingIndicator.small()));
      expect(_sizedBoxFor(tester).width, AppDimensions.iconSizeS);
      expect(_sizedBoxFor(tester).height, AppDimensions.iconSizeS);
    });

    testWidgets('uses strokeWidth=2', (tester) async {
      await tester.pumpWidget(_wrap(const LoadingIndicator.small()));
      expect(_adaptiveOf(tester).strokeWidth, 2);
    });

    testWidgets('wraps content in Padding(all: spacingL)', (tester) async {
      await tester.pumpWidget(_wrap(const LoadingIndicator.small()));
      final padding = tester.widget<Padding>(find.descendant(
        of: find.byType(LoadingIndicator),
        matching: find.byType(Padding),
      ));
      expect(
        padding.padding,
        const EdgeInsets.all(AppDimensions.spacingL),
      );
    });

    testWidgets('forwards color', (tester) async {
      await tester.pumpWidget(_wrap(
        const LoadingIndicator.small(color: Colors.teal),
      ));
      expect(_adaptiveOf(tester).color, Colors.teal);
    });
  });
}
