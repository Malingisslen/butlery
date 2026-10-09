/// A vote on one menu slot, derived from everyone's ballot documents.

// lib/models/realtime/menu_slot_vote.dart

import 'package:clock/clock.dart';
import 'package:butlery/models/realtime/menu_ballot.dart';

export 'package:butlery/models/realtime/menu_ballot.dart';

/// Where a vote stands. A vote that ran out is NOT settled: nothing decides
/// at the deadline (produktregler 4.8), so the two expired states are their
/// own states, waiting for the person who started it.
enum SlotVoteState { open, expiredWithVotes, expiredEmpty, decided, released }

/// One slot's vote as everyone sees it: the starter's options plus everyone's
/// proposals, and one ballot per person. Built by [deriveAll]; never stored.
class MenuSlotVote {
  final String id;
  final String category;
  final int slotIndex;
  final String starterId;
  final List<VoteOption> alternatives;

  /// Ballots that name one of [alternatives], keyed by voter.
  final Map<String, String> votes;

  final DateTime deadline;
  final DateTime createdAt;
  final VoteResolution? resolution;

  /// An expired vote nobody settled is dropped from view after this long, so
  /// a starter who never comes back does not leave a card on the menu for
  /// good. The slot itself was never locked.
  static const Duration hideAfterExpiry = Duration(days: 7);

  const MenuSlotVote({
    required this.id,
    required this.category,
    required this.slotIndex,
    required this.starterId,
    required this.alternatives,
    this.votes = const {},
    required this.deadline,
    required this.createdAt,
    this.resolution,
  });

  String get slotKey => MenuBallot.slotKey(category, slotIndex);

  bool get isResolved => resolution != null;
  bool get isExpired => clock.now().isAfter(deadline);
  bool get isActive => !isResolved && !isExpired;
  bool get isStale =>
      !isResolved && clock.now().isAfter(deadline.add(hideAfterExpiry));

  SlotVoteState get state {
    final r = resolution;
    if (r != null) {
      return r.outcome == VoteOutcome.winner
          ? SlotVoteState.decided
          : SlotVoteState.released;
    }
    if (!isExpired) return SlotVoteState.open;
    return votes.isEmpty
        ? SlotVoteState.expiredEmpty
        : SlotVoteState.expiredWithVotes;
  }

  bool isStarter(String userId) => userId == starterId;
  bool hasVoted(String userId) => votes.containsKey(userId);
  int get totalVotes => votes.length;

  Map<String, int> get tallies {
    final counts = <String, int>{};
    for (final optionId in votes.values) {
      counts[optionId] = (counts[optionId] ?? 0) + 1;
    }
    return counts;
  }

  /// Every option with the highest count. More than one is a tie, which the
  /// app never breaks on its own: only the starter decides it.
  List<VoteOption> get leaders {
    final counts = tallies;
    if (counts.isEmpty) return const [];
    final top = counts.values.reduce((a, b) => a > b ? a : b);
    return [
      for (final o in alternatives)
        if (counts[o.id] == top) o,
    ];
  }

  bool get isTie => leaders.length > 1;
  VoteOption? get clearWinner => leaders.length == 1 ? leaders.first : null;

  VoteOption? optionById(String id) {
    for (final o in alternatives) {
      if (o.id == id) return o;
    }
    return null;
  }

  VoteOption? get winningOption {
    final id = resolution?.optionId;
    return id == null ? null : optionById(id);
  }

  /// The votes on the menu, from the ballot documents of the people now on
  /// it. A person who left stops counting: their vote, their proposals and
  /// any vote they started drop out together. A ballot naming an option that
  /// is not on the vote is ignored, so a stray write cannot add a choice.
  static List<MenuSlotVote> deriveAll(
    Iterable<MenuBallot> documents,
    Set<String> participantIds,
  ) {
    final current = [
      for (final d in documents)
        if (participantIds.contains(d.userId)) d,
    ];
    final out = <MenuSlotVote>[];
    for (final starter in current) {
      for (final entry in starter.started.entries) {
        final slot = _parseSlotKey(entry.key);
        if (slot == null) continue;
        final started = entry.value;
        final options = <VoteOption>[...started.options];
        final seen = {for (final o in options) o.id};
        for (final d in current) {
          final proposal = d.proposals[started.id];
          if (proposal != null && seen.add(proposal.id)) options.add(proposal);
        }
        final votes = <String, String>{
          for (final d in current)
            if (d.ballots[started.id] case final choice?)
              if (seen.contains(choice)) d.userId: choice,
        };
        out.add(
          MenuSlotVote(
            id: started.id,
            category: slot.$1,
            slotIndex: slot.$2,
            starterId: starter.userId,
            alternatives: options,
            votes: votes,
            deadline: started.deadline,
            createdAt: started.createdAt,
            resolution: starter.resolved[started.id],
          ),
        );
      }
    }
    return out;
  }

  static (String, int)? _parseSlotKey(String key) {
    final cut = key.lastIndexOf('#');
    if (cut <= 0) return null;
    final index = int.tryParse(key.substring(cut + 1));
    if (index == null || index < 0) return null;
    return (key.substring(0, cut), index);
  }

  @override
  String toString() =>
      'MenuSlotVote(id: $id, $category[$slotIndex], '
      '${alternatives.length} options, ${votes.length} votes, $state)';
}
