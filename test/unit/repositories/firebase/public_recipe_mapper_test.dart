library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/firebase/public_recipe_mapper.dart';

void main() {
  final created = DateTime.utc(2026, 9, 1, 8);
  final updated = DateTime.utc(2026, 10, 2, 9);

  Map<String, dynamic> fullCopy() => {
    'ownerId': 'someone-else',
    'title': 'Köttbullar',
    'description': 'Klassiska',
    'portions': 4,
    'timeMinutes': 45,
    'prepTimeMinutes': 15,
    'cookTimeMinutes': 30,
    'ingredients': ['500 g köttfärs', '1 ägg'],
    'structuredIngredients': [
      {'name': 'köttfärs', 'raw': '500 g köttfärs', 'amount': 500, 'unit': 'g'},
    ],
    'instructions': ['Blanda', 'Stek'],
    'mealType': 'Middag',
    'cuisine': 'Svenskt',
    'difficulty': 'Lätt',
    'imageUrls': ['https://img/1.jpg'],
    'thumbnailUrl': 'https://img/t.jpg',
    'sourceUrl': 'https://example.se/r',
    'sourceAuthor': 'Anna',
    'createdAt': Timestamp.fromDate(created),
    'updatedAt': Timestamp.fromDate(updated),
  };

  test('maps every copied field', () {
    final r = recipeFromPublicCopy('owner-1', 'rid', fullCopy());

    expect(r.id, 'rid');
    expect(r.type, RecipeType.personal);
    expect(r.title, 'Köttbullar');
    expect(r.core.description, 'Klassiska');
    expect(r.core.portions, 4);
    expect(r.core.timeMinutes, 45);
    expect(r.core.prepTimeMinutes, 15);
    expect(r.core.cookTimeMinutes, 30);
    expect(r.core.ingredients, ['500 g köttfärs', '1 ägg']);
    expect(r.core.instructions, ['Blanda', 'Stek']);
    expect(r.core.mealType, 'Middag');
    expect(r.core.cuisine, 'Svenskt');
    expect(r.core.difficulty, 'Lätt');
    expect(r.core.imageUrls, ['https://img/1.jpg']);
    expect(r.core.thumbnailUrl, 'https://img/t.jpg');
    expect(r.sourceUrl, 'https://example.se/r');
    expect(r.core.sourceAuthor, 'Anna');
    expect(r.core.createdAt.toUtc(), created);
    expect(r.updatedAt.toUtc(), updated);
    expect(r.showOnProfile, isFalse);
  });

  test('createdBy is the path owner even when data.ownerId differs', () {
    final r = recipeFromPublicCopy('owner-1', 'rid', fullCopy());

    expect(r.createdBy, 'owner-1');
  });

  test('parses structuredIngredients', () {
    final r = recipeFromPublicCopy('o', 'rid', fullCopy());

    final s = r.core.structuredIngredients!;
    expect(s, hasLength(1));
    expect(s.first.name, 'köttfärs');
    expect(s.first.amount, 500);
    expect(s.first.unit, 'g');
  });

  test('missing fields degrade to empty lists and null', () {
    final r = recipeFromPublicCopy('o', 'rid', {'title': 'Bara titel'});

    expect(r.title, 'Bara titel');
    expect(r.core.ingredients, isEmpty);
    expect(r.core.instructions, isEmpty);
    expect(r.core.imageUrls, isEmpty);
    expect(r.core.structuredIngredients, isNull);
    expect(r.core.portions, isNull);
    expect(r.core.timeMinutes, isNull);
    expect(r.core.cuisine, isNull);
    expect(r.core.thumbnailUrl, isNull);
    expect(r.sourceUrl, isNull);
  });

  test('wrongly typed list entries are dropped, not thrown on', () {
    final r = recipeFromPublicCopy('o', 'rid', {
      'ingredients': ['mjölk', 3, null],
      'instructions': 'not a list',
      'portions': 'four',
    });

    expect(r.core.ingredients, ['mjölk']);
    expect(r.core.instructions, isEmpty);
    expect(r.core.portions, isNull);
  });
}
