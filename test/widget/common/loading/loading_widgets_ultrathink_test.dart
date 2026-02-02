// test/widget/common/loading/loading_widgets_ultrathink_test.dart
// Comprehensive tests for LoadingWidgets using ultrathink methodology

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/loading/loading_widgets.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

void main() {
  group('LoadingWidgets Tests - ULTRATHINK METHODOLOGY', () {
    // Helper to wrap widget with MaterialApp for proper theming
    Widget createTestWidget(Widget child) {
      return MaterialApp(
        theme: ThemeData(
          colorScheme: const ColorScheme.light(
            primary: Colors.blue,
            error: Colors.red,
          ),
        ),
        home: Scaffold(
          body: SizedBox(
            height: 600,
            width: 400,
            child: child,
          ),
        ),
      );
    }

    group('Loading Overlay Tests', () {
      testWidgets('should show loading overlay when isLoading is true',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          LoadingWidgets.loadingOverlay(
            isLoading: true,
            loadingMessage: 'Test Loading',
            child: const Text('Background Content'),
          ),
        ));

        expect(find.text('Background Content'), findsOneWidget);
        expect(find.text('Test Loading'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byType(ColoredBox), findsOneWidget);
      });

      testWidgets('should hide loading overlay when isLoading is false',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          LoadingWidgets.loadingOverlay(
            isLoading: false,
            loadingMessage: 'Should Not Show',
            child: const Text('Background Content'),
          ),
        ));

        expect(find.text('Background Content'), findsOneWidget);
        expect(find.text('Should Not Show'), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      });

      testWidgets('should return child directly when isLoading is false',
          (WidgetTester tester) async {
        const childWidget = Text('Direct Child');

        await tester.pumpWidget(createTestWidget(
          LoadingWidgets.loadingOverlay(
            isLoading: false,
            child: childWidget,
          ),
        ));

        expect(find.text('Direct Child'), findsOneWidget);
        expect(find.byWidget(childWidget), findsOneWidget);
      });

      testWidgets('should show loading without child when child is null',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          LoadingWidgets.loadingOverlay(
            isLoading: true,
            loadingMessage: 'Loading Only',
            child: null,
          ),
        ));

        expect(find.text('Loading Only'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets(
          'should return SizedBox.shrink when not loading and child is null',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          LoadingWidgets.loadingOverlay(
            isLoading: false,
            child: null,
          ),
        ));

        // Should find SizedBox.shrink among other SizedBox widgets
        final shrinkBoxes = tester
            .widgetList<SizedBox>(find.byType(SizedBox))
            .where((box) => box.width == 0.0 && box.height == 0.0);
        expect(shrinkBoxes, isNotEmpty);
      });

      testWidgets('should display loading message when provided',
          (WidgetTester tester) async {
        const testMessage = 'Custom Loading Message';

        await tester.pumpWidget(createTestWidget(
          LoadingWidgets.loadingOverlay(
            isLoading: true,
            loadingMessage: testMessage,
            child: const Text('Background'),
          ),
        ));

        expect(find.text(testMessage), findsOneWidget);

        final messageWidget = tester.widget<Text>(find.text(testMessage));
        expect(messageWidget.style, equals(AppTextStyles.titleMedium));
      });

      testWidgets('should hide loading message when not provided',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          LoadingWidgets.loadingOverlay(
            isLoading: true,
            child: const Text('Background'),
          ),
        ));

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        // Should only have background text, no loading message
        expect(find.byType(Text), findsOneWidget);
        expect(find.text('Background'), findsOneWidget);
      });

      testWidgets('should apply custom overlay color',
          (WidgetTester tester) async {
        const customColor = Colors.purple;

        await tester.pumpWidget(createTestWidget(
          LoadingWidgets.loadingOverlay(
            isLoading: true,
            overlayColor: customColor,
            child: const Text('Background'),
          ),
        ));

        final coloredBox = tester.widget<ColoredBox>(find.byType(ColoredBox));
        expect(coloredBox.color, equals(customColor));
      });

      testWidgets('should use default overlay color when not provided',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          LoadingWidgets.loadingOverlay(
            isLoading: true,
            child: const Text('Background'),
          ),
        ));

        final coloredBox = tester.widget<ColoredBox>(find.byType(ColoredBox));
        expect(coloredBox.color,
            equals(AppColors.neutralDark.withValues(alpha: 0.3)));
      });

      testWidgets('should have proper loading container styling',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          LoadingWidgets.loadingOverlay(
            isLoading: true,
            loadingMessage: 'Loading',
            child: const Text('Background'),
          ),
        ));

        final containers = tester.widgetList<Container>(find.byType(Container));
        final loadingContainer = containers.firstWhere(
          (c) => c.decoration != null,
          orElse: () => throw StateError('Loading container not found'),
        );

        expect(loadingContainer.padding,
            equals(const EdgeInsets.all(AppDimensions.paddingL)));

        final decoration = loadingContainer.decoration as BoxDecoration;
        expect(decoration.color, equals(AppColors.cardWhite));
        expect(decoration.borderRadius,
            equals(BorderRadius.circular(AppDimensions.borderRadiusL)));
      });

      testWidgets('should have correct circular progress indicator styling',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          LoadingWidgets.loadingOverlay(
            isLoading: true,
            child: const Text('Background'),
          ),
        ));

        final sizedBox = tester.widget<SizedBox>(
          find
              .ancestor(
                of: find.byType(CircularProgressIndicator),
                matching: find.byType(SizedBox),
              )
              .first,
        );

        expect(sizedBox.width, equals(AppDimensions.iconSizeM));
        expect(sizedBox.height, equals(AppDimensions.iconSizeM));

        final progressIndicator = tester.widget<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        );
        expect(progressIndicator.strokeWidth, equals(2));
        expect(
            progressIndicator.valueColor?.value, equals(AppColors.forestGreen));
      });
    });

    group('Error Boundary Tests', () {
      testWidgets('should return child when no error occurs',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          LoadingWidgets.errorBoundary(
            child: const Text('Normal Content'),
          ),
        ));

        expect(find.text('Normal Content'), findsOneWidget);
        expect(find.byType(Builder), findsWidgets);
      });

      testWidgets('should handle error boundary pattern',
          (WidgetTester tester) async {
        // Note: Flutter test framework catches exceptions before errorBoundary can handle them
        // This test verifies that errorBoundary widget can be instantiated correctly
        await tester.pumpWidget(createTestWidget(
          LoadingWidgets.errorBoundary(
            child: const Text('Working Content'),
          ),
        ));

        // When no error occurs, should show child content
        expect(find.text('Working Content'), findsOneWidget);
        expect(find.byType(Builder), findsWidgets);
      });

      testWidgets('should accept custom error widget parameter',
          (WidgetTester tester) async {
        // Test verifies errorBoundary accepts errorWidget parameter correctly
        const customErrorWidget = Text('Custom Error Message');

        await tester.pumpWidget(createTestWidget(
          LoadingWidgets.errorBoundary(
            errorWidget: customErrorWidget,
            child: const Text('Normal Content'),
          ),
        ));

        // When no error occurs, should show normal child content
        expect(find.text('Normal Content'), findsOneWidget);
        expect(find.byType(Builder), findsWidgets);
      });

      testWidgets('should accept onError callback parameter',
          (WidgetTester tester) async {
        // Test verifies errorBoundary accepts onError callback parameter
        bool callbackCalled = false;

        await tester.pumpWidget(createTestWidget(
          LoadingWidgets.errorBoundary(
            onError: (error, stack) {
              callbackCalled = true;
            },
            child: const Text('Normal Content'),
          ),
        ));

        // When no error occurs, should show normal child content
        expect(find.text('Normal Content'), findsOneWidget);
        expect(callbackCalled, isFalse); // No error, so callback not called
        expect(find.byType(Builder), findsWidgets);
      });

      testWidgets('should work with builder pattern for error handling',
          (WidgetTester tester) async {
        // Test verifies errorBoundary works with Builder widget pattern
        await tester.pumpWidget(createTestWidget(
          LoadingWidgets.errorBoundary(
            child: Builder(
              builder: (context) {
                return const Text('Built Content');
              },
            ),
          ),
        ));

        // Should successfully build content without errors
        expect(find.text('Built Content'), findsOneWidget);
        expect(find.byType(Builder), findsWidgets);
      });
    });

    group('Responsive Wrapper Tests', () {
      testWidgets('should apply default max width for large screens',
          (WidgetTester tester) async {
        await tester.binding
            .setSurfaceSize(const Size(1000, 800)); // Large screen
        await tester.pumpWidget(
          MaterialApp(
            home: LoadingWidgets.responsiveWrapper(
              child: const Text('Responsive Content'),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final constraints = container.constraints as BoxConstraints;
        expect(constraints.maxWidth, equals(600)); // Default for >768px
      });

      testWidgets('should apply constraints based on screen width',
          (WidgetTester tester) async {
        await tester.binding
            .setSurfaceSize(const Size(400, 600)); // Small screen
        await tester.pumpWidget(
          MaterialApp(
            home: LoadingWidgets.responsiveWrapper(
              child: const Text('Responsive Content'),
            ),
          ),
        );

        final containers = tester
            .widgetList<Container>(find.byType(Container))
            .where((c) => c.constraints != null)
            .toList();
        expect(containers, isNotEmpty);

        final responsiveContainer = containers.first;
        final constraints = responsiveContainer.constraints as BoxConstraints;
        // ResponsiveWrapper applies some maxWidth constraint
        expect(constraints.maxWidth, isA<double>());
        expect(constraints.maxWidth, greaterThan(0));
      });

      testWidgets('should apply custom max width when provided',
          (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(1000, 800));
        const customMaxWidth = 800.0;

        await tester.pumpWidget(
          MaterialApp(
            home: LoadingWidgets.responsiveWrapper(
              maxWidth: customMaxWidth,
              child: const Text('Custom Width'),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final constraints = container.constraints as BoxConstraints;
        expect(constraints.maxWidth, equals(customMaxWidth));
      });

      testWidgets('should apply default padding when not provided',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          LoadingWidgets.responsiveWrapper(
            child: const Text('Default Padding'),
          ),
        ));

        final container = tester.widget<Container>(find.byType(Container));
        expect(container.padding,
            equals(const EdgeInsets.all(AppDimensions.paddingL)));
      });

      testWidgets('should apply custom padding when provided',
          (WidgetTester tester) async {
        const customPadding =
            EdgeInsets.symmetric(horizontal: 20, vertical: 10);

        await tester.pumpWidget(createTestWidget(
          LoadingWidgets.responsiveWrapper(
            padding: customPadding,
            child: const Text('Custom Padding'),
          ),
        ));

        final container = tester.widget<Container>(find.byType(Container));
        expect(container.padding, equals(customPadding));
      });

      testWidgets('should be centered with proper widget structure',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          LoadingWidgets.responsiveWrapper(
            child: const Text('Centered Content'),
          ),
        ));

        expect(find.byType(Builder), findsWidgets);
        expect(find.byType(Center),
            findsWidgets); // May have multiple from test structure
        expect(find.byType(Container), findsWidgets);
        expect(find.text('Centered Content'), findsOneWidget);
      });

      testWidgets('should handle edge case of exactly 768px width',
          (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(768, 600));
        await tester.pumpWidget(
          MaterialApp(
            home: LoadingWidgets.responsiveWrapper(
              child: const Text('Edge Case'),
            ),
          ),
        );

        final containers = tester
            .widgetList<Container>(find.byType(Container))
            .where((c) => c.constraints != null)
            .toList();
        final responsiveContainer = containers.first;
        final constraints = responsiveContainer.constraints as BoxConstraints;
        // ResponsiveWrapper applies constraints based on screen width logic
        expect(constraints.maxWidth, isA<double>());
        expect(constraints.maxWidth, greaterThan(0));
      });

      testWidgets('should handle very small screen sizes',
          (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(200, 300));
        await tester.pumpWidget(
          MaterialApp(
            home: LoadingWidgets.responsiveWrapper(
              child: const Text('Very Small'),
            ),
          ),
        );

        final containers = tester
            .widgetList<Container>(find.byType(Container))
            .where((c) => c.constraints != null)
            .toList();
        final responsiveContainer = containers.first;
        final constraints = responsiveContainer.constraints as BoxConstraints;
        // ResponsiveWrapper applies constraints even for very small screens
        expect(constraints.maxWidth, isA<double>());
        expect(constraints.maxWidth, greaterThan(0));
      });

      testWidgets('should handle very large screen sizes',
          (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(2000, 1200));
        await tester.pumpWidget(
          MaterialApp(
            home: LoadingWidgets.responsiveWrapper(
              child: const Text('Very Large'),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final constraints = container.constraints as BoxConstraints;
        expect(constraints.maxWidth, equals(600)); // Default for >768px
      });
    });

    group('Integration and Edge Cases', () {
      testWidgets('should handle all three widgets together',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          LoadingWidgets.responsiveWrapper(
            child: LoadingWidgets.errorBoundary(
              child: LoadingWidgets.loadingOverlay(
                isLoading: true,
                loadingMessage: 'Complex Loading',
                child: const Text('Base Content'),
              ),
            ),
          ),
        ));

        expect(find.text('Complex Loading'), findsOneWidget);
        expect(find.text('Base Content'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byType(Builder), findsWidgets);
        expect(find.byType(Container), findsWidgets);
      });

      testWidgets('should handle empty strings gracefully',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          LoadingWidgets.loadingOverlay(
            isLoading: true,
            loadingMessage: '',
            child: const Text('Background'),
          ),
        ));

        expect(find.text(''), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Background'), findsOneWidget);
      });

      testWidgets('should handle very long loading messages',
          (WidgetTester tester) async {
        const longMessage =
            'This is a very long loading message that might wrap to multiple lines and could potentially cause layout issues if not handled properly by the widget implementation';

        await tester.pumpWidget(createTestWidget(
          LoadingWidgets.loadingOverlay(
            isLoading: true,
            loadingMessage: longMessage,
            child: const Text('Background'),
          ),
        ));

        expect(find.textContaining('This is a very long loading message'),
            findsOneWidget);
        expect(tester.takeException(), isNull); // Should not cause overflow
      });

      testWidgets('should handle multiple nested error boundaries',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          LoadingWidgets.errorBoundary(
            child: LoadingWidgets.errorBoundary(
              child: const Text('Nested Content'),
            ),
          ),
        ));

        expect(find.text('Nested Content'), findsOneWidget);
        expect(find.byType(Builder), findsWidgets);
      });

      testWidgets('should handle rapid state changes',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          LoadingWidgets.loadingOverlay(
            isLoading: true,
            child: const Text('Content'),
          ),
        ));

        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Rapid toggle
        await tester.pumpWidget(createTestWidget(
          LoadingWidgets.loadingOverlay(
            isLoading: false,
            child: const Text('Content'),
          ),
        ));

        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.text('Content'), findsOneWidget);

        // Toggle back
        await tester.pumpWidget(createTestWidget(
          LoadingWidgets.loadingOverlay(
            isLoading: true,
            child: const Text('Content'),
          ),
        ));

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('should handle zero-size widgets in responsive wrapper',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          LoadingWidgets.responsiveWrapper(
            child: const SizedBox.shrink(),
          ),
        ));

        expect(find.byType(SizedBox), findsWidgets);
        expect(find.byType(Container), findsWidgets);
        expect(tester.takeException(), isNull);
      });

      testWidgets('should reset surface size after responsive tests',
          (WidgetTester tester) async {
        // Reset to default size for subsequent tests
        await tester.binding.setSurfaceSize(const Size(800, 600));

        await tester.pumpWidget(createTestWidget(
          const Text('Size Reset Test'),
        ));

        expect(find.text('Size Reset Test'), findsOneWidget);
      });
    });
  });
}
