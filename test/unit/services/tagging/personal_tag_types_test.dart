/// Unit tests for tagging helper types (TagRulePair + PersonalTagsWithGroups).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/models/tagging/personal_tag_group.dart';
import 'package:butlery/models/tagging/personal_tag_rule.dart';
import 'package:butlery/services/tagging/personal_tag_types.dart';

PersonalTag _tag({String id = 't1', String name = 'Tag', String? groupId}) {
  return PersonalTag(
    id: id,
    name: name,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
    groupId: groupId,
  );
}

PersonalTagGroup _group({String id = 'g1', String name = 'Group'}) {
  return PersonalTagGroup(
    id: id,
    name: name,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );
}

void main() {
  group('TagRulePair', () {
    test('exposes tag + rule as supplied', () {
      final tag = _tag();
      final rule = PersonalTagRule(
        id: 'r1',
        name: 'demo',
        conditions: const [],
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      final pair = TagRulePair(tag, rule);
      expect(pair.tag, same(tag));
      expect(pair.rule, same(rule));
    });
  });

  group('PersonalTagsWithGroups', () {
    test('getTagsForGroup returns the list for the matching group id', () {
      final tags = PersonalTagsWithGroups(
        groups: [_group(id: 'g1')],
        tagsByGroup: {
          'g1': [_tag(id: 't1', groupId: 'g1'), _tag(id: 't2', groupId: 'g1')],
        },
        ungroupedTags: const [],
      );
      expect(tags.getTagsForGroup('g1').map((t) => t.id), ['t1', 't2']);
    });

    test('getTagsForGroup returns empty list for unknown group id', () {
      final tags = PersonalTagsWithGroups(
        groups: const [],
        tagsByGroup: const {},
        ungroupedTags: const [],
      );
      expect(tags.getTagsForGroup('missing'), isEmpty);
    });

    test('getTagsForGroup honors the null key (ungrouped bucket)', () {
      final tags = PersonalTagsWithGroups(
        groups: const [],
        tagsByGroup: {
          null: [_tag(id: 'ung')],
        },
        ungroupedTags: [_tag(id: 'ung')],
      );
      expect(tags.getTagsForGroup(null).single.id, 'ung');
    });

    test('totalTagCount sums all values regardless of key', () {
      final tags = PersonalTagsWithGroups(
        groups: [
          _group(id: 'g1'),
          _group(id: 'g2'),
        ],
        tagsByGroup: {
          'g1': [_tag(id: 't1'), _tag(id: 't2')],
          'g2': [_tag(id: 't3')],
          null: [_tag(id: 't4'), _tag(id: 't5')],
        },
        ungroupedTags: const [],
      );
      expect(tags.totalTagCount, 5);
    });

    test('totalTagCount is 0 for an empty map', () {
      final tags = PersonalTagsWithGroups(
        groups: const [],
        tagsByGroup: const {},
        ungroupedTags: const [],
      );
      expect(tags.totalTagCount, 0);
    });

    test('groups + ungroupedTags expose what was passed in', () {
      final g = _group();
      final u = _tag(id: 'u');
      final tags = PersonalTagsWithGroups(
        groups: [g],
        tagsByGroup: const {},
        ungroupedTags: [u],
      );
      expect(tags.groups.single, same(g));
      expect(tags.ungroupedTags.single, same(u));
    });
  });
}
