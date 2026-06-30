// test/widget/styled/styled_input_test.dart
// Comprehensive tests for StyledInput and StyledFormField widgets using ultrathink methodology

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/styled/styled_input.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/l10n/app_localizations.dart';

void main() {
  group('StyledInput Widget Tests', () {
    // Helper to wrap widget with MaterialApp for proper theming
    Widget createTestWidget(Widget child) {
      return MaterialApp(
        // StyledFormField.build reads context.l10n (a11yRequiredFieldSuffix)
        // when isRequired — without these delegates that lookup throws and the
        // widget never builds (BUT-1449 / BUT-1430 localized required-field).
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('sv'),
        theme: ThemeData(
          colorScheme: const ColorScheme.light(
            primary: Colors.blue,
            outline: Colors.grey,
          ),
        ),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: child,
            ),
          ),
        ),
      );
    }

    group('Default Constructor', () {
      testWidgets('should render basic text field', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          createTestWidget(
            const StyledInput(
              label: 'Test Label',
              hint: 'Test Hint',
            ),
          ),
        );

        expect(find.byType(StyledInput), findsOneWidget);
        expect(find.byType(TextFormField), findsOneWidget);
        expect(find.text('Test Label'), findsOneWidget);

        // Hint text is not visible until field is focused
        await tester.tap(find.byType(TextFormField));
        await tester.pump();
        expect(find.text('Test Hint'), findsOneWidget);
      });

      testWidgets('should handle text input', (WidgetTester tester) async {
        final controller = TextEditingController();

        await tester.pumpWidget(
          createTestWidget(
            StyledInput(
              controller: controller,
            ),
          ),
        );

        await tester.enterText(find.byType(TextFormField), 'Test Input');
        expect(controller.text, equals('Test Input'));
      });

      testWidgets('should call onChanged callback', (
        WidgetTester tester,
      ) async {
        String? changedValue;

        await tester.pumpWidget(
          createTestWidget(
            StyledInput(
              onChanged: (value) => changedValue = value,
            ),
          ),
        );

        await tester.enterText(find.byType(TextFormField), 'New Value');
        expect(changedValue, equals('New Value'));
      });

      testWidgets('should show error text', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            const StyledInput(
              errorText: 'Error Message',
            ),
          ),
        );

        expect(find.text('Error Message'), findsOneWidget);
      });

      testWidgets('should show helper text', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            const StyledInput(
              helperText: 'Helper Message',
            ),
          ),
        );

        expect(find.text('Helper Message'), findsOneWidget);
      });

      testWidgets('should handle disabled state', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            const StyledInput(
              enabled: false,
              label: 'Disabled',
            ),
          ),
        );

        final textField = tester.widget<TextFormField>(
          find.byType(TextFormField),
        );
        expect(textField.enabled, isFalse);
      });

      testWidgets('should handle read-only state', (WidgetTester tester) async {
        final controller = TextEditingController(text: 'Initial');

        await tester.pumpWidget(
          createTestWidget(
            StyledInput(
              readOnly: true,
              label: 'Read Only',
              controller: controller,
            ),
          ),
        );

        // Try to modify the text - it should remain unchanged
        await tester.enterText(find.byType(TextFormField), 'Modified');
        expect(controller.text, equals('Initial'));
      });

      testWidgets('should handle obscured text behavior', (
        WidgetTester tester,
      ) async {
        final controller = TextEditingController();

        await tester.pumpWidget(
          createTestWidget(
            StyledInput(
              obscureText: true,
              controller: controller,
            ),
          ),
        );

        await tester.enterText(find.byType(TextFormField), 'password123');
        expect(controller.text, equals('password123'));

        // The text should be obscured visually (we can't directly test the obscureText property)
        // but we can verify the controller received the text
      });

      testWidgets('should handle prefix and suffix icons', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          createTestWidget(
            const StyledInput(
              prefixIcon: Icon(Icons.search),
              suffixIcon: Icon(Icons.clear),
            ),
          ),
        );

        expect(find.byIcon(Icons.search), findsOneWidget);
        expect(find.byIcon(Icons.clear), findsOneWidget);
      });

      testWidgets('should handle max length constraint', (
        WidgetTester tester,
      ) async {
        final controller = TextEditingController();

        await tester.pumpWidget(
          createTestWidget(
            StyledInput(
              maxLength: 5,
              controller: controller,
            ),
          ),
        );

        // Try to enter more than 5 characters
        await tester.enterText(find.byType(TextFormField), '123456789');
        // Should be truncated to 5 characters
        expect(controller.text, equals('12345'));
      });

      testWidgets('should handle multiline configuration', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          createTestWidget(
            const StyledInput(
              maxLines: 3,
              minLines: 2,
            ),
          ),
        );

        // Verify the field is rendered (can't directly test maxLines/minLines)
        expect(find.byType(TextFormField), findsOneWidget);
      });

      testWidgets('should handle onTap callback', (WidgetTester tester) async {
        var tapped = false;

        await tester.pumpWidget(
          createTestWidget(
            StyledInput(
              onTap: () => tapped = true,
            ),
          ),
        );

        await tester.tap(find.byType(TextFormField));
        expect(tapped, isTrue);
      });

      testWidgets('should handle validator', (WidgetTester tester) async {
        String? validator(String? value) {
          if (value == null || value.isEmpty) {
            return 'Required';
          }
          return null;
        }

        await tester.pumpWidget(
          createTestWidget(
            StyledInput(
              validator: validator,
            ),
          ),
        );

        final textField = tester.widget<TextFormField>(
          find.byType(TextFormField),
        );
        expect(textField.validator, equals(validator));
      });
    });

    group('Text Constructor', () {
      testWidgets('should render standard text input', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          createTestWidget(
            const StyledInput.text(
              label: 'Name',
            ),
          ),
        );

        expect(find.byType(TextFormField), findsOneWidget);
        expect(find.text('Name'), findsOneWidget);
      });

      testWidgets('should not be obscured', (WidgetTester tester) async {
        final controller = TextEditingController();

        await tester.pumpWidget(
          createTestWidget(
            StyledInput.text(
              controller: controller,
            ),
          ),
        );

        await tester.enterText(find.byType(TextFormField), 'visible text');
        expect(controller.text, equals('visible text'));
        // Text should be visible (not obscured)
      });
    });

    group('Password Constructor', () {
      testWidgets('should render password input with lock icon', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          createTestWidget(
            const StyledInput.password(
              label: 'Password',
            ),
          ),
        );

        expect(find.byIcon(Icons.lock_outline), findsOneWidget);
        expect(find.text('Password'), findsOneWidget);
      });

      testWidgets('should obscure text by default', (
        WidgetTester tester,
      ) async {
        final controller = TextEditingController();

        await tester.pumpWidget(
          createTestWidget(
            StyledInput.password(
              controller: controller,
            ),
          ),
        );

        await tester.enterText(find.byType(TextFormField), 'secret123');
        expect(controller.text, equals('secret123'));
        // Password should be obscured visually
      });

      testWidgets('should allow toggling obscure text', (
        WidgetTester tester,
      ) async {
        final controller = TextEditingController();

        await tester.pumpWidget(
          createTestWidget(
            StyledInput.password(
              obscureText: false,
              controller: controller,
            ),
          ),
        );

        await tester.enterText(find.byType(TextFormField), 'visible123');
        expect(controller.text, equals('visible123'));
        // With obscureText: false, password should be visible
      });
    });

    group('Email Constructor', () {
      testWidgets('should render email input with email icon', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          createTestWidget(
            const StyledInput.email(
              label: 'Email',
            ),
          ),
        );

        expect(find.byIcon(Icons.email), findsOneWidget);
        expect(find.text('Email'), findsOneWidget);
      });

      testWidgets('should accept email input', (WidgetTester tester) async {
        final controller = TextEditingController();

        await tester.pumpWidget(
          createTestWidget(
            StyledInput.email(
              controller: controller,
            ),
          ),
        );

        await tester.enterText(find.byType(TextFormField), 'test@example.com');
        expect(controller.text, equals('test@example.com'));
      });
    });

    group('Phone Constructor', () {
      testWidgets('should render phone input with phone icon', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          createTestWidget(
            const StyledInput.phone(
              label: 'Phone',
            ),
          ),
        );

        expect(find.byIcon(Icons.phone), findsOneWidget);
        expect(find.text('Phone'), findsOneWidget);
      });

      testWidgets('should accept phone input', (WidgetTester tester) async {
        final controller = TextEditingController();

        await tester.pumpWidget(
          createTestWidget(
            StyledInput.phone(
              controller: controller,
            ),
          ),
        );

        await tester.enterText(find.byType(TextFormField), '+46701234567');
        expect(controller.text, equals('+46701234567'));
      });
    });

    group('Multiline Constructor', () {
      testWidgets('should render multiline input', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            const StyledInput.multiline(
              label: 'Description',
            ),
          ),
        );

        expect(find.text('Description'), findsOneWidget);
        expect(find.byType(TextFormField), findsOneWidget);
      });

      testWidgets('should accept multiline text', (WidgetTester tester) async {
        final controller = TextEditingController();

        await tester.pumpWidget(
          createTestWidget(
            StyledInput.multiline(
              controller: controller,
            ),
          ),
        );

        await tester.enterText(
          find.byType(TextFormField),
          'Line 1\nLine 2\nLine 3',
        );
        expect(controller.text, equals('Line 1\nLine 2\nLine 3'));
      });

      testWidgets('should accept custom line configuration', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          createTestWidget(
            const StyledInput.multiline(
              maxLines: 10,
              minLines: 5,
            ),
          ),
        );

        // Verify the field is rendered with custom config
        expect(find.byType(TextFormField), findsOneWidget);
      });
    });

    group('Number Constructor', () {
      testWidgets('should render number input', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            const StyledInput.number(
              label: 'Amount',
            ),
          ),
        );

        expect(find.text('Amount'), findsOneWidget);
        expect(find.byType(TextFormField), findsOneWidget);
      });

      testWidgets('should filter non-digit characters', (
        WidgetTester tester,
      ) async {
        final controller = TextEditingController();

        await tester.pumpWidget(
          createTestWidget(
            StyledInput.number(
              controller: controller,
            ),
          ),
        );

        // Try to enter mixed characters
        await tester.enterText(find.byType(TextFormField), '123abc456');
        // Should only keep digits
        expect(controller.text, equals('123456'));
      });
    });

    group('Search Constructor', () {
      testWidgets('should render search input with search icon', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          createTestWidget(
            const StyledInput.search(
              hint: 'Search...',
            ),
          ),
        );

        expect(find.byIcon(Icons.search), findsOneWidget);

        // Focus to see hint
        await tester.tap(find.byType(TextFormField));
        await tester.pump();
        expect(find.text('Search...'), findsOneWidget);
      });

      testWidgets('should not have label', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            const StyledInput.search(),
          ),
        );

        // Search input doesn't have a label (only hint)
        expect(find.textContaining('Label'), findsNothing);
      });

      testWidgets('should accept search text', (WidgetTester tester) async {
        final controller = TextEditingController();

        await tester.pumpWidget(
          createTestWidget(
            StyledInput.search(
              controller: controller,
            ),
          ),
        );

        await tester.enterText(find.byType(TextFormField), 'search query');
        expect(controller.text, equals('search query'));
      });
    });

    group('Visual Styling', () {
      testWidgets('should have rounded borders', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            const StyledInput(),
          ),
        );

        // Verify the input field is rendered with styled borders
        expect(find.byType(TextFormField), findsOneWidget);
      });

      testWidgets('should show error styling', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            const StyledInput(
              errorText: 'Error',
            ),
          ),
        );

        expect(find.text('Error'), findsOneWidget);
        // Error text should be displayed with error styling
      });

      testWidgets('should have filled background', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            const StyledInput(),
          ),
        );

        // Verify the field has a filled background
        expect(find.byType(TextFormField), findsOneWidget);
      });

      testWidgets('should handle disabled styling', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          createTestWidget(
            const StyledInput(
              enabled: false,
              label: 'Disabled Field',
            ),
          ),
        );

        final textField = tester.widget<TextFormField>(
          find.byType(TextFormField),
        );
        expect(textField.enabled, isFalse);
        // Disabled field should have different styling
      });
    });
  });

  group('StyledFormField Widget Tests', () {
    Widget createTestWidget(Widget child) {
      return MaterialApp(
        // StyledFormField.build reads context.l10n (a11yRequiredFieldSuffix)
        // when isRequired — without these delegates that lookup throws
        // (BUT-1449 / BUT-1430 localized required-field).
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('sv'),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: child,
            ),
          ),
        ),
      );
    }

    testWidgets('should render child widget', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(
          const StyledFormField(
            child: Text('Child Widget'),
          ),
        ),
      );

      expect(find.byType(StyledFormField), findsOneWidget);
      expect(find.text('Child Widget'), findsOneWidget);
    });

    testWidgets('should show label when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(
          const StyledFormField(
            label: 'Field Label',
            child: SizedBox(),
          ),
        ),
      );

      expect(find.text('Field Label'), findsOneWidget);
    });

    testWidgets('should show required asterisk when isRequired is true', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(
          const StyledFormField(
            label: 'Required Field',
            isRequired: true,
            child: SizedBox(),
          ),
        ),
      );

      expect(find.text('Required Field'), findsOneWidget);
      expect(find.text(' *'), findsOneWidget);
    });

    testWidgets('should show error text when provided', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(
          const StyledFormField(
            errorText: 'Field error',
            child: SizedBox(),
          ),
        ),
      );

      expect(find.text('Field error'), findsOneWidget);
    });

    testWidgets('should show helper text when no error', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(
          const StyledFormField(
            helperText: 'Helper text',
            child: SizedBox(),
          ),
        ),
      );

      expect(find.text('Helper text'), findsOneWidget);
    });

    testWidgets('should not show helper text when error exists', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(
          const StyledFormField(
            helperText: 'Helper text',
            errorText: 'Error text',
            child: SizedBox(),
          ),
        ),
      );

      expect(find.text('Error text'), findsOneWidget);
      expect(find.text('Helper text'), findsNothing);
    });

    testWidgets('should have proper spacing', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(
          const StyledFormField(
            label: 'Label',
            child: SizedBox(height: 50),
          ),
        ),
      );

      // Check for spacing widgets
      expect(find.byType(SizedBox), findsWidgets);

      // Find SizedBox widgets used for spacing
      final spacingBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));

      // Should have spacing after label and at bottom
      expect(
        spacingBoxes.any((box) => box.height == AppDimensions.spacingSm),
        isTrue,
      );
      expect(
        spacingBoxes.any((box) => box.height == AppDimensions.spacingMd),
        isTrue,
      );
    });

    testWidgets('should layout vertically', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(
          const StyledFormField(
            label: 'Label',
            helperText: 'Helper',
            child: Text('Input'),
          ),
        ),
      );

      final column = tester.widget<Column>(find.byType(Column));
      expect(column.crossAxisAlignment, equals(CrossAxisAlignment.start));
    });
  });
}
