import 'package:flutter/foundation.dart';

import 'package:butlery/core/utils/serialization_utils.dart';

/// A reference to a PersonalTag stored on a recipe.
///
/// Tracks which PersonalTags are applied to a recipe and
/// how they were applied (manually or by rules).
///
/// Stored in the `personalTagIds` array on recipe documents.
@immutable
class RecipePersonalTag {
  /// The ID of the PersonalTag.
  final String tagId;

  /// The name of the tag (denormalized for display).
  /// Updated when the tag is renamed.
  final String name;

  /// How this tag was applied.
  ///
  /// Possible values:
  /// - `['manual']` - User explicitly added the tag
  /// - `['rule-xyz']` - Applied by rule with ID 'xyz'
  /// - `['manual', 'rule-xyz']` - Both manual and rule
  final List<String> sources;

  const RecipePersonalTag({
    required this.tagId,
    required this.name,
    required this.sources,
  });

  /// Creates a manually-applied tag reference.
  factory RecipePersonalTag.manual({
    required String tagId,
    required String name,
  }) {
    return RecipePersonalTag(
      tagId: tagId,
      name: name,
      sources: const ['manual'],
    );
  }

  /// Creates a rule-applied tag reference.
  factory RecipePersonalTag.fromRule({
    required String tagId,
    required String name,
    required String ruleId,
  }) {
    return RecipePersonalTag(
      tagId: tagId,
      name: name,
      sources: ['rule-$ruleId'],
    );
  }

  /// Creates from Firestore/JSON map.
  factory RecipePersonalTag.fromMap(Map<String, dynamic> data) {
    return RecipePersonalTag(
      tagId: SerializationUtils.safeString(data, 'tagId', defaultValue: ''),
      name: SerializationUtils.safeString(data, 'name', defaultValue: ''),
      sources: _parseSources(data['sources']),
    );
  }

  static List<String> _parseSources(dynamic value) {
    if (value == null) return ['manual']; // Default to manual
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return ['manual'];
  }

  /// Converts to Firestore/JSON map.
  Map<String, dynamic> toMap() {
    return {
      'tagId': tagId,
      'name': name,
      'sources': sources,
    };
  }

  /// Returns true if this tag was manually applied.
  bool get isManual => sources.contains('manual');

  /// Returns true if this tag was applied by any rule.
  bool get isFromRule => sources.any((s) => s.startsWith('rule-'));

  /// Returns the rule IDs that applied this tag.
  List<String> get ruleIds => sources
      .where((s) => s.startsWith('rule-'))
      .map((s) => s.substring(5)) // Remove 'rule-' prefix
      .toList();

  /// Returns true if this tag was applied by a specific rule.
  bool isAppliedByRule(String ruleId) => sources.contains('rule-$ruleId');

  /// Creates a copy with an additional source.
  RecipePersonalTag addSource(String source) {
    if (sources.contains(source)) return this;
    return RecipePersonalTag(
      tagId: tagId,
      name: name,
      sources: [...sources, source],
    );
  }

  /// Creates a copy with a source removed.
  /// Returns null if no sources remain.
  RecipePersonalTag? removeSource(String source) {
    final newSources = sources.where((s) => s != source).toList();
    if (newSources.isEmpty) return null;
    return RecipePersonalTag(
      tagId: tagId,
      name: name,
      sources: newSources,
    );
  }

  /// Creates a copy with updated name.
  RecipePersonalTag withName(String newName) {
    return RecipePersonalTag(
      tagId: tagId,
      name: newName,
      sources: sources,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecipePersonalTag &&
          runtimeType == other.runtimeType &&
          tagId == other.tagId;

  @override
  int get hashCode => tagId.hashCode;

  @override
  String toString() =>
      'RecipePersonalTag(tagId: $tagId, name: $name, sources: $sources)';
}

/// Helper for managing a list of RecipePersonalTags.
extension RecipePersonalTagListExtension on List<RecipePersonalTag> {
  /// Finds a tag by ID.
  RecipePersonalTag? findByTagId(String tagId) {
    for (final tag in this) {
      if (tag.tagId == tagId) return tag;
    }
    return null;
  }

  /// Returns true if a tag with this ID exists.
  bool containsTagId(String tagId) => findByTagId(tagId) != null;

  /// Adds or updates a tag.
  /// If the tag exists, merges sources.
  List<RecipePersonalTag> addOrUpdate(RecipePersonalTag tag) {
    final existing = findByTagId(tag.tagId);
    if (existing == null) {
      return [...this, tag];
    }

    // Merge sources
    final mergedSources = {...existing.sources, ...tag.sources}.toList();
    final updated = RecipePersonalTag(
      tagId: tag.tagId,
      name: tag.name,
      sources: mergedSources,
    );

    return [
      for (final t in this)
        if (t.tagId == tag.tagId) updated else t,
    ];
  }

  /// Removes a tag by ID.
  List<RecipePersonalTag> removeByTagId(String tagId) {
    return where((t) => t.tagId != tagId).toList();
  }

  /// Removes a specific source from a tag.
  /// Removes the tag entirely if no sources remain.
  List<RecipePersonalTag> removeSource(String tagId, String source) {
    final result = <RecipePersonalTag>[];
    for (final tag in this) {
      if (tag.tagId == tagId) {
        final updated = tag.removeSource(source);
        if (updated != null) {
          result.add(updated);
        }
        // If null, tag is removed entirely
      } else {
        result.add(tag);
      }
    }
    return result;
  }

  /// Updates the name for a tag.
  List<RecipePersonalTag> updateName(String tagId, String newName) {
    return [
      for (final tag in this)
        if (tag.tagId == tagId) tag.withName(newName) else tag,
    ];
  }
}
