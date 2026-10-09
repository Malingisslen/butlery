// lib/models/realtime/menu_ballot.dart

import 'package:clock/clock.dart';
import 'package:butlery/core/types/app_timestamp.dart';
import 'package:butlery/core/utils/serialization_utils.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:uuid/uuid.dart';

/// A dish put up for a vote. [dish] is stored in the shape a menu stores a
/// dish (`Recipe.toMenuDish`), so the winner goes into the menu as the same
/// write a swap makes, and the person settling the vote never needs to read
/// the proposer's recipe.
class VoteOption {
  final String id;
  final Map<String, dynamic> dish;

  /// How many ballots had been cast when this option was added. Drawn as
  /// "N hade redan röstat" on an option added after voting began.
  final int votersBefore;

  const VoteOption({
    required this.id,
    required this.dish,
    this.votersBefore = 0,
  });

  factory VoteOption.fromRecipe(Recipe recipe, {int votersBefore = 0}) =>
      VoteOption(
        id: const Uuid().v4(),
        dish: recipe.toMenuDish(),
        votersBefore: votersBefore,
      );

  String get recipeId => SerializationUtils.safeString(dish, 'id');
  String get recipeName => SerializationUtils.safeString(dish, 'title');

  Recipe toRecipe() => Recipe.fromMap(recipeId, dish);

  Map<String, dynamic> toFirestore() => {
    'id': id,
    'dish': dish,
    'votersBefore': votersBefore,
  };

  factory VoteOption.fromMap(Map<String, dynamic> data) => VoteOption(
    id: SerializationUtils.safeString(data, 'id'),
    dish: SerializationUtils.safeMap(data, 'dish'),
    votersBefore: SerializationUtils.safeInt(data, 'votersBefore'),
  );
}

/// A vote someone started on one slot of the menu.
class StartedVote {
  final String id;
  final List<VoteOption> options;
  final DateTime deadline;
  final DateTime createdAt;

  const StartedVote({
    required this.id,
    required this.options,
    required this.deadline,
    required this.createdAt,
  });

  factory StartedVote.create({
    required List<VoteOption> options,
    Duration window = const Duration(hours: 24),
  }) {
    final now = clock.now();
    return StartedVote(
      id: const Uuid().v4(),
      options: options,
      deadline: now.add(window),
      createdAt: now,
    );
  }

  StartedVote withDeadline(DateTime deadline) => StartedVote(
    id: id,
    options: options,
    deadline: deadline,
    createdAt: createdAt,
  );

  Map<String, dynamic> toFirestore() => {
    'id': id,
    'options': options.map((o) => o.toFirestore()).toList(),
    'deadline': AppTimestamp.fromDateTime(deadline).toFirestore(),
    'createdAt': AppTimestamp.fromDateTime(createdAt).toFirestore(),
  };

  // The rules do not check what is inside a vote, so a field of the wrong
  // type is dropped here rather than failing the whole snapshot.
  factory StartedVote.fromMap(Map<String, dynamic> data) {
    final options = data['options'];
    return StartedVote(
      id: SerializationUtils.safeString(data, 'id'),
      options: [
        if (options is List)
          for (final o in options)
            if (o is Map) VoteOption.fromMap(o.cast<String, dynamic>()),
      ],
      deadline: SerializationUtils.parseRequiredDateTimeValue(data['deadline']),
      createdAt: SerializationUtils.parseRequiredDateTimeValue(
        data['createdAt'],
      ),
    );
  }
}

enum VoteOutcome { winner, released }

/// How the starter settled a vote.
class VoteResolution {
  final VoteOutcome outcome;
  final String? optionId;
  final DateTime at;

  const VoteResolution({
    required this.outcome,
    this.optionId,
    required this.at,
  });

  Map<String, dynamic> toFirestore() => {
    'outcome': outcome.name,
    if (optionId != null) 'optionId': optionId,
    'at': AppTimestamp.fromDateTime(at).toFirestore(),
  };

  factory VoteResolution.fromMap(Map<String, dynamic> data) => VoteResolution(
    outcome: data['outcome'] == VoteOutcome.winner.name
        ? VoteOutcome.winner
        : VoteOutcome.released,
    optionId: SerializationUtils.safeNullableString(data, 'optionId'),
    at: SerializationUtils.parseRequiredDateTimeValue(data['at']),
  );
}

/// One person's ballot document on a live menu,
/// `realtime_resources/{menuId}/votes/{userId}`. Only its owner writes it;
/// the votes on the menu are derived from everyone's documents together
/// (`MenuSlotVote.deriveAll`).
class MenuBallot {
  final String userId;

  /// Votes this person started, keyed by [slotKey].
  final Map<String, StartedVote> started;

  /// Options this person added to someone's vote, keyed by vote id.
  final Map<String, VoteOption> proposals;

  /// This person's ballot per vote id: the option they chose.
  final Map<String, String> ballots;

  /// How this person settled the votes they started, keyed by vote id.
  final Map<String, VoteResolution> resolved;

  const MenuBallot({
    required this.userId,
    this.started = const {},
    this.proposals = const {},
    this.ballots = const {},
    this.resolved = const {},
  });

  static String slotKey(String category, int slotIndex) =>
      '$category#$slotIndex';

  bool get isEmpty =>
      started.isEmpty &&
      proposals.isEmpty &&
      ballots.isEmpty &&
      resolved.isEmpty;

  MenuBallot copyWith({
    Map<String, StartedVote>? started,
    Map<String, VoteOption>? proposals,
    Map<String, String>? ballots,
    Map<String, VoteResolution>? resolved,
  }) => MenuBallot(
    userId: userId,
    started: started ?? this.started,
    proposals: proposals ?? this.proposals,
    ballots: ballots ?? this.ballots,
    resolved: resolved ?? this.resolved,
  );

  /// The stored fields; the repository adds `updatedAt` and `expireAt`.
  Map<String, dynamic> toFirestore() => {
    'userId': userId,
    'started': started.map((k, v) => MapEntry(k, v.toFirestore())),
    'proposals': proposals.map((k, v) => MapEntry(k, v.toFirestore())),
    'ballots': ballots,
    'resolved': resolved.map((k, v) => MapEntry(k, v.toFirestore())),
  };

  factory MenuBallot.fromMap(String userId, Map<String, dynamic> data) {
    Map<String, T> parse<T>(String key, T Function(Map<String, dynamic>) f) => {
      for (final e in SerializationUtils.safeMap(data, key).entries)
        if (e.value is Map) e.key: f((e.value as Map).cast<String, dynamic>()),
    };
    return MenuBallot(
      userId: userId,
      started: parse('started', StartedVote.fromMap),
      proposals: parse('proposals', VoteOption.fromMap),
      ballots: {
        for (final e in SerializationUtils.safeMap(data, 'ballots').entries)
          if (e.value is String) e.key: e.value as String,
      },
      resolved: parse('resolved', VoteResolution.fromMap),
    );
  }
}
