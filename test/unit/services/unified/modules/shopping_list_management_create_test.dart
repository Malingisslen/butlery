import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/services/unified/modules/shopping_list_management_module.dart';

import '../../../../infrastructure/mocks/production_mocks.dart';

void main() {
  late MockShoppingRepository repository;
  late List<UnifiedShoppingList> lists;

  setUpAll(() {
    registerFallbackValue(
      UnifiedShoppingList(
        name: 'fallback',
        ownerId: 'x',
        ownerDisplayName: 'x',
        type: ListType.collaborative,
      ),
    );
  });

  ShoppingListManagementModule build() => ShoppingListManagementModule(
    repository: repository,
    lists: lists,
    getActiveListId: () => null,
    setActiveListId: (_) {},
    notifyListeners: () {},
    getCurrentUserId: () => 'owner-uid',
    getCurrentUserDisplayName: () => 'Malin',
    saveActiveListId: () async {},
  );

  setUp(() {
    repository = MockShoppingRepository();
    lists = [];
    when(() => repository.create(any())).thenAnswer((i) async {
      final l = i.positionalArguments[0] as UnifiedShoppingList;
      return UnifiedShoppingList(
        id: 'new',
        name: l.name,
        ownerId: l.ownerId,
        ownerDisplayName: l.ownerDisplayName,
        type: l.type,
        memberPermissions: l.memberPermissions,
      );
    });
  });

  test('seats only the owner, as admin', () async {
    final id = await build().createCollaborativeList(
      name: 'Veckohandling',
      allowGuestEditing: false,
    );

    final created =
        verify(() => repository.create(captureAny())).captured.single
            as UnifiedShoppingList;
    expect(id, 'new');
    expect(created.type, ListType.collaborative);
    expect(created.ownerId, 'owner-uid');
    expect(created.memberPermissions, {
      'owner-uid': SharedListPermission.admin,
    });
    expect(lists.single.id, 'new');
  });
}
