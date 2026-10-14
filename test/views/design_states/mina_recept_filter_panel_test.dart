/// Intent: an open filter panel scrolls away with the recipe cards instead of
/// being pinned, so on the smallest phone at 200 % text the pinned part stays
/// inside the screen and the cards can still be reached (A40 / 17-A5).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/search_filter_widget.dart';
import 'package:butlery/widgets/common/search_filter/filters_panel_widget.dart';

import '../golden_linux/golden_hosts.dart';
import 'state_harness.dart';
import 'state_hosts.dart';
import 'state_runner.dart';

const _screen = Size(360, 640);

void main() {
  setUpAll(registerHostFallbacks);

  testWidgets('with the panel open at 360x640 and 200 % text the pinned part '
      'fits the screen and the cards stay reachable', (tester) async {
    final run = await pumpState(
      tester,
      StateRow(
        view: 'mina_recept',
        state: 'DEFAULT',
        drawing: '-',
        evidence: '-',
        host: '-',
        hostFile: '-',
        hostNote: null,
        block288Category: '-',
        ownerNow: null,
      ),
      Brightness.light,
      size: _screen,
      textScale: 2.0,
      host: minaReceptHost,
    );

    await tester.tap(
      find.descendant(
        of: find.byType(SearchFilterWidget),
        matching: find.byIcon(ButleryIcons.filter),
      ),
    );
    // The panel animates open and the host's looping animations keep
    // pumpAndSettle from returning.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 2));

    final panel = find.byType(FiltersPanelWidget);
    expect(
      tester.getSize(panel).height,
      greaterThan(0),
      reason: 'the panel must be open for this measurement to mean anything',
    );
    expect(
      tester.getRect(find.byType(SearchFilterWidget)).bottom,
      lessThanOrEqualTo(_screen.height),
      reason: 'search is pinned; nothing below it may push it off the screen',
    );
    expect(
      tester.getSize(panel).height,
      greaterThan(_screen.height / 2),
      reason:
          'taller than the old half-screen cap: it takes its full height '
          'and the list scrolls it, instead of a scroll area of its own',
    );

    final firstCard = find.text('Krämig svamppasta med timjan');
    var dragged = 0;
    while ((firstCard.evaluate().isEmpty ||
            tester.getRect(firstCard).bottom >= _screen.height) &&
        dragged++ < 30) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -150));
      await tester.pump();
    }
    expect(tester.getRect(firstCard).bottom, lessThan(_screen.height));
    await finishState(tester, run);
  });
}
