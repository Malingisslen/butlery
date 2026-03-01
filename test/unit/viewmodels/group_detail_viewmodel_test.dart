import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/group_detail_viewmodel.dart';
import 'package:butlery/services/messaging_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';

// Mock services
class MockMessagingService extends Mock implements MessagingService {}

class MockUnifiedFriendsService extends Mock implements UnifiedFriendsService {}

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  group('GroupDetailViewModel - Group Collaboration Tests', () {
    late GroupDetailViewModel viewModel;
    late MockMessagingService mockMessagingService;
    late MockUnifiedFriendsService mockFriendsService;
    late MockAuthRepository mockAuthRepository;
    late StreamController<List<Conversation>> conversationsStreamController;

    // Test data
    const testConversationId = 'test-conversation-123';
    const testUserId = 'current-user-123';
    const testMember1Id = 'member-1';
    const testMember2Id = 'member-2';
    const testMember3Id = 'member-3';

    final testGroupConversation = Conversation(
      id: testConversationId,
      participantIds: [testUserId, testMember1Id, testMember2Id],
      participantDisplayNames: {
        testUserId: 'Current User',
        testMember1Id: 'Anna',
        testMember2Id: 'Erik',
      },
      participantAvatarUrls: {},
      lastReadTimestamps: {
        testUserId: DateTime(2025, 1, 1),
        testMember1Id: DateTime(2025, 1, 1),
        testMember2Id: DateTime(2025, 1, 1),
      },
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
      title: 'Testgrupp',
      isGroup: true,
      metadata: {'creatorId': testUserId},
    );

    final testFriends = [
      UserProfile(
        uid: testMember3Id,
        displayName: 'Maria',
        email: 'maria@test.com',
        isOnline: true,
        joinedAt: DateTime(2024, 1, 1),
        lastActiveAt: DateTime.now(),
      ),
    ];

    setUpAll(() async {
      await BaseUnitTest.setupUnit();

      // Register fallback values for mocktail
      registerFallbackValue(<String>[]);
      registerFallbackValue(<String, String>{});
      registerFallbackValue(<String, String?>{});

      // Bridge production ServiceLocator to test GetIt instance
      // so GroupDetailViewModel.currentUserId can resolve PermissionService
      final testDIContainer = DIContainer();
      production.ServiceLocator.initialize(testDIContainer);
    });

    setUp(() async {
      await TestServiceLocator.initialize();

      // Create mocks
      mockMessagingService = MockMessagingService();
      mockFriendsService = MockUnifiedFriendsService();
      mockAuthRepository = MockAuthRepository();

      // Setup stream controller for conversations
      conversationsStreamController =
          StreamController<List<Conversation>>.broadcast();

      // Register mocks
      TestServiceLocator.registerMock<MessagingService>(mockMessagingService);
      TestServiceLocator.registerMock<UnifiedFriendsService>(
          mockFriendsService);
      TestServiceLocator.registerMock<AuthRepository>(mockAuthRepository);

      // Configure PermissionService with test user ID so
      // GroupDetailViewModel.currentUserId resolves correctly via production ServiceLocator
      final permissionService =
          TestServiceLocator.get<PermissionService>() as MockPermissionService;
      permissionService.setPermissionState(currentUserId: testUserId);

      // Default mock behaviors
      when(() => mockAuthRepository.currentUserId).thenReturn(testUserId);
      when(() => mockMessagingService.getMyConversations())
          .thenAnswer((_) => conversationsStreamController.stream);
      when(() => mockMessagingService.getConversation(testConversationId))
          .thenAnswer((_) async => testGroupConversation);
      when(() => mockFriendsService.friends).thenReturn(testFriends);
    });

    tearDown(() async {
      try {
        viewModel.dispose();
      } catch (e) {
        // Already disposed in test
      }
      await conversationsStreamController.close();
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    // Helper function to create ViewModel
    GroupDetailViewModel createViewModel() {
      return GroupDetailViewModel(
        conversationId: testConversationId,
        messagingService: mockMessagingService,
        friendsService: mockFriendsService,
      );
    }

    // ===== INITIALIZATION AND STATE =====

    group('Initialization and State', () {
      test('should initialize with loading state', () {
        // Act
        viewModel = createViewModel();

        // Assert
        expect(viewModel.isLoading, true, reason: 'Should start loading');
        expect(viewModel.conversation, null,
            reason: 'No conversation loaded yet');
        expect(viewModel.hasConversation, false, reason: 'No conversation yet');
        expect(viewModel.error, null, reason: 'No error initially');
      });

      test('should load conversation on initialization', () async {
        // Act
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 100));

        // Assert
        expect(viewModel.conversation, isNotNull,
            reason: 'Conversation should be loaded');
        expect(viewModel.isLoading, false, reason: 'Should finish loading');
        verify(() => mockMessagingService.getConversation(testConversationId))
            .called(1);
      });

      test('should subscribe to conversation stream on initialization',
          () async {
        // Act
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 100));

        // Assert
        verify(() => mockMessagingService.getMyConversations()).called(1);
      });

      test('should update conversation from stream', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 100));

        final updatedConversation = testGroupConversation.copyWith(
          title: 'Updated Title',
        );

        // Act - Emit updated conversation through stream
        conversationsStreamController.add([updatedConversation]);
        await Future.delayed(const Duration(milliseconds: 50));

        // Assert
        expect(viewModel.conversation?.title, 'Updated Title');
        expect(viewModel.isLoading, false);
        expect(viewModel.error, null);
      });

      test('should handle conversation not in stream list', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 100));

        // Act - Emit conversation list without our conversation
        conversationsStreamController.add([]);
        await Future.delayed(const Duration(milliseconds: 50));

        // Assert - Should keep cached conversation
        expect(viewModel.conversation, isNotNull,
            reason: 'Should keep cached conversation');
      });
    });

    // ===== GROUP INFORMATION =====

    group('Group Information', () {
      test('should provide group title', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 100));

        // Act & Assert
        expect(viewModel.groupTitle, 'Testgrupp');
      });

      test('should provide default title when no conversation', () {
        // Arrange
        viewModel = createViewModel();

        // Act & Assert - production uses AppLocale.current.labelChat
        expect(viewModel.groupTitle, 'Chatt');
      });

      test('should provide member IDs', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 100));

        // Act
        final memberIds = viewModel.memberIds;

        // Assert
        expect(memberIds.length, 3);
        expect(memberIds, contains(testUserId));
        expect(memberIds, contains(testMember1Id));
        expect(memberIds, contains(testMember2Id));
      });

      test('should provide member count', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 100));

        // Act & Assert
        expect(viewModel.memberCount, 3);
      });

      test('should provide creation date', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 100));

        // Act & Assert
        expect(viewModel.createdAt, DateTime(2025, 1, 1));
      });

      test('should provide member display name', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 100));

        // Act & Assert
        expect(viewModel.getMemberDisplayName(testMember1Id), 'Anna');
        expect(viewModel.getMemberDisplayName(testMember2Id), 'Erik');
        expect(viewModel.getMemberDisplayName('unknown-id'), '?');
      });

      test('should provide member avatar URL', () async {
        // Arrange
        final conversationWithAvatars = testGroupConversation.copyWith(
          participantAvatarUrls: {
            testMember1Id: 'https://example.com/anna.jpg',
          },
        );

        when(() => mockMessagingService.getConversation(testConversationId))
            .thenAnswer((_) async => conversationWithAvatars);

        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 100));

        // Act & Assert
        expect(viewModel.getMemberAvatarUrl(testMember1Id),
            'https://example.com/anna.jpg');
        expect(viewModel.getMemberAvatarUrl(testMember2Id), null);
      });
    });

    // ===== ADMIN PERMISSIONS =====

    group('Admin Permissions', () {
      test('should identify current user as admin when they are creator',
          () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 100));

        // Act & Assert
        expect(viewModel.isAdmin, true, reason: 'Current user is creator');
      });

      test(
          'should identify current user as not admin when they are not creator',
          () async {
        // Arrange
        final nonAdminConversation = testGroupConversation.copyWith(
          metadata: {'creatorId': testMember1Id},
        );

        when(() => mockMessagingService.getConversation(testConversationId))
            .thenAnswer((_) async => nonAdminConversation);

        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 100));

        // Act & Assert
        expect(viewModel.isAdmin, false, reason: 'Current user is not creator');
      });

      test('should return false for isAdmin when no conversation loaded', () {
        // Arrange
        viewModel = createViewModel();

        // Act & Assert
        expect(viewModel.isAdmin, false);
      });

      test('should return false for isAdmin when not authenticated', () async {
        // Arrange - clear userId on PermissionService (which the ViewModel actually uses)
        final permService = TestServiceLocator.get<PermissionService>()
            as MockPermissionService;
        permService.setPermissionState(currentUserId: null);
        when(() => mockAuthRepository.currentUserId).thenReturn(null);
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 100));

        // Act & Assert
        expect(viewModel.isAdmin, false);
      });
    });

    // ===== ADD MEMBERS =====

    group('Add Members', () {
      test('should add members successfully', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 100));

        when(() => mockMessagingService.addParticipantsToGroup(
              conversationId: any(named: 'conversationId'),
              participantIds: any(named: 'participantIds'),
              participantDisplayNames: any(named: 'participantDisplayNames'),
              participantAvatarUrls: any(named: 'participantAvatarUrls'),
            )).thenAnswer((_) async => {});

        // Act
        final result = await viewModel.addMembers(
          [testMember3Id],
          {testMember3Id: 'Maria'},
          {testMember3Id: null},
        );

        // Assert
        expect(result, true, reason: 'Add members should succeed');
        expect(viewModel.isAddingMembers, false,
            reason: 'Should finish adding');
        expect(viewModel.error, null, reason: 'No error should occur');

        verify(() => mockMessagingService.addParticipantsToGroup(
              conversationId: testConversationId,
              participantIds: [testMember3Id],
              participantDisplayNames: {testMember3Id: 'Maria'},
              participantAvatarUrls: {testMember3Id: null},
            )).called(1);
      });

      test('should set loading state during add members', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 100));

        final completer = Completer<void>();
        when(() => mockMessagingService.addParticipantsToGroup(
              conversationId: any(named: 'conversationId'),
              participantIds: any(named: 'participantIds'),
              participantDisplayNames: any(named: 'participantDisplayNames'),
              participantAvatarUrls: any(named: 'participantAvatarUrls'),
            )).thenAnswer((_) => completer.future);

        // Act
        final addFuture = viewModel.addMembers(
          [testMember3Id],
          {testMember3Id: 'Maria'},
          null,
        );

        await Future.delayed(const Duration(milliseconds: 10));

        // Assert - Should be loading
        expect(viewModel.isAddingMembers, true);

        // Complete the operation
        completer.complete();
        await addFuture;

        expect(viewModel.isAddingMembers, false);
      });

      test('should handle add members failure', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 100));

        when(() => mockMessagingService.addParticipantsToGroup(
              conversationId: any(named: 'conversationId'),
              participantIds: any(named: 'participantIds'),
              participantDisplayNames: any(named: 'participantDisplayNames'),
              participantAvatarUrls: any(named: 'participantAvatarUrls'),
            )).thenThrow(Exception('Failed to add members'));

        // Act
        final result = await viewModel.addMembers(
          [testMember3Id],
          {testMember3Id: 'Maria'},
          null,
        );

        // Assert
        expect(result, false, reason: 'Should fail');
        expect(viewModel.error, contains('Kunde inte lägga till medlemmar'));
        expect(viewModel.isAddingMembers, false);
      });

      test('should not add members when disposed', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 100));
        viewModel.dispose();

        // Act
        final result = await viewModel.addMembers(
          [testMember3Id],
          {testMember3Id: 'Maria'},
          null,
        );

        // Assert
        expect(result, false);
        verifyNever(() => mockMessagingService.addParticipantsToGroup(
              conversationId: any(named: 'conversationId'),
              participantIds: any(named: 'participantIds'),
              participantDisplayNames: any(named: 'participantDisplayNames'),
              participantAvatarUrls: any(named: 'participantAvatarUrls'),
            ));
      });
    });

    // ===== REMOVE MEMBER =====

    group('Remove Member', () {
      test('should remove member successfully when user is admin', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 100));

        when(() => mockMessagingService.removeParticipantFromGroup(
              conversationId: any(named: 'conversationId'),
              participantId: any(named: 'participantId'),
            )).thenAnswer((_) async => {});

        // Act
        final result = await viewModel.removeMember(testMember1Id);

        // Assert
        expect(result, true, reason: 'Remove should succeed');
        expect(viewModel.isRemovingMember, false);
        expect(viewModel.error, null);

        verify(() => mockMessagingService.removeParticipantFromGroup(
              conversationId: testConversationId,
              participantId: testMember1Id,
            )).called(1);
      });

      test('should not remove member when user is not admin', () async {
        // Arrange
        final nonAdminConversation = testGroupConversation.copyWith(
          metadata: {'creatorId': testMember1Id},
        );

        when(() => mockMessagingService.getConversation(testConversationId))
            .thenAnswer((_) async => nonAdminConversation);

        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 100));

        // Act
        final result = await viewModel.removeMember(testMember2Id);

        // Assert
        expect(result, false, reason: 'Should fail (not admin)');
        expect(viewModel.error, contains('Endast administratör'));

        verifyNever(() => mockMessagingService.removeParticipantFromGroup(
              conversationId: any(named: 'conversationId'),
              participantId: any(named: 'participantId'),
            ));
      });

      test('should not allow removing self via removeMember', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 100));

        // Act
        final result = await viewModel.removeMember(testUserId);

        // Assert
        expect(result, false);
        expect(viewModel.error, contains('Lämna grupp'));

        verifyNever(() => mockMessagingService.removeParticipantFromGroup(
              conversationId: any(named: 'conversationId'),
              participantId: any(named: 'participantId'),
            ));
      });

      test('should handle remove member failure', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 100));

        when(() => mockMessagingService.removeParticipantFromGroup(
              conversationId: any(named: 'conversationId'),
              participantId: any(named: 'participantId'),
            )).thenThrow(Exception('Failed to remove'));

        // Act
        final result = await viewModel.removeMember(testMember1Id);

        // Assert
        expect(result, false);
        expect(viewModel.error, contains('Kunde inte ta bort medlem'));
        expect(viewModel.isRemovingMember, false);
      });

      test('should set loading state during remove member', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 100));

        final completer = Completer<void>();
        when(() => mockMessagingService.removeParticipantFromGroup(
              conversationId: any(named: 'conversationId'),
              participantId: any(named: 'participantId'),
            )).thenAnswer((_) => completer.future);

        // Act
        final removeFuture = viewModel.removeMember(testMember1Id);
        await Future.delayed(const Duration(milliseconds: 10));

        // Assert
        expect(viewModel.isRemovingMember, true);

        completer.complete();
        await removeFuture;

        expect(viewModel.isRemovingMember, false);
      });
    });

    // ===== LEAVE GROUP =====

    group('Leave Group', () {
      test('should allow current user to leave group', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 100));

        when(() => mockMessagingService.removeParticipantFromGroup(
              conversationId: any(named: 'conversationId'),
              participantId: any(named: 'participantId'),
            )).thenAnswer((_) async => {});

        // Act
        final result = await viewModel.leaveGroup();

        // Assert
        expect(result, true);
        expect(viewModel.isLeavingGroup, false);

        verify(() => mockMessagingService.removeParticipantFromGroup(
              conversationId: testConversationId,
              participantId: testUserId,
            )).called(1);
      });

      test('should set loading state during leave group', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 100));

        final completer = Completer<void>();
        when(() => mockMessagingService.removeParticipantFromGroup(
              conversationId: any(named: 'conversationId'),
              participantId: any(named: 'participantId'),
            )).thenAnswer((_) => completer.future);

        // Act
        final leaveFuture = viewModel.leaveGroup();
        await Future.delayed(const Duration(milliseconds: 10));

        // Assert
        expect(viewModel.isLeavingGroup, true);

        completer.complete();
        await leaveFuture;

        expect(viewModel.isLeavingGroup, false);
      });

      test('should handle leave group failure', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 100));

        when(() => mockMessagingService.removeParticipantFromGroup(
              conversationId: any(named: 'conversationId'),
              participantId: any(named: 'participantId'),
            )).thenThrow(Exception('Failed to leave'));

        // Act
        final result = await viewModel.leaveGroup();

        // Assert
        expect(result, false);
        expect(viewModel.error, contains('Kunde inte lämna grupp'));
        expect(viewModel.isLeavingGroup, false);
      });

      test('should not leave group when not authenticated', () async {
        // Arrange - clear userId on PermissionService (which the ViewModel actually uses)
        final permService = TestServiceLocator.get<PermissionService>()
            as MockPermissionService;
        permService.setPermissionState(currentUserId: null);
        when(() => mockAuthRepository.currentUserId).thenReturn(null);
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 100));

        // Act
        final result = await viewModel.leaveGroup();

        // Assert
        expect(result, false);

        verifyNever(() => mockMessagingService.removeParticipantFromGroup(
              conversationId: any(named: 'conversationId'),
              participantId: any(named: 'participantId'),
            ));
      });
    });

    // ===== UPDATE GROUP TITLE =====

    group('Update Group Title', () {
      test('should update group title when user is admin', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 100));

        when(() => mockMessagingService.updateGroupTitle(
              conversationId: any(named: 'conversationId'),
              newTitle: any(named: 'newTitle'),
            )).thenAnswer((_) async => {});

        // Act
        final result = await viewModel.updateGroupTitle('New Title');

        // Assert
        expect(result, true);
        expect(viewModel.isUpdatingTitle, false);
        expect(viewModel.error, null);

        verify(() => mockMessagingService.updateGroupTitle(
              conversationId: testConversationId,
              newTitle: 'New Title',
            )).called(1);
      });

      test('should trim whitespace from title', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 100));

        when(() => mockMessagingService.updateGroupTitle(
              conversationId: any(named: 'conversationId'),
              newTitle: any(named: 'newTitle'),
            )).thenAnswer((_) async => {});

        // Act
        await viewModel.updateGroupTitle('  Title with spaces  ');

        // Assert
        verify(() => mockMessagingService.updateGroupTitle(
              conversationId: testConversationId,
              newTitle: 'Title with spaces',
            )).called(1);
      });

      test('should not update title when user is not admin', () async {
        // Arrange
        final nonAdminConversation = testGroupConversation.copyWith(
          metadata: {'creatorId': testMember1Id},
        );

        when(() => mockMessagingService.getConversation(testConversationId))
            .thenAnswer((_) async => nonAdminConversation);

        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 100));

        // Act
        final result = await viewModel.updateGroupTitle('New Title');

        // Assert
        expect(result, false);
        expect(viewModel.error, contains('Endast administratör'));

        verifyNever(() => mockMessagingService.updateGroupTitle(
              conversationId: any(named: 'conversationId'),
              newTitle: any(named: 'newTitle'),
            ));
      });

      test('should not update empty title', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 100));

        // Act
        final result = await viewModel.updateGroupTitle('   ');

        // Assert
        expect(result, false);
        expect(viewModel.error, contains('Gruppnamn kan inte vara tomt'));

        verifyNever(() => mockMessagingService.updateGroupTitle(
              conversationId: any(named: 'conversationId'),
              newTitle: any(named: 'newTitle'),
            ));
      });

      test('should handle update title failure', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 100));

        when(() => mockMessagingService.updateGroupTitle(
              conversationId: any(named: 'conversationId'),
              newTitle: any(named: 'newTitle'),
            )).thenThrow(Exception('Failed to update'));

        // Act
        final result = await viewModel.updateGroupTitle('New Title');

        // Assert
        expect(result, false);
        expect(viewModel.error, contains('Kunde inte uppdatera gruppnamn'));
        expect(viewModel.isUpdatingTitle, false);
      });

      test('should set loading state during title update', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 100));

        final completer = Completer<void>();
        when(() => mockMessagingService.updateGroupTitle(
              conversationId: any(named: 'conversationId'),
              newTitle: any(named: 'newTitle'),
            )).thenAnswer((_) => completer.future);

        // Act
        final updateFuture = viewModel.updateGroupTitle('New Title');
        await Future.delayed(const Duration(milliseconds: 10));

        // Assert
        expect(viewModel.isUpdatingTitle, true);

        completer.complete();
        await updateFuture;

        expect(viewModel.isUpdatingTitle, false);
      });
    });

    // ===== GET AVAILABLE FRIENDS =====

    group('Get Available Friends', () {
      test('should return friends not in group', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 100));

        // Act
        final availableFriends = await viewModel.getAvailableFriendsToAdd();

        // Assert
        expect(availableFriends.length, 1);
        expect(availableFriends.first.uid, testMember3Id);
        expect(availableFriends.first.displayName, 'Maria');
      });

      test('should return empty list when all friends are members', () async {
        // Arrange
        final allFriendsInGroup = testGroupConversation.copyWith(
          participantIds: [
            testUserId,
            testMember1Id,
            testMember2Id,
            testMember3Id
          ],
        );

        when(() => mockMessagingService.getConversation(testConversationId))
            .thenAnswer((_) async => allFriendsInGroup);

        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 100));

        // Act
        final availableFriends = await viewModel.getAvailableFriendsToAdd();

        // Assert
        expect(availableFriends, isEmpty);
      });

      test('should handle error when getting friends', () async {
        // Arrange
        when(() => mockFriendsService.friends).thenThrow(Exception('Failed'));
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 100));

        // Act
        final availableFriends = await viewModel.getAvailableFriendsToAdd();

        // Assert
        expect(availableFriends, isEmpty);
      });
    });

    // ===== STREAM MANAGEMENT =====

    group('Stream Management', () {
      test('should handle stream errors gracefully', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 100));

        // Act - Emit error through stream
        conversationsStreamController.addError(Exception('Stream error'));
        await Future.delayed(const Duration(milliseconds: 50));

        // Assert - Should set error state
        expect(viewModel.error, isNotNull);
        expect(viewModel.isLoading, false);
      });

      test('should continue working after stream error', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 100));

        // Act - Error then recovery
        conversationsStreamController.addError(Exception('Error'));
        await Future.delayed(const Duration(milliseconds: 50));

        conversationsStreamController.add([testGroupConversation]);
        await Future.delayed(const Duration(milliseconds: 50));

        // Assert - Should recover
        expect(viewModel.conversation, isNotNull);
      });
    });

    // ===== DISPOSE =====

    group('Dispose', () {
      test('should dispose without errors', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 100));

        // Act & Assert
        expect(() => viewModel.dispose(), returnsNormally);
      });

      test('should cancel stream subscription on dispose', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 100));

        // Act
        viewModel.dispose();

        // Emit event after dispose - should not crash
        conversationsStreamController.add([testGroupConversation]);
        await Future.delayed(const Duration(milliseconds: 50));

        // Assert - No crash means subscription was cancelled
      });

      test('should not perform operations after dispose', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 100));
        viewModel.dispose();

        when(() => mockMessagingService.addParticipantsToGroup(
              conversationId: any(named: 'conversationId'),
              participantIds: any(named: 'participantIds'),
              participantDisplayNames: any(named: 'participantDisplayNames'),
              participantAvatarUrls: any(named: 'participantAvatarUrls'),
            )).thenAnswer((_) async => {});

        // Act
        final result = await viewModel
            .addMembers([testMember3Id], {testMember3Id: 'Maria'}, null);

        // Assert
        expect(result, false,
            reason: 'Should not perform operation after dispose');
      });
    });
  });
}
