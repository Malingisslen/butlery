// ButlerySwitch is the token-sized toggle: a 34 x 20 track in a 48 x 48
// touch target, toggling once per tap and not at all when disabled.

import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/widgets/common/input/butlery_switch.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

void main() {
  Future<List<bool>> pumpSwitch(
    WidgetTester tester, {
    bool enabled = true,
  }) async {
    final calls = <bool>[];
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Center(
          child: ButlerySwitch(
            value: false,
            onChanged: enabled ? calls.add : null,
          ),
        ),
      ),
    );
    return calls;
  }

  testWidgets('draws a 34 x 20 track inside a 48 x 48 target', (tester) async {
    await pumpSwitch(tester);
    expect(tester.getSize(find.byType(ButlerySwitch)), const Size(48, 48));
    final track = tester.getSize(
      find.descendant(
        of: find.byType(ButlerySwitch),
        matching: find.byType(OverflowBox),
      ),
    );
    expect(track, const Size(34, 20));
  });

  testWidgets('a screen reader gets one 48 x 48 node it can tap', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpSwitch(tester);

    final node = tester.getSemantics(find.byType(ButlerySwitch));
    expect(node.rect.size, const Size(48, 48));
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    handle.dispose();
  });

  testWidgets('a tap on the track toggles once', (tester) async {
    final calls = await pumpSwitch(tester);
    await tester.tap(find.byType(Switch));
    expect(calls, [true]);
  });

  testWidgets('a tap in the padding beside the track toggles once', (
    tester,
  ) async {
    final calls = await pumpSwitch(tester);
    final box = tester.getTopLeft(find.byType(ButlerySwitch));
    await tester.tapAt(box + const Offset(3, 24));
    expect(calls, [true]);
  });

  testWidgets('a disabled switch hands the Switch no handler', (tester) async {
    await pumpSwitch(tester, enabled: false);
    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
  });
}
