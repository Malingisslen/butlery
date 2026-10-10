/// Interface for menu voting persistence.

// lib/repositories/interfaces/menu_voting_repository.dart

import 'package:butlery/models/realtime/menu_ballot.dart';

/// Ballot documents under a live menu, one per person (BUT-2118).
abstract class MenuVotingRepository {
  /// Every ballot document on [menuId], including people who have left the
  /// menu; the caller decides who counts.
  Stream<List<MenuBallot>> watchBallots(String menuId);

  /// Read-modify-write of the signed-in user's own document on [menuId].
  /// [change] receives the stored document, or an empty one; returning that
  /// same instance writes nothing.
  Future<void> updateOwnBallot(
    String menuId,
    MenuBallot Function(MenuBallot current) change,
  );
}
