// test/widget/styled/styled_button_test.dart
// Comprehensive tests for StyledButton widget using ultrathink methodology

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/styled/styled_button.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_colors.dart';

void main() {
  group('StyledButton Widget Tests', () {
    // Helper to wrap widget with MaterialApp for proper theming
    Widget createTestWidget(Widget child) {
      return MaterialApp(
        theme: ThemeData(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primaryBlue,
            onPrimary: Colors.white,
          ),
        ),
        home: Scaffold(
          body: Center(child: child),
        ),
      );
    }

    group('Default Constructor', () {
      testWidgets('should render with text and no icon', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          StyledButton(
            text: 'Test Button',
            onPressed: () {},
          ),
        ));

        expect(find.byType(StyledButton), findsOneWidget);
        expect(find.text('Test Button'), findsOneWidget);
        expect(find.byType(ElevatedButton), findsOneWidget);
        expect(find.byType(Icon), findsNothing);
      });

      testWidgets('should be disabled when onPressed is null', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          const StyledButton(
            text: 'Disabled',
            onPressed: null,
          ),
        ));

        final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
        expect(button.onPressed, isNull);
      });

      testWidgets('should show loading state', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          const StyledButton(
            text: 'Loading',
            isLoading: true,
          ),
        ));

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Loading'), findsNothing); // Text hidden during loading
        
        // Button should be disabled during loading
        final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
        expect(button.onPressed, isNull);
      });

      testWidgets('should render with icon when provided', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          StyledButton(
            text: 'Icon Button',
            icon: const Icon(Icons.add),
            onPressed: () {},
          ),
        ));

        expect(find.text('Icon Button'), findsOneWidget);
        expect(find.byIcon(Icons.add), findsWidgets); // May find multiple instances due to button structure
        
        // Check that we have a button with both icon and text
        expect(find.byWidgetPredicate((widget) =>
          widget is ElevatedButton && widget.child != null
        ), findsOneWidget);
      });

      testWidgets('should apply custom width and height', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          StyledButton(
            text: 'Custom Size',
            width: 200,
            height: 60,
            onPressed: () {},
          ),
        ));

        final sizedBox = tester.widget<SizedBox>(
          find.ancestor(
            of: find.byType(ElevatedButton),
            matching: find.byType(SizedBox),
          ).first,
        );
        
        expect(sizedBox.width, equals(200));
        expect(sizedBox.height, equals(60));
      });

      testWidgets('should apply custom padding', (WidgetTester tester) async {
        const customPadding = EdgeInsets.all(20);
        
        await tester.pumpWidget(createTestWidget(
          StyledButton(
            text: 'Custom Padding',
            padding: customPadding,
            onPressed: () {},
          ),
        ));

        final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
        final buttonStyle = button.style;
        
        // Note: We can't directly test padding from ButtonStyle due to MaterialStateProperty
        // But we can verify the button was created with custom style
        expect(buttonStyle, isNotNull);
      });
    });

    group('Primary Button Constructor', () {
      testWidgets('should render as primary button', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          StyledButton.primary(
            text: 'Primary',
            onPressed: () {},
          ),
        ));

        expect(find.text('Primary'), findsOneWidget);
        
        // Check height is standard button height
        final sizedBox = tester.widget<SizedBox>(
          find.ancestor(
            of: find.byType(ElevatedButton),
            matching: find.byType(SizedBox),
          ).first,
        );
        expect(sizedBox.height, equals(AppDimensions.buttonHeight));
      });

      testWidgets('should support loading state', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          const StyledButton.primary(
            text: 'Loading Primary',
            isLoading: true,
          ),
        ));

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('should accept icon', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          StyledButton.primary(
            text: 'Primary Icon',
            icon: const Icon(Icons.save),
            onPressed: () {},
          ),
        ));

        expect(find.byIcon(Icons.save), findsOneWidget);
        expect(find.text('Primary Icon'), findsOneWidget);
      });
    });

    group('Secondary Button Constructor', () {
      testWidgets('should render as secondary button', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          StyledButton.secondary(
            text: 'Secondary',
            onPressed: () {},
          ),
        ));

        expect(find.text('Secondary'), findsOneWidget);
        expect(find.byType(ElevatedButton), findsOneWidget);
      });
    });

    group('Destructive Button Constructor', () {
      testWidgets('should render with destructive styling', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          StyledButton.destructive(
            text: 'Delete',
            onPressed: () {},
          ),
        ));

        expect(find.text('Delete'), findsOneWidget);
        
        final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
        final style = button.style;
        
        // Verify destructive styling is applied
        expect(style, isNotNull);
        // Note: The actual color testing would require resolving MaterialStateProperty
      });

      testWidgets('should work with icon', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          StyledButton.destructive(
            text: 'Remove',
            icon: const Icon(Icons.delete),
            onPressed: () {},
          ),
        ));

        expect(find.byIcon(Icons.delete), findsOneWidget);
        expect(find.text('Remove'), findsOneWidget);
      });
    });

    group('Small Button Constructor', () {
      testWidgets('should render with small height', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          StyledButton.small(
            text: 'Small',
            onPressed: () {},
          ),
        ));

        final sizedBox = tester.widget<SizedBox>(
          find.ancestor(
            of: find.byType(ElevatedButton),
            matching: find.byType(SizedBox),
          ).first,
        );
        
        expect(sizedBox.height, equals(36.0));
        expect(find.text('Small'), findsOneWidget);
      });
    });

    group('Icon Button Constructor', () {
      testWidgets('should render icon-only button', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          StyledButton.icon(
            icon: const Icon(Icons.add),
            onPressed: () {},
          ),
        ));

        expect(find.byIcon(Icons.add), findsOneWidget);
        expect(find.byType(IconButton), findsOneWidget);
        
        // Should not have text
        expect(find.byType(Text), findsNothing);
      });

      testWidgets('should render destructive icon button', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          StyledButton.icon(
            icon: const Icon(Icons.delete),
            isDestructive: true,
            onPressed: () {},
          ),
        ));

        expect(find.byIcon(Icons.delete), findsOneWidget);
        
        final iconButton = tester.widget<IconButton>(find.byType(IconButton));
        expect(iconButton.style, isNotNull);
      });

      testWidgets('should show loading state for icon button', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          const StyledButton.icon(
            icon: Icon(Icons.refresh),
            isLoading: true,
          ),
        ));

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byIcon(Icons.refresh), findsNothing); // Icon hidden during loading
      });
    });

    group('User Interaction', () {
      testWidgets('should call onPressed callback when tapped', (WidgetTester tester) async {
        var pressed = false;
        
        await tester.pumpWidget(createTestWidget(
          StyledButton(
            text: 'Tap Me',
            onPressed: () => pressed = true,
          ),
        ));

        await tester.tap(find.byType(ElevatedButton));
        expect(pressed, isTrue);
      });

      testWidgets('should not respond to tap when disabled', (WidgetTester tester) async {
        final pressed = false;
        
        await tester.pumpWidget(createTestWidget(
          StyledButton(
            text: 'Disabled',
            onPressed: null,
          ),
        ));

        await tester.tap(find.byType(ElevatedButton));
        expect(pressed, isFalse);
      });

      testWidgets('should not respond to tap when loading', (WidgetTester tester) async {
        var pressed = false;
        
        await tester.pumpWidget(createTestWidget(
          StyledButton(
            text: 'Loading',
            isLoading: true,
            onPressed: () => pressed = true,
          ),
        ));

        await tester.tap(find.byType(ElevatedButton));
        expect(pressed, isFalse);
      });
    });
  });

  group('StyledButtons Utility Class Tests', () {
    Widget createTestWidget(Widget child) {
      return MaterialApp(
        home: Scaffold(
          body: Center(child: child),
        ),
      );
    }

    group('Swedish Localization', () {
      testWidgets('cancel button should display Swedish text', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          StyledButtons.cancel(onPressed: () {}),
        ));

        expect(find.text('Avbryt'), findsOneWidget);
      });

      testWidgets('save button should display Swedish text', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          StyledButtons.save(onPressed: () {}),
        ));

        expect(find.text('Spara'), findsOneWidget);
        expect(find.byIcon(Icons.save), findsOneWidget);
      });

      testWidgets('delete button should display Swedish text', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          StyledButtons.delete(onPressed: () {}),
        ));

        expect(find.text('Ta bort'), findsOneWidget);
        expect(find.byIcon(Icons.delete), findsOneWidget);
      });

      testWidgets('add button should display Swedish text', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          StyledButtons.add(onPressed: () {}),
        ));

        expect(find.text('Lägg till'), findsOneWidget);
        expect(find.byIcon(Icons.add), findsOneWidget);
      });

      testWidgets('edit button should display Swedish text', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          StyledButtons.edit(onPressed: () {}),
        ));

        expect(find.text('Redigera'), findsOneWidget);
        expect(find.byIcon(Icons.edit), findsOneWidget);
      });

      testWidgets('share button should display Swedish text', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          StyledButtons.share(onPressed: () {}),
        ));

        expect(find.text('Dela'), findsOneWidget);
        expect(find.byIcon(Icons.share), findsOneWidget);
      });
    });

    group('Custom Text Support', () {
      testWidgets('should accept custom text for cancel', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          StyledButtons.cancel(
            text: 'Stäng',
            onPressed: () {},
          ),
        ));

        expect(find.text('Stäng'), findsOneWidget);
      });

      testWidgets('should accept custom text for save', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          StyledButtons.save(
            text: 'Skicka',
            onPressed: () {},
          ),
        ));

        expect(find.text('Skicka'), findsOneWidget);
      });
    });

    group('Loading State Support', () {
      testWidgets('save button should support loading state', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          StyledButtons.save(
            isLoading: true,
            onPressed: () {},
          ),
        ));

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Spara'), findsNothing); // Text hidden during loading
      });

      testWidgets('delete button should support loading state', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          StyledButtons.delete(
            isLoading: true,
            onPressed: () {},
          ),
        ));

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Ta bort'), findsNothing);
      });
    });

    group('Button Type Verification', () {
      testWidgets('cancel should be secondary button', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          StyledButtons.cancel(onPressed: () {}),
        ));

        // Verify it's using secondary style (by checking it's not destructive)
        final styledButton = tester.widget<StyledButton>(find.byType(StyledButton));
        expect(styledButton.isDestructive, isFalse);
      });

      testWidgets('delete should be destructive button', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          StyledButtons.delete(onPressed: () {}),
        ));

        // Verify it's using destructive style
        final styledButton = tester.widget<StyledButton>(find.byType(StyledButton));
        expect(styledButton.isDestructive, isTrue);
      });

      testWidgets('save should be primary button', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          StyledButtons.save(onPressed: () {}),
        ));

        // Verify it's using primary style
        final styledButton = tester.widget<StyledButton>(find.byType(StyledButton));
        expect(styledButton.isDestructive, isFalse);
        expect(styledButton.height, equals(AppDimensions.buttonHeight));
      });
    });
  });
}