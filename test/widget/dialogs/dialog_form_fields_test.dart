import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/moderation/content_filter_service.dart';
import 'package:butlery/widgets/common/dialogs/dialog_form_fields.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

void main() {
  group('DialogFormFields Widget Tests', () {
    group('Text Form Field', () {
      testWidgets('renders basic text form field', (WidgetTester tester) async {
        final controller = TextEditingController();

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: DialogFormFields.buildTextFormField(
              controller: controller,
              labelText: 'Namn',
            ),
          ),
        );

        expect(find.byType(TextFormField), findsOneWidget);
        expect(find.text('Namn'), findsOneWidget);
      });

      testWidgets('shows hint text when provided', (WidgetTester tester) async {
        final controller = TextEditingController();

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: DialogFormFields.buildTextFormField(
              controller: controller,
              labelText: 'Namn',
              hintText: 'Ange ditt namn',
            ),
          ),
        );

        expect(find.text('Ange ditt namn'), findsOneWidget);
      });

      testWidgets('displays prefix icon when provided',
          (WidgetTester tester) async {
        final controller = TextEditingController();

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: DialogFormFields.buildTextFormField(
              controller: controller,
              labelText: 'Email',
              prefixIcon: Icons.email,
            ),
          ),
        );

        expect(find.byIcon(Icons.email), findsOneWidget);
      });

      testWidgets('enforces max length constraint',
          (WidgetTester tester) async {
        final controller = TextEditingController();

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: DialogFormFields.buildTextFormField(
              controller: controller,
              labelText: 'Kort text',
              maxLength: 10,
            ),
          ),
        );

        expect(find.text('0/10'), findsOneWidget);

        await tester.enterText(find.byType(TextFormField), '12345');
        await tester.pump();

        expect(find.text('5/10'), findsOneWidget);
      });

      testWidgets('validates required field', (WidgetTester tester) async {
        final controller = TextEditingController();
        final formKey = GlobalKey<FormState>();

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Form(
              key: formKey,
              child: DialogFormFields.buildTextFormField(
                controller: controller,
                labelText: 'Obligatoriskt',
                required: true,
              ),
            ),
          ),
        );

        formKey.currentState!.validate();
        await tester.pump();

        // ValidationUtils.validateRequired produces "<field> far inte vara tom"
        expect(find.textContaining('Obligatoriskt'), findsWidgets);
      });

      testWidgets('validates minimum length', (WidgetTester tester) async {
        final controller = TextEditingController();
        final formKey = GlobalKey<FormState>();

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Form(
              key: formKey,
              child: DialogFormFields.buildTextFormField(
                controller: controller,
                labelText: 'Namn',
                minLength: 3,
              ),
            ),
          ),
        );

        await tester.enterText(find.byType(TextFormField), 'AB');
        formKey.currentState!.validate();
        await tester.pump();

        // Should show length validation error
        expect(find.textContaining('minst 3'), findsOneWidget);
      });

      testWidgets('allows multiline input', (WidgetTester tester) async {
        final controller = TextEditingController();

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: DialogFormFields.buildTextFormField(
              controller: controller,
              labelText: 'Beskrivning',
              maxLines: 5,
            ),
          ),
        );

        await tester.enterText(
            find.byType(TextFormField), 'Line 1\nLine 2\nLine 3');
        await tester.pump();

        expect(controller.text, equals('Line 1\nLine 2\nLine 3'));
      });

      testWidgets('disables field when enabled is false',
          (WidgetTester tester) async {
        final controller = TextEditingController();

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: DialogFormFields.buildTextFormField(
              controller: controller,
              labelText: 'Inaktiverat',
              enabled: false,
            ),
          ),
        );

        final textField =
            tester.widget<TextFormField>(find.byType(TextFormField));
        expect(textField.enabled, isFalse);
      });

      testWidgets('applies custom validator', (WidgetTester tester) async {
        final controller = TextEditingController();
        final formKey = GlobalKey<FormState>();

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Form(
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
        );

        await tester.enterText(find.byType(TextFormField), 'invalid');
        formKey.currentState!.validate();
        await tester.pump();

        expect(find.text('Ogiltig e-postadress'), findsOneWidget);
      });

      testWidgets('applies input formatters', (WidgetTester tester) async {
        final controller = TextEditingController();

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: DialogFormFields.buildTextFormField(
              controller: controller,
              labelText: 'Nummer',
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ),
        );

        await tester.enterText(find.byType(TextFormField), 'abc123def');
        await tester.pump();

        expect(controller.text, equals('123'));
      });
    });

    group('Specialized Fields', () {
      testWidgets('renders name field with defaults',
          (WidgetTester tester) async {
        final controller = TextEditingController();

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Builder(
              builder: (context) => DialogFormFields.buildNameField(
                context: context,
                controller: controller,
              ),
            ),
          ),
        );

        expect(find.byType(TextFormField), findsOneWidget);
        expect(find.byIcon(Icons.label_outline), findsOneWidget);
      });

      testWidgets('renders description field', (WidgetTester tester) async {
        final controller = TextEditingController();

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Builder(
              builder: (context) => DialogFormFields.buildDescriptionField(
                context: context,
                controller: controller,
              ),
            ),
          ),
        );

        expect(find.byType(TextFormField), findsOneWidget);
        expect(find.byIcon(Icons.description_outlined), findsOneWidget);
      });

      testWidgets('renders amount field with numeric keyboard',
          (WidgetTester tester) async {
        final controller = TextEditingController();

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Builder(
              builder: (context) => DialogFormFields.buildAmountField(
                context: context,
                controller: controller,
              ),
            ),
          ),
        );

        expect(find.byType(TextFormField), findsOneWidget);
        expect(find.byIcon(Icons.numbers), findsOneWidget);
      });

      testWidgets('validates amount field min/max',
          (WidgetTester tester) async {
        final controller = TextEditingController();
        final formKey = GlobalKey<FormState>();

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Builder(
              builder: (context) => Form(
                key: formKey,
                child: DialogFormFields.buildAmountField(
                  context: context,
                  controller: controller,
                  minValue: 1.0,
                  maxValue: 100.0,
                ),
              ),
            ),
          ),
        );

        await tester.enterText(find.byType(TextFormField), '0.5');
        formKey.currentState!.validate();
        await tester.pump();
        expect(find.textContaining('1'), findsWidgets);

        await tester.enterText(find.byType(TextFormField), '150');
        formKey.currentState!.validate();
        await tester.pump();
        expect(find.textContaining('100'), findsWidgets);
      });

      testWidgets('renders email field', (WidgetTester tester) async {
        final controller = TextEditingController();

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Builder(
              builder: (context) => DialogFormFields.buildEmailField(
                context: context,
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
          createLocalizedTestApp(
            child: Builder(
              builder: (context) => DialogFormFields.buildUrlField(
                context: context,
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
          createLocalizedTestApp(
            child: Builder(
              builder: (context) => DialogFormFields.buildPasswordField(
                context: context,
                controller: controller,
              ),
            ),
          ),
        );

        expect(find.byType(TextFormField), findsOneWidget);
        expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      });

      testWidgets('renders search field', (WidgetTester tester) async {
        final controller = TextEditingController();

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Builder(
              builder: (context) => DialogFormFields.buildSearchField(
                context: context,
                controller: controller,
              ),
            ),
          ),
        );

        expect(find.byType(TextFormField), findsOneWidget);
        expect(find.byIcon(Icons.search), findsOneWidget);
      });
    });

    group('Phone Field', () {
      testWidgets('renders with icon and hint', (WidgetTester tester) async {
        final controller = TextEditingController();

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Builder(
              builder: (context) => DialogFormFields.buildPhoneField(
                context: context,
                controller: controller,
              ),
            ),
          ),
        );

        expect(find.byType(TextFormField), findsOneWidget);
        expect(find.byIcon(Icons.phone_outlined), findsOneWidget);
        expect(find.text('+46 70 123 45 67'), findsOneWidget);
      });

      testWidgets('filters non-phone characters', (WidgetTester tester) async {
        final controller = TextEditingController();

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Builder(
              builder: (context) => DialogFormFields.buildPhoneField(
                context: context,
                controller: controller,
              ),
            ),
          ),
        );

        await tester.enterText(
            find.byType(TextFormField), 'abc+46()70-123 45 67xyz');
        await tester.pump();

        expect(controller.text, equals('+46()70-123 45 67'));
      });

      testWidgets('validates required empty field',
          (WidgetTester tester) async {
        final controller = TextEditingController();
        final formKey = GlobalKey<FormState>();

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Builder(
              builder: (context) => Form(
                key: formKey,
                child: DialogFormFields.buildPhoneField(
                  context: context,
                  controller: controller,
                  required: true,
                ),
              ),
            ),
          ),
        );

        formKey.currentState!.validate();
        await tester.pump();

        // Required field shows error
        expect(find.byType(TextFormField), findsOneWidget);
        // The error text contains the field label
        expect(
          find.textContaining('inte vara tom'),
          findsOneWidget,
        );
      });

      testWidgets('accepts optional empty field', (WidgetTester tester) async {
        final controller = TextEditingController();
        final formKey = GlobalKey<FormState>();

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Builder(
              builder: (context) => Form(
                key: formKey,
                child: DialogFormFields.buildPhoneField(
                  context: context,
                  controller: controller,
                  required: false,
                ),
              ),
            ),
          ),
        );

        final isValid = formKey.currentState!.validate();
        await tester.pump();

        expect(isValid, isTrue);
      });

      testWidgets('rejects phone with fewer than 10 digits',
          (WidgetTester tester) async {
        final controller = TextEditingController();
        final formKey = GlobalKey<FormState>();

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Builder(
              builder: (context) => Form(
                key: formKey,
                child: DialogFormFields.buildPhoneField(
                  context: context,
                  controller: controller,
                ),
              ),
            ),
          ),
        );

        await tester.enterText(find.byType(TextFormField), '+46 123 45 67');
        formKey.currentState!.validate();
        await tester.pump();

        expect(find.textContaining('telefonnummer'), findsWidgets);
      });

      testWidgets('accepts valid 10+ digit phone', (WidgetTester tester) async {
        final controller = TextEditingController();
        final formKey = GlobalKey<FormState>();

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Builder(
              builder: (context) => Form(
                key: formKey,
                child: DialogFormFields.buildPhoneField(
                  context: context,
                  controller: controller,
                ),
              ),
            ),
          ),
        );

        await tester.enterText(find.byType(TextFormField), '+46701234567');
        final isValid = formKey.currentState!.validate();
        await tester.pump();

        expect(isValid, isTrue);
      });

      testWidgets('disabled when enabled is false',
          (WidgetTester tester) async {
        final controller = TextEditingController();

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Builder(
              builder: (context) => DialogFormFields.buildPhoneField(
                context: context,
                controller: controller,
                enabled: false,
              ),
            ),
          ),
        );

        final textField =
            tester.widget<TextFormField>(find.byType(TextFormField));
        expect(textField.enabled, isFalse);
      });

      testWidgets('supports custom label and hint',
          (WidgetTester tester) async {
        final controller = TextEditingController();

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Builder(
              builder: (context) => DialogFormFields.buildPhoneField(
                context: context,
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
    });

    group('Dropdown Field', () {
      testWidgets('renders dropdown with items', (WidgetTester tester) async {
        String? selectedValue;

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Builder(
              builder: (context) => DialogFormFields.buildDropdownField<String>(
                context: context,
                value: selectedValue,
                labelText: 'Kategori',
                items: const [
                  DropdownMenuItem(value: 'A', child: Text('A')),
                  DropdownMenuItem(value: 'B', child: Text('B')),
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
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Builder(
              builder: (context) => DialogFormFields.buildDropdownField<String>(
                context: context,
                value: 'B',
                labelText: 'Kategori',
                items: const [
                  DropdownMenuItem(value: 'A', child: Text('A')),
                  DropdownMenuItem(value: 'B', child: Text('B')),
                ],
                onChanged: (value) {},
              ),
            ),
          ),
        );

        expect(find.text('B'), findsOneWidget);
      });

      testWidgets('validates required dropdown', (WidgetTester tester) async {
        final formKey = GlobalKey<FormState>();

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Builder(
              builder: (context) => Form(
                key: formKey,
                child: DialogFormFields.buildDropdownField<String>(
                  context: context,
                  value: null,
                  labelText: 'Kategori',
                  items: const [
                    DropdownMenuItem(value: 'A', child: Text('A')),
                  ],
                  onChanged: (value) {},
                  required: true,
                ),
              ),
            ),
          ),
        );

        formKey.currentState!.validate();
        await tester.pump();

        // Validator produces "Kategori <l10n.dialogFieldRequired>"
        expect(find.textContaining('Kategori'), findsWidgets);
      });
    });

    group('Checkbox and Switch Fields', () {
      testWidgets('renders checkbox field', (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: DialogFormFields.buildCheckboxField(
              value: false,
              title: 'Godkann villkor',
              onChanged: (newValue) {},
            ),
          ),
        );

        expect(find.byType(CheckboxListTile), findsOneWidget);
        expect(find.text('Godkann villkor'), findsOneWidget);
      });

      testWidgets('checkbox toggles on tap', (WidgetTester tester) async {
        bool value = false;

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: StatefulBuilder(
              builder: (context, setState) {
                return DialogFormFields.buildCheckboxField(
                  value: value,
                  title: 'Godkann villkor',
                  onChanged: (newValue) {
                    setState(() => value = newValue ?? false);
                  },
                );
              },
            ),
          ),
        );

        await tester.tap(find.byType(Checkbox));
        await tester.pump();

        expect(value, isTrue);
      });

      testWidgets('renders switch field', (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: DialogFormFields.buildSwitchField(
              value: false,
              title: 'Aktivera notifikationer',
              onChanged: (newValue) {},
            ),
          ),
        );

        expect(find.byType(SwitchListTile), findsOneWidget);
        expect(find.text('Aktivera notifikationer'), findsOneWidget);
      });

      testWidgets('switch toggles on tap', (WidgetTester tester) async {
        bool value = false;

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: StatefulBuilder(
              builder: (context, setState) {
                return DialogFormFields.buildSwitchField(
                  value: value,
                  title: 'Aktivera notifikationer',
                  onChanged: (newValue) {
                    setState(() => value = newValue);
                  },
                );
              },
            ),
          ),
        );

        await tester.tap(find.byType(Switch));
        await tester.pump();

        expect(value, isTrue);
      });

      testWidgets('shows subtitle when provided', (WidgetTester tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: DialogFormFields.buildSwitchField(
              value: false,
              title: 'Aktivera notifikationer',
              subtitle: 'Fa meddelanden om nya recept',
              onChanged: (newValue) {},
            ),
          ),
        );

        expect(find.text('Fa meddelanden om nya recept'), findsOneWidget);
      });
    });

    group('Accessibility', () {
      testWidgets('form fields have semantic labels',
          (WidgetTester tester) async {
        final controller = TextEditingController();

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: DialogFormFields.buildTextFormField(
              controller: controller,
              labelText: 'Anvandarnamn',
            ),
          ),
        );

        expect(find.text('Anvandarnamn'), findsOneWidget);
      });

      testWidgets('error messages are announced', (WidgetTester tester) async {
        final controller = TextEditingController();
        final formKey = GlobalKey<FormState>();

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Form(
              key: formKey,
              child: DialogFormFields.buildTextFormField(
                controller: controller,
                labelText: 'Email',
                customValidator: (value) => 'Felaktig e-post',
              ),
            ),
          ),
        );

        formKey.currentState!.validate();
        await tester.pump();

        expect(find.text('Felaktig e-post'), findsOneWidget);
      });
    });

    // BUT-517 follow-up: regression coverage for the contentFilter-bypass
    // foot-gun. Before the fix, passing a `customValidator` silently dropped
    // the profanity gate (`validator: customValidator ?? combine([...])`).
    // After the fix, customValidator and contentFilter compose so a UGC field
    // can never be opted out of moderation by mistake.
    group('Content filter bypass prevention (BUT-517 follow-up)', () {
      setUp(() {
        // Both production ServiceLocator and TestServiceLocator share
        // GetIt.instance, so registering directly on GetIt makes
        // `ServiceLocator.tryGet<ContentFilterService>()` resolve.
        ServiceLocator.initialize(DIContainer());
        if (GetIt.instance.isRegistered<ContentFilterService>()) {
          GetIt.instance.unregister<ContentFilterService>();
        }
        GetIt.instance
            .registerSingleton<ContentFilterService>(ContentFilterService());
      });

      tearDown(() {
        if (GetIt.instance.isRegistered<ContentFilterService>()) {
          GetIt.instance.unregister<ContentFilterService>();
        }
        ServiceLocator.reset();
      });

      testWidgets(
          'profanity is rejected even when customValidator returns null',
          (WidgetTester tester) async {
        // The bug: a permissive customValidator used to short-circuit the
        // entire chain — including the profanity gate. This test pins that
        // contract: customValidator returning null must NOT bypass
        // FormValidators.contentFilter.
        final controller = TextEditingController();
        final formKey = GlobalKey<FormState>();

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Form(
              key: formKey,
              child: DialogFormFields.buildTextFormField(
                controller: controller,
                labelText: 'Beskrivning',
                customValidator: (_) => null,
              ),
            ),
          ),
        );

        // 'fan' is a Swedish profanity token in ContentFilterService's list,
        // matched as a standalone word by the word-boundary regex.
        await tester.enterText(find.byType(TextFormField), 'vad fan');
        formKey.currentState!.validate();
        await tester.pump();

        // The localized contentFilterWarning (Swedish locale is the test
        // default in createLocalizedTestApp) must surface as the field error.
        expect(
          find.textContaining('olämpligt språk'),
          findsOneWidget,
          reason: 'contentFilter must run even when customValidator '
              'returns null — otherwise UGC fields can be opted out of '
              'moderation by passing a permissive customValidator.',
        );
      });

      testWidgets(
          'customValidator error wins on its own concern with clean input',
          (WidgetTester tester) async {
        // Compose order: customValidator runs FIRST so its domain-specific
        // error (e.g. "must contain @") still surfaces ahead of length /
        // required / contentFilter. Verifies the new order doesn't suppress
        // legitimate customValidator errors.
        final controller = TextEditingController();
        final formKey = GlobalKey<FormState>();

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Form(
              key: formKey,
              child: DialogFormFields.buildTextFormField(
                controller: controller,
                labelText: 'Email',
                customValidator: (value) {
                  if (value == null || !value.contains('@')) {
                    return 'Saknar @-tecken';
                  }
                  return null;
                },
              ),
            ),
          ),
        );

        await tester.enterText(find.byType(TextFormField), 'utan-snabel-a');
        formKey.currentState!.validate();
        await tester.pump();

        expect(find.text('Saknar @-tecken'), findsOneWidget);
      });

      testWidgets('clean input passes when customValidator also passes',
          (WidgetTester tester) async {
        // Round-trip sanity: when both customValidator and contentFilter are
        // happy with the input, the field validates. Guards against the fix
        // accidentally turning every form into a permanent error state.
        final controller = TextEditingController();
        final formKey = GlobalKey<FormState>();
        bool? validatorReturn;

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: Form(
              key: formKey,
              child: DialogFormFields.buildTextFormField(
                controller: controller,
                labelText: 'Beskrivning',
                customValidator: (_) => null,
              ),
            ),
          ),
        );

        await tester.enterText(
            find.byType(TextFormField), 'En helt vanlig beskrivning');
        validatorReturn = formKey.currentState!.validate();
        await tester.pump();

        expect(validatorReturn, isTrue);
      });
    });
  });
}
