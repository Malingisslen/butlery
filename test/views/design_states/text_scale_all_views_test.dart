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
    String name,
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
    final overflows = run.capture.overflows;
    final exceptions = run.capture.exceptions;
    final breaks = words ? findMidWordBreaks(tester) : const <String>[];
    await finishState(tester, run);
    expect(overflows, isEmpty, reason: 'overflow');
    expect(exceptions, isEmpty, reason: 'exception');
    if (words) expect(breaks, isEmpty);
  }

  for (final e in screens.entries) {
    final tooBig = '${e.key} at 200 % text wraps between words';
    testWidgets(tooBig, (tester) async {
      await expectCalm(
        tester,
        tooBig,
        e.value,
        size: const Size(360, 800),
        textScale: 2,
        words: true,
      );
    });
    final wide = '${e.key} fits a wide screen';
    testWidgets(wide, (tester) async {
      await expectCalm(
        tester,
        wide,
        e.value,
        size: const Size(1280, 800),
        textScale: 1,
        words: false,
      );
    });
    final sideways = '${e.key} fits a screen on its side';
    testWidgets(sideways, (tester) async {
      await expectCalm(
        tester,
        sideways,
        e.value,
        size: const Size(800, 360),
        textScale: 1,
        words: false,
      );
    });
  }
}
