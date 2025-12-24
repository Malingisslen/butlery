// test/widget/common/indicators/member_count_badge_test.dart
// Comprehensive tests for MemberCountBadge using ultrathink methodology

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/indicators/member_count_badge.dart';
import 'package:butlery/theme/app_colors.dart';

void main() {
  group('MemberCountBadge Widget Tests', () {
    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    group('Rendering', () {
      testWidgets('should render with required count',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MemberCountBadge(additionalCount: 5),
            ),
          ),
        );

        expect(find.byType(MemberCountBadge), findsOneWidget);
        expect(find.text('+5'), findsOneWidget);
      });

      testWidgets('should display plus sign before count',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MemberCountBadge(additionalCount: 10),
            ),
          ),
        );

        expect(find.text('+10'), findsOneWidget);
      });

      testWidgets('should render different count values',
          (WidgetTester tester) async {
        final counts = [1, 5, 10, 99, 100, 999];

        for (final count in counts) {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: MemberCountBadge(additionalCount: count),
              ),
            ),
          );

          expect(find.text('+$count'), findsOneWidget);
        }
      });
    });

    group('Styling', () {
      testWidgets('should use default size when not specified',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MemberCountBadge(additionalCount: 3),
            ),
          ),
        );

        final renderBox = tester.renderObject<RenderBox>(
          find.byType(MemberCountBadge),
        );
        expect(renderBox.size.width, equals(32.0));
        expect(renderBox.size.height, equals(32.0));
      });

      testWidgets('should apply custom size', (WidgetTester tester) async {
        const customSize = 48.0;

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MemberCountBadge(
                additionalCount: 3,
                size: customSize,
              ),
            ),
          ),
        );

        final renderBox = tester.renderObject<RenderBox>(
          find.byType(MemberCountBadge),
        );
        expect(renderBox.size.width, equals(customSize));
        expect(renderBox.size.height, equals(customSize));
      });

      testWidgets('should have circular shape', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MemberCountBadge(additionalCount: 3),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.shape, equals(BoxShape.circle));
      });

      testWidgets('should use theme surface container color',
          (WidgetTester tester) async {
        const testColor = Color(0xFF123456);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              colorScheme: const ColorScheme.light(
                surfaceContainerHighest: testColor,
              ),
            ),
            home: const Scaffold(
              body: MemberCountBadge(additionalCount: 3),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, equals(testColor));
      });

      testWidgets('should have divider color border',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MemberCountBadge(additionalCount: 3),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        final border = decoration.border as Border;
        expect(border.top.color, equals(AppColors.divider));
        expect(border.top.width, equals(1));
      });

      testWidgets('should center text content', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MemberCountBadge(additionalCount: 3),
            ),
          ),
        );

        expect(find.byType(Center), findsOneWidget);
      });

      testWidgets('should use bodySmall text style with fontWeight 600',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MemberCountBadge(additionalCount: 3),
            ),
          ),
        );

        final text = tester.widget<Text>(find.text('+3'));
        expect(text.style?.fontWeight, equals(FontWeight.w600));
      });
    });

    group('Count Display', () {
      testWidgets('should display single digit counts',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MemberCountBadge(additionalCount: 7),
            ),
          ),
        );

        expect(find.text('+7'), findsOneWidget);
      });

      testWidgets('should display double digit counts',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MemberCountBadge(additionalCount: 42),
            ),
          ),
        );

        expect(find.text('+42'), findsOneWidget);
      });

      testWidgets('should display triple digit counts',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MemberCountBadge(additionalCount: 123),
            ),
          ),
        );

        expect(find.text('+123'), findsOneWidget);
      });

      testWidgets('should handle zero count', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MemberCountBadge(additionalCount: 0),
            ),
          ),
        );

        expect(find.text('+0'), findsOneWidget);
      });

      testWidgets('should handle negative count', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MemberCountBadge(additionalCount: -5),
            ),
          ),
        );

        // The widget displays the count as-is with a plus sign
        expect(find.text('+-5'), findsOneWidget);
      });
    });

    group('Size Variations', () {
      testWidgets('should work with very small size',
          (WidgetTester tester) async {
        const smallSize = 20.0;

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MemberCountBadge(
                additionalCount: 3,
                size: smallSize,
              ),
            ),
          ),
        );

        final renderBox = tester.renderObject<RenderBox>(
          find.byType(MemberCountBadge),
        );
        expect(renderBox.size.width, equals(smallSize));
        expect(renderBox.size.height, equals(smallSize));
      });

      testWidgets('should work with large size', (WidgetTester tester) async {
        const largeSize = 64.0;

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MemberCountBadge(
                additionalCount: 3,
                size: largeSize,
              ),
            ),
          ),
        );

        final renderBox = tester.renderObject<RenderBox>(
          find.byType(MemberCountBadge),
        );
        expect(renderBox.size.width, equals(largeSize));
        expect(renderBox.size.height, equals(largeSize));
      });

      testWidgets('should maintain circular shape at different sizes',
          (WidgetTester tester) async {
        final sizes = [20.0, 32.0, 48.0, 64.0];

        for (final size in sizes) {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: MemberCountBadge(
                  additionalCount: 3,
                  size: size,
                ),
              ),
            ),
          );

          final renderBox = tester.renderObject<RenderBox>(
            find.byType(MemberCountBadge),
          );
          expect(renderBox.size.width, equals(renderBox.size.height));
          expect(renderBox.size.width, equals(size));
        }
      });
    });

    group('Layout Integration', () {
      testWidgets('should work in Row layout', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Row(
                children: [
                  CircleAvatar(child: Text('A')),
                  CircleAvatar(child: Text('B')),
                  CircleAvatar(child: Text('C')),
                  MemberCountBadge(additionalCount: 5),
                ],
              ),
            ),
          ),
        );

        expect(find.byType(MemberCountBadge), findsOneWidget);
        expect(find.byType(CircleAvatar), findsNWidgets(3));
        expect(find.text('+5'), findsOneWidget);
      });

      testWidgets('should work in Stack layout', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  Container(
                    width: 200,
                    height: 50,
                    color: Colors.grey[200],
                  ),
                  const Positioned(
                    right: 10,
                    top: 10,
                    child: MemberCountBadge(additionalCount: 10),
                  ),
                ],
              ),
            ),
          ),
        );

        expect(find.byType(MemberCountBadge), findsOneWidget);
        expect(find.text('+10'), findsOneWidget);
      });

      testWidgets('should work with avatar list', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    child: Text('U1'),
                  ),
                  SizedBox(width: 4),
                  CircleAvatar(
                    radius: 16,
                    child: Text('U2'),
                  ),
                  SizedBox(width: 4),
                  MemberCountBadge(
                    additionalCount: 3,
                    size: 32,
                  ),
                ],
              ),
            ),
          ),
        );

        expect(find.byType(CircleAvatar), findsNWidgets(2));
        expect(find.byType(MemberCountBadge), findsOneWidget);
        expect(find.text('+3'), findsOneWidget);
      });
    });

    group('Theme Variations', () {
      testWidgets('should work with light theme', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: const Scaffold(
              body: MemberCountBadge(additionalCount: 5),
            ),
          ),
        );

        expect(find.byType(MemberCountBadge), findsOneWidget);
        expect(find.text('+5'), findsOneWidget);
      });

      testWidgets('should work with dark theme', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: const Scaffold(
              body: MemberCountBadge(additionalCount: 5),
            ),
          ),
        );

        expect(find.byType(MemberCountBadge), findsOneWidget);
        expect(find.text('+5'), findsOneWidget);
      });

      testWidgets('should adapt to custom theme colors',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              colorScheme: const ColorScheme.light(
                surfaceContainerHighest: Colors.purple,
              ),
            ),
            home: const Scaffold(
              body: MemberCountBadge(additionalCount: 5),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, equals(Colors.purple));
      });
    });

    group('Use Cases', () {
      testWidgets('should display small additional count',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MemberCountBadge(additionalCount: 2),
            ),
          ),
        );

        expect(find.text('+2'), findsOneWidget);
      });

      testWidgets('should display large group overflow',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MemberCountBadge(additionalCount: 50),
            ),
          ),
        );

        expect(find.text('+50'), findsOneWidget);
      });

      testWidgets('should work as team member overflow indicator',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Row(
                children: [
                  Text('Team: '),
                  CircleAvatar(radius: 12, child: Text('A')),
                  CircleAvatar(radius: 12, child: Text('B')),
                  MemberCountBadge(additionalCount: 8, size: 24),
                ],
              ),
            ),
          ),
        );

        expect(find.text('+8'), findsOneWidget);
        expect(find.text('Team: '), findsOneWidget);
      });
    });

    group('Edge Cases', () {
      testWidgets('should handle very large counts',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MemberCountBadge(additionalCount: 9999),
            ),
          ),
        );

        expect(find.text('+9999'), findsOneWidget);
      });

      testWidgets('should handle count with custom theme text style',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              textTheme: const TextTheme(
                bodySmall: TextStyle(fontSize: 10),
              ),
            ),
            home: const Scaffold(
              body: MemberCountBadge(additionalCount: 5),
            ),
          ),
        );

        final text = tester.widget<Text>(find.text('+5'));
        // The widget uses AppTextStyles.bodySmall.copyWith, not theme's bodySmall directly
        expect(text.style?.fontWeight, equals(FontWeight.w600));
      });

      testWidgets('should maintain visibility with transparent background',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              colorScheme: const ColorScheme.light(
                surfaceContainerHighest: Colors.transparent,
              ),
            ),
            home: const Scaffold(
              backgroundColor: Colors.white,
              body: MemberCountBadge(additionalCount: 5),
            ),
          ),
        );

        expect(find.text('+5'), findsOneWidget);

        // Border should still be visible
        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        final border = decoration.border as Border;
        expect(border.top.color, equals(AppColors.divider));
      });
    });

    tearDownAll(() {
      // Clean up after all tests
    });
  });
}
