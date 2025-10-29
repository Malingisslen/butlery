/// Manager handling social engagement operations including likes and ratings.

import 'package:flutter/foundation.dart';
import 'package:butlery/models/social/social_comment.dart';
import 'package:butlery/core/utils/logger.dart';

class SocialEngagementManager extends ChangeNotifier {
  final List<SocialComment> Function() _getComments;

  SocialEngagementManager(this._getComments);

  Future<void> toggleCommentLike(String commentId) async {
    try {
      final comments = _getComments();
      final comment = comments.firstWhere((c) => c.id == commentId);
      comment.isLiked = !comment.isLiked;
      comment.likeCount += comment.isLiked ? 1 : -1;
      notifyListeners();

      AppLogger.info('Successfully toggled like for comment: $commentId (liked: ${comment.isLiked})');
    } catch (e) {
      AppLogger.error('Failed to toggle comment like for $commentId: $e');
    }
  }

  bool hasLikedComment(String commentId) {
    try {
      final comments = _getComments();
      final comment = comments.firstWhere((c) => c.id == commentId);
      return comment.isLiked;
    } catch (e) {
      return false;
    }
  }
}
