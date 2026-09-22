// Laddningens två former: tallrikslinjen med text direkt, skelettet först
// efter 300 ms (produktregler.md:163 och :304, beslut B-18).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/widgets/common/indicators/pea_loading_animation.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';
import 'package:butlery/widgets/common/state/delayed_skeleton.dart';
import 'package:butlery/widgets/common/state/loading_states.dart';
import 'package:butlery/widgets/common/state_widget.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

Widget _variant(LoadingVariant variant, {String? message}) => _wrap(
  Builder(
    builder: (context) => LoadingStates.buildLoadingState(
      context,
      variant: variant,
      message: message,
    ),
  ),
);

void main() {
  group('DelayedSkeleton', () {
    testWidgets('draws nothing at 299 ms and the skeleton at 301 ms', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const DelayedSkeleton(child: Text('skelett'))),
      );
      expect(find.text('skelett'), findsNothing);

      await tester.pump(const Duration(milliseconds: 299));
      expect(find.text('skelett'), findsNothing);

      await tester.pump(const Duration(milliseconds: 2));
      expect(find.text('skelett'), findsOneWidget);
    });

    testWidgets('has no semantics node before the threshold', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(const DelayedSkeleton(child: Text('skelett'))),
      );
      expect(find.bySemanticsLabel('skelett'), findsNothing);
      await tester.pump(const Duration(milliseconds: 301));
      expect(find.bySemanticsLabel('skelett'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('disposing before the threshold cancels the timer', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const DelayedSkeleton(child: Text('skelett'))),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(_wrap(const SizedBox()));
      // Ingen väntande timer och inget setState efter dispose.
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      expect(find.text('skelett'), findsNothing);
    });

    test('the threshold is 300 ms', () {
      expect(DelayedSkeleton.threshold, const Duration(milliseconds: 300));
    });
  });

  group('LoadingStates — the threshold applies to the skeleton only', () {
    for (final variant in [
      LoadingVariant.skeletonRecipeList,
      LoadingVariant.skeletonRecipeCard,
      LoadingVariant.skeletonGeneric,
      LoadingVariant.shimmerBox,
    ]) {
      testWidgets('$variant waits 300 ms', (tester) async {
        await tester.pumpWidget(_variant(variant));
        expect(find.byType(DelayedSkeleton), findsOneWidget);
        expect(find.byType(Card), findsNothing);
        expect(find.byType(Container), findsNothing);
        await tester.pump(const Duration(milliseconds: 301));
        expect(find.byType(Container), findsWidgets);
      });
    }

    testWidgets('the plate line and its text show at once', (tester) async {
      await tester.pumpWidget(
        _variant(LoadingVariant.spinner, message: 'Hämtar recepten …'),
      );
      expect(find.byType(PlateLine), findsOneWidget);
      expect(find.text('Hämtar recepten …'), findsOneWidget);
      expect(find.byType(DelayedSkeleton), findsNothing);
    });

    testWidgets('peaAnimation draws the plate line, not the pea pod', (
      tester,
    ) async {
      await tester.pumpWidget(_variant(LoadingVariant.peaAnimation));
      expect(find.byType(PlateLine), findsOneWidget);
      expect(find.byType(PeaLoadingAnimation), findsNothing);
    });

    testWidgets('the line carries the text as its name, read once', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _variant(LoadingVariant.spinner, message: 'Hämtar veckomenyn …'),
      );
      expect(find.bySemanticsLabel('Hämtar veckomenyn …'), findsOneWidget);
      final node = tester.getSemantics(
        find.bySemanticsLabel('Hämtar veckomenyn …'),
      );
      expect(node.flagsCollection.isLiveRegion, isTrue);
      handle.dispose();
    });
  });

  group('StateWidget.loading', () {
    testWidgets('defaults to the plate line, not the pea pod', (tester) async {
      await tester.pumpWidget(
        _wrap(StateWidget.loading(message: 'Hämtar recepten …')),
      );
      expect(find.byType(PlateLine), findsOneWidget);
      expect(find.byType(PeaLoadingAnimation), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Hämtar recepten …'), findsOneWidget);
    });
  });
}
