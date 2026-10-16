// On a desktop-wide window the recipe cards share their cell, and a chat or
// a form keeps to the page column instead of running edge to edge.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/responsive/breakpoints.dart';
import 'package:butlery/widgets/recipe/recipe_card.dart';

import '../golden_linux/golden_hosts.dart';
import '../golden_linux/linux_golden_helper.dart';
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
  const wide = Size(1280, 800);

  setUpAll(() async {
    registerHostFallbacks();
    await loadGoldenFonts();
  });

  final rows = {
    for (final r in StateFixture.load().rows)
      if (r.state == 'DEFAULT') r.view: r,
  };

  Future<StateRun> open(
    WidgetTester tester,
    StateRow row, {
    StateHost? host,
  }) => pumpState(tester, row, Brightness.light, host: host, size: wide);

  testWidgets('Mina recept: every card is as wide as its cell', (
    tester,
  ) async {
    final run = await open(tester, _row('minaRecept'), host: minaReceptHost);

    final cards = find.byType(RecipeCard).evaluate().toList();
    expect(cards.length, greaterThan(1));
    final widths = {
      for (final c in cards) (c.renderObject! as RenderBox).size.width,
    };
    expect(widths, hasLength(1), reason: 'cards share one width: $widths');
    await finishState(tester, run);
  });

  testWidgets('the chat keeps to the page column', (tester) async {
    final run = await open(tester, rows['chatt']!);

    final cap = Breakpoints.pageMaxWidth(
      tester.element(find.byType(Scaffold).first),
      PageWidth.text,
    );
    final bubble = find.textContaining('kokosmjölk');
    expect(bubble, findsOneWidget);
    expect(tester.getTopRight(bubble).dx, lessThanOrEqualTo(cap));
    await finishState(tester, run);
  });

  testWidgets('the recipe editor keeps its fields to the page column', (
    tester,
  ) async {
    final run = await open(tester, rows['recepteditor']!);

    final cap = Breakpoints.pageMaxWidth(
      tester.element(find.byType(Scaffold).first),
      PageWidth.text,
    );
    final fields = find.byType(TextField);
    expect(fields, findsWidgets);
    for (final f in fields.evaluate()) {
      final box = f.renderObject! as RenderBox;
      expect(
        box.localToGlobal(Offset(box.size.width, 0)).dx,
        lessThanOrEqualTo(cap),
      );
    }
    await finishState(tester, run);
  });
}
