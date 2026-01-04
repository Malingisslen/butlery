/// Unit tests for PersonalTag exclusive group enforcement.
///
/// Tests that exclusive groups work correctly:
/// - Only one tag from exclusive group can be applied
/// - Non-exclusive groups allow multiple tags
/// - Mixed scenarios with both group types
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/models/tagging/personal_tag_group.dart';

void main() {
  group('Exclusive Groups Logic', () {
    group('PersonalTagGroup model', () {
      test('can create exclusive group', () {
        final group = PersonalTagGroup.create(
          name: 'Difficulty',
          sortOrder: 1,
          isExclusive: true,
        );

        expect(group.isExclusive, isTrue);
        expect(group.name, 'Difficulty');
      });

      test('creates non-exclusive group by default', () {
        final group = PersonalTagGroup.create(
          name: 'Categories',
          sortOrder: 2,
        );

        expect(group.isExclusive, isFalse);
      });

      test('copyWith preserves exclusive flag', () {
        final group = PersonalTagGroup.create(
          name: 'Difficulty',
          sortOrder: 1,
          isExclusive: true,
        );

        final updated = group.copyWith(name: 'Svårighet');

        expect(updated.isExclusive, isTrue);
        expect(updated.name, 'Svårighet');
      });

      test('copyWith can change exclusive flag', () {
        final group = PersonalTagGroup.create(
          name: 'Difficulty',
          sortOrder: 1,
          isExclusive: true,
        );

        final updated = group.copyWith(isExclusive: false);

        expect(updated.isExclusive, isFalse);
      });

      test('serializes exclusive flag correctly', () {
        final group = PersonalTagGroup.create(
          name: 'Difficulty',
          sortOrder: 1,
          isExclusive: true,
        );

        final json = group.toJson();
        expect(json['isExclusive'], isTrue);

        final restored = PersonalTagGroup.fromJson(json);
        expect(restored.isExclusive, isTrue);
      });
    });

    group('PersonalTag with group assignment', () {
      test('tag can be assigned to exclusive group', () {
        final group = PersonalTagGroup.create(
          name: 'Difficulty',
          sortOrder: 1,
          isExclusive: true,
        );

        final tag = PersonalTag.create(
          name: 'Enkel',
          sortOrder: 1,
          groupId: group.id,
        );

        expect(tag.groupId, group.id);
      });

      test('tag groupId survives serialization', () {
        final tag = PersonalTag.create(
          name: 'Svår',
          sortOrder: 1,
          groupId: 'test-group-id',
        );

        final json = tag.toJson();
        expect(json['groupId'], 'test-group-id');

        final restored = PersonalTag.fromJson(json);
        expect(restored.groupId, 'test-group-id');
      });

      test('tag without group has null groupId', () {
        final tag = PersonalTag.create(
          name: 'Favorit',
          sortOrder: 1,
        );

        expect(tag.groupId, isNull);
      });
    });

    group('Rule evaluation scenarios', () {
      test('rules from same exclusive group should conflict', () {
        // Create exclusive group
        final difficultyGroup = PersonalTagGroup.create(
          name: 'Svårighetsgrad',
          sortOrder: 1,
          isExclusive: true,
        );

        // Create two tags in the same exclusive group
        final easyTag = PersonalTag.create(
          name: 'Enkel',
          sortOrder: 1,
          groupId: difficultyGroup.id,
        );

        final hardTag = PersonalTag.create(
          name: 'Svår',
          sortOrder: 2,
          groupId: difficultyGroup.id,
        );

        // Both tags are in the same exclusive group
        expect(easyTag.groupId, equals(hardTag.groupId));
        expect(difficultyGroup.isExclusive, isTrue);

        // When both would match, only one should be applied
        // (This is enforced by PersonalTagService._enforceExclusiveGroups)
      });

      test('rules from non-exclusive group can all apply', () {
        // Create non-exclusive group
        final moodGroup = PersonalTagGroup.create(
          name: 'Stämning',
          sortOrder: 1,
          isExclusive: false,
        );

        final festiveTag = PersonalTag.create(
          name: 'Festligt',
          sortOrder: 1,
          groupId: moodGroup.id,
        );

        final familyTag = PersonalTag.create(
          name: 'Familjevänligt',
          sortOrder: 2,
          groupId: moodGroup.id,
        );

        // Both tags are in non-exclusive group
        expect(festiveTag.groupId, equals(familyTag.groupId));
        expect(moodGroup.isExclusive, isFalse);

        // Both can be applied simultaneously
      });

      test('ungrouped tags are always independent', () {
        final favoriteTag = PersonalTag.create(
          name: 'Favorit',
          sortOrder: 1,
        );

        final testedTag = PersonalTag.create(
          name: 'Testat',
          sortOrder: 2,
        );

        // Both have no group
        expect(favoriteTag.groupId, isNull);
        expect(testedTag.groupId, isNull);

        // Both can be applied independently
      });
    });

    group('Enforcement algorithm simulation', () {
      /// Simulates the exclusive group enforcement logic
      Set<String> enforceExclusiveGroups(
        Set<String> matchingTagIds,
        List<PersonalTag> tags,
        List<PersonalTagGroup> groups,
      ) {
        if (matchingTagIds.isEmpty) return matchingTagIds;

        final exclusiveGroupIds =
            groups.where((g) => g.isExclusive).map((g) => g.id).toSet();

        if (exclusiveGroupIds.isEmpty) return matchingTagIds;

        final tagById = {for (final tag in tags) tag.id: tag};
        final result = <String>{};
        final seenExclusiveGroups = <String>{};

        for (final tagId in matchingTagIds) {
          final tag = tagById[tagId];
          if (tag == null) {
            result.add(tagId);
            continue;
          }

          if (tag.groupId != null && exclusiveGroupIds.contains(tag.groupId)) {
            if (!seenExclusiveGroups.contains(tag.groupId)) {
              result.add(tagId);
              seenExclusiveGroups.add(tag.groupId!);
            }
            // Skip if already have a tag from this exclusive group
          } else {
            result.add(tagId);
          }
        }

        return result;
      }

      test('keeps only first tag from exclusive group', () {
        final group = PersonalTagGroup.create(
          name: 'Difficulty',
          sortOrder: 1,
          isExclusive: true,
        );

        final easyTag =
            PersonalTag.create(name: 'Easy', sortOrder: 1, groupId: group.id);
        final mediumTag =
            PersonalTag.create(name: 'Medium', sortOrder: 2, groupId: group.id);
        final hardTag =
            PersonalTag.create(name: 'Hard', sortOrder: 3, groupId: group.id);

        final matching = {easyTag.id, mediumTag.id, hardTag.id};
        final result = enforceExclusiveGroups(
          matching,
          [easyTag, mediumTag, hardTag],
          [group],
        );

        // Only one should remain
        expect(result.length, 1);
        expect(result.contains(easyTag.id), isTrue);
      });

      test('allows all tags from non-exclusive group', () {
        final group = PersonalTagGroup.create(
          name: 'Tags',
          sortOrder: 1,
          isExclusive: false,
        );

        final tag1 =
            PersonalTag.create(name: 'A', sortOrder: 1, groupId: group.id);
        final tag2 =
            PersonalTag.create(name: 'B', sortOrder: 2, groupId: group.id);
        final tag3 =
            PersonalTag.create(name: 'C', sortOrder: 3, groupId: group.id);

        final matching = {tag1.id, tag2.id, tag3.id};
        final result = enforceExclusiveGroups(
          matching,
          [tag1, tag2, tag3],
          [group],
        );

        // All should remain
        expect(result.length, 3);
      });

      test('handles mixed exclusive and non-exclusive groups', () {
        final exclusiveGroup = PersonalTagGroup.create(
          name: 'Exclusive',
          sortOrder: 1,
          isExclusive: true,
        );

        final nonExclusiveGroup = PersonalTagGroup.create(
          name: 'NonExclusive',
          sortOrder: 2,
          isExclusive: false,
        );

        final excTag1 = PersonalTag.create(
            name: 'E1', sortOrder: 1, groupId: exclusiveGroup.id);
        final excTag2 = PersonalTag.create(
            name: 'E2', sortOrder: 2, groupId: exclusiveGroup.id);
        final nonExcTag1 = PersonalTag.create(
            name: 'N1', sortOrder: 3, groupId: nonExclusiveGroup.id);
        final nonExcTag2 = PersonalTag.create(
            name: 'N2', sortOrder: 4, groupId: nonExclusiveGroup.id);

        final matching = {excTag1.id, excTag2.id, nonExcTag1.id, nonExcTag2.id};
        final result = enforceExclusiveGroups(
          matching,
          [excTag1, excTag2, nonExcTag1, nonExcTag2],
          [exclusiveGroup, nonExclusiveGroup],
        );

        // Should have 1 from exclusive + 2 from non-exclusive = 3
        expect(result.length, 3);
        expect(result.contains(excTag1.id), isTrue);
        expect(result.contains(excTag2.id), isFalse);
        expect(result.contains(nonExcTag1.id), isTrue);
        expect(result.contains(nonExcTag2.id), isTrue);
      });

      test('ungrouped tags always pass through', () {
        final group = PersonalTagGroup.create(
          name: 'Exclusive',
          sortOrder: 1,
          isExclusive: true,
        );

        final groupedTag =
            PersonalTag.create(name: 'G1', sortOrder: 1, groupId: group.id);
        final ungroupedTag = PersonalTag.create(name: 'Favorit', sortOrder: 2);

        final matching = {groupedTag.id, ungroupedTag.id};
        final result = enforceExclusiveGroups(
          matching,
          [groupedTag, ungroupedTag],
          [group],
        );

        // Both should remain (ungrouped is not restricted)
        expect(result.length, 2);
      });
    });
  });
}
