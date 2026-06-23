/// Widget tests for the InputComponents facade.
///
/// Verifies each factory returns the right concrete widget with the
/// arguments forwarded correctly, and that the modal openers actually
/// mount their dialog/sheet widget into the tree.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/widgets/common/input_components.dart';
import 'package:butlery/widgets/common/input/instruction_editor.dart';
import 'package:butlery/widgets/common/input/portion_scaler.dart';
import 'package:butlery/widgets/common/input/debounced_checkbox.dart';
import 'package:butlery/widgets/common/input/shopping_item_dialog.dart';

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('sv'),
  home: Scaffold(body: child),
);

void main() {
  group('InputComponents.instructionEditor', () {
    testWidgets('returns an InstructionEditor with the supplied instructions', (
      tester,
    ) async {
      final widget = InputComponents.instructionEditor(
        initialInstructions: const ['Step 1', 'Step 2'],
        onChanged: (_) {},
      );
      expect(widget, isA<InstructionEditor>());
      final editor = widget as InstructionEditor;
      expect(editor.initialInstructions, const ['Step 1', 'Step 2']);
      expect(editor.onChanged, isNotNull);

      await tester.pumpWidget(_wrap(widget));
      // Each instruction renders as a text field with the initial text.
      expect(find.text('Step 1'), findsOneWidget);
      expect(find.text('Step 2'), findsOneWidget);
    });

    testWidgets('forwards null onChanged when omitted', (tester) async {
      final widget = InputComponents.instructionEditor(
        initialInstructions: const [],
      );
      expect(widget, isA<InstructionEditor>());
      expect((widget as InstructionEditor).onChanged, isNull);
    });
  });

  group('InputComponents.portionScaler', () {
    testWidgets('returns a PortionScaler with defaults', (tester) async {
      final widget = InputComponents.portionScaler(
        originalPortions: 4,
        originalIngredients: const ['200 g pasta'],
        onPortionChanged: (_, __) {},
      );
      expect(widget, isA<PortionScaler>());
      final scaler = widget as PortionScaler;
      expect(scaler.originalPortions, 4);
      expect(scaler.originalIngredients, const ['200 g pasta']);
      expect(scaler.minPortions, 1);
      expect(scaler.maxPortions, 20);
    });

    testWidgets('forwards custom min/maxPortions', (tester) async {
      final widget = InputComponents.portionScaler(
        originalPortions: 6,
        originalIngredients: const [],
        onPortionChanged: (_, __) {},
        minPortions: 2,
        maxPortions: 30,
      );
      final scaler = widget as PortionScaler;
      expect(scaler.minPortions, 2);
      expect(scaler.maxPortions, 30);
    });
  });

  group('InputComponents.debouncedCheckbox', () {
    testWidgets('returns a DebouncedCheckbox with supplied value', (
      tester,
    ) async {
      final widget = InputComponents.debouncedCheckbox(
        value: true,
        onChanged: (_) {},
      );
      expect(widget, isA<DebouncedCheckbox>());
      final cb = widget as DebouncedCheckbox;
      expect(cb.value, isTrue);
      expect(cb.onChanged, isNotNull);
    });

    testWidgets('forwards activeColor and debounceDuration', (tester) async {
      const dur = Duration(milliseconds: 999);
      final widget = InputComponents.debouncedCheckbox(
        value: false,
        onChanged: null,
        activeColor: const Color(0xFF112233),
        debounceDuration: dur,
      );
      final cb = widget as DebouncedCheckbox;
      expect(cb.value, isFalse);
      expect(cb.activeColor, const Color(0xFF112233));
      expect(cb.debounceDuration, dur);
      expect(cb.onChanged, isNull);
    });

    testWidgets('mounts and renders without throwing', (tester) async {
      await tester.pumpWidget(
        _wrap(
          InputComponents.debouncedCheckbox(
            value: false,
            onChanged: (_) {},
          ),
        ),
      );
      expect(find.byType(DebouncedCheckbox), findsOneWidget);
      expect(find.byType(Checkbox), findsOneWidget);
    });
  });

  group('InputComponents.showShoppingItemDialog', () {
    testWidgets('shows an AddUnifiedShoppingItemDialog on call', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('sv'),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () =>
                    InputComponents.showShoppingItemDialog(context),
                child: const Text('Open dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open dialog'));
      await tester.pumpAndSettle();

      expect(find.byType(AddUnifiedShoppingItemDialog), findsOneWidget);
    });

    testWidgets('returns null when dialog dismissed via barrier', (
      tester,
    ) async {
      Object? result = const Object();
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('sv'),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await InputComponents.showShoppingItemDialog(
                    context,
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byType(AddUnifiedShoppingItemDialog), findsOneWidget);

      // Tap outside dialog to dismiss via barrier.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.byType(AddUnifiedShoppingItemDialog), findsNothing);
      expect(result, isNull);
    });
  });

  // SKIP: showListSelector mounts ShoppingListSelector which requires
  // UnifiedShoppingViewModel via ApplicationProvider and the full ServiceLocator
  // stack — too much wiring for a facade smoke test. Covered downstream
  // by ShoppingListSelector's own integration tests.
}
