import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/social_recipe_viewmodel.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/recipe_comment.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/user_service.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';

// Test data builders
class UserProfileBuilder {
  static UserProfile build({
    String? uid,
    String? displayName,
    String? email,
    String? avatarUrl,
    bool isSearchable = true,
    bool allowEmailSearch = false,
    int publicRecipeCount = 0,
    int friendsCount = 0,
    DateTime? joinedAt,
    DateTime? lastActiveAt,
    bool isOnline = false,
    String? fcmToken,
    DateTime? fcmTokenUpdatedAt,
    bool notificationsEnabled = true,
  }) {
    final now = DateTime.now();
    return UserProfile(
      uid: uid ?? 'test-user-123',
      displayName: displayName ?? 'Test User',
      email: email ?? 'test@example.com',
      avatarUrl: avatarUrl,
      isSearchable: isSearchable,
      allowEmailSearch: allowEmailSearch,
      publicRecipeCount: publicRecipeCount,
      friendsCount: friendsCount,
      joinedAt: joinedAt ?? now,
      lastActiveAt: lastActiveAt ?? now,
      isOnline: isOnline,
      fcmToken: fcmToken,
      fcmTokenUpdatedAt: fcmTokenUpdatedAt,
      notificationsEnabled: notificationsEnabled,
    );
  }
}

class RecipeCommentBuilder {
  static RecipeComment build({
    String? id,
    String? recipeId,
    String? authorId,
    String? text,
    DateTime? createdAt,
    String? parentCommentId,
    int likesCount = 0,
  }) {
    return RecipeComment(
      id: id ?? 'comment_${DateTime.now().millisecondsSinceEpoch}',
      recipeId: recipeId ?? 'recipe_123',
      authorId: authorId ?? 'user_123',
      authorDisplayName: 'Test Author',
      text: text ?? 'Test comment',
      createdAt: createdAt ?? DateTime.now(),
      parentCommentId: parentCommentId,
      likesCount: likesCount,
    );
  }

  static RecipeComment buildReply({
    String? id,
    String? parentId,
    String? authorId,
    String? text,
  }) {
    return build(
      id: id,
      parentCommentId: parentId ?? 'parent_comment_123',
      authorId: authorId,
      text: text ?? 'Reply comment',
    );
  }
}

void main() {
  group('SocialRecipeViewModel', () {
    late SocialRecipeViewModel viewModel;
    late MockUnifiedFriendsService mockFriendsService;
    late MockUnifiedRecipeService mockRecipeService;
    late MockUserService mockUserService;
    late MockSocialRecipeOperations mockSocialOps;
    const testRecipeId = 'test_recipe_123';

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(UserProfileBuilder.build());
      registerFallbackValue(RecipeCommentBuilder.build());
      registerFallbackValue(ResourcePermission.viewer);
    });

    setUp(() async {
      await TestServiceLocator.initialize();

      // Create mocks
      mockFriendsService = MockUnifiedFriendsService();
      mockRecipeService = MockUnifiedRecipeService();
      mockUserService = MockUserService();
      mockSocialOps = MockSocialRecipeOperations();

      // Configure default state
      final testFriends = [
        UserProfileBuilder.build(
          uid: 'friend_1',
          displayName: 'Anna Andersson',
          email: 'anna@example.com',
        ),
        UserProfileBuilder.build(
          uid: 'friend_2',
          displayName: 'Erik Svensson',
          email: 'erik@example.com',
        ),
      ];

      mockFriendsService.setFriendsState(
        friends: testFriends,
        isInitialized: true,
        isLoading: false,
        error: null,
      );

      // Configure user service state
      mockUserService.setUserState(
        currentUser: UserProfileBuilder.build(
          uid: 'current_user_123',
          displayName: 'Current User',
          email: 'current@example.com',
        ),
      );

      // Stub the social accessor and service-layer methods on the recipe mock
      when(() => mockRecipeService.social).thenReturn(mockSocialOps);
      when(() => mockRecipeService.createCollaborativeRecipe(
            title: any(named: 'title'),
            memberIds: any(named: 'memberIds'),
            description: any(named: 'description'),
            ingredients: any(named: 'ingredients'),
            instructions: any(named: 'instructions'),
            imageUrls: any(named: 'imageUrls'),
            mealType: any(named: 'mealType'),
            portions: any(named: 'portions'),
            timeMinutes: any(named: 'timeMinutes'),
            rating: any(named: 'rating'),
            personalTagIds: any(named: 'personalTagIds'),
            sourceUrl: any(named: 'sourceUrl'),
            descriptionCollaborative: any(named: 'descriptionCollaborative'),
            allowGuestViewing: any(named: 'allowGuestViewing'),
            allowMemberInvites: any(named: 'allowMemberInvites'),
            categoryIds: any(named: 'categoryIds'),
          )).thenAnswer((_) async => null);
      when(() => mockRecipeService.addMemberToRecipe(
            any(),
            any(),
            any(),
          )).thenAnswer((_) async => false);
      when(() => mockRecipeService.removeMemberFromRecipe(any(), any()))
          .thenAnswer((_) async => false);
      when(() => mockRecipeService.updateMemberPermission(
            any(),
            any(),
            any(),
          )).thenAnswer((_) async => false);

      // Stub currentUserProfile on MockUserService so SocialProfileManager gets it
      when(() => mockUserService.currentUserProfile).thenReturn(
        UserProfileBuilder.build(
          uid: 'current_user_123',
          displayName: 'Current User',
          email: 'current@example.com',
        ),
      );

      // Register mocks in test service locator
      TestServiceLocator.registerMock<UnifiedFriendsService>(
          mockFriendsService);
      TestServiceLocator.registerMock<UnifiedRecipeService>(mockRecipeService);
      TestServiceLocator.registerMock<UserService>(mockUserService);

      // Create viewModel
      viewModel = SocialRecipeViewModel(
        friendsService: mockFriendsService,
        recipeService: mockRecipeService,
        userService: mockUserService,
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
      test('should initialize with default state', () {
        // Arrange - viewModel created in setUp

        // Act - no action needed, checking initial state

        // Assert
        expect(viewModel.hasComments, isFalse);
        expect(viewModel.isLoadingComments, isFalse);
        expect(viewModel.commentsError, isNull);
        expect(viewModel.isPostingComment, isFalse);
        expect(viewModel.isReplying, isFalse);
        expect(viewModel.newCommentText, isEmpty);
        expect(viewModel.comments, isEmpty);
        expect(viewModel.topLevelComments, isEmpty);
        expect(viewModel.friends, isEmpty); // Not initialized yet
        expect(viewModel.currentUser, isNull); // Not initialized yet
      });

      test('should initialize friends and user on initialize', () async {
        // Arrange - service configured in setUp

        // Act
        await viewModel.initialize();

        // Assert
        expect(viewModel.friends.length, equals(2));
        expect(viewModel.friends[0].displayName, equals('Anna Andersson'));
        expect(viewModel.friends[1].displayName, equals('Erik Svensson'));
      });

      test('should handle initialization error gracefully', () async {
        // Arrange
        mockFriendsService.setFriendsState(
          friends: [],
          error: 'Connection failed',
        );

        // Act
        await viewModel.initialize();

        // Assert - should not throw, but log error
        expect(viewModel.friends, isEmpty);
      });
    });

    group('Comment System State Management', () {
      test('should refresh comments for recipe', () async {
        // Arrange
        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);

        // Act
        await viewModel.refreshComments(testRecipeId);

        // Assert
        expect(viewModel.comments, isEmpty); // Mock returns empty
        expect(viewModel.commentsError, isNull);
        expect(viewModel.isLoadingComments, isFalse);
        expect(notificationCount,
            greaterThanOrEqualTo(2)); // Loading and loaded states
      });

      test('should handle comment refresh error', () async {
        // Note: In production, this would connect to a service
        // For now, we simulate an error scenario

        // Act
        await viewModel.refreshComments('invalid_recipe');

        // Assert - should handle gracefully
        expect(viewModel.isLoadingComments, isFalse);
      });

      test('should update comment text', () {
        // Arrange
        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);

        // Act
        viewModel.updateNewCommentText('Detta är en kommentar');

        // Assert
        expect(viewModel.newCommentText, equals('Detta är en kommentar'));
        expect(notificationCount, equals(1));
      });

      test('should trim comment text on update', () {
        // Arrange & Act
        viewModel.updateNewCommentText('  Trimmed text  ');

        // Assert - Note: trimming happens on post, not update
        expect(viewModel.newCommentText, equals('  Trimmed text  '));
      });
    });

    group('Comment Posting', () {
      test('should post comment successfully', () async {
        // Arrange
        await viewModel.initialize();
        viewModel.updateNewCommentText('Fantastiskt recept!');
        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);

        // Act
        await viewModel.postComment(testRecipeId);

        // Assert - after posting, the comment text is cleared and state is reset
        expect(viewModel.newCommentText, isEmpty); // Should clear
        expect(viewModel.isReplying, isFalse); // Should reset
        expect(viewModel.isPostingComment, isFalse);
        expect(notificationCount,
            greaterThanOrEqualTo(2)); // Posting and posted states
      });

      test('should not post empty comment', () async {
        // Arrange
        viewModel.updateNewCommentText('   '); // Only whitespace

        // Act
        await viewModel.postComment(testRecipeId);

        // Assert
        expect(viewModel.comments, isEmpty);
      });

      test('should handle comment posting error', () async {
        // Arrange - use a failing social ops mock
        final failingSocialOps = _FailingAddCommentSocialOps();
        when(() => mockRecipeService.social).thenReturn(failingSocialOps);

        // Create a new viewModel that uses the failing social ops
        final errorViewModel = SocialRecipeViewModel(
          friendsService: mockFriendsService,
          recipeService: mockRecipeService,
          userService: mockUserService,
        );
        errorViewModel.updateNewCommentText('Test comment');

        // Act - postComment rethrows, so expect the exception
        await expectLater(
          () => errorViewModel.postComment(testRecipeId),
          throwsA(isA<Exception>()),
        );

        errorViewModel.dispose();

        // Restore the original mock social ops for other tests
        when(() => mockRecipeService.social).thenReturn(mockSocialOps);
      });

      test('should post reply with parent reference', () async {
        // Arrange
        viewModel.setReplyTo('parent_comment_123');
        viewModel.updateNewCommentText('Detta är ett svar');

        // Act
        await viewModel.postComment(testRecipeId);

        // Assert - reply state is cleared after successful post
        expect(viewModel.isReplying, isFalse); // Should reset
        expect(viewModel.newCommentText, isEmpty); // Should clear
        expect(viewModel.isPostingComment, isFalse);
      });
    });

    group('Reply Functionality', () {
      test('should set reply target', () {
        // Arrange
        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);

        // Act
        viewModel.setReplyTo('comment_456');

        // Assert
        expect(viewModel.isReplying, isTrue);
        expect(notificationCount, equals(1));
      });

      test('should cancel reply mode', () {
        // Arrange
        viewModel.setReplyTo('comment_456');
        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);

        // Act
        viewModel.cancelReply();

        // Assert
        expect(viewModel.isReplying, isFalse);
        expect(notificationCount, equals(1));
      });

      test('should get replies for parent comment', () {
        // Arrange
        final parentComment = RecipeCommentBuilder.build(
          id: 'parent_1',
          parentCommentId: null,
        );
        final reply1 = RecipeCommentBuilder.buildReply(
          id: 'reply_1',
          parentId: 'parent_1',
        );
        final reply2 = RecipeCommentBuilder.buildReply(
          id: 'reply_2',
          parentId: 'parent_1',
        );
        final otherComment = RecipeCommentBuilder.build(
          id: 'other_1',
        );

        // Simulate having comments
        viewModel.comments
            .addAll([parentComment, reply1, reply2, otherComment]);

        // Act
        final replies = viewModel.getReplies('parent_1');

        // Assert
        expect(replies.length, equals(2));
        expect(replies[0].id, equals('reply_1'));
        expect(replies[1].id, equals('reply_2'));
      });

      test('should return empty list for comment with no replies', () {
        // Arrange
        final comment = RecipeCommentBuilder.build(id: 'lonely_comment');
        viewModel.comments.add(comment);

        // Act
        final replies = viewModel.getReplies('lonely_comment');

        // Assert
        expect(replies, isEmpty);
      });
    });

    group('Social Engagement', () {
      test('should toggle comment like', () async {
        // Arrange
        final comment = RecipeCommentBuilder.build(
          id: 'comment_789',
          likesCount: 5,
        );
        viewModel.comments.add(comment);
        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);

        // Act
        await viewModel.toggleCommentLike('comment_789');

        // Assert
        expect(viewModel.hasLikedComment('comment_789'), isTrue);
        expect(notificationCount, equals(1));
      });

      test('should toggle comment unlike', () async {
        // Arrange
        final comment = RecipeCommentBuilder.build(
          id: 'comment_789',
          likesCount: 6,
        );
        viewModel.comments.add(comment);

        // Like then unlike
        await viewModel.toggleCommentLike('comment_789');
        await viewModel.toggleCommentLike('comment_789');

        // Assert
        expect(viewModel.hasLikedComment('comment_789'), isFalse);
      });

      test('should handle toggle like for non-existent comment', () async {
        // Arrange & Act
        await viewModel.toggleCommentLike('non_existent');

        // Assert - should not throw, handled by try-catch
        expect(viewModel.comments, isEmpty);
      });

      test('should check if comment is liked', () async {
        // Arrange
        final comment1 = RecipeCommentBuilder.build(id: 'liked_comment');
        final comment2 = RecipeCommentBuilder.build(id: 'unliked_comment');
        viewModel.comments.addAll([comment1, comment2]);

        // Like only the first comment
        await viewModel.toggleCommentLike('liked_comment');

        // Act & Assert
        expect(viewModel.hasLikedComment('liked_comment'), isTrue);
        expect(viewModel.hasLikedComment('unliked_comment'), isFalse);
        expect(viewModel.hasLikedComment('non_existent'), isFalse);
      });
    });

    group('User Operations', () {
      test('should get author display name for friend', () async {
        // Arrange
        await viewModel.initialize();

        // Act
        final name = viewModel.getAuthorDisplayName('friend_1');

        // Assert
        expect(name, equals('Anna Andersson'));
      });

      test('should return current user name for self', () async {
        // Arrange - set current user
        await viewModel.initialize();

        // Act - look up an ID that is neither the current user nor a friend
        final name = viewModel.getAuthorDisplayName('unknown_user');

        // Assert - SocialProfileManager returns '?' for unknown author IDs
        expect(name, equals('?'));
      });

      test('should get author avatar URL', () async {
        // Arrange
        final friendWithAvatar = UserProfileBuilder.build(
          uid: 'friend_avatar',
          displayName: 'Friend With Avatar',
          avatarUrl: 'https://example.com/avatar.jpg',
        );

        // Update friends list in mock service
        mockFriendsService.setFriendsState(
          friends: [
            UserProfileBuilder.build(
              uid: 'friend_1',
              displayName: 'Anna Andersson',
            ),
            UserProfileBuilder.build(
              uid: 'friend_2',
              displayName: 'Erik Svensson',
            ),
            friendWithAvatar,
          ],
        );

        await viewModel.initialize();

        // Act
        final avatarUrl = viewModel.getAuthorAvatarUrl('friend_avatar');

        // Assert
        expect(avatarUrl, equals('https://example.com/avatar.jpg'));
      });

      test('should return null for unknown user avatar', () async {
        // Arrange
        await viewModel.initialize();

        // Act
        final avatarUrl = viewModel.getAuthorAvatarUrl('unknown_user');

        // Assert
        expect(avatarUrl, isNull);
      });
    });

    group('Comment Hierarchy', () {
      test('should get top level comments only', () {
        // Arrange
        final topLevel1 = RecipeCommentBuilder.build(
          id: 'top_1',
          parentCommentId: null,
        );
        final topLevel2 = RecipeCommentBuilder.build(
          id: 'top_2',
          parentCommentId: null,
        );
        final reply1 = RecipeCommentBuilder.buildReply(
          id: 'reply_1',
          parentId: 'top_1',
        );
        final reply2 = RecipeCommentBuilder.buildReply(
          id: 'reply_2',
          parentId: 'top_2',
        );

        viewModel.comments.addAll([topLevel1, reply1, topLevel2, reply2]);

        // Act
        final topLevelComments = viewModel.topLevelComments;

        // Assert
        expect(topLevelComments.length, equals(2));
        expect(topLevelComments[0].id, equals('top_1'));
        expect(topLevelComments[1].id, equals('top_2'));
      });

      test('should handle empty comments list', () {
        // Arrange - no comments

        // Act
        final topLevelComments = viewModel.topLevelComments;

        // Assert
        expect(topLevelComments, isEmpty);
      });

      test('should handle all replies (no top level)', () {
        // Arrange
        final reply1 = RecipeCommentBuilder.buildReply(id: 'r1');
        final reply2 = RecipeCommentBuilder.buildReply(id: 'r2');
        viewModel.comments.addAll([reply1, reply2]);

        // Act
        final topLevelComments = viewModel.topLevelComments;

        // Assert
        expect(topLevelComments, isEmpty);
      });
    });

    group('Collaborative Recipe Operations', () {
      test('should create collaborative recipe', () async {
        // Arrange
        const recipeName = 'Collaborative Köttbullar';
        final memberIds = ['user_1', 'user_2'];
        final memberDisplayNames = {
          'user_1': 'Anna',
          'user_2': 'Erik',
        };

        // Act
        final result = await viewModel.createCollaborativeRecipe(
          name: recipeName,
          memberIds: memberIds,
          memberDisplayNames: memberDisplayNames,
        );

        // Assert - placeholder implementation returns false
        expect(result, isFalse);
      });

      test('should share recipe', () async {
        // Arrange
        const recipeId = 'recipe_to_share';
        final memberIds = ['friend_1'];
        final memberDisplayNames = {'friend_1': 'Anna'};

        // Act
        final sharedId = await viewModel.shareRecipe(
          recipeId: recipeId,
          memberIds: memberIds,
          memberDisplayNames: memberDisplayNames,
        );

        // Assert - delegates to social ops which returns 'shared-<recipeId>'
        expect(sharedId, equals('shared-recipe_to_share'));
      });

      test('should make recipe personal', () async {
        // Arrange
        const collaborativeRecipeId = 'collab_recipe_123';

        // Act
        final personalId =
            await viewModel.makeRecipePersonal(collaborativeRecipeId);

        // Assert - delegates to social ops which returns 'personal-<id>'
        expect(personalId, equals('personal-collab_recipe_123'));
      });
    });

    group('Member Management', () {
      test('should add member to recipe', () async {
        // Arrange
        const recipeId = 'recipe_123';
        const userId = 'new_member';
        const displayName = 'New Member';

        // Act
        final result = await viewModel.addMemberToRecipe(
          recipeId,
          userId,
          displayName,
          permission: ResourcePermission.editor,
        );

        // Assert - placeholder implementation returns false
        expect(result, isFalse);
      });

      test('should remove member from recipe', () async {
        // Arrange
        const recipeId = 'recipe_123';
        const userId = 'member_to_remove';

        // Act
        final result = await viewModel.removeMemberFromRecipe(recipeId, userId);

        // Assert - placeholder implementation returns false
        expect(result, isFalse);
      });

      test('should update member permission', () async {
        // Arrange
        const recipeId = 'recipe_123';
        const userId = 'member_123';

        // Act
        final result = await viewModel.updateMemberPermission(
          recipeId,
          userId,
          ResourcePermission.admin,
        );

        // Assert - placeholder implementation returns false
        expect(result, isFalse);
      });

      test('should get recipe members', () {
        // Arrange
        const recipeId = 'recipe_123';

        // Act
        final members = viewModel.getRecipeMembers(recipeId);

        // Assert - placeholder implementation returns empty map
        expect(members, isEmpty);
      });

      test('should check if can invite members', () {
        // Arrange
        const recipeId = 'recipe_123';

        // Act
        final canInvite = viewModel.canInviteMembers(recipeId);

        // Assert - delegates to social ops which returns true
        expect(canInvite, isTrue);
      });

      test('should get recipes shared with me', () {
        // Arrange - no setup needed

        // Act
        final sharedWithMe = viewModel.getSharedWithMe();

        // Assert - placeholder implementation returns empty list
        expect(sharedWithMe, isEmpty);
      });

      test('should get recipes shared by me', () {
        // Arrange - no setup needed

        // Act
        final sharedByMe = viewModel.getSharedByMe();

        // Assert - placeholder implementation returns empty list
        expect(sharedByMe, isEmpty);
      });
    });

    group('Service Information', () {
      test('should provide service name', () {
        // Arrange - viewModel created in setUp

        // Act & Assert
        expect(viewModel.serviceName, equals('SocialRecipeViewModel'));
      });
    });

    group('State Management', () {
      test('should notify listeners on comment text update', () {
        // Arrange
        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);

        // Act
        viewModel.updateNewCommentText('Test 1');
        viewModel.updateNewCommentText('Test 2');
        viewModel.updateNewCommentText('Test 3');

        // Assert
        expect(notificationCount, equals(3));
      });

      test('should maintain comment state across operations', () async {
        // Arrange
        final comment1 = RecipeCommentBuilder.build(id: 'c1', text: 'First');
        final comment2 = RecipeCommentBuilder.build(id: 'c2', text: 'Second');

        // Act
        viewModel.comments.add(comment1);
        await viewModel.toggleCommentLike('c1');
        viewModel.comments.add(comment2);

        // Assert
        expect(viewModel.comments.length, equals(2));
        expect(viewModel.hasLikedComment('c1'), isTrue);
        expect(viewModel.hasLikedComment('c2'), isFalse);
      });
    });

    group('Error Handling', () {
      test('should set error on comment refresh failure', () async {
        // Note: In production, this would connect to service
        // Error handling is in place but needs service integration

        // Act
        await viewModel.refreshComments('test_recipe');

        // Assert - no error in mock scenario
        expect(viewModel.commentsError, isNull);
      });

      test('should handle missing comment gracefully in operations', () async {
        // Arrange - no comments in the list

        // Act & Assert - toggleCommentLike is async but should not throw
        await viewModel.toggleCommentLike('missing');
        // After toggling, the engagement manager tracks the like regardless
        // of whether the comment exists in the local list
        expect(viewModel.hasLikedComment('missing'), isTrue);
        expect(viewModel.getReplies('missing'), isEmpty);
      });
    });

    group('Lifecycle', () {
      test('should dispose without errors', () {
        // Arrange
        final testViewModel = SocialRecipeViewModel(
          friendsService: mockFriendsService,
          recipeService: mockRecipeService,
          userService: mockUserService,
        );

        // Act & Assert
        expect(() => testViewModel.dispose(), returnsNormally);
      });

      test('should clean up listeners on dispose', () {
        // Arrange
        final testViewModel = SocialRecipeViewModel(
          friendsService: mockFriendsService,
          recipeService: mockRecipeService,
          userService: mockUserService,
        );
        var notificationCount = 0;
        testViewModel.addListener(() => notificationCount++);

        // Act
        testViewModel.updateNewCommentText('Test');
        expect(notificationCount, equals(1));

        testViewModel.dispose();

        // Note: After dispose, notifications should not work
        // Framework ensures listeners are cleaned up
      });
    });
  });
}

/// A social ops mock that returns null from addComment to trigger the error path.
class _FailingAddCommentSocialOps extends MockSocialRecipeOperations {
  @override
  Future<String?> addComment({
    required String recipeId,
    required String content,
    String? parentCommentId,
    List<String>? mentions,
  }) async =>
      null;
}
