// The merge dialog on the personal-tags screen: the user keeps ONE of the
// selected tags and every other selected tag is merged into it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/viewmodels/personal_tag_viewmodel.dart';
import 'package:butlery/viewmodels/personal_tags/personal_tag_selection_manager.dart';
import 'package:butlery/views/personal_tags/personal_tag_bulk_dialogs.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

class _MockTagViewModel extends Mock implements PersonalTagViewModel {}

void main() {
  late _MockTagViewModel viewModel;
  late PersonalTagSelectionManager selection;

  final now = DateTime(2026, 10, 17);
  final tags = [
    for (final (id, name) in [('a', 'Vardag'), ('b', 'Fest'), ('c', 'Snabbt')])
      PersonalTag(id: id, name: name, createdAt: now, updatedAt: now),
  ];

  setUp(() {
    viewModel = _MockTagViewModel();
    selection = PersonalTagSelectionManager()..enterSelection('a');
    when(
      () => viewModel.mergeTagsInto(any(), any()),
    ).thenAnswer((_) async => 2);
    when(() => viewModel.loadTagStatistics()).thenAnswer((_) async {});
  });

  Future<void> openDialog(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PersonalTagViewModel>.value(value: viewModel),
          ChangeNotifierProvider<PersonalTagSelectionManager>.value(
            value: selection,
          ),
        ],
        child: createLocalizedTestApp(
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  PersonalTagBulkDialogs.showMergeDialog(context, tags),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('merges the other tags into the one the user keeps and leaves '
      'selection mode', (tester) async {
    await openDialog(tester);

    await tester.tap(find.byKey(const ValueKey('merge-keep-b')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Slå ihop'));
    await tester.pumpAndSettle();

    verify(() => viewModel.mergeTagsInto('b', ['a', 'c'])).called(1);
    expect(selection.isSelectionMode, isFalse);
    expect(find.text('Slå ihop taggar'), findsNothing);
  });

  testWidgets('keeps the first tag by default', (tester) async {
    await openDialog(tester);

    await tester.tap(find.text('Slå ihop'));
    await tester.pumpAndSettle();

    verify(() => viewModel.mergeTagsInto('a', ['b', 'c'])).called(1);
  });

  testWidgets('Avbryt closes the dialog without merging', (tester) async {
    await openDialog(tester);

    await tester.tap(find.text('Avbryt'));
    await tester.pumpAndSettle();

    verifyNever(() => viewModel.mergeTagsInto(any(), any()));
    expect(selection.isSelectionMode, isTrue);
    expect(find.text('Slå ihop taggar'), findsNothing);
  });
}
