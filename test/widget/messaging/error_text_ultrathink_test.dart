// test/widget/messaging/error_text_ultrathink_test.dart
// Comprehensive tests for ErrorText using ultrathink methodology
// 
// ULTRATHINK ANALYSIS: ErrorText widget (22 lines)
// - StatelessWidget with single required String text parameter
// - Direct Text widget with AppColors.error styling
// - TextStyle(color: AppColors.error) applied to all error text
// - Simple error text display with consistent error color theming
// - No complex layout, just styled text with error color application

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/messaging/error_text.dart';
import 'package:butlery/theme/app_colors.dart';

void main() {
  group('ErrorText Widget Tests - ULTRATHINK METHODOLOGY', () {
    // Helper to create test environment
    Widget createTestWidget(Widget child) {
      return MaterialApp(
        home: Scaffold(
          body: Center(child: child),
        ),
      );
    }

    group('Basic Constructor and Rendering', () {
      testWidgets('should create widget with simple text', (WidgetTester tester) async {
        // ULTRATHINK: Test production code lines 10-13 constructor with required parameter
        const errorText = 'Simple error message';
        
        await tester.pumpWidget(createTestWidget(
          const ErrorText(errorText),
        ));

        expect(tester.takeException(), isNull);
        
        // Should display the error text
        expect(find.text('Simple error message'), findsOneWidget);
        expect(find.byType(ErrorText), findsOneWidget);
      });

      testWidgets('should create Text widget as child', (WidgetTester tester) async {
        // ULTRATHINK: Test production code lines 17-20 Text widget creation
        const errorText = 'Text widget test';
        
        await tester.pumpWidget(createTestWidget(
          const ErrorText(errorText),
        ));

        expect(tester.takeException(), isNull);
        
        // Should create Text widget as direct child
        expect(find.byType(Text), findsOneWidget);
        
        // Text widget should contain the error message
        final textWidget = tester.widget<Text>(find.byType(Text));
        expect(textWidget.data, equals('Text widget test'));
      });

      testWidgets('should apply AppColors.error styling', (WidgetTester tester) async {
        // ULTRATHINK: Test production code line 19 TextStyle with AppColors.error
        const errorText = 'Error styling test';
        
        await tester.pumpWidget(createTestWidget(
          const ErrorText(errorText),
        ));

        expect(tester.takeException(), isNull);
        
        // Should apply error color from AppColors
        final textWidget = tester.widget<Text>(find.text('Error styling test'));
        expect(textWidget.style, isNotNull);
        expect(textWidget.style!.color, equals(AppColors.error));
      });

      testWidgets('should use TextStyle constructor correctly', (WidgetTester tester) async {
        // ULTRATHINK: Test production code line 19 const TextStyle creation
        const errorText = 'TextStyle test';
        
        await tester.pumpWidget(createTestWidget(
          const ErrorText(errorText),
        ));

        expect(tester.takeException(), isNull);
        
        // Should create const TextStyle with color property
        final textWidget = tester.widget<Text>(find.text('TextStyle test'));
        expect(textWidget.style, isA<TextStyle>());
        
        // Should have only color set, other properties should be null/default
        expect(textWidget.style!.color, equals(AppColors.error));
        expect(textWidget.style!.fontSize, isNull); // Default from TextStyle()
        expect(textWidget.style!.fontWeight, isNull); // Default from TextStyle()
      });
    });

    group('Text Content Handling', () {
      testWidgets('should handle empty string', (WidgetTester tester) async {
        // ULTRATHINK: Test edge case with empty text parameter
        const errorText = '';
        
        await tester.pumpWidget(createTestWidget(
          const ErrorText(errorText),
        ));

        expect(tester.takeException(), isNull);
        
        // Should display empty text without errors
        expect(find.text(''), findsOneWidget);
        expect(find.byType(ErrorText), findsOneWidget);
      });

      testWidgets('should handle single character', (WidgetTester tester) async {
        // ULTRATHINK: Test minimal text content
        const errorText = 'X';
        
        await tester.pumpWidget(createTestWidget(
          const ErrorText(errorText),
        ));

        expect(tester.takeException(), isNull);
        
        // Should display single character
        expect(find.text('X'), findsOneWidget);
        
        // Should still apply error styling
        final textWidget = tester.widget<Text>(find.text('X'));
        expect(textWidget.style!.color, equals(AppColors.error));
      });

      testWidgets('should handle multi-line text', (WidgetTester tester) async {
        // ULTRATHINK: Test text with line breaks
        const errorText = 'First line\nSecond line\nThird line';
        
        await tester.pumpWidget(createTestWidget(
          const ErrorText(errorText),
        ));

        expect(tester.takeException(), isNull);
        
        // Should display multi-line text
        expect(find.text('First line\nSecond line\nThird line'), findsOneWidget);
        
        // Should apply styling to all lines
        final textWidget = tester.widget<Text>(find.text('First line\nSecond line\nThird line'));
        expect(textWidget.style!.color, equals(AppColors.error));
      });

      testWidgets('should handle long text content', (WidgetTester tester) async {
        // ULTRATHINK: Test with very long error messages
        const errorText = 'This is a very long error message that might cause layout issues if not handled properly. It contains multiple sentences and should test the text widget\'s ability to handle extended content.';
        
        await tester.pumpWidget(createTestWidget(
          const ErrorText(errorText),
        ));

        expect(tester.takeException(), isNull);
        
        // Should display long text without layout errors
        expect(find.text(errorText), findsOneWidget);
        
        // Should maintain error styling for long text
        final textWidget = tester.widget<Text>(find.text(errorText));
        expect(textWidget.style!.color, equals(AppColors.error));
      });

      testWidgets('should handle special characters', (WidgetTester tester) async {
        // ULTRATHINK: Test Swedish characters and special symbols
        const errorText = 'Fel: Åtgärden kunde inte utföras! Försök igen. 🚨';
        
        await tester.pumpWidget(createTestWidget(
          const ErrorText(errorText),
        ));

        expect(tester.takeException(), isNull);
        
        // Should display Swedish characters and emoji
        expect(find.text(errorText), findsOneWidget);
        
        // Should preserve all special characters with error styling
        final textWidget = tester.widget<Text>(find.text(errorText));
        expect(textWidget.data, contains('Å'));
        expect(textWidget.data, contains('ö'));
        expect(textWidget.data, contains('🚨'));
        expect(textWidget.style!.color, equals(AppColors.error));
      });

      testWidgets('should handle whitespace-only text', (WidgetTester tester) async {
        // ULTRATHINK: Test edge case with whitespace
        const errorText = '   \t\n   ';
        
        await tester.pumpWidget(createTestWidget(
          const ErrorText(errorText),
        ));

        expect(tester.takeException(), isNull);
        
        // Should display whitespace as-is
        expect(find.text('   \t\n   '), findsOneWidget);
        
        // Should apply styling to whitespace text
        final textWidget = tester.widget<Text>(find.text('   \t\n   '));
        expect(textWidget.style!.color, equals(AppColors.error));
      });
    });

    group('AppColors Integration', () {
      testWidgets('should use exact AppColors.error value', (WidgetTester tester) async {
        // ULTRATHINK: Test specific color value from AppColors
        const errorText = 'Color value test';
        
        await tester.pumpWidget(createTestWidget(
          const ErrorText(errorText),
        ));

        expect(tester.takeException(), isNull);
        
        // Should use the exact color from AppColors.error
        final textWidget = tester.widget<Text>(find.text('Color value test'));
        expect(textWidget.style!.color, equals(AppColors.error));
        
        // Color should not be null
        expect(textWidget.style!.color, isNotNull);
      });

      testWidgets('should maintain consistent error color across different text', (WidgetTester tester) async {
        // ULTRATHINK: Test color consistency for different content
        await tester.pumpWidget(createTestWidget(
          Column(
            children: const [
              ErrorText('Error 1'),
              ErrorText('Error 2'),
              ErrorText('Error 3'),
            ],
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // All error texts should use the same color
        final textWidgets = tester.widgetList<Text>(find.byType(Text));
        expect(textWidgets.length, equals(3));
        
        for (final textWidget in textWidgets) {
          expect(textWidget.style!.color, equals(AppColors.error));
        }
      });

      testWidgets('should work in different theme contexts', (WidgetTester tester) async {
        // ULTRATHINK: Test color independence from theme
        const errorText = 'Theme test';
        
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData.dark(), // Dark theme to test color independence
          home: Scaffold(
            body: Center(
              child: const ErrorText(errorText),
            ),
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // Should use AppColors.error regardless of theme
        final textWidget = tester.widget<Text>(find.text('Theme test'));
        expect(textWidget.style!.color, equals(AppColors.error));
        
        // Should not inherit theme text color
        expect(textWidget.style!.color, isNot(equals(ThemeData.dark().textTheme.bodyMedium?.color)));
      });
    });

    group('Layout and Constraints', () {
      testWidgets('should work in constrained containers', (WidgetTester tester) async {
        // ULTRATHINK: Test layout behavior in different constraints
        const errorText = 'Constrained test';
        
        await tester.pumpWidget(createTestWidget(
          SizedBox(
            width: 100,
            height: 50,
            child: const ErrorText(errorText),
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // Should render within constraints
        expect(find.text('Constrained test'), findsOneWidget);
        expect(find.byType(SizedBox), findsOneWidget);
        
        // Should maintain error styling in constrained space
        final textWidget = tester.widget<Text>(find.text('Constrained test'));
        expect(textWidget.style!.color, equals(AppColors.error));
      });

      testWidgets('should handle text overflow gracefully', (WidgetTester tester) async {
        // ULTRATHINK: Test behavior with very constrained width
        const errorText = 'This is extremely long error text that will definitely overflow';
        
        await tester.pumpWidget(createTestWidget(
          SizedBox(
            width: 50, // Very narrow to force overflow
            child: const ErrorText(errorText),
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // Should display text even with potential overflow
        expect(find.text(errorText), findsOneWidget);
        
        // Should maintain styling despite layout constraints
        final textWidget = tester.widget<Text>(find.text(errorText));
        expect(textWidget.style!.color, equals(AppColors.error));
      });

      testWidgets('should work in flex layouts', (WidgetTester tester) async {
        // ULTRATHINK: Test in Row/Column layouts
        await tester.pumpWidget(createTestWidget(
          Row(
            children: const [
              ErrorText('Error A'),
              SizedBox(width: 10),
              ErrorText('Error B'),
              SizedBox(width: 10),
              ErrorText('Error C'),
            ],
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // Should render all error texts in Row
        expect(find.text('Error A'), findsOneWidget);
        expect(find.text('Error B'), findsOneWidget);
        expect(find.text('Error C'), findsOneWidget);
        
        // All should maintain error styling
        final textWidgets = tester.widgetList<Text>(find.byType(Text));
        for (final textWidget in textWidgets) {
          expect(textWidget.style!.color, equals(AppColors.error));
        }
      });
    });

    group('API Completeness and Constructor Validation', () {
      testWidgets('should expose required text parameter correctly', (WidgetTester tester) async {
        // ULTRATHINK: Verify constructor API
        expect(() => const ErrorText('test'), returnsNormally);
        
        // Test that text parameter is required and accessible
        const widget = ErrorText('API test');
        expect(widget, isA<Widget>());
        expect(widget.text, equals('API test'));
      });

      testWidgets('should return proper Widget type', (WidgetTester tester) async {
        // ULTRATHINK: Verify return type hierarchy
        const widget = ErrorText('Type test');
        expect(widget, isA<Widget>());
        expect(widget, isA<StatelessWidget>());
        expect(widget, isA<ErrorText>());
      });

      testWidgets('should maintain StatelessWidget behavior', (WidgetTester tester) async {
        // ULTRATHINK: Test stateless widget behavior - multiple builds should be identical
        const errorText = 'Consistency test';
        Widget createSameWidget() => const ErrorText(errorText);
        
        await tester.pumpWidget(createTestWidget(createSameWidget()));
        expect(tester.takeException(), isNull);
        
        // First build
        var textWidget = tester.widget<Text>(find.text('Consistency test'));
        expect(textWidget.data, equals('Consistency test'));
        expect(textWidget.style!.color, equals(AppColors.error));
        
        // Rebuild with same parameters should produce identical results
        await tester.pumpWidget(createTestWidget(createSameWidget()));
        expect(tester.takeException(), isNull);
        
        textWidget = tester.widget<Text>(find.text('Consistency test'));
        expect(textWidget.data, equals('Consistency test'));
        expect(textWidget.style!.color, equals(AppColors.error));
      });

      testWidgets('should work with key parameter', (WidgetTester tester) async {
        // ULTRATHINK: Test key parameter inheritance from StatelessWidget
        const testKey = Key('error-text-key');
        const errorText = 'Key test';
        
        await tester.pumpWidget(createTestWidget(
          const ErrorText(
            errorText,
            key: testKey,
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // Should accept and use key parameter
        expect(find.byKey(testKey), findsOneWidget);
        expect(find.text('Key test'), findsOneWidget);
      });
    });

    group('Production Code Intention Testing', () {
      testWidgets('should provide consistent error text styling across application', (WidgetTester tester) async {
        // ULTRATHINK: Test the code intention - consistent error text styling
        await tester.pumpWidget(createTestWidget(
          Column(
            children: const [
              ErrorText('Connection failed'),
              ErrorText('Invalid input'),
              ErrorText('Authentication error'),
              ErrorText('Network timeout'),
            ],
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // Should provide consistent styling for all error messages
        final textWidgets = tester.widgetList<Text>(find.byType(Text));
        expect(textWidgets.length, equals(4));
        
        // All should use exactly the same error color
        for (final textWidget in textWidgets) {
          expect(textWidget.style, isNotNull);
          expect(textWidget.style!.color, equals(AppColors.error));
          
          // Should use const TextStyle (same instance for all)
          expect(textWidget.style, isA<TextStyle>());
        }
      });

      testWidgets('should serve as reusable error text component', (WidgetTester tester) async {
        // ULTRATHINK: Test reusability intention for different error scenarios
        await tester.pumpWidget(createTestWidget(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('Form Validation:'),
              ErrorText('Email is required'),
              SizedBox(height: 8),
              Text('Network Status:'),
              ErrorText('Connection lost'),
              SizedBox(height: 8),
              Text('User Action:'),
              ErrorText('Action not permitted'),
            ],
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // Should work as reusable component for different error types
        expect(find.text('Email is required'), findsOneWidget);
        expect(find.text('Connection lost'), findsOneWidget);
        expect(find.text('Action not permitted'), findsOneWidget);
        
        // All error texts should have identical styling
        final errorTexts = [
          tester.widget<Text>(find.text('Email is required')),
          tester.widget<Text>(find.text('Connection lost')),
          tester.widget<Text>(find.text('Action not permitted')),
        ];
        
        for (final errorText in errorTexts) {
          expect(errorText.style!.color, equals(AppColors.error));
        }
      });

      testWidgets('should integrate seamlessly with other UI components', (WidgetTester tester) async {
        // ULTRATHINK: Test integration with common UI patterns
        await tester.pumpWidget(createTestWidget(
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text('Status', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const ErrorText('System error detected'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {},
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // Should integrate well with other widgets in complex layouts
        expect(find.byType(Card), findsOneWidget);
        expect(find.text('Status'), findsOneWidget);
        expect(find.text('System error detected'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
        
        // Error text should maintain its styling within complex UI
        final errorText = tester.widget<Text>(find.text('System error detected'));
        expect(errorText.style!.color, equals(AppColors.error));
      });
    });
  });
}