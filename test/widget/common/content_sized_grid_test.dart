// BUT-1911: the index arithmetic in `ContentSizedGrid` is the whole widget, and
// its only production caller renders a grid of recipe cards whose own suite
// covers one full row. Everything the arithmetic can get wrong — a short last
// row, the gap between rows, a single column, an empty list — lives here.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/widgets/common/content_sized_grid.dart';

void main() {
  /// A cell wide enough to measure and tall enough to differ per index, so a
  /// row's height can be read against its tallest member.
  Widget cell(int index, {double height = 40}) => SizedBox(
    key: ValueKey('cell-$index'),
    height: height,
    child: Text('$index'),
  );

  Future<void> pump(
    WidgetTester tester, {
    required int itemCount,
    required int columns,
    double spacing = 16,
    double Function(int index)? heightOf,
  }) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ContentSizedGrid(
            itemCount: itemCount,
            columns: columns,
            spacing: spacing,
            padding: EdgeInsets.zero,
            itemBuilder: (context, index) =>
                cell(index, height: heightOf?.call(index) ?? 40),
          ),
        ),
      ),
    );
  }

  testWidgets('a short last row keeps the column width of a full row', (
    tester,
  ) async {
    // The reason the empty cells are laid out at all. Without them the lone
    // card in the last row stretches across the screen and the grid looks
    // broken at exactly the size most lists end at.
    await pump(tester, itemCount: 3, columns: 2);

    final first = tester.getRect(find.byKey(const ValueKey('cell-0')));
    final second = tester.getRect(find.byKey(const ValueKey('cell-1')));
    final last = tester.getRect(find.byKey(const ValueKey('cell-2')));

    expect(last.width, first.width);
    expect(last.left, first.left, reason: 'it starts in the first column');

    // The gutter BETWEEN columns, which nothing else here can see: deleting
    // it makes every tile wider, so the row-spacing case still passes, the
    // width comparisons above still pass because both sides move together,
    // and the recipe geometry suite gets an EASIER job. Cards touching
    // edge-to-edge would have shipped with nothing red.
    expect(
      second.left - first.right,
      16,
      reason: 'one spacing between columns, the same value used between rows',
    );
  });

  testWidgets('rows are separated by the spacing, and the last one is not', (
    tester,
  ) async {
    // A trailing gap under the final row is the classic off-by-one here, and
    // it is invisible in a screenshot of a scrolling list.
    await pump(tester, itemCount: 4, columns: 2, spacing: 24);

    final row1 = tester.getRect(find.byKey(const ValueKey('cell-0')));
    final row2 = tester.getRect(find.byKey(const ValueKey('cell-2')));
    expect(row2.top - row1.bottom, 24);

    // And no gap UNDER the last row. Measured as scroll extent, because a
    // trailing 24px on the final row is invisible in any screenshot of a list
    // that scrolls: two 40px rows plus one 24px gap is 104px of content, so a
    // 60px viewport scrolls exactly 44. A trailing gap would make it 68.
    tester.view.physicalSize = const Size(800, 60);
    await tester.pump();
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position;
    expect(
      position.maxScrollExtent,
      44,
      reason: 'the last row must not carry a bottom gap',
    );
  });

  testWidgets('a row is as tall as its tallest cell', (tester) async {
    // The entire point of the widget. If this ever stops holding, the shorter
    // card is the one that clips.
    await pump(
      tester,
      itemCount: 2,
      columns: 2,
      heightOf: (i) => i == 0 ? 40 : 120,
    );

    final short = tester.getRect(find.byKey(const ValueKey('cell-0')));
    final tall = tester.getRect(find.byKey(const ValueKey('cell-1')));

    expect(tall.height, 120);
    expect(
      short.height,
      120,
      reason:
          'cells stretch to the row height, so a card that draws less keeps '
          'the same box rather than ending short of its neighbour',
    );
  });

  testWidgets('a cell whose height depends on its width is measured at the '
      'COLUMN width', (tester) async {
    // The one thing this widget exists for, and the case the fixed-height
    // cells above are structurally blind to. A recipe card's height is a
    // function of how wide its column is — text wraps. If the row measured a
    // cell at the full viewport width instead of its share of it, every
    // fixed-height case still passes and every real card clips.
    //
    // 800px viewport, two columns, 16px gutter -> 392px per column. The word
    // is sized so it fits on one line at 392 and needs two at 800/2 without
    // the gutter taken off... so the assertion is on the RATIO, not a pixel
    // count: a cell measured at the wrong width wraps to a different number
    // of lines than the column it is drawn in.
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    const long =
        'Köttbullar med potatismos och lingonsylt och pressgurka och '
        'brunsås till hela familjen';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ContentSizedGrid(
            itemCount: 2,
            columns: 2,
            spacing: 16,
            padding: EdgeInsets.zero,
            itemBuilder: (context, index) => KeyedSubtree(
              key: ValueKey('cell-$index'),
              child: Text(index == 0 ? long : 'kort'),
            ),
          ),
        ),
      ),
    );

    final wrapping = tester.getRect(find.byKey(const ValueKey('cell-0')));
    final short = tester.getRect(find.byKey(const ValueKey('cell-1')));
    final text = tester.getRect(find.text(long));

    expect(
      wrapping.width,
      392,
      reason: '(800 - one 16px gutter) / 2',
    );
    expect(
      text.width,
      lessThanOrEqualTo(392),
      reason:
          'the text must have been laid out at the COLUMN width — measured at '
          'the full viewport it would wrap to fewer, wider lines and the row '
          'would be too short for what is drawn',
    );
    expect(
      text.height,
      greaterThan(20),
      reason: 'the premise: this string really does wrap at 392px',
    );
    expect(
      short.height,
      wrapping.height,
      reason: 'and the short cell stretches to the wrapped one',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('one column lays out one card per row', (tester) async {
    await pump(tester, itemCount: 3, columns: 1, spacing: 10);

    final a = tester.getRect(find.byKey(const ValueKey('cell-0')));
    final b = tester.getRect(find.byKey(const ValueKey('cell-1')));

    expect(a.left, b.left);
    expect(b.top - a.bottom, 10);
    expect(a.width, tester.getRect(find.byType(ContentSizedGrid)).width);
  });

  testWidgets('an empty list renders nothing and does not throw', (
    tester,
  ) async {
    await pump(tester, itemCount: 0, columns: 3);

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('cell-0')), findsNothing);
  });

  testWidgets('only the rows near the viewport are built', (tester) async {
    // The laziness `GridView.builder` had. A grid that builds every row up
    // front is a different widget with the same name.
    final built = <int>[];
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ContentSizedGrid(
            itemCount: 400,
            columns: 2,
            spacing: 16,
            padding: EdgeInsets.zero,
            itemBuilder: (context, index) {
              built.add(index);
              return cell(index, height: 100);
            },
          ),
        ),
      ),
    );

    expect(
      built.length,
      lessThan(400),
      reason: 'a lazy list must not build all 400 cells for a 600px viewport',
    );
    expect(built, contains(0));
  });
}
