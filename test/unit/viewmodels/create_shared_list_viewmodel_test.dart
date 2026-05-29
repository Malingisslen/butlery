// test/unit/viewmodels/create_shared_list_viewmodel_test.dart

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/create_shared_list_viewmodel.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/core/di/di_container.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/factories/mock_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/di/test_service_locator.dart';

void main() {
  late MockUnifiedShoppingService mockShoppingService;
  late MockUnifiedFriendsService mockFriendsService;
  late FakePermissionService mockPermissionService;
  late CreateSharedListViewModel viewModel;
  late List<UserProfile> testFriends;

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    production.ServiceLocator.initialize(DIContainer());
  });

  setUp(() async {
    await TestServiceLocator.initialize();

    mockShoppingService = MockUnifiedShoppingService();
    mockFriendsService = MockUnifiedFriendsService();
    mockPermissionService = FakePermissionService();

    // Register mocks
    TestServiceLocator.registerMock<UnifiedShoppingService>(
        mockShoppingService);
    TestServiceLocator.registerMock<UnifiedFriendsService>(mockFriendsService);
    TestServiceLocator.registerMock<PermissionService>(mockPermissionService);

    testFriends = [
      MockFactory.createUserProfile(
        userId: 'friend_1',
        displayName: 'Anna Andersson',
        email: 'anna@example.com',
      ),
      MockFactory.createUserProfile(
        userId: 'friend_2',
        displayName: 'Erik Eriksson',
        email: 'erik@example.com',
      ),
    ];

    // Configure mock state
    mockFriendsService.setFriendsState(friends: testFriends);
    mockPermissionService.setPermissionState(
      currentUserId: 'test_user',
      isAuthenticated: true,
    );
    mockShoppingService.setShoppingState(error: null);

    viewModel = CreateSharedListViewModel(
      shoppingService: mockShoppingService,
      friendsService: mockFriendsService,
    );
  });

  tearDown(() async {
    viewModel.dispose();
    BaseUnitTest.resetMocks();
    await TestServiceLocator.reset();
  });

  Map<String, List<Recipe>> createTestMenu() {
    return {
      'Monday': [
        RecipeFactory.build(id: 'recipe_1', title: 'Monday Pasta'),
      ],
      'Tuesday': [
        RecipeFactory.build(id: 'recipe_2', title: 'Tuesday Soup'),
      ],
    };
  }

  group('CreateSharedListViewModel - Initialization', () {
    test('should initialize with default state', () {
      expect(viewModel.title, isEmpty);
      expect(viewModel.description, isEmpty);
      expect(viewModel.selectedFriendIds, isEmpty);
      expect(viewModel.menu, isNull);
      expect(viewModel.isCreating, isFalse);
      expect(viewModel.error, isNull);
      expect(viewModel.hasError, isFalse);
    });

    test('should initialize with menu and title', () {
      final menu = createTestMenu();

      viewModel.initialize(
        menu: menu,
        defaultTitle: 'Weekly Menu',
      );

      expect(viewModel.title, equals('Weekly Menu'));
      expect(viewModel.menu, equals(menu));
    });

    test('should not override empty title', () {
      viewModel.initialize(defaultTitle: '');

      expect(viewModel.title, isEmpty);
    });
  });

  group('CreateSharedListViewModel - Form Management', () {
    test('should update title', () {
      viewModel.updateTitle('My Shopping List');

      expect(viewModel.title, equals('My Shopping List'));
      expect(viewModel.trimmedTitle, equals('My Shopping List'));
      expect(viewModel.isTitleValid, isTrue);
    });

    test('should trim title', () {
      viewModel.updateTitle('  My List  ');

      expect(viewModel.title, equals('  My List  '));
      expect(viewModel.trimmedTitle, equals('My List'));
    });

    test('should update description', () {
      viewModel.updateDescription('List for weekend shopping');

      expect(viewModel.description, equals('List for weekend shopping'));
      expect(viewModel.hasDescription, isTrue);
    });

    test('should trim description', () {
      viewModel.updateDescription('  Description  ');

      expect(viewModel.description, equals('  Description  '));
      expect(viewModel.trimmedDescription, equals('Description'));
    });

    test('should update selected friends', () {
      viewModel.updateSelectedFriends(['friend_1', 'friend_2']);

      expect(viewModel.selectedFriendIds.length, equals(2));
      expect(viewModel.hasFriendsSelected, isTrue);
      expect(viewModel.selectedFriendsText, equals('2 vänner valda'));
    });

    test('should handle single friend selection text', () {
      viewModel.updateSelectedFriends(['friend_1']);

      expect(viewModel.selectedFriendsText, equals('1 vän vald'));
    });

    test('should handle no friends selected text', () {
      expect(viewModel.selectedFriendsText, equals('Inga vänner valda'));
    });

    test('should clear form', () {
      viewModel.updateTitle('Title');
      viewModel.updateDescription('Description');
      viewModel.updateSelectedFriends(['friend_1']);

      viewModel.clearForm();

      expect(viewModel.title, isEmpty);
      expect(viewModel.description, isEmpty);
      expect(viewModel.selectedFriendIds, isEmpty);
      expect(viewModel.error, isNull);
    });
  });

  group('CreateSharedListViewModel - Validation', () {
    test('should validate title requirements', () {
      expect(viewModel.isTitleValid, isFalse);
      expect(viewModel.titleError, isNull); // No error when empty initially

      viewModel.updateTitle(' ');
      expect(viewModel.isTitleValid, isFalse);
      expect(viewModel.titleError, equals('Titel krävs och får inte vara tom'));

      viewModel.updateTitle('Valid Title');
      expect(viewModel.isTitleValid, isTrue);
      expect(viewModel.titleError, isNull);
    });

    test('should validate title length', () {
      final longTitle = 'a' * 101;
      viewModel.updateTitle(longTitle);

      // VM reuses errorDescriptionTooLong for title length too
      expect(viewModel.titleError, equals('Beskrivning för lång'));
    });

    test('should validate description length', () {
      final longDescription = 'a' * 501;
      viewModel.updateDescription(longDescription);

      expect(viewModel.descriptionError, equals('Beskrivning för lång'));
    });

    test('should validate form completeness', () {
      expect(viewModel.validateForm(), isFalse);
      expect(viewModel.error, contains('Titel krävs och får inte vara tom'));

      viewModel.updateTitle('Valid Title');
      expect(viewModel.validateForm(), isFalse);
      expect(viewModel.error, contains('Välj minst en vän att dela med'));

      viewModel.updateSelectedFriends(['friend_1']);
      expect(viewModel.validateForm(), isTrue);
    });

    test('should check if can create', () {
      expect(viewModel.canCreate, isFalse);

      viewModel.updateTitle('Valid Title');
      expect(viewModel.canCreate, isFalse);

      viewModel.updateSelectedFriends(['friend_1']);
      expect(viewModel.canCreate, isTrue);
    });

    test('should disable create when creating', () async {
      viewModel.updateTitle('Valid Title');
      viewModel.updateSelectedFriends(['friend_1']);
      expect(viewModel.canCreate, isTrue);

      // Start creation (will fail but sets isCreating)
      when(() => mockShoppingService.createCollaborativeList(
            name: any(named: 'name'),
            description: any(named: 'description'),
            memberIds: any(named: 'memberIds'),
            memberDisplayNames: any(named: 'memberDisplayNames'),
          )).thenAnswer((_) async {
        await Future.delayed(Duration(milliseconds: 50));
        return null;
      });

      final future = viewModel.createSharedList();

      // Should be creating now
      expect(viewModel.isCreating, isTrue);
      expect(viewModel.canCreate, isFalse);
      expect(viewModel.createButtonText, equals('Skapar...'));

      await future;

      expect(viewModel.isCreating, isFalse);
      expect(viewModel.createButtonText, equals('Skapa & Dela'));
    });
  });

  group('CreateSharedListViewModel - List Creation', () {
    test('should create shared list successfully', () async {
      viewModel.updateTitle('Grocery List');
      viewModel.updateDescription('Weekly groceries');
      viewModel.updateSelectedFriends(['friend_1', 'friend_2']);

      when(() => mockShoppingService.createCollaborativeList(
            name: 'Grocery List',
            description: 'Weekly groceries',
            memberIds: ['friend_1', 'friend_2'],
            memberDisplayNames: {
              'friend_1': 'Anna Andersson',
              'friend_2': 'Erik Eriksson',
            },
          )).thenAnswer((_) async => 'list_123');

      final listId = await viewModel.createSharedList();

      expect(listId, equals('list_123'));
      expect(viewModel.isCreating, isFalse);
      expect(viewModel.error, isNull);

      // Form should be cleared after success
      expect(viewModel.title, isEmpty);
      expect(viewModel.description, isEmpty);
      expect(viewModel.selectedFriendIds, isEmpty);
    });

    test('should handle creation without description', () async {
      viewModel.updateTitle('Simple List');
      viewModel.updateSelectedFriends(['friend_1']);

      when(() => mockShoppingService.createCollaborativeList(
            name: 'Simple List',
            description: null,
            memberIds: ['friend_1'],
            memberDisplayNames: {'friend_1': 'Anna Andersson'},
          )).thenAnswer((_) async => 'list_456');

      final listId = await viewModel.createSharedList();

      expect(listId, equals('list_456'));
    });

    test('should handle unknown friend names', () async {
      viewModel.updateTitle('List');
      viewModel.updateSelectedFriends(['unknown_friend']);

      // VM uses friend?.displayName ?? '?' for unknown friends
      when(() => mockShoppingService.createCollaborativeList(
            name: 'List',
            description: null,
            memberIds: ['unknown_friend'],
            memberDisplayNames: {'unknown_friend': '?'},
          )).thenAnswer((_) async => 'list_789');

      final listId = await viewModel.createSharedList();

      expect(listId, equals('list_789'));
    });

    test('should handle creation failure', () async {
      viewModel.updateTitle('List');
      viewModel.updateSelectedFriends(['friend_1']);

      when(() => mockShoppingService.createCollaborativeList(
            name: any(named: 'name'),
            description: any(named: 'description'),
            memberIds: any(named: 'memberIds'),
            memberDisplayNames: any(named: 'memberDisplayNames'),
          )).thenAnswer((_) async => null);

      mockShoppingService.setShoppingState(error: 'Creation failed');

      final listId = await viewModel.createSharedList();

      expect(listId, isNull);
      expect(viewModel.error, equals('Creation failed'));
      expect(viewModel.isCreating, isFalse);
    });

    test('should handle creation exception', () async {
      viewModel.updateTitle('List');
      viewModel.updateSelectedFriends(['friend_1']);

      when(() => mockShoppingService.createCollaborativeList(
            name: any(named: 'name'),
            description: any(named: 'description'),
            memberIds: any(named: 'memberIds'),
            memberDisplayNames: any(named: 'memberDisplayNames'),
          )).thenThrow(Exception('Network error'));

      final listId = await viewModel.createSharedList();

      expect(listId, isNull);
      expect(viewModel.error, contains('Fel vid skapande av delad lista'));
      expect(viewModel.isCreating, isFalse);
    });

    test('should validate form before creation', () async {
      // Empty form
      final listId = await viewModel.createSharedList();

      expect(listId, isNull);
      expect(viewModel.error, equals('Formuläret är inte komplett'));
    });

    test('should check authentication before creation', () async {
      viewModel.updateTitle('List');
      viewModel.updateSelectedFriends(['friend_1']);

      mockPermissionService.setPermissionState(isAuthenticated: false);

      final listId = await viewModel.createSharedList();

      expect(listId, isNull);
      expect(viewModel.error, equals('Du måste skapa en profil först'));

      verifyNever(() => mockShoppingService.createCollaborativeList(
            name: any(named: 'name'),
            description: any(named: 'description'),
            memberIds: any(named: 'memberIds'),
            memberDisplayNames: any(named: 'memberDisplayNames'),
          ));
    });
  });

  group('CreateSharedListViewModel - Error Handling', () {
    test('should clear error when updating title', () {
      viewModel.clearForm(); // Sets error
      viewModel.validateForm();
      expect(viewModel.hasError, isTrue);

      viewModel.updateTitle('New Title');

      expect(viewModel.hasError, isFalse);
    });

    test('should clear error when updating description', () {
      viewModel.clearForm();
      viewModel.validateForm();
      expect(viewModel.hasError, isTrue);

      viewModel.updateDescription('New Description');

      expect(viewModel.hasError, isFalse);
    });

    test('should clear error when updating friends', () {
      viewModel.clearForm();
      viewModel.validateForm();
      expect(viewModel.hasError, isTrue);

      viewModel.updateSelectedFriends(['friend_1']);

      expect(viewModel.hasError, isFalse);
    });

    test('should clear error explicitly', () {
      viewModel.validateForm();
      expect(viewModel.hasError, isTrue);

      viewModel.clearError();

      expect(viewModel.hasError, isFalse);
      expect(viewModel.error, isNull);
    });
  });

  group('CreateSharedListViewModel - Analytics', () {
    test('should provide analytics data', () {
      final menu = createTestMenu();
      viewModel.initialize(menu: menu);
      viewModel.updateTitle('Test List');
      viewModel.updateDescription('Test Description');
      viewModel.updateSelectedFriends(['friend_1', 'friend_2']);

      final analytics = viewModel.analyticsData;

      expect(analytics['title_length'], equals(9));
      expect(analytics['has_description'], isTrue);
      expect(analytics['selected_friends_count'], equals(2));
      expect(analytics['menu_days_count'], equals(2));
    });

    test('should handle analytics without menu', () {
      viewModel.updateTitle('List');

      final analytics = viewModel.analyticsData;

      expect(analytics['menu_days_count'], equals(0));
    });
  });

  group('CreateSharedListViewModel - Disposal Safety', () {
    // BUT-520 migration guard: the headline behavioral benefit of moving onto
    // BaseViewModel is that a createSharedList() resolving AFTER dispose() must
    // not mutate state or notify a disposed VM. The old hand-rolled setError
    // had no disposed guard; this test fails (uncaught error / late
    // notification) if that guard is ever removed.
    test('state mutation after dispose is safely ignored', () async {
      // Local VM so tearDown's dispose of the shared `viewModel` stays valid.
      final disposableVm = CreateSharedListViewModel(
        shoppingService: mockShoppingService,
        friendsService: mockFriendsService,
      );

      var notificationsAfterDispose = 0;
      var disposed = false;
      disposableVm.addListener(() {
        if (disposed) notificationsAfterDispose++;
      });

      // Defer completion so we can dispose mid-flight, then resolve the gap.
      final gate = Completer<String?>();
      when(() => mockShoppingService.createCollaborativeList(
            name: any(named: 'name'),
            description: any(named: 'description'),
            memberIds: any(named: 'memberIds'),
            memberDisplayNames: any(named: 'memberDisplayNames'),
          )).thenAnswer((_) => gate.future);

      disposableVm.updateTitle('List');
      disposableVm.updateSelectedFriends(['friend_1']);

      final pending = disposableVm.createSharedList();

      disposableVm.dispose();
      disposed = true;

      // Resolve with null → VM's failure branch calls setError, which must
      // no-op on the disposed VM rather than throw or notify.
      gate.complete(null);
      final result = await pending;

      expect(result, isNull);
      expect(notificationsAfterDispose, equals(0));
      expect(disposableVm.isDisposed, isTrue);
    });
  });

  group('CreateSharedListViewModel - Edge Cases', () {
    test('should not update when values are same', () {
      var notificationCount = 0;
      viewModel.addListener(() => notificationCount++);

      viewModel.updateTitle('Title');
      final count1 = notificationCount;

      viewModel.updateTitle('Title');
      expect(notificationCount, equals(count1)); // No change

      viewModel.updateDescription('Desc');
      final count2 = notificationCount;

      viewModel.updateDescription('Desc');
      expect(notificationCount, equals(count2)); // No change
    });

    test('should handle listEquals for friends list', () {
      var notificationCount = 0;
      viewModel.addListener(() => notificationCount++);

      viewModel.updateSelectedFriends(['friend_1', 'friend_2']);
      final count1 = notificationCount;

      // Same list content
      viewModel.updateSelectedFriends(['friend_1', 'friend_2']);
      expect(notificationCount, equals(count1)); // No change

      // Different list
      viewModel.updateSelectedFriends(['friend_2', 'friend_1']);
      expect(notificationCount, greaterThan(count1)); // Changed
    });
  });
}
