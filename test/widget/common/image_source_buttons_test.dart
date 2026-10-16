/// The two buttons that start a picture import: each asks for its own source,
/// a screen reader can activate each, they grow with the text, and while a
/// picture is being read both show the plate line instead of going disabled.
library;

import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/buttons/image_source_buttons.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';

import '../../test_support/semantics_announcement.dart';

/// Tabs until the focused element sits inside a widget of type [T].
Future<void> _tabInto<T extends Widget>(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final focus = FocusManager.instance.primaryFocus?.context;
    if (focus?.findAncestorWidgetOfExactType<T>() != null) return;
  }
  fail('focus never reached $T');
}

void main() {
  Widget host({
    VoidCallback? onCamera,
    VoidCallback? onLibrary,
    bool busy = false,
  }) => MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(
      body: ImageSourceButtons(
        cameraLabel: 'Fota nu',
        libraryLabel: 'Ur bildbiblioteket',
        onCamera: onCamera,
        onLibrary: onLibrary,
        busy: busy,
      ),
    ),
  );

  testWidgets('each button runs only its own action', (tester) async {
    var camera = 0;
    var library = 0;
    await tester.pumpWidget(
      host(onCamera: () => camera++, onLibrary: () => library++),
    );

    await tester.tap(find.text('Fota nu'));
    expect(camera, 1);
    expect(library, 0);

    await tester.tap(find.text('Ur bildbiblioteket'));
    expect(camera, 1);
    expect(library, 1);
  });

  testWidgets('without actions neither button reports itself as enabled', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host());

    for (final label in ['Fota nu', 'Ur bildbiblioteket']) {
      final node = tester.getSemantics(find.bySemanticsLabel(label));
      expect(
        node.flagsCollection.isEnabled,
        Tristate.isFalse,
        reason: label,
      );
    }
    handle.dispose();
  });

  testWidgets('a screen reader can activate each button', (tester) async {
    final handle = tester.ensureSemantics();
    var camera = 0;
    var library = 0;
    await tester.pumpWidget(
      host(onCamera: () => camera++, onLibrary: () => library++),
    );

    for (final label in ['Fota nu', 'Ur bildbiblioteket']) {
      expectActivatable(tester, find.bySemanticsLabel(label));
      tester.semantics.tap(find.semantics.byLabel(label));
    }
    expect(camera, 1);
    expect(library, 1);
    handle.dispose();
  });

  testWidgets('at 1.0x text both buttons are 88 dp high', (tester) async {
    await tester.pumpWidget(host(onCamera: () {}, onLibrary: () {}));

    for (final label in ['Fota nu', 'Ur bildbiblioteket']) {
      final button = find.ancestor(
        of: find.text(label),
        matching: find.byType(Material),
      );
      expect(tester.getSize(button.first).height, 88, reason: label);
    }
  });

  testWidgets('at 2.0x text on 320 dp the buttons grow instead of '
      'overflowing, and stay equally high', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 800),
          textScaler: TextScaler.linear(2),
        ),
        child: host(onCamera: () {}, onLibrary: () {}),
      ),
    );

    expect(tester.takeException(), isNull);
    final heights = [
      for (final label in ['Fota nu', 'Ur bildbiblioteket'])
        tester
            .getSize(
              find
                  .ancestor(
                    of: find.text(label),
                    matching: find.byType(Material),
                  )
                  .first,
            )
            .height,
    ];
    expect(heights[0], heights[1]);
    expect(heights[0], greaterThan(88));
  });

  testWidgets('busy keeps both buttons named, draws the plate line and '
      'ignores taps', (tester) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(
      host(onCamera: () => taps++, onLibrary: () => taps++, busy: true),
    );

    expect(find.byType(ButtonPlateLine), findsNWidgets(2));
    for (final label in ['Fota nu', 'Ur bildbiblioteket']) {
      expect(find.bySemanticsLabel(label), findsOneWidget);
      await tester.tap(find.text(label), warnIfMissed: false);
    }
    expect(taps, 0);
    handle.dispose();
  });

  testWidgets('not busy draws no plate line', (tester) async {
    await tester.pumpWidget(host(onCamera: () {}, onLibrary: () {}));
    expect(find.byType(ButtonPlateLine), findsNothing);
  });

  testWidgets('busy: Enter on the focused button activates nothing', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      host(onCamera: () => taps++, onLibrary: () => taps++, busy: true),
    );

    await _tabInto<ImageSourceButtons>(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(taps, 0);
  });

  testWidgets('not busy: Enter on the focused button activates it', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(host(onCamera: () => taps++, onLibrary: () {}));

    await _tabInto<ImageSourceButtons>(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(taps, 1);
  });
}
