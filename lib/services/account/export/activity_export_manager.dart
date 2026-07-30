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
      // BUT-1698: both reads carry a cap, so both get the N+1 probe and the
      // section declares truncation when either clipped. Applying the cap
      // silently made a partial Art. 15/20 bundle read as complete.
      final results = await Future.wait([
        ExportPaginationHelper.fetchCapped(
          type: 'comments',
          fetch: (max) =>
              _comments.exportCommentsByAuthor(userId, maxDocuments: max),
        ),
        ExportPaginationHelper.fetchCapped(
          type: 'ratings',
          fetch: (max) =>
              _ratings.exportRatingsByUser(userId, maxDocuments: max),
        ),
      ]);

      final recipeComments = results[0];
      final recipeRatings = results[1];

      for (final entry in recipeComments.items) {
        data['comments'].add({
          'comment_id': entry['id'],
          'type': 'recipe',
          'data': sanitizeForJson(entry['data']),
        });
      }

      for (final entry in recipeRatings.items) {
        data['ratings'].add({
          'rating_id': entry['id'],
          'type': 'recipe',
          'data': sanitizeForJson(entry['data']),
        });
      }

      data['total_comments'] = data['comments'].length;
      data['total_ratings'] = data['ratings'].length;
      if (recipeComments.truncated || recipeRatings.truncated) {
        data['truncated'] = true;
      }

      return data;
    } catch (e) {
      app_logger.AppLogger.error(
        '[$_logTag] Failed to export comments and ratings',
        e,
      );
      // BUT-1721: `error_code` is what lifts a failed section into
      // `export_metadata.warnings` with a token naming WHICH read failed. Every
      // catch in this manager carries one, as the pooled-events catch already
      // did — a comments-and-ratings section that vanished from an Art. 15
      // bundle must not vanish quietly.
      //
      // `error` is a stable sentence, never `e.toString()`: the aggregator
      // promotes it to `warnings[].message` at the ROOT of a bundle the data
      // subject may forward to a supervisory authority, and a raw Firestore
      // string carries foreign uids, index URLs and internal paths. The
      // exception is already in `AppLogger.error` above. Same convention as
      // `shared_shopping_list_export.dart`.
      return {
        'error': 'Comments and ratings could not be exported.',
        'error_code': 'comments-and-ratings-export-failed',
      };
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
      final entries = await ExportPaginationHelper.fetchCapped(
        type: 'canonical_rating_events',
        fetch: (max) =>
            _exports.exportCanonicalRatingEvents(userId, maxDocuments: max),
      );
      return {
        // Distinct inner key (not the outer section key) so consumers read
        // pooled_rating_events.events, matching the feedback→submissions /
        // comments_and_ratings→comments sibling convention (not the double-nest).
        'events': entries.items
            .map((e) => {'id': e['id'], 'data': sanitizeForJson(e['data'])})
            .toList(),
        'total_count': entries.length,
        if (entries.truncated) 'truncated': true,
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
        'error': 'Pooled rating events could not be exported.',
        'error_code': 'pooled-rating-events-export-failed',
      };
    }
  }

  /// Export user feedback submissions
  Future<Map<String, dynamic>> exportFeedback(String userId) async {
    try {
      // BUT-1698: this read was riding the repository's default cap, so a user
      // over it lost submissions with no signal at all.
      final feedback = await ExportPaginationHelper.fetchCapped(
        type: 'feedback',
        fetch: (max) =>
            _feedback.exportFeedbackByUser(userId, maxDocuments: max),
      );

      return {
        'submissions': feedback.items
            .map((entry) => sanitizeForJson(entry['data']))
            .toList(),
        'total': feedback.length,
        if (feedback.truncated) 'truncated': true,
      };
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to export feedback', e);
      return {
        'error': 'Feedback could not be exported.',
        'error_code': 'feedback-export-failed',
      };
    }
  }
}
