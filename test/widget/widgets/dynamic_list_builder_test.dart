import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/widgets/recipe/recipe_form/dynamic_list_builder.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

void main() {
  late TextEditingController first;
  late TextEditingController last;
  var adds = 0;

  setUp(() {
    first = TextEditingController(text: 'Hacka löken');
    last = TextEditingController();
    adds = 0;
  });

  tearDown(() {
    first.dispose();
    last.dispose();
  });

  Widget build({bool reorderable = false}) => createLocalizedTestApp(
    wrapInScrollView: true,
    child: DynamicListBuilder(
      label: 'Instruktion',
      controllers: [first, last],
      onUpdate: (_, __) {},
      onAdd: () => adds++,
      onRemove: (_) {},
      // The edit view passes onReorder, which selects the reorderable rows.
      onReorder: reorderable ? (_, __) {} : null,
    ),
  );

  for (final reorderable in [false, true]) {
    group('reorderable: $reorderable', () {
      testWidgets('a pasted whole step in the last row adds one new row', (
        tester,
      ) async {
        await tester.pumpWidget(build(reorderable: reorderable));
        await tester.enterText(
          find.byType(TextFormField).last,
          'Stek i 5 minuter',
        );
        await tester.pump();
        expect(adds, 1);
      });

      testWidgets('typing in a row that is not last adds nothing', (
        tester,
      ) async {
        await tester.pumpWidget(build(reorderable: reorderable));
        await tester.enterText(
          find.byType(TextFormField).first,
          'Stek i 5 minuter',
        );
        await tester.pump();
        expect(adds, 0);
      });

      testWidgets('whitespace only in the last row adds nothing', (
        tester,
      ) async {
        await tester.pumpWidget(build(reorderable: reorderable));
        await tester.enterText(find.byType(TextFormField).last, '   ');
        await tester.pump();
        expect(adds, 0);
      });

      testWidgets('"Lägg till instruktion" adds a row', (tester) async {
        await tester.pumpWidget(build(reorderable: reorderable));
        await tester.tap(find.text('Lägg till instruktion'));
        expect(adds, 1);
      });
    });
  }
}
