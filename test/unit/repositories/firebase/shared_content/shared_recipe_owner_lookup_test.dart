/// BUT-1504: the owner's own share of a recipe is found by BOTH recipe keys the
/// two live writers use, only for the signed-in user, and only for recipes.
library;

import 'package:butlery/repositories/firebase/shared_content/shared_recipe_owner_lookup.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore db;
  late SharedRecipeOwnerLookup lookup;

  Future<void> row(
    String id, {
    String contentType = 'recipe',
    String sharedBy = 'me',
    Map<String, Object?> keys = const {},
    List<String> sharedTo = const ['me', 'friend'],
  }) => db.collection('shared_content').doc(id).set({
    'contentType': contentType,
    'sharedByUserId': sharedBy,
    'sharedToUserIds': sharedTo,
    ...keys,
  });

  setUp(() {
    db = FakeFirebaseFirestore();
    lookup = SharedRecipeOwnerLookup(
      db.collection('shared_content'),
      () => 'me',
    );
  });

  test('finds the row the share repository wrote (originalRecipeId)', () async {
    await row('a', keys: {'originalRecipeId': 'r1'});

    final found = await lookup.find('r1');

    expect(found?.id, 'a');
    expect(found?.ownerId, 'me');
    expect(found?.sharedToUserIds, ['me', 'friend']);
  });

  test('finds the row RecipeSharingManager wrote (recipeId)', () async {
    await row('b', keys: {'recipeId': 'r1'}, sharedTo: ['me', 'x', 'y']);

    final found = await lookup.find('r1');

    expect(found?.id, 'b');
    expect(found?.sharedToUserIds, ['me', 'x', 'y']);
  });

  test("never returns another user's share of the same recipe id", () async {
    await row('c', sharedBy: 'someone-else', keys: {'originalRecipeId': 'r1'});

    expect(await lookup.find('r1'), isNull);
  });

  test('never returns a menu or shopping row with a matching key', () async {
    await row('d', contentType: 'menu', keys: {'originalRecipeId': 'r1'});

    expect(await lookup.find('r1'), isNull);
  });

  test('an unshared recipe gives null', () async {
    await row('e', keys: {'originalRecipeId': 'r2'});

    expect(await lookup.find('r1'), isNull);
  });

  test('a row without a recipient list reads as no recipients', () async {
    await db.collection('shared_content').doc('f').set({
      'contentType': 'recipe',
      'sharedByUserId': 'me',
      'originalRecipeId': 'r1',
    });

    expect((await lookup.find('r1'))?.sharedToUserIds, isEmpty);
  });

  test('unions the recipients of every own row of the recipe', () async {
    await row('g', keys: {'originalRecipeId': 'r1'}, sharedTo: ['me', 'a']);
    await row('h', keys: {'recipeId': 'r1'}, sharedTo: ['me', 'b']);
    await row('i', keys: {'recipeId': 'r1'}, sharedTo: ['me', 'c', 'a']);

    final found = await lookup.find('r1');

    expect(found?.sharedToUserIds.toSet(), {'me', 'a', 'b', 'c'});
  });
}
