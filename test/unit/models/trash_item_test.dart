import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/trash_item.dart';

import '../../infrastructure/factories/recipe_factory.dart';

void main() {
  const owner = 'owner-uid';

  Recipe sharedRecipe() => RecipeFactory.build(
    id: 'recipe-1',
    title: 'Kycklinggryta',
    createdBy: owner,
    imageUrls: ['https://img/a.jpg', 'https://img/b.jpg'],
    type: RecipeType.collaborative,
    socialData: RecipeSocialData(
      ownerId: owner,
      ownerDisplayName: 'Ägaren',
      memberPermissions: {
        'friend-uid': ResourcePermission.editor,
        'other-uid': ResourcePermission.viewer,
      },
      allowGuestViewing: false,
      allowMemberInvites: true,
    ),
    realtimeData: const RecipeRealtimeData(
      activeEditorIds: ['friend-uid'],
      lastEditedByUserId: 'friend-uid',
      lastEditedByDisplayName: 'Vännen',
    ),
  ).copyWith(rev: 4);

  group('TrashItem.fromRecipe', () {
    test('keeps exactly 30 days from the clock, and nothing past it', () {
      final now = clock.now();
      final item = withClock(
        Clock.fixed(now),
        () => TrashItem.fromRecipe(sharedRecipe(), ownerId: owner),
      );

      expect(item.deletedAt, now.toUtc());
      // A literal, not keptFor: firestore.rules requires exactly 30 days.
      expect(
        item.expireAt.difference(item.deletedAt),
        const Duration(days: 30),
      );
      expect(item.isKeptAt(item.deletedAt), isTrue);
      expect(
        item.isKeptAt(item.expireAt.subtract(const Duration(microseconds: 1))),
        isTrue,
      );
      expect(item.isKeptAt(item.expireAt), isFalse);
      expect(
        item.isKeptAt(item.expireAt.add(const Duration(seconds: 1))),
        isFalse,
      );
    });

    test('the payload names nobody but its owner', () {
      final item = TrashItem.fromRecipe(sharedRecipe(), ownerId: owner);

      expect(item.payload.keys.toSet(), {'core', 'type', 'rev'});
      expect(item.payload.containsKey('socialData'), isFalse);
      expect(item.payload.containsKey('realtimeData'), isFalse);
      final stored = jsonEncode(item.toFirestore(), toEncodable: _encode);
      expect(stored, isNot(contains('friend-uid')));
      expect(stored, isNot(contains('other-uid')));
      expect(stored, isNot(contains('Vännen')));
    });

    test('comes back private, under its own id, at its revision', () {
      final item = TrashItem.fromRecipe(sharedRecipe(), ownerId: owner);

      final recipe = item.recipe;
      expect(recipe.id, 'recipe-1');
      expect(recipe.type, RecipeType.personal);
      expect(recipe.socialData, isNull);
      expect(recipe.createdBy, owner);
      expect(recipe.rev, 4);
      expect(recipe.ingredients, sharedRecipe().ingredients);
    });

    test('fills the list fields from the recipe', () {
      final item = TrashItem.fromRecipe(sharedRecipe(), ownerId: owner);

      expect(item.id, 'recipe-1');
      expect(item.sourceId, 'recipe-1');
      expect(item.ownerId, owner);
      expect(item.kind, TrashItemKind.recipe);
      expect(item.title, 'Kycklinggryta');
      expect(item.thumbnailUrl, 'https://img/a.jpg');
    });

    test('a recipe without images has no thumbnail', () {
      final item = TrashItem.fromRecipe(
        RecipeFactory.buildPersonal(id: 'r', createdBy: owner),
        ownerId: owner,
      );
      expect(item.thumbnailUrl, isNull);
      expect(item.payload.containsKey('rev'), isFalse);
    });

    test(
      'a long title is cut to the stored limit without splitting a char',
      () {
        // Literals, not maxTitleLength: firestore.rules caps the title at 200.
        final title = '${'a' * 199}😀tail';
        final item = TrashItem.fromRecipe(
          RecipeFactory.buildPersonal(id: 'r', title: title, createdBy: owner),
          ownerId: owner,
        );
        expect(item.title, 'a' * 199);
        expect(TrashItem.maxTitleLength, 200);
      },
    );
  });

  group('TrashItem Firestore round trip', () {
    test('reads back what it writes', () {
      final item = TrashItem.fromRecipe(sharedRecipe(), ownerId: owner);

      final back = TrashItem.fromFirestore(item.id, item.toFirestore())!;

      expect(back.ownerId, owner);
      expect(back.title, item.title);
      expect(back.thumbnailUrl, item.thumbnailUrl);
      expect(back.deletedAt, item.deletedAt);
      expect(back.expireAt, item.expireAt);
      expect(back.recipe.title, 'Kycklinggryta');
    });

    test('writes exactly the keys the rule allows', () {
      final item = TrashItem.fromRecipe(sharedRecipe(), ownerId: owner);
      expect(item.toFirestore().keys.toSet(), {
        'kind',
        'ownerId',
        'sourceId',
        'title',
        'thumbnailUrl',
        'payload',
        'deletedAt',
        'expireAt',
      });
      expect(item.toFirestore()['deletedAt'], isA<Timestamp>());
    });

    test('a row it cannot restore is not offered', () {
      final stored = TrashItem.fromRecipe(
        sharedRecipe(),
        ownerId: owner,
      ).toFirestore();

      expect(TrashItem.fromFirestore('x', {...stored, 'kind': 'list'}), isNull);
      expect(
        TrashItem.fromFirestore('x', {...stored}..remove('payload')),
        isNull,
      );
      expect(
        TrashItem.fromFirestore('x', {...stored}..remove('expireAt')),
        isNull,
      );
      expect(TrashItem.fromFirestore('x', {...stored, 'ownerId': ''}), isNull);
    });
  });
}

Object? _encode(Object? value) =>
    value is Timestamp ? value.toString() : '$value';
