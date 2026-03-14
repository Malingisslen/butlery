/// Manager handling social engagement operations including likes and ratings.

import 'package:flutter/foundation.dart';
import 'package:butlery/core/utils/logger.dart';

class SocialEngagementManager extends ChangeNotifier {
  final Set<String> _likedCommentIds = {};

  Future<void> toggleCommentLike(String commentId) async {
    try {
      final isNowLiked = !_likedCommentIds.contains(commentId);
      if (isNowLiked) {
        _likedCommentIds.add(commentId);
      } else {
        _likedCommentIds.remove(commentId);
      }
      notifyListeners();

      AppLogger.info(
          'Successfully toggled like for comment: $commentId (liked: $isNowLiked)');
    } catch (e) {
      AppLogger.error('Failed to toggle comment like for $commentId: $e');
    }
  }

  bool hasLikedComment(String commentId) {
    return _likedCommentIds.contains(commentId);
  }
}
