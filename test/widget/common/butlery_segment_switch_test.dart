import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/widgets/common/butlery_segment_switch.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

void main() {
  Future<List<String>> pump(
    WidgetTester tester, {
    bool enabled = true,
    Set<String> disabled = const {},
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final picked = <String>[];
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: ButlerySegmentSwitch<String>(
              choices: const [('a', 'Alla'), ('b', 'Några')],
              selected: 'a',
              disabledValues: disabled,
              onChanged: enabled ? picked.add : null,
            ),
          ),
        ),
      ),
    );
    return picked;
  }

  testWidgets('tapping the other half reports it', (tester) async {
    final picked = await pump(tester);

    await tester.tap(find.text('Några'));
    await tester.pump();

    expect(picked, ['b']);
  });

  testWidgets('with no onChanged nothing can be picked', (tester) async {
    final picked = await pump(tester, enabled: false);

    await tester.tap(find.text('Några'));
    await tester.pump();

    expect(picked, isEmpty);
    expect(
      tester
          .widget<SegmentedButton<String>>(find.byType(SegmentedButton<String>))
          .onSelectionChanged,
      isNull,
    );
  });

  testWidgets('a disabled value cannot be picked, the other still can', (
    tester,
  ) async {
    final picked = await pump(tester, disabled: {'b'});

    await tester.tap(find.text('Några'));
    await tester.pump();
    expect(picked, isEmpty);

    final enabledHalf = tester.widget<SegmentedButton<String>>(
      find.byType(SegmentedButton<String>),
    );
    expect(enabledHalf.segments.map((s) => s.enabled), [true, false]);
  });

  testWidgets('at 200 % text the chip fallback respects both rules', (
    tester,
  ) async {
    final picked = await pump(tester, disabled: {'b'}, textScale: 2.0);

    expect(find.byType(SegmentedButton<String>), findsNothing);
    await tester.tap(find.text('Några'));
    await tester.pump();
    expect(picked, isEmpty);

    final off = await pump(tester, enabled: false, textScale: 2.0);
    await tester.tap(find.text('Några'));
    await tester.pump();
    expect(off, isEmpty);
  });
}
