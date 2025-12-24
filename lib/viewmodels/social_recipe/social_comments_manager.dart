/// Manager handling comment operations including posting, replying, threading, and real-time updates.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:butlery/models/social/social_comment.dart';
import 'package:butlery/models/recipe_comment.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/core/utils/logger.dart';

class SocialCommentsManager extends ChangeNotifier {
  final UnifiedRecipeService _recipeService;

  bool _isLoadingComments = false;
  String? _commentsError;
  bool _isPostingComment = false;
  bool _isReplying = false;
  String _newCommentText = '';
  String? _replyToCommentId;

  List<SocialComment> _comments = [];

  StreamSubscription<List<RecipeComment>>? _commentStreamSubscription;
  String? _watchedRecipeId;

  SocialCommentsManager(this._recipeService);

  bool get hasComments => _comments.isNotEmpty;
  bool get isLoadingComments => _isLoadingComments;
  String? get commentsError => _commentsError;
  bool get isPostingComment => _isPostingComment;
  bool get isReplying => _isReplying;
  String get newCommentText => _newCommentText;
  List<SocialComment> get comments => _comments;
  List<SocialComment> get topLevelComments =>
      _comments.where((comment) => comment.parentCommentId == null).toList();

  Future<void> refreshComments(String recipeId) async {
    _isLoadingComments = true;
    _commentsError = null;
    notifyListeners();

    try {
      final recipeComments =
          await _recipeService.social.getComments(recipeId: recipeId);
      _comments = recipeComments
          .map((comment) => _convertRecipeCommentToSocialComment(comment))
          .toList();
      AppLogger.info('Comments refreshed successfully for recipe: $recipeId');
    } catch (e) {
      _commentsError = 'Kunde inte ladda kommentarer: $e';
      AppLogger.error('Failed to refresh comments for recipe $recipeId: $e');
    } finally {
      _isLoadingComments = false;
      notifyListeners();
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
    notifyListeners();

    try {
      AppLogger.info('Starting real-time comment stream for recipe: $recipeId');

      _commentStreamSubscription =
          _recipeService.social.getCommentsStream(recipeId).listen(
        (recipeComments) {
          _comments = recipeComments
              .map((comment) => _convertRecipeCommentToSocialComment(comment))
              .toList();
          _isLoadingComments = false;
          _commentsError = null;
          notifyListeners();
          AppLogger.debug(
              'Real-time comment update received: ${_comments.length} comments');
        },
        onError: (error) {
          _commentsError = 'Kunde inte lyssna på kommentarer: $error';
          _isLoadingComments = false;
          notifyListeners();
          AppLogger.error('Comment stream error for recipe $recipeId: $error');
        },
      );
    } catch (e) {
      _commentsError = 'Kunde inte starta kommentarströmning: $e';
      _isLoadingComments = false;
      notifyListeners();
      AppLogger.error(
          'Failed to start comment stream for recipe $recipeId: $e');
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
    notifyListeners();
  }

  Future<void> postComment(String recipeId) async {
    if (_newCommentText.trim().isEmpty) return;

    _isPostingComment = true;
    notifyListeners();

    try {
      final commentId = await _recipeService.social.addComment(
        recipeId: recipeId,
        content: _newCommentText.trim(),
        parentCommentId: _replyToCommentId,
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
      _commentsError = 'Kunde inte posta kommentar: $e';
      AppLogger.error('Failed to post comment for recipe $recipeId: $e');
    } finally {
      _isPostingComment = false;
      notifyListeners();
    }
  }

  void setReplyTo(String commentId) {
    _replyToCommentId = commentId;
    _isReplying = true;
    notifyListeners();
  }

  void cancelReply() {
    _replyToCommentId = null;
    _isReplying = false;
    notifyListeners();
  }

  List<SocialComment> getReplies(String parentCommentId) {
    return _comments
        .where((comment) => comment.parentCommentId == parentCommentId)
        .toList();
  }

  SocialComment _convertRecipeCommentToSocialComment(
      RecipeComment recipeComment) {
    return SocialComment(
      id: recipeComment.id,
      recipeId: recipeComment.recipeId,
      authorId: recipeComment.authorId,
      text: recipeComment.text,
      createdAt: recipeComment.createdAt,
      parentCommentId: recipeComment.parentCommentId,
    );
  }

  @override
  void dispose() {
    stopWatchingComments();
    super.dispose();
  }
}
