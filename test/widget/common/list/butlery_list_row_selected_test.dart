// BUT-723: the row of the item shown on the right takes the selected surface
// across its full width and says so to a screen reader.

import 'dart:ui' show Tristate;

import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(ButleryListRow row) => MaterialApp(
  theme: AppTheme.lightTheme,
  home: Scaffold(body: ListView(children: [row])),
);

Finder get _rowSurface => find.descendant(
  of: find.byType(ButleryListRow),
  matching: find.byType(Material),
);

void main() {
  testWidgets('selected: true exposes selected and paints the surface', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(ButleryListRow(label: 'Profil', selected: true, onTap: () {})),
    );

    final data = tester
        .getSemantics(find.bySemanticsLabel('Profil'))
        .getSemanticsData();
    expect(data.flagsCollection.isSelected, Tristate.isTrue);
    expect(data.flagsCollection.isButton, isTrue);
    final material = tester.widget<Material>(_rowSurface.first);
    expect(
      material.color,
      Theme.of(
        tester.element(find.byType(ButleryListRow)),
      ).colorScheme.surfaceContainerHighest,
    );
    expect(
      tester.getSize(_rowSurface.first).width,
      tester.getSize(find.byType(ButleryListRow)).width,
    );
    handle.dispose();
  });

  testWidgets('selected: false is announced as not selected, unpainted', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(ButleryListRow(label: 'Profil', selected: false, onTap: () {})),
    );

    final data = tester
        .getSemantics(find.bySemanticsLabel('Profil'))
        .getSemanticsData();
    expect(data.flagsCollection.isSelected, isNot(Tristate.none));
    expect(data.flagsCollection.isSelected, isNot(Tristate.isTrue));
    expect(
      tester.widget<Material>(_rowSurface.first).color,
      Colors.transparent,
    );
    handle.dispose();
  });

  testWidgets('without selected the row carries no selected state', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(ButleryListRow(label: 'Profil', onTap: () {})),
    );

    final data = tester
        .getSemantics(find.bySemanticsLabel('Profil'))
        .getSemanticsData();
    expect(data.flagsCollection.isSelected, Tristate.none);
    handle.dispose();
  });
}
