// test/widget/common/indicators/notification_badge_ultrathink_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/indicators/notification_badge.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

void main() {
  group('NotificationBadge Widget Tests - ULTRATHINK METHODOLOGY', () {
    // Helper to create test environment with theme support
    Widget createTestWidget(Widget child) {
      return MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue).copyWith(
            surface: Colors.white,
          ),
        ),
        home: Scaffold(
          body: child,
        ),
      );
    }

    group('Construction Tests', () {
      testWidgets('creates widget with required count parameter',
          (tester) async {
        const testCount = 5;

        await tester.pumpWidget(
          createTestWidget(
            const NotificationBadge(count: testCount),
          ),
        );

        expect(find.byType(NotificationBadge), findsOneWidget);
        expect(find.text('$testCount'), findsOneWidget);
      });

      testWidgets('creates widget with all parameters', (tester) async {
        const testCount = 10;
        const testBackgroundColor = Colors.red;
        const testTextColor = Colors.white;
        const testBorderColor = Colors.black;

        await tester.pumpWidget(
          createTestWidget(
            const NotificationBadge(
              count: testCount,
              backgroundColor: testBackgroundColor,
              textColor: testTextColor,
              borderColor: testBorderColor,
            ),
          ),
        );

        expect(find.byType(NotificationBadge), findsOneWidget);
        expect(find.text('$testCount'), findsOneWidget);
      });

      testWidgets('accepts zero count', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            const NotificationBadge(count: 0),
          ),
        );

        expect(find.byType(NotificationBadge), findsOneWidget);
        expect(find.text('0'), findsOneWidget);
      });

      testWidgets('accepts large count values', (tester) async {
        const largeCounts = [100, 500, 999, 1000, 9999];

        for (final count in largeCounts) {
          await tester.pumpWidget(
            createTestWidget(
              NotificationBadge(count: count),
            ),
          );

          expect(find.byType(NotificationBadge), findsOneWidget);
        }
      });
    });

    group('Count Display Logic Tests', () {
      testWidgets('displays actual count when count <= 99', (tester) async {
        const testCounts = [1, 5, 25, 50, 99];

        for (final count in testCounts) {
          await tester.pumpWidget(
            createTestWidget(
              NotificationBadge(count: count),
            ),
          );

          expect(find.text('$count'), findsOneWidget);
        }
      });

      testWidgets('displays "99+" when count > 99', (tester) async {
        const largeCounts = [100, 101, 150, 200, 999, 1000];

        for (final count in largeCounts) {
          await tester.pumpWidget(
            createTestWidget(
              NotificationBadge(count: count),
            ),
          );

          expect(find.text('99+'), findsOneWidget);
        }
      });

      testWidgets('boundary testing at count = 99', (tester) async {
        // Test exactly 99
        await tester.pumpWidget(
          createTestWidget(
            const NotificationBadge(count: 99),
          ),
        );
        expect(find.text('99'), findsOneWidget);

        // Test exactly 100
        await tester.pumpWidget(
          createTestWidget(
            const NotificationBadge(count: 100),
          ),
        );
        expect(find.text('99+'), findsOneWidget);
      });

      testWidgets('handles negative counts', (tester) async {
        const negativeCounts = [-1, -5, -100];

        for (final count in negativeCounts) {
          await tester.pumpWidget(
            createTestWidget(
              NotificationBadge(count: count),
            ),
          );

          // Negative counts should display as-is (production behavior)
          expect(find.text('$count'), findsOneWidget);
        }
      });
    });

    group('Container Styling Tests', () {
      testWidgets('applies correct container decoration with defaults',
          (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            const NotificationBadge(count: 5),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;

        expect(decoration.color, AppColors.error);
        expect(decoration.shape, BoxShape.circle);
        expect(
            container.padding, const EdgeInsets.all(AppDimensions.spacingXs));
      });

      testWidgets('applies custom background color', (tester) async {
        const customColor = Colors.blue;

        await tester.pumpWidget(
          createTestWidget(
            const NotificationBadge(
              count: 5,
              backgroundColor: customColor,
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;

        expect(decoration.color, customColor);
      });

      testWidgets('applies correct border styling with defaults',
          (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            const NotificationBadge(count: 5),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        final border = decoration.border as Border;

        expect(border.top.width, AppDimensions.borderWidthThick);
        expect(border.top.color, Colors.white); // Theme surface color
      });

      testWidgets('applies custom border color', (tester) async {
        const customBorderColor = Colors.green;

        await tester.pumpWidget(
          createTestWidget(
            const NotificationBadge(
              count: 5,
              borderColor: customBorderColor,
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        final border = decoration.border as Border;

        expect(border.top.color, customBorderColor);
      });

      testWidgets('applies box constraints correctly', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            const NotificationBadge(count: 5),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));

        expect(container.constraints,
            const BoxConstraints(minWidth: 20, minHeight: 20));
      });
    });

    group('Text Styling Tests', () {
      testWidgets('applies correct text style with defaults', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            const NotificationBadge(count: 5),
          ),
        );

        final text = tester.widget<Text>(find.text('5'));

        expect(text.textAlign, TextAlign.center);
        expect(text.style?.color, AppColors.neutralLight);
        expect(text.style?.fontWeight, FontWeight.bold);
        expect(text.style?.fontSize, AppTextStyles.labelSmall.fontSize);
      });

      testWidgets('applies custom text color', (tester) async {
        const customTextColor = Colors.yellow;

        await tester.pumpWidget(
          createTestWidget(
            const NotificationBadge(
              count: 5,
              textColor: customTextColor,
            ),
          ),
        );

        final text = tester.widget<Text>(find.text('5'));

        expect(text.style?.color, customTextColor);
      });

      testWidgets('maintains font weight and alignment with custom colors',
          (tester) async {
        const customTextColor = Colors.purple;

        await tester.pumpWidget(
          createTestWidget(
            const NotificationBadge(
              count: 5,
              textColor: customTextColor,
            ),
          ),
        );

        final text = tester.widget<Text>(find.text('5'));

        expect(text.textAlign, TextAlign.center);
        expect(text.style?.fontWeight, FontWeight.bold);
        expect(text.style?.fontSize, AppTextStyles.labelSmall.fontSize);
        expect(text.style?.color, customTextColor);
      });

      testWidgets('applies correct styling to "99+" text', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            const NotificationBadge(count: 150),
          ),
        );

        final text = tester.widget<Text>(find.text('99+'));

        expect(text.textAlign, TextAlign.center);
        expect(text.style?.color, AppColors.neutralLight);
        expect(text.style?.fontWeight, FontWeight.bold);
        expect(text.style?.fontSize, AppTextStyles.labelSmall.fontSize);
      });
    });

    group('Theme Integration Tests', () {
      testWidgets('uses AppDimensions constants correctly', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            const NotificationBadge(count: 5),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        final border = decoration.border as Border;

        // Check padding uses AppDimensions.spacingXs
        expect(
            container.padding, const EdgeInsets.all(AppDimensions.spacingXs));

        // Check border uses AppDimensions.borderWidthThick
        expect(border.top.width, AppDimensions.borderWidthThick);

        // Check minimum constraints
        expect(container.constraints,
            const BoxConstraints(minWidth: 20, minHeight: 20));
      });

      testWidgets('uses AppColors constants correctly', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            const NotificationBadge(count: 5),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        final text = tester.widget<Text>(find.text('5'));

        // Check default background color
        expect(decoration.color, AppColors.error);

        // Check default text color
        expect(text.style?.color, AppColors.neutralLight);
      });

      testWidgets('uses AppTextStyles constants correctly', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            const NotificationBadge(count: 5),
          ),
        );

        final text = tester.widget<Text>(find.text('5'));

        expect(text.style?.fontSize, AppTextStyles.labelSmall.fontSize);
      });

      testWidgets('integrates with theme colorScheme correctly',
          (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            const NotificationBadge(count: 5),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        final border = decoration.border as Border;

        // Border should use theme surface color (white from our test theme)
        expect(border.top.color, Colors.white);
      });
    });

    group('Widget Structure Tests', () {
      testWidgets('has correct widget hierarchy', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            const NotificationBadge(count: 5),
          ),
        );

        // Should have Container as root
        expect(find.byType(Container), findsOneWidget);

        // Should have Text as child
        expect(find.byType(Text), findsOneWidget);

        // Should have the correct parent-child relationship
        final container = find.byType(Container);
        final text = find.byType(Text);

        expect(find.descendant(of: container, matching: text), findsOneWidget);
      });

      testWidgets('maintains structure with different parameters',
          (tester) async {
        const variations = [
          NotificationBadge(count: 0),
          NotificationBadge(count: 50, backgroundColor: Colors.blue),
          NotificationBadge(count: 100, textColor: Colors.red),
          NotificationBadge(
              count: 999,
              backgroundColor: Colors.green,
              textColor: Colors.white,
              borderColor: Colors.black),
        ];

        for (final variation in variations) {
          await tester.pumpWidget(createTestWidget(variation));

          // Each variation should have same structure
          expect(find.byType(Container), findsOneWidget);
          expect(find.byType(Text), findsOneWidget);
        }
      });
    });

    group('Edge Cases and Integration Tests', () {
      testWidgets('handles extreme color values', (tester) async {
        const extremeColors = [
          Colors.transparent,
          Colors.black,
          Colors.white,
          Color(0x00000000), // Fully transparent
          Color(0xFFFFFFFF), // Fully opaque white
        ];

        for (final color in extremeColors) {
          await tester.pumpWidget(
            createTestWidget(
              NotificationBadge(
                count: 5,
                backgroundColor: color,
                textColor: color,
                borderColor: color,
              ),
            ),
          );

          expect(find.byType(NotificationBadge), findsOneWidget);
        }
      });

      testWidgets('works with various count edge cases', (tester) async {
        const edgeCounts = [
          0,
          1,
          99,
          100,
          999,
          1000,
          -1,
          -100,
        ];

        for (final count in edgeCounts) {
          await tester.pumpWidget(
            createTestWidget(
              NotificationBadge(count: count),
            ),
          );

          expect(find.byType(NotificationBadge), findsOneWidget);
          expect(find.byType(Text), findsOneWidget);
        }
      });

      testWidgets('renders correctly in different layout contexts',
          (tester) async {
        // Test in Row
        await tester.pumpWidget(
          createTestWidget(
            const Row(
              children: [
                NotificationBadge(count: 5),
                SizedBox(width: 10),
                NotificationBadge(count: 100),
              ],
            ),
          ),
        );

        expect(find.byType(NotificationBadge), findsNWidgets(2));

        // Test in Column
        await tester.pumpWidget(
          createTestWidget(
            const Column(
              children: [
                NotificationBadge(count: 3),
                SizedBox(height: 10),
                NotificationBadge(count: 200),
              ],
            ),
          ),
        );

        expect(find.byType(NotificationBadge), findsNWidgets(2));
      });

      testWidgets('maintains minimum size constraints', (tester) async {
        // Test with single digit count
        await tester.pumpWidget(
          createTestWidget(
            const NotificationBadge(count: 1),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        expect(container.constraints?.minWidth, 20);
        expect(container.constraints?.minHeight, 20);

        // Test with zero count
        await tester.pumpWidget(
          createTestWidget(
            const NotificationBadge(count: 0),
          ),
        );

        final container2 = tester.widget<Container>(find.byType(Container));
        expect(container2.constraints?.minWidth, 20);
        expect(container2.constraints?.minHeight, 20);
      });
    });
  });
}
