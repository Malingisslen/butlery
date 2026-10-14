// The import dialog's editable lists: each row edits and removes its own
// item, numbers show only where asked, and the add row adds a trimmed item.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/widgets/import/components/add_item_field.dart';
import 'package:butlery/widgets/import/components/editable_list_builder.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

void main() {
  final sv = AppLocalizationsSv();

  late List<(int, String)> updates;
  late List<int> removals;
  late List<String> added;

  setUp(() {
    updates = [];
    removals = [];
    added = [];
  });

  Widget build({bool showNumbers = false}) => createLocalizedTestApp(
    wrapInScrollView: true,
    child: EditableListBuilder(
      items: const ['2 dl grädde', '400 g tomater'],
      onUpdate: (i, v) => updates.add((i, v)),
      onRemove: removals.add,
      onAdd: added.add,
      hintText: 'Lägg till ingrediens',
      showNumbers: showNumbers,
    ),
  );

  testWidgets('each row starts with its item', (tester) async {
    await tester.pumpWidget(build());

    expect(find.text('2 dl grädde'), findsOneWidget);
    expect(find.text('400 g tomater'), findsOneWidget);
  });

  testWidgets('editing a row reports that row', (tester) async {
    await tester.pumpWidget(build());

    await tester.enterText(find.text('400 g tomater'), '500 g tomater');

    expect(updates, [(1, '500 g tomater')]);
  });

  testWidgets('a row\'s remove button removes that row', (tester) async {
    await tester.pumpWidget(build());

    await tester.tap(find.byTooltip(sv.commonDelete).at(1));

    expect(removals, [1]);
  });

  testWidgets(
    'removing the first row leaves the second item\'s text in the surviving '
    'field, and editing it reports index 0',
    (tester) async {
      final items = ['2 dl grädde', '400 g tomater'];
      await tester.pumpWidget(
        createLocalizedTestApp(
          wrapInScrollView: true,
          child: StatefulBuilder(
            builder: (context, setState) => EditableListBuilder(
              items: items,
              onUpdate: (i, v) => updates.add((i, v)),
              onRemove: (i) => setState(() => items.removeAt(i)),
              onAdd: added.add,
              hintText: 'Lägg till ingrediens',
            ),
          ),
        ),
      );

      await tester.tap(find.byTooltip(sv.commonDelete).first);
      await tester.pump();

      final fields = find.byType(EditableText);
      expect(fields, findsNWidgets(2)); // surviving row + the add field
      expect(
        tester.widget<EditableText>(fields.first).controller.text,
        '400 g tomater',
      );
      expect(find.text('2 dl grädde'), findsNothing);

      await tester.enterText(fields.first, '500 g tomater');
      expect(updates, [(0, '500 g tomater')]);
    },
  );

  testWidgets('numbers show only when asked', (tester) async {
    await tester.pumpWidget(build());
    expect(find.text('1.'), findsNothing);

    await tester.pumpWidget(build(showNumbers: true));
    expect(find.text('1.'), findsOneWidget);
    expect(find.text('2.'), findsOneWidget);
  });

  group('AddItemField', () {
    Widget field() => createLocalizedTestApp(
      child: AddItemField(hintText: 'Lägg till', onAdd: added.add),
    );

    testWidgets('the add button adds the trimmed text and clears the field', (
      tester,
    ) async {
      await tester.pumpWidget(field());

      await tester.enterText(find.byType(TextField), '  salt  ');
      await tester.tap(find.byTooltip(sv.commonAdd));
      await tester.pump();

      expect(added, ['salt']);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
    });

    testWidgets('done on the keyboard adds too', (tester) async {
      await tester.pumpWidget(field());

      await tester.enterText(find.byType(TextField), 'peppar');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(added, ['peppar']);
    });

    testWidgets('blank text adds nothing', (tester) async {
      await tester.pumpWidget(field());

      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.byTooltip(sv.commonAdd));
      await tester.pump();

      expect(added, isEmpty);
    });
  });
}
