import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/indicators/loading_indicator.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';

/// BUT-1173: LoadingIndicator has a determinate variant (`value:`). The body is
/// now the plate line (decision B-18, beslutslogg.md:25: no spinner), so these
/// tests pin that the value reaches the line and that the screen-reader
/// contract is unchanged.
void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: Center(child: child)),
    ),
  );

  group('LoadingIndicator determinate variant (BUT-1173)', () {
    testWidgets('value != null reaches the plate line as measured progress', (
      tester,
    ) async {
      await pump(tester, const LoadingIndicator(value: 0.42));

      final line = tester.widget<PlateLine>(find.byType(PlateLine));
      expect(line.value, 0.42);
      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, 0.42);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('determinate exposes the percentage to screen readers', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(tester, const LoadingIndicator(value: 0.42));

      final node = tester.getSemantics(find.byType(LoadingIndicator));
      expect(node.value, '42%'); // not masked by a static "Loading" label
      handle.dispose();
    });
  });

  group('LoadingIndicator indeterminate', () {
    testWidgets('default (no value) draws an indeterminate plate line', (
      tester,
    ) async {
      await pump(tester, const LoadingIndicator());
      expect(tester.widget<PlateLine>(find.byType(PlateLine)).value, isNull);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('.small stays indeterminate (value is null)', (tester) async {
      await pump(tester, const LoadingIndicator.small());
      expect(tester.widget<PlateLine>(find.byType(PlateLine)).value, isNull);
    });

    testWidgets('announces a11yLoading as a live region', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, const LoadingIndicator(semanticLabel: 'Hämtar …'));
      final node = tester.getSemantics(find.byType(LoadingIndicator));
      expect(node.label, 'Hämtar …');
      expect(node.flagsCollection.isLiveRegion, isTrue);
      handle.dispose();
    });
  });
}
