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

import 'package:butlery/repositories/firebase/firebase_data_export_repository.dart';
import 'package:butlery/repositories/interfaces/comments_repository.dart';
import 'package:butlery/repositories/interfaces/feedback_repository.dart';
import 'package:butlery/repositories/interfaces/ratings_repository.dart';
import 'package:butlery/services/account/export/activity_export_manager.dart';
import 'package:butlery/services/account/export/export_pagination_helper.dart';

// The `maxDocuments` sentinel below is -1, a value no real caller passes, so a
// production path that stops forwarding its cap fails the forwarding test
// instead of coincidentally matching the repository's own default.
class _FakeCommentsRepository extends Fake implements CommentsRepository {
  _FakeCommentsRepository(this.rows);
  final List<Map<String, dynamic>> rows;
  String? capturedUserId;
  int? capturedMaxDocuments;

  @override
  Future<List<Map<String, dynamic>>> exportCommentsByAuthor(
    String userId, {
    int maxDocuments = -1,
  }) async {
    capturedUserId = userId;
    capturedMaxDocuments = maxDocuments;
    return rows;
  }
}

class _FakeRatingsRepository extends Fake implements RatingsRepository {
  _FakeRatingsRepository(this.rows);
  final List<Map<String, dynamic>> rows;
  int? capturedMaxDocuments;

  @override
  Future<List<Map<String, dynamic>>> exportRatingsByUser(
    String userId, {
    int maxDocuments = -1,
  }) async {
    capturedMaxDocuments = maxDocuments;
    return rows;
  }
}

class _FakeFeedbackRepository extends Fake implements FeedbackRepository {
  _FakeFeedbackRepository(this.rows);
  final List<Map<String, dynamic>> rows;
  int? capturedMaxDocuments;

  @override
  Future<List<Map<String, dynamic>>> exportFeedbackByUser(
    String userId, {
    int maxDocuments = -1,
  }) async {
    capturedMaxDocuments = maxDocuments;
    return rows;
  }
}

/// Pooled-rating events have no typed repository — they read through the
/// export gateway, so the seam is [FirebaseDataExportRepository].
class _FakePooledEventsRepository extends Fake
    implements FirebaseDataExportRepository {
  _FakePooledEventsRepository(this.rows, {this.throwOnRead = false});
  final List<Map<String, dynamic>> rows;
  final bool throwOnRead;
  int? capturedMaxDocuments;
  String? capturedUserId;

  @override
  Future<List<Map<String, dynamic>>> exportCanonicalRatingEvents(
    String userId, {
    int maxDocuments = -1,
  }) async {
    capturedUserId = userId;
    capturedMaxDocuments = maxDocuments;
    if (throwOnRead) throw StateError('firestore unavailable');
    return rows;
  }
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

/// BUT-1721: a comments repository whose capped read throws, carrying exactly
/// the text that must never reach the data subject.
///
/// The aggregator's leak test is a CONTROL, not coverage of this: it derives
/// the bundle-root message, so it passes with the leak still present in the
/// section body — and the section body is what the user downloads.
class _ThrowingCommentsRepository extends Fake implements CommentsRepository {
  static const String foreignUid = 'uid-of-another-person-9f2e45';

  @override
  Future<List<Map<String, dynamic>>> exportCommentsByAuthor(
    String userId, {
    int maxDocuments = -1,
  }) async => throw StateError(
    'PERMISSION_DENIED reading recipe_comments/me_$foreignUid; '
    'https://console.firebase.google.com/project/butlery-prod-42/firestore/'
    'indexes?create_composite=memberPermissions.$foreignUid',
  );
}

/// A row with a stable, per-index id so a trimmed payload can be told apart
/// from a re-ordered one.
Map<String, dynamic> _row(String prefix, int i) => {
  'id': '$prefix$i',
  'data': {'n': i},
};

void main() {
  group('ActivityExportManager failure envelope (BUT-1721)', () {
    test('a failed comments-and-ratings read carries a stable token and never '
        'the raw exception', () async {
      final manager = ActivityExportManager(
        commentsRepository: _ThrowingCommentsRepository(),
        ratingsRepository: _FakeRatingsRepository(const []),
        feedbackRepository: _FakeFeedbackRepository(const []),
      );

      final result = await manager.exportCommentsAndRatings('u1');

      expect(
        result['error_code'],
        'comments-and-ratings-export-failed',
        reason:
            'the token is what DataExportService lifts to bundle level; '
            'without it the section can fail while the bundle reads complete',
      );
      expect(
        result['error'] as String,
        isNot(contains(_ThrowingCommentsRepository.foreignUid)),
        reason:
            'another data subject`s uid must not ship inside the requester`s '
            'Art. 15 bundle',
      );
      expect(
        result['error'] as String,
        isNot(contains('create_composite')),
        reason: 'an index URL names the project and a member field path',
      );
      expect(
        result['error'],
        'Comments and ratings could not be exported.',
        reason:
            'the sentence is authored and stable — pinning it is what makes '
            'the two assertions above non-vacuous',
      );
    });
  });

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
      expect(result.containsKey('truncated'), isFalse);
    });
  });

  // BUT-1698: both of this manager's record sections applied a document cap and
  // emitted no `truncated` key at all, so a user over the cap silently received
  // a clipped Article 15/20 bundle labelled complete. They now run the same N+1
  // probe as the preferences sections (BUT-1662): fetch cap + 1, flag only when
  // a row past the cap really exists, trim to the cap.
  group('ActivityExportManager.exportCommentsAndRatings truncation '
      '(BUT-1698)', () {
    final commentCap = ExportPaginationHelper.getLimitForType('comments');
    final ratingCap = ExportPaginationHelper.getLimitForType('ratings');

    ActivityExportManager managerWith({int comments = 0, int ratings = 0}) =>
        _manager(
          comments: List.generate(comments, (i) => _row('c', i)),
          ratings: List.generate(ratings, (i) => _row('r', i)),
        );

    test('omits truncated when both legs sit exactly at their cap', () async {
      // Boundary: exactly `cap` records IS the complete set. A `length >= cap`
      // rule would claim data was withheld when none was.
      final result = await managerWith(
        comments: commentCap,
        ratings: ratingCap,
      ).exportCommentsAndRatings('user-uid');

      expect(result['total_comments'], commentCap);
      expect(result['total_ratings'], ratingCap);
      expect(result.containsKey('truncated'), isFalse);
    });

    test('flags truncated and trims when the COMMENTS leg is over', () async {
      final result = await managerWith(
        comments: commentCap + 1,
        ratings: 2,
      ).exportCommentsAndRatings('user-uid');

      final comments = (result['comments'] as List)
          .cast<Map<String, dynamic>>();
      expect(result['truncated'], isTrue);
      expect(comments.length, commentCap);
      expect(result['total_comments'], commentCap);
      // The probe row itself must never reach the bundle.
      expect(
        comments.map((c) => c['comment_id']),
        isNot(contains('c$commentCap')),
      );
    });

    test('flags truncated when only the RATINGS leg is over', () async {
      // The two legs carry their caps independently, so the OR needs a positive
      // case per leg — a collapse to one leg would ship silently.
      final result = await managerWith(
        comments: 2,
        ratings: ratingCap + 1,
      ).exportCommentsAndRatings('user-uid');

      expect(result['truncated'], isTrue);
      expect(result['total_ratings'], ratingCap);
      expect(result['total_comments'], 2);
    });

    test('forwards cap + 1 to both repository queries', () async {
      final commentsRepo = _FakeCommentsRepository(const []);
      final ratingsRepo = _FakeRatingsRepository(const []);
      final manager = ActivityExportManager(
        commentsRepository: commentsRepo,
        ratingsRepository: ratingsRepo,
        feedbackRepository: _FakeFeedbackRepository(const []),
      );

      await manager.exportCommentsAndRatings('user-uid');

      expect(commentsRepo.capturedMaxDocuments, commentCap + 1);
      expect(ratingsRepo.capturedMaxDocuments, ratingCap + 1);
    });
  });

  group('ActivityExportManager.exportFeedback truncation (BUT-1698)', () {
    // This section was riding the repository's own default cap, so the limit is
    // now declared in exportLimits at that same value — the probe was added
    // without shrinking anyone's export.
    final cap = ExportPaginationHelper.getLimitForType('feedback');

    test('the declared cap still equals the repository default it replaced', () {
      // exportLimits' comment claims 'feedback': 1000 was "pinned at the
      // repository default this section was already riding … without shrinking
      // anyone's export". That claim spans two files with nothing tying the two
      // numbers together, and every other test here derives the cap from
      // getLimitForType, so all of them would follow a silent change. This is
      // the one literal pin: FeedbackRepository.exportFeedbackByUser (and
      // FirebaseFeedbackRepository's implementation) both default maxDocuments
      // to 1000. If either side moves, "behaviour unchanged" stops being true
      // and the export starts clipping or over-reading without a review.
      expect(cap, 1000);
    });

    test('omits truncated when exactly at the cap', () async {
      final manager = _manager(
        feedback: List.generate(cap, (i) => _row('f', i)),
      );

      final result = await manager.exportFeedback('user-uid');

      expect(result['total'], cap);
      expect(result.containsKey('truncated'), isFalse);
    });

    test('flags truncated and trims when more than the cap exist', () async {
      final manager = _manager(
        feedback: List.generate(cap + 1, (i) => _row('f', i)),
      );

      final result = await manager.exportFeedback('user-uid');

      final submissions = (result['submissions'] as List)
          .cast<Map<String, dynamic>>();
      expect(result['truncated'], isTrue);
      expect(submissions.length, cap);
      expect(result['total'], cap);
      // Submissions are unwrapped to their `data`, so the probe row is spotted
      // by its payload rather than its id.
      expect(submissions.map((s) => s['n']), isNot(contains(cap)));
    });

    test('forwards cap + 1 to the repository query', () async {
      final feedbackRepo = _FakeFeedbackRepository(const []);
      final manager = ActivityExportManager(
        commentsRepository: _FakeCommentsRepository(const []),
        ratingsRepository: _FakeRatingsRepository(const []),
        feedbackRepository: feedbackRepo,
      );

      await manager.exportFeedback('user-uid');

      expect(feedbackRepo.capturedMaxDocuments, cap + 1);
    });
  });

  // BUT-1686: the pooled-rating-events section moved onto the N+1 probe in
  // BUT-1662 but shipped without a boundary test, so the exact case that ticket
  // exists to prevent — a bundle holding exactly `limit` events falsely
  // declaring itself clipped — was unproven here.
  group('ActivityExportManager.exportPooledRatingEvents (BUT-1686)', () {
    final cap = ExportPaginationHelper.getLimitForType(
      'canonical_rating_events',
    );

    ActivityExportManager managerWith(int count) => ActivityExportManager(
      commentsRepository: _FakeCommentsRepository(const []),
      ratingsRepository: _FakeRatingsRepository(const []),
      feedbackRepository: _FakeFeedbackRepository(const []),
      dataExportRepository: _FakePooledEventsRepository(
        List.generate(count, (i) => _row('pe', i)),
      ),
    );

    test(
      'omits truncated when exactly at the cap (nothing left out)',
      () async {
        final result = await managerWith(cap).exportPooledRatingEvents('u1');

        expect(result.containsKey('error'), isFalse);
        expect((result['events'] as List).length, cap);
        expect(result['total_count'], cap);
        expect(
          result.containsKey('truncated'),
          isFalse,
          reason:
              'the bundle holds every pooled-rating event the user has, so it '
              'must not declare itself clipped',
        );
      },
    );

    test('flags truncated and trims the payload to exactly the cap', () async {
      final result = await managerWith(cap + 1).exportPooledRatingEvents('u1');

      final events = (result['events'] as List).cast<Map<String, dynamic>>();
      expect(result['truncated'], isTrue);
      expect(events.length, cap);
      expect(events.map((e) => e['id']), isNot(contains('pe$cap')));
      expect((events.first['data'] as Map)['n'], 0);
    });

    test(
      'total_count counts the included events, not the N+1 probe fetch',
      () async {
        // A regression that counted the pre-trim fetch would ship `cap` events
        // while claiming cap + 1 — a manifest disagreeing with its contents.
        final result = await managerWith(
          cap + 1,
        ).exportPooledRatingEvents('u1');

        expect(result['total_count'], (result['events'] as List).length);
        expect(result['total_count'], isNot(cap + 1));
      },
    );

    test('forwards cap + 1 to the repository query for this user', () async {
      final repo = _FakePooledEventsRepository(const []);
      final manager = ActivityExportManager(
        commentsRepository: _FakeCommentsRepository(const []),
        ratingsRepository: _FakeRatingsRepository(const []),
        feedbackRepository: _FakeFeedbackRepository(const []),
        dataExportRepository: repo,
      );

      await manager.exportPooledRatingEvents('user-42');

      expect(repo.capturedMaxDocuments, cap + 1);
      expect(repo.capturedUserId, 'user-42');
    });

    test('the pseudonymity note ships on every successful export', () async {
      // Decision 12 / Breyer C-582/14: each event links the account to a
      // reproducible recipe-identity hash, so the bundle must never present
      // this section as anonymous data.
      final result = await managerWith(1).exportPooledRatingEvents('u1');

      expect(result['note'], contains('Pseudonymous'));
    });

    test('a failed read surfaces an error_code, not a silent empty '
        'section', () async {
      // A bare {'error': ...} would let an incomplete Article 15 export look
      // complete; the code is what the bundle's warnings aggregator keys off.
      final manager = ActivityExportManager(
        commentsRepository: _FakeCommentsRepository(const []),
        ratingsRepository: _FakeRatingsRepository(const []),
        feedbackRepository: _FakeFeedbackRepository(const []),
        dataExportRepository: _FakePooledEventsRepository(
          const [],
          throwOnRead: true,
        ),
      );

      final result = await manager.exportPooledRatingEvents('u1');

      expect(result['error_code'], 'pooled-rating-events-export-failed');
      expect(result.containsKey('events'), isFalse);
    });
  });
}
