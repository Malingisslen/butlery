// test/widget/messaging/error_list_tile_ultrathink_test.dart
// Comprehensive tests for ErrorListTile using ultrathink methodology
// 
// ULTRATHINK ANALYSIS: ErrorListTile widget (28 lines)
// - StatelessWidget with three required parameters: IconData icon, String title, VoidCallback onTap
// - ListTile widget with leading Icon, title ErrorText, and onTap callback
// - Error theming: Icon uses AppColors.error color, title uses ErrorText widget
// - Dependencies: Uses ErrorText widget for consistent error text styling
// - Simple error action component for consistent error-related user interactions

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/messaging/error_list_tile.dart';
import 'package:butlery/widgets/messaging/error_text.dart';
import 'package:butlery/theme/app_colors.dart';

void main() {
  group('ErrorListTile Widget Tests - ULTRATHINK METHODOLOGY', () {
    // Helper to create test environment
    Widget createTestWidget(Widget child) {
      return MaterialApp(
        home: Scaffold(
          body: child,
        ),
      );
    }

    group('Basic Constructor and Rendering', () {
      testWidgets('should create widget with required parameters', (WidgetTester tester) async {
        // ULTRATHINK: Test production code lines 13-18 constructor with required parameters
        bool tapCalled = false;
        
        await tester.pumpWidget(createTestWidget(
          ErrorListTile(
            icon: Icons.error,
            title: 'Error action',
            onTap: () {
              tapCalled = true;
            },
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // Should display the ErrorListTile
        expect(find.byType(ErrorListTile), findsOneWidget);
        expect(find.byType(ListTile), findsOneWidget);
        
        // Should not have called tap yet
        expect(tapCalled, isFalse);
      });

      testWidgets('should create ListTile as main widget', (WidgetTester tester) async {
        // ULTRATHINK: Test production code lines 22-26 ListTile creation
        await tester.pumpWidget(createTestWidget(
          ErrorListTile(
            icon: Icons.warning,
            title: 'ListTile test',
            onTap: () {},
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // Should create ListTile as main widget
        expect(find.byType(ListTile), findsOneWidget);
        
        // Should display the title text
        expect(find.text('ListTile test'), findsOneWidget);
        
        // Should display the icon
        expect(find.byIcon(Icons.warning), findsOneWidget);
      });

      testWidgets('should set leading icon with error color', (WidgetTester tester) async {
        // ULTRATHINK: Test production code line 23 leading Icon with AppColors.error
        await tester.pumpWidget(createTestWidget(
          ErrorListTile(
            icon: Icons.delete,
            title: 'Icon test',
            onTap: () {},
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // Should create Icon widget with correct properties
        expect(find.byIcon(Icons.delete), findsOneWidget);
        
        final iconWidget = tester.widget<Icon>(find.byIcon(Icons.delete));
        expect(iconWidget.icon, equals(Icons.delete));
        expect(iconWidget.color, equals(AppColors.error));
      });

      testWidgets('should use ErrorText for title', (WidgetTester tester) async {
        // ULTRATHINK: Test production code line 24 title ErrorText(title)
        await tester.pumpWidget(createTestWidget(
          ErrorListTile(
            icon: Icons.info,
            title: 'ErrorText test',
            onTap: () {},
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // Should create ErrorText widget for title
        expect(find.byType(ErrorText), findsOneWidget);
        
        // ErrorText should contain the title text
        final errorText = tester.widget<ErrorText>(find.byType(ErrorText));
        expect(errorText.text, equals('ErrorText test'));
        
        // Should display the text with error styling
        expect(find.text('ErrorText test'), findsOneWidget);
      });

      testWidgets('should handle onTap callback', (WidgetTester tester) async {
        // ULTRATHINK: Test production code line 25 onTap: onTap
        bool tapCalled = false;
        
        await tester.pumpWidget(createTestWidget(
          ErrorListTile(
            icon: Icons.touch_app,
            title: 'Tap test',
            onTap: () {
              tapCalled = true;
            },
          ),
        ));

        expect(tester.takeException(), isNull);
        expect(tapCalled, isFalse);
        
        // Tap the ListTile
        await tester.tap(find.byType(ListTile));
        await tester.pump();
        
        // Should have called the callback
        expect(tapCalled, isTrue);
      });
    });

    group('Icon Parameter Testing', () {
      testWidgets('should handle different icon types', (WidgetTester tester) async {
        // ULTRATHINK: Test various IconData values
        final icons = [Icons.error, Icons.warning, Icons.info, Icons.delete, Icons.refresh];
        
        for (final icon in icons) {
          await tester.pumpWidget(createTestWidget(
            ErrorListTile(
              icon: icon,
              title: 'Icon: ${icon.codePoint}',
              onTap: () {},
            ),
          ));

          expect(tester.takeException(), isNull);
          
          // Should display the specific icon
          expect(find.byIcon(icon), findsOneWidget);
          
          // Should apply error color to any icon
          final iconWidget = tester.widget<Icon>(find.byIcon(icon));
          expect(iconWidget.color, equals(AppColors.error));
        }
      });

      testWidgets('should handle custom icons', (WidgetTester tester) async {
        // ULTRATHINK: Test custom IconData
        const customIcon = IconData(0xe000, fontFamily: 'MaterialIcons');
        
        await tester.pumpWidget(createTestWidget(
          ErrorListTile(
            icon: customIcon,
            title: 'Custom icon',
            onTap: () {},
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // Should handle custom icon data
        expect(find.byIcon(customIcon), findsOneWidget);
        
        final iconWidget = tester.widget<Icon>(find.byIcon(customIcon));
        expect(iconWidget.icon, equals(customIcon));
        expect(iconWidget.color, equals(AppColors.error));
      });

      testWidgets('should maintain icon styling consistency', (WidgetTester tester) async {
        // ULTRATHINK: Test that all icons get same error styling
        await tester.pumpWidget(createTestWidget(
          Column(
            children: [
              ErrorListTile(icon: Icons.error, title: 'Error 1', onTap: () {}),
              ErrorListTile(icon: Icons.warning, title: 'Warning 1', onTap: () {}),
              ErrorListTile(icon: Icons.info, title: 'Info 1', onTap: () {}),
            ],
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // All icons should use the same error color
        final iconWidgets = tester.widgetList<Icon>(find.byType(Icon));
        expect(iconWidgets.length, equals(3));
        
        for (final iconWidget in iconWidgets) {
          expect(iconWidget.color, equals(AppColors.error));
        }
      });
    });

    group('Title Parameter Testing', () {
      testWidgets('should handle different title strings', (WidgetTester tester) async {
        // ULTRATHINK: Test various title content
        final titles = [
          'Simple error',
          'Connection failed! Please try again.',
          'Åtgärden kunde inte slutföras',
          'Error with emoji 🚨',
          'Multi-line\nerror\nmessage',
        ];
        
        for (final title in titles) {
          await tester.pumpWidget(createTestWidget(
            ErrorListTile(
              icon: Icons.error,
              title: title,
              onTap: () {},
            ),
          ));

          expect(tester.takeException(), isNull);
          
          // Should display the title text
          expect(find.text(title), findsOneWidget);
          
          // Should use ErrorText widget
          expect(find.byType(ErrorText), findsOneWidget);
          
          final errorText = tester.widget<ErrorText>(find.byType(ErrorText));
          expect(errorText.text, equals(title));
        }
      });

      testWidgets('should handle empty title', (WidgetTester tester) async {
        // ULTRATHINK: Test edge case with empty title
        await tester.pumpWidget(createTestWidget(
          ErrorListTile(
            icon: Icons.error,
            title: '',
            onTap: () {},
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // Should handle empty title gracefully
        expect(find.text(''), findsOneWidget);
        expect(find.byType(ErrorText), findsOneWidget);
        
        final errorText = tester.widget<ErrorText>(find.byType(ErrorText));
        expect(errorText.text, equals(''));
      });

      testWidgets('should handle very long title', (WidgetTester tester) async {
        // ULTRATHINK: Test long title handling
        const longTitle = 'This is an extremely long error message that might cause layout issues if not handled properly by the ListTile widget and ErrorText component working together.';
        
        await tester.pumpWidget(createTestWidget(
          ErrorListTile(
            icon: Icons.error,
            title: longTitle,
            onTap: () {},
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // Should display long title
        expect(find.text(longTitle), findsOneWidget);
        expect(find.byType(ErrorText), findsOneWidget);
        
        final errorText = tester.widget<ErrorText>(find.byType(ErrorText));
        expect(errorText.text, equals(longTitle));
      });

      testWidgets('should maintain ErrorText styling in title', (WidgetTester tester) async {
        // ULTRATHINK: Test that title uses ErrorText styling
        await tester.pumpWidget(createTestWidget(
          ErrorListTile(
            icon: Icons.error,
            title: 'Styled title test',
            onTap: () {},
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // Should use ErrorText which applies AppColors.error styling
        final errorText = tester.widget<ErrorText>(find.byType(ErrorText));
        expect(errorText.text, equals('Styled title test'));
        
        // The underlying Text widget should have error color
        final textWidget = tester.widget<Text>(find.text('Styled title test'));
        expect(textWidget.style!.color, equals(AppColors.error));
      });
    });

    group('OnTap Callback Testing', () {
      testWidgets('should execute onTap when tapped', (WidgetTester tester) async {
        // ULTRATHINK: Test callback execution
        int tapCount = 0;
        
        await tester.pumpWidget(createTestWidget(
          ErrorListTile(
            icon: Icons.touch_app,
            title: 'Tap counter',
            onTap: () {
              tapCount++;
            },
          ),
        ));

        expect(tester.takeException(), isNull);
        expect(tapCount, equals(0));
        
        // Tap multiple times
        await tester.tap(find.byType(ListTile));
        await tester.pump();
        expect(tapCount, equals(1));
        
        await tester.tap(find.byType(ListTile));
        await tester.pump();
        expect(tapCount, equals(2));
      });

      testWidgets('should handle onTap with complex callback', (WidgetTester tester) async {
        // ULTRATHINK: Test complex callback scenarios
        final results = <String>[];
        
        await tester.pumpWidget(createTestWidget(
          ErrorListTile(
            icon: Icons.code,
            title: 'Complex callback',
            onTap: () {
              results.add('executed');
              results.add('completed');
            },
          ),
        ));

        expect(tester.takeException(), isNull);
        expect(results, isEmpty);
        
        // Tap and verify complex callback execution
        await tester.tap(find.byType(ListTile));
        await tester.pump();
        
        expect(results, equals(['executed', 'completed']));
      });

      testWidgets('should handle onTap with exception gracefully', (WidgetTester tester) async {
        // ULTRATHINK: Test callback exception handling
        await tester.pumpWidget(createTestWidget(
          ErrorListTile(
            icon: Icons.bug_report,
            title: 'Exception test',
            onTap: () {
              throw Exception('Test exception');
            },
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // Tap will cause exception but widget should remain
        await tester.tap(find.byType(ListTile));
        await tester.pump();
        
        // Exception should be caught by framework
        expect(tester.takeException(), isA<Exception>());
        
        // Widget should still be present after exception
        expect(find.byType(ErrorListTile), findsOneWidget);
      });

      testWidgets('should allow onTap to modify external state', (WidgetTester tester) async {
        // ULTRATHINK: Test stateful callback interactions
        String status = 'initial';
        
        await tester.pumpWidget(createTestWidget(
          ErrorListTile(
            icon: Icons.edit,
            title: 'State modifier',
            onTap: () {
              status = 'modified';
            },
          ),
        ));

        expect(tester.takeException(), isNull);
        expect(status, equals('initial'));
        
        // Callback should modify external state
        await tester.tap(find.byType(ListTile));
        await tester.pump();
        
        expect(status, equals('modified'));
      });
    });

    group('Layout and Integration', () {
      testWidgets('should work in ListView', (WidgetTester tester) async {
        // ULTRATHINK: Test ListView integration
        await tester.pumpWidget(createTestWidget(
          ListView(
            children: [
              ErrorListTile(icon: Icons.error, title: 'Error 1', onTap: () {}),
              ErrorListTile(icon: Icons.warning, title: 'Warning 1', onTap: () {}),
              ErrorListTile(icon: Icons.info, title: 'Info 1', onTap: () {}),
            ],
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // Should render all items in ListView
        expect(find.byType(ErrorListTile), findsNWidgets(3));
        expect(find.text('Error 1'), findsOneWidget);
        expect(find.text('Warning 1'), findsOneWidget);
        expect(find.text('Info 1'), findsOneWidget);
      });

      testWidgets('should work in constrained containers', (WidgetTester tester) async {
        // ULTRATHINK: Test constrained layout behavior
        await tester.pumpWidget(createTestWidget(
          SizedBox(
            width: 200,
            height: 100,
            child: ErrorListTile(
              icon: Icons.crop,
              title: 'Constrained tile',
              onTap: () {},
            ),
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // Should render within constraints
        expect(find.text('Constrained tile'), findsOneWidget);
        expect(find.byIcon(Icons.crop), findsOneWidget);
        expect(find.byType(SizedBox), findsAtLeastNWidgets(1));
      });

      testWidgets('should maintain proper ListTile structure', (WidgetTester tester) async {
        // ULTRATHINK: Test ListTile internal structure
        await tester.pumpWidget(createTestWidget(
          ErrorListTile(
            icon: Icons.account_tree,
            title: 'Structure test',
            onTap: () {},
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // Should have proper ListTile structure
        final listTile = tester.widget<ListTile>(find.byType(ListTile));
        
        // Leading should be Icon widget
        expect(listTile.leading, isA<Icon>());
        final leadingIcon = listTile.leading as Icon;
        expect(leadingIcon.icon, equals(Icons.account_tree));
        expect(leadingIcon.color, equals(AppColors.error));
        
        // Title should be ErrorText widget
        expect(listTile.title, isA<ErrorText>());
        final titleErrorText = listTile.title as ErrorText;
        expect(titleErrorText.text, equals('Structure test'));
        
        // OnTap should be set
        expect(listTile.onTap, isNotNull);
      });
    });

    group('Error Theming Consistency', () {
      testWidgets('should maintain consistent error theming', (WidgetTester tester) async {
        // ULTRATHINK: Test consistent error color application
        await tester.pumpWidget(createTestWidget(
          ErrorListTile(
            icon: Icons.palette,
            title: 'Theming test',
            onTap: () {},
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // Both icon and title should use AppColors.error
        final iconWidget = tester.widget<Icon>(find.byIcon(Icons.palette));
        expect(iconWidget.color, equals(AppColors.error));
        
        final textWidget = tester.widget<Text>(find.text('Theming test'));
        expect(textWidget.style!.color, equals(AppColors.error));
      });

      testWidgets('should work across different themes', (WidgetTester tester) async {
        // ULTRATHINK: Test theme independence
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: ErrorListTile(
              icon: Icons.dark_mode,
              title: 'Dark theme test',
              onTap: () {},
            ),
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // Should use AppColors.error regardless of theme
        final iconWidget = tester.widget<Icon>(find.byIcon(Icons.dark_mode));
        expect(iconWidget.color, equals(AppColors.error));
        
        final textWidget = tester.widget<Text>(find.text('Dark theme test'));
        expect(textWidget.style!.color, equals(AppColors.error));
      });

      testWidgets('should integrate with ErrorText styling', (WidgetTester tester) async {
        // ULTRATHINK: Test ErrorText integration
        await tester.pumpWidget(createTestWidget(
          Column(
            children: [
              const ErrorText('Standalone error'),
              ErrorListTile(
                icon: Icons.integration_instructions,
                title: 'Integrated error',
                onTap: () {},
              ),
            ],
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // Both ErrorText widgets should have identical styling
        final textWidgets = tester.widgetList<Text>(find.byType(Text));
        expect(textWidgets.length, equals(2));
        
        final standaloneText = textWidgets.firstWhere((w) => w.data == 'Standalone error');
        final integratedText = textWidgets.firstWhere((w) => w.data == 'Integrated error');
        
        expect(standaloneText.style!.color, equals(AppColors.error));
        expect(integratedText.style!.color, equals(AppColors.error));
        expect(standaloneText.style!.color, equals(integratedText.style!.color));
      });
    });

    group('API Completeness and Constructor Validation', () {
      testWidgets('should expose all required parameters correctly', (WidgetTester tester) async {
        // ULTRATHINK: Verify constructor API
        expect(() => ErrorListTile(icon: Icons.check, title: 'test', onTap: () {}), returnsNormally);
        
        // Test that all parameters are required and accessible
        final widget = ErrorListTile(icon: Icons.api, title: 'API test', onTap: () {});
        expect(widget, isA<Widget>());
        expect(widget.icon, equals(Icons.api));
        expect(widget.title, equals('API test'));
        expect(widget.onTap, isNotNull);
      });

      testWidgets('should return proper Widget type', (WidgetTester tester) async {
        // ULTRATHINK: Verify return type hierarchy
        final widget = ErrorListTile(icon: Icons.type_specimen, title: 'Type test', onTap: () {});
        expect(widget, isA<Widget>());
        expect(widget, isA<StatelessWidget>());
        expect(widget, isA<ErrorListTile>());
      });

      testWidgets('should maintain StatelessWidget behavior', (WidgetTester tester) async {
        // ULTRATHINK: Test stateless widget behavior - multiple builds should be identical
        Widget createSameWidget() => ErrorListTile(icon: Icons.check_circle, title: 'Consistency test', onTap: () {});
        
        await tester.pumpWidget(createTestWidget(createSameWidget()));
        expect(tester.takeException(), isNull);
        
        // First build
        expect(find.byIcon(Icons.check_circle), findsOneWidget);
        expect(find.text('Consistency test'), findsOneWidget);
        
        // Rebuild with same parameters should produce identical results
        await tester.pumpWidget(createTestWidget(createSameWidget()));
        expect(tester.takeException(), isNull);
        
        expect(find.byIcon(Icons.check_circle), findsOneWidget);
        expect(find.text('Consistency test'), findsOneWidget);
      });

      testWidgets('should work with key parameter', (WidgetTester tester) async {
        // ULTRATHINK: Test key parameter inheritance from StatelessWidget
        const testKey = Key('error-list-tile-key');
        
        await tester.pumpWidget(createTestWidget(
          ErrorListTile(
            key: testKey,
            icon: Icons.key,
            title: 'Key test',
            onTap: () {},
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // Should accept and use key parameter
        expect(find.byKey(testKey), findsOneWidget);
        expect(find.text('Key test'), findsOneWidget);
      });
    });

    group('Production Code Intention Testing', () {
      testWidgets('should provide consistent error action interface', (WidgetTester tester) async {
        // ULTRATHINK: Test the code intention - error action interface
        int retryCount = 0;
        int deleteCount = 0;
        
        await tester.pumpWidget(createTestWidget(
          Column(
            children: [
              ErrorListTile(
                icon: Icons.refresh,
                title: 'Retry connection',
                onTap: () { retryCount++; },
              ),
              ErrorListTile(
                icon: Icons.delete,
                title: 'Delete failed item',
                onTap: () { deleteCount++; },
              ),
            ],
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // Should provide consistent interface for error actions
        await tester.tap(find.text('Retry connection'));
        await tester.pump();
        expect(retryCount, equals(1));
        
        await tester.tap(find.text('Delete failed item'));
        await tester.pump();
        expect(deleteCount, equals(1));
        
        // Both should maintain consistent error styling
        final iconWidgets = tester.widgetList<Icon>(find.byType(Icon));
        for (final iconWidget in iconWidgets) {
          expect(iconWidget.color, equals(AppColors.error));
        }
      });

      testWidgets('should serve as reusable error action component', (WidgetTester tester) async {
        // ULTRATHINK: Test reusability for different error scenarios
        await tester.pumpWidget(createTestWidget(
          ListView(
            children: [
              ErrorListTile(icon: Icons.wifi_off, title: 'Connection lost', onTap: () {}),
              ErrorListTile(icon: Icons.storage, title: 'Storage full', onTap: () {}),
              ErrorListTile(icon: Icons.security, title: 'Authentication failed', onTap: () {}),
              ErrorListTile(icon: Icons.sync_problem, title: 'Sync error', onTap: () {}),
            ],
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // Should work for different error types with consistent styling
        expect(find.byType(ErrorListTile), findsNWidgets(4));
        
        final titles = ['Connection lost', 'Storage full', 'Authentication failed', 'Sync error'];
        for (final title in titles) {
          expect(find.text(title), findsOneWidget);
        }
        
        // All should use ErrorText for consistent styling
        expect(find.byType(ErrorText), findsNWidgets(4));
      });

      testWidgets('should integrate with error handling workflows', (WidgetTester tester) async {
        // ULTRATHINK: Test integration with error handling patterns
        final errorActions = <String>[];
        
        await tester.pumpWidget(createTestWidget(
          Card(
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: ErrorText('Multiple errors occurred:'),
                ),
                ErrorListTile(
                  icon: Icons.warning,
                  title: 'Network timeout',
                  onTap: () { errorActions.add('retry_network'); },
                ),
                ErrorListTile(
                  icon: Icons.error,
                  title: 'Invalid data',
                  onTap: () { errorActions.add('fix_data'); },
                ),
              ],
            ),
          ),
        ));

        expect(tester.takeException(), isNull);
        
        // Should integrate well in error handling UI
        expect(find.text('Multiple errors occurred:'), findsOneWidget);
        expect(find.text('Network timeout'), findsOneWidget);
        expect(find.text('Invalid data'), findsOneWidget);
        
        // Actions should work in workflow context
        await tester.tap(find.text('Network timeout'));
        await tester.tap(find.text('Invalid data'));
        await tester.pump();
        
        expect(errorActions, equals(['retry_network', 'fix_data']));
      });
    });
  });
}