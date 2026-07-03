// lib/services/account/export/activity_export_manager.dart

import 'package:butlery/core/utils/logger.dart' as app_logger;
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/repositories/firebase/firebase_data_export_repository.dart';
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
  // Increment 5: the pooled-rating events have no typed repository (CF-only
  // writes), so they read through the export gateway like other residuals.
  final FirebaseDataExportRepository? _exportRepo;

  static const String _logTag = 'ActivityExportManager';

  ActivityExportManager({
    CommentsRepository? commentsRepository,
    RatingsRepository? ratingsRepository,
    FeedbackRepository? feedbackRepository,
    FirebaseDataExportRepository? dataExportRepository,
  }) : _commentsRepo = commentsRepository,
       _ratingsRepo = ratingsRepository,
       _feedbackRepo = feedbackRepository,
       _exportRepo = dataExportRepository;

  CommentsRepository get _comments =>
      _commentsRepo ?? ServiceLocator.get<CommentsRepository>();
  RatingsRepository get _ratings =>
      _ratingsRepo ?? ServiceLocator.get<RatingsRepository>();
  FeedbackRepository get _feedback =>
      _feedbackRepo ?? ServiceLocator.get<FeedbackRepository>();
  FirebaseDataExportRepository get _exports =>
      _exportRepo ?? ServiceLocator.get<FirebaseDataExportRepository>();

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

  /// Increment 5 (decision 12): export the user's pooled-rating events
  /// (`users/{uid}/canonical_rating_events`). The deletion cascade erases these,
  /// so Art. 15 right-of-access requires the export to include them — the
  /// section is always present (even when empty) so export ⊇ erased holds.
  ///
  /// PSEUDONYMOUS, NOT anonymous (decision 12 / Breyer C-582/14): each event
  /// links this account to a reproducible recipe-identity hash (poolKey). Never
  /// label this section anonymous — only the uid-free aggregate is anonymous.
  Future<Map<String, dynamic>> exportPooledRatingEvents(String userId) async {
    try {
      final limit = ExportPaginationHelper.getLimitForType(
        'canonical_rating_events',
      );
      final entries = await _exports.exportCanonicalRatingEvents(
        userId,
        maxDocuments: limit,
      );
      return {
        // Distinct inner key (not the outer section key) so consumers read
        // pooled_rating_events.events, matching the feedback→submissions /
        // comments_and_ratings→comments sibling convention (not the double-nest).
        'events': entries
            .map((e) => {'id': e['id'], 'data': sanitizeForJson(e['data'])})
            .toList(),
        'total_count': entries.length,
        if (entries.length >= limit) 'truncated': true,
        'note':
            'Pseudonymous: each event links your account to a recipe-identity '
            'hash (poolKey), not anonymous data.',
      };
    } catch (e) {
      app_logger.AppLogger.error(
        '[$_logTag] Failed to export pooled rating events',
        e,
      );
      // error_code lets the service's warnings aggregator surface a failed
      // pooled-events read as a top-level bundle warning — a silent {'error'}
      // here would let an incomplete Art. 15 export look complete. Mirrors
      // family_export_manager's GDPR-section error token.
      return {
        'error': e.toString(),
        'error_code': 'pooled-rating-events-export-failed',
      };
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
