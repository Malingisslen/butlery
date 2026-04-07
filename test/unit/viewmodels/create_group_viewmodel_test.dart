import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/create_group_viewmodel.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/user_profile.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';

// Test data builders
class FriendCategoryBuilder {
  static FriendCategory build({
    String? id,
    String? name,
    String? description,
    String? emoji,
    String? ownerId,
    List<String>? friendUserIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    int sortOrder = 0,
    bool isDefault = false,
  }) {
    final now = DateTime.now();
    return FriendCategory(
      id: id ?? 'category_${now.millisecondsSinceEpoch}',
      name: name ?? 'Test Grupp',
      description: description,
      emoji: emoji ?? '👥',
      ownerId: ownerId ?? 'test_user_123',
      friendUserIds: friendUserIds ?? [],
      createdAt: createdAt ?? now,
      updatedAt: updatedAt ?? now,
      sortOrder: sortOrder,
      isDefault: isDefault,
    );
  }
}

class UserProfileBuilder {
  static UserProfile build({
    String? uid,
    String? displayName,
    String? email,
    String? avatarUrl,
    DateTime? joinedAt,
    DateTime? lastActiveAt,
    bool isOnline = false,
  }) {
    final now = DateTime.now();
    return UserProfile(
      uid: uid ?? 'user_${now.millisecondsSinceEpoch}',
      displayName: displayName ?? 'Test User',
      email: email ?? 'test@example.com',
      avatarUrl: avatarUrl,
      joinedAt: joinedAt ?? now,
      lastActiveAt: lastActiveAt ?? now,
      isOnline: isOnline,
    );
  }
}

// Using centralized MockUnifiedFriendsService with enhanced setFriendsState() method

void main() {
  group('CreateGroupViewModel', () {
    late CreateGroupViewModel viewModel;
    late MockUnifiedFriendsService mockFriendsService;
    late MockFriendsCategoriesOperations mockCategoriesOps;
    late MockFriendsManagementOperations mockManagementOps;
    late MockFriendsInvitationsOperations mockInvitationsOps;

    // Test data
    final testFriend1 = UserProfileBuilder.build(
      uid: 'friend_123',
      displayName: 'Anna Andersson',
      email: 'anna@example.com',
    );

    final testFriend2 = UserProfileBuilder.build(
      uid: 'friend_456',
      displayName: 'Erik Svensson',
      email: 'erik@example.com',
    );

    final testFriend3 = UserProfileBuilder.build(
      uid: 'friend_789',
      displayName: 'Maria Öberg',
      email: '', // No email for testing edge case
    );

    final existingCategory = FriendCategoryBuilder.build(
      id: 'existing_category',
      name: 'Existerande Grupp',
      description: 'En grupp som redan finns',
    );

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(FriendCategoryBuilder.build());
      registerFallbackValue(UserProfileBuilder.build());
    });

    setUp(() async {
      await TestServiceLocator.initialize();

      // Create centralized mocks
      mockFriendsService = MockUnifiedFriendsService();
      mockCategoriesOps = MockFriendsCategoriesOperations();
      mockManagementOps = MockFriendsManagementOperations();
      mockInvitationsOps = MockFriendsInvitationsOperations();

      // Configure mock service operations using enhanced setFriendsState()
      mockFriendsService.setFriendsState(
        error: null,
        management: mockManagementOps,
        categories: mockCategoriesOps,
        invitations: mockInvitationsOps,
        categoriesList: [],
        friends: [],
        incomingRequests: [],
        outgoingRequests: [],
      );

      // Configure default mock behavior
      when(() => mockCategoriesOps.getCategoryByName(any())).thenReturn(null);

      when(() => mockCategoriesOps.getAllCategories())
          .thenReturn([existingCategory]);

      when(() => mockCategoriesOps.createCategory(
            name: any(named: 'name'),
            description: any(named: 'description'),
            icon: any(named: 'icon'),
            initialMemberIds: any(named: 'initialMemberIds'),
          )).thenAnswer((_) async => 'new_category_123');

      when(() => mockManagementOps.getFriendById(any())).thenReturn(null);

      when(() => mockInvitationsOps.sendEmailInvitation(
            email: any(named: 'email'),
            customMessage: any(named: 'customMessage'),
          )).thenAnswer((_) async => true);

      // Create viewModel
      viewModel = CreateGroupViewModel(
        friendsService: mockFriendsService,
      );
    });

    tearDown(() async {
      viewModel.dispose();
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('Initialization', () {
      test('should initialize with default values', () {
        expect(viewModel.name, isEmpty);
        expect(viewModel.description, isEmpty);
        expect(viewModel.emoji, equals('👥'));
        expect(viewModel.selectedFriendIds, isEmpty);
        expect(viewModel.selectedFriendsCount, equals(0));
        expect(viewModel.isLoading, isFalse);
        expect(viewModel.error, isNull);
        expect(viewModel.nameError, isNull);
        expect(viewModel.isValid, isFalse);
      });
    });

    group('Form Input Management', () {
      test('should update name and validate', () {
        // Act
        viewModel.updateName('Receptgruppen');

        // Assert
        expect(viewModel.name, equals('Receptgruppen'));
        expect(viewModel.nameError, isNull);
        expect(viewModel.isValid, isTrue);
      });

      test('should update description', () {
        // Act
        viewModel.updateDescription('En grupp för vegetariska recept');

        // Assert
        expect(
            viewModel.description, equals('En grupp för vegetariska recept'));
      });

      test('should update emoji', () {
        // Act
        viewModel.updateEmoji('🥗');

        // Assert
        expect(viewModel.emoji, equals('🥗'));
      });

      test('should toggle friend selection', () {
        // Act - First toggle selects
        viewModel.toggleFriend('friend_123');

        // Assert
        expect(viewModel.selectedFriendIds.contains('friend_123'), isTrue);
        expect(viewModel.selectedFriendsCount, equals(1));

        // Act - Second toggle deselects
        viewModel.toggleFriend('friend_123');

        // Assert
        expect(viewModel.selectedFriendIds.contains('friend_123'), isFalse);
        expect(viewModel.selectedFriendsCount, equals(0));
      });

      test('should handle multiple friend selections', () {
        // Act
        viewModel.toggleFriend('friend_123');
        viewModel.toggleFriend('friend_456');
        viewModel.toggleFriend('friend_789');

        // Assert
        expect(viewModel.selectedFriendsCount, equals(3));
        expect(viewModel.selectedFriendIds,
            containsAll(['friend_123', 'friend_456', 'friend_789']));
      });

      test('should notify listeners on input changes', () {
        // Arrange
        int notificationCount = 0;
        viewModel.addListener(() => notificationCount++);

        // Act
        viewModel.updateName('Test');
        viewModel.updateDescription('Description');
        viewModel.updateEmoji('🎉');
        viewModel.toggleFriend('friend_123');

        // Assert
        expect(notificationCount, equals(4));
      });
    });

    group('Name Validation', () {
      test('should require non-empty name', () {
        // Act
        viewModel.updateName('');

        // Assert
        expect(viewModel.nameError, equals('Gruppnamn krävs'));
        expect(viewModel.isValid, isFalse);
      });

      test('should reject whitespace-only name', () {
        // Act
        viewModel.updateName('   ');

        // Assert
        expect(viewModel.nameError, equals('Gruppnamn krävs'));
        expect(viewModel.isValid, isFalse);
      });

      test('should detect duplicate group names', () {
        // Arrange
        when(() => mockCategoriesOps.getCategoryByName('Existerande Grupp'))
            .thenReturn(existingCategory);

        // Act
        viewModel.updateName('Existerande Grupp');

        // Assert
        expect(viewModel.nameError, equals('Det här gruppnamnet finns redan'));
        expect(viewModel.isValid, isFalse);
      });

      test('should trim name for validation', () {
        // Act
        viewModel.updateName('  Ny Grupp  ');

        // Assert
        expect(viewModel.name, equals('  Ny Grupp  '));
        expect(viewModel.nameError, isNull);
        expect(viewModel.isValid, isTrue);
      });

      test('should handle Swedish characters in name', () {
        // Act
        viewModel.updateName('Åsa Ängströms Örter');

        // Assert
        expect(viewModel.name, equals('Åsa Ängströms Örter'));
        expect(viewModel.nameError, isNull);
        expect(viewModel.isValid, isTrue);
      });

      test('should clear error when valid name entered', () {
        // Arrange - First set an error
        viewModel.updateName('');
        expect(viewModel.nameError, isNotNull);

        // Act
        viewModel.updateName('Valid Name');

        // Assert
        expect(viewModel.nameError, isNull);
        expect(viewModel.isValid, isTrue);
      });
    });

    group('Group Creation', () {
      setUp(() {
        // Setup valid form state
        viewModel.updateName('Receptgruppen');
        viewModel.updateDescription('En grupp för recept');
        viewModel.updateEmoji('🍳');
      });

      test('should create group successfully', () async {
        // Arrange
        final newCategory = FriendCategoryBuilder.build(
          id: 'new_category_123',
          name: 'Receptgruppen',
          description: 'En grupp för recept',
          emoji: '🍳',
        );

        when(() => mockCategoriesOps.getAllCategories())
            .thenReturn([existingCategory, newCategory]);

        // Act
        final result = await viewModel.createGroup();

        // Assert
        expect(result, isTrue);
        expect(viewModel.error, isNull);
        expect(viewModel.isLoading, isFalse);

        verify(() => mockCategoriesOps.createCategory(
              name: 'Receptgruppen',
              description: 'En grupp för recept',
              icon: '🍳',
              initialMemberIds: null,
            )).called(1);
      });

      test('should not create group with invalid form', () async {
        // Arrange
        viewModel.updateName(''); // Invalid name

        // Act
        final result = await viewModel.createGroup();

        // Assert
        expect(result, isFalse);
        expect(viewModel.error, isNull);

        verifyNever(() => mockCategoriesOps.createCategory(
              name: any(named: 'name'),
              description: any(named: 'description'),
              icon: any(named: 'icon'),
              initialMemberIds: any(named: 'initialMemberIds'),
            ));
      });

      test('should handle group creation failure', () async {
        // Arrange
        when(() => mockCategoriesOps.createCategory(
              name: any(named: 'name'),
              description: any(named: 'description'),
              icon: any(named: 'icon'),
              initialMemberIds: any(named: 'initialMemberIds'),
            )).thenAnswer((_) async => null);

        // Set error state on the mock service
        mockFriendsService.setFriendsState(error: 'Network error');

        // Act
        final result = await viewModel.createGroup();

        // Assert
        expect(result, isFalse);
        // The error is prefixed by executeAsync's errorPrefix parameter
        expect(viewModel.error,
            equals('Kunde inte skapa grupp: Exception: Network error'));
        expect(viewModel.isLoading, isFalse);
      });

      test('should handle missing created group', () async {
        // Arrange - Group creation returns ID but group not found
        when(() => mockCategoriesOps.getAllCategories())
            .thenReturn([existingCategory]); // New group not in list

        // Act
        final result = await viewModel.createGroup();

        // Assert
        expect(result, isFalse);
        // The error is prefixed by executeAsync's errorPrefix parameter
        expect(viewModel.error,
            equals('Kunde inte skapa grupp: Exception: Gruppen hittades inte'));
      });

      test('should set loading state during creation', () async {
        // Arrange
        bool wasCreating = false;
        viewModel.addListener(() {
          if (viewModel.isLoading) wasCreating = true;
        });

        final newCategory = FriendCategoryBuilder.build(
          id: 'new_category_123',
          name: 'Receptgruppen',
        );

        when(() => mockCategoriesOps.getAllCategories())
            .thenReturn([existingCategory, newCategory]);

        // Act
        await viewModel.createGroup();

        // Assert
        expect(wasCreating, isTrue);
        expect(viewModel.isLoading, isFalse);
      });

      test('should handle exception during creation', () async {
        // Arrange
        when(() => mockCategoriesOps.createCategory(
              name: any(named: 'name'),
              description: any(named: 'description'),
              icon: any(named: 'icon'),
              initialMemberIds: any(named: 'initialMemberIds'),
            )).thenThrow(Exception('Database error'));

        // Act
        final result = await viewModel.createGroup();

        // Assert
        expect(result, isFalse);
        expect(viewModel.error, contains('Database error'));
        expect(viewModel.isLoading, isFalse);
      });
    });

    group('Invitation Sending', () {
      setUp(() {
        // Setup valid form and friend selection
        viewModel.updateName('Receptgruppen');
        viewModel.toggleFriend('friend_123');
        viewModel.toggleFriend('friend_456');
        viewModel.toggleFriend('friend_789');

        // Configure friend lookup
        when(() => mockManagementOps.getFriendById('friend_123'))
            .thenReturn(testFriend1);
        when(() => mockManagementOps.getFriendById('friend_456'))
            .thenReturn(testFriend2);
        when(() => mockManagementOps.getFriendById('friend_789'))
            .thenReturn(testFriend3);
      });

      test('should send invitations to selected friends with emails', () async {
        // Arrange
        final newCategory = FriendCategoryBuilder.build(
          id: 'new_category_123',
          name: 'Receptgruppen',
        );

        when(() => mockCategoriesOps.getAllCategories())
            .thenReturn([existingCategory, newCategory]);

        // Act
        final result = await viewModel.createGroup();

        // Assert
        expect(result, isTrue);

        // Verify invitations sent to friends with valid emails
        verify(() => mockInvitationsOps.sendEmailInvitation(
              email: 'anna@example.com',
              customMessage: any(named: 'customMessage'),
            )).called(1);

        verify(() => mockInvitationsOps.sendEmailInvitation(
              email: 'erik@example.com',
              customMessage: any(named: 'customMessage'),
            )).called(1);

        // Friend without email should not receive invitation
        verifyNever(() => mockInvitationsOps.sendEmailInvitation(
              email: '',
              customMessage: any(named: 'customMessage'),
            ));
      });

      test('should include personalized message in invitations', () async {
        // Arrange
        viewModel.updateName('Vegetariska Recept');
        viewModel
            .toggleFriend('friend_456'); // Deselect to only have friend_123
        viewModel
            .toggleFriend('friend_789'); // Deselect to only have friend_123

        final newCategory = FriendCategoryBuilder.build(
          id: 'new_category_123',
          name: 'Vegetariska Recept',
        );

        when(() => mockCategoriesOps.getAllCategories())
            .thenReturn([existingCategory, newCategory]);

        // Act
        await viewModel.createGroup();

        // Assert
        verify(() => mockInvitationsOps.sendEmailInvitation(
              email: 'anna@example.com',
              customMessage: any(named: 'customMessage'),
            )).called(1);
      });

      test('should handle invitation sending failures', () async {
        // Arrange
        when(() => mockInvitationsOps.sendEmailInvitation(
              email: any(named: 'email'),
              customMessage: any(named: 'customMessage'),
            )).thenAnswer((_) async => false);

        final newCategory = FriendCategoryBuilder.build(
          id: 'new_category_123',
          name: 'Receptgruppen',
        );

        when(() => mockCategoriesOps.getAllCategories())
            .thenReturn([existingCategory, newCategory]);

        // Act
        final result = await viewModel.createGroup();

        // Assert - Group creation should still succeed even if invitations fail
        expect(result, isTrue);
        expect(viewModel.error, isNull);
      });

      test('should handle friends not found', () async {
        // Arrange
        when(() => mockManagementOps.getFriendById(any()))
            .thenReturn(null); // Friends not found

        final newCategory = FriendCategoryBuilder.build(
          id: 'new_category_123',
          name: 'Receptgruppen',
        );

        when(() => mockCategoriesOps.getAllCategories())
            .thenReturn([existingCategory, newCategory]);

        // Act
        final result = await viewModel.createGroup();

        // Assert
        expect(result, isTrue); // Group creation should still succeed

        // No invitations should be sent
        verifyNever(() => mockInvitationsOps.sendEmailInvitation(
              email: any(named: 'email'),
              customMessage: any(named: 'customMessage'),
            ));
      });

      test('should create group without invitations if no friends selected',
          () async {
        // Arrange - Clear friend selection
        viewModel.toggleFriend('friend_123');
        viewModel.toggleFriend('friend_456');
        viewModel.toggleFriend('friend_789');
        expect(viewModel.selectedFriendsCount, equals(0));

        final newCategory = FriendCategoryBuilder.build(
          id: 'new_category_123',
          name: 'Receptgruppen',
        );

        when(() => mockCategoriesOps.getAllCategories())
            .thenReturn([existingCategory, newCategory]);

        // Act
        final result = await viewModel.createGroup();

        // Assert
        expect(result, isTrue);

        // No invitations should be sent
        verifyNever(() => mockInvitationsOps.sendEmailInvitation(
              email: any(named: 'email'),
              customMessage: any(named: 'customMessage'),
            ));
      });
    });

    group('Edge Cases', () {
      test('should handle very long group name', () {
        // Arrange
        final longName = 'A' * 200;

        // Act
        viewModel.updateName(longName);

        // Assert
        expect(viewModel.name, equals(longName));
        expect(viewModel.nameError, isNull);
        expect(viewModel.isValid, isTrue);
      });

      test('should handle very long description', () {
        // Arrange
        final longDescription = 'B' * 500;

        // Act
        viewModel.updateDescription(longDescription);

        // Assert
        expect(viewModel.description, equals(longDescription));
      });

      test('should handle emoji characters in all fields', () {
        // Act
        viewModel.updateName('🎉 Party Group 🎊');
        viewModel.updateDescription('A fun group for parties 🥳🍾');
        viewModel.updateEmoji('🎈');

        // Assert
        expect(viewModel.name, equals('🎉 Party Group 🎊'));
        expect(viewModel.description, equals('A fun group for parties 🥳🍾'));
        expect(viewModel.emoji, equals('🎈'));
        expect(viewModel.isValid, isTrue);
      });

      test('should handle rapid friend selection toggles', () {
        // Act - Rapidly toggle same friend
        for (int i = 0; i < 10; i++) {
          viewModel.toggleFriend('friend_123');
        }

        // Assert - Should end up not selected (even number of toggles)
        expect(viewModel.selectedFriendIds.contains('friend_123'), isFalse);
      });
    });

    group('Lifecycle', () {
      test('should dispose without errors', () {
        // Arrange
        final testViewModel = CreateGroupViewModel(
          friendsService: mockFriendsService,
        );

        // Act & Assert - Should not throw
        expect(() => testViewModel.dispose(), returnsNormally);
      });

      test('should handle operations after dispose', () async {
        // Arrange
        final testViewModel = CreateGroupViewModel(
          friendsService: mockFriendsService,
        );

        testViewModel.dispose();

        // Act - Operations after dispose should throw FlutterError
        expect(() {
          testViewModel.updateName('Test');
        }, throwsFlutterError);

        expect(() {
          testViewModel.updateDescription('Test');
        }, throwsFlutterError);

        expect(() {
          testViewModel.updateEmoji('🎉');
        }, throwsFlutterError);

        expect(() {
          testViewModel.toggleFriend('friend_123');
        }, throwsFlutterError);

        // Creating group after dispose should return false (caught by outer try-catch)
        expect(testViewModel.createGroup(), completion(isFalse));
      });
    });
  });
}
