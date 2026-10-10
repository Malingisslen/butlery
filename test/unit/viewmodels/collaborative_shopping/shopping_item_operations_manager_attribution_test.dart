/// Who a claimed / released shopping row names (BUT-2009): the profile, never
/// the Firebase Auth account the permission service synthesizes the user from.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/providers/application_provider.dart' as app;
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/viewmodels/collaborative_shopping/shopping_item_operations_manager.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

void main() {
  const me = 'user-me';
  late MockUnifiedShoppingService shopping;
  late ShoppingItemOperationsManager manager;

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    registerFallbackValue(UnifiedShoppingItem(name: 'x', amount: 1));
  });

  setUp(() async {
    await TestServiceLocator.initialize();
    app.ServiceLocator.reset();
    app.ServiceLocator.initialize(MockDIContainer());

    (TestServiceLocator.get<PermissionService>() as FakePermissionService)
        .setPermissionState(
          currentUserId: me,
          isAuthenticated: true,
          defaultHasPermission: true,
          currentUser: UserProfile(
            uid: me,
            email: 'me@example.com',
            displayName: 'Google Anna',
            joinedAt: DateTime.utc(2026),
            lastActiveAt: DateTime.utc(2026),
          ),
        );
    when(
      () => (TestServiceLocator.get<UserService>() as MockUserService)
          .attributionDisplayName,
    ).thenReturn('Profil Anna');

    shopping = MockUnifiedShoppingService();
    when(
      () => shopping.updateCollaborativeItem(any(), any()),
    ).thenAnswer((_) async => true);
    manager = ShoppingItemOperationsManager(shopping, 'list-1');
  });

  tearDown(() async {
    manager.dispose();
    await TestServiceLocator.reset();
  });

  UnifiedShoppingItem sentItem() =>
      verify(
            () => shopping.updateCollaborativeItem('list-1', captureAny()),
          ).captured.single
          as UnifiedShoppingItem;

  UnifiedShoppingList listWith(UnifiedShoppingItem item) => UnifiedShoppingList(
    id: 'list-1',
    name: 'Handla',
    ownerId: me,
    ownerDisplayName: 'Profil Anna',
    items: [item],
  );

  test('claiming a row names the PROFILE as claimer and modifier', () async {
    final item = UnifiedShoppingItem(name: 'Mjölk', amount: 1);

    final result = await manager.claimItem(
      item.id,
      listWith(item),
      true,
      () async {},
      (_, _) {},
    );

    expect(result.outcome, ClaimOutcome.claimed);
    final sent = sentItem();
    expect(sent.assignedToUserId, me);
    expect(sent.assignedToDisplayName, 'Profil Anna');
    expect(sent.lastModifiedByDisplayName, 'Profil Anna');
  });

  test('releasing a row names the PROFILE as modifier', () async {
    final held = UnifiedShoppingItem(
      name: 'Mjölk',
      amount: 1,
      assignedToUserId: me,
      assignedToDisplayName: 'Gammalt namn',
    );

    final result = await manager.unclaimItem(
      held.id,
      listWith(held),
      true,
      () async {},
      (_, _) {},
    );

    expect(result.outcome, ClaimOutcome.unclaimed);
    final sent = sentItem();
    expect(sent.assignedToUserId, isNull);
    expect(sent.lastModifiedByDisplayName, 'Profil Anna');
  });
}
