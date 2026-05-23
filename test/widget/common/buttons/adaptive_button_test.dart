/// Widget tests for AdaptiveButton + AdaptiveButton.primary +
/// AdaptiveButton.text + AdaptiveButton.destructive + AdaptiveIconButton.
///
/// The widget branches on `Platform.isIOS` (dart:io), NOT on
/// `defaultTargetPlatform`. In the Flutter test environment the host is
/// always Windows/Linux/macOS, so `Platform.isIOS` is false — we therefore
/// can only exercise the Material branch directly. Cupertino-branch coverage
/// would require platform-channel mocking or running on an iOS device, which
/// is out of scope for a unit widget test. The Material branch is the path
/// users on Android/web/desktop hit, which is the majority surface.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/widgets/common/buttons/adaptive_button.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('AdaptiveButton — default constructor (Material branch)', () {
    testWidgets('renders ElevatedButton with the provided child',
        (tester) async {
      await tester.pumpWidget(_wrap(
        AdaptiveButton(onPressed: () {}, child: const Text('Spara')),
      ));
      expect(find.byType(ElevatedButton), findsOneWidget);
      expect(find.text('Spara'), findsOneWidget);
    });

    testWidgets('onPressed fires when tapped', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(
        AdaptiveButton(
          onPressed: () => taps++,
          child: const Text('tap'),
        ),
      ));
      await tester.tap(find.text('tap'));
      expect(taps, 1);
    });

    testWidgets(
        'disabled (onPressed=null) does NOT fire callback and reports '
        'disabled', (tester) async {
      await tester.pumpWidget(_wrap(
        const AdaptiveButton(onPressed: null, child: Text('off')),
      ));
      final btn = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(btn.enabled, isFalse);
      // Tapping a disabled button is a no-op — verify no exception.
      await tester.tap(find.text('off'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('forwards color → foregroundColor and minSize → minimumSize',
        (tester) async {
      await tester.pumpWidget(_wrap(
        AdaptiveButton(
          onPressed: () {},
          color: Colors.purple,
          minSize: 56.0,
          padding: const EdgeInsets.all(7),
          child: const Text('x'),
        ),
      ));
      final btn = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      final style = btn.style!;
      expect(
        style.foregroundColor!.resolve(<WidgetState>{}),
        Colors.purple,
      );
      expect(
        style.minimumSize!.resolve(<WidgetState>{}),
        const Size(56.0, 56.0),
      );
      expect(
        style.padding!.resolve(<WidgetState>{}),
        const EdgeInsets.all(7),
      );
    });

    testWidgets('disabledColor → disabledForegroundColor', (tester) async {
      await tester.pumpWidget(_wrap(
        const AdaptiveButton(
          onPressed: null,
          disabledColor: Colors.amber,
          child: Text('d'),
        ),
      ));
      final btn = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(
        btn.style!.foregroundColor!
            .resolve(<WidgetState>{WidgetState.disabled}),
        Colors.amber,
      );
    });
  });

  group('AdaptiveButton.primary', () {
    testWidgets('renders as ElevatedButton on Material branch', (tester) async {
      await tester.pumpWidget(_wrap(
        AdaptiveButton.primary(
          onPressed: () {},
          child: const Text('Primary'),
        ),
      ));
      expect(find.byType(ElevatedButton), findsOneWidget);
      expect(find.text('Primary'), findsOneWidget);
    });

    testWidgets('onPressed fires', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(
        AdaptiveButton.primary(
          onPressed: () => taps++,
          child: const Text('p'),
        ),
      ));
      await tester.tap(find.text('p'));
      expect(taps, 1);
    });

    testWidgets('null onPressed → disabled, no callback fires', (tester) async {
      await tester.pumpWidget(_wrap(
        const AdaptiveButton.primary(
          onPressed: null,
          child: Text('p'),
        ),
      ));
      final btn = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(btn.enabled, isFalse);
    });
  });

  group('AdaptiveButton.text', () {
    testWidgets('renders as TextButton on Material branch', (tester) async {
      await tester.pumpWidget(_wrap(
        AdaptiveButton.text(
          onPressed: () {},
          child: const Text('Avbryt'),
        ),
      ));
      expect(find.byType(TextButton), findsOneWidget);
      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.text('Avbryt'), findsOneWidget);
    });

    testWidgets('onPressed fires when tapped', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(
        AdaptiveButton.text(
          onPressed: () => taps++,
          child: const Text('t'),
        ),
      ));
      await tester.tap(find.text('t'));
      expect(taps, 1);
    });

    testWidgets('null onPressed → disabled TextButton', (tester) async {
      await tester.pumpWidget(_wrap(
        AdaptiveButton.text(
          onPressed: null,
          child: const Text('t'),
        ),
      ));
      final btn = tester.widget<TextButton>(find.byType(TextButton));
      expect(btn.enabled, isFalse);
    });

    testWidgets('forwards color → foregroundColor and padding', (tester) async {
      await tester.pumpWidget(_wrap(
        AdaptiveButton.text(
          onPressed: () {},
          color: Colors.teal,
          padding: const EdgeInsets.all(11),
          child: const Text('t'),
        ),
      ));
      final btn = tester.widget<TextButton>(find.byType(TextButton));
      final style = btn.style!;
      expect(
        style.foregroundColor!.resolve(<WidgetState>{}),
        Colors.teal,
      );
      expect(
        style.padding!.resolve(<WidgetState>{}),
        const EdgeInsets.all(11),
      );
    });
  });

  group('AdaptiveButton.destructive', () {
    testWidgets('renders as TextButton on Material branch', (tester) async {
      await tester.pumpWidget(_wrap(
        AdaptiveButton.destructive(
          onPressed: () {},
          child: const Text('Ta bort'),
        ),
      ));
      expect(find.byType(TextButton), findsOneWidget);
      expect(find.text('Ta bort'), findsOneWidget);
    });

    testWidgets('uses theme.colorScheme.error as foregroundColor',
        (tester) async {
      final theme = ThemeData(
        colorScheme: const ColorScheme.light(error: Colors.deepOrange),
      );
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: Scaffold(
          body: AdaptiveButton.destructive(
            onPressed: () {},
            child: const Text('d'),
          ),
        ),
      ));
      final btn = tester.widget<TextButton>(find.byType(TextButton));
      expect(
        btn.style!.foregroundColor!.resolve(<WidgetState>{}),
        Colors.deepOrange,
      );
    });

    testWidgets('onPressed fires', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(
        AdaptiveButton.destructive(
          onPressed: () => taps++,
          child: const Text('d'),
        ),
      ));
      await tester.tap(find.text('d'));
      expect(taps, 1);
    });

    testWidgets('null onPressed → disabled', (tester) async {
      await tester.pumpWidget(_wrap(
        AdaptiveButton.destructive(
          onPressed: null,
          child: const Text('d'),
        ),
      ));
      final btn = tester.widget<TextButton>(find.byType(TextButton));
      expect(btn.enabled, isFalse);
    });

    testWidgets('forwards padding', (tester) async {
      await tester.pumpWidget(_wrap(
        AdaptiveButton.destructive(
          onPressed: () {},
          padding: const EdgeInsets.all(9),
          child: const Text('d'),
        ),
      ));
      final btn = tester.widget<TextButton>(find.byType(TextButton));
      expect(
        btn.style!.padding!.resolve(<WidgetState>{}),
        const EdgeInsets.all(9),
      );
    });
  });

  group('AdaptiveIconButton', () {
    testWidgets('renders as IconButton on Material branch', (tester) async {
      await tester.pumpWidget(_wrap(
        AdaptiveIconButton(
          icon: const Icon(Icons.share),
          onPressed: () {},
          semanticLabel: 'Dela',
        ),
      ));
      expect(find.byType(IconButton), findsOneWidget);
      expect(find.byIcon(Icons.share), findsOneWidget);
    });

    testWidgets('onPressed fires when tapped', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(
        AdaptiveIconButton(
          icon: const Icon(Icons.share),
          onPressed: () => taps++,
          semanticLabel: 'Dela',
        ),
      ));
      await tester.tap(find.byIcon(Icons.share));
      expect(taps, 1);
    });

    testWidgets('null onPressed → disabled IconButton, no callback fires',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const AdaptiveIconButton(
          icon: Icon(Icons.share),
          onPressed: null,
          semanticLabel: 'Dela',
        ),
      ));
      final btn = tester.widget<IconButton>(find.byType(IconButton));
      expect(btn.onPressed, isNull);
      await tester.tap(find.byIcon(Icons.share));
      expect(tester.takeException(), isNull);
    });

    testWidgets('semanticLabel → IconButton.tooltip (Android/Material path)',
        (tester) async {
      await tester.pumpWidget(_wrap(
        AdaptiveIconButton(
          icon: const Icon(Icons.share),
          onPressed: () {},
          semanticLabel: 'Dela receptet',
        ),
      ));
      final btn = tester.widget<IconButton>(find.byType(IconButton));
      expect(btn.tooltip, 'Dela receptet');
    });

    testWidgets('forwards color, size, padding to IconButton', (tester) async {
      await tester.pumpWidget(_wrap(
        AdaptiveIconButton(
          icon: const Icon(Icons.share),
          onPressed: () {},
          semanticLabel: 'Dela',
          color: Colors.indigo,
          size: 30,
          padding: const EdgeInsets.all(13),
        ),
      ));
      final btn = tester.widget<IconButton>(find.byType(IconButton));
      expect(btn.color, Colors.indigo);
      expect(btn.iconSize, 30);
      expect(btn.padding, const EdgeInsets.all(13));
    });

    testWidgets('default size is 24', (tester) async {
      await tester.pumpWidget(_wrap(
        AdaptiveIconButton(
          icon: const Icon(Icons.share),
          onPressed: () {},
          semanticLabel: 'Dela',
        ),
      ));
      final btn = tester.widget<IconButton>(find.byType(IconButton));
      expect(btn.iconSize, 24.0);
    });
  });

  // SKIP: iOS branch (`Platform.isIOS == true`) requires either running on a
  // real iOS device or mocking `dart:io.Platform`, which is not possible
  // without a wrapper around Platform. The widget reads `Platform.isIOS`
  // directly (not `defaultTargetPlatform`), so `debugDefaultTargetPlatformOverride`
  // has no effect here. Coverage of the CupertinoButton branch is therefore
  // intentionally omitted from this widget test and is exercised by manual
  // QA on iOS hardware.
}
