/// Menu slot vote model for collaborative menu decision-making.

// lib/models/realtime/menu_slot_vote.dart

import 'package:butlery/core/types/app_timestamp.dart';
import 'package:butlery/core/utils/serialization_utils.dart';
import 'package:uuid/uuid.dart';

/// A single vote option — a recipe proposed for a menu slot.
class VoteOption {
  final String id;
  final String recipeId;
  final String recipeName;
  final String? recipeImageUrl;
  final String suggestedByUserId;

  const VoteOption({
    required this.id,
    required this.recipeId,
    required this.recipeName,
    this.recipeImageUrl,
    required this.suggestedByUserId,
  });

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'recipeId': recipeId,
        'recipeName': recipeName,
        'recipeImageUrl': recipeImageUrl,
        'suggestedByUserId': suggestedByUserId,
      };

  factory VoteOption.fromMap(Map<String, dynamic> data) => VoteOption(
        id: SerializationUtils.safeString(data, 'id'),
        recipeId: SerializationUtils.safeString(data, 'recipeId'),
        recipeName: SerializationUtils.safeString(data, 'recipeName'),
        recipeImageUrl:
            SerializationUtils.safeNullableString(data, 'recipeImageUrl'),
        suggestedByUserId:
            SerializationUtils.safeString(data, 'suggestedByUserId'),
      );
}

/// A vote on a menu slot — multiple recipe alternatives, household members vote.
class MenuSlotVote {
  final String id;
  final String menuId;
  final String category;
  final int slotIndex;
  final List<VoteOption> alternatives;
  final Map<String, String> votes; // userId -> optionId
  final DateTime deadline;
  final bool isResolved;
  final String? winningOptionId;
  final String createdByUserId;
  final DateTime createdAt;

  const MenuSlotVote({
    required this.id,
    required this.menuId,
    required this.category,
    required this.slotIndex,
    required this.alternatives,
    this.votes = const {},
    required this.deadline,
    this.isResolved = false,
    this.winningOptionId,
    required this.createdByUserId,
    required this.createdAt,
  });

  factory MenuSlotVote.create({
    required String menuId,
    required String category,
    required int slotIndex,
    required List<VoteOption> alternatives,
    required Duration votingWindow,
    required String createdByUserId,
  }) {
    return MenuSlotVote(
      id: const Uuid().v4(),
      menuId: menuId,
      category: category,
      slotIndex: slotIndex,
      alternatives: alternatives,
      deadline: DateTime.now().add(votingWindow),
      createdByUserId: createdByUserId,
      createdAt: DateTime.now(),
    );
  }

  MenuSlotVote copyWith({
    List<VoteOption>? alternatives,
    Map<String, String>? votes,
    DateTime? deadline,
    bool? isResolved,
    String? winningOptionId,
  }) {
    return MenuSlotVote(
      id: id,
      menuId: menuId,
      category: category,
      slotIndex: slotIndex,
      alternatives: alternatives ?? this.alternatives,
      votes: votes ?? this.votes,
      deadline: deadline ?? this.deadline,
      isResolved: isResolved ?? this.isResolved,
      winningOptionId: winningOptionId ?? this.winningOptionId,
      createdByUserId: createdByUserId,
      createdAt: createdAt,
    );
  }

  // --- Computed getters ---

  bool get isExpired => DateTime.now().isAfter(deadline);
  bool get isActive => !isResolved && !isExpired;
  bool hasVoted(String userId) => votes.containsKey(userId);
  int get totalVotes => votes.length;

  /// Tally votes per option.
  Map<String, int> get tallies {
    final counts = <String, int>{};
    for (final optionId in votes.values) {
      counts[optionId] = (counts[optionId] ?? 0) + 1;
    }
    return counts;
  }

  /// The option with the most votes (null if no votes).
  VoteOption? get leadingOption {
    if (votes.isEmpty) return null;
    final sorted = tallies.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final leadingId = sorted.first.key;
    try {
      return alternatives.firstWhere((o) => o.id == leadingId);
    } on StateError {
      return null;
    }
  }

  /// The resolved winner option.
  VoteOption? get winningOption {
    if (winningOptionId == null) return null;
    try {
      return alternatives.firstWhere((o) => o.id == winningOptionId);
    } on StateError {
      return null;
    }
  }

  // --- Serialization ---

  Map<String, dynamic> toFirestore() => {
        'menuId': menuId,
        'category': category,
        'slotIndex': slotIndex,
        'alternatives': alternatives.map((o) => o.toFirestore()).toList(),
        'votes': votes,
        'deadline': AppTimestamp.fromDateTime(deadline).toFirestore(),
        'isResolved': isResolved,
        'winningOptionId': winningOptionId,
        'createdByUserId': createdByUserId,
        'createdAt': AppTimestamp.fromDateTime(createdAt).toFirestore(),
      };

  factory MenuSlotVote.fromMap(String id, Map<String, dynamic> data) {
    final alternativesList = (data['alternatives'] as List<dynamic>?)
            ?.map((e) => VoteOption.fromMap(e as Map<String, dynamic>))
            .toList() ??
        [];

    final votesMap = <String, String>{};
    if (data['votes'] is Map) {
      (data['votes'] as Map).forEach((key, value) {
        votesMap[key.toString()] = value.toString();
      });
    }

    return MenuSlotVote(
      id: id,
      menuId: SerializationUtils.safeString(data, 'menuId'),
      category: SerializationUtils.safeString(data, 'category'),
      slotIndex: SerializationUtils.safeInt(data, 'slotIndex'),
      alternatives: alternativesList,
      votes: votesMap,
      deadline: SerializationUtils.parseRequiredDateTimeValue(data['deadline']),
      isResolved: SerializationUtils.safeBool(data, 'isResolved'),
      winningOptionId:
          SerializationUtils.safeNullableString(data, 'winningOptionId'),
      createdByUserId: SerializationUtils.safeString(data, 'createdByUserId'),
      createdAt:
          SerializationUtils.parseRequiredDateTimeValue(data['createdAt']),
    );
  }

  @override
  String toString() =>
      'MenuSlotVote(id: $id, menu: $menuId, $category[$slotIndex], '
      '${alternatives.length} options, ${votes.length} votes, '
      'resolved: $isResolved)';
}
