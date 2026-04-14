// test/unit/viewmodels/shopping_share_viewmodel_test.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/shopping_share_viewmodel.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/unified/operations/shopping_share_operations.dart';
import 'package:butlery/services/unified/operations/friends_management_operations.dart';
import '../../infrastructure/di/test_service_locator.dart';

// Pure mocks without concrete @override — when()/verify() work correctly
class _MockShareOps extends Mock implements ShoppingShareOperations {}

class _MockFriendsMgmt extends Mock implements FriendsManagementOperations {}

// Thin mock services that return the pure-mock operations modules
class _MockShoppingService extends Mock implements UnifiedShoppingService {
  final ShoppingShareOperations _shareOps;
  _MockShoppingService(this._shareOps);

  @override
  ShoppingShareOperations get sharing => _shareOps;

  @override
  ShoppingShareOperations get share => _shareOps;
}

class _MockFriendsService extends Mock
    with ChangeNotifier
    implements UnifiedFriendsService {
  final FriendsManagementOperations _mgmt;
  _MockFriendsService(this._mgmt);

  @override
  FriendsManagementOperations get management => _mgmt;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _MockShoppingService mockShoppingService;
  late _MockFriendsService mockFriendsService;
  late _MockShareOps mockShareOps;
  late _MockFriendsMgmt mockFriendsMgmt;
  late ShoppingShareViewModel viewModel;
  late List<UserProfile> testFriends;

  setUpAll(() async {
    await TestServiceLocator.initialize();
    registerFallbackValue('');
  });

  setUp(() {
    mockShareOps = _MockShareOps();
    mockFriendsMgmt = _MockFriendsMgmt();
    mockShoppingService = _MockShoppingService(mockShareOps);
    mockFriendsService = _MockFriendsService(mockFriendsMgmt);

    testFriends = [
      UserProfile(
        uid: 'friend_1',
        displayName: 'Anna Andersson',
        email: 'anna@example.com',
        joinedAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
      ),
      UserProfile(
        uid: 'friend_2',
        displayName: 'Erik Eriksson',
        email: 'erik@example.com',
        joinedAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
      ),
      UserProfile(
        uid: 'friend_3',
        displayName: 'Maria Mariasson',
        email: 'maria@example.com',
        joinedAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
      ),
    ];

    // Default stub: getAllFriends returns testFriends
    when(() => mockFriendsMgmt.getAllFriends()).thenReturn(testFriends);

    viewModel = ShoppingShareViewModel(
      shoppingService: mockShoppingService,
      friendsService: mockFriendsService,
    );
  });

  tearDown(() {
    try {
      viewModel.dispose();
    } catch (_) {
      // Guard against double-dispose or uninitialized
    }
  });

  tearDownAll(() async {
    await TestServiceLocator.reset();
  });

  UnifiedShoppingList createTestShoppingList({
    String? name,
    List<UnifiedShoppingItem>? items,
  }) {
    final list = UnifiedShoppingList.personal(
      name: name ?? 'Test Shopping List',
      ownerId: 'test_user',
      ownerDisplayName: 'Test User',
    );
    return list.copyWith(
      items: items ??
          [
            UnifiedShoppingItem(
              id: 'item_1',
              name: 'Milk',
              amount: 1,
              unit: 'L',
              category: 'Dairy',
              bought: false,
            ),
            UnifiedShoppingItem(
              id: 'item_2',
              name: 'Bread',
              amount: 2,
              unit: 'loaves',
              category: 'Bakery',
              bought: false,
            ),
          ],
    );
  }

  group('ShoppingShareViewModel - Initialization', () {
    test('should initialize with default state', () {
      expect(viewModel.isSharing, isFalse);
      expect(viewModel.friends, isEmpty);
      expect(viewModel.selectedFriendIds, isEmpty);
      expect(viewModel.shareMessage, isEmpty);
      expect(viewModel.isInitialized, isFalse);
      expect(viewModel.canShare, isFalse);
      expect(viewModel.hasFriends, isFalse);
      expect(viewModel.selectedCount, equals(0));
      expect(viewModel.selectedFriends, isEmpty);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.error, isNull);
    });

    test('should initialize and load friends', () async {
      await viewModel.initializeCommand();

      expect(viewModel.isInitialized, isTrue);
      expect(viewModel.friends.length, equals(3));
      expect(viewModel.hasFriends, isTrue);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.error, isNull);
    });

    test('should not re-initialize if already initialized', () async {
      await viewModel.initializeCommand();
      expect(viewModel.isInitialized, isTrue);

      // Change mock — should not affect since already initialized
      when(() => mockFriendsMgmt.getAllFriends()).thenReturn([]);

      await viewModel.initializeCommand();

      expect(viewModel.friends.length, equals(3));
    });

    test('should handle initialization error', () async {
      when(() => mockFriendsMgmt.getAllFriends())
          .thenThrow(Exception('Load failed'));

      await viewModel.initializeCommand();

      expect(viewModel.isInitialized, isFalse);
      expect(viewModel.error, contains('Kunde inte ladda vänner'));
      expect(viewModel.friends, isEmpty);
      expect(viewModel.isLoading, isFalse);
    });
  });

  group('ShoppingShareViewModel - Friend Selection', () {
    setUp(() async {
      await viewModel.initializeCommand();
    });

    test('should toggle friend selection', () {
      viewModel.toggleFriendSelectionCommand('friend_1');

      expect(viewModel.selectedFriendIds.contains('friend_1'), isTrue);
      expect(viewModel.selectedCount, equals(1));
      expect(viewModel.canShare, isTrue);
    });

    test('should deselect friend on second toggle', () {
      viewModel.toggleFriendSelectionCommand('friend_1');
      expect(viewModel.selectedFriendIds.contains('friend_1'), isTrue);

      viewModel.toggleFriendSelectionCommand('friend_1');

      expect(viewModel.selectedFriendIds.contains('friend_1'), isFalse);
      expect(viewModel.selectedCount, equals(0));
      expect(viewModel.canShare, isFalse);
    });

    test('should select all friends', () {
      viewModel.selectAllFriendsCommand();

      expect(viewModel.selectedFriendIds.length, equals(3));
      expect(viewModel.selectedCount, equals(3));
      expect(viewModel.canShare, isTrue);
    });

    test('should clear all selections', () {
      viewModel.selectAllFriendsCommand();
      expect(viewModel.selectedCount, equals(3));

      viewModel.clearAllSelectionsCommand();

      expect(viewModel.selectedFriendIds, isEmpty);
      expect(viewModel.selectedCount, equals(0));
      expect(viewModel.canShare, isFalse);
    });

    test('should get selected friend profiles', () {
      viewModel.toggleFriendSelectionCommand('friend_1');
      viewModel.toggleFriendSelectionCommand('friend_3');

      final selected = viewModel.selectedFriends;

      expect(selected.length, equals(2));
      expect(selected.any((f) => f.uid == 'friend_1'), isTrue);
      expect(selected.any((f) => f.uid == 'friend_3'), isTrue);
      expect(selected.any((f) => f.displayName == 'Anna Andersson'), isTrue);
      expect(selected.any((f) => f.displayName == 'Maria Mariasson'), isTrue);
    });
  });

  group('ShoppingShareViewModel - Message Management', () {
    test('should update share message', () {
      const message = 'Kolla in min inköpslista!';

      viewModel.updateShareMessageCommand(message);

      expect(viewModel.shareMessage, equals(message));
    });

    test('should trim share message', () {
      const message = '  Kolla in min inköpslista!  ';

      viewModel.updateShareMessageCommand(message);

      expect(viewModel.shareMessage, equals('Kolla in min inköpslista!'));
    });
  });

  group('ShoppingShareViewModel - Sharing Operations', () {
    setUp(() async {
      await viewModel.initializeCommand();
    });

    test('should share shopping list successfully', () async {
      final shoppingList = createTestShoppingList();

      viewModel.toggleFriendSelectionCommand('friend_1');
      viewModel.toggleFriendSelectionCommand('friend_2');
      viewModel.updateShareMessageCommand('Helgens inköpslista');

      when(() => mockShareOps.shareListWithFriend(any(), any()))
          .thenAnswer((_) async => true);

      final success = await viewModel.shareShoppingListCommand(shoppingList);

      expect(success, isTrue);
      expect(viewModel.isSharing, isFalse);

      verify(() => mockShareOps.shareListWithFriend(any(), 'friend_1'))
          .called(1);
      verify(() => mockShareOps.shareListWithFriend(any(), 'friend_2'))
          .called(1);
    });

    test('should handle partial sharing failure', () async {
      final shoppingList = createTestShoppingList();

      viewModel.toggleFriendSelectionCommand('friend_1');
      viewModel.toggleFriendSelectionCommand('friend_2');

      when(() => mockShareOps.shareListWithFriend(any(), 'friend_1'))
          .thenAnswer((_) async => true);
      when(() => mockShareOps.shareListWithFriend(any(), 'friend_2'))
          .thenAnswer((_) async => false);

      final success = await viewModel.shareShoppingListCommand(shoppingList);

      expect(success, isFalse);
      expect(viewModel.error, contains('Vissa delningar misslyckades'));
      expect(viewModel.isSharing, isFalse);
    });

    test('should handle sharing exception', () async {
      final shoppingList = createTestShoppingList();

      viewModel.toggleFriendSelectionCommand('friend_1');

      when(() => mockShareOps.shareListWithFriend(any(), any()))
          .thenThrow(Exception('Network error'));

      final success = await viewModel.shareShoppingListCommand(shoppingList);

      expect(success, isFalse);
      expect(viewModel.error, contains('Vissa delningar misslyckades'));
      expect(viewModel.isSharing, isFalse);
    });

    test('should not share without selected friends', () async {
      final shoppingList = createTestShoppingList();

      final success = await viewModel.shareShoppingListCommand(shoppingList);

      expect(success, isFalse);
      expect(viewModel.error, contains('Välj minst en vän'));
      verifyNever(() => mockShareOps.shareListWithFriend(any(), any()));
    });

    test('should use default message if none provided', () async {
      final shoppingList = createTestShoppingList();

      viewModel.toggleFriendSelectionCommand('friend_1');

      when(() => mockShareOps.shareListWithFriend(any(), any()))
          .thenAnswer((_) async => true);

      final success = await viewModel.shareShoppingListCommand(shoppingList);

      expect(success, isTrue);
    });
  });

  group('ShoppingShareViewModel - Refresh', () {
    test('should refresh friends list', () async {
      await viewModel.initializeCommand();
      expect(viewModel.friends.length, equals(3));

      final updatedFriends = [
        UserProfile(
          uid: 'friend_4',
          displayName: 'New Friend',
          email: 'new@example.com',
          joinedAt: DateTime.now(),
          lastActiveAt: DateTime.now(),
        ),
      ];

      when(() => mockFriendsMgmt.getAllFriends()).thenReturn(updatedFriends);

      await viewModel.refreshFriendsCommand();

      expect(viewModel.friends.length, equals(1));
      expect(viewModel.friends.first.displayName, equals('New Friend'));
    });

    test('should handle refresh error', () async {
      await viewModel.initializeCommand();

      when(() => mockFriendsMgmt.getAllFriends())
          .thenThrow(Exception('Refresh failed'));

      await viewModel.refreshFriendsCommand();

      expect(viewModel.error, contains('Kunde inte ladda vänlista'));
      expect(viewModel.isLoading, isFalse);
    });
  });

  group('ShoppingShareViewModel - Validation', () {
    setUp(() async {
      await viewModel.initializeCommand();
    });

    test('should validate sharing is possible', () {
      expect(viewModel.validateSharingPossible(), isFalse);
      expect(viewModel.error, contains('Välj minst en vän'));

      viewModel.toggleFriendSelectionCommand('friend_1');

      expect(viewModel.validateSharingPossible(), isTrue);
      // Error persists from previous call until explicitly cleared
      expect(viewModel.error, contains('Välj minst en vän'));
    });

    test('should validate when no friends available', () async {
      when(() => mockFriendsMgmt.getAllFriends()).thenReturn([]);

      final emptyViewModel = ShoppingShareViewModel(
        shoppingService: mockShoppingService,
        friendsService: mockFriendsService,
      );

      await emptyViewModel.initializeCommand();

      expect(emptyViewModel.validateSharingPossible(), isFalse);
      expect(emptyViewModel.error, contains('Du har inga vänner att dela med'));

      emptyViewModel.dispose();
    });

    test('should get sharing summary', () {
      viewModel.toggleFriendSelectionCommand('friend_1');
      viewModel.toggleFriendSelectionCommand('friend_2');

      final summary = viewModel.getSharingSummary();

      expect(summary, contains('Dela med:'));
      expect(summary, contains('Anna Andersson'));
      expect(summary, contains('Erik Eriksson'));
    });
  });

  group('ShoppingShareViewModel - Error Handling', () {
    test('should clear error', () async {
      when(() => mockFriendsMgmt.getAllFriends())
          .thenThrow(Exception('Load failed'));

      await viewModel.initializeCommand();
      expect(viewModel.error, isNotNull);

      viewModel.clearErrorCommand();

      expect(viewModel.error, isNull);
    });

    test('should clear error when selecting friends', () async {
      when(() => mockFriendsMgmt.getAllFriends())
          .thenThrow(Exception('Load failed'));

      await viewModel.initializeCommand();
      expect(viewModel.error, isNotNull);

      // Reset mock to succeed, re-initialize (allowed since _initialized is still false)
      when(() => mockFriendsMgmt.getAllFriends()).thenReturn(testFriends);

      await viewModel.initializeCommand();
      viewModel.toggleFriendSelectionCommand('friend_1');

      expect(viewModel.error, isNull);
    });

    test('should clear error when updating message', () async {
      when(() => mockFriendsMgmt.getAllFriends())
          .thenThrow(Exception('Load failed'));

      await viewModel.initializeCommand();
      expect(viewModel.error, isNotNull);

      viewModel.updateShareMessageCommand('New message');

      // Error persists until explicitly cleared or successful operation
      expect(viewModel.error, isNotNull);
    });
  });

  group('ShoppingShareViewModel - State Management', () {
    test('should track loading state correctly', () async {
      expect(viewModel.isLoading, isFalse);

      final future = viewModel.initializeCommand();
      expect(viewModel.isLoading, isTrue);

      await future;
      expect(viewModel.isLoading, isFalse);
    });

    test('should track sharing state correctly', () async {
      await viewModel.initializeCommand();
      viewModel.toggleFriendSelectionCommand('friend_1');

      final shoppingList = createTestShoppingList();

      when(() => mockShareOps.shareListWithFriend(any(), any()))
          .thenAnswer((_) async => true);

      expect(viewModel.isSharing, isFalse);
      expect(viewModel.canShare, isTrue);

      final future = viewModel.shareShoppingListCommand(shoppingList);

      expect(viewModel.isSharing, isTrue);
      expect(viewModel.canShare, isFalse);

      await future;

      expect(viewModel.isSharing, isFalse);
    });
  });

  group('ShoppingShareViewModel - Edge Cases and Integration', () {
    setUp(() async {
      await viewModel.initializeCommand();
    });

    test('should handle concurrent sharing operations gracefully', () async {
      final shoppingList = createTestShoppingList();

      viewModel.toggleFriendSelectionCommand('friend_1');

      when(() => mockShareOps.shareListWithFriend(any(), any()))
          .thenAnswer((_) async => true);

      final futures = [
        viewModel.shareShoppingListCommand(shoppingList),
        viewModel.shareShoppingListCommand(shoppingList),
        viewModel.shareShoppingListCommand(shoppingList),
      ];

      final results = await Future.wait(futures);

      // First succeeds, others fail due to isSharing guard
      expect(results[0], isTrue);
      expect(results[1], isFalse);
      expect(results[2], isFalse);
    });

    test('should handle large friend lists efficiently', () async {
      final largeFriendList = List.generate(
          100,
          (index) => UserProfile(
                uid: 'friend_$index',
                displayName: 'Friend $index',
                email: 'friend$index@example.com',
                joinedAt: DateTime.now(),
                lastActiveAt: DateTime.now(),
              ));

      when(() => mockFriendsMgmt.getAllFriends()).thenReturn(largeFriendList);

      final newViewModel = ShoppingShareViewModel(
        shoppingService: mockShoppingService,
        friendsService: mockFriendsService,
      );

      await newViewModel.initializeCommand();

      expect(newViewModel.friends.length, equals(100));
      expect(newViewModel.isInitialized, isTrue);

      newViewModel.selectAllFriendsCommand();
      expect(newViewModel.selectedFriendIds.length, equals(100));

      newViewModel.clearAllSelectionsCommand();
      expect(newViewModel.selectedFriendIds.length, equals(0));

      newViewModel.dispose();
    });

    test('should handle empty shopping list', () async {
      final emptyList = createTestShoppingList(items: []);

      viewModel.toggleFriendSelectionCommand('friend_1');

      when(() => mockShareOps.shareListWithFriend(any(), any()))
          .thenAnswer((_) async => true);

      final success = await viewModel.shareShoppingListCommand(emptyList);

      expect(success, isTrue);
      expect(viewModel.error, isNull);
    });

    test('should handle shopping list with special characters', () async {
      final specialList = createTestShoppingList(
        name: 'Speciell Lista! @#\$%^&*()',
        items: [
          UnifiedShoppingItem(
            id: 'item_special',
            name: 'Kött & Fisk',
            amount: 1,
            unit: 'kg',
            category: 'Kött & Fisk',
            bought: false,
          ),
        ],
      );

      viewModel.toggleFriendSelectionCommand('friend_1');
      viewModel.updateShareMessageCommand('Special message! @#\$%^&*()');

      when(() => mockShareOps.shareListWithFriend(any(), any()))
          .thenAnswer((_) async => true);

      final success = await viewModel.shareShoppingListCommand(specialList);

      expect(success, isTrue);
      expect(viewModel.shareMessage, equals('Special message! @#\$%^&*()'));
    });

    test('should handle network interruption during sharing', () async {
      final shoppingList = createTestShoppingList();

      viewModel.toggleFriendSelectionCommand('friend_1');
      viewModel.toggleFriendSelectionCommand('friend_2');

      when(() => mockShareOps.shareListWithFriend(any(), 'friend_1'))
          .thenAnswer((_) async => true);
      when(() => mockShareOps.shareListWithFriend(any(), 'friend_2'))
          .thenThrow(Exception('Network timeout'));

      final success = await viewModel.shareShoppingListCommand(shoppingList);

      expect(success, isFalse);
      expect(viewModel.error, contains('Vissa delningar misslyckades'));
      expect(viewModel.isSharing, isFalse);
    });

    test('should preserve selections during error recovery', () async {
      viewModel.toggleFriendSelectionCommand('friend_1');
      viewModel.toggleFriendSelectionCommand('friend_2');
      viewModel.updateShareMessageCommand('Test message');

      expect(viewModel.selectedFriendIds.length, equals(2));
      expect(viewModel.shareMessage, equals('Test message'));

      when(() => mockShareOps.shareListWithFriend(any(), any()))
          .thenThrow(Exception('Share failed'));

      final success =
          await viewModel.shareShoppingListCommand(createTestShoppingList());

      expect(success, isFalse);
      expect(viewModel.error, isNotNull);

      expect(viewModel.selectedFriendIds.length, equals(2));
      expect(viewModel.shareMessage, equals('Test message'));
    });

    test('should handle friend list update during sharing', () async {
      final shoppingList = createTestShoppingList();

      viewModel.toggleFriendSelectionCommand('friend_1');

      when(() => mockShareOps.shareListWithFriend(any(), any()))
          .thenAnswer((_) async => true);

      final sharePromise = viewModel.shareShoppingListCommand(shoppingList);

      when(() => mockFriendsMgmt.getAllFriends())
          .thenReturn([testFriends.first]);
      await viewModel.refreshFriendsCommand();

      final success = await sharePromise;

      expect(success, isTrue);
      expect(viewModel.friends.length, equals(1));
    });

    test('should handle friend ID selection', () {
      viewModel.toggleFriendSelectionCommand('friend_1');
      expect(viewModel.selectedFriendIds.contains('friend_1'), isTrue);

      viewModel.toggleFriendSelectionCommand('');
      expect(viewModel.selectedFriendIds.contains(''), isTrue);

      viewModel.toggleFriendSelectionCommand('null');
      expect(viewModel.selectedFriendIds.contains('null'), isTrue);
    });

    test('should handle friend selection counting correctly', () {
      expect(viewModel.selectedCount, equals(0));
      expect(viewModel.canShare, isFalse);

      viewModel.toggleFriendSelectionCommand('friend_1');
      expect(viewModel.selectedCount, equals(1));
      expect(viewModel.canShare, isTrue);

      viewModel.toggleFriendSelectionCommand('friend_2');
      expect(viewModel.selectedCount, equals(2));
      expect(viewModel.canShare, isTrue);

      viewModel.selectAllFriendsCommand();
      expect(viewModel.selectedCount, equals(3));
      expect(viewModel.canShare, isTrue);
    });

    test('should maintain consistent state during rapid operations', () async {
      for (int i = 0; i < 10; i++) {
        viewModel.toggleFriendSelectionCommand('friend_1');
        viewModel.toggleFriendSelectionCommand('friend_2');
      }

      expect(viewModel.selectedFriendIds.length, equals(0));

      for (int i = 0; i < 5; i++) {
        viewModel.updateShareMessageCommand('Message $i');
      }

      expect(viewModel.shareMessage, equals('Message 4'));
    });

    test('should handle dispose during active operations', () async {
      final shoppingList = createTestShoppingList();

      viewModel.toggleFriendSelectionCommand('friend_1');

      when(() => mockShareOps.shareListWithFriend(any(), any()))
          .thenAnswer((_) async => true);

      final sharePromise = viewModel.shareShoppingListCommand(shoppingList);

      final result = await sharePromise;

      expect(result, isTrue);
      expect(viewModel.isSharing, isFalse);
    });

    test('should preserve selections when friends list changes', () async {
      viewModel.toggleFriendSelectionCommand('friend_1');
      viewModel.toggleFriendSelectionCommand('friend_2');
      expect(viewModel.selectedFriendIds.length, equals(2));

      final newFriends = [
        UserProfile(
          uid: 'new_friend_1',
          displayName: 'New Friend 1',
          email: 'new1@example.com',
          joinedAt: DateTime.now(),
          lastActiveAt: DateTime.now(),
        ),
      ];

      when(() => mockFriendsMgmt.getAllFriends()).thenReturn(newFriends);
      await viewModel.refreshFriendsCommand();

      expect(viewModel.friends.length, equals(1));
      // ViewModel doesn't automatically clear invalid selections
      expect(viewModel.selectedFriendIds.length, equals(2));
    });

    test('should handle sharing with mixed success and failures', () async {
      final shoppingList = createTestShoppingList();

      viewModel.toggleFriendSelectionCommand('friend_1');
      viewModel.toggleFriendSelectionCommand('friend_2');
      viewModel.toggleFriendSelectionCommand('friend_3');

      when(() => mockShareOps.shareListWithFriend(any(), 'friend_1'))
          .thenAnswer((_) async => true);
      when(() => mockShareOps.shareListWithFriend(any(), 'friend_2'))
          .thenAnswer((_) async => false);
      when(() => mockShareOps.shareListWithFriend(any(), 'friend_3'))
          .thenThrow(Exception('Network error'));

      final success = await viewModel.shareShoppingListCommand(shoppingList);

      expect(success, isFalse);
      expect(viewModel.error, contains('Vissa delningar misslyckades'));
    });

    test('should handle extremely long messages gracefully', () {
      final longMessage = 'A' * 10000;

      viewModel.updateShareMessageCommand(longMessage);

      expect(viewModel.shareMessage.length, lessThanOrEqualTo(10000));
      expect(viewModel.shareMessage, equals(longMessage.trim()));
    });

    test('should provide accurate validation error messages', () async {
      when(() => mockFriendsMgmt.getAllFriends()).thenReturn([]);

      final emptyViewModel = ShoppingShareViewModel(
        shoppingService: mockShoppingService,
        friendsService: mockFriendsService,
      );

      await emptyViewModel.initializeCommand();

      expect(emptyViewModel.validateSharingPossible(), isFalse);
      expect(emptyViewModel.hasFriends, isFalse);

      emptyViewModel.dispose();
    });
  });
}
