/// The calm line at the top of a shopping list the week menu changed: what it
/// says, when it appears (only while the list is on screen), and what Ångra
/// and × do.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/services/shopping/menu_shopping_list_generator.dart';
import 'package:butlery/viewmodels/week_list_follow_notice_manager.dart';
import 'package:butlery/views/unified_shopping/widgets/week_list_follow_notice_bar.dart';
import 'package:butlery/widgets/common/layout/main_tab_shown.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

class _MockGenerator extends Mock implements MenuShoppingListGenerator {}

class _FakeNotice extends Fake implements WeekListFollowNotice {}

UnifiedShoppingItem _row(String id) =>
    UnifiedShoppingItem(id: id, name: 'vara $id', amount: 1);

WeekListFollowNotice _notice({
  String listId = 'list-1',
  int added = 3,
  int removed = 1,
  int changed = 0,
}) => WeekListFollowNotice(
  listId: listId,
  addedIds: [for (var i = 0; i < added; i++) 'a$i'],
  removed: [for (var i = 0; i < removed; i++) _row('r$i')],
  changed: [for (var i = 0; i < changed; i++) _row('c$i')],
  updatedAt: DateTime(2026, 10, 31),
);

void main() {
  late _MockGenerator generator;
  late WeekListFollowNoticeManager manager;

  setUpAll(() => registerFallbackValue(_FakeNotice()));

  setUp(() {
    generator = _MockGenerator();
    manager = WeekListFollowNoticeManager(generator: generator);
  });

  tearDown(() => manager.dispose());

  void stubTake(String listId, WeekListFollowNotice? notice) => when(
    () => generator.takeFollowNotice(listId),
  ).thenAnswer((_) async => notice);

  Widget host({
    String? listId = 'list-1',
    bool shown = true,
    bool canUndo = true,
  }) => createLocalizedTestApp(
    child: MainTabShown(
      shown: shown,
      child: WeekListFollowNoticeBar(
        listId: listId,
        canUndo: canUndo,
        manager: manager,
      ),
    ),
  );

  final undoButton = find.byKey(
    const ValueKey('unifiedShopping.weekListFollowNotice.undo'),
  );
  final noticeRow = find.byKey(
    const ValueKey('unifiedShopping.weekListFollowNotice'),
  );

  testWidgets('says what the week menu did to the list', (tester) async {
    stubTake('list-1', _notice(added: 3, removed: 1));

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(
      find.text('Uppdaterad från veckomenyn: 3 nya, 1 borttagen'),
      findsOneWidget,
    );
  });

  testWidgets('names changed rows too', (tester) async {
    stubTake('list-1', _notice(added: 0, removed: 0, changed: 1));

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('Uppdaterad från veckomenyn: 1 ändrad'), findsOneWidget);
  });

  testWidgets('shows nothing for a list the menu did not change', (
    tester,
  ) async {
    stubTake('list-1', null);

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(noticeRow, findsNothing);
    expect(find.textContaining('Uppdaterad från veckomenyn'), findsNothing);
  });

  testWidgets('the cross hides the notice without undoing anything', (
    tester,
  ) async {
    stubTake('list-1', _notice());
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(noticeRow, findsOneWidget);

    await tester.tap(find.byTooltip('Stäng meddelandet'));
    await tester.pumpAndSettle();

    expect(noticeRow, findsNothing);
    verifyNever(() => generator.undoFollow(any()));
  });

  testWidgets('Ångra undoes the follow and hides the notice', (tester) async {
    final notice = _notice();
    stubTake('list-1', notice);
    when(() => generator.undoFollow(any())).thenAnswer((_) async => true);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(undoButton);
    await tester.pumpAndSettle();

    verify(() => generator.undoFollow(notice)).called(1);
    expect(noticeRow, findsNothing);
    expect(find.text('Kunde inte ångra uppdateringen'), findsNothing);
  });

  testWidgets('an Ångra that could not put the list back says so', (
    tester,
  ) async {
    stubTake('list-1', _notice());
    when(() => generator.undoFollow(any())).thenAnswer((_) async => false);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(undoButton);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Kunde inte ångra uppdateringen'),
      findsOneWidget,
    );
    expect(noticeRow, findsNothing);
  });

  testWidgets('a list behind another tab takes no notice until it is shown', (
    tester,
  ) async {
    stubTake('list-1', _notice());

    await tester.pumpWidget(host(shown: false));
    await tester.pumpAndSettle();

    verifyNever(() => generator.takeFollowNotice(any()));
    expect(noticeRow, findsNothing);

    await tester.pumpWidget(host(shown: true));
    await tester.pumpAndSettle();

    verify(() => generator.takeFollowNotice('list-1')).called(1);
    expect(
      find.text('Uppdaterad från veckomenyn: 3 nya, 1 borttagen'),
      findsOneWidget,
    );
  });

  testWidgets('leaving the tab hides the notice', (tester) async {
    stubTake('list-1', _notice());
    await tester.pumpWidget(host(shown: true));
    await tester.pumpAndSettle();
    expect(noticeRow, findsOneWidget);

    await tester.pumpWidget(host(shown: false));
    await tester.pumpAndSettle();

    expect(noticeRow, findsNothing);
  });

  testWidgets('switching to another list takes that list\'s notice', (
    tester,
  ) async {
    stubTake('list-1', _notice(added: 3, removed: 1));
    stubTake('list-2', _notice(listId: 'list-2', added: 2, removed: 0));
    await tester.pumpWidget(host(listId: 'list-1'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(host(listId: 'list-2'));
    await tester.pumpAndSettle();

    verify(() => generator.takeFollowNotice('list-2')).called(1);
    expect(find.text('Uppdaterad från veckomenyn: 2 nya'), findsOneWidget);
    expect(find.textContaining('borttagen'), findsNothing);
  });

  testWidgets('a notice taken while the list is left is put back, unseen', (
    tester,
  ) async {
    final taking = Completer<WeekListFollowNotice?>();
    final notice = _notice();
    when(
      () => generator.takeFollowNotice('list-1'),
    ).thenAnswer((_) => taking.future);
    when(
      () => generator.putBackFollowNotice(any()),
    ).thenAnswer((_) async {});
    await tester.pumpWidget(host());

    await tester.pumpWidget(host(shown: false));
    taking.complete(notice);
    await tester.pumpAndSettle();

    verify(() => generator.putBackFollowNotice(notice)).called(1);
    expect(noticeRow, findsNothing);
  });

  testWidgets('without a connection the line shows without Ångra', (
    tester,
  ) async {
    stubTake('list-1', _notice());
    await tester.pumpWidget(host(canUndo: false));
    await tester.pumpAndSettle();

    expect(noticeRow, findsOneWidget);
    expect(undoButton, findsNothing);
  });

  testWidgets('switching away and back before a take ends keeps the later '
      'take\'s notice', (tester) async {
    final first = Completer<WeekListFollowNotice?>();
    final notice = _notice();
    var takes = 0;
    when(() => generator.takeFollowNotice('list-1')).thenAnswer((_) {
      takes++;
      return takes == 1 ? first.future : Future.value(notice);
    });
    stubTake('list-2', null);
    when(() => generator.putBackFollowNotice(any())).thenAnswer((_) async {});
    await tester.pumpWidget(host());
    await tester.pumpWidget(host(listId: 'list-2'));
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(noticeRow, findsOneWidget);

    first.complete(null);
    await tester.pumpAndSettle();

    expect(noticeRow, findsOneWidget);
  });

  testWidgets('a rebuild on the same list does not take the notice again', (
    tester,
  ) async {
    stubTake('list-1', _notice());
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    verify(() => generator.takeFollowNotice('list-1')).called(1);
    expect(noticeRow, findsOneWidget);
  });
}
