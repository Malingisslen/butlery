// lib/services/account/export/activity_export_manager.dart

import 'package:butlery/core/utils/logger.dart' as app_logger;
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/repositories/interfaces/comments_repository.dart';
import 'package:butlery/repositories/interfaces/feedback_repository.dart';
import 'package:butlery/repositories/interfaces/ratings_repository.dart';
import 'package:butlery/services/account/export/export_pagination_helper.dart'
    show ExportPaginationHelper, sanitizeForJson;

/// Handles export of user activity: comments and ratings.
/// Part of GDPR Article 20 (Right to Data Portability) compliance.
///
/// BUT-501: routed through repositories with `validateOwnership` guards
/// instead of direct Firestore access. The repos enforce that the
/// authenticated caller can only export their own data.
class ActivityExportManager {
  // Test seams: production resolves via ServiceLocator on first use; tests
  // inject fakes that share state with the test fake firestore.
  final CommentsRepository? _commentsRepo;
  final RatingsRepository? _ratingsRepo;
  final FeedbackRepository? _feedbackRepo;

  static const String _logTag = 'ActivityExportManager';

  ActivityExportManager({
    CommentsRepository? commentsRepository,
    RatingsRepository? ratingsRepository,
    FeedbackRepository? feedbackRepository,
  }) : _commentsRepo = commentsRepository,
       _ratingsRepo = ratingsRepository,
       _feedbackRepo = feedbackRepository;

  CommentsRepository get _comments =>
      _commentsRepo ?? ServiceLocator.get<CommentsRepository>();
  RatingsRepository get _ratings =>
      _ratingsRepo ?? ServiceLocator.get<RatingsRepository>();
  FeedbackRepository get _feedback =>
      _feedbackRepo ?? ServiceLocator.get<FeedbackRepository>();

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
        _comments.exportCommentsByAuthor(userId, maxDocuments: commentLimit),
        _ratings.exportRatingsByUser(userId, maxDocuments: ratingLimit),
      ]);

      final recipeComments = results[0];
      final recipeRatings = results[1];

      for (final entry in recipeComments) {
        data['comments'].add({
          'comment_id': entry['id'],
          'type': 'recipe',
          'data': sanitizeForJson(entry['data']),
        });
      }

      for (final entry in recipeRatings) {
        data['ratings'].add({
          'rating_id': entry['id'],
          'type': 'recipe',
          'data': sanitizeForJson(entry['data']),
        });
      }

      data['total_comments'] = data['comments'].length;
      data['total_ratings'] = data['ratings'].length;

      return data;
    } catch (e) {
      app_logger.AppLogger.error(
        '[$_logTag] Failed to export comments and ratings',
        e,
      );
      return {'error': e.toString()};
    }
  }

  /// Export user feedback submissions
  Future<Map<String, dynamic>> exportFeedback(String userId) async {
    try {
      final feedback = await _feedback.exportFeedbackByUser(userId);

      return {
        'submissions': feedback
            .map((entry) => sanitizeForJson(entry['data']))
            .toList(),
        'total': feedback.length,
      };
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to export feedback', e);
      return {'error': e.toString()};
    }
  }
}
