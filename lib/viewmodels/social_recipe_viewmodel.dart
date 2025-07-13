// lib/viewmodels/social_recipe_viewmodel.dart

import 'package:flutter/foundation.dart';
import '../models/recipe.dart';
import '../models/user_profile.dart';
import '../models/recipe_comment.dart';
import '../services/social_recipe_service.dart';
import '../services/friends_service.dart';
import '../services/user_service.dart';
import '../core/utils/logger.dart'; // Fixad import


class SocialRecipeViewModel extends ChangeNotifier {
  final Recipe _recipe;
  final SocialRecipeService _socialRecipeService;
  final FriendsService _friendsService;
  final UserService _userService;

  // Comments state
  List<RecipeComment> _comments = [];
  bool _isLoadingComments = false;
  String? _commentsError;

  // Sharing state
  bool _isSharing = false;
  String? _sharingError;
  final Set<String> _selectedFriendIds = {};

  // Comment form state
  String _newCommentText = '';
  String? _replyToCommentId;
  bool _isPostingComment = false;

  SocialRecipeViewModel({
    required Recipe recipe,
    required SocialRecipeService socialRecipeService,
    required FriendsService friendsService,
    required UserService userService,
  })  : _recipe = recipe,
        _socialRecipeService = socialRecipeService,
        _friendsService = friendsService,
        _userService = userService {
    _loadComments();
    _socialRecipeService.addListener(_onSocialServiceChanged);
    _friendsService.addListener(_onFriendsServiceChanged);
  }

  // ===== GETTERS =====

  Recipe get recipe => _recipe;
  List<RecipeComment> get comments => List.unmodifiable(_comments);
  bool get isLoadingComments => _isLoadingComments;
  String? get commentsError => _commentsError;
  bool get hasComments => _comments.isNotEmpty;

  bool get isSharing => _isSharing;
  String? get sharingError => _sharingError;
  Set<String> get selectedFriendIds => Set.unmodifiable(_selectedFriendIds);
  bool get hasSelectedFriends => _selectedFriendIds.isNotEmpty;

  String get newCommentText => _newCommentText;
  String? get replyToCommentId => _replyToCommentId;
  bool get isPostingComment => _isPostingComment;
  bool get isReplying => _replyToCommentId != null;

  List<UserProfile> get friends => _friendsService.friends;
  UserProfile? get currentUser => _userService.currentUserProfile;

  // Comment filtering
  List<RecipeComment> get topLevelComments =>
      _comments.where((c) => c.isTopLevel).toList();

  List<RecipeComment> getReplies(String parentCommentId) =>
      _comments.where((c) => c.parentCommentId == parentCommentId).toList();

  // ===== SHARING ACTIONS =====

  /// Toggle friend selection for sharing
  void toggleFriendSelection(String friendId) {
    if (_selectedFriendIds.contains(friendId)) {
      _selectedFriendIds.remove(friendId);
    } else {
      _selectedFriendIds.add(friendId);
    }
    notifyListeners();
  }

  /// Select all friends
  void selectAllFriends() {
    _selectedFriendIds.clear();
    _selectedFriendIds.addAll(friends.map((f) => f.uid));
    notifyListeners();
  }

  /// Clear friend selection
  void clearFriendSelection() {
    _selectedFriendIds.clear();
    notifyListeners();
  }

  /// Share recipe to selected friends
  Future<bool> shareRecipe({String? message}) async {
    if (_selectedFriendIds.isEmpty) {
      _sharingError = 'Välj minst en vän att dela med';
      notifyListeners();
      return false;
    }

    try {
      _isSharing = true;
      _sharingError = null;
      notifyListeners();

      final success = await _socialRecipeService.shareRecipeToFriends(
        recipe: _recipe,
        friendUserIds: _selectedFriendIds.toList(),
        message: message,
      );

      if (success) {
        _selectedFriendIds.clear();
        AppLogger.success(
          '✅ Recept delat med ${_selectedFriendIds.length} vänner',
        );
      } else {
        _sharingError = _socialRecipeService.error ?? 'Kunde inte dela recept';
      }

      return success;
    } catch (e) {
      _sharingError = 'Kunde inte dela recept: $e';
      AppLogger.error('Share recipe failed', e);
      return false;
    } finally {
      _isSharing = false;
      notifyListeners();
    }
  }

  // ===== COMMENT ACTIONS =====

  /// Update new comment text
  void updateNewCommentText(String text) {
    _newCommentText = text;
    notifyListeners();
  }

  /// Set reply target
  void setReplyTo(String? commentId) {
    _replyToCommentId = commentId;
    notifyListeners();
  }

  /// Cancel reply
  void cancelReply() {
    _replyToCommentId = null;
    notifyListeners();
  }

  /// Post new comment or reply
  Future<bool> postComment() async {
    if (_newCommentText.trim().isEmpty) {
      return false;
    }

    try {
      _isPostingComment = true;
      notifyListeners();

      final success = await _socialRecipeService.addComment(
        recipeId: _recipe.id,
        text: _newCommentText.trim(),
        parentCommentId: _replyToCommentId,
      );

      if (success) {
        _newCommentText = '';
        _replyToCommentId = null;
        await _loadComments(); // Refresh comments
        AppLogger.success('✅ Kommentar postad');
      }

      return success;
    } catch (e) {
      AppLogger.error('Post comment failed', e);
      return false;
    } finally {
      _isPostingComment = false;
      notifyListeners();
    }
  }

  /// Edit existing comment
  Future<bool> editComment(String commentId, String newText) async {
    final success = await _socialRecipeService.editComment(commentId, newText);

    if (success) {
      await _loadComments(); // Refresh to show edit
    }

    return success;
  }

  /// Delete comment
  Future<bool> deleteComment(String commentId) async {
    final success = await _socialRecipeService.deleteComment(commentId);

    if (success) {
      await _loadComments(); // Refresh to show deletion
    }

    return success;
  }

  /// Toggle like on comment
  Future<bool> toggleCommentLike(String commentId) async {
    final success = await _socialRecipeService.toggleCommentLike(commentId);

    if (success) {
      // Update local comment state optimistically
      final commentIndex = _comments.indexWhere((c) => c.id == commentId);
      if (commentIndex >= 0) {
        final comment = _comments[commentIndex];
        final currentUserId = _userService.currentUserId;

        if (currentUserId != null) {
          final isLiked = comment.isLikedBy(currentUserId);
          _comments[commentIndex] = isLiked
              ? comment.removeLike(currentUserId)
              : comment.addLike(currentUserId);
          notifyListeners();
        }
      }
    }

    return success;
  }

  /// Check if current user can edit comment
  bool canEditComment(RecipeComment comment) {
    final currentUserId = _userService.currentUserId;
    return currentUserId != null && comment.canBeEditedBy(currentUserId);
  }

  /// Check if current user has liked comment
  bool hasLikedComment(RecipeComment comment) {
    final currentUserId = _userService.currentUserId;
    return currentUserId != null && comment.isLikedBy(currentUserId);
  }

  // ===== PRIVATE METHODS =====

  Future<void> _loadComments() async {
    try {
      _isLoadingComments = true;
      _commentsError = null;
      notifyListeners();

      final comments = await _socialRecipeService.getRecipeComments(_recipe.id);

      // Sort comments: top-level first (newest first), then replies by date
      _comments = List.from(comments);
      _comments.sort((a, b) {
        // Top-level comments first
        if (a.isTopLevel && !b.isTopLevel) return -1;
        if (!a.isTopLevel && b.isTopLevel) return 1;

        // Within same level, sort by date (newest first for top-level, oldest first for replies)
        if (a.isTopLevel && b.isTopLevel) {
          return b.createdAt.compareTo(a.createdAt);
        } else {
          return a.createdAt.compareTo(b.createdAt);
        }
      });

      AppLogger.info('💬 ${_comments.length} kommentarer laddade för recept');
    } catch (e) {
      _commentsError = 'Kunde inte ladda kommentarer: $e';
      AppLogger.error('Load comments failed', e);
    } finally {
      _isLoadingComments = false;
      notifyListeners();
    }
  }

  void _onSocialServiceChanged() {
    notifyListeners();
  }

  void _onFriendsServiceChanged() {
    notifyListeners();
  }

  /// Clear all errors
  void clearErrors() {
    _commentsError = null;
    _sharingError = null;
    notifyListeners();
  }

  /// Refresh comments
  Future<void> refreshComments() async {
    await _loadComments();
  }

  /// Get display name for comment author
  String getAuthorDisplayName(RecipeComment comment) {
    // Use cached display name from comment first
    if (comment.authorDisplayName.isNotEmpty) {
      return comment.authorDisplayName;
    }

    // Fallback to friends list lookup
    final friend = friends.firstWhere(
      (f) => f.uid == comment.authorId,
      orElse: () => UserProfile(
        uid: comment.authorId,
        displayName: 'Användare',
        email: '',
        joinedAt: DateTime.now(), // FIXA: Lägg till required parameter
        lastActiveAt: DateTime.now(), // FIXA: Lägg till required parameter
      ),
    );

    return friend.displayName;
  }

  /// Get avatar URL for comment author
  String? getAuthorAvatarUrl(RecipeComment comment) {
    // Use cached avatar from comment first
    if (comment.authorAvatarUrl != null) {
      return comment.authorAvatarUrl;
    }

    // Fallback to friends list lookup
    try {
      final friend = friends.firstWhere((f) => f.uid == comment.authorId);
      return friend.avatarUrl;
    } catch (e) {
      return null;
    }
  }

  @override
  void dispose() {
    _socialRecipeService.removeListener(_onSocialServiceChanged);
    _friendsService.removeListener(_onFriendsServiceChanged);
    super.dispose();
  }
}
