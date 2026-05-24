// BUT-983: imageUrls field on RecipeComment.
// Pins the cap-at-3 assertion, default-empty, JSON roundtrip, and
// the legacy-comment-without-imageUrls backcompat path.

import 'package:butlery/models/recipe_comment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  RecipeComment build({List<String> imageUrls = const []}) =>
      RecipeComment.create(
        recipeId: 'r1',
        authorId: 'u1',
        authorDisplayName: 'Test',
        text: 'comment',
        imageUrls: imageUrls,
      );

  group('RecipeComment.imageUrls (BUT-983)', () {
    test('defaults to empty list — text-only comments unchanged', () {
      final c = build();
      expect(c.imageUrls, isEmpty);
    });

    test('accepts up to maxImageUrls (3)', () {
      final c = build(imageUrls: const ['a', 'b', 'c']);
      expect(c.imageUrls, equals(['a', 'b', 'c']));
    });

    test('asserts when imageUrls exceeds maxImageUrls', () {
      expect(
        () => build(imageUrls: const ['a', 'b', 'c', 'd']),
        throwsA(isA<AssertionError>()),
      );
    });

    test('toJson omits imageUrls when empty (no legacy doc growth)', () {
      final c = build();
      final json = c.toJson();
      expect(json.containsKey('imageUrls'), isFalse);
    });

    test('toJson includes imageUrls when populated', () {
      final c = build(imageUrls: const ['url1', 'url2']);
      final json = c.toJson();
      expect(json['imageUrls'], equals(['url1', 'url2']));
    });

    test('roundtrip: toJson → fromJson preserves imageUrls', () {
      final original = build(imageUrls: const ['url1', 'url2']);
      final restored = RecipeComment.fromJson(original.toJson());
      expect(restored.imageUrls, equals(['url1', 'url2']));
    });

    test('fromJson with no imageUrls key reads as empty list (backcompat)', () {
      // Legacy text-only comments serialized before BUT-983 have no
      // imageUrls key. Must parse cleanly with an empty list, not crash.
      final json = {
        'id': 'c1',
        'recipeId': 'r1',
        'authorId': 'u1',
        'authorDisplayName': 'Test',
        'text': 'legacy comment',
        'createdAt': DateTime.utc(2026, 1, 1).toIso8601String(),
        // imageUrls deliberately omitted
      };
      final c = RecipeComment.fromJson(json);
      expect(c.imageUrls, isEmpty);
    });

    test('copyWith preserves imageUrls when not specified', () {
      final c = build(imageUrls: const ['url1']);
      final edited = c.copyWith(text: 'new text');
      expect(edited.imageUrls, equals(['url1']));
    });

    test('copyWith replaces imageUrls when specified', () {
      final c = build(imageUrls: const ['url1']);
      final edited = c.copyWith(imageUrls: const ['url2', 'url3']);
      expect(edited.imageUrls, equals(['url2', 'url3']));
    });
  });
}
