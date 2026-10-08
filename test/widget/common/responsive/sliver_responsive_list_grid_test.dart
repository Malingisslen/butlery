// BUT-2254: Mina recept's list mode, as a sliver under the pinned library
// header. A phone gets one item per row with the spacing between items; a
// tablet or desktop gets a grid with the caller's column count.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/widgets/common/responsive/sliver_responsive_list_grid.dart';

Future<void> _pumpAtWidth(
  WidgetTester tester,
  double width, {
  int? tabletColumns,
  int? desktopColumns,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(width, 2000);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverResponsiveListGrid<int>(
              items: const [0, 1, 2, 3, 4, 5],
              tabletColumns: tabletColumns,
              desktopColumns: desktopColumns,
              spacing: 12,
              padding: EdgeInsets.zero,
              gridChildAspectRatio: 2,
              itemBuilder: (context, n) => SizedBox(
                key: ValueKey('item-$n'),
                height: 50,
                child: Text('item-$n'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Rect _rect(WidgetTester tester, int n) =>
    tester.getRect(find.byKey(ValueKey('item-$n')));

/// How many items share the first item's row.
int _firstRowCount(WidgetTester tester) {
  final top = _rect(tester, 0).top;
  var n = 0;
  while (find.byKey(ValueKey('item-$n')).evaluate().isNotEmpty &&
      _rect(tester, n).top == top) {
    n++;
  }
  return n;
}

void main() {
  testWidgets('phone: one item per row, the spacing between them', (
    tester,
  ) async {
    await _pumpAtWidth(tester, 400);

    final a = _rect(tester, 0);
    final b = _rect(tester, 1);
    expect(_firstRowCount(tester), 1);
    expect(b.left, a.left);
    expect(a.width, 400);
    expect(b.top - a.bottom, 12);
    expect(a.height, 50, reason: 'a list item keeps its own height');
  });

  testWidgets('phone: no gap under the last item', (tester) async {
    await _pumpAtWidth(tester, 400);

    // Six 50px items and five 12px gaps: 360px, so a 300px viewport scrolls
    // 60. A gap after the sixth item makes it 72.
    tester.view.physicalSize = const Size(400, 300);
    await tester.pump();
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position;
    expect(position.maxScrollExtent, 60);
  });

  testWidgets('tablet: two columns by default', (tester) async {
    await _pumpAtWidth(tester, 800);

    expect(_firstRowCount(tester), 2);
    final a = _rect(tester, 0);
    final b = _rect(tester, 1);
    expect(b.left - a.right, 12, reason: 'the spacing between columns');
    expect(_rect(tester, 2).top - a.bottom, 12, reason: 'and between rows');
  });

  testWidgets('tablet: the caller\'s column count wins', (tester) async {
    await _pumpAtWidth(tester, 800, tabletColumns: 3);

    expect(_firstRowCount(tester), 3);
  });

  testWidgets('desktop: three columns by default, the caller\'s count wins', (
    tester,
  ) async {
    await _pumpAtWidth(tester, 1400);
    expect(_firstRowCount(tester), 3);

    await _pumpAtWidth(tester, 1400, desktopColumns: 4);
    expect(_firstRowCount(tester), 4);
  });
}
