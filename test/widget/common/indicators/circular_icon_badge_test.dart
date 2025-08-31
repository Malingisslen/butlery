// test/widget/common/indicators/circular_icon_badge_test.dart
// Comprehensive tests for CircularIconBadge using ultrathink methodology

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/indicators/circular_icon_badge.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';

void main() {
  group('CircularIconBadge Widget Tests', () {
    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    group('Default Constructor', () {
      testWidgets('should render with required icon', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: CircularIconBadge(icon: Icons.star),
            ),
          ),
        );

        expect(find.byType(CircularIconBadge), findsOneWidget);
        expect(find.byIcon(Icons.star), findsOneWidget);
      });

      testWidgets('should use default blue background color', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: CircularIconBadge(icon: Icons.star),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, equals(AppColors.primaryBlue));
      });

      testWidgets('should use default white icon color', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: CircularIconBadge(icon: Icons.star),
            ),
          ),
        );

        final icon = tester.widget<Icon>(find.byIcon(Icons.star));
        expect(icon.color, equals(AppColors.cardWhite));
      });

      testWidgets('should use default icon size', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: CircularIconBadge(icon: Icons.star),
            ),
          ),
        );

        final renderBox = tester.renderObject<RenderBox>(
          find.byType(CircularIconBadge),
        );
        expect(renderBox.size.width, equals(AppDimensions.iconSizeS));
        expect(renderBox.size.height, equals(AppDimensions.iconSizeS));

        final icon = tester.widget<Icon>(find.byIcon(Icons.star));
        expect(icon.size, equals(AppDimensions.iconSizeS));
      });

      testWidgets('should apply custom background color', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: CircularIconBadge(
                icon: Icons.star,
                backgroundColor: Colors.red,
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, equals(Colors.red));
      });

      testWidgets('should apply custom icon color', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: CircularIconBadge(
                icon: Icons.star,
                iconColor: Colors.yellow,
              ),
            ),
          ),
        );

        final icon = tester.widget<Icon>(find.byIcon(Icons.star));
        expect(icon.color, equals(Colors.yellow));
      });

      testWidgets('should apply custom size', (WidgetTester tester) async {
        const customSize = 48.0;
        
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: CircularIconBadge(
                icon: Icons.star,
                size: customSize,
              ),
            ),
          ),
        );

        final renderBox = tester.renderObject<RenderBox>(
          find.byType(CircularIconBadge),
        );
        expect(renderBox.size.width, equals(customSize));
        expect(renderBox.size.height, equals(customSize));

        final icon = tester.widget<Icon>(find.byIcon(Icons.star));
        expect(icon.size, equals(customSize));
      });

      testWidgets('should have circular shape', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: CircularIconBadge(icon: Icons.star),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.shape, equals(BoxShape.circle));
      });
    });

    group('Add Constructor', () {
      testWidgets('should render with add icon', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: CircularIconBadge.add(),
            ),
          ),
        );

        expect(find.byType(CircularIconBadge), findsOneWidget);
        expect(find.byIcon(Icons.add), findsOneWidget);
      });

      testWidgets('should use primary blue background', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: CircularIconBadge.add(),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, equals(AppColors.primaryBlue));
      });

      testWidgets('should use white icon color', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: CircularIconBadge.add(),
            ),
          ),
        );

        final icon = tester.widget<Icon>(find.byIcon(Icons.add));
        expect(icon.color, equals(AppColors.cardWhite));
      });

      testWidgets('should accept custom size', (WidgetTester tester) async {
        const customSize = 64.0;
        
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: CircularIconBadge.add(size: customSize),
            ),
          ),
        );

        final renderBox = tester.renderObject<RenderBox>(
          find.byType(CircularIconBadge),
        );
        expect(renderBox.size.width, equals(customSize));
        expect(renderBox.size.height, equals(customSize));

        final icon = tester.widget<Icon>(find.byIcon(Icons.add));
        expect(icon.size, equals(customSize));
      });
    });

    group('Visual Consistency', () {
      testWidgets('should maintain aspect ratio', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: CircularIconBadge(
                icon: Icons.star,
                size: 40,
              ),
            ),
          ),
        );

        final renderBox = tester.renderObject<RenderBox>(
          find.byType(CircularIconBadge),
        );
        expect(renderBox.size.width, equals(renderBox.size.height));
      });

      testWidgets('should center icon in badge', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: CircularIconBadge(icon: Icons.star),
            ),
          ),
        );

        // Icon should be directly inside Container
        final container = tester.widget<Container>(find.byType(Container));
        expect(container.child, isA<Icon>());
      });

      testWidgets('should work with different icon types', (WidgetTester tester) async {
        const icons = [
          Icons.favorite,
          Icons.settings,
          Icons.notifications,
          Icons.person,
        ];

        for (final iconData in icons) {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: CircularIconBadge(icon: iconData),
              ),
            ),
          );

          expect(find.byIcon(iconData), findsOneWidget);
        }
      });
    });

    group('Theme Integration', () {
      testWidgets('should work with light theme', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: const Scaffold(
              body: CircularIconBadge(icon: Icons.star),
            ),
          ),
        );

        expect(find.byType(CircularIconBadge), findsOneWidget);
      });

      testWidgets('should work with dark theme', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: const Scaffold(
              body: CircularIconBadge(icon: Icons.star),
            ),
          ),
        );

        expect(find.byType(CircularIconBadge), findsOneWidget);
      });
    });

    group('Layout Integration', () {
      testWidgets('should work in Row layout', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Row(
                children: [
                  CircularIconBadge(icon: Icons.star),
                  CircularIconBadge(icon: Icons.favorite),
                  CircularIconBadge.add(),
                ],
              ),
            ),
          ),
        );

        expect(find.byType(CircularIconBadge), findsNWidgets(3));
        expect(find.byIcon(Icons.star), findsOneWidget);
        expect(find.byIcon(Icons.favorite), findsOneWidget);
        expect(find.byIcon(Icons.add), findsOneWidget);
      });

      testWidgets('should work in Stack layout', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  Positioned(
                    top: 10,
                    left: 10,
                    child: CircularIconBadge(icon: Icons.star),
                  ),
                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: CircularIconBadge.add(),
                  ),
                ],
              ),
            ),
          ),
        );

        expect(find.byType(CircularIconBadge), findsNWidgets(2));
      });
    });

    group('Edge Cases', () {
      testWidgets('should handle very small size', (WidgetTester tester) async {
        const smallSize = 16.0;
        
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: CircularIconBadge(
                icon: Icons.star,
                size: smallSize,
              ),
            ),
          ),
        );

        final renderBox = tester.renderObject<RenderBox>(
          find.byType(CircularIconBadge),
        );
        expect(renderBox.size.width, equals(smallSize));
        expect(renderBox.size.height, equals(smallSize));
      });

      testWidgets('should handle very large size', (WidgetTester tester) async {
        const largeSize = 128.0;
        
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: CircularIconBadge(
                icon: Icons.star,
                size: largeSize,
              ),
            ),
          ),
        );

        final renderBox = tester.renderObject<RenderBox>(
          find.byType(CircularIconBadge),
        );
        expect(renderBox.size.width, equals(largeSize));
        expect(renderBox.size.height, equals(largeSize));
      });

      testWidgets('should handle transparent colors', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: CircularIconBadge(
                icon: Icons.star,
                backgroundColor: Colors.transparent,
                iconColor: Colors.black,
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, equals(Colors.transparent));

        final icon = tester.widget<Icon>(find.byIcon(Icons.star));
        expect(icon.color, equals(Colors.black));
      });
    });

    tearDownAll(() {
      // Clean up after all tests
    });
  });
}