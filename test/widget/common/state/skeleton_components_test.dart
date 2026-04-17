// test/widget/common/state/skeleton_components_test.dart
// Comprehensive tests for SkeletonComponents using ultrathink methodology

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/state/skeleton_components.dart';
import 'package:butlery/theme/app_dimensions.dart';

void main() {
  group('SkeletonComponents Widget Tests', () {
    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    group('Default Skeleton Box', () {
      testWidgets('should render skeleton box with default properties',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SkeletonComponents.skeletonBox(),
            ),
          ),
        );

        expect(find.byType(Container), findsOneWidget);
      });

      testWidgets('should have default border radius',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SkeletonComponents.skeletonBox(),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        expect(
          decoration.borderRadius,
          equals(BorderRadius.circular(AppDimensions.borderRadiusS)),
        );
      });

      testWidgets('should have shimmer gradient', (WidgetTester tester) async {
        late ColorScheme cs;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(builder: (context) {
                cs = Theme.of(context).colorScheme;
                return SkeletonComponents.skeletonBox();
              }),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.gradient, isA<LinearGradient>());

        final gradient = decoration.gradient as LinearGradient;
        expect(
          gradient.colors,
          equals([
            cs.onSurfaceVariant,
            cs.surfaceContainerHighest,
            cs.onSurfaceVariant,
          ]),
        );
      });

      testWidgets('should have animation controller',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SkeletonComponents.skeletonBox(),
            ),
          ),
        );

        // Pump frames to trigger animation
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 750));

        // Animation should be running
        expect(find.byType(Container), findsOneWidget);
      });
    });

    group('Custom Dimensions', () {
      testWidgets('should apply custom width', (WidgetTester tester) async {
        const customWidth = 200.0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SkeletonComponents.skeletonBox(
                width: customWidth,
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        expect(container.constraints?.maxWidth, equals(customWidth));
      });

      testWidgets('should apply custom height', (WidgetTester tester) async {
        const customHeight = 100.0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SkeletonComponents.skeletonBox(
                height: customHeight,
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        expect(container.constraints?.maxHeight, equals(customHeight));
      });

      testWidgets('should apply both custom width and height',
          (WidgetTester tester) async {
        const customWidth = 150.0;
        const customHeight = 75.0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SkeletonComponents.skeletonBox(
                width: customWidth,
                height: customHeight,
              ),
            ),
          ),
        );

        final renderBox = tester.renderObject<RenderBox>(
          find.byType(Container),
        );
        expect(renderBox.size.width, equals(customWidth));
        expect(renderBox.size.height, equals(customHeight));
      });
    });

    group('Custom Border Radius', () {
      testWidgets('should apply custom border radius',
          (WidgetTester tester) async {
        final customRadius = BorderRadius.circular(16.0);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SkeletonComponents.skeletonBox(
                borderRadius: customRadius,
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.borderRadius, equals(customRadius));
      });

      testWidgets('should apply asymmetric border radius',
          (WidgetTester tester) async {
        const customRadius = BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
          bottomLeft: Radius.circular(0),
          bottomRight: Radius.circular(0),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SkeletonComponents.skeletonBox(
                borderRadius: customRadius,
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.borderRadius, equals(customRadius));
      });
    });

    group('Custom Margin', () {
      testWidgets('should apply custom margin', (WidgetTester tester) async {
        const customMargin = EdgeInsets.all(16.0);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SkeletonComponents.skeletonBox(
                margin: customMargin,
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        expect(container.margin, equals(customMargin));
      });

      testWidgets('should apply asymmetric margin',
          (WidgetTester tester) async {
        const customMargin = EdgeInsets.only(
          left: 8,
          right: 16,
          top: 4,
          bottom: 12,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SkeletonComponents.skeletonBox(
                margin: customMargin,
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        expect(container.margin, equals(customMargin));
      });
    });

    group('Animation', () {
      testWidgets('should animate shimmer effect', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SkeletonComponents.skeletonBox(
                width: 200,
                height: 50,
              ),
            ),
          ),
        );

        // Initial state
        expect(find.byType(Container), findsOneWidget);

        // Animate forward
        await tester.pump(const Duration(milliseconds: 375));
        expect(find.byType(Container), findsOneWidget);

        // Animate more
        await tester.pump(const Duration(milliseconds: 375));
        expect(find.byType(Container), findsOneWidget);

        // Complete cycle
        await tester.pump(const Duration(milliseconds: 750));
        expect(find.byType(Container), findsOneWidget);
      });

      testWidgets('should repeat animation', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SkeletonComponents.skeletonBox(),
            ),
          ),
        );

        // First cycle
        await tester.pump(const Duration(milliseconds: 1500));
        expect(find.byType(Container), findsOneWidget);

        // Second cycle
        await tester.pump(const Duration(milliseconds: 1500));
        expect(find.byType(Container), findsOneWidget);

        // Third cycle
        await tester.pump(const Duration(milliseconds: 1500));
        expect(find.byType(Container), findsOneWidget);
      });
    });

    group('Layout Integration', () {
      testWidgets('should work in Row layout', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Row(
                children: [
                  SkeletonComponents.skeletonBox(width: 50, height: 50),
                  const SizedBox(width: 8),
                  SkeletonComponents.skeletonBox(width: 100, height: 50),
                  const SizedBox(width: 8),
                  SkeletonComponents.skeletonBox(width: 50, height: 50),
                ],
              ),
            ),
          ),
        );

        expect(find.byType(Container), findsNWidgets(3));
      });

      testWidgets('should work in Column layout', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  SkeletonComponents.skeletonBox(width: 200, height: 20),
                  const SizedBox(height: 8),
                  SkeletonComponents.skeletonBox(width: 150, height: 20),
                  const SizedBox(height: 8),
                  SkeletonComponents.skeletonBox(width: 100, height: 20),
                ],
              ),
            ),
          ),
        );

        expect(find.byType(Container), findsNWidgets(3));
      });

      testWidgets('should work in ListView', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ListView(
                children: List.generate(
                  5,
                  (index) => SkeletonComponents.skeletonBox(
                    width: double.infinity,
                    height: 60,
                    margin: const EdgeInsets.all(8),
                  ),
                ),
              ),
            ),
          ),
        );

        expect(find.byType(Container), findsNWidgets(5));
      });
    });

    group('Use Cases', () {
      testWidgets('should work as text placeholder',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonComponents.skeletonBox(width: 200, height: 20),
                  const SizedBox(height: 8),
                  SkeletonComponents.skeletonBox(width: 150, height: 20),
                  const SizedBox(height: 8),
                  SkeletonComponents.skeletonBox(width: 180, height: 20),
                ],
              ),
            ),
          ),
        );

        expect(find.byType(Container), findsNWidgets(3));
      });

      testWidgets('should work as image placeholder',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SkeletonComponents.skeletonBox(
                width: 100,
                height: 100,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        );

        final renderBox =
            tester.renderObject<RenderBox>(find.byType(Container));
        expect(renderBox.size.width, equals(100));
        expect(renderBox.size.height, equals(100));
      });

      testWidgets('should work as avatar placeholder',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SkeletonComponents.skeletonBox(
                width: 48,
                height: 48,
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.borderRadius, equals(BorderRadius.circular(24)));
      });

      testWidgets('should work as card placeholder',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      SkeletonComponents.skeletonBox(width: 60, height: 60),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonComponents.skeletonBox(height: 20),
                            const SizedBox(height: 8),
                            SkeletonComponents.skeletonBox(height: 16),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

        expect(find.byType(Container), findsNWidgets(3));
      });
    });

    group('Edge Cases', () {
      testWidgets('should handle zero dimensions', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SkeletonComponents.skeletonBox(
                width: 0,
                height: 0,
              ),
            ),
          ),
        );

        final renderBox = tester.renderObject<RenderBox>(
          find.byType(Container),
        );
        expect(renderBox.size.width, equals(0));
        expect(renderBox.size.height, equals(0));
      });

      testWidgets('should handle very large dimensions',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SkeletonComponents.skeletonBox(
                width: 1000,
                height: 500,
              ),
            ),
          ),
        );

        expect(find.byType(Container), findsOneWidget);
      });

      testWidgets('should handle null dimensions', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SkeletonComponents.skeletonBox(),
            ),
          ),
        );

        expect(find.byType(Container), findsOneWidget);
      });

      testWidgets('should dispose animation controller properly',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SkeletonComponents.skeletonBox(),
            ),
          ),
        );

        expect(find.byType(Container), findsOneWidget);

        // Change to different widget to trigger disposal
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Text('Replaced'),
            ),
          ),
        );

        expect(find.text('Replaced'), findsOneWidget);
        expect(find.byType(Container), findsNothing);
      });
    });

    tearDownAll(() {
      // Clean up after all tests
    });
  });
}
