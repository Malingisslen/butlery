/// Deleting a tag group goes through the shared destructive dialog
/// (BUT-2366/BUT-2370): the success note comes only after the group is
/// gone, and a refused delete keeps the dialog open with its inline error.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/tagging/personal_tag_group.dart';
import 'package:butlery/viewmodels/personal_tag_viewmodel.dart';
import 'package:butlery/views/personal_tags/personal_tag_dialogs.dart';
import 'package:butlery/widgets/common/dialogs/destructive_confirmation_dialog.dart';
import 'package:butlery/widgets/common/feedback/inline_error.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';
import '../recipe/fake_personal_tag_viewmodel.dart';

class _DeletingViewModel extends FakePersonalTagViewModel {
  _DeletingViewModel(this.result);

  bool result;
  final deleted = <String>[];

  @override
  Future<bool> deleteGroup(String groupId) async {
    deleted.add(groupId);
    return result;
  }
}

void main() {
  final sv = AppLocalizationsSv();
  final group = PersonalTagGroup.create(name: 'Middagar');

  Future<void> open(WidgetTester tester, _DeletingViewModel vm) async {
    vm.setState(tags: const [], groups: [group]);
    await tester.pumpWidget(
      ChangeNotifierProvider<PersonalTagViewModel>.value(
        value: vm,
        child: createLocalizedTestApp(
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () => PersonalTagDialogs.handleGroupAction(
                context,
                'delete',
                group,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> confirm(WidgetTester tester) async {
    await tester.tap(
      find.descendant(
        of: find.byType(DestructiveConfirmationDialog),
        matching: find.text(sv.personalTagDeleteGroup),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('asks in the shared dialog, deletes, then confirms', (
    tester,
  ) async {
    final vm = _DeletingViewModel(true);
    await open(tester, vm);

    expect(find.byType(DestructiveConfirmationDialog), findsOneWidget);
    expect(find.text(sv.personalTagDeleteGroupConfirm), findsOneWidget);
    expect(
      find.text(sv.personalTagDeleteGroupMessage('Middagar')),
      findsOneWidget,
    );

    await confirm(tester);

    expect(vm.deleted, [group.id]);
    expect(find.byType(DestructiveConfirmationDialog), findsNothing);
    expect(find.textContaining(sv.personalTagGroupDeleted), findsOneWidget);
  });

  testWidgets('a refused delete stays in the dialog with its error and no '
      'success note', (tester) async {
    final vm = _DeletingViewModel(false);
    await open(tester, vm);
    await confirm(tester);

    expect(vm.deleted, [group.id]);
    expect(find.byType(DestructiveConfirmationDialog), findsOneWidget);
    expect(find.byType(InlineError), findsOneWidget);
    expect(find.textContaining(sv.personalTagGroupDeleted), findsNothing);
  });

  testWidgets('Avbryt deletes nothing', (tester) async {
    final vm = _DeletingViewModel(true);
    await open(tester, vm);
    await tester.tap(find.text(sv.commonCancel));
    await tester.pumpAndSettle();

    expect(vm.deleted, isEmpty);
    expect(find.textContaining(sv.personalTagGroupDeleted), findsNothing);
  });
}
