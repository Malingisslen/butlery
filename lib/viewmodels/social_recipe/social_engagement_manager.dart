/// Manager handling social engagement operations including likes and ratings.

import 'package:flutter/foundation.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/unified/operations/modules/comment_likes_system.dart';

class SocialEngagementManager extends ChangeNotifier {
  final Set<String> _likedCommentIds = {};

  Future<void> toggleCommentLike(String commentId) async {
    final userId = ServiceLocator.get<PermissionService>().currentUserId;
    if (userId == null) return;

    // Optimistic local update
    final wasLiked = _likedCommentIds.contains(commentId);
    if (wasLiked) {
      _likedCommentIds.remove(commentId);
    } else {
      _likedCommentIds.add(commentId);
    }
    notifyListeners();

    // Persist to Firestore
    final result = await CommentLikesSystem.toggleCommentLike(
      commentId: commentId,
      currentUserId: userId,
    );

    if (result == null) {
      // Rollback on failure
      if (wasLiked) {
        _likedCommentIds.add(commentId);
      } else {
        _likedCommentIds.remove(commentId);
      }
      notifyListeners();
      AppLogger.error('Failed to persist comment like for $commentId');
    }
  }

  bool hasLikedComment(String commentId) {
    return _likedCommentIds.contains(commentId);
  }

  /// Seed like status from Firestore for a batch of comments.
  Future<void> loadLikeStatus(List<String> commentIds) async {
    if (commentIds.isEmpty) return;

    final userId = ServiceLocator.get<PermissionService>().currentUserId;
    if (userId == null) return;

    try {
      final statuses = await CommentLikesSystem.getBulkLikeStatus(
        commentIds: commentIds,
        userId: userId,
      );
      for (final entry in statuses.entries) {
        if (entry.value) {
          _likedCommentIds.add(entry.key);
        } else {
          _likedCommentIds.remove(entry.key);
        }
      }
      notifyListeners();
    } catch (e) {
      AppLogger.warning('Failed to load comment like status: $e');
    }
  }
}
