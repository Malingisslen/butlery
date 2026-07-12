// test/unit/viewmodels/social_recipe_viewmodel_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/social_recipe_viewmodel.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/recipe_comment.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/moderation/content_filter_service.dart';
import 'package:butlery/repositories/interfaces/comments_repository.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;

// ---- Helpers ---------------------------------------------------------------

UserProfile _user({
  String uid = 'test-user-123',
  String displayName = 'Test User',
  String email = 'test@example.com',
  String? avatarUrl,
}) {
  final now = DateTime.now();
  return UserProfile(
    uid: uid,
    displayName: displayName,
    email: email,
    avatarUrl: avatarUrl,
    // MATURED account: the BUT-1419 comment gate blocks accounts younger
    // than 60 min, and this suite tests posting behavior, not the gate
    // (the gate's own contract lives in social_comments_manager_test).
    joinedAt: now.subtract(const Duration(hours: 2)),
    lastActiveAt: now,
  );
}

RecipeComment _comment({
  String? id,
  String recipeId = 'recipe_123',
  String authorId = 'user_123',
  String text = 'Test comment',
  String? parentCommentId,
  int likesCount = 0,
}) {
  return RecipeComment(
    id: id ?? 'comment_${DateTime.now().microsecondsSinceEpoch}',
    recipeId: recipeId,
    authorId: authorId,
    authorDisplayName: 'Test Author',
    text: text,
    createdAt: DateTime.now(),
    parentCommentId: parentCommentId,
    likesCount: likesCount,
  );
}

// ---- Tests -----------------------------------------------------------------

void main() {
  group('SocialRecipeViewModel', () {
    late SocialRecipeViewModel viewModel;
    late MockUnifiedFriendsService mockFriendsService;
    late MockUnifiedRecipeService mockRecipeService;
    late MockUserService mockUserService;
    late FakePermissionService mockPermissionService;

    const testRecipeId = 'test_recipe_123';

    setUpAll(() async {
      await TestServiceLocator.initialize();
      // Bridge production ServiceLocator for SocialCommentsManager / SocialEngagementManager
      production.ServiceLocator.initialize(DIContainer());
      registerFallbackValue(_user());
      registerFallbackValue(_comment());
      registerFallbackValue(ResourcePermission.viewer);
    });

    setUp(() async {
      await TestServiceLocator.initialize();
      // Re-bridge after reset (reset clears GetIt)
      production.ServiceLocator.initialize(DIContainer());

      mockFriendsService = MockUnifiedFriendsService();
      mockRecipeService = MockUnifiedRecipeService();
      mockUserService = MockUserService();
      mockPermissionService = FakePermissionService();

      // Register PermissionService so SocialEngagementManager finds it
      mockPermissionService.setPermissionState(
        currentUserId: 'current_user_123',
        isAuthenticated: true,
      );
      TestServiceLocator.registerMock<PermissionService>(mockPermissionService);

      // SocialEngagementManager.toggleCommentLike eventually calls
      // CommentLikesSystem.toggleCommentLike, which reads CommentsRepository
      // from GetIt via a static field. Without a registration the call
      // throws → returns null → the manager rolls back its optimistic
      // local add → hasLikedComment returns false. Register a minimal
      // stub so the persistence path succeeds.
      final mockCommentsRepo = MockCommentsRepository();
      when(
        () => mockCommentsRepo.hasUserLikedComment(any(), any()),
      ).thenAnswer((_) async => false);
      when(
        () => mockCommentsRepo.toggleCommentLike(any(), any()),
      ).thenAnswer((_) async {});
      TestServiceLocator.registerMock<CommentsRepository>(mockCommentsRepo);

      // Configure friends via state setter (concrete override — no when())
      mockFriendsService.setFriendsState(
        friends: [
          _user(uid: 'friend_1', displayName: 'Anna Andersson'),
          _user(uid: 'friend_2', displayName: 'Erik Svensson'),
        ],
        isInitialized: true,
        isLoading: false,
        error: null,
      );

      // Configure user via state setter
      mockUserService.setUserState(
        currentUser: _user(
          uid: 'current_user_123',
          displayName: 'Current User',
        ),
      );

      // currentUserProfile is NOT concrete on MockUserService — stub it
      when(() => mockUserService.currentUserProfile).thenReturn(
        _user(uid: 'current_user_123', displayName: 'Current User'),
      );

      // social getter is concrete on MockUnifiedRecipeService (returns _mockSocial).
      // Do NOT use when() on it. Access via mockRecipeService.mockSocial instead.

      // Register mocks in test service locator
      TestServiceLocator.registerMock<UnifiedFriendsService>(
        mockFriendsService,
      );
      TestServiceLocator.registerMock<UnifiedRecipeService>(mockRecipeService);
      TestServiceLocator.registerMock<UserService>(mockUserService);

      viewModel = SocialRecipeViewModel(
        friendsService: mockFriendsService,
        recipeService: mockRecipeService,
        userService: mockUserService,
      );
    });

    tearDown(() async {
      viewModel.dispose();
      await TestServiceLocator.reset();
    });

    // -- Initialization ------------------------------------------------------

    group('Initialization', () {
      test('should have default empty state', () {
        expect(viewModel.hasComments, isFalse);
        expect(viewModel.isLoadingComments, isFalse);
        expect(viewModel.commentsError, isNull);
        expect(viewModel.isPostingComment, isFalse);
        expect(viewModel.isReplying, isFalse);
        expect(viewModel.newCommentText, isEmpty);
        expect(viewModel.comments, isEmpty);
        expect(viewModel.topLevelComments, isEmpty);
        expect(viewModel.friends, isEmpty);
        expect(viewModel.currentUser, isNull);
      });

      test('should load friends and user on initialize', () async {
        await viewModel.initialize();

        expect(viewModel.friends.length, equals(2));
        expect(viewModel.friends[0].displayName, equals('Anna Andersson'));
        expect(viewModel.friends[1].displayName, equals('Erik Svensson'));
      });

      test('should handle initialization error gracefully', () async {
        mockFriendsService.setFriendsState(
          friends: [],
          error: 'Connection failed',
        );

        await viewModel.initialize();
        expect(viewModel.friends, isEmpty);
      });
    });

    // -- Comment State -------------------------------------------------------

    group('Comment State', () {
      test('should refresh comments for recipe', () async {
        var notifications = 0;
        viewModel.addListener(() => notifications++);

        await viewModel.refreshComments(testRecipeId);

        expect(viewModel.comments, isEmpty);
        expect(viewModel.commentsError, isNull);
        expect(viewModel.isLoadingComments, isFalse);
        expect(notifications, greaterThanOrEqualTo(2));
      });

      test('should handle refresh for unknown recipe', () async {
        await viewModel.refreshComments('unknown');
        expect(viewModel.isLoadingComments, isFalse);
      });

      test('should update comment text and notify', () {
        var notifications = 0;
        viewModel.addListener(() => notifications++);

        viewModel.updateNewCommentText('Ny kommentar');
        expect(viewModel.newCommentText, equals('Ny kommentar'));
        expect(notifications, equals(1));
      });

      test('should preserve whitespace on update (trimmed on post)', () {
        viewModel.updateNewCommentText('  spaces  ');
        expect(viewModel.newCommentText, equals('  spaces  '));
      });
    });

    // -- Posting Comments ----------------------------------------------------

    group('Comment Posting', () {
      test('should post comment and clear state', () async {
        await viewModel.initialize();
        viewModel.updateNewCommentText('Fantastiskt recept!');

        var notifications = 0;
        viewModel.addListener(() => notifications++);

        await viewModel.postComment(testRecipeId);

        expect(viewModel.newCommentText, isEmpty);
        expect(viewModel.isReplying, isFalse);
        expect(viewModel.isPostingComment, isFalse);
        expect(notifications, greaterThanOrEqualTo(2));
      });

      test('should not post empty comment', () async {
        viewModel.updateNewCommentText('   ');
        await viewModel.postComment(testRecipeId);
        expect(viewModel.comments, isEmpty);
      });

      test('rejects a profane comment at the gate (BUT-1393)', () async {
        // Register the real content filter so the profanity gate is active, then
        // build a fresh VM — SocialCommentsManager captures ContentFilterService
        // in its constructor, so it must exist before construction.
        TestServiceLocator.registerMock<ContentFilterService>(
          ContentFilterService(),
        );
        final vm = SocialRecipeViewModel(
          friendsService: mockFriendsService,
          recipeService: mockRecipeService,
          userService: mockUserService,
        );
        // 'fan' is on the Swedish profanity list (see content_filter_service_test).
        vm.updateNewCommentText('din jävla fan');

        await vm.postComment(testRecipeId);

        // Blocked before any service write: error surfaced, text NOT cleared
        // (a successful post clears it), posting flag reset.
        expect(vm.commentsError, isNotNull);
        expect(vm.newCommentText, equals('din jävla fan'));
        expect(vm.isPostingComment, isFalse);
        vm.dispose();
      });

      test('should post reply with parent reference then clear', () async {
        viewModel.setReplyTo('parent_123');
        viewModel.updateNewCommentText('Svar!');

        await viewModel.postComment(testRecipeId);

        expect(viewModel.isReplying, isFalse);
        expect(viewModel.newCommentText, isEmpty);
      });

      test('should rethrow when addComment returns null', () async {
        // Configure the built-in mockSocial to return null (failure path)
        final failingSocial = _NullAddCommentSocialOps();
        // Since social is concrete, we need a local recipe service mock
        final localRecipeService = _MockRecipeServiceWithSocial(failingSocial);
        final vm = SocialRecipeViewModel(
          friendsService: mockFriendsService,
          recipeService: localRecipeService,
          userService: mockUserService,
        );
        vm.updateNewCommentText('Test');

        await expectLater(
          () => vm.postComment(testRecipeId),
          throwsA(isA<Exception>()),
        );
        vm.dispose();
      });
    });

    // -- Reply Functionality -------------------------------------------------

    group('Reply Functionality', () {
      test('should set reply target', () {
        var n = 0;
        viewModel.addListener(() => n++);

        viewModel.setReplyTo('comment_456');
        expect(viewModel.isReplying, isTrue);
        expect(n, equals(1));
      });

      test('should cancel reply mode', () {
        viewModel.setReplyTo('comment_456');
        var n = 0;
        viewModel.addListener(() => n++);

        viewModel.cancelReply();
        expect(viewModel.isReplying, isFalse);
        expect(n, equals(1));
      });

      test('should filter replies for parent', () {
        viewModel.comments.addAll([
          _comment(id: 'top_1'),
          _comment(id: 'reply_a', parentCommentId: 'top_1'),
          _comment(id: 'reply_b', parentCommentId: 'top_1'),
          _comment(id: 'other'),
        ]);

        final replies = viewModel.getReplies('top_1');
        expect(replies.length, equals(2));
        expect(replies[0].id, equals('reply_a'));
        expect(replies[1].id, equals('reply_b'));
      });

      test('should return empty for comment with no replies', () {
        viewModel.comments.add(_comment(id: 'lonely'));
        expect(viewModel.getReplies('lonely'), isEmpty);
      });
    });

    // -- Social Engagement ---------------------------------------------------

    group('Social Engagement', () {
      test('should toggle comment like (optimistic)', () async {
        viewModel.comments.add(_comment(id: 'c_1', likesCount: 5));

        var n = 0;
        viewModel.addListener(() => n++);

        await viewModel.toggleCommentLike('c_1');
        expect(viewModel.hasLikedComment('c_1'), isTrue);
        expect(n, greaterThanOrEqualTo(1));
      });

      test('should toggle unlike', () async {
        viewModel.comments.add(_comment(id: 'c_2'));

        await viewModel.toggleCommentLike('c_2');
        expect(viewModel.hasLikedComment('c_2'), isTrue);

        await viewModel.toggleCommentLike('c_2');
        expect(viewModel.hasLikedComment('c_2'), isFalse);
      });

      test('should handle toggle for non-existent comment', () async {
        await viewModel.toggleCommentLike('missing');
        // Engagement manager tracks likes regardless of comment list membership
        expect(viewModel.hasLikedComment('missing'), isTrue);
      });

      test('should track per-comment like state', () async {
        viewModel.comments.addAll([
          _comment(id: 'liked'),
          _comment(id: 'not_liked'),
        ]);

        await viewModel.toggleCommentLike('liked');

        expect(viewModel.hasLikedComment('liked'), isTrue);
        expect(viewModel.hasLikedComment('not_liked'), isFalse);
        expect(viewModel.hasLikedComment('unknown'), isFalse);
      });
    });

    // -- User Operations -----------------------------------------------------

    group('User Operations', () {
      test('should get friend display name', () async {
        await viewModel.initialize();
        expect(
          viewModel.getAuthorDisplayName('friend_1'),
          equals('Anna Andersson'),
        );
      });

      test('should return ? for unknown user', () async {
        await viewModel.initialize();
        expect(viewModel.getAuthorDisplayName('unknown'), equals('?'));
      });

      test('should get friend avatar URL', () async {
        mockFriendsService.setFriendsState(
          friends: [
            _user(
              uid: 'f_avatar',
              displayName: 'With Avatar',
              avatarUrl: 'https://example.com/avatar.jpg',
            ),
          ],
        );
        await viewModel.initialize();

        expect(
          viewModel.getAuthorAvatarUrl('f_avatar'),
          equals('https://example.com/avatar.jpg'),
        );
      });

      test('should return null avatar for unknown user', () async {
        await viewModel.initialize();
        expect(viewModel.getAuthorAvatarUrl('unknown'), isNull);
      });
    });

    // -- Comment Hierarchy ---------------------------------------------------

    group('Comment Hierarchy', () {
      test('should filter top-level comments only', () {
        viewModel.comments.addAll([
          _comment(id: 't1'),
          _comment(id: 'r1', parentCommentId: 't1'),
          _comment(id: 't2'),
          _comment(id: 'r2', parentCommentId: 't2'),
        ]);

        final top = viewModel.topLevelComments;
        expect(top.length, equals(2));
        expect(top[0].id, equals('t1'));
        expect(top[1].id, equals('t2'));
      });

      test('should return empty when no comments', () {
        expect(viewModel.topLevelComments, isEmpty);
      });

      test('should return empty when all are replies', () {
        viewModel.comments.addAll([
          _comment(id: 'r1', parentCommentId: 'p'),
          _comment(id: 'r2', parentCommentId: 'p'),
        ]);
        expect(viewModel.topLevelComments, isEmpty);
      });
    });

    // -- Collaborative Recipe Operations -------------------------------------

    group('Collaborative Recipe Operations', () {
      test(
        'should create collaborative recipe (delegates to service)',
        () async {
          // createCollaborativeRecipe is concrete on MockUnifiedRecipeService,
          // returns null by default (collaborativeShouldSucceed=false)
          final result = await viewModel.createCollaborativeRecipe(
            name: 'Collab',
            memberIds: ['u1', 'u2'],
            memberDisplayNames: {'u1': 'A', 'u2': 'B'},
          );
          expect(result, isFalse);
        },
      );

      test('should share recipe (delegates to social ops)', () async {
        // social.shareRecipe is concrete on FakeSocialRecipeOperations:
        // returns 'shared-<recipeId>'
        final id = await viewModel.shareRecipe(
          recipeId: 'r1',
          memberIds: ['f1'],
          memberDisplayNames: {'f1': 'Anna'},
        );
        expect(id, equals('shared-r1'));
      });

      test('should make recipe personal (delegates to social ops)', () async {
        final id = await viewModel.makeRecipePersonal('collab_1');
        expect(id, equals('personal-collab_1'));
      });
    });

    // -- Member Management ---------------------------------------------------

    group('Member Management', () {
      test('should add member', () async {
        when(
          () => mockRecipeService.addMemberToRecipe(any(), any(), any()),
        ).thenAnswer((_) async => false);
        final result = await viewModel.addMemberToRecipe(
          'r',
          'u',
          'User',
          permission: ResourcePermission.editor,
        );
        expect(result, isFalse);
      });

      test('should remove member', () async {
        when(
          () => mockRecipeService.removeMemberFromRecipe(any(), any()),
        ).thenAnswer((_) async => false);
        final result = await viewModel.removeMemberFromRecipe('r', 'u');
        expect(result, isFalse);
      });

      test('should update member permission', () async {
        when(
          () => mockRecipeService.updateMemberPermission(any(), any(), any()),
        ).thenAnswer((_) async => false);
        final result = await viewModel.updateMemberPermission(
          'r',
          'u',
          ResourcePermission.admin,
        );
        expect(result, isFalse);
      });

      test('should get recipe members (placeholder)', () {
        expect(viewModel.getRecipeMembers('r'), isEmpty);
      });

      test('should check if can invite members', () {
        // Concrete override on FakeSocialRecipeOperations returns true
        expect(viewModel.canInviteMembers('r'), isTrue);
      });

      test('should get shared with me (placeholder)', () {
        expect(viewModel.getSharedWithMe(), isEmpty);
      });

      test('should get shared by me (placeholder)', () {
        expect(viewModel.getSharedByMe(), isEmpty);
      });
    });

    // -- Service Info --------------------------------------------------------

    group('Service Info', () {
      test('should provide service name', () {
        expect(viewModel.serviceName, equals('SocialRecipeViewModel'));
      });
    });

    // -- State Notifications -------------------------------------------------

    group('State Notifications', () {
      test('should notify on each comment text update', () {
        var n = 0;
        viewModel.addListener(() => n++);

        viewModel.updateNewCommentText('A');
        viewModel.updateNewCommentText('B');
        viewModel.updateNewCommentText('C');
        expect(n, equals(3));
      });

      test('should maintain like state across operations', () async {
        viewModel.comments.addAll([
          _comment(id: 'c1', text: 'First'),
          _comment(id: 'c2', text: 'Second'),
        ]);

        await viewModel.toggleCommentLike('c1');

        expect(viewModel.hasLikedComment('c1'), isTrue);
        expect(viewModel.hasLikedComment('c2'), isFalse);
      });
    });

    // -- Error Handling ------------------------------------------------------

    group('Error Handling', () {
      test('should have no error after successful refresh', () async {
        await viewModel.refreshComments(testRecipeId);
        expect(viewModel.commentsError, isNull);
      });

      test('should handle missing comment in operations', () async {
        await viewModel.toggleCommentLike('missing');
        expect(viewModel.hasLikedComment('missing'), isTrue);
        expect(viewModel.getReplies('missing'), isEmpty);
      });
    });

    // -- Lifecycle ------------------------------------------------------------

    group('Lifecycle', () {
      test('should dispose without errors', () {
        final vm = SocialRecipeViewModel(
          friendsService: mockFriendsService,
          recipeService: mockRecipeService,
          userService: mockUserService,
        );
        expect(() => vm.dispose(), returnsNormally);
      });

      test('should stop notifying after dispose', () {
        final vm = SocialRecipeViewModel(
          friendsService: mockFriendsService,
          recipeService: mockRecipeService,
          userService: mockUserService,
        );
        var n = 0;
        vm.addListener(() => n++);
        vm.updateNewCommentText('Before');
        expect(n, equals(1));
        vm.dispose();
      });
    });
  });
}

// ---------------------------------------------------------------------------
// Local helpers for test-specific mock behavior
// ---------------------------------------------------------------------------

/// Social ops that returns null from addComment to trigger the error path.
class _NullAddCommentSocialOps extends FakeSocialRecipeOperations {
  @override
  Future<String?> addComment({
    required String recipeId,
    required String content,
    String? parentCommentId,
    List<String>? mentions,
    List<String> imageUrls = const [],
  }) async => null;
}

/// Recipe service with injectable social ops (bypasses the concrete getter).
class _MockRecipeServiceWithSocial extends MockUnifiedRecipeService {
  final FakeSocialRecipeOperations _social;
  _MockRecipeServiceWithSocial(this._social);

  @override
  FakeSocialRecipeOperations get social => _social;
}
