/// Widget tests for DebouncedButton + DebouncedElevatedButton +
/// DebouncedTextButton.
///
/// Debounce timing is verified with `fakeAsync` — pumping real durations
/// would slow the suite and make timing brittle. Note that
/// `tester.pumpAndSettle()` would loop forever on debounce timers, so we use
/// targeted `tester.pump(...)` calls when stepping through state changes.
library;

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/input/debounced_button.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('DebouncedButton — render', () {
    testWidgets('renders the child widget', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DebouncedButton(
            onPressed: () {},
            child: const Text('Spara'),
          ),
        ),
      );
      expect(find.text('Spara'), findsOneWidget);
      // No Semantics wrapper when semanticLabel is null.
      expect(find.byType(GestureDetector), findsOneWidget);
    });

    testWidgets('child is at full opacity when enabled', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DebouncedButton(
            onPressed: () {},
            child: const Text('x'),
          ),
        ),
      );
      final opacity = tester.widget<Opacity>(
        find.descendant(
          of: find.byType(DebouncedButton),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, 1.0);
    });

    testWidgets('disabled=true → child opacity 0.6 + IgnorePointer ignoring', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          DebouncedButton(
            onPressed: () {},
            disabled: true,
            child: const Text('x'),
          ),
        ),
      );
      final opacity = tester.widget<Opacity>(
        find.descendant(
          of: find.byType(DebouncedButton),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, 0.6);
      final ignore = tester.widget<IgnorePointer>(
        find.descendant(
          of: find.byType(DebouncedButton),
          matching: find.byType(IgnorePointer),
        ),
      );
      expect(ignore.ignoring, isTrue);
    });

    testWidgets('onPressed=null → child opacity 0.6', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const DebouncedButton(
            onPressed: null,
            child: Text('x'),
          ),
        ),
      );
      final opacity = tester.widget<Opacity>(
        find.descendant(
          of: find.byType(DebouncedButton),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, 0.6);
    });

    testWidgets(
      'semanticLabel wraps in an explicit Semantics with button=true',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            DebouncedButton(
              onPressed: () {},
              semanticLabel: 'Spara recept',
              child: const Text('x'),
            ),
          ),
        );
        // The widget under test adds exactly one explicit Semantics node when
        // `semanticLabel` is set. Find Semantics widgets that were constructed
        // with our label literal (the test framework also adds anonymous ones).
        final semantics = tester
            .widgetList<Semantics>(find.byType(Semantics))
            .where((s) => s.properties.label == 'Spara recept')
            .toList();
        expect(semantics, hasLength(1));
        expect(semantics.single.properties.button, isTrue);
        expect(semantics.single.properties.enabled, isTrue);
      },
    );

    testWidgets('semanticLabel + disabled → Semantics.enabled is false', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          DebouncedButton(
            onPressed: () {},
            semanticLabel: 'Spara recept',
            disabled: true,
            child: const Text('x'),
          ),
        ),
      );
      final semantics = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .where((s) => s.properties.label == 'Spara recept')
          .toList();
      expect(semantics, hasLength(1));
      expect(semantics.single.properties.enabled, isFalse);
    });
  });

  group('DebouncedButton — callback + debounce', () {
    testWidgets('synchronous onPressed fires once on tap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          DebouncedButton(
            onPressed: () => taps++,
            child: const Text('x'),
          ),
        ),
      );
      await tester.tap(find.text('x'));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('disabled button does not fire callback', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          DebouncedButton(
            onPressed: () => taps++,
            disabled: true,
            child: const Text('x'),
          ),
        ),
      );
      await tester.tap(find.text('x'), warnIfMissed: false);
      await tester.pump();
      expect(taps, 0);
    });

    testWidgets('null onPressed does not fire and does not throw', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const DebouncedButton(
            onPressed: null,
            child: Text('x'),
          ),
        ),
      );
      await tester.tap(find.text('x'), warnIfMissed: false);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'rapid taps inside debounce window invoke onPressed only once',
      (tester) async {
        var taps = 0;
        await tester.pumpWidget(
          _wrap(
            DebouncedButton(
              onPressed: () => taps++,
              debounceDuration: const Duration(milliseconds: 300),
              child: const Text('x'),
            ),
          ),
        );
        await tester.tap(find.text('x'));
        await tester.pump();
        // Within the 300ms debounce window — taps should be ignored.
        await tester.tap(find.text('x'), warnIfMissed: false);
        await tester.tap(find.text('x'), warnIfMissed: false);
        await tester.pump();
        expect(taps, 1);
        // After the debounce window elapses, taps are accepted again.
        await tester.pump(const Duration(milliseconds: 301));
        await tester.tap(find.text('x'));
        await tester.pump();
        expect(taps, 2);
      },
    );

    testWidgets(
      'async onPressed keeps button disabled until Future completes',
      (tester) async {
        final completer = Completer<void>();
        var taps = 0;
        await tester.pumpWidget(
          _wrap(
            DebouncedButton(
              onPressed: () async {
                taps++;
                await completer.future;
              },
              debounceDuration: const Duration(milliseconds: 10),
              child: const Text('x'),
            ),
          ),
        );
        await tester.tap(find.text('x'));
        await tester.pump();
        // Still processing — second tap is ignored.
        await tester.tap(find.text('x'), warnIfMissed: false);
        await tester.pump();
        expect(taps, 1);
        // Complete the Future, then wait out the debounce.
        completer.complete();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 11));
        // Now another tap goes through.
        await tester.tap(find.text('x'));
        await tester.pump();
        expect(taps, 2);
      },
    );

    testWidgets(
      'showLoadingIndicator renders default spinner during processing',
      (tester) async {
        final completer = Completer<void>();
        await tester.pumpWidget(
          _wrap(
            DebouncedButton(
              onPressed: () => completer.future,
              showLoadingIndicator: true,
              child: const Text('Spara'),
            ),
          ),
        );
        expect(find.byType(CircularProgressIndicator), findsNothing);
        await tester.tap(find.text('Spara'));
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        // Child text is no longer shown during loading.
        expect(find.text('Spara'), findsNothing);
        completer.complete();
        await tester.pump();
        await tester.pump(AppDimensions.animationDurationLong);
      },
    );

    testWidgets('custom loadingIndicator overrides default spinner', (
      tester,
    ) async {
      final completer = Completer<void>();
      await tester.pumpWidget(
        _wrap(
          DebouncedButton(
            onPressed: () => completer.future,
            showLoadingIndicator: true,
            loadingIndicator: const Text('Laddar...'),
            child: const Text('Spara'),
          ),
        ),
      );
      await tester.tap(find.text('Spara'));
      await tester.pump();
      expect(find.text('Laddar...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      completer.complete();
      await tester.pump();
      await tester.pump(AppDimensions.animationDurationLong);
    });

    testWidgets('dispose during pending debounce timer does not throw', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          DebouncedButton(
            onPressed: () => taps++,
            debounceDuration: const Duration(seconds: 10),
            child: const Text('x'),
          ),
        ),
      );
      await tester.tap(find.text('x'));
      await tester.pump();
      // Replace the tree before the debounce timer fires.
      await tester.pumpWidget(_wrap(const SizedBox.shrink()));
      expect(tester.takeException(), isNull);
    });
  });

  group('DebouncedElevatedButton', () {
    testWidgets('renders an ElevatedButton with the child', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DebouncedElevatedButton(
            onPressed: () {},
            child: const Text('Spara'),
          ),
        ),
      );
      expect(find.byType(ElevatedButton), findsOneWidget);
      expect(find.text('Spara'), findsOneWidget);
    });

    testWidgets('forwards ButtonStyle', (tester) async {
      final style = ElevatedButton.styleFrom(backgroundColor: Colors.purple);
      await tester.pumpWidget(
        _wrap(
          DebouncedElevatedButton(
            onPressed: () {},
            style: style,
            child: const Text('x'),
          ),
        ),
      );
      final btn = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(btn.style, same(style));
    });

    testWidgets('onPressed=null → ElevatedButton.enabled is false', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const DebouncedElevatedButton(
            onPressed: null,
            child: Text('x'),
          ),
        ),
      );
      final btn = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(btn.enabled, isFalse);
    });

    testWidgets('sync onPressed fires once and debounces follow-up taps', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          DebouncedElevatedButton(
            onPressed: () => taps++,
            debounceDuration: const Duration(milliseconds: 200),
            child: const Text('x'),
          ),
        ),
      );
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      expect(taps, 1);
      // Re-tap inside the debounce window: button is disabled, no fire.
      await tester.tap(find.byType(ElevatedButton), warnIfMissed: false);
      await tester.pump();
      expect(taps, 1);
      await tester.pump(const Duration(milliseconds: 201));
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      expect(taps, 2);
    });

    testWidgets('async onPressed: button disabled while Future runs', (
      tester,
    ) async {
      fakeAsync((async) {
        final completer = Completer<void>();
        var taps = 0;
        tester.pumpWidget(
          _wrap(
            DebouncedElevatedButton(
              onPressed: () async {
                taps++;
                await completer.future;
              },
              debounceDuration: const Duration(milliseconds: 100),
              child: const Text('x'),
            ),
          ),
        );
        async.flushMicrotasks();

        tester.tap(find.byType(ElevatedButton));
        async.flushMicrotasks();
        tester.pump();
        async.flushMicrotasks();

        // Future still pending → button reads as disabled.
        final btn1 = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
        expect(btn1.enabled, isFalse);

        completer.complete();
        async.flushMicrotasks();
        tester.pump();
        async.flushMicrotasks();
        // Debounce window still active.
        final btn2 = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
        expect(btn2.enabled, isFalse);

        async.elapse(const Duration(milliseconds: 101));
        tester.pump();
        async.flushMicrotasks();
        final btn3 = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
        expect(btn3.enabled, isTrue);
        expect(taps, 1);
      });
    });
  });

  group('DebouncedTextButton', () {
    testWidgets('renders a TextButton with the child', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DebouncedTextButton(
            onPressed: () {},
            child: const Text('Avbryt'),
          ),
        ),
      );
      expect(find.byType(TextButton), findsOneWidget);
      expect(find.text('Avbryt'), findsOneWidget);
    });

    testWidgets('forwards ButtonStyle', (tester) async {
      final style = TextButton.styleFrom(foregroundColor: Colors.teal);
      await tester.pumpWidget(
        _wrap(
          DebouncedTextButton(
            onPressed: () {},
            style: style,
            child: const Text('x'),
          ),
        ),
      );
      final btn = tester.widget<TextButton>(find.byType(TextButton));
      expect(btn.style, same(style));
    });

    testWidgets('onPressed=null → TextButton.enabled is false', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const DebouncedTextButton(
            onPressed: null,
            child: Text('x'),
          ),
        ),
      );
      final btn = tester.widget<TextButton>(find.byType(TextButton));
      expect(btn.enabled, isFalse);
    });

    testWidgets('sync onPressed fires once; debounce blocks rapid follow-up', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          DebouncedTextButton(
            onPressed: () => taps++,
            debounceDuration: const Duration(milliseconds: 150),
            child: const Text('x'),
          ),
        ),
      );
      await tester.tap(find.byType(TextButton));
      await tester.pump();
      expect(taps, 1);
      await tester.tap(find.byType(TextButton), warnIfMissed: false);
      await tester.pump();
      expect(taps, 1);
      await tester.pump(const Duration(milliseconds: 151));
      await tester.tap(find.byType(TextButton));
      await tester.pump();
      expect(taps, 2);
    });

    testWidgets('default debounceDuration is animationDurationLong (500ms)', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          DebouncedTextButton(
            onPressed: () => taps++,
            child: const Text('x'),
          ),
        ),
      );
      await tester.tap(find.byType(TextButton));
      await tester.pump();
      expect(taps, 1);
      // 499ms after — still debouncing.
      await tester.pump(const Duration(milliseconds: 499));
      await tester.tap(find.byType(TextButton), warnIfMissed: false);
      await tester.pump();
      expect(taps, 1);
      // Past 500ms total — debounce released.
      await tester.pump(const Duration(milliseconds: 2));
      await tester.tap(find.byType(TextButton));
      await tester.pump();
      expect(taps, 2);
    });
  });
}
