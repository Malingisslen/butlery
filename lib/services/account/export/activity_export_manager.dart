// lib/services/account/export/activity_export_manager.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/utils/logger.dart' as app_logger;

/// Handles export of user activity: comments, ratings, activity history.
/// Part of GDPR Article 20 (Right to Data Portability) compliance.
class ActivityExportManager {
  final FirebaseFirestore _firestore;
  static const String _logTag = 'ActivityExportManager';

  ActivityExportManager({required FirebaseFirestore firestore})
      : _firestore = firestore;

  /// Export user comments and ratings
  Future<Map<String, dynamic>> exportCommentsAndRatings(String userId) async {
    try {
      final data = <String, dynamic>{
        'comments': [],
        'ratings': [],
      };

      // Get comments
      final comments = await _firestore
          .collection('recipe_comments')
          .where('userId', isEqualTo: userId)
          .get();

      for (final doc in comments.docs) {
        data['comments'].add({
          'comment_id': doc.id,
          'data': doc.data(),
        });
      }

      // Get ratings
      final ratings = await _firestore
          .collection('recipe_ratings')
          .where('userId', isEqualTo: userId)
          .get();

      for (final doc in ratings.docs) {
        data['ratings'].add({
          'rating_id': doc.id,
          'data': doc.data(),
        });
      }

      data['total_comments'] = data['comments'].length;
      data['total_ratings'] = data['ratings'].length;

      return data;
    } catch (e) {
      app_logger.AppLogger.error(
          '[$_logTag] Failed to export comments and ratings', e);
      return {'error': e.toString()};
    }
  }

  /// Export user activity feed history
  Future<Map<String, dynamic>> exportActivityHistory(String userId) async {
    try {
      final activities = <Map<String, dynamic>>[];

      // Get user's activity feed items
      final activitySnapshot = await _firestore
          .collection('activity_feed')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(500) // Limit to last 500 activities
          .get();

      for (final doc in activitySnapshot.docs) {
        activities.add({
          'activity_id': doc.id,
          'data': doc.data(),
        });
      }

      return {
        'total_count': activities.length,
        'activities': activities,
        'note': 'Limited to last 500 activities for export size',
      };
    } catch (e) {
      app_logger.AppLogger.error(
          '[$_logTag] Failed to export activity history', e);
      return {'error': e.toString()};
    }
  }
}
