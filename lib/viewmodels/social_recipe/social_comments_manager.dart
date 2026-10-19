/// Manager handling comment operations including posting, replying, threading, and real-time updates.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:butlery/core/mixins/disposal_guard_mixin.dart';
import 'package:butlery/core/exceptions/repository_exception.dart';
import 'package:butlery/models/recipe_comment.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/moderation/content_filter_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/auth/account_maturity_helper.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/l10n/app_locale.dart';

class SocialCommentsManager extends ChangeNotifier with DisposalGuardMixin {
  final UnifiedRecipeService _recipeService;
  ContentFilterService? _contentFilter;
  UnifiedFriendsService? _friendsService;
  UserService? _userService;
  AuthRepository? _authRepository;
  final AccountMaturityHelper _maturityHelper;

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

  SocialCommentsManager(
    this._recipeService, {
    AccountMaturityHelper? maturityHelper,
    UserService? userService,
    AuthRepository? authRepository,
  }) : _maturityHelper = maturityHelper ?? AccountMaturityHelper() {
    _contentFilter = ServiceLocator.tryGet<ContentFilterService>();
    _friendsService = ServiceLocator.tryGet<UnifiedFriendsService>();
    _userService = userService ?? ServiceLocator.tryGet<UserService>();
    _authRepository = authRepository ?? ServiceLocator.tryGet<AuthRepository>();
  }

  /// Client-side mirror of the server `isAccountMatured()` gate (BUT-1419).
  /// The Firestore rule is the authority; this lets the UI surface a clear
  /// "verify your email" message instead of an opaque permission-denied.
  bool get isAccountMatured => _maturityHelper.isMatured(
    profile: _userService?.currentUserProfile,
    firebaseUser: _authRepository?.currentUser,
  );

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

  String get newCommentText => _newCommentText;
  List<RecipeComment> get comments => _comments;
  List<RecipeComment> get topLevelComments =>
      _comments.where((comment) => comment.parentCommentId == null).toList();

  Future<void> refreshComments(String recipeId) async {
    _isLoadingComments = true;
    _commentsError = null;
    notifyListeners();

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
      notifyListeners();
    }
  }

  /// Lightweight count-only fetch using Firestore aggregation.
  Future<void> fetchCommentCount(String recipeId) async {
    try {
      final stats = await _recipeService.social.getCommentStatistics(recipeId);
      _commentCount = stats['total_comments'] as int? ?? 0;
      notifyListeners();
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
    notifyListeners();

    try {
      AppLogger.info('Starting real-time comment stream for recipe: $recipeId');

      _commentStreamSubscription = _recipeService.social
          .getCommentsStream(recipeId)
          .listen(
            (recipeComments) {
              _comments = _filterBlockedUsers(recipeComments);
              _isLoadingComments = false;
              _commentsError = null;
              notifyListeners();
              AppLogger.debug(
                'Real-time comment update received: ${_comments.length} comments',
              );
            },
            onError: (error) {
              _commentsError = AppLocale.current.errorCouldNotLoad(
                'kommentarer',
              );
              _isLoadingComments = false;
              notifyListeners();
              AppLogger.error(
                'Comment stream error for recipe $recipeId: $error',
              );
            },
          );
    } catch (e) {
      _commentsError = AppLocale.current.errorCouldNotLoad('kommentarer');
      _isLoadingComments = false;
      notifyListeners();
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
    notifyListeners();
  }

  Future<void> postComment(
    String recipeId, {
    List<String> imageUrls = const [],
  }) async {
    if (_newCommentText.trim().isEmpty) return;

    // BUT-1419: client-side mirror of the server isAccountMatured() gate.
    // Comments are now maturity-gated (like DMs/friend-requests) to close the
    // register-blast-abandon comment-spam vector. The Firestore rule is the
    // authority; this surfaces a clear "verify your email" message instead of
    // the opaque permission-denied a fresh, unverified account would hit.
    if (!isAccountMatured) {
      _commentsError = AppLocale.current.newAccountSocialBlockedComment;
      notifyListeners();
      return;
    }

    // BUT-1393: gate comment text through the canonical profanity filter before
    // publishing (same path as recipe titles, group names, bios, cook-snap
    // captions). Firestore rules cannot filter content, so this is the only
    // pre-publish line of defense on a primary harassment surface.
    final filter = _contentFilter;
    if (filter != null) {
      final result = filter.ensureClean(
        _newCommentText.trim(),
        fieldName: 'comment',
      );
      if (!result.isClean) {
        _commentsError = result.reason;
        notifyListeners();
        return;
      }
    }

    _isPostingComment = true;
    notifyListeners();

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
    } on CommentAwaitingSendException {
      // Nothing failed: the form says why, and the list stays.
      rethrow;
    } catch (e) {
      _commentsError = AppLocale.current.errorGeneric;
      AppLogger.error('Failed to post comment for recipe $recipeId: $e');
      rethrow;
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
      notifyListeners();
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
      notifyListeners();
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
    // First, so the guard is up before the cleanup below runs.
    super.dispose();
    stopWatchingComments();
  }
}
