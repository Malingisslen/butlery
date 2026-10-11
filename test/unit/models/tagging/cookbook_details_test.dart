import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/tagging/cookbook_details.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/models/tagging/personal_tag_rule.dart';
import 'package:butlery/services/tagging/cookbook_service.dart';

PersonalTag _tagFromFirestoreMap(Map<String, dynamic> map) {
  // toFirestore writes Timestamps; fromMap reads them back the same way.
  return PersonalTag.fromMap('t1', map);
}

void main() {
  final now = DateTime(2026, 10, 10);
  const cookbook = CookbookDetails(
    description: 'Det Inga lagade varje söndag.',
    cover: CookbookCover(
      kind: CookbookCoverKind.recipe,
      colorKey: 'orange',
      recipeId: 'r2',
    ),
    recipeOrder: ['r2', 'r1'],
    recipeNotes: {'r1': 'Dubbla satsen till jul.'},
  );

  group('PersonalTag.cookbook', () {
    test('a tag without the map is not a cookbook', () {
      final tag = PersonalTag.fromMap('t1', {
        'name': 'Snabbt',
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });
      expect(tag.isCookbook, isFalse);
      expect(tag.toFirestore().containsKey('cookbook'), isFalse);
    });

    test('round-trips through Firestore and JSON', () {
      final tag = PersonalTag(
        id: 't1',
        name: 'Mormors favoriter',
        createdAt: now,
        updatedAt: now,
        cookbook: cookbook,
      );
      expect(_tagFromFirestoreMap(tag.toFirestore()).cookbook, cookbook);
      expect(PersonalTag.fromJson(tag.toJson()).cookbook, cookbook);
    });

    test('an own-photo cover keeps its photo through Firestore', () {
      const photoBook = CookbookDetails(
        cover: CookbookCover(
          kind: CookbookCoverKind.photo,
          imageUrl: 'https://img/a.jpg',
        ),
      );
      final tag = PersonalTag(
        id: 't1',
        name: 'Jul',
        createdAt: now,
        updatedAt: now,
        cookbook: photoBook,
      );
      final parsed = _tagFromFirestoreMap(tag.toFirestore()).cookbook!;
      expect(parsed.cover.kind, CookbookCoverKind.photo);
      expect(parsed.cover.imageUrl, 'https://img/a.jpg');
      expect(
        const CookbookCover().toMap().containsKey('imageUrl'),
        isFalse,
      );
    });

    test('rename, rule and group edits keep the cookbook', () {
      final tag = PersonalTag(
        id: 't1',
        name: 'Mormors favoriter',
        createdAt: now,
        updatedAt: now,
        cookbook: cookbook,
      );
      final edited = tag
          .copyWith(name: 'Mormors bästa')
          .copyWith(
            rules: [
              PersonalTagRule.create(
                tagId: 't1',
                name: 'r',
                conditions: const [],
              ),
            ],
          )
          .copyWith(groupId: 'g1');
      expect(_tagFromFirestoreMap(edited.toFirestore()).cookbook, cookbook);
    });

    test('clearCookbook drops it', () {
      final tag = PersonalTag(
        id: 't1',
        name: 'x',
        createdAt: now,
        updatedAt: now,
        cookbook: cookbook,
      );
      expect(tag.copyWith(clearCookbook: true).isCookbook, isFalse);
    });
  });

  group('CookbookDetails.fromMap', () {
    test('a missing order means A–Ö, an empty list means own order', () {
      expect(CookbookDetails.fromMap(const {}).hasCustomOrder, isFalse);
      expect(
        CookbookDetails.fromMap(const {
          'recipeOrder': <String>[],
        }).hasCustomOrder,
        isTrue,
      );
    });

    test('malformed fields parse without throwing', () {
      final parsed = CookbookDetails.fromMap(const {
        'description': 42,
        'cover': 'not a map',
        'recipeOrder': 'not a list',
        'recipeNotes': {'r1': 7, 'r2': '', 'r3': 'ok'},
      });
      expect(parsed.description, '42');
      expect(parsed.cover.kind, CookbookCoverKind.color);
      expect(parsed.recipeOrder, isNull);
      expect(parsed.recipeNotes, {'r3': 'ok'});
    });

    test('an unknown cover kind falls back to colour', () {
      final parsed = CookbookDetails.fromMap(const {
        'cover': {'kind': 'hologram'},
      });
      expect(parsed.cover.kind, CookbookCoverKind.color);
      expect(parsed.cover.colorKey, CookbookCover.defaultColorKey);
    });
  });

  group('CookbookService.isValid bounds', () {
    String text(int n) => List.filled(n, 'a').join();
    List<String> ids(int n) => [for (var i = 0; i < n; i++) 'r$i'];

    test('description 300 ok, 301 refused', () {
      expect(
        CookbookService.isValid(CookbookDetails(description: text(300))),
        isTrue,
      );
      expect(
        CookbookService.isValid(CookbookDetails(description: text(301))),
        isFalse,
      );
    });

    test('order 1000 ok, 1001 refused', () {
      expect(
        CookbookService.isValid(CookbookDetails(recipeOrder: ids(1000))),
        isTrue,
      );
      expect(
        CookbookService.isValid(CookbookDetails(recipeOrder: ids(1001))),
        isFalse,
      );
    });

    test('note 300 ok, 301 refused', () {
      expect(
        CookbookService.isValid(
          CookbookDetails(recipeNotes: {'r1': text(300)}),
        ),
        isTrue,
      );
      expect(
        CookbookService.isValid(
          CookbookDetails(recipeNotes: {'r1': text(301)}),
        ),
        isFalse,
      );
    });
  });
}
