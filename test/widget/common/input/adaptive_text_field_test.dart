/// Widget tests for AdaptiveTextField.
///
/// The widget branches on `dart:io Platform.isIOS` (NOT
/// `defaultTargetPlatform`), so `debugDefaultTargetPlatformOverride` has no
/// effect. The Flutter test host is always Windows/Linux/macOS, so the
/// Cupertino branch is unreachable from a unit widget test — we cover the
/// Material (TextFormField) branch which is what Android/web/desktop users
/// hit. The iOS Cupertino branch is exercised by manual QA on iOS hardware.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/widgets/common/input/adaptive_text_field.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('AdaptiveTextField — render (Material branch)', () {
    testWidgets('renders a TextFormField', (tester) async {
      await tester.pumpWidget(_wrap(const AdaptiveTextField()));
      expect(find.byType(TextFormField), findsOneWidget);
    });

    testWidgets('label is forwarded to InputDecoration.labelText',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const AdaptiveTextField(label: 'Namn'),
      ));
      expect(find.text('Namn'), findsOneWidget);
    });

    testWidgets('placeholder is forwarded to InputDecoration.hintText',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const AdaptiveTextField(placeholder: 'Skriv här'),
      ));
      // Hint is rendered as a Text widget inside the field.
      expect(find.text('Skriv här'), findsOneWidget);
    });

    testWidgets('helperText is rendered below the field', (tester) async {
      await tester.pumpWidget(_wrap(
        const AdaptiveTextField(helperText: 'Max 30 tecken'),
      ));
      expect(find.text('Max 30 tecken'), findsOneWidget);
    });

    testWidgets('errorText is rendered below the field', (tester) async {
      await tester.pumpWidget(_wrap(
        const AdaptiveTextField(errorText: 'Får inte vara tomt'),
      ));
      expect(find.text('Får inte vara tomt'), findsOneWidget);
    });

    testWidgets('prefix widget is rendered (prefixIcon slot)', (tester) async {
      await tester.pumpWidget(_wrap(
        const AdaptiveTextField(prefix: Icon(Icons.search)),
      ));
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('suffix widget is rendered (suffixIcon slot)', (tester) async {
      await tester.pumpWidget(_wrap(
        const AdaptiveTextField(suffix: Icon(Icons.clear)),
      ));
      expect(find.byIcon(Icons.clear), findsOneWidget);
    });
  });

  group('AdaptiveTextField — controller + callbacks', () {
    testWidgets('initial controller text is displayed', (tester) async {
      final controller = TextEditingController(text: 'hej');
      addTearDown(controller.dispose);
      await tester.pumpWidget(_wrap(
        AdaptiveTextField(controller: controller),
      ));
      expect(find.text('hej'), findsOneWidget);
    });

    testWidgets('onChanged fires for each character entered', (tester) async {
      final received = <String>[];
      await tester.pumpWidget(_wrap(
        AdaptiveTextField(onChanged: received.add),
      ));
      await tester.enterText(find.byType(TextFormField), 'ab');
      // enterText sends the whole string in one go — onChanged sees the
      // final aggregated value.
      expect(received, contains('ab'));
    });

    testWidgets('onSubmitted is forwarded to TextFormField.onFieldSubmitted',
        (tester) async {
      String? submitted;
      await tester.pumpWidget(_wrap(
        AdaptiveTextField(onSubmitted: (v) => submitted = v),
      ));
      await tester.enterText(find.byType(TextFormField), 'klar');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(submitted, equals('klar'));
    });

    testWidgets('onTap fires when field is tapped', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(_wrap(
        AdaptiveTextField(onTap: () => tapped++),
      ));
      await tester.tap(find.byType(TextFormField));
      await tester.pump();
      expect(tapped, 1);
    });
  });

  group('AdaptiveTextField — enabled / readOnly / obscure', () {
    testWidgets('enabled=false → TextFormField.enabled is false',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const AdaptiveTextField(enabled: false),
      ));
      final field = tester.widget<TextFormField>(find.byType(TextFormField));
      expect(field.enabled, isFalse);
    });

    testWidgets('readOnly=true is forwarded', (tester) async {
      // readOnly is on the underlying EditableText; we assert via the
      // rendered EditableText state.
      await tester.pumpWidget(_wrap(
        AdaptiveTextField(
          controller: TextEditingController(text: 'locked'),
          readOnly: true,
        ),
      ));
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.readOnly, isTrue);
    });

    testWidgets('obscureText=true → underlying EditableText.obscureText=true',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const AdaptiveTextField(obscureText: true),
      ));
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.obscureText, isTrue);
    });
  });

  group('AdaptiveTextField — line limits + maxLength', () {
    testWidgets('default maxLines=1', (tester) async {
      await tester.pumpWidget(_wrap(const AdaptiveTextField()));
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.maxLines, 1);
    });

    testWidgets('maxLines forwarded', (tester) async {
      await tester.pumpWidget(_wrap(
        const AdaptiveTextField(maxLines: 5),
      ));
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.maxLines, 5);
    });

    testWidgets('minLines forwarded', (tester) async {
      await tester.pumpWidget(_wrap(
        const AdaptiveTextField(minLines: 2, maxLines: 5),
      ));
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.minLines, 2);
    });

    testWidgets('maxLength forwarded — counter appears below the field',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const AdaptiveTextField(maxLength: 10),
      ));
      // TextFormField does not expose maxLength on its outer widget; the
      // observable effect is the counter "0/10" rendered by the decoration.
      expect(find.text('0/10'), findsOneWidget);
    });
  });

  group('AdaptiveTextField — keyboard + autofill + capitalization', () {
    testWidgets('keyboardType forwarded', (tester) async {
      await tester.pumpWidget(_wrap(
        const AdaptiveTextField(keyboardType: TextInputType.emailAddress),
      ));
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.keyboardType, TextInputType.emailAddress);
    });

    testWidgets('textInputAction forwarded', (tester) async {
      await tester.pumpWidget(_wrap(
        const AdaptiveTextField(textInputAction: TextInputAction.search),
      ));
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.textInputAction, TextInputAction.search);
    });

    testWidgets('autofillHints forwarded', (tester) async {
      await tester.pumpWidget(_wrap(
        const AdaptiveTextField(autofillHints: [AutofillHints.email]),
      ));
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.autofillHints, contains(AutofillHints.email));
    });

    testWidgets('textCapitalization forwarded (non-default)', (tester) async {
      await tester.pumpWidget(_wrap(
        const AdaptiveTextField(
          textCapitalization: TextCapitalization.sentences,
        ),
      ));
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.textCapitalization, TextCapitalization.sentences);
    });

    testWidgets('default textCapitalization is none', (tester) async {
      await tester.pumpWidget(_wrap(const AdaptiveTextField()));
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.textCapitalization, TextCapitalization.none);
    });
  });

  group('AdaptiveTextField — input formatters + validator + focus', () {
    testWidgets('inputFormatters restrict input (digits only)', (tester) async {
      await tester.pumpWidget(_wrap(
        AdaptiveTextField(
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
      ));
      await tester.enterText(find.byType(TextFormField), 'a1b2c3');
      // Letters filtered out — only digits remain.
      expect(find.text('123'), findsOneWidget);
    });

    testWidgets('validator runs inside a Form and surfaces errorText',
        (tester) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Form(
            key: formKey,
            child: AdaptiveTextField(
              validator: (v) => (v == null || v.isEmpty) ? 'krävs' : null,
            ),
          ),
        ),
      ));
      // Run validation on the empty field.
      formKey.currentState!.validate();
      await tester.pump();
      expect(find.text('krävs'), findsOneWidget);
    });

    testWidgets('autofocus=true → field has primary focus after first frame',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const AdaptiveTextField(autofocus: true),
      ));
      await tester.pump();
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.focusNode.hasFocus, isTrue);
    });

    testWidgets('focusNode is forwarded and can request focus externally',
        (tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      await tester.pumpWidget(_wrap(
        AdaptiveTextField(focusNode: focusNode),
      ));
      expect(focusNode.hasFocus, isFalse);
      focusNode.requestFocus();
      await tester.pump();
      expect(focusNode.hasFocus, isTrue);
    });
  });

  // SKIP: iOS Cupertino branch (CupertinoTextField path) — `Platform.isIOS`
  // cannot be overridden via `debugDefaultTargetPlatformOverride` and the
  // test host is never iOS. Exercised by manual QA on iOS hardware. This
  // covers the Cupertino-specific code paths: label-above rendering, hasError
  // border thickness/colour, Cupertino-styled prefix/suffix padding, and
  // helper/error text styling with CupertinoColors.
}
