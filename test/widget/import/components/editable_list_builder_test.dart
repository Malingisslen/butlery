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
