// lib/viewmodels/social_recipe_viewmodel.dart

import 'package:flutter/foundation.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/recipe_comment.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/injection.dart';
import 'package:butlery/core/utils/logger.dart'; // Fixad import
import 'package:butlery/core/mixins/error_handling_mixin.dart';


class SocialRecipeViewModel extends ChangeNotifier with ErrorHandlingMixin {
  final Recipe _recipe;
  final UnifiedRecipeService _recipeService;
  final UnifiedFriendsService _friendsService;

  // Comments state
  List<RecipeComment> _comments = [];

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
    required UnifiedRecipeService recipeService,
    required UnifiedFriendsService friendsService,
  })  : _recipe = recipe,
        _recipeService = recipeService,
        _friendsService = friendsService {
    _loadComments();
    _recipeService.addListener(_onSocialServiceChanged);
    _friendsService.addListener(_onFriendsServiceChanged);
  }

  // ===== GETTERS =====

  Recipe get recipe => _recipe;
  List<RecipeComment> get comments => List.unmodifiable(_comments);
  bool get isLoadingComments => _isPostingComment;
  String? get commentsError => _sharingError;
  bool get hasComments => _comments.isNotEmpty;
  
  // Combined state getters
  bool get isLoading => _isSharing || _isPostingComment;
  String? get error => _sharingError;

  bool get isSharing => _isSharing;
  String? get sharingError => _sharingError;
  Set<String> get selectedFriendIds => Set.unmodifiable(_selectedFriendIds);
  bool get hasSelectedFriends => _selectedFriendIds.isNotEmpty;

  String get newCommentText => _newCommentText;
  String? get replyToCommentId => _replyToCommentId;
  bool get isPostingComment => _isPostingComment;
  bool get isReplying => _replyToCommentId != null;

  List<UserProfile> get friends => _friendsService.friendsList;
  UserProfile? get currentUser => sl<PermissionService>().currentUser;

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

    _isSharing = true;
    _sharingError = null;
    notifyListeners();
    
    try {
      final result = await safeExecute(
        () async {
          // Convert friend IDs to member display names - simplified for now
          final memberDisplayNames = <String, String>{};
          for (final friendId in _selectedFriendIds) {
            final friend = friends.where((f) => f.uid == friendId).firstOrNull;
            memberDisplayNames[friendId] = friend?.displayName ?? 'Friend';
          }

          final sharedRecipeId = await _recipeService.social.shareRecipe(
            recipeId: _recipe.id,
            memberIds: _selectedFriendIds.toList(),
            memberDisplayNames: memberDisplayNames,
            collaborativeDescription: message,
          );

          final success = sharedRecipeId != null;
          if (success) {
            _selectedFriendIds.clear();
            AppLogger.success(
              '✅ Recept delat med ${_selectedFriendIds.length} vänner',
            );
            return true;
          } else {
            _sharingError = _recipeService.error ?? 'Kunde inte dela recept';
            throw Exception(_sharingError!);
          }
        },
        operationName: 'Share recipe',
      );
      
      return result ?? false;
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

    _isPostingComment = true;
    notifyListeners();
    
    try {
      final result = await safeExecute(
        () async {
          // Implement comment functionality through UnifiedRecipeService social operations
          final commentId = await _recipeService.social.addComment(
            recipeId: _recipe.id,
            content: _newCommentText.trim(),
            parentCommentId: _replyToCommentId,
          );

          // Handle success case
          if (commentId != null) {
            _newCommentText = '';
            _replyToCommentId = null;
            await _loadComments(); // Refresh comments
            AppLogger.success('✅ Kommentar postad');
            return true;
          } else {
            throw Exception('Kunde inte posta kommentar');
          }
        },
        operationName: 'Post comment',
      );
      
      return result ?? false;
    } finally {
      _isPostingComment = false;
      notifyListeners();
    }
  }

  /// Edit existing comment
  Future<bool> editComment(String commentId, String newText) async {
    return await safeExecute(
      () async {
        final success = await _recipeService.social.editComment(
          commentId: commentId,
          newContent: newText,
        );
        
        if (success) {
          await _loadComments(); // Refresh to show edit
          return true;
        } else {
          throw Exception('Kunde inte redigera kommentar');
        }
      },
      operationName: 'Edit comment',
    ) ?? false;
  }

  /// Delete comment
  Future<bool> deleteComment(String commentId) async {
    return await safeExecute(
      () async {
        final success = await _recipeService.social.deleteComment(commentId);
        
        if (success) {
          await _loadComments(); // Refresh to show deletion
          return true;
        } else {
          throw Exception('Kunde inte ta bort kommentar');
        }
      },
      operationName: 'Delete comment',
    ) ?? false;
  }

  /// Toggle like on comment
  Future<bool> toggleCommentLike(String commentId) async {
    final currentUserId = sl<PermissionService>().currentUserId;
    if (currentUserId == null) return false;

    return await safeExecute(
      () async {
        // Optimistic update
        final commentIndex = _comments.indexWhere((c) => c.id == commentId);
        if (commentIndex >= 0) {
          final comment = _comments[commentIndex];
          final isLiked = comment.isLikedBy(currentUserId);
          _comments[commentIndex] = isLiked
              ? comment.removeLike(currentUserId)
              : comment.addLike(currentUserId);
          notifyListeners();
        }

        final success = await _recipeService.social.toggleCommentLike(commentId);
        
        if (!success) {
          // Revert optimistic update on failure
          if (commentIndex >= 0) {
            final comment = _comments[commentIndex];
            final isLiked = comment.isLikedBy(currentUserId);
            _comments[commentIndex] = isLiked
                ? comment.removeLike(currentUserId)
                : comment.addLike(currentUserId);
            notifyListeners();
          }
          throw Exception('Kunde inte uppdatera gilla-status');
        }
        
        return success;
      },
      operationName: 'Toggle comment like',
    ) ?? false;
  }

  /// Check if current user can edit comment
  bool canEditComment(RecipeComment comment) {
    final currentUserId = sl<PermissionService>().currentUserId;
    return currentUserId != null && comment.canBeEditedBy(currentUserId);
  }

  /// Check if current user has liked comment
  bool hasLikedComment(RecipeComment comment) {
    final currentUserId = sl<PermissionService>().currentUserId;
    return currentUserId != null && comment.isLikedBy(currentUserId);
  }

  // ===== PRIVATE METHODS =====

  Future<void> _loadComments() async {
    await safeExecute(
      () async {
        final comments = await _recipeService.social.getComments(
          recipeId: _recipe.id,
        );

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
      },
      operationName: 'Load comments',
    );
  }

  void _onSocialServiceChanged() {
    notifyListeners();
  }

  void _onFriendsServiceChanged() {
    notifyListeners();
  }

  /// Clear all errors
  void clearErrors() {
    _sharingError = null;
    notifyListeners();
  }
  
  /// Clear error implementation for compatibility
  void clearError() {
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
    _recipeService.removeListener(_onSocialServiceChanged);
    _friendsService.removeListener(_onFriendsServiceChanged);
    super.dispose();
  }
}
