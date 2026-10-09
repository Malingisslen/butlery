import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/shared_shopping_list.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/repositories/firebase/firebase_shared_shopping_repository.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/utils/social_content_features.dart';

import '../../infrastructure/mocks/production_mocks.dart';

class _MockSharedShoppingRepository extends Mock
    implements FirebaseSharedShoppingRepository {}

class _FakeSharedShoppingList extends Fake implements SharedShoppingList {}

/// Resolves only the two services the invitation path asks the locator for.
class _Container extends Mock implements DIContainer {
  _Container(this.userService, this.repository);

  final UserService userService;
  final FirebaseSharedShoppingRepository repository;

  @override
  T get<T extends Object>() {
    if (T == UserService) return userService as T;
    if (T == FirebaseSharedShoppingRepository) return repository as T;
    throw StateError('not registered: $T');
  }

  @override
  bool isRegistered<T extends Object>() =>
      T == UserService || T == FirebaseSharedShoppingRepository;

  @override
  bool get isInitialized => true;
}

void main() {
  late MockUnifiedShoppingService shopping;
  late _MockSharedShoppingRepository repository;

  setUpAll(() => registerFallbackValue(_FakeSharedShoppingList()));

  setUp(() {
    shopping = MockUnifiedShoppingService();
    repository = _MockSharedShoppingRepository();
    final userService = MockUserService();
    when(() => userService.currentUserProfile).thenReturn(
      UserProfile(
        uid: 'me',
        displayName: 'Anna',
        email: 'a@example.com',
        joinedAt: DateTime(2026, 1, 1),
        lastActiveAt: DateTime(2026, 1, 1),
      ),
    );
    when(
      () => repository.createSharedShoppingList(
        any(),
        recipientIds: any(named: 'recipientIds'),
        groupIds: any(named: 'groupIds'),
      ),
    ).thenAnswer((_) async => 'shared-1');
    ServiceLocator.reset();
    ServiceLocator.initialize(_Container(userService, repository));
  });

  tearDown(ServiceLocator.reset);

  Future<SharedShoppingList> shareAndCapture(UnifiedShoppingList list) async {
    shopping.setShoppingState(lists: [list], currentUserId: 'me');
    final ok = await SocialContentFeatures.shareContentWithFriends(
      list.id,
      'shopping_list',
      const ['friend-1'],
      'hej',
      shopping,
    );
    expect(ok, isTrue);
    return verify(
          () => repository.createSharedShoppingList(
            captureAny(),
            recipientIds: ['friend-1'],
            groupIds: null,
          ),
        ).captured.single
        as SharedShoppingList;
  }

  UnifiedShoppingList listWith(int itemCount) => UnifiedShoppingList(
    id: 'l1',
    name: 'Helgshandling',
    ownerId: 'me',
    ownerDisplayName: 'Anna',
    items: [
      for (var i = 0; i < itemCount; i++)
        UnifiedShoppingItem(name: 'vara $i', amount: 1),
    ],
  );

  group('shareContentWithFriends shopping_list invitation', () {
    test('stamps itemCount from the list items (BUT-2095)', () async {
      final shared = await shareAndCapture(listWith(3));

      expect(shared.itemCount, 3);
    });

    test('stamps itemCount 0 for an empty list', () async {
      final shared = await shareAndCapture(listWith(0));

      expect(shared.itemCount, 0);
    });
  });
}
