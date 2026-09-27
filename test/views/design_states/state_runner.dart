/// P8-U01: pumps one row in one mode and judges it by its kind's rule.
///
/// Time comes only from tester.pump (scripts/check_test_real_time.sh). A
/// LOADING state is read twice: 299 ms after it began, when no skeleton may
/// show (DelayedSkeleton.threshold, produktregler.md:304), and just after the
/// threshold for the rest of the rule.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'state_harness.dart';
import 'state_host.dart';
import 'state_hosts.dart';
import 'state_rules.dart';

/// One pumped row.
class StateRun {
  StateRun(this.row, this.mode, this.ctx, this.capture);

  final StateRow row;
  final Brightness mode;
  final HostContext? ctx;
  final StateCapture capture;
  final List<Violation> violations = [];

  String get modeName => mode == Brightness.dark ? 'dark' : 'light';
}

/// Pumps [row] in [mode] on [size] at [textScale] and leaves the state on
/// screen. Call [judgeState] to read the rule and [finishState] to clean up.
/// [host] replaces the row's own host, for screens outside the 53 (the
/// Linux goldens' Mer, Väntar på synk and a filled pantry).
Future<StateRun> pumpState(
  WidgetTester tester,
  StateRow row,
  Brightness mode, {
  Size size = stateSurface,
  double textScale = 1.0,
  StateHost? host,
}) async {
  host ??= stateHosts[row.id];
  setStateSurface(
    tester,
    size: host != null && host.landscape ? size.flipped : size,
  );
  final capture = captureFrameworkErrors();
  if (host == null) {
    return StateRun(row, mode, null, capture)
      ..violations.add(Violation('NO_HOST', 'no host for ${row.id}'));
  }
  final env = await StateEnvironment.setUp(online: host.online);
  final ctx = HostContext(env, mode);
  final home = await host.build(ctx);
  await tester.pumpWidget(
    stateApp(mode: mode, home: home, textScale: textScale),
  );
  await tester.pump();
  drainExceptions(tester, capture);
  if (host.reach != null) await host.reach!(tester, ctx);
  drainExceptions(tester, capture);
  final run = StateRun(row, mode, ctx, capture);
  if (row.state == 'LOADING') {
    await tester.pump(const Duration(milliseconds: 299));
    run.violations.addAll(earlySkeletonCheck());
    await tester.pump(const Duration(milliseconds: 2));
  } else {
    await tester.pump(const Duration(milliseconds: 400));
  }
  drainExceptions(tester, capture);
  return run;
}

/// Reads the rule for the row's kind off the tree now on screen.
Future<List<Violation>> judgeState(WidgetTester tester, StateRun run) async {
  final ctx = run.ctx;
  if (ctx == null) return run.violations;
  final host = stateHosts[run.row.id]!;
  final kindRule = switch (run.row.state) {
    'LOADING' => loadingRule(earlyCheck: const []),
    'EMPTY' => emptyRule(run.mode),
    'OFFLINE' => offlineRule(tester, run.mode),
    'CONFLICT' =>
      host.conflictItems == null
          ? recipeConflictRule()
          : shoppingConflictRule(
              localItem: host.conflictItems!.local,
              remoteItem: host.conflictItems!.remote,
            ),
    _ => const <Violation>[],
  };
  drainExceptions(tester, run.capture);
  // Colours and overflow last: a CONFLICT host may have opened the diff.
  run.violations
    ..addAll(kindRule)
    ..addAll(commonRule(run.capture, run.mode));
  return run.violations;
}

/// Takes the host off screen and undoes the shared services.
Future<void> finishState(WidgetTester tester, StateRun run) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  final before = run.capture.exceptions.length;
  drainExceptions(tester, run.capture);
  if (run.capture.exceptions.length > before &&
      !run.violations.any((v) => v.code == 'EXCEPTION')) {
    run.violations.add(
      Violation('EXCEPTION', run.capture.exceptions.skip(before).join(' | ')),
    );
  }
  run.capture.restore();
  final ctx = run.ctx;
  if (ctx == null) return;
  for (final dispose in ctx.disposers.reversed) {
    dispose();
  }
  await ctx.env.tearDown();
}
