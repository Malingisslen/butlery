/// Manager handling comment operations including posting, replying, threading, and real-time updates.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:butlery/models/recipe_comment.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/moderation/content_filter_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/l10n/app_locale.dart';

class SocialCommentsManager extends ChangeNotifier {
  final UnifiedRecipeService _recipeService;
  ContentFilterService? _contentFilter;
  UnifiedFriendsService? _friendsService;
  bool _isDisposed = false;

  bool _isLoadingComments = false;
  String? _commentsError;
  bool _isPostingComment = false;
  bool _isReplying = false;
  String _newCommentText = '';
  String? _replyToCommentId;

  List<RecipeComment> _comments = [];
  int? _commentCount;

  StreamSubscription<List<RecipeComment>>? _commentStreamSubscription;
  String? _watchedRecipeId;

  SocialCommentsManager(this._recipeService) {
    _contentFilter = ServiceLocator.tryGet<ContentFilterService>();
    _friendsService = ServiceLocator.tryGet<UnifiedFriendsService>();
  }

  void _safeNotify() {
    if (!_isDisposed) notifyListeners();
  }

  /// BP3: Filter out comments from blocked users.
  List<RecipeComment> _filterBlockedUsers(List<RecipeComment> comments) {
    final blocked = _friendsService?.blockedUsers;
    if (blocked == null || blocked.isEmpty) return comments;
    return comments.where((c) => !blocked.contains(c.authorId)).toList();
  }

  bool get hasComments => _comments.isNotEmpty;
  int? get commentCount => _commentCount;
  bool get isLoadingComments => _isLoadingComments;
  String? get commentsError => _commentsError;
  bool get isPostingComment => _isPostingComment;
  bool get isReplying => _isReplying;

  /// Returns true if the current comment text contains profanity.
  bool get hasProfanityWarning =>
      _contentFilter?.containsProfanity(_newCommentText) ?? false;
  String get newCommentText => _newCommentText;
  List<RecipeComment> get comments => _comments;
  List<RecipeComment> get topLevelComments =>
      _comments.where((comment) => comment.parentCommentId == null).toList();

  Future<void> refreshComments(String recipeId) async {
    _isLoadingComments = true;
    _commentsError = null;
    _safeNotify();

    try {
      final recipeComments = await _recipeService.social.getComments(
        recipeId: recipeId,
      );
      _comments = _filterBlockedUsers(recipeComments);
      _commentCount = _comments.length;
      AppLogger.info('Comments refreshed successfully for recipe: $recipeId');
    } catch (e) {
      _commentsError = AppLocale.current.errorCouldNotLoad('kommentarer');
      AppLogger.error('Failed to refresh comments for recipe $recipeId: $e');
    } finally {
      _isLoadingComments = false;
      _safeNotify();
    }
  }

  /// Lightweight count-only fetch using Firestore aggregation.
  Future<void> fetchCommentCount(String recipeId) async {
    try {
      final stats = await _recipeService.social.getCommentStatistics(recipeId);
      _commentCount = stats['total_comments'] as int? ?? 0;
      _safeNotify();
    } catch (e) {
      AppLogger.warning('Failed to fetch comment count: $e');
    }
  }

  void startWatchingComments(String recipeId) {
    if (_watchedRecipeId == recipeId && _commentStreamSubscription != null) {
      AppLogger.debug('Already watching comments for recipe: $recipeId');
      return;
    }

    stopWatchingComments();

    _isLoadingComments = true;
    _commentsError = null;
    _watchedRecipeId = recipeId;
    _safeNotify();

    try {
      AppLogger.info('Starting real-time comment stream for recipe: $recipeId');

      _commentStreamSubscription = _recipeService.social
          .getCommentsStream(recipeId)
          .listen(
            (recipeComments) {
              _comments = _filterBlockedUsers(recipeComments);
              _isLoadingComments = false;
              _commentsError = null;
              _safeNotify();
              AppLogger.debug(
                'Real-time comment update received: ${_comments.length} comments',
              );
            },
            onError: (error) {
              _commentsError = AppLocale.current.errorCouldNotLoad(
                'kommentarer',
              );
              _isLoadingComments = false;
              _safeNotify();
              AppLogger.error(
                'Comment stream error for recipe $recipeId: $error',
              );
            },
          );
    } catch (e) {
      _commentsError = AppLocale.current.errorCouldNotLoad('kommentarer');
      _isLoadingComments = false;
      _safeNotify();
      AppLogger.error(
        'Failed to start comment stream for recipe $recipeId: $e',
      );
    }
  }

  void stopWatchingComments() {
    if (_commentStreamSubscription != null) {
      AppLogger.info('Stopping comment stream for recipe: $_watchedRecipeId');
      _commentStreamSubscription?.cancel();
      _commentStreamSubscription = null;
      _watchedRecipeId = null;
    }
  }

  void updateNewCommentText(String text) {
    _newCommentText = text;
    _safeNotify();
  }

  Future<void> postComment(
    String recipeId, {
    List<String> imageUrls = const [],
  }) async {
    if (_newCommentText.trim().isEmpty) return;

    _isPostingComment = true;
    _safeNotify();

    try {
      final commentId = await _recipeService.social.addComment(
        recipeId: recipeId,
        content: _newCommentText.trim(),
        parentCommentId: _replyToCommentId,
        imageUrls: imageUrls,
      );

      if (commentId != null) {
        _newCommentText = '';
        _replyToCommentId = null;
        _isReplying = false;

        await refreshComments(recipeId);

        AppLogger.info('Comment posted successfully for recipe: $recipeId');
      } else {
        throw Exception('Failed to post comment - service returned null');
      }
    } catch (e) {
      _commentsError = AppLocale.current.errorGeneric;
      AppLogger.error('Failed to post comment for recipe $recipeId: $e');
      rethrow;
    } finally {
      _isPostingComment = false;
      _safeNotify();
    }
  }

  void setReplyTo(String commentId) {
    _replyToCommentId = commentId;
    _isReplying = true;
    _safeNotify();
  }

  void cancelReply() {
    _replyToCommentId = null;
    _isReplying = false;
    _safeNotify();
  }

  Future<void> deleteComment(String recipeId, String commentId) async {
    try {
      final success = await _recipeService.social.deleteComment(commentId);
      if (success) {
        await refreshComments(recipeId);
        AppLogger.info('Comment deleted successfully: $commentId');
      } else {
        throw Exception('Service returned false for comment deletion');
      }
    } catch (e) {
      _commentsError = AppLocale.current.errorCouldNotDelete('kommentar');
      AppLogger.error('Failed to delete comment $commentId: $e');
      _safeNotify();
    }
  }

  Future<void> editComment(
    String recipeId,
    String commentId,
    String newContent,
  ) async {
    try {
      final success = await _recipeService.social.editComment(
        commentId: commentId,
        newContent: newContent,
      );
      if (success) {
        await refreshComments(recipeId);
        AppLogger.info('Comment edited successfully: $commentId');
      } else {
        throw Exception('Service returned false for comment edit');
      }
    } catch (e) {
      _commentsError = AppLocale.current.commentEditError;
      AppLogger.error('Failed to edit comment $commentId: $e');
      _safeNotify();
      rethrow;
    }
  }

  List<RecipeComment> getReplies(String parentCommentId) {
    return _comments
        .where((comment) => comment.parentCommentId == parentCommentId)
        .toList();
  }

  @override
  void dispose() {
    _isDisposed = true;
    stopWatchingComments();
    super.dispose();
  }
}
