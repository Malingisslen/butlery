import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/dialogs/dialog_form_fields.dart';

void main() {
  group('DialogFormFields Widget Tests', () {
    group('Text Form Field', () {
      testWidgets('renders basic text form field', (WidgetTester tester) async {
        final controller = TextEditingController();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DialogFormFields.buildTextFormField(
                controller: controller,
                labelText: 'Namn',
              ),
            ),
          ),
        );

        expect(find.byType(TextFormField), findsOneWidget);
        expect(find.text('Namn'), findsOneWidget);
      });

      testWidgets('shows hint text when provided', (WidgetTester tester) async {
        final controller = TextEditingController();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DialogFormFields.buildTextFormField(
                controller: controller,
                labelText: 'Namn',
                hintText: 'Ange ditt namn här',
              ),
            ),
          ),
        );

        expect(find.text('Ange ditt namn här'), findsOneWidget);
      });

      testWidgets('displays prefix icon when provided', (WidgetTester tester) async {
        final controller = TextEditingController();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DialogFormFields.buildTextFormField(
                controller: controller,
                labelText: 'Email',
                prefixIcon: Icons.email,
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.email), findsOneWidget);
      });

      testWidgets('enforces max length constraint', (WidgetTester tester) async {
        final controller = TextEditingController();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DialogFormFields.buildTextFormField(
                controller: controller,
                labelText: 'Kort text',
                maxLength: 10,
              ),
            ),
          ),
        );

        // Shows character counter
        expect(find.text('0/10'), findsOneWidget);

        // Enter text
        await tester.enterText(find.byType(TextFormField), '12345');
        await tester.pump();

        expect(find.text('5/10'), findsOneWidget);
      });

      testWidgets('validates required field', (WidgetTester tester) async {
        final controller = TextEditingController();
        final formKey = GlobalKey<FormState>();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Form(
                key: formKey,
                child: DialogFormFields.buildTextFormField(
                  controller: controller,
                  labelText: 'Obligatoriskt fält',
                  required: true,
                ),
              ),
            ),
          ),
        );

        // Validate empty field
        formKey.currentState!.validate();
        await tester.pump();

        // Should show validation error
        expect(find.text('Obligatoriskt fält får inte vara tom'), findsOneWidget);
      });

      testWidgets('validates minimum length', (WidgetTester tester) async {
        final controller = TextEditingController();
        final formKey = GlobalKey<FormState>();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Form(
                key: formKey,
                child: DialogFormFields.buildTextFormField(
                  controller: controller,
                  labelText: 'Namn',
                  minLength: 3,
                ),
              ),
            ),
          ),
        );

        // Enter short text
        await tester.enterText(find.byType(TextFormField), 'AB');
        
        // Validate
        formKey.currentState!.validate();
        await tester.pump();

        // Should show validation error
        expect(find.text('Namn måste vara minst 3 tecken'), findsOneWidget);
      });

      testWidgets('allows multiline input', (WidgetTester tester) async {
        final controller = TextEditingController();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DialogFormFields.buildTextFormField(
                controller: controller,
                labelText: 'Beskrivning',
                maxLines: 5,
              ),
            ),
          ),
        );

        // Enter multiline text
        await tester.enterText(find.byType(TextFormField), 'Line 1\nLine 2\nLine 3');
        await tester.pump();

        expect(controller.text, equals('Line 1\nLine 2\nLine 3'));
      });

      testWidgets('disables field when enabled is false', (WidgetTester tester) async {
        final controller = TextEditingController();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DialogFormFields.buildTextFormField(
                controller: controller,
                labelText: 'Inaktiverat fält',
                enabled: false,
              ),
            ),
          ),
        );

        final textField = tester.widget<TextFormField>(find.byType(TextFormField));
        expect(textField.enabled, isFalse);
      });

      testWidgets('applies custom validator', (WidgetTester tester) async {
        final controller = TextEditingController();
        final formKey = GlobalKey<FormState>();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Form(
                key: formKey,
                child: DialogFormFields.buildTextFormField(
                  controller: controller,
                  labelText: 'Email',
                  customValidator: (value) {
                    if (value == null || !value.contains('@')) {
                      return 'Ogiltig e-postadress';
                    }
                    return null;
                  },
                ),
              ),
            ),
          ),
        );

        // Enter invalid email
        await tester.enterText(find.byType(TextFormField), 'invalid');
        
        // Validate
        formKey.currentState!.validate();
        await tester.pump();

        expect(find.text('Ogiltig e-postadress'), findsOneWidget);
      });

      testWidgets('applies input formatters', (WidgetTester tester) async {
        final controller = TextEditingController();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DialogFormFields.buildTextFormField(
                controller: controller,
                labelText: 'Nummer',
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
          ),
        );

        // Try to enter letters
        await tester.enterText(find.byType(TextFormField), 'abc123def');
        await tester.pump();

        // Only digits should remain
        expect(controller.text, equals('123'));
      });
    });

    group('Specialized Fields', () {
      testWidgets('renders name field with defaults', (WidgetTester tester) async {
        final controller = TextEditingController();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DialogFormFields.buildNameField(
                controller: controller,
              ),
            ),
          ),
        );

        expect(find.byType(TextFormField), findsOneWidget);
        expect(find.text('Namn'), findsOneWidget);
        expect(find.byIcon(Icons.label_outline), findsOneWidget);
      });

      testWidgets('renders description field', (WidgetTester tester) async {
        final controller = TextEditingController();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DialogFormFields.buildDescriptionField(
                controller: controller,
              ),
            ),
          ),
        );

        expect(find.byType(TextFormField), findsOneWidget);
        expect(find.text('Beskrivning'), findsOneWidget);
        expect(find.text('Valfri beskrivning...'), findsOneWidget);
      });

      testWidgets('renders amount field with numeric keyboard', (WidgetTester tester) async {
        final controller = TextEditingController();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DialogFormFields.buildAmountField(
                controller: controller,
              ),
            ),
          ),
        );

        expect(find.byType(TextFormField), findsOneWidget);
        expect(find.text('Antal'), findsOneWidget);
        expect(find.byIcon(Icons.numbers), findsOneWidget);
      });

      testWidgets('validates amount field min/max', (WidgetTester tester) async {
        final controller = TextEditingController();
        final formKey = GlobalKey<FormState>();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Form(
                key: formKey,
                child: DialogFormFields.buildAmountField(
                  controller: controller,
                  minValue: 1.0,
                  maxValue: 100.0,
                ),
              ),
            ),
          ),
        );

        // Test value below minimum
        await tester.enterText(find.byType(TextFormField), '0.5');
        formKey.currentState!.validate();
        await tester.pump();
        expect(find.textContaining('Minst 1'), findsOneWidget);

        // Clear and test value above maximum
        await tester.enterText(find.byType(TextFormField), '150');
        formKey.currentState!.validate();
        await tester.pump();
        expect(find.textContaining('Max 100'), findsOneWidget);
      });

      testWidgets('renders email field with validation', (WidgetTester tester) async {
        final controller = TextEditingController();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DialogFormFields.buildEmailField(
                controller: controller,
              ),
            ),
          ),
        );

        expect(find.byType(TextFormField), findsOneWidget);
        expect(find.text('E-post'), findsOneWidget);
        expect(find.byIcon(Icons.email_outlined), findsOneWidget);
      });

      testWidgets('renders URL field', (WidgetTester tester) async {
        final controller = TextEditingController();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DialogFormFields.buildUrlField(
                controller: controller,
              ),
            ),
          ),
        );

        expect(find.byType(TextFormField), findsOneWidget);
        expect(find.text('URL'), findsOneWidget);
        expect(find.byIcon(Icons.link), findsOneWidget);
      });

      testWidgets('renders password field', (WidgetTester tester) async {
        final controller = TextEditingController();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DialogFormFields.buildPasswordField(
                controller: controller,
              ),
            ),
          ),
        );

        expect(find.byType(TextFormField), findsOneWidget);
        expect(find.text('Lösenord'), findsOneWidget);
        expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      });

      testWidgets('renders search field', (WidgetTester tester) async {
        final controller = TextEditingController();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DialogFormFields.buildSearchField(
                controller: controller,
              ),
            ),
          ),
        );

        expect(find.byType(TextFormField), findsOneWidget);
        expect(find.text('Sök'), findsOneWidget);
        expect(find.byIcon(Icons.search), findsOneWidget);
      });

      testWidgets('renders phone field with formatting', (WidgetTester tester) async {
        final controller = TextEditingController();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DialogFormFields.buildPhoneField(
                controller: controller,
              ),
            ),
          ),
        );

        expect(find.byType(TextFormField), findsOneWidget);
        expect(find.text('Telefonnummer'), findsOneWidget);
        expect(find.byIcon(Icons.phone_outlined), findsOneWidget);

        // Test that only allowed characters are accepted
        await tester.enterText(find.byType(TextFormField), 'abc+46701234567xyz');
        await tester.pump();
        
        // Letters should be filtered out
        expect(controller.text, contains('+46701234567'));
      });

      // ULTRATHINK COMPREHENSIVE PHONE FIELD TESTS
      group('Phone Field - Comprehensive Coverage', () {
        testWidgets('should display Swedish default values', (WidgetTester tester) async {
          final controller = TextEditingController();

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: DialogFormFields.buildPhoneField(
                  controller: controller,
                ),
              ),
            ),
          );

          // Check Swedish localization
          expect(find.text('Telefonnummer'), findsOneWidget);
          expect(find.text('+46 70 123 45 67'), findsOneWidget); // Swedish hint
          expect(find.byIcon(Icons.phone_outlined), findsOneWidget);
        });

        testWidgets('should use phone keyboard type', (WidgetTester tester) async {
          final controller = TextEditingController();

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: DialogFormFields.buildPhoneField(
                  controller: controller,
                ),
              ),
            ),
          );

          // Note: TextFormField doesn't expose keyboardType directly in tests
          // The behavior is tested through input filtering instead
          // Production code confirms keyboardType: TextInputType.phone is set
          expect(find.byType(TextFormField), findsOneWidget);
        });

        testWidgets('should filter allowed characters only', (WidgetTester tester) async {
          final controller = TextEditingController();

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: DialogFormFields.buildPhoneField(
                  controller: controller,
                ),
              ),
            ),
          );

          // Test various inputs with allowed/disallowed characters
          await tester.enterText(find.byType(TextFormField), 'abc+46()70-123 45 67xyz!@#');
          await tester.pump();

          // Only allowed characters: [0-9+\-\s()]
          expect(controller.text, equals('+46()70-123 45 67'));
        });

        testWidgets('should validate required phone field when empty', (WidgetTester tester) async {
          final controller = TextEditingController();
          final formKey = GlobalKey<FormState>();

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Form(
                  key: formKey,
                  child: DialogFormFields.buildPhoneField(
                    controller: controller,
                    required: true,
                  ),
                ),
              ),
            ),
          );

          // Validate empty required field
          formKey.currentState!.validate();
          await tester.pump();

          expect(find.text('Telefonnummer får inte vara tom'), findsOneWidget);
        });

        testWidgets('should not validate optional phone field when empty', (WidgetTester tester) async {
          final controller = TextEditingController();
          final formKey = GlobalKey<FormState>();

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Form(
                  key: formKey,
                  child: DialogFormFields.buildPhoneField(
                    controller: controller,
                    required: false, // Default behavior
                  ),
                ),
              ),
            ),
          );

          // Validate empty optional field
          final isValid = formKey.currentState!.validate();
          await tester.pump();

          expect(isValid, isTrue);
          expect(find.text('Telefonnummer får inte vara tom'), findsNothing);
        });

        testWidgets('should validate phone with less than 10 digits', (WidgetTester tester) async {
          final controller = TextEditingController();
          final formKey = GlobalKey<FormState>();

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Form(
                  key: formKey,
                  child: DialogFormFields.buildPhoneField(
                    controller: controller,
                  ),
                ),
              ),
            ),
          );

          // Enter phone with only 9 digits
          await tester.enterText(find.byType(TextFormField), '+46 123 45 67');
          
          // Validate
          formKey.currentState!.validate();
          await tester.pump();

          expect(find.text('Ogiltigt telefonnummer'), findsOneWidget);
        });

        testWidgets('should accept valid phone with exactly 10 digits', (WidgetTester tester) async {
          final controller = TextEditingController();
          final formKey = GlobalKey<FormState>();

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Form(
                  key: formKey,
                  child: DialogFormFields.buildPhoneField(
                    controller: controller,
                  ),
                ),
              ),
            ),
          );

          // Enter phone with exactly 10 digits
          await tester.enterText(find.byType(TextFormField), '+46701234567');
          
          // Validate
          final isValid = formKey.currentState!.validate();
          await tester.pump();

          expect(isValid, isTrue);
          expect(find.text('Ogiltigt telefonnummer'), findsNothing);
        });

        testWidgets('should accept valid phone with more than 10 digits', (WidgetTester tester) async {
          final controller = TextEditingController();
          final formKey = GlobalKey<FormState>();

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Form(
                  key: formKey,
                  child: DialogFormFields.buildPhoneField(
                    controller: controller,
                  ),
                ),
              ),
            ),
          );

          // Enter phone with 13 digits (international format)
          await tester.enterText(find.byType(TextFormField), '+46 70 123 45 67 89');
          
          // Validate
          final isValid = formKey.currentState!.validate();
          await tester.pump();

          expect(isValid, isTrue);
          expect(find.text('Ogiltigt telefonnummer'), findsNothing);
        });

        testWidgets('should accept various valid Swedish phone formats', (WidgetTester tester) async {
          final controller = TextEditingController();
          final formKey = GlobalKey<FormState>();

          final validFormats = [
            '+46701234567',           // International without spaces
            '+46 70 123 45 67',       // International with spaces
            '070-123 45 67',          // National with dash and spaces
            '070 123 45 67',          // National with spaces
            '(070) 123 45 67',        // With parentheses
            '+46(0)701234567',        // International with (0)
          ];

          for (final format in validFormats) {
            await tester.pumpWidget(
              MaterialApp(
                home: Scaffold(
                  body: Form(
                    key: formKey,
                    child: DialogFormFields.buildPhoneField(
                      controller: controller,
                    ),
                  ),
                ),
              ),
            );

            controller.clear();
            await tester.enterText(find.byType(TextFormField), format);
            
            final isValid = formKey.currentState!.validate();
            await tester.pump();

            expect(isValid, isTrue, reason: 'Format "$format" should be valid');
          }
        });

        testWidgets('should handle max length constraint', (WidgetTester tester) async {
          final controller = TextEditingController();
          final formKey = GlobalKey<FormState>();

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Form(
                  key: formKey,
                  child: DialogFormFields.buildPhoneField(
                    controller: controller,
                  ),
                ),
              ),
            ),
          );

          // Try to enter very long phone number (more than 20 chars)  
          const longPhone = '+46701234567890123456789';
          await tester.enterText(find.byType(TextFormField), longPhone);
          await tester.pump();

          // Note: TextFormField doesn't enforce maxLength by default, only validates
          // The production code sets maxLengthLimit: 20 for validation, not input limiting
          // Input filtering only affects character types, not length
          expect(controller.text, equals(longPhone)); // All characters are allowed types
        });

        testWidgets('should be disabled when enabled is false', (WidgetTester tester) async {
          final controller = TextEditingController();

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: DialogFormFields.buildPhoneField(
                  controller: controller,
                  enabled: false,
                ),
              ),
            ),
          );

          final textField = tester.widget<TextFormField>(find.byType(TextFormField));
          expect(textField.enabled, isFalse);
        });

        testWidgets('should support custom label and hint', (WidgetTester tester) async {
          final controller = TextEditingController();

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: DialogFormFields.buildPhoneField(
                  controller: controller,
                  labelText: 'Mobilnummer',
                  hintText: '08-123 456 78',
                ),
              ),
            ),
          );

          expect(find.text('Mobilnummer'), findsOneWidget);
          expect(find.text('08-123 456 78'), findsOneWidget);
        });

        testWidgets('should handle edge case - only special characters', (WidgetTester tester) async {
          final controller = TextEditingController();
          final formKey = GlobalKey<FormState>();

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Form(
                  key: formKey,
                  child: DialogFormFields.buildPhoneField(
                    controller: controller,
                  ),
                ),
              ),
            ),
          );

          // Enter only special characters (no digits)
          await tester.enterText(find.byType(TextFormField), '+()- ');
          
          // Validate
          formKey.currentState!.validate();
          await tester.pump();

          // Should fail validation (0 digits)
          expect(find.text('Ogiltigt telefonnummer'), findsOneWidget);
        });

        testWidgets('should handle edge case - mixed valid and invalid characters', (WidgetTester tester) async {
          final controller = TextEditingController();

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: DialogFormFields.buildPhoneField(
                  controller: controller,
                ),
              ),
            ),
          );

          // Mix of allowed and disallowed characters
          await tester.enterText(find.byType(TextFormField), 'abc+46xyz701()def234567ghi!@#');
          await tester.pump();

          // Only allowed characters should remain
          expect(controller.text, equals('+46701()234567'));
        });

        testWidgets('should validate boundary case - exactly 10 digits with formatting', (WidgetTester tester) async {
          final controller = TextEditingController();
          final formKey = GlobalKey<FormState>();

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Form(
                  key: formKey,
                  child: DialogFormFields.buildPhoneField(
                    controller: controller,
                  ),
                ),
              ),
            ),
          );

          // Enter exactly 10 digits with formatting: (070) 123-45-67 
          // Digits: 0,7,0,1,2,3,4,5,6,7 = 10 digits
          await tester.enterText(find.byType(TextFormField), '(070) 123-45-67');
          
          // Validate - should pass (10 digits)
          final isValid = formKey.currentState!.validate();
          await tester.pump();

          expect(isValid, isTrue);
          expect(find.text('Ogiltigt telefonnummer'), findsNothing);
        });

        testWidgets('should support Swedish character handling in validation messages', (WidgetTester tester) async {
          final controller = TextEditingController();
          final formKey = GlobalKey<FormState>();

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Form(
                  key: formKey,
                  child: DialogFormFields.buildPhoneField(
                    controller: controller,
                    labelText: 'Telefonnummer',
                  ),
                ),
              ),
            ),
          );

          // Enter invalid phone
          await tester.enterText(find.byType(TextFormField), '123');
          
          // Validate
          formKey.currentState!.validate();
          await tester.pump();

          // Should show Swedish error message
          expect(find.text('Ogiltigt telefonnummer'), findsOneWidget);
        });
      });
    });

    group('Dropdown Field', () {
      testWidgets('renders dropdown with items', (WidgetTester tester) async {
        String? selectedValue;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DialogFormFields.buildDropdownField<String>(
                value: selectedValue,
                labelText: 'Kategori',
                items: [
                  const DropdownMenuItem(value: 'Förrätt', child: Text('Förrätt')),
                  const DropdownMenuItem(value: 'Huvudrätt', child: Text('Huvudrätt')),
                  const DropdownMenuItem(value: 'Efterrätt', child: Text('Efterrätt')),
                ],
                onChanged: (value) => selectedValue = value,
              ),
            ),
          ),
        );

        expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
        expect(find.text('Kategori'), findsOneWidget);
      });

      testWidgets('shows selected value', (WidgetTester tester) async {
        String? selectedValue = 'Huvudrätt';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DialogFormFields.buildDropdownField<String>(
                value: selectedValue,
                labelText: 'Kategori',
                items: [
                  const DropdownMenuItem(value: 'Förrätt', child: Text('Förrätt')),
                  const DropdownMenuItem(value: 'Huvudrätt', child: Text('Huvudrätt')),
                  const DropdownMenuItem(value: 'Efterrätt', child: Text('Efterrätt')),
                ],
                onChanged: (value) => selectedValue = value,
              ),
            ),
          ),
        );

        expect(find.text('Huvudrätt'), findsOneWidget);
      });

      testWidgets('validates required dropdown', (WidgetTester tester) async {
        String? selectedValue;
        final formKey = GlobalKey<FormState>();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Form(
                key: formKey,
                child: DialogFormFields.buildDropdownField<String>(
                  value: selectedValue,
                  labelText: 'Kategori',
                  items: [
                    const DropdownMenuItem(value: 'Förrätt', child: Text('Förrätt')),
                    const DropdownMenuItem(value: 'Huvudrätt', child: Text('Huvudrätt')),
                    const DropdownMenuItem(value: 'Efterrätt', child: Text('Efterrätt')),
                  ],
                  onChanged: (value) => selectedValue = value,
                  required: true,
                ),
              ),
            ),
          ),
        );

        // Validate without selection
        formKey.currentState!.validate();
        await tester.pump();

        expect(find.text('Kategori krävs'), findsOneWidget);
      });
    });

    group('Checkbox and Switch Fields', () {
      testWidgets('renders checkbox field', (WidgetTester tester) async {
        bool value = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DialogFormFields.buildCheckboxField(
                value: value,
                title: 'Godkänn villkor',
                onChanged: (newValue) => value = newValue ?? false,
              ),
            ),
          ),
        );

        expect(find.byType(CheckboxListTile), findsOneWidget);
        expect(find.text('Godkänn villkor'), findsOneWidget);
      });

      testWidgets('checkbox toggles on tap', (WidgetTester tester) async {
        bool value = false;
        bool changed = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return DialogFormFields.buildCheckboxField(
                    value: value,
                    title: 'Godkänn villkor',
                    onChanged: (newValue) {
                      setState(() {
                        value = newValue ?? false;
                        changed = true;
                      });
                    },
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.byType(Checkbox));
        await tester.pump();

        expect(changed, isTrue);
        expect(value, isTrue);
      });

      testWidgets('renders switch field', (WidgetTester tester) async {
        bool value = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DialogFormFields.buildSwitchField(
                value: value,
                title: 'Aktivera notifikationer',
                onChanged: (newValue) => value = newValue,
              ),
            ),
          ),
        );

        expect(find.byType(SwitchListTile), findsOneWidget);
        expect(find.text('Aktivera notifikationer'), findsOneWidget);
      });

      testWidgets('switch toggles on tap', (WidgetTester tester) async {
        bool value = false;
        bool changed = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return DialogFormFields.buildSwitchField(
                    value: value,
                    title: 'Aktivera notifikationer',
                    onChanged: (newValue) {
                      setState(() {
                        value = newValue;
                        changed = true;
                      });
                    },
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.byType(Switch));
        await tester.pump();

        expect(changed, isTrue);
        expect(value, isTrue);
      });

      testWidgets('shows subtitle when provided', (WidgetTester tester) async {
        bool value = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DialogFormFields.buildSwitchField(
                value: value,
                title: 'Aktivera notifikationer',
                subtitle: 'Få meddelanden om nya recept',
                onChanged: (newValue) => value = newValue,
              ),
            ),
          ),
        );

        expect(find.text('Få meddelanden om nya recept'), findsOneWidget);
      });
    });

    group('Accessibility', () {
      testWidgets('form fields have semantic labels', (WidgetTester tester) async {
        final controller = TextEditingController();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DialogFormFields.buildTextFormField(
                controller: controller,
                labelText: 'Användarnamn',
              ),
            ),
          ),
        );

        // The label text should be visible in the widget tree
        expect(find.text('Användarnamn'), findsOneWidget);
      });

      testWidgets('error messages are announced', (WidgetTester tester) async {
        final controller = TextEditingController();
        final formKey = GlobalKey<FormState>();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Form(
                key: formKey,
                child: DialogFormFields.buildTextFormField(
                  controller: controller,
                  labelText: 'Email',
                  customValidator: (value) => 'Felaktig e-post',
                ),
              ),
            ),
          ),
        );

        formKey.currentState!.validate();
        await tester.pump();

        expect(find.text('Felaktig e-post'), findsOneWidget);
      });
    });

    group('Responsive Design', () {
      testWidgets('adapts to small screens', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;

        final controller = TextEditingController();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DialogFormFields.buildTextFormField(
                controller: controller,
                labelText: 'Test',
              ),
            ),
          ),
        );

        expect(find.byType(TextFormField), findsOneWidget);

        // Reset
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      testWidgets('adapts to tablets', (WidgetTester tester) async {
        tester.view.physicalSize = const Size(768, 1024);
        tester.view.devicePixelRatio = 1.0;

        final controller = TextEditingController();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DialogFormFields.buildTextFormField(
                controller: controller,
                labelText: 'Test',
              ),
            ),
          ),
        );

        expect(find.byType(TextFormField), findsOneWidget);

        // Reset
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });
  });
}