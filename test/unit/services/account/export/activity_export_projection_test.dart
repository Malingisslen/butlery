/// BUT-2062: the comments and ratings sections of the Art. 15 bundle are
/// PROJECTED through an allowlist, and the projection is held against the
/// writers rather than against a hand-kept list.
///
/// Three things are pinned here, and they fail in different directions:
///
/// 1. Fail-closed — a field the allowlist does not name does not travel. This
///    is what stops a third party's uid reaching somebody else's bundle.
/// 2. Writer-derived — every key the models can emit is either exported or
///    deliberately withheld. This is the direction that reddens NOTHING
///    without a test: a writer gains a field, the projection does not, and the
///    user's own content disappears from their own bundle in silence.
/// 3. The `data_minimisation` sentence is byte-identical on every path,
///    including the failure branch. It bears a fact about third parties, so
///    per BUT-2056 a note that varied would reconstruct what it withholds.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/recipe_comment.dart';
import 'package:butlery/repositories/interfaces/comments_repository.dart';
import 'package:butlery/repositories/interfaces/ratings_repository.dart';
import 'package:butlery/services/account/export/activity_export_manager.dart';

class _FakeCommentsRepository extends Fake implements CommentsRepository {
  _FakeCommentsRepository(this.rows);
  final List<Map<String, dynamic>> rows;

  @override
  Future<List<Map<String, dynamic>>> exportCommentsByAuthor(
    String userId, {
    int maxDocuments = -1,
  }) async => rows;
}

class _FakeRatingsRepository extends Fake implements RatingsRepository {
  _FakeRatingsRepository(this.rows);
  final List<Map<String, dynamic>> rows;

  @override
  Future<List<Map<String, dynamic>>> exportRatingsByUser(
    String userId, {
    int maxDocuments = -1,
  }) async => rows;
}

class _ThrowingCommentsRepository extends Fake implements CommentsRepository {
  @override
  Future<List<Map<String, dynamic>>> exportCommentsByAuthor(
    String userId, {
    int maxDocuments = -1,
  }) async => throw StateError('firestore unavailable');
}

ActivityExportManager _manager({
  List<Map<String, dynamic>> comments = const [],
  List<Map<String, dynamic>> ratings = const [],
}) => ActivityExportManager(
  commentsRepository: _FakeCommentsRepository(comments),
  ratingsRepository: _FakeRatingsRepository(ratings),
);

/// A comment document carrying every field a writer can emit, so the
/// projection is measured against the real surface rather than a subset.
Map<String, dynamic> _wholeCommentDocument() => {
  'recipeId': 'recipe-1',
  'authorId': 'me',
  'authorDisplayName': 'Jag',
  'authorAvatarUrl': 'https://example.test/me.png',
  'text': 'Mycket god!',
  'createdAt': '2026-09-10T00:00:00.000',
  'updatedAt': '2026-09-10T00:00:00.000',
  'editedAt': null,
  'likesCount': 2,
  'parentCommentId': null,
  'replyCount': 0,
  'isDeleted': false,
  'reactions': <String, List<String>>{
    '👍': <String>['someone-else'],
  },
  'recipeOwnerId': 'the-recipe-owner',
  'sharedWithUserIds': <String>['friend-a', 'friend-b'],
  'imageUrls': <String>['https://example.test/img.jpg?token=abc'],
};

Map<String, dynamic> _wholeRatingDocument() => {
  'recipeId': 'recipe-1',
  'userId': 'me',
  'rating': 4.0,
  'review': 'Gick snabbt.',
  'createdAt': '2026-09-10T00:00:00.000',
  'updatedAt': '2026-09-10T00:00:00.000',
  'recipeOwnerId': 'the-recipe-owner',
};

void main() {
  group('BUT-2062: the sections fail CLOSED', () {
    test('every withheld comment field is absent, and every kept one is '
        'present', () async {
      final result = await _manager(
        comments: [
          {'id': 'c1', 'data': _wholeCommentDocument()},
        ],
      ).exportCommentsAndRatings('me');

      final row = (result['comments'] as List).single as Map<String, dynamic>;
      final data = row['data'] as Map<String, dynamic>;

      for (final withheld in ActivityExportManager.commentFieldsWithheld) {
        expect(
          data.containsKey(withheld),
          isFalse,
          reason:
              '$withheld reached the bundle. It names somebody other than the '
              'requester, or it is the query filter restated.',
        );
      }
      for (final kept in ActivityExportManager.commentFieldsExported) {
        expect(
          data.containsKey(kept),
          isTrue,
          reason:
              '$kept is declared exported but did not travel — the requester '
              'lost their own content out of their own bundle.',
        );
      }
    });

    test('every withheld rating field is absent, and every kept one is '
        'present', () async {
      final result = await _manager(
        ratings: [
          {'id': 'recipe-1_me', 'data': _wholeRatingDocument()},
        ],
      ).exportCommentsAndRatings('me');

      final row = (result['ratings'] as List).single as Map<String, dynamic>;
      final data = row['data'] as Map<String, dynamic>;

      for (final withheld in ActivityExportManager.ratingFieldsWithheld) {
        expect(data.containsKey(withheld), isFalse, reason: '$withheld leaked');
      }
      for (final kept in ActivityExportManager.ratingFieldsExported) {
        expect(data.containsKey(kept), isTrue, reason: '$kept was dropped');
      }
    });

    test('a field NOBODY has declared does not travel — the create limbs use '
        'hasRequiredFields, not hasOnly, so a client can store one', () async {
      final planted = _wholeCommentDocument()
        ..['aFieldNoWriterEmits'] = 'planted by a hand-rolled client';

      final result = await _manager(
        comments: [
          {'id': 'c1', 'data': planted},
        ],
      ).exportCommentsAndRatings('me');

      final data =
          ((result['comments'] as List).single as Map<String, dynamic>)['data']
              as Map<String, dynamic>;
      expect(data.containsKey('aFieldNoWriterEmits'), isFalse);
      // Self-contained: without this, a projection that returned an EMPTY map
      // for everything would satisfy the assertion above. The sibling loop
      // case catches that mutant today, so this is the case standing on its
      // own feet rather than on its neighbour's.
      expect(data.containsKey('text'), isTrue);
    });

    test('the rating_id still carries the uid — the field is dropped, the '
        'identifier is not gone', () async {
      final result = await _manager(
        ratings: [
          {'id': 'recipe-1_me', 'data': _wholeRatingDocument()},
        ],
      ).exportCommentsAndRatings('me');

      final row = (result['ratings'] as List).single as Map<String, dynamic>;
      expect(row['rating_id'], 'recipe-1_me');
    });
  });

  group('BUT-2062: the projection is held against the WRITERS', () {
    test('every key RecipeComment.toFirestore can emit is exported or '
        'deliberately withheld', () {
      final written =
          RecipeComment(
              id: 'c1',
              recipeId: 'recipe-1',
              authorId: 'me',
              authorDisplayName: 'Jag',
              authorAvatarUrl: 'https://example.test/me.png',
              text: 'Mycket god!',
              createdAt: DateTime(2026, 9, 10),
              editedAt: DateTime(2026, 9, 10),
              recipeOwnerId: 'the-recipe-owner',
              sharedWithUserIds: const ['friend-a'],
              imageUrls: const ['https://example.test/img.jpg'],
              reactions: const {
                '👍': ['someone-else'],
              },
            ).toFirestore().keys.toSet()
            // Not on the model: the repository stamps it on create and on update.
            ..add('updatedAt');

      final decided = {
        ...ActivityExportManager.commentFieldsExported,
        ...ActivityExportManager.commentFieldsWithheld,
      };

      expect(
        written.difference(decided),
        isEmpty,
        reason:
            'A writer emits a field nobody decided about. Fail-closed means '
            'it is being dropped from the bundle in silence — add it to the '
            'exported list or to the withheld list, with a reason.',
      );
    });

    test('every key RecipeRating.toFirestore can emit is exported or '
        'deliberately withheld', () {
      // `recipeOwnerId` is emitted only when set, so the fixture sets it.
      final written = RecipeRating(
        id: 'recipe-1_me',
        recipeId: 'recipe-1',
        userId: 'me',
        rating: 4,
        review: 'Gick snabbt.',
        createdAt: DateTime(2026, 9, 10),
        updatedAt: DateTime(2026, 9, 10),
        recipeOwnerId: 'the-recipe-owner',
      ).toFirestore().keys.toSet();

      final decided = {
        ...ActivityExportManager.ratingFieldsExported,
        ...ActivityExportManager.ratingFieldsWithheld,
      };

      expect(
        written.difference(decided),
        isEmpty,
        reason:
            'RecipeRating emits a field nobody decided about. Fail-closed '
            'means it is being dropped from the bundle in silence — add it to '
            'the exported list or to the withheld list, with a reason.',
      );
    });

    // The fixtures above are hand-kept while the writer tests above derive
    // from the models. A withheld field missing from `_wholeCommentDocument` would make
    // its `containsKey(...) isFalse` assertion unfailable, so bind the two.
    test('the whole-document fixture carries every decided comment field', () {
      final decided = {
        ...ActivityExportManager.commentFieldsExported,
        ...ActivityExportManager.commentFieldsWithheld,
      };
      expect(
        _wholeCommentDocument().keys.toSet().containsAll(decided),
        isTrue,
        reason:
            'a decided field the fixture does not carry cannot be asserted '
            'absent — that assertion would pass for free',
      );
    });

    test('the whole-document fixture carries every decided rating field', () {
      final decided = {
        ...ActivityExportManager.ratingFieldsExported,
        ...ActivityExportManager.ratingFieldsWithheld,
      };
      expect(
        _wholeRatingDocument().keys.toSet().containsAll(decided),
        isTrue,
        reason:
            'the ratings presence loops carry the same hazard as the comment '
            'ones — an absent fixture key makes an absence assertion unfailable',
      );
    });

    test('the exported and withheld lists do not overlap', () {
      expect(
        ActivityExportManager.commentFieldsExported.toSet().intersection(
          ActivityExportManager.commentFieldsWithheld.toSet(),
        ),
        isEmpty,
      );
      expect(
        ActivityExportManager.ratingFieldsExported.toSet().intersection(
          ActivityExportManager.ratingFieldsWithheld.toSet(),
        ),
        isEmpty,
      );
    });
  });

  group('BUT-2062/BUT-2056: the note is byte-invariant', () {
    test('an empty read, a populated one and a refusal carry the same '
        'sentence', () async {
      final empty = await _manager().exportCommentsAndRatings('me');
      final populated = await _manager(
        comments: [
          {'id': 'c1', 'data': _wholeCommentDocument()},
        ],
        ratings: [
          {'id': 'recipe-1_me', 'data': _wholeRatingDocument()},
        ],
      ).exportCommentsAndRatings('me');
      final failed = await ActivityExportManager(
        commentsRepository: _ThrowingCommentsRepository(),
        ratingsRepository: _FakeRatingsRepository(const []),
      ).exportCommentsAndRatings('me');

      final note = empty['data_minimisation'] as String;
      expect(note, isNotEmpty);
      // The note IS the Art. 12(1) disclosure, so pin what it says and not
      // only that it says the same thing everywhere: invariance alone stays
      // green through a rewrite that claims the opposite.
      expect(note, contains('identifiers belonging to other people are not'));
      expect(note, contains('who reacted to your comment'));
      expect(populated['data_minimisation'], note);
      expect(
        failed['data_minimisation'],
        note,
        reason:
            'The failure branch dropped the note. A note that only appears '
            'when the read succeeded says something about what the read '
            'found.',
      );
      expect(failed['error_code'], 'comments-and-ratings-export-failed');
    });
  });
}
