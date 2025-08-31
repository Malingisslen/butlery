// test/widget/common/source_url_display_ultrathink_test.dart
// Comprehensive tests for SourceUrlDisplay using ultrathink methodology
// 
// ULTRATHINK ANALYSIS: SourceUrlDisplay widget (49 lines)
// - Simple StatelessWidget with single required String sourceUrl parameter
// - Container with full width styling: AppColors.backgroundTint, border, AppDimensions.paddingL
// - Row structure: Icon (Icons.link) + SizedBox spacing + Expanded Text
// - Swedish localization: 'Importerat från: $sourceUrl' (line 37)
// - Text overflow handling: maxLines: 1, TextOverflow.ellipsis (lines 41-42)
// - Theme integration: colorScheme.onSurfaceVariant for icon, AppColors.textMedium for text

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/source_url_display.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';

void main() {
  group('SourceUrlDisplay Widget Tests - ULTRATHINK METHODOLOGY', () {
    // Helper to create test environment
    Widget createTestWidget(Widget child) {
      return MaterialApp(
        theme: ThemeData(
          colorScheme: const ColorScheme.light(
            onSurfaceVariant: Colors.grey,
            surface: Colors.white,
            onSurface: Colors.black,
          ),
          textTheme: const TextTheme(
            bodySmall: TextStyle(fontSize: 14.0, color: Colors.black),
          ),
        ),
        home: Scaffold(
          body: Center(child: child),
        ),
      );
    }

    group('Basic Constructor and Rendering', () {
      testWidgets('should create widget with simple URL', (WidgetTester tester) async {
        // ULTRATHINK: Test production code lines 12-15 constructor with required sourceUrl
        const testUrl = 'https://example.com';
        
        await tester.pumpWidget(createTestWidget(
          const SourceUrlDisplay(sourceUrl: testUrl),
        ));

        expect(tester.takeException(), isNull);
        
        // Should display the widget with Swedish text (line 37)
        expect(find.text('Importerat från: $testUrl'), findsOneWidget);
        expect(find.byType(SourceUrlDisplay), findsOneWidget);
      });

      testWidgets('should maintain Container widget structure', (WidgetTester tester) async {
        // ULTRATHINK: Test production code lines 19-26 Container structure
        const testUrl = 'https://test.com';
        
        await tester.pumpWidget(createTestWidget(
          const SourceUrlDisplay(sourceUrl: testUrl),
        ));

        expect(tester.takeException(), isNull);
        
        // Should create Container as main structure (line 19)
        expect(find.byType(Container), findsOneWidget);
        
        // Container should have proper styling
        final container = tester.widget<Container>(find.byType(Container));
        expect(container.decoration, isA<BoxDecoration>());
        
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, equals(AppColors.backgroundTint));
        expect(decoration.borderRadius, isA<BorderRadius>());
        expect(decoration.border, isA<Border>());
      });

      testWidgets('should display Row with Icon and Text', (WidgetTester tester) async {
        // ULTRATHINK: Test production code lines 27-46 Row structure
        const testUrl = 'https://layout-test.com';
        
        await tester.pumpWidget(createTestWidget(
          const SourceUrlDisplay(sourceUrl: testUrl),
        ));

        expect(tester.takeException(), isNull);
        
        // Should create Row with 3 children: Icon + SizedBox + Expanded (line 27)
        expect(find.byType(Row), findsOneWidget);
        final row = tester.widget<Row>(find.byType(Row));
        expect(row.children.length, equals(3));
        expect(row.children[0], isA<Icon>());
        expect(row.children[1], isA<SizedBox>());
        expect(row.children[2], isA<Expanded>());
        
        // Should display link icon (line 30)
        expect(find.byIcon(Icons.link), findsOneWidget);
        
        // Should display Swedish text with URL
        expect(find.text('Importerat från: $testUrl'), findsOneWidget);
      });

      testWidgets('should apply correct Container styling', (WidgetTester tester) async {
        // ULTRATHINK: Test production code lines 19-26 Container decoration
        const testUrl = 'https://styling-test.com';
        
        await tester.pumpWidget(createTestWidget(
          const SourceUrlDisplay(sourceUrl: testUrl),
        ));

        expect(tester.takeException(), isNull);
        
        final container = tester.widget<Container>(find.byType(Container));
        
        // Should have full width (line 20)
        expect(container.constraints?.minWidth, equals(double.infinity));
        
        // Should have proper padding (line 21)
        expect(container.padding, equals(const EdgeInsets.all(AppDimensions.paddingL)));
        
        // Should have proper decoration (lines 22-26)
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, equals(AppColors.backgroundTint));
        expect(decoration.borderRadius, equals(BorderRadius.circular(AppDimensions.borderRadiusM)));
        expect(decoration.border, equals(Border.all(color: AppColors.divider)));
      });
    });

    group('Theme Integration and Styling', () {
      testWidgets('should apply correct icon styling', (WidgetTester tester) async {
        // ULTRATHINK: Test production code lines 29-33 Icon styling
        const testUrl = 'https://icon-test.com';
        
        await tester.pumpWidget(createTestWidget(
          const SourceUrlDisplay(sourceUrl: testUrl),
        ));

        expect(tester.takeException(), isNull);
        
        // Should use Icons.link (line 30)
        final icon = tester.widget<Icon>(find.byIcon(Icons.link));
        expect(icon.icon, equals(Icons.link));
        
        // Should use correct size (line 31)
        expect(icon.size, equals(AppDimensions.iconSizeM));
        
        // Should use theme color (line 32)
        expect(icon.color, equals(Colors.grey)); // From test theme colorScheme.onSurfaceVariant
      });

      testWidgets('should apply correct text styling', (WidgetTester tester) async {
        // ULTRATHINK: Test production code lines 36-43 Text styling
        const testUrl = 'https://text-style-test.com';
        
        await tester.pumpWidget(createTestWidget(
          const SourceUrlDisplay(sourceUrl: testUrl),
        ));

        expect(tester.takeException(), isNull);
        
        // Should create Text with proper styling
        final textWidget = tester.widget<Text>(find.text('Importerat från: $testUrl'));
        expect(textWidget.style, isNotNull);
        
        // Should use AppTextStyles.bodySmall as base (line 38)
        expect(textWidget.style!.fontSize, equals(AppTextStyles.bodySmall.fontSize));
        
        // Should override color with AppColors.textMedium (line 39)
        expect(textWidget.style!.color, equals(AppColors.textMedium));
        
        // Should set text overflow properties (lines 41-42)
        expect(textWidget.maxLines, equals(1));
        expect(textWidget.overflow, equals(TextOverflow.ellipsis));
      });

      testWidgets('should work with different theme configurations', (WidgetTester tester) async {
        // ULTRATHINK: Test theme integration robustness
        const testUrl = 'https://theme-test.com';
        
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              colorScheme: const ColorScheme.dark(
                onSurfaceVariant: Colors.lightBlue,
                surface: Colors.black,
                onSurface: Colors.white,
              ),
            ),
            home: Scaffold(
              body: Center(
                child: const SourceUrlDisplay(sourceUrl: testUrl),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        
        // Should adapt icon color to theme
        final icon = tester.widget<Icon>(find.byIcon(Icons.link));
        expect(icon.color, equals(Colors.lightBlue)); // Dark theme onSurfaceVariant
        
        // Text color should still use AppColors.textMedium (not theme dependent)
        final textWidget = tester.widget<Text>(find.text('Importerat från: $testUrl'));
        expect(textWidget.style!.color, equals(AppColors.textMedium));
      });

      testWidgets('should maintain SizedBox spacing in Row structure', (WidgetTester tester) async {
        // ULTRATHINK: Test production code line 34 SizedBox spacing
        const testUrl = 'https://spacing-test.com';
        
        await tester.pumpWidget(createTestWidget(
          const SourceUrlDisplay(sourceUrl: testUrl),
        ));

        expect(tester.takeException(), isNull);
        
        // Should have proper Row structure with 3 children (Icon + SizedBox + Expanded)
        final row = tester.widget<Row>(find.byType(Row));
        expect(row.children.length, equals(3));
        expect(row.children[0], isA<Icon>());
        expect(row.children[1], isA<SizedBox>());
        expect(row.children[2], isA<Expanded>());
        
        // Verify the middle child is the spacing SizedBox
        final spacingSizedBox = row.children[1] as SizedBox;
        expect(spacingSizedBox.width, equals(AppDimensions.spacingS));
        expect(spacingSizedBox.height, isNull); // Should not constrain height
      });
    });

    group('Swedish Localization and Text Handling', () {
      testWidgets('should display Swedish "Importerat från" text', (WidgetTester tester) async {
        // ULTRATHINK: Test production code line 37 Swedish localization
        const testUrl = 'https://swedish-test.com';
        
        await tester.pumpWidget(createTestWidget(
          const SourceUrlDisplay(sourceUrl: testUrl),
        ));

        expect(tester.takeException(), isNull);
        
        // Should display Swedish text prefix
        expect(find.text('Importerat från: $testUrl'), findsOneWidget);
        
        // Should contain Swedish characters properly
        final textWidget = tester.widget<Text>(find.text('Importerat från: $testUrl'));
        expect(textWidget.data, contains('Importerat från:'));
        expect(textWidget.data, contains(testUrl));
      });

      testWidgets('should handle URLs with Swedish domains', (WidgetTester tester) async {
        // ULTRATHINK: Test with Swedish domain names
        const testUrl = 'https://svenska-recept.se/måltid';
        
        await tester.pumpWidget(createTestWidget(
          const SourceUrlDisplay(sourceUrl: testUrl),
        ));

        expect(tester.takeException(), isNull);
        
        // Should display Swedish characters in URLs correctly
        expect(find.text('Importerat från: $testUrl'), findsOneWidget);
        
        final textWidget = tester.widget<Text>(find.text('Importerat från: $testUrl'));
        expect(textWidget.data, contains('svenska-recept.se'));
        expect(textWidget.data, contains('måltid'));
      });

      testWidgets('should handle special URL characters', (WidgetTester tester) async {
        // ULTRATHINK: Test with special URL characters
        const testUrl = 'https://example.com/path?param=value&other=123#fragment';
        
        await tester.pumpWidget(createTestWidget(
          const SourceUrlDisplay(sourceUrl: testUrl),
        ));

        expect(tester.takeException(), isNull);
        
        // Should display all URL characters correctly
        expect(find.text('Importerat från: $testUrl'), findsOneWidget);
        
        final textWidget = tester.widget<Text>(find.text('Importerat från: $testUrl'));
        expect(textWidget.data, contains('?param=value'));
        expect(textWidget.data, contains('&other=123'));
        expect(textWidget.data, contains('#fragment'));
      });
    });

    group('Text Overflow and Layout Behavior', () {
      testWidgets('should handle very long URLs with ellipsis', (WidgetTester tester) async {
        // ULTRATHINK: Test production code lines 41-42 TextOverflow.ellipsis
        const longUrl = 'https://very-very-very-long-domain-name-that-will-definitely-cause-overflow.example.com/with/very/long/path/segments/that/keep/going/and/going/until/overflow/happens/inevitably';
        
        await tester.pumpWidget(createTestWidget(
          SizedBox(
            width: 300, // Constrained width to force overflow
            child: const SourceUrlDisplay(sourceUrl: longUrl),
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // Should create text widget with overflow settings
        final textWidget = tester.widget<Text>(find.text('Importerat från: $longUrl'));
        expect(textWidget.maxLines, equals(1));
        expect(textWidget.overflow, equals(TextOverflow.ellipsis));
        
        // Text should be inside Expanded widget (line 35)
        expect(find.byType(Expanded), findsOneWidget);
      });

      testWidgets('should maintain full width layout', (WidgetTester tester) async {
        // ULTRATHINK: Test production code line 20 double.infinity width
        const testUrl = 'https://width-test.com';
        
        await tester.pumpWidget(createTestWidget(
          const SourceUrlDisplay(sourceUrl: testUrl),
        ));

        expect(tester.takeException(), isNull);
        
        // Container should expand to full available width
        final container = tester.widget<Container>(find.byType(Container));
        expect(container.constraints?.minWidth, equals(double.infinity));
        
        // Should render without layout errors in full width
        expect(find.byType(SourceUrlDisplay), findsOneWidget);
      });

      testWidgets('should work in constrained width containers', (WidgetTester tester) async {
        // ULTRATHINK: Test layout behavior in constrained environments
        const testUrl = 'https://constraint-test.com/path';
        
        await tester.pumpWidget(createTestWidget(
          SizedBox(
            width: 200,
            height: 100,
            child: const SourceUrlDisplay(sourceUrl: testUrl),
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // Should adapt to container constraints without errors
        expect(find.byType(SourceUrlDisplay), findsOneWidget);
        expect(find.text('Importerat från: $testUrl'), findsOneWidget);
        
        // Expanded should handle width constraints properly
        expect(find.byType(Expanded), findsOneWidget);
      });
    });

    group('Edge Cases and Input Validation', () {
      testWidgets('should handle empty URL string', (WidgetTester tester) async {
        // ULTRATHINK: Test edge case with empty URL
        const testUrl = '';
        
        await tester.pumpWidget(createTestWidget(
          const SourceUrlDisplay(sourceUrl: testUrl),
        ));

        expect(tester.takeException(), isNull);
        
        // Should still display Swedish prefix even with empty URL
        expect(find.text('Importerat från: '), findsOneWidget);
        expect(find.byType(SourceUrlDisplay), findsOneWidget);
        
        // Should maintain widget structure
        expect(find.byType(Container), findsOneWidget);
        expect(find.byType(Row), findsOneWidget);
        expect(find.byIcon(Icons.link), findsOneWidget);
      });

      testWidgets('should handle single character URLs', (WidgetTester tester) async {
        // ULTRATHINK: Test minimal URL input
        const testUrl = 'a';
        
        await tester.pumpWidget(createTestWidget(
          const SourceUrlDisplay(sourceUrl: testUrl),
        ));

        expect(tester.takeException(), isNull);
        
        // Should handle single character correctly
        expect(find.text('Importerat från: $testUrl'), findsOneWidget);
        expect(find.byType(SourceUrlDisplay), findsOneWidget);
      });

      testWidgets('should handle URLs with only whitespace', (WidgetTester tester) async {
        // ULTRATHINK: Test whitespace-only URL
        const testUrl = '   ';
        
        await tester.pumpWidget(createTestWidget(
          const SourceUrlDisplay(sourceUrl: testUrl),
        ));

        expect(tester.takeException(), isNull);
        
        // Should display whitespace as-is (no trimming in production code)
        expect(find.text('Importerat från: $testUrl'), findsOneWidget);
        
        // Should maintain structure with whitespace content
        expect(find.byIcon(Icons.link), findsOneWidget);
      });

      testWidgets('should handle URLs with newlines and special whitespace', (WidgetTester tester) async {
        // ULTRATHINK: Test complex whitespace scenarios
        const testUrl = 'https://example.com\nwith\tnewline\rand\ttabs';
        
        await tester.pumpWidget(createTestWidget(
          const SourceUrlDisplay(sourceUrl: testUrl),
        ));

        expect(tester.takeException(), isNull);
        
        // Should display all characters including whitespace
        expect(find.text('Importerat från: $testUrl'), findsOneWidget);
        
        // Should truncate with ellipsis due to maxLines: 1
        final textWidget = tester.widget<Text>(find.text('Importerat från: $testUrl'));
        expect(textWidget.maxLines, equals(1));
      });

      testWidgets('should handle numeric and mixed content URLs', (WidgetTester tester) async {
        // ULTRATHINK: Test various URL formats
        const testUrl = 'https://192.168.1.1:8080/api/v1/data?id=123&token=abc123';
        
        await tester.pumpWidget(createTestWidget(
          const SourceUrlDisplay(sourceUrl: testUrl),
        ));

        expect(tester.takeException(), isNull);
        
        // Should handle IP addresses, ports, paths, and query parameters
        expect(find.text('Importerat från: $testUrl'), findsOneWidget);
        
        final textWidget = tester.widget<Text>(find.text('Importerat från: $testUrl'));
        expect(textWidget.data, contains('192.168.1.1:8080'));
        expect(textWidget.data, contains('api/v1/data'));
        expect(textWidget.data, contains('id=123'));
      });
    });

    group('API Completeness and Constructor Validation', () {
      testWidgets('should expose required sourceUrl parameter', (WidgetTester tester) async {
        // ULTRATHINK: Verify constructor API
        expect(() => const SourceUrlDisplay(sourceUrl: 'test'), returnsNormally);
        
        // Test that sourceUrl is required
        const widget = SourceUrlDisplay(sourceUrl: 'Required URL Test');
        expect(widget, isA<Widget>());
        expect(widget.sourceUrl, equals('Required URL Test'));
      });

      testWidgets('should return proper Widget type', (WidgetTester tester) async {
        // ULTRATHINK: Verify return type
        const widget = SourceUrlDisplay(sourceUrl: 'Type Test');
        expect(widget, isA<Widget>());
        expect(widget, isA<StatelessWidget>());
        expect(widget, isA<SourceUrlDisplay>());
      });

      testWidgets('should maintain StatelessWidget behavior', (WidgetTester tester) async {
        // ULTRATHINK: Test stateless widget behavior - multiple builds should be identical
        const testUrl = 'https://consistency-test.com';
        Widget createSameWidget() => const SourceUrlDisplay(sourceUrl: testUrl);
        
        await tester.pumpWidget(createTestWidget(createSameWidget()));
        expect(tester.takeException(), isNull);
        
        // First build
        var textWidget = tester.widget<Text>(find.text('Importerat från: $testUrl'));
        var icon = tester.widget<Icon>(find.byIcon(Icons.link));
        expect(textWidget.data, equals('Importerat från: $testUrl'));
        expect(textWidget.maxLines, equals(1));
        expect(icon.icon, equals(Icons.link));
        
        // Rebuild with same parameters should produce identical results
        await tester.pumpWidget(createTestWidget(createSameWidget()));
        expect(tester.takeException(), isNull);
        
        textWidget = tester.widget<Text>(find.text('Importerat från: $testUrl'));
        icon = tester.widget<Icon>(find.byIcon(Icons.link));
        expect(textWidget.data, equals('Importerat från: $testUrl'));
        expect(textWidget.maxLines, equals(1));
        expect(icon.icon, equals(Icons.link));
      });

      testWidgets('should work with key parameter', (WidgetTester tester) async {
        // ULTRATHINK: Test key parameter inheritance from StatelessWidget
        const testKey = Key('source-url-key');
        const testUrl = 'https://key-test.com';
        
        await tester.pumpWidget(createTestWidget(
          const SourceUrlDisplay(sourceUrl: testUrl, key: testKey),
        ));

        expect(tester.takeException(), isNull);
        
        // Should accept and use key parameter
        expect(find.byKey(testKey), findsOneWidget);
        expect(find.text('Importerat från: $testUrl'), findsOneWidget);
      });
    });

    group('Production Code Intention Testing', () {
      testWidgets('should create URL source display with visual prominence', (WidgetTester tester) async {
        // ULTRATHINK: Test the code intention - source URL display with clear visual hierarchy
        const testUrl = 'https://recipe-source.com/recipe/123';
        
        await tester.pumpWidget(createTestWidget(
          const SourceUrlDisplay(sourceUrl: testUrl),
        ));

        expect(tester.takeException(), isNull);
        
        // Should create visually distinct container with background and border
        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, isNotNull); // Should have background
        expect(decoration.border, isNotNull); // Should have border for visual separation
        
        // Should include link icon for immediate recognition
        expect(find.byIcon(Icons.link), findsOneWidget);
        
        // Should handle long URLs gracefully with ellipsis
        final textWidget = tester.widget<Text>(find.text('Importerat från: $testUrl'));
        expect(textWidget.overflow, equals(TextOverflow.ellipsis));
      });

      testWidgets('should serve as reusable source attribution component', (WidgetTester tester) async {
        // ULTRATHINK: Test reusability intention for import attribution
        await tester.pumpWidget(createTestWidget(
          Column(
            children: const [
              SourceUrlDisplay(sourceUrl: 'https://allrecipes.com/recipe/1'),
              SizedBox(height: 16),
              SourceUrlDisplay(sourceUrl: 'https://food.com/recipe/2'),
              SizedBox(height: 16),
              SourceUrlDisplay(sourceUrl: 'https://swedish-recipes.se/recept/3'),
            ],
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // Should work as reusable component for multiple sources
        expect(find.byType(SourceUrlDisplay), findsNWidgets(3));
        expect(find.text('Importerat från: https://allrecipes.com/recipe/1'), findsOneWidget);
        expect(find.text('Importerat från: https://food.com/recipe/2'), findsOneWidget);
        expect(find.text('Importerat från: https://swedish-recipes.se/recept/3'), findsOneWidget);
        
        // Each instance should maintain consistent styling
        final containers = tester.widgetList<Container>(find.byType(Container));
        expect(containers.length, equals(3));
        
        // All should use same background color and styling
        for (final container in containers) {
          final decoration = container.decoration as BoxDecoration;
          expect(decoration.color, equals(AppColors.backgroundTint));
          expect(decoration.borderRadius, equals(BorderRadius.circular(AppDimensions.borderRadiusM)));
        }
      });
    });
  });
}