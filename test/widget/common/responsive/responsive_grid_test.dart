/// Widget tests for ResponsiveGrid + ResponsiveGridExtent + ResponsiveWrap +
/// ResponsiveStaggeredGrid + ResponsiveListGrid.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/widgets/common/responsive/responsive_grid.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

/// Pump at a specific logical width so Breakpoints resolves to a known
/// category. height is generous to avoid clipping the children we look for.
Future<void> _pumpAtWidth(
  WidgetTester tester,
  double width,
  Widget child,
) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(width, 2000);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_wrap(child));
}

SliverGridDelegateWithFixedCrossAxisCount _fixedDelegate(WidgetTester tester) {
  final grid = tester.widget<GridView>(find.byType(GridView));
  return grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
}

void main() {
  group('ResponsiveGrid — column count by breakpoint', () {
    testWidgets('mobile (< 600px) → 1 column', (tester) async {
      await _pumpAtWidth(
        tester,
        400,
        const ResponsiveGrid(children: [Text('a')]),
      );
      expect(_fixedDelegate(tester).crossAxisCount, 1);
    });

    testWidgets('tablet (600-1023px) → 2 columns', (tester) async {
      await _pumpAtWidth(
        tester,
        800,
        const ResponsiveGrid(children: [Text('a')]),
      );
      // 800px → tablet category (>= 768, < 1024)
      expect(_fixedDelegate(tester).crossAxisCount, 2);
    });

    testWidgets('desktop (1280-1919px) → 3 columns', (tester) async {
      await _pumpAtWidth(
        tester,
        1400,
        const ResponsiveGrid(children: [Text('a')]),
      );
      expect(_fixedDelegate(tester).crossAxisCount, 3);
    });

    testWidgets('large desktop (>= 1920px) → 4 columns', (tester) async {
      await _pumpAtWidth(
        tester,
        2000,
        const ResponsiveGrid(children: [Text('a')]),
      );
      expect(_fixedDelegate(tester).crossAxisCount, 4);
    });

    testWidgets('custom column counts override breakpoint defaults', (
      tester,
    ) async {
      await _pumpAtWidth(
        tester,
        400,
        const ResponsiveGrid(
          mobileColumns: 5,
          children: [Text('a')],
        ),
      );
      expect(_fixedDelegate(tester).crossAxisCount, 5);
    });
  });

  group('ResponsiveGrid — children vs lazy modes', () {
    testWidgets('children mode: renders each child', (tester) async {
      await _pumpAtWidth(
        tester,
        400,
        const ResponsiveGrid(
          children: [
            Text('first'),
            Text('second'),
            Text('third'),
          ],
        ),
      );
      expect(find.text('first'), findsOneWidget);
      expect(find.text('second'), findsOneWidget);
      expect(find.text('third'), findsOneWidget);
    });

    testWidgets('lazy mode: itemCount limits builder calls', (tester) async {
      var calls = 0;
      await _pumpAtWidth(
        tester,
        400,
        ResponsiveGrid(
          lazyItemCount: 4,
          lazyItemBuilder: (ctx, i) {
            calls++;
            return Text('lazy-$i');
          },
        ),
      );
      // GridView.builder is lazy; at least the visible items get built.
      expect(calls, greaterThan(0));
      expect(calls, lessThanOrEqualTo(4));
      expect(find.text('lazy-0'), findsOneWidget);
    });

    testWidgets('animate=true wraps each child in AnimatedListItem', (
      tester,
    ) async {
      await _pumpAtWidth(
        tester,
        400,
        const ResponsiveGrid(
          animate: true,
          children: [Text('a'), Text('b')],
        ),
      );
      // AnimatedListItem is a private wrapper, just verify it produces stable
      // output without throwing and renders the children.
      expect(find.text('a'), findsOneWidget);
      expect(find.text('b'), findsOneWidget);
    });
  });

  group('ResponsiveGrid — spacing props', () {
    testWidgets('explicit mainAxisSpacing wins', (tester) async {
      await _pumpAtWidth(
        tester,
        400,
        const ResponsiveGrid(
          mainAxisSpacing: 42,
          children: [Text('a')],
        ),
      );
      expect(_fixedDelegate(tester).mainAxisSpacing, 42);
    });

    testWidgets('explicit crossAxisSpacing wins', (tester) async {
      await _pumpAtWidth(
        tester,
        400,
        const ResponsiveGrid(
          crossAxisSpacing: 17,
          children: [Text('a')],
        ),
      );
      expect(_fixedDelegate(tester).crossAxisSpacing, 17);
    });

    testWidgets('explicit aspect ratio wins over default 1.0', (tester) async {
      await _pumpAtWidth(
        tester,
        400,
        const ResponsiveGrid(
          childAspectRatio: 2.5,
          children: [Text('a')],
        ),
      );
      expect(_fixedDelegate(tester).childAspectRatio, 2.5);
    });
  });

  group('ResponsiveGridExtent', () {
    testWidgets('passes maxCrossAxisExtent through to delegate', (
      tester,
    ) async {
      await _pumpAtWidth(
        tester,
        400,
        const ResponsiveGridExtent(
          maxCrossAxisExtent: 250,
          children: [Text('x')],
        ),
      );
      final grid = tester.widget<GridView>(find.byType(GridView));
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithMaxCrossAxisExtent;
      expect(delegate.maxCrossAxisExtent, 250);
    });

    testWidgets('renders children', (tester) async {
      await _pumpAtWidth(
        tester,
        400,
        const ResponsiveGridExtent(
          maxCrossAxisExtent: 300,
          children: [Text('one'), Text('two')],
        ),
      );
      expect(find.text('one'), findsOneWidget);
      expect(find.text('two'), findsOneWidget);
    });

    testWidgets('explicit aspect ratio wins over default 1.0', (tester) async {
      await _pumpAtWidth(
        tester,
        400,
        const ResponsiveGridExtent(
          maxCrossAxisExtent: 300,
          childAspectRatio: 0.75,
          children: [Text('a')],
        ),
      );
      final delegate =
          (tester.widget<GridView>(find.byType(GridView)).gridDelegate)
              as SliverGridDelegateWithMaxCrossAxisExtent;
      expect(delegate.childAspectRatio, 0.75);
    });
  });

  group('ResponsiveWrap', () {
    testWidgets('renders all children inside a Wrap', (tester) async {
      await _pumpAtWidth(
        tester,
        400,
        const ResponsiveWrap(
          children: [
            Chip(label: Text('A')),
            Chip(label: Text('B')),
          ],
        ),
      );
      expect(find.byType(Wrap), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
    });

    testWidgets('forwards alignment props', (tester) async {
      await _pumpAtWidth(
        tester,
        400,
        const ResponsiveWrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.end,
          runAlignment: WrapAlignment.center,
          children: [Text('a')],
        ),
      );
      final w = tester.widget<Wrap>(find.byType(Wrap));
      expect(w.alignment, WrapAlignment.spaceBetween);
      expect(w.crossAxisAlignment, WrapCrossAlignment.end);
      expect(w.runAlignment, WrapAlignment.center);
    });

    testWidgets('explicit spacing wins over breakpoint default', (
      tester,
    ) async {
      await _pumpAtWidth(
        tester,
        400,
        const ResponsiveWrap(
          spacing: 99,
          runSpacing: 33,
          children: [Text('a')],
        ),
      );
      final w = tester.widget<Wrap>(find.byType(Wrap));
      expect(w.spacing, 99);
      expect(w.runSpacing, 33);
    });
  });

  group('ResponsiveStaggeredGrid', () {
    testWidgets('distributes children round-robin across columns', (
      tester,
    ) async {
      // mobile → 1 column → all children stack vertically
      await _pumpAtWidth(
        tester,
        400,
        const ResponsiveStaggeredGrid(
          children: [Text('a'), Text('b'), Text('c')],
        ),
      );
      expect(find.text('a'), findsOneWidget);
      expect(find.text('b'), findsOneWidget);
      expect(find.text('c'), findsOneWidget);
      // Should produce 1 Expanded for 1 column
      expect(find.byType(Expanded), findsOneWidget);
    });

    testWidgets('on tablet width: 2 columns, 2 Expanded', (tester) async {
      await _pumpAtWidth(
        tester,
        800,
        const ResponsiveStaggeredGrid(
          children: [Text('a'), Text('b'), Text('c'), Text('d')],
        ),
      );
      expect(find.byType(Expanded), findsNWidgets(2));
    });

    testWidgets('custom column counts override default', (tester) async {
      await _pumpAtWidth(
        tester,
        400,
        const ResponsiveStaggeredGrid(
          mobileColumns: 3,
          children: [Text('a'), Text('b'), Text('c')],
        ),
      );
      expect(find.byType(Expanded), findsNWidgets(3));
    });
  });

  group('ResponsiveListGrid', () {
    testWidgets('mobile → ListView.separated (no GridView)', (tester) async {
      await _pumpAtWidth(
        tester,
        400,
        ResponsiveListGrid<String>(
          items: const ['x', 'y'],
          itemBuilder: (ctx, item) => Text(item),
        ),
      );
      expect(find.byType(ListView), findsOneWidget);
      expect(find.byType(GridView), findsNothing);
      expect(find.text('x'), findsOneWidget);
      expect(find.text('y'), findsOneWidget);
    });

    testWidgets('tablet → GridView (no ListView)', (tester) async {
      await _pumpAtWidth(
        tester,
        800,
        ResponsiveListGrid<int>(
          items: const [1, 2, 3, 4],
          itemBuilder: (ctx, n) => Text('item-$n'),
        ),
      );
      expect(find.byType(GridView), findsOneWidget);
      expect(find.byType(ListView), findsNothing);
    });

    testWidgets('desktop → GridView with desktop column count', (tester) async {
      await _pumpAtWidth(
        tester,
        1400,
        ResponsiveListGrid<int>(
          items: const [1, 2, 3, 4, 5, 6],
          itemBuilder: (ctx, n) => Text('n=$n'),
        ),
      );
      expect(_fixedDelegate(tester).crossAxisCount, 3);
    });
  });
}
