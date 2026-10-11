// BUT-723: the real Mina recept view beside a detail pane. The pane itself has
// suites of its own; this one pins what Hem hands it: the first recipe before
// any pick, and a discovery-shelf card opened on the right.

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/views/mina_recept/discovery_shelves_widget.dart';
import 'package:butlery/widgets/common/layout/detail_pane.dart';

import '../../../views/design_states/state_harness.dart';
import '../../../views/design_states/state_host.dart';
import '../../../views/design_states/state_hosts.dart'
    show registerHostFallbacks;
import '../../../views/design_states/state_runner.dart';
import '../../../views/golden_linux/golden_hosts.dart';

/// Counts the view's offers, so a repeat the controller would ignore anyway
/// still shows.
class _SpyController extends DetailPaneController {
  final offers = <Object>[];

  @override
  void offerFirst(RouteSettings settings, {required Object key}) {
    offers.add(key);
    super.offerFirst(settings, key: key);
  }
}

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

void main() {
  setUpAll(registerHostFallbacks);

  StateHost paneHost(DetailPaneController? pane, {bool dormant = false}) {
    final base = minaReceptHostWith(dormantRecipe: dormant);
    return StateHost(
      build: (ctx) async {
        final home = await base.build(ctx);
        return pane == null
            ? home
            : DetailPaneScope(controller: pane, child: home);
      },
      reach: base.reach,
    );
  }

  Future<StateRun> pumpHem(
    WidgetTester tester,
    DetailPaneController? pane, {
    bool dormant = false,
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
          size: const Size(400, 1600),
          host: paneHost(pane, dormant: dormant),
        );
      },
    );
    return run;
  }

  String? shownId(DetailPaneController pane) =>
      (pane.selected?.arguments as Recipe?)?.id;

  testWidgets(
    'the first recipe is offered once, and a later pick replaces it',
    (
      tester,
    ) async {
      final pane = _SpyController();
      addTearDown(pane.dispose);
      final run = await pumpHem(tester, pane);
      await tester.pump();

      expect(pane.selected?.name, Routes.recipeDetail);
      expect(shownId(pane), 'r1');
      expect(pane.isSelected('r1'), isTrue);
      expect(pane.offers, ['r1']);

      // A rebuild with the same first recipe offers nothing new.
      pane.notifyListeners();
      await tester.pump();
      await tester.pump();
      expect(pane.offers, ['r1']);

      pane.open(const RouteSettings(name: '/other'), key: 'other');
      await tester.pump();
      await tester.pump();
      expect(pane.isSelected('other'), isTrue);
      expect(pane.isSelected('r1'), isFalse);

      run.capture.restore();
      expect(run.capture.exceptions, isEmpty);
      await finishState(tester, run);
    },
  );

  testWidgets('without a pane the view still draws', (
    tester,
  ) async {
    final run = await pumpHem(tester, null);
    await tester.pump();
    run.capture.restore();
    expect(run.capture.exceptions, isEmpty);
    expect(find.text('Krämig svamppasta med timjan'), findsWidgets);
    await finishState(tester, run);
  });

  testWidgets('a discovery-shelf card opens on the right', (tester) async {
    final pane = _SpyController();
    addTearDown(pane.dispose);
    final run = await pumpHem(tester, pane, dormant: true);
    await tester.pump();

    final shelfCard = find.descendant(
      of: find.byType(MinaReceptDiscoveryShelves),
      matching: find.text('Kålpudding'),
    );
    expect(shelfCard, findsWidgets);
    await tester.ensureVisible(shelfCard.first);
    await tester.tap(shelfCard.first);
    await tester.pump();

    expect(pane.selected?.name, Routes.recipeDetail);
    expect(shownId(pane), 'r5');
    expect(pane.isSelected('r5'), isTrue);
    // The tap stays on the list side: nothing was pushed over Hem.
    expect(find.byType(MinaReceptDiscoveryShelves), findsOneWidget);

    run.capture.restore();
    expect(run.capture.exceptions, isEmpty);
    await finishState(tester, run);
  });
}
