/// Widget tests for FilterStatusChip.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/widgets/common/filter_status_chip.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('renders filter label with single-part list', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const FilterStatusChip(
          filterParts: ['Vegetarisk'],
          selectedCount: 1,
        ),
      ),
    );
    expect(find.text('Filter: Vegetarisk'), findsOneWidget);
    expect(find.text('1 valda'), findsOneWidget);
  });

  testWidgets('joins multiple filter parts with " • "', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const FilterStatusChip(
          filterParts: ['Vegetarisk', 'Mejerifri', 'Glutenfri'],
          selectedCount: 7,
        ),
      ),
    );
    expect(
      find.text('Filter: Vegetarisk • Mejerifri • Glutenfri'),
      findsOneWidget,
    );
    expect(find.text('7 valda'), findsOneWidget);
  });

  testWidgets('renders empty-parts case as "Filter: "', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const FilterStatusChip(filterParts: [], selectedCount: 0),
      ),
    );
    expect(find.text('Filter: '), findsOneWidget);
    expect(find.text('0 valda'), findsOneWidget);
  });

  testWidgets('uses the Icons.tune leading icon', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const FilterStatusChip(filterParts: ['x'], selectedCount: 1),
      ),
    );
    expect(find.byIcon(Icons.tune), findsOneWidget);
  });

  testWidgets('container takes full width (double.infinity)', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const FilterStatusChip(filterParts: ['x'], selectedCount: 1),
      ),
    );
    final container = tester.widget<Container>(
      find.byType(Container).first,
    );
    expect(container.constraints?.maxWidth, double.infinity);
  });

  testWidgets('decoration uses rounded border + secondary-container tint', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const FilterStatusChip(filterParts: ['x'], selectedCount: 1),
      ),
    );
    final container = tester.widget<Container>(
      find.byType(Container).first,
    );
    final deco = container.decoration! as BoxDecoration;
    expect(deco.borderRadius, isNotNull);
    expect(deco.border, isA<Border>());
    expect(deco.color, isNotNull);
  });

  testWidgets('count text styled with the primary color', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const FilterStatusChip(filterParts: ['x'], selectedCount: 3),
      ),
    );
    final countText = tester.widget<Text>(find.text('3 valda'));
    expect(countText.style, isNotNull);
    expect(countText.style!.color, isNotNull);
  });

  testWidgets('long filter text expands but does not overflow', (tester) async {
    final manyParts = List.generate(20, (i) => 'Tag$i');
    await tester.pumpWidget(
      _wrap(
        FilterStatusChip(filterParts: manyParts, selectedCount: 20),
      ),
    );
    // No render exceptions.
    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.tune), findsOneWidget);
  });
}
