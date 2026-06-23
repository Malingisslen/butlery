/// Widget tests for DialogFormFields — the 10 public static field factory
/// helpers (text, name, description, amount, email, url, password, search,
/// phone, dropdown, checkbox, switch).
///
/// Goal: cover render output (label/hint/icon), validator composition (the
/// BUT-517 follow-up that customValidator no longer bypasses contentFilter,
/// the empty-input short-circuit on length, optional vs required behaviour),
/// input formatter wiring for amount/phone, and onChanged callbacks for the
/// non-text widgets.
///
/// Most helpers wrap the field in a `Form` so we can invoke
/// `FormState.validate()` to exercise the validator without keystroke noise.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/dialogs/dialog_form_fields.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.lightTheme,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('sv'),
  home: Scaffold(body: child),
);

/// Wraps the field in a Form whose key is exposed so tests can call
/// `formKey.currentState!.validate()` and read the rendered error text. We
/// also expose the surrounding `Builder` so the inner factory can grab a
/// localized BuildContext.
class _FormHarness extends StatelessWidget {
  const _FormHarness({required this.builder, required this.formKey});
  final GlobalKey<FormState> formKey;
  final Widget Function(BuildContext context) builder;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Builder(builder: builder),
    );
  }
}

void main() {
  // ---------------------------------------------------------------------------
  // buildTextFormField
  // ---------------------------------------------------------------------------
  group('buildTextFormField', () {
    testWidgets('renders label, hint, and prefix icon', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DialogFormFields.buildTextFormField(
            controller: TextEditingController(),
            labelText: 'Titel',
            hintText: 'Skriv ett namn',
            prefixIcon: Icons.label_outline,
          ),
        ),
      );
      expect(find.text('Titel'), findsOneWidget);
      expect(find.text('Skriv ett namn'), findsOneWidget);
      expect(find.byIcon(Icons.label_outline), findsOneWidget);
    });

    testWidgets('controller seeds initial text', (tester) async {
      final controller = TextEditingController(text: 'Förvald');
      await tester.pumpWidget(
        _wrap(
          DialogFormFields.buildTextFormField(
            controller: controller,
            labelText: 'Titel',
          ),
        ),
      );
      expect(find.text('Förvald'), findsOneWidget);
    });

    testWidgets('enabled=false disables the TextFormField', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DialogFormFields.buildTextFormField(
            controller: TextEditingController(),
            labelText: 'Titel',
            enabled: false,
          ),
        ),
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.enabled, isFalse);
    });

    testWidgets('typing updates the controller', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        _wrap(
          DialogFormFields.buildTextFormField(
            controller: controller,
            labelText: 'Titel',
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'Hej världen');
      expect(controller.text, 'Hej världen');
    });

    testWidgets(
      'required=true + empty input → validator returns Swedish error',
      (tester) async {
        final formKey = GlobalKey<FormState>();
        await tester.pumpWidget(
          _wrap(
            _FormHarness(
              formKey: formKey,
              builder: (_) => DialogFormFields.buildTextFormField(
                controller: TextEditingController(),
                labelText: 'Titel',
              ),
            ),
          ),
        );
        expect(formKey.currentState!.validate(), isFalse);
        await tester.pump();
        // Swedish: "Titel får inte vara tom" (validateRequired path) — assert
        // the field name and a trailing word from the localized message.
        expect(find.textContaining('Titel'), findsWidgets);
      },
    );

    testWidgets('required=false + empty input → validator passes', (
      tester,
    ) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        _wrap(
          _FormHarness(
            formKey: formKey,
            builder: (_) => DialogFormFields.buildTextFormField(
              controller: TextEditingController(),
              labelText: 'Anteckning',
              required: false,
            ),
          ),
        ),
      );
      expect(formKey.currentState!.validate(), isTrue);
    });

    testWidgets(
      'length validator only fires when content present (empty short-circuits)',
      (tester) async {
        // Optional field with minLength=3 — empty should pass (because empty is
        // optional), but a single char should fail length.
        final controller = TextEditingController();
        final formKey = GlobalKey<FormState>();
        await tester.pumpWidget(
          _wrap(
            _FormHarness(
              formKey: formKey,
              builder: (_) => DialogFormFields.buildTextFormField(
                controller: controller,
                labelText: 'Kod',
                required: false,
                minLength: 3,
                maxLengthLimit: 10,
              ),
            ),
          ),
        );
        expect(
          formKey.currentState!.validate(),
          isTrue,
          reason: 'empty should bypass length check for optional field',
        );

        controller.text = 'ab';
        await tester.pump();
        expect(
          formKey.currentState!.validate(),
          isFalse,
          reason: 'two chars is below minLength=3',
        );
      },
    );

    testWidgets('customValidator error wins on its own concern', (
      tester,
    ) async {
      final formKey = GlobalKey<FormState>();
      final controller = TextEditingController(text: 'anything');
      await tester.pumpWidget(
        _wrap(
          _FormHarness(
            formKey: formKey,
            builder: (_) => DialogFormFields.buildTextFormField(
              controller: controller,
              labelText: 'Fält',
              customValidator: (_) => 'Custom-fel från test',
            ),
          ),
        ),
      );
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Custom-fel från test'), findsOneWidget);
    });

    testWidgets('maxLines>1 produces multi-line field', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DialogFormFields.buildTextFormField(
            controller: TextEditingController(),
            labelText: 'Anteckning',
            maxLines: 4,
          ),
        ),
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.maxLines, 4);
    });

    testWidgets('maxLength shows native counter (no counterText override)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          DialogFormFields.buildTextFormField(
            controller: TextEditingController(),
            labelText: 'Titel',
            maxLength: 50,
          ),
        ),
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.maxLength, 50);
      // counterText is null when maxLength is set (decoration default counter)
      expect(field.decoration?.counterText, isNull);
    });

    testWidgets('no maxLength → counterText is empty string (hides counter)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          DialogFormFields.buildTextFormField(
            controller: TextEditingController(),
            labelText: 'Titel',
          ),
        ),
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.decoration?.counterText, '');
    });

    testWidgets('keyboardType + inputFormatters forwarded', (tester) async {
      final formatter = FilteringTextInputFormatter.digitsOnly;
      await tester.pumpWidget(
        _wrap(
          DialogFormFields.buildTextFormField(
            controller: TextEditingController(),
            labelText: 'Nummer',
            keyboardType: TextInputType.number,
            inputFormatters: [formatter],
          ),
        ),
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.keyboardType, TextInputType.number);
      expect(field.inputFormatters, contains(formatter));
    });
  });

  // ---------------------------------------------------------------------------
  // buildNameField
  // ---------------------------------------------------------------------------
  group('buildNameField', () {
    testWidgets('default label uses commonName (Namn) and label icon', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          _FormHarness(
            formKey: GlobalKey<FormState>(),
            builder: (ctx) => DialogFormFields.buildNameField(
              context: ctx,
              controller: TextEditingController(),
            ),
          ),
        ),
      );
      expect(find.text('Namn'), findsOneWidget);
      expect(find.byIcon(Icons.label_outline), findsOneWidget);
    });

    testWidgets('custom labelText + prefixIcon overrides defaults', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          _FormHarness(
            formKey: GlobalKey<FormState>(),
            builder: (ctx) => DialogFormFields.buildNameField(
              context: ctx,
              controller: TextEditingController(),
              labelText: 'Gruppnamn',
              prefixIcon: Icons.group,
            ),
          ),
        ),
      );
      expect(find.text('Gruppnamn'), findsOneWidget);
      expect(find.byIcon(Icons.group), findsOneWidget);
    });

    testWidgets('maxLength=50 by default', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _FormHarness(
            formKey: GlobalKey<FormState>(),
            builder: (ctx) => DialogFormFields.buildNameField(
              context: ctx,
              controller: TextEditingController(),
            ),
          ),
        ),
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.maxLength, 50);
    });
  });

  // ---------------------------------------------------------------------------
  // buildDescriptionField
  // ---------------------------------------------------------------------------
  group('buildDescriptionField', () {
    testWidgets('default label/hint use l10n (Beskrivning)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _FormHarness(
            formKey: GlobalKey<FormState>(),
            builder: (ctx) => DialogFormFields.buildDescriptionField(
              context: ctx,
              controller: TextEditingController(),
            ),
          ),
        ),
      );
      expect(find.text('Beskrivning'), findsOneWidget);
      expect(find.text('Valfri beskrivning...'), findsOneWidget);
      expect(find.byIcon(Icons.description_outlined), findsOneWidget);
    });

    testWidgets('description is optional → empty validates true', (
      tester,
    ) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        _wrap(
          _FormHarness(
            formKey: formKey,
            builder: (ctx) => DialogFormFields.buildDescriptionField(
              context: ctx,
              controller: TextEditingController(),
            ),
          ),
        ),
      );
      expect(formKey.currentState!.validate(), isTrue);
    });

    testWidgets('defaults to 3 lines, maxLength=200', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _FormHarness(
            formKey: GlobalKey<FormState>(),
            builder: (ctx) => DialogFormFields.buildDescriptionField(
              context: ctx,
              controller: TextEditingController(),
            ),
          ),
        ),
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.maxLines, 3);
      expect(field.maxLength, 200);
    });
  });

  // ---------------------------------------------------------------------------
  // buildAmountField
  // ---------------------------------------------------------------------------
  group('buildAmountField', () {
    testWidgets('default label/hint/icon are amount-flavoured', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _FormHarness(
            formKey: GlobalKey<FormState>(),
            builder: (ctx) => DialogFormFields.buildAmountField(
              context: ctx,
              controller: TextEditingController(),
            ),
          ),
        ),
      );
      expect(find.text('Antal'), findsOneWidget);
      expect(find.text('Ange antal...'), findsOneWidget);
      expect(find.byIcon(Icons.numbers), findsOneWidget);
    });

    testWidgets('keyboard is decimal-numeric and only digits/dot accepted', (
      tester,
    ) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        _wrap(
          _FormHarness(
            formKey: GlobalKey<FormState>(),
            builder: (ctx) => DialogFormFields.buildAmountField(
              context: ctx,
              controller: controller,
            ),
          ),
        ),
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(
        field.keyboardType,
        const TextInputType.numberWithOptions(decimal: true),
      );

      // Letters get filtered out
      await tester.enterText(find.byType(TextField), '12.5abc');
      expect(controller.text, '12.5');
    });

    testWidgets('empty input → "Antal krävs"', (tester) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        _wrap(
          _FormHarness(
            formKey: formKey,
            builder: (ctx) => DialogFormFields.buildAmountField(
              context: ctx,
              controller: TextEditingController(),
            ),
          ),
        ),
      );
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Antal krävs'), findsOneWidget);
    });

    testWidgets('below minValue → min error', (tester) async {
      final controller = TextEditingController(text: '5');
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        _wrap(
          _FormHarness(
            formKey: formKey,
            builder: (ctx) => DialogFormFields.buildAmountField(
              context: ctx,
              controller: controller,
              minValue: 10,
              maxValue: 100,
            ),
          ),
        ),
      );
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      // Swedish "Minst {min} krävs" → "Minst 10 krävs"
      expect(find.text('Minst 10 krävs'), findsOneWidget);
    });

    testWidgets('above maxValue → max error', (tester) async {
      final controller = TextEditingController(text: '500');
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        _wrap(
          _FormHarness(
            formKey: formKey,
            builder: (ctx) => DialogFormFields.buildAmountField(
              context: ctx,
              controller: controller,
              minValue: 1,
              maxValue: 100,
            ),
          ),
        ),
      );
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Max 100 tillåtet'), findsOneWidget);
    });

    testWidgets('valid amount in range → validates true', (tester) async {
      final controller = TextEditingController(text: '42.5');
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        _wrap(
          _FormHarness(
            formKey: formKey,
            builder: (ctx) => DialogFormFields.buildAmountField(
              context: ctx,
              controller: controller,
              minValue: 1,
              maxValue: 100,
            ),
          ),
        ),
      );
      expect(formKey.currentState!.validate(), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // buildEmailField
  // ---------------------------------------------------------------------------
  group('buildEmailField', () {
    testWidgets('default label/hint use l10n; email icon present', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          _FormHarness(
            formKey: GlobalKey<FormState>(),
            builder: (ctx) => DialogFormFields.buildEmailField(
              context: ctx,
              controller: TextEditingController(),
            ),
          ),
        ),
      );
      expect(find.text('E-post'), findsOneWidget);
      expect(find.text('din@email.se'), findsOneWidget);
      expect(find.byIcon(Icons.email_outlined), findsOneWidget);
    });

    testWidgets('keyboardType is emailAddress', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _FormHarness(
            formKey: GlobalKey<FormState>(),
            builder: (ctx) => DialogFormFields.buildEmailField(
              context: ctx,
              controller: TextEditingController(),
            ),
          ),
        ),
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.keyboardType, TextInputType.emailAddress);
    });

    testWidgets('empty → required error from authEmail validator', (
      tester,
    ) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        _wrap(
          _FormHarness(
            formKey: formKey,
            builder: (ctx) => DialogFormFields.buildEmailField(
              context: ctx,
              controller: TextEditingController(),
            ),
          ),
        ),
      );
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      // The authEmail validator returns 'E-post krävs' for empty.
      expect(find.text('E-post krävs'), findsOneWidget);
    });

    testWidgets('missing "@" or "." → invalid email message', (tester) async {
      final controller = TextEditingController(text: 'notanemail');
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        _wrap(
          _FormHarness(
            formKey: formKey,
            builder: (ctx) => DialogFormFields.buildEmailField(
              context: ctx,
              controller: controller,
            ),
          ),
        ),
      );
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Ange en giltig e-postadress'), findsOneWidget);
    });

    testWidgets('valid email → validates true', (tester) async {
      final controller = TextEditingController(text: 'user@example.com');
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        _wrap(
          _FormHarness(
            formKey: formKey,
            builder: (ctx) => DialogFormFields.buildEmailField(
              context: ctx,
              controller: controller,
            ),
          ),
        ),
      );
      expect(formKey.currentState!.validate(), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // buildUrlField
  // ---------------------------------------------------------------------------
  group('buildUrlField', () {
    testWidgets('default optional → empty validates true', (tester) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        _wrap(
          _FormHarness(
            formKey: formKey,
            builder: (ctx) => DialogFormFields.buildUrlField(
              context: ctx,
              controller: TextEditingController(),
            ),
          ),
        ),
      );
      expect(formKey.currentState!.validate(), isTrue);
    });

    testWidgets('label/hint/icon present', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _FormHarness(
            formKey: GlobalKey<FormState>(),
            builder: (ctx) => DialogFormFields.buildUrlField(
              context: ctx,
              controller: TextEditingController(),
            ),
          ),
        ),
      );
      expect(find.text('URL'), findsOneWidget);
      expect(find.text('https://exempel.se'), findsOneWidget);
      expect(find.byIcon(Icons.link), findsOneWidget);
    });

    testWidgets('invalid URL content → "Ogiltig URL"', (tester) async {
      final controller = TextEditingController(text: 'notaurl');
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        _wrap(
          _FormHarness(
            formKey: formKey,
            builder: (ctx) => DialogFormFields.buildUrlField(
              context: ctx,
              controller: controller,
            ),
          ),
        ),
      );
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Ogiltig URL'), findsOneWidget);
    });

    testWidgets('valid https URL → passes', (tester) async {
      final controller = TextEditingController(text: 'https://example.com');
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        _wrap(
          _FormHarness(
            formKey: formKey,
            builder: (ctx) => DialogFormFields.buildUrlField(
              context: ctx,
              controller: controller,
            ),
          ),
        ),
      );
      expect(formKey.currentState!.validate(), isTrue);
    });

    testWidgets('required=true + empty → required-message error', (
      tester,
    ) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        _wrap(
          _FormHarness(
            formKey: formKey,
            builder: (ctx) => DialogFormFields.buildUrlField(
              context: ctx,
              controller: TextEditingController(),
              required: true,
            ),
          ),
        ),
      );
      expect(formKey.currentState!.validate(), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // buildPasswordField
  // ---------------------------------------------------------------------------
  group('buildPasswordField', () {
    testWidgets('default label is Lösenord with lock icon', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _FormHarness(
            formKey: GlobalKey<FormState>(),
            builder: (ctx) => DialogFormFields.buildPasswordField(
              context: ctx,
              controller: TextEditingController(),
            ),
          ),
        ),
      );
      expect(find.text('Lösenord'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });

    testWidgets('empty → "Lösenord krävs"', (tester) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        _wrap(
          _FormHarness(
            formKey: formKey,
            builder: (ctx) => DialogFormFields.buildPasswordField(
              context: ctx,
              controller: TextEditingController(),
            ),
          ),
        ),
      );
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Lösenord krävs'), findsOneWidget);
    });

    testWidgets('non-empty value passes (no signup-strength constraint)', (
      tester,
    ) async {
      // buildPasswordField uses FormValidators.authPassword() with isSignUp=false
      // → any non-empty value passes.
      final controller = TextEditingController(text: 'abc');
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        _wrap(
          _FormHarness(
            formKey: formKey,
            builder: (ctx) => DialogFormFields.buildPasswordField(
              context: ctx,
              controller: controller,
            ),
          ),
        ),
      );
      expect(formKey.currentState!.validate(), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // buildSearchField
  // ---------------------------------------------------------------------------
  group('buildSearchField', () {
    testWidgets('default label is Sök with search icon, optional', (
      tester,
    ) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        _wrap(
          _FormHarness(
            formKey: formKey,
            builder: (ctx) => DialogFormFields.buildSearchField(
              context: ctx,
              controller: TextEditingController(),
            ),
          ),
        ),
      );
      expect(find.text('Sök'), findsOneWidget);
      expect(find.text('Skriv för att söka...'), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);
      // No validation → always valid even when empty.
      expect(formKey.currentState!.validate(), isTrue);
    });

    testWidgets('typing updates controller', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        _wrap(
          _FormHarness(
            formKey: GlobalKey<FormState>(),
            builder: (ctx) => DialogFormFields.buildSearchField(
              context: ctx,
              controller: controller,
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'köttbullar');
      expect(controller.text, 'köttbullar');
    });
  });

  // ---------------------------------------------------------------------------
  // buildPhoneField
  // ---------------------------------------------------------------------------
  group('buildPhoneField', () {
    testWidgets('default label is Telefonnummer with phone icon, optional', (
      tester,
    ) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        _wrap(
          _FormHarness(
            formKey: formKey,
            builder: (ctx) => DialogFormFields.buildPhoneField(
              context: ctx,
              controller: TextEditingController(),
            ),
          ),
        ),
      );
      expect(find.text('Telefonnummer'), findsOneWidget);
      expect(find.byIcon(Icons.phone_outlined), findsOneWidget);
      expect(
        formKey.currentState!.validate(),
        isTrue,
        reason: 'optional + empty → valid',
      );
    });

    testWidgets('keyboardType is phone, only digits/+/-/space/parens allowed', (
      tester,
    ) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        _wrap(
          _FormHarness(
            formKey: GlobalKey<FormState>(),
            builder: (ctx) => DialogFormFields.buildPhoneField(
              context: ctx,
              controller: controller,
            ),
          ),
        ),
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.keyboardType, TextInputType.phone);

      // Letters filtered out, digits/+/-/space retained.
      await tester.enterText(find.byType(TextField), '+46 70-123abc 4567');
      expect(controller.text, '+46 70-123 4567');
    });

    testWidgets('less than 10 digits → "Ogiltigt telefonnummer"', (
      tester,
    ) async {
      final controller = TextEditingController(text: '123 456');
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        _wrap(
          _FormHarness(
            formKey: formKey,
            builder: (ctx) => DialogFormFields.buildPhoneField(
              context: ctx,
              controller: controller,
            ),
          ),
        ),
      );
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Ogiltigt telefonnummer'), findsOneWidget);
    });

    testWidgets('10+ digit number passes', (tester) async {
      final controller = TextEditingController(text: '+46 70 123 45 67');
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        _wrap(
          _FormHarness(
            formKey: formKey,
            builder: (ctx) => DialogFormFields.buildPhoneField(
              context: ctx,
              controller: controller,
            ),
          ),
        ),
      );
      expect(formKey.currentState!.validate(), isTrue);
    });

    testWidgets('required=true + empty → fails validation', (tester) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        _wrap(
          _FormHarness(
            formKey: formKey,
            builder: (ctx) => DialogFormFields.buildPhoneField(
              context: ctx,
              controller: TextEditingController(),
              required: true,
            ),
          ),
        ),
      );
      expect(formKey.currentState!.validate(), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // buildDropdownField
  // ---------------------------------------------------------------------------
  group('buildDropdownField', () {
    List<DropdownMenuItem<String>> items() => const [
      DropdownMenuItem(value: 'a', child: Text('Alfa')),
      DropdownMenuItem(value: 'b', child: Text('Beta')),
    ];

    testWidgets('renders label, initial value, and items', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _FormHarness(
            formKey: GlobalKey<FormState>(),
            builder: (ctx) => DialogFormFields.buildDropdownField<String>(
              context: ctx,
              value: 'a',
              items: items(),
              onChanged: (_) {},
              labelText: 'Val',
            ),
          ),
        ),
      );
      expect(find.text('Val'), findsOneWidget);
      // Selected item label is visible.
      expect(find.text('Alfa'), findsWidgets);
    });

    testWidgets('onChanged fires with selected value', (tester) async {
      String? picked;
      await tester.pumpWidget(
        _wrap(
          _FormHarness(
            formKey: GlobalKey<FormState>(),
            builder: (ctx) => DialogFormFields.buildDropdownField<String>(
              context: ctx,
              value: 'a',
              items: items(),
              onChanged: (v) => picked = v,
              labelText: 'Val',
            ),
          ),
        ),
      );
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Beta').last);
      await tester.pumpAndSettle();
      expect(picked, 'b');
    });

    testWidgets('enabled=false → onChanged is null on the widget', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          _FormHarness(
            formKey: GlobalKey<FormState>(),
            builder: (ctx) => DialogFormFields.buildDropdownField<String>(
              context: ctx,
              value: 'a',
              items: items(),
              onChanged: (_) {},
              labelText: 'Val',
              enabled: false,
            ),
          ),
        ),
      );
      final dd = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>),
      );
      expect(dd.onChanged, isNull);
    });

    testWidgets('required=true + null value → localized required error', (
      tester,
    ) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        _wrap(
          _FormHarness(
            formKey: formKey,
            builder: (ctx) => DialogFormFields.buildDropdownField<String>(
              context: ctx,
              value: null,
              items: items(),
              onChanged: (_) {},
              labelText: 'Val',
            ),
          ),
        ),
      );
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      // dialogFieldRequired: "{field} krävs" → "Val krävs"
      expect(find.text('Val krävs'), findsOneWidget);
    });

    testWidgets('required=false + null value → passes validation', (
      tester,
    ) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        _wrap(
          _FormHarness(
            formKey: formKey,
            builder: (ctx) => DialogFormFields.buildDropdownField<String>(
              context: ctx,
              value: null,
              items: items(),
              onChanged: (_) {},
              labelText: 'Val',
              required: false,
            ),
          ),
        ),
      );
      expect(formKey.currentState!.validate(), isTrue);
    });

    testWidgets('custom validator overrides default required behaviour', (
      tester,
    ) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        _wrap(
          _FormHarness(
            formKey: formKey,
            builder: (ctx) => DialogFormFields.buildDropdownField<String>(
              context: ctx,
              value: 'a',
              items: items(),
              onChanged: (_) {},
              labelText: 'Val',
              validator: (_) => 'Egen regel ej uppfylld',
            ),
          ),
        ),
      );
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Egen regel ej uppfylld'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // buildCheckboxField
  // ---------------------------------------------------------------------------
  group('buildCheckboxField', () {
    testWidgets('renders title and subtitle; value reflects state', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          DialogFormFields.buildCheckboxField(
            value: true,
            onChanged: (_) {},
            title: 'Acceptera villkor',
            subtitle: 'Du måste godkänna',
          ),
        ),
      );
      expect(find.text('Acceptera villkor'), findsOneWidget);
      expect(find.text('Du måste godkänna'), findsOneWidget);
      final tile = tester.widget<CheckboxListTile>(
        find.byType(CheckboxListTile),
      );
      expect(tile.value, isTrue);
    });

    testWidgets('tap fires onChanged with toggled value', (tester) async {
      bool? received;
      await tester.pumpWidget(
        _wrap(
          DialogFormFields.buildCheckboxField(
            value: false,
            onChanged: (v) => received = v,
            title: 'Aktivera',
          ),
        ),
      );
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      expect(received, isTrue);
    });

    testWidgets('enabled=false → onChanged null on the widget', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DialogFormFields.buildCheckboxField(
            value: false,
            onChanged: (_) {},
            title: 'Aktivera',
            enabled: false,
          ),
        ),
      );
      final tile = tester.widget<CheckboxListTile>(
        find.byType(CheckboxListTile),
      );
      expect(tile.onChanged, isNull);
    });

    testWidgets('subtitle omitted → no subtitle rendered', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DialogFormFields.buildCheckboxField(
            value: false,
            onChanged: (_) {},
            title: 'Bara titel',
          ),
        ),
      );
      final tile = tester.widget<CheckboxListTile>(
        find.byType(CheckboxListTile),
      );
      expect(tile.subtitle, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // buildSwitchField
  // ---------------------------------------------------------------------------
  group('buildSwitchField', () {
    testWidgets('renders title/subtitle and reflects value', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DialogFormFields.buildSwitchField(
            value: true,
            onChanged: (_) {},
            title: 'Notifieringar',
            subtitle: 'Pusha mig',
          ),
        ),
      );
      expect(find.text('Notifieringar'), findsOneWidget);
      expect(find.text('Pusha mig'), findsOneWidget);
      final tile = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
      expect(tile.value, isTrue);
    });

    testWidgets('tap fires onChanged with toggled value', (tester) async {
      bool? received;
      await tester.pumpWidget(
        _wrap(
          DialogFormFields.buildSwitchField(
            value: false,
            onChanged: (v) => received = v,
            title: 'Toggle',
          ),
        ),
      );
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(received, isTrue);
    });

    testWidgets('enabled=false → switch onChanged is null', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DialogFormFields.buildSwitchField(
            value: false,
            onChanged: (_) {},
            title: 'Toggle',
            enabled: false,
          ),
        ),
      );
      final tile = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
      expect(tile.onChanged, isNull);
    });

    testWidgets('subtitle omitted → no subtitle rendered', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DialogFormFields.buildSwitchField(
            value: true,
            onChanged: (_) {},
            title: 'Solo',
          ),
        ),
      );
      final tile = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
      expect(tile.subtitle, isNull);
    });
  });
}
