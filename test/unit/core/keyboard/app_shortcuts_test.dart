// test/unit/core/keyboard/app_shortcuts_test.dart
//
// BUT-521: behavioral tests for the top-level keyboard layer. Each test
// pumps a minimal MaterialApp wrapped in `Shortcuts` + `Actions`, simulates
// a key press via `tester.sendKeyEvent`, and asserts the corresponding
// `Intent` was dispatched (via a tracked override action) — proving the
// activator → intent → action chain is wired correctly.
//
// We override the top-level Actions inside the test tree so the assertion
// is "the right Intent fired", not "a real navigator pop happened" — that
// would require a full app shell and wouldn't add coverage of the shortcut
// layer itself.

import 'package:butlery/core/keyboard/app_actions.dart';
import 'package:butlery/core/keyboard/app_shortcuts.dart';
import 'package:butlery/widgets/common/feedback_fab.dart' show appNavigatorKey;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppShortcuts.bindings', () {
    test('contains all 7 documented bindings', () {
      // Acts as a contract test: if any binding is removed accidentally,
      // a11y reviewers see a failing assertion before merge. Keep this
      // count in sync with the table in the BUT-521 spec.
      expect(AppShortcuts.bindings.length, 7);
    });

    test('maps Esc to CloseDialogIntent', () {
      final intent = AppShortcuts.bindings.entries
          .firstWhere(
            (e) =>
                e.key is SingleActivator &&
                (e.key as SingleActivator).trigger == LogicalKeyboardKey.escape,
          )
          .value;
      expect(intent, isA<CloseDialogIntent>());
    });

    test('maps Backspace to NavigateBackIntent', () {
      final intent = AppShortcuts.bindings.entries
          .firstWhere(
            (e) =>
                e.key is SingleActivator &&
                (e.key as SingleActivator).trigger ==
                    LogicalKeyboardKey.backspace,
          )
          .value;
      expect(intent, isA<NavigateBackIntent>());
    });
  });

  group('Shortcuts → Actions dispatch', () {
    /// Pumps a stub app with the production Shortcuts map and a test-local
    /// Actions map that captures which Intent fired. Returns the captured
    /// intent type list so tests can assert on order + count.
    Future<List<Type>> pumpAndPress(
      WidgetTester tester,
      List<LogicalKeyboardKey> keys,
    ) async {
      final fired = <Type>[];

      Action<T> capture<T extends Intent>() => CallbackAction<T>(
        onInvoke: (intent) {
          fired.add(T);
          return null;
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Shortcuts(
            shortcuts: AppShortcuts.bindings,
            child: Actions(
              actions: <Type, Action<Intent>>{
                CloseDialogIntent: capture<CloseDialogIntent>(),
                NavigateBackIntent: capture<NavigateBackIntent>(),
                OpenSearchIntent: capture<OpenSearchIntent>(),
                GoToRecipesIntent: capture<GoToRecipesIntent>(),
                GoToMenuIntent: capture<GoToMenuIntent>(),
                GoToShoppingIntent: capture<GoToShoppingIntent>(),
                SubmitFormIntent: capture<SubmitFormIntent>(),
              },
              child: const Focus(
                autofocus: true,
                child: SizedBox(width: 100, height: 100),
              ),
            ),
          ),
        ),
      );
      // Let autofocus settle so the Shortcuts widget owns the focus root.
      await tester.pumpAndSettle();

      for (final key in keys) {
        await tester.sendKeyEvent(key);
        await tester.pump();
      }
      return fired;
    }

    testWidgets('Esc fires CloseDialogIntent', (tester) async {
      final fired = await pumpAndPress(tester, [LogicalKeyboardKey.escape]);
      expect(fired, [CloseDialogIntent]);
    });

    testWidgets('Backspace fires NavigateBackIntent', (tester) async {
      final fired = await pumpAndPress(tester, [LogicalKeyboardKey.backspace]);
      expect(fired, [NavigateBackIntent]);
    });

    testWidgets('Ctrl+K fires OpenSearchIntent', (tester) async {
      // We use control here (not meta) because the test runs on the host
      // platform's `defaultTargetPlatform`, which is `android` in flutter
      // test by default — non-Mac → control branch.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      final fired = await pumpAndPress(tester, [LogicalKeyboardKey.keyK]);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      expect(fired, [OpenSearchIntent]);
    });

    testWidgets('Ctrl+1 fires GoToRecipesIntent', (tester) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      final fired = await pumpAndPress(tester, [LogicalKeyboardKey.digit1]);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      expect(fired, [GoToRecipesIntent]);
    });
  });

  group('Backspace vs. text editing', () {
    // These two use the REAL `AppActions.dispatch()` map, not a capturing
    // stub: the whole question is whether the production NavigateBack action
    // disables itself, and a stub action is always enabled. The app's
    // Shortcuts layer is mounted inside `MaterialApp.builder`, i.e. below
    // `DefaultTextEditingShortcuts` and therefore nearer a focused field, so
    // it sees Backspace first and would swallow the delete.

    // Mirrors `butlery_app.dart`: the keyboard layer goes in
    // `MaterialApp.builder` so it wraps the whole navigator, which is exactly
    // what puts it below `DefaultTextEditingShortcuts`.
    Widget app(Widget home) => MaterialApp(
      navigatorKey: appNavigatorKey,
      builder: (context, child) => Shortcuts(
        shortcuts: AppShortcuts.bindings,
        child: Actions(
          actions: AppActions.dispatch(),
          child: Focus(autofocus: true, child: child ?? const SizedBox()),
        ),
      ),
      home: home,
    );

    testWidgets('Backspace still deletes a character in a focused field', (
      tester,
    ) async {
      final controller = TextEditingController(text: 'abc');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        app(
          Material(child: TextField(controller: controller, autofocus: true)),
        ),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();

      expect(controller.text, 'ab');
    });

    testWidgets('Backspace still pops a route when no field has focus', (
      tester,
    ) async {
      await tester.pumpWidget(app(const Material(child: Text('root'))));
      await tester.pumpAndSettle();

      appNavigatorKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Material(child: Text('pushed')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('pushed'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();

      expect(find.text('pushed'), findsNothing);
    });
  });

  group('mainTabSwitchRequest notifier', () {
    test('publishes the requested tab index to listeners', () {
      // Start fresh so previous tests don't bleed into this assertion.
      mainTabSwitchRequest.value = 0;

      final received = <int>[];
      void listener() => received.add(mainTabSwitchRequest.value);
      mainTabSwitchRequest.addListener(listener);
      addTearDown(() => mainTabSwitchRequest.removeListener(listener));

      mainTabSwitchRequest.value = 2;
      mainTabSwitchRequest.value = 1;
      // Re-emitting the same value must not double-fire (ValueNotifier
      // contract — the layout depends on it to skip redundant setState).
      mainTabSwitchRequest.value = 1;

      expect(received, [2, 1]);
    });
  });
}
