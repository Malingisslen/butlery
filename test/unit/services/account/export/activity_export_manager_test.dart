/// Direct unit tests for [ActivityExportManager] (BUT-1438, BUT-1401 follow-up).
///
/// These prove the GDPR Article-15/20 *activity* export contract: every
/// record type this manager owns (comments, ratings, feedback submissions)
/// is present and correctly reshaped in the exported payload. The risk this
/// guards against is a refactor silently dropping a record type from a
/// data-subject export — the DataExportService integration test would still
/// assemble a bundle, so only a direct shape assertion catches it.
///
/// Mocking strategy: the manager exposes constructor seams for each
/// repository (`_commentsRepo ?? ServiceLocator.get<...>()`), so we inject
/// `Fake` repos that return canned rows — no emulator, no ServiceLocator.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/repositories/interfaces/comments_repository.dart';
import 'package:butlery/repositories/interfaces/feedback_repository.dart';
import 'package:butlery/repositories/interfaces/ratings_repository.dart';
import 'package:butlery/services/account/export/activity_export_manager.dart';

class _FakeCommentsRepository extends Fake implements CommentsRepository {
  _FakeCommentsRepository(this.rows);
  final List<Map<String, dynamic>> rows;
  String? capturedUserId;

  @override
  Future<List<Map<String, dynamic>>> exportCommentsByAuthor(
    String userId, {
    int maxDocuments = 1000,
  }) async {
    capturedUserId = userId;
    return rows;
  }
}

class _FakeRatingsRepository extends Fake implements RatingsRepository {
  _FakeRatingsRepository(this.rows);
  final List<Map<String, dynamic>> rows;

  @override
  Future<List<Map<String, dynamic>>> exportRatingsByUser(
    String userId, {
    int maxDocuments = 1000,
  }) async => rows;
}

class _FakeFeedbackRepository extends Fake implements FeedbackRepository {
  _FakeFeedbackRepository(this.rows);
  final List<Map<String, dynamic>> rows;

  @override
  Future<List<Map<String, dynamic>>> exportFeedbackByUser(
    String userId, {
    int maxDocuments = 1000,
  }) async => rows;
}

ActivityExportManager _manager({
  List<Map<String, dynamic>> comments = const [],
  List<Map<String, dynamic>> ratings = const [],
  List<Map<String, dynamic>> feedback = const [],
}) {
  return ActivityExportManager(
    commentsRepository: _FakeCommentsRepository(comments),
    ratingsRepository: _FakeRatingsRepository(ratings),
    feedbackRepository: _FakeFeedbackRepository(feedback),
  );
}

void main() {
  group('ActivityExportManager.exportCommentsAndRatings (BUT-1438)', () {
    test('includes and reshapes both comments and ratings', () async {
      final manager = _manager(
        comments: [
          {
            'id': 'c1',
            'data': {'text': 'Lovely recipe'},
          },
        ],
        ratings: [
          {
            'id': 'r1',
            'data': {'stars': 5},
          },
        ],
      );

      final result = await manager.exportCommentsAndRatings('user-uid');

      final comments = result['comments'] as List;
      final ratings = result['ratings'] as List;
      expect(comments, hasLength(1));
      expect(ratings, hasLength(1));
      // Each record is reshaped: source `id` becomes a typed id key, the
      // type is tagged, and the payload is carried under `data`.
      expect(comments.single, {
        'comment_id': 'c1',
        'type': 'recipe',
        'data': {'text': 'Lovely recipe'},
      });
      expect(ratings.single, {
        'rating_id': 'r1',
        'type': 'recipe',
        'data': {'stars': 5},
      });
      expect(result['total_comments'], 1);
      expect(result['total_ratings'], 1);
    });

    test(
      'both record-type keys are always present, even when one is empty '
      '(a dropped type would surface as a missing key)',
      () async {
        final manager = _manager(
          comments: const [],
          ratings: [
            {
              'id': 'r1',
              'data': {'stars': 3},
            },
          ],
        );

        final result = await manager.exportCommentsAndRatings('user-uid');

        expect(result.containsKey('comments'), isTrue);
        expect(result.containsKey('ratings'), isTrue);
        expect(result['comments'], isEmpty);
        expect((result['ratings'] as List), hasLength(1));
        expect(result['total_comments'], 0);
        expect(result['total_ratings'], 1);
      },
    );

    test('queries the export for the requested user id', () async {
      final commentsRepo = _FakeCommentsRepository(const []);
      final manager = ActivityExportManager(
        commentsRepository: commentsRepo,
        ratingsRepository: _FakeRatingsRepository(const []),
        feedbackRepository: _FakeFeedbackRepository(const []),
      );

      await manager.exportCommentsAndRatings('user-42');

      expect(commentsRepo.capturedUserId, 'user-42');
    });
  });

  group('ActivityExportManager.exportFeedback (BUT-1438)', () {
    test('includes every feedback submission, unwrapped to its data', () async {
      final manager = _manager(
        feedback: [
          {
            'id': 'f1',
            'data': {'message': 'Bug on import'},
          },
          {
            'id': 'f2',
            'data': {'message': 'Love the app'},
          },
        ],
      );

      final result = await manager.exportFeedback('user-uid');

      final submissions = result['submissions'] as List;
      expect(submissions, hasLength(2));
      expect(submissions, [
        {'message': 'Bug on import'},
        {'message': 'Love the app'},
      ]);
      expect(result['total'], 2);
    });

    test('empty feedback still yields a well-formed payload', () async {
      final manager = _manager(feedback: const []);

      final result = await manager.exportFeedback('user-uid');

      expect(result['submissions'], isEmpty);
      expect(result['total'], 0);
    });
  });
}
