/// P8-U04: golden baselines for eleven key screens, light and dark, made
/// and compared on Linux only (linux_golden_helper.dart).
///
/// Each screen is a U01 harness state (test/views/design_states), so the
/// golden shows the same host the design rules judge. The clock is fixed at
/// [goldenNow] and moves only with the test's fake time, so dates, week
/// numbers and queue ages read the same on every run.
///
/// Regenerate with the goldens-linux-update workflow and read the README
/// next to this file.
library;

import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../design_states/hosts/shopping_hosts.dart' show pantryWithItemsHost;
import '../design_states/known_state_findings.dart';
import '../design_states/state_harness.dart';
import '../design_states/state_host.dart';
import '../design_states/state_hosts.dart';
import '../design_states/state_runner.dart';
import 'golden_hosts.dart';
import 'linux_golden_helper.dart';

/// One key screen: the U01 row it is, or its own host, and how long to let
/// it run before the picture.
class _KeyScreen {
  const _KeyScreen(
    this.name, {
    this.row,
    this.host,
    this.after = Duration.zero,
    this.blockedBy,
  });

  final String name;
  final String? row;
  final StateHost? host;
  final Duration after;

  /// A known finding that keeps this screen from a stable picture.
  final String? blockedBy;
}

final _screens = <_KeyScreen>[
  const _KeyScreen('hem', row: 'hem::DEFAULT'),
  const _KeyScreen('veckomeny', row: 'veckomeny::DEFAULT'),
  // "Planerar veckan" after 6 s, when the slower line shows
  // (VeckomenyGeneratingOverlay.slowAfter).
  const _KeyScreen(
    'veckogenerering_6s',
    row: 'veckogenerering::LOADING',
    after: Duration(seconds: 6),
  ),
  // The open list's header fails its layout today (BUT-2186); a picture of
  // that would lock the failure in as the baseline.
  const _KeyScreen(
    'inkopslista',
    row: 'inköpslista::DEFAULT',
    blockedBy: 'BUT-2186',
  ),
  const _KeyScreen('receptdetalj', row: 'receptdetalj::DEFAULT'),
  const _KeyScreen('recepteditor', row: 'recepteditor::DEFAULT'),
  const _KeyScreen('matlagningslage', row: 'matlagningsläge::DEFAULT'),
  _KeyScreen('skafferi', host: pantryWithItemsHost),
  _KeyScreen('mer', host: moreHost),
  _KeyScreen('vantar_pa_synk', host: syncQueueHost),
  const _KeyScreen('inloggning', row: 'start::DEFAULT'),
];

void main() {
  refuseUpdateOffLinux();
  final rows = {for (final r in StateFixture.load().rows) r.id: r};

  setUpAll(() async {
    registerHostFallbacks();
    await loadGoldenFonts();
  });

  test('every key screen names a harness row or a host, and a block is '
      'a registered package 8 ticket', () {
    expect(_screens, hasLength(11));
    for (final s in _screens) {
      expect(s.row != null || s.host != null, isTrue, reason: s.name);
      if (s.row != null) expect(rows, contains(s.row), reason: s.name);
      if (s.blockedBy != null) {
        expect(registeredTickets, contains(s.blockedBy), reason: s.name);
      }
    }
  });

  test(
    'the Linux baselines are committed',
    () => expect(linuxBaselinesMissing, isFalse),
    skip: Platform.isLinux ? false : 'compared on Linux only',
  );

  for (final screen in _screens) {
    for (final mode in [Brightness.light, Brightness.dark]) {
      final modeName = mode == Brightness.dark ? 'dark' : 'light';
      final file = 'goldens/${screen.name}_$modeName.png';
      // A blocked screen is reported as skipped with its ticket as the
      // reason (testWidgets takes no skip reason).
      if (screen.blockedBy != null) {
        test(
          '${screen.name} ($modeName)',
          () {},
          skip:
              '${screen.blockedBy}: no stable picture until it is fixed '
              '(README.md, Blocked screens)',
        );
        continue;
      }
      testWidgets(
        '${screen.name} ($modeName)',
        (tester) async {
          final start = tester.binding.clock.now();
          await withClock(
            Clock(
              () => goldenNow.add(tester.binding.clock.now().difference(start)),
            ),
            () async {
              final row =
                  rows[screen.row] ??
                  StateRow(
                    view: screen.name,
                    state: 'DEFAULT',
                    drawing: '-',
                    evidence: '-',
                    host: '-',
                    hostFile: '-',
                    hostNote: null,
                    block288Category: '-',
                    ownerNow: null,
                  );
              final run = await pumpState(
                tester,
                row,
                mode,
                host: screen.host,
              );
              if (screen.after > Duration.zero) {
                await tester.pump(screen.after);
              }
              // Compared on Linux only. BUTLERY_GOLDEN_SMOKE=1 pumps the
              // screens elsewhere without a picture, to see that every host
              // still builds.
              if (linuxGoldensCompareHere) await expectScreenGolden(file);
              await finishState(tester, run);
            },
          );
        },
        skip: !(linuxGoldensCompareHere || goldenSmokeRun),
      );
    }
  }
}
