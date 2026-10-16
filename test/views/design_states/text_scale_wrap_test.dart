// At the largest text size a screen has to wrap between words or scroll:
// no overflow stripes and no word broken between letters. Each screen is
// its own case so a failure names the screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../infrastructure/helpers/word_break_finder.dart';
import '../golden_linux/linux_golden_helper.dart';
import 'hosts/review_hosts.dart';
import 'hosts/shopping_hosts.dart' show pantryWithItemsHost;
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

const _rows = ['veckomeny', 'inköpslista', 'admin', 'skafferi'];
const _hosts = [
  'CookbookDetailView',
  'TagDetailView',
  'FriendRequestsView',
  'GroupWeeklyMenuView',
  'MenuPlacementView',
];

void main() {
  setUpAll(() async {
    registerHostFallbacks();
    await loadGoldenFonts();
  });

  final rows = {
    for (final r in StateFixture.load().rows)
      if (r.state == 'DEFAULT') r.view: r,
  };

  Future<void> expectCalm(
    WidgetTester tester,
    StateRow row,
    StateHost? host, {
    Size size = const Size(360, 800),
  }) async {
    final run = await pumpState(
      tester,
      row,
      Brightness.light,
      host: host,
      size: size,
      textScale: 2,
    );
    expect(run.capture.overflows, isEmpty, reason: 'overflow in ${row.view}');
    expect(findMidWordBreaks(tester), isEmpty);
    await finishState(tester, run);
  }

  for (final view in _rows) {
    testWidgets('$view at 200 % text wraps between words', (tester) async {
      expect(rows[view], isNotNull);
      await expectCalm(tester, rows[view]!, null);
    });
  }
  for (final name in _hosts) {
    testWidgets('$name at 200 % text wraps between words', (tester) async {
      await expectCalm(tester, _row(name), reviewHosts[name]);
    });
  }
  testWidgets('the shopping tabs keep their labels whole at 200 % text', (
    tester,
  ) async {
    final run = await pumpState(
      tester,
      rows['inköpslista']!,
      Brightness.light,
      size: const Size(360, 800),
      textScale: 2,
    );
    // Cut off by the tab's own edge, a label draws no ellipsis, so the
    // test asks for the sideways scroll that keeps it whole.
    expect(tester.widget<TabBar>(find.byType(TabBar)).isScrollable, isTrue);
    await finishState(tester, run);
  });
  testWidgets('pantry at 200 % text wraps between words', (tester) async {
    await expectCalm(tester, _row('pantry'), pantryWithItemsHost);
  });
}
