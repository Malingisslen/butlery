// test/widget/common/indicators/loading_indicator_ultrathink_test.dart
// Comprehensive tests for LoadingIndicator using ultrathink methodology
// 
// ULTRATHINK ANALYSIS: LoadingIndicator widget (48 lines)
// - Simple component with optional parameters: size, strokeWidth, padding
// - Named constructor LoadingIndicator.small() with preset values
// - Conditional padding logic (lines 39-46) - only adds Padding if padding != null
// - Delegates to CircularProgressIndicator with size constraints via SizedBox
// - Default values: size=AppDimensions.iconSizeM, strokeWidth=3

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/indicators/loading_indicator.dart';
import 'package:butlery/theme/app_dimensions.dart';

void main() {
  group('LoadingIndicator Widget Tests - ULTRATHINK METHODOLOGY', () {
    // Helper to create test environment
    Widget createTestWidget(Widget child) {
      return MaterialApp(
        theme: ThemeData(
          colorScheme: const ColorScheme.light(
            primary: Colors.blue,
            surface: Colors.white,
            onSurface: Colors.black,
          ),
        ),
        home: Scaffold(
          body: Center(child: child),
        ),
      );
    }

    group('Main Constructor - Default Behavior', () {
      testWidgets('should create CircularProgressIndicator with default values', (WidgetTester tester) async {
        // ULTRATHINK: Test production code lines 30-47 with all defaults
        await tester.pumpWidget(createTestWidget(
          const LoadingIndicator(),
        ));

        expect(tester.takeException(), isNull);
        
        // Should create SizedBox with default size (AppDimensions.iconSizeM)
        final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox));
        expect(sizedBox.width, equals(AppDimensions.iconSizeM));
        expect(sizedBox.height, equals(AppDimensions.iconSizeM));
        
        // Should create CircularProgressIndicator with default strokeWidth (3)
        final indicator = tester.widget<CircularProgressIndicator>(find.byType(CircularProgressIndicator));
        expect(indicator.strokeWidth, equals(3.0));
        
        // Should NOT wrap with Padding since padding is null (lines 39-46)
        expect(find.byType(Padding), findsNothing);
      });

      testWidgets('should respect custom size parameter', (WidgetTester tester) async {
        // ULTRATHINK: Test production code lines 32-33 with custom size
        const customSize = 50.0;
        
        await tester.pumpWidget(createTestWidget(
          const LoadingIndicator(size: customSize),
        ));

        expect(tester.takeException(), isNull);
        
        // Should create SizedBox with custom size
        final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox));
        expect(sizedBox.width, equals(customSize));
        expect(sizedBox.height, equals(customSize));
        
        // Should still use default strokeWidth
        final indicator = tester.widget<CircularProgressIndicator>(find.byType(CircularProgressIndicator));
        expect(indicator.strokeWidth, equals(3.0));
      });

      testWidgets('should respect custom strokeWidth parameter', (WidgetTester tester) async {
        // ULTRATHINK: Test production code line 35 with custom strokeWidth
        const customStrokeWidth = 5.0;
        
        await tester.pumpWidget(createTestWidget(
          const LoadingIndicator(strokeWidth: customStrokeWidth),
        ));

        expect(tester.takeException(), isNull);
        
        // Should use default size
        final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox));
        expect(sizedBox.width, equals(AppDimensions.iconSizeM));
        expect(sizedBox.height, equals(AppDimensions.iconSizeM));
        
        // Should create CircularProgressIndicator with custom strokeWidth
        final indicator = tester.widget<CircularProgressIndicator>(find.byType(CircularProgressIndicator));
        expect(indicator.strokeWidth, equals(customStrokeWidth));
      });

      testWidgets('should add Padding when padding parameter provided', (WidgetTester tester) async {
        // ULTRATHINK: Test production code conditional logic lines 39-46
        const customPadding = EdgeInsets.all(20.0);
        
        await tester.pumpWidget(createTestWidget(
          const LoadingIndicator(padding: customPadding),
        ));

        expect(tester.takeException(), isNull);
        
        // Should wrap with Padding when padding is provided
        expect(find.byType(Padding), findsOneWidget);
        
        // Should use the provided padding
        final padding = tester.widget<Padding>(find.byType(Padding));
        expect(padding.padding, equals(customPadding));
        
        // Padding should contain SizedBox with default size
        final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox));
        expect(sizedBox.width, equals(AppDimensions.iconSizeM));
        expect(sizedBox.height, equals(AppDimensions.iconSizeM));
      });

      testWidgets('should combine all custom parameters correctly', (WidgetTester tester) async {
        // ULTRATHINK: Test production code with all parameters customized
        const customSize = 60.0;
        const customStrokeWidth = 4.0;
        const customPadding = EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0);
        
        await tester.pumpWidget(createTestWidget(
          const LoadingIndicator(
            size: customSize,
            strokeWidth: customStrokeWidth,
            padding: customPadding,
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // Should wrap with Padding
        expect(find.byType(Padding), findsOneWidget);
        final padding = tester.widget<Padding>(find.byType(Padding));
        expect(padding.padding, equals(customPadding));
        
        // Should create SizedBox with custom size
        final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox));
        expect(sizedBox.width, equals(customSize));
        expect(sizedBox.height, equals(customSize));
        
        // Should create CircularProgressIndicator with custom strokeWidth
        final indicator = tester.widget<CircularProgressIndicator>(find.byType(CircularProgressIndicator));
        expect(indicator.strokeWidth, equals(customStrokeWidth));
      });
    });

    group('Named Constructor - LoadingIndicator.small()', () {
      testWidgets('should create small loading indicator with preset values', (WidgetTester tester) async {
        // ULTRATHINK: Test production code lines 23-27 - small named constructor
        await tester.pumpWidget(createTestWidget(
          const LoadingIndicator.small(),
        ));

        expect(tester.takeException(), isNull);
        
        // Should wrap with Padding (line 27 sets padding)
        expect(find.byType(Padding), findsOneWidget);
        
        // Should use preset padding from line 27
        final padding = tester.widget<Padding>(find.byType(Padding));
        expect(padding.padding, equals(const EdgeInsets.all(AppDimensions.spacingL)));
        
        // Should create SizedBox with small size (line 25)
        final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox));
        expect(sizedBox.width, equals(AppDimensions.iconSizeS));
        expect(sizedBox.height, equals(AppDimensions.iconSizeS));
        
        // Should create CircularProgressIndicator with small strokeWidth (line 26)
        final indicator = tester.widget<CircularProgressIndicator>(find.byType(CircularProgressIndicator));
        expect(indicator.strokeWidth, equals(2.0));
      });

      testWidgets('should maintain small preset values regardless of context', (WidgetTester tester) async {
        // ULTRATHINK: Test that named constructor ignores external sizing hints
        await tester.pumpWidget(createTestWidget(
          SizedBox(
            width: 200,
            height: 200,
            child: const LoadingIndicator.small(),
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // Should still use preset small values, not container size
        // Find the SizedBox that contains the CircularProgressIndicator (the inner one)
        final innerSizedBox = tester.widget<SizedBox>(
          find.descendant(
            of: find.byType(LoadingIndicator),
            matching: find.byType(SizedBox),
          ),
        );
        expect(innerSizedBox.width, equals(AppDimensions.iconSizeS));
        expect(innerSizedBox.height, equals(AppDimensions.iconSizeS));
        
        // Should still use preset small strokeWidth
        final indicator = tester.widget<CircularProgressIndicator>(find.byType(CircularProgressIndicator));
        expect(indicator.strokeWidth, equals(2.0));
      });
    });

    group('Widget Structure and Layout', () {
      testWidgets('should maintain proper widget hierarchy without padding', (WidgetTester tester) async {
        // ULTRATHINK: Test production code structure lines 31-37 (no padding path)
        await tester.pumpWidget(createTestWidget(
          const LoadingIndicator(),
        ));

        expect(tester.takeException(), isNull);
        
        // Widget hierarchy: LoadingIndicator -> SizedBox -> CircularProgressIndicator
        expect(find.byType(LoadingIndicator), findsOneWidget);
        expect(find.byType(SizedBox), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byType(Padding), findsNothing);
        
        // SizedBox should contain CircularProgressIndicator
        final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox));
        expect(sizedBox.child, isA<CircularProgressIndicator>());
      });

      testWidgets('should maintain proper widget hierarchy with padding', (WidgetTester tester) async {
        // ULTRATHINK: Test production code structure lines 40-46 (with padding path)
        await tester.pumpWidget(createTestWidget(
          const LoadingIndicator(padding: EdgeInsets.all(8.0)),
        ));

        expect(tester.takeException(), isNull);
        
        // Widget hierarchy: LoadingIndicator -> Padding -> SizedBox -> CircularProgressIndicator
        expect(find.byType(LoadingIndicator), findsOneWidget);
        expect(find.byType(Padding), findsOneWidget);
        expect(find.byType(SizedBox), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        
        // Padding should contain SizedBox
        final padding = tester.widget<Padding>(find.byType(Padding));
        expect(padding.child, isA<SizedBox>());
        
        // SizedBox should contain CircularProgressIndicator
        final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox));
        expect(sizedBox.child, isA<CircularProgressIndicator>());
      });

      testWidgets('should handle null size parameter gracefully', (WidgetTester tester) async {
        // ULTRATHINK: Test production code line 32 null coalescing with AppDimensions.iconSizeM
        await tester.pumpWidget(createTestWidget(
          const LoadingIndicator(size: null),
        ));

        expect(tester.takeException(), isNull);
        
        // Should fallback to default size when null provided
        final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox));
        expect(sizedBox.width, equals(AppDimensions.iconSizeM));
        expect(sizedBox.height, equals(AppDimensions.iconSizeM));
      });

      testWidgets('should handle null strokeWidth parameter gracefully', (WidgetTester tester) async {
        // ULTRATHINK: Test production code line 35 null coalescing with default 3
        await tester.pumpWidget(createTestWidget(
          const LoadingIndicator(strokeWidth: null),
        ));

        expect(tester.takeException(), isNull);
        
        // Should fallback to default strokeWidth when null provided
        final indicator = tester.widget<CircularProgressIndicator>(find.byType(CircularProgressIndicator));
        expect(indicator.strokeWidth, equals(3.0));
      });
    });

    group('Edge Cases and Constraints', () {
      testWidgets('should handle extremely small size values', (WidgetTester tester) async {
        // ULTRATHINK: Test edge case with very small size
        const tinySize = 1.0;
        
        await tester.pumpWidget(createTestWidget(
          const LoadingIndicator(size: tinySize),
        ));

        expect(tester.takeException(), isNull);
        
        // Should accept and use tiny size
        final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox));
        expect(sizedBox.width, equals(tinySize));
        expect(sizedBox.height, equals(tinySize));
        
        // Should still create CircularProgressIndicator
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('should handle extremely large size values', (WidgetTester tester) async {
        // ULTRATHINK: Test edge case with very large size
        const largeSize = 500.0;
        
        await tester.pumpWidget(createTestWidget(
          const LoadingIndicator(size: largeSize),
        ));

        expect(tester.takeException(), isNull);
        
        // Should accept and use large size
        final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox));
        expect(sizedBox.width, equals(largeSize));
        expect(sizedBox.height, equals(largeSize));
        
        // Should still create CircularProgressIndicator
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('should handle zero strokeWidth', (WidgetTester tester) async {
        // ULTRATHINK: Test edge case with zero strokeWidth
        const zeroStroke = 0.0;
        
        await tester.pumpWidget(createTestWidget(
          const LoadingIndicator(strokeWidth: zeroStroke),
        ));

        expect(tester.takeException(), isNull);
        
        // Should accept zero strokeWidth
        final indicator = tester.widget<CircularProgressIndicator>(find.byType(CircularProgressIndicator));
        expect(indicator.strokeWidth, equals(zeroStroke));
      });

      testWidgets('should handle very large strokeWidth', (WidgetTester tester) async {
        // ULTRATHINK: Test edge case with very large strokeWidth
        const largeStroke = 50.0;
        
        await tester.pumpWidget(createTestWidget(
          const LoadingIndicator(strokeWidth: largeStroke),
        ));

        expect(tester.takeException(), isNull);
        
        // Should accept large strokeWidth
        final indicator = tester.widget<CircularProgressIndicator>(find.byType(CircularProgressIndicator));
        expect(indicator.strokeWidth, equals(largeStroke));
      });

      testWidgets('should handle asymmetric padding', (WidgetTester tester) async {
        // ULTRATHINK: Test edge case with complex padding
        const asymmetricPadding = EdgeInsets.only(
          left: 5.0,
          top: 10.0,
          right: 15.0,
          bottom: 20.0,
        );
        
        await tester.pumpWidget(createTestWidget(
          const LoadingIndicator(padding: asymmetricPadding),
        ));

        expect(tester.takeException(), isNull);
        
        // Should wrap with Padding and use asymmetric values
        expect(find.byType(Padding), findsOneWidget);
        final padding = tester.widget<Padding>(find.byType(Padding));
        expect(padding.padding, equals(asymmetricPadding));
      });

      testWidgets('should handle zero padding', (WidgetTester tester) async {
        // ULTRATHINK: Test edge case with zero padding (but still provided, not null)
        const zeroPadding = EdgeInsets.zero;
        
        await tester.pumpWidget(createTestWidget(
          const LoadingIndicator(padding: zeroPadding),
        ));

        expect(tester.takeException(), isNull);
        
        // Should still wrap with Padding since padding was provided (not null)
        expect(find.byType(Padding), findsOneWidget);
        final padding = tester.widget<Padding>(find.byType(Padding));
        expect(padding.padding, equals(zeroPadding));
      });
    });

    group('Theme Integration and Rendering', () {
      testWidgets('should inherit CircularProgressIndicator theme properties', (WidgetTester tester) async {
        // ULTRATHINK: Test theme integration through CircularProgressIndicator
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              colorScheme: const ColorScheme.light(primary: Colors.red),
              progressIndicatorTheme: const ProgressIndicatorThemeData(
                color: Colors.green,
              ),
            ),
            home: Scaffold(
              body: Center(
                child: const LoadingIndicator(),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // Should create CircularProgressIndicator that can inherit theme
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        final indicator = tester.widget<CircularProgressIndicator>(find.byType(CircularProgressIndicator));
        
        // Should use our custom strokeWidth, not theme strokeWidth
        expect(indicator.strokeWidth, equals(3.0));
      });

      testWidgets('should render correctly in different layout constraints', (WidgetTester tester) async {
        // ULTRATHINK: Test rendering in constrained containers
        await tester.pumpWidget(createTestWidget(
          Column(
            children: const [
              // Tight constraints
              SizedBox(
                width: 30,
                height: 30,
                child: LoadingIndicator(),
              ),
              SizedBox(height: 16),
              // Loose constraints
              Expanded(
                child: LoadingIndicator(size: 100),
              ),
            ],
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // Should create two LoadingIndicator widgets
        expect(find.byType(LoadingIndicator), findsNWidgets(2));
        expect(find.byType(CircularProgressIndicator), findsNWidgets(2));
      });
    });

    group('API Completeness and Constructor Validation', () {
      testWidgets('should expose all documented constructor parameters', (WidgetTester tester) async {
        // ULTRATHINK: Verify all constructor parameters are accessible
        expect(() => const LoadingIndicator(), returnsNormally);
        expect(() => const LoadingIndicator(size: 40.0), returnsNormally);
        expect(() => const LoadingIndicator(strokeWidth: 4.0), returnsNormally);
        expect(() => const LoadingIndicator(padding: EdgeInsets.all(8.0)), returnsNormally);
        expect(() => const LoadingIndicator.small(), returnsNormally);
        
        // Test all parameters together
        expect(() => const LoadingIndicator(
          size: 50.0,
          strokeWidth: 5.0,
          padding: EdgeInsets.all(10.0),
        ), returnsNormally);
      });

      testWidgets('should return proper Widget type', (WidgetTester tester) async {
        // ULTRATHINK: Verify return type
        expect(const LoadingIndicator(), isA<Widget>());
        expect(const LoadingIndicator.small(), isA<Widget>());
        expect(const LoadingIndicator(size: 40.0), isA<Widget>());
      });

      testWidgets('should maintain StatelessWidget behavior', (WidgetTester tester) async {
        // ULTRATHINK: Test stateless widget behavior - multiple builds should be identical
        Widget createSameIndicator() => const LoadingIndicator(size: 35.0, strokeWidth: 2.5);
        
        await tester.pumpWidget(createTestWidget(createSameIndicator()));
        expect(tester.takeException(), isNull);
        
        // First build
        var sizedBox = tester.widget<SizedBox>(find.byType(SizedBox));
        var indicator = tester.widget<CircularProgressIndicator>(find.byType(CircularProgressIndicator));
        expect(sizedBox.width, equals(35.0));
        expect(indicator.strokeWidth, equals(2.5));
        
        // Rebuild with same parameters should produce identical results
        await tester.pumpWidget(createTestWidget(createSameIndicator()));
        expect(tester.takeException(), isNull);
        
        sizedBox = tester.widget<SizedBox>(find.byType(SizedBox));
        indicator = tester.widget<CircularProgressIndicator>(find.byType(CircularProgressIndicator));
        expect(sizedBox.width, equals(35.0));
        expect(indicator.strokeWidth, equals(2.5));
      });
    });
  });
}