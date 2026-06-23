import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/indicators/adaptive_activity_indicator.dart';
import 'package:butlery/widgets/common/indicators/loading_indicator.dart';

/// BUT-1173: LoadingIndicator gained a determinate variant (`value:`). These
/// tests pin the branch contract — determinate renders a Material
/// CircularProgressIndicator carrying the value; the indeterminate default path
/// is unchanged (still the platform-adaptive indicator).
void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: Center(child: child)),
    ),
  );

  group('LoadingIndicator determinate variant (BUT-1173)', () {
    testWidgets(
      'value != null renders a determinate CircularProgressIndicator',
      (tester) async {
        await pump(tester, const LoadingIndicator(value: 0.42));

        final cpi = tester.widget<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        );
        expect(cpi.value, 0.42);
        // Determinate path bypasses the adaptive (indeterminate) indicator.
        expect(find.byType(AdaptiveActivityIndicator), findsNothing);
      },
    );

    testWidgets('value != null forwards strokeWidth and backgroundColor', (
      tester,
    ) async {
      await pump(
        tester,
        const LoadingIndicator(
          value: 0.7,
          strokeWidth: 8,
          backgroundColor: Color(0xFF112233),
        ),
      );

      final cpi = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(cpi.value, 0.7);
      expect(cpi.strokeWidth, 8);
      expect(cpi.backgroundColor, const Color(0xFF112233));
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

    testWidgets(
      'value null but backgroundColor set keeps the Material track (not adaptive)',
      (tester) async {
        // Upload site: progress==0 → value null, but the track ring must remain.
        await pump(
          tester,
          const LoadingIndicator(
            value: null,
            backgroundColor: Color(0xFF112233),
          ),
        );

        final cpi = tester.widget<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        );
        expect(cpi.value, isNull); // indeterminate…
        expect(cpi.backgroundColor, const Color(0xFF112233)); // …but track kept
        expect(find.byType(AdaptiveActivityIndicator), findsNothing);
      },
    );
  });

  group('LoadingIndicator indeterminate (unchanged)', () {
    testWidgets(
      'default (no value) uses the adaptive indeterminate indicator',
      (tester) async {
        await pump(tester, const LoadingIndicator());
        expect(find.byType(AdaptiveActivityIndicator), findsOneWidget);
      },
    );

    testWidgets('.small stays indeterminate (value is null)', (tester) async {
      await pump(tester, const LoadingIndicator.small());
      expect(find.byType(AdaptiveActivityIndicator), findsOneWidget);
    });
  });
}
