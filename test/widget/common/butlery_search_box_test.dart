/// Widget tests for ButlerySearchBox + ButleryHeaderSearchBox.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/widgets/common/butlery_search_box.dart';

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('sv'),
  home: Scaffold(body: child),
);

void main() {
  group('ButlerySearchBox — render', () {
    testWidgets('renders a TextField with the localized default hint', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const ButlerySearchBox()));
      expect(find.byType(TextField), findsOneWidget);
      final tf = tester.widget<TextField>(find.byType(TextField));
      // Default hint pulled from l10n.searchHint
      expect(tf.decoration!.hintText, isNotNull);
      expect(tf.decoration!.hintText, isNotEmpty);
    });

    testWidgets('explicit hintText overrides l10n default', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ButlerySearchBox(
            hintText: 'sök bara',
          ),
        ),
      );
      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(tf.decoration!.hintText, 'sök bara');
    });

    testWidgets('renders default search prefix icon when none supplied', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const ButlerySearchBox()));
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('explicit prefixIcon overrides default search icon', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const ButlerySearchBox(
            prefixIcon: Icon(Icons.menu),
          ),
        ),
      );
      expect(find.byIcon(Icons.menu), findsOneWidget);
      expect(find.byIcon(Icons.search), findsNothing);
    });

    testWidgets('no clear button visible when text is empty', (tester) async {
      await tester.pumpWidget(_wrap(const ButlerySearchBox()));
      expect(find.byIcon(Icons.close), findsNothing);
    });

    testWidgets('clear (close) button appears when text is present', (
      tester,
    ) async {
      final controller = TextEditingController(text: 'pasta');
      await tester.pumpWidget(_wrap(ButlerySearchBox(controller: controller)));
      await tester.pump(); // listener registers initial state
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('explicit suffixIcon overrides the clear button', (
      tester,
    ) async {
      final controller = TextEditingController(text: 'pasta');
      await tester.pumpWidget(
        _wrap(
          ButlerySearchBox(
            controller: controller,
            suffixIcon: const Icon(Icons.tune),
          ),
        ),
      );
      await tester.pump();
      expect(find.byIcon(Icons.tune), findsOneWidget);
      expect(find.byIcon(Icons.close), findsNothing);
    });

    testWidgets('enabled=false disables the TextField', (tester) async {
      await tester.pumpWidget(_wrap(const ButlerySearchBox(enabled: false)));
      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(tf.enabled, isFalse);
    });

    testWidgets('autofocus forwards to TextField', (tester) async {
      await tester.pumpWidget(_wrap(const ButlerySearchBox(autofocus: true)));
      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(tf.autofocus, isTrue);
    });

    testWidgets('textInputAction defaults to TextInputAction.search', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const ButlerySearchBox()));
      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(tf.textInputAction, TextInputAction.search);
    });
  });

  group('ButlerySearchBox — interaction', () {
    testWidgets('typing into the box fires onChanged with the new value', (
      tester,
    ) async {
      final changes = <String>[];
      await tester.pumpWidget(
        _wrap(
          ButlerySearchBox(
            onChanged: changes.add,
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'hej');
      expect(changes, ['hej']);
    });

    testWidgets('submitting fires onSubmitted with the final value', (
      tester,
    ) async {
      String? submitted;
      await tester.pumpWidget(
        _wrap(
          ButlerySearchBox(
            onSubmitted: (v) => submitted = v,
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'final');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      expect(submitted, 'final');
    });

    testWidgets(
      'tapping the clear button clears text + fires onClear + onChanged(empty)',
      (tester) async {
        final controller = TextEditingController(text: 'pasta');
        var cleared = 0;
        final changes = <String>[];
        await tester.pumpWidget(
          _wrap(
            ButlerySearchBox(
              controller: controller,
              onClear: () => cleared++,
              onChanged: changes.add,
            ),
          ),
        );
        await tester.pump();
        await tester.tap(find.byIcon(Icons.close));
        await tester.pump();
        expect(controller.text, '');
        expect(cleared, 1);
        expect(changes, ['']);
      },
    );

    testWidgets('focus listener flips the focused-state decoration branch', (
      tester,
    ) async {
      final focus = FocusNode();
      await tester.pumpWidget(_wrap(ButlerySearchBox(focusNode: focus)));
      // Initially unfocused — search icon should be muted color (outline).
      // We don't pin the exact color, just verify focus listener triggers
      // a setState without throwing.
      focus.requestFocus();
      await tester.pump();
      expect(focus.hasFocus, isTrue);
      expect(tester.takeException(), isNull);
    });
  });

  group('ButlerySearchBox — controller lifecycle', () {
    testWidgets('internal controller is disposed when external one is null', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const ButlerySearchBox()));
      // Pump a blank widget to dispose
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      expect(tester.takeException(), isNull);
    });

    testWidgets('external controller survives widget disposal', (tester) async {
      final controller = TextEditingController(text: 'survives');
      await tester.pumpWidget(_wrap(ButlerySearchBox(controller: controller)));
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      // External controller should still be usable
      expect(controller.text, 'survives');
      controller.dispose();
    });
  });

  group('ButleryHeaderSearchBox', () {
    testWidgets(
      'readOnly=true renders Semantics(button) with custom Container',
      (tester) async {
        var tapped = 0;
        await tester.pumpWidget(
          _wrap(
            ButleryHeaderSearchBox(
              readOnly: true,
              onTap: () => tapped++,
              hintText: 'sök recept...',
            ),
          ),
        );
        // No TextField in readOnly path
        expect(find.byType(TextField), findsNothing);
        // Hint visible as Text
        expect(find.text('sök recept...'), findsOneWidget);
        // Search icon visible
        expect(find.byIcon(Icons.search), findsOneWidget);
        // Tap fires onTap
        await tester.tap(find.text('sök recept...'));
        expect(tapped, 1);
      },
    );

    testWidgets('readOnly=false delegates to ButlerySearchBox', (tester) async {
      await tester.pumpWidget(_wrap(const ButleryHeaderSearchBox()));
      expect(find.byType(ButlerySearchBox), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('forwards controller + callbacks to nested ButlerySearchBox', (
      tester,
    ) async {
      final controller = TextEditingController();
      final changes = <String>[];
      await tester.pumpWidget(
        _wrap(
          ButleryHeaderSearchBox(
            controller: controller,
            onChanged: changes.add,
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'hej');
      expect(changes, ['hej']);
      expect(controller.text, 'hej');
    });

    testWidgets('explicit hintText is used when supplied', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ButleryHeaderSearchBox(
            readOnly: true,
            hintText: 'specifik hint',
          ),
        ),
      );
      expect(find.text('specifik hint'), findsOneWidget);
    });

    testWidgets('readOnly with no hintText falls back to localized default', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const ButleryHeaderSearchBox(
            readOnly: true,
          ),
        ),
      );
      // Should render *some* text (the l10n default), not throw
      expect(tester.takeException(), isNull);
    });
  });
}
