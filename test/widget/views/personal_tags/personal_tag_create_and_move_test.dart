/// "Skapa ny grupp" in a tag's move sheet creates the group and moves the tag.
/// A move that fails keeps the dialog open, and the retry must find the group
/// the first attempt created instead of creating a second one.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/models/tagging/personal_tag_group.dart';
import 'package:butlery/viewmodels/personal_tag_viewmodel.dart';
import 'package:butlery/views/personal_tags/personal_tag_dialogs.dart';
import 'package:butlery/views/personal_tags/personal_tag_name_dialog.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';
import '../recipe/fake_personal_tag_viewmodel.dart';

class _GroupingViewModel extends FakePersonalTagViewModel {
  _GroupingViewModel(this.moveResults);

  final List<bool> moveResults;
  final createdNames = <String>[];
  final moved = <(String, String?)>[];

  @override
  Future<bool> createGroup({required String name, String? emoji}) async {
    createdNames.add(name);
    setState(
      tags: tags,
      groups: [
        ...groups,
        PersonalTagGroup.create(name: name),
      ],
    );
    return true;
  }

  @override
  Future<bool> moveTagToGroup(String tagId, String? groupId) async {
    moved.add((tagId, groupId));
    return moveResults.removeAt(0);
  }
}

void main() {
  final sv = AppLocalizationsSv();
  final tag = PersonalTag.create(name: 'Snabbt');

  Future<void> openNameDialog(
    WidgetTester tester,
    _GroupingViewModel vm,
  ) async {
    vm.setState(tags: [tag], groups: const []);
    await tester.pumpWidget(
      ChangeNotifierProvider<PersonalTagViewModel>.value(
        value: vm,
        child: createLocalizedTestApp(
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  PersonalTagDialogs.showMoveTagToGroupDialog(context, tag),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(sv.personalTagCreateNewGroup));
    await tester.pumpAndSettle();
  }

  Future<void> submit(WidgetTester tester, String name) async {
    await tester.enterText(find.byType(TextField), name);
    await tester.tap(
      find.descendant(
        of: find.byType(PersonalTagNameDialog),
        matching: find.text(sv.commonCreate),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('creates the group once and moves the tag into it', (
    tester,
  ) async {
    final vm = _GroupingViewModel([true]);
    await openNameDialog(tester, vm);
    await submit(tester, 'Middagar');

    expect(vm.createdNames, ['Middagar']);
    expect(vm.moved.single.$1, tag.id);
    expect(vm.moved.single.$2, vm.groups.single.id);
    expect(find.byType(PersonalTagNameDialog), findsNothing);
    expect(
      find.textContaining(sv.personalTagGroupCreatedAndTagMoved),
      findsOneWidget,
    );
  });

  testWidgets('a failed move keeps the dialog, and the retry reuses the group '
      'the first attempt created', (tester) async {
    final vm = _GroupingViewModel([false, true]);
    await openNameDialog(tester, vm);

    await submit(tester, 'Middagar');
    expect(find.byType(PersonalTagNameDialog), findsOneWidget);
    expect(find.text(sv.personalTagCouldNotMove), findsOneWidget);
    expect(
      find.textContaining(sv.personalTagGroupCreatedAndTagMoved),
      findsNothing,
    );

    await submit(tester, 'Middagar');

    expect(vm.createdNames, ['Middagar']);
    expect(vm.moved, hasLength(2));
    expect(vm.moved.last.$2, vm.groups.single.id);
    expect(find.byType(PersonalTagNameDialog), findsNothing);
    expect(
      find.textContaining(sv.personalTagGroupCreatedAndTagMoved),
      findsOneWidget,
    );
  });
}
