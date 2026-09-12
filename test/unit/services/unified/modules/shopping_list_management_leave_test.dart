// test/unit/services/unified/modules/shopping_list_management_leave_test.dart

/// BUT-1718: the ONE production line that asks for a self-removal.
///
/// `ShoppingListManagementModule.leaveList` is the only site in `lib/` that
/// passes `intent: MembershipWriteIntent.selfRemoval`, and before this file
/// nothing executed it. The widget suite mocks `CollaborativeShoppingOperations`,
/// the operations suite mocks `leaveSharedList` on the service, and the
/// repository suite hand-passes the intent — a fake sandwich with the real
/// decision in the middle. Swapping `selfRemoval` for `ordinary` there left
/// every suite green while the server would refuse every real departure.
///
/// That is verbatim the incident `ADR-002` exists to record: a membership seam
/// that shipped green with no caller reaching it. Caught by the
/// `testing-specialist` gate reading line coverage, not by any assertion.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/repositories/interfaces/shopping_repository.dart';
import 'package:butlery/services/unified/modules/shopping_list_management_module.dart';

import '../../../../infrastructure/mocks/production_mocks.dart';

UnifiedShoppingList _list({String id = 'list-1'}) => UnifiedShoppingList(
  id: id,
  name: 'Familjehandling',
  ownerId: 'owner-uid',
  ownerDisplayName: 'Malin',
  type: ListType.collaborative,
  memberPermissions: const {
    'owner-uid': SharedListPermission.admin,
    'bob': SharedListPermission.edit,
  },
);

void main() {
  late MockShoppingRepository repository;
  late List<UnifiedShoppingList> lists;
  late String? activeListId;
  late int notifyCount;

  setUpAll(() {
    registerFallbackValue(_list());
    registerFallbackValue(MembershipWriteIntent.ordinary);
  });

  ShoppingListManagementModule build() => ShoppingListManagementModule(
    repository: repository,
    lists: lists,
    getActiveListId: () => activeListId,
    setActiveListId: (id) => activeListId = id,
    notifyListeners: () => notifyCount++,
    getCurrentUserId: () => 'bob',
    getCurrentUserDisplayName: () => 'Bob',
    saveActiveListId: () async {},
  );

  setUp(() {
    repository = MockShoppingRepository();
    lists = [_list(), _list(id: 'other')];
    activeListId = 'list-1';
    notifyCount = 0;
    when(
      () => repository.updateCollaborativeListMembership(
        any(),
        any(),
        intent: any(named: 'intent'),
      ),
    ).thenAnswer((i) async => i.positionalArguments[0] as UnifiedShoppingList);
  });

  test('leaveList asks the repository for a SELF-REMOVAL', () async {
    // The assertion the whole ticket rests on. `ordinary` here compiles, passes
    // every other suite, and is refused by the client guards and by
    // `firestore.rules` for every member who is not the owner.
    await build().leaveList(_list(), _list());

    final intent =
        verify(
              () => repository.updateCollaborativeListMembership(
                any(),
                any(),
                intent: captureAny(named: 'intent'),
              ),
            ).captured.single
            as MembershipWriteIntent;
    expect(intent, MembershipWriteIntent.selfRemoval);
  });

  test('the ordinary membership write still asks for ORDINARY', () async {
    // The single-variable control: same module, same repository, the sibling
    // method. Without it, a mutant that hardcoded `selfRemoval` everywhere
    // would satisfy the case above.
    await build().updateListMembership(_list(), _list());

    final intent =
        verify(
              () => repository.updateCollaborativeListMembership(
                any(),
                any(),
                intent: captureAny(named: 'intent'),
              ),
            ).captured.single
            as MembershipWriteIntent;
    expect(intent, MembershipWriteIntent.ordinary);
  });

  test('a departure drops the list locally and clears the active id', () async {
    // The other half of the dead body: the list is gone from this user's view
    // the moment the write lands (the stream filters on
    // `memberPermissions.<uid>`), so a stale copy left in `lists` keeps a list
    // on screen whose next snapshot is a permission denial.
    await build().leaveList(_list(), _list());

    expect(lists.map((l) => l.id), ['other']);
    expect(activeListId, isNull);
    expect(notifyCount, 1);
  });

  test(
    'leaving a list that is NOT the active one leaves the active id alone',
    () async {
      // Control for the line above: without it, `setActiveListId(null)` could be
      // unconditional and every assertion here would still pass.
      activeListId = 'other';

      await build().leaveList(_list(), _list());

      expect(activeListId, 'other');
      expect(lists.map((l) => l.id), ['other']);
    },
  );

  test('a refused write rethrows and touches nothing locally', () async {
    // `updateListMembership` rethrows by contract (ADR-002) so "removed" and
    // "the list moved under you" cannot look the same on screen; `leaveList`
    // inherits that, and the service above maps it to a Swedish sentence.
    when(
      () => repository.updateCollaborativeListMembership(
        any(),
        any(),
        intent: any(named: 'intent'),
      ),
    ).thenThrow(StateError('refused'));

    await expectLater(
      () => build().leaveList(_list(), _list()),
      throwsA(isA<StateError>()),
    );
    expect(lists.map((l) => l.id), ['list-1', 'other']);
    expect(activeListId, 'list-1');
    expect(notifyCount, 0);
  });
}
