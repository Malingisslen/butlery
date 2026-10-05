// BUT-2254: the real Mina recept view on a phone. Before the fix the swipe
// hint, banners and discovery shelves sat in a Column above an Expanded grid,
// one viewport tall.

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/views/mina_recept/discovery_shelves_widget.dart';
import 'package:butlery/views/mina_recept/recipe_card_widget.dart';
import 'package:butlery/widgets/common/content_sized_grid.dart';
import 'package:butlery/widgets/common/responsive/sliver_responsive_list_grid.dart';

import '../../../views/design_states/state_harness.dart';
import '../../../views/design_states/state_hosts.dart'
    show registerHostFallbacks;
import '../../../views/design_states/state_runner.dart';
import '../../../views/golden_linux/golden_hosts.dart';

const _height = 800.0;

final _row = StateRow(
  view: 'mina_recept',
  state: 'DEFAULT',
  drawing: '-',
  evidence: '-',
  host: '-',
  hostFile: '-',
  hostNote: null,
  block288Category: '-',
  ownerNow: null,
);

Future<StateRun> _pump(
  WidgetTester tester, {
  required double width,
  required double textScale,
  required bool grid,
  bool dormantRecipe = false,
}) async {
  final start = tester.binding.clock.now();
  late StateRun run;
  await withClock(
    Clock(() => goldenNow.add(tester.binding.clock.now().difference(start))),
    () async {
      run = await pumpState(
        tester,
        _row,
        Brightness.light,
        size: Size(width, _height),
        textScale: textScale,
        host: minaReceptHostWith(dormantRecipe: dormantRecipe, grid: grid),
      );
    },
  );
  return run;
}

Finder get _firstCard => find.byType(MinaReceptRecipeCard).first;

/// Scrolls the page until the first recipe card's top is on the screen:
/// below the greeting, the shelves and the banners it starts off screen.
Future<void> _scrollToFirstCard(WidgetTester tester) async {
  bool onScreen() =>
      find.byType(MinaReceptRecipeCard).evaluate().isNotEmpty &&
      tester.getRect(_firstCard).top < _height;
  for (var i = 0; i < 40 && !onScreen(); i++) {
    await tester.drag(find.byType(NestedScrollView), const Offset(0, -100));
    await tester.pump();
  }
  // The list mode's entrance animation scales the card in.
  await tester.pump(const Duration(seconds: 1));
}

/// The first card sits inside the viewport.
void _expectFirstCardVisible(WidgetTester tester, {required bool grid}) {
  // The premise: the mode under test is the one on screen.
  expect(
    find.byType(SliverContentSizedGrid),
    grid ? findsOneWidget : findsNothing,
  );
  expect(
    find.byWidgetPredicate((w) => w is SliverResponsiveListGrid),
    grid ? findsNothing : findsOneWidget,
  );
  expect(find.byType(MinaReceptRecipeCard), findsWidgets);
  final card = tester.getRect(_firstCard);
  expect(card.top, lessThan(_height), reason: 'the card is on the screen');
}

void main() {
  setUpAll(registerHostFallbacks);

  for (final grid in [true, false]) {
    final mode = grid ? 'grid' : 'list';
    for (final width in [360.0, 320.0]) {
      testWidgets('${width.toInt()} dp, 1.0 with a discovery shelf ($mode): '
          'no overflow and the first card is visible', (tester) async {
        final run = await _pump(
          tester,
          width: width,
          textScale: 1.0,
          grid: grid,
          dormantRecipe: true,
        );
        run.capture.restore();
        // The premise: the never-cooked recipe fills the discovery shelf.
        expect(find.byType(MinaReceptDiscoveryShelves), findsOneWidget);
        expect(find.text('Kålpudding'), findsWidgets);
        expect(run.capture.overflows, isEmpty);
        expect(run.capture.exceptions, isEmpty);
        await _scrollToFirstCard(tester);
        _expectFirstCardVisible(tester, grid: grid);
        await finishState(tester, run);
      });

      testWidgets('${width.toInt()} dp, 2.0 ($mode): no overflow and the '
          'first card is visible', (tester) async {
        final run = await _pump(
          tester,
          width: width,
          textScale: 2.0,
          grid: grid,
        );
        run.capture.restore();
        expect(run.capture.overflows, isEmpty);
        expect(run.capture.exceptions, isEmpty);
        await _scrollToFirstCard(tester);
        _expectFirstCardVisible(tester, grid: grid);
        await finishState(tester, run);
      });
    }
  }
}
