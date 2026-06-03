/// Unit tests for RecipeTagOperations.
///
/// The module owns three denormalized-tag write paths on user recipes:
/// rename, remove, and batch-additive remove. All three depend only on
/// `firestore` and a `getCollectionForUser` callback, so we can drive
/// them end-to-end with `FakeFirebaseFirestore` without any auth wiring.
///
/// Coverage focus: short-circuit guards (empty/null inputs), happy-path
/// read-modify-write semantics, the rename vs remove field-update split,
/// and the batch-additive contract (no commit, no try/catch).
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/repositories/firebase/modules/recipe_tag_operations.dart';

const _userId = 'alice';

CollectionReference<Map<String, dynamic>> _userRecipes(
  FakeFirebaseFirestore firestore,
  String userId,
) =>
    firestore.collection('users').doc(userId).collection('recipes');

RecipeTagOperations _ops(FakeFirebaseFirestore firestore) =>
    RecipeTagOperations(
      firestore: firestore,
      getCollectionForUser: (userId) => _userRecipes(firestore, userId),
    );

Future<void> _seedRecipe(
  FakeFirebaseFirestore firestore, {
  required String userId,
  required String recipeId,
  required List<String> tagIds,
  List<Map<String, dynamic>>? tags,
}) async {
  await _userRecipes(firestore, userId).doc(recipeId).set({
    'core': {
      'personalTagIds': tagIds,
      'personalTags': tags ??
          tagIds.map((id) => {'tagId': id, 'name': 'name-$id'}).toList(),
    },
  });
}

void main() {
  group('renamePersonalTagInRecipes', () {
    test('returns 0 when tagId is empty', () async {
      final firestore = FakeFirebaseFirestore();
      expect(
        await _ops(firestore).renamePersonalTagInRecipes(_userId, '', 'new'),
        0,
      );
    });

    test('returns 0 when newName is empty', () async {
      final firestore = FakeFirebaseFirestore();
      expect(
        await _ops(firestore).renamePersonalTagInRecipes(_userId, 'tag-1', ''),
        0,
      );
    });

    test('returns 0 when userId is null', () async {
      final firestore = FakeFirebaseFirestore();
      expect(
        await _ops(firestore).renamePersonalTagInRecipes(null, 'tag-1', 'new'),
        0,
      );
    });

    test('returns 0 when no recipes match', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedRecipe(firestore,
          userId: _userId, recipeId: 'r1', tagIds: ['other-tag']);
      expect(
        await _ops(firestore)
            .renamePersonalTagInRecipes(_userId, 'missing-tag', 'new'),
        0,
      );
    });

    test('renames matching entry, leaves siblings untouched', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedRecipe(
        firestore,
        userId: _userId,
        recipeId: 'r1',
        tagIds: ['tag-a', 'tag-b'],
        tags: const [
          {'tagId': 'tag-a', 'name': 'old-a'},
          {'tagId': 'tag-b', 'name': 'name-b'},
        ],
      );

      final updated = await _ops(firestore)
          .renamePersonalTagInRecipes(_userId, 'tag-a', 'new-a');
      expect(updated, 1);

      final snap = await _userRecipes(firestore, _userId).doc('r1').get();
      final tags = (snap.data()!['core'] as Map)['personalTags'] as List;
      expect(tags, [
        {'tagId': 'tag-a', 'name': 'new-a'},
        {'tagId': 'tag-b', 'name': 'name-b'},
      ]);

      // personalTagIds unchanged on rename
      expect(
          (snap.data()!['core'] as Map)['personalTagIds'], ['tag-a', 'tag-b']);
    });

    test('renames across multiple recipes', () async {
      final firestore = FakeFirebaseFirestore();
      for (var i = 0; i < 3; i++) {
        await _seedRecipe(firestore,
            userId: _userId, recipeId: 'r$i', tagIds: ['tag-x']);
      }
      // a recipe without the tag should be ignored
      await _seedRecipe(firestore,
          userId: _userId, recipeId: 'other', tagIds: ['unrelated']);

      final updated = await _ops(firestore)
          .renamePersonalTagInRecipes(_userId, 'tag-x', 'renamed');
      expect(updated, 3);

      for (var i = 0; i < 3; i++) {
        final snap = await _userRecipes(firestore, _userId).doc('r$i').get();
        final tags = (snap.data()!['core'] as Map)['personalTags'] as List;
        expect((tags.single as Map)['name'], 'renamed');
      }
    });

    test('is idempotent — re-running with same name yields no logical diff',
        () async {
      final firestore = FakeFirebaseFirestore();
      await _seedRecipe(firestore,
          userId: _userId, recipeId: 'r1', tagIds: ['tag-a']);

      final first = await _ops(firestore)
          .renamePersonalTagInRecipes(_userId, 'tag-a', 'final');
      final second = await _ops(firestore)
          .renamePersonalTagInRecipes(_userId, 'tag-a', 'final');
      expect(first, 1);
      expect(second, 1);

      final snap = await _userRecipes(firestore, _userId).doc('r1').get();
      final tags = (snap.data()!['core'] as Map)['personalTags'] as List;
      expect((tags.single as Map)['name'], 'final');
    });

    test('skips docs whose personalTags array is missing', () async {
      final firestore = FakeFirebaseFirestore();
      // arrayContains hits because personalTagIds is set, but personalTags
      // is absent — the rename branch must noop without throwing.
      await _userRecipes(firestore, _userId).doc('r1').set({
        'core': {
          'personalTagIds': ['tag-a'],
        },
      });

      final updated = await _ops(firestore)
          .renamePersonalTagInRecipes(_userId, 'tag-a', 'new');
      // chunk.length still counts the doc — we assert no exception and the
      // doc was untouched.
      expect(updated, 1);

      final snap = await _userRecipes(firestore, _userId).doc('r1').get();
      expect(
          (snap.data()!['core'] as Map).containsKey('personalTags'), isFalse);
    });
  });

  group('removePersonalTagFromRecipes', () {
    test('returns 0 on empty tagId', () async {
      final firestore = FakeFirebaseFirestore();
      expect(
        await _ops(firestore).removePersonalTagFromRecipes(_userId, ''),
        0,
      );
    });

    test('returns 0 on null userId', () async {
      final firestore = FakeFirebaseFirestore();
      expect(
        await _ops(firestore).removePersonalTagFromRecipes(null, 'tag-a'),
        0,
      );
    });

    test('returns 0 when no matching recipes', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedRecipe(firestore,
          userId: _userId, recipeId: 'r1', tagIds: ['other']);
      expect(
        await _ops(firestore).removePersonalTagFromRecipes(_userId, 'missing'),
        0,
      );
    });

    test('removes tag from both personalTagIds and personalTags arrays',
        () async {
      final firestore = FakeFirebaseFirestore();
      await _seedRecipe(
        firestore,
        userId: _userId,
        recipeId: 'r1',
        tagIds: ['tag-a', 'tag-b'],
        tags: const [
          {'tagId': 'tag-a', 'name': 'name-a'},
          {'tagId': 'tag-b', 'name': 'name-b'},
        ],
      );

      final updated =
          await _ops(firestore).removePersonalTagFromRecipes(_userId, 'tag-a');
      expect(updated, 1);

      final snap = await _userRecipes(firestore, _userId).doc('r1').get();
      final core = snap.data()!['core'] as Map;
      expect(core['personalTagIds'], ['tag-b']);
      expect(core['personalTags'], [
        {'tagId': 'tag-b', 'name': 'name-b'},
      ]);
    });

    test('removes across multiple recipes', () async {
      final firestore = FakeFirebaseFirestore();
      for (var i = 0; i < 3; i++) {
        await _seedRecipe(firestore,
            userId: _userId, recipeId: 'r$i', tagIds: ['tag-x', 'keep']);
      }

      final updated =
          await _ops(firestore).removePersonalTagFromRecipes(_userId, 'tag-x');
      expect(updated, 3);

      for (var i = 0; i < 3; i++) {
        final snap = await _userRecipes(firestore, _userId).doc('r$i').get();
        expect((snap.data()!['core'] as Map)['personalTagIds'], ['keep']);
      }
    });

    test('tolerates missing personalTags rich array (only IDs present)',
        () async {
      final firestore = FakeFirebaseFirestore();
      await _userRecipes(firestore, _userId).doc('r1').set({
        'core': {
          'personalTagIds': ['tag-a'],
        },
      });

      final updated =
          await _ops(firestore).removePersonalTagFromRecipes(_userId, 'tag-a');
      expect(updated, 1);

      final snap = await _userRecipes(firestore, _userId).doc('r1').get();
      expect((snap.data()!['core'] as Map)['personalTagIds'], <String>[]);
    });
  });

  group('addRemovePersonalTagFromRecipesToBatch', () {
    test('returns 0 on empty tagId — batch stays untouched', () async {
      final firestore = FakeFirebaseFirestore();
      final batch = firestore.batch();
      expect(
        await _ops(firestore)
            .addRemovePersonalTagFromRecipesToBatch(_userId, batch, ''),
        0,
      );
    });

    test('returns 0 on null userId', () async {
      final firestore = FakeFirebaseFirestore();
      final batch = firestore.batch();
      expect(
        await _ops(firestore)
            .addRemovePersonalTagFromRecipesToBatch(null, batch, 'tag-a'),
        0,
      );
    });

    test('returns 0 when no matching recipes', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedRecipe(firestore,
          userId: _userId, recipeId: 'r1', tagIds: ['other']);
      final batch = firestore.batch();
      expect(
        await _ops(firestore)
            .addRemovePersonalTagFromRecipesToBatch(_userId, batch, 'missing'),
        0,
      );
    });

    test('does NOT commit — caller owns the batch lifecycle', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedRecipe(firestore,
          userId: _userId, recipeId: 'r1', tagIds: ['tag-a']);

      final batch = firestore.batch();
      final count = await _ops(firestore)
          .addRemovePersonalTagFromRecipesToBatch(_userId, batch, 'tag-a');
      expect(count, 1);

      // Without commit, the doc is unchanged.
      final beforeCommit =
          await _userRecipes(firestore, _userId).doc('r1').get();
      expect(
        (beforeCommit.data()!['core'] as Map)['personalTagIds'],
        ['tag-a'],
      );

      // Caller commits — only then does the update apply.
      await batch.commit();
      final afterCommit =
          await _userRecipes(firestore, _userId).doc('r1').get();
      expect(
        (afterCommit.data()!['core'] as Map)['personalTagIds'],
        <String>[],
      );
    });

    test('adds updates for all matching docs', () async {
      final firestore = FakeFirebaseFirestore();
      for (var i = 0; i < 4; i++) {
        await _seedRecipe(firestore,
            userId: _userId, recipeId: 'r$i', tagIds: ['tag-x']);
      }
      final batch = firestore.batch();
      final count = await _ops(firestore)
          .addRemovePersonalTagFromRecipesToBatch(_userId, batch, 'tag-x');
      expect(count, 4);

      await batch.commit();
      for (var i = 0; i < 4; i++) {
        final snap = await _userRecipes(firestore, _userId).doc('r$i').get();
        expect((snap.data()!['core'] as Map)['personalTagIds'], <String>[]);
      }
    });
  });

  group('addReplaceTagInRecipesToBatch', () {
    // The rich entry the repo appends to recipes that don't already carry the
    // destination tag — mirrors RecipePersonalTag.manual(...).toMap().
    const toRichEntry = {
      'tagId': 'to-tag',
      'name': 'Destination',
      'sources': ['manual'],
    };

    test('returns 0 on empty fromTagId', () async {
      final firestore = FakeFirebaseFirestore();
      final batch = firestore.batch();
      expect(
        await _ops(firestore).addReplaceTagInRecipesToBatch(
            _userId, batch, '', 'to-tag', toRichEntry),
        0,
      );
    });

    test('returns 0 on empty toTagId', () async {
      final firestore = FakeFirebaseFirestore();
      final batch = firestore.batch();
      expect(
        await _ops(firestore).addReplaceTagInRecipesToBatch(
            _userId, batch, 'from-tag', '', toRichEntry),
        0,
      );
    });

    test('returns 0 on null userId', () async {
      final firestore = FakeFirebaseFirestore();
      final batch = firestore.batch();
      expect(
        await _ops(firestore).addReplaceTagInRecipesToBatch(
            null, batch, 'from-tag', 'to-tag', toRichEntry),
        0,
      );
    });

    test('returns 0 when fromTagId == toTagId (defensive no-op)', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedRecipe(firestore,
          userId: _userId, recipeId: 'r1', tagIds: ['same']);
      final batch = firestore.batch();
      expect(
        await _ops(firestore).addReplaceTagInRecipesToBatch(
            _userId, batch, 'same', 'same', toRichEntry),
        0,
      );
    });

    test('returns 0 when no recipes carry fromTagId', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedRecipe(firestore,
          userId: _userId, recipeId: 'r1', tagIds: ['other']);
      final batch = firestore.batch();
      expect(
        await _ops(firestore).addReplaceTagInRecipesToBatch(
            _userId, batch, 'from-tag', 'to-tag', toRichEntry),
        0,
      );
    });

    test('swaps fromTagId for toTagId in both arrays', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedRecipe(
        firestore,
        userId: _userId,
        recipeId: 'r1',
        tagIds: ['from-tag', 'keep'],
        tags: const [
          {
            'tagId': 'from-tag',
            'name': 'Old',
            'sources': ['manual']
          },
          {
            'tagId': 'keep',
            'name': 'Keep',
            'sources': ['manual']
          },
        ],
      );

      final batch = firestore.batch();
      final count = await _ops(firestore).addReplaceTagInRecipesToBatch(
          _userId, batch, 'from-tag', 'to-tag', toRichEntry);
      expect(count, 1);
      await batch.commit();

      final core = (await _userRecipes(firestore, _userId).doc('r1').get())
          .data()!['core'] as Map;

      // (a) fromId gone, toId present in personalTagIds
      expect(core['personalTagIds'], containsAll(['keep', 'to-tag']));
      expect(core['personalTagIds'], isNot(contains('from-tag')));
      expect((core['personalTagIds'] as List).length, 2);

      // (c) rich array: from-tag entry gone, to-tag entry appended
      final tags = (core['personalTags'] as List).cast<Map>();
      final tagIds = tags.map((t) => t['tagId']).toList();
      expect(tagIds, containsAll(['keep', 'to-tag']));
      expect(tagIds, isNot(contains('from-tag')));
      final toEntry = tags.firstWhere((t) => t['tagId'] == 'to-tag');
      expect(toEntry['name'], 'Destination');
      expect(toEntry['sources'], ['manual']);
    });

    test('does NOT duplicate toTagId when recipe already had it', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedRecipe(
        firestore,
        userId: _userId,
        recipeId: 'r1',
        tagIds: ['from-tag', 'to-tag'],
        tags: const [
          {
            'tagId': 'from-tag',
            'name': 'Old',
            'sources': ['manual']
          },
          {
            'tagId': 'to-tag',
            'name': 'Destination',
            'sources': ['manual']
          },
        ],
      );

      final batch = firestore.batch();
      final count = await _ops(firestore).addReplaceTagInRecipesToBatch(
          _userId, batch, 'from-tag', 'to-tag', toRichEntry);
      expect(count, 1);
      await batch.commit();

      final core = (await _userRecipes(firestore, _userId).doc('r1').get())
          .data()!['core'] as Map;

      // (b) no duplicate toId in personalTagIds
      expect(core['personalTagIds'], ['to-tag']);

      // (c) no duplicate toId entry in rich array, existing entry preserved
      final tags = (core['personalTags'] as List).cast<Map>();
      expect(tags.length, 1);
      expect(tags.single['tagId'], 'to-tag');
      expect(tags.single['name'], 'Destination');
    });

    test('leaves recipes without fromTagId untouched', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedRecipe(firestore,
          userId: _userId, recipeId: 'with', tagIds: ['from-tag']);
      await _seedRecipe(
        firestore,
        userId: _userId,
        recipeId: 'without',
        tagIds: ['unrelated'],
        tags: const [
          {
            'tagId': 'unrelated',
            'name': 'Unrelated',
            'sources': ['manual']
          },
        ],
      );

      final batch = firestore.batch();
      final count = await _ops(firestore).addReplaceTagInRecipesToBatch(
          _userId, batch, 'from-tag', 'to-tag', toRichEntry);
      // (e) affected count counts only the matching doc
      expect(count, 1);
      await batch.commit();

      // (d) the untouched recipe is unchanged
      final without =
          (await _userRecipes(firestore, _userId).doc('without').get())
              .data()!['core'] as Map;
      expect(without['personalTagIds'], ['unrelated']);
      expect(without['personalTags'], [
        {
          'tagId': 'unrelated',
          'name': 'Unrelated',
          'sources': ['manual']
        },
      ]);
    });

    test('does NOT commit — caller owns the batch lifecycle', () async {
      final firestore = FakeFirebaseFirestore();
      await _seedRecipe(firestore,
          userId: _userId, recipeId: 'r1', tagIds: ['from-tag']);

      final batch = firestore.batch();
      await _ops(firestore).addReplaceTagInRecipesToBatch(
          _userId, batch, 'from-tag', 'to-tag', toRichEntry);

      // Uncommitted: still carries fromTag.
      final before = (await _userRecipes(firestore, _userId).doc('r1').get())
          .data()!['core'] as Map;
      expect(before['personalTagIds'], ['from-tag']);
    });
  });
}
