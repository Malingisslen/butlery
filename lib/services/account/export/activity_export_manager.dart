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

  /// Export user recipe comments and ratings
  Future<Map<String, dynamic>> exportCommentsAndRatings(String userId) async {
    try {
      final data = <String, dynamic>{
        'comments': [],
        'ratings': [],
      };
      final commentLimit = ExportPaginationHelper.getLimitForType('comments');
      final ratingLimit = ExportPaginationHelper.getLimitForType('ratings');

      final results = await Future.wait([
        ExportPaginationHelper.paginatedQuery(
          query: _firestore
              .collection(FirestoreCollections.recipeComments)
              .where('authorId', isEqualTo: userId),
          maxDocuments: commentLimit,
        ),
        ExportPaginationHelper.paginatedQuery(
          query: _firestore
              .collection(FirestoreCollections.recipeRatings)
              .where('userId', isEqualTo: userId),
          maxDocuments: ratingLimit,
        ),
      ]);

      final recipeComments = results[0];
      final recipeRatings = results[1];

      for (final doc in recipeComments) {
        data['comments'].add({
          'comment_id': doc.id,
          'type': 'recipe',
          'data': sanitizeForJson(doc.data()),
        });
      }

      for (final doc in recipeRatings) {
        data['ratings'].add({
          'rating_id': doc.id,
          'type': 'recipe',
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
