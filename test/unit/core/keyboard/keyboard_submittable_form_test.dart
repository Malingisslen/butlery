// test/unit/core/keyboard/keyboard_submittable_form_test.dart
//
// BUT-521 follow-up: behavioral coverage for the form-submit override.
// Each test asserts the *contract* (when does onSubmit fire?), not the
// implementation. We test through the production keyboard layer so the
// activator → intent → action chain is exercised end-to-end.

import 'package:butlery/core/keyboard/app_shortcuts.dart';
import 'package:butlery/core/keyboard/keyboard_submittable_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('KeyboardSubmittableForm', () {
    testWidgets('Actions.invoke<SubmitFormIntent> fires onSubmit', (
      tester,
    ) async {
      var fired = 0;
      late BuildContext capturedContext;

      await tester.pumpWidget(
        MaterialApp(
          home: KeyboardSubmittableForm(
            onSubmit: () => fired++,
            child: Builder(
              builder: (context) {
                capturedContext = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      Actions.invoke(capturedContext, const SubmitFormIntent());
      await tester.pump();

      expect(fired, 1);
    });

    testWidgets('skips onSubmit when validateBeforeSubmit and form invalid', (
      tester,
    ) async {
      final formKey = GlobalKey<FormState>();
      var fired = 0;
      late BuildContext capturedContext;

      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: KeyboardSubmittableForm(
              formKey: formKey,
              onSubmit: () => fired++,
              child: Builder(
                builder: (context) {
                  capturedContext = context;
                  return TextFormField(
                    // Always-fail validator so validate() returns false.
                    validator: (_) => 'required',
                    autovalidateMode: AutovalidateMode.disabled,
                  );
                },
              ),
            ),
          ),
        ),
      );

      Actions.invoke(capturedContext, const SubmitFormIntent());
      await tester.pump();

      expect(fired, 0);
    });

    testWidgets(
      'fires onSubmit when validateBeforeSubmit and form valid',
      (tester) async {
        final formKey = GlobalKey<FormState>();
        var fired = 0;
        late BuildContext capturedContext;

        await tester.pumpWidget(
          MaterialApp(
            home: Material(
              child: KeyboardSubmittableForm(
                formKey: formKey,
                onSubmit: () => fired++,
                child: Builder(
                  builder: (context) {
                    capturedContext = context;
                    // No validators → validate() returns true.
                    return const TextField();
                  },
                ),
              ),
            ),
          ),
        );

        Actions.invoke(capturedContext, const SubmitFormIntent());
        await tester.pump();

        expect(fired, 1);
      },
    );

    testWidgets(
      'when validateBeforeSubmit=false, onSubmit fires even with invalid form',
      (tester) async {
        final formKey = GlobalKey<FormState>();
        var fired = 0;
        late BuildContext capturedContext;

        await tester.pumpWidget(
          MaterialApp(
            home: Material(
              child: KeyboardSubmittableForm(
                formKey: formKey,
                validateBeforeSubmit: false,
                onSubmit: () => fired++,
                child: Builder(
                  builder: (context) {
                    capturedContext = context;
                    return TextFormField(validator: (_) => 'required');
                  },
                ),
              ),
            ),
          ),
        );

        Actions.invoke(capturedContext, const SubmitFormIntent());
        await tester.pump();

        expect(fired, 1);
      },
    );

    testWidgets(
      'Ctrl+Enter through full Shortcuts/Actions stack fires onSubmit',
      (tester) async {
        // Proves the activator → intent → override action chain works end
        // to end — not just direct Actions.invoke.
        var fired = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: Shortcuts(
              shortcuts: AppShortcuts.bindings,
              child: KeyboardSubmittableForm(
                onSubmit: () => fired++,
                child: const Focus(
                  autofocus: true,
                  child: SizedBox(width: 100, height: 100),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Test runs as android by default → control branch in AppShortcuts.
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pump();

        expect(fired, 1);
      },
    );
  });
}
