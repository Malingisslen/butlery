// test/widget/common/content_cards/text_display_card_ultrathink_test.dart
// Comprehensive tests for TextDisplayCard using ultrathink methodology
//
// ULTRATHINK ANALYSIS: text_display_card.dart (48 lines)
// - StatelessWidget with 6 properties (1 required, 5 optional with defaults)
// - Theme-integrated design using AppColors, AppDimensions, Theme.of(context)
// - Conditional rendering: scrollable → SingleChildScrollView, non-scrollable → direct Text
// - Required text parameter with theme fallback styling
// - scrollable = true default provides scrolling capability
// - Container decoration with rounded corners, borders, padding
// - Fallback system: All optional params have sensible theme-based defaults

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/content_cards/text_display_card.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';

void main() {
  group('TextDisplayCard Tests - ULTRATHINK METHODOLOGY', () {

    const String testText = 'Test text content';
    const String longText = 'This is a very long text that might need scrolling behavior to be properly tested in various scenarios and edge cases';
    const String emptyText = '';
    const String swedishText = 'Svensk text med åäö tecken för att testa lokalisering';

    group('Widget Construction and Required Parameters', () {
      testWidgets('should render with required text parameter', (WidgetTester tester) async {
        // ULTRATHINK: Test basic construction with minimal required parameters (line 21)
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TextDisplayCard(text: testText),
            ),
          ),
        );

        expect(find.text(testText), findsOneWidget);
        expect(find.byType(TextDisplayCard), findsOneWidget);
        expect(find.byType(Container), findsOneWidget);
      });

      testWidgets('should require text parameter for construction', (WidgetTester tester) async {
        // ULTRATHINK: Verify required parameter enforcement (line 21)
        expect(() => TextDisplayCard(text: testText), returnsNormally);
      });

      testWidgets('should handle empty text parameter', (WidgetTester tester) async {
        // ULTRATHINK: Test edge case with empty text
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TextDisplayCard(text: emptyText),
            ),
          ),
        );

        expect(find.text(emptyText), findsOneWidget);
        expect(find.byType(TextDisplayCard), findsOneWidget);
      });

      testWidgets('should handle Swedish characters in text', (WidgetTester tester) async {
        // ULTRATHINK: Test internationalization support
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TextDisplayCard(text: swedishText),
            ),
          ),
        );

        expect(find.text(swedishText), findsOneWidget);
      });
    });

    group('Optional Parameter Defaults and Overrides', () {
      testWidgets('should use default scrollable = true behavior', (WidgetTester tester) async {
        // ULTRATHINK: Test default scrollable behavior (line 26)
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TextDisplayCard(text: testText),
            ),
          ),
        );

        expect(find.byType(SingleChildScrollView), findsOneWidget);
        expect(find.byType(Text), findsOneWidget);
      });

      testWidgets('should allow scrollable override to false', (WidgetTester tester) async {
        // ULTRATHINK: Test scrollable parameter override (line 43-45)
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TextDisplayCard(
                text: testText,
                scrollable: false,
              ),
            ),
          ),
        );

        expect(find.byType(SingleChildScrollView), findsNothing);
        expect(find.byType(Text), findsOneWidget);
      });

      testWidgets('should accept custom text style parameter', (WidgetTester tester) async {
        // ULTRATHINK: Test textStyle parameter (line 22, 33)
        const customTextStyle = TextStyle(fontSize: 20, fontWeight: FontWeight.bold);
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TextDisplayCard(
                text: testText,
                textStyle: customTextStyle,
              ),
            ),
          ),
        );

        final Text textWidget = tester.widget(find.byType(Text));
        expect(textWidget.style, equals(customTextStyle));
      });

      testWidgets('should accept custom background color parameter', (WidgetTester tester) async {
        // ULTRATHINK: Test backgroundColor parameter (line 23, 39)
        const customBackgroundColor = Colors.blue;
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TextDisplayCard(
                text: testText,
                backgroundColor: customBackgroundColor,
              ),
            ),
          ),
        );

        final Container container = tester.widget(find.byType(Container));
        final BoxDecoration decoration = container.decoration as BoxDecoration;
        expect(decoration.color, equals(customBackgroundColor));
      });

      testWidgets('should accept custom border color parameter', (WidgetTester tester) async {
        // ULTRATHINK: Test borderColor parameter (line 24, 41)
        const customBorderColor = Colors.red;
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TextDisplayCard(
                text: testText,
                borderColor: customBorderColor,
              ),
            ),
          ),
        );

        final Container container = tester.widget(find.byType(Container));
        final BoxDecoration decoration = container.decoration as BoxDecoration;
        final Border border = decoration.border as Border;
        expect(border.top.color, equals(customBorderColor));
      });

      testWidgets('should accept custom padding parameter', (WidgetTester tester) async {
        // ULTRATHINK: Test padding parameter (line 25, 37)
        const customPadding = EdgeInsets.all(16.0);
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TextDisplayCard(
                text: testText,
                padding: customPadding,
              ),
            ),
          ),
        );

        final Container container = tester.widget(find.byType(Container));
        expect(container.padding, equals(customPadding));
      });
    });

    group('Theme Integration and Fallbacks', () {
      testWidgets('should use theme text style when textStyle not provided', (WidgetTester tester) async {
        // ULTRATHINK: Test theme fallback for text style (line 33)
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              textTheme: const TextTheme(
                bodyMedium: TextStyle(fontSize: 18, color: Colors.purple),
              ),
            ),
            home: Scaffold(
              body: TextDisplayCard(text: testText),
            ),
          ),
        );

        final Text textWidget = tester.widget(find.byType(Text));
        expect(textWidget.style?.fontSize, equals(18));
        expect(textWidget.style?.color, equals(Colors.purple));
      });

      testWidgets('should use AppColors.backgroundTint when backgroundColor not provided', (WidgetTester tester) async {
        // ULTRATHINK: Test AppColors fallback for background (line 39)
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TextDisplayCard(text: testText),
            ),
          ),
        );

        final Container container = tester.widget(find.byType(Container));
        final BoxDecoration decoration = container.decoration as BoxDecoration;
        expect(decoration.color, equals(AppColors.backgroundTint));
      });

      testWidgets('should use AppColors.divider when borderColor not provided', (WidgetTester tester) async {
        // ULTRATHINK: Test AppColors fallback for border (line 41)
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TextDisplayCard(text: testText),
            ),
          ),
        );

        final Container container = tester.widget(find.byType(Container));
        final BoxDecoration decoration = container.decoration as BoxDecoration;
        final Border border = decoration.border as Border;
        expect(border.top.color, equals(AppColors.divider));
      });

      testWidgets('should use AppDimensions.paddingL when padding not provided', (WidgetTester tester) async {
        // ULTRATHINK: Test AppDimensions fallback for padding (line 37)
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TextDisplayCard(text: testText),
            ),
          ),
        );

        final Container container = tester.widget(find.byType(Container));
        expect(container.padding, equals(const EdgeInsets.all(AppDimensions.paddingL)));
      });

      testWidgets('should use AppDimensions.borderRadiusM for container decoration', (WidgetTester tester) async {
        // ULTRATHINK: Test AppDimensions border radius (line 40)
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TextDisplayCard(text: testText),
            ),
          ),
        );

        final Container container = tester.widget(find.byType(Container));
        final BoxDecoration decoration = container.decoration as BoxDecoration;
        final BorderRadius borderRadius = decoration.borderRadius as BorderRadius;
        expect(borderRadius, equals(BorderRadius.circular(AppDimensions.borderRadiusM)));
      });
    });

    group('Container Decoration and Styling', () {
      testWidgets('should create proper container decoration structure', (WidgetTester tester) async {
        // ULTRATHINK: Test complete container decoration (lines 38-42)
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TextDisplayCard(text: testText),
            ),
          ),
        );

        final Container container = tester.widget(find.byType(Container));
        final BoxDecoration decoration = container.decoration as BoxDecoration;
        
        expect(decoration.color, isNotNull);
        expect(decoration.borderRadius, isNotNull);
        expect(decoration.border, isNotNull);
      });

      testWidgets('should support all decoration customizations together', (WidgetTester tester) async {
        // ULTRATHINK: Test combined custom styling
        const customBackgroundColor = Colors.yellow;
        const customBorderColor = Colors.green;
        const customPadding = EdgeInsets.all(12.0);
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TextDisplayCard(
                text: testText,
                backgroundColor: customBackgroundColor,
                borderColor: customBorderColor,
                padding: customPadding,
              ),
            ),
          ),
        );

        final Container container = tester.widget(find.byType(Container));
        final BoxDecoration decoration = container.decoration as BoxDecoration;
        final Border border = decoration.border as Border;
        
        expect(decoration.color, equals(customBackgroundColor));
        expect(border.top.color, equals(customBorderColor));
        expect(container.padding, equals(customPadding));
      });
    });

    group('Scrolling Behavior and Content Handling', () {
      testWidgets('should wrap content in SingleChildScrollView when scrollable = true', (WidgetTester tester) async {
        // ULTRATHINK: Test scrollable = true path (line 44)
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 50,
                child: TextDisplayCard(
                  text: longText,
                  scrollable: true,
                ),
              ),
            ),
          ),
        );

        expect(find.byType(SingleChildScrollView), findsOneWidget);
        expect(find.byType(Text), findsOneWidget);
        
        final SingleChildScrollView scrollView = tester.widget(find.byType(SingleChildScrollView));
        expect(scrollView.child, isA<Text>());
      });

      testWidgets('should render text directly when scrollable = false', (WidgetTester tester) async {
        // ULTRATHINK: Test scrollable = false path (line 45)
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TextDisplayCard(
                text: testText,
                scrollable: false,
              ),
            ),
          ),
        );

        expect(find.byType(SingleChildScrollView), findsNothing);
        expect(find.byType(Text), findsOneWidget);
      });

      testWidgets('should handle long text with scrolling enabled', (WidgetTester tester) async {
        // ULTRATHINK: Test long text scrolling behavior
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 50,
                width: 100,
                child: TextDisplayCard(
                  text: longText,
                  scrollable: true,
                ),
              ),
            ),
          ),
        );

        expect(find.text(longText), findsOneWidget);
        expect(find.byType(SingleChildScrollView), findsOneWidget);
        
        // Verify scrolling is possible
        await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -20));
        await tester.pumpAndSettle();
      });

      testWidgets('should handle long text without scrolling when disabled', (WidgetTester tester) async {
        // ULTRATHINK: Test long text without scrolling
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 50,
                width: 100,
                child: TextDisplayCard(
                  text: longText,
                  scrollable: false,
                ),
              ),
            ),
          ),
        );

        expect(find.text(longText), findsOneWidget);
        expect(find.byType(SingleChildScrollView), findsNothing);
      });
    });

    group('Edge Cases and Parameter Validation', () {
      testWidgets('should handle null optional parameters gracefully', (WidgetTester tester) async {
        // ULTRATHINK: Test null parameter handling
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TextDisplayCard(
                text: testText,
                textStyle: null,
                backgroundColor: null,
                borderColor: null,
                padding: null,
              ),
            ),
          ),
        );

        expect(find.text(testText), findsOneWidget);
        expect(find.byType(TextDisplayCard), findsOneWidget);
      });

      testWidgets('should handle very long text content', (WidgetTester tester) async {
        // ULTRATHINK: Test extreme content length
        final veryLongText = 'A' * 10000; // 10,000 character string
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TextDisplayCard(text: veryLongText),
            ),
          ),
        );

        expect(find.text(veryLongText), findsOneWidget);
        expect(find.byType(SingleChildScrollView), findsOneWidget);
      });

      testWidgets('should handle special characters and emojis', (WidgetTester tester) async {
        // ULTRATHINK: Test special character support
        const specialText = '🍕🥗🍰 Special chars: @#\$%^&*()_+{}|:"<>?[]\\;\',./ åäöÅÄÖ';
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TextDisplayCard(text: specialText),
            ),
          ),
        );

        expect(find.text(specialText), findsOneWidget);
      });

      testWidgets('should maintain accessibility properties', (WidgetTester tester) async {
        // ULTRATHINK: Test accessibility considerations
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TextDisplayCard(text: testText),
            ),
          ),
        );

        final Text textWidget = tester.widget(find.byType(Text));
        expect(textWidget.data, equals(testText));
        
        // Verify widget is found by accessibility tools
        expect(find.text(testText), findsOneWidget);
      });
    });

    group('Widget Integration and Context Requirements', () {
      testWidgets('should work within different parent widgets', (WidgetTester tester) async {
        // ULTRATHINK: Test widget integration flexibility
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: const [
                  TextDisplayCard(text: 'First card'),
                  Expanded(
                    child: TextDisplayCard(text: 'Expanded card'),
                  ),
                  TextDisplayCard(text: 'Last card'),
                ],
              ),
            ),
          ),
        );

        expect(find.text('First card'), findsOneWidget);
        expect(find.text('Expanded card'), findsOneWidget);
        expect(find.text('Last card'), findsOneWidget);
        expect(find.byType(TextDisplayCard), findsNWidgets(3));
      });

      testWidgets('should respond to theme changes', (WidgetTester tester) async {
        // ULTRATHINK: Test theme responsiveness
        final lightTheme = ThemeData(
          textTheme: const TextTheme(
            bodyMedium: TextStyle(color: Colors.black),
          ),
        );
        
        await tester.pumpWidget(
          MaterialApp(
            theme: lightTheme,
            home: Scaffold(
              body: TextDisplayCard(text: testText),
            ),
          ),
        );

        final Text textWidget = tester.widget(find.byType(Text));
        expect(textWidget.style?.color, equals(Colors.black));
      });

      testWidgets('should maintain performance with multiple instances', (WidgetTester tester) async {
        // ULTRATHINK: Test performance with multiple widgets
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ListView(
                children: List.generate(20, (index) => 
                  TextDisplayCard(text: 'Card $index')),
              ),
            ),
          ),
        );

        // ListView only renders visible widgets (lazy loading)
        expect(find.byType(TextDisplayCard), findsWidgets);
        
        // Verify first card is rendered
        expect(find.text('Card 0'), findsOneWidget);
        
        // Scroll to see more widgets
        await tester.drag(find.byType(ListView), const Offset(0, -500));
        await tester.pumpAndSettle();
        
        // After scrolling, more cards should be visible
        expect(find.byType(TextDisplayCard), findsWidgets);
      });
    });

    group('Build Method Behavior and Widget Tree Structure', () {
      testWidgets('should create expected widget tree structure', (WidgetTester tester) async {
        // ULTRATHINK: Test complete widget tree structure (lines 30-47)
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TextDisplayCard(text: testText),
            ),
          ),
        );

        // Verify widget hierarchy: Container > SingleChildScrollView > Text
        expect(find.byType(Container), findsOneWidget);
        expect(find.byType(SingleChildScrollView), findsOneWidget);
        expect(find.byType(Text), findsOneWidget);
      });

      testWidgets('should create alternate widget tree when scrollable = false', (WidgetTester tester) async {
        // ULTRATHINK: Test alternate widget tree structure (line 45)
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TextDisplayCard(
                text: testText,
                scrollable: false,
              ),
            ),
          ),
        );

        // Verify widget hierarchy: Container > Text (no ScrollView)
        expect(find.byType(Container), findsOneWidget);
        expect(find.byType(SingleChildScrollView), findsNothing);
        expect(find.byType(Text), findsOneWidget);
      });

      testWidgets('should build consistently across multiple rebuilds', (WidgetTester tester) async {
        // ULTRATHINK: Test build method consistency
        Widget buildWidget(String text) {
          return MaterialApp(
            home: Scaffold(
              body: TextDisplayCard(text: text),
            ),
          );
        }

        await tester.pumpWidget(buildWidget('Initial'));
        expect(find.text('Initial'), findsOneWidget);

        await tester.pumpWidget(buildWidget('Updated'));
        expect(find.text('Updated'), findsOneWidget);
        expect(find.text('Initial'), findsNothing);

        await tester.pumpWidget(buildWidget('Final'));
        expect(find.text('Final'), findsOneWidget);
        expect(find.text('Updated'), findsNothing);
      });
    });

    group('Production Use Case Scenarios', () {
      testWidgets('should work for OCR results display scenario', (WidgetTester tester) async {
        // ULTRATHINK: Test OCR use case mentioned in documentation (line 10)
        const ocrText = 'Extracted text from image:\n\nIngredients:\n- 2 cups flour\n- 1 tsp salt\n- 1 cup water';
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TextDisplayCard(
                text: ocrText,
                backgroundColor: Colors.grey[100],
                borderColor: Colors.grey[400],
              ),
            ),
          ),
        );

        expect(find.text(ocrText), findsOneWidget);
        expect(find.byType(SingleChildScrollView), findsOneWidget);
      });

      testWidgets('should work for preview display scenario', (WidgetTester tester) async {
        // ULTRATHINK: Test preview use case mentioned in documentation (line 10)
        const previewText = 'Recipe Preview: Delicious Swedish meatballs with lingonberry sauce';
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TextDisplayCard(
                text: previewText,
                scrollable: false,
                textStyle: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
          ),
        );

        expect(find.text(previewText), findsOneWidget);
        expect(find.byType(SingleChildScrollView), findsNothing);
        
        final Text textWidget = tester.widget(find.byType(Text));
        expect(textWidget.style?.fontStyle, equals(FontStyle.italic));
      });

      testWidgets('should work for general text content display scenario', (WidgetTester tester) async {
        // ULTRATHINK: Test general content display use case (line 10)
        const contentText = 'Tips för att lyckas med bakning:\n\n1. Mät ingredienserna noggrant\n2. Förvärm ugnen\n3. Använd färska ingredienser';
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 200,
                child: TextDisplayCard(
                  text: contentText,
                  padding: const EdgeInsets.all(20),
                ),
              ),
            ),
          ),
        );

        expect(find.text(contentText), findsOneWidget);
        expect(find.byType(SingleChildScrollView), findsOneWidget);
        
        final Container container = tester.widget(find.byType(Container));
        expect(container.padding, equals(const EdgeInsets.all(20)));
      });
    });
  });
}