// lib/services/account/export/activity_export_manager.dart

import 'package:butlery/core/utils/logger.dart' as app_logger;
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/repositories/firebase/firebase_data_export_repository.dart';
import 'package:butlery/repositories/interfaces/comments_repository.dart';
import 'package:butlery/repositories/interfaces/feedback_repository.dart';
import 'package:butlery/repositories/interfaces/ratings_repository.dart';
import 'package:butlery/services/account/export/export_pagination_helper.dart'
    show ExportPaginationHelper, projectExportFields, sanitizeForJson;

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

  /// What a `recipe_comments` row contributes to the bundle (BUT-2062).
  ///
  /// An ALLOWLIST, so the section fails CLOSED. Derived from the WRITERS, not
  /// hand-listed: `RecipeComment.toFirestore()` plus the `updatedAt` that
  /// `FirebaseCommentsRepository.addComment` and `updateComment` stamp.
  /// `activity_export_projection_test.dart` compares this list and the strip
  /// list below against `RecipeComment.toFirestore()`. It does not range over
  /// the repository's own stamps or the server-side writers.
  ///
  /// WITHHELD, and why, argued on this collection's own facts:
  /// * `authorId` — the requester's own uid AND the query's own filter. Not a
  ///   withholding; it adds nothing the bundle does not already say.
  /// * `recipeOwnerId` — a third party's raw uid. The requester can see whose
  ///   recipe it is inside the app, so this is not secrecy: an opaque uid is an
  ///   identifier they cannot resolve, and reproducing it in a forwardable file
  ///   hands on an identifier for someone who did not ask for this bundle.
  /// * `sharedWithUserIds` — uids of everyone the recipe was shared with when
  ///   the comment was written. People with no relationship to the requester at
  ///   all. Also a frozen snapshot: nothing updates it when a recipe is
  ///   re-shared or unshared.
  /// * `reactions` — a map of emoji to the uids that reacted, i.e. a record of
  ///   other people's behaviour. Withheld whole: the requester's own uid can
  ///   appear in it, but splitting the map by uid would still disclose how many
  ///   others reacted with what.
  ///
  /// KEPT and worth naming: `authorAvatarUrl` is the requester's OWN avatar,
  /// and `imageUrls` are their own comment images. The image links are
  /// `getDownloadURL()` values carrying a `?token=` bearer credential — anyone
  /// holding the string can fetch the file without signing in — so a forwarded
  /// bundle forwards that access. Kept anyway: it is the requester's own
  /// content and Art. 15 favours inclusion.
  static const _commentFields = <String>[
    'recipeId',
    'text',
    'createdAt',
    'updatedAt',
    'editedAt',
    'parentCommentId',
    'isDeleted',
    'likesCount',
    'replyCount',
    'imageUrls',
    'authorDisplayName',
    'authorAvatarUrl',
  ];

  /// What a `recipe_ratings` row contributes (BUT-2062). Derived from
  /// `RecipeRating.toFirestore()`.
  ///
  /// `userId` is the requester's own uid and the query's own filter.
  /// `recipeOwnerId` is a third party's uid: `FirebaseRatingsRepository`'s own
  /// writer never emits it today, but the model does when it is set and
  /// `firestore.rules` permits it on create — so it is a DECIDED strip rather
  /// than a field that happens to be absent, and a later change that starts
  /// writing it cannot widen this bundle by accident.
  static const _ratingFields = <String>[
    'recipeId',
    'rating',
    'review',
    'createdAt',
    'updatedAt',
  ];

  /// Fields the two lists above deliberately drop. Not read at runtime — the
  /// projection is an allowlist — but read by the test that holds both lists
  /// against the models' writers.
  static const commentFieldsWithheld = <String>[
    'authorId',
    'recipeOwnerId',
    'sharedWithUserIds',
    'reactions',
  ];
  static const ratingFieldsWithheld = <String>['userId', 'recipeOwnerId'];

  static const commentFieldsExported = _commentFields;
  static const ratingFieldsExported = _ratingFields;

  /// BUT-2062: the sentence is byte-identical on every path — an empty read, a
  /// populated one, and the failure branch below. It bears a fact about third
  /// parties, so it is in the invariant class (BUT-2056): a note that appeared
  /// only when a comment HAD reactions, or only when a recipe HAD been shared,
  /// would reconstruct from its own presence exactly what it withholds.
  static const _dataMinimisation =
      'Your own comments and ratings are reproduced here, but identifiers '
      'belonging to other people are not: who owns the recipe you commented '
      'on, who that recipe was shared with, and who reacted to your comment '
      'with which emoji. Your own name, avatar and comment images are '
      'included. These sections carry only the fields they recognise, so a '
      'field added later may be missing.';

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

      // BUT-2062: project BEFORE sanitizing, so a withheld field is never
      // walked. Both repositories return the raw document by design — their
      // interfaces say so, because the export pipeline is what shapes it —
      // which is exactly why the shaping has to happen here and not be
      // forgotten.
      for (final entry in recipeComments.items) {
        data['comments'].add({
          'comment_id': entry['id'],
          'type': 'recipe',
          'data': sanitizeForJson(
            projectExportFields(entry['data'], _commentFields),
          ),
        });
      }

      for (final entry in recipeRatings.items) {
        data['ratings'].add({
          // The document id is `{recipeId}_{userId}`, so the requester's own
          // uid still travels here. That is their own data and stays; the note
          // below therefore says the uid FIELD is dropped, never that the uid
          // is gone.
          'rating_id': entry['id'],
          'type': 'recipe',
          'data': sanitizeForJson(
            projectExportFields(entry['data'], _ratingFields),
          ),
        });
      }

      data['total_comments'] = data['comments'].length;
      data['total_ratings'] = data['ratings'].length;
      data['data_minimisation'] = _dataMinimisation;
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
        // Same sentence, same bytes, on the path where nothing was read at
        // all — see [_dataMinimisation]. A note that only appeared when the
        // section succeeded would say something about what the read found.
        'data_minimisation': _dataMinimisation,
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
