// Every screen the state register and the review hosts draw has to stay
// calm outside the phone-sized default: at 200 % text no word is broken
// between letters and nothing overflows, and on a wide or a sideways screen
// nothing overflows. Each screen is its own case so a failure names it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../infrastructure/helpers/word_break_finder.dart';
import '../golden_linux/linux_golden_helper.dart';
import 'hosts/review_hosts.dart';
import 'state_harness.dart';
import 'state_host.dart';
import 'state_hosts.dart';
import 'state_runner.dart';

StateRow _row(String view) => StateRow(
  view: view,
  state: 'DEFAULT',
  drawing: '-',
  evidence: '-',
  host: '-',
  hostFile: '-',
  hostNote: null,
  block288Category: '-',
  ownerNow: null,
);

void main() {
  setUpAll(() async {
    registerHostFallbacks();
    await loadGoldenFonts();
  });

  final rows = {
    for (final r in StateFixture.load().rows)
      if (r.state == 'DEFAULT') r.view: r,
  };
  final screens = <String, (StateRow, StateHost?)>{
    for (final e in reviewHosts.entries) e.key: (_row(e.key), e.value),
    for (final e in rows.entries) 'row:${e.key}': (e.value, null),
  };

  Future<void> expectCalm(
    WidgetTester tester,
    (StateRow, StateHost?) screen, {
    required Size size,
    required double textScale,
    required bool words,
  }) async {
    final run = await pumpState(
      tester,
      screen.$1,
      Brightness.light,
      host: screen.$2,
      size: size,
      textScale: textScale,
    );
    expect(run.capture.overflows, isEmpty, reason: 'overflow');
    expect(run.capture.exceptions, isEmpty, reason: 'exception');
    if (words) expect(findMidWordBreaks(tester), isEmpty);
    await finishState(tester, run);
  }

  for (final e in screens.entries) {
    testWidgets('${e.key} at 200 % text wraps between words', (tester) async {
      await expectCalm(
        tester,
        e.value,
        size: const Size(360, 800),
        textScale: 2,
        words: true,
      );
    });
    testWidgets('${e.key} fits a wide screen', (tester) async {
      await expectCalm(
        tester,
        e.value,
        size: const Size(1280, 800),
        textScale: 1,
        words: false,
      );
    });
    testWidgets('${e.key} fits a screen on its side', (tester) async {
      await expectCalm(
        tester,
        e.value,
        size: const Size(800, 360),
        textScale: 1,
        words: false,
      );
    });
  }
}
