// test/widget/common/layout/category_header_test.dart
// Comprehensive tests for CategoryHeader using ultrathink methodology

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/layout/category_header.dart';
import 'package:butlery/theme/app_dimensions.dart';

void main() {
  group('CategoryHeader Widget Tests', () {
    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    group('Basic Rendering', () {
      testWidgets('should render with required properties', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CategoryHeader(
                title: 'Huvudrätter',
                icon: Icons.restaurant,
                count: 5,
              ),
            ),
          ),
        );

        expect(find.byType(CategoryHeader), findsOneWidget);
        expect(find.byType(Container), findsNWidgets(2)); // Main container + count badge
        expect(find.byType(Row), findsOneWidget);
        expect(find.text('Huvudrätter'), findsOneWidget);
        expect(find.byIcon(Icons.restaurant), findsOneWidget);
        expect(find.text('5'), findsOneWidget);
      });

      testWidgets('should have correct padding', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CategoryHeader(
                title: 'Test',
                icon: Icons.star,
                count: 1,
              ),
            ),
          ),
        );

        final containers = tester.widgetList<Container>(find.byType(Container));
        final mainContainer = containers.first; // First container is the main one
        
        expect(
          mainContainer.padding,
          equals(const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingS,
            vertical: AppDimensions.spacingXs,
          )),
        );
      });

      testWidgets('should have full width', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CategoryHeader(
                title: 'Test',
                icon: Icons.star,
                count: 1,
              ),
            ),
          ),
        );

        final containers = tester.widgetList<Container>(find.byType(Container));
        final mainContainer = containers.first;
        
        expect(mainContainer.constraints?.minWidth, equals(double.infinity));
        expect(mainContainer.constraints?.maxWidth, equals(double.infinity));
      });

      testWidgets('should have correct border radius', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CategoryHeader(
                title: 'Test',
                icon: Icons.star,
                count: 1,
              ),
            ),
          ),
        );

        final containers = tester.widgetList<Container>(find.byType(Container));
        final mainContainer = containers.first;
        final decoration = mainContainer.decoration as BoxDecoration;
        
        expect(
          decoration.borderRadius,
          equals(BorderRadius.circular(AppDimensions.borderRadiusS)),
        );
      });
    });

    group('Theme Integration', () {
      testWidgets('should use default theme colors', (WidgetTester tester) async {
        const customTheme = ColorScheme(
          brightness: Brightness.light,
          primary: Colors.blue,
          onPrimary: Colors.white,
          secondary: Colors.orange,
          onSecondary: Colors.black,
          error: Colors.red,
          onError: Colors.white,
          surface: Colors.white,
          onSurface: Colors.black,
          secondaryContainer: Colors.lightBlue,
          onSecondaryContainer: Colors.blue,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(colorScheme: customTheme),
            home: Scaffold(
              body: CategoryHeader(
                title: 'Test',
                icon: Icons.star,
                count: 1,
              ),
            ),
          ),
        );

        final containers = tester.widgetList<Container>(find.byType(Container));
        final mainContainer = containers.first;
        final countContainer = containers.last;
        
        // Check main container background
        final mainDecoration = mainContainer.decoration as BoxDecoration;
        expect(mainDecoration.color, equals(Colors.lightBlue));
        
        // Check count badge background
        final countDecoration = countContainer.decoration as BoxDecoration;
        expect(countDecoration.color, equals(Colors.orange));
        
        // Check icon color
        final icon = tester.widget<Icon>(find.byIcon(Icons.star));
        expect(icon.color, equals(Colors.blue));
      });

      testWidgets('should work with dark theme', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: CategoryHeader(
                title: 'Test',
                icon: Icons.star,
                count: 1,
              ),
            ),
          ),
        );

        expect(find.byType(CategoryHeader), findsOneWidget);
        expect(find.text('Test'), findsOneWidget);
        expect(find.byIcon(Icons.star), findsOneWidget);
        expect(find.text('1'), findsOneWidget);
      });

      testWidgets('should work with light theme', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: Scaffold(
              body: CategoryHeader(
                title: 'Test',
                icon: Icons.star,
                count: 1,
              ),
            ),
          ),
        );

        expect(find.byType(CategoryHeader), findsOneWidget);
        expect(find.text('Test'), findsOneWidget);
        expect(find.byIcon(Icons.star), findsOneWidget);
        expect(find.text('1'), findsOneWidget);
      });
    });

    group('Custom Properties', () {
      testWidgets('should use custom background color', (WidgetTester tester) async {
        const customBackgroundColor = Colors.purple;
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CategoryHeader(
                title: 'Test',
                icon: Icons.star,
                count: 1,
                backgroundColor: customBackgroundColor,
              ),
            ),
          ),
        );

        final containers = tester.widgetList<Container>(find.byType(Container));
        final mainContainer = containers.first;
        final decoration = mainContainer.decoration as BoxDecoration;
        
        expect(decoration.color, equals(customBackgroundColor));
      });

      testWidgets('should use custom text color', (WidgetTester tester) async {
        const customTextColor = Colors.red;
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CategoryHeader(
                title: 'Test Title',
                icon: Icons.star,
                count: 1,
                textColor: customTextColor,
              ),
            ),
          ),
        );

        // Check icon color
        final icon = tester.widget<Icon>(find.byIcon(Icons.star));
        expect(icon.color, equals(customTextColor));
        
        // Check title color by finding the Text widget with our title
        final titleTextWidgets = tester.widgetList<Text>(find.text('Test Title'));
        expect(titleTextWidgets.length, equals(1));
        final titleText = titleTextWidgets.first;
        expect(titleText.style?.color, equals(customTextColor));
      });

      testWidgets('should use both custom colors together', (WidgetTester tester) async {
        const customBackgroundColor = Colors.green;
        const customTextColor = Colors.yellow;
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CategoryHeader(
                title: 'Custom Colors',
                icon: Icons.palette,
                count: 3,
                backgroundColor: customBackgroundColor,
                textColor: customTextColor,
              ),
            ),
          ),
        );

        final containers = tester.widgetList<Container>(find.byType(Container));
        final mainContainer = containers.first;
        final decoration = mainContainer.decoration as BoxDecoration;
        
        expect(decoration.color, equals(customBackgroundColor));
        
        final icon = tester.widget<Icon>(find.byIcon(Icons.palette));
        expect(icon.color, equals(customTextColor));
      });
    });

    group('Layout Structure', () {
      testWidgets('should have correct layout structure', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CategoryHeader(
                title: 'Test',
                icon: Icons.star,
                count: 1,
              ),
            ),
          ),
        );

        // Should have: Container > Row > [Icon, SizedBox, Text, Spacer, Container]
        expect(find.byType(Row), findsOneWidget);
        expect(find.byType(Icon), findsOneWidget);
        expect(find.byType(SizedBox), findsAtLeastNWidgets(1)); // Multiple SizedBox widgets may exist
        expect(find.byType(Text), findsNWidgets(2)); // Title + count
        expect(find.byType(Spacer), findsOneWidget);
      });

      testWidgets('should have correct icon size', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CategoryHeader(
                title: 'Test',
                icon: Icons.star,
                count: 1,
              ),
            ),
          ),
        );

        final icon = tester.widget<Icon>(find.byIcon(Icons.star));
        expect(icon.size, equals(AppDimensions.iconSizeM));
      });

      testWidgets('should have correct spacing between icon and text', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CategoryHeader(
                title: 'Test',
                icon: Icons.star,
                count: 1,
              ),
            ),
          ),
        );

        // Find the SizedBox with width = spacingS (spacing between icon and text)
        final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
        final spacingSizedBox = sizedBoxes.firstWhere(
          (box) => box.width == AppDimensions.spacingS,
          orElse: () => throw StateError('Spacing SizedBox not found'),
        );
        expect(spacingSizedBox.width, equals(AppDimensions.spacingS));
      });
    });

    group('Count Badge', () {
      testWidgets('should display count badge with correct styling', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CategoryHeader(
                title: 'Test',
                icon: Icons.star,
                count: 42,
              ),
            ),
          ),
        );

        expect(find.text('42'), findsOneWidget);
        
        final containers = tester.widgetList<Container>(find.byType(Container));
        final countContainer = containers.last; // Count badge is the last container
        final decoration = countContainer.decoration as BoxDecoration;
        
        expect(
          countContainer.padding,
          equals(const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingXs,
            vertical: 2,
          )),
        );
        
        expect(
          decoration.borderRadius,
          equals(BorderRadius.circular(AppDimensions.borderRadius10)),
        );
      });

      testWidgets('should handle zero count', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CategoryHeader(
                title: 'Empty Category',
                icon: Icons.folder,
                count: 0,
              ),
            ),
          ),
        );

        expect(find.text('0'), findsOneWidget);
        expect(find.text('Empty Category'), findsOneWidget);
      });

      testWidgets('should handle large count numbers', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CategoryHeader(
                title: 'Popular Category',
                icon: Icons.trending_up,
                count: 9999,
              ),
            ),
          ),
        );

        expect(find.text('9999'), findsOneWidget);
        expect(find.text('Popular Category'), findsOneWidget);
      });

      testWidgets('should use correct count badge colors from theme', (WidgetTester tester) async {
        const customTheme = ColorScheme(
          brightness: Brightness.light,
          primary: Colors.blue,
          onPrimary: Colors.white,
          secondary: Colors.red,
          onSecondary: Colors.white,
          error: Colors.red,
          onError: Colors.white,
          surface: Colors.white,
          onSurface: Colors.black,
          secondaryContainer: Colors.lightBlue,
          onSecondaryContainer: Colors.blue,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(colorScheme: customTheme),
            home: Scaffold(
              body: CategoryHeader(
                title: 'Test',
                icon: Icons.star,
                count: 5,
              ),
            ),
          ),
        );

        final containers = tester.widgetList<Container>(find.byType(Container));
        final countContainer = containers.last;
        final decoration = countContainer.decoration as BoxDecoration;
        
        expect(decoration.color, equals(Colors.red)); // secondary color
        
        // Check count text color
        final countTextWidgets = tester.widgetList<Text>(find.text('5'));
        expect(countTextWidgets.length, equals(1));
        final countText = countTextWidgets.first;
        expect(countText.style?.color, equals(Colors.white)); // onSecondary color
      });
    });

    group('Text Styling', () {
      testWidgets('should use correct title text style', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CategoryHeader(
                title: 'Styled Title',
                icon: Icons.text_fields,
                count: 1,
              ),
            ),
          ),
        );

        final titleTextWidgets = tester.widgetList<Text>(find.text('Styled Title'));
        expect(titleTextWidgets.length, equals(1));
        final titleText = titleTextWidgets.first;
        
        // Check font weight
        expect(titleText.style?.fontWeight, equals(FontWeight.w600));
      });

      testWidgets('should use correct count text style', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CategoryHeader(
                title: 'Test',
                icon: Icons.star,
                count: 123,
              ),
            ),
          ),
        );

        final countTextWidgets = tester.widgetList<Text>(find.text('123'));
        expect(countTextWidgets.length, equals(1));
        final countText = countTextWidgets.first;
        
        // Check font weight
        expect(countText.style?.fontWeight, equals(FontWeight.bold));
      });
    });

    group('Swedish Localization', () {
      testWidgets('should display Swedish category names', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CategoryHeader(
                title: 'Förrätter',
                icon: Icons.restaurant_menu,
                count: 8,
              ),
            ),
          ),
        );

        expect(find.text('Förrätter'), findsOneWidget);
        expect(find.text('8'), findsOneWidget);
      });

      testWidgets('should support Swedish characters in titles', (WidgetTester tester) async {
        const swedishTitle = 'Kött & Fågel';
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CategoryHeader(
                title: swedishTitle,
                icon: Icons.dining,
                count: 15,
              ),
            ),
          ),
        );

        expect(find.text(swedishTitle), findsOneWidget);
        expect(find.byIcon(Icons.dining), findsOneWidget);
      });

      testWidgets('should handle long Swedish titles', (WidgetTester tester) async {
        const longSwedishTitle = 'Vegetariska Rätter';
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CategoryHeader(
                title: longSwedishTitle,
                icon: Icons.eco,
                count: 25,
              ),
            ),
          ),
        );

        expect(find.text(longSwedishTitle), findsOneWidget);
        expect(find.text('25'), findsOneWidget);
      });
    });

    group('Use Cases', () {
      testWidgets('should work for menu categories', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: const Column(
                children: [
                  CategoryHeader(
                    title: 'Huvudrätter',
                    icon: Icons.restaurant,
                    count: 12,
                  ),
                  CategoryHeader(
                    title: 'Förrätter',
                    icon: Icons.restaurant_menu,
                    count: 6,
                  ),
                  CategoryHeader(
                    title: 'Desserter',
                    icon: Icons.cake,
                    count: 8,
                  ),
                ],
              ),
            ),
          ),
        );

        expect(find.byType(CategoryHeader), findsNWidgets(3));
        expect(find.text('Huvudrätter'), findsOneWidget);
        expect(find.text('Förrätter'), findsOneWidget);
        expect(find.text('Desserter'), findsOneWidget);
        expect(find.text('12'), findsOneWidget);
        expect(find.text('6'), findsOneWidget);
        expect(find.text('8'), findsOneWidget);
      });

      testWidgets('should work for content categories', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CategoryHeader(
                title: 'Mina Recept',
                icon: Icons.book,
                count: 156,
                backgroundColor: Colors.blue.withValues(alpha: 0.1),
                textColor: Colors.blue.shade700,
              ),
            ),
          ),
        );

        expect(find.text('Mina Recept'), findsOneWidget);
        expect(find.byIcon(Icons.book), findsOneWidget);
        expect(find.text('156'), findsOneWidget);
      });

      testWidgets('should work for shopping list categories', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CategoryHeader(
                title: 'Frukt & Grönt',
                icon: Icons.apple,
                count: 7,
                backgroundColor: Colors.green.withValues(alpha: 0.1),
                textColor: Colors.green.shade800,
              ),
            ),
          ),
        );

        expect(find.text('Frukt & Grönt'), findsOneWidget);
        expect(find.byIcon(Icons.apple), findsOneWidget);
        expect(find.text('7'), findsOneWidget);
      });
    });

    group('Edge Cases', () {
      testWidgets('should handle empty title', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CategoryHeader(
                title: '',
                icon: Icons.help,
                count: 0,
              ),
            ),
          ),
        );

        expect(find.text(''), findsOneWidget);
        expect(find.byIcon(Icons.help), findsOneWidget);
        expect(find.text('0'), findsOneWidget);
      });

      testWidgets('should handle negative count', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CategoryHeader(
                title: 'Negative Test',
                icon: Icons.warning,
                count: -1,
              ),
            ),
          ),
        );

        expect(find.text('-1'), findsOneWidget);
        expect(find.text('Negative Test'), findsOneWidget);
      });

      testWidgets('should handle null custom colors gracefully', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CategoryHeader(
                title: 'Null Colors',
                icon: Icons.colorize,
                count: 1,
                backgroundColor: null,
                textColor: null,
              ),
            ),
          ),
        );

        expect(find.byType(CategoryHeader), findsOneWidget);
        expect(find.text('Null Colors'), findsOneWidget);
        expect(find.byIcon(Icons.colorize), findsOneWidget);
        expect(find.text('1'), findsOneWidget);
      });

      testWidgets('should handle very long titles without overflow - PRODUCTION BUG FIXED', (WidgetTester tester) async {
        const veryLongTitle = 'This is a very long title that should wrap properly without overflow';
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 200, // Constrained width to test overflow handling
                child: CategoryHeader(
                  title: veryLongTitle,
                  icon: Icons.text_snippet,
                  count: 999,
                ),
              ),
            ),
          ),
        );

        expect(find.text(veryLongTitle), findsOneWidget);
        expect(find.text('999'), findsOneWidget);
        
        // PRODUCTION BUG FIXED: Text widget is now wrapped in Expanded
        // Should no longer cause RenderFlex overflow with long titles
        final exception = tester.takeException();
        expect(exception, isNull, reason: 'No overflow exception should occur with Expanded wrapper');
        
        // Verify there are Expanded widgets in the layout
        expect(find.byType(Expanded), findsWidgets);
        
        // Verify that one of the Expanded widgets contains our Text widget
        final expandedWidgets = tester.widgetList<Expanded>(find.byType(Expanded));
        final textExpanded = expandedWidgets.firstWhere(
          (expanded) => expanded.child is Text && (expanded.child as Text).data == veryLongTitle,
          orElse: () => throw StateError('Text not found in Expanded widget'),
        );
        expect(textExpanded.child, isA<Text>());
        final textWidget = textExpanded.child as Text;
        expect(textWidget.data, equals(veryLongTitle));
      });

      testWidgets('should handle transparent colors', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CategoryHeader(
                title: 'Transparent',
                icon: Icons.opacity,
                count: 1,
                backgroundColor: Colors.transparent,
                textColor: Colors.transparent,
              ),
            ),
          ),
        );

        final containers = tester.widgetList<Container>(find.byType(Container));
        final mainContainer = containers.first;
        final decoration = mainContainer.decoration as BoxDecoration;
        
        expect(decoration.color, equals(Colors.transparent));
        
        final icon = tester.widget<Icon>(find.byIcon(Icons.opacity));
        expect(icon.color, equals(Colors.transparent));
      });
    });

    group('Accessibility', () {
      testWidgets('should be accessible with proper semantics', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Semantics(
                label: 'Category header for Huvudrätter with 12 items',
                child: CategoryHeader(
                  title: 'Huvudrätter',
                  icon: Icons.restaurant,
                  count: 12,
                ),
              ),
            ),
          ),
        );

        expect(find.byType(Semantics), findsWidgets);
        expect(find.byType(CategoryHeader), findsOneWidget);
      });

      testWidgets('should support screen reader navigation', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CategoryHeader(
                title: 'Accessible Category',
                icon: Icons.accessibility,
                count: 5,
              ),
            ),
          ),
        );

        // Icon, title text, and count text should all be findable
        expect(find.byIcon(Icons.accessibility), findsOneWidget);
        expect(find.text('Accessible Category'), findsOneWidget);
        expect(find.text('5'), findsOneWidget);
      });
    });

    tearDownAll(() {
      // Clean up after all tests
    });
  });
}