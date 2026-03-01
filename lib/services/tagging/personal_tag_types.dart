import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/models/tagging/personal_tag_group.dart';
import 'package:butlery/models/tagging/personal_tag_rule.dart';

/// Helper for pairing a tag with one of its rules.
/// Used when evaluating rules across all tags.
class TagRulePair {
  final PersonalTag tag;
  final PersonalTagRule rule;

  TagRulePair(this.tag, this.rule);
}

/// Result of watching tags with groups for hierarchical display.
class PersonalTagsWithGroups {
  final List<PersonalTagGroup> groups;
  final Map<String?, List<PersonalTag>> tagsByGroup;
  final List<PersonalTag> ungroupedTags;

  PersonalTagsWithGroups({
    required this.groups,
    required this.tagsByGroup,
    required this.ungroupedTags,
  });

  List<PersonalTag> getTagsForGroup(String? groupId) {
    return tagsByGroup[groupId] ?? [];
  }

  int get totalTagCount =>
      tagsByGroup.values.fold(0, (sum, tags) => sum + tags.length);
}
