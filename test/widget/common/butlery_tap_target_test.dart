/// The shared tap target: 48 dp whatever the child, a button to a screen
/// reader, reachable and activatable from the keyboard.
library;

import 'dart:ui' show SemanticsAction, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/butlery_focus_ring.dart';
import 'package:butlery/widgets/common/butlery_tap_target.dart';

import '../../test_support/semantics_announcement.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    VoidCallback onTap, {
    bool? selected,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Center(
          child: ButleryTapTarget(
            semanticLabel: 'Stäng varning',
            selected: selected,
            onTap: onTap,
            child: const SizedBox.square(dimension: 16),
          ),
        ),
      ),
    ),
  );

  testWidgets('a 16 dp child gets a 48 x 48 target that a tap reaches', (
    tester,
  ) async {
    var taps = 0;
    await pump(tester, () => taps++);

    expect(tester.getSize(find.byType(ButleryTapTarget)), const Size(48, 48));
    final corner = tester.getTopLeft(find.byType(ButleryTapTarget));
    await tester.tapAt(corner + const Offset(3, 3));
    expect(taps, 1);
  });

  testWidgets('the keyboard reaches it and Enter and Space activate it', (
    tester,
  ) async {
    var taps = 0;
    await pump(tester, () => taps++);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(find.byType(ButleryFocusRing), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(taps, 2);
  });

  testWidgets('a screen reader hears a button with the label and can tap it', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await pump(tester, () => taps++, selected: true);

    final node = find.bySemanticsLabel('Stäng varning');
    final data = tester.getSemantics(node).getSemanticsData();
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.flagsCollection.isSelected, Tristate.isTrue);
    expectActivatable(tester, node);
    tester.semantics.tap(find.semantics.byLabel('Stäng varning'));
    expect(taps, 1);
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    handle.dispose();
  });
}
