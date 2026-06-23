/// Interface for menu slot voting persistence.

// lib/repositories/interfaces/menu_voting_repository.dart

import 'package:butlery/models/realtime/menu_slot_vote.dart';

/// Repository interface for menu voting operations.
abstract class MenuVotingRepository {
  /// Create a new vote for a menu slot.
  Future<MenuSlotVote> createVote(MenuSlotVote vote);

  /// Get a specific vote by menu and vote ID.
  Future<MenuSlotVote?> getVote(String menuId, String voteId);

  /// Cast a vote (atomic update of userId → optionId).
  Future<void> castVote(
    String menuId,
    String voteId,
    String userId,
    String optionId,
  );

  /// Resolve a vote with the winning option.
  Future<void> resolveVote(
    String menuId,
    String voteId,
    String winningOptionId,
  );

  /// Stream all votes for a menu.
  Stream<List<MenuSlotVote>> watchVotesForMenu(String menuId);

  /// Add an alternative option to an existing vote.
  Future<void> addAlternative(String menuId, String voteId, VoteOption option);
}
