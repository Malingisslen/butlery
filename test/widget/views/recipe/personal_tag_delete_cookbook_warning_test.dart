/// BUT-1325: deleting a tag that is a cookbook also deletes the book's cover,
/// description, order and notes, so both delete confirmations must say so, and
/// must stay silent for ordinary tags.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:butlery/models/tagging/cookbook_details.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/viewmodels/personal_tag_viewmodel.dart';
import 'package:butlery/viewmodels/personal_tags/personal_tag_selection_manager.dart';
import 'package:butlery/views/personal_tags/personal_tag_dialogs.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';
import '../../../test_support/cookbook_fixtures.dart';
import 'fake_personal_tag_viewmodel.dart';

void main() {
  final plain = PersonalTag.create(name: 'Vardag');
  final book = cookbookTag(
    id: 'book',
    name: 'Jul hos mormor',
    cookbook: const CookbookDetails(),
  );
  const warning =
      'Taggen är en kokbok, så kokbokens omslag, beskrivning, ordning och '
      'texter försvinner också.';

  Future<void> open(
    WidgetTester tester,
    Future<void> Function(BuildContext) show,
  ) async {
    final vm = FakePersonalTagViewModel()
      ..setState(tags: [plain, book], usageCounts: const {});
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PersonalTagViewModel>.value(value: vm),
          ChangeNotifierProvider<PersonalTagSelectionManager>(
            create: (_) => PersonalTagSelectionManager(),
          ),
        ],
        child: createLocalizedTestApp(
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () => show(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('single delete', () {
    testWidgets('a cookbook tag adds the warning', (tester) async {
      await open(
        tester,
        (c) => PersonalTagDialogs.showDeleteTagDialog(c, book),
      );
      expect(find.textContaining(warning), findsOneWidget);
    });

    testWidgets('an ordinary tag does not', (tester) async {
      await open(
        tester,
        (c) => PersonalTagDialogs.showDeleteTagDialog(c, plain),
      );
      expect(find.textContaining('Är du säker'), findsOneWidget);
      expect(find.textContaining('kokbok'), findsNothing);
    });
  });

  group('bulk delete', () {
    testWidgets('one cookbook among the selected adds the warning', (
      tester,
    ) async {
      await open(
        tester,
        (c) => PersonalTagDialogs.showBulkDeleteDialog(c, [plain, book]),
      );
      expect(find.textContaining(warning), findsOneWidget);
    });

    testWidgets('only ordinary tags selected: no warning', (tester) async {
      await open(
        tester,
        (c) => PersonalTagDialogs.showBulkDeleteDialog(c, [plain]),
      );
      expect(find.textContaining('Taggen tas bort'), findsOneWidget);
      expect(find.textContaining('kokbok'), findsNothing);
    });
  });
}
