import 'package:cloud_firestore/cloud_firestore.dart';

/// BUT-1473: one captured allergen tag-override correction, feeding the tagging
/// learning loop.
///
/// Written fire-and-forget whenever a user overrides an auto-generated allergen
/// verdict, so the pipeline can later mine which allergen verdicts users most
/// often correct — and on which ingredients — to improve tagging accuracy. The
/// allergen direction is captured first (highest safety value); dietary/tag
/// capture is a future extension.
class TagOverrideLogEntry {
  final String id;

  /// The correcting user (also the Firestore-rule ownership key).
  final String userId;

  /// The recipe whose verdict was corrected.
  final String recipeId;

  /// Decision category — 'allergen' for this first slice.
  final String type;

  /// The overridden key, e.g. 'gluten', 'mjölk'.
  final String tag;

  /// The correction direction as `auto->user`, e.g. 'contains->free' — captures
  /// exactly what the user disagreed with.
  final String direction;

  /// The ingredients the auto-tagger cited for its verdict (from the
  /// [TagDecision] log), so a reviewer sees which ingredient drove the
  /// corrected call. Empty when the decision named none.
  final List<String> triggeringIngredients;

  final DateTime timestamp;

  const TagOverrideLogEntry({
    required this.id,
    required this.userId,
    required this.recipeId,
    required this.type,
    required this.tag,
    required this.direction,
    required this.triggeringIngredients,
    required this.timestamp,
  });

  Map<String, dynamic> toFirestore() => {
    'id': id,
    'userId': userId,
    'recipeId': recipeId,
    'type': type,
    'tag': tag,
    'direction': direction,
    'triggeringIngredients': triggeringIngredients,
    'timestamp': Timestamp.fromDate(timestamp),
  };
}
