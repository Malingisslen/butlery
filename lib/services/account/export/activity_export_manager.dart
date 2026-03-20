// lib/services/account/export/activity_export_manager.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/utils/logger.dart' as app_logger;
import 'package:butlery/services/account/export/export_pagination_helper.dart'
    show ExportPaginationHelper, sanitizeForJson;
import 'package:butlery/core/constants/firestore_collections.dart';

/// Handles export of user activity: comments and ratings.
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
      final commentLimit = ExportPaginationHelper.getLimitForType('comments');
      final ratingLimit = ExportPaginationHelper.getLimitForType('ratings');

      // Get comments (paginated)
      final comments = await ExportPaginationHelper.paginatedQuery(
        query: _firestore
            .collection(FirestoreCollections.recipeComments)
            .where('userId', isEqualTo: userId),
        maxDocuments: commentLimit,
      );

      for (final doc in comments) {
        data['comments'].add({
          'comment_id': doc.id,
          'data': sanitizeForJson(doc.data()),
        });
      }

      // Get ratings (paginated)
      final ratings = await ExportPaginationHelper.paginatedQuery(
        query: _firestore
            .collection(FirestoreCollections.recipeRatings)
            .where('userId', isEqualTo: userId),
        maxDocuments: ratingLimit,
      );

      for (final doc in ratings) {
        data['ratings'].add({
          'rating_id': doc.id,
          'data': sanitizeForJson(doc.data()),
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
}
