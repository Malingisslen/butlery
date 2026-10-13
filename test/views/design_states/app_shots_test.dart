/// Draws the app's screens, light and dark, as PNGs for the sketch-against-app
/// scan (tools/sketch_scan.py). Not a check: it runs only with
/// BUTLERY_APP_SHOTS=true and `--update-goldens`, and writes to shots/ next to
/// this file.
///
///   BUTLERY_APP_SHOTS=true flutter test --update-goldens \
///     test/views/design_states/app_shots_test.dart
library;

import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../golden_linux/golden_hosts.dart';
import '../golden_linux/linux_golden_helper.dart';
import '../../widget/golden/golden_helper.dart'
    show installGoldenImageErrorFilter;
import 'hosts/review_hosts.dart';
import 'hosts/shopping_hosts.dart' show pantryWithItemsHost;
import 'state_harness.dart';
import 'state_host.dart';
import 'state_hosts.dart';
import 'state_runner.dart';

String _slug(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9åäö]+'), '_')
    .replaceAll(RegExp(r'^_+|_+$'), '');

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
  final on = Platform.environment['BUTLERY_APP_SHOTS'] == 'true';
  final stateRows = [
    for (final r in StateFixture.load().rows)
      if (r.state == 'DEFAULT') r,
  ];
  final named = <String, StateHost>{
    'host_minaRecept': minaReceptHost,
    'host_more': moreHost,
    'host_syncQueue': syncQueueHost,
    'host_pantry': pantryWithItemsHost,
    for (final e in reviewHosts.entries) 'host_${_slug(e.key)}': e.value,
  };

  setUpAll(() async {
    registerHostFallbacks();
    await loadGoldenFonts();
  });

  Future<void> shoot(
    WidgetTester tester,
    String name,
    StateRow row,
    StateHost? host,
    Brightness mode,
  ) async {
    final start = tester.binding.clock.now();
    await withClock(
      Clock(() => goldenNow.add(tester.binding.clock.now().difference(start))),
      () async {
        final run = await pumpState(tester, row, mode, host: host);
        installGoldenImageErrorFilter();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'shots/${name}_${mode == Brightness.dark ? 'dark' : 'light'}.png',
          ),
        );
        await finishState(tester, run);
      },
    );
  }

  for (final mode in [Brightness.light, Brightness.dark]) {
    for (final r in stateRows) {
      testWidgets(
        'row_${_slug(r.view)} $mode',
        (t) => shoot(t, 'row_${_slug(r.view)}', r, null, mode),
        skip: !on,
      );
    }
    for (final e in named.entries) {
      testWidgets(
        '${e.key} $mode',
        (t) => shoot(t, e.key, _row(e.key), e.value, mode),
        skip: !on,
      );
    }
  }
}
