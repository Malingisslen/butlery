import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/tagging/recipe_personal_tag.dart';

void main() {
  group('RecipePersonalTag', () {
    group('creation', () {
      test('creates tag with all fields', () {
        const tag = RecipePersonalTag(
          tagId: 'tag-1',
          name: 'Favoriter',
          sources: ['manual'],
        );

        expect(tag.tagId, 'tag-1');
        expect(tag.name, 'Favoriter');
        expect(tag.sources, ['manual']);
      });

      test('factory manual creates manual source', () {
        final tag = RecipePersonalTag.manual(
          tagId: 'tag-1',
          name: 'Favoriter',
        );

        expect(tag.tagId, 'tag-1');
        expect(tag.name, 'Favoriter');
        expect(tag.sources, ['manual']);
        expect(tag.isManual, isTrue);
        expect(tag.isFromRule, isFalse);
      });

      test('factory fromRule creates rule source', () {
        final tag = RecipePersonalTag.fromRule(
          tagId: 'tag-1',
          name: 'Fiskrecept',
          ruleId: 'rule-123',
        );

        expect(tag.tagId, 'tag-1');
        expect(tag.name, 'Fiskrecept');
        expect(tag.sources, ['rule-rule-123']);
        expect(tag.isManual, isFalse);
        expect(tag.isFromRule, isTrue);
      });
    });

    group('source tracking', () {
      test('isManual returns true for manual source', () {
        const tag = RecipePersonalTag(
          tagId: 'tag-1',
          name: 'Test',
          sources: ['manual'],
        );

        expect(tag.isManual, isTrue);
      });

      test('isManual returns true when manual is among sources', () {
        const tag = RecipePersonalTag(
          tagId: 'tag-1',
          name: 'Test',
          sources: ['manual', 'rule-123'],
        );

        expect(tag.isManual, isTrue);
      });

      test('isManual returns false when no manual source', () {
        const tag = RecipePersonalTag(
          tagId: 'tag-1',
          name: 'Test',
          sources: ['rule-123'],
        );

        expect(tag.isManual, isFalse);
      });

      test('isFromRule returns true for rule source', () {
        const tag = RecipePersonalTag(
          tagId: 'tag-1',
          name: 'Test',
          sources: ['rule-abc'],
        );

        expect(tag.isFromRule, isTrue);
      });

      test('isFromRule returns false for manual only', () {
        const tag = RecipePersonalTag(
          tagId: 'tag-1',
          name: 'Test',
          sources: ['manual'],
        );

        expect(tag.isFromRule, isFalse);
      });

      test('ruleIds extracts rule IDs correctly', () {
        const tag = RecipePersonalTag(
          tagId: 'tag-1',
          name: 'Test',
          sources: ['manual', 'rule-abc', 'rule-xyz'],
        );

        expect(tag.ruleIds, ['abc', 'xyz']);
      });

      test('ruleIds returns empty for manual only', () {
        const tag = RecipePersonalTag(
          tagId: 'tag-1',
          name: 'Test',
          sources: ['manual'],
        );

        expect(tag.ruleIds, isEmpty);
      });

      test('isAppliedByRule checks specific rule', () {
        const tag = RecipePersonalTag(
          tagId: 'tag-1',
          name: 'Test',
          sources: ['rule-abc', 'rule-xyz'],
        );

        expect(tag.isAppliedByRule('abc'), isTrue);
        expect(tag.isAppliedByRule('xyz'), isTrue);
        expect(tag.isAppliedByRule('other'), isFalse);
      });
    });

    group('source manipulation', () {
      test('addSource adds new source', () {
        const original = RecipePersonalTag(
          tagId: 'tag-1',
          name: 'Test',
          sources: ['manual'],
        );

        final updated = original.addSource('rule-123');

        expect(updated.sources, ['manual', 'rule-123']);
      });

      test('addSource does not duplicate existing source', () {
        const original = RecipePersonalTag(
          tagId: 'tag-1',
          name: 'Test',
          sources: ['manual'],
        );

        final updated = original.addSource('manual');

        expect(updated.sources, ['manual']);
        expect(identical(updated, original), isTrue);
      });

      test('removeSource removes source', () {
        const original = RecipePersonalTag(
          tagId: 'tag-1',
          name: 'Test',
          sources: ['manual', 'rule-123'],
        );

        final updated = original.removeSource('rule-123');

        expect(updated, isNotNull);
        expect(updated!.sources, ['manual']);
      });

      test('removeSource returns null when no sources remain', () {
        const original = RecipePersonalTag(
          tagId: 'tag-1',
          name: 'Test',
          sources: ['manual'],
        );

        final updated = original.removeSource('manual');

        expect(updated, isNull);
      });

      test('withName updates name', () {
        const original = RecipePersonalTag(
          tagId: 'tag-1',
          name: 'Old Name',
          sources: ['manual'],
        );

        final updated = original.withName('New Name');

        expect(updated.name, 'New Name');
        expect(updated.tagId, original.tagId);
        expect(updated.sources, original.sources);
      });
    });

    group('serialization', () {
      test('toMap serializes all fields', () {
        const tag = RecipePersonalTag(
          tagId: 'tag-1',
          name: 'Favoriter',
          sources: ['manual', 'rule-abc'],
        );

        final map = tag.toMap();

        expect(map['tagId'], 'tag-1');
        expect(map['name'], 'Favoriter');
        expect(map['sources'], ['manual', 'rule-abc']);
      });

      test('fromMap parses all fields', () {
        final tag = RecipePersonalTag.fromMap(const {
          'tagId': 'tag-1',
          'name': 'Test',
          'sources': ['manual', 'rule-xyz'],
        });

        expect(tag.tagId, 'tag-1');
        expect(tag.name, 'Test');
        expect(tag.sources, ['manual', 'rule-xyz']);
      });

      test('fromMap defaults to manual when sources missing', () {
        final tag = RecipePersonalTag.fromMap(const {
          'tagId': 'tag-1',
          'name': 'Test',
        });

        expect(tag.sources, ['manual']);
      });

      test('fromMap handles null sources', () {
        final tag = RecipePersonalTag.fromMap(const {
          'tagId': 'tag-1',
          'name': 'Test',
          'sources': null,
        });

        expect(tag.sources, ['manual']);
      });

      test('roundtrip toMap/fromMap preserves data', () {
        const original = RecipePersonalTag(
          tagId: 'tag-123',
          name: 'Fiskrecept',
          sources: ['manual', 'rule-abc'],
        );

        final map = original.toMap();
        final restored = RecipePersonalTag.fromMap(map);

        expect(restored.tagId, original.tagId);
        expect(restored.name, original.name);
        expect(restored.sources, original.sources);
      });
    });

    group('equality', () {
      test('tags with same tagId are equal', () {
        const tag1 = RecipePersonalTag(
          tagId: 'same-id',
          name: 'Name 1',
          sources: ['manual'],
        );
        const tag2 = RecipePersonalTag(
          tagId: 'same-id',
          name: 'Name 2',
          sources: ['rule-abc'],
        );

        expect(tag1, equals(tag2));
        expect(tag1.hashCode, equals(tag2.hashCode));
      });

      test('tags with different tagId are not equal', () {
        const tag1 = RecipePersonalTag(
          tagId: 'id-1',
          name: 'Test',
          sources: ['manual'],
        );
        const tag2 = RecipePersonalTag(
          tagId: 'id-2',
          name: 'Test',
          sources: ['manual'],
        );

        expect(tag1, isNot(equals(tag2)));
      });
    });

    group('toString', () {
      test('returns readable string', () {
        const tag = RecipePersonalTag(
          tagId: 'tag-123',
          name: 'Favoriter',
          sources: ['manual'],
        );

        expect(tag.toString(), contains('tag-123'));
        expect(tag.toString(), contains('Favoriter'));
        expect(tag.toString(), contains('manual'));
      });
    });
  });

  group('RecipePersonalTagListExtension', () {
    test('findByTagId finds existing tag', () {
      final list = [
        RecipePersonalTag.manual(tagId: 'tag-1', name: 'Tag 1'),
        RecipePersonalTag.manual(tagId: 'tag-2', name: 'Tag 2'),
      ];

      final found = list.findByTagId('tag-1');

      expect(found, isNotNull);
      expect(found!.name, 'Tag 1');
    });

    test('findByTagId returns null for missing tag', () {
      final list = [
        RecipePersonalTag.manual(tagId: 'tag-1', name: 'Tag 1'),
      ];

      final found = list.findByTagId('tag-missing');

      expect(found, isNull);
    });

    test('containsTagId returns true for existing tag', () {
      final list = [
        RecipePersonalTag.manual(tagId: 'tag-1', name: 'Tag 1'),
      ];

      expect(list.containsTagId('tag-1'), isTrue);
      expect(list.containsTagId('tag-missing'), isFalse);
    });

    test('addOrUpdate adds new tag', () {
      final list = [
        RecipePersonalTag.manual(tagId: 'tag-1', name: 'Tag 1'),
      ];

      final newTag = RecipePersonalTag.manual(tagId: 'tag-2', name: 'Tag 2');
      final updated = list.addOrUpdate(newTag);

      expect(updated, hasLength(2));
      expect(updated.containsTagId('tag-2'), isTrue);
    });

    test('addOrUpdate merges sources for existing tag', () {
      final list = [
        RecipePersonalTag.manual(tagId: 'tag-1', name: 'Tag 1'),
      ];

      final ruleTag = RecipePersonalTag.fromRule(
        tagId: 'tag-1',
        name: 'Tag 1 Updated',
        ruleId: 'rule-123',
      );
      final updated = list.addOrUpdate(ruleTag);

      expect(updated, hasLength(1));
      expect(updated.first.sources, containsAll(['manual', 'rule-rule-123']));
      expect(updated.first.name, 'Tag 1 Updated');
    });

    test('removeByTagId removes tag', () {
      final list = [
        RecipePersonalTag.manual(tagId: 'tag-1', name: 'Tag 1'),
        RecipePersonalTag.manual(tagId: 'tag-2', name: 'Tag 2'),
      ];

      final updated = list.removeByTagId('tag-1');

      expect(updated, hasLength(1));
      expect(updated.containsTagId('tag-1'), isFalse);
      expect(updated.containsTagId('tag-2'), isTrue);
    });

    test('removeSource removes specific source', () {
      final list = [
        const RecipePersonalTag(
          tagId: 'tag-1',
          name: 'Tag 1',
          sources: ['manual', 'rule-123'],
        ),
      ];

      final updated = list.removeSource('tag-1', 'rule-123');

      expect(updated, hasLength(1));
      expect(updated.first.sources, ['manual']);
    });

    test('removeSource removes tag when no sources remain', () {
      final list = [
        const RecipePersonalTag(
          tagId: 'tag-1',
          name: 'Tag 1',
          sources: ['manual'],
        ),
      ];

      final updated = list.removeSource('tag-1', 'manual');

      expect(updated, isEmpty);
    });

    test('updateName updates tag name', () {
      final list = [
        RecipePersonalTag.manual(tagId: 'tag-1', name: 'Old Name'),
      ];

      final updated = list.updateName('tag-1', 'New Name');

      expect(updated.first.name, 'New Name');
    });

    test('updateName does nothing for missing tag', () {
      final list = [
        RecipePersonalTag.manual(tagId: 'tag-1', name: 'Tag 1'),
      ];

      final updated = list.updateName('tag-missing', 'New Name');

      expect(updated, hasLength(1));
      expect(updated.first.name, 'Tag 1');
    });
  });
}
